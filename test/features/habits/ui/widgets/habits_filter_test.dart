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
import 'package:pie_chart/pie_chart.dart';

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
    testWidgets('renders filter icon when no habits', (tester) async {
      await pumpFilter(tester, _EmptyController.new);

      expect(find.byIcon(Icons.filter_alt_off_outlined), findsOneWidget);
    });

    testWidgets('renders pie chart when habits have categories', (
      tester,
    ) async {
      await pumpFilter(tester, _WithHabitsController.new);

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
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

class _EmptyController extends HabitsController {
  @override
  HabitsState build() {
    return HabitsState.initial();
  }
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
