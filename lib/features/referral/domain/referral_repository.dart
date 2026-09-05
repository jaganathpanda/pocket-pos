import 'referral.dart';

abstract class ReferralRepository {
  /// Get all referrals for a user
  Stream<List<Referral>> watchUserReferrals(String uid);

  /// Get referral statistics for a user
  Future<ReferralStats> getReferralStats(String uid);

  /// Generate referral code for a user
  Future<String> generateReferralCode(String uid);

  /// Mark a referral as completed (when referred user makes first purchase)
  Future<void> completeReferral(String referralId);

  /// Reward a referral
  Future<void> rewardReferral(String referralId);

  /// Get referral settings (admin)
  Future<ReferralSettings> getSettings();

  /// Update referral settings (admin only)
  Future<void> updateSettings(ReferralSettings settings);

  /// Check if a referral code is valid
  Future<bool> isValidReferralCode(String code);
}

class ReferralStats {
  final int totalReferrals;
  final int completedReferrals;
  final int rewardedReferrals;
  final double totalRewards;
  final double pendingRewards;

  const ReferralStats({
    required this.totalReferrals,
    required this.completedReferrals,
    required this.rewardedReferrals,
    required this.totalRewards,
    required this.pendingRewards,
  });
}
