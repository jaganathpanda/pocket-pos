import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/models/invoice_branding.dart';
import '../../../core/models/printer_config.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utilities/money.dart';
import '../../store/presentation/store_auth_controller.dart';

class CustomerInvoiceDetailPage extends ConsumerStatefulWidget {
  const CustomerInvoiceDetailPage({required this.saleId, super.key});

  final int saleId;

  @override
  ConsumerState<CustomerInvoiceDetailPage> createState() => _CustomerInvoiceDetailPageState();
}

class _CustomerInvoiceDetailPageState extends ConsumerState<CustomerInvoiceDetailPage> {
  late Future<({Sale sale, List<SaleItem> items})> _invoiceFuture;
  late Future<Customer?> _customerFuture;
  late Future<List<Product>> _productsFuture;
  late Future<Map<int, double>> _returnedQtyBySaleItemFuture;
  late Future<({
    double totalCollected,
    double totalRefund,
    double netPaid,
    List<_RefundEntry> entries
  })> _refundSummaryFuture;
  String? _lastPrintMode;
  bool _showLastPrintBanner = false;

  Future<void> _printInvoice() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final invoice = await _invoiceFuture;
      final sale = invoice.sale;
      final items = invoice.items;

      final productIds = items.map((i) => i.productId).toSet().toList();
      final products = await ref.read(productRepositoryProvider).getByIds(productIds);
      final productNameById = {for (final p in products) p.id: p.name};

      final branding =
          ref.read(invoiceBrandingProvider).valueOrNull ??
              const InvoiceBranding.defaults();
      final printerConfig =
          ref.read(printerConfigProvider).valueOrNull ??
              const PrinterConfig.defaults();
      final shopName = branding.displayName.isNotEmpty
          ? branding.displayName
          : (ref.read(storeSessionProvider)?.storeName ?? 'Pocket POS');

