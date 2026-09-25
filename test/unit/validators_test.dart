import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/core/utilities/validators.dart';

void main() {
  group('validators', () {
    test('mobile validation', () {
      expect(isValidMobile('9876543210'), isTrue);
      expect(isValidMobile(' 9876543210 '), isTrue);
      expect(isValidMobile('12345'), isFalse);
      expect(validateMobile(''), isNull);
      expect(validateMobile('', required: true), isNotNull);
      expect(validateMobile('9876543210'), isNull);
      expect(validateMobile('12345'), isNotNull);
    });

    test('pin validation', () {
      expect(isStrongPin('1234'), isTrue);
      expect(isStrongPin('12ab'), isFalse);
    });
  });
}
