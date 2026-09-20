import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/csv_file_export.dart';
import '../../warehouse/domain/inventory_mode.dart';

class PurchaseImportPage extends ConsumerStatefulWidget {
  const PurchaseImportPage({super.key});

  @override
  ConsumerState<PurchaseImportPage> createState() => _PurchaseImportPageState();
}

class _PurchaseImportPageState extends ConsumerState<PurchaseImportPage> {
  _PurchaseImportPreview? _preview;
  bool _loading = false;
  bool _applying = false;

  static const List<String> _headers = <String>[
    'invoiceNo',
    'supplierName',
    'warehouseName',
    'productCode',
    'barcode',
    'quantity',
    'unitCost',
    'taxPercent',
    'note',
    'finalize',
  ];

  String _templateCsv() {
    return const CsvEncoder().convert(<List<dynamic>>[
      _headers,
      <String>[
        'PUR-1001',
        'ABC Traders',
        'Main Warehouse',
        'PRD-TEA-001',
        '',
        '25',
        '8.50',
        '5',
        'Morning stock',
        'true',
      ],
      <String>[
        'PUR-1001',
        'ABC Traders',
        'Main Warehouse',
        'PRD-BIS-002',
        '',
        '10',
        '12.00',
        '12',
        'Morning stock',
        'true',
      ],
    ]);
  }

