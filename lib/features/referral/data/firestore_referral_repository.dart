import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_pos/core/firestore/store_scope.dart';
import 'dart:math';
import '../../../core/firestore/firestore_ids.dart';
import '../domain/referral.dart';
import '../domain/referral_repository.dart';

class FirestoreReferralRepository implements ReferralRepository {
  final FirebaseFirestore _db;
  final String _storeId;

  FirestoreReferralRepository(this._db, this._storeId);

  CollectionReference<Map<String, dynamic>> get _referralsCol =>
      storeCollection(_db, _storeId, 'referrals');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      storeCollection(_db, _storeId, 'users');

  DocumentReference<Map<String, dynamic>> get _legacyStoreSettingsDoc =>
      storeCollection(_db, _storeId, 'settings').doc('referral_settings');

  DocumentReference<Map<String, dynamic>> get _platformSettingsDoc =>
      _db.collection('platform_config').doc('referral_settings');

  static const String _referralCodeChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final RegExp _legacyRepeatedCode = RegExp(r'^([A-Z0-9])\1{7}$');
  static final Random _random = Random.secure();

  @override
  Stream<List<Referral>> watchUserReferrals(String uid) {
    return _referralsCol
        .where('referrerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Referral.fromMap(doc.data())).toList());
  }

  @override
  Future<ReferralStats> getReferralStats(String uid) async {
    final snap = await _referralsCol.where('referrerUid', isEqualTo: uid).get();
    final referrals =
        snap.docs.map((doc) => Referral.fromMap(doc.data())).toList();

    final total = referrals.length;
    final completed = referrals.where((r) => r.isCompleted).length;
    final rewarded = referrals.where((r) => r.isRewarded).length;
    final totalRewards = referrals
        .where((r) => r.isRewarded)
        .fold<double>(0, (sum, r) => sum + r.rewardAmount);
    final pendingRewards = referrals
        .where((r) => r.isCompleted && !r.isRewarded)
        .fold<double>(0, (sum, r) => sum + r.rewardAmount);

    return ReferralStats(
      totalReferrals: total,
      completedReferrals: completed,
      rewardedReferrals: rewarded,
      totalRewards: totalRewards,
      pendingRewards: pendingRewards,
    );
  }

  @override
  Future<String> generateReferralCode(String uid) async {
    // Check if user already has a code
    final userDoc = await _usersCol.doc(uid).get();
    if (userDoc.exists) {
      final existing = userDoc.data()?['referralCode'] as String?;
      if (existing != null && existing.isNotEmpty) {
        final normalized = existing.trim().toUpperCase();
        // Legacy fix: previous generator produced repeated chars like YYYYYYYY.
        // Regenerate once when such a code is detected.
        if (!_legacyRepeatedCode.hasMatch(normalized)) {
          return normalized;
        }
      }
    }

    // Generate new code
    String code;
    bool exists;
    do {
      code = _generateCode();
      final existingDoc =
          await _usersCol.where('referralCode', isEqualTo: code).get();
      exists = existingDoc.docs.isNotEmpty;
    } while (exists);

    // Save to user
    await _usersCol.doc(uid).set({
      'referralCode': code,
    }, SetOptions(merge: true));

    return code;
  }

  String _generateCode() {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      final index = _random.nextInt(_referralCodeChars.length);
      buffer.write(_referralCodeChars[index]);
    }
    return buffer.toString();
  }

  @override
  Future<void> createReferral({
    required String referrerUid,
    required String referredUid,
    required String referredEmail,
    required String referredName,
    String? referralCode,
  }) async {
    // Get settings
    final settings = await getSettings();
    final expiryDate = DateTime.now().add(Duration(days: settings.expiryDays));

    final referral = Referral(
      id: newIntId().toString(),
      referrerUid: referrerUid,
      referredUid: referredUid,
      referredEmail: referredEmail,
      referredName: referredName,
      status: ReferralStatus.pending,
      rewardType: settings.rewardType,
      rewardAmount: settings.rewardAmount,
      createdAt: DateTime.now(),
      expiryAt: expiryDate,
    );

    await _referralsCol.doc(referral.id).set(referral.toMap());

    // Update referred user's "referredBy" field
    await _usersCol.doc(referredUid).set({
      'referredBy': referrerUid,
      'referredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> completeReferral(String referralId) async {
    final doc = await _referralsCol.doc(referralId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final referral = Referral.fromMap(data);

    if (referral.status != ReferralStatus.pending) return;

    await _referralsCol.doc(referralId).set({
      'status': ReferralStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> rewardReferral(String referralId) async {
    final doc = await _referralsCol.doc(referralId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final referral = Referral.fromMap(data);

    if (referral.status != ReferralStatus.completed) return;

    await _referralsCol.doc(referralId).set({
      'status': ReferralStatus.rewarded.name,
      'rewardedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Add reward to referrer's account
    await _usersCol.doc(referral.referrerUid).set({
      'referralRewards': FieldValue.increment(referral.rewardAmount),
    }, SetOptions(merge: true));
  }

  @override
  Future<ReferralSettings> getSettings() async {
    try {
      final doc = await _platformSettingsDoc.get();
      if (doc.exists) {
        return ReferralSettings.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (_) {
      // Fallback for older deployments that still use store-scoped settings.
      try {
        final legacy = await _legacyStoreSettingsDoc.get();
        if (legacy.exists) {
          return ReferralSettings.fromMap(
              legacy.data() as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    return const ReferralSettings();
  }

  @override
  Future<void> updateSettings(ReferralSettings settings) async {
    await _platformSettingsDoc.set(settings.toMap(), SetOptions(merge: true));
  }

  @override
  Future<bool> isValidReferralCode(String code) async {
    if (code.isEmpty) return false;
    final snap = await _usersCol.where('referralCode', isEqualTo: code).get();
    return snap.docs.isNotEmpty;
  }
}
