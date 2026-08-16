import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';
import '../domain/mill_run_models.dart';
import '../domain/milling_config.dart';

class MillRunPage extends ConsumerWidget {
  const MillRunPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(millRunsProvider);
    final config = ref.watch(millingConfigProvider).valueOrNull ??
        MillingConfig.defaults();

    return Scaffold(
      appBar: AppBar(title: const Text('Mill Runs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRunDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Run'),
      ),
      body: runsAsync.when(
        data: (runs) => runs.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.factory_rounded, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No mill runs yet.',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: runs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) =>
                    _MillRunTile(mw: runs[i], config: config),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showRunDialog(BuildContext context, WidgetRef ref,
      [MillRunWithOutputs? existing]) async {
    final products =
        ref.read(productsProvider).valueOrNull ?? const <Product>[];
    final warehouses =
        (ref.read(warehousesProvider).valueOrNull ?? const <Warehouse>[])
            .where((w) => w.isActive)
            .toList();

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add products before creating a mill run.')),
      );
      return;
    }

    // Pre-select paddy products (category heuristic: name contains 'Paddy').
    final paddyProducts =
        products.where((p) => p.name.toLowerCase().contains('paddy')).toList();
    final allProducts = products;

    final paddyCtrl = TextEditingController(
        text: existing?.run.paddyConsumedKg.toString() ?? '');
    final lotCtrl = TextEditingController(text: existing?.run.lotNumber ?? '');
    final noteCtrl = TextEditingController(text: existing?.run.note ?? '');

    int? selectedPaddyProductId = existing?.run.paddyProductId ??
        (paddyProducts.isNotEmpty ? paddyProducts.first.id : null);
    int? selectedWarehouseId = existing?.run.warehouseId ??
        (warehouses.isNotEmpty
            ? warehouses
                .firstWhere((w) => w.isDefault, orElse: () => warehouses.first)
                .id
            : null);
    DateTime runDate = existing?.run.runDate ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final dialogWidth = MediaQuery.sizeOf(ctx).width > 620
            ? 620.0
            : MediaQuery.sizeOf(ctx).width * 0.95;
        return StatefulBuilder(
          builder: (ctx, setState) => Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? 'New Mill Run' : 'Edit Mill Run',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    // Run date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded),
                      title: Text(DateFormat('dd MMM yyyy').format(runDate)),
                      subtitle: const Text('Run date'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: runDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => runDate = picked);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Warehouse
                    if (warehouses.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: selectedWarehouseId,
                        decoration: const InputDecoration(
                          labelText: 'Godown / Warehouse',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.warehouse_rounded),
                        ),
                        items: [
                          for (final w in warehouses)
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                        ],
                        onChanged: (v) =>
                            setState(() => selectedWarehouseId = v),
                      ),
                    const SizedBox(height: 10),

                    // Paddy product
                    DropdownButtonFormField<int>(
                      value:
                          allProducts.any((p) => p.id == selectedPaddyProductId)
                              ? selectedPaddyProductId
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'Paddy (Input) Product',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.grass_rounded),
                      ),
                      items: [
                        for (final p in allProducts)
                          DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (v) =>
                          setState(() => selectedPaddyProductId = v),
                    ),
                    const SizedBox(height: 10),

