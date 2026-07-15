import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';

class WarehousePage extends ConsumerWidget {
  const WarehousePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses = ref.watch(warehousesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Warehouses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Warehouse'),
      ),
      body: warehouses.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No warehouses yet. Tap + to add one.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final w = list[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.warehouse_rounded,
                    color: w.isActive ? Colors.indigo : Colors.grey,
                  ),
                  title: Row(
                    children: [
                      Flexible(child: Text(w.name)),
                      if (w.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text('DEFAULT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(w.isActive ? 'Active' : 'Inactive'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => _onAction(context, ref, w, v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      if (!w.isDefault)
                        const PopupMenuItem(
                            value: 'default', child: Text('Set as default')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(w.isActive ? 'Deactivate' : 'Activate'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
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

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, Warehouse w, String action) async {
    final repo = ref.read(warehouseRepositoryProvider);
    try {
      switch (action) {
        case 'rename':
          await _renameDialog(context, ref, w);
        case 'default':
          await repo.setDefaultWarehouse(w.id);
        case 'toggle':
          await repo.setWarehouseActive(w.id, !w.isActive);
        case 'delete':
          await repo.deleteWarehouse(w.id);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    bool makeDefault = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Warehouse'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Warehouse name', border: OutlineInputBorder()),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: makeDefault,
                onChanged: (v) => setState(() => makeDefault = v ?? false),
                title: const Text('Set as default'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(warehouseRepositoryProvider).addWarehouse(ctrl.text, isDefault: makeDefault);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref, Warehouse w) async {
    final ctrl = TextEditingController(text: w.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Warehouse'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Warehouse name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(warehouseRepositoryProvider).renameWarehouse(w.id, name);
  }
}
