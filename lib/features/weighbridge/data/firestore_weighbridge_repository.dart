import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocket_pos/features/weighbridge/data/weighbridge_repository.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';

import '../domain/vehicle_entry.dart';

class FirestoreWeighbridgeRepository implements WeighbridgeRepository {
  final FirebaseFirestore _db;
  final String _storeId;

  FirestoreWeighbridgeRepository(this._db, this._storeId);

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'vehicle_entries');

  double _netFor(VehicleEntryCompanion data) {
    if ((data.weighMode ?? 'weighbridge') == 'manual') {
      return (data.manualWeights ?? const [])
          .fold<double>(0, (s, l) => s + l.weight);
    }
    return data.netWeight ??
        ((data.firstWeight ?? 0) - (data.secondWeight ?? 0));
  }

  @override
  Stream<List<VehicleEntry>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? vehicleNo,
    String? partyName,
  }) {
    var query =
        _col.orderBy('date', descending: true) as Query<Map<String, dynamic>>;
    if (fromDate != null)
      query = query.where('date', isGreaterThanOrEqualTo: fromDate);
    if (toDate != null)
      query = query.where('date', isLessThanOrEqualTo: toDate);
    // Firestore doesn't support substring search directly; we'll filter client-side for vehicle/party
    return query.snapshots().asyncMap((snap) async {
      final entries = <VehicleEntry>[];
      for (final doc in snap.docs) {
        final entry = _fromDoc(doc);
        if (vehicleNo != null &&
            vehicleNo.isNotEmpty &&
            !entry.vehicleNo.toLowerCase().contains(vehicleNo.toLowerCase()))
          continue;
        if (partyName != null &&
            partyName.isNotEmpty &&
            !entry.partyName.toLowerCase().contains(partyName.toLowerCase()))
          continue;
        entries.add(entry);
      }
      return entries;
    });
  }

  @override
  Future<VehicleEntry?> getEntry(int id) async {
    final doc = await _col.doc('$id').get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<int> createEntry(VehicleEntryCompanion data) async {
    final id = newIntId();
    final netWeight = _netFor(data);
    await _col.doc('$id').set({
      'date': data.date,
      'slipNo': data.slipNo,
      'voucherNo': data.voucherNo,
      'vehicleNo': data.vehicleNo,
      'rstManual': data.rstManual,
      'partyName': data.partyName,
      'partyId': data.partyId,
      'productId': data.productId,
      'firstWeight': data.firstWeight,
      'firstWeightTime': data.firstWeightTime,
      'secondWeight': data.secondWeight,
      'secondWeightTime': data.secondWeightTime,
      'netWeight': netWeight,
      'entryType': data.entryType ?? 'inward',
      'weighMode': data.weighMode ?? 'weighbridge',
      'manualWeights':
          (data.manualWeights ?? const []).map((l) => l.toMap()).toList(),
      'bags': data.bags,
      'lotNumber': data.lotNumber,
      'complete': data.complete ?? false,
      'completeCode': data.completeCode,
      'completeDate': data.completeDate,
      'remark': data.remark,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> updateEntry(VehicleEntryCompanion data) async {
    if (data.id == null) throw Exception('ID required for update');
    final netWeight = _netFor(data);
    await _col.doc('${data.id}').set({
      'date': data.date,
      'slipNo': data.slipNo,
      'voucherNo': data.voucherNo,
      'vehicleNo': data.vehicleNo,
      'rstManual': data.rstManual,
      'partyName': data.partyName,
      'partyId': data.partyId,
      'productId': data.productId,
      'firstWeight': data.firstWeight,
      'firstWeightTime': data.firstWeightTime,
      'secondWeight': data.secondWeight,
      'secondWeightTime': data.secondWeightTime,
      'netWeight': netWeight,
      'entryType': data.entryType ?? 'inward',
      'weighMode': data.weighMode ?? 'weighbridge',
      'manualWeights':
          (data.manualWeights ?? const []).map((l) => l.toMap()).toList(),
      'bags': data.bags,
      'lotNumber': data.lotNumber,
      'complete': data.complete ?? false,
      'completeCode': data.completeCode,
      'completeDate': data.completeDate,
      'remark': data.remark,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteEntry(int id) async {
    await _col.doc('$id').delete();
  }

  @override
  Future<void> markComplete(int id, {String? completeCode}) async {
    final now = DateTime.now();
    final code = completeCode ??
        'GEN${now.millisecondsSinceEpoch.toString().substring(0, 6)}';
    await _col.doc('$id').set({
      'complete': true,
      'completeCode': code,
      'completeDate': now,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  VehicleEntry _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    double num_(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return VehicleEntry(
      id: int.tryParse(doc.id) ?? 0,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      slipNo: d['slipNo'] as String? ?? '',
      voucherNo: d['voucherNo'] as String?,
      vehicleNo: d['vehicleNo'] as String? ?? '',
      rstManual: d['rstManual'] as String?,
      partyName: d['partyName'] as String? ?? '',
      partyId: (d['partyId'] as num?)?.toInt(),
      productId: (d['productId'] as num?)?.toInt() ?? 0,
      firstWeight: num_(d['firstWeight']),
      firstWeightTime: (d['firstWeightTime'] as Timestamp?)?.toDate(),
      secondWeight: num_(d['secondWeight']),
      secondWeightTime: (d['secondWeightTime'] as Timestamp?)?.toDate(),
      netWeight: num_(d['netWeight']),
      bags: (d['bags'] as num?)?.toInt(),
      lotNumber: d['lotNumber'] as String?,
      complete: (d['complete'] as bool?) ?? false,
      completeCode: d['completeCode'] as String?,
      completeDate: (d['completeDate'] as Timestamp?)?.toDate(),
      remark: d['remark'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      entryType: d['entryType'] as String? ?? 'inward',
      weighMode: d['weighMode'] as String? ?? 'weighbridge',
      manualWeights: (d['manualWeights'] as List?)
              ?.map((e) => ManualWeightLine.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
