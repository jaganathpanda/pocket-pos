enum DemoBusinessType {
  grocery,
  pharmacy,
  garment,
  electronics,
  bakery,
}

extension DemoBusinessTypeLabel on DemoBusinessType {
  String get label => switch (this) {
        DemoBusinessType.grocery => 'Grocery / Kirana',
        DemoBusinessType.pharmacy => 'Pharmacy',
        DemoBusinessType.garment => 'Garment / Apparel',
        DemoBusinessType.electronics => 'Electronics',
        DemoBusinessType.bakery => 'Bakery',
      };
}
