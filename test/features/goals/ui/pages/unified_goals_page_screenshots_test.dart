/// Deterministic design-review captures of the Goals list
/// (`UnifiedGoalsPage`): three goals over penguin-world habits with one habit
/// in no goal, the first-run invitation, and a failed first load — at phone
/// and desktop widths, dark and light.
///
/// PNGs are written to `LOTTI_SCREENSHOT_DIR`, or `screenshots/goals_list`
/// when only `LOTTI_CAPTURE_SCREENSHOTS=true` is set. Run with:
///
/// ```sh
/// LOTTI_SCREENSHOT_DIR=/tmp/lotti-goals-list \
///   fvm flutter test \
///   test/features/goals/ui/pages/unified_goals_page_screenshots_test.dart
/// ```
library;

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/pages/unified_goals_page.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';
import '../../../habits/test_utils.dart';

const _subdir = 'goals_list';

/// A Saturday afternoon, the card suite's week.
final _now = DateTime(2026, 8, 15, 14);

/// Penguin-world habits, built from the shared test habit.
HabitDefinition _habit(String id, String name) =>
    habitFlossing.copyWith(id: id, name: name);

final HabitDefinition _swim = _habit('habit-swim', 'Swim before breakfast');
final HabitDefinition _stretch = _habit(
  'habit-stretch',
  'Stretch on the ice shelf',
);
final HabitDefinition _read = _habit('habit-read', 'Read to the chicks');
final HabitDefinition _krill = _habit('habit-krill', 'Log the krill catch');

/// The goals on the page: id, title, status, the habit it claims, its week.
final _goals = <(String, String, GoalTrackStatus, HabitDefinition, int)>[
  ('goal-swim', 'Swim before breakfast', GoalTrackStatus.onTrack, _swim, 5),
  (
    'goal-stretch',
    'Stretch three times a week',
    GoalTrackStatus.atRisk,
    _stretch,
    1,
  ),
  ('goal-read', 'Read every evening', GoalTrackStatus.offTrack, _read, 0),
];

AgentIdentityEntity _identity(String id, String name) =>
    AgentDomainEntity.agent(
          id: id,
          agentId: id,
          kind: AgentKinds.goalAgent,
          displayName: name,
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: '$id:state',
          config: const AgentConfig(),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          vectorClock: null,
        )
        as AgentIdentityEntity;

GoalSpecVersionEntity _spec(String agentId, String title, String habitId) =>
    AgentDomainEntity.goalSpecVersion(
          id: '$agentId:spec-v1',
          agentId: agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: title,
          statement: title,
          criteria: GoalCriterion.habit(
            criterionId: 'c1',
            habitId: habitId,
            window: const GoalWindow.rollingDays(count: 7),
            targetCount: 4,
          ),
          createdAt: DateTime(2026),
          vectorClock: null,
        )
        as GoalSpecVersionEntity;

/// A week with [done] successful days, the most recent ones first.
GoalProgressView _progress(HabitDefinition habit, int done) {
  final today = DateTime.utc(2026, 8, 15);
  return GoalProgressView(
    today: today,
    habits: [
      GoalHabitProgressView(
        habitId: habit.id,
        criterionId: 'c1',
        name: habit.name,
        targetCount: 4,
        days: [
          for (var i = 0; i < 7; i++)
            GoalProgressDay(
              day: today.subtract(Duration(days: 6 - i)),
              value: i >= 7 - done ? 1 : 0,
              targetSatisfied: i >= 7 - done,
            ),
        ],
        successfulWeeks: 0,
        evaluatedSuccesses: done,
      ),
    ],
  );
}

class _FakeHeatmapController extends HabitHeatmapController {
  @override
  HabitHeatmapData build() => const HabitHeatmapData(
    days: [],
    hasHabits: true,
    isLoading: false,
    streaksByHabit: {'habit-swim': 5},
  );

  @override
  Future<void> refreshNow() async {}
}

enum _Face { goals, empty, loadFailed }

