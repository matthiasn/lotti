import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/daily_os_next/ui/pages/drafting_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/reconcile_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_glass_action_bar.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_thinking_shader.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../widget_test_utils.dart';

/// Minimal capture controller that pins a fixed [CaptureState] so the modal
/// renders deterministically without the recorder/transcription stack.
class _FakeCaptureController extends CaptureController {
  _FakeCaptureController(this._initial);

  final CaptureState _initial;

  @override
  CaptureState build() => _initial;

  @override
  void reset() => state = const CaptureState.idle();

  @override
  void startTyping() => state = const CaptureState(
    phase: CapturePhase.captured,
    transcript: '',
    amplitudes: [],
  );

  @override
  Future<void> toggle() async {}
}

/// Reconcile agent whose parse step throws — drives the error branch.
class _ThrowingReconcileAgent extends MockDayAgent {
  _ThrowingReconcileAgent()
    : super(parseLatency: Duration.zero, pendingLatency: Duration.zero);

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    throw StateError('parse failed');
  }
}

/// Drafting agent whose draft step throws — drives the error branch.
class _ThrowingDraftAgent extends MockDayAgent {
  _ThrowingDraftAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async {
    throw StateError('draft failed');
  }
}

/// Drafting agent whose draft never resolves (a never-completing
/// [Completer], so no pending timer) — keeps the Drafting step on screen in
/// its "drafting" phase for a stable assertion.
class _PendingDraftAgent extends MockDayAgent {
  _PendingDraftAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        summarizeLatency: Duration.zero,
      );

  final Completer<DraftPlan> _draft = Completer<DraftPlan>();

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) => _draft.future;
}

MockDayAgent _fastAgent() => MockDayAgent(
  parseLatency: Duration.zero,
  pendingLatency: Duration.zero,
  triageLatency: Duration.zero,
  draftLatency: Duration.zero,
  summarizeLatency: Duration.zero,
  clock: () => DateTime(2024, 3, 15, 9),
);

