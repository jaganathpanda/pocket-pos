import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/store_scope.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../domain/expense_item.dart';

class ExpenseRepository {
  ExpenseRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String storeId) =>
      storeCollection(_db, storeId, 'expenses');

  Stream<List<ExpenseItem>> watch(String storeId) {
    return _col(storeId)
        .orderBy('spentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<void> add(
    String storeId, {
    required String category,
    required double amount,
    required DateTime spentAt,
    String? note,
  }) {
    return _col(storeId).add({
      'category': category,
      'amount': amount,
      'note': note,
      'spentAt': Timestamp.fromDate(spentAt),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String storeId, String id) => _col(storeId).doc(id).delete();

  ExpenseItem _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return ExpenseItem(
      id: doc.id,
      category: (d['category'] as String?) ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      note: d['note'] as String?,
      spentAt: (d['spentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(firestoreProvider));
});

/// Live expenses for the currently signed-in store (empty when logged out).
final storeExpensesProvider = StreamProvider<List<ExpenseItem>>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(const <ExpenseItem>[]);
  return ref.watch(expenseRepositoryProvider).watch(storeId);
});
