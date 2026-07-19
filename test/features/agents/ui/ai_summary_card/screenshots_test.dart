/// Deterministic design-review captures for the task-agent summary card.
///
/// The same interaction states are rendered at desktop and phone widths
/// in dark and light mode. This matrix is intentionally reused for baseline,
/// iteration, and final captures so expert-panel comparisons judge the same
/// content, viewport, and state every time.
///
/// PNGs are written to `LOTTI_SCREENSHOT_DIR`. When only
/// `LOTTI_CAPTURE_SCREENSHOTS=true` is set, they are written to
/// `screenshots/task_agent_card`. Run with:
///
/// ```sh
/// LOTTI_SCREENSHOT_DIR=/tmp/lotti-task-agent-card-screenshots \
///   fvm flutter test \
///   test/features/agents/ui/ai_summary_card/screenshots_test.dart
/// ```
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../daily_os_next/screenshot_harness.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

const _subdir = 'task_agent_card';
final _now = DateTime(2026, 7, 16, 21);

// Production centers task content in a 760px column with 15px horizontal
// insets (`TaskDetailsPage`), leaving a 730px card. Keep desktop captures at
// that real rendered width instead of stretching the card across the whole
// screenshot device and creating layout artifacts users never see.
const _desktopCardWidth = 730.0;

const _summary =
    'New task created from audio dictation about making task agent auto-wake '
    'optional to reduce token consumption. Eight checklist items cover the '
    'redesign workflow from implementation to PR merge. Active phase: '
    'Planning and design.';

AgentTemplateEntity _template() =>
    AgentDomainEntity.agentTemplate(
          id: 'template-laura',
          agentId: 'template-laura',
          displayName: 'Task Laura',
          kind: AgentTemplateKind.taskAgent,
          modelId: 'qwen-3.5-397b-a17b',
          categoryIds: const {},
          createdAt: _now,
          updatedAt: _now,
          vectorClock: null,
        )
        as AgentTemplateEntity;

AgentReportEntity _report() => makeTestReport(
  createdAt: _now.subtract(const Duration(minutes: 4)),
  tldr: _summary,
  content:
      '$_summary\n\n## Current focus\n\n'
      'The agent is coordinating implementation, documentation, review, and '
      'release preparation.',
  provenance: ReportInferenceProvenance(
    runKey: 'run-baseline',
    threadId: 'thread-baseline',
    executor: InferenceRouteSnapshot.fromResolvedProfile(
      defaultResolvedSetup.profile!,
    ),
    finalContentAuthor: ReportContentAuthor.executor,
  ).toReportMap(),
);

UnifiedSuggestionList _suggestions({bool withOpen = false}) =>
    UnifiedSuggestionList(
      open: withOpen
          ? [
              makePending(
                id: 'p-timer',
                toolName: 'set_running_timer_text',
                humanSummary:
                    'running timer text: "Continuing card polish — focusing '
                    'on proposal rows after the footer restructure."',
              ),
              makePending(
                id: 'p-check',
                toolName: 'add_checklist_item',
                humanSummary:
                    'Add: "Re-rate the card with the expert panel after the '
                    'proposal-row polish."',
              ),
            ]
          : const [],
      activity: [
        for (var index = 0; index < 11; index++)
          makeLedgerEntry(
            id: 'history-$index',
            status: index.isEven
                ? ChangeItemStatus.confirmed
                : ChangeItemStatus.rejected,
          ),
      ],
      agentName: 'Task Laura',
    );

Future<void> _capture(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  required bool automaticUpdates,
  bool withOpenProposals = false,
  bool running = false,
}) async {
  // The toggle and entrance widgets are stateful. Explicitly unmount the
  // previous fixture before applying the next viewport so sequential matrix
  // captures cannot retain a prior visual state in the shared test binding.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  applyScreenshotDevice(tester, device);
  final isDesktop = !device.isPhone;
  final padding = isDesktop
      ? const EdgeInsets.all(40)
      : const EdgeInsets.fromLTRB(12, 16, 12, 12);
  final identity = makeTestIdentity(
    displayName: 'Task Laura',
    config: AgentConfig(automaticUpdatesEnabled: automaticUpdates),
  );
  final state =
      makeTestState(
        updatedAt: _now,
        lastWakeAt: _now.subtract(const Duration(minutes: 4)),
        nextWakeAt: automaticUpdates
            ? _now.add(const Duration(minutes: 1, seconds: 30))
            : null,
      ).copyWith(
        reportStaleAt: automaticUpdates
            ? null
            : _now.subtract(const Duration(minutes: 1)),
        reportFreshAt: automaticUpdates
            ? _now.subtract(const Duration(minutes: 4))
            : _now.subtract(const Duration(minutes: 5)),
      );

  await withClock(Clock.fixed(_now), () async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotBoundaryKey,
        child: AgentTestBench(
          report: _report(),
          suggestions: _suggestions(withOpen: withOpenProposals),
          state: state,
          identity: identity,
          template: _template(),
          enableSummaryTts: true,
          isRunning: running,
          mediaQueryData: MediaQueryData(size: device.size),
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          surfaceConstraints: BoxConstraints.tight(device.size),
          padding: padding,
          width: isDesktop ? _desktopCardWidth : device.size.width - 24,
        ).build(),
      ),
    );
    await settleFrames(tester);
  });

  expect(find.text('AI summary'), findsOneWidget);
  expect(find.text('Task Laura'), findsOneWidget);
  expect(find.text(_summary), findsOneWidget);

  final mode = running
      ? 'running'
      : withOpenProposals
      ? 'proposals'
      : automaticUpdates
      ? 'scheduled'
      : 'manual';
  final theme = brightness == Brightness.dark ? 'dark' : 'light';
  await captureScreenshot(
    tester,
    '${device.name}_${mode}_$theme',
    subdir: _subdir,
  );
}

void main() {
  if (!screenshotCaptureEnabled) {
    test(
      'task-agent-card screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true).',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  for (final device in [desktopDevice, proDevice, miniDevice]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      for (final automaticUpdates in [true, false]) {
        final theme = brightness == Brightness.dark ? 'dark' : 'light';
        final mode = automaticUpdates ? 'scheduled' : 'manual';
        testWidgets('${device.name} $mode $theme', (tester) async {
          await _capture(
            tester,
            device: device,
            brightness: brightness,
            automaticUpdates: automaticUpdates,
          );
        });
      }
      final theme = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('${device.name} running $theme', (tester) async {
        await _capture(
          tester,
          device: device,
          brightness: brightness,
          automaticUpdates: true,
          running: true,
        );
      });
      // The real-world hot path: automation off, stale report, and open
      // proposals awaiting review — exercises the proposal rows the other
      // states leave empty.
      testWidgets('${device.name} proposals $theme', (tester) async {
        await _capture(
          tester,
          device: device,
          brightness: brightness,
          automaticUpdates: false,
          withOpenProposals: true,
        );
      });
    }
  }
}
