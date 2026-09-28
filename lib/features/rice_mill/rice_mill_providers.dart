import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pos/core/database/database_provider.dart';

import '../../core/di/providers.dart';
import '../../core/firestore/store_scope.dart';
import '../pos_counters/domain/pos_counter_repository.dart';
import '../store/presentation/store_auth_controller.dart';
import 'mill_run/data/firestore_mill_run_repository.dart';
import 'mill_run/data/firestore_milling_charge_repository.dart';
import 'mill_run/domain/mill_run_models.dart';
import 'mill_run/domain/mill_run_repository.dart';
import 'mill_run/domain/milling_charge_models.dart';
import 'mill_run/domain/milling_charge_repository.dart';
import 'mill_run/domain/milling_config.dart';
import 'weighbridge/data/firestore_weighbridge_repository.dart';
import 'weighbridge/data/weighbridge_repository.dart';
import 'weighbridge/data/weighbridge_repository_impl.dart';
import 'weighbridge/domain/vehicle_entry.dart';

final millersProvider = StreamProvider<List<PosUserRow>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(posCounterRepositoryProvider).watchMillers();
});

final millingConfigProvider = StreamProvider<MillingConfig>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (storeId == null) return Stream.value(MillingConfig.defaults());
  return storeCollection(ref.watch(firestoreProvider), storeId, 'settings')
      .doc('milling_config')
      .snapshots()
      .map((snap) => MillingConfig.fromMap(snap.data() ?? {}));
});

final millRunRepositoryProvider = Provider<MillRunRepository>((ref) {
  return FirestoreMillRunRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final millRunsProvider = StreamProvider<List<MillRunWithOutputs>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(millRunRepositoryProvider).watchAll();
});

final millingChargeRepositoryProvider =
    Provider<MillingChargeRepository>((ref) {
  return FirestoreMillingChargeRepository(
      ref.watch(firestoreProvider), ref.watch(activeStoreIdProvider) ?? '');
});

final millingChargesProvider =
    StreamProvider<List<MillingChargeInvoice>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  return ref.watch(millingChargeRepositoryProvider).watchAll();
});

class WeighbridgeFilter {
  const WeighbridgeFilter({
    this.fromDate,
    this.toDate,
    this.vehicleNo,
    this.partyName,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final String? vehicleNo;
  final String? partyName;
}

final useFirestoreProvider = Provider<bool>((ref) => true);

final weighbridgeRepositoryProvider = Provider<WeighbridgeRepository>((ref) {
  final storeId = ref.watch(activeStoreIdProvider);
  if (ref.watch(useFirestoreProvider) &&
      storeId != null &&
      storeId.isNotEmpty) {
    return FirestoreWeighbridgeRepository(
      ref.watch(firestoreProvider),
      storeId,
    );
  }
  return WeighbridgeRepositoryImpl(ref.watch(appDatabaseProvider));
});

final weighbridgeFilterProvider =
    StateProvider<WeighbridgeFilter>((ref) => const WeighbridgeFilter());

final vehicleEntriesStreamProvider = StreamProvider<List<VehicleEntry>>((ref) {
  final filter = ref.watch(weighbridgeFilterProvider);
  final useFirestore = ref.watch(useFirestoreProvider);
  if (useFirestore && ref.watch(activeStoreIdProvider) == null) {
    return Stream.value(const []);
  }
  return ref.watch(weighbridgeRepositoryProvider).watchAll(
        fromDate: filter.fromDate,
        toDate: filter.toDate,
        vehicleNo: filter.vehicleNo,
        partyName: filter.partyName,
      );
});

final vehicleEntryProvider =
    FutureProvider.family<VehicleEntry?, int>((ref, id) {
  if (ref.watch(useFirestoreProvider) &&
      ref.watch(activeStoreIdProvider) == null) {
    return Future.value(null);
  }
  return ref.watch(weighbridgeRepositoryProvider).getEntry(id);
});

final vehicleEntryStreamProvider =
    StreamProvider.family<VehicleEntry?, int>((ref, id) {
  if (ref.watch(useFirestoreProvider) &&
      ref.watch(activeStoreIdProvider) == null) {
    return Stream.value(null);
  }
  return ref.watch(weighbridgeRepositoryProvider).watchEntry(id);
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(storeSessionProvider)?.uid;
});

final pendingApprovalsProvider = StreamProvider<List<VehicleEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref
      .watch(weighbridgeRepositoryProvider)
      .watchPending(approverUid: uid);
});

final pendingApprovalsCountProvider = Provider<int>((ref) {
  return ref.watch(pendingApprovalsProvider).valueOrNull?.length ?? 0;
});

final myWeighbridgeEntriesProvider = StreamProvider<List<VehicleEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(weighbridgeRepositoryProvider).watchByCreator(uid);
});