  Future<void> _downloadTemplate() async {
    try {
      await saveCsvFile(
        fileName: 'purchase_import_template.csv',
        content: _templateCsv(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase template downloaded.')),
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

  Future<_PurchaseImportPreview> _buildPreview(String csvContent) async {
    final rows = const CsvDecoder().convert(csvContent);
    if (rows.isEmpty) {
      throw Exception('CSV is empty');
    }
    final header = rows.first.map((cell) => '$cell'.trim()).toList();
    final missing = _headers.where((value) => !header.contains(value)).toList();
    if (missing.isNotEmpty) {
      throw Exception('Missing columns: ${missing.join(', ')}');
    }

    final suppliers = await ref.read(suppliersProvider.future);
    final supplierByName = <String, Supplier>{
      for (final supplier in suppliers)
        supplier.name.trim().toLowerCase(): supplier,
    };
    final warehouses = await ref.read(warehousesProvider.future);
    final activeWarehouses =
        warehouses.where((warehouse) => warehouse.isActive).toList();
    final warehouseByName = <String, Warehouse>{
      for (final warehouse in activeWarehouses)
        warehouse.name.trim().toLowerCase(): warehouse,
    };
    final defaultWarehouse = activeWarehouses.cast<Warehouse?>().firstWhere(
          (warehouse) => warehouse?.isDefault == true,
          orElse: () =>
              activeWarehouses.isEmpty ? null : activeWarehouses.first,
        );
    final inventoryMode =
        ref.read(inventoryModeProvider).valueOrNull ?? InventoryMode.single;
    final products = await ref.read(productRepositoryProvider).watchAll().first;
    final productByCode = <String, Product>{
      for (final product in products)
        product.productCode.trim().toLowerCase(): product,
    };
    final productByBarcode = <String, Product>{
      for (final product in products)
        if ((product.barcode ?? '').trim().isNotEmpty)
          product.barcode!.trim().toLowerCase(): product,
    };

    final parsedRows = <_PurchaseImportRow>[];
    for (var index = 1; index < rows.length; index++) {
      final raw = rows[index];
      if (raw.every((cell) => '$cell'.trim().isEmpty)) {
        continue;
      }
      final map = <String, String>{};
      for (var i = 0; i < header.length; i++) {
        map[header[i]] = i < raw.length ? '${raw[i]}'.trim() : '';
      }
      final errors = <String>[];
      final invoiceNo = map['invoiceNo']!;
      final supplierName = map['supplierName']!;
      final warehouseName = map['warehouseName']!;
      final productCode = map['productCode']!;
      final barcode = map['barcode']!;
      final quantity = double.tryParse(map['quantity']!);
      final unitCost = double.tryParse(map['unitCost']!);
      final taxPercent = double.tryParse(map['taxPercent']!);
      final finalize = _parseBool(map['finalize']!);

      if (invoiceNo.isEmpty) errors.add('invoiceNo is required');
      if (productCode.isEmpty && barcode.isEmpty) {
        errors.add('productCode or barcode is required');
      }
      if (quantity == null || quantity <= 0) errors.add('Invalid quantity');
      if (unitCost == null || unitCost < 0) errors.add('Invalid unitCost');
      if (taxPercent == null || taxPercent < 0) {
        errors.add('Invalid taxPercent');
      }

      final supplier = supplierName.isEmpty
          ? null
          : supplierByName[supplierName.toLowerCase()];
      if (supplierName.isNotEmpty && supplier == null) {
        errors.add('Unknown supplier "$supplierName"');
      }

      Warehouse? warehouse;
      if (inventoryMode == InventoryMode.multiple) {
        if (warehouseName.isEmpty) {
          warehouse = defaultWarehouse;
          if (warehouse == null) {
            errors.add('No active warehouse available');
          }
        } else {
          warehouse = warehouseByName[warehouseName.toLowerCase()];
          if (warehouse == null) {
            errors.add('Unknown warehouse "$warehouseName"');
          }
        }
      }

      final existingByCode =
          productCode.isEmpty ? null : productByCode[productCode.toLowerCase()];
      final existingByBarcode =
          barcode.isEmpty ? null : productByBarcode[barcode.toLowerCase()];
      Product? product = existingByCode ?? existingByBarcode;
      if (existingByCode != null &&
          existingByBarcode != null &&
          existingByCode.id != existingByBarcode.id) {
        errors.add('productCode and barcode match different products');
        product = null;
      }
      if (product == null) errors.add('Product not found');

      parsedRows.add(
        _PurchaseImportRow(
          lineNumber: index + 1,
          invoiceNo: invoiceNo,
          supplier: supplier,
          warehouse: warehouse,
          product: product,
          quantity: quantity ?? 0,
          unitCost: unitCost ?? 0,
          taxPercent: taxPercent ?? 0,
          note: map['note']!.isEmpty ? null : map['note']!,
          finalize: finalize,
          errors: errors,
        ),
      );
    }

    return _PurchaseImportPreview(rows: parsedRows);
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
      final repo = ref.read(purchaseRepositoryProvider);
      final grouped = <String, List<_PurchaseImportRow>>{};
      for (final row in validRows) {
        final key = [
          row.invoiceNo,
          '${row.supplier?.id ?? 0}',
          '${row.warehouse?.id ?? 0}',
          row.note ?? '',
          row.finalize.toString(),
        ].join('|');
        grouped.putIfAbsent(key, () => <_PurchaseImportRow>[]).add(row);
      }

      for (final entry in grouped.entries) {
        final rows = entry.value;
        final first = rows.first;
        final purchaseId = await repo.createPurchase(
          supplierId: first.supplier?.id,
          invoiceNo: first.invoiceNo,
          note: first.note,
          warehouseId: first.warehouse?.id,
        );
        for (final row in rows) {
          await repo.addItem(
            purchaseId: purchaseId,
            productId: row.product!.id,
            quantity: row.quantity,
            unitCost: row.unitCost,
            taxPercent: row.taxPercent,
          );
        }
        if (first.finalize) {
          await repo.finalize(purchaseId);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${grouped.length} purchase entries.')),
      );
      setState(() => _preview = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase import failed: $e')),
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
            const <_PurchaseImportRow>[];
    final errorCount =
        preview?.rows.where((row) => row.errors.isNotEmpty).length ?? 0;
    final groupedCount = validRows
        .map((row) =>
            '${row.invoiceNo}|${row.supplier?.id ?? 0}|${row.warehouse?.id ?? 0}')
        .toSet()
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Import')),
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
                    'Purchase CSV Import',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Upload vendor purchase rows, review validation, then confirm to create draft or finalized purchase entries.',
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
                    const Text(
                      'Preview',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _PurchaseSummaryChip(
                          label: 'Rows',
                          value: preview.rows.length.toString(),
                        ),
                        _PurchaseSummaryChip(
                          label: 'Purchases',
                          value: groupedCount.toString(),
                        ),
                        _PurchaseSummaryChip(
                          label: 'Errors',
                          value: errorCount.toString(),
                        ),
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
                  title: Text(
                      '${row.invoiceNo} · ${row.product?.name ?? 'Unknown product'}'),
                  subtitle: Text(
                    row.errors.isEmpty
                        ? 'Qty ${row.quantity.toStringAsFixed(2)} · Cost ₹${row.unitCost.toStringAsFixed(2)} · ${row.finalize ? 'Finalize' : 'Draft'}'
                        : row.errors.join(' | '),
                    style: TextStyle(
                      color: row.errors.isEmpty
                          ? null
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  trailing: Chip(
                    label: Text(row.errors.isEmpty ? 'READY' : 'ERROR'),
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

class _PurchaseSummaryChip extends StatelessWidget {
  const _PurchaseSummaryChip({required this.label, required this.value});

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

class _PurchaseImportPreview {
  const _PurchaseImportPreview({required this.rows});

  final List<_PurchaseImportRow> rows;
}

class _PurchaseImportRow {
  const _PurchaseImportRow({
    required this.lineNumber,
    required this.invoiceNo,
    required this.supplier,
    required this.warehouse,
    required this.product,
    required this.quantity,
    required this.unitCost,
    required this.taxPercent,
    required this.note,
    required this.finalize,
    required this.errors,
  });

  final int lineNumber;
  final String invoiceNo;
  final Supplier? supplier;
  final Warehouse? warehouse;
  final Product? product;
  final double quantity;
  final double unitCost;
  final double taxPercent;
  final String? note;
  final bool finalize;
  final List<String> errors;
}
