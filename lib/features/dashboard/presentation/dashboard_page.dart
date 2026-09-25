import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final upcomingExpiries = ref.watch(upcomingExpiringProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh metrics',
            onPressed: () => ref.invalidate(dashboardMetricsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: metrics.when(
        data: (m) {
          final cards = <({String title, String value, IconData icon})>[
            (
              title: "Today's Revenue",
              value: formatInr(m.todayRevenue),
              icon: Icons.payments_rounded
            ),
            (
              title: "Today's Transactions",
              value: m.todayTransactions.toString(),
              icon: Icons.receipt_long_rounded
            ),
            (
              title: 'Total Revenue',
              value: formatInr(m.totalRevenue),
              icon: Icons.savings_rounded
            ),
            (
              title: 'Total Transactions',
              value: m.totalTransactions.toString(),
              icon: Icons.receipt_rounded
            ),
            (
              title: 'Total Tax Collected',
              value: formatInr(m.totalTax),
              icon: Icons.account_balance_rounded
            ),
            (
              title: 'Total Discount',
              value: formatInr(m.totalDiscount),
              icon: Icons.local_offer_rounded
            ),
            (
              title: 'Active Carts',
              value: m.activeCarts.toString(),
              icon: Icons.shopping_cart_rounded
            ),
            (
              title: 'Total Products',
              value: m.totalProducts.toString(),
              icon: Icons.inventory_2_rounded
            ),
            (
              title: 'Total Customers',
              value: m.totalCustomers.toString(),
              icon: Icons.people_alt_rounded
            ),
            (
              title: 'Low Stock Items',
              value: m.lowStockItems.toString(),
              icon: Icons.warning_amber_rounded
            ),
            (
              title: 'Out Of Stock',
              value: m.outOfStockItems.toString(),
              icon: Icons.block_rounded
            ),
            (
              title: 'Pending Credit',
              value: formatInr(m.pendingCredit),
              icon: Icons.account_balance_wallet_rounded
            ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ...cards.map((c) {
                      return SizedBox(
                        width: 220,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(c.icon, size: 20),
                                const SizedBox(height: 8),
                                Text(
                                  c.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c.value,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(
                      width: 220,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_busy_rounded, size: 20),
                              const SizedBox(height: 8),
                              const Text(
                                'Upcoming Expiry',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              upcomingExpiries.when(
                                data: (items) {
                                  return MouseRegion(
                                    cursor: items.isEmpty
                                        ? SystemMouseCursors.basic
                                        : SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: items.isEmpty
                                          ? null
                                          : () => _showExpiryDialog(
                                              context, items),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            items.length.toString(),
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w700,
                                              color: items.isEmpty
                                                  ? Colors.grey
                                                  : (items.any((i) =>
                                                          i.daysLeft <= 7)
                                                      ? Colors.red
                                                      : Colors.orange),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'product${items.length == 1 ? '' : 's'} expiring soon',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (items.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                      top: 6),
                                              child: Text(
                                                'Click to view all',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                loading: () => const SizedBox(
                                  height: 24,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                error: (e, _) => Text(
                                  'Expiry data unavailable',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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

  static void _showExpiryDialog(
    BuildContext context,
    List<({String name, DateTime expiryDate, int daysLeft})> items,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Products Expiring Soon'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final item = items[index];
              final isExpired = item.daysLeft <= 0;
              final isUrgent = item.daysLeft <= 7;
              return ListTile(
                leading: Icon(
                  isExpired ? Icons.error_rounded : Icons.warning_rounded,
                  color: isExpired
                      ? Colors.red
                      : isUrgent
                          ? Colors.orange
                          : Colors.amber,
                  size: 20,
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isExpired ? Colors.red : null,
                    decoration:
                        isExpired ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${DateFormat('dd MMM yyyy').format(item.expiryDate)}  ·  '
                  '${isExpired ? 'EXPIRED' : '${item.daysLeft} day${item.daysLeft == 1 ? '' : 's'} left'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.red : Colors.grey,
                  ),
                ),
              );
            },
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
}
