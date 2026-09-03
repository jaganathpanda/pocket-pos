import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pos/core/firestore/store_scope.dart';
import 'package:pocket_pos/features/store/presentation/store_auth_controller.dart';
import '../data/firestore_referral_repository.dart';
import '../domain/referral.dart';
import '../domain/referral_repository.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null || storeId.isEmpty) {
    throw StateError('No active store selected for referral data.');
  }
  return FirestoreReferralRepository(ref.read(firestoreProvider), storeId);
});

final referralSettingsProvider = FutureProvider<ReferralSettings>((ref) async {
  return ref.read(referralRepositoryProvider).getSettings();
});

final referralSettingsStreamProvider = StreamProvider<ReferralSettings>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null || storeId.isEmpty) {
    return Stream.value(const ReferralSettings());
  }
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('referral_settings')
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (data == null || data.isEmpty) return const ReferralSettings();
    try {
      return ReferralSettings.fromMap(data);
    } catch (_) {
      return const ReferralSettings();
    }
  });
});

final userReferralStatsProvider =
    FutureProvider.family<ReferralStats, String>((ref, uid) async {
  return ref.read(referralRepositoryProvider).getReferralStats(uid);
});

final userReferralsProvider =
    StreamProvider.family<List<Referral>, String>((ref, uid) {
  return ref.read(referralRepositoryProvider).watchUserReferrals(uid);
});

final referralCodeProvider =
    FutureProvider.family<String, String>((ref, uid) async {
  return ref.read(referralRepositoryProvider).generateReferralCode(uid);
});
