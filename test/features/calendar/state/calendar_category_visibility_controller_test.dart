// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/calendar/state/calendar_category_visibility_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsDb extends Mock implements SettingsDb {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockSettingsDb mockSettingsDb;
  late StreamController<List<SettingsItem>> settingsStreamController;
  late Listener<Set<String>> listener;

  setUpAll(() {
    registerFallbackValue(<String>{});
    getIt.allowReassignment = true;
  });

  setUp(() {
    mockSettingsDb = MockSettingsDb();
    settingsStreamController = StreamController<List<SettingsItem>>.broadcast();
    listener = Listener<Set<String>>();

    when(() => mockSettingsDb.watchSettingsItemByKey(any()))
        .thenAnswer((_) => settingsStreamController.stream);

    getIt.registerSingleton<SettingsDb>(mockSettingsDb);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    settingsStreamController.close();
  });

  group('CalendarCategoryVisibilityController', () {
    test('initial state is empty set (show all)', () {
      // Act
      final state =
          container.read(calendarCategoryVisibilityControllerProvider);

      // Assert
      expect(state, isEmpty);
    });

    test('listens to settings changes and updates state', () async {
      // Arrange
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        listener.call,
        fireImmediately: true,
      );

      const filter = TasksFilter(
        selectedCategoryIds: {'category-1', 'category-2'},
      );

      // Act - simulate settings update
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);

      // Allow stream to process
      await Future<void>.delayed(Duration.zero);

      // Assert
      final updatedState =
          container.read(calendarCategoryVisibilityControllerProvider);
      expect(updatedState, {'category-1', 'category-2'});
    });

    test('handles empty settings list', () async {
      // Arrange
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        listener.call,
        fireImmediately: true,
      );

      // Act - simulate empty settings
      settingsStreamController.add([]);

      // Allow stream to process
      await Future<void>.delayed(Duration.zero);

      // Assert
      final updatedState =
          container.read(calendarCategoryVisibilityControllerProvider);
      expect(updatedState, isEmpty);
    });

    test('handles malformed JSON gracefully', () async {
      // Arrange
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        listener.call,
        fireImmediately: true,
      );

      // Act - simulate malformed settings
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: 'not valid json',
          updatedAt: DateTime(2024),
        ),
      ]);

      // Allow stream to process
      await Future<void>.delayed(Duration.zero);

      // Assert - should fall back to empty set
      final updatedState =
          container.read(calendarCategoryVisibilityControllerProvider);
      expect(updatedState, isEmpty);
    });

    test('handles settings update with multiple categories', () async {
      // Arrange
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        listener.call,
        fireImmediately: true,
      );

      const filter = TasksFilter(
        selectedCategoryIds: {
          'work',
          'personal',
          'health',
          '', // unassigned
        },
      );

      // Act
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);

      await Future<void>.delayed(Duration.zero);

      // Assert
      final updatedState =
          container.read(calendarCategoryVisibilityControllerProvider);
      expect(updatedState, {'work', 'personal', 'health', ''});
    });

    test('reacts to multiple settings updates', () async {
      // Arrange
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        listener.call,
        fireImmediately: true,
      );

      // First update
      const filter1 = TasksFilter(selectedCategoryIds: {'category-a'});
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter1),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(calendarCategoryVisibilityControllerProvider),
        {'category-a'},
      );

      // Second update
      const filter2 = TasksFilter(selectedCategoryIds: {'category-b'});
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter2),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(calendarCategoryVisibilityControllerProvider),
        {'category-b'},
      );

      // Third update - clear selection
      const filter3 = TasksFilter(selectedCategoryIds: {});
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter3),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(calendarCategoryVisibilityControllerProvider),
        isEmpty,
      );
    });
  });

  group('isCategoryVisible', () {
    test('empty set means all categories are visible', () {
      // Act & Assert
      final controller =
          container.read(calendarCategoryVisibilityControllerProvider.notifier);

      // With empty state (default)
      expect(controller.isCategoryVisible('any-category'), isTrue);
      expect(controller.isCategoryVisible('another-category'), isTrue);
      expect(controller.isCategoryVisible(null), isTrue);
      expect(controller.isCategoryVisible(''), isTrue);
    });

    test('returns true for selected categories', () async {
      // Arrange
      const filter = TasksFilter(
        selectedCategoryIds: {'selected-1', 'selected-2'},
      );
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      final controller =
          container.read(calendarCategoryVisibilityControllerProvider.notifier);

      // Act & Assert
      expect(controller.isCategoryVisible('selected-1'), isTrue);
      expect(controller.isCategoryVisible('selected-2'), isTrue);
    });

    test('returns false for unselected categories', () async {
      // Arrange - first trigger the provider to start listening
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );

      const filter = TasksFilter(
        selectedCategoryIds: {'selected-category'},
      );
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);
      // Allow async stream to process
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final controller =
          container.read(calendarCategoryVisibilityControllerProvider.notifier);

      // Act & Assert
      expect(controller.isCategoryVisible('unselected-category'), isFalse);
      expect(controller.isCategoryVisible('another-hidden'), isFalse);
    });

    test('handles unassigned entries (null categoryId)', () async {
      // Arrange - first trigger the provider to start listening
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );

      const filterWithUnassigned = TasksFilter(
        selectedCategoryIds: {'category-1', ''},
      );
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filterWithUnassigned),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final controller =
          container.read(calendarCategoryVisibilityControllerProvider.notifier);

      // Act & Assert
      expect(controller.isCategoryVisible(null), isTrue);
      expect(controller.isCategoryVisible(''), isTrue);
      expect(controller.isCategoryVisible('category-1'), isTrue);
      expect(controller.isCategoryVisible('category-2'), isFalse);
    });

    test('handles unassigned entries when not in selection', () async {
      // Arrange - first trigger the provider to start listening
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );

      const filterWithoutUnassigned = TasksFilter(
        selectedCategoryIds: {'category-1'},
      );
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filterWithoutUnassigned),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final controller =
          container.read(calendarCategoryVisibilityControllerProvider.notifier);

      // Act & Assert - unassigned should not be visible
      expect(controller.isCategoryVisible(null), isFalse);
      expect(controller.isCategoryVisible(''), isFalse);
      expect(controller.isCategoryVisible('category-1'), isTrue);
    });

    test('handles empty string categoryId same as null', () async {
      // Arrange
      const filter = TasksFilter(selectedCategoryIds: {'category-a', ''});
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      final controller =
          container.read(calendarCategoryVisibilityControllerProvider.notifier);

      // Both null and empty string should be treated as unassigned
      expect(controller.isCategoryVisible(null), isTrue);
      expect(controller.isCategoryVisible(''), isTrue);
    });
  });

  group('Provider lifecycle', () {
    test('keeps alive and maintains state', () async {
      // Arrange - first trigger the provider to start listening
      container.listen(
        calendarCategoryVisibilityControllerProvider,
        (_, __) {},
        fireImmediately: true,
      );

      const filter = TasksFilter(selectedCategoryIds: {'persistent'});
      settingsStreamController.add([
        SettingsItem(
          configKey: 'TASKS_CATEGORY_FILTERS',
          value: jsonEncode(filter),
          updatedAt: DateTime(2024),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // First read
      final state1 =
          container.read(calendarCategoryVisibilityControllerProvider);
      expect(state1, {'persistent'});

      // Second read should return same state
      final state2 =
          container.read(calendarCategoryVisibilityControllerProvider);
      expect(state2, {'persistent'});
    });
  });
}
