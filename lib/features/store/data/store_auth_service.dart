import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/seed/demo_business_type.dart';
import '../../../core/models/storefront_shopping_config.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../notifications/domain/domain.dart';
import '../../referral/domain/referral.dart';
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
  static const _prefsOperator = 'is_weighbridge_operator';

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

  DocumentReference<Map<String, dynamic>> _operatorDoc(String uid) =>
      _db.collection('weighbridge_operators').doc(uid);

  DocumentReference<Map<String, dynamic>> _notificationConfigDoc() =>
      _db.collection('platform_config').doc('notifications');

  DocumentReference<Map<String, dynamic>> _publicFeaturesDoc() =>
      _db.collection('platform_config').doc('public_features');

  DocumentReference<Map<String, dynamic>> _referralSettingsDoc() =>
      _db.collection('platform_config').doc('referral_settings');

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
    String? referralCode,
  }) async {
    // One email = one store: the contact email must be unique across the
    // platform. We reserve it atomically in `email_index` right after creating
    // the auth account (below).
    final emailKey = (email ?? '').trim().toLowerCase();
    if (emailKey.isEmpty) {
      throw Exception('Email is required.');
    }

    // Generated locally (no pre-read: the caller isn't signed in yet, and the
    // id space is large). Firestore's create rule guards against a real clash.
    final normalizedReferralCode = referralCode?.trim().toUpperCase();
    final storeId = _generateStoreId();
    final cred = await _auth
        .createUserWithEmailAndPassword(
          email: _emailFor(storeId, ownerUsername),
          password: password,
        )
        .timeout(_netTimeout,
            onTimeout: () => _timedOut('Creating your account'));
    final uid = cred.user!.uid;

    // Reserve the email atomically. The transaction fails (and no store is
    // created) if another store already registered this address.
    final emailRef = _db.collection('email_index').doc(emailKey);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(emailRef);
        if (snap.exists) throw const _EmailTakenException();
        tx.set(emailRef, {
          'storeId': storeId,
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }).timeout(_netTimeout,
          onTimeout: () => _timedOut('Checking your email'));
    } on _EmailTakenException {
      await _safeDeleteUser(cred.user);
      throw Exception(
          'This email is already registered to a store. Log in to your '
          'existing store, or use a different email.');
    } catch (_) {
      await _safeDeleteUser(cred.user);
      rethrow;
    }

    // Email reserved — create the store. On any failure, release the
    // reservation and the auth account so the email can be reused.
    try {
      await _storeDoc(storeId).set({
        'storeId': storeId,
        'name': storeName.trim(),
        'ownerName': ownerName.trim(),
        'ownerUid': uid,
        'ownerUsername': ownerUsername.trim(),
        'mobile': mobile?.trim(),
        'email': emailKey,
        if (normalizedReferralCode != null && normalizedReferralCode.isNotEmpty)
          'appliedReferralCode': normalizedReferralCode,
        if (normalizedReferralCode != null && normalizedReferralCode.isNotEmpty)
          'referralRewardStatus': 'pending',
        if (normalizedReferralCode != null && normalizedReferralCode.isNotEmpty)
          'referralAppliedAt': FieldValue.serverTimestamp(),
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
      await _db
          .collection('user_store_index')
          .doc(uid)
          .set({'storeId': storeId});

      // Seed the chosen business type's demo catalog (categories, products,
      // opening stock) into the new store.
      await StoreCatalogSeeder(_db).load(businessType, storeId);
    } catch (e) {
      await emailRef.delete().catchError((_) {});
      await _safeDeleteUser(cred.user);
      rethrow;
    }

    if (normalizedReferralCode != null && normalizedReferralCode.isNotEmpty) {
      unawaited(_createReferralRecordForRegistration(
        storeId: storeId,
        referredUid: uid,
        referredEmail: emailKey,
        referredName: ownerName.trim(),
        referralCode: normalizedReferralCode,
      ).catchError((Object e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Referral registration link skipped/failed: $e');
        }
      }));
    }

    await _persist(storeId: storeId, isAdmin: false);
    return storeId;
  }

  Future<ReferralSettings> _loadReferralSettings() async {
    final doc = await _referralSettingsDoc().get();
    final data = doc.data();
    if (data == null || data.isEmpty) return const ReferralSettings();
    return ReferralSettings.fromMap(data);
  }

  Future<_ReferralReferrerMatch?> _findReferrerByReferralCode(
    String referralCode,
  ) async {
    final snap = await _db
        .collectionGroup('users')
        .where('referralCode', isEqualTo: referralCode)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;

    final userDoc = snap.docs.first;
    final storeRef = userDoc.reference.parent.parent;
    if (storeRef == null) return null;

    return _ReferralReferrerMatch(
      storeId: storeRef.id,
      uid: userDoc.id,
      userRef: userDoc.reference,
    );
  }

  Future<void> _createReferralRecordForRegistration({
    required String storeId,
    required String referredUid,
    required String referredEmail,
    required String referredName,
    required String referralCode,
  }) async {
    final normalizedCode = referralCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) return;

    final referrer = await _findReferrerByReferralCode(normalizedCode);
    if (referrer == null) {
      await _storeDoc(storeId).set(
        {
          'referralRewardStatus': 'invalid_code',
          'referralRewardEvaluatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return;
    }

    if (referrer.storeId == storeId) {
      await _storeDoc(storeId).set(
        {
          'referralRewardStatus': 'self_referral_rejected',
          'referralRewardEvaluatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return;
    }

    final settings = await _loadReferralSettings();
    final referralId = newIntId().toString();
    final now = DateTime.now();
    final referral = Referral(
      id: referralId,
      referrerUid: referrer.uid,
      referredUid: referredUid,
      referredEmail: referredEmail,
      referredName: referredName,
      status: ReferralStatus.pending,
      rewardType: settings.rewardType,
      rewardAmount: settings.rewardAmount,
      createdAt: now,
      expiryAt: now.add(Duration(days: settings.expiryDays)),
    );

    await _db
        .collection('stores')
        .doc(referrer.storeId)
        .collection('referrals')
        .doc(referralId)
        .set({
      ...referral.toMap(),
      'referrerStoreId': referrer.storeId,
      'referredStoreId': storeId,
      'referralCode': normalizedCode,
    });

    await _storeDoc(storeId).set(
      {
        'referralRewardStatus': 'pending',
        'referralSourceStoreId': referrer.storeId,
        'referralSourceUid': referrer.uid,
        'referralReferralId': referralId,
        'referralAppliedAt': FieldValue.serverTimestamp(),
        'appliedReferralCode': normalizedCode,
      },
      SetOptions(merge: true),
    );

    await _storeDoc(storeId).collection('users').doc(referredUid).set(
      {
        'referredBy': referrer.uid,
        'referredAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Best-effort cleanup of a just-created auth account when registration is
  /// aborted (e.g. the email was already taken). A freshly created user can be
  /// deleted without re-authentication; failures are non-fatal.
  Future<void> _safeDeleteUser(User? user) async {
    try {
      await user?.delete();
    } catch (_) {
      // Leaves an orphan auth account with a unique synthesized email; harmless
      // because no store is attached and a retry generates a fresh store id.
    }
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

  Future<StoreSession> _sessionFor(
      String storeId, String uid, String username) async {
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

  // ── Weighbridge operators (platform-level, not tied to a store) ────────────

  /// Registers a platform weighbridge operator (status = pending) with a real
  /// email + password. A platform admin must approve before they can log in.
  Future<void> registerOperator({
    required String name,
    required String email,
    required String password,
    String? mobile,
  }) async {
    final cred = await _auth
        .createUserWithEmailAndPassword(
            email: email.trim().toLowerCase(), password: password)
        .timeout(_netTimeout,
            onTimeout: () => _timedOut('Creating your account'));
    final uid = cred.user!.uid;
    try {
      await _operatorDoc(uid).set({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'mobile': mobile?.trim(),
        'status': 'pending',
        'role': 'weighbridgeOperator',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await _safeDeleteUser(cred.user);
      rethrow;
    }
    await _persist(storeId: null, isAdmin: false, isOperator: true);
  }

  /// Operator login (email + password). Returns the operator's profile; the
  /// caller routes to pending or operator stage based on [OperatorProfile].
  Future<OperatorProfile> operatorLogin({
    required String email,
    required String password,
  }) async {
    final cred = await _auth
        .signInWithEmailAndPassword(
            email: email.trim().toLowerCase(), password: password)
        .timeout(_netTimeout, onTimeout: () => _timedOut('Sign-in'));
    final uid = cred.user!.uid;
    final doc = await _operatorDoc(uid).get();
    if (!doc.exists) {
      await _auth.signOut();
      throw Exception('This account is not a weighbridge operator.');
    }
    await _persist(storeId: null, isAdmin: false, isOperator: true);
    return _operatorFromDoc(uid, doc.data()!);
  }

  OperatorProfile _operatorFromDoc(String uid, Map<String, dynamic> d) {
    return OperatorProfile(
      uid: uid,
      name: (d['name'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      status: storeStatusFromString(d['status'] as String?),
    );
  }

  /// An operator "enters" a mill by its Store ID. Reads the store doc and builds
  /// a store session scoped to that mill, tagged with the operator role.
  Future<StoreSession> operatorEnterMill({
    required String storeId,
    required OperatorProfile operator,
  }) async {
    final id = storeId.trim().toUpperCase();
    final storeRef = _storeDoc(id);
    final snap = await storeRef
        .get()
        .timeout(_netTimeout, onTimeout: () => _timedOut('Loading the mill'));
    if (!snap.exists) {
      throw Exception('Mill $id not found. Check the Store ID.');
    }
    final data = snap.data()!;
    final status = storeStatusFromString(data['status'] as String?);
    if (status != StoreStatus.approved) {
      throw Exception('Mill $id is not active yet.');
    }
    // Weighbridge is a rice-mill-only feature.
    if ((data['businessType'] as String?) != DemoBusinessType.riceMill.name) {
      throw Exception('Store $id is not a Rice Mill. Weighbridge is only '
          'available for rice mills.');
    }
    return StoreSession(
      storeId: id,
      storeName: (data['name'] as String?) ?? id,
      uid: operator.uid,
      username: operator.name,
      role: 'weighbridge_operator',
      status: status,
    );
  }

  /// Platform-admin: live stream of operators by status (for approval screen).
  Stream<List<OperatorProfile>> watchOperatorsByStatus(StoreStatus status) {
    return _db
        .collection('weighbridge_operators')
        .where('status', isEqualTo: status.name)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => _operatorFromDoc(d.id, d.data())).toList());
  }

  Future<void> setOperatorStatus(String uid, StoreStatus status) {
    return _operatorDoc(uid).update({'status': status.name});
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
    if (prefs.getBool(_prefsOperator) ?? false) {
      final opDoc = await _operatorDoc(user.uid).get();
      if (opDoc.exists) {
        final profile = _operatorFromDoc(user.uid, opDoc.data()!);
        return StoreAuthState(
          stage: profile.isApproved
              ? StoreAuthStage.operator
              : StoreAuthStage.pending,
          operator: profile,
        );
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
      stage:
          session.isApproved ? StoreAuthStage.active : StoreAuthStage.pending,
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

  Stream<NotificationFeatures> watchNotificationFeatures() {
    return _notificationConfigDoc().snapshots().map((snap) {
      return NotificationFeatures.fromFirestoreMap(snap.data());
    });
  }

  Future<void> setNotificationFeatures(NotificationFeatures features) {
    return _notificationConfigDoc().set(
      features.toFirestoreMap(),
      SetOptions(merge: true),
    );
  }

  Stream<StorefrontShoppingConfig> watchStorefrontFeatureFlag() {
    return _publicFeaturesDoc().snapshots().map((snap) {
      return StorefrontShoppingConfig.fromFirestoreMap(snap.data());
    });
  }

  Future<void> setStorefrontFeatureFlag(StorefrontShoppingConfig features) {
    return _publicFeaturesDoc().set(
      features.toFirestoreMap(),
      SetOptions(merge: true),
    );
  }

  Stream<ReferralSettings> watchReferralSettings() {
    return _referralSettingsDoc().snapshots().map((snap) {
      final data = snap.data();
      if (data == null || data.isEmpty) return const ReferralSettings();
      return ReferralSettings.fromMap(data);
    });
  }

  Future<void> setReferralSettings(ReferralSettings settings) {
    return _referralSettingsDoc().set(
      settings.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> setStoreStatus(String storeId, StoreStatus status) {
    return _storeDoc(storeId).update({'status': status.name});
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsStoreId);
    await prefs.remove(_prefsAdmin);
    await prefs.remove(_prefsOperator);
    await _auth.signOut();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getWithCacheFallback({
    required Future<DocumentSnapshot<Map<String, dynamic>>> Function()
        serverAndCacheRead,
    required Future<DocumentSnapshot<Map<String, dynamic>>> Function()
        cacheRead,
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

  Future<void> _persist({
    String? storeId,
    required bool isAdmin,
    bool isOperator = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (storeId != null) await prefs.setString(_prefsStoreId, storeId);
    await prefs.setBool(_prefsAdmin, isAdmin);
    await prefs.setBool(_prefsOperator, isOperator);
  }
}

class _ReferralReferrerMatch {
  final String storeId;
  final String uid;
  final DocumentReference<Map<String, dynamic>> userRef;

  const _ReferralReferrerMatch({
    required this.storeId,
    required this.uid,
    required this.userRef,
  });
}

/// Thrown inside the registration transaction when the email is already
/// reserved by another store. Kept private to the auth service.
class _EmailTakenException implements Exception {
  const _EmailTakenException();
}
