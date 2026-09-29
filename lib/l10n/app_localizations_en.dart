// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pocket POS';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get save => 'Save';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get refreshMetrics => 'Refresh metrics';

  @override
  String get todayRevenue => 'Today\'s Revenue';

  @override
  String get todayTransactions => 'Today\'s Transactions';

  @override
  String get totalRevenue => 'Total Revenue';

  @override
  String get totalTransactions => 'Total Transactions';

  @override
  String get totalTaxCollected => 'Total Tax Collected';

  @override
  String get totalDiscount => 'Total Discount';

  @override
  String get activeCarts => 'Active Carts';

  @override
  String get totalProducts => 'Total Products';

  @override
  String get totalCustomers => 'Total Customers';

  @override
  String get lowStockItems => 'Low Stock Items';

  @override
  String get outOfStock => 'Out Of Stock';

  @override
  String get pendingCredit => 'Pending Credit';

  @override
  String get upcomingExpiry => 'Upcoming Expiry';

  @override
  String productsExpiringCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products expiring soon',
      one: '1 product expiring soon',
    );
    return '$_temp0';
  }

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get expired => 'EXPIRED';

  @override
  String dashboardError(String message) {
    return 'Error: $message';
  }

  @override
  String get productsExpiringSoon => 'Products Expiring Soon';

  @override
  String get clickToViewAll => 'Click to view all';

  @override
  String get expiryDataUnavailable => 'Expiry data unavailable';

  @override
  String get close => 'Close';
}
