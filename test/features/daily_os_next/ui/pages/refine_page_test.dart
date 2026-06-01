// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/refine_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/diff_row.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

const _category = DayAgentCategory(
  id: 'cat_focus',
  name: 'Focus',
  colorHex: '0080FF',
);

DraftPlan _emptyPlan() => DraftPlan(
  dayDate: DateTime(2026, 5, 26),
  blocks: const [],
  bands: const [],
  capacityMinutes: 240,
  scheduledMinutes: 0,
);

PlanDiff _diffWithTwoChanges(DraftPlan plan) => PlanDiff(
  id: 'diff_1',
  transcript: 'move focus later and add review',
  changes: const [
    PlanDiffChange(
      id: 'chg_move',
      kind: PlanDiffChangeKind.moved,
      title: 'Move focus block',
      category: _category,
      reason: 'pushes deep work past the standup',
      affectedBlockId: 'blk_1',
    ),
    PlanDiffChange(
      id: 'chg_add',
      kind: PlanDiffChangeKind.added,
      title: 'Add review slot',
      category: _category,
      reason: 'adds a 30-minute wrap-up',
      affectedBlockId: 'blk_2',
    ),
  ],
  updatedPlan: plan,
);

/// Recording agent: returns canned diff/plan responses and remembers
/// the args the controller passed in so tests can assert on them.
class _RecordingAgent implements DayAgentInterface {
  _RecordingAgent({
    required this.diff,
    DraftPlan? acceptedPlan,
    this.proposeError,
    this.proposeGate,
  }) : acceptedPlan = acceptedPlan ?? diff.updatedPlan;

  final PlanDiff diff;
  final DraftPlan acceptedPlan;
  final Error? proposeError;

  /// When set, `proposePlanDiff` blocks on this future before returning,
  /// keeping the refine controller pinned in `RefinePhase.thinking` so
  /// tests can observe that transient phase.
  final Future<void>? proposeGate;

  PlanDiff? capturedDiff;
  String? proposedTranscript;
  List<int>? acceptIndices;
  List<int>? revertIndices;
  DraftPlan? revertOriginalPlan;
  int proposeCount = 0;

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
    bool Function()? isCancelled,
  }) async {
    proposeCount++;
    proposedTranscript = voiceTranscript;
    final gate = proposeGate;
    if (gate != null) await gate;
    final error = proposeError;
    if (error != null) throw error;
    return diff;
  }

  @override
  Future<DraftPlan> acceptDiff(
    PlanDiff diff, {
    List<int>? itemIndices,
  }) async {
    capturedDiff = diff;
    acceptIndices = itemIndices;
    return acceptedPlan;
  }

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
    List<int>? itemIndices,
  }) async {
    capturedDiff = diff;
    revertIndices = itemIndices;
    revertOriginalPlan = originalPlan;
    return originalPlan;
  }

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async => const CaptureId('cap');

  @override
  Future<DraftPlan?> currentPlanForDate(DateTime date) async => null;

  @override
  Future<bool> deletePlanForDate(DateTime date) async => true;

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async => const [];

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async => const [];

  @override
  Future<ParsedItem> breakCaptureLink(String parsedItemId) async =>
      throw UnimplementedError();

  @override
  Future<TriageResult> applyTriage({
    required String taskId,
    required TriageAction action,
    DateTime? deferTo,
  }) async => TriageResult(taskId: taskId, action: action);

  @override
  Future<DraftPlan> draftDayPlan({
    required CaptureId captureId,
    required List<String> decidedTaskIds,
    required DateTime dayDate,
    List<String> decidedCaptureItemIds = const [],
    List<TimeBlock> calendarBlocks = const [],
    bool Function()? isCancelled,
  }) async => _emptyPlan();

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async => const [];

  @override
  Future<DraftPlan> commitDay(DraftPlan plan) async =>
      plan.copyWith(state: DayState.committed);

  @override
  Future<
    ({
      List<CompletedItem> completed,
      List<CarryoverItem> carryover,
      ShutdownMetrics metrics,
    })
  >
  surfaceShutdownData({required DateTime forDate}) async => (
    completed: const <CompletedItem>[],
    carryover: const <CarryoverItem>[],
    metrics: const ShutdownMetrics(
      focusMinutes: 0,
      flowSessions: 0,
      contextSwitches: 0,
      contextSwitchesWeekAvg: 0,
      energyScore: 0,
      energyDeltaVsWeek: 0,
    ),
  );

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {}

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {}

  @override
  Future<TomorrowNote> generateTomorrowNote({
    required DateTime forDate,
  }) async => const TomorrowNote(body: '', maturity: 1);

  @override
  Future<List<TaskCorpusItem>> surfaceTaskCorpus({
    TaskCorpusState stateFilter = TaskCorpusState.all,
    String? categoryId,
    String? query,
  }) async => const [];
}

