import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../barcode/presentation/barcode_scanner_page.dart';
import '../../barcode/presentation/hid_scanner_listener.dart';
import '../../warehouse/domain/inventory_mode.dart';
import 'product_name_scanner.dart';

class ProductPage extends ConsumerStatefulWidget {
  const ProductPage({super.key});

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          SizedBox(
            width: 260,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search product / barcode',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _search.clear();
                            ref.read(productSearchQueryProvider.notifier).state = '';
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (q) {
                  ref.read(productSearchQueryProvider.notifier).state = q;
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, ref),
        label: const Text('Add Product'),
        icon: const Icon(Icons.add),
      ),
      body: products.when(
        data: (list) {
          final categoryById = {
            for (final c in (categories.valueOrNull ?? const <Category>[])) c.id: c.name,
          };

          if (list.isEmpty) {
            return const Center(child: Text('No products found. Tap + to add one.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = list[index];
              return ListTile(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Category: ${p.categoryId == null ? '-' : (categoryById[p.categoryId] ?? '-')}  |  '
                  'Code: ${p.productCode}  |  Barcode: ${p.barcode ?? '-'}  |  Tax: ${p.taxPercent}%  |  Unit: ${p.unit}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${p.sellingPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Cost: ₹${p.purchasePrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showProductDialog(context, ref, product: p),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () => _confirmDelete(context, ref, p),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(productRepositoryProvider).delete(p.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${p.name}" deleted')));
      }
    }
  }

