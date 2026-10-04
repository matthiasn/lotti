import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';

void main() {
  group('timelineBlockTintAlpha — the paint-by-numbers contract', () {
    test('a planned block is the same faint sketch in either theme', () {
      expect(
        timelineBlockTintAlpha(tracked: false, isLight: true),
        timelineBlockTintAlpha(tracked: false, isLight: false),
      );
    });

    test('a recorded block is filled in more strongly than a planned one', () {
      for (final isLight in [true, false]) {
        expect(
          timelineBlockTintAlpha(tracked: true, isLight: isLight),
          greaterThan(timelineBlockTintAlpha(tracked: false, isLight: isLight)),
        );
      }
    });

    test('light mode gives a recorded block more chroma than dark mode', () {
      expect(
        timelineBlockTintAlpha(tracked: true, isLight: true),
        greaterThan(timelineBlockTintAlpha(tracked: true, isLight: false)),
      );
    });

    test('a planned accent keys the category more strongly than its fill', () {
      expect(
        kTimelinePlannedAccentAlpha,
        greaterThan(timelineBlockTintAlpha(tracked: false, isLight: true)),
      );
    });
  });
}
