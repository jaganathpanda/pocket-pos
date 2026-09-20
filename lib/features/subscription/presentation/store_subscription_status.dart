import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_pos/features/auth/domain/auth_models.dart';
import 'package:pocket_pos/features/store/domain/store_models.dart';
import 'package:pocket_pos/features/subscription/domain/subscription_models.dart';
import 'package:pocket_pos/features/subscription/providers/subscription_providers.dart';

/// Displays the current subscription status for a store.
/// Shows plan name, billing cycle, status, and renewal date.
class StoreSubscriptionStatus extends ConsumerWidget {
  const StoreSubscriptionStatus({
    Key? key,
    required this.storeId,
  }) : super(key: key);

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlementAsync = ref.watch(storeEntitlementProvider(storeId));

    return entitlementAsync.when(
      data: (entitlement) {
        if (entitlement == null) {
          return _buildNoSubscription(context);
        }
        return _buildSubscriptionStatus(context, entitlement);
      },
      loading: () => _buildLoading(),
      error: (error, stack) => _buildError(context, error),
    );
  }

  Widget _buildNoSubscription(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No Active Subscription',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your store does not have an active subscription yet.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                // Navigate to subscription plans
                // context.push('/subscription-plans');
              },
              child: const Text('View Plans'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatus(
    BuildContext context,
    StoreEntitlement entitlement,
  ) {
    final statusColor = _getStatusColor(entitlement.status);
    final statusLabel = _getStatusLabel(entitlement.status);
    final renewalDate = entitlement.effectiveUntil;
    final formattedPrice =
        '₹${(entitlement.priceMinor / 100).toStringAsFixed(0)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with plan name and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entitlement.planName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entitlement.billingCycle.name[0].toUpperCase()}${entitlement.billingCycle.name.substring(1)} Billing',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Price info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Plan Price',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  '$formattedPrice/${entitlement.billingCycle.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Renewal date info
            if (renewalDate != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Next Renewal',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    _formatDate(renewalDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Status message based on subscription state
            _buildStatusMessage(entitlement),

            const SizedBox(height: 16),

            // Features/Limits info
            if (entitlement.featureList.isNotEmpty) ...[
              const Text(
                'Included Features',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entitlement.featureList.take(4).map((feature) {
                  return Chip(
                    label: Text(feature),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(2),
                    side: const BorderSide(color: Colors.transparent),
                  );
                }).toList(),
              ),
              if (entitlement.featureList.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${entitlement.featureList.length - 4} more features',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],

            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      // Show subscription details dialog
                      _showSubscriptionDetails(context, entitlement);
                    },
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // Navigate to upgrade/change plan
                      // context.push('/change-subscription');
                    },
                    child: const Text('Change Plan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage(StoreEntitlement entitlement) {
    switch (entitlement.status) {
      case SubscriptionStatus.trialing:
        final daysLeft = entitlement.effectiveUntil?.difference(DateTime.now()).inDays ?? 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(25),
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'You are on a free trial. $daysLeft days remaining.',
            style: const TextStyle(fontSize: 12, color: Colors.blue),
          ),
        );
      case SubscriptionStatus.active:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            border: Border.all(color: Colors.green),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Your subscription is active and in good standing.',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
        );
      case SubscriptionStatus.pastDue:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(25),
            border: Border.all(color: Colors.orange),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Your subscription payment is overdue. Please update your payment method.',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
        );
      case SubscriptionStatus.canceled:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(25),
            border: Border.all(color: Colors.red),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Your subscription has been canceled.',
            style: TextStyle(fontSize: 12, color: Colors.red),
          ),
        );
      case SubscriptionStatus.expired:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(25),
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Your subscription has expired. Please renew to continue.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      case SubscriptionStatus.pending:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withAlpha(25),
            border: Border.all(color: Colors.amber),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Your subscription is being set up. Please wait...',
            style: TextStyle(fontSize: 12, color: Colors.amber),
          ),
        );
    }
  }

  Widget _buildLoading() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 12),
                Text(
                  'Loading subscription...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Error Loading Subscription',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                // Retry logic would go here
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.trialing:
        return Colors.blue;
      case SubscriptionStatus.pastDue:
        return Colors.orange;
      case SubscriptionStatus.canceled:
      case SubscriptionStatus.expired:
        return Colors.red;
      case SubscriptionStatus.pending:
        return Colors.amber;
    }
  }

  String _getStatusLabel(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.trialing:
        return 'Trialing';
      case SubscriptionStatus.pastDue:
        return 'Past Due';
      case SubscriptionStatus.canceled:
        return 'Canceled';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.pending:
        return 'Pending';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day + 1) {
      return 'Tomorrow';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSubscriptionDetails(
    BuildContext context,
    StoreEntitlement entitlement,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Plan', entitlement.planName),
              _buildDetailRow('Billing Cycle', entitlement.billingCycle.name),
              _buildDetailRow(
                'Price',
                '₹${(entitlement.priceMinor / 100).toStringAsFixed(2)}',
              ),
              _buildDetailRow('Status', _getStatusLabel(entitlement.status)),
              if (entitlement.effectiveFrom != null)
                _buildDetailRow(
                  'Active From',
                  _formatDate(entitlement.effectiveFrom!),
                ),
              if (entitlement.effectiveUntil != null)
                _buildDetailRow(
                  'Valid Until',
                  _formatDate(entitlement.effectiveUntil!),
                ),
              const SizedBox(height: 16),
              const Text(
                'Limits:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(entitlement.limits.entries.map((e) {
                final limitValue =
                    e.value == -1 ? 'Unlimited' : e.value.toString();
                return Text('• ${e.key}: $limitValue');
              }).toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
