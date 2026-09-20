import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/subscription_models.dart';
import '../domain/subscription_repository.dart';

class FirestoreSubscriptionRepository implements SubscriptionRepository {
  FirestoreSubscriptionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _plansCol =>
      _db.collection('platform_subscription_plans');

  CollectionReference<Map<String, dynamic>> _storeSubscriptionsCol(
    String storeId,
  ) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('customer_subscriptions');
  }

  DocumentReference<Map<String, dynamic>> _storeEntitlementDoc(String storeId) {
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('subscription_state')
        .doc('current');
  }

  @override
  Stream<List<SubscriptionPlan>> watchPlans({
    bool includeInactive = true,
    bool includeDeleted = false,
  }) {
    Query<Map<String, dynamic>> query = _plansCol.orderBy('sortOrder');
    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }
    if (!includeDeleted) {
      query = query.where('deletedAt', isNull: true);
    }
    return query.snapshots().map((snap) {
      return snap.docs
          .map((doc) => SubscriptionPlan.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<void> savePlan(SubscriptionPlan plan) async {
    final now = FieldValue.serverTimestamp();
    final ref =
        plan.id.trim().isEmpty ? _plansCol.doc() : _plansCol.doc(plan.id);

    final payload = plan.toMap()
      ..remove('createdAt')
      ..remove('updatedAt')
      ..['createdAt'] = plan.createdAt ?? now
      ..['updatedAt'] = now;

    await ref.set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> duplicatePlan(String planId) async {
    final source = await _plansCol.doc(planId).get();
    if (!source.exists) {
      throw Exception('Plan not found.');
    }
    final src = SubscriptionPlan.fromMap(source.id, source.data()!);
    final copyRef = _plansCol.doc();
    final newSlug = '${src.slug}-copy-${DateTime.now().millisecondsSinceEpoch}';
    final duplicated = src.copyWith(
      id: copyRef.id,
      slug: newSlug,
      name: '${src.name} (Copy)',
      isActive: false,
      sortOrder: src.sortOrder + 1,
      clearDeletedAt: true,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    await savePlan(duplicated);
  }

  @override
  Future<void> movePlan(String planId, {required bool up}) async {
    final snap = await _plansCol
        .where('deletedAt', isNull: true)
        .orderBy('sortOrder')
        .get();
    final plans =
        snap.docs.map((d) => SubscriptionPlan.fromMap(d.id, d.data())).toList();
    final index = plans.indexWhere((p) => p.id == planId);
    if (index < 0) return;

    final swapWith = up ? index - 1 : index + 1;
    if (swapWith < 0 || swapWith >= plans.length) return;

    final current = plans[index];
    final target = plans[swapWith];
    final batch = _db.batch();
    batch.update(_plansCol.doc(current.id), {
      'sortOrder': target.sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_plansCol.doc(target.id), {
      'sortOrder': current.sortOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<void> setPlanActive(String planId, bool isActive) {
    return _plansCol.doc(planId).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> safeDeletePlan(String planId) async {
    final inUse = await _db
        .collectionGroup('customer_subscriptions')
        .where('planId', isEqualTo: planId)
        .where('status', whereIn: const ['trialing', 'active', 'past_due'])
        .limit(1)
        .get();
    if (inUse.docs.isNotEmpty) {
      throw Exception('Plan is currently assigned to active subscriptions.');
    }

    await _plansCol.doc(planId).set({
      'isActive': false,
      'publicVisible': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<CustomerSubscription>> watchStoreSubscriptions(String storeId) {
    return _storeSubscriptionsCol(storeId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                CustomerSubscription.fromMap(d.id, d.data(), storeId: storeId))
            .toList());
  }

  @override
  Future<void> saveStoreSubscription(CustomerSubscription subscription) {
    final col = _storeSubscriptionsCol(subscription.storeId);
    final ref =
        subscription.id.trim().isEmpty ? col.doc() : col.doc(subscription.id);

    final payload = subscription.toMap()
      ..remove('createdAt')
      ..remove('updatedAt')
      ..['createdAt'] = subscription.createdAt ?? FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    return ref.set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> updateStoreSubscriptionStatus({
    required String storeId,
    required String subscriptionId,
    required SubscriptionStatus status,
    bool? cancelAtPeriodEnd,
  }) {
    return _storeSubscriptionsCol(storeId).doc(subscriptionId).set({
      'status': subscriptionStatusWireName(status),
      if (cancelAtPeriodEnd != null) 'cancelAtPeriodEnd': cancelAtPeriodEnd,
      if (status == SubscriptionStatus.canceled)
        'canceledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<StoreEntitlement?> watchStoreEntitlement(String storeId) {
    return _storeEntitlementDoc(storeId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return StoreEntitlement.fromMap(storeId, data);
    });
  }
}
