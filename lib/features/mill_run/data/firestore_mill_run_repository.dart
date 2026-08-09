import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../../inventory/data/firestore_inventory_repository.dart';
import '../domain/mill_run_models.dart';
import '../domain/mill_run_repository.dart';

class FirestoreMillRunRepository implements MillRunRepository {
  FirestoreMillRunRepository(this._db, this._storeId)
      : _inventory = FirestoreInventoryRepository(_db, _storeId);

  final FirebaseFirestore _db;
  final String _storeId;
  final FirestoreInventoryRepository _inventory;

  CollectionReference<Map<String, dynamic>> get _runs =>
      storeCollection(_db, _storeId, 'mill_runs');
  CollectionReference<Map<String, dynamic>> get _outputs =>
      storeCollection(_db, _storeId, 'mill_run_outputs');
  CollectionReference<Map<String, dynamic>> get _products =>
      storeCollection(_db, _storeId, 'products');
  CollectionReference<Map<String, dynamic>> get _warehouses =>
      storeCollection(_db, _storeId, 'warehouses');

  // ── helpers ──────────────────────────────────────────────────────────────

  static double _num(dynamic v, [double or = 0]) =>
      (v as num?)?.toDouble() ?? or;

  MillRun _runFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MillRun(
      id: int.parse(doc.id),
      runDate: (d['runDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      warehouseId: (d['warehouseId'] as num?)?.toInt() ?? 0,
      paddyProductId: (d['paddyProductId'] as num?)?.toInt() ?? 0,
      paddyConsumedKg: _num(d['paddyConsumedKg']),
      status: MillRunStatus.fromString(d['status'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lotNumber: d['lotNumber'] as String?,
      note: d['note'] as String?,
    );
  }

  MillRunOutput _outputFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MillRunOutput(
      id: int.parse(doc.id),
      millRunId: (d['millRunId'] as num?)?.toInt() ?? 0,
      productId: (d['productId'] as num?)?.toInt() ?? 0,
      quantityKg: _num(d['quantityKg']),
      grade: d['grade'] as String?,
    );
  }

  Future<Map<int, String>> _productNamesById() async {
    final snap = await _products.get();
    return {
      for (final d in snap.docs)
        int.parse(d.id): (d.data()['name'] as String?) ?? '',
    };
  }

  Future<Map<int, String>> _warehouseNamesById() async {
    final snap = await _warehouses.get();
    return {
      for (final d in snap.docs)
        int.parse(d.id): (d.data()['name'] as String?) ?? '',
    };
  }

  // ── repository impl ───────────────────────────────────────────────────────

  @override
  Stream<List<MillRunWithOutputs>> watchAll() {
    return _runs.snapshots().asyncMap((snap) async {
      if (snap.docs.isEmpty) return const <MillRunWithOutputs>[];

      final productNames = await _productNamesById();
      final warehouseNames = await _warehouseNamesById();

      final outputsSnap = await _outputs.get();
      final outputsByRunId = <int, List<MillRunOutput>>{};
      for (final doc in outputsSnap.docs) {
        final o = _outputFromDoc(doc);
        outputsByRunId.putIfAbsent(o.millRunId, () => []).add(o);
      }

      final result = snap.docs.map((doc) {
        final run = _runFromDoc(doc);
        final outputs = outputsByRunId[run.id] ?? [];
        return MillRunWithOutputs(
          run: run,
          outputs: outputs,
          warehouseName: warehouseNames[run.warehouseId],
          paddyProductName: productNames[run.paddyProductId],
          outputProducts: {
            for (final o in outputs)
              if (productNames.containsKey(o.productId))
                o.productId: productNames[o.productId]!,
          },
        );
      }).toList();

      result.sort((a, b) => b.run.runDate.compareTo(a.run.runDate));
      return result;
    });
  }

  @override
  Future<int> createRun({
    required int warehouseId,
    required int paddyProductId,
    required double paddyConsumedKg,
    required DateTime runDate,
    String? lotNumber,
    String? note,
  }) async {
    final id = newIntId();
    await _runs.doc('$id').set({
      'warehouseId': warehouseId,
      'paddyProductId': paddyProductId,
      'paddyConsumedKg': paddyConsumedKg,
      'runDate': Timestamp.fromDate(runDate),
      'lotNumber': lotNumber,
      'note': note,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> updateRun({
    required int id,
    required int warehouseId,
    required int paddyProductId,
    required double paddyConsumedKg,
    required DateTime runDate,
    String? lotNumber,
    String? note,
  }) =>
      _runs.doc('$id').update({
        'warehouseId': warehouseId,
        'paddyProductId': paddyProductId,
        'paddyConsumedKg': paddyConsumedKg,
        'runDate': Timestamp.fromDate(runDate),
        'lotNumber': lotNumber,
        'note': note,
      });

  @override
  Future<void> addOutput({
    required int millRunId,
    required int productId,
    required double quantityKg,
    String? grade,
  }) async {
    final id = newIntId();
    await _outputs.doc('$id').set({
      'millRunId': millRunId,
      'productId': productId,
      'quantityKg': quantityKg,
      'grade': grade,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeOutput(int outputId) =>
      _outputs.doc('$outputId').delete();

  @override
  Future<void> complete(int millRunId) async {
    final runDoc = await _runs.doc('$millRunId').get();
    if (!runDoc.exists) throw Exception('Mill run not found.');
    final run = _runFromDoc(runDoc);
    if (run.status != MillRunStatus.draft) {
      throw Exception('Only draft runs can be completed.');
    }

    final outputsSnap =
        await _outputs.where('millRunId', isEqualTo: millRunId).get();
    if (outputsSnap.docs.isEmpty) {
      throw Exception('Add at least one output before completing the run.');
    }

    // Deduct paddy from inventory.
    await _inventory.stockOut(
      productId: run.paddyProductId,
      warehouseId: run.warehouseId,
      quantity: run.paddyConsumedKg,
      note: 'Mill run #$millRunId',
    );

    // Stock-in each output product.
    for (final doc in outputsSnap.docs) {
      final o = _outputFromDoc(doc);
      await _inventory.stockIn(
        productId: o.productId,
        warehouseId: run.warehouseId,
        quantity: o.quantityKg,
        note: 'Mill run #$millRunId output',
      );
    }

    await _runs.doc('$millRunId').update({'status': 'completed'});
  }

  @override
  Future<void> cancel(int millRunId) =>
      _runs.doc('$millRunId').update({'status': 'cancelled'});

  @override
  Future<void> deleteRun(int millRunId) async {
    final outputsSnap =
        await _outputs.where('millRunId', isEqualTo: millRunId).get();
    final batch = _db.batch();
    for (final doc in outputsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_runs.doc('$millRunId'));
    await batch.commit();
  }
}
