import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/firestore/firestore_ids.dart';
import '../../../core/utilities/money.dart';
import '../domain/subscription_models.dart';
import '../providers/subscription_providers.dart';

class AdminSubscriptionPanel extends ConsumerStatefulWidget {
  const AdminSubscriptionPanel({super.key});

  @override
  ConsumerState<AdminSubscriptionPanel> createState() =>
      _AdminSubscriptionPanelState();
}

class _AdminSubscriptionPanelState
    extends ConsumerState<AdminSubscriptionPanel> {
  final _storeIdCtrl = TextEditingController();
  String? _storeId;

  @override
  void dispose() {
    _storeIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(adminSubscriptionPlansProvider);
    final repo = ref.read(subscriptionRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Icon(Icons.subscriptions_rounded),
            const SizedBox(width: 8),
            Text(
              'Subscription Administration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _openPlanEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create plan'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        plansAsync.when(
          data: (plans) {
            if (plans.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No plans yet. Create your first plan.'),
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < plans.length; i++)
                  Card(
                    child: ListTile(
                      title: Text(
                          '${plans[i].name} (${plans[i].billingCycle.name})'),
                      subtitle: Text(
                        '${formatInr(plans[i].priceMajor)} · ${plans[i].isActive ? 'Active' : 'Inactive'}${plans[i].publicVisible ? ' · Public' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Preview',
                            onPressed: () =>
                                _showPlanPreview(context, plans[i]),
                            icon: const Icon(Icons.preview_rounded),
                          ),
                          IconButton(
                            tooltip: 'Duplicate',
                            onPressed: () async {
                              try {
                                await repo.duplicatePlan(plans[i].id);
                              } catch (e) {
                                _snack(context, '$e');
                              }
                            },
                            icon: const Icon(Icons.copy_rounded),
                          ),
                          IconButton(
                            tooltip: 'Move up',
                            onPressed: i == 0
                                ? null
                                : () async {
                                    await repo.movePlan(plans[i].id, up: true);
                                  },
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            onPressed: i == plans.length - 1
                                ? null
                                : () async {
                                    await repo.movePlan(plans[i].id, up: false);
                                  },
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                          IconButton(
                            tooltip:
                                plans[i].isActive ? 'Deactivate' : 'Activate',
                            onPressed: () async {
                              await repo.setPlanActive(
                                  plans[i].id, !plans[i].isActive);
                            },
                            icon: Icon(
                              plans[i].isActive
                                  ? Icons.pause_circle_rounded
                                  : Icons.play_circle_fill_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () =>
                                _openPlanEditor(context, ref, plan: plans[i]),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: 'Safe delete',
                            onPressed: () async {
                              final sure = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete plan?'),
                                  content: const Text(
                                    'This will soft-delete the plan if there are no active subscriptions on it.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (sure != true) return;
                              try {
                                await repo.safeDeletePlan(plans[i].id);
                              } catch (e) {
                                _snack(context, '$e');
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Plan load error: $e'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text('Store Subscription Lifecycle',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _storeIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Store ID',
                  hintText: 'STR-ABC123',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                setState(() {
                  _storeId = _storeIdCtrl.text.trim().toUpperCase();
                });
              },
              child: const Text('Load'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_storeId != null && _storeId!.isNotEmpty)
          _StoreSubscriptionList(storeId: _storeId!),
      ],
    );
  }

  void _showPlanPreview(BuildContext context, SubscriptionPlan plan) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${plan.name} preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.description),
              const SizedBox(height: 12),
              Text(
                '${formatInr(plan.priceMajor)} / ${plan.billingCycle.name}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (plan.badgeText != null && plan.badgeText!.isNotEmpty)
                Chip(label: Text(plan.badgeText!)),
              const SizedBox(height: 8),
              const Text('Features'),
              const SizedBox(height: 4),
              for (final f in plan.featureList)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $f'),
                ),
              if (plan.limits.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Limits'),
                const SizedBox(height: 4),
                for (final entry in plan.limits.entries)
                  Text('${entry.key}: ${entry.value}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlanEditor(
    BuildContext context,
    WidgetRef ref, {
    SubscriptionPlan? plan,
  }) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    final nameCtrl = TextEditingController(text: plan?.name ?? '');
    final slugCtrl = TextEditingController(text: plan?.slug ?? '');
    final descriptionCtrl =
        TextEditingController(text: plan?.description ?? '');
    final priceCtrl = TextEditingController(
      text: ((plan?.priceMinor ?? 0) / 100).toStringAsFixed(2),
    );
    final badgeCtrl = TextEditingController(text: plan?.badgeText ?? '');
    final ctaLabelCtrl = TextEditingController(text: plan?.ctaLabel ?? '');
    final ctaUrlCtrl = TextEditingController(text: plan?.ctaUrl ?? '');
    final trialDaysCtrl =
        TextEditingController(text: (plan?.trialDays ?? 0).toString());
    final sortCtrl =
        TextEditingController(text: (plan?.sortOrder ?? 0).toString());
    final featuresCtrl =
        TextEditingController(text: (plan?.featureList ?? const []).join('\n'));
    final limitsCtrl = TextEditingController(
      text: (plan?.limits.entries ??
              const Iterable<MapEntry<String, int>>.empty())
          .map((e) => '${e.key}:${e.value}')
          .join('\n'),
    );

    var cycle = plan?.billingCycle ?? BillingCycle.monthly;
    var active = plan?.isActive ?? true;
    var publicVisible = plan?.publicVisible ?? true;
    var popular = plan?.isPopular ?? false;
    var defaultForNewStores = plan?.defaultForNewStores ?? false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(plan == null ? 'Create plan' : 'Edit plan'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                          controller: nameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Plan name')),
                      TextField(
                          controller: slugCtrl,
                          decoration: const InputDecoration(labelText: 'Slug')),
                      TextField(
                          controller: descriptionCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Description')),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<BillingCycle>(
                              value: cycle,
                              decoration: const InputDecoration(
                                  labelText: 'Billing cycle'),
                              items: const [
                                DropdownMenuItem(
                                    value: BillingCycle.monthly,
                                    child: Text('Monthly')),
                                DropdownMenuItem(
                                    value: BillingCycle.yearly,
                                    child: Text('Yearly')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setStateDialog(() => cycle = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: priceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Price (INR major unit)'),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                                controller: trialDaysCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Trial days')),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                                controller: sortCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Sort order')),
                          ),
                        ],
                      ),
                      TextField(
                          controller: badgeCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Badge text (optional)')),
                      TextField(
                          controller: ctaLabelCtrl,
                          decoration: const InputDecoration(
                              labelText: 'CTA label (optional)')),
                      TextField(
                          controller: ctaUrlCtrl,
                          decoration: const InputDecoration(
                              labelText: 'CTA URL (optional)')),
                      TextField(
                        controller: featuresCtrl,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Feature list (one per line)',
                        ),
                      ),
                      TextField(
                        controller: limitsCtrl,
                        minLines: 3,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: 'Limits key:value (one per line)',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        value: active,
                        onChanged: (v) => setStateDialog(() => active = v),
                        title: const Text('Active'),
                      ),
                      SwitchListTile.adaptive(
                        value: publicVisible,
                        onChanged: (v) =>
                            setStateDialog(() => publicVisible = v),
                        title: const Text('Public visible'),
                      ),
                      SwitchListTile.adaptive(
                        value: popular,
                        onChanged: (v) => setStateDialog(() => popular = v),
                        title: const Text('Popular plan'),
                      ),
                      SwitchListTile.adaptive(
                        value: defaultForNewStores,
                        onChanged: (v) =>
                            setStateDialog(() => defaultForNewStores = v),
                        title: const Text('Default for new store trial'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    try {
      final priceMajor = double.tryParse(priceCtrl.text.trim()) ?? 0;
      final trialDays = int.tryParse(trialDaysCtrl.text.trim()) ?? 0;
      final sortOrder = int.tryParse(sortCtrl.text.trim()) ?? 0;

      final features = featuresCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final limits = <String, int>{};
      for (final row in limitsCtrl.text.split('\n')) {
        final line = row.trim();
        if (line.isEmpty || !line.contains(':')) continue;
        final parts = line.split(':');
        final key = parts.first.trim();
        final value = int.tryParse(parts.sublist(1).join(':').trim());
        if (key.isEmpty || value == null) continue;
        limits[key] = value;
      }

      final payload = SubscriptionPlan(
        id: plan?.id ?? '',
        name: nameCtrl.text.trim(),
        slug: slugCtrl.text.trim().isEmpty
            ? nameCtrl.text.trim().toLowerCase().replaceAll(' ', '-')
            : slugCtrl.text.trim(),
        description: descriptionCtrl.text.trim(),
        billingCycle: cycle,
        priceMinor: (priceMajor * 100).round(),
        currency: 'INR',
        sortOrder: sortOrder,
        isActive: active,
        publicVisible: publicVisible,
        isPopular: popular,
        trialDays: trialDays,
        featureList: features,
        limits: limits,
        badgeText: badgeCtrl.text.trim().isEmpty ? null : badgeCtrl.text.trim(),
        ctaLabel:
            ctaLabelCtrl.text.trim().isEmpty ? null : ctaLabelCtrl.text.trim(),
        ctaUrl: ctaUrlCtrl.text.trim().isEmpty ? null : ctaUrlCtrl.text.trim(),
        defaultForNewStores: defaultForNewStores,
      );

      await repo.savePlan(payload);
    } catch (e) {
      if (context.mounted) {
        _snack(context, '$e');
      }
    } finally {
      nameCtrl.dispose();
      slugCtrl.dispose();
      descriptionCtrl.dispose();
      priceCtrl.dispose();
      badgeCtrl.dispose();
      ctaLabelCtrl.dispose();
      ctaUrlCtrl.dispose();
      trialDaysCtrl.dispose();
      sortCtrl.dispose();
      featuresCtrl.dispose();
      limitsCtrl.dispose();
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StoreSubscriptionList extends ConsumerWidget {
  const _StoreSubscriptionList({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(storeSubscriptionsProvider(storeId));
    final plansAsync = ref.watch(adminSubscriptionPlansProvider);
    final entitlementAsync = ref.watch(storeEntitlementProvider(storeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Store $storeId',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: plansAsync.valueOrNull == null
                  ? null
                  : () => _openCreateSubscriptionDialog(
                        context,
                        ref,
                        storeId,
                        plansAsync.valueOrNull!,
                      ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Assign subscription'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        entitlementAsync.when(
          data: (entitlement) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: entitlement == null
                  ? const Text('No projected entitlement yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current entitlement: ${entitlement.planName} (${subscriptionStatusWireName(entitlement.status)})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatInr(entitlement.priceMinor / 100)} / ${entitlement.billingCycle.name}',
                        ),
                        if (entitlement.effectiveUntil != null)
                          Text(
                            'Effective until: ${DateFormat.yMMMd().add_jm().format(entitlement.effectiveUntil!.toLocal())}',
                          ),
                      ],
                    ),
            ),
          ),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Entitlement error: $e'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        subAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No subscriptions for this store yet.'),
                ),
              );
            }

            return Column(
              children: [
                for (final item in list)
                  Card(
                    child: ListTile(
                      title: Text(
                          '${item.planId} · ${subscriptionStatusWireName(item.status)}'),
                      subtitle: Text(
                        'Period end: ${item.currentPeriodEnd == null ? 'n/a' : DateFormat.yMMMd().format(item.currentPeriodEnd!.toLocal())}',
                      ),
                      trailing: PopupMenuButton<SubscriptionStatus>(
                        tooltip: 'Update status',
                        onSelected: (next) {
                          ref
                              .read(subscriptionRepositoryProvider)
                              .updateStoreSubscriptionStatus(
                                storeId: storeId,
                                subscriptionId: item.id,
                                status: next,
                              );
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(
                            value: SubscriptionStatus.pending,
                            child: Text('Set pending'),
                          ),
                          PopupMenuItem(
                            value: SubscriptionStatus.trialing,
                            child: Text('Set trialing'),
                          ),
                          PopupMenuItem(
                            value: SubscriptionStatus.active,
                            child: Text('Set active'),
                          ),
                          PopupMenuItem(
                            value: SubscriptionStatus.pastDue,
                            child: Text('Set past due'),
                          ),
                          PopupMenuItem(
                            value: SubscriptionStatus.canceled,
                            child: Text('Set canceled'),
                          ),
                          PopupMenuItem(
                            value: SubscriptionStatus.expired,
                            child: Text('Set expired'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Subscription list error: $e'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreateSubscriptionDialog(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    List<SubscriptionPlan> plans,
  ) async {
    SubscriptionPlan? selected = plans.where((p) => p.isActive).isNotEmpty
        ? plans.where((p) => p.isActive).first
        : plans.first;
    final status =
        ValueNotifier<SubscriptionStatus>(SubscriptionStatus.trialing);
    final daysCtrl = TextEditingController(text: selected.trialDays.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Assign store subscription'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SubscriptionPlan>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: [
                    for (final plan in plans)
                      DropdownMenuItem(
                        value: plan,
                        child: Text('${plan.name} (${plan.billingCycle.name})'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setStateDialog(() {
                      selected = value;
                      daysCtrl.text = value.trialDays.toString();
                    });
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<SubscriptionStatus>(
                  valueListenable: status,
                  builder: (ctx, value, _) {
                    return DropdownButtonFormField<SubscriptionStatus>(
                      value: value,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: SubscriptionStatus.pending,
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: SubscriptionStatus.trialing,
                          child: Text('Trialing'),
                        ),
                        DropdownMenuItem(
                          value: SubscriptionStatus.active,
                          child: Text('Active'),
                        ),
                      ],
                      onChanged: (next) {
                        if (next != null) status.value = next;
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Period days'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Assign')),
          ],
        ),
      ),
    );

    if (ok != true || selected == null) return;
    final now = DateTime.now().toUtc();
    final days = int.tryParse(daysCtrl.text.trim()) ?? selected!.trialDays;
    final periodEnd = now.add(Duration(days: days < 1 ? 1 : days));

    final model = CustomerSubscription(
      id: newIntId().toString(),
      storeId: storeId,
      planId: selected!.id,
      status: status.value,
      source: 'admin',
      provider: 'none',
      cancelAtPeriodEnd: false,
      startedAt: now,
      trialEndAt:
          status.value == SubscriptionStatus.trialing ? periodEnd : null,
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
      metadata: {
        'assignedBy': 'platform_admin',
      },
    );

    await ref.read(subscriptionRepositoryProvider).saveStoreSubscription(model);
  }
}
