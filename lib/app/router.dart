import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/categories/presentation/category_page.dart';
import '../features/customers/presentation/customer_details_page.dart';
import '../features/customers/presentation/customer_invoice_detail_page.dart';
import '../features/customers/presentation/customer_list_page.dart';
import '../features/customers/presentation/customer_orders_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/products/presentation/product_page.dart';
import '../features/purchases/presentation/purchase_page.dart';
import '../features/ledger/presentation/credit_ledger_page.dart';
import '../features/reports/presentation/sales_report_page.dart';
import '../features/sales/presentation/pos_billing_page.dart';
import '../features/expense/presentation/expense_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/suppliers/presentation/supplier_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
          GoRoute(path: '/categories', builder: (context, state) => const CategoryPage()),
          GoRoute(path: '/products', builder: (context, state) => const ProductPage()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryPage()),
          GoRoute(path: '/billing', builder: (context, state) => const PosBillingPage()),
          GoRoute(path: '/customers', builder: (context, state) => const CustomerListPage()),
          GoRoute(
            path: '/customer/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return CustomerDetailsPage(customerId: id);
            },
            routes: [
              GoRoute(
                path: 'orders',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return CustomerOrdersPage(customerId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/invoice/:saleId',
            builder: (context, state) {
              final saleId = int.parse(state.pathParameters['saleId']!);
              return CustomerInvoiceDetailPage(saleId: saleId);
            },
          ),
          GoRoute(path: '/suppliers', builder: (context, state) => const SupplierPage()),
          GoRoute(
            path: '/purchases',
            builder: (context, state) {
              final supplierId = state.extra as int?;
              return PurchasePage(initialSupplierId: supplierId);
            },
          ),
          GoRoute(path: '/reports', builder: (context, state) => const SalesReportPage()),
          GoRoute(path: '/ledger', builder: (context, state) => const CreditLedgerPage()),
          GoRoute(path: '/expenses', builder: (context, state) => const ExpensePage()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
        ],
      ),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    final destinations = <({String route, String label, IconData icon})>[
      (route: '/dashboard', label: 'Dashboard', icon: Icons.dashboard_rounded),
      (route: '/categories', label: 'Categories', icon: Icons.category_rounded),
      (route: '/products', label: 'Products', icon: Icons.inventory_2_rounded),
      (route: '/inventory', label: 'Inventory', icon: Icons.warehouse_rounded),
      (route: '/billing', label: 'POS', icon: Icons.point_of_sale_rounded),
      (route: '/customers', label: 'Customers', icon: Icons.person_rounded),
      (route: '/suppliers', label: 'Vendors', icon: Icons.storefront_rounded),
      (route: '/purchases', label: 'Purchases', icon: Icons.shopping_bag_rounded),
      (route: '/reports', label: 'Reports', icon: Icons.analytics_rounded),
      (route: '/ledger', label: 'Udhar', icon: Icons.account_balance_wallet_rounded),
      (route: '/expenses', label: 'Expenses', icon: Icons.receipt_long_rounded),
      (route: '/settings', label: 'Settings', icon: Icons.settings_rounded),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= 600;

    // ── Tablet / desktop: keep the left navigation rail ──────────────────────
    if (isWide) {
      final selectedIndex = destinations.indexWhere((d) => location.startsWith(d.route));
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (index) => context.go(destinations[index].route),
              labelType: NavigationRailLabelType.all,
              scrollable: true,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Phones: bottom tab bar with the most-used screens + a "Menu" sheet ───
    const primary = <({String route, String label, IconData icon})>[
      (route: '/dashboard', label: 'Home', icon: Icons.home_rounded),
      (route: '/billing', label: 'Billing', icon: Icons.point_of_sale_rounded),
      (route: '/products', label: 'Items', icon: Icons.inventory_2_rounded),
      (route: '/customers', label: 'Parties', icon: Icons.people_alt_rounded),
    ];

    var currentIndex = primary.indexWhere((d) => location.startsWith(d.route));
    if (currentIndex < 0) currentIndex = primary.length; // highlight "Menu"

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index < primary.length) {
            context.go(primary[index].route);
          } else {
            _showMenuSheet(context, destinations);
          }
        },
        destinations: [
          for (final d in primary)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
          const NavigationDestination(icon: Icon(Icons.menu_rounded), label: 'Menu'),
        ],
      ),
    );
  }

  void _showMenuSheet(
    BuildContext context,
    List<({String route, String label, IconData icon})> destinations,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text('All Sections',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                  children: [
                    for (final d in destinations)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          context.go(d.route);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(radius: 24, child: Icon(d.icon, size: 22)),
                            const SizedBox(height: 6),
                            Text(d.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
