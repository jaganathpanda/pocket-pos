import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/firestore_ids.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/models/invoice_branding.dart';
import '../../../core/models/invoice_document.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utilities/validators.dart';
import '../../store/presentation/store_auth_controller.dart';

class QuickInvoicePage extends ConsumerStatefulWidget {
  const QuickInvoicePage({super.key, this.invoiceId});

  final String? invoiceId;

  @override
  ConsumerState<QuickInvoicePage> createState() => _QuickInvoicePageState();
}

class _QuickInvoicePageState extends ConsumerState<QuickInvoicePage> {
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  final List<_InvoiceDraftLine> _lines = <_InvoiceDraftLine>[];
  String? _savedInvoiceId;
  late String _invoiceNo;
  late DateTime _invoiceDate;
  bool _saving = false;
  bool _printing = false;
  bool _isLoading = false;

  // Cache for customer suggestions to avoid repeated Firestore reads
  List<({String name, String phone, String address})>? _cachedCustomers;

  @override
  void initState() {
    super.initState();
    _resetInvoiceMeta();
    if (widget.invoiceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInvoice();
      });
    }
  }

  Future<void> _loadInvoice() async {
    if (widget.invoiceId == null) return;
    setState(() => _isLoading = true);
    try {
      final storeId = ref.read(activeStoreIdProvider);
      final firestore = ref.read(firestoreProvider);

      if (storeId == null) {
        throw Exception('Store not selected');
      }

      final doc = await storeCollection(
        firestore,
        storeId,
        'quick_invoices',
      ).doc(widget.invoiceId!).get();

      if (!mounted) return;
      if (!doc.exists) {
        throw Exception('Invoice not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _savedInvoiceId = widget.invoiceId;
        _invoiceNo = data['invoiceNo'] as String? ?? _invoiceNo;
        _invoiceDate =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        _customerNameCtrl.text = data['customerName'] as String? ?? '';
        _customerPhoneCtrl.text = data['customerPhone'] as String? ?? '';
        _customerAddressCtrl.text = data['customerAddress'] as String? ?? '';
        _noteCtrl.text = data['note'] as String? ?? '';

        _lines.clear();
        final items = (data['items'] as List?) ?? [];
        for (final item in items) {
          _lines.add(_InvoiceDraftLine(
            product: null,
            description: item['description'] as String? ?? '',
            quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
            unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0,
            taxPercent: (item['taxPercent'] as num?)?.toDouble() ?? 0,
          ));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load invoice: $e')),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _customerAddressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _resetInvoiceMeta() {
    final branding = ref.read(invoiceBrandingProvider).valueOrNull ??
        const InvoiceBranding.defaults();
    _invoiceDate = DateTime.now();
    _invoiceNo =
        '${branding.invoicePrefix}-${DateTime.now().millisecondsSinceEpoch}';
  }

  double get _subtotal =>
      _lines.fold<double>(0, (sum, line) => sum + line.subtotal);

  double get _taxTotal =>
      _lines.fold<double>(0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _taxTotal;

  /// Normalizes a phone number by removing spaces, +91, 91, 0 prefixes.
  /// Returns only the last 10 digits for comparison.
  String _normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    // Remove leading +91, 91, or 0
    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length > 10) {
      digits = digits.substring(1);
    }
    // Return last 10 digits if longer
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Loads and caches all customer records from quick_invoices.
  /// Called once when the user starts typing a phone number.
  Future<List<({String name, String phone, String address})>>
      _loadCustomers() async {
    if (_cachedCustomers != null) return _cachedCustomers!;

    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) return [];

    try {
      final snapshot = await storeCollection(
        ref.read(firestoreProvider),
        storeId,
        'quick_invoices',
      ).orderBy('createdAt', descending: true).limit(200).get();

      final seenPhones = <String>{};
      final results = <({String name, String phone, String address})>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final phone = (data['customerPhone'] as String? ?? '').trim();
        final name = (data['customerName'] as String? ?? '').trim();
        final address = (data['customerAddress'] as String? ?? '').trim();

        if (phone.isEmpty) continue;
        final normalized = _normalizePhone(phone);
        if (normalized.length < 4) continue; // Skip invalid/short numbers
        if (!seenPhones.add(normalized)) continue;

        results.add((name: name, phone: phone, address: address));
      }

      _cachedCustomers = results;
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<void> _showAddProductDialog(
      {_InvoiceDraftLine? existing, int? index}) async {
    final allProducts =
        ref.read(productsProvider).valueOrNull ?? const <Product>[];
    Product? selectedProduct = existing?.product;
    final descriptionCtrl =
        TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing?.unitPrice.toStringAsFixed(2) ?? '',
    );
    final qtyCtrl = TextEditingController(
      text: existing == null
          ? '1'
          : existing.quantity
              .toStringAsFixed(existing.quantity % 1 == 0 ? 0 : 2),
    );
    final taxCtrl = TextEditingController(
      text: (existing?.taxPercent ?? 0).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add Product' : 'Edit Product'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Autocomplete<Product>(
                      initialValue:
                          TextEditingValue(text: descriptionCtrl.text),
                      displayStringForOption: (product) => product.name,
                      optionsBuilder: (textEditingValue) {
                        final query =
                            textEditingValue.text.trim().toLowerCase();
                        if (query.isEmpty) {
                          return allProducts.take(12);
                        }
                        return allProducts.where((product) {
                          return product.name.toLowerCase().contains(query) ||
                              product.productCode
                                  .toLowerCase()
                                  .contains(query) ||
                              (product.barcode?.toLowerCase().contains(query) ??
                                  false);
                        }).take(12);
                      },
                      onSelected: (product) {
                        selectedProduct = product;
                        descriptionCtrl.text = product.name;
                        priceCtrl.text =
                            product.sellingPrice.toStringAsFixed(2);
                        taxCtrl.text = product.taxPercent.toStringAsFixed(2);
                        setLocal(() {});
                      },
                      fieldViewBuilder: (context, textEditingController,
                          focusNode, onSubmit) {
                        textEditingController.text = descriptionCtrl.text;
                        textEditingController.selection =
                            TextSelection.collapsed(
                          offset: textEditingController.text.length,
                        );
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Product or Description',
                            hintText:
                                'Search existing product or type manual item',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            descriptionCtrl.text = value;
                            if (selectedProduct != null &&
                                value.trim() != selectedProduct!.name) {
                              selectedProduct = null;
                            }
                          },
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null,
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: SizedBox(
                              width: 480,
                              height: 240,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (context, optionIndex) {
                                  final option = options.elementAt(optionIndex);
                                  return ListTile(
                                    dense: true,
                                    title: Text(option.name),
                                    subtitle: Text(
                                      'Code: ${option.productCode} · Price: ₹${option.sellingPrice.toStringAsFixed(2)}',
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (value) {
                              final parsed =
                                  double.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed < 0)
                                return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (value) {
                              final parsed =
                                  double.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed <= 0)
                                return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: taxCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'GST %',
                        hintText: 'Auto-filled from product. Clear to edit.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) return 'Invalid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        selectedProduct == null
                            ? 'Manual item mode'
                            : 'Using saved product price as default. You can still edit it.',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final line = _InvoiceDraftLine(
                  product: selectedProduct,
                  description: descriptionCtrl.text.trim(),
                  quantity: double.parse(qtyCtrl.text.trim()),
                  unitPrice: double.parse(priceCtrl.text.trim()),
                  taxPercent: double.parse(taxCtrl.text.trim()),
                );
                setState(() {
                  if (index != null) {
                    _lines[index] = line;
                  } else {
                    _lines.add(line);
                  }
                  _savedInvoiceId = null;
                });
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _saveInvoice({bool showMessage = true}) async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) return false;
    if (_lines.isEmpty) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one line item.')),
        );
      }
      return false;
    }
    final phoneError = validateMobile(_customerPhoneCtrl.text);
    if (phoneError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(phoneError)),
        );
      }
      return false;
    }

    setState(() => _saving = true);
    try {
      final id = _savedInvoiceId ?? '${newIntId()}';
      final now = DateTime.now();
      await storeCollection(
              ref.read(firestoreProvider), storeId, 'quick_invoices')
          .doc(id)
          .set({
        'invoiceNo': _invoiceNo,
        'customerName': _customerNameCtrl.text.trim(),
        'customerPhone': _customerPhoneCtrl.text.trim(),
        'customerAddress': _customerAddressCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'subTotal': _subtotal,
        'taxTotal': _taxTotal,
        'grandTotal': _grandTotal,
        'items': _lines
            .map((line) => <String, dynamic>{
                  'productId': line.product?.id,
                  'description': line.description,
                  'quantity': line.quantity,
                  'unitPrice': line.unitPrice,
                  'taxPercent': line.taxPercent,
                  'taxAmount': line.taxAmount,
                  'lineTotal': line.lineTotal,
                })
            .toList(),
        'createdByUid': ref.read(storeSessionProvider)?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_savedInvoiceId == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _savedInvoiceId = id;
      // Invalidate cache so new customer phone appears next time
      _cachedCustomers = null;
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved.')),
        );
      }
      return true;
    } catch (e) {
      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save invoice: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printInvoice() async {
    final branding = ref.read(invoiceBrandingProvider).valueOrNull ??
        const InvoiceBranding.defaults();
    final shopName = branding.displayName.isNotEmpty
        ? branding.displayName
        : (ref.read(storeSessionProvider)?.storeName ?? 'Pocket POS');
    final saved = await _saveInvoice(showMessage: false);
    if (!saved) return;

    setState(() => _printing = true);
    try {
      final bytes = await ReceiptPdfService().generateInvoicePdf(
        invoice: InvoiceDocument(
          shopName: shopName,
          invoiceNo: _invoiceNo,
          invoiceDate: _invoiceDate,
          customerName: _customerNameCtrl.text.trim(),
          customerAddress: _customerAddressCtrl.text.trim(),
          branding: branding,
          items: _lines
              .map(
                (line) => InvoiceLine(
                  description: line.description,
                  unitPrice: line.unitPrice,
                  qty: line.quantity,
                  lineTotal: line.lineTotal,
                ),
              )
              .toList(growable: false),
          subTotal: _subtotal,
          total: _grandTotal,
          taxTotal: _taxTotal,
          footerNote: _noteCtrl.text.trim(),
        ),
      );
      final pdfBytes = Uint8List.fromList(bytes);
      if (kIsWeb) {
        await Printing.sharePdf(bytes: pdfBytes, filename: '$_invoiceNo.pdf');
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
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _newInvoice() {
    setState(() {
      _savedInvoiceId = null;
      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
      _customerAddressCtrl.clear();
      _noteCtrl.clear();
      _lines.clear();
      _resetInvoiceMeta();
    });
  }

  Widget _buildCustomerPhoneAutocomplete(WidgetRef ref) {
    return Autocomplete<({String name, String phone, String address})>(
      initialValue: TextEditingValue(text: _customerPhoneCtrl.text),
      displayStringForOption: (customer) => customer.phone,
      optionsBuilder: (textEditingValue) async {
        final rawQuery = textEditingValue.text.trim();
        // Only start suggesting after 4 characters
        if (rawQuery.length < 4) {
          return const [];
        }

        final query = _normalizePhone(rawQuery);
        if (query.length < 4) return const [];

        // Load all customers (cached after first call)
        final allCustomers = await _loadCustomers();

        // Filter by normalized phone containing the query
        final matches = allCustomers
            .where((c) {
              final normalizedStored = _normalizePhone(c.phone);
              return normalizedStored.contains(query);
            })
            .take(10)
            .toList();

        return matches;
      },
      onSelected: (customer) {
        _customerPhoneCtrl.text = customer.phone;
        _customerNameCtrl.text = customer.name;
        _customerAddressCtrl.text = customer.address;
        setState(() => _savedInvoiceId = null);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onSubmit) {
        // Sync the external controller with internal
        if (textEditingController.text != _customerPhoneCtrl.text) {
          textEditingController.text = _customerPhoneCtrl.text;
          textEditingController.selection = TextSelection.collapsed(
            offset: textEditingController.text.length,
          );
        }
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Customer Phone',
            hintText: 'Enter 4+ digits for suggestions',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            _customerPhoneCtrl.text = value;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: 300,
              height: 200,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final customer = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(customer.name.isEmpty ? 'N/A' : customer.name),
                    subtitle: Text(customer.phone),
                    onTap: () => onSelected(customer),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(invoiceBrandingProvider).valueOrNull ??
        const InvoiceBranding.defaults();
    final shopName = branding.displayName.isNotEmpty
        ? branding.displayName
        : (ref.watch(storeSessionProvider)?.storeName ?? 'Pocket POS');

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _savedInvoiceId != null ? 'Edit Invoice' : 'Quick Invoice',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving || _printing ? null : _newInvoice,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('New'),
          ),
          TextButton.icon(
            onPressed: _saving || _printing ? null : _saveInvoice,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
          TextButton.icon(
            onPressed: _saving || _printing ? null : _printInvoice,
            icon: _printing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
          TextButton.icon(
            onPressed: () => context.push('/quick-invoice-report'),
            icon: const Icon(Icons.assessment_outlined),
            label: const Text('Report'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;

              final formCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invoice Details',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _buildCustomerPhoneAutocomplete(ref),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) =>
                            setState(() => _savedInvoiceId = null),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customerAddressCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Customer Address',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) =>
                            setState(() => _savedInvoiceId = null),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Footer Note',
                          hintText: 'Optional thank-you or payment note',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) =>
                            setState(() => _savedInvoiceId = null),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Invoice No: $_invoiceNo'),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(_invoiceDate)}',
                            ),
                            if (_savedInvoiceId != null) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Status: Saved',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final previewCard = Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInvoiceHeader(isWide, shopName, branding),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: _saving || _printing
                                ? null
                                : () => _showAddProductDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Horizontal scroll to prevent column squishing
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 650),
                          child: Table(
                            columnWidths: const <int, TableColumnWidth>{
                              0: FlexColumnWidth(3.5),
                              1: FlexColumnWidth(1.2),
                              2: FlexColumnWidth(1.0),
                              3: FlexColumnWidth(1.2),
                              4: FlexColumnWidth(1.5),
                              5: FixedColumnWidth(80),
                            },
                            border: const TableBorder(
                              horizontalInside:
                                  BorderSide(color: Color(0xFFE0E0E0)),
                              bottom: BorderSide(color: Color(0xFFCCCCCC)),
                            ),
                            children: [
                              const TableRow(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom:
                                        BorderSide(color: Color(0xFFCCCCCC)),
                                  ),
                                ),
                                children: [
                                  _HeaderCell('Description'),
                                  _HeaderCell('Price', alignRight: true),
                                  _HeaderCell('Qty', alignRight: true),
                                  _HeaderCell('GST %', alignRight: true),
                                  _HeaderCell('Total', alignRight: true),
                                  SizedBox(),
                                ],
                              ),
                              if (_lines.isEmpty)
                                const TableRow(
                                  children: [
                                    _EmptyCell('No items added yet'),
                                    _EmptyCell(''),
                                    _EmptyCell(''),
                                    _EmptyCell(''),
                                    _EmptyCell(''),
                                    SizedBox(),
                                  ],
                                ),
                              for (var i = 0; i < _lines.length; i++)
                                _buildLineRow(i, _lines[i]),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 320,
                          child: Column(
                            children: [
                              _TotalLine(label: 'Sub-total', value: _subtotal),
                              _TotalLine(label: 'GST', value: _taxTotal),
                              _TotalLine(
                                  label: 'TOTAL',
                                  value: _grandTotal,
                                  bold: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Center(
                        child: Text(
                          'Thank You!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          [
                            if (branding.phone.isNotEmpty) branding.phone,
                            if (branding.email.isNotEmpty) branding.email,
                          ].join(' | '),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      if (_noteCtrl.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: Text(
                              _noteCtrl.text.trim(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );

              // Responsive layout switch
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 360, child: formCard),
                    const SizedBox(width: 16),
                    Expanded(child: previewCard),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    formCard,
                    const SizedBox(height: 16),
                    previewCard,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopInfoBlock(InvoiceBranding branding, String shopName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          shopName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        if (branding.address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              branding.address,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        if (branding.phone.isNotEmpty || branding.email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              [
                if (branding.phone.isNotEmpty) branding.phone,
                if (branding.email.isNotEmpty) branding.email,
              ].join(' | '),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        if (branding.gstin.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'GSTIN: ${branding.gstin}',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
      ],
    );
  }

  Widget _buildInvoiceMetaBlock(CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'INVOICE',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        _MetaLine(
            label: 'Date',
            value: DateFormat('dd/MM/yyyy').format(_invoiceDate)),
        _MetaLine(label: 'Invoice No', value: _invoiceNo),
        _MetaLine(
          label: 'Invoice To',
          value: _customerNameCtrl.text.trim().isEmpty
              ? '-'
              : _customerNameCtrl.text.trim(),
        ),
      ],
    );
  }

  Widget _buildInvoiceHeader(
    bool isWide,
    String shopName,
    InvoiceBranding branding,
  ) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildShopInfoBlock(branding, shopName)),
          const SizedBox(width: 24),
          _buildInvoiceMetaBlock(CrossAxisAlignment.end),
        ],
      );
    }

    // Mobile: two full-width horizontal sections stacked one above the other.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShopInfoBlock(branding, shopName),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        _buildInvoiceMetaBlock(CrossAxisAlignment.start),
      ],
    );
  }

  TableRow _buildLineRow(int index, _InvoiceDraftLine line) {
    return TableRow(
      children: [
        _BodyCell(line.description),
        _BodyCell('₹${line.unitPrice.toStringAsFixed(2)}', alignRight: true),
        _BodyCell(_formatQty(line.quantity), alignRight: true),
        _BodyCell('${line.taxPercent.toStringAsFixed(2)}%', alignRight: true),
        _BodyCell('₹${line.lineTotal.toStringAsFixed(2)}', alignRight: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit line',
                visualDensity: VisualDensity.compact,
                onPressed: _saving || _printing
                    ? null
                    : () => _showAddProductDialog(existing: line, index: index),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Delete line',
                visualDensity: VisualDensity.compact,
                onPressed: _saving || _printing
                    ? null
                    : () {
                        setState(() {
                          _lines.removeAt(index);
                          _savedInvoiceId = null;
                        });
                      },
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatQty(double qty) {
    return qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
  }
}

class _InvoiceDraftLine {
  const _InvoiceDraftLine({
    required this.product,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxPercent = 0,
  });

  final Product? product;
  final String description;
  final double quantity;
  final double unitPrice;
  final double taxPercent;

  double get subtotal => quantity * unitPrice;
  double get taxAmount => subtotal * (taxPercent / 100);
  double get lineTotal => subtotal + taxAmount;
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label : $value',
        style: const TextStyle(fontSize: 14, color: Colors.black),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.alignRight = false});

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {this.alignRight = false});

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 14, color: Colors.black),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 18 : 15,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: Colors.black,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child:
                  Text('$label :', textAlign: TextAlign.right, style: style)),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(
              '₹${value.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
