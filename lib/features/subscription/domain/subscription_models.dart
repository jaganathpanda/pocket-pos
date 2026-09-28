import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum BillingCycle { monthly, yearly }

enum SubscriptionStatus {
  pending,
  trialing,
  active,
  pastDue,
  canceled,
  expired,
}

BillingCycle billingCycleFromString(String? value) {
  switch (value) {
    case 'yearly':
      return BillingCycle.yearly;
    case 'monthly':
    default:
      return BillingCycle.monthly;
  }
}

SubscriptionStatus subscriptionStatusFromString(String? value) {
  switch (value) {
    case 'trialing':
      return SubscriptionStatus.trialing;
    case 'active':
      return SubscriptionStatus.active;
    case 'past_due':
      return SubscriptionStatus.pastDue;
    case 'canceled':
      return SubscriptionStatus.canceled;
    case 'expired':
      return SubscriptionStatus.expired;
    case 'pending':
    default:
      return SubscriptionStatus.pending;
  }
}

String subscriptionStatusWireName(SubscriptionStatus status) {
  switch (status) {
    case SubscriptionStatus.pastDue:
      return 'past_due';
    default:
      return status.name;
  }
}

DateTime? _readDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate().toUtc();
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) return DateTime.tryParse(raw)?.toUtc();
  return null;
}

class SubscriptionPlan extends Equatable {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.billingCycle,
    required this.priceMinor,
    required this.currency,
    required this.sortOrder,
    required this.isActive,
    required this.publicVisible,
    required this.isPopular,
    required this.trialDays,
    required this.featureList,
    required this.limits,
    this.badgeText,
    this.ctaLabel,
    this.ctaUrl,
    this.defaultForNewStores = false,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final BillingCycle billingCycle;
  final int priceMinor;
  final String currency;
  final int sortOrder;
  final bool isActive;
  final bool publicVisible;
  final bool isPopular;
  final int trialDays;
  final List<String> featureList;
  final Map<String, int> limits;
  final String? badgeText;
  final String? ctaLabel;
  final String? ctaUrl;
  final bool defaultForNewStores;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  double get priceMajor => priceMinor / 100.0;

