/// Deterministic design-review captures for the task-agent summary card.
///
/// The same interaction states are rendered at desktop and phone widths
/// in dark and light mode. This matrix is intentionally reused for baseline,
/// iteration, and final captures so expert-panel comparisons judge the same
/// content, viewport, and state every time.
///
/// Beyond the core matrix it also renders the states that stress the card's
/// bottom section: the narrowest supported phone, German at large text scale,
/// a report written by a different route than the current setup (two identity
/// lines), and the two hover states — driven with a real mouse pointer,
/// because `tester.tap` never fires `InkWell.onHover`.
///
/// PNGs are written to `LOTTI_SCREENSHOT_DIR`. When only
/// `LOTTI_CAPTURE_SCREENSHOTS=true` is set, they are written to
/// `screenshots/task_agent_card`. Point `LOTTI_SCREENSHOT_DIR` at a fresh
/// directory per review round so a panel agent cannot read stale pixels. Run
/// with:
///
/// ```sh
/// LOTTI_SCREENSHOT_DIR=/tmp/lotti-task-agent-card-screenshots/round1 \
///   fvm flutter test \
///   test/features/agents/ui/ai_summary_card/screenshots_test.dart
/// ```
library;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

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

/// The narrowest phone the card still has to work on. Below `mini` (375) this
/// is where the footer's controls genuinely run out of room.
///
/// Width is the only layout-relevant dimension; the viewport is deliberately
/// taller than any real 320px handset because a capture clipped mid-footer
/// gives a review panel nothing to judge. Real phones scroll — reviewers
/// cannot.
const _narrowDevice = ScreenshotDevice('narrow', Size(320, 1120), 2);

const _summary =
    'New task created from audio dictation about making task agent auto-wake '
    'optional to reduce token consumption. Eight checklist items cover the '
    'redesign workflow from implementation to PR merge. Active phase: '
    'Planning and design.';

/// The live setup: a realistically long model/publisher/provider identity, so
/// the footer's identity row is measured against the strings users actually
/// see rather than a short test stub.
final _thinkingProvider = AiConfigInferenceProvider(
  id: 'provider-melious',
  baseUrl: 'https://example.invalid',
  apiKey: 'test-key',
  name: 'Melious.ai',
  createdAt: _now,
  inferenceProviderType: InferenceProviderType.melious,
);

final _thinkingModel = AiConfigModel(
  id: 'model-qwen-35-plus',
  name: 'Qwen 3.5 Plus',
  providerModelId: 'qwen3.5-plus',
  inferenceProviderId: _thinkingProvider.id,
  createdAt: _now,
  inputModalities: const [Modality.text],
  outputModalities: const [Modality.text],
  isReasoningModel: true,
  publisher: 'Alibaba',
);

final _resolvedSetup = ResolvedAgentSetup(
  status: AgentSetupResolutionStatus.resolved,
  profile: ResolvedProfile(
    thinkingModelId: _thinkingModel.providerModelId,
    thinkingProvider: _thinkingProvider,
    thinkingModel: _thinkingModel,
  ),
  source: AgentSetupResolutionSource.baseProfile,
);

/// The route that wrote an older report — deliberately different from
/// [_resolvedSetup] so the identity region splits into two lines.
const _priorRoute = InferenceRouteSnapshot(
  providerModelId: 'glm-5.2',
  modelName: 'GLM 5.2',
  publisherName: 'Z.ai',
  servingProviderType: InferenceProviderType.openRouter,
  servingProviderName: 'OpenRouter',
  runtimeSettings: {},
);

/// Which interaction state the capture renders.
enum _Mode { manual, scheduled, running, proposals }

/// Which element the mouse rests on, if any.
enum _Hover { none, modelRow, header }

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

