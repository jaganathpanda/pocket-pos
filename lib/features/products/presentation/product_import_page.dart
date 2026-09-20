import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/utilities/csv_file_export.dart';
import '../../store/presentation/store_auth_controller.dart';

class ProductImportPage extends ConsumerStatefulWidget {
  const ProductImportPage({super.key});

  @override
  ConsumerState<ProductImportPage> createState() => _ProductImportPageState();
}

class _ProductImportPageState extends ConsumerState<ProductImportPage> {
  _ProductImportPreview? _preview;
  bool _loading = false;
  bool _applying = false;

  static const List<String> _headers = <String>[
    'name',
    'productCode',
    'barcode',
    'purchasePrice',
    'sellingPrice',
    'taxPercent',
    'unit',
    'hideFromQuickCheckout',
    'quickCheckoutEmoji',
    'expiryDate',
  ];

  String _templateCsv() {
    return const CsvEncoder().convert(<List<dynamic>>[
      _headers,
      <String>[
        'Tea',
        'PRD-TEA-001',
        '8900000000011',
        '8.50',
        '10.00',
        '5',
        'piece',
        'false',
        '☕',
        '2027-03-31',
      ],
      <String>[
        'Biscuit',
        'PRD-BIS-002',
        '8900000000028',
        '12.00',
        '15.00',
        '12',
        'piece',
        'true',
        '🍪',
        '',
      ],
    ]);
  }

