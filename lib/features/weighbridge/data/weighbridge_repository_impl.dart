import 'package:drift/drift.dart';
import 'package:pocket_pos/features/weighbridge/data/weighbridge_repository.dart';
import 'package:pocket_pos/features/weighbridge/domain/vehicle_entry.dart';
import '../../../core/database/app_database.dart' hide VehicleEntry;

class WeighbridgeRepositoryImpl implements WeighbridgeRepository {
  final AppDatabase _db;

  WeighbridgeRepositoryImpl(this._db);

  @override
  Stream<List<VehicleEntry>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? vehicleNo,
    String? partyName,
  }) {
    final joinQuery = _db.select(_db.vehicleEntries).join([
      innerJoin(_db.products,
          _db.products.id.equalsExp(_db.vehicleEntries.productId)),
      leftOuterJoin(_db.suppliers,
          _db.suppliers.id.equalsExp(_db.vehicleEntries.partyId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.vehicleEntries.date)]);

    // Typed column comparisons rather than raw SQL: CustomExpression takes no
    // bind variables, and a bare `date` would be ambiguous across the join.
    if (fromDate != null) {
      joinQuery.where(_db.vehicleEntries.date.isBiggerOrEqualValue(fromDate));
    }
    if (toDate != null) {
      joinQuery.where(_db.vehicleEntries.date.isSmallerOrEqualValue(toDate));
    }
    if (vehicleNo != null && vehicleNo.isNotEmpty) {
      joinQuery.where(_db.vehicleEntries.vehicleNo.like('%$vehicleNo%'));
    }
    if (partyName != null && partyName.isNotEmpty) {
      joinQuery.where(_db.vehicleEntries.partyName.like('%$partyName%'));
    }

    return joinQuery.watch().map((rows) => rows.map((r) {
          final entry = r.readTable(_db.vehicleEntries);
          final product = r.readTable(_db.products);
          final supplier = r.readTableOrNull(_db.suppliers);
          return VehicleEntry(
            id: entry.id,
            date: entry.date,
            slipNo: entry.slipNo,
            voucherNo: entry.voucherNo,
            vehicleNo: entry.vehicleNo,
            rstManual: entry.rstManual,
            partyName: entry.partyName,
            partyId: entry.partyId,
            productId: entry.productId,
            firstWeight: entry.firstWeight,
            firstWeightTime: entry.firstWeightTime,
            secondWeight: entry.secondWeight,
            secondWeightTime: entry.secondWeightTime,
            netWeight: entry.netWeight,
            bags: entry.bags,
            lotNumber: entry.lotNumber,
            complete: entry.complete,
            completeCode: entry.completeCode,
            completeDate: entry.completeDate,
            remark: entry.remark,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            productName: product.name,
            partyNameFromSupplier: supplier?.name,
          );
        }).toList());
  }

  @override
  Future<VehicleEntry?> getEntry(int id) async {
    final row = await (_db.select(_db.vehicleEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final product = await (_db.select(_db.products)
          ..where((p) => p.id.equals(row.productId)))
        .getSingle();
    final supplier = row.partyId != null
        ? await (_db.select(_db.suppliers)
              ..where((s) => s.id.equals(row.partyId!)))
            .getSingleOrNull()
        : null;
    return VehicleEntry(
      id: row.id,
      date: row.date,
      slipNo: row.slipNo,
      voucherNo: row.voucherNo,
      vehicleNo: row.vehicleNo,
      rstManual: row.rstManual,
      partyName: row.partyName,
      partyId: row.partyId,
      productId: row.productId,
      firstWeight: row.firstWeight,
      firstWeightTime: row.firstWeightTime,
      secondWeight: row.secondWeight,
      secondWeightTime: row.secondWeightTime,
      netWeight: row.netWeight,
      bags: row.bags,
      lotNumber: row.lotNumber,
      complete: row.complete,
      completeCode: row.completeCode,
      completeDate: row.completeDate,
      remark: row.remark,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      productName: product.name,
      partyNameFromSupplier: supplier?.name,
    );
  }

  @override
  Future<int> createEntry(VehicleEntryCompanion data) {
    final companion = VehicleEntriesCompanion(
      date: Value(data.date!),
      slipNo: Value(data.slipNo!),
      voucherNo: Value(data.voucherNo),
      vehicleNo: Value(data.vehicleNo!),
      rstManual: Value(data.rstManual),
      partyName: Value(data.partyName!),
      partyId: Value(data.partyId),
      productId: Value(data.productId!),
      firstWeight: Value(data.firstWeight!),
      firstWeightTime: Value(data.firstWeightTime),
      secondWeight: Value(data.secondWeight!),
      secondWeightTime: Value(data.secondWeightTime),
      netWeight: Value(data.netWeight ?? _calculateNetWeight(data)),
      bags: Value(data.bags),
      lotNumber: Value(data.lotNumber),
      complete: Value(data.complete ?? false),
      completeCode: Value(data.completeCode),
      completeDate: Value(data.completeDate),
      remark: Value(data.remark),
      createdAt: Value(data.createdAt ?? DateTime.now()),
      updatedAt: Value(data.updatedAt ?? DateTime.now()),
    );
    return _db.into(_db.vehicleEntries).insert(companion);
  }

  @override
  Future<void> updateEntry(VehicleEntryCompanion data) {
    if (data.id == null) throw Exception('ID required for update');
    final companion = VehicleEntriesCompanion(
      date: Value(data.date!),
      slipNo: Value(data.slipNo!),
      voucherNo: Value(data.voucherNo),
      vehicleNo: Value(data.vehicleNo!),
      rstManual: Value(data.rstManual),
      partyName: Value(data.partyName!),
      partyId: Value(data.partyId),
      productId: Value(data.productId!),
      firstWeight: Value(data.firstWeight!),
      firstWeightTime: Value(data.firstWeightTime),
      secondWeight: Value(data.secondWeight!),
      secondWeightTime: Value(data.secondWeightTime),
      netWeight:
          Value(data.netWeight ?? (data.firstWeight! - data.secondWeight!)),
      bags: Value(data.bags),
      lotNumber: Value(data.lotNumber),
      complete: Value(data.complete ?? false),
      completeCode: Value(data.completeCode),
      completeDate: Value(data.completeDate),
      remark: Value(data.remark),
      updatedAt: Value(DateTime.now()),
    );
    return (_db.update(_db.vehicleEntries)..where((t) => t.id.equals(data.id!)))
        .write(companion);
  }

  @override
  Future<void> deleteEntry(int id) {
    return (_db.delete(_db.vehicleEntries)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> markComplete(int id, {String? completeCode}) async {
    final now = DateTime.now();
    final code = completeCode ??
        'GEN${now.millisecondsSinceEpoch.toString().substring(0, 6)}';
    await (_db.update(_db.vehicleEntries)..where((t) => t.id.equals(id))).write(
      VehicleEntriesCompanion(
        complete: const Value(true),
        completeCode: Value(code),
        completeDate: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  double _calculateNetWeight(VehicleEntryCompanion data) {
    final first = data.firstWeight!;
    final second = data.secondWeight!;
    final type = data.entryType ?? 'inward';

    if (type == 'inward') {
      // Inward: First = Gross, Second = Tare
      return (first - second).clamp(0, double.infinity);
    } else {
      // Outward: First = Tare, Second = Gross
      return (second - first).clamp(0, double.infinity);
    }
  }
}