Future<void> _capture(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  required _Face face,
  required String name,
  Locale? locale,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  applyScreenshotDevice(tester, device);
  final habits = [_swim, _stretch, _read, _krill];
  final state = HabitsState.initial().copyWith(
    habitDefinitions: habits,
    openNowAll: [_stretch, _read, _krill],
    completedAll: [_swim],
    successfulToday: {_swim.id},
    completedToday: {_swim.id},
    successfulByDay: {
      '2026-08-15': {_swim.id},
    },
  );
  final goals = face == _Face.goals
      ? _goals
      : const <(String, String, GoalTrackStatus, HabitDefinition, int)>[];
  final overrides = <Override>[
    habitsControllerProvider.overrideWith(() => FakeHabitsController(state)),
    habitsNowProvider.overrideWithValue(() => _now),
    habitHeatmapControllerProvider.overrideWith(_FakeHeatmapController.new),
    firstDayOfWeekIndexProvider.overrideWith((ref) => 1),
    if (face == _Face.loadFailed)
      activeGoalAgentsProvider.overrideWith(
        (ref) async => throw StateError('agent database unavailable'),
      )
    else
      activeGoalAgentsProvider.overrideWith(
        (ref) async => [
          for (final (id, title, _, _, _) in goals) _identity(id, title),
        ],
      ),
    dormantGoalAgentsProvider.overrideWith((ref) async => []),
    for (final (id, title, status, habit, done) in goals) ...[
      goalAgentHealthProvider(id).overrideWith(
        (ref) async => (
          trackStatus: status,
          attainment: null,
          reportOneLiner: null,
          pendingProposals: 0,
          spec: _spec(id, title, habit.id),
          direction: null,
          deficit: status == GoalTrackStatus.atRisk ? 2 : null,
          buffer: null,
        ),
      ),
      goalAgentProgressViewProvider(
        id,
      ).overrideWith((ref) async => _progress(habit, done)),
      goalAssessmentHistoryProvider(id).overrideWith((ref) async => []),
    ],
  ];

  await tester.pumpWidget(
    RepaintBoundary(
      key: screenshotBoundaryKey,
      child: makeTestableWidgetNoScroll(
        const UnifiedGoalsPage(),
        theme: brightness == Brightness.dark
            ? DesignSystemTheme.dark()
            : DesignSystemTheme.light(),
        mediaQueryData: MediaQueryData(size: device.size),
        locale: locale,
        overrides: overrides,
      ),
    ),
  );
  await settleFrames(tester, 30);
  await captureScreenshot(tester, name, subdir: _subdir);
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'goals-list screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  final cache = MockEntitiesCacheService();
  setUpAll(loadScreenshotFonts);
  setUp(() {
    for (final habit in [_swim, _stretch, _read, _krill]) {
      when(() => cache.getHabitById(habit.id)).thenReturn(habit);
    }
    getIt
      ..registerSingleton<EntitiesCacheService>(cache)
      ..registerSingleton<UserActivityService>(UserActivityService());
  });
  tearDown(getIt.reset);

  for (final device in [proDevice, desktopDevice]) {
    final viewport = device.isPhone ? 'mobile' : 'desktop';
    for (final brightness in [Brightness.dark, Brightness.light]) {
      final theme = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('$viewport goals list — $theme', (tester) async {
        await _capture(
          tester,
          device: device,
          brightness: brightness,
          face: _Face.goals,
          name: 'goals_list_${viewport}_$theme',
        );
      });
    }
    testWidgets('$viewport goals list — dark, German', (tester) async {
      await _capture(
        tester,
        device: device,
        brightness: Brightness.dark,
        face: _Face.goals,
        name: 'goals_list_${viewport}_dark_de',
        locale: const Locale('de'),
      );
    });
    testWidgets('$viewport goals list empty — dark', (tester) async {
      await _capture(
        tester,
        device: device,
        brightness: Brightness.dark,
        face: _Face.empty,
        name: 'goals_list_empty_${viewport}_dark',
      );
    });
    testWidgets('$viewport goals list, load failed — dark', (tester) async {
      await _capture(
        tester,
        device: device,
        brightness: Brightness.dark,
        face: _Face.loadFailed,
        name: 'goals_list_load_failed_${viewport}_dark',
      );
    });
  }
}
