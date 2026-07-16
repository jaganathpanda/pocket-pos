/// Industry-neutral description of a demo product catalog. Each business-type
/// dataset file (bakery, electronics, …) exposes a [DemoCatalog]; the
/// [DemoDataLoader] turns it into Categories/Products/Inventory rows.
class DemoProduct {
  const DemoProduct({
    required this.name,
    required this.code,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    this.barcode,
    this.mrp = 0,
    this.taxPercent = 0,
    this.unit = 'piece',
    this.stock = 0,
    this.lowStock = 5,
  });

  final String name;
  final String code;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final String? barcode;
  final double mrp;
  final double taxPercent;
  final String unit;
  final double stock;
  final double lowStock;
}

class DemoCatalog {
  const DemoCatalog({required this.categories, required this.products});

  final List<String> categories;
  final List<DemoProduct> products;
}
