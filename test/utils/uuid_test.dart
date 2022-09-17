import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/uuid.dart';

void main() {
  group('UUID test', () {
    test('Generated UUID is valid', () {
      expect(isUuid(uuid.v1()), true);
    });
  });
}
