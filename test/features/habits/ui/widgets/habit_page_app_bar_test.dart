import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habit_page_app_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  late FakeHabitsController controller;

  setUp(() {
    // HabitsFilter (embedded in the app bar) reads categories from GetIt.
    final mockEntitiesCacheService = MockEntitiesCacheService();
    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
    getIt
      ..pushNewScope()
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(() async {
    await getIt.popScope();
  });

  Future<void> pumpAppBar(WidgetTester tester, HabitsState state) async {
    // ProviderScope overrides are fixed at state creation: tear the old
    // tree down first so re-pumps with a new controller take effect.
    await tester.pumpWidget(const SizedBox.shrink());
    controller = FakeHabitsController(state);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(
          body: CustomScrollView(
            slivers: [HabitsSliverAppBar()],
          ),
        ),
        overrides: [
          habitsControllerProvider.overrideWith(() => controller),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('search and time-span toggles invoke the controller', (
    tester,
  ) async {
    await pumpAppBar(tester, HabitsState.initial());

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    expect(controller.toggleShowSearchCalls, 1);

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pump();
    expect(controller.toggleShowTimeSpanCalls, 1);
  });

  testWidgets('zero-baseline toggle only renders when minY > 20', (
    tester,
  ) async {
    // minY at the boundary: hidden.
    await pumpAppBar(tester, HabitsState.initial().copyWith(minY: 20));
    expect(find.byIcon(MdiIcons.unfoldLessHorizontal), findsNothing);
    expect(find.byIcon(MdiIcons.unfoldMoreHorizontal), findsNothing);

    // Above the threshold with zeroBased=true: the "unfold less" icon shows
    // and tapping it calls toggleZeroBased.
    await pumpAppBar(tester, HabitsState.initial().copyWith(minY: 21));
    final toggle = find.byIcon(MdiIcons.unfoldLessHorizontal);
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(controller.toggleZeroBasedCalls, 1);

    // zeroBased=false renders the "unfold more" variant.
    await pumpAppBar(
      tester,
      HabitsState.initial().copyWith(minY: 21, zeroBased: false),
    );
    expect(find.byIcon(MdiIcons.unfoldMoreHorizontal), findsOneWidget);
  });

  testWidgets('segmented filter control forwards selection changes', (
    tester,
  ) async {
    await pumpAppBar(tester, HabitsState.initial());

    await tester.tap(find.text('all'));
    await tester.pump();

    expect(controller.displayFilterCalls, [HabitDisplayFilter.all]);
  });
}
