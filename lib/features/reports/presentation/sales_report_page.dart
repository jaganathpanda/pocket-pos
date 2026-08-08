import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/models/invoice_branding.dart';
import '../../../core/models/printer_config.dart';
import '../../../core/services/pdf_service.dart';
import '../../sales/domain/sales_repository.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../../../core/utilities/money.dart';

final _salesLastPrintModeProvider = StateProvider<String?>((ref) => null);
final _salesShowLastPrintBannerProvider = StateProvider<bool>((ref) => false);

class SalesReportPage extends ConsumerWidget {
  const SalesReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(salesReportRangeProvider);
    final report = ref.watch(salesReportProvider);
    final lastPrintMode = ref.watch(_salesLastPrintModeProvider);
    final showLastPrintBanner = ref.watch(_salesShowLastPrintBannerProvider);
    final printerConfig =
        ref.watch(printerConfigProvider).valueOrNull ??
            const PrinterConfig.defaults();
    final canPrint = printerConfig.enabled || printerConfig.allowPdfFallback;

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
              if (lastPrintMode != null && showLastPrintBanner) ...[
                _lastPrintModeBanner(
                  ref,
                  lastPrintMode,
                ),
                const SizedBox(height: 12),
              ],
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
                                            tooltip: canPrint
                                              ? 'Print invoice'
                                              : 'Enable printer integration or PDF fallback in Settings',
                                            icon: const Icon(
                                                Icons.print_outlined),
                                            onPressed: canPrint
                                              ? () =>
                                                _printInvoice(context, ref, row)
                                              : null,
                                          ),
                                          IconButton(
                                            tooltip: _isReturnCompleted(
                                                    row.paymentStatus)
                                                ? 'Invoice already returned'
                                                : 'Sales return / refund',
                                            icon: const Icon(
                                                Icons.assignment_return_outlined),
                                            onPressed: _isReturnCompleted(
                                                    row.paymentStatus)
                                                ? null
                                                : () => _processSaleReturn(
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

  Widget _lastPrintModeBanner(WidgetRef ref, String mode) {
    final isThermal = mode == 'Thermal';
    final color = isThermal ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(isThermal ? Icons.bluetooth_connected : Icons.picture_as_pdf,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last print mode: $mode',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              ref.read(_salesShowLastPrintBannerProvider.notifier).state =
                  false;
            },
            icon: Icon(Icons.close_rounded, color: color),
          ),
        ],
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

  bool _isReturnCompleted(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'returned' || normalized == 'refunded';
  }

  Future<void> _processSaleReturn(
      BuildContext context, WidgetRef ref, SalesReportRow row) async {
    final messenger = ScaffoldMessenger.of(context);

    final items = await _loadReturnableItems(ref, row.saleId);
    if (items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No returnable quantities left for this invoice.')),
      );
      return;
    }

    final result = await _showPartialReturnDialog(context, row.invoiceNo, items);
    if (result == null) return;

    try {
      final returnResult = await ref
          .read(salesRepositoryProvider)
          .processPartialSaleReturn(
            saleId: row.saleId,
            lines: result.lines,
            reason: result.reason,
            refundMethod: result.refundMethod,
          );

      ref.invalidate(salesReportProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(creditLedgerProvider);

      if (!context.mounted) return;
      final returnedText =
          'Returned items worth ${formatInr(returnResult.returnedAmount)}.';
      final refundText = returnResult.refundAmount > 0
          ? 'Refunded ${formatInr(returnResult.refundAmount)} via ${result.refundMethod.toUpperCase()}.'
          : 'No monetary refund needed for this return.';
      final stockText =
          returnResult.stockRestocked ? ' Stock restocked.' : ' Stock tracking is disabled.';
      messenger.showSnackBar(
        SnackBar(content: Text('Sale return completed. $returnedText $refundText$stockText')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to process sale return: $e')),
      );
    }
  }

  Future<List<_ReturnableLine>> _loadReturnableItems(
      WidgetRef ref, int saleId) async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) return const [];
    final fs = ref.read(firestoreProvider);

    final itemSnap = await storeCollection(fs, storeId, 'sale_items')
        .where('saleId', isEqualTo: saleId)
        .get();
    if (itemSnap.docs.isEmpty) return const [];

    final saleItems = itemSnap.docs.map(saleItemFromDoc).toList(growable: false);
    final productIds = saleItems.map((i) => i.productId).toSet().toList(growable: false);
    final productSnap = await storeCollection(fs, storeId, 'products').get();
    final productById = {
      for (final d in productSnap.docs) (int.tryParse(d.id) ?? 0): productFromDoc(d),
    };

    final rows = <_ReturnableLine>[];
    for (final doc in itemSnap.docs) {
      final item = saleItemFromDoc(doc);
      if (!productIds.contains(item.productId)) continue;
      final returnedQty = fsNum(doc.data()['returnedQty']);
      final remainingQty = (item.quantity - returnedQty).clamp(0, item.quantity).toDouble();
      if (remainingQty <= 0) continue;
      rows.add(
        _ReturnableLine(
          saleItemId: item.id,
          productName: productById[item.productId]?.name ?? 'Product #${item.productId}',
          soldQty: item.quantity,
          alreadyReturnedQty: returnedQty,
          remainingQty: remainingQty,
        ),
      );
    }

    rows.sort((a, b) {
      final byQty = b.remainingQty.compareTo(a.remainingQty);
      if (byQty != 0) return byQty;
      return a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
    });

    return rows;
  }

  Future<_PartialReturnDialogResult?> _showPartialReturnDialog(
      BuildContext context, String invoiceNo, List<_ReturnableLine> items) async {
    final reasonCtrl = TextEditingController();
    var refundMethod = 'cash';
    final qtyCtrls = [
      for (final _ in items) TextEditingController(text: '0'),
    ];
    final qtyFocusNodes = [
      for (final _ in items) FocusNode(),
    ];

    final response = await showDialog<_PartialReturnDialogResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Return / Refund - $invoiceNo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        for (var i = 0; i < qtyCtrls.length; i++) {
                          qtyCtrls[i].text = items[i].remainingQty
                              .toStringAsFixed(items[i].remainingQty % 1 == 0 ? 0 : 2);
                        }
                        setState(() {});
                      },
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: const Text('Return all remaining'),
                    ),
                  ),
                  SizedBox(
                    width: 520,
                    height: 220,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final line = items[index];
                        final soldText = line.soldQty
                            .toStringAsFixed(line.soldQty % 1 == 0 ? 0 : 2);
                        final returnedText = line.alreadyReturnedQty.toStringAsFixed(
                            line.alreadyReturnedQty % 1 == 0 ? 0 : 2);
                        final remainingText = line.remainingQty
                            .toStringAsFixed(line.remainingQty % 1 == 0 ? 0 : 2);
                        final isFullyReturned = line.remainingQty <= 0.0001;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.productName,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        Chip(
                                          visualDensity: VisualDensity.compact,
                                          label: Text('Sold: $soldText'),
                                        ),
                                        Chip(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor:
                                              Colors.orange.withOpacity(0.12),
                                          side: BorderSide(
                                            color: Colors.orange.withOpacity(0.35),
                                          ),
                                          label: Text(
                                            'Returned: $returnedText',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Chip(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: isFullyReturned
                                              ? Colors.red.withOpacity(0.12)
                                              : Colors.green.withOpacity(0.12),
                                          side: BorderSide(
                                            color: (isFullyReturned
                                                    ? Colors.red
                                                    : Colors.green)
                                                .withOpacity(0.35),
                                          ),
                                          label: Text(
                                            'Remaining: $remainingText',
                                            style: TextStyle(
                                              color: isFullyReturned
                                                  ? Colors.red
                                                  : Colors.green,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 90,
                                child: GestureDetector(
                                  onLongPress: () {
                                    qtyCtrls[index].text = '0';
                                    qtyCtrls[index].selection = const TextSelection(
                                      baseOffset: 0,
                                      extentOffset: 1,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Reset ${items[index].productName} to 0',
                                        ),
                                        duration: const Duration(milliseconds: 900),
                                      ),
                                    );
                                  },
                                  child: TextField(
                                    controller: qtyCtrls[index],
                                    focusNode: qtyFocusNodes[index],
                                    autofocus: index == 0,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(decimal: true),
                                    onTap: () {
                                      final raw = qtyCtrls[index].text.trim();
                                      final parsed = double.tryParse(raw) ?? 0;
                                      if (parsed <= 0) {
                                        final next = items[index].remainingQty
                                            .toStringAsFixed(
                                                items[index].remainingQty % 1 == 0 ? 0 : 2);
                                        qtyCtrls[index].text = next;
                                        qtyCtrls[index].selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset: next.length,
                                        );
                                      }
                                    },
                                    textInputAction: index == qtyCtrls.length - 1
                                        ? TextInputAction.done
                                        : TextInputAction.next,
                                    onSubmitted: (_) {
                                      if (index < qtyFocusNodes.length - 1) {
                                        FocusScope.of(context)
                                            .requestFocus(qtyFocusNodes[index + 1]);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      labelText: 'Return Qty',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Return reason *',
                      hintText: 'Damaged item, billing error, customer cancellation...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: refundMethod,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Refund method',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => refundMethod = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final reason = reasonCtrl.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter return reason.'),
                        ),
                      );
                      return;
                    }

                    final lines = <SaleReturnLineRequest>[];
                    for (var i = 0; i < items.length; i++) {
                      final raw = qtyCtrls[i].text.trim();
                      final qty = double.tryParse(raw) ?? 0;
                      if (qty <= 0) continue;
                      if (qty > items[i].remainingQty + 0.0001) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Qty for ${items[i].productName} exceeds remaining (${items[i].remainingQty.toStringAsFixed(2)}).',
                            ),
                          ),
                        );
                        return;
                      }
                      lines.add(
                        SaleReturnLineRequest(
                          saleItemId: items[i].saleItemId,
                          quantity: qty,
                        ),
                      );
                    }
                    if (lines.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Enter return quantity for at least one item.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      ctx,
                      _PartialReturnDialogResult(
                        reason: reason,
                        refundMethod: refundMethod,
                        lines: lines,
                      ),
                    );
                  },
                  child: const Text('Confirm Return'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonCtrl.dispose();
    for (final c in qtyCtrls) {
      c.dispose();
    }
    for (final n in qtyFocusNodes) {
      n.dispose();
    }
    return response;
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

      final branding =
          ref.read(invoiceBrandingProvider).valueOrNull ??
              const InvoiceBranding.defaults();
      final printerConfig =
          ref.read(printerConfigProvider).valueOrNull ??
              const PrinterConfig.defaults();
      final shopName = branding.displayName.isNotEmpty
          ? branding.displayName
          : (ref.read(storeSessionProvider)?.storeName ?? 'Pocket POS');
      final printableItems = saleItems
          .map(
            (item) => (
              name:
                  '${productNameById[item.productId] ?? 'Product #${item.productId}'} (GST ${item.taxPercent.toStringAsFixed(item.taxPercent % 1 == 0 ? 0 : 2)}%)',
              qty: item.quantity,
              discountAmount: item.discountAmount,
              netAmount: item.lineTotal,
            ),
          )
          .toList(growable: false);

      if (printerConfig.enabled) {
        try {
          await ref.read(printerServiceProvider).printInvoice(
                config: printerConfig,
                branding: branding,
                fallbackShopName: shopName,
                invoiceNo: row.invoiceNo,
                items: printableItems,
                grandTotal: row.grandTotal,
              );
          ref.read(_salesLastPrintModeProvider.notifier).state = 'Thermal';
          ref.read(_salesShowLastPrintBannerProvider.notifier).state = true;
          return;
        } catch (e) {
          if (!printerConfig.allowPdfFallback) {
            final msg = ref.read(printerServiceProvider).toUserMessage(e);
            throw Exception(msg);
          }
          if (context.mounted) {
            final msg = ref.read(printerServiceProvider).toUserMessage(e);
            messenger.showSnackBar(
              SnackBar(content: Text('$msg Falling back to PDF.')),
            );
          }
        }
      }

      if (!printerConfig.allowPdfFallback) {
        throw Exception(
          'Printer integration is disabled and PDF fallback is off in Settings.',
        );
      }

      await _printPdfInvoice(
        invoiceNo: row.invoiceNo,
        branding: branding,
        shopName: shopName,
        items: printableItems,
        grandTotal: row.grandTotal,
        refundEntries: await _loadRefundEntries(ref, row.saleId),
      );
      ref.read(_salesLastPrintModeProvider.notifier).state = 'PDF fallback';
      ref.read(_salesShowLastPrintBannerProvider.notifier).state = true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to print invoice: $e')),
      );
    }
  }

  Future<void> _printPdfInvoice({
    required String invoiceNo,
    required InvoiceBranding branding,
    required String shopName,
    required List<
            ({
              String name,
              double qty,
              double discountAmount,
              double netAmount
            })>
        items,
    required double grandTotal,
    List<
            ({
              String method,
              double amount,
              DateTime paidAt,
              String? referenceNo
            })>
        refundEntries = const [],
  }) async {
    final bytes = await ReceiptPdfService().generateSimpleReceipt(
      shopName: shopName,
      invoiceNo: invoiceNo,
      branding: branding,
      items: items,
      grandTotal: grandTotal,
      refundEntries: refundEntries,
    );

    final pdfBytes = Uint8List.fromList(bytes);
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '$invoiceNo.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
      );
    }
  }

  Future<List<
      ({
        String method,
        double amount,
        DateTime paidAt,
        String? referenceNo
      })>> _loadRefundEntries(WidgetRef ref, int saleId) async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) return const [];

    final fs = ref.read(firestoreProvider);
    final snap = await storeCollection(fs, storeId, 'payments')
        .where('saleId', isEqualTo: saleId)
        .get();

    final entries = <
        ({
          String method,
          double amount,
          DateTime paidAt,
          String? referenceNo
        })>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount >= 0) continue;
      entries.add((
        method: (data['method'] as String?) ?? 'refund',
        amount: amount.abs(),
        paidAt: (data['paidAt'] as dynamic)?.toDate() as DateTime? ?? DateTime.now(),
        referenceNo: data['referenceNo'] as String?,
      ));
    }
    entries.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return entries;
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

class _ReturnableLine {
  const _ReturnableLine({
    required this.saleItemId,
    required this.productName,
    required this.soldQty,
    required this.alreadyReturnedQty,
    required this.remainingQty,
  });

  final int saleItemId;
  final String productName;
  final double soldQty;
  final double alreadyReturnedQty;
  final double remainingQty;
}

class _PartialReturnDialogResult {
  const _PartialReturnDialogResult({
    required this.reason,
    required this.refundMethod,
    required this.lines,
  });

  final String reason;
  final String refundMethod;
  final List<SaleReturnLineRequest> lines;
}
