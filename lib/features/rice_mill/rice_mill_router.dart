import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../settings/presentation/settings_page.dart';
import '../store/presentation/operator_home_page.dart';
import '../store/presentation/operator_login_page.dart';
import '../store/presentation/operator_register_page.dart';
import '../notifications/presentation/notifications_page.dart';
import 'mill_run/presentation/mill_run_page.dart';
import 'mill_run/presentation/milling_charge_page.dart';
import 'mill_run/presentation/milling_config_page.dart';
import 'mill_run/presentation/milling_contracts_page.dart';
import 'presentation/milling_settings_section.dart';
import 'weighbridge/presentation/vehicle_entry_detail_page.dart';
import 'weighbridge/presentation/weighbridge_operator_dashboard.dart';

final riceMillRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter(
    ref,
    riceMillApp: true,
    publicRoutes: [
      GoRoute(
        path: '/operator-login',
        builder: (context, state) => const OperatorLoginPage(),
      ),
      GoRoute(
        path: '/operator-register',
        builder: (context, state) => const OperatorRegisterPage(),
      ),
      GoRoute(
        path: '/operator-home',
        builder: (context, state) => const OperatorHomePage(),
      ),
      GoRoute(
        path: '/weighbridge-dashboard',
        builder: (context, state) => const WeighbridgeOperatorDashboard(),
      ),
    ],
    authenticatedRoutes: [
      GoRoute(
        path: '/mill-runs',
        builder: (context, state) => const MillRunPage(),
      ),
      GoRoute(
        path: '/milling-charges',
        builder: (context, state) => const MillingChargePage(),
      ),
      GoRoute(
        path: '/milling-contracts',
        builder: (context, state) => const MillingContractsPage(),
      ),
      GoRoute(
        path: '/milling-config',
        builder: (context, state) => const MillingConfigPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationsPage(
          onVehicleEntrySelected: (id) => context.push('/vehicle-entry/$id'),
        ),
      ),
      GoRoute(
        path: '/vehicle-entry/:id',
        builder: (context, state) => VehicleEntryDetailPage(
          entryId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
    riceMillDestinations: const [
      (
        route: '/mill-runs',
        label: 'Mill Runs',
        icon: Icons.factory_rounded,
      ),
      (
        route: '/milling-charges',
        label: 'Milling Charges',
        icon: Icons.receipt_long_rounded,
      ),
    ],
    settingsPageBuilder: () => const SettingsPage(
      additionalSections: [
        SizedBox(height: 16),
        MillingSettingsSection(),
      ],
    ),
  );
});
