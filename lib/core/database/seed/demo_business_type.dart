enum DemoBusinessType {
  grocery,
  pharmacy,
  garment,
  electronics,
  bakery,
  riceMill,
  hardwareSanitary,
  hotel,
  other,
}

extension DemoBusinessTypeLabel on DemoBusinessType {
  String get label => switch (this) {
        DemoBusinessType.grocery => 'Grocery / Kirana',
        DemoBusinessType.pharmacy => 'Pharmacy',
        DemoBusinessType.garment => 'Garment / Apparel',
        DemoBusinessType.electronics => 'Electronics',
        DemoBusinessType.bakery => 'Bakery',
        DemoBusinessType.riceMill => 'Rice Mill',
        DemoBusinessType.hardwareSanitary => 'Hardware / Sanitary',
        DemoBusinessType.hotel => 'Hotel',
        DemoBusinessType.other => 'Other',
      };
}
