import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/services/pdf_service.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../../../core/utilities/money.dart';

class SalesReportPage extends ConsumerWidget {
  const SalesReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(salesReportRangeProvider);
    final report = ref.watch(salesReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        actions: [
          IconButton(
            tooltip: 'Pick date range',
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: range,
              );
              if (picked != null) {
                ref.read(salesReportRangeProvider.notifier).state = picked;
              }
            },
            icon: const Icon(Icons.date_range_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(salesReportProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Export CSV',
            onPressed: () async {
              final data = await ref.read(salesReportProvider.future);
              if (!context.mounted) return;
              await Clipboard.setData(ClipboardData(text: _toCsv(data)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sales report CSV copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: report.when(
        data: (data) {
          final rangeLabel =
              '${DateFormat('dd MMM yyyy').format(data.start)} - ${DateFormat('dd MMM yyyy').format(data.end)}';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(rangeLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricCard('Sales Count', data.totalSales.toString(),
                      Icons.receipt_long_rounded),
                  _metricCard('Total Amount', formatInr(data.totalAmount),
                      Icons.currency_rupee_rounded),
                  _metricCard('Tax Collected', formatInr(data.totalTax),
                      Icons.account_balance_rounded),
                  _metricCard('Discount Given', formatInr(data.totalDiscount),
                      Icons.local_offer_rounded),
                  _metricCard('Line Items', data.totalItems.toString(),
                      Icons.inventory_2_rounded),
                  _metricCard(
                      'Quantity Sold',
                      data.totalQuantity.toStringAsFixed(2),
                      Icons.shopping_bag_rounded),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Method Summary',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (data.paymentMethodTotals.isEmpty)
                        const Text('No payment records for selected range')
                      else
                        ...data.paymentMethodTotals.entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(e.key.toUpperCase())),
                                Text(formatInr(e.value),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top Products',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (data.topProducts.isEmpty)
                        const Text('No products sold in selected range')
                      else
                        ...data.topProducts.map(
                          (p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(p.name)),
                                Text('Qty ${p.quantity.toStringAsFixed(2)}'),
                                const SizedBox(width: 12),
                                Text(formatInr(p.amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invoices',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (data.rows.isEmpty)
                        const Text('No invoices in selected range')
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Invoice')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Products (GST)')),
                              DataColumn(label: Text('Items')),
                              DataColumn(label: Text('Qty')),
                              DataColumn(label: Text('Method')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: [
                              for (final row in data.rows)
                                DataRow(
                                  cells: [
                                    DataCell(Text(row.invoiceNo)),
                                    DataCell(Text(DateFormat('dd/MM/yyyy HH:mm')
                                        .format(row.soldAt))),
                                    DataCell(
                                      SizedBox(
                                        width: 320,
                                        child: Text(
                                          row.productGstSummary,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(row.itemsCount.toString())),
                                    DataCell(
                                        Text(row.totalQty.toStringAsFixed(2))),
                                    DataCell(Text((row.paymentMethod ?? '-')
                                        .toUpperCase())),
                                    DataCell(
                                        Text(row.paymentStatus.toUpperCase())),
                                    DataCell(Text(formatInr(row.grandTotal))),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Print invoice',
                                            icon: const Icon(
                                                Icons.print_outlined),
                                            onPressed: () => _printInvoice(
                                                context, ref, row),
                                          ),
                                          if (_isCreditLike(row.paymentStatus))
                                            IconButton(
                                              tooltip:
                                                  'View payments (${row.paymentCount})',
                                              icon: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  const Icon(
                                                      Icons.payments_outlined),
                                                  Positioned(
                                                    right: -8,
                                                    top: -8,
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 4,
                                                          vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.red.shade700,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        row.paymentCount
                                                            .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onPressed: () =>
                                                  _showPaymentsDialog(
                                                      context, ref, row),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load report: $e')),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  String _toCsv(SalesReportData data) {
    final b = StringBuffer();
    b.writeln('invoice,date,payment_method,payment_status,items,qty,amount,products_gst');
    for (final row in data.rows) {
      b.writeln(
        '${_csv(row.invoiceNo)},${row.soldAt.toIso8601String()},${_csv((row.paymentMethod ?? '-').toUpperCase())},'
        '${_csv(row.paymentStatus.toUpperCase())},${row.itemsCount},${row.totalQty.toStringAsFixed(2)},${row.grandTotal.toStringAsFixed(2)},${_csv(row.productGstSummary)}',
      );
    }
    return b.toString();
  }

  String _csv(String v) => '"${v.replaceAll('"', '""')}"';

  bool _isCreditLike(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'credit' || normalized == 'partial';
  }

  Future<void> _printInvoice(
      BuildContext context, WidgetRef ref, SalesReportRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final storeId = ref.read(activeStoreIdProvider);
      if (storeId == null || storeId.isEmpty) {
        throw Exception('No active store.');
      }
      final fs = ref.read(firestoreProvider);

      // Line items for this sale (served from cache when offline).
      final itemSnap = await storeCollection(fs, storeId, 'sale_items')
          .where('saleId', isEqualTo: row.saleId)
          .get();
      final saleItems = itemSnap.docs.map(saleItemFromDoc).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      final productIds = saleItems.map((i) => i.productId).toSet().toList();
      var productNameById = <int, String>{};
      if (productIds.isNotEmpty) {
        final productSnap = await storeCollection(fs, storeId, 'products').get();
        final productById = {
          for (final d in productSnap.docs)
            (int.tryParse(d.id) ?? 0): productFromDoc(d),
        };
        productNameById = {
          for (final id in productIds)
            id: productById[id]?.name ?? 'Product #$id',
        };
      }

      final shopName = ref.read(storeSessionProvider)?.storeName ?? 'Pocket POS';
      final bytes = await ReceiptPdfService().generateSimpleReceipt(
        shopName: shopName,
        invoiceNo: row.invoiceNo,
        items: saleItems
            .map(
              (item) => (
                name: '${productNameById[item.productId] ?? 'Product #${item.productId}'} (GST ${item.taxPercent.toStringAsFixed(item.taxPercent % 1 == 0 ? 0 : 2)}%)',
                qty: item.quantity,
                discountAmount: item.discountAmount,
                netAmount: item.lineTotal,
              ),
            )
            .toList(growable: false),
        grandTotal: row.grandTotal,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to print invoice: $e')),
      );
    }
  }

  Future<void> _showPaymentsDialog(
      BuildContext context, WidgetRef ref, SalesReportRow row) async {
    final storeId = ref.read(activeStoreIdProvider);
    var payments = <Payment>[];
    if (storeId != null && storeId.isNotEmpty) {
      final fs = ref.read(firestoreProvider);
      final snap = await storeCollection(fs, storeId, 'payments')
          .where('saleId', isEqualTo: row.saleId)
          .get();
      payments = snap.docs.map(paymentFromDoc).toList()
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Payments - ${row.invoiceNo}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment count: ${payments.length}'),
              Text('Paid: ${formatInr(row.paidAmount)}'),
              Text(
                'Due: ${formatInr(row.dueAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: row.dueAmount > 0 ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              if (payments.isEmpty)
                const Text('No payment records found for this invoice.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final payment = payments[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${payment.method.toUpperCase()} - ${formatInr(payment.amount)}'),
                        subtitle: Text(DateFormat('dd MMM yyyy HH:mm')
                            .format(payment.paidAt)),
                        trailing: Text(
                            payment.referenceNo?.trim().isNotEmpty == true
                                ? payment.referenceNo!
                                : '-'),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
