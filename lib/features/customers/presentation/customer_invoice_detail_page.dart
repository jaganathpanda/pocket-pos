import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final repo = ref.read(customerRepositoryProvider);
    final products = ref.read(productRepositoryProvider);

    _invoiceFuture = repo.getOrderDetails(widget.saleId);

    _invoiceFuture.then((invoice) {
      _customerFuture = invoice.sale.customerId != null
          ? repo.getById(invoice.sale.customerId!)
          : Future.value(null);

      final productIds = invoice.items.map((i) => i.productId).toSet().toList();
      _productsFuture = products.getByIds(productIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        elevation: 0,
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

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columnWidths: const {
                          0: FixedColumnWidth(180),
                          1: FixedColumnWidth(60),
                          2: FixedColumnWidth(100),
                          3: FixedColumnWidth(100),
                        },
                        children: [
                          // Header Row
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade200),
                            children: [
                              _tableCell('Item', isHeader: true),
                              _tableCell('QTY', isHeader: true, align: TextAlign.right),
                              _tableCell('Disc. Amt', isHeader: true, align: TextAlign.right),
                              _tableCell('Net.amt', isHeader: true, align: TextAlign.right),
                            ],
                          ),
                          // Data Rows
                          ...items.map(
                            (item) => TableRow(
                              children: [
                                _tableCell(productNameById[item.productId] ?? 'Product #${item.productId}'),
                                _tableCell(
                                  item.quantity % 1 == 0 ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2),
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
                            ),
                          ),
                        ],
                      ),
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
                      ],
                    ),
                  ),
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
}