  Future<void> _downloadTemplate() async {
    try {
      await saveCsvFile(
        fileName: 'product_import_template.csv',
        content: _templateCsv(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product template downloaded.')),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _templateCsv()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save file. Template copied to clipboard.'),
        ),
      );
    }
  }

  Future<void> _exportCurrentProducts() async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final snap = await storeCollection(
        ref.read(firestoreProvider),
        storeId,
        'products',
      ).where('isActive', isEqualTo: true).get();
      final rows = <List<dynamic>>[_headers];
      final docs = snap.docs.toList()
        ..sort((a, b) => ((a.data()['name'] as String?) ?? '')
            .toLowerCase()
            .compareTo(((b.data()['name'] as String?) ?? '').toLowerCase()));
      for (final doc in docs) {
        final data = doc.data();
        final rawExpiry = data['expiryDate'];
        final expiryDate = rawExpiry is Timestamp ? rawExpiry.toDate() : null;
        rows.add(<String>[
          (data['name'] as String?) ?? '',
          (data['productCode'] as String?) ?? '',
          (data['barcode'] as String?) ?? '',
          ((data['purchasePrice'] as num?) ?? 0).toString(),
          ((data['sellingPrice'] as num?) ?? 0).toString(),
          ((data['taxPercent'] as num?) ?? 0).toString(),
          (data['unit'] as String?) ?? 'piece',
          ((data['hideFromQuickCheckout'] as bool?) ?? false).toString(),
          (data['quickCheckoutEmoji'] as String?) ?? '',
          expiryDate == null ? '' : DateFormat('yyyy-MM-dd').format(expiryDate),
        ]);
      }
      await saveCsvFile(
        fileName: 'products_export.csv',
        content: const CsvEncoder().convert(rows),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current products exported.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCsv() async {
    setState(() => _loading = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['csv'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      if (bytes == null) {
        throw Exception('No CSV file selected');
      }
      final content = utf8.decode(bytes, allowMalformed: true);
      final preview = await _buildPreview(content);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import preview failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_ProductImportPreview> _buildPreview(String csvContent) async {
    final rows = const CsvDecoder().convert(csvContent);
    if (rows.isEmpty) {
      throw Exception('CSV is empty');
    }
    final header = rows.first.map((cell) => '$cell'.trim()).toList();
    final missing = _headers.where((value) => !header.contains(value)).toList();
    if (missing.isNotEmpty) {
      throw Exception('Missing columns: ${missing.join(', ')}');
    }

    final products = await ref.read(productRepositoryProvider).watchAll().first;
    final byCode = <String, Product>{
      for (final product in products)
        product.productCode.trim().toLowerCase(): product,
    };
    final byBarcode = <String, Product>{
      for (final product in products)
        if ((product.barcode ?? '').trim().isNotEmpty)
          product.barcode!.trim().toLowerCase(): product,
    };
    final seenCodes = <String>{};
    final ops = <_ProductImportRow>[];

    for (var index = 1; index < rows.length; index++) {
      final raw = rows[index];
      if (raw.every((cell) => '$cell'.trim().isEmpty)) {
        continue;
      }
      final map = <String, String>{};
      for (var i = 0; i < header.length; i++) {
        map[header[i]] = i < raw.length ? '${raw[i]}'.trim() : '';
      }
      final codeKey = map['productCode']!.toLowerCase();
      final barcodeKey = map['barcode']!.toLowerCase();
      final errors = <String>[];
      if (map['name']!.isEmpty) errors.add('Name is required');
      if (map['productCode']!.isEmpty) errors.add('Product code is required');
      if (codeKey.isNotEmpty && !seenCodes.add(codeKey)) {
        errors.add('Duplicate productCode in file');
      }
      final purchasePrice = double.tryParse(map['purchasePrice']!);
      final sellingPrice = double.tryParse(map['sellingPrice']!);
      final taxPercent = double.tryParse(map['taxPercent']!);
      if (purchasePrice == null) errors.add('Invalid purchasePrice');
      if (sellingPrice == null) errors.add('Invalid sellingPrice');
      if (taxPercent == null) errors.add('Invalid taxPercent');
      final expiryDate = _parseDate(map['expiryDate']!);
      if (map['expiryDate']!.isNotEmpty && expiryDate == null) {
        errors.add('Invalid expiryDate. Use yyyy-MM-dd');
      }
      final existingByCode = codeKey.isEmpty ? null : byCode[codeKey];
      final existingByBarcode =
          barcodeKey.isEmpty ? null : byBarcode[barcodeKey];
      Product? existing = existingByCode ?? existingByBarcode;
      if (existingByCode != null &&
          existingByBarcode != null &&
          existingByCode.id != existingByBarcode.id) {
        errors.add('productCode and barcode match different products');
        existing = null;
      }
      ops.add(
        _ProductImportRow(
          lineNumber: index + 1,
          name: map['name']!,
          productCode: map['productCode']!,
          barcode: map['barcode']!.isEmpty ? null : map['barcode']!,
          purchasePrice: purchasePrice ?? 0,
          sellingPrice: sellingPrice ?? 0,
          taxPercent: taxPercent ?? 0,
          unit: map['unit']!.isEmpty ? 'piece' : map['unit']!,
          hideFromQuickCheckout: _parseBool(map['hideFromQuickCheckout']!),
          quickCheckoutEmoji: map['quickCheckoutEmoji']!.isEmpty
              ? null
              : map['quickCheckoutEmoji']!,
          expiryDate: expiryDate,
          existing: existing,
          errors: errors,
        ),
      );
    }

    return _ProductImportPreview(rows: ops, importedAt: DateTime.now());
  }

  DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  bool _parseBool(String raw) {
    final value = raw.trim().toLowerCase();
    return value == 'true' || value == '1' || value == 'yes' || value == 'y';
  }

  Future<void> _applyPreview() async {
    final preview = _preview;
    if (preview == null) return;
    final validRows = preview.rows.where((row) => row.errors.isEmpty).toList();
    if (validRows.isEmpty) return;
    setState(() => _applying = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      for (final row in validRows) {
        if (row.existing == null) {
          await repo.add(
            name: row.name,
            productCode: row.productCode,
            barcode: row.barcode,
            categoryId: null,
            sellingPrice: row.sellingPrice,
            purchasePrice: row.purchasePrice,
            taxPercent: row.taxPercent,
            unit: row.unit,
            openingStock: 0,
            showInQuickCheckout: !row.hideFromQuickCheckout,
            quickCheckoutEmoji: row.quickCheckoutEmoji,
            expiryDate: row.expiryDate,
          );
        } else {
          await repo.update(
            id: row.existing!.id,
            name: row.name,
            productCode: row.productCode,
            barcode: row.barcode,
            categoryId: row.existing!.categoryId,
            sellingPrice: row.sellingPrice,
            purchasePrice: row.purchasePrice,
            taxPercent: row.taxPercent,
            unit: row.unit,
            showInQuickCheckout: !row.hideFromQuickCheckout,
            quickCheckoutEmoji: row.quickCheckoutEmoji,
            expiryDate: row.expiryDate,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${validRows.length} product rows.'),
        ),
      );
      setState(() => _preview = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final validRows =
        preview?.rows.where((row) => row.errors.isEmpty).toList() ??
            const <_ProductImportRow>[];
    final createCount = validRows.where((row) => row.existing == null).length;
    final updateCount = validRows.where((row) => row.existing != null).length;
    final errorCount =
        preview?.rows.where((row) => row.errors.isNotEmpty).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Product Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product CSV Import',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Download the template, fill the rows, upload the CSV, review create/update validation, then confirm the import.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _loading ? null : _downloadTemplate,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download Template'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _exportCurrentProducts,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export Current Products'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _pickCsv,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Upload CSV'),
                      ),
                    ],
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview · ${DateFormat('dd MMM yyyy HH:mm').format(preview.importedAt)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _SummaryChip(
                            label: 'Create', value: createCount.toString()),
                        _SummaryChip(
                            label: 'Update', value: updateCount.toString()),
                        _SummaryChip(
                            label: 'Errors', value: errorCount.toString()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _applying || validRows.isEmpty
                            ? null
                            : _applyPreview,
                        icon: _applying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: const Text('Confirm Import'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...preview.rows.map(
              (row) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${row.lineNumber}')),
                  title: Text('${row.name} (${row.productCode})'),
                  subtitle: Text(
                    row.errors.isEmpty
                        ? '${row.existing == null ? 'Create new product' : 'Update existing product'} · Sell ₹${row.sellingPrice.toStringAsFixed(2)} · Cost ₹${row.purchasePrice.toStringAsFixed(2)}'
                        : row.errors.join(' | '),
                    style: TextStyle(
                      color: row.errors.isEmpty
                          ? null
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  trailing: Chip(
                    label: Text(row.errors.isEmpty
                        ? (row.existing == null ? 'CREATE' : 'UPDATE')
                        : 'ERROR'),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProductImportPreview {
  const _ProductImportPreview({required this.rows, required this.importedAt});

  final List<_ProductImportRow> rows;
  final DateTime importedAt;
}

class _ProductImportRow {
  const _ProductImportRow({
    required this.lineNumber,
    required this.name,
    required this.productCode,
    required this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.taxPercent,
    required this.unit,
    required this.hideFromQuickCheckout,
    required this.quickCheckoutEmoji,
    required this.expiryDate,
    required this.existing,
    required this.errors,
  });

  final int lineNumber;
  final String name;
  final String productCode;
  final String? barcode;
  final double purchasePrice;
  final double sellingPrice;
  final double taxPercent;
  final String unit;
  final bool hideFromQuickCheckout;
  final String? quickCheckoutEmoji;
  final DateTime? expiryDate;
  final Product? existing;
  final List<String> errors;
}
