import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_activity_view.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final date = DateTime(2026, 7, 18);
  final capturedAt = DateTime(2026, 7, 18, 8, 15);

  DayProcessingJob job({
    required String id,
    required String activityId,
    required DayProcessingJobStatus status,
    String? transcript,
  }) => DayProcessingJob(
    id: id,
    kind: DayProcessingJobKind.transcribeAudio,
    status: status,
    dayId: 'dayplan-2026-07-18',
    activityEntryId: activityId,
    recordingSessionId: 'session-$activityId',
    audioId: 'audio-$activityId',
    audioPath: '/tmp/$activityId.wav',
    createdAt: capturedAt,
    updatedAt: capturedAt,
    nextAttemptAt: capturedAt,
    attempts: 0,
    generation: 0,
    resultTranscript: transcript,
  );

  testWidgets('shows durable states and lets a ready transcript build a plan', (
    tester,
  ) async {
    DayActivityEntry? used;
    final transcriptWriter = MockDayAudioTranscriptWriter();
    final outbox = MockDayProcessingOutboxRepository();
    when(
      () => transcriptWriter.attachManual(
        audioId: any(named: 'audioId'),
        transcript: any(named: 'transcript'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => outbox.satisfyWithReviewedText(any(), any()),
    ).thenAnswer((_) async => null);
    final waiting = DayActivityEntry(
      id: 'waiting',
      kind: DayActivityEntryKind.recording,
      createdAt: capturedAt,
      activityEntryId: 'waiting',
      processingJob: job(
        id: 'job-waiting',
        activityId: 'waiting',
        status: DayProcessingJobStatus.waitingForNetwork,
      ),
    );
    final ready = DayActivityEntry(
      id: 'ready',
      kind: DayActivityEntryKind.recording,
      createdAt: capturedAt.add(const Duration(minutes: 5)),
      activityEntryId: 'ready',
      processingJob: job(
        id: 'job-ready',
        activityId: 'ready',
        status: DayProcessingJobStatus.succeeded,
        transcript: 'Protect the afternoon for focused work.',
      ),
    );
    final recovery = DayActivityEntry(
      id: 'recovery',
      kind: DayActivityEntryKind.recovery,
      createdAt: capturedAt.add(const Duration(minutes: 10)),
      activityEntryId: 'recovery',
      recoveryManifest: DurableAudioSpoolManifest(
        generation: 1,
        context: DurableAudioSpoolContext(
          recordingSessionId: 'session-recovery',
          activityEntryId: 'recovery',
          createdAt: capturedAt,
          assetRootPath: '/tmp',
          origin: AudioCaptureOrigin.dailyOs,
          intent: AudioCaptureIntent.dayPlan,
          dayId: 'dayplan-2026-07-18',
          planDate: date,
        ),
        state: DurableAudioSpoolState.recoveryRequired,
        chunks: const [],
        activeChunkBytes: 4,
        acceptedPcmBytes: 4,
        chunkBytes: 4,
      ),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayActivityView(
          date: date,
          hasPlan: false,
          actualBlocks: const [],
          onUseEntry: (entry) => used = entry,
        ),
        overrides: [
          dayActivityProvider.overrideWith(
            (ref, date) async => [waiting, ready, recovery],
          ),
          dayAudioTranscriptWriterProvider.overrideWithValue(transcriptWriter),
          dayProcessingOutboxRepositoryProvider.overrideWithValue(outbox),
        ],
      ),
    );
    await tester.pump();

    final messages = tester.element(find.byType(DayActivityView)).messages;
    expect(
      find.text(messages.dailyOsNextActivityWaitingForNetwork),
      findsOneWidget,
    );
    expect(
      find.text(messages.dailyOsNextActivityTranscriptPending),
      findsOneWidget,
    );
    expect(find.text(messages.dailyOsNextActivityRetry), findsOneWidget);
    expect(find.text(messages.dailyOsNextActivityRecover), findsOneWidget);
    expect(
      find.text('Protect the afternoon for focused work.'),
      findsOneWidget,
    );

    await tester.tap(
      find.text(messages.dailyOsNextActivityAddOrEditText).first,
    );
    await tester.pump();
    expect(
      find.text(messages.dailyOsNextActivityTextDialogTitle),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'My reviewed wording');
    await tester.tap(find.text(messages.saveButton));
    await tester.pump();
    verify(
      () => transcriptWriter.attachManual(
        audioId: 'audio-ready',
        transcript: 'My reviewed wording',
      ),
    ).called(1);

    await tester.tap(find.text(messages.dailyOsNextActivityUseToPlan));
    await tester.pump();

    expect(used, same(ready));
  });

  testWidgets('distinguishes a local load failure from an empty day', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayActivityView(
          date: date,
          hasPlan: false,
          actualBlocks: const [],
          onUseEntry: (_) {},
        ),
        overrides: [
          dayActivityProvider.overrideWith(
            (ref, date) => throw StateError('database temporarily unavailable'),
          ),
        ],
      ),
    );
    await tester.pump();

    final messages = tester.element(find.byType(DayActivityView)).messages;
    expect(find.text(messages.dailyOsNextActivityLoadFailed), findsOneWidget);
    expect(find.text(messages.dailyOsNextActivityRetryLoad), findsOneWidget);
    expect(find.text(messages.dailyOsNextActivityEmpty), findsNothing);
  });

  testWidgets('keeps tracked time visible when the day has no agent entries', (
    tester,
  ) async {
    final block = TimeBlock(
      id: 'actual:client',
      title: 'Client follow-up',
      start: DateTime(2026, 7, 18, 8),
      end: DateTime(2026, 7, 18, 9),
      type: TimeBlockType.manual,
      state: TimeBlockState.completed,
      category: const DayAgentCategory(
        id: 'work',
        name: 'Work',
        colorHex: '5ED4B7',
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayActivityView(
          date: date,
          hasPlan: false,
          actualBlocks: [block],
          onUseEntry: (_) {},
        ),
        overrides: [
          dayActivityProvider.overrideWith((ref, date) async => const []),
        ],
      ),
    );
    await tester.pump();

    final messages = tester.element(find.byType(DayActivityView)).messages;
    expect(find.text('Client follow-up'), findsOneWidget);
    expect(find.text(messages.dailyOsNextActivityEmpty), findsNothing);
  });
}
