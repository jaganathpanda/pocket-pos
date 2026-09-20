import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pos/core/firestore/store_scope.dart';

import '../data/firestore_subscription_repository.dart';
import '../domain/subscription_models.dart';
import '../domain/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return FirestoreSubscriptionRepository(ref.watch(firestoreProvider));
});

final adminSubscriptionPlansProvider =
    StreamProvider<List<SubscriptionPlan>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchPlans();
});

final publicSubscriptionPlansProvider =
    StreamProvider<List<SubscriptionPlan>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchPlans(
        includeInactive: false,
        includeDeleted: false,
      );
});

final storeSubscriptionsProvider =
    StreamProvider.family<List<CustomerSubscription>, String>((ref, storeId) {
  return ref.watch(subscriptionRepositoryProvider).watchStoreSubscriptions(
        storeId,
      );
});

final storeEntitlementProvider =
    StreamProvider.family<StoreEntitlement?, String>((ref, storeId) {
  return ref.watch(subscriptionRepositoryProvider).watchStoreEntitlement(
        storeId,
      );
});
