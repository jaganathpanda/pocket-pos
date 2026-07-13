import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';

class ExpensePage extends ConsumerWidget {
  const ExpensePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Management'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () async {
              final rows = await ref.read(expensesProvider.future);
              if (!context.mounted) return;
              await Clipboard.setData(ClipboardData(text: _toCsv(rows)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense CSV copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: expenses.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No expenses recorded yet.'));
          }
          final total = list.fold<double>(0, (sum, e) => sum + e.amount);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Total Expenses'),
                  trailing: Text(formatInr(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              for (final e in list)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_rounded),
                    title: Text(e.category),
                    subtitle: Text(
                      '${DateFormat('dd MMM yyyy HH:mm').format(e.spentAt)}'
                      '${e.note == null || e.note!.isEmpty ? '' : '\n${e.note}'}',
                    ),
                    isThreeLine: e.note != null && e.note!.isNotEmpty,
                    trailing: SizedBox(
                      width: 140,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(formatInr(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final db = ref.read(appDatabaseProvider);
                              await (db.delete(db.expenses)..where((x) => x.id.equals(e.id))).go();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load expenses: $e')),
      ),
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context, WidgetRef ref) async {
    final category = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    DateTime spentAt = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Expense'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(DateFormat('dd MMM yyyy').format(spentAt))),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDate: spentAt,
                        );
                        if (picked != null) {
                          setState(() => spentAt = DateTime(picked.year, picked.month, picked.day, spentAt.hour, spentAt.minute));
                        }
                      },
                      child: const Text('Pick Date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final cat = category.text.trim();
    final amt = double.tryParse(amount.text) ?? 0;
    if (cat.isEmpty || amt <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category and valid amount are required')),
        );
      }
      return;
    }

    final db = ref.read(appDatabaseProvider);
    await db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            category: cat,
            amount: amt,
            note: Value(note.text.trim().isEmpty ? null : note.text.trim()),
            spentAt: Value(spentAt),
          ),
        );
  }

  String _toCsv(List<Expense> rows) {
    final b = StringBuffer();
    b.writeln('spent_at,category,amount,note');
    for (final r in rows) {
      b.writeln('${r.spentAt.toIso8601String()},${_csv(r.category)},${r.amount.toStringAsFixed(2)},${_csv(r.note ?? '')}');
    }
    return b.toString();
  }

  String _csv(String v) => '"${v.replaceAll('"', '""')}"';
}
