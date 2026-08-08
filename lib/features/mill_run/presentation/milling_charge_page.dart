import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';
import '../domain/milling_charge_models.dart';
import '../domain/milling_config.dart';
import '../domain/mill_run_models.dart';

class MillingChargePage extends ConsumerWidget {
  const MillingChargePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(millingChargesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Milling Charges')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInvoiceDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
      body: invoicesAsync.when(
        data: (invoices) => invoices.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No milling charge invoices yet.',
                        style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 6),
                    Text(
                      'Create an invoice after completing a mill run.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: invoices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _InvoiceTile(invoice: invoices[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showInvoiceDialog(BuildContext context, WidgetRef ref,
      [MillingChargeInvoice? existing]) async {
    final config =
        ref.read(millingConfigProvider).valueOrNull ?? MillingConfig.defaults();
    final customers =
        ref.read(customersProvider).valueOrNull ?? const <Customer>[];
    final runs = (ref.read(millRunsProvider).valueOrNull ?? const <MillRunWithOutputs>[])
        .where((r) => r.run.status == MillRunStatus.completed)
        .toList();

    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a rice party / FCI customer before creating an invoice.')),
      );
      return;
    }
    if (runs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Complete a mill run before raising a milling charge invoice.')),
      );
      return;
    }

    int? selectedPartyId = existing?.partyId ??
        (customers.isNotEmpty ? customers.first.id : null);
    int? selectedRunId = existing?.millRunId ??
        (runs.isNotEmpty ? runs.first.run.id : null);

    MillingChargeBasis basis =
        existing?.chargeBasis ?? config.defaultBasis;

    final rateCtrl = TextEditingController(
        text: (existing?.ratePerUnit ?? config.defaultRatePerUnit).toString());
    final dryingCtrl = TextEditingController(
        text: (existing?.dryingChargePerUnit ?? config.defaultDryingChargePerUnit)
            .toString());
    final loadingCtrl = TextEditingController(
        text: (existing?.loadingChargePerUnit ?? config.defaultLoadingChargePerUnit)
            .toString());
    final baggingCtrl = TextEditingController(
        text: (existing?.baggingChargePerUnit ?? config.defaultBaggingChargePerUnit)
            .toString());
    final deductionCtrl = TextEditingController(
        text: (existing?.deductionPerUnit ?? config.defaultDeductionPerUnit)
            .toString());
    final gstCtrl = TextEditingController(
        text: (existing?.gstPercent ?? config.defaultGstPercent).toString());
    final tdsCtrl = TextEditingController(text: '0');
    final lotCtrl =
        TextEditingController(text: existing?.lotNumber ?? '');
    final noteCtrl =
        TextEditingController(text: existing?.note ?? '');
    DateTime invoiceDate = existing?.invoiceDate ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final dialogWidth = MediaQuery.sizeOf(ctx).width > 660
            ? 660.0
            : MediaQuery.sizeOf(ctx).width * 0.96;

        return StatefulBuilder(builder: (ctx, setState) {
          // Derive billed qty from selected run based on basis
          final selectedRun =
              runs.firstWhere((r) => r.run.id == selectedRunId,
                  orElse: () => runs.first);
          final autoQty = basis == MillingChargeBasis.perInputQuintal
              ? selectedRun.run.paddyConsumedKg
              : selectedRun.totalOutputKg;

          // Live preview calc
          final rate = double.tryParse(rateCtrl.text) ?? 0;
          final drying = double.tryParse(dryingCtrl.text) ?? 0;
          final loading = double.tryParse(loadingCtrl.text) ?? 0;
          final bagging = double.tryParse(baggingCtrl.text) ?? 0;
          final deduct = double.tryParse(deductionCtrl.text) ?? 0;
          final gst = double.tryParse(gstCtrl.text) ?? 0;
          final tds = double.tryParse(tdsCtrl.text) ?? 0;
          final gross = autoQty * (rate + drying + loading + bagging - deduct);
          final gstAmt = gross * gst / 100;
          final tdsAmt = gross * tds / 100;
          final net = gross + gstAmt - tdsAmt;

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null
                          ? 'New Milling Charge Invoice'
                          : 'Edit Invoice',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    // Invoice date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded),
                      title:
                          Text(DateFormat('dd MMM yyyy').format(invoiceDate)),
                      subtitle: const Text('Invoice date'),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: invoiceDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => invoiceDate = picked);
                        }
                      },
                    ),
                    const Divider(height: 20),

                    // Party
                    DropdownButtonFormField<int>(
                      value: customers.any((c) => c.id == selectedPartyId)
                          ? selectedPartyId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Rice Party / FCI Party',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      items: [
                        for (final c in customers)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => selectedPartyId = v),
                    ),
                    const SizedBox(height: 10),

                    // Mill run
                    DropdownButtonFormField<int>(
                      value:
                          runs.any((r) => r.run.id == selectedRunId)
                              ? selectedRunId
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'Completed Mill Run',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.factory_rounded),
                      ),
                      items: [
                        for (final r in runs)
                          DropdownMenuItem(
                            value: r.run.id,
                            child: Text(
                              '${DateFormat('dd MMM yy').format(r.run.runDate)}'
                              '  •  ${r.paddyProductName ?? 'Paddy'}'
                              '  •  ${r.run.paddyConsumedKg} qty'
                              '${r.run.lotNumber != null ? '  •  Lot: ${r.run.lotNumber}' : ''}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => selectedRunId = v),
                    ),
                    const SizedBox(height: 10),

                    // Charge basis
                    DropdownButtonFormField<MillingChargeBasis>(
                      value: basis,
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
                        if (v != null) setState(() => basis = v);
                      },
                    ),

                    // Auto qty chip
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Billed qty: $autoQty  '
                            '(auto from ${basis == MillingChargeBasis.perInputQuintal ? 'paddy consumed' : 'total output'})',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),

                    // Rate fields — two per row
                    Row(children: [
                      Expanded(
                          child: _RateField(
                              ctrl: rateCtrl,
                              label: 'Rate / unit (₹)',
                              onChanged: () => setState(() {}))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _RateField(
                              ctrl: dryingCtrl,
                              label: 'Drying (₹)',
                              onChanged: () => setState(() {}))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: _RateField(
                              ctrl: loadingCtrl,
                              label: 'Loading (₹)',
                              onChanged: () => setState(() {}))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _RateField(
                              ctrl: baggingCtrl,
                              label: 'Bagging (₹)',
                              onChanged: () => setState(() {}))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: _RateField(
                              ctrl: deductionCtrl,
                              label: 'Deduction (₹)',
                              onChanged: () => setState(() {}))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _RateField(
                              ctrl: gstCtrl,
                              label: 'GST %',
                              onChanged: () => setState(() {}))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: _RateField(
                              ctrl: tdsCtrl,
                              label: 'TDS %',
                              onChanged: () => setState(() {}))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                        controller: lotCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Lot / Contract ref',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      )),
                    ]),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live calculation preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Charge Preview',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          const SizedBox(height: 8),
                          _PreviewRow('Gross charge',
                              formatInr(gross.clamp(0, double.infinity))),
                          _PreviewRow('GST (${gst.toStringAsFixed(1)}%)',
                              formatInr(gstAmt.clamp(0, double.infinity))),
                          if (tds > 0)
                            _PreviewRow(
                                'TDS (${tds.toStringAsFixed(1)}%)',
                                '- ${formatInr(tdsAmt.clamp(0, double.infinity))}'),
                          const Divider(height: 12),
                          _PreviewRow(
                              'Net payable',
                              formatInr(net.clamp(0, double.infinity)),
                              bold: true),
                        ],
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
                            if (selectedPartyId == null ||
                                selectedRunId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Select a party and a mill run.')),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            try {
                              final repo = ref
                                  .read(millingChargeRepositoryProvider);
                              if (existing == null) {
                                await repo.createInvoice(
                                  partyId: selectedPartyId!,
                                  millRunId: selectedRunId!,
                                  chargeBasis: basis,
                                  billedQty: autoQty,
                                  ratePerUnit: double.tryParse(rateCtrl.text) ?? 0,
                                  dryingChargePerUnit: double.tryParse(dryingCtrl.text) ?? 0,
                                  loadingChargePerUnit: double.tryParse(loadingCtrl.text) ?? 0,
                                  baggingChargePerUnit: double.tryParse(baggingCtrl.text) ?? 0,
                                  deductionPerUnit: double.tryParse(deductionCtrl.text) ?? 0,
                                  gstPercent: double.tryParse(gstCtrl.text) ?? 0,
                                  tdsPercent: double.tryParse(tdsCtrl.text) ?? 0,
                                  invoiceDate: invoiceDate,
                                  lotNumber: lotCtrl.text.trim().isEmpty
                                      ? null
                                      : lotCtrl.text.trim(),
                                  note: noteCtrl.text.trim().isEmpty
                                      ? null
                                      : noteCtrl.text.trim(),
                                );
                              } else {
                                await repo.updateInvoice(
                                  id: existing.id,
                                  partyId: selectedPartyId!,
                                  millRunId: selectedRunId!,
                                  chargeBasis: basis,
                                  billedQty: autoQty,
                                  ratePerUnit: double.tryParse(rateCtrl.text) ?? 0,
                                  dryingChargePerUnit: double.tryParse(dryingCtrl.text) ?? 0,
                                  loadingChargePerUnit: double.tryParse(loadingCtrl.text) ?? 0,
                                  baggingChargePerUnit: double.tryParse(baggingCtrl.text) ?? 0,
                                  deductionPerUnit: double.tryParse(deductionCtrl.text) ?? 0,
                                  gstPercent: double.tryParse(gstCtrl.text) ?? 0,
                                  tdsPercent: double.tryParse(tdsCtrl.text) ?? 0,
                                  invoiceDate: invoiceDate,
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
          );
        });
      },
    );
  }
}