  SubscriptionPlan copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    BillingCycle? billingCycle,
    int? priceMinor,
    String? currency,
    int? sortOrder,
    bool? isActive,
    bool? publicVisible,
    bool? isPopular,
    int? trialDays,
    List<String>? featureList,
    Map<String, int>? limits,
    String? badgeText,
    String? ctaLabel,
    String? ctaUrl,
    bool? defaultForNewStores,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      billingCycle: billingCycle ?? this.billingCycle,
      priceMinor: priceMinor ?? this.priceMinor,
      currency: currency ?? this.currency,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      publicVisible: publicVisible ?? this.publicVisible,
      isPopular: isPopular ?? this.isPopular,
      trialDays: trialDays ?? this.trialDays,
      featureList: featureList ?? this.featureList,
      limits: limits ?? this.limits,
      badgeText: badgeText ?? this.badgeText,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      ctaUrl: ctaUrl ?? this.ctaUrl,
      defaultForNewStores: defaultForNewStores ?? this.defaultForNewStores,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'billingCycle': billingCycle.name,
      'priceMinor': priceMinor,
      'currency': currency,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'publicVisible': publicVisible,
      'isPopular': isPopular,
      'trialDays': trialDays,
      'featureList': featureList,
      'limits': limits,
      'badgeText': badgeText,
      'ctaLabel': ctaLabel,
      'ctaUrl': ctaUrl,
      'defaultForNewStores': defaultForNewStores,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };
  }

  factory SubscriptionPlan.fromMap(String id, Map<String, dynamic> map) {
    final rawLimits = map['limits'];
    final limits = <String, int>{};
    if (rawLimits is Map) {
      for (final entry in rawLimits.entries) {
        final key = entry.key.toString().trim();
        final value = (entry.value as num?)?.toInt();
        if (key.isNotEmpty && value != null) {
          limits[key] = value;
        }
      }
    }

    return SubscriptionPlan(
      id: id,
      name: (map['name'] as String?)?.trim() ?? '',
      slug: (map['slug'] as String?)?.trim() ?? id,
      description: (map['description'] as String?)?.trim() ?? '',
      billingCycle: billingCycleFromString(map['billingCycle'] as String?),
      priceMinor: (map['priceMinor'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String?)?.trim().toUpperCase() ?? 'INR',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] == true,
      publicVisible: map['publicVisible'] == true,
      isPopular: map['isPopular'] == true,
      trialDays: (map['trialDays'] as num?)?.toInt() ?? 0,
      featureList: (map['featureList'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[],
      limits: limits,
      badgeText: (map['badgeText'] as String?)?.trim(),
      ctaLabel: (map['ctaLabel'] as String?)?.trim(),
      ctaUrl: (map['ctaUrl'] as String?)?.trim(),
      defaultForNewStores: map['defaultForNewStores'] == true,
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
      deletedAt: _readDate(map['deletedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        billingCycle,
        priceMinor,
        currency,
        sortOrder,
        isActive,
        publicVisible,
        isPopular,
        trialDays,
        featureList,
        limits,
        badgeText,
        ctaLabel,
        ctaUrl,
        defaultForNewStores,
        deletedAt,
      ];
}

class CustomerSubscription extends Equatable {
  const CustomerSubscription({
    required this.id,
    required this.storeId,
    required this.planId,
    required this.status,
    required this.source,
    required this.provider,
    required this.cancelAtPeriodEnd,
    this.providerRef,
    this.startedAt,
    this.trialEndAt,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.canceledAt,
    this.createdAt,
    this.updatedAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String storeId;
  final String planId;
  final SubscriptionStatus status;
  final String source;
  final String provider;
  final String? providerRef;
  final bool cancelAtPeriodEnd;
  final DateTime? startedAt;
  final DateTime? trialEndAt;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? canceledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  CustomerSubscription copyWith({
    String? id,
    String? storeId,
    String? planId,
    SubscriptionStatus? status,
    String? source,
    String? provider,
    String? providerRef,
    bool? cancelAtPeriodEnd,
    DateTime? startedAt,
    DateTime? trialEndAt,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    DateTime? canceledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return CustomerSubscription(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      source: source ?? this.source,
      provider: provider ?? this.provider,
      providerRef: providerRef ?? this.providerRef,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      startedAt: startedAt ?? this.startedAt,
      trialEndAt: trialEndAt ?? this.trialEndAt,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      canceledAt: canceledAt ?? this.canceledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'planId': planId,
      'status': subscriptionStatusWireName(status),
      'source': source,
      'provider': provider,
      'providerRef': providerRef,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'startedAt': startedAt,
      'trialEndAt': trialEndAt,
      'currentPeriodStart': currentPeriodStart,
      'currentPeriodEnd': currentPeriodEnd,
      'canceledAt': canceledAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'metadata': metadata,
    };
  }

  factory CustomerSubscription.fromMap(
    String id,
    Map<String, dynamic> map, {
    required String storeId,
  }) {
    final rawMeta = map['metadata'];
    return CustomerSubscription(
      id: id,
      storeId: storeId,
      planId: (map['planId'] as String?)?.trim() ?? '',
      status: subscriptionStatusFromString(map['status'] as String?),
      source: (map['source'] as String?)?.trim() ?? 'admin',
      provider: (map['provider'] as String?)?.trim() ?? 'none',
      providerRef: (map['providerRef'] as String?)?.trim(),
      cancelAtPeriodEnd: map['cancelAtPeriodEnd'] == true,
      startedAt: _readDate(map['startedAt']),
      trialEndAt: _readDate(map['trialEndAt']),
      currentPeriodStart: _readDate(map['currentPeriodStart']),
      currentPeriodEnd: _readDate(map['currentPeriodEnd']),
      canceledAt: _readDate(map['canceledAt']),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
      metadata: rawMeta is Map
          ? Map<String, dynamic>.from(rawMeta as Map)
          : const <String, dynamic>{},
    );
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        planId,
        status,
        source,
        provider,
        providerRef,
        cancelAtPeriodEnd,
        startedAt,
        trialEndAt,
        currentPeriodStart,
        currentPeriodEnd,
        canceledAt,
      ];
}

class StoreEntitlement extends Equatable {
  const StoreEntitlement({
    required this.storeId,
    required this.status,
    required this.planId,
    required this.planName,
    required this.billingCycle,
    required this.priceMinor,
    required this.currency,
    required this.featureList,
    required this.limits,
    this.effectiveFrom,
    this.effectiveUntil,
    this.sourceSubscriptionId,
    this.updatedAt,
  });

  final String storeId;
  final SubscriptionStatus status;
  final String planId;
  final String planName;
  final BillingCycle billingCycle;
  final int priceMinor;
  final String currency;
  final List<String> featureList;
  final Map<String, int> limits;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;
  final String? sourceSubscriptionId;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'status': subscriptionStatusWireName(status),
      'planId': planId,
      'planName': planName,
      'billingCycle': billingCycle.name,
      'priceMinor': priceMinor,
      'currency': currency,
      'featureList': featureList,
      'limits': limits,
      'effectiveFrom': effectiveFrom,
      'effectiveUntil': effectiveUntil,
      'sourceSubscriptionId': sourceSubscriptionId,
      'updatedAt': updatedAt,
    };
  }

  factory StoreEntitlement.fromMap(String storeId, Map<String, dynamic> map) {
    final rawLimits = map['limits'];
    final limits = <String, int>{};
    if (rawLimits is Map) {
      for (final entry in rawLimits.entries) {
        final key = entry.key.toString();
        final value = (entry.value as num?)?.toInt();
        if (key.isNotEmpty && value != null) {
          limits[key] = value;
        }
      }
    }

    return StoreEntitlement(
      storeId: storeId,
      status: subscriptionStatusFromString(map['status'] as String?),
      planId: (map['planId'] as String?) ?? '',
      planName: (map['planName'] as String?) ?? '',
      billingCycle: billingCycleFromString(map['billingCycle'] as String?),
      priceMinor: (map['priceMinor'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String?)?.toUpperCase() ?? 'INR',
      featureList:
          (map['featureList'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[],
      limits: limits,
      effectiveFrom: _readDate(map['effectiveFrom']),
      effectiveUntil: _readDate(map['effectiveUntil']),
      sourceSubscriptionId: map['sourceSubscriptionId'] as String?,
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
        storeId,
        status,
        planId,
        planName,
        billingCycle,
        priceMinor,
        currency,
        featureList,
        limits,
        effectiveFrom,
        effectiveUntil,
        sourceSubscriptionId,
      ];
}
