import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockUpdateNotifications = MockUpdateNotifications();
    definitionsController = StreamController.broadcast();
    updateController = StreamController.broadcast();

    when(
      () => mockJournalDb.getHabitCompletionsInRange(
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => []);

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateController.stream);

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([
      categoryMindfulness,
    ]);

    when(() => mockEntitiesCacheService.getCategoryById(any())).thenReturn(
      categoryMindfulness,
    );

    // Per-test GetIt scope, popped in tearDown.
    getIt
      ..pushNewScope()
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() async {
    await definitionsController.close();
    await updateController.close();
    await getIt.popScope();
  });

  Future<void> pumpFilter(
    WidgetTester tester,
    HabitsController Function() controller,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const HabitsFilter(),
        overrides: [habitsControllerProvider.overrideWith(controller)],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('HabitsFilter', () {
    testWidgets('renders an outlined filter icon when nothing is selected', (
      tester,
    ) async {
      await pumpFilter(tester, _WithHabitsController.new);

      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.filter_alt), findsNothing);
    });

    testWidgets('renders a filled filter icon when categories are selected', (
      tester,
    ) async {
      await pumpFilter(tester, _SelectedController.new);

      expect(find.byIcon(Icons.filter_alt), findsOneWidget);
      expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    });

    testWidgets('opens the deferred category picker when tapped', (
      tester,
    ) async {
      await pumpFilter(tester, _WithHabitsController.new);

      await tester.tap(find.byKey(const Key('habit_category_filter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The unified picker is shown with the category row.
      expect(find.byType(CategoryPickerSheet), findsOneWidget);
      expect(find.text(categoryMindfulness.name), findsOneWidget);
    });

    testWidgets('commits the selected categories on Apply', (tester) async {
      _TrackingController.lastSetCategoryIds = null;

      await pumpFilter(tester, _TrackingController.new);

      // Open the picker.
      await tester.tap(find.byKey(const Key('habit_category_filter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Stage the category, then commit via Apply.
      await tester.tap(find.text(categoryMindfulness.name));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('category-picker-apply')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Nothing was committed until Apply, and Apply set the whole staged set.
      expect(
        _TrackingController.lastSetCategoryIds,
        {categoryMindfulness.id},
      );
    });
  });
}

class _WithHabitsController extends HabitsController {
  @override
  HabitsState build() {
    return HabitsState.initial().copyWith(
      openNow: [habitFlossing],
      habitDefinitions: [habitFlossing],
    );
  }
}

class _SelectedController extends HabitsController {
  @override
  HabitsState build() {
    return HabitsState.initial().copyWith(
      openNow: [habitFlossing],
      habitDefinitions: [habitFlossing],
      selectedCategoryIds: {categoryMindfulness.id},
    );
  }
}

/// Controller that records the committed category set for testing.
class _TrackingController extends HabitsController {
  static Set<String>? lastSetCategoryIds;

  @override
  HabitsState build() {
    return HabitsState.initial().copyWith(
      openNow: [habitFlossing],
      habitDefinitions: [habitFlossing],
    );
  }

  @override
  void setSelectedCategoryIds(Set<String> categoryIds) {
    lastSetCategoryIds = categoryIds;
  }
}
