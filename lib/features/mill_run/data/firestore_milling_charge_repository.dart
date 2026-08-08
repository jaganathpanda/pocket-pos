import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/milling_charge_models.dart';
import '../domain/milling_charge_repository.dart';
import '../domain/milling_config.dart';

class FirestoreMillingChargeRepository implements MillingChargeRepository {
  FirestoreMillingChargeRepository(this._db, this._storeId);

  final FirebaseFirestore _db;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _invoices =>
      storeCollection(_db, _storeId, 'milling_charge_invoices');
  CollectionReference<Map<String, dynamic>> get _payments =>
      storeCollection(_db, _storeId, 'milling_charge_payments');
  CollectionReference<Map<String, dynamic>> get _customers =>
      storeCollection(_db, _storeId, 'customers');
  CollectionReference<Map<String, dynamic>> get _runs =>
      storeCollection(_db, _storeId, 'mill_runs');

  static double _num(dynamic v, [double or = 0]) =>
      (v as num?)?.toDouble() ?? or;

  MillingChargeInvoice _invoiceFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      Map<int, String> partyNames) {
    final d = doc.data()!;
    final partyId = (d['partyId'] as num?)?.toInt() ?? 0;
    return MillingChargeInvoice(
      id: int.parse(doc.id),
      invoiceNo: (d['invoiceNo'] as String?) ?? doc.id,
      invoiceDate:
          (d['invoiceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      partyId: partyId,
      millRunId: (d['millRunId'] as num?)?.toInt() ?? 0,
      chargeBasis: MillingChargeBasis.values.firstWhere(
        (b) => b.name == (d['chargeBasis'] as String?),
        orElse: () => MillingChargeBasis.perInputQuintal,
      ),
      billedQty: _num(d['billedQty']),
      ratePerUnit: _num(d['ratePerUnit']),
      dryingChargePerUnit: _num(d['dryingChargePerUnit']),
      loadingChargePerUnit: _num(d['loadingChargePerUnit']),
      baggingChargePerUnit: _num(d['baggingChargePerUnit']),
      deductionPerUnit: _num(d['deductionPerUnit']),
      grossCharge: _num(d['grossCharge']),
      gstPercent: _num(d['gstPercent']),
      gstAmount: _num(d['gstAmount']),
      tdsPercent: _num(d['tdsPercent']),
      tdsAmount: _num(d['tdsAmount']),
      netPayable: _num(d['netPayable']),
      paidAmount: _num(d['paidAmount']),
      status: MillingChargeStatus.fromString(d['status'] as String?),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lotNumber: d['lotNumber'] as String?,
      note: d['note'] as String?,
      partyName: partyNames[partyId],
    );
  }

  Future<Map<int, String>> _partyNamesById() async {
    final snap = await _customers.get();
    return {
      for (final d in snap.docs)
        int.parse(d.id): (d.data()['name'] as String?) ?? '',
    };
  }

  String _invoiceNo(int id) =>
      'MC-${DateTime.now().year}-${id.toString().substring(id.toString().length > 5 ? id.toString().length - 5 : 0)}';

  Map<String, dynamic> _toMap(MillingChargeInvoice inv) => {
        'invoiceNo': inv.invoiceNo,
        'invoiceDate': Timestamp.fromDate(inv.invoiceDate),
        'partyId': inv.partyId,
        'millRunId': inv.millRunId,
        'chargeBasis': inv.chargeBasis.name,
        'billedQty': inv.billedQty,
        'ratePerUnit': inv.ratePerUnit,
        'dryingChargePerUnit': inv.dryingChargePerUnit,
        'loadingChargePerUnit': inv.loadingChargePerUnit,
        'baggingChargePerUnit': inv.baggingChargePerUnit,
        'deductionPerUnit': inv.deductionPerUnit,
        'grossCharge': inv.grossCharge,
        'gstPercent': inv.gstPercent,
        'gstAmount': inv.gstAmount,
        'tdsPercent': inv.tdsPercent,
        'tdsAmount': inv.tdsAmount,
        'netPayable': inv.netPayable,
        'paidAmount': inv.paidAmount,
        'status': inv.status.name,
        'lotNumber': inv.lotNumber,
        'note': inv.note,
      };

  @override
  Stream<List<MillingChargeInvoice>> watchAll() {
    return _invoices.snapshots().asyncMap((snap) async {
      if (snap.docs.isEmpty) return const <MillingChargeInvoice>[];
      final partyNames = await _partyNamesById();
      final list = snap.docs
          .map((doc) => _invoiceFromDoc(doc, partyNames))
          .toList();
      list.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
      return list;
    });
  }

  @override
  Future<int> createInvoice({
    required int partyId,
    required int millRunId,
    required MillingChargeBasis chargeBasis,
    required double billedQty,
    required double ratePerUnit,
    required double dryingChargePerUnit,
    required double loadingChargePerUnit,
    required double baggingChargePerUnit,
    required double deductionPerUnit,
    required double gstPercent,
    required double tdsPercent,
    required DateTime invoiceDate,
    String? lotNumber,
    String? note,
  }) async {
    final id = newIntId();
    final inv = MillingChargeInvoice.calculate(
      id: id,
      invoiceNo: _invoiceNo(id),
      invoiceDate: invoiceDate,
      partyId: partyId,
      millRunId: millRunId,
      chargeBasis: chargeBasis,
      billedQty: billedQty,
      ratePerUnit: ratePerUnit,
      dryingChargePerUnit: dryingChargePerUnit,
      loadingChargePerUnit: loadingChargePerUnit,
      baggingChargePerUnit: baggingChargePerUnit,
      deductionPerUnit: deductionPerUnit,
      gstPercent: gstPercent,
      tdsPercent: tdsPercent,
      lotNumber: lotNumber,
      note: note,
    );
    await _invoices.doc('$id').set({
      ..._toMap(inv),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> updateInvoice({
    required int id,
    required int partyId,
    required int millRunId,
    required MillingChargeBasis chargeBasis,
    required double billedQty,
    required double ratePerUnit,
    required double dryingChargePerUnit,
    required double loadingChargePerUnit,
    required double baggingChargePerUnit,
    required double deductionPerUnit,
    required double gstPercent,
    required double tdsPercent,
    required DateTime invoiceDate,
    String? lotNumber,
    String? note,
  }) async {
    final inv = MillingChargeInvoice.calculate(
      id: id,
      invoiceNo: _invoiceNo(id),
      invoiceDate: invoiceDate,
      partyId: partyId,
      millRunId: millRunId,
      chargeBasis: chargeBasis,
      billedQty: billedQty,
      ratePerUnit: ratePerUnit,
      dryingChargePerUnit: dryingChargePerUnit,
      loadingChargePerUnit: loadingChargePerUnit,
      baggingChargePerUnit: baggingChargePerUnit,
      deductionPerUnit: deductionPerUnit,
      gstPercent: gstPercent,
      tdsPercent: tdsPercent,
      lotNumber: lotNumber,
      note: note,
    );
    await _invoices.doc('$id').update(_toMap(inv));
  }

  @override
  Future<void> issueInvoice(int id) =>
      _invoices.doc('$id').update({'status': MillingChargeStatus.issued.name});

  @override
  Future<void> recordPayment({
    required int invoiceId,
    required double amount,
    required String method,
    String? referenceNo,
  }) async {
    final invDoc = await _invoices.doc('$invoiceId').get();
    if (!invDoc.exists) return;
    final currentPaid = _num(invDoc.data()!['paidAmount']);
    final netPayable = _num(invDoc.data()!['netPayable']);
    final newPaid =
        (currentPaid + amount).clamp(0, netPayable).toDouble();
    final newStatus = newPaid >= netPayable
        ? MillingChargeStatus.paid.name
        : MillingChargeStatus.partiallyPaid.name;

    final payId = newIntId();
    final batch = _db.batch();
    batch.set(_payments.doc('$payId'), {
      'invoiceId': invoiceId,
      'amount': amount,
      'method': method,
      'referenceNo': referenceNo,
      'paidAt': FieldValue.serverTimestamp(),
    });
    batch.update(_invoices.doc('$invoiceId'), {
      'paidAmount': newPaid,
      'status': newStatus,
    });
    await batch.commit();
  }

  @override
  Future<List<MillingChargePayment>> getPayments(int invoiceId) async {
    final snap = await _payments
        .where('invoiceId', isEqualTo: invoiceId)
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return MillingChargePayment(
        id: int.parse(doc.id),
        invoiceId: invoiceId,
        amount: _num(d['amount']),
        method: (d['method'] as String?) ?? 'cash',
        paidAt: (d['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        referenceNo: d['referenceNo'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> cancelInvoice(int id) =>
      _invoices.doc('$id').update({'status': MillingChargeStatus.cancelled.name});

  @override
  Future<void> deleteInvoice(int id) => _invoices.doc('$id').delete();
}
