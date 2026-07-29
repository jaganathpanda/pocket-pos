import 'bakery_demo_data.dart';
import 'demo_business_type.dart';
import 'demo_catalog.dart';
import 'electronics_demo_data.dart';
import 'garment_demo_data.dart';
import 'grocery_demo_data.dart';
import 'pharmacy_demo_data.dart';

/// Registry of demo product catalogs by business type. The actual seeding into
/// a store is done by `StoreCatalogSeeder` (Firestore) at registration.
class DemoDataLoader {
  const DemoDataLoader._();

  /// Catalog used when none is chosen.
  static const DemoBusinessType defaultBusinessType = DemoBusinessType.grocery;

  static DemoCatalog catalogFor(DemoBusinessType type) {
    switch (type) {
      case DemoBusinessType.grocery:
        return groceryCatalog;
      case DemoBusinessType.pharmacy:
        return pharmacyCatalog;
      case DemoBusinessType.garment:
        return garmentCatalog;
      case DemoBusinessType.electronics:
        return electronicsCatalog;
      case DemoBusinessType.bakery:
        return bakeryCatalog;
    }
  }
}
