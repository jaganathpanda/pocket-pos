import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../inventory/data/inventory_repository_impl.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../domain/paddy_procurement.dart';
import '../domain/paddy_procurement_repository.dart';

class PaddyProcurementRepositoryImpl implements PaddyProcurementRepository {
  final AppDatabase _db;
  late final InventoryRepository _inventory;

  PaddyProcurementRepositoryImpl(this._db) {
    _inventory = InventoryRepositoryImpl(_db);
  }

  @override
  Stream<List<PaddyProcurement>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? partyName,
    String? procurementType,
  }) {
    final query = _db.select(_db.paddyProcurements)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);

    if (fromDate != null) {
      query.where((t) => t.date.isBiggerOrEqual(fromDate));
    }
    if (toDate != null) {
      query.where((t) => t.date.isSmallerOrEqual(toDate));
    }
    if (procurementType != null && procurementType.isNotEmpty) {
      query.where((t) => t.procurementType.equals(procurementType));
    }

    return query.watch().map((rows) {
      var list = rows.map(_fromRow).toList();
      if (partyName != null && partyName.isNotEmpty) {
        list = list
            .where((p) =>
                p.partyName.toLowerCase().contains(partyName.toLowerCase()))
            .toList();
      }
      return list;
    });
  }

  @override
  Future<PaddyProcurement?> getProcurement(int id) async {
    final row = await (_db.select(_db.paddyProcurements)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _fromRow(row) : null;
  }

  @override
  Future<int> createProcurement(PaddyProcurementCompanion data) async {
    final qualityCutsJson =
        jsonEncode(data.qualityCuts?.map((c) => c.toMap()).toList() ?? []);
    final gunnyJson = jsonEncode(
        data.gunnyTransactions?.map((g) => g.toMap()).toList() ?? []);

    return _db.into(_db.paddyProcurements).insert(
          PaddyProcurementsCompanion.insert(
            date: data.date!,
            slipNo: data.slipNo!,
            voucherNo: Value(data.voucherNo),
            rstManual: Value(data.rstManual),
            area: Value(data.area),
            vType: Value(data.vType ?? 'BILL'),
            partyName: data.partyName!,
            partyId: Value(data.partyId),
            truckNo: Value(data.truckNo),
            emptyWeight: Value(data.emptyWeight),
            marketType: Value(data.marketType ?? 'FT'),
            grossWeight: Value(data.grossWeight),
            tareWeight: Value(data.tareWeight),
            juteBags: Value(data.juteBags ?? 0),
            plasticBags: Value(data.plasticBags ?? 0),
            totalBags: Value((data.juteBags ?? 0) + (data.plasticBags ?? 0)),
            avgBagWeight: Value(data.netWeight != null && data.totalBags! > 0
                ? data.netWeight! / data.totalBags!
                : 0),
            gnyWtLess: Value(data.gnyWtLess ?? false),
            bagReturn: Value(data.bagReturn ?? false),
            otherCut: Value(data.otherCut ?? 0),
            unloadTime: Value(data.unloadTime ?? 3.00),
            eBag: Value(data.eBag ?? 0.700),
            ePkt: Value(data.ePkt ?? 0.100),
            netWeight: data.netWeight!,
            rateCalculation: Value(data.rateCalculation ?? 'Qntl'),
            kgPerBag: Value(data.kgPerBag ?? 75),
            productId: data.productId!,
            productName: data.productName!,
            quantityNew: Value(data.quantityNew ?? 'N'),
            quantityQntl: Value(data.quantityQntl),
            ratePerQntl: Value(data.ratePerQntl),
            totalAmount:
                Value((data.quantityQntl ?? 0) * (data.ratePerQntl ?? 0)),
            avgRate: Value(data.avgRate),
            avgAmount: Value(data.avgAmount),
            qrtCutAmt: Value(data.qrtCutAmt),
            paddyAmt: Value(data.paddyAmt),
            qualityCutsJson: qualityCutsJson,
            totalCutKg: Value(data.totalCutKg),
            finalWeight: Value(data.finalWeight),
            gunnyTransactionsJson: gunnyJson,
            deliveryType: Value(data.deliveryType ?? 'MD'),
            truckRentType: Value(data.truckRentType ?? 'Qntl'),
            truckRent: Value(data.truckRent ?? 0),
            truckRentPaid: Value(data.truckRentPaid ?? 0),
            otherAmount: Value(data.otherAmount ?? 0),
            transportType: Value(data.transportType ?? 'Direct'),
            truckAccount: Value(data.truckAccount ?? 'none'),
            freightAmount: Value(data.freightAmount ?? 0),
            procurementType: Value(data.procurementType ?? 'local'),
            mandiInvoiceNo: Value(data.mandiInvoiceNo),
            tenderNumber: Value(data.tenderNumber),
            commissionAgentId: Value(data.commissionAgentId),
            warehouseId: Value(data.warehouseId),
            remainingStock: Value(data.netWeight ?? 0),
            status: Value(data.status ?? 'draft'),
          ),
        );
  }

  @override
  Future<void> updateProcurement(PaddyProcurementCompanion data) async {
    if (data.id == null) throw Exception('ID required for update');

    final qualityCutsJson =
        jsonEncode(data.qualityCuts?.map((c) => c.toMap()).toList() ?? []);
    final gunnyJson = jsonEncode(
        data.gunnyTransactions?.map((g) => g.toMap()).toList() ?? []);

    await (_db.update(_db.paddyProcurements)
          ..where((t) => t.id.equals(data.id!)))
        .write(
      PaddyProcurementsCompanion(
        date: Value(data.date!),
        slipNo: Value(data.slipNo!),
        voucherNo: Value(data.voucherNo),
        rstManual: Value(data.rstManual),
        area: Value(data.area),
        vType: Value(data.vType ?? 'BILL'),
        partyName: Value(data.partyName!),
        partyId: Value(data.partyId),
        truckNo: Value(data.truckNo),
        emptyWeight: Value(data.emptyWeight),
        marketType: Value(data.marketType ?? 'FT'),
        grossWeight: Value(data.grossWeight),
        tareWeight: Value(data.tareWeight),
        juteBags: Value(data.juteBags ?? 0),
        plasticBags: Value(data.plasticBags ?? 0),
        totalBags: Value((data.juteBags ?? 0) + (data.plasticBags ?? 0)),
        avgBagWeight: Value(data.netWeight != null && data.totalBags! > 0
            ? data.netWeight! / data.totalBags!
            : 0),
        gnyWtLess: Value(data.gnyWtLess ?? false),
        bagReturn: Value(data.bagReturn ?? false),
        otherCut: Value(data.otherCut ?? 0),
        unloadTime: Value(data.unloadTime ?? 3.00),
        eBag: Value(data.eBag ?? 0.700),
        ePkt: Value(data.ePkt ?? 0.100),
        netWeight: Value(data.netWeight!),
        rateCalculation: Value(data.rateCalculation ?? 'Qntl'),
        kgPerBag: Value(data.kgPerBag ?? 75),
        productId: Value(data.productId!),
        productName: Value(data.productName!),
        quantityNew: Value(data.quantityNew ?? 'N'),
        quantityQntl: Value(data.quantityQntl),
        ratePerQntl: Value(data.ratePerQntl),
        totalAmount: Value((data.quantityQntl ?? 0) * (data.ratePerQntl ?? 0)),
        avgRate: Value(data.avgRate),
        avgAmount: Value(data.avgAmount),
        qrtCutAmt: Value(data.qrtCutAmt),
        paddyAmt: Value(data.paddyAmt),
        qualityCutsJson: Value(qualityCutsJson),
        totalCutKg: Value(data.totalCutKg),
        finalWeight: Value(data.finalWeight),
        gunnyTransactionsJson: Value(gunnyJson),
        deliveryType: Value(data.deliveryType ?? 'MD'),
        truckRentType: Value(data.truckRentType ?? 'Qntl'),
        truckRent: Value(data.truckRent ?? 0),
        truckRentPaid: Value(data.truckRentPaid ?? 0),
        otherAmount: Value(data.otherAmount ?? 0),
        transportType: Value(data.transportType ?? 'Direct'),
        truckAccount: Value(data.truckAccount ?? 'none'),
        freightAmount: Value(data.freightAmount ?? 0),
        procurementType: Value(data.procurementType ?? 'local'),
        mandiInvoiceNo: Value(data.mandiInvoiceNo),
        tenderNumber: Value(data.tenderNumber),
        commissionAgentId: Value(data.commissionAgentId),
        warehouseId: Value(data.warehouseId),
        remainingStock: Value(data.remainingStock ?? data.netWeight ?? 0),
        status: Value(data.status ?? 'draft'),
      ),
    );
  }

  @override
  Future<void> deleteProcurement(int id) async {
    await (_db.delete(_db.paddyProcurements)..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Future<void> completeProcurement(int id) async {
    final row = await (_db.select(_db.paddyProcurements)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw Exception('Procurement not found');

    // Parse quality cuts
    final qualityCuts = _parseQualityCuts(row.qualityCutsJson);
    final totalDeduction = qualityCuts.fold<double>(
      0,
      (sum, cut) => sum + cut.cutQuantityKg,
    );
    final actualQty = row.netWeight - totalDeduction - (row.otherCut ?? 0);

    // Stock-in to inventory (convert Kg to Qntl)
    final quantityInQntl = actualQty / 100;
    final ratePerQntl = row.ratePerQntl ?? 0;

    await _inventory.stockIn(
      productId: row.productId,
      warehouseId: row.warehouseId ?? await _db.defaultWarehouseId(),
      quantity: quantityInQntl,
      unitCost: ratePerQntl,
      note: 'Paddy Procurement #$id - ${row.slipNo}',
    );

    // Update status
    await (_db.update(_db.paddyProcurements)..where((t) => t.id.equals(id)))
        .write(
      PaddyProcurementsCompanion(
        status: const Value('completed'),
        remainingStock: Value(actualQty),
      ),
    );
  }

  @override
  Future<void> cancelProcurement(int id) async {
    await (_db.update(_db.paddyProcurements)..where((t) => t.id.equals(id)))
        .write(
      const PaddyProcurementsCompanion(
        status: Value('cancelled'),
      ),
    );
  }

  @override
  Future<double> getRemainingStock(int id) async {
    final row = await (_db.select(_db.paddyProcurements)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.remainingStock ?? 0;
  }

  @override
  Future<void> deductStock(int id, double quantity) async {
    final current = await getRemainingStock(id);
    final newStock = (current - quantity).clamp(0, double.infinity);
    await (_db.update(_db.paddyProcurements)..where((t) => t.id.equals(id)))
        .write(
      PaddyProcurementsCompanion(
        remainingStock: Value(newStock),
      ),
    );
  }

  // ── Helpers ──

  List<QualityCut> _parseQualityCuts(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => QualityCut.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<GunnyTransaction> _parseGunnyTransactions(String json) {
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => GunnyTransaction.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  PaddyProcurement _fromRow(PaddyProcurementRow row) {
    return PaddyProcurement(
      id: row.id,
      date: row.date,
      slipNo: row.slipNo,
      voucherNo: row.voucherNo,
      rstManual: row.rstManual,
      area: row.area,
      vType: row.vType,
      partyName: row.partyName,
      partyId: row.partyId,
      truckNo: row.truckNo,
      emptyWeight: row.emptyWeight,
      marketType: row.marketType,
      grossWeight: row.grossWeight,
      tareWeight: row.tareWeight,
      juteBags: row.juteBags,
      plasticBags: row.plasticBags,
      totalBags: row.totalBags,
      gnyWtLess: row.gnyWtLess,
      bagReturn: row.bagReturn,
      otherCut: row.otherCut,
      unloadTime: row.unloadTime,
      eBag: row.eBag,
      ePkt: row.ePkt,
      netWeight: row.netWeight,
      avgBagWeight: row.avgBagWeight,
      rateCalculation: row.rateCalculation,
      kgPerBag: row.kgPerBag,
      productId: row.productId,
      productName: row.productName,
      quantityNew: row.quantityNew,
      quantityQntl: row.quantityQntl,
      ratePerQntl: row.ratePerQntl,
      totalAmount: row.totalAmount,
      avgRate: row.avgRate,
      avgAmount: row.avgAmount,
      qrtCutAmt: row.qrtCutAmt,
      paddyAmt: row.paddyAmt,
      qualityCuts: _parseQualityCuts(row.qualityCutsJson),
      totalCutKg: row.totalCutKg,
      finalWeight: row.finalWeight,
      gunnyTransactions: _parseGunnyTransactions(row.gunnyTransactionsJson),
      deliveryType: row.deliveryType,
      truckRentType: row.truckRentType,
      truckRent: row.truckRent,
      truckRentPaid: row.truckRentPaid,
      otherAmount: row.otherAmount,
      transportType: row.transportType,
      truckAccount: row.truckAccount,
      freightAmount: row.freightAmount,
      procurementType: row.procurementType,
      mandiInvoiceNo: row.mandiInvoiceNo,
      tenderNumber: row.tenderNumber,
      commissionAgentId: row.commissionAgentId,
      warehouseId: row.warehouseId,
      remainingStock: row.remainingStock,
      status: row.status,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
