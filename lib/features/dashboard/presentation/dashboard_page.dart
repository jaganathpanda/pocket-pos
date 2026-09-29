import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocket_pos/l10n/app_localizations.dart';

import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final upcomingExpiries = ref.watch(upcomingExpiringProductsProvider);

    final strings = AppLocalizations.of(context);
    final compactActions = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.dashboard),
        actions: [
          compactActions
              ? IconButton(
                  tooltip: 'Add Sales',
                  onPressed: () => context.push('/billing'),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                )
              : TextButton.icon(
                  onPressed: () => context.push('/billing'),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Add Sales'),
                ),
          compactActions
              ? IconButton(
                  tooltip: 'Find Invoice',
                  onPressed: () => context.push('/find-invoice'),
                  icon: const Icon(Icons.search_rounded),
                )
              : TextButton.icon(
                  onPressed: () => context.push('/find-invoice'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Find Invoice'),
                ),
          IconButton(
            tooltip: strings.refreshMetrics,
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
              title: strings.todayRevenue,
              value: formatInr(m.todayRevenue),
              icon: Icons.payments_rounded
            ),
            (
              title: strings.todayTransactions,
              value: m.todayTransactions.toString(),
              icon: Icons.receipt_long_rounded
            ),
            (
              title: strings.totalRevenue,
              value: formatInr(m.totalRevenue),
              icon: Icons.savings_rounded
            ),
            (
              title: strings.totalTransactions,
              value: m.totalTransactions.toString(),
              icon: Icons.receipt_rounded
            ),
            (
              title: strings.totalTaxCollected,
              value: formatInr(m.totalTax),
              icon: Icons.account_balance_rounded
            ),
            (
              title: strings.totalDiscount,
              value: formatInr(m.totalDiscount),
              icon: Icons.local_offer_rounded
            ),
            (
              title: strings.activeCarts,
              value: m.activeCarts.toString(),
              icon: Icons.shopping_cart_rounded
            ),
            (
              title: strings.totalProducts,
              value: m.totalProducts.toString(),
              icon: Icons.inventory_2_rounded
            ),
            (
              title: strings.totalCustomers,
              value: m.totalCustomers.toString(),
              icon: Icons.people_alt_rounded
            ),
            (
              title: strings.lowStockItems,
              value: m.lowStockItems.toString(),
              icon: Icons.warning_amber_rounded
            ),
            (
              title: strings.outOfStock,
              value: m.outOfStockItems.toString(),
              icon: Icons.block_rounded
            ),
            (
              title: strings.pendingCredit,
              value: formatInr(m.pendingCredit),
              icon: Icons.account_balance_wallet_rounded
            ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              const preferredCardWidth = 220.0;
              final availableWidth = (constraints.maxWidth - 32)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              final columnCount =
                  ((availableWidth + spacing) / (preferredCardWidth + spacing))
                      .floor()
                      .clamp(2, 5)
                      .toInt();
              final cardWidth =
                  (availableWidth - spacing * (columnCount - 1)) / columnCount;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    ...cards.map((c) {
                      return SizedBox(
                        width: cardWidth,
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
                      width: cardWidth,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event_busy_rounded, size: 20),
                              const SizedBox(height: 8),
                              Text(
                                strings.upcomingExpiry,
                                style: const TextStyle(
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
                                          : () =>
                                              _showExpiryDialog(context, items),
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
                                            strings.productsExpiringCount(
                                                items.length),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (items.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Text(
                                                strings.clickToViewAll,
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
                                  strings.expiryDataUnavailable,
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
        error: (e, _) => Center(
          child: Text(strings.dashboardError(e.toString())),
        ),
      ),
    );
  }

  static void _showExpiryDialog(
    BuildContext context,
    List<({String name, DateTime expiryDate, int daysLeft})> items,
  ) {
    final strings = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.productsExpiringSoon),
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
                    decoration: isExpired ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${DateFormat('dd MMM yyyy').format(item.expiryDate)}  ·  '
                  '${isExpired ? strings.expired : strings.daysLeft(item.daysLeft)}',
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
            child: Text(strings.close),
          ),
        ],
      ),
    );
  }
}
