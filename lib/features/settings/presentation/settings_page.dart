import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/seed/demo_business_type.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/store_catalog_seeder.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../../warehouse/domain/inventory_mode.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InventoryModeCard(),
          const SizedBox(height: 16),
          _DemoDataCard(),
        ],
      ),
    );
  }
}

class _DemoDataCard extends ConsumerWidget {
  Future<void> _load(
      BuildContext context, WidgetRef ref, DemoBusinessType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Load ${type.label} sample data?'),
        content: const Text(
            'This replaces all current products, categories and stock with the '
            'selected sample catalog. Users, warehouses and customers are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load')),
        ],
      ),
    );
    if (confirmed != true) return;

    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null) return;
    try {
      await ref.read(storeCatalogSeederProvider).load(type, storeId);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(salesReportProvider);
      ref.invalidate(creditLedgerProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${type.label} sample data.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(demoBusinessTypeProvider).valueOrNull ??
        DemoBusinessType.grocery;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sample Data',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            const SizedBox(height: 4),
            const Text(
              'Load ready-made products for your type of business. '
              'Selecting a type replaces the current catalog.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DemoBusinessType>(
              initialValue: current,
              decoration: const InputDecoration(
                labelText: 'Business type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final t in DemoBusinessType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (t) {
                if (t != null && t != current) _load(context, ref, t);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryModeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(inventoryModeProvider).valueOrNull ?? InventoryMode.single;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventory Mode',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            const SizedBox(height: 4),
            const Text('Controls how stock is tracked across the app.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            for (final mode in InventoryMode.values)
              RadioListTile<InventoryMode>(
                contentPadding: EdgeInsets.zero,
                value: mode,
                groupValue: current,
                title: Text(mode.label),
                subtitle: Text(mode.description,
                    style: const TextStyle(fontSize: 12)),
                onChanged: (v) async {
                  if (v == null || v == current) return;
                  await ref.read(warehouseRepositoryProvider).setMode(v);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Inventory mode: ${v.label}')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
