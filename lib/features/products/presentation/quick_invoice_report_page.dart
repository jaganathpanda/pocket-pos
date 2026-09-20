import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/di/providers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utilities/money.dart';
import '../../store/presentation/store_auth_controller.dart';

class QuickInvoiceReportPage extends ConsumerStatefulWidget {
  const QuickInvoiceReportPage({super.key});

  @override
  ConsumerState<QuickInvoiceReportPage> createState() =>
      _QuickInvoiceReportPageState();
}

class _QuickInvoiceReportPageState extends ConsumerState<QuickInvoiceReportPage>
    with WidgetsBindingObserver {
  late DateTimeRange _dateRange;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(activeStoreIdProvider);
    if (storeId == null) {
      return const Scaffold(
        body: Center(child: Text('No store selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Invoice Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _pickDateRange,
            tooltip:
                'Date Range: ${DateFormat('dd MMM').format(_dateRange.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange.end)}',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by invoice #, customer name, phone...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (q) {
                setState(() => _searchQuery = q.toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: storeCollection(
                ref.read(firestoreProvider),
                storeId,
                'quick_invoices',
              )
                  .where('createdAt',
                      isGreaterThanOrEqualTo:
                          Timestamp.fromDate(_dateRange.start))
                  .where('createdAt',
                      isLessThanOrEqualTo: Timestamp.fromDate(
                        _dateRange.end.add(const Duration(days: 1)),
                      ))
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final invoiceNo =
                      (data['invoiceNo'] as String?)?.toLowerCase() ?? '';
                  final customerName =
                      (data['customerName'] as String?)?.toLowerCase() ?? '';
                  final customerPhone =
                      (data['customerPhone'] as String?)?.toLowerCase() ?? '';
                  return invoiceNo.contains(_searchQuery) ||
                      customerName.contains(_searchQuery) ||
                      customerPhone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No quick invoices found'),
                  );
                }

                double totalRevenue = 0;
                for (final doc in filtered) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalRevenue += (data['grandTotal'] as num?)?.toDouble() ?? 0;
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Invoices: ${filtered.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Total: ${formatInr(totalRevenue)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final invoiceNo = data['invoiceNo'] as String?;
                          final customerName =
                              data['customerName'] as String? ?? '-';
                          final customerPhone =
                              data['customerPhone'] as String? ?? '-';
                          final createdAt = data['createdAt'] as Timestamp?;
                          final grandTotal =
                              (data['grandTotal'] as num?)?.toDouble() ?? 0;
                          final items = (data['items'] as List?)?.length ?? 0;

                          return ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(invoiceNo ?? 'Unknown'),
                            subtitle: Text(
                              '${customerName.isNotEmpty ? customerName : 'Walk-in'} • $items items',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: SizedBox(
                              width: 260,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatInr(grandTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (createdAt != null)
                                        Text(
                                          DateFormat('dd MMM, HH:mm')
                                              .format(createdAt.toDate()),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.print_outlined,
                                        size: 18),
                                    tooltip: 'Print',
                                    onPressed: () => _printInvoice(data),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    tooltip: 'Edit',
                                    onPressed: () => context.push(
                                      '/quick-invoice?id=${doc.id}',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outlined,
                                        size: 18),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _deleteInvoice(context, doc.id),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () => _showInvoiceDetails(context, data),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(Map<String, dynamic> data) async {
    try {
      final storeId = ref.read(activeStoreIdProvider);
      if (storeId == null) return;

      final shopName = data['shopName'] as String? ?? 'Invoice';
      final invoiceNo = data['invoiceNo'] as String? ?? 'Unknown';
      final items = (data['items'] as List?) ?? [];

      final bytes = await ReceiptPdfService().generateClassicInvoice(
        shopName: shopName,
        invoiceNo: invoiceNo,
        invoiceDate:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        customerName: data['customerName'] as String? ?? '',
        customerAddress: data['customerAddress'] as String? ?? '',
        items: items
            .map(
              (item) => (
                description: item['description'] as String? ?? 'Item',
                unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0,
                qty: (item['quantity'] as num?)?.toDouble() ?? 0,
                lineTotal: (item['lineTotal'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList(growable: false),
        subTotal: (data['subTotal'] as num?)?.toDouble() ?? 0,
        total: (data['grandTotal'] as num?)?.toDouble() ?? 0,
        taxTotal: (data['taxTotal'] as num?)?.toDouble(),
        footerNote: data['note'] as String? ?? '',
      );

      if (!mounted) return;
      final pdfBytes = Uint8List.fromList(bytes);
      if (kIsWeb) {
        await Printing.sharePdf(bytes: pdfBytes, filename: '$invoiceNo.pdf');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice ready to print.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    }
  }

  Future<void> _deleteInvoice(BuildContext context, String invoiceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final storeId = ref.read(activeStoreIdProvider);
      if (storeId == null) return;

      await storeCollection(
        ref.read(firestoreProvider),
        storeId,
        'quick_invoices',
      ).doc(invoiceId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice deleted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  void _showInvoiceDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(data['invoiceNo'] as String? ?? 'Invoice'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(
                  'Customer',
                  data['customerName'] as String? ?? '-',
                ),
                _buildDetailRow(
                  'Phone',
                  data['customerPhone'] as String? ?? '-',
                ),
                _buildDetailRow(
                  'Address',
                  data['customerAddress'] as String? ?? '-',
                ),
                const Divider(),
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...(data['items'] as List?)?.map((item) {
                      final desc = item['description'] as String? ?? 'Item';
                      final qty = item['quantity'] as num? ?? 0;
                      final total = item['lineTotal'] as num? ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '$desc × $qty',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(formatInr(total.toDouble())),
                          ],
                        ),
                      );
                    }).toList() ??
                    [const Text('No items')],
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text(
                      formatInr(
                          (data['subTotal'] as num?)?.toDouble() ?? 0),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatInr(
                          (data['grandTotal'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if ((data['note'] as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Note:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(data['note'] as String? ?? ''),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