AgentReportEntity _report({bool priorRoute = false}) => makeTestReport(
  createdAt: _now.subtract(const Duration(minutes: 4)),
  tldr: _summary,
  content:
      '$_summary\n\n## Current focus\n\n'
      'The agent is coordinating implementation, documentation, review, and '
      'release preparation.',
  provenance: ReportInferenceProvenance(
    runKey: 'run-baseline',
    threadId: 'thread-baseline',
    executor: priorRoute
        ? _priorRoute
        : InferenceRouteSnapshot.fromResolvedProfile(_resolvedSetup.profile!),
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

/// Rests a real mouse pointer on [target] and lets the ink overlay settle.
/// A synthetic tap does not produce a hover state — only a
/// [PointerDeviceKind.mouse] gesture does.
Future<void> _hoverOver(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  await settleFrames(tester, 6);
}

Future<void> _capture(
  WidgetTester tester, {
  required ScreenshotDevice device,
  required Brightness brightness,
  required _Mode mode,
  _Hover hover = _Hover.none,
  bool priorReportRoute = false,
  Locale? locale,
  TextScaler textScaler = TextScaler.noScaling,
  String? nameSuffix,
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
  final automaticUpdates = mode == _Mode.scheduled || mode == _Mode.running;
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
          report: _report(priorRoute: priorReportRoute),
          suggestions: _suggestions(withOpen: mode == _Mode.proposals),
          state: state,
          identity: identity,
          template: _template(),
          resolvedSetup: _resolvedSetup,
          enableSummaryTts: true,
          isRunning: mode == _Mode.running,
          mediaQueryData: MediaQueryData(
            size: device.size,
            textScaler: textScaler,
          ),
          locale: locale,
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

    switch (hover) {
      case _Hover.none:
        break;
      case _Hover.modelRow:
        await _hoverOver(tester, find.byIcon(LottiIcons.reasoning));
      case _Hover.header:
        await _hoverOver(tester, find.byIcon(LottiIcons.aiSpark));
    }
  });

  // Guard the fixture itself: a capture of the wrong content is worse than no
  // capture, because a review panel scores it as if it were real. The chrome
  // strings are only asserted in the default locale.
  expect(find.text(_summary), findsOneWidget);
  if (locale == null) {
    expect(find.text('AI summary'), findsOneWidget);
    expect(find.text('Task Laura'), findsOneWidget);
  }

  final theme = brightness == Brightness.dark ? 'dark' : 'light';
  final suffix = nameSuffix == null ? '' : '_$nameSuffix';
  await captureScreenshot(
    tester,
    '${device.name}_${mode.name}${suffix}_$theme',
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

  // Core matrix: every interaction state at every width, both themes.
  for (final device in [desktopDevice, proDevice, miniDevice]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      for (final mode in _Mode.values) {
        final theme = brightness == Brightness.dark ? 'dark' : 'light';
        testWidgets('${device.name} ${mode.name} $theme', (tester) async {
          await _capture(
            tester,
            device: device,
            brightness: brightness,
            mode: mode,
          );
        });
      }
    }
  }

  // The states that stress the card's bottom section specifically. Dark only
  // (the theme axis is already covered above) except where contrast is part
  // of what is being judged.
  group('footer stress states', () {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      final theme = brightness == Brightness.dark ? 'dark' : 'light';

      // 320px: the footer's controls have the least room here.
      for (final mode in [_Mode.manual, _Mode.scheduled]) {
        testWidgets('narrow ${mode.name} $theme', (tester) async {
          await _capture(
            tester,
            device: _narrowDevice,
            brightness: brightness,
            mode: mode,
          );
        });
      }

      // German at 1.3x: every footer label roughly doubles in length while
      // the row height grows — the worst realistic single-line pressure.
      testWidgets('pro scheduled german $theme', (tester) async {
        await _capture(
          tester,
          device: proDevice,
          brightness: brightness,
          mode: _Mode.scheduled,
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.3),
          nameSuffix: 'german',
        );
      });

      testWidgets('narrow scheduled german $theme', (tester) async {
        await _capture(
          tester,
          device: _narrowDevice,
          brightness: brightness,
          mode: _Mode.scheduled,
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.3),
          nameSuffix: 'german',
        );
      });

      // A report written by a route the agent no longer uses: the identity
      // region splits into a second attribution line.
      for (final device in [desktopDevice, _narrowDevice]) {
        testWidgets('${device.name} manual split $theme', (tester) async {
          await _capture(
            tester,
            device: device,
            brightness: brightness,
            mode: _Mode.manual,
            priorReportRoute: true,
            nameSuffix: 'split',
          );
        });
      }
    }

    // Hover: dark only — the state layer's extent, not its hue, is the
    // subject.
    for (final entry in {
      'model': _Hover.modelRow,
      'header': _Hover.header,
    }.entries) {
      testWidgets('desktop manual hover ${entry.key} dark', (tester) async {
        await _capture(
          tester,
          device: desktopDevice,
          brightness: Brightness.dark,
          mode: _Mode.manual,
          hover: entry.value,
          nameSuffix: 'hover-${entry.key}',
        );
      });
    }
  });
}
