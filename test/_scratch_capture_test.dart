import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';
import 'test_utils/screenshot_harness.dart';
import 'widget_test_utils.dart';

class _FixedStateController extends HabitsController {
  _FixedStateController(this._state);
  final HabitsState _state;
  @override
  HabitsState build() => _state;
}

HabitDefinition _habit(String id, String name) => HabitDefinition(
  id: id,
  name: name,
  description: '',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  vectorClock: null,
  habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  active: true,
  private: false,
);

HabitsState _demoState() {
  final h1 = _habit('h1', 'Meditation');
  final h2 = _habit('h2', 'Flossing');
  final h3 = _habit('h3', 'Reading');
  final h4 = _habit('h4', 'Exercise');
  final ids = {h1.id, h2.id, h3.id, h4.id};

  final days = [
    for (var d = 1; d <= 30; d++) '2024-03-${d.toString().padLeft(2, '0')}',
  ];

  final successfulByDay = <String, Set<String>>{};
  for (var i = 0; i < days.length; i++) {
    final kept = <String>{};
    if (i >= 2) kept.add(h2.id); // flossing settles in early
    if (i % 3 != 0) kept.add(h3.id); // reading misses every third day
    if (i >= 22) kept.add(h4.id); // exercise returns strong in the last week
    if (i % 7 == 0) kept.add(h1.id); // meditation: the laggard
    successfulByDay[days[i]] = kept;
  }

  return HabitsState.initial().copyWith(
    days: days,
    timeSpanDays: 30,
    habitDefinitions: [h1, h2, h3, h4],
    allByDay: {for (final day in days) day: ids},
    successfulByDay: successfulByDay,
    minY: 30,
  );
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    final nav = MockNavService();
    when(() => nav.habitsIndex).thenReturn(3);
    when(() => nav.index).thenReturn(3);
    when(nav.getIndexStream).thenAnswer((_) => const Stream<int>.empty());
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<NavService>(nav),
    );
  });
  tearDown(tearDownTestGetIt);

  testWidgets('capture habits chart card', (tester) async {
    await captureInApp(
      tester,
      name: 'chart_panel_v2',
      size: const Size(820, 380),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: dsPageSurface(context),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                shrinkWrap: true,
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: HabitsChartCard(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      overrides: [
        habitsControllerProvider.overrideWith(
          () => _FixedStateController(_demoState()),
        ),
      ],
    );
  });
}
