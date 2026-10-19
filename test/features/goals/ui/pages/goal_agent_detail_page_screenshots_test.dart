/// Deterministic design-review captures of the goal agent's page, framed on
/// its hero "Agent's read" card: a goal at risk with a stale report, at phone
/// and desktop widths, dark and light, with the companion on and off.
///
/// PNGs are written to `LOTTI_SCREENSHOT_DIR`, or
/// `screenshots/goal_agent_detail` when only `LOTTI_CAPTURE_SCREENSHOTS=true`
/// is set. Run with:
///
/// ```sh
/// LOTTI_SCREENSHOT_DIR=/tmp/lotti-goal-agent-screenshots \
///   fvm flutter test \
///   test/features/goals/ui/pages/goal_agent_detail_page_screenshots_test.dart
/// ```
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../companion/companion_overrides.dart';
import '../../../daily_os_next/screenshot_harness.dart';
import '../../../habits/test_utils.dart';
import '../../../tts/test_utils.dart';

const _subdir = 'goal_agent_detail';
final _now = DateTime(2026, 8, 16, 18);
const _agentId = 'goal-1';

const _tldr =
    'Two of four stretching sessions this week, and the weekend is still '
    'open. One more session by Sunday keeps the goal on its feet.';

final _identity =
    AgentDomainEntity.agent(
          id: _agentId,
          agentId: _agentId,
          kind: AgentKinds.goalAgent,
          displayName: 'Stretch coach',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: '$_agentId:state',
          config: const AgentConfig(),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          vectorClock: null,
        )
        as AgentIdentityEntity;

final _spec =
    AgentDomainEntity.goalSpecVersion(
          id: '$_agentId:spec-v1',
          agentId: _agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: 'Stretch three times a week',
          statement: 'Stretch three times a week.',
          criteria: const GoalCriterion.habit(
            criterionId: 'c1',
            habitId: 'habit-stretch',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
          createdAt: DateTime(2026),
          vectorClock: null,
        )
        as GoalSpecVersionEntity;

Future<void> _capture(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  required bool companion,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  applyScreenshotDevice(tester, device);
  final report = makeTestReport(
    agentId: _agentId,
    createdAt: _now.subtract(const Duration(hours: 3)),
    tldr: _tldr,
    content: '$_tldr\n\n## Next step\n\nA short session on Saturday morning.',
  );
  final state = makeTestState(
    agentId: _agentId,
    updatedAt: _now,
  ).copyWith(reportStaleAt: _now.subtract(const Duration(minutes: 30)));

  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotBoundaryKey,
        child: makeTestableWidgetNoScroll(
          const GoalAgentDetailPage(agentId: _agentId),
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          mediaQueryData: MediaQueryData(size: device.size),
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(switch (flagName) {
                enableCompanionFlag => companion,
                enableAiSummaryTtsFlag => true,
                _ => false,
              }),
            ),
            ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
            spokenTrackLoaderProvider.overrideWithValue(
              (clip, text) async => throw StateError('no voice in captures'),
            ),
            // Her everyday outfit, not the session's random one.
            ...companionLookOverrides(),
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(
                HabitsState.initial(now: DateTime(2026, 8, 16)),
              ),
            ),
            agentIdentityProvider(
              _agentId,
            ).overrideWith((ref) async => _identity),
            goalAgentHealthProvider(_agentId).overrideWith(
              (ref) async => (
                trackStatus: GoalTrackStatus.atRisk,
                attainment: 0.66,
                reportOneLiner: 'Two of three sessions so far.',
                pendingProposals: 0,
                spec: _spec,
                direction: null,
                deficit: 1,
                buffer: null,
              ),
            ),
            selfTargetedPendingChangeSetsProvider(
              _agentId,
            ).overrideWith((ref) async => []),
            agentMessagesByThreadProvider(
              _agentId,
            ).overrideWith((ref) async => {}),
            agentReportProvider(_agentId).overrideWith((ref) async => report),
            agentStateProvider(_agentId).overrideWith((ref) async => state),
          ],
        ),
      ),
    );
    // She never settles: pump frames by hand.
    await settleFrames(tester, 20);
  });

  final theme = brightness == Brightness.dark ? 'dark' : 'light';
  await captureScreenshot(
    tester,
    '${device.name}_${companion ? 'companion' : 'badge'}_$theme',
    subdir: _subdir,
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'goal-agent-detail screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  for (final device in [desktopDevice, proDevice]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      for (final companion in [false, true]) {
        final theme = brightness == Brightness.dark ? 'dark' : 'light';
        final face = companion ? 'companion' : 'badge';
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
