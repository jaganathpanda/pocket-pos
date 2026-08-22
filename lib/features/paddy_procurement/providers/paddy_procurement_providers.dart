import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pos/features/store/presentation/store_auth_controller.dart';
import '../../../core/firestore/store_scope.dart';
import '../data/firestore_paddy_procurement_repository.dart';
import '../domain/paddy_procurement.dart';
import '../domain/paddy_procurement_repository.dart';

final paddyProcurementRepositoryProvider =
    Provider<PaddyProcurementRepository>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) throw Exception('No active store');
  return FirestorePaddyProcurementRepository(
    ref.watch(firestoreProvider),
    storeId,
  );
});

final paddyProcurementFilterProvider = StateProvider<PaddyProcurementFilter>(
  (ref) => const PaddyProcurementFilter(),
);

final paddyProcurementStreamProvider =
    StreamProvider<List<PaddyProcurement>>((ref) {
  final filter = ref.watch(paddyProcurementFilterProvider);
  if (ref.watch(activeStoreIdProvider) == null) {
    return Stream.value(const []);
  }
  return ref.watch(paddyProcurementRepositoryProvider).watchAll(
        fromDate: filter.fromDate,
        toDate: filter.toDate,
        partyName: filter.partyName,
        procurementType: filter.procurementType,
      );
});

final paddyProcurementProvider =
    FutureProvider.family<PaddyProcurement?, int>((ref, id) {
  if (ref.watch(activeStoreIdProvider) == null) {
    return Future.value(null);
  }
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
