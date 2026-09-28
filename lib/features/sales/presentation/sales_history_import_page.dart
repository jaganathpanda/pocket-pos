import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/utilities/csv_file_export.dart';
import '../../store/presentation/store_auth_controller.dart';

class SalesHistoryImportPage extends ConsumerStatefulWidget {
  const SalesHistoryImportPage({super.key});

  @override
  ConsumerState<SalesHistoryImportPage> createState() =>
      _SalesHistoryImportPageState();
}

class _SalesHistoryImportPageState
    extends ConsumerState<SalesHistoryImportPage> {
  List<_HistoryInvoice>? _invoices;
  bool _busy = false;

  static const _headers = [
    'invoiceNo',
    'soldAt',
    'customerMobile',
    'productCode',
    'quantity',
    'unitPrice',
    'discountAmount',
    'taxPercent',
    'paymentMethod',
    'amountPaid',
  ];

  Future<void> _downloadTemplate() async {
    try {
      await saveCsvFile(
        fileName: 'sales_history_import_template.csv',
        content: const CsvEncoder().convert([
          _headers,
          [
            'OLD-1001',
            '2024-03-12',
            '9876543210',
            'PRD-EXISTING-CODE',
            '2',
            '100',
            '0',
            '5',
            'cash',
            '210',
          ],
        ]),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales history template downloaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save sales template: $e')),
      );
    }
  }

  Future<void> _pickCsv() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      final bytes = file?.files.single.bytes;
      if (bytes == null) throw Exception('No CSV file selected');
      final preview = await _buildPreview(
        utf8.decode(bytes, allowMalformed: true),
      );
      if (!mounted) return;
      setState(() => _invoices = preview);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales history preview failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<_HistoryInvoice>> _buildPreview(String content) async {
    final csvRows = const CsvDecoder().convert(content);
    if (csvRows.isEmpty) throw Exception('CSV is empty');
    final headers = csvRows.first.map((value) => '$value'.trim()).toList();
    final missing = _headers.where((header) => !headers.contains(header));
    if (missing.isNotEmpty) {
      throw Exception('Missing columns: ${missing.join(', ')}');
    }

    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) throw Exception('No active store');
    final db = ref.read(firestoreProvider);
    final customers = await storeCollection(db, storeId, 'customers').get();
    final products = await storeCollection(db, storeId, 'products').get();
    final sales = await storeCollection(db, storeId, 'sales').get();
    final customersByMobile = <String, int>{};
    for (final doc in customers.docs) {
      final mobile = _normalizeMobile(doc.data()['mobile'] as String? ?? '');
      final id = int.tryParse(doc.id);
      if (mobile.isNotEmpty && id != null) customersByMobile[mobile] = id;
    }
    final productsByCode = <String, int>{};
    for (final doc in products.docs) {
      final code = (doc.data()['productCode'] as String? ?? '').trim();
      final id = int.tryParse(doc.id);
      if (code.isNotEmpty && id != null) {
        productsByCode[code.toLowerCase()] = id;
      }
    }
    final existingInvoices = sales.docs
        .map((doc) =>
            (doc.data()['invoiceNo'] as String? ?? '').trim().toLowerCase())
        .where((invoice) => invoice.isNotEmpty)
        .toSet();
    final grouped = <String, _HistoryInvoice>{};

    for (var index = 1; index < csvRows.length; index++) {
      final raw = csvRows[index];
      if (raw.every((cell) => '$cell'.trim().isEmpty)) continue;
      String value(String key) {
        final column = headers.indexOf(key);
        return column < raw.length ? '${raw[column]}'.trim() : '';
      }

      final invoiceNo = value('invoiceNo');
      final soldAtText = value('soldAt');
      final mobile = _normalizeMobile(value('customerMobile'));
      final productCode = value('productCode');
      final quantity = double.tryParse(value('quantity'));
      final unitPrice = double.tryParse(value('unitPrice'));
      final discountText = value('discountAmount');
      final parsedDiscount = double.tryParse(discountText);
      final discount = discountText.isEmpty ? 0.0 : parsedDiscount ?? 0.0;
      final taxPercent = double.tryParse(value('taxPercent'));
      final paymentMethod = value('paymentMethod').toLowerCase();
      final amountPaid = double.tryParse(value('amountPaid'));
      final soldAt = DateTime.tryParse(soldAtText);
      final errors = <String>[];

      if (invoiceNo.isEmpty) errors.add('Invoice number is required');
      if (soldAt == null) errors.add('Invalid date; use yyyy-MM-dd');
      if (mobile.length != 10 || !RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
        errors.add('Invalid customer mobile');
      } else if (!customersByMobile.containsKey(mobile)) {
        errors.add('Customer not found; import customers first');
      }
      if (productCode.isEmpty) {
        errors.add('Product code is required');
      } else if (!productsByCode.containsKey(productCode.toLowerCase())) {
        errors.add('Product code not found in catalog');
      }
      if (quantity == null || quantity <= 0) errors.add('Quantity must be > 0');
      if (unitPrice == null || unitPrice < 0) {
        errors.add('Unit price must be >= 0');
      }
      if (parsedDiscount == null && discountText.isNotEmpty) {
        errors.add('Discount must be a number >= 0');
      } else if (discount < 0) {
        errors.add('Discount must be >= 0');
      }
      if (quantity != null &&
          unitPrice != null &&
          discount > quantity * unitPrice) {
        errors.add('Discount cannot exceed the line amount');
      }
      if (taxPercent == null || taxPercent < 0 || taxPercent > 100) {
        errors.add('Tax must be between 0 and 100');
      }
      if (paymentMethod.isEmpty) errors.add('Payment method is required');
      if (amountPaid == null || amountPaid < 0) {
        errors.add('Amount paid must be >= 0');
      }

      final key = invoiceNo.toLowerCase();
      final invoice = grouped.putIfAbsent(
        key,
        () => _HistoryInvoice(
          invoiceNo: invoiceNo,
          soldAt: soldAt,
          customerMobile: mobile,
          customerId: customersByMobile[mobile],
          paymentMethod: paymentMethod,
          amountPaid: amountPaid,
        ),
      );
      invoice.errors.addAll(errors.map((error) => 'Row ${index + 1}: $error'));

      if (invoice.soldAt != soldAt ||
          invoice.customerMobile != mobile ||
          invoice.paymentMethod != paymentMethod ||
          invoice.amountPaid != amountPaid) {
        invoice.errors.add('Invoice rows have inconsistent order details');
      }
      if (invoiceNo.trim() != invoice.invoiceNo) {
        invoice.errors.add('Invoice number differs only by letter case');
      }
      if (quantity != null &&
          unitPrice != null &&
          discount >= 0 &&
          taxPercent != null) {
        invoice.lines.add(_HistoryLine(
          productId: productsByCode[productCode.toLowerCase()],
          quantity: quantity,
          unitPrice: unitPrice,
          discount: discount,
          taxPercent: taxPercent,
        ));
      }
    }

    if (grouped.isEmpty) throw Exception('No sales rows found');
    for (final invoice in grouped.values) {
      if (existingInvoices.contains(invoice.invoiceNo.toLowerCase())) {
        invoice.errors.add('Invoice number already exists');
      }
      if (invoice.lines.length > 498) {
        invoice.errors.add('Invoice has too many item rows to import');
      }
      if (invoice.amountPaid != null &&
          invoice.amountPaid! > invoice.grandTotal) {
        invoice.errors.add('Amount paid exceeds invoice total');
      }
    }
    return grouped.values.toList();
  }

  String _normalizeMobile(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  Future<void> _import() async {
    final invoices = _invoices;
    final storeId = ref.read(activeStoreIdProvider);
    if (invoices == null || storeId == null || storeId.isEmpty) return;
    final valid = invoices.where((invoice) => invoice.errors.isEmpty).toList();
    if (valid.isEmpty) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(firestoreProvider);
      final sales = storeCollection(db, storeId, 'sales');
      final saleItems = storeCollection(db, storeId, 'sale_items');
      final payments = storeCollection(db, storeId, 'payments');

      for (final invoice in valid) {
        final saleId = newIntId();
        final subTotal = invoice.subTotal;
        final discountTotal = invoice.discountTotal;
        final taxTotal = invoice.taxTotal;
        final grandTotal = invoice.grandTotal;
        final amountPaid = invoice.amountPaid!;
        final paymentStatus = amountPaid >= grandTotal
            ? 'paid'
            : amountPaid > 0
                ? 'partial'
                : 'credit';
        final batch = db.batch();
        batch.set(sales.doc('$saleId'), {
          'cartId': null,
          'invoiceNo': invoice.invoiceNo,
          'customerId': invoice.customerId,
          'posCounterId': null,
          'warehouseId': null,
          'subTotal': subTotal,
          'discountTotal': discountTotal,
          'billDiscountPercent': 0,
          'taxTotal': taxTotal,
          'grandTotal': grandTotal,
          'paymentStatus': paymentStatus,
          'soldAt': Timestamp.fromDate(invoice.soldAt!),
          'importedHistory': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        for (final line in invoice.lines) {
          final taxable = _roundMoney(
            _roundMoney(line.quantity * line.unitPrice) -
                _roundMoney(line.discount),
          );
          final lineTotal = _roundMoney(
            taxable + _roundMoney(taxable * line.taxPercent / 100),
          );
          batch.set(saleItems.doc('${newIntId()}'), {
            'saleId': saleId,
            'productId': line.productId,
            'variantId': null,
            'quantity': line.quantity,
            'unitPrice': line.unitPrice,
            'discountAmount': line.discount,
            'taxPercent': line.taxPercent,
            'lineTotal': lineTotal,
          });
        }
        batch.set(payments.doc('${newIntId()}'), {
          'saleId': saleId,
          'method': invoice.paymentMethod,
          'amount': amountPaid,
          'referenceNo': null,
          'paidAt': Timestamp.fromDate(invoice.soldAt!),
          'importedHistory': true,
        });
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${valid.length} historical orders.')),
      );
      setState(() => _invoices = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales history import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _invoices;
    final validCount =
        invoices?.where((invoice) => invoice.errors.isEmpty).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Sales History Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Import after customers and products exist. Each CSV row is one order item; repeat order details for every item on an invoice. Historical imports do not change stock.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Required columns: invoiceNo, soldAt, customerMobile, productCode, quantity, unitPrice, discountAmount, taxPercent, paymentMethod, amountPaid. Dates use yyyy-MM-dd.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _downloadTemplate,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download Template'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _pickCsv,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Choose CSV'),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (invoices != null) ...[
            const SizedBox(height: 20),
            Text('Preview · $validCount of ${invoices.length} valid orders'),
            const SizedBox(height: 8),
            for (final invoice in invoices)
              Card(
                child: ListTile(
                  leading: Icon(
                    invoice.errors.isEmpty
                        ? Icons.receipt_long_outlined
                        : Icons.error_outline_rounded,
                    color: invoice.errors.isEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                      '${invoice.invoiceNo} · ${invoice.lines.length} items'),
                  subtitle: Text(
                    invoice.errors.isEmpty
                        ? '${invoice.customerMobile} · ${invoice.soldAt!.toIso8601String().substring(0, 10)} · Total ${invoice.grandTotal.toStringAsFixed(2)}'
                        : invoice.errors.toSet().join('; '),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || validCount == 0 ? null : _import,
              icon: const Icon(Icons.check_rounded),
              label: Text('Import $validCount Orders'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryInvoice {
  _HistoryInvoice({
    required this.invoiceNo,
    required this.soldAt,
    required this.customerMobile,
    required this.customerId,
    required this.paymentMethod,
    required this.amountPaid,
  });

  final String invoiceNo;
  final DateTime? soldAt;
  final String customerMobile;
  final int? customerId;
  final String paymentMethod;
  final double? amountPaid;
  final List<_HistoryLine> lines = [];
  final List<String> errors = [];

  double get subTotal => lines.fold<double>(
        0,
        (total, line) => total + _roundMoney(line.quantity * line.unitPrice),
      );

  double get discountTotal => lines.fold<double>(
      0, (total, line) => total + _roundMoney(line.discount));

  double get taxTotal => lines.fold<double>(
        0,
        (total, line) {
          final taxable = _roundMoney(
            _roundMoney(line.quantity * line.unitPrice) -
                _roundMoney(line.discount),
          );
          return total + _roundMoney(taxable * line.taxPercent / 100);
        },
      );

  double get grandTotal => _roundMoney(subTotal - discountTotal + taxTotal);
}

double _roundMoney(double value) => double.parse(value.toStringAsFixed(2));

class _HistoryLine {
  const _HistoryLine({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.taxPercent,
  });

  final int? productId;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double taxPercent;
}
