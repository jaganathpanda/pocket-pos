import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';

class CreditLedgerPage extends ConsumerWidget {
  const CreditLedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(creditLedgerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit / Udhar Ledger'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(creditLedgerProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () async {
              final rows = await ref.read(creditLedgerProvider.future);
              if (!context.mounted) return;
              final csv = _toCsv(rows);
              await Clipboard.setData(ClipboardData(text: csv));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ledger CSV copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ledger.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No credit / udhar records found.'));
          }

          final totalDue = rows.fold<double>(0, (sum, r) => sum + r.dueAmount);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Total Pending Credit'),
                  trailing: Text(
                    formatInr(totalDue),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final row in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.customer?.name ?? 'Walk-in Customer',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              'Due ${formatInr(row.dueAmount)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Invoice: ${row.sale.invoiceNo}'),
                        Text('Date: ${DateFormat('dd MMM yyyy HH:mm').format(row.sale.soldAt)}'),
                        Text('Mobile: ${row.customer?.mobile ?? '-'}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Paid ${formatInr(row.paidAmount)}', style: const TextStyle(fontSize: 12)),
                            ),
                            FilledButton.tonal(
                              onPressed: row.dueAmount > 0 ? () => _showRecordPaymentDialog(context, ref, row) : null,
                              child: Text(row.dueAmount > 0 ? 'Record Payment' : 'No Due'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load ledger: $e')),
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(BuildContext context, WidgetRef ref, CreditLedgerRow row) async {
    final amountCtrl = TextEditingController(text: row.dueAmount.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    String method = 'cash';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Record Payment - ${row.sale.invoiceNo}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  ],
                  onChanged: (v) => setState(() => method = v ?? 'cash'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Reference No (optional)', border: OutlineInputBorder()),
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

    final amount = double.tryParse(amountCtrl.text) ?? 0;
    try {
      await ref.read(salesRepositoryProvider).recordCreditPayment(
            saleId: row.sale.id,
            amount: amount,
            method: method,
            referenceNo: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
          );
      ref.invalidate(creditLedgerProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(salesReportProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded')), 
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  String _toCsv(List<CreditLedgerRow> rows) {
    final buffer = StringBuffer();
    buffer.writeln('invoice_no,customer,mobile,sold_at,grand_total,paid,due,status');
    for (final row in rows) {
      buffer.writeln(
        '${row.sale.invoiceNo},${_csv(row.customer?.name ?? 'Walk-in')},${_csv(row.customer?.mobile ?? '')},'
        '${row.sale.soldAt.toIso8601String()},${row.sale.grandTotal.toStringAsFixed(2)},'
        '${row.paidAmount.toStringAsFixed(2)},${row.dueAmount.toStringAsFixed(2)},${row.sale.paymentStatus}',
      );
    }
    return buffer.toString();
  }

  String _csv(String v) => '"${v.replaceAll('"', '""')}"';
}
