import 'package:equatable/equatable.dart';

/// Referral status enum
enum ReferralStatus {
  pending, // Referred user signed up but hasn't completed first transaction
  completed, // Referred user completed first transaction
  rewarded, // Reward has been given
  expired, // Referral expired
}

/// Reward type enum
enum RewardType {
  credit, // Store credit
  discount, // Discount coupon
  cash, // Cash payment
  points, // Loyalty points
}

class Referral extends Equatable {
  final String id;
  final String referrerUid;
  final String referredUid;
  final String referredEmail;
  final String referredName;
  final ReferralStatus status;
  final RewardType rewardType;
  final double rewardAmount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? rewardedAt;
  final DateTime? expiryAt;

  const Referral({
    required this.id,
    required this.referrerUid,
    required this.referredUid,
    required this.referredEmail,
    required this.referredName,
    required this.status,
    required this.rewardType,
    required this.rewardAmount,
    required this.createdAt,
    this.completedAt,
    this.rewardedAt,
    this.expiryAt,
  });

  bool get isPending => status == ReferralStatus.pending;
  bool get isCompleted => status == ReferralStatus.completed;
  bool get isRewarded => status == ReferralStatus.rewarded;
  bool get isExpired => status == ReferralStatus.expired;

  Referral copyWith({
    String? id,
    String? referrerUid,
    String? referredUid,
    String? referredEmail,
    String? referredName,
    ReferralStatus? status,
    RewardType? rewardType,
    double? rewardAmount,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? rewardedAt,
    DateTime? expiryAt,
  }) {
    return Referral(
      id: id ?? this.id,
      referrerUid: referrerUid ?? this.referrerUid,
      referredUid: referredUid ?? this.referredUid,
      referredEmail: referredEmail ?? this.referredEmail,
      referredName: referredName ?? this.referredName,
      status: status ?? this.status,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      rewardedAt: rewardedAt ?? this.rewardedAt,
      expiryAt: expiryAt ?? this.expiryAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'referrerUid': referrerUid,
      'referredUid': referredUid,
      'referredEmail': referredEmail,
      'referredName': referredName,
      'status': status.name,
      'rewardType': rewardType.name,
      'rewardAmount': rewardAmount,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'rewardedAt': rewardedAt?.toIso8601String(),
      'expiryAt': expiryAt?.toIso8601String(),
    };
  }

  factory Referral.fromMap(Map<String, dynamic> map) {
    return Referral(
      id: map['id'] as String,
      referrerUid: map['referrerUid'] as String,
      referredUid: map['referredUid'] as String,
      referredEmail: map['referredEmail'] as String,
      referredName: map['referredName'] as String,
      status: ReferralStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReferralStatus.pending,
      ),
      rewardType: RewardType.values.firstWhere(
        (e) => e.name == map['rewardType'],
        orElse: () => RewardType.credit,
      ),
      rewardAmount: (map['rewardAmount'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      rewardedAt: map['rewardedAt'] != null
          ? DateTime.parse(map['rewardedAt'] as String)
          : null,
      expiryAt: map['expiryAt'] != null
          ? DateTime.parse(map['expiryAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, status, referrerUid, referredUid];
}

/// Referral settings (admin configurable)
class ReferralSettings extends Equatable {
  final bool enabled;
  final RewardType rewardType;
  final double rewardAmount;
  final int rewardPerReferral;
  final int? maxReferrals;
  final int expiryDays;
  final String termsAndConditions;

  const ReferralSettings({
    this.enabled = true,
    this.rewardType = RewardType.credit,
    this.rewardAmount = 100.0,
    this.rewardPerReferral = 1,
    this.maxReferrals,
    this.expiryDays = 30,
    this.termsAndConditions = '',
  });

  ReferralSettings copyWith({
    bool? enabled,
    RewardType? rewardType,
    double? rewardAmount,
    int? rewardPerReferral,
    int? maxReferrals,
    int? expiryDays,
    String? termsAndConditions,
  }) {
    return ReferralSettings(
      enabled: enabled ?? this.enabled,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      rewardPerReferral: rewardPerReferral ?? this.rewardPerReferral,
      maxReferrals: maxReferrals ?? this.maxReferrals,
      expiryDays: expiryDays ?? this.expiryDays,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'rewardType': rewardType.name,
      'rewardAmount': rewardAmount,
      'rewardPerReferral': rewardPerReferral,
      'maxReferrals': maxReferrals,
      'expiryDays': expiryDays,
      'termsAndConditions': termsAndConditions,
    };
  }

  factory ReferralSettings.fromMap(Map<String, dynamic> map) {
    return ReferralSettings(
      enabled: map['enabled'] as bool? ?? true,
      rewardType: RewardType.values.firstWhere(
        (e) => e.name == map['rewardType'],
        orElse: () => RewardType.credit,
      ),
      rewardAmount: (map['rewardAmount'] as num?)?.toDouble() ?? 100.0,
      rewardPerReferral: map['rewardPerReferral'] as int? ?? 1,
      maxReferrals: map['maxReferrals'] as int?,
      expiryDays: map['expiryDays'] as int? ?? 30,
      termsAndConditions: map['termsAndConditions'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [enabled, rewardType, rewardAmount];
}
