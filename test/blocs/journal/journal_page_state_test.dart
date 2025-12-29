import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';

void main() {
  group('TaskSortOption', () {
    test('enum has correct values', () {
      expect(TaskSortOption.values.length, 2);
      expect(TaskSortOption.byPriority.index, 0);
      expect(TaskSortOption.byDate.index, 1);
    });

    test('enum name serialization', () {
      expect(TaskSortOption.byPriority.name, 'byPriority');
      expect(TaskSortOption.byDate.name, 'byDate');
    });
  });

  group('TasksFilter serialization', () {
    test('serializes and deserializes with default values', () {
      final filter = TasksFilter();

      final json = filter.toJson();
      final decoded = TasksFilter.fromJson(json);

      expect(decoded.selectedCategoryIds, isEmpty);
      expect(decoded.selectedTaskStatuses, isEmpty);
      expect(decoded.selectedLabelIds, isEmpty);
      expect(decoded.selectedPriorities, isEmpty);
      expect(decoded.sortOption, TaskSortOption.byPriority);
      expect(decoded.showCreationDate, isFalse);
    });

    test('serializes and deserializes sortOption byPriority', () {
      final filter = TasksFilter();

      final json = filter.toJson();
      final decoded = TasksFilter.fromJson(json);

      expect(decoded.sortOption, TaskSortOption.byPriority);
    });

    test('serializes and deserializes sortOption byDate', () {
      final filter = TasksFilter(
        sortOption: TaskSortOption.byDate,
      );

      final json = filter.toJson();
      final decoded = TasksFilter.fromJson(json);

      expect(decoded.sortOption, TaskSortOption.byDate);
    });

    test('serializes and deserializes showCreationDate true', () {
      final filter = TasksFilter(
        showCreationDate: true,
      );

      final json = filter.toJson();
      final decoded = TasksFilter.fromJson(json);

      expect(decoded.showCreationDate, isTrue);
    });

    test('serializes and deserializes showCreationDate false', () {
      final filter = TasksFilter();

      final json = filter.toJson();
      final decoded = TasksFilter.fromJson(json);

      expect(decoded.showCreationDate, isFalse);
    });

    test('serializes and deserializes all fields together', () {
      final filter = TasksFilter(
        selectedCategoryIds: {'cat1', 'cat2'},
        selectedTaskStatuses: {'OPEN', 'DONE'},
        selectedLabelIds: {'label1'},
        selectedPriorities: {'P0', 'P1'},
        sortOption: TaskSortOption.byDate,
        showCreationDate: true,
      );

      final json = filter.toJson();
      final decoded = TasksFilter.fromJson(json);

      expect(decoded.selectedCategoryIds, {'cat1', 'cat2'});
      expect(decoded.selectedTaskStatuses, {'OPEN', 'DONE'});
      expect(decoded.selectedLabelIds, {'label1'});
      expect(decoded.selectedPriorities, {'P0', 'P1'});
      expect(decoded.sortOption, TaskSortOption.byDate);
      expect(decoded.showCreationDate, isTrue);
    });

    test('JSON round-trip through jsonEncode/jsonDecode', () {
      final filter = TasksFilter(
        selectedCategoryIds: {'cat1'},
        selectedTaskStatuses: {'OPEN'},
        sortOption: TaskSortOption.byDate,
        showCreationDate: true,
      );

      // Simulate actual persistence pattern
      final encoded = jsonEncode(filter.toJson());
      final decoded =
          TasksFilter.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.selectedCategoryIds, {'cat1'});
      expect(decoded.selectedTaskStatuses, {'OPEN'});
      expect(decoded.sortOption, TaskSortOption.byDate);
      expect(decoded.showCreationDate, isTrue);
    });

    test('handles missing sortOption field gracefully (defaults to byPriority)',
        () {
      // Simulate legacy JSON without sortOption field
      final legacyJson = <String, dynamic>{
        'selectedCategoryIds': ['cat1'],
        'selectedTaskStatuses': ['OPEN'],
        'selectedLabelIds': <String>[],
        'selectedPriorities': <String>[],
        // sortOption and showCreationDate missing
      };

      final decoded = TasksFilter.fromJson(legacyJson);

      expect(decoded.selectedCategoryIds, {'cat1'});
      expect(decoded.selectedTaskStatuses, {'OPEN'});
      expect(decoded.sortOption, TaskSortOption.byPriority); // default
      expect(decoded.showCreationDate, isFalse); // default
    });

    test(
        'handles missing showCreationDate field gracefully (defaults to false)',
        () {
      final legacyJson = <String, dynamic>{
        'selectedCategoryIds': <String>[],
        'selectedTaskStatuses': <String>[],
        'selectedLabelIds': <String>[],
        'selectedPriorities': <String>[],
        'sortOption': 'byDate',
        // showCreationDate missing
      };

      final decoded = TasksFilter.fromJson(legacyJson);

      expect(decoded.sortOption, TaskSortOption.byDate);
      expect(decoded.showCreationDate, isFalse); // default
    });
  });

  group('TasksFilter equality', () {
    test('two filters with same values are equal', () {
      final filter1 = TasksFilter(
        selectedCategoryIds: {'cat1'},
        sortOption: TaskSortOption.byDate,
        showCreationDate: true,
      );
      final filter2 = TasksFilter(
        selectedCategoryIds: {'cat1'},
        sortOption: TaskSortOption.byDate,
        showCreationDate: true,
      );

      expect(filter1, equals(filter2));
    });

    test('two filters with different sortOption are not equal', () {
      final filter1 = TasksFilter();
      final filter2 = TasksFilter(
        sortOption: TaskSortOption.byDate,
      );

      expect(filter1, isNot(equals(filter2)));
    });

    test('two filters with different showCreationDate are not equal', () {
      final filter1 = TasksFilter(
        showCreationDate: true,
      );
      final filter2 = TasksFilter();

      expect(filter1, isNot(equals(filter2)));
    });
  });
}
