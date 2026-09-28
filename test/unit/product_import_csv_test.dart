import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/features/products/presentation/product_import_page.dart';

void main() {
  group('product import csv', () {
    test('opening stock parses numeric values and blank values as zero', () {
      expect(parseProductImportOpeningStock('25'), 25);
      expect(parseProductImportOpeningStock('0.5'), 0.5);
      expect(parseProductImportOpeningStock(''), 0.0);
      expect(parseProductImportOpeningStock('   '), 0.0);
    });
  });
}
