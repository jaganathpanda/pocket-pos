import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/seed/demo_business_type.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/store_catalog_seeder.dart';
import '../../../core/firestore/store_scope.dart';
import '../../mill_run/domain/milling_config.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../../warehouse/domain/inventory_mode.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRiceMill = ref.watch(isRiceMillProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BusinessTypeCard(),
          const SizedBox(height: 16),
          _InventoryModeCard(),
          const SizedBox(height: 16),
          if (isRiceMill) ...[
            _MillingConfigCard(),
            const SizedBox(height: 16),
          ],
          _DemoDataCard(),
        ],
      ),
    );
  }
}

// ── Business Type Card (read-only after registration) ─────────────────────────

class _BusinessTypeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeAsync = ref.watch(businessTypeProvider);
    final type = typeAsync.valueOrNull ?? DemoBusinessType.grocery;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Business Type',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            const SizedBox(height: 4),
            const Text(
              'Set at registration and cannot be changed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  Icon(
                    type == DemoBusinessType.riceMill
                        ? Icons.factory_rounded
                        : Icons.storefront_rounded,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type.label,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Icon(Icons.lock_outline,
                      size: 16, color: Colors.grey.shade500),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Milling Config Card (rice mill only) ─────────────────────────────────────

class _MillingConfigCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MillingConfigCard> createState() => _MillingConfigCardState();
}

class _MillingConfigCardState extends ConsumerState<_MillingConfigCard> {
  bool _saving = false;

  Future<void> _save(MillingConfig updated) async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null) return;
    setState(() => _saving = true);
    try {
      await storeCollection(ref.read(firestoreProvider), storeId, 'settings')
          .doc('milling_config')
          .set(updated.toMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milling settings saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config =
        ref.watch(millingConfigProvider).valueOrNull ?? MillingConfig.defaults();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.factory_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Milling Charge Defaults',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                const Spacer(),
                if (_saving)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Default rates used to auto-calculate milling charge invoices. '
              'Party-specific contracts can override these.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Charge basis
            DropdownButtonFormField<MillingChargeBasis>(
              value: config.defaultBasis,
              decoration: const InputDecoration(
                labelText: 'Charge basis',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final b in MillingChargeBasis.values)
                  DropdownMenuItem(value: b, child: Text(b.label)),
              ],
              onChanged: (v) {
                if (v != null) _save(config.copyWith(defaultBasis: v));
              },
            ),
            const SizedBox(height: 10),

            // Rate + GST row
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Rate / unit (₹)',
                    value: config.defaultRatePerUnit,
                    onSave: (v) => _save(config.copyWith(defaultRatePerUnit: v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    label: 'GST %',
                    value: config.defaultGstPercent,
                    onSave: (v) =>
                        _save(config.copyWith(defaultGstPercent: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Drying + Loading row
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Drying charge / unit (₹)',
                    value: config.defaultDryingChargePerUnit,
                    onSave: (v) => _save(
                        config.copyWith(defaultDryingChargePerUnit: v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    label: 'Loading charge / unit (₹)',
                    value: config.defaultLoadingChargePerUnit,
                    onSave: (v) => _save(
                        config.copyWith(defaultLoadingChargePerUnit: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bagging + Deduction row
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Bagging charge / unit (₹)',
                    value: config.defaultBaggingChargePerUnit,
                    onSave: (v) => _save(
                        config.copyWith(defaultBaggingChargePerUnit: v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    label: 'Deduction / unit (₹)',
                    value: config.defaultDeductionPerUnit,
                    onSave: (v) => _save(
                        config.copyWith(defaultDeductionPerUnit: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Yield threshold + TDS row
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Yield warning threshold (%)',
                    value: config.yieldWarningThresholdPercent,
                    onSave: (v) => _save(config.copyWith(
                        yieldWarningThresholdPercent: v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('TDS applicable',
                        style: TextStyle(fontSize: 14)),
                    value: config.tdsApplicable,
                    onChanged: (v) =>
                        _save(config.copyWith(tdsApplicable: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rate contracts link
            OutlinedButton.icon(
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('Manage Party Rate Contracts'),
              onPressed: () => context.push('/milling-contracts'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small inline numeric field that fires onSave when focus leaves.
class _NumField extends StatefulWidget {
  const _NumField({
    required this.label,
    required this.value,
    required this.onSave,
  });

  final String label;
  final double value;
  final void Function(double) onSave;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_NumField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onEditingComplete: _commit,
      onTapOutside: (_) => _commit(),
    );
  }

  void _commit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v != null) widget.onSave(v);
  }
}

// ── Demo Data Card ────────────────────────────────────────────────────────────

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
              value: current,
              decoration: const InputDecoration(
                labelText: 'Sample catalog',
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

// ── Inventory Mode Card ───────────────────────────────────────────────────────

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
