import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class CustomerOrdersPage extends ConsumerStatefulWidget {
  const CustomerOrdersPage({required this.customerId, super.key});

  final int customerId;

  @override
  ConsumerState<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends ConsumerState<CustomerOrdersPage> {
  final _itemsPerPage = 10;
  int _currentPage = 0;
  late Future<List<({Sale sale, int itemCount})>> _ordersFuture;
  String? _lastPrintMode;
  bool _showLastPrintBanner = false;

  Future<void> _printSale(Sale sale) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final invoice =
          await ref.read(customerRepositoryProvider).getOrderDetails(sale.id);
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
        refundEntries: await _loadRefundEntries(sale.id),
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
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = ref.read(customerRepositoryProvider).getCustomerOrders(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    final printerConfig =
      ref.watch(printerConfigProvider).valueOrNull ??
        const PrinterConfig.defaults();
    final canPrint = printerConfig.enabled || printerConfig.allowPdfFallback;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Orders'),
        elevation: 0,
      ),
      body: FutureBuilder<List<({Sale sale, int itemCount})>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Error loading orders'));
          }

          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('No orders found'));
          }

          final totalPages = (orders.length / _itemsPerPage).ceil();
          final startIndex = _currentPage * _itemsPerPage;
          final endIndex = (startIndex + _itemsPerPage).clamp(0, orders.length);
          final paginatedOrders = orders.sublist(startIndex, endIndex);

          return Column(
            children: [
              if (_lastPrintMode != null && _showLastPrintBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: _lastPrintModeBanner(_lastPrintMode!),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: paginatedOrders.length,
                  itemBuilder: (context, index) {
                    final order = paginatedOrders[index];
                    final sale = order.sale;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('Invoice ${sale.invoiceNo}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy hh:mm a').format(sale.soldAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${order.itemCount} items - ${formatInr(sale.grandTotal)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: canPrint
                                  ? 'Print invoice'
                                : 'Enable printer integration or PDF fallback in Settings',
                              icon: const Icon(Icons.print_outlined),
                              onPressed: canPrint
                                  ? () => _printSale(sale)
                                  : null,
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: () => context.push('/invoice/${sale.id}'),
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _currentPage > 0
                            ? () => setState(() => _currentPage--)
                            : null,
                      ),
                      Text('Page ${_currentPage + 1} of $totalPages'),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() => _currentPage++)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
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
      })>> _loadRefundEntries(int saleId) async {
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
}
