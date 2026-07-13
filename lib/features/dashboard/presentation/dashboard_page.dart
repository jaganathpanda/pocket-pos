import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);

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
            (title: "Today's Revenue", value: formatInr(m.todayRevenue), icon: Icons.payments_rounded),
            (title: "Today's Transactions", value: m.todayTransactions.toString(), icon: Icons.receipt_long_rounded),
            (title: 'Total Revenue', value: formatInr(m.totalRevenue), icon: Icons.savings_rounded),
            (title: 'Total Transactions', value: m.totalTransactions.toString(), icon: Icons.receipt_rounded),
            (title: 'Total Tax Collected', value: formatInr(m.totalTax), icon: Icons.account_balance_rounded),
            (title: 'Total Discount', value: formatInr(m.totalDiscount), icon: Icons.local_offer_rounded),
            (title: 'Active Carts', value: m.activeCarts.toString(), icon: Icons.shopping_cart_rounded),
            (title: 'Total Products', value: m.totalProducts.toString(), icon: Icons.inventory_2_rounded),
            (title: 'Total Customers', value: m.totalCustomers.toString(), icon: Icons.people_alt_rounded),
            (title: 'Low Stock Items', value: m.lowStockItems.toString(), icon: Icons.warning_amber_rounded),
            (title: 'Out Of Stock', value: m.outOfStockItems.toString(), icon: Icons.block_rounded),
            (title: 'Pending Credit', value: formatInr(m.pendingCredit), icon: Icons.account_balance_wallet_rounded),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width < 700 ? 1 : (width < 1100 ? 2 : 3);

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final c = cards[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(c.icon),
                          const Spacer(),
                          Text(c.title),
                          const SizedBox(height: 8),
                          Text(c.value, style: Theme.of(context).textTheme.headlineSmall),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
