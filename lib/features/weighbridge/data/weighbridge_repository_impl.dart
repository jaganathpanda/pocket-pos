import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:pocket_pos/features/weighbridge/data/weighbridge_repository.dart';
import 'package:pocket_pos/features/weighbridge/domain/vehicle_entry.dart';
import '../../../core/database/app_database.dart' hide VehicleEntry;

// ─── Helper: Parse manual weights from JSON ───

List<ManualWeightLine> _parseManualWeights(String json) {
  try {
    final list = jsonDecode(json) as List;
    return list
        .map((e) => ManualWeightLine.fromMap(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
}

// ─── Helper: Encode manual weights to JSON ───

String _encodeManualWeights(List<ManualWeightLine>? weights) {
  if (weights == null || weights.isEmpty) return '[]';
  return jsonEncode(weights.map((l) => l.toMap()).toList());
}

// ─── Helper: Calculate net weight ───

double _calculateNetWeight(VehicleEntryCompanion data) {
  final first = data.firstWeight ?? 0;
  final second = data.secondWeight ?? 0;
  final type = data.entryType ?? 'inward';

  if (type == 'inward') {
    return (first - second).clamp(0, double.infinity);
  } else {
    return (second - first).clamp(0, double.infinity);
  }
}

// ─── Helper: Get net weight based on weigh mode ───

double _netFor(VehicleEntryCompanion data) {
  if ((data.weighMode ?? 'weighbridge') == 'manual') {
    return (data.manualWeights ?? const [])
        .fold<double>(0, (s, l) => s + l.weight);
  }
  return data.netWeight ?? _calculateNetWeight(data);
}

// ─── Main Repository Implementation ───

class WeighbridgeRepositoryImpl implements WeighbridgeRepository {
  final AppDatabase _db;

  WeighbridgeRepositoryImpl(this._db);

  // ──────────────────────────────────────────────────────────────────────────
  // ── watchAll ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Stream<List<VehicleEntry>> watchAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? vehicleNo,
    String? partyName,
  }) {
    print('🔍 WeighbridgeRepositoryImpl.watchAll() called');

    final joinQuery = _db.select(_db.vehicleEntries).join([
      innerJoin(_db.products,
          _db.products.id.equalsExp(_db.vehicleEntries.productId)),
      leftOuterJoin(_db.suppliers,
          _db.suppliers.id.equalsExp(_db.vehicleEntries.partyId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.vehicleEntries.date)]);

    // Date filters
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
            entryType: entry.entryType,
            weighMode: entry.weighMode,
            manualWeights: _parseManualWeights(entry.manualWeightsJson),
            status: entry.status ?? 'approved',
            createdByUid: entry.createdByUid,
            createdByName: entry.createdByName,
            approverUid: entry.approverUid,
            approverName: entry.approverName,
            productName: product.name,
            partyNameFromSupplier: supplier?.name,
          );
        }).toList());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── getEntry ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<VehicleEntry?> getEntry(int id) async {
    print('🔍 WeighbridgeRepositoryImpl.getEntry() called for ID: $id');

    final row = await (_db.select(_db.vehicleEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();

    if (row == null) {
      print('❌ Entry not found for ID: $id');
      return null;
    }

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
      entryType: row.entryType,
      weighMode: row.weighMode,
      manualWeights: _parseManualWeights(row.manualWeightsJson),
      status: row.status ?? 'approved',
      createdByUid: row.createdByUid,
      createdByName: row.createdByName,
      approverUid: row.approverUid,
      approverName: row.approverName,
      productName: product.name,
      partyNameFromSupplier: supplier?.name,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── watchEntry (Real-time stream) ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Stream<VehicleEntry?> watchEntry(int id) {
    print('🔍 WeighbridgeRepositoryImpl.watchEntry() called for ID: $id');

    final entryStream = (_db.select(_db.vehicleEntries)
          ..where((t) => t.id.equals(id)))
        .watchSingleOrNull();

    return entryStream.asyncMap((row) async {
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
        entryType: row.entryType,
        weighMode: row.weighMode,
        manualWeights: _parseManualWeights(row.manualWeightsJson),
        status: row.status ?? 'approved',
        createdByUid: row.createdByUid,
        createdByName: row.createdByName,
        approverUid: row.approverUid,
        approverName: row.approverName,
        productName: product.name,
        partyNameFromSupplier: supplier?.name,
      );
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── createEntry ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<int> createEntry(VehicleEntryCompanion data) {
    print('🔍 WeighbridgeRepositoryImpl.createEntry() called');
    print('   Status: ${data.status}');
    print('   CreatedByUid: ${data.createdByUid}');

    final netWeight = _netFor(data);

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
      netWeight: Value(netWeight),
      bags: Value(data.bags),
      lotNumber: Value(data.lotNumber),
      complete: Value(data.complete ?? false),
      completeCode: Value(data.completeCode),
      completeDate: Value(data.completeDate),
      remark: Value(data.remark),
      entryType: Value(data.entryType ?? 'inward'),
      weighMode: Value(data.weighMode ?? 'weighbridge'),
      manualWeightsJson: Value(_encodeManualWeights(data.manualWeights)),
      status: Value(data.status ?? 'approved'),
      createdByUid: Value(data.createdByUid),
      createdByName: Value(data.createdByName),
      approverUid: Value(data.approverUid),
      approverName: Value(data.approverName),
      createdAt: Value(data.createdAt ?? DateTime.now()),
      updatedAt: Value(data.updatedAt ?? DateTime.now()),
    );

    return _db.into(_db.vehicleEntries).insert(companion);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── updateEntry ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> updateEntry(VehicleEntryCompanion data) {
    if (data.id == null) throw Exception('ID required for update');

    print(
        '🔍 WeighbridgeRepositoryImpl.updateEntry() called for ID: ${data.id}');

    final netWeight = _netFor(data);

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
      netWeight: Value(netWeight),
      bags: Value(data.bags),
      lotNumber: Value(data.lotNumber),
      complete: Value(data.complete ?? false),
      completeCode: Value(data.completeCode),
      completeDate: Value(data.completeDate),
      remark: Value(data.remark),
      entryType: Value(data.entryType ?? 'inward'),
      weighMode: Value(data.weighMode ?? 'weighbridge'),
      manualWeightsJson: Value(_encodeManualWeights(data.manualWeights)),
      status: Value(data.status ?? 'approved'),
      createdByUid: Value(data.createdByUid),
      createdByName: Value(data.createdByName),
      approverUid: Value(data.approverUid),
      approverName: Value(data.approverName),
      updatedAt: Value(DateTime.now()),
    );

    return (_db.update(_db.vehicleEntries)..where((t) => t.id.equals(data.id!)))
        .write(companion);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── deleteEntry ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> deleteEntry(int id) {
    print('🔍 WeighbridgeRepositoryImpl.deleteEntry() called for ID: $id');
    return (_db.delete(_db.vehicleEntries)..where((t) => t.id.equals(id))).go();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── markComplete ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> markComplete(int id, {String? completeCode}) async {
    print('🔍 WeighbridgeRepositoryImpl.markComplete() called for ID: $id');

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

  // ──────────────────────────────────────────────────────────────────────────
  // ── watchPending ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Stream<List<VehicleEntry>> watchPending({String? approverUid}) {
    print('🔍 WeighbridgeRepositoryImpl.watchPending() called');

    final query = _db.select(_db.vehicleEntries)
      ..where((t) => t.status.equals('pending'))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);

    if (approverUid != null && approverUid.isNotEmpty) {
      query.where((t) => t.approverUid.equals(approverUid));
    }

    return query.watch().asyncMap((rows) async {
      final result = <VehicleEntry>[];
      for (final row in rows) {
        final product = await (_db.select(_db.products)
              ..where((p) => p.id.equals(row.productId)))
            .getSingle();

        final supplier = row.partyId != null
            ? await (_db.select(_db.suppliers)
                  ..where((s) => s.id.equals(row.partyId!)))
                .getSingleOrNull()
            : null;

        result.add(VehicleEntry(
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
          entryType: row.entryType,
          weighMode: row.weighMode,
          manualWeights: _parseManualWeights(row.manualWeightsJson),
          status: row.status ?? 'pending',
          createdByUid: row.createdByUid,
          createdByName: row.createdByName,
          approverUid: row.approverUid,
          approverName: row.approverName,
          productName: product.name,
          partyNameFromSupplier: supplier?.name,
        ));
      }
      return result;
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── watchByCreator ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Stream<List<VehicleEntry>> watchByCreator(String createdByUid) {
    print(
        '🔍 WeighbridgeRepositoryImpl.watchByCreator() called for UID: $createdByUid');

    final query = _db.select(_db.vehicleEntries)
      ..where((t) => t.createdByUid.equals(createdByUid))
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);

    return query.watch().asyncMap((rows) async {
      final result = <VehicleEntry>[];
      for (final row in rows) {
        final product = await (_db.select(_db.products)
              ..where((p) => p.id.equals(row.productId)))
            .getSingle();

        final supplier = row.partyId != null
            ? await (_db.select(_db.suppliers)
                  ..where((s) => s.id.equals(row.partyId!)))
                .getSingleOrNull()
            : null;

        result.add(VehicleEntry(
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
          entryType: row.entryType,
          weighMode: row.weighMode,
          manualWeights: _parseManualWeights(row.manualWeightsJson),
          status: row.status ?? 'approved',
          createdByUid: row.createdByUid,
          createdByName: row.createdByName,
          approverUid: row.approverUid,
          approverName: row.approverName,
          productName: product.name,
          partyNameFromSupplier: supplier?.name,
        ));
      }
      return result;
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── approveEntry ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> approveEntry(int id,
      {required String approvedByUid, String? approverName}) async {
    print('🔍 WeighbridgeRepositoryImpl.approveEntry() called for ID: $id');

    await (_db.update(_db.vehicleEntries)..where((t) => t.id.equals(id))).write(
      VehicleEntriesCompanion(
        status: const Value('approved'),
        approvedByUid: Value(approvedByUid),
        approverName: Value(approverName),
        approvedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── rejectEntry ──
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> rejectEntry(int id,
      {required String approvedByUid, String? reason}) async {
    print('🔍 WeighbridgeRepositoryImpl.rejectEntry() called for ID: $id');

    await (_db.update(_db.vehicleEntries)..where((t) => t.id.equals(id))).write(
      VehicleEntriesCompanion(
        status: const Value('rejected'),
        approvedByUid: Value(approvedByUid),
        rejectionReason: Value(reason),
        approvedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
