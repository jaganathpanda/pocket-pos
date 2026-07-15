import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../warehouse/domain/inventory_mode.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final Set<int> _selected = {};
  bool _bulkMode = false;

  /// The warehouse stock adjustments apply to.
  int? _resolveWarehouse(InventoryMode mode, List<Warehouse> warehouses) {
    if (warehouses.isEmpty) return null;
    final defaultWh =
        warehouses.firstWhere((w) => w.isDefault, orElse: () => warehouses.first);
    if (mode == InventoryMode.multiple) {
      return ref.watch(selectedInventoryWarehouseProvider) ?? defaultWh.id;
    }
    return defaultWh.id;
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(inventoryModeProvider).valueOrNull ?? InventoryMode.single;

    if (mode == InventoryMode.none) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Inventory tracking is turned off.\nEnable it in Settings → Inventory Mode.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? const <Warehouse>[];
    final multiple = mode == InventoryMode.multiple;
    final activeWarehouseId = _resolveWarehouse(mode, warehouses);
    final inventory = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (_bulkMode && _selected.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: activeWarehouseId == null
                  ? null
                  : () => _bulkUpdateDialog(context, activeWarehouseId),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text('Update ${_selected.length} selected'),
            ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() {
              _bulkMode = !_bulkMode;
              _selected.clear();
            }),
            icon: Icon(_bulkMode ? Icons.close : Icons.checklist_rounded),
            label: Text(_bulkMode ? 'Cancel Bulk' : 'Bulk Update'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (multiple)
            _WarehouseBar(
              warehouses: warehouses,
              selectedId: activeWarehouseId,
              onChanged: (id) => ref
                  .read(selectedInventoryWarehouseProvider.notifier)
                  .state = id,
            ),
          Expanded(
            child: inventory.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No inventory records yet.'));
                }
                return Column(
                  children: [
                    if (_bulkMode)
                      Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Select products to bulk update stock'),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                if (_selected.length == list.length) {
                                  _selected.clear();
                                } else {
                                  _selected
                                    ..clear()
                                    ..addAll(list.map((i) => i.product.id));
                                }
                              }),
                              child: Text(_selected.length == list.length
                                  ? 'Deselect All'
                                  : 'Select All'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final low = item.inventory.availableStock <=
                              item.inventory.lowStockThreshold;
                          final out = item.inventory.availableStock <= 0;
                          final isSelected =
                              _selected.contains(item.product.id);

                          return ListTile(
                            leading: _bulkMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => setState(() {
                                      if (isSelected) {
                                        _selected.remove(item.product.id);
                                      } else {
                                        _selected.add(item.product.id);
                                      }
                                    }),
                                  )
                                : CircleAvatar(
                                    backgroundColor: out
                                        ? Colors.red.shade100
                                        : low
                                            ? Colors.orange.shade100
                                            : Colors.green.shade100,
                                    child: Icon(
                                      out
                                          ? Icons.remove_circle_outline
                                          : Icons.inventory_2_outlined,
                                      size: 18,
                                      color: out
                                          ? Colors.red
                                          : low
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                  ),
                            title: Text(item.product.name,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${item.inventory.availableStock.toStringAsFixed(item.inventory.availableStock % 1 == 0 ? 0 : 1)} ${item.product.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: out
                                        ? Colors.red
                                        : low
                                            ? Colors.orange
                                            : Colors.green.shade700,
                                  ),
                                ),
                                if (multiple && item.warehouseName != null)
                                  Text('@ ${item.warehouseName}',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.indigo)),
                                if (out)
                                  const Text('OUT OF STOCK',
                                      style:
                                          TextStyle(fontSize: 10, color: Colors.red))
                                else if (low)
                                  const Text('LOW STOCK',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.orange)),
                                Text('Min: ${item.inventory.lowStockThreshold}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            trailing: _bulkMode || activeWarehouseId == null
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Stock In',
                                        icon: const Icon(Icons.add_circle_outline,
                                            color: Colors.green),
                                        onPressed: () => _stockAdjustDialog(
                                          context,
                                          warehouseId: activeWarehouseId,
                                          productId: item.product.id,
                                          productName: item.product.name,
                                          mode: _AdjustMode.stockIn,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Stock Out',
                                        icon: const Icon(Icons.remove_circle_outline,
                                            color: Colors.orange),
                                        onPressed: () => _stockAdjustDialog(
                                          context,
                                          warehouseId: activeWarehouseId,
                                          productId: item.product.id,
                                          productName: item.product.name,
                                          mode: _AdjustMode.stockOut,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Set Stock',
                                        icon: const Icon(Icons.edit_note_rounded,
                                            color: Colors.blue),
                                        onPressed: () => _stockAdjustDialog(
                                          context,
                                          warehouseId: activeWarehouseId,
                                          productId: item.product.id,
                                          productName: item.product.name,
                                          mode: _AdjustMode.setStock,
                                          currentQty:
                                              item.inventory.availableStock,
                                        ),
                                      ),
                                      if (multiple)
                                        IconButton(
                                          tooltip: 'Transfer',
                                          icon: const Icon(
                                              Icons.swap_horiz_rounded,
                                              color: Colors.indigo),
                                          onPressed: () => _transferDialog(
                                            context,
                                            fromWarehouseId: activeWarehouseId,
                                            productId: item.product.id,
                                            productName: item.product.name,
                                            available:
                                                item.inventory.availableStock,
                                            warehouses: warehouses,
                                          ),
                                        ),
                                    ],
                                  ),
                            onTap: _bulkMode
                                ? () => setState(() {
                                      if (isSelected) {
                                        _selected.remove(item.product.id);
                                      } else {
                                        _selected.add(item.product.id);
                                      }
                                    })
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stockAdjustDialog(
    BuildContext context, {
    required int warehouseId,
    required int productId,
    required String productName,
    required _AdjustMode mode,
    double? currentQty,
  }) async {
    final qty = TextEditingController(
      text: mode == _AdjustMode.setStock ? (currentQty?.toStringAsFixed(0) ?? '0') : '1',
    );

    final title = switch (mode) {
      _AdjustMode.stockIn => 'Stock In — $productName',
      _AdjustMode.stockOut => 'Stock Out — $productName',
      _AdjustMode.setStock => 'Set Stock — $productName',
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mode == _AdjustMode.setStock)
              const Text('Enter the new absolute stock quantity.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: qty,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: mode == _AdjustMode.setStock ? 'New Stock Quantity' : 'Quantity',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.inventory_2_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(qty.text) ?? 0;
              if (value < 0) return;
              final repo = ref.read(inventoryRepositoryProvider);
              switch (mode) {
                case _AdjustMode.stockIn:
                  if (value > 0) {
                    await repo.stockIn(productId: productId, warehouseId: warehouseId, quantity: value);
                  }
                case _AdjustMode.stockOut:
                  if (value > 0) {
                    await repo.stockOut(productId: productId, warehouseId: warehouseId, quantity: value);
                  }
                case _AdjustMode.setStock:
                  await repo.setStock(productId: productId, warehouseId: warehouseId, quantity: value);
              }
              ref.invalidate(dashboardMetricsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _transferDialog(
    BuildContext context, {
    required int fromWarehouseId,
    required int productId,
    required String productName,
    required double available,
    required List<Warehouse> warehouses,
  }) async {
    final targets = warehouses.where((w) => w.id != fromWarehouseId && w.isActive).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add another warehouse to transfer stock.')),
      );
      return;
    }
    final qty = TextEditingController(text: '1');
    int toId = targets.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Transfer — $productName', style: const TextStyle(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available here: ${available.toStringAsFixed(available % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: toId,
                decoration: const InputDecoration(
                    labelText: 'To warehouse', border: OutlineInputBorder()),
                items: [
                  for (final w in targets)
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => setDialogState(() => toId = v ?? toId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qty,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Quantity', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Transfer')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final value = double.tryParse(qty.text) ?? 0;
    try {
      await ref.read(inventoryRepositoryProvider).transferStock(
            productId: productId,
            fromWarehouseId: fromWarehouseId,
            toWarehouseId: toId,
            quantity: value,
          );
      ref.invalidate(dashboardMetricsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock transferred')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _bulkUpdateDialog(BuildContext context, int warehouseId) async {
    final qty = TextEditingController(text: '0');
    String mode = 'set';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Bulk Update — ${_selected.length} products'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'set', label: Text('Set')),
                    ButtonSegment(value: 'add', label: Text('Add')),
                    ButtonSegment(value: 'remove', label: Text('Remove')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setDialogState(() => mode = s.first),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qty,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(qty.text) ?? 0;
                if (value < 0) return;
                final repo = ref.read(inventoryRepositoryProvider);
                for (final productId in _selected) {
                  switch (mode) {
                    case 'set':
                      await repo.setStock(productId: productId, warehouseId: warehouseId, quantity: value);
                    case 'add':
                      if (value > 0) await repo.stockIn(productId: productId, warehouseId: warehouseId, quantity: value);
                    case 'remove':
                      if (value > 0) await repo.stockOut(productId: productId, warehouseId: warehouseId, quantity: value);
                  }
                }
                ref.invalidate(dashboardMetricsProvider);
                setState(() {
                  _selected.clear();
                  _bulkMode = false;
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bulk stock update applied')),
                  );
                }
              },
              child: const Text('Apply to All Selected'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseBar extends StatelessWidget {
  const _WarehouseBar({
    required this.warehouses,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Warehouse> warehouses;
  final int? selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warehouse_rounded, size: 18),
          const SizedBox(width: 8),
          const Text('Warehouse:'),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedId,
              underline: const SizedBox.shrink(),
              items: [
                for (final w in warehouses)
                  DropdownMenuItem(
                    value: w.id,
                    child: Text(w.isDefault ? '${w.name} (default)' : w.name),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _AdjustMode { stockIn, stockOut, setStock }
