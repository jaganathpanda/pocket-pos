import 'subscription_models.dart';

abstract class SubscriptionRepository {
  Stream<List<SubscriptionPlan>> watchPlans({
    bool includeInactive = true,
    bool includeDeleted = false,
  });

  Future<void> savePlan(SubscriptionPlan plan);

  Future<void> duplicatePlan(String planId);

  Future<void> movePlan(String planId, {required bool up});

  Future<void> setPlanActive(String planId, bool isActive);

  Future<void> safeDeletePlan(String planId);

  Stream<List<CustomerSubscription>> watchStoreSubscriptions(String storeId);

  Future<void> saveStoreSubscription(CustomerSubscription subscription);

  Future<void> updateStoreSubscriptionStatus({
    required String storeId,
    required String subscriptionId,
    required SubscriptionStatus status,
    bool? cancelAtPeriodEnd,
  });

  Stream<StoreEntitlement?> watchStoreEntitlement(String storeId);
}
