import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:pocket_pos/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/seed/demo_business_type.dart';
import '../../../core/models/storefront_shopping_config.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../notifications/domain/domain.dart';
import '../../referral/domain/referral.dart';
import '../../../core/firestore/store_catalog_seeder.dart';
import '../../../core/models/storefront_shopping_config.dart';
import '../../notifications/domain/domain.dart';
import '../domain/store_models.dart';

/// Firebase-backed multi-tenant auth: store registration, store-scoped login
/// (store id + username + password), and platform-admin approval.
class StoreAuthService {
  StoreAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static const _prefsStoreId = 'active_store_id';
  static const _prefsAdmin = 'is_platform_admin';
  static const _prefsOperator = 'is_weighbridge_operator';

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

  String _emailFor(String storeId, String username) =>
      '${username.trim().toLowerCase()}@${storeId.trim().toLowerCase()}.pocketpos.app';

  String _usernameFromGoogleUser(User user) {
    final raw = (user.email?.split('@').first ?? user.displayName ?? 'owner')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return raw.isEmpty ? 'owner' : raw;
  }

  String _generateStoreId() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final code =
        List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'STR-$code';
  }

  DocumentReference<Map<String, dynamic>> _storeDoc(String storeId) =>
      _db.collection('stores').doc(storeId);

  DocumentReference<Map<String, dynamic>> _notificationConfigDoc() =>
      _db.collection('platform_config').doc('notifications');

  DocumentReference<Map<String, dynamic>> _publicFeaturesDoc() =>
      _db.collection('platform_config').doc('public_features');

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
    final emailKey = (email ?? '').trim().toLowerCase();
    if (emailKey.isEmpty) {
      throw Exception('Email is required.');
    }

    final storeId = _generateStoreId();
    final cred = await _auth
        .createUserWithEmailAndPassword(
          email: _emailFor(storeId, ownerUsername),
          password: password,
        )
        .timeout(_netTimeout,
            onTimeout: () => _timedOut('Creating your account'));
    final uid = cred.user!.uid;

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

    try {
      final storeData = {
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
      };

      await _storeDoc(storeId).set(storeData);

      await _storeDoc(storeId).collection('users').doc(uid).set({
        'username': ownerUsername.trim(),
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db
          .collection('user_store_index')
          .doc(uid)
          .set({'storeId': storeId});

      await StoreCatalogSeeder(_db).load(businessType, storeId);

      // Send registration email (fire-and-forget, but we log failures).
      // On error, the store is still created; email delivery is non-critical.
      unawaited(_triggerAppsScriptWebhook(storeId, {
        'name': storeName.trim(),
        'ownerName': ownerName.trim(),
        'ownerUsername': ownerUsername.trim(),
        'mobile': mobile?.trim(),
        'email': emailKey,
        'businessType': businessType.name,
      }).catchError((error) {
        if (kDebugMode) {
          print(
              '⚠️ Registration email webhook failed (store still created): $error');
        }
      }));
    } catch (e) {
      await emailRef.delete().catchError((_) {});
      await _safeDeleteUser(cred.user);
      rethrow;
    }

    if (normalizedReferralCode != null && normalizedReferralCode.isNotEmpty) {
      try {
        await _createReferralRecordForRegistration(
          storeId: storeId,
          referredUid: uid,
          referredEmail: emailKey,
          referredName: ownerName.trim(),
          referralCode: normalizedReferralCode,
        );
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Referral registration link failed: $e');
        }
        await _storeDoc(storeId).set(
          {
            'referralLinkStatus': 'failed',
            'referralLinkError': e.toString(),
            'referralRewardStatus': 'pending',
            'referralRewardEvaluatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await _persist(storeId: storeId, isAdmin: false);
    return storeId;
  }

  /// Calls the Google Apps Script Web App to send the registration email.
  ///
  /// The webhook generates an activation token, stores it in Firestore, and sends
  /// a welcome email with an activation link. This is awaitable so the caller can
  /// log failures, though the store is still created if the email fails.
  Future<void> _triggerAppsScriptWebhook(
      String storeId, Map<String, dynamic> storeData) async {
    const endpoint = AppConstants.cartSessionEndpoint;
    if (endpoint.isEmpty) {
      if (kDebugMode) {
        print(
            '⚠️ Cart session endpoint not configured; skipping registration email');
      }
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'storeId': storeId,
              'storeData': storeData,
            }),
          )
          .timeout(_netTimeout,
              onTimeout: () => _timedOut('Registration email'));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true) {
        if (kDebugMode) {
          print('✅ Registration email sent: ${json['emailId']}');
        }
      } else {
        throw Exception(json['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Registration email failed: $e');
      }
      rethrow;
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

  /// Gmail login with Firebase Auth.
  ///
  /// If this is the first login for the account, it auto-creates an approved
  /// store + user mapping so multi-tenant session restore can work.
  Future<StoreSession> loginWithGoogle() async {
    UserCredential cred;
    if (kIsWeb) {
      cred = await _auth
          .signInWithPopup(GoogleAuthProvider())
          .timeout(_netTimeout, onTimeout: () => _timedOut('Google sign-in'));
    } else {
      final googleUser = await _googleSignIn
          .signIn()
          .timeout(_netTimeout, onTimeout: () => _timedOut('Google sign-in'));
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      cred = await _auth
          .signInWithCredential(credential)
          .timeout(_netTimeout, onTimeout: () => _timedOut('Google sign-in'));
    }

    final user = cred.user;
    if (user == null) {
      throw Exception('Google sign-in failed. Please try again.');
    }

    final email = (user.email ?? '').trim().toLowerCase();
    if (email.isEmpty) {
      await _auth.signOut();
      throw Exception('Google account must include an email address.');
    }

    final userStoreRef = _db.collection('user_store_index').doc(user.uid);
    final existingUserStore = await userStoreRef.get();
    var storeId = existingUserStore.data()?['storeId'] as String?;

    final emailRef = _db.collection('email_index').doc(email);
    final emailSnap = await emailRef.get();
    if (storeId == null && emailSnap.exists) {
      final linkedUid = emailSnap.data()?['uid'] as String?;
      final linkedStoreId = emailSnap.data()?['storeId'] as String?;
      if (linkedUid != null && linkedUid != user.uid) {
        await _auth.signOut();
        throw Exception(
            'This Gmail account is already linked to another store owner.');
      }
      storeId = linkedStoreId;
    }

    if (storeId == null) {
      storeId = _generateStoreId();
      final ownerName = (user.displayName ?? 'Store Owner').trim();
      final username = _usernameFromGoogleUser(user);

      try {
        await _db.runTransaction((tx) async {
          final snap = await tx.get(emailRef);
          if (snap.exists) throw const _EmailTakenException();
          tx.set(emailRef, {
            'storeId': storeId,
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(_storeDoc(storeId!), {
            'storeId': storeId,
            'name': ownerName,
            'ownerName': ownerName,
            'ownerUid': user.uid,
            'ownerUsername': username,
            'mobile': user.phoneNumber,
            'email': email,
            'businessType': DemoBusinessType.grocery.name,
            'status': 'approved',
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(_storeDoc(storeId).collection('users').doc(user.uid), {
            'username': username,
            'role': 'owner',
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(userStoreRef, {'storeId': storeId});
        }).timeout(_netTimeout, onTimeout: () => _timedOut('Creating store'));
      } on _EmailTakenException {
        throw Exception(
            'This Gmail account is already registered. Try logging in again.');
      }

      await StoreCatalogSeeder(_db).load(DemoBusinessType.grocery, storeId);
    } else {
      await userStoreRef.set({'storeId': storeId}, SetOptions(merge: true));
      await _storeDoc(storeId).collection('users').doc(user.uid).set({
        'username': _usernameFromGoogleUser(user),
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final session =
        await _sessionFor(storeId, user.uid, _usernameFromGoogleUser(user));
    await _persist(storeId: storeId, isAdmin: false);
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

  Future<void> setStoreStatus(String storeId, StoreStatus status) {
    return _storeDoc(storeId).update({'status': status.name});
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsStoreId);
    await prefs.remove(_prefsAdmin);
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
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

  Future<void> _safeDeleteUser(User? user) async {
    try {
      await user?.delete();
    } catch (_) {}
  }
}

class _EmailTakenException implements Exception {
  const _EmailTakenException();
}
