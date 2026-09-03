import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../../inventory/data/firestore_inventory_repository.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../domain/paddy_procurement.dart';
import '../domain/paddy_procurement_repository.dart';

class FirestorePaddyProcurementRepository
    implements PaddyProcurementRepository {
  final FirebaseFirestore _db;
  final String _storeId;
  late final InventoryRepository _inventory;

  FirestorePaddyProcurementRepository(this._db, this._storeId) {
    _inventory = FirestoreInventoryRepository(_db, _storeId);
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      storeCollection(_db, _storeId, 'paddy_procurement');

  @override
  Stream<List<PaddyProcurement>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? partyName,
    String? procurementType,
  }) {
    var query =
        _col.orderBy('date', descending: true) as Query<Map<String, dynamic>>;

    if (fromDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: fromDate);
    }
    if (toDate != null) {
      query = query.where('date', isLessThanOrEqualTo: toDate);
    }
    if (procurementType != null && procurementType.isNotEmpty) {
      query = query.where('procurementType', isEqualTo: procurementType);
    }

    return query.snapshots().asyncMap((snap) async {
      final entries = <PaddyProcurement>[];
      for (final doc in snap.docs) {
        final entry = _fromDoc(doc);
        if (partyName != null &&
            partyName.isNotEmpty &&
            !entry.partyName.toLowerCase().contains(partyName.toLowerCase())) {
          continue;
        }
        entries.add(entry);
      }
      return entries;
    });
  }

  @override
  Future<PaddyProcurement?> getProcurement(int id) async {
    final doc = await _col.doc('$id').get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<PaddyProcurement?> findByVehicleEntryId(int vehicleEntryId) async {
    final snap = await _col
        .where('vehicleEntryId', isEqualTo: vehicleEntryId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _fromDoc(snap.docs.first);
  }

  @override
  Future<int> createProcurement(PaddyProcurementCompanion data) async {
    final id = newIntId();
    final totalBags = (data.juteBags ?? 0) + (data.plasticBags ?? 0);

    await _col.doc('$id').set({
      'date': data.date,
      'slipNo': data.slipNo,
      'voucherNo': data.voucherNo,
      'rstManual': data.rstManual,
      'area': data.area,
      'vType': data.vType ?? 'BILL',
      'partyName': data.partyName,
      'partyId': data.partyId,
      'truckNo': data.truckNo,
      'emptyWeight': data.emptyWeight,
      'marketType': data.marketType ?? 'FT',
      'grossWeight': data.grossWeight,
      'tareWeight': data.tareWeight,
      'juteBags': data.juteBags ?? 0,
      'plasticBags': data.plasticBags ?? 0,
      'totalBags': totalBags,
      'avgBagWeight': data.netWeight != null && totalBags > 0
          ? data.netWeight! / totalBags
          : 0,
      'gnyWtLess': data.gnyWtLess ?? false,
      'bagReturn': data.bagReturn ?? false,
      'otherCut': data.otherCut ?? 0,
      'dustCut': data.dustCut,
      'polCut': data.polCut,
      'qualityGrade': data.qualityGrade,
      'unloadTime': data.unloadTime ?? 3.00,
      'eBag': data.eBag ?? 0.700,
      'ePkt': data.ePkt ?? 0.100,
      'netWeight': data.netWeight,
      'rateCalculation': data.rateCalculation ?? 'Qntl',
      'kgPerBag': data.kgPerBag ?? 75,
      'productId': data.productId,
      'productName': data.productName,
      'quantityNew': data.quantityNew ?? 'N',
      'quantityQntl': data.quantityQntl,
      'ratePerQntl': data.ratePerQntl,
      'totalAmount': (data.quantityQntl ?? 0) * (data.ratePerQntl ?? 0),
      'avgRate': data.avgRate,
      'avgAmount': data.avgAmount,
      'qrtCutAmt': data.qrtCutAmt,
      'paddyAmt': data.paddyAmt,
      'qualityCuts': data.qualityCuts?.map((c) => c.toMap()).toList() ?? [],
      'totalCutKg': data.totalCutKg,
      'finalWeight': data.finalWeight,
      'gunnyTransactions':
          data.gunnyTransactions?.map((g) => g.toMap()).toList() ?? [],
      'deliveryType': data.deliveryType ?? 'MD',
      'truckRentType': data.truckRentType ?? 'Qntl',
      'truckRent': data.truckRent ?? 0,
      'truckRentPaid': data.truckRentPaid ?? 0,
      'otherAmount': data.otherAmount ?? 0,
      'transportType': data.transportType ?? 'Direct',
      'truckAccount': data.truckAccount ?? 'none',
      'freightAmount': data.freightAmount ?? 0,
      'procurementType': data.procurementType ?? 'local',
      'mandiInvoiceNo': data.mandiInvoiceNo,
      'tenderNumber': data.tenderNumber,
      'commissionAgentId': data.commissionAgentId,
      'warehouseId': data.warehouseId,
      'warehouseAllocations':
          (data.warehouseAllocations ?? const []).map((a) => a.toMap()).toList(),
      'vehicleEntryId': data.vehicleEntryId,
      'weighMode': data.weighMode ?? 'weighbridge',
      'remainingStock': data.netWeight ?? 0,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  @override
  Future<void> updateProcurement(PaddyProcurementCompanion data) async {
    if (data.id == null) throw Exception('ID required for update');
    final totalBags = (data.juteBags ?? 0) + (data.plasticBags ?? 0);

    await _col.doc('${data.id}').set({
      'date': data.date,
      'slipNo': data.slipNo,
      'voucherNo': data.voucherNo,
      'rstManual': data.rstManual,
      'area': data.area,
      'vType': data.vType ?? 'BILL',
      'partyName': data.partyName,
      'partyId': data.partyId,
      'truckNo': data.truckNo,
      'emptyWeight': data.emptyWeight,
      'marketType': data.marketType ?? 'FT',
      'grossWeight': data.grossWeight,
      'tareWeight': data.tareWeight,
      'juteBags': data.juteBags ?? 0,
      'plasticBags': data.plasticBags ?? 0,
      'totalBags': totalBags,
      'avgBagWeight': data.netWeight != null && totalBags > 0
          ? data.netWeight! / totalBags
          : 0,
      'gnyWtLess': data.gnyWtLess ?? false,
      'bagReturn': data.bagReturn ?? false,
      'otherCut': data.otherCut ?? 0,
      'dustCut': data.dustCut,
      'polCut': data.polCut,
      'qualityGrade': data.qualityGrade,
      'unloadTime': data.unloadTime ?? 3.00,
      'eBag': data.eBag ?? 0.700,
      'ePkt': data.ePkt ?? 0.100,
      'netWeight': data.netWeight,
      'rateCalculation': data.rateCalculation ?? 'Qntl',
      'kgPerBag': data.kgPerBag ?? 75,
      'productId': data.productId,
      'productName': data.productName,
      'quantityNew': data.quantityNew ?? 'N',
      'quantityQntl': data.quantityQntl,
      'ratePerQntl': data.ratePerQntl,
      'totalAmount': (data.quantityQntl ?? 0) * (data.ratePerQntl ?? 0),
      'avgRate': data.avgRate,
      'avgAmount': data.avgAmount,
      'qrtCutAmt': data.qrtCutAmt,
      'paddyAmt': data.paddyAmt,
      'qualityCuts': data.qualityCuts?.map((c) => c.toMap()).toList() ?? [],
      'totalCutKg': data.totalCutKg,
      'finalWeight': data.finalWeight,
      'gunnyTransactions':
          data.gunnyTransactions?.map((g) => g.toMap()).toList() ?? [],
      'deliveryType': data.deliveryType ?? 'MD',
      'truckRentType': data.truckRentType ?? 'Qntl',
      'truckRent': data.truckRent ?? 0,
      'truckRentPaid': data.truckRentPaid ?? 0,
      'otherAmount': data.otherAmount ?? 0,
      'transportType': data.transportType ?? 'Direct',
      'truckAccount': data.truckAccount ?? 'none',
      'freightAmount': data.freightAmount ?? 0,
      'procurementType': data.procurementType ?? 'local',
      'mandiInvoiceNo': data.mandiInvoiceNo,
      'tenderNumber': data.tenderNumber,
      'commissionAgentId': data.commissionAgentId,
      'warehouseId': data.warehouseId,
      'warehouseAllocations':
          (data.warehouseAllocations ?? const []).map((a) => a.toMap()).toList(),
      'vehicleEntryId': data.vehicleEntryId,
      'weighMode': data.weighMode ?? 'weighbridge',
      'status': data.status ?? 'draft',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteProcurement(int id) async {
    await _col.doc('$id').delete();
  }

  @override
  Future<void> completeProcurement(int id) async {
    final doc = await _col.doc('$id').get();
    if (!doc.exists) throw Exception('Procurement not found');

    final data = doc.data()!;

    // Calculate quality deductions
    final qualityCuts = (data['qualityCuts'] as List?)
            ?.map((e) => QualityCut.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];
    final totalDeduction = qualityCuts.fold<double>(
      0,
      (sum, cut) => sum + cut.cutQuantityKg,
    );
    final actualQty = ((data['netWeight'] as num?)?.toDouble() ?? 0) -
        totalDeduction -
        ((data['otherCut'] as num?)?.toDouble() ?? 0);

    final ratePerQntl = (data['ratePerQntl'] as num?)?.toDouble() ?? 0;
    final productId = data['productId'] as int;
    final note = 'Paddy Procurement #$id - ${data['slipNo']}';

    final allocations = (data['warehouseAllocations'] as List?)
            ?.map((e) => WarehouseAllocation.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const <WarehouseAllocation>[];

    if (allocations.isNotEmpty) {
      // Split the post-cut quantity across the chosen godowns, in proportion to
      // each godown's allocated share (so quality cuts are shared fairly).
      final totalAlloc = allocations.fold<double>(0, (s, a) => s + a.quantityKg);
      for (final a in allocations) {
        final share = totalAlloc > 0
            ? a.quantityKg / totalAlloc
            : 1 / allocations.length;
        final qtyQntl = (actualQty * share) / 100;
        if (qtyQntl <= 0) continue;
        await _inventory.stockIn(
          productId: productId,
          warehouseId: a.warehouseId,
          quantity: qtyQntl,
          unitCost: ratePerQntl,
          note: note,
        );
      }
    } else {
      // Single-warehouse: stock everything into the chosen (or default) godown.
      await _inventory.stockIn(
        productId: productId,
        warehouseId: data['warehouseId'] as int? ?? 1,
        quantity: actualQty / 100,
        unitCost: ratePerQntl,
        note: note,
      );
    }

    // Update status
    await _col.doc('$id').set({
      'status': 'completed',
      'remainingStock': actualQty,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> cancelProcurement(int id) async {
    await _col.doc('$id').set({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<double> getRemainingStock(int id) async {
    final doc = await _col.doc('$id').get();
    if (!doc.exists) return 0;
    final data = doc.data()!;
    return ((data['remainingStock'] as num?)?.toDouble() ?? 0);
  }

  @override
  Future<void> deductStock(int id, double quantity) async {
    final current = await getRemainingStock(id);
    final newStock = (current - quantity).clamp(0, double.infinity);
    await _col.doc('$id').set({
      'remainingStock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  PaddyProcurement _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    double num_(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int int_(dynamic v) => (v as num?)?.toInt() ?? 0;

    final qualityCuts = (d['qualityCuts'] as List?)
            ?.map((e) => QualityCut.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final gunnyTransactions = (d['gunnyTransactions'] as List?)
            ?.map((e) => GunnyTransaction.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PaddyProcurement(
      id: int.tryParse(doc.id) ?? 0,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      slipNo: d['slipNo'] as String? ?? '',
      voucherNo: d['voucherNo'] as String?,
      rstManual: d['rstManual'] as String?,
      area: d['area'] as String?,
      vType: d['vType'] as String? ?? 'BILL',
      partyName: d['partyName'] as String? ?? '',
      partyId: (d['partyId'] as num?)?.toInt(),
      truckNo: d['truckNo'] as String?,
      emptyWeight: num_(d['emptyWeight']),
      marketType: d['marketType'] as String? ?? 'FT',
      grossWeight: num_(d['grossWeight']),
      tareWeight: num_(d['tareWeight']),
      juteBags: int_(d['juteBags']),
      plasticBags: int_(d['plasticBags']),
      totalBags: int_(d['totalBags']),
      gnyWtLess: (d['gnyWtLess'] as bool?) ?? false,
      bagReturn: (d['bagReturn'] as bool?) ?? false,
      otherCut: num_(d['otherCut']),
      dustCut: (d['dustCut'] as num?)?.toDouble(),
      polCut: (d['polCut'] as num?)?.toDouble(),
      qualityGrade: d['qualityGrade'] as String?,
      unloadTime: num_(d['unloadTime']),
      eBag: num_(d['eBag']),
      ePkt: num_(d['ePkt']),
      netWeight: num_(d['netWeight']),
      avgBagWeight: num_(d['avgBagWeight']),
      rateCalculation: d['rateCalculation'] as String? ?? 'Qntl',
      kgPerBag: num_(d['kgPerBag']),
      productId: int_(d['productId']),
      productName: d['productName'] as String? ?? '',
      quantityNew: d['quantityNew'] as String? ?? 'N',
      quantityQntl: num_(d['quantityQntl']),
      ratePerQntl: num_(d['ratePerQntl']),
      totalAmount: num_(d['totalAmount']),
      avgRate: num_(d['avgRate']),
      avgAmount: num_(d['avgAmount']),
      qrtCutAmt: num_(d['qrtCutAmt']),
      paddyAmt: num_(d['paddyAmt']),
      qualityCuts: qualityCuts,
      totalCutKg: num_(d['totalCutKg']),
      finalWeight: num_(d['finalWeight']),
      gunnyTransactions: gunnyTransactions,
      deliveryType: d['deliveryType'] as String?,
      truckRentType: d['truckRentType'] as String?,
      truckRent: num_(d['truckRent']),
      truckRentPaid: num_(d['truckRentPaid']),
      otherAmount: num_(d['otherAmount']),
      transportType: d['transportType'] as String?,
      truckAccount: d['truckAccount'] as String?,
      freightAmount: num_(d['freightAmount']),
      procurementType: d['procurementType'] as String? ?? 'local',
      mandiInvoiceNo: d['mandiInvoiceNo'] as String?,
      tenderNumber: d['tenderNumber'] as String?,
      commissionAgentId: (d['commissionAgentId'] as num?)?.toInt(),
      warehouseId: (d['warehouseId'] as num?)?.toInt(),
      warehouseAllocations: (d['warehouseAllocations'] as List?)
              ?.map((e) =>
                  WarehouseAllocation.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      vehicleEntryId: (d['vehicleEntryId'] as num?)?.toInt(),
      weighMode: d['weighMode'] as String? ?? 'weighbridge',
      remainingStock: num_(d['remainingStock']),
      status: d['status'] as String? ?? 'draft',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
