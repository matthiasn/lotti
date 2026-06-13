import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_category.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNotificationService mockNotificationService;

  setUpAll(() {
    registerFallbackValue(FakeHabitDefinition());
  });

  setUp(() {
    mockJournalDb = mockJournalDbWithHabits([habitFlossing]);
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNotificationService = MockNotificationService();

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn(
      [categoryMindfulness],
    );

    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(null);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<NotificationService>(mockNotificationService);
  });

  tearDown(getIt.reset);

  testWidgets('shows the selected category name in the field', (tester) async {
    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(categoryMindfulness);

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectCategoryWidget(habitId: habitFlossing.id),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The field renders the resolved category's name, not just any text box.
    expect(find.byType(SettingsPickerField), findsOneWidget);
    expect(find.text(categoryMindfulness.name), findsOneWidget);
  });

  testWidgets(
    'selecting a category in the modal updates the habit settings state',
    (tester) async {
      when(
        () => mockEntitiesCacheService.getCategoryById(categoryMindfulness.id),
      ).thenReturn(categoryMindfulness);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WidgetTestBench(
            child: SelectCategoryWidget(habitId: habitFlossing.id),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open the modal and pick the category.
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsPickerField),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final categoryFinder = find.text(categoryMindfulness.name);
      expect(categoryFinder, findsWidgets);
      await tester.tap(categoryFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The selection landed in the controller state (dirty + categoryId).
      final state = container.read(
        habitSettingsControllerProvider(habitFlossing.id),
      );
      expect(state.dirty, isTrue);
      expect(state.habitDefinition.categoryId, categoryMindfulness.id);
    },
  );
}
