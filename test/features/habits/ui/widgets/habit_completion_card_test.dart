import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);

  final fixedNow = DateTime(2026, 5, 22);
  final rangeStart = fixedNow.subtract(const Duration(days: 13));
  final rangeEnd = fixedNow;

  late MockEntitiesCacheService mockEntitiesCache;
  late MockPersistenceLogic mockPersistence;

  HabitDefinition makeHabit({
    String id = 'habit-1',
    String name = 'Audio Journal',
    bool? priority,
    String categoryId = 'cat-1',
  }) {
    return HabitDefinition(
      id: id,
      name: name,
      description: '',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      private: false,
      active: true,
      activeFrom: DateTime(2024),
      categoryId: categoryId,
      habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      priority: priority,
    );
  }

  CategoryDefinition makeCategory({
    String id = 'cat-1',
    String name = 'Reflection',
  }) {
    return CategoryDefinition(
      id: id,
      name: name,
      private: false,
      active: true,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
    );
  }

  List<HabitResult> buildResults({
    int days = 14,
    HabitCompletionType Function(int i)? completionFor,
  }) {
    return List<HabitResult>.generate(days, (i) {
      final day = rangeStart.add(Duration(days: i));
      final ymd =
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      return HabitResult(
        dayString: ymd,
        completionType: completionFor?.call(i) ?? HabitCompletionType.open,
      );
    });
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required List<HabitResult> results,
    HabitDefinition? habit,
    CategoryDefinition? category,
  }) async {
    final h = habit ?? makeHabit();
    when(() => mockEntitiesCache.getHabitById(h.id)).thenReturn(h);
    when(
      () => mockEntitiesCache.getCategoryById(h.categoryId),
    ).thenReturn(category);

    await tester.pumpWidget(
      makeTestableWidget(
        HabitCompletionCard(
          habitId: h.id,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
        overrides: [
          habitCompletionControllerProvider(
            habitId: h.id,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ).overrideWith(() => _StubHabitCompletionController(results)),
        ],
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    mockEntitiesCache = MockEntitiesCacheService();
    mockPersistence = MockPersistenceLogic();

    when(
      () => mockPersistence.createHabitCompletionEntry(
        data: any(named: 'data'),
        habitDefinition: any(named: 'habitDefinition'),
        linkedId: any(named: 'linkedId'),
        comment: any(named: 'comment'),
      ),
    ).thenAnswer((_) async => null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCache)
          ..registerSingleton<PersistenceLogic>(mockPersistence);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('renders habit name, category, and last-week count', (
    tester,
  ) async {
    final habit = makeHabit();
    final category = makeCategory();
    final results = buildResults(
      completionFor: (i) =>
          i >= 7 ? HabitCompletionType.success : HabitCompletionType.open,
    );

    await pumpCard(
      tester,
      results: results,
      habit: habit,
      category: category,
    );

    expect(find.text('Audio Journal'), findsOneWidget);
    expect(find.text('Reflection'), findsOneWidget);
    // 7 successes in the last 7 days -> "7/7 last week"
    expect(find.text('7/7 last week'), findsOneWidget);
  });

  testWidgets('shows priority star only when habit.priority == true', (
    tester,
  ) async {
    final habit = makeHabit(priority: true);
    await pumpCard(
      tester,
      results: buildResults(),
      habit: habit,
      category: makeCategory(),
    );

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('hides priority star when habit.priority is null/false', (
    tester,
  ) async {
    await pumpCard(
      tester,
      results: buildResults(),
      category: makeCategory(),
    );

    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('renders streak text when trailing successes exist', (
    tester,
  ) async {
    final results = buildResults(
      completionFor: (i) =>
          i >= 11 ? HabitCompletionType.success : HabitCompletionType.open,
    );

    await pumpCard(
      tester,
      results: results,
      category: makeCategory(),
    );

    expect(find.text('3-day streak'), findsOneWidget);
  });

  testWidgets('does not render streak when last entry is not success', (
    tester,
  ) async {
    final results = buildResults(
      completionFor: (i) =>
          i == 12 ? HabitCompletionType.success : HabitCompletionType.open,
    );

    await pumpCard(
      tester,
      results: results,
      category: makeCategory(),
    );

    expect(find.textContaining('streak'), findsNothing);
  });

  testWidgets('tapping success quick-action records a success completion', (
    tester,
  ) async {
    final habit = makeHabit();
    await pumpCard(
      tester,
      results: buildResults(),
      habit: habit,
      category: makeCategory(),
    );

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();

    final captured =
        verify(
              () => mockPersistence.createHabitCompletionEntry(
                data: captureAny(named: 'data'),
                habitDefinition: any(named: 'habitDefinition'),
                linkedId: any(named: 'linkedId'),
                comment: any(named: 'comment'),
              ),
            ).captured.single
            as HabitCompletionData;

    expect(captured.habitId, habit.id);
    expect(captured.completionType, HabitCompletionType.success);
  });

  testWidgets('tapping skip quick-action records a skip completion', (
    tester,
  ) async {
    final habit = makeHabit();
    await pumpCard(
      tester,
      results: buildResults(),
      habit: habit,
      category: makeCategory(),
    );

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right_rounded));
    await tester.pump();

    final captured =
        verify(
              () => mockPersistence.createHabitCompletionEntry(
                data: captureAny(named: 'data'),
                habitDefinition: any(named: 'habitDefinition'),
                linkedId: any(named: 'linkedId'),
                comment: any(named: 'comment'),
              ),
            ).captured.single
            as HabitCompletionData;

    expect(captured.completionType, HabitCompletionType.skip);
  });

  testWidgets('tapping fail quick-action records a fail completion', (
    tester,
  ) async {
    final habit = makeHabit();
    await pumpCard(
      tester,
      results: buildResults(),
      habit: habit,
      category: makeCategory(),
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    final captured =
        verify(
              () => mockPersistence.createHabitCompletionEntry(
                data: captureAny(named: 'data'),
                habitDefinition: any(named: 'habitDefinition'),
                linkedId: any(named: 'linkedId'),
                comment: any(named: 'comment'),
              ),
            ).captured.single
            as HabitCompletionData;

    expect(captured.completionType, HabitCompletionType.fail);
  });

  testWidgets('does nothing when habit definition is missing', (tester) async {
    when(() => mockEntitiesCache.getHabitById(any())).thenReturn(null);
    when(() => mockEntitiesCache.getCategoryById(any())).thenReturn(null);

    await tester.pumpWidget(
      makeTestableWidget(
        HabitCompletionCard(
          habitId: 'missing-id',
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Material), findsNothing);
  });
}

class _StubHabitCompletionController extends HabitCompletionController {
  _StubHabitCompletionController(this._results);

  final List<HabitResult> _results;

  @override
  Future<List<HabitResult>> build({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    return _results;
  }
}
