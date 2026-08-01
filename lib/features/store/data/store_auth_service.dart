import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/seed/demo_business_type.dart';
import '../../../core/firestore/store_catalog_seeder.dart';
import '../domain/store_models.dart';

/// Firebase-backed multi-tenant auth: store registration, store-scoped login
/// (store id + username + password), and platform-admin approval.
class StoreAuthService {
  StoreAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static const _prefsStoreId = 'active_store_id';
  static const _prefsAdmin = 'is_platform_admin';

  // Firebase Auth / Firestore calls occasionally never complete on Android (a
  // stalled reCAPTCHA / Play-Integrity handshake, or an unreachable backend),
  // which would leave the login spinner hanging forever. Cap every network
  // step so a stall surfaces as a clear error instead.
  static const _netTimeout = Duration(seconds: 25);

  Never _timedOut(String what) => throw Exception(
        kIsWeb
            ? '$what timed out. Check your internet connection. If it keeps '
                'happening, your network may be blocking Firestore WebChannel. '
                'Try again on a different network or enable long-polling transport.'
            : '$what timed out. Check your internet connection. If it keeps '
                'happening, the app\'s SHA-1/SHA-256 fingerprints may need to be '
                'added to this Firebase project.',
      );

  // Firebase Auth is email-based; we synthesize a per-store email so the same
  // username can exist in different stores.
  String _emailFor(String storeId, String username) =>
      '${username.trim().toLowerCase()}@${storeId.trim().toLowerCase()}.pocketpos.app';

