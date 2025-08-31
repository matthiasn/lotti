import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/domain/models/task_query.dart';

void main() {
  group('TaskQuery', () {
    group('factory constructors', () {
      test('dateRange creates query with specific dates', () {
        final startDate = DateTime(2024);
        final endDate = DateTime(2024, 1, 31);

        final query = TaskQuery.dateRange(startDate, endDate);

        expect(query.startDate, equals(startDate));
        expect(query.endDate, equals(endDate));
        expect(query.categoryIds, isNull);
        expect(query.tagIds, isNull);
        expect(query.limit, isNull);
        expect(query.queryType, isNull);
        expect(query.filters, isNull);
      });

      test('lastDays creates query for past N days', () {
        final query = TaskQuery.lastDays(7);
        final now = DateTime.now();
        final expectedStart = now.subtract(const Duration(days: 7));

        // Check that the date range is approximately correct (within same day)
        expect(query.startDate.year, equals(expectedStart.year));
        expect(query.startDate.month, equals(expectedStart.month));
        expect(query.startDate.day, equals(expectedStart.day));
        expect(query.endDate.year, equals(now.year));
        expect(query.endDate.month, equals(now.month));
        expect(query.endDate.day, equals(now.day));
        expect(query.hasDateRange, isTrue);
      });

      test('thisWeek creates query for current week', () {
        final now = DateTime.now();
        final query = TaskQuery.thisWeek();

        expect(query.startDate.weekday, equals(1)); // Monday
        expect(query.endDate.year, equals(now.year));
        expect(query.endDate.month, equals(now.month));
        expect(query.endDate.day, equals(now.day));
        expect(query.hasDateRange, isTrue);
      });

      test('thisMonth creates query for current month', () {
        final now = DateTime.now();
        final query = TaskQuery.thisMonth();

        expect(query.startDate, equals(DateTime(now.year, now.month)));
        expect(query.endDate.year, equals(now.year));
        expect(query.endDate.month, equals(now.month));
        expect(query.endDate.day, equals(now.day));
        expect(query.hasDateRange, isTrue);
      });

      test('lastMonth creates query for previous month', () {
        final now = DateTime.now();
        final query = TaskQuery.lastMonth();

        // Handle year rollover for January
        final expectedYear = now.month == 1 ? now.year - 1 : now.year;
        final expectedMonth = now.month == 1 ? 12 : now.month - 1;

        expect(query.startDate.year, equals(expectedYear));
        expect(query.startDate.month, equals(expectedMonth));
        expect(query.startDate.day, equals(1));

        // Day 0 of current month = last day of previous month
        final expectedEndDay = DateTime(now.year, now.month, 0).day;
        expect(query.endDate.day, equals(expectedEndDay));
        expect(query.hasDateRange, isTrue);
      });
    });

    group('extensions', () {
      test('hasDateRange returns true when start is before end', () {
        final query = TaskQuery.dateRange(
          DateTime(2024),
          DateTime(2024, 1, 31),
        );

        expect(query.hasDateRange, isTrue);
      });

      test('hasCategoryFilter returns true when categories exist', () {
        final query = TaskQuery(
          startDate: DateTime(2024),
          endDate: DateTime(2024, 1, 31),
          categoryIds: ['cat1', 'cat2'],
        );

        expect(query.hasCategoryFilter, isTrue);
      });

      test('hasCategoryFilter returns false when categories are null or empty',
          () {
        final query1 = TaskQuery(
          startDate: DateTime(2024),
          endDate: DateTime(2024, 1, 31),
        );

        final query2 = TaskQuery(
          startDate: DateTime(2024),
          endDate: DateTime(2024, 1, 31),
          categoryIds: [],
        );

        expect(query1.hasCategoryFilter, isFalse);
        expect(query2.hasCategoryFilter, isFalse);
      });

      test('hasTagFilter returns true when tags exist', () {
        final query = TaskQuery(
          startDate: DateTime(2024),
          endDate: DateTime(2024, 1, 31),
          tagIds: ['tag1', 'tag2'],
        );

        expect(query.hasTagFilter, isTrue);
      });

      test('dayCount calculates correct number of days', () {
        final query = TaskQuery.dateRange(
          DateTime(2024),
          DateTime(2024, 1, 8),
        );

        expect(query.dayCount, equals(7));
      });

      test('withCategories returns new query with categories', () {
        final originalQuery = TaskQuery.dateRange(
          DateTime(2024),
          DateTime(2024, 1, 31),
        );

        final newQuery = originalQuery.withCategories(['cat1', 'cat2']);

        expect(newQuery.categoryIds, equals(['cat1', 'cat2']));
        expect(newQuery.startDate, equals(originalQuery.startDate));
        expect(newQuery.endDate, equals(originalQuery.endDate));
      });

      test('withTags returns new query with tags', () {
        final originalQuery = TaskQuery.dateRange(
          DateTime(2024),
          DateTime(2024, 1, 31),
        );

        final newQuery = originalQuery.withTags(['tag1', 'tag2']);

        expect(newQuery.tagIds, equals(['tag1', 'tag2']));
        expect(newQuery.startDate, equals(originalQuery.startDate));
        expect(newQuery.endDate, equals(originalQuery.endDate));
      });

      test('withLimit returns new query with limit', () {
        final originalQuery = TaskQuery.dateRange(
          DateTime(2024),
          DateTime(2024, 1, 31),
        );

        final newQuery = originalQuery.withLimit(50);

        expect(newQuery.limit, equals(50));
        expect(newQuery.startDate, equals(originalQuery.startDate));
        expect(newQuery.endDate, equals(originalQuery.endDate));
      });
    });

    group('JSON serialization', () {
      test('toJson and fromJson work correctly', () {
        final originalQuery = TaskQuery(
          startDate: DateTime(2024),
          endDate: DateTime(2024, 1, 31),
          categoryIds: ['cat1'],
          tagIds: ['tag1'],
          limit: 100,
          queryType: TaskQueryType.withTimeLogged,
          filters: {'status': 'completed'},
        );

        final json = originalQuery.toJson();
        final deserializedQuery = TaskQuery.fromJson(json);

        expect(deserializedQuery.startDate, equals(originalQuery.startDate));
        expect(deserializedQuery.endDate, equals(originalQuery.endDate));
        expect(
            deserializedQuery.categoryIds, equals(originalQuery.categoryIds));
        expect(deserializedQuery.tagIds, equals(originalQuery.tagIds));
        expect(deserializedQuery.limit, equals(originalQuery.limit));
        expect(deserializedQuery.queryType, equals(originalQuery.queryType));
        expect(deserializedQuery.filters, equals(originalQuery.filters));
      });
    });
  });

  group('TaskQueryType', () {
    test('enum values are correct', () {
      expect(TaskQueryType.values, contains(TaskQueryType.all));
      expect(TaskQueryType.values, contains(TaskQueryType.withTimeLogged));
      expect(TaskQueryType.values, contains(TaskQueryType.withAiSummary));
      expect(TaskQueryType.values, contains(TaskQueryType.completed));
      expect(TaskQueryType.values, contains(TaskQueryType.incomplete));
    });
  });
}
