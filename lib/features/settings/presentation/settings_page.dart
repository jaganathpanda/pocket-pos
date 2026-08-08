import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/seed/demo_business_type.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/store_catalog_seeder.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/models/discount_policy.dart';
import '../../../core/models/invoice_branding.dart';
import '../../../core/models/printer_config.dart';
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
          _InvoiceBrandingCard(),
          const SizedBox(height: 16),
          _DiscountPolicyCard(),
          const SizedBox(height: 16),
          _PrinterIntegrationCard(),
          const SizedBox(height: 16),
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

// ── Discount Policy Card ────────────────────────────────────────────────────

class _DiscountPolicyCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DiscountPolicyCard> createState() =>
      _DiscountPolicyCardState();
}

class _DiscountPolicyCardState extends ConsumerState<_DiscountPolicyCard> {
  final _maxCtrl = TextEditingController();
  bool _loaded = false;
  bool _enabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _maxCtrl.dispose();
    super.dispose();
  }

  void _loadOnce(DiscountPolicy policy) {
    if (_loaded) return;
    _loaded = true;
    _enabled = policy.enabled;
    _maxCtrl.text = policy.maxBillDiscountPercent.toStringAsFixed(
      policy.maxBillDiscountPercent % 1 == 0 ? 0 : 2,
    );
  }

  Future<void> _save() async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null) return;
    final max = double.tryParse(_maxCtrl.text.trim());
    if (max == null || max < 0 || max > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum discount must be between 0 and 100.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final policy = DiscountPolicy(
        enabled: _enabled,
        billLevelOnly: true,
        percentageOnly: true,
        maxBillDiscountPercent: max,
      );
      await storeCollection(ref.read(firestoreProvider), storeId, 'settings')
          .doc('discount_policy')
          .set(policy.toFirestoreMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount policy saved.')),
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
    final policy =
        ref.watch(discountPolicyProvider).valueOrNull ??
            const DiscountPolicy.defaults();
    _loadOnce(policy);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.percent_rounded, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bill Discount Policy',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Only bill-level percentage discount is allowed. Any discount above '
              'the configured maximum is blocked.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable bill-level discount'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _maxCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Maximum discount percentage',
                hintText: 'e.g. 15',
                suffixText: '%',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mode: Bill level only • Percentage only',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Printer Integration Card ─────────────────────────────────────────────────

class _PrinterIntegrationCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PrinterIntegrationCard> createState() =>
      _PrinterIntegrationCardState();
}

class _PrinterIntegrationCardState extends ConsumerState<_PrinterIntegrationCard> {
  final _deviceCtrl = TextEditingController();
  bool _loaded = false;
  bool _enabled = false;
  bool _allowPdfFallback = false;
  bool _saving = false;
  bool _scanning = false;
  bool _testing = false;
  PrinterConnectionOption _connection = PrinterConnectionOption.bluetooth;

  ({String label, Color color}) _effectiveMode() {
    if (_enabled && _allowPdfFallback) {
      return (label: 'Thermal + PDF fallback', color: Colors.teal);
    }
    if (_enabled) {
      return (label: 'Thermal only', color: Colors.green);
    }
    if (_allowPdfFallback) {
      return (label: 'PDF fallback only', color: Colors.orange);
    }
    return (label: 'Printing disabled', color: Colors.red);
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    super.dispose();
  }

  void _loadOnce(PrinterConfig config) {
    if (_loaded) return;
    _loaded = true;
    _enabled = config.enabled;
    _allowPdfFallback = config.allowPdfFallback;
    _connection = config.connection;
    _deviceCtrl.text = config.deviceIdentifier;
  }

  Future<void> _save() async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null) return;

    setState(() => _saving = true);
    try {
      final config = PrinterConfig(
        enabled: _enabled,
        allowPdfFallback: _allowPdfFallback,
        connection: _connection,
        deviceIdentifier: _deviceCtrl.text.trim(),
      );
      await storeCollection(ref.read(firestoreProvider), storeId, 'settings')
          .doc('printer_config')
          .set(config.toFirestoreMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer settings saved.')),
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

  Future<void> _scanAndPick() async {
    setState(() => _scanning = true);
    try {
      final service = ref.read(printerServiceProvider);
      final devices = await service.scanDevices(_connection);
      if (!mounted) return;
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No printers found.')),
        );
        return;
      }

      final chosen = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final d = devices[index];
                final id = service.deviceIdentifier(d);
                return ListTile(
                  leading: Icon(_connection == PrinterConnectionOption.usb
                      ? Icons.usb
                      : Icons.bluetooth),
                  title: Text(d.name),
                  subtitle: Text(id),
                  onTap: () => Navigator.pop(ctx, id),
                );
              },
            ),
          );
        },
      );

      if (chosen != null) {
        setState(() => _deviceCtrl.text = chosen);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      final config = PrinterConfig(
        enabled: _enabled,
        allowPdfFallback: _allowPdfFallback,
        connection: _connection,
        deviceIdentifier: _deviceCtrl.text.trim(),
      );
      final branding =
          ref.read(invoiceBrandingProvider).valueOrNull ??
              const InvoiceBranding.defaults();
      final storeName = ref.read(storeSessionProvider)?.storeName ?? 'Pocket POS';
      await ref.read(printerServiceProvider).printInvoice(
            config: config,
            branding: branding,
            fallbackShopName: storeName,
            invoiceNo: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
            items: const [
              (
                name: 'Printer Test Item',
                qty: 1,
                discountAmount: 0,
                netAmount: 1,
              ),
            ],
            grandTotal: 1,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test receipt sent to printer.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = ref.read(printerServiceProvider).toUserMessage(e);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print failed: $msg')));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config =
        ref.watch(printerConfigProvider).valueOrNull ??
            const PrinterConfig.defaults();
    final mode = _effectiveMode();
    _loadOnce(config);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.print_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bluetooth / USB Printer Integration',
                        style:
                            TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: mode.color.withOpacity(0.12),
                          side: BorderSide(color: mode.color.withOpacity(0.35)),
                          label: Text(
                            mode.label,
                            style: TextStyle(
                              color: mode.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'When enabled, invoice print actions will use direct ESC/POS printer output. '
              'When disabled, print can stay available only if PDF fallback is enabled.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable direct printer integration'),
              subtitle: const Text(
                'Feature flag controlling all invoice print actions.',
                style: TextStyle(fontSize: 12),
              ),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow PDF fallback when direct print is unavailable'),
              subtitle: const Text(
                'Keeps print action available using PDF share/print flows.',
                style: TextStyle(fontSize: 12),
              ),
              value: _allowPdfFallback,
              onChanged: (v) => setState(() => _allowPdfFallback = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PrinterConnectionOption>(
              value: _connection,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Printer transport',
              ),
              items: const [
                DropdownMenuItem(
                  value: PrinterConnectionOption.bluetooth,
                  child: Text('Bluetooth'),
                ),
                DropdownMenuItem(
                  value: PrinterConnectionOption.usb,
                  child: Text('USB'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _connection = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _deviceCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                labelText: _connection == PrinterConnectionOption.usb
                    ? 'USB device identifier'
                    : 'Bluetooth device identifier',
                hintText: 'Use Scan to fill this automatically',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _scanning ? null : _scanAndPick,
                  icon: _scanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Scan Printers'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: (_testing || !_enabled) ? null : _testPrint,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_outlined),
                  label: const Text('Test Print'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invoice Branding Card ─────────────────────────────────────────────────────

class _InvoiceBrandingCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_InvoiceBrandingCard> createState() =>
      _InvoiceBrandingCardState();
}

class _InvoiceBrandingCardState extends ConsumerState<_InvoiceBrandingCard> {
  final _displayNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstinCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  void _loadOnce(InvoiceBranding b) {
    if (_loaded) return;
    _loaded = true;
    _displayNameCtrl.text = b.displayName;
    _addressCtrl.text = b.address;
    _phoneCtrl.text = b.phone;
    _emailCtrl.text = b.email;
    _gstinCtrl.text = b.gstin;
    _prefixCtrl.text = b.invoicePrefix;
  }

  Future<void> _save() async {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null) return;

    final prefix = _prefixCtrl.text.trim().toUpperCase();
    if (prefix.isEmpty || prefix.length > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Invoice prefix must be 1–8 uppercase characters.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final branding = InvoiceBranding(
        displayName: _displayNameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim(),
        invoicePrefix: prefix,
      );
      await storeCollection(ref.read(firestoreProvider), storeId, 'settings')
          .doc('invoice_branding')
          .set(branding.toFirestoreMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice branding saved.')),
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
    final brandingAsync = ref.watch(invoiceBrandingProvider);
    final branding =
        brandingAsync.valueOrNull ?? const InvoiceBranding.defaults();
    _loadOnce(branding);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Invoice Branding',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                ),
                if (_saving)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Displayed on every printed receipt and PDF invoice.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _displayNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display name on invoice',
                hintText: 'e.g. Shree Ram Kirana Store',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Shop No. 12, Main Road, City – 560001',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone / Mobile',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gstinCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN',
                      hintText: '29AABCU9603R1ZX',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _prefixCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Invoice prefix',
                      hintText: 'INV',
                      helperText: 'e.g. INV → INV-1720000000',
                      border: OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