  Future<void> _showProductDialog(BuildContext context, WidgetRef ref, {Product? product}) async {
    final allCategories = await ref.read(categoryRepositoryProvider).watchAll().first;
    final isEdit = product != null;
    final name = TextEditingController(text: product?.name ?? '');
    // New products get an auto-generated (editable) code.
    final code = TextEditingController(
        text: product?.productCode ?? _generateProductCode());
    final barcode = TextEditingController(text: product?.barcode ?? '');
    final selling = TextEditingController(text: (product?.sellingPrice ?? 0).toStringAsFixed(2));
    final purchase = TextEditingController(text: (product?.purchasePrice ?? 0).toStringAsFixed(2));
    final tax = TextEditingController(text: (product?.taxPercent ?? 0).toStringAsFixed(1));
    final unit = TextEditingController(text: product?.unit ?? 'piece');
    final opening = TextEditingController(text: '0');
    final purchaseFocus = FocusNode();
    final sellingFocus = FocusNode();
    // On focus: clear a leading 0 so the user types the real price straight
    // away. On blur: restore 0 if left empty.
    void clearZeroOnFocus(TextEditingController c, FocusNode n) {
      n.addListener(() {
        if (n.hasFocus) {
          if ((double.tryParse(c.text) ?? 0) == 0) c.clear();
        } else if (c.text.trim().isEmpty) {
          c.text = '0';
        }
      });
    }

    clearZeroOnFocus(purchase, purchaseFocus);
    clearZeroOnFocus(selling, sellingFocus);
    final formKey = GlobalKey<FormState>();
    int? selectedCategoryId = product?.categoryId;
    final messenger = ScaffoldMessenger.of(context);

    // Opening stock is only meaningful for a brand-new product in a
    // stock-tracking mode.
    final tracksStock =
        (ref.read(inventoryModeProvider).valueOrNull ?? InventoryMode.single)
            .tracksStock;
    final showOpeningStock = !isEdit && tracksStock;

    // When a barcode matches an already-saved product, prefill the form from it.
    Future<void> applyBarcode(
        String raw, void Function(VoidCallback) setLocal) async {
      final value = raw.trim();
      if (value.isEmpty) return;
      final match = await ref.read(productRepositoryProvider).findByBarcode(value);
      if (match == null || match.id == product?.id) return;
      name.text = match.name;
      code.text = match.productCode;
      selling.text = match.sellingPrice.toStringAsFixed(2);
      purchase.text = match.purchasePrice.toStringAsFixed(2);
      tax.text = match.taxPercent.toStringAsFixed(1);
      unit.text = match.unit;
      setLocal(() => selectedCategoryId = match.categoryId);
      messenger.showSnackBar(SnackBar(
          content: Text('Filled details from existing product "${match.name}".')));
    }


    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HidScannerListener(
          onScan: (scanned) {
            barcode.text = scanned;
            applyBarcode(scanned, setLocal);
          },
          child: AlertDialog(
            title: Text(isEdit ? 'Edit Product' : 'Add Product'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          helperText: productNameScannerSupported
                              ? 'Tap the camera to read the name from a photo'
                              : null,
                          suffixIcon: productNameScannerSupported
                              ? IconButton(
                                  tooltip: 'Scan product name from photo',
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  onPressed: () async {
                                    final scanned =
                                        await scanProductNameFromImage(ctx);
                                    if (scanned != null && scanned.isNotEmpty) {
                                      setLocal(() => name.text = scanned);
                                      messenger.showSnackBar(SnackBar(
                                          content: Text('Read: "$scanned"')));
                                    } else {
                                      messenger.showSnackBar(const SnackBar(
                                          content: Text(
                                              'Could not read a name. Fill the frame with the product name and try again.')));
                                    }
                                  },
                                )
                              : null,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: code,
                        decoration: InputDecoration(
                          labelText: 'Product Code *',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Generate code',
                            icon: const Icon(Icons.autorenew_rounded),
                            onPressed: () => code.text = _generateProductCode(),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('No category')),
                          for (final c in allCategories)
                            DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: (v) => setLocal(() => selectedCategoryId = v),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: barcode,
                        onFieldSubmitted: (v) => applyBarcode(v, setLocal),
                        decoration: InputDecoration(
                          labelText: 'Barcode (optional)',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          helperText:
                              'Scan, type or generate. A saved match fills the form.',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Generate barcode',
                                icon: const Icon(Icons.qr_code_2_rounded),
                                onPressed: () => barcode.text = _generateEan13(),
                              ),
                              IconButton(
                                tooltip: 'Scan with camera',
                                icon: const Icon(Icons.qr_code_scanner),
                                onPressed: () async {
                                  final scanned = await scanBarcodeWithCamera(ctx);
                                  if (scanned != null) {
                                    barcode.text = scanned;
                                    await applyBarcode(scanned, setLocal);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _priceField(
                                purchase, purchaseFocus, 'Purchase Price *')),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _priceField(
                                selling, sellingFocus, 'Selling Price *')),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _field(tax, 'Tax %', numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _field(unit, 'Unit (piece/kg/ltr...)')),
                      ]),
                      if (showOpeningStock) ...[
                        const SizedBox(height: 8),
                        _field(opening, 'Opening stock', numeric: true),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final barcodeVal =
                      barcode.text.trim().isEmpty ? null : barcode.text.trim();
                  final unitVal =
                      unit.text.trim().isEmpty ? 'piece' : unit.text.trim();
                  final repo = ref.read(productRepositoryProvider);
                  try {
                    if (isEdit) {
                      await repo.update(
                        id: product.id,
                        name: name.text.trim(),
                        productCode: code.text.trim(),
                        barcode: barcodeVal,
                        categoryId: selectedCategoryId,
                        sellingPrice: double.tryParse(selling.text) ?? 0,
                        purchasePrice: double.tryParse(purchase.text) ?? 0,
                        taxPercent: double.tryParse(tax.text) ?? 0,
                        unit: unitVal,
                      );
                    } else {
                      await repo.add(
                        name: name.text.trim(),
                        productCode: code.text.trim(),
                        barcode: barcodeVal,
                        categoryId: selectedCategoryId,
                        sellingPrice: double.tryParse(selling.text) ?? 0,
                        purchasePrice: double.tryParse(purchase.text) ?? 0,
                        taxPercent: double.tryParse(tax.text) ?? 0,
                        unit: unitVal,
                        openingStock: showOpeningStock
                            ? (double.tryParse(opening.text) ?? 0)
                            : 0,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to save product: $e')),
                    );
                  }
                },
                child: Text(isEdit ? 'Update' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );

    purchaseFocus.dispose();
    sellingFocus.dispose();
  }

  /// A short, human-friendly product code, e.g. `PRD-4F2A9C`.
  String _generateProductCode() {
    final suffix =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'PRD-${suffix.substring(suffix.length - 6)}';
  }

  /// A valid EAN-13 barcode using the in-store "20" prefix + check digit, for
  /// products that don't carry a manufacturer barcode.
  String _generateEan13() {
    final base = DateTime.now().millisecondsSinceEpoch.toString();
    final body = ('20$base').padLeft(12, '0').substring(0, 12);
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final d = int.parse(body[i]);
      sum += (i.isEven) ? d : d * 3;
    }
    final check = (10 - (sum % 10)) % 10;
    return '$body$check';
  }

  Widget _priceField(
      TextEditingController ctrl, FocusNode node, String label) {
    return TextFormField(
      controller: ctrl,
      focusNode: node,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
          labelText: label, isDense: true, border: const OutlineInputBorder()),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, bool numeric = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}
