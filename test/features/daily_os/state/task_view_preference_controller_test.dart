import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os/state/task_view_preference_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsDb extends Mock implements SettingsDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockSettingsDb mockSettingsDb;

  setUp(() {
    mockSettingsDb = MockSettingsDb();

    getIt.allowReassignment = true;
    getIt.registerSingleton<SettingsDb>(mockSettingsDb);

    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  group('TaskViewPreference', () {
    test('defaults to list mode when no stored preference', () async {
      when(() => mockSettingsDb.itemByKey('time_budget_view_cat-1'))
          .thenAnswer((_) async => null);

      final result = await container.read(
        taskViewPreferenceProvider(categoryId: 'cat-1').future,
      );

      expect(result, equals(TaskViewMode.list));
    });

    test('returns list mode when stored as "list"', () async {
      when(() => mockSettingsDb.itemByKey('time_budget_view_cat-1'))
          .thenAnswer((_) async => 'list');

      final result = await container.read(
        taskViewPreferenceProvider(categoryId: 'cat-1').future,
      );

      expect(result, equals(TaskViewMode.list));
    });

    test('returns grid mode when stored as "grid"', () async {
      when(() => mockSettingsDb.itemByKey('time_budget_view_cat-1'))
          .thenAnswer((_) async => 'grid');

      final result = await container.read(
        taskViewPreferenceProvider(categoryId: 'cat-1').future,
      );

      expect(result, equals(TaskViewMode.grid));
    });

    test('toggle switches from list to grid and persists', () async {
      when(() => mockSettingsDb.itemByKey('time_budget_view_cat-1'))
          .thenAnswer((_) async => null);
      when(
        () => mockSettingsDb.saveSettingsItem(
          'time_budget_view_cat-1',
          'grid',
        ),
      ).thenAnswer((_) async => 1);

      // Get initial state
      await container.read(
        taskViewPreferenceProvider(categoryId: 'cat-1').future,
      );

      // Toggle
      await container
          .read(taskViewPreferenceProvider(categoryId: 'cat-1').notifier)
          .toggle();

      final state =
          container.read(taskViewPreferenceProvider(categoryId: 'cat-1'));

      expect(state.value, equals(TaskViewMode.grid));
      verify(
        () => mockSettingsDb.saveSettingsItem(
          'time_budget_view_cat-1',
          'grid',
        ),
      ).called(1);
    });

    test('toggle switches from grid to list and persists', () async {
      when(() => mockSettingsDb.itemByKey('time_budget_view_cat-1'))
          .thenAnswer((_) async => 'grid');
      when(
        () => mockSettingsDb.saveSettingsItem(
          'time_budget_view_cat-1',
          'list',
        ),
      ).thenAnswer((_) async => 1);

      // Get initial state
      await container.read(
        taskViewPreferenceProvider(categoryId: 'cat-1').future,
      );

      // Toggle
      await container
          .read(taskViewPreferenceProvider(categoryId: 'cat-1').notifier)
          .toggle();

      final state =
          container.read(taskViewPreferenceProvider(categoryId: 'cat-1'));

      expect(state.value, equals(TaskViewMode.list));
      verify(
        () => mockSettingsDb.saveSettingsItem(
          'time_budget_view_cat-1',
          'list',
        ),
      ).called(1);
    });

    test('different categories have independent preferences', () async {
      when(() => mockSettingsDb.itemByKey('time_budget_view_cat-1'))
          .thenAnswer((_) async => 'grid');
      when(() => mockSettingsDb.itemByKey('time_budget_view_cat-2'))
          .thenAnswer((_) async => 'list');

      final result1 = await container.read(
        taskViewPreferenceProvider(categoryId: 'cat-1').future,
      );
      final result2 = await container.read(
        taskViewPreferenceProvider(categoryId: 'cat-2').future,
      );

      expect(result1, equals(TaskViewMode.grid));
      expect(result2, equals(TaskViewMode.list));
    });
  });
}