      final printableItems = items
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
                invoiceNo: sale.invoiceNo,
                items: printableItems,
                grandTotal: sale.grandTotal,
              );
          if (mounted) {
            setState(() {
              _lastPrintMode = 'Thermal';
              _showLastPrintBanner = true;
            });
          }
          return;
        } catch (e) {
          if (!printerConfig.allowPdfFallback) {
            final msg = ref.read(printerServiceProvider).toUserMessage(e);
            throw Exception(msg);
          }
          if (mounted) {
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
        invoiceNo: sale.invoiceNo,
        branding: branding,
        shopName: shopName,
        items: printableItems,
        grandTotal: sale.grandTotal,
        refundEntries: [
          for (final e in (await _refundSummaryFuture).entries)
            (
              method: e.method,
              amount: e.amount,
              paidAt: e.paidAt,
              referenceNo: e.referenceNo,
            ),
        ],
      );
      if (mounted) {
        setState(() {
          _lastPrintMode = 'PDF fallback';
          _showLastPrintBanner = true;
        });
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to print invoice: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final repo = ref.read(customerRepositoryProvider);
    final products = ref.read(productRepositoryProvider);

    _invoiceFuture = repo.getOrderDetails(widget.saleId);
    _returnedQtyBySaleItemFuture =
        _invoiceFuture.then((invoice) => _loadReturnedQtyBySaleItem(invoice.sale.id));
    _refundSummaryFuture =
      _invoiceFuture.then((invoice) => _loadRefundSummary(invoice.sale.id));

    _invoiceFuture.then((invoice) {
      _customerFuture = invoice.sale.customerId != null
          ? repo.getById(invoice.sale.customerId!)
          : Future.value(null);

      final productIds = invoice.items.map((i) => i.productId).toSet().toList();
      _productsFuture = products.getByIds(productIds);
    });
  }

  Future<Map<int, double>> _loadReturnedQtyBySaleItem(int saleId) async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) return const {};

    final fs = ref.read(firestoreProvider);
    final snap = await storeCollection(fs, storeId, 'sale_items')
        .where('saleId', isEqualTo: saleId)
        .get();

    final result = <int, double>{};
    for (final doc in snap.docs) {
      final itemId = int.tryParse(doc.id);
      if (itemId == null) continue;
      result[itemId] = (doc.data()['returnedQty'] as num?)?.toDouble() ?? 0.0;
    }
    return result;
  }

  Future<({
    double totalCollected,
    double totalRefund,
    double netPaid,
    List<_RefundEntry> entries
  })> _loadRefundSummary(
      int saleId) async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) {
      return (
        totalCollected: 0.0,
        totalRefund: 0.0,
        netPaid: 0.0,
        entries: const <_RefundEntry>[]
      );
    }

    final fs = ref.read(firestoreProvider);
    final snap = await storeCollection(fs, storeId, 'payments')
        .where('saleId', isEqualTo: saleId)
        .get();

    final entries = <_RefundEntry>[];
    var totalCollected = 0.0;
    var total = 0.0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount >= 0) {
        totalCollected += amount;
        continue;
      }

      final refundAmount = amount.abs();
      total += refundAmount;
      entries.add(
        _RefundEntry(
          amount: refundAmount,
          method: (data['method'] as String?) ?? 'refund',
          paidAt: (data['paidAt'] as dynamic)?.toDate() as DateTime? ?? DateTime.now(),
          referenceNo: data['referenceNo'] as String?,
        ),
      );
    }

    entries.sort((a, b) => b.paidAt.compareTo(a.paidAt));
    return (
      totalCollected: totalCollected,
      totalRefund: total,
      netPaid: (totalCollected - total).clamp(0, 999999999).toDouble(),
      entries: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final printerConfig =
      ref.watch(printerConfigProvider).valueOrNull ??
        const PrinterConfig.defaults();
    final canPrint = printerConfig.enabled || printerConfig.allowPdfFallback;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: canPrint
                ? 'Print invoice'
                : 'Enable printer integration or PDF fallback in Settings',
            icon: const Icon(Icons.print_outlined),
            onPressed: canPrint ? _printInvoice : null,
          ),
        ],
      ),
      body: FutureBuilder<({Sale sale, List<SaleItem> items})>(
        future: _invoiceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Invoice not found'));
          }

          final invoice = snapshot.data!;
          final sale = invoice.sale;
          final items = invoice.items;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_lastPrintMode != null && _showLastPrintBanner) ...[
                  _lastPrintModeBanner(_lastPrintMode!),
                  const SizedBox(height: 12),
                ],
                // Invoice Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice ${sale.invoiceNo}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        _headerRow('Date', DateFormat('dd MMM yyyy hh:mm a').format(sale.soldAt)),
                        _headerRow('Payment Status', sale.paymentStatus.toUpperCase()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Customer Info
                if (sale.customerId != null)
                  FutureBuilder<Customer?>(
                    future: _customerFuture,
                    builder: (context, custSnapshot) {
                      if (!custSnapshot.hasData || custSnapshot.data == null) {
                        return const SizedBox.shrink();
                      }
                      final customer = custSnapshot.data!;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              _headerRow('Name', customer.name),
                              _headerRow('Mobile', customer.mobile ?? 'N/A'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),

                // Products Table
                Text(
                  'Items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Product>>(
                  future: _productsFuture,
                  builder: (context, prodSnapshot) {
                    final products = prodSnapshot.data ?? [];
                    final productNameById = {for (final p in products) p.id: p.name};

                    return FutureBuilder<Map<int, double>>(
                      future: _returnedQtyBySaleItemFuture,
                      builder: (context, returnedSnapshot) {
                        final returnedByItemId = returnedSnapshot.data ?? const <int, double>{};

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            border: TableBorder.all(color: Colors.grey.shade300),
                            columnWidths: const {
                              0: FixedColumnWidth(220),
                              1: FixedColumnWidth(70),
                              2: FixedColumnWidth(90),
                              3: FixedColumnWidth(90),
                              4: FixedColumnWidth(100),
                              5: FixedColumnWidth(100),
                            },
                            children: [
                              // Header Row
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade200),
                                children: [
                                  _tableCell('Item', isHeader: true),
                                  _tableCell('QTY', isHeader: true, align: TextAlign.right),
                                  _tableCell('Returned', isHeader: true, align: TextAlign.right),
                                  _tableCell('Returnable', isHeader: true, align: TextAlign.right),
                                  _tableCell('Disc. Amt', isHeader: true, align: TextAlign.right),
                                  _tableCell('Net.amt', isHeader: true, align: TextAlign.right),
                                ],
                              ),
                              // Data Rows
                              ...items.map(
                                (item) {
                                  final returnedQty = returnedByItemId[item.id] ?? 0;
                                  final returnableQty =
                                      (item.quantity - returnedQty).clamp(0, item.quantity).toDouble();
                                  return TableRow(
                                    children: [
                                      _tableCell(productNameById[item.productId] ?? 'Product #${item.productId}'),
                                      _tableCell(
                                        _fmtQty(item.quantity),
                                        align: TextAlign.right,
                                      ),
                                      _tableCell(
                                        _fmtQty(returnedQty),
                                        align: TextAlign.right,
                                      ),
                                      _tableCell(
                                        _fmtQty(returnableQty),
                                        align: TextAlign.right,
                                      ),
                                      _tableCell(
                                        item.discountAmount.toStringAsFixed(2),
                                        align: TextAlign.right,
                                      ),
                                      _tableCell(
                                        item.lineTotal.toStringAsFixed(2),
                                        align: TextAlign.right,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Totals Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _totalsRow('Subtotal', sale.subTotal),
                        const SizedBox(height: 8),
                        _totalsRow('Discount', -sale.discountTotal),
                        const SizedBox(height: 8),
                        _totalsRow('Tax', sale.taxTotal),
                        const Divider(height: 16),
                        _totalsRow('Grand Total', sale.grandTotal, isTotal: true),
                        FutureBuilder<({
                          double totalCollected,
                          double totalRefund,
                          double netPaid,
                          List<_RefundEntry> entries
                        })>(
                          future: _refundSummaryFuture,
                          builder: (context, refundSnapshot) {
                            final summary = refundSnapshot.data;
                            if (summary == null || summary.totalRefund <= 0) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const SizedBox(height: 8),
                                _totalsRow('Refunded', -summary.totalRefund),
                                const SizedBox(height: 8),
                                _totalsRow(
                                  'Net Paid After Refund',
                                  summary.netPaid,
                                  isTotal: true,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<({
                  double totalCollected,
                  double totalRefund,
                  double netPaid,
                  List<_RefundEntry> entries
                })>(
                  future: _refundSummaryFuture,
                  builder: (context, refundSnapshot) {
                    final summary = refundSnapshot.data;
                    if (summary == null || summary.entries.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.replay_circle_filled_rounded,
                                    color: Colors.orange, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Refund Summary',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...summary.entries.map(
                              (entry) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${entry.method.toUpperCase()} • ${DateFormat('dd MMM yyyy hh:mm a').format(entry.paidAt)}'
                                        '${entry.referenceNo == null || entry.referenceNo!.isEmpty ? '' : ' • ${entry.referenceNo}'}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      '-${formatInr(entry.amount)}',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Refunded',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  formatInr(summary.totalRefund),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _totalsRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
        Text(
          formatInr(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            fontSize: isTotal ? 16 : 13,
            color: isTotal ? Colors.green.shade700 : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _fmtQty(double qty) {
    return qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
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

  Widget _lastPrintModeBanner(String mode) {
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
              setState(() => _showLastPrintBanner = false);
            },
            icon: Icon(Icons.close_rounded, color: color),
          ),
        ],
      ),
    );
  }
}

class _RefundEntry {
  const _RefundEntry({
    required this.amount,
    required this.method,
    required this.paidAt,
    required this.referenceNo,
  });

  final double amount;
  final String method;
  final DateTime paidAt;
  final String? referenceNo;
}
