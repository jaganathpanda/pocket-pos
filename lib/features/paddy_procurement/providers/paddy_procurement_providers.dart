import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pos/core/database/database_provider.dart';
import 'package:pocket_pos/features/store/presentation/store_auth_controller.dart';
import '../../../core/firestore/store_scope.dart';
import '../data/firestore_paddy_procurement_repository.dart';
import '../data/paddy_procurement_repository_impl.dart';
import '../data/synced_paddy_procurement_repository.dart';
import '../domain/paddy_procurement.dart';
import '../domain/paddy_procurement_repository.dart';

/// Paddy procurement is persisted to BOTH local Drift (offline, source of truth
/// for reads) and Firestore (cloud mirror, when a store is active). See
/// [SyncedPaddyProcurementRepository].
final paddyProcurementRepositoryProvider =
    Provider<PaddyProcurementRepository>((ref) {
  final local = PaddyProcurementRepositoryImpl(ref.watch(appDatabaseProvider));
  final storeId = ref.watch(activeStoreIdProvider);
  final cloud = (storeId == null || storeId.isEmpty)
      ? null
      : FirestorePaddyProcurementRepository(
          ref.watch(firestoreProvider), storeId);
  return SyncedPaddyProcurementRepository(local, cloud);
});

final paddyProcurementFilterProvider = StateProvider<PaddyProcurementFilter>(
  (ref) => const PaddyProcurementFilter(),
);

final paddyProcurementStreamProvider =
    StreamProvider<List<PaddyProcurement>>((ref) {
  final filter = ref.watch(paddyProcurementFilterProvider);
  return ref.watch(paddyProcurementRepositoryProvider).watchAll(
        fromDate: filter.fromDate,
        toDate: filter.toDate,
        partyName: filter.partyName,
        procurementType: filter.procurementType,
      );
});

final paddyProcurementProvider =
    FutureProvider.family<PaddyProcurement?, int>((ref, id) {
  return ref.watch(paddyProcurementRepositoryProvider).getProcurement(id);
});

class PaddyProcurementFilter {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? partyName;
  final String? procurementType;

  const PaddyProcurementFilter({
    this.fromDate,
    this.toDate,
    this.partyName,
    this.procurementType,
  });

  PaddyProcurementFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? partyName,
    String? procurementType,
  }) {
    return PaddyProcurementFilter(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      partyName: partyName ?? this.partyName,
      procurementType: procurementType ?? this.procurementType,
    );
  }
}
