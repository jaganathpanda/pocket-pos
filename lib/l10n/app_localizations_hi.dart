// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'पॉकेट POS';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get language => 'भाषा';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिंदी';

  @override
  String get save => 'सेव';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get refreshMetrics => 'मेट्रिक्स रीफ्रेश करें';

  @override
  String get todayRevenue => 'आज की बिक्री';

  @override
  String get todayTransactions => 'आज के लेनदेन';

  @override
  String get totalRevenue => 'कुल बिक्री';

  @override
  String get totalTransactions => 'कुल लेनदेन';

  @override
  String get totalTaxCollected => 'कुल एकत्रित कर';

  @override
  String get totalDiscount => 'कुल छूट';

  @override
  String get activeCarts => 'सक्रिय कार्ट';

  @override
  String get totalProducts => 'कुल उत्पाद';

  @override
  String get totalCustomers => 'कुल ग्राहक';

  @override
  String get lowStockItems => 'कम स्टॉक वाले उत्पाद';

  @override
  String get outOfStock => 'स्टॉक समाप्त';

  @override
  String get pendingCredit => 'बकाया उधार';

  @override
  String get upcomingExpiry => 'आगामी समाप्ति';

  @override
  String productsExpiringCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count उत्पाद जल्द समाप्त होंगे',
      one: '1 उत्पाद जल्द समाप्त होगा',
    );
    return '$_temp0';
  }

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन बाकी',
      one: '1 दिन बाकी',
    );
    return '$_temp0';
  }

  @override
  String get expired => 'समाप्त';

  @override
  String dashboardError(String message) {
    return 'त्रुटि: $message';
  }

  @override
  String get productsExpiringSoon => 'जल्दी समाप्त होने वाले उत्पाद';

  @override
  String get clickToViewAll => 'सभी देखने के लिए क्लिक करें';

  @override
  String get expiryDataUnavailable => 'समाप्ति डेटा उपलब्ध नहीं है';

  @override
  String get close => 'बंद करें';
}
