/// Deterministic design-review captures for the unified goal card: one card
/// per track status, with the companion on (her bust and the mood each
/// status gives her) and off (the persona monogram), at phone and desktop
/// widths, dark and light.
///
/// PNGs are written to `LOTTI_SCREENSHOT_DIR`, or `screenshots/goal_card`
/// when only `LOTTI_CAPTURE_SCREENSHOTS=true` is set. Run with:
///
/// ```sh
/// LOTTI_SCREENSHOT_DIR=/tmp/lotti-goal-card-screenshots \
///   fvm flutter test \
///   test/features/goals/ui/unified/goal_card_screenshots_test.dart
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../daily_os_next/screenshot_harness.dart';

const _subdir = 'goal_card';

/// One goal per status the companion's mood distinguishes.
const _goals = <(String, String, GoalTrackStatus)>[
  ('goal-on-track', 'Swim before breakfast', GoalTrackStatus.onTrack),
  ('goal-recovering', 'Read every evening', GoalTrackStatus.recovering),
  ('goal-at-risk', 'Stretch three times a week', GoalTrackStatus.atRisk),
  ('goal-off-track', 'Fish market budget', GoalTrackStatus.offTrack),
  ('goal-no-data', 'Learn to sketch', GoalTrackStatus.insufficientData),
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

GoalSpecVersionEntity _spec(String agentId, String title) =>
    AgentDomainEntity.goalSpecVersion(
          id: '$agentId:spec-v1',
          agentId: agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: title,
          statement: title,
          criteria: GoalCriterion.allOf(
            criterionId: 'root',
            criteria: [
              GoalCriterion.habit(
                criterionId: 'c1',
                habitId: '$agentId:habit',
                window: const GoalWindow.rollingDays(count: 7),
                targetCount: 4,
              ),
            ],
          ),
          createdAt: DateTime(2026),
          vectorClock: null,
        )
        as GoalSpecVersionEntity;

/// A week whose marks match the status, so the strip agrees with her face.
List<DayMarkState> _week(GoalTrackStatus status) => switch (status) {
  GoalTrackStatus.onTrack || GoalTrackStatus.achieved => const [
    DayMarkState.full,
    DayMarkState.full,
    DayMarkState.none,
    DayMarkState.full,
    DayMarkState.full,
    DayMarkState.none,
    DayMarkState.full,
  ],
  GoalTrackStatus.recovering => const [
    DayMarkState.missed,
    DayMarkState.missed,
    DayMarkState.none,
    DayMarkState.full,
    DayMarkState.partial,
    DayMarkState.full,
    DayMarkState.full,
  ],
  GoalTrackStatus.atRisk => const [
    DayMarkState.full,
    DayMarkState.none,
    DayMarkState.none,
    DayMarkState.partial,
    DayMarkState.none,
    DayMarkState.missed,
    DayMarkState.none,
  ],
  GoalTrackStatus.offTrack => const [
    DayMarkState.missed,
    DayMarkState.none,
    DayMarkState.missed,
    DayMarkState.none,
    DayMarkState.missed,
    DayMarkState.none,
    DayMarkState.missed,
  ],
  GoalTrackStatus.insufficientData => const [
    DayMarkState.none,
    DayMarkState.none,
    DayMarkState.none,
    DayMarkState.none,
    DayMarkState.none,
    DayMarkState.none,
    DayMarkState.none,
  ],
};

/// A progress view whose compact window is [week].
GoalProgressView _progress(String agentId, List<DayMarkState> week) {
  final today = DateTime.utc(2026, 8, 15);
  return GoalProgressView(
    today: today,
    habits: [
      GoalHabitProgressView(
        habitId: '$agentId:habit',
        name: 'Habit',
        targetCount: 4,
        days: [
          for (var i = 0; i < week.length; i++)
            GoalProgressDay(
              day: today.subtract(Duration(days: week.length - 1 - i)),
              value: switch (week[i]) {
                DayMarkState.full => 1,
                DayMarkState.partial => 0.5,
                _ => 0,
              },
              isObserved: week[i] != DayMarkState.none,
              targetSatisfied: week[i] == DayMarkState.full,
            ),
        ],
        successfulWeeks: 0,
        evaluatedSuccesses: week.where((d) => d == DayMarkState.full).length,
      ),
    ],
  );
}

Future<void> _capture(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  required bool companion,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  applyScreenshotDevice(tester, device);
  final isDesktop = !device.isPhone;
  await tester.pumpWidget(
    RepaintBoundary(
      key: screenshotBoundaryKey,
      child: makeTestableWidgetWithScaffold(
        Padding(
          padding: isDesktop
              ? const EdgeInsets.all(40)
              : const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              // The unified Goals surfaces' content measure on desktop.
              width: isDesktop ? 760 : device.size.width - 24,
              child: Column(
                children: [
                  for (final (id, title, _) in _goals) ...[
                    UnifiedGoalCard(identity: _identity(id, title)),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
        theme: brightness == Brightness.dark
            ? DesignSystemTheme.dark()
            : DesignSystemTheme.light(),
        mediaQueryData: MediaQueryData(size: device.size),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flagName) =>
                Stream.value(companion && flagName == enableCompanionFlag),
          ),
          for (final (id, title, status) in _goals) ...[
            goalAgentHealthProvider(id).overrideWith(
              (ref) async => (
                trackStatus: status,
                attainment: null,
                reportOneLiner: null,
                pendingProposals: 0,
                spec: _spec(id, title),
                direction: null,
                deficit: status == GoalTrackStatus.atRisk ? 2 : null,
                buffer: null,
              ),
            ),
            goalAgentProgressViewProvider(
              id,
            ).overrideWith((ref) async => _progress(id, _week(status))),
            goalAssessmentHistoryProvider(id).overrideWith((ref) async => []),
          ],
        ],
      ),
    ),
  );
  // Her mood springs in over the first frames; give it time to land.
  await settleFrames(tester, 30);

  final theme = brightness == Brightness.dark ? 'dark' : 'light';
  await captureScreenshot(
    tester,
    '${device.name}_${companion ? 'companion' : 'monogram'}_$theme',
    subdir: _subdir,
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'goal-card screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);
  setUp(() {
    getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
  });
  tearDown(getIt.reset);

  for (final device in [desktopDevice, proDevice]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      for (final companion in [false, true]) {
        final theme = brightness == Brightness.dark ? 'dark' : 'light';
        final face = companion ? 'companion' : 'monogram';
        testWidgets('${device.name} $face $theme', (tester) async {
          await _capture(
            tester,
            device: device,
            brightness: brightness,
            companion: companion,
          );
        });
      }
    }
  }
}
