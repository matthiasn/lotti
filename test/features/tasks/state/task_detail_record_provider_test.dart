import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';

void main() {
  group('showcaseFormatDuration', () {
    test('formats hours and minutes', () {
      expect(
        showcaseFormatDuration(const Duration(hours: 2, minutes: 30)),
        '2h 30m',
      );
    });

    test('formats single hour with zero minutes', () {
      expect(
        showcaseFormatDuration(const Duration(hours: 1)),
        '1h 0m',
      );
    });

    test('formats minutes and seconds', () {
      expect(
        showcaseFormatDuration(const Duration(minutes: 11, seconds: 38)),
        '11m 38s',
      );
    });

    test('formats minutes without seconds', () {
      expect(
        showcaseFormatDuration(const Duration(minutes: 5)),
        '5m',
      );
    });

    test('formats seconds only for sub-minute durations', () {
      expect(
        showcaseFormatDuration(const Duration(seconds: 45)),
        '45s',
      );
    });

    test('formats zero duration', () {
      expect(
        showcaseFormatDuration(Duration.zero),
        '0s',
      );
    });
  });
}