/// Stub the realtime/transcriber/recorder so the auto-disposing
/// CaptureController can build and clean up without touching mic, fs,
/// or the AI providers (which would otherwise read Ref during dispose
/// and explode the test).
CaptureController _stubCapture() {
  final recorder = MockAudioRecorderRepository();
  final transcriber = MockAudioTranscriptionService();
  final realtime = MockRealtimeTranscriptionService();
  when(realtime.dispose).thenAnswer((_) async {});
  when(realtime.resolveRealtimeConfig).thenAnswer((_) async => null);
  when(recorder.stopRecording).thenAnswer((_) async {});
  // Permission denied → toggle() lands the controller in CapturePhase.error
  // synchronously enough for tests to observe the resulting refine state.
  when(recorder.hasPermission).thenAnswer((_) async => false);
  return CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    realtimeService: realtime,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => null,
    now: () => DateTime(2026, 5, 26, 9),
  );
}

/// Capture controller that lets tests push arbitrary [CaptureState]
/// transitions so the refine panel's `ref.listen` on
/// [captureControllerProvider] can be exercised directly, without
/// driving the real mic / realtime lifecycle.
class _DriveableCaptureController extends CaptureController {
  @override
  CaptureState build() => const CaptureState.idle();

  /// Pushes a new capture state, triggering the panel's listener.
  // ignore: use_setters_to_change_properties
  void emit(CaptureState next) => state = next;

  // The panel calls these on a voice-button tap; the driveable tests
  // never tap the button, but keep them no-ops for safety.
  @override
  void reset() {}

  @override
  void skipRealtimeTranscriptVerificationForNextCapture() {}

  @override
  Future<void> toggle() async {}
}

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  Size size = const Size(1280, 900),
  CaptureController Function()? captureFactory,
}) {
  return ProviderScope(
    overrides: [
      captureControllerProvider.overrideWith(captureFactory ?? _stubCapture),
      ...overrides,
    ],
    child: makeTestableWidget2(
      child,
      mediaQueryData: MediaQueryData(size: size),
    ),
  );
}

/// Reads the driveable capture controller for the page so tests can push
/// capture-state transitions.
_DriveableCaptureController _readCapture(WidgetTester tester) {
  final element = tester.element(find.byType(RefinePage));
  return ProviderScope.containerOf(
        element,
      ).read(captureControllerProvider.notifier)
      as _DriveableCaptureController;
}

/// Returns the controller for the page's draft so tests can drive phase
/// transitions without depending on real voice capture.
RefineController _readNotifier(WidgetTester tester, DraftPlan draft) {
  final element = tester.element(find.byType(RefinePage));
  return ProviderScope.containerOf(
    element,
  ).read(refineControllerProvider(draft).notifier);
}

