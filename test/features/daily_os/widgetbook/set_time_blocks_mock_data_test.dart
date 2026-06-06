import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/widgetbook/set_time_blocks_mock_data.dart';

void main() {
  group('SetTimeBlocksMockData', () {
    test('favourites are four distinctly-identified favourite categories', () {
      const favourites = SetTimeBlocksMockData.favourites;

      expect(favourites, hasLength(4));
      expect(
        favourites.map((c) => c.id),
        ['work', 'study', 'meals', 'exercise'],
      );
      expect(
        favourites.map((c) => c.id).toSet(),
        hasLength(favourites.length),
        reason: 'favourite ids must be unique',
      );
      for (final category in favourites) {
        expect(category.isFavourite, isTrue, reason: category.id);
        expect(category.name, isNotEmpty, reason: category.id);
      }
    });

    test('other categories are non-favourites with unique ids', () {
      const others = SetTimeBlocksMockData.otherCategories;

      expect(others, hasLength(5));
      expect(
        others.map((c) => c.id).toSet(),
        hasLength(others.length),
        reason: 'category ids must be unique',
      );
      for (final category in others) {
        expect(category.isFavourite, isFalse, reason: category.id);
        expect(category.name, isNotEmpty, reason: category.id);
      }
    });

    test('hasBlocks reflects the presence of time blocks', () {
      final all = [
        ...SetTimeBlocksMockData.favourites,
        ...SetTimeBlocksMockData.otherCategories,
      ];
      final withBlocks = all.where((c) => c.hasBlocks).map((c) => c.id);

      expect(withBlocks, ['work', 'meals', 'commute', 'household']);
      for (final category in all) {
        expect(category.hasBlocks, category.timeBlocks.isNotEmpty);
      }
    });

    test('every time block has a start, an end, and a combined label', () {
      final all = [
        ...SetTimeBlocksMockData.favourites,
        ...SetTimeBlocksMockData.otherCategories,
      ];
      for (final category in all) {
        for (final block in category.timeBlocks) {
          expect(block.start, isNotEmpty, reason: category.id);
          expect(block.end, isNotEmpty, reason: category.id);
          expect(block.label, '${block.start}-${block.end}');
        }
      }
    });
  });

  group('MockCategory.copyWith', () {
    test('overrides only the provided fields', () {
      const original = MockCategory(
        id: 'work',
        name: 'Work',
        color: Color(0xFF9500FF),
        icon: Icons.flight,
        isFavourite: true,
        timeBlocks: [MockTimeBlock(start: '8:00am', end: '12:00pm')],
      );

      final renamed = original.copyWith(name: 'Deep Work');

      expect(renamed.name, 'Deep Work');
      expect(renamed.id, original.id);
      expect(renamed.color, original.color);
      expect(renamed.icon, original.icon);
      expect(renamed.isFavourite, original.isFavourite);
      expect(renamed.timeBlocks, original.timeBlocks);

      final cleared = original.copyWith(timeBlocks: const []);
      expect(cleared.hasBlocks, isFalse);
      expect(original.hasBlocks, isTrue);
    });
  });
}
