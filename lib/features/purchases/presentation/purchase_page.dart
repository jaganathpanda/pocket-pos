import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';
import '../domain/purchase_repository.dart';

class PurchasePage extends ConsumerWidget {
  const PurchasePage({super.key, this.initialSupplierId});

  final int? initialSupplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Entry')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewPurchaseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
      ),
      body: purchases.when(
        data: (list) => list.isEmpty
            ? const Center(child: Text('No purchases yet.'))
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final pw = list[index];
                  return _PurchaseTile(
                    pw: pw,
                    onFinalize: pw.purchase.status == 'draft'
                        ? () async {
                            await ref.read(purchaseRepositoryProvider).finalize(pw.purchase.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Purchase finalized — stock updated')),
                              );
                            }
                          }
                        : null,
                    onDelete: pw.purchase.status == 'draft'
                        ? () async {
                            await ref.read(purchaseRepositoryProvider).deletePurchase(pw.purchase.id);
                          }
                        : null,
                    onTap: () => _showItemsSheet(context, ref, pw.purchase),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showNewPurchaseDialog(BuildContext context, WidgetRef ref) async {
    final invoiceNo = TextEditingController();
    final note = TextEditingController();
    int? selectedSupplierId = initialSupplierId;

    final suppliers = await ref.read(supplierRepositoryProvider).search('');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final dialogWidth = size.width > 620 ? 620.0 : size.width * 0.94;

        return StatefulBuilder(
          builder: (ctx, setState) => Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SizedBox(
              width: dialogWidth,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Purchase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedSupplierId,
                      decoration: const InputDecoration(labelText: 'Vendor / Party', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Cash Purchase —')),
                        for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => selectedSupplierId = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: invoiceNo,
                      decoration: const InputDecoration(labelText: 'Vendor Invoice No.', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: note,
                      decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final id = await ref.read(purchaseRepositoryProvider).createPurchase(
                                  supplierId: selectedSupplierId,
                                  invoiceNo: invoiceNo.text.trim().isEmpty ? null : invoiceNo.text.trim(),
                                  note: note.text.trim().isEmpty ? null : note.text.trim(),
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              final db = ref.read(appDatabaseProvider);
                              final p = await (db.select(db.purchases)..where((x) => x.id.equals(id))).getSingle();
                              if (context.mounted) {
                                _showItemsSheet(context, ref, p);
                              }
                            }
                          },
                          child: const Text('Create & Add Items'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showItemsSheet(BuildContext context, WidgetRef ref, Purchase purchase) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = size.width > 900 ? 900.0 : size.width * 0.96;
    final dialogHeight = size.height > 760 ? 760.0 : size.height * 0.92;

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: _PurchaseItemsSheet(purchase: purchase),
        ),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.pw,
    required this.onTap,
    this.onFinalize,
    this.onDelete,
  });

  final PurchaseWithSupplier pw;
  final VoidCallback onTap;
  final VoidCallback? onFinalize;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = pw.purchase;
    final statusColor = p.status == 'received' ? Colors.green : Colors.orange;

    return ListTile(
      onTap: onTap,
      title: Row(
        children: [
          Text(pw.supplier?.name ?? 'Cash Purchase', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Chip(
            label: Text(p.status.toUpperCase(), style: const TextStyle(fontSize: 10)),
            backgroundColor: statusColor.withOpacity(0.15),
            side: BorderSide(color: statusColor),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.invoiceNo != null) Text('Invoice: ${p.invoiceNo}'),
          Text(
            'Date: ${p.purchasedAt.toLocal().toString().substring(0, 16)}  |  '
            'Items: —  |  Payment: ${p.paymentStatus}',
          ),
          if (onFinalize != null || onDelete != null)
            Wrap(
              spacing: 8,
              children: [
                if (onFinalize != null)
                  TextButton(
                    onPressed: onFinalize,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Finalize'),
                  ),
                if (onDelete != null)
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Delete'),
                  ),
              ],
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Text(formatInr(p.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _PurchaseItemsSheet extends ConsumerStatefulWidget {
  const _PurchaseItemsSheet({required this.purchase});

  final Purchase purchase;

  @override
  ConsumerState<_PurchaseItemsSheet> createState() => _PurchaseItemsSheetState();
}

class _PurchaseItemsSheetState extends ConsumerState<_PurchaseItemsSheet> {
  // controllers for the add-item dialog — kept here so they live in proper state
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(purchaseItemsProvider(widget.purchase.id));
    final isDraft = widget.purchase.status == 'draft';

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Purchase Items  ${isDraft ? "(Draft)" : "(Received)"}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isDraft)
                  FilledButton.icon(
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
              ],
            ),
            const Divider(),
            items.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No items. Tap "Add Item" to add products.')),
                  );
                }
                final total = list.fold<double>(0, (s, r) => s + r.item.lineTotal);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final row = list[i];
                          return ListTile(
                            title: Text(row.product.name),
                            subtitle: Text(
                              'Qty: ${row.item.quantity}  ×  Rs ${row.item.unitCost}  '
                              '| Tax: ${row.item.taxPercent}%',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formatInr(row.item.lineTotal)),
                                if (isDraft)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => ref
                                        .read(purchaseRepositoryProvider)
                                        .removeItem(row.item.id),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(formatInr(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    _searchCtrl.clear();
    _qtyCtrl.text = '1';
    _costCtrl.clear();
    _taxCtrl.text = '0';
    Product? selectedProduct;

    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final dialogWidth = size.width > 760 ? 760.0 : size.width * 0.94;
        final dialogHeight = size.height > 620 ? 620.0 : size.height * 0.9;

        return StatefulBuilder(
          builder: (ctx, setDlgState) => Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Purchase Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search Product',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: FutureBuilder<List<Product>>(
                        future: ref.read(productRepositoryProvider).search(_searchCtrl.text),
                        builder: (_, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final results = snap.data ?? const <Product>[];
                          if (results.isEmpty) {
                            return const Center(child: Text('No products found'));
                          }
                          return ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final p = results[i];
                              return ListTile(
                                title: Text(p.name),
                                subtitle: Text('MRP: Rs ${p.mrp}'),
                                selected: selectedProduct?.id == p.id,
                                onTap: () {
                                  setDlgState(() {
                                    selectedProduct = p;
                                    _costCtrl.text = p.purchasePrice.toStringAsFixed(2);
                                    _taxCtrl.text = p.taxPercent.toStringAsFixed(0);
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 20),
                    if (selectedProduct != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Selected: ${selectedProduct!.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Cost / Unit', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _taxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Tax %', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: selectedProduct == null
                              ? null
                              : () async {
                                  await ref.read(purchaseRepositoryProvider).addItem(
                                        purchaseId: widget.purchase.id,
                                        productId: selectedProduct!.id,
                                        quantity: double.tryParse(_qtyCtrl.text) ?? 1,
                                        unitCost: double.tryParse(_costCtrl.text) ?? 0,
                                        taxPercent: double.tryParse(_taxCtrl.text) ?? 0,
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