void _setWideSurface(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1400, 1400)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('RefinePage', () {
    testWidgets('idle phase shows status idle, voice button, no diff rows', (
      tester,
    ) async {
      final draft = _emptyPlan();
      await tester.pumpWidget(_wrap(RefinePage(draft: draft)));
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      expect(find.text(messages.dailyOsNextRefineStatusIdle), findsOneWidget);
      expect(find.byType(VoiceButton), findsOneWidget);
      expect(find.byType(LiveWaveform), findsNothing);
      expect(find.byType(DiffRow), findsNothing);
    });

    testWidgets('listening phase renders waveform and transcript card', (
      tester,
    ) async {
      final draft = _emptyPlan();
      await tester.pumpWidget(_wrap(RefinePage(draft: draft)));
      await tester.pump();

      final notifier = _readNotifier(tester, draft);
      notifier
        ..beginListening(resetTranscript: true)
        ..updateActiveTranscript('move things later');
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      expect(find.byType(LiveWaveform), findsOneWidget);
      expect(find.text('move things later'), findsOneWidget);
      expect(
        find.text(messages.dailyOsNextRefineStatusListening),
        findsOneWidget,
      );
    });

    testWidgets(
      'reviewing phase lets user edit transcript before proposing diff',
      (tester) async {
        final draft = _emptyPlan();
        final agent = _RecordingAgent(diff: _diffWithTwoChanges(draft));
        await tester.pumpWidget(
          _wrap(
            RefinePage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        final notifier = _readNotifier(tester, draft);
        notifier.reviewTranscript('make the gym block longer');
        await tester.pump();

        const editorKey = Key('daily_os_refine_transcript_editor');
        final editor = find.byKey(editorKey);
        expect(editor, findsOneWidget);

        await tester.enterText(editor, 'make the writing block longer');
        await tester.pump();

        final messages = tester.element(find.byType(RefinePage)).messages;
        await _tap(
          tester,
          find.widgetWithText(
            FilledButton,
            messages.dailyOsNextRefineTitle,
          ),
        );

        expect(agent.proposedTranscript, 'make the writing block longer');
        expect(find.byType(DiffRow), findsNWidgets(2));
      },
    );

    testWidgets('empty proposal keeps review open and explains no changes', (
      tester,
    ) async {
      final draft = _emptyPlan();
      final agent = _RecordingAgent(
        diff: PlanDiff(
          id: 'diff_empty',
          transcript: 'make it lighter',
          changes: const [],
          updatedPlan: draft,
        ),
      );
      await tester.pumpWidget(
        _wrap(
          RefinePage(draft: draft),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      final notifier = _readNotifier(tester, draft);
      notifier.reviewTranscript('make it lighter');
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      await _tap(
        tester,
        find.widgetWithText(
          FilledButton,
          messages.dailyOsNextRefineTitle,
        ),
      );

      expect(find.byType(DiffRow), findsNothing);
      expect(find.text(messages.dailyOsNextRefineNoChanges), findsOneWidget);
      expect(
        find.byKey(const Key('daily_os_refine_transcript_editor')),
        findsOneWidget,
      );
    });

    testWidgets(
      'proposal failure keeps review open and surfaces the localized error',
      (tester) async {
        final previousOnError = FlutterError.onError;
        final reportedErrors = <FlutterErrorDetails>[];
        FlutterError.onError = reportedErrors.add;
        addTearDown(() => FlutterError.onError = previousOnError);

        final draft = _emptyPlan();
        final agent = _RecordingAgent(
          diff: _diffWithTwoChanges(draft),
          proposeError: StateError('proposal exploded'),
        );
        await tester.pumpWidget(
          _wrap(
            RefinePage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        final notifier = _readNotifier(tester, draft);
        notifier.reviewTranscript('move the workout earlier');
        await tester.pump();

        final messages = tester.element(find.byType(RefinePage)).messages;
        await _tap(
          tester,
          find.widgetWithText(
            FilledButton,
            messages.dailyOsNextRefineTitle,
          ),
        );

        expect(reportedErrors, isNotEmpty);
        expect(find.text(messages.dailyOsNextGenericError), findsOneWidget);
        expect(find.textContaining('proposal exploded'), findsNothing);
        expect(
          find.byKey(const Key('daily_os_refine_transcript_editor')),
          findsOneWidget,
        );
      },
    );

    testWidgets('diffReady renders one DiffRow per change + action buttons', (
      tester,
    ) async {
      final draft = _emptyPlan();
      final agent = _RecordingAgent(diff: _diffWithTwoChanges(draft));
      await tester.pumpWidget(
        _wrap(
          RefinePage(draft: draft),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      final notifier = _readNotifier(tester, draft);
      notifier.beginListening(resetTranscript: true);
      await notifier.finishWithTranscript('please rearrange');
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      expect(find.byType(DiffRow), findsNWidgets(2));
      expect(find.text('Move focus block'), findsOneWidget);
      expect(find.text('Add review slot'), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineRevert), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineKeepTalking), findsOneWidget);
    });

    testWidgets('tap accept on a DiffRow calls acceptDiff with that index', (
      tester,
    ) async {
      final draft = _emptyPlan();
      final agent = _RecordingAgent(diff: _diffWithTwoChanges(draft));
      await tester.pumpWidget(
        _wrap(
          RefinePage(draft: draft),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      _setWideSurface(tester);
      final notifier = _readNotifier(tester, draft);
      notifier.beginListening(resetTranscript: true);
      await notifier.finishWithTranscript('please rearrange');
      await tester.pump();

      // Second DiffRow → index 1.
      final messages = tester.element(find.byType(RefinePage)).messages;
      final acceptOnRowTwo = find
          .descendant(
            of: find.byType(DiffRow).at(1),
            matching: find.text(messages.dailyOsNextRefineAccept),
          )
          .first;
      await _tap(tester, acceptOnRowTwo);

      expect(agent.acceptIndices, [1]);
      expect(agent.capturedDiff?.id, 'diff_1');
    });

    testWidgets('tap reject on a DiffRow calls revertDiff with that index', (
      tester,
    ) async {
      final draft = _emptyPlan();
      final agent = _RecordingAgent(diff: _diffWithTwoChanges(draft));
      await tester.pumpWidget(
        _wrap(
          RefinePage(draft: draft),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      _setWideSurface(tester);
      final notifier = _readNotifier(tester, draft);
      notifier.beginListening(resetTranscript: true);
      await notifier.finishWithTranscript('please rearrange');
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      final rejectOnRowOne = find
          .descendant(
            of: find.byType(DiffRow).first,
            matching: find.text(messages.changeSetSwipeReject),
          )
          .first;
      await _tap(tester, rejectOnRowOne);

      expect(agent.revertIndices, [0]);
    });

    testWidgets(
      'tap revert action button reverts all pending indices and returns to idle',
      (tester) async {
        final draft = _emptyPlan();
        final agent = _RecordingAgent(diff: _diffWithTwoChanges(draft));
        await tester.pumpWidget(
          _wrap(
            RefinePage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();

        _setWideSurface(tester);
        final notifier = _readNotifier(tester, draft);
        notifier.beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('please rearrange');
        await tester.pump();

        final messages = tester.element(find.byType(RefinePage)).messages;
        await _tap(tester, find.text(messages.dailyOsNextRefineRevert));

        expect(agent.revertIndices, [0, 1]);
        expect(agent.revertOriginalPlan, isNotNull);
        // Action row + diff rows collapse once we're back to idle.
        expect(find.byType(DiffRow), findsNothing);
        expect(find.text(messages.dailyOsNextRefineStatusIdle), findsOneWidget);
      },
    );

    testWidgets('tap keep talking re-enters listening with prior transcript', (
      tester,
    ) async {
      final draft = _emptyPlan();
      final agent = _RecordingAgent(diff: _diffWithTwoChanges(draft));
      await tester.pumpWidget(
        _wrap(
          RefinePage(draft: draft),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      _setWideSurface(tester);
      final notifier = _readNotifier(tester, draft);
      notifier.beginListening(resetTranscript: true);
      await notifier.finishWithTranscript('move focus later');
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      await _tap(tester, find.text(messages.dailyOsNextRefineKeepTalking));

      expect(
        find.text(messages.dailyOsNextRefineStatusListening),
        findsOneWidget,
      );
      // Prior transcript preserved (visible in the transcript card).
      expect(find.text('move focus later'), findsOneWidget);
    });

    testWidgets('accepted phase pops the navigator with the current plan', (
      tester,
    ) async {
      final draft = _emptyPlan();
      final acceptedPlan = draft.copyWith(scheduledMinutes: 99);
      // Single-change diff so a single acceptChange flips the controller
      // into `accepted` without re-entering it after the page pops (which
      // would touch a disposed autoDispose provider).
      final singleChangeDiff = PlanDiff(
        id: 'diff_single',
        transcript: 't',
        changes: const [
          PlanDiffChange(
            id: 'chg_only',
            kind: PlanDiffChangeKind.moved,
            title: 'Only change',
            category: _category,
            reason: 'just one',
            affectedBlockId: 'blk_1',
          ),
        ],
        updatedPlan: acceptedPlan,
      );
      final agent = _RecordingAgent(
        diff: singleChangeDiff,
        acceptedPlan: acceptedPlan,
      );

      DraftPlan? popped;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<DraftPlan>(
                    MaterialPageRoute<DraftPlan>(
                      builder: (_) => RefinePage(draft: draft),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      _setWideSurface(tester);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Drive into diffReady via the notifier, then accept via the UI so
      // the page's ref.listen has real frames to react to.
      final notifier = _readNotifier(tester, draft);
      notifier.beginListening(resetTranscript: true);
      await notifier.finishWithTranscript('please rearrange');
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      await _tap(tester, find.text(messages.dailyOsNextRefineAccept));
      // Drain the route-pop animation so the page is fully removed.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(popped, isNotNull);
      expect(popped?.scheduledMinutes, 99);
      expect(find.byType(RefinePage), findsNothing);
    });

    testWidgets('narrow layout (< 900) stacks panel above timeline (Column)', (
      tester,
    ) async {
      final draft = _emptyPlan();
      await tester.pumpWidget(
        _wrap(RefinePage(draft: draft), size: const Size(600, 900)),
      );
      await tester.pump();

      // Scaffold body's first child is the SafeArea → Column on narrow.
      final scaffold = find.byType(Scaffold);
      expect(
        find.descendant(of: scaffold, matching: find.byType(Column)),
        findsWidgets,
      );
      // Wide layout-only Row with two Expanded children should be absent;
      // a basic sanity check is that the panel still renders the status.
      final messages = tester.element(find.byType(RefinePage)).messages;
      expect(find.text(messages.dailyOsNextRefineStatusIdle), findsOneWidget);
      expect(find.byType(VoiceButton), findsOneWidget);
    });

    testWidgets('cancelListening from capture-error path returns to idle', (
      tester,
    ) async {
      final draft = _emptyPlan();
      await tester.pumpWidget(_wrap(RefinePage(draft: draft)));
      await tester.pump();

      final notifier = _readNotifier(tester, draft);
      notifier.beginListening(resetTranscript: true);
      await tester.pump();
      notifier.cancelListening();
      await tester.pump();

      final messages = tester.element(find.byType(RefinePage)).messages;
      expect(find.text(messages.dailyOsNextRefineStatusIdle), findsOneWidget);
      expect(find.byType(LiveWaveform), findsNothing);
    });

    testWidgets('close button pops the page', (tester) async {
      final draft = _emptyPlan();
      var poppedAfterOpen = false;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => RefinePage(draft: draft),
                    ),
                  );
                  poppedAfterOpen = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      _setWideSurface(tester);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(RefinePage), findsOneWidget);

      // Tap the leading close IconButton → Navigator.maybePop pops the route.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(RefinePage), findsNothing);
      expect(poppedAfterOpen, isTrue);
    });

    testWidgets(
      'thinking phase shows the thinking status and ignores voice taps',
      (tester) async {
        final draft = _emptyPlan();
        final gate = Completer<void>();
        final agent = _RecordingAgent(
          diff: _diffWithTwoChanges(draft),
          proposeGate: gate.future,
        );
        await tester.pumpWidget(
          _wrap(
            RefinePage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();
        _setWideSurface(tester);

        // Kick off a proposal that blocks on the gate, pinning the
        // controller in RefinePhase.thinking.
        final notifier = _readNotifier(tester, draft);
        notifier.beginListening(resetTranscript: true);
        unawaited(notifier.finishWithTranscript('rearrange the morning'));
        await tester.pump();

        final messages = tester.element(find.byType(RefinePage)).messages;
        expect(
          find.text(messages.dailyOsNextRefineStatusThinking),
          findsOneWidget,
        );

        // Tapping the voice button while thinking is a no-op: the proposal
        // is still pending (count stays at 1) and the phase is unchanged.
        await tester.tap(find.byType(VoiceButton));
        await tester.pump();
        expect(agent.proposeCount, 1);
        expect(
          find.text(messages.dailyOsNextRefineStatusThinking),
          findsOneWidget,
        );

        // Release the gate so the controller settles into diffReady and the
        // pending future completes before teardown.
        gate.complete();
        await tester.pump();
        await tester.pump();
        expect(find.byType(DiffRow), findsNWidgets(2));
      },
    );
  });

  group('showRefineModal', () {
    testWidgets('opens modal content over the current surface', (tester) async {
      final draft = _emptyPlan();
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    const Text('Daily surface behind modal'),
                    ElevatedButton(
                      onPressed: () {
                        unawaited(
                          showRefineModal(context: context, draft: draft),
                        );
                      },
                      child: const Text('Open refine'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open refine'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final messages = tester.element(find.byType(RefineModalContent)).messages;
      expect(find.text('Daily surface behind modal'), findsOneWidget);
      expect(find.byType(RefineModalContent), findsOneWidget);
      expect(find.text(messages.dailyOsNextRefineTitle), findsOneWidget);
      expect(find.byType(RefinePage), findsNothing);
    });

    testWidgets('returns the accepted plan when modal content accepts a diff', (
      tester,
    ) async {
      final draft = _emptyPlan();
      final acceptedPlan = draft.copyWith(scheduledMinutes: 42);
      final diff = PlanDiff(
        id: 'diff_modal',
        transcript: 'move one thing',
        changes: const [
          PlanDiffChange(
            id: 'chg_modal',
            kind: PlanDiffChangeKind.moved,
            title: 'Move one thing',
            category: _category,
            reason: 'one change resolves the modal',
            affectedBlockId: 'blk_1',
          ),
        ],
        updatedPlan: acceptedPlan,
      );
      final agent = _RecordingAgent(diff: diff, acceptedPlan: acceptedPlan);
      DraftPlan? result;

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showRefineModal(
                      context: context,
                      draft: draft,
                    );
                  },
                  child: const Text('Open refine'),
                );
              },
            ),
          ),
          overrides: [dayAgentProvider.overrideWithValue(agent)],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open refine'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final element = tester.element(find.byType(RefineModalContent));
      final container = ProviderScope.containerOf(element);
      final notifier = container.read(
        refineControllerProvider(draft).notifier,
      );
      await notifier.finishWithTranscript('move one thing');
      await tester.pump();

      final messages = element.messages;
      await _tap(tester, find.text(messages.dailyOsNextRefineAccept));
      await tester.pump(const Duration(milliseconds: 600));

      expect(result?.scheduledMinutes, 42);
      expect(find.byType(RefineModalContent), findsNothing);
    });
  });

  // Renders the active-transcript panel once the refine controller
  // holds a partial transcript. The full capture → refine forwarding
  // (`ref.listen` on `captureControllerProvider`) is exercised in the
  // capture-page tests; here we only verify the surface that displays
  // whatever the refine controller already holds.
  group('RefinePage active-transcript panel', () {
    testWidgets(
      'partial transcripts pushed into the refine controller surface in panel',
      (
        tester,
      ) async {
        final draft = _emptyPlan();
        await tester.pumpWidget(_wrap(RefinePage(draft: draft)));
        await tester.pump();

        final element = tester.element(find.byType(RefinePage));
        final container = ProviderScope.containerOf(element);
        final refine = container.read(refineControllerProvider(draft).notifier)
          ..beginListening(resetTranscript: true);
        await tester.pump();
        refine.updateActiveTranscript('hello world');
        await tester.pump();

        expect(find.text('hello world'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the voice button on idle phase begins listening then handles capture error',
      (tester) async {
        final draft = _emptyPlan();
        await tester.pumpWidget(_wrap(RefinePage(draft: draft)));
        await tester.pump();

        // Tap the voice button → _handleVoiceTap fires:
        //   1. captureNotifier.reset()
        //   2. refineNotifier.beginListening(resetTranscript: true)
        //   3. unawaited(captureNotifier.toggle())
        // The stub recorder denies permission so the capture controller
        // lands in `error`, which trips the refine page's ref.listen
        // and calls cancelListening → refine returns to idle.
        await tester.tap(find.byType(VoiceButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        final messages = tester.element(find.byType(RefinePage)).messages;
        expect(
          find.text(messages.dailyOsNextRefineStatusIdle),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the voice button while listening triggers a capture toggle',
      (tester) async {
        final draft = _emptyPlan();
        await tester.pumpWidget(_wrap(RefinePage(draft: draft)));
        await tester.pump();

        // Seed refine into listening so the next tap takes the
        // `RefinePhase.listening → captureNotifier.toggle()` branch.
        final notifier = _readNotifier(tester, draft);
        notifier.beginListening(resetTranscript: true);
        await tester.pump();

        await tester.tap(find.byType(VoiceButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The status line is still rendered (no exception thrown
        // navigating through the listening branch).
        expect(find.byType(VoiceButton), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the voice button on diffReady re-arms listening (keeps transcript)',
      (tester) async {
        final draft = _emptyPlan();
        final agent = _RecordingAgent(diff: _diffWithTwoChanges(draft));
        await tester.pumpWidget(
          _wrap(
            RefinePage(draft: draft),
            overrides: [dayAgentProvider.overrideWithValue(agent)],
          ),
        );
        await tester.pump();
        _setWideSurface(tester);

        final notifier = _readNotifier(tester, draft);
        notifier.beginListening(resetTranscript: true);
        await notifier.finishWithTranscript('rearrange things');
        await tester.pump();

        // Tap the voice button while diffReady → _handleVoiceTap takes
        // the diffReady branch, which calls captureNotifier.reset() and
        // refineNotifier.beginListening(resetTranscript: false). The
        // existing transcript should still be visible because
        // `resetTranscript: false`.
        await tester.tap(find.byType(VoiceButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('rearrange things'), findsOneWidget);
      },
    );
  });

  // Drives the capture controller directly so the panel's
  // `ref.listen(captureControllerProvider, ...)` forwarding into the
  // refine controller is exercised end to end.
  group('RefinePage capture → refine forwarding', () {
    testWidgets(
      'partial transcript while listening is forwarded to the refine panel',
      (tester) async {
        final draft = _emptyPlan();
        await tester.pumpWidget(
          _wrap(
            RefinePage(draft: draft),
            captureFactory: _DriveableCaptureController.new,
          ),
        );
        await tester.pump();

        // Refine must already be listening for updateActiveTranscript to
        // take effect (it ignores updates outside RefinePhase.listening).
        _readNotifier(tester, draft).beginListening(resetTranscript: true);
        await tester.pump();

        // Capture goes live and streams a partial transcript → the panel's
        // listener forwards it via refineNotifier.updateActiveTranscript.
        _readCapture(tester).emit(
          const CaptureState(
            phase: CapturePhase.listening,
            transcript: '',
            amplitudes: <double>[],
            partialTranscript: '  move lunch later  ',
          ),
        );
        await tester.pump();

        expect(find.text('move lunch later'), findsOneWidget);

        // A blank partial transcript is ignored (the trimmed-empty guard),
        // so the previously forwarded text is preserved.
        _readCapture(tester).emit(
          const CaptureState(
            phase: CapturePhase.transcribing,
            transcript: '',
            amplitudes: <double>[],
            partialTranscript: '   ',
          ),
        );
        await tester.pump();

        expect(find.text('move lunch later'), findsOneWidget);
        final refineState = ProviderScope.containerOf(
          tester.element(find.byType(RefinePage)),
        ).read(refineControllerProvider(draft));
        expect(refineState.transcript, 'move lunch later');
      },
    );

    testWidgets(
      'captured capture state moves refine into reviewing with the transcript',
      (tester) async {
        final draft = _emptyPlan();
        await tester.pumpWidget(
          _wrap(
            RefinePage(draft: draft),
            captureFactory: _DriveableCaptureController.new,
          ),
        );
        await tester.pump();

        _readNotifier(tester, draft).beginListening(resetTranscript: true);
        await tester.pump();

        // Capture finishes → CapturePhase.captured forwards the final
        // transcript via refineNotifier.reviewTranscript, flipping the
        // refine panel into the reviewing (editable) surface.
        _readCapture(tester).emit(
          const CaptureState(
            phase: CapturePhase.captured,
            transcript: 'add a wrap-up block at five',
            amplitudes: <double>[],
          ),
        );
        await tester.pump();

        final messages = tester.element(find.byType(RefinePage)).messages;
        expect(
          find.text(messages.dailyOsNextCaptureCaptured),
          findsOneWidget,
        );
        final editor = find.byKey(
          const Key('daily_os_refine_transcript_editor'),
        );
        expect(editor, findsOneWidget);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: editor,
                  matching: find.byType(EditableText),
                ),
              )
              .controller
              .text,
          'add a wrap-up block at five',
        );
      },
    );
  });
}
