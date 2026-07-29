import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/database/app_database.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/category_repository.dart';

/// Store-scoped Firestore implementation of [CategoryRepository].
/// Returns the existing Drift [Category] model so the UI is unchanged.
class FirestoreCategoryRepository implements CategoryRepository {
  FirestoreCategoryRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'categories');

  @override
  Stream<List<Category>> watchAll() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Future<void> add(String name, {int? parentCategoryId}) {
    final id = newIntId();
    return _col.doc('$id').set({
      'name': name,
      'parentCategoryId': parentCategoryId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateName(int id, String name) =>
      _col.doc('$id').set({'name': name}, SetOptions(merge: true));

  @override
  Future<void> delete(int id) => _col.doc('$id').delete();

  Category _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Category(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      parentCategoryId: (d['parentCategoryId'] as num?)?.toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
