import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os/voice/day_plan_voice_strategy.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  group('CategoryResolver', () {
    late MockEntitiesCacheService mockCacheService;
    late CategoryResolver resolver;

    final testDate = DateTime(2026);

    final workCategory = CategoryDefinition(
      id: 'cat-1',
      name: 'Work',
      color: '#FF0000',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
    );

    final exerciseCategory = CategoryDefinition(
      id: 'cat-2',
      name: 'Exercise',
      color: '#00FF00',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
    );

    final deepWorkCategory = CategoryDefinition(
      id: 'cat-3',
      name: 'Deep Work',
      color: '#0000FF',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
    );

    final personalCategory = CategoryDefinition(
      id: 'cat-4',
      name: 'Personal Development',
      color: '#FFFF00',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
    );

    setUp(() {
      mockCacheService = MockEntitiesCacheService();
      resolver = CategoryResolver(mockCacheService);

      when(() => mockCacheService.sortedCategories).thenReturn([
        workCategory,
        exerciseCategory,
        deepWorkCategory,
        personalCategory,
      ]);
    });

    group('exact match', () {
      test('finds category with exact match (same case)', () {
        final result = resolver.resolve('Work');

        expect(result, isNotNull);
        expect(result!.id, 'cat-1');
        expect(result.name, 'Work');
      });

      test('finds category with exact match (lowercase)', () {
        final result = resolver.resolve('work');

        expect(result, isNotNull);
        expect(result!.id, 'cat-1');
      });

      test('finds category with exact match (uppercase)', () {
        final result = resolver.resolve('WORK');

        expect(result, isNotNull);
        expect(result!.id, 'cat-1');
      });

      test('finds category with exact match (mixed case)', () {
        final result = resolver.resolve('WoRk');

        expect(result, isNotNull);
        expect(result!.id, 'cat-1');
      });

      test('finds multi-word category with exact match', () {
        final result = resolver.resolve('deep work');

        expect(result, isNotNull);
        expect(result!.id, 'cat-3');
        expect(result.name, 'Deep Work');
      });
    });

    group('prefix match', () {
      test('finds category by prefix', () {
        final result = resolver.resolve('exer');

        expect(result, isNotNull);
        expect(result!.id, 'cat-2');
        expect(result.name, 'Exercise');
      });

      test('finds category by single letter prefix', () {
        final result = resolver.resolve('w');

        expect(result, isNotNull);
        expect(result!.id, 'cat-1');
        expect(result.name, 'Work');
      });

      test('prefers exact match over prefix match', () {
        // 'Work' should match exactly, not 'Deep Work' by contains
        final result = resolver.resolve('Work');

        expect(result, isNotNull);
        expect(result!.name, 'Work');
      });

      test('finds multi-word category by prefix', () {
        final result = resolver.resolve('personal');

        expect(result, isNotNull);
        expect(result!.id, 'cat-4');
        expect(result.name, 'Personal Development');
      });
    });

    group('contains match', () {
      test('finds category by contained substring', () {
        final result = resolver.resolve('development');

        expect(result, isNotNull);
        expect(result!.id, 'cat-4');
        expect(result.name, 'Personal Development');
      });

      test('finds category by middle substring', () {
        final result = resolver.resolve('ercis');

        expect(result, isNotNull);
        expect(result!.id, 'cat-2');
        expect(result.name, 'Exercise');
      });
    });

    group('priority order', () {
      test('exact match takes priority over prefix match', () {
        // Setup: categories where one name is a prefix of another
        when(() => mockCacheService.sortedCategories).thenReturn([
          CategoryDefinition(
            id: 'cat-a',
            name: 'Work',
            color: '#FF0000',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
            private: false,
            active: true,
          ),
          CategoryDefinition(
            id: 'cat-b',
            name: 'Workout',
            color: '#00FF00',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
            private: false,
            active: true,
          ),
        ]);

        final result = resolver.resolve('work');

        expect(result!.id, 'cat-a');
        expect(result.name, 'Work');
      });

      test('prefix match takes priority over contains match', () {
        // 'Deep' should match 'Deep Work' by prefix, not 'Personal Development'
        final result = resolver.resolve('deep');

        expect(result, isNotNull);
        expect(result!.name, 'Deep Work');
      });
    });

    group('whitespace handling', () {
      test('trims leading whitespace', () {
        final result = resolver.resolve('  Work');

        expect(result, isNotNull);
        expect(result!.name, 'Work');
      });

      test('trims trailing whitespace', () {
        final result = resolver.resolve('Work  ');

        expect(result, isNotNull);
        expect(result!.name, 'Work');
      });

      test('trims both leading and trailing whitespace', () {
        final result = resolver.resolve('  Work  ');

        expect(result, isNotNull);
        expect(result!.name, 'Work');
      });
    });

    group('no match scenarios', () {
      test('returns null for non-existent category', () {
        final result = resolver.resolve('Nonexistent');

        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = resolver.resolve('');

        expect(result, isNull);
      });

      test('returns null for whitespace-only string', () {
        final result = resolver.resolve('   ');

        expect(result, isNull);
      });

      test('returns null when no categories exist', () {
        when(() => mockCacheService.sortedCategories).thenReturn([]);

        final result = resolver.resolve('Work');

        expect(result, isNull);
      });
    });
  });
}
