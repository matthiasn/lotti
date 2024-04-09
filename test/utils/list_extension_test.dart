import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/list_extension.dart';

void main() {
  group('List extension test', () {
    test('Partition divides list in before, match, after', () {
      final (before, found, after) =
          ['1', '2', 'foo', '3', '4', '5'].partition((item) => item == 'foo');
      expect(listEquals(before, ['1', '2']), true);
      expect(found, 'foo');
      expect(listEquals(after, ['3', '4', '5']), true);
    });

    test('Partition handles empty list', () {
      final (before, found, after) =
          <String>[].partition((item) => item == 'foo');
      expect(listEquals(before, []), true);
      expect(found, null);
      expect(after, null);
    });

    test('Partition handles match in first position', () {
      final (before, found, after) =
          ['foo', '3', '4', '5'].partition((item) => item == 'foo');
      expect(listEquals(before, []), true);
      expect(found, 'foo');
      expect(listEquals(after, ['3', '4', '5']), true);
    });

    test('Partition divides list in last position', () {
      final (before, found, after) =
          ['1', '2', '3', 'foo'].partition((item) => item == 'foo');
      expect(listEquals(before, ['1', '2', '3']), true);
      expect(found, 'foo');
      expect(listEquals(after, null), true);
    });

    test('Partition handles no match', () {
      final (before, found, after) =
          ['1', '2', 'foo', '3'].partition((item) => item == 'bar');
      expect(listEquals(before, ['1', '2', 'foo', '3']), true);
      expect(found, null);
      expect(listEquals(after, null), true);
    });
  });
}
