import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/location.dart';

void main() {
  group('LocationConstants', () {
    test('has correct constant values', () {
      expect(LocationConstants.locationTimeout, const Duration(seconds: 10));
      expect(LocationConstants.appDesktopId, 'com.matthiasn.lotti');
    });
  });
}
