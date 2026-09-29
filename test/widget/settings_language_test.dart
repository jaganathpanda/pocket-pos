import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/core/di/providers.dart';
import 'package:pocket_pos/core/localization/app_locale.dart';
import 'package:pocket_pos/features/dashboard/presentation/dashboard_page.dart';
import 'package:pocket_pos/features/settings/presentation/settings_page.dart';
import 'package:pocket_pos/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings page defaults to English and exposes language selector',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWith((ref) => AppLocaleController()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: SettingsLanguageSection()),
        ),
      ),
    );

    final dropdown = find.byType(DropdownButtonFormField<Locale>);
    expect(dropdown, findsOneWidget);

    final field = tester.widget<DropdownButtonFormField<Locale>>(dropdown);
    expect(field.initialValue, const Locale('en'));

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिंदी').last);
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), const Locale('hi'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_locale'), 'hi');
  });

  testWidgets('dashboard title is localized in Hindi',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final controller = AppLocaleController();
    await controller.setLocale(const Locale('hi'));
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWith((ref) => controller),
        dashboardMetricsProvider.overrideWith(
          (ref) async => const DashboardMetrics(
            todayRevenue: 0,
            todayTransactions: 0,
            totalRevenue: 0,
            totalTransactions: 0,
            totalTax: 0,
            totalDiscount: 0,
            activeCarts: 0,
            lowStockItems: 0,
            outOfStockItems: 0,
            pendingCredit: 0,
            totalProducts: 0,
            totalCustomers: 0,
          ),
        ),
        upcomingExpiringProductsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('hi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DashboardPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('डैशबोर्ड'), findsOneWidget);
    expect(find.text('आज की बिक्री'), findsOneWidget);
  });
}
