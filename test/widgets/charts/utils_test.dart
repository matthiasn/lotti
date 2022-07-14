import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/charts/utils.dart';

void main() {
  group('Chart utils', () {
    test('Hours as int are correctly formatted', () {
      expect(
        hoursToHhMm(12),
        '12:00',
      );
    });

    test('Hours as float is rounded down', () {
      expect(
        hoursToHhMm(1.333333),
        '01:19',
      );
    });

    test('Hours as float from fraction are correctly formatted', () {
      expect(
        hoursToHhMm(2 / 3),
        '00:40',
      );
    });

    test('Hours are nullable, returning 00:00', () {
      expect(
        hoursToHhMm(null),
        '00:00',
      );
    });

    test('Hours are rounded down', () {
      expect(
        hoursToHhMm(1.999),
        '01:59',
      );
    });

    test('Minutes as int are correctly formatted', () {
      expect(
        minutesToHhMm(183),
        '03:03',
      );
    });

    test('Minutes as float are correctly formatted', () {
      expect(
        minutesToHhMm(1.3333),
        '00:01',
      );
    });

    test('Minutes are rounded down', () {
      expect(
        minutesToHhMm(1.999),
        '00:01',
      );
    });

    test('Minutes are nullable, returning 00:00', () {
      expect(
        minutesToHhMm(null),
        '00:00',
      );
    });
  });
}
