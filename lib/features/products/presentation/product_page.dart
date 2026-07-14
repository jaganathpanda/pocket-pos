import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../barcode/presentation/barcode_scanner_page.dart';
import '../../barcode/presentation/hid_scanner_listener.dart';

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
    final code = TextEditingController(text: product?.productCode ?? '');
    final barcode = TextEditingController(text: product?.barcode ?? '');
    final selling = TextEditingController(text: (product?.sellingPrice ?? 0).toStringAsFixed(2));
    final purchase = TextEditingController(text: (product?.purchasePrice ?? 0).toStringAsFixed(2));
    final tax = TextEditingController(text: (product?.taxPercent ?? 0).toStringAsFixed(1));
    final unit = TextEditingController(text: product?.unit ?? 'piece');
    final formKey = GlobalKey<FormState>();
    int? selectedCategoryId = product?.categoryId;

    await showDialog<void>(
      context: context,
      builder: (ctx) => HidScannerListener(
        onScan: (code) => barcode.text = code,
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
                  _field(name, 'Name *', required: true),
                  const SizedBox(height: 8),
                  _field(code, 'Product Code *', required: true),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('No category')),
                      for (final c in allCategories) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => selectedCategoryId = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: barcode,
                    decoration: InputDecoration(
                      labelText: 'Barcode (optional)',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      helperText: 'Scan with camera, or a USB/Bluetooth (HID) scanner',
                      suffixIcon: IconButton(
                        tooltip: 'Scan with camera',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          final code = await scanBarcodeWithCamera(ctx);
                          if (code != null) barcode.text = code;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _field(purchase, 'Purchase Price *', numeric: true, required: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(selling, 'Selling Price *', numeric: true, required: true)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _field(tax, 'Tax %', numeric: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _field(unit, 'Unit (piece/kg/ltr...)')),
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final barcodeVal = barcode.text.trim().isEmpty ? null : barcode.text.trim();
              final unitVal = unit.text.trim().isEmpty ? 'piece' : unit.text.trim();
              if (isEdit) {
                await ref.read(productRepositoryProvider).update(
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
                await ref.read(productRepositoryProvider).add(
                      name: name.text.trim(),
                      productCode: code.text.trim(),
                      barcode: barcodeVal,
                      categoryId: selectedCategoryId,
                      sellingPrice: double.tryParse(selling.text) ?? 0,
                      purchasePrice: double.tryParse(purchase.text) ?? 0,
                      taxPercent: double.tryParse(tax.text) ?? 0,
                      unit: unitVal,
                    );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Update' : 'Save'),
          ),
        ],
        ),
      ),
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
