import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/customer_repository.dart';

/// Store-scoped Firestore implementation of [CustomerRepository].
class FirestoreCustomerRepository implements CustomerRepository {
  FirestoreCustomerRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'customers');
  CollectionReference<Map<String, dynamic>> get _sales =>
      storeCollection(_db, _storeId, 'sales');
  CollectionReference<Map<String, dynamic>> get _saleItems =>
      storeCollection(_db, _storeId, 'sale_items');

  @override
  Stream<List<Customer>> watchAll() {
    return _col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Future<Customer?> findByMobile(String mobile) async {
    final m = mobile.trim();
    if (m.isEmpty) return null;
    final snap = await _col.where('mobile', isEqualTo: m).limit(1).get();
    return snap.docs.isEmpty ? null : _fromDoc(snap.docs.first);
  }

  @override
  Future<Customer?> getById(int id) async {
    final doc = await _col.doc('$id').get();
    final d = doc.data();
    if (!doc.exists || d == null) return null;
    return Customer(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      mobile: d['mobile'] as String?,
      address: d['address'] as String?,
      loyaltyPoints: (d['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<int> createOrUpdate({
    required String mobile,
    required String name,
    String? address,
  }) async {
    final existing = await findByMobile(mobile);
    if (existing != null) {
      await _col.doc('${existing.id}').set({
        'name': name,
        'address': address,
      }, SetOptions(merge: true));
      return existing.id;
    }
    final id = newIntId();
    await _col.doc('$id').set({
      'name': name,
      'mobile': mobile.trim(),
      'address': address,
      'loyaltyPoints': 0,
    });
    return id;
  }

  @override
  Future<List<Customer>> searchByNameOrMobile(String query) async {
    final q = query.trim().toLowerCase();
    final snap = await _col.get();
    final all = snap.docs.map(_fromDoc);
    if (q.isEmpty) return all.take(30).toList();
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.mobile?.toLowerCase().contains(q) ?? false))
        .take(30)
        .toList();
  }

  @override
  Future<List<({Sale sale, int itemCount})>> getCustomerOrders(int customerId) async {
    final snap = await _sales.where('customerId', isEqualTo: customerId).get();
    final sales = snap.docs.map(saleFromDoc).toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    final result = <({Sale sale, int itemCount})>[];
    for (final sale in sales) {
      final items = await _saleItems.where('saleId', isEqualTo: sale.id).get();
      result.add((sale: sale, itemCount: items.docs.length));
    }
    return result;
  }

  @override
  Future<({Sale sale, List<SaleItem> items})> getOrderDetails(int saleId) async {
    final saleDoc = await _sales.doc('$saleId').get();
    final itemsSnap = await _saleItems.where('saleId', isEqualTo: saleId).get();
    return (
      sale: saleFromDoc(saleDoc),
      items: itemsSnap.docs.map(saleItemFromDoc).toList(),
    );
  }

  Customer _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Customer(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      mobile: d['mobile'] as String?,
      address: d['address'] as String?,
      loyaltyPoints: (d['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }
}
