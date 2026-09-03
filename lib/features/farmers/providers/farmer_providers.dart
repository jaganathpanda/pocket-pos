import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/store_scope.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../data/firestore_farmer_repository.dart';
import '../domain/farmer.dart';
import '../domain/farmer_repository.dart';

final farmerRepositoryProvider = Provider<FarmerRepository>((ref) {
  return FirestoreFarmerRepository(
    ref.watch(firestoreProvider),
    ref.watch(activeStoreIdProvider) ?? '',
  );
});

final farmerFilterTypeProvider = StateProvider<String?>((ref) => null);

final farmersProvider = StreamProvider<List<Farmer>>((ref) {
  if (ref.watch(activeStoreIdProvider) == null) return Stream.value(const []);
  final type = ref.watch(farmerFilterTypeProvider);
  return ref.watch(farmerRepositoryProvider).watchAll(type: type);
});

final farmerSearchQueryProvider = StateProvider<String>((ref) => '');

final farmerSearchResultsProvider = FutureProvider<List<Farmer>>((ref) async {
  final query = ref.watch(farmerSearchQueryProvider).trim();
  if (query.isEmpty) return const [];
  final type = ref.watch(farmerFilterTypeProvider);
  return ref.watch(farmerRepositoryProvider).search(query, type: type);
});

final farmerProvider = FutureProvider.family<Farmer?, int>((ref, id) {
  if (ref.watch(activeStoreIdProvider) == null) return Future.value(null);
  return ref.watch(farmerRepositoryProvider).getById(id);
});
