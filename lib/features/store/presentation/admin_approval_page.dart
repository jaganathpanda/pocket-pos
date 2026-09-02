import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/storefront_shopping_config.dart';
import '../../notifications/domain/domain.dart';
import '../domain/store_models.dart';
import 'store_auth_controller.dart';

final _pendingStoresProvider = StreamProvider<List<StoreRecord>>((ref) {
  return ref
      .watch(storeAuthServiceProvider)
      .watchStoresByStatus(StoreStatus.pending);
});

final _approvedStoresProvider = StreamProvider<List<StoreRecord>>((ref) {
  return ref
      .watch(storeAuthServiceProvider)
      .watchStoresByStatus(StoreStatus.approved);
});

final _pendingOperatorsProvider =
    StreamProvider<List<OperatorProfile>>((ref) {
  return ref
      .watch(storeAuthServiceProvider)
      .watchOperatorsByStatus(StoreStatus.pending);
});

final _approvedOperatorsProvider =
    StreamProvider<List<OperatorProfile>>((ref) {
  return ref
      .watch(storeAuthServiceProvider)
      .watchOperatorsByStatus(StoreStatus.approved);
});

final _notificationFeaturesProvider =
    StreamProvider<NotificationFeatures>((ref) {
  return ref.watch(storeAuthServiceProvider).watchNotificationFeatures();
});

final _storefrontFeatureFlagProvider =
    StreamProvider<StorefrontShoppingConfig>((ref) {
  return ref.watch(storeAuthServiceProvider).watchStorefrontFeatureFlag();
});

