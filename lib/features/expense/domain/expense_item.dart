/// A store-scoped expense (Firestore-backed, replaces the Drift `Expense`).
class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.category,
    required this.amount,
    required this.spentAt,
    this.note,
  });

  final String id;
  final String category;
  final double amount;
  final DateTime spentAt;
  final String? note;
}