// ── Invoice Tile ──────────────────────────────────────────────────────────────

class _InvoiceTile extends ConsumerWidget {
  const _InvoiceTile({required this.invoice});
  final MillingChargeInvoice invoice;

  Color _statusColor(MillingChargeStatus s) => switch (s) {
        MillingChargeStatus.draft => Colors.orange,
        MillingChargeStatus.issued => Colors.blue,
        MillingChargeStatus.paid => Colors.green,
        MillingChargeStatus.partiallyPaid => Colors.purple,
        MillingChargeStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = invoice;
    final color = _statusColor(inv.status);

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(Icons.receipt_long_rounded, color: color, size: 20),
      ),
      title: Text(
        '${inv.invoiceNo}  •  ${inv.partyName ?? 'Party'}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${DateFormat('dd MMM yyyy').format(inv.invoiceDate)}'
        '  •  ${formatInr(inv.netPayable)}'
        '  •  Due: ${formatInr(inv.dueAmount.clamp(0, double.infinity))}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Chip(
        label: Text(inv.status.label,
            style: const TextStyle(fontSize: 11)),
        backgroundColor: color.withOpacity(0.12),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      children: [
        // Charge breakdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('Basis', inv.chargeBasis.label),
              _DetailRow('Billed qty', '${inv.billedQty}'),
              _DetailRow('Rate / unit', formatInr(inv.ratePerUnit)),
              if (inv.dryingChargePerUnit > 0)
                _DetailRow('Drying', formatInr(inv.dryingChargePerUnit)),
              if (inv.loadingChargePerUnit > 0)
                _DetailRow('Loading', formatInr(inv.loadingChargePerUnit)),
              if (inv.baggingChargePerUnit > 0)
                _DetailRow('Bagging', formatInr(inv.baggingChargePerUnit)),
              if (inv.deductionPerUnit > 0)
                _DetailRow('Deduction', '- ${formatInr(inv.deductionPerUnit)}'),
              const Divider(height: 12),
              _DetailRow('Gross charge', formatInr(inv.grossCharge)),
              _DetailRow(
                  'GST (${inv.gstPercent.toStringAsFixed(1)}%)',
                  formatInr(inv.gstAmount)),
              if (inv.tdsAmount > 0)
                _DetailRow(
                    'TDS (${inv.tdsPercent.toStringAsFixed(1)}%)',
                    '- ${formatInr(inv.tdsAmount)}'),
              _DetailRow('Net payable', formatInr(inv.netPayable),
                  bold: true),
              _DetailRow('Paid', formatInr(inv.paidAmount),
                  color: Colors.green),
              _DetailRow(
                  'Due',
                  formatInr(inv.dueAmount.clamp(0, double.infinity)),
                  color: inv.dueAmount > 0 ? Colors.red : Colors.green),
              if (inv.lotNumber != null)
                _DetailRow('Lot / Ref', inv.lotNumber!),
              if (inv.note != null) _DetailRow('Note', inv.note!),
            ],
          ),
        ),

        // Action row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (inv.status == MillingChargeStatus.draft) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  onPressed: () =>
                      MillingChargePage()._showInvoiceDialog(context, ref, inv),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Issue'),
                  onPressed: () => _issue(context, ref),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _delete(context, ref),
                ),
              ],
              if (inv.status == MillingChargeStatus.issued ||
                  inv.status == MillingChargeStatus.partiallyPaid) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.payments_rounded, size: 16),
                  label: const Text('Record Payment'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.green),
                  onPressed: () => _showPaymentSheet(context, ref),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Payments'),
                  onPressed: () => _showPaymentHistory(context, ref),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _cancel(context, ref),
                ),
              ],
              if (inv.status == MillingChargeStatus.paid)
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Payment History'),
                  onPressed: () => _showPaymentHistory(context, ref),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _issue(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Invoice?'),
        content: const Text(
            'Issuing locks the invoice from further edits. The party can be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Issue')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(millingChargeRepositoryProvider).issueInvoice(invoice.id);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(millingChargeRepositoryProvider).deleteInvoice(invoice.id);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invoice?'),
        content: const Text('No payment entries will be reversed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref
        .read(millingChargeRepositoryProvider)
        .cancelInvoice(invoice.id);
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) =>
          _PaymentSheet(invoice: invoice, ref: ref),
    );
  }

  Future<void> _showPaymentHistory(
      BuildContext context, WidgetRef ref) async {
    final payments = await ref
        .read(millingChargeRepositoryProvider)
        .getPayments(invoice.id);

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment History — ${invoice.invoiceNo}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            if (payments.isEmpty)
              const Text('No payments recorded.',
                  style: TextStyle(color: Colors.grey))
            else
              for (final p in payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_rounded),
                  title: Text(formatInr(p.amount)),
                  subtitle: Text(
                    '${p.method.toUpperCase()}'
                    '${p.referenceNo != null ? '  •  Ref: ${p.referenceNo}' : ''}',
                  ),
                  trailing: Text(
                    DateFormat('dd MMM yy').format(p.paidAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// ── Payment Sheet ─────────────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.invoice, required this.ref});
  final MillingChargeInvoice invoice;
  final WidgetRef ref;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _amtCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _amtCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final due =
        widget.invoice.dueAmount.clamp(0.0, double.infinity).toDouble();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record Payment — ${widget.invoice.invoiceNo}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Due: ${formatInr(due)}',
                style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _amtCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixText: formatInr(due),
                  ),
                  onTap: () {
                    if (_amtCtrl.text.isEmpty) {
                      _amtCtrl.text = due.toStringAsFixed(2);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _method,
                  decoration: const InputDecoration(
                    labelText: 'Method',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  ],
                  onChanged: (v) => setState(() => _method = v ?? 'cash'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Reference / Cheque no. (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.ref
          .read(millingChargeRepositoryProvider)
          .recordPayment(
            invoiceId: widget.invoice.id,
            amount: amt,
            method: _method,
            referenceNo: _refCtrl.text.trim().isEmpty
                ? null
                : _refCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _RateField extends StatelessWidget {
  const _RateField(
      {required this.ctrl,
      required this.label,
      required this.onChanged});
  final TextEditingController ctrl;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true),
      onChanged: (_) => onChanged(),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow(this.label, this.value,
      {this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontSize: bold ? 14 : 13,
        color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value,
      {this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontSize: 13,
        color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}

