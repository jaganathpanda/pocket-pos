import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/auth_models.dart';
import '../features/categories/presentation/category_page.dart';
import '../features/customers/presentation/customer_details_page.dart';
import '../features/customers/presentation/customer_invoice_detail_page.dart';
import '../features/customers/presentation/customer_list_page.dart';
import '../features/customers/presentation/customer_orders_page.dart';
import '../core/di/providers.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/pos_counters/presentation/pos_counters_page.dart';
import '../features/products/presentation/product_page.dart';
import '../features/purchases/presentation/purchase_page.dart';
import '../features/ledger/presentation/credit_ledger_page.dart';
import '../features/reports/presentation/sales_report_page.dart';
import '../features/sales/presentation/pos_billing_page.dart';
import '../features/expense/presentation/expense_page.dart';
import '../features/staff/presentation/staff_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/store/domain/store_models.dart';
import '../features/store/presentation/admin_approval_page.dart';
import '../features/store/presentation/admin_login_page.dart';
import '../features/store/presentation/pending_approval_page.dart';
import '../features/store/presentation/shop_owner_profile_page.dart';
import '../features/store/presentation/store_auth_controller.dart';
import '../features/store/presentation/store_login_page.dart';
import '../features/store/presentation/store_register_page.dart';
import '../features/suppliers/presentation/supplier_page.dart';
import '../features/warehouse/domain/inventory_mode.dart';
import '../features/warehouse/presentation/warehouse_page.dart';
import '../features/mill_run/presentation/mill_run_page.dart';
import '../features/mill_run/presentation/milling_charge_page.dart';
import '../features/mill_run/presentation/milling_contracts_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(storeAuthControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/store-login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final stage = ref.read(storeAuthControllerProvider).stage;
      final loc = state.matchedLocation;
      const authRoutes = {'/store-login', '/store-register', '/admin-login'};
      switch (stage) {
        case StoreAuthStage.unknown:
          return null; // brief; controller resolves on start
        case StoreAuthStage.loggedOut:
          return authRoutes.contains(loc) ? null : '/store-login';
        case StoreAuthStage.pending:
          return loc == '/pending' ? null : '/pending';
        case StoreAuthStage.admin:
          return loc == '/admin' ? null : '/admin';
        case StoreAuthStage.active:
          if (authRoutes.contains(loc) || loc == '/pending') return '/dashboard';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/store-login', builder: (context, state) => const StoreLoginPage()),
      GoRoute(path: '/store-register', builder: (context, state) => const StoreRegisterPage()),
      GoRoute(path: '/pending', builder: (context, state) => const PendingApprovalPage()),
      GoRoute(path: '/admin-login', builder: (context, state) => const AdminLoginPage()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminApprovalPage()),
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
          GoRoute(path: '/staff', builder: (context, state) => const StaffPage()),
            GoRoute(
              path: '/owner-profile',
              builder: (context, state) => const ShopOwnerProfilePage()),
          GoRoute(path: '/counters', builder: (context, state) => const PosCountersPage()),
          GoRoute(path: '/warehouses', builder: (context, state) => const WarehousePage()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
          GoRoute(path: '/mill-runs', builder: (context, state) => const MillRunPage()),
          GoRoute(path: '/milling-charges', builder: (context, state) => const MillingChargePage()),
          GoRoute(path: '/milling-contracts', builder: (context, state) => const MillingContractsPage()),
        ],
      ),
    ],
  );
});

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(currentUserProvider);

    // POS users (locked to a counter) only see POS-related sections. Owners see
    // everything plus the Counters/Users management screen.
    final scoped = user?.isCounterScoped ?? false;
    final canManage = user?.canManagePos ?? false;
    final mode = ref.watch(inventoryModeProvider).valueOrNull ?? InventoryMode.single;
    final isRiceMill = ref.watch(isRiceMillProvider);

    // Keep the warehouse + inventory caches warm for the whole authenticated
    // session. Firestore's one-time .get() throws ("client is offline") for a
    // document that isn't in the local cache, and returns nothing for an
    // un-cached query — so without a live listener, the POS add-to-cart /
    // checkout path (which resolves the default warehouse and reads stock via
    // .get()) fails as soon as the device goes offline. These listeners prime
    // and maintain that cache so offline billing works.
    ref.watch(warehousesProvider);
    ref.watch(inventoryProvider);

    final destinations = <({String route, String label, IconData icon})>[
      (route: '/dashboard', label: 'Dashboard', icon: Icons.dashboard_rounded),
      if (!scoped) (route: '/categories', label: 'Categories', icon: Icons.category_rounded),
      (route: '/products', label: isRiceMill ? 'Products / Stock' : 'Products', icon: Icons.inventory_2_rounded),
      if (!scoped && mode.tracksStock)
        (route: '/inventory', label: 'Inventory', icon: Icons.inventory_rounded),
      if (!scoped && mode.usesWarehouses)
        (route: '/warehouses', label: isRiceMill ? 'Godowns' : 'Warehouses', icon: Icons.warehouse_rounded),
      (route: '/billing', label: isRiceMill ? 'Rice Sales' : 'POS', icon: Icons.point_of_sale_rounded),
      (route: '/customers', label: isRiceMill ? 'Rice Parties' : 'Customers', icon: Icons.person_rounded),
      if (!scoped) (route: '/suppliers', label: isRiceMill ? 'Farmers / Mandi' : 'Vendors', icon: Icons.storefront_rounded),
      if (!scoped) (route: '/purchases', label: isRiceMill ? 'Paddy Procurement' : 'Purchases', icon: Icons.shopping_bag_rounded),
      // Rice mill-only menu items
      if (!scoped && isRiceMill)
        (route: '/mill-runs', label: 'Mill Runs', icon: Icons.factory_rounded),
      if (!scoped && isRiceMill)
        (route: '/milling-charges', label: 'Milling Charges', icon: Icons.receipt_long_rounded),
      (route: '/reports', label: 'Reports', icon: Icons.analytics_rounded),
      (route: '/ledger', label: isRiceMill ? 'Khata / Udhar' : 'Udhar', icon: Icons.account_balance_wallet_rounded),
      if (!scoped) (route: '/expenses', label: 'Expenses', icon: Icons.receipt_outlined),
      if (!scoped) (route: '/staff', label: 'Staff', icon: Icons.badge_rounded),
      if (!scoped) (route: '/owner-profile', label: 'Owner', icon: Icons.badge_outlined),
      if (!scoped) (route: '/settings', label: 'Settings', icon: Icons.settings_rounded),
      if (canManage) (route: '/counters', label: 'Counters', icon: Icons.storefront_rounded),
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
              trailing: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user?.posCounterName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(user!.posCounterName!,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    IconButton(
                      tooltip: 'Logout',
                      icon: const Icon(Icons.logout),
                      onPressed: () => _logout(context, ref),
                    ),
                  ],
                ),
              ),
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
            _showMenuSheet(context, ref, destinations, user);
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

  void _logout(BuildContext context, WidgetRef ref) {
    // Clear any in-memory POS selection so the next user never inherits the
    // previous user's open cart.
    ref.read(selectedCartIdProvider.notifier).state = null;
    // Sign out of the cloud store session; the app.dart listener clears the
    // local session and the router redirect returns to /store-login.
    ref.read(storeAuthControllerProvider.notifier).logout();
  }

  void _showMenuSheet(
    BuildContext context,
    WidgetRef ref,
    List<({String route, String label, IconData icon})> destinations,
    AppUser? user,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user?.username ?? 'User'),
                  subtitle: Text(user?.posCounterName != null
                      ? 'Counter: ${user!.posCounterName}'
                      : 'All counters'),
                  trailing: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _logout(context, ref);
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                  ),
                ),
                const Divider(),
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
          ),
        );
      },
    );
  }
}
