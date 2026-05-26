import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _RecordingAgent implements DayAgentInterface {
  String? capturedTranscript;
  String? capturedAudioId;
  DateTime? capturedAt;
  int submitCount = 0;

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
    String? audioId,
  }) async {
    capturedTranscript = transcript;
    capturedAudioId = audioId;
    this.capturedAt = capturedAt;
    submitCount++;
    return const CaptureId('cap_recorded');
  }

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
    List<TimeBlock> calendarBlocks = const [],
  }) async => DraftPlan(
    dayDate: dayDate,
    blocks: const [],
    bands: const [],
    capacityMinutes: 0,
    scheduledMinutes: 0,
  );

  @override
  Future<List<LearningCard>> summarizeRecentPatterns({
    required DateTime asOf,
    int lookbackDays = 7,
  }) async => const [];

  @override
  Future<PlanDiff> proposePlanDiff({
    required DraftPlan currentPlan,
    required String voiceTranscript,
  }) async => PlanDiff(
    id: 'rec',
    transcript: voiceTranscript,
    changes: const [],
    updatedPlan: currentPlan,
  );

  @override
  Future<DraftPlan> acceptDiff(PlanDiff diff) async => diff.updatedPlan;

  @override
  Future<DraftPlan> revertDiff({
    required PlanDiff diff,
    required DraftPlan originalPlan,
  }) async => originalPlan;

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

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: makeTestableWidget2(
      child,
      mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
    ),
  );
}

void main() {
  group('CapturePage', () {
    testWidgets('idle phase shows hint, headline, voice button, no CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CapturePage()));
      await tester.pump();

      final context = tester.element(find.byType(CapturePage));
      final messages = context.messages;

      expect(find.text(messages.dailyOsNextGreetingHi), findsOneWidget);
      expect(find.text(messages.dailyOsNextCaptureIdleHint), findsOneWidget);
      expect(find.byType(VoiceButton), findsOneWidget);
      expect(find.byType(LiveWaveform), findsNothing);
      expect(find.text(messages.dailyOsNextCaptureReconcileCta), findsNothing);
    });

    testWidgets('tapping the voice button arms the listening phase', (
      tester,
    ) async {
      final harness = _AudioHarness()..arm();
      await tester.pumpWidget(
        _wrap(
          const CapturePage(),
          overrides: [
            captureControllerProvider.overrideWith(harness.controllerFactory),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(VoiceButton));
      await tester.pump();
      await tester.pump();

      final context = tester.element(find.byType(CapturePage));
      final messages = context.messages;
      expect(find.text(messages.dailyOsNextCaptureListening), findsOneWidget);
      expect(find.byType(LiveWaveform), findsOneWidget);

      await harness.dispose();
    });

    testWidgets(
      'after capture, the Reconcile CTA submits edited transcript + audioId',
      (tester) async {
        final agent = _RecordingAgent();
        final harness = _AudioHarness(transcript: 'hi there')..arm();
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              dayAgentProvider.overrideWithValue(agent),
              captureControllerProvider.overrideWith(harness.controllerFactory),
            ],
          ),
        );
        await tester.pump();

        // Start listening (async permission + startRecording).
        await tester.tap(find.byType(VoiceButton));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        // Stop listening — triggers transcribe + persist.
        await tester.tap(find.byType(VoiceButton));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();

        final context = tester.element(find.byType(CapturePage));
        final messages = context.messages;
        expect(find.text(messages.dailyOsNextCaptureCaptured), findsOneWidget);
        expect(
          find.text(messages.dailyOsNextCaptureTranscriptLabel),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('daily_os_capture_transcript_editor')),
          'complete client animation',
        );
        await tester.pump();

        final ctaFinder = find.text(messages.dailyOsNextCaptureReconcileCta);
        expect(ctaFinder, findsOneWidget);
        await tester.ensureVisible(ctaFinder);
        await tester.pump();
        await tester.tap(ctaFinder, warnIfMissed: false);
        await tester.pump();

        expect(agent.submitCount, 1);
        expect(agent.capturedTranscript, 'complete client animation');
        expect(agent.capturedAudioId, 'audio_001');

        await harness.dispose();
      },
    );

    testWidgets('submits captures against the selected planning date', (
      tester,
    ) async {
      final agent = _RecordingAgent();
      final harness = _AudioHarness(transcript: 'plan tomorrow')..arm();
      await tester.pumpWidget(
        _wrap(
          CapturePage(forDate: DateTime(2026, 5, 27)),
          overrides: [
            dayAgentProvider.overrideWithValue(agent),
            captureControllerProvider.overrideWith(harness.controllerFactory),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(VoiceButton));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      await tester.tap(find.byType(VoiceButton));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      final ctaFinder = find.text(
        tester
            .element(find.byType(CapturePage))
            .messages
            .dailyOsNextCaptureReconcileCta,
      );
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder, warnIfMissed: false);
      await tester.pump();

      expect(agent.submitCount, 1);
      expect(agent.capturedAt?.year, 2026);
      expect(agent.capturedAt?.month, 5);
      expect(agent.capturedAt?.day, 27);

      await harness.dispose();
    });
  });
}

/// Wraps a fake recorder + transcription service so widget tests can
/// drive the [CaptureController] without touching the mic or cloud.
class _AudioHarness {
  _AudioHarness({this.transcript = 'transcript'});

  final String transcript;
  final MockAudioRecorderRepository recorder = MockAudioRecorderRepository();
  final MockAudioTranscriptionService transcriber =
      MockAudioTranscriptionService();
  final MockRealtimeTranscriptionService realtimeService =
      MockRealtimeTranscriptionService();
  final StreamController<Amplitude> ampController =
      StreamController<Amplitude>.broadcast();

  void arm() {
    // Page tests pin the batch path; realtime coverage lives in the
    // controller test.
    when(
      () => realtimeService.resolveRealtimeConfig(
        preferMistral: any(named: 'preferMistral'),
      ),
    ).thenAnswer((_) async => null);
    when(recorder.hasPermission).thenAnswer((_) async => true);
    when(
      () => recorder.amplitudeStream,
    ).thenAnswer((_) => ampController.stream);
    when(recorder.startRecording).thenAnswer(
      (_) async => AudioNote(
        createdAt: DateTime(2026, 5, 26, 9),
        audioFile: 'capture.m4a',
        audioDirectory: '/audio/2026-05-26/',
        duration: Duration.zero,
      ),
    );
    when(recorder.stopRecording).thenAnswer((_) async {});
    when(
      () => transcriber.transcribe(
        any(),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer((_) async => transcript);
  }

  CaptureController controllerFactory() => CaptureController(
    recorder: recorder,
    transcriber: transcriber,
    realtimeService: realtimeService,
    docDir: Directory.systemTemp.createTempSync,
    persistAudio: (_) async => JournalAudio(
      meta: Metadata(
        id: 'audio_001',
        createdAt: DateTime(2026, 5, 26, 9),
        updatedAt: DateTime(2026, 5, 26, 9),
        dateFrom: DateTime(2026, 5, 26, 9),
        dateTo: DateTime(2026, 5, 26, 9, 0, 1),
        vectorClock: const VectorClock(<String, int>{}),
      ),
      data: AudioData(
        dateFrom: DateTime(2026, 5, 26, 9),
        dateTo: DateTime(2026, 5, 26, 9, 0, 1),
        audioFile: 'capture.m4a',
        audioDirectory: '/audio/2026-05-26/',
        duration: const Duration(seconds: 1),
      ),
    ),
    now: () => DateTime(2026, 5, 26, 9),
  );

  Future<void> dispose() async {
    await ampController.close();
  }
}
