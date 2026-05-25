import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/capture_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

class _RecordingAgent implements DayAgentInterface {
  String? capturedTranscript;
  int submitCount = 0;

  @override
  Future<CaptureId> submitCapture({
    required String transcript,
    required DateTime capturedAt,
  }) async {
    capturedTranscript = transcript;
    submitCount++;
    return const CaptureId('cap_recorded');
  }

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
      await tester.pumpWidget(
        _wrap(
          const CapturePage(),
          overrides: [
            captureControllerProvider.overrideWith(
              () => CaptureController(
                transcriptChunks: const ['hello'],
                chunkInterval: const Duration(milliseconds: 50),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(VoiceButton));
      await tester.pump();

      final context = tester.element(find.byType(CapturePage));
      final messages = context.messages;
      expect(find.text(messages.dailyOsNextCaptureListening), findsOneWidget);
      expect(find.byType(LiveWaveform), findsOneWidget);
    });

    testWidgets(
      'after capture, the Reconcile CTA submits the transcript and pushes '
      'Reconcile',
      (tester) async {
        final agent = _RecordingAgent();
        await tester.pumpWidget(
          _wrap(
            const CapturePage(),
            overrides: [
              dayAgentProvider.overrideWithValue(agent),
              captureControllerProvider.overrideWith(
                () => CaptureController(
                  transcriptChunks: const ['hi'],
                  chunkInterval: const Duration(milliseconds: 10),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        // Start listening; let the scripted transcript finish.
        await tester.tap(find.byType(VoiceButton));
        await tester.pump(const Duration(milliseconds: 50));

        final context = tester.element(find.byType(CapturePage));
        final messages = context.messages;
        expect(find.text(messages.dailyOsNextCaptureCaptured), findsOneWidget);

        final ctaFinder = find.text(messages.dailyOsNextCaptureReconcileCta);
        expect(ctaFinder, findsOneWidget);
        await tester.ensureVisible(ctaFinder);
        await tester.pump();
        await tester.tap(ctaFinder, warnIfMissed: false);
        await tester.pump();

        expect(agent.submitCount, 1);
        expect(agent.capturedTranscript, 'hi');
      },
    );
  });
}
