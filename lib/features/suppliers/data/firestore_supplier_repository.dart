import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/supplier_repository.dart';

/// Store-scoped Firestore implementation of [SupplierRepository].
class FirestoreSupplierRepository implements SupplierRepository {
  FirestoreSupplierRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'suppliers');

  @override
  Stream<List<Supplier>> watchAll() {
    return _col.where('isActive', isEqualTo: true).snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Future<List<Supplier>> search(String query) async {
    final snap = await _col.where('isActive', isEqualTo: true).get();
    final q = query.trim().toLowerCase();
    final all = snap.docs.map(_fromDoc);
    if (q.isEmpty) return all.toList();
    return all
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            (s.mobile?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Future<Supplier> getById(int id) async {
    final doc = await _col.doc('$id').get();
    return _fromSnap(doc);
  }

  @override
  Future<int> add({
    required String name,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
  }) async {
    final id = newIntId();
    await _col.doc('$id').set({
      'name': name.trim(),
      'mobile': mobile,
      'gstNumber': gstNumber,
      'email': email,
      'address': address,
      'contactPerson': contactPerson,
      'outstandingBalance': 0.0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> update({
    required int id,
    required String name,
    String? mobile,
    String? gstNumber,
    String? email,
    String? address,
    String? contactPerson,
  }) {
    return _col.doc('$id').set({
      'name': name.trim(),
      'mobile': mobile,
      'gstNumber': gstNumber,
      'email': email,
      'address': address,
      'contactPerson': contactPerson,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete(int id) =>
      _col.doc('$id').set({'isActive': false}, SetOptions(merge: true));

  Supplier _fromSnap(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Supplier(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      mobile: d['mobile'] as String?,
      gstNumber: d['gstNumber'] as String?,
      email: d['email'] as String?,
      address: d['address'] as String?,
      contactPerson: d['contactPerson'] as String?,
      outstandingBalance: (d['outstandingBalance'] as num?)?.toDouble() ?? 0,
      isActive: (d['isActive'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Supplier _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => _fromSnap(doc);
}