  String _generateStoreId() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no ambiguous chars
    final rnd = Random.secure();
    final code =
        List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'STR-$code';
  }

  DocumentReference<Map<String, dynamic>> _storeDoc(String storeId) =>
      _db.collection('stores').doc(storeId);

  /// Registers a new store (status = pending) and its owner login.
  /// Returns the generated store id.
  Future<String> registerStore({
    required String storeName,
    required String ownerName,
    required String ownerUsername,
    required String password,
    required DemoBusinessType businessType,
    String? mobile,
    String? email,
  }) async {
    // Generated locally (no pre-read: the caller isn't signed in yet, and the
    // id space is large). Firestore's create rule guards against a real clash.
    final storeId = _generateStoreId();
    final cred = await _auth
        .createUserWithEmailAndPassword(
          email: _emailFor(storeId, ownerUsername),
          password: password,
        )
        .timeout(_netTimeout, onTimeout: () => _timedOut('Creating your account'));
    final uid = cred.user!.uid;

    await _storeDoc(storeId).set({
      'storeId': storeId,
      'name': storeName.trim(),
      'ownerName': ownerName.trim(),
      'ownerUid': uid,
      'ownerUsername': ownerUsername.trim(),
      'mobile': mobile?.trim(),
      'email': email?.trim(),
      'businessType': businessType.name,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _storeDoc(storeId).collection('users').doc(uid).set({
      'username': ownerUsername.trim(),
      'role': 'owner',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Index for session restore (uid -> storeId).
    await _db.collection('user_store_index').doc(uid).set({'storeId': storeId});

    // Seed the chosen business type's demo catalog (categories, products,
    // opening stock) into the new store.
    await StoreCatalogSeeder(_db).load(businessType, storeId);

    await _persist(storeId: storeId, isAdmin: false);
    return storeId;
  }

  /// Store-scoped login. Throws [FirebaseAuthException] on bad credentials.
  Future<StoreSession> login({
    required String storeId,
    required String username,
    required String password,
  }) async {
    final id = storeId.trim().toUpperCase();
    final cred = await _auth
        .signInWithEmailAndPassword(
          email: _emailFor(id, username),
          password: password,
        )
        .timeout(_netTimeout, onTimeout: () => _timedOut('Sign-in'));
    final session = await _sessionFor(id, cred.user!.uid, username.trim());
    await _persist(storeId: id, isAdmin: false);
    return session;
  }

  Future<StoreSession> _sessionFor(String storeId, String uid, String username) async {
    final storeRef = _storeDoc(storeId);
    final storeSnap = await _getWithCacheFallback(
      serverAndCacheRead: () => storeRef.get(),
      cacheRead: () => storeRef.get(const GetOptions(source: Source.cache)),
      timeoutLabel: 'Loading your store',
    );

    if (!storeSnap.exists) {
      await _auth.signOut();
      throw Exception('Store $storeId not found.');
    }

    final userRef = storeRef.collection('users').doc(uid);
    final userSnap = await _getWithCacheFallback(
      serverAndCacheRead: () => userRef.get(),
      cacheRead: () => userRef.get(const GetOptions(source: Source.cache)),
      timeoutLabel: 'Loading your profile',
    );

    final data = storeSnap.data()!;
    return StoreSession(
      storeId: storeId,
      storeName: (data['name'] as String?) ?? storeId,
      uid: uid,
      username: (userSnap.data()?['username'] as String?) ?? username,
      role: (userSnap.data()?['role'] as String?) ?? 'owner',
      status: storeStatusFromString(data['status'] as String?),
      posCounterId: (userSnap.data()?['posCounterId'] as num?)?.toInt(),
    );
  }

  /// Platform-admin login (email + password). The user must be listed in
  /// `platform_admins/{uid}`.
  Future<void> adminLogin({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    final adminDoc =
        await _db.collection('platform_admins').doc(cred.user!.uid).get();
    if (!adminDoc.exists) {
      await _auth.signOut();
      throw Exception('This account is not a platform admin.');
    }
    await _persist(storeId: null, isAdmin: true);
  }

  /// Restores a session on app start (if a Firebase user is still signed in).
  Future<StoreAuthState> restore() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const StoreAuthState(stage: StoreAuthStage.loggedOut);
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsAdmin) ?? false) {
      final adminDoc =
          await _db.collection('platform_admins').doc(user.uid).get();
      if (adminDoc.exists) {
        return const StoreAuthState(stage: StoreAuthStage.admin);
      }
    }
    var storeId = prefs.getString(_prefsStoreId);
    storeId ??= (await _db.collection('user_store_index').doc(user.uid).get())
        .data()?['storeId'] as String?;
    if (storeId == null) {
      await _auth.signOut();
      return const StoreAuthState(stage: StoreAuthStage.loggedOut);
    }
    final session = await _sessionFor(storeId, user.uid, '');
    return StoreAuthState(
      stage: session.isApproved ? StoreAuthStage.active : StoreAuthStage.pending,
      session: session,
    );
  }

  /// Live stream of pending stores for the admin approval screen.
  Stream<List<StoreRecord>> watchStoresByStatus(StoreStatus status) {
    return _db
        .collection('stores')
        .where('status', isEqualTo: status.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              return StoreRecord(
                storeId: d.id,
                name: (m['name'] as String?) ?? d.id,
                ownerName: (m['ownerName'] as String?) ?? '',
                status: storeStatusFromString(m['status'] as String?),
                mobile: m['mobile'] as String?,
                email: m['email'] as String?,
              );
            }).toList());
  }

  Future<void> setStoreStatus(String storeId, StoreStatus status) {
    return _storeDoc(storeId).update({'status': status.name});
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsStoreId);
    await prefs.remove(_prefsAdmin);
    await _auth.signOut();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getWithCacheFallback({
    required Future<DocumentSnapshot<Map<String, dynamic>>> Function()
        serverAndCacheRead,
    required Future<DocumentSnapshot<Map<String, dynamic>>> Function() cacheRead,
    required String timeoutLabel,
  }) async {
    try {
      return await serverAndCacheRead().timeout(
        _netTimeout,
        onTimeout: () => throw TimeoutException(timeoutLabel),
      );
    } on TimeoutException {
      // If network transport stalls but cache has the doc, allow login/restore.
      final cached = await cacheRead();
      if (cached.exists) return cached;
      _timedOut(timeoutLabel);
    }
  }

  Future<void> _persist({String? storeId, required bool isAdmin}) async {
    final prefs = await SharedPreferences.getInstance();
    if (storeId != null) await prefs.setString(_prefsStoreId, storeId);
    await prefs.setBool(_prefsAdmin, isAdmin);
  }
}
