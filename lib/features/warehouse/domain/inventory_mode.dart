/// How the shop tracks stock. Stored in `app_settings` under `inventory_mode`.
enum InventoryMode {
  none,
  single,
  multiple;

  static InventoryMode fromValue(String value) {
    switch (value) {
      case 'none':
        return InventoryMode.none;
      case 'multiple':
        return InventoryMode.multiple;
      case 'single':
      default:
        return InventoryMode.single;
    }
  }

  String get value => switch (this) {
        InventoryMode.none => 'none',
        InventoryMode.single => 'single',
        InventoryMode.multiple => 'multiple',
      };

  String get label => switch (this) {
        InventoryMode.none => 'No Inventory',
        InventoryMode.single => 'Single Warehouse',
        InventoryMode.multiple => 'Multiple Warehouses',
      };

  String get description => switch (this) {
        InventoryMode.none =>
          'Stock is not tracked. Purchases and sales do not change stock.',
        InventoryMode.single =>
          'Track stock in one default warehouse. No warehouse selection needed.',
        InventoryMode.multiple =>
          'Track stock per warehouse. Choose a warehouse for purchases, POS, adjustments and transfers.',
      };

  /// Whether stock is tracked at all (purchases/sales adjust inventory).
  bool get tracksStock => this != InventoryMode.none;

  /// Whether the user must pick a warehouse (multiple-warehouse mode).
  bool get usesWarehouses => this == InventoryMode.multiple;
}