                    // Paddy qty
                    TextField(
                      controller: paddyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Paddy consumed (qty)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.scale_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Lot number
                    TextField(
                      controller: lotCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Lot / Batch number (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Note
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final qty =
                                double.tryParse(paddyCtrl.text.trim()) ?? 0;
                            if (selectedPaddyProductId == null ||
                                selectedWarehouseId == null ||
                                qty <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Fill paddy product, warehouse, and qty.')),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            try {
                              if (existing == null) {
                                final id = await ref
                                    .read(millRunRepositoryProvider)
                                    .createRun(
                                      warehouseId: selectedWarehouseId!,
                                      paddyProductId: selectedPaddyProductId!,
                                      paddyConsumedKg: qty,
                                      runDate: runDate,
                                      lotNumber: lotCtrl.text.trim().isEmpty
                                          ? null
                                          : lotCtrl.text.trim(),
                                      note: noteCtrl.text.trim().isEmpty
                                          ? null
                                          : noteCtrl.text.trim(),
                                    );
                                if (context.mounted) {
                                  _showOutputsSheet(
                                    context,
                                    ref,
                                    id,
                                    allProducts,
                                  );
                                }
                              } else {
                                await ref
                                    .read(millRunRepositoryProvider)
                                    .updateRun(
                                      id: existing.run.id,
                                      warehouseId: selectedWarehouseId!,
                                      paddyProductId: selectedPaddyProductId!,
                                      paddyConsumedKg: qty,
                                      runDate: runDate,
                                      lotNumber: lotCtrl.text.trim().isEmpty
                                          ? null
                                          : lotCtrl.text.trim(),
                                      note: noteCtrl.text.trim().isEmpty
                                          ? null
                                          : noteCtrl.text.trim(),
                                    );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                          child: Text(existing == null ? 'Create' : 'Save'),
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

  void _showOutputsSheet(
    BuildContext context,
    WidgetRef ref,
    int millRunId,
    List<Product> products,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) =>
          _OutputsSheet(millRunId: millRunId, products: products, ref: ref),
    );
  }
}

// ── Mill Run List Tile ────────────────────────────────────────────────────────

class _MillRunTile extends ConsumerWidget {
  const _MillRunTile({required this.mw, required this.config});

  final MillRunWithOutputs mw;
  final MillingConfig config;

  Color _statusColor(MillRunStatus s) => switch (s) {
        MillRunStatus.draft => Colors.orange,
        MillRunStatus.completed => Colors.green,
        MillRunStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = mw.run;
    final products =
        ref.watch(productsProvider).valueOrNull ?? const <Product>[];

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: _statusColor(run.status).withOpacity(0.15),
        child: Icon(Icons.factory_rounded,
            color: _statusColor(run.status), size: 20),
      ),
      title: Text(
        '${DateFormat('dd MMM yyyy').format(run.runDate)}'
        '${run.lotNumber != null ? '  •  Lot: ${run.lotNumber}' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${mw.paddyProductName ?? 'Unknown paddy'}  •  '
        '${run.paddyConsumedKg} qty input  •  '
        'Yield ${mw.yieldPercent.toStringAsFixed(1)}%  •  '
        '${mw.warehouseName ?? ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Chip(
        label: Text(run.status.label, style: const TextStyle(fontSize: 11)),
        backgroundColor: _statusColor(run.status).withOpacity(0.12),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      children: [
        // Output lines
        if (mw.outputs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                const TableRow(
                  children: [
                    Text('Output Product',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                    Text('Qty',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                    Text('Grade',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey)),
                  ],
                ),
                for (final o in mw.outputs)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        mw.outputProducts[o.productId] ??
                            'Product ${o.productId}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text('${o.quantityKg}',
                        style: const TextStyle(fontSize: 13)),
                    Text(o.grade ?? '—', style: const TextStyle(fontSize: 13)),
                  ]),
              ],
            ),
          )
        else if (run.status == MillRunStatus.draft)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('No outputs added yet.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

        // Yield warning
        if (run.status == MillRunStatus.completed &&
            mw.yieldPercent < config.yieldWarningThresholdPercent)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  'Yield ${mw.yieldPercent.toStringAsFixed(1)}% is below '
                  'warning threshold (${config.yieldWarningThresholdPercent}%)',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ),

        // Action row
        if (run.status == MillRunStatus.draft)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Outputs'),
                  onPressed: () => _openOutputs(context, ref, products),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  onPressed: () =>
                      MillRunPage()._showRunDialog(context, ref, mw),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Complete'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _complete(context, ref),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _cancelRun(context, ref),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _openOutputs(
      BuildContext context, WidgetRef ref, List<Product> products) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) =>
          _OutputsSheet(millRunId: mw.run.id, products: products, ref: ref),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Mill Run?'),
        content: const Text(
            'This will deduct paddy from inventory and stock-in all output products. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(millRunRepositoryProvider).complete(mw.run.id);
      ref.invalidate(millRunsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Mill run completed — inventory updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cancelRun(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Mill Run?'),
        content: const Text(
            'The run will be marked cancelled. No inventory changes will be made.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Run'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(millRunRepositoryProvider).cancel(mw.run.id);
    ref.invalidate(millRunsProvider);
  }
}

// ── Outputs bottom sheet ──────────────────────────────────────────────────────

class _OutputsSheet extends ConsumerStatefulWidget {
  const _OutputsSheet({
    required this.millRunId,
    required this.products,
    required this.ref,
  });

  final int millRunId;
  final List<Product> products;
  final WidgetRef ref;

  @override
  ConsumerState<_OutputsSheet> createState() => _OutputsSheetState();
}

class _OutputsSheetState extends ConsumerState<_OutputsSheet> {
  int? _selectedProductId;
  final _qtyCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  // Helper to get current run data
  MillRunWithOutputs? _getCurrentRun() {
    final runsAsync = ref.watch(millRunsProvider);
    return runsAsync.valueOrNull?.firstWhere(
      (r) => r.run.id == widget.millRunId,
      orElse: () => MillRunWithOutputs(
        run: _emptyRun(widget.millRunId),
        outputs: const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to trigger rebuilds
    final runsAsync = ref.watch(millRunsProvider);
    final mw = runsAsync.valueOrNull?.firstWhere(
      (r) => r.run.id == widget.millRunId,
      orElse: () => MillRunWithOutputs(
        run: _emptyRun(widget.millRunId),
        outputs: const [],
      ),
    );

    // Non-paddy products suggested for output
    final outputProducts = widget.products
        .where((p) => !p.name.toLowerCase().contains('paddy'))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Text('Mill Run Outputs',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Add output form — stacked layout avoids overflow on small screens
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: outputProducts.any((p) => p.id == _selectedProductId)
                        ? _selectedProductId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Output product',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final p in outputProducts)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _gradeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Grade (optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Output'),
                      onPressed: _addOutput,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Output list
            Expanded(
              child: mw == null || mw.outputs.isEmpty
                  ? const Center(
                      child: Text('No outputs yet.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: mw.outputs.length,
                      itemBuilder: (_, i) {
                        final o = mw.outputs[i];
                        final name =
                            mw.outputProducts[o.productId] ?? 'Product';
                        return ListTile(
                          leading: const Icon(Icons.grain_rounded),
                          title: Text(name),
                          subtitle: Text('Qty: ${o.quantityKg}'
                              '${o.grade != null ? '  •  ${o.grade}' : ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () async {
                              await ref
                                  .read(millRunRepositoryProvider)
                                  .removeOutput(o.id);
                              // Refresh the provider
                              ref.invalidate(millRunsProvider);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Output removed'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Summary footer
            if (mw != null && mw.outputs.isNotEmpty)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Total output: ${mw.totalOutputKg} '
                      '  |  Yield: ${mw.yieldPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOutput() async {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an output product.')));
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid quantity.')));
      return;
    }

    try {
      // Add the output
      await ref.read(millRunRepositoryProvider).addOutput(
            millRunId: widget.millRunId,
            productId: _selectedProductId!,
            quantityKg: qty,
            grade:
                _gradeCtrl.text.trim().isEmpty ? null : _gradeCtrl.text.trim(),
          );

      // Invalidate the provider to refresh the UI
      ref.invalidate(millRunsProvider);

      // Clear the form
      setState(() {
        _selectedProductId = null;
        _qtyCtrl.clear();
        _gradeCtrl.clear();
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Output added successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

MillRun _emptyRun(int id) => MillRun(
      id: id,
      runDate: DateTime.now(),
      warehouseId: 0,
      paddyProductId: 0,
      paddyConsumedKg: 0,
      status: MillRunStatus.draft,
      createdAt: DateTime.now(),
    );
