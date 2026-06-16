import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_filter.dart';
import 'package:lotti/features/habits/ui/widgets/habits_header.dart';
import 'package:lotti/features/habits/ui/widgets/habits_tool_button.dart';
import 'package:lotti/features/habits/ui/widgets/status_segmented_control.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntitiesCacheService mockEntitiesCacheService;

  setUp(() async {
    await setUpTestGetIt();
    mockEntitiesCacheService = MockEntitiesCacheService();
    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(null);
    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(tearDownTestGetIt);

  /// Pumps [HabitsHeader] with a [FakeHabitsController] serving [state] and
  /// returns the fake so tests can inspect recorded mutation calls.
  Future<FakeHabitsController> pumpHeader(
    WidgetTester tester, {
    required HabitsState state,
  }) async {
    final fake = FakeHabitsController(state);
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const HabitsHeader(),
        overrides: [
          habitsControllerProvider.overrideWith(() => fake),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return fake;
  }

  HabitsState stateWith({
    bool showSearch = false,
    HabitDisplayFilter displayFilter = HabitDisplayFilter.openNow,
  }) => HabitsState.initial().copyWith(
    showSearch: showSearch,
    displayFilter: displayFilter,
  );

  testWidgets('renders the Habits title', (tester) async {
    await pumpHeader(tester, state: stateWith());

    expect(find.text('Habits'), findsOneWidget);
  });

  testWidgets('tapping the search tool button invokes toggleShowSearch', (
    tester,
  ) async {
    final fake = await pumpHeader(tester, state: stateWith());

    expect(fake.toggleShowSearchCalls, 0);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.toggleShowSearchCalls, 1);
  });

  Future<void> expectSearchButtonActive(
    WidgetTester tester, {
    required bool showSearch,
  }) async {
    await pumpHeader(tester, state: stateWith(showSearch: showSearch));

    final button = tester.widget<HabitsToolButton>(
      find.byType(HabitsToolButton),
    );
    expect(button.active, showSearch);
    expect(button.icon, Icons.search);
  }

  testWidgets('search tool button is active when state.showSearch is true', (
    tester,
  ) async {
    await expectSearchButtonActive(tester, showSearch: true);
  });

  testWidgets('search tool button is inactive when state.showSearch is false', (
    tester,
  ) async {
    await expectSearchButtonActive(tester, showSearch: false);
  });

  testWidgets('renders the four status segments', (tester) async {
    await pumpHeader(tester, state: stateWith());

    expect(find.byType(HabitStatusSegmentedControl), findsOneWidget);
    // Each segment label is rendered twice (a hidden width-reserving ghost
    // plus the visible label), so each resolves to two Text widgets.
    for (final label in ['due', 'later', 'done', 'all']) {
      expect(find.text(label), findsNWidgets(2));
    }
  });

  testWidgets('tapping a status segment records the matching display filter', (
    tester,
  ) async {
    final fake = await pumpHeader(tester, state: stateWith());

    expect(fake.displayFilterCalls, isEmpty);

    // Tap the visible "done" segment via its InkWell ancestor.
    await tester.tap(
      find
          .ancestor(of: find.text('done'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.displayFilterCalls, [HabitDisplayFilter.completed]);
  });

  testWidgets('renders the category filter button', (tester) async {
    await pumpHeader(tester, state: stateWith());

    expect(find.byType(HabitsFilter), findsOneWidget);
    expect(find.byKey(const Key('habit_category_filter')), findsOneWidget);
  });
}
