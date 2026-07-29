/// Generates stable integer ids used as Firestore document ids, so the existing
/// int-keyed model classes (Product, Category, …) can be reused unchanged as
/// Firestore DTOs during the Drift → Firestore migration.
///
/// Monotonic within a session (microsecond clock + a rolling counter), which is
/// unique enough for a single store's catalogue and avoids collisions in tight
/// seeding loops.
int _counter = 0;

int newIntId() {
  final base = DateTime.now().microsecondsSinceEpoch;
  _counter = (_counter + 1) & 0x3FF; // 0..1023
  return base * 1024 + _counter;
}