const _captured = CaptureState(
  phase: CapturePhase.captured,
  transcript: 'Plan tomorrow morning',
  amplitudes: [],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _openCreate(
  WidgetTester tester, {
  CaptureState capture = const CaptureState.idle(),
  MockDayAgent? agent,
  Size size = const Size(420, 900),
}) async {
  await tester.pumpWidget(
    makeTestableWidget(
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showDayPlanningModal(
              context: context,
              dayDate: DateTime(2024, 3, 15),
              intent: const DayPlanningCreate(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(size: size),
      overrides: [
        captureControllerProvider.overrideWith(
          () => _FakeCaptureController(capture),
        ),
        if (agent != null) dayAgentProvider.overrideWithValue(agent),
      ],
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byType(DayPlanningGlassActionBar)),
)!;

Future<void> _tapPill(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(DsGlassPill, label));
  await _settle(tester);
}

void main() {
  group('showDayPlanningModal — capture step', () {
    testWidgets('opens the Capture step with a glass action bar + shader', (
      tester,
    ) async {
      await _openCreate(tester);
      expect(find.byType(CaptureModalContent), findsOneWidget);
      expect(find.byType(DayPlanningGlassActionBar), findsOneWidget);
      expect(find.byType(DayPlanningThinkingShader), findsOneWidget);
    });

    testWidgets('idle bar offers only the "type instead" action', (
      tester,
    ) async {
      await _openCreate(tester);
      expect(find.byType(DsGlassPill), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    testWidgets('captured bar offers re-record + continue', (tester) async {
      await _openCreate(tester, capture: _captured);
      expect(find.byType(DsGlassPill), findsNWidgets(2));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('listening bar shows no action pills and no shader', (
      tester,
    ) async {
      await _openCreate(
        tester,
        capture: const CaptureState(
          phase: CapturePhase.listening,
          transcript: '',
          amplitudes: [],
        ),
      );
      expect(find.byType(DsGlassPill), findsNothing);
      expect(find.byKey(DayPlanningThinkingShader.indicatorKey), findsNothing);
    });

    testWidgets('transcribing bar lights the thinking shader', (tester) async {
      await _openCreate(
        tester,
        capture: const CaptureState(
          phase: CapturePhase.transcribing,
          transcript: '',
          amplitudes: [],
        ),
      );
      expect(find.byType(DsGlassPill), findsNothing);
      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsOneWidget,
      );
    });

    testWidgets('error bar offers the "type instead" fallback', (tester) async {
      await _openCreate(
        tester,
        capture: const CaptureState(
          phase: CapturePhase.error,
          transcript: '',
          amplitudes: [],
          error: CaptureError.noAudioRecorded,
        ),
      );
      expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);
    });

    testWidgets('"type instead" flips capture into the captured editor', (
      tester,
    ) async {
      await _openCreate(tester);
      await tester.tap(find.byIcon(Icons.keyboard_rounded));
      await tester.pump();
      expect(find.byType(DsGlassPill), findsNWidgets(2));
    });
  });

  group('showDayPlanningModal — create chain', () {
    testWidgets('continue advances Capture → Reconcile', (tester) async {
      await _openCreate(tester, capture: _captured, agent: _fastAgent());
      final messages = _l10n(tester);
      await _tapPill(tester, messages.dailyOsNextCaptureReconcileCta);
      expect(find.byType(ReconcileModalContent), findsOneWidget);
    });

    testWidgets('build day advances Reconcile → Drafting with the shader', (
      tester,
    ) async {
      await _openCreate(
        tester,
        capture: _captured,
        agent: _PendingDraftAgent(),
      );
      final messages = _l10n(tester);
      await _tapPill(tester, messages.dailyOsNextCaptureReconcileCta);
      await _tapPill(tester, messages.dailyOsNextReconcileBuildDayCta);
      expect(find.byType(DraftingModalContent), findsOneWidget);
      expect(
        find.byKey(DayPlanningThinkingShader.indicatorKey),
        findsOneWidget,
      );
    });

    testWidgets('drafting ready closes the modal', (tester) async {
      await _openCreate(tester, capture: _captured, agent: _fastAgent());
      final messages = _l10n(tester);
      await _tapPill(tester, messages.dailyOsNextCaptureReconcileCta);
      await _tapPill(tester, messages.dailyOsNextReconcileBuildDayCta);
      await _settle(tester);
      // The whole modal layer is gone once drafting is ready.
      expect(find.byType(DayPlanningGlassActionBar), findsNothing);
      expect(find.byType(DraftingModalContent), findsNothing);
      expect(find.byType(ReconcileModalContent), findsNothing);
    });

    testWidgets('reconcile re-record steps back to capture', (tester) async {
      await _openCreate(tester, capture: _captured, agent: _fastAgent());
      final messages = _l10n(tester);
      await _tapPill(tester, messages.dailyOsNextCaptureReconcileCta);
      expect(find.byType(ReconcileModalContent), findsOneWidget);
      await _tapPill(tester, messages.dailyOsNextReconcileReRecord);
      expect(find.byType(CaptureModalContent), findsOneWidget);
    });

    testWidgets('reconcile surfaces an error when parsing fails', (
      tester,
    ) async {
      await _openCreate(
        tester,
        capture: _captured,
        agent: _ThrowingReconcileAgent(),
      );
      final messages = _l10n(tester);
      await _tapPill(tester, messages.dailyOsNextCaptureReconcileCta);
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
    });

    testWidgets('drafting surfaces an error when the draft fails', (
      tester,
    ) async {
      await _openCreate(
        tester,
        capture: _captured,
        agent: _ThrowingDraftAgent(),
      );
      final messages = _l10n(tester);
      await _tapPill(tester, messages.dailyOsNextCaptureReconcileCta);
      await _tapPill(tester, messages.dailyOsNextReconcileBuildDayCta);
      expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
    });
  });

  group('showDayPlanningModal — adapt (refine)', () {
    testWidgets('opens the Refine step with its title, body and glass bar', (
      tester,
    ) async {
      final draft = DraftPlan.emptyForDay(DateTime(2024, 3, 15));
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDayPlanningModal(
                  context: context,
                  dayDate: draft.dayDate,
                  intent: DayPlanningAdapt(draft),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(420, 900)),
          overrides: [
            captureControllerProvider.overrideWith(
              () => _FakeCaptureController(const CaptureState.idle()),
            ),
            dayAgentProvider.overrideWithValue(_fastAgent()),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final messages = _l10n(tester);
      expect(find.byType(RefineModalContent), findsOneWidget);
      expect(find.byType(DayPlanningGlassActionBar), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineTitle), findsWidgets);
    });
  });

  group('showDayPlanningModal — responsive', () {
    testWidgets('renders as a dialog on wide viewports', (tester) async {
      await _openCreate(tester, size: const Size(1280, 900));
      expect(find.byType(CaptureModalContent), findsOneWidget);
      expect(find.byType(DayPlanningGlassActionBar), findsOneWidget);
    });
  });
}
