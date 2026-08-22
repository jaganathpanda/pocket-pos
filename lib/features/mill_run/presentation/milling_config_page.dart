import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_pos/features/store/presentation/store_auth_controller.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/store_scope.dart';
import '../domain/milling_config.dart';

class MillingConfigPage extends ConsumerStatefulWidget {
  const MillingConfigPage({super.key});

  @override
  ConsumerState<MillingConfigPage> createState() => _MillingConfigPageState();
}

class _MillingConfigPageState extends ConsumerState<MillingConfigPage> {
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
    final config = ref.watch(millingConfigProvider).valueOrNull ??
        MillingConfig.defaults();

    return Scaffold(
      appBar: AppBar(title: const Text('Milling Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.factory_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text('Charge Defaults',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 18)),
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
                          onSave: (v) =>
                              _save(config.copyWith(defaultRatePerUnit: v)),
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
                          onSave: (v) => _save(
                              config.copyWith(yieldWarningThresholdPercent: v)),
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
          ),
        ],
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
