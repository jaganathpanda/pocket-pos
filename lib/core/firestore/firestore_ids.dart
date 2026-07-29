/// Generates stable integer ids used as Firestore document ids, so the existing
/// int-keyed model classes (Product, Category, …) can be reused unchanged as
/// Firestore DTOs.
///
/// IMPORTANT: ids must stay below 2^53 (JavaScript's safe-integer limit) so they
/// survive round-tripping on Flutter **web**, where Dart ints are JS doubles.
/// `millisecondsSinceEpoch * 1000 + counter` ≈ 1.77e15 today — well under
/// 2^53 (~9.007e15) — and stays unique within a store (1000 ids per ms).
int _counter = 0;

int newIntId() {
  final base = DateTime.now().millisecondsSinceEpoch; // ~1.77e12
  _counter = (_counter + 1) % 1000;
  return base * 1000 + _counter; // < 2^53, safe on web and native
}
