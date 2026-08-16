class AppConstants {
  static const appName = 'Pocket POS';
  static const defaultCurrency = 'INR';

  /// Google Apps Script Web App URL for anonymous customer cart session minting.
  /// Replace with your deployed /exec URL after deploying appscript/cart_session.js.
  /// See appscript/README.md for setup steps.
  static const cartSessionEndpoint =
      'https://script.google.com/macros/s/AKfycbwT7NrcEzsA6BHFUist0Xdu6mQtcFPieUJXvCIHOtYUStJV_9XYzrA8bZYCK7aPvW0V/exec';

  static const defaultTaxPercent = 0.0;
  static const lowStockThreshold = 5;

  static const roles = <String>[
    'super_admin',
    'shop_owner',
    'shop_manager',
    'cashier',
  ];
}