class AdminApprovalPage extends ConsumerWidget {
  const AdminApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingStoresProvider);
    final approved = ref.watch(_approvedStoresProvider);
    final pendingOps = ref.watch(_pendingOperatorsProvider);
    final approvedOps = ref.watch(_approvedOperatorsProvider);
    final notificationFeatures = ref.watch(_notificationFeaturesProvider);
    final storefrontFeature = ref.watch(_storefrontFeatureFlagProvider);
    final service = ref.watch(storeAuthServiceProvider);

    Future<void> setStatus(StoreRecord s, StoreStatus status) async {
      try {
        await service.setStoreStatus(s.storeId, status);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    Future<void> setOpStatus(OperatorProfile o, StoreStatus status) async {
      try {
        await service.setOperatorStatus(o.uid, status);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    Future<void> updateNotificationFeatures(NotificationFeatures next) async {
      try {
        await service.setNotificationFeatures(next);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    Future<void> updateStorefrontFeatureFlag(
      StorefrontShoppingConfig next,
    ) async {
      try {
        await service.setStorefrontFeatureFlag(next);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Approvals'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(storeAuthControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SectionHeader('Notifications (Platform Feature Flags)'),
          notificationFeatures.when(
            data: (features) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NotificationConfigCard(
                      features: features,
                      onSave: updateNotificationFeatures,
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Notification flags error: $e'),
          ),
          const SizedBox(height: 12),
          storefrontFeature.when(
            data: (cfg) => Card(
              child: SwitchListTile.adaptive(
                title: const Text('Enable Public Storefront Shopping'),
                subtitle: const Text(
                  'Global master switch. When OFF, the customer storefront link '
                  'is hidden from store login for all stores.',
                ),
                value: cfg.allowAnonymousShopping,
                onChanged: (v) => updateStorefrontFeatureFlag(
                    cfg.copyWith(allowAnonymousShopping: v)),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Storefront feature flag error: $e'),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Pending approval'),
          pending.when(
            data: (list) => list.isEmpty
                ? const _Empty('No stores waiting for approval.')
                : Column(
                    children: [
                      for (final s in list)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.storefront_rounded,
                                color: Colors.orange),
                            title: Text('${s.name}  (${s.storeId})'),
                            subtitle: Text(
                                'Owner: ${s.ownerName}${s.mobile != null && s.mobile!.isNotEmpty ? ' • ${s.mobile}' : ''}'),
                            trailing: FilledButton(
                              onPressed: () =>
                                  setStatus(s, StoreStatus.approved),
                              child: const Text('Approve'),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Error: $e'),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Approved stores'),
          approved.when(
            data: (list) => list.isEmpty
                ? const _Empty('No approved stores yet.')
                : Column(
                    children: [
                      for (final s in list)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: Colors.green),
                            title: Text('${s.name}  (${s.storeId})'),
                            subtitle: Text('Owner: ${s.ownerName}'),
                            trailing: TextButton(
                              onPressed: () =>
                                  setStatus(s, StoreStatus.suspended),
                              child: const Text('Suspend'),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Error: $e'),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Pending weighbridge operators'),
          pendingOps.when(
            data: (list) => list.isEmpty
                ? const _Empty('No operators awaiting approval.')
                : Column(
                    children: [
                      for (final o in list)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.scale_rounded,
                                color: Colors.orange),
                            title: Text(o.name),
                            subtitle: Text(o.email),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setOpStatus(o, StoreStatus.suspended),
                                  child: const Text('Reject'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      setOpStatus(o, StoreStatus.approved),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Error: $e'),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Approved operators'),
          approvedOps.when(
            data: (list) => list.isEmpty
                ? const _Empty('No approved operators yet.')
                : Column(
                    children: [
                      for (final o in list)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.check_circle,
                                color: Colors.green),
                            title: Text(o.name),
                            subtitle: Text(o.email),
                            trailing: TextButton(
                              onPressed: () =>
                                  setOpStatus(o, StoreStatus.suspended),
                              child: const Text('Suspend'),
                            ),
                          ),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Empty('Error: $e'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );
}

class _NotificationConfigCard extends ConsumerStatefulWidget {
  const _NotificationConfigCard({
    required this.features,
    required this.onSave,
  });

  final NotificationFeatures features;
  final Future<void> Function(NotificationFeatures next) onSave;

  @override
  ConsumerState<_NotificationConfigCard> createState() =>
      _NotificationConfigCardState();
}

class _NotificationConfigCardState
    extends ConsumerState<_NotificationConfigCard> {
  late final TextEditingController _emailFromCtrl;
  late final TextEditingController _emailApiKeyCtrl;
  late final TextEditingController _smsFromCtrl;
  late final TextEditingController _smsAccountSidCtrl;
  late final TextEditingController _smsAuthTokenCtrl;
  late final TextEditingController _whatsappFromCtrl;
  late final TextEditingController _whatsappAccountSidCtrl;
  late final TextEditingController _whatsappAuthTokenCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailFromCtrl =
        TextEditingController(text: widget.features.emailFromAddress ?? '');
    _emailApiKeyCtrl =
        TextEditingController(text: widget.features.emailApiKey ?? '');
    _smsFromCtrl =
        TextEditingController(text: widget.features.smsFromNumber ?? '');
    _smsAccountSidCtrl =
        TextEditingController(text: widget.features.smsAccountSid ?? '');
    _smsAuthTokenCtrl =
        TextEditingController(text: widget.features.smsAuthToken ?? '');
    _whatsappFromCtrl =
        TextEditingController(text: widget.features.whatsappFromNumber ?? '');
    _whatsappAccountSidCtrl =
        TextEditingController(text: widget.features.whatsappAccountSid ?? '');
    _whatsappAuthTokenCtrl = TextEditingController(
      text: widget.features.whatsappAuthToken ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _NotificationConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.features.emailFromAddress !=
        widget.features.emailFromAddress) {
      _emailFromCtrl.text = widget.features.emailFromAddress ?? '';
    }
    if (oldWidget.features.emailApiKey != widget.features.emailApiKey) {
      _emailApiKeyCtrl.text = widget.features.emailApiKey ?? '';
    }
    if (oldWidget.features.smsFromNumber != widget.features.smsFromNumber) {
      _smsFromCtrl.text = widget.features.smsFromNumber ?? '';
    }
    if (oldWidget.features.smsAccountSid != widget.features.smsAccountSid) {
      _smsAccountSidCtrl.text = widget.features.smsAccountSid ?? '';
    }
    if (oldWidget.features.smsAuthToken != widget.features.smsAuthToken) {
      _smsAuthTokenCtrl.text = widget.features.smsAuthToken ?? '';
    }
    if (oldWidget.features.whatsappFromNumber !=
        widget.features.whatsappFromNumber) {
      _whatsappFromCtrl.text = widget.features.whatsappFromNumber ?? '';
    }
    if (oldWidget.features.whatsappAccountSid !=
        widget.features.whatsappAccountSid) {
      _whatsappAccountSidCtrl.text = widget.features.whatsappAccountSid ?? '';
    }
    if (oldWidget.features.whatsappAuthToken !=
        widget.features.whatsappAuthToken) {
      _whatsappAuthTokenCtrl.text = widget.features.whatsappAuthToken ?? '';
    }
  }

  @override
  void dispose() {
    _emailFromCtrl.dispose();
    _emailApiKeyCtrl.dispose();
    _smsFromCtrl.dispose();
    _smsAccountSidCtrl.dispose();
    _smsAuthTokenCtrl.dispose();
    _whatsappFromCtrl.dispose();
    _whatsappAccountSidCtrl.dispose();
    _whatsappAuthTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All channels are disabled by default. Enable only when provider '
          'setup is ready.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Email notifications'),
          subtitle: const Text(
            'Controls welcome emails and other email sends.',
          ),
          value: widget.features.emailEnabled,
          onChanged: (enabled) => _save(
            widget.features.copyWith(emailEnabled: enabled),
          ),
        ),
        TextFormField(
          controller: _emailFromCtrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'Email from address',
            hintText: 'Pocket POS <onboarding@updates.mypocketpos.in>',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailApiKeyCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'Resend API key',
            hintText: 're_xxxxxxxxxxxxx',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saving ? null : _saveEmailSettings,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Email Settings'),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('SMS notifications'),
          value: widget.features.smsEnabled,
          onChanged: (enabled) => _save(
            widget.features.copyWith(smsEnabled: enabled),
          ),
        ),
        TextFormField(
          controller: _smsFromCtrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'SMS from number (E.164)',
            hintText: '+14155550123',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _smsAccountSidCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'SMS Account SID',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _smsAuthTokenCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'SMS Auth Token',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saving ? null : _saveSmsSettings,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save SMS Settings'),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('WhatsApp notifications'),
          value: widget.features.whatsappEnabled,
          onChanged: (enabled) => _save(
            widget.features.copyWith(whatsappEnabled: enabled),
          ),
        ),
        TextFormField(
          controller: _whatsappFromCtrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'WhatsApp from number',
            hintText: 'whatsapp:+14155238886',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _whatsappAccountSidCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'WhatsApp Account SID',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _whatsappAuthTokenCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: 'WhatsApp Auth Token',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saving ? null : _saveWhatsappSettings,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save WhatsApp Settings'),
          ),
        ),
      ],
    );
  }

  Future<void> _saveEmailSettings() async {
    final fromAddress = _emailFromCtrl.text.trim();
    final apiKey = _emailApiKeyCtrl.text.trim();
    final next = widget.features.copyWith(
      emailFromAddress: fromAddress.isEmpty ? null : fromAddress,
      emailApiKey: apiKey.isEmpty ? null : apiKey,
      clearEmailFromAddress: fromAddress.isEmpty,
      clearEmailApiKey: apiKey.isEmpty,
    );
    await _save(next);
  }

  Future<void> _saveSmsSettings() async {
    final fromNumber = _smsFromCtrl.text.trim();
    final accountSid = _smsAccountSidCtrl.text.trim();
    final authToken = _smsAuthTokenCtrl.text.trim();
    final next = widget.features.copyWith(
      smsFromNumber: fromNumber.isEmpty ? null : fromNumber,
      smsAccountSid: accountSid.isEmpty ? null : accountSid,
      smsAuthToken: authToken.isEmpty ? null : authToken,
      clearSmsFromNumber: fromNumber.isEmpty,
      clearSmsAccountSid: accountSid.isEmpty,
      clearSmsAuthToken: authToken.isEmpty,
    );
    await _save(next);
  }

  Future<void> _saveWhatsappSettings() async {
    final fromNumber = _whatsappFromCtrl.text.trim();
    final accountSid = _whatsappAccountSidCtrl.text.trim();
    final authToken = _whatsappAuthTokenCtrl.text.trim();
    final next = widget.features.copyWith(
      whatsappFromNumber: fromNumber.isEmpty ? null : fromNumber,
      whatsappAccountSid: accountSid.isEmpty ? null : accountSid,
      whatsappAuthToken: authToken.isEmpty ? null : authToken,
      clearWhatsappFromNumber: fromNumber.isEmpty,
      clearWhatsappAccountSid: accountSid.isEmpty,
      clearWhatsappAuthToken: authToken.isEmpty,
    );
    await _save(next);
  }

  Future<void> _save(NotificationFeatures next) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
