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

class CustomerImportPage extends ConsumerStatefulWidget {
  const CustomerImportPage({super.key});

  @override
  ConsumerState<CustomerImportPage> createState() => _CustomerImportPageState();
}

class _CustomerImportPageState extends ConsumerState<CustomerImportPage> {
  List<_CustomerImportRow>? _rows;
  bool _busy = false;

  static const _headers = ['mobile', 'name', 'address'];

  Future<void> _downloadTemplate() async {
    try {
      await saveCsvFile(
        fileName: 'customer_import_template.csv',
        content: const CsvEncoder().convert([_headers]),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer template downloaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save customer template: $e')),
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
      final rows =
          await _buildPreview(utf8.decode(bytes, allowMalformed: true));
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer import preview failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<_CustomerImportRow>> _buildPreview(String content) async {
    final csvRows = const CsvDecoder().convert(content);
    if (csvRows.isEmpty) throw Exception('CSV is empty');
    final headers = csvRows.first.map((value) => '$value'.trim()).toList();
    final missing = _headers.where((header) => !headers.contains(header));
    if (missing.isNotEmpty) {
      throw Exception('Missing columns: ${missing.join(', ')}');
    }

    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) throw Exception('No active store');
    final customers = storeCollection(
      ref.read(firestoreProvider),
      storeId,
      'customers',
    );
    final existingDocs = await customers.get();
    final existingByMobile =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in existingDocs.docs)
        if (_normalizeMobile(doc.data()['mobile'] as String? ?? '')
            case final mobile when mobile.isNotEmpty)
          mobile: doc,
    };
    final seenMobiles = <String>{};
    final result = <_CustomerImportRow>[];

    for (var index = 1; index < csvRows.length; index++) {
      final row = csvRows[index];
      if (row.every((cell) => '$cell'.trim().isEmpty)) continue;
      String value(String key) {
        final column = headers.indexOf(key);
        return column < row.length ? '${row[column]}'.trim() : '';
      }

      final mobile = _normalizeMobile(value('mobile'));
      final name = value('name');
      final address = value('address');
      final errors = <String>[];
      if (mobile.length != 10 || !RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
        errors.add('Enter a valid 10-digit Indian mobile');
      } else if (!seenMobiles.add(mobile)) {
        errors.add('Mobile is repeated in this file');
      }
      if (name.isEmpty) errors.add('Name is required');

      result.add(_CustomerImportRow(
        line: index + 1,
        mobile: mobile,
        name: name,
        address: address,
        existingId: existingByMobile[mobile]?.id,
        errors: errors,
      ));
    }
    if (result.isEmpty) throw Exception('No customer rows found');
    return result;
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
    final rows = _rows;
    final storeId = ref.read(activeStoreIdProvider);
    if (rows == null || storeId == null || storeId.isEmpty) return;
    final validRows = rows.where((row) => row.errors.isEmpty).toList();
    if (validRows.isEmpty) return;
    setState(() => _busy = true);
    try {
      final collection = storeCollection(
        ref.read(firestoreProvider),
        storeId,
        'customers',
      );
      for (var start = 0; start < validRows.length; start += 400) {
        final batch = ref.read(firestoreProvider).batch();
        for (final row in validRows.skip(start).take(400)) {
          final id = row.existingId ?? newIntId();
          batch.set(
            collection.doc(row.existingId ?? '$id'),
            {
              'name': row.name,
              'mobile': row.mobile,
              if (row.address.isNotEmpty || row.existingId == null)
                'address': row.address.isEmpty ? null : row.address,
              if (row.existingId == null) 'loyaltyPoints': 0,
              if (row.existingId == null)
                'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${validRows.length} customers.')),
      );
      setState(() => _rows = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final validCount = rows?.where((row) => row.errors.isEmpty).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Import customers before uploading their sales history. Existing customers are updated by mobile number.',
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
          if (rows != null) ...[
            const SizedBox(height: 20),
            Text('Preview · $validCount of ${rows.length} valid'),
            const SizedBox(height: 8),
            for (final row in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  row.errors.isEmpty
                      ? row.existingId == null
                          ? Icons.person_add_alt_1_outlined
                          : Icons.person_outline_rounded
                      : Icons.error_outline_rounded,
                  color: row.errors.isEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text('${row.name} · ${row.mobile}'),
                subtitle: Text(
                  row.errors.isNotEmpty
                      ? 'Row ${row.line}: ${row.errors.join('; ')}'
                      : row.existingId == null
                          ? 'New customer'
                          : 'Will update existing customer',
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || validCount == 0 ? null : _import,
              icon: const Icon(Icons.check_rounded),
              label: Text('Import $validCount Customers'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerImportRow {
  const _CustomerImportRow({
    required this.line,
    required this.mobile,
    required this.name,
    required this.address,
    required this.existingId,
    required this.errors,
  });

  final int line;
  final String mobile;
  final String name;
  final String address;
  final String? existingId;
  final List<String> errors;
}
