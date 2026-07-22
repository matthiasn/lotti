import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/state/day_activity_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_activity_view.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/speech/state/audio_waveform_provider.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
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
    DayProcessingFailureClass? failureClass,
    String? lastError,
  }) => DayProcessingJob(
    id: id,
    status: status,
    dayId: 'dayplan-2026-07-18',
    payload: TranscribeAudioPayload(
      activityEntryId: activityId,
      recordingSessionId: 'session-$activityId',
      audioId: 'audio-$activityId',
      audioPath: '/tmp/$activityId.wav',
    ),
    createdAt: capturedAt,
    updatedAt: capturedAt,
    requestedAt: capturedAt,
    nextAttemptAt: capturedAt,
    attempts: 0,
    generation: 0,
    resultTranscript: transcript,
    lastFailureClass: failureClass,
    lastError: lastError,
  );

  tearDown(() => nav_service.beamToNamedOverride = null);

  testWidgets('shows durable states and lets a ready transcript build a plan', (
    tester,
  ) async {
    DayActivityEntry? used;
    final outbox = MockDayProcessingOutboxRepository();
    final runtime = MockDayProcessingRuntime();
    when(() => outbox.retryNow(any())).thenAnswer((_) async => null);
    when(runtime.nudge).thenAnswer((_) async {});
    final waiting = DayActivityEntry(
      id: 'waiting',
      kind: DayActivityEntryKind.recording,
      createdAt: capturedAt,
      activityEntryId: 'waiting',
      processingJob: job(
        id: 'job-waiting',
        activityId: 'waiting',
        status: DayProcessingJobStatus.waitingForNetwork,
        lastError: 'SocketException: connection refused',
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
    final backedOff = DayActivityEntry(
      id: 'backed-off',
      kind: DayActivityEntryKind.recording,
      createdAt: capturedAt.add(const Duration(minutes: 7)),
      activityEntryId: 'backed-off',
      processingJob: job(
        id: 'job-backed-off',
        activityId: 'backed-off',
        status: DayProcessingJobStatus.queued,
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
            (ref, date) async => [waiting, ready, backedOff],
          ),
          dayProcessingOutboxRepositoryProvider.overrideWithValue(outbox),
          dayProcessingRuntimeProvider.overrideWithValue(runtime),
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
      findsNWidgets(2),
    );
    // Both the waiting and the queued/backed-off recordings stay manually
    // retryable — backoff must never leave the user without a trigger.
    expect(find.text(messages.dailyOsNextActivityRetry), findsNWidgets(2));
    // The stored failure reason is visible, so a retry that fails again
    // is diagnosable instead of looking like a dead button.
    expect(
      find.text('SocketException: connection refused'),
      findsOneWidget,
    );
    expect(
      find.text('Protect the afternoon for focused work.'),
      findsOneWidget,
    );

    await tester.tap(find.text(messages.dailyOsNextActivityRetry).last);
    await tester.pump();
    verify(() => outbox.retryNow('job-waiting')).called(1);
    verify(runtime.nudge).called(1);

    // Without a persisted journal entity there is nothing to edit in place.
    expect(find.byType(EditorWidget), findsNothing);

    await tester.tap(find.text(messages.dailyOsNextActivityUseToPlan));
    await tester.pump();

    expect(used, same(ready));
  });

  testWidgets('distinguishes a local load failure from an empty day', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: DayActivityView(
            date: date,
            hasPlan: false,
            actualBlocks: const [],
            onUseEntry: (_) {},
          ),
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

  testWidgets('renders plan, summary, processing, and failure semantics', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1000, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = [
      DayActivityEntry(
        id: 'plan',
        kind: DayActivityEntryKind.plan,
        createdAt: capturedAt,
        activityEntryId: 'plan',
      ),
      DayActivityEntry(
        id: 'summary',
        kind: DayActivityEntryKind.summary,
        createdAt: capturedAt,
        activityEntryId: 'summary',
      ),
      for (final (id, status, failure) in [
        ('running', DayProcessingJobStatus.running, null),
        (
          'missing',
          DayProcessingJobStatus.failed,
          DayProcessingFailureClass.missingAsset,
        ),
        (
          'setup',
          DayProcessingJobStatus.waitingForUser,
          DayProcessingFailureClass.setupRequired,
        ),
      ])
        DayActivityEntry(
          id: id,
          kind: DayActivityEntryKind.recording,
          createdAt: capturedAt,
          activityEntryId: id,
          processingJob: job(
            id: 'job-$id',
            activityId: id,
            status: status,
            failureClass: failure,
          ),
        ),
    ];

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayActivityView(
          date: date,
          hasPlan: true,
          actualBlocks: const [],
          onUseEntry: (_) {},
        ),
        overrides: [
          dayActivityProvider.overrideWith((ref, date) async => entries),
        ],
        mediaQueryData: const MediaQueryData(size: Size(1000, 2000)),
      ),
    );
    await tester.pump();

    final messages = tester.element(find.byType(DayActivityView)).messages;
    for (final text in [
      messages.dailyOsNextActivityPlanCreated,
      messages.dailyOsNextActivityPlanAvailable,
      messages.dailyOsNextActivityDaySummary,
      messages.dailyOsNextActivityTranscribing,
      messages.dailyOsNextActivityMissingAudio,
      messages.dailyOsNextActivitySetupRequired,
      messages.dailyOsNextActivityOpenSetup,
    ]) {
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('reports a retry failure without leaving the button busy', (
    tester,
  ) async {
    final retryCompleter = Completer<DayProcessingJob?>();
    final outbox = MockDayProcessingOutboxRepository();
    final runtime = MockDayProcessingRuntime();
    when(
      () => outbox.retryNow('job-waiting'),
    ).thenAnswer((_) => retryCompleter.future);
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
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: DayActivityView(
            date: date,
            hasPlan: false,
            actualBlocks: const [],
            onUseEntry: (_) {},
          ),
        ),
        overrides: [
          dayActivityProvider.overrideWith((ref, date) async => [waiting]),
          dayProcessingOutboxRepositoryProvider.overrideWithValue(outbox),
          dayProcessingRuntimeProvider.overrideWithValue(runtime),
        ],
      ),
    );
    await tester.pump();
    final messages = tester.element(find.byType(DayActivityView)).messages;

    await tester.tap(find.text(messages.dailyOsNextActivityRetry));
    await tester.tap(find.text(messages.dailyOsNextActivityRetry));
    verify(() => outbox.retryNow('job-waiting')).called(1);
    retryCompleter.completeError(StateError('network still unavailable'));
    await tester.pump();
    expect(
      find.text(messages.dailyOsNextActivityActionFailed),
      findsOneWidget,
    );
    verifyNever(runtime.nudge);
  });

  testWidgets('renders submitted, saved, refine, and setup semantics', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1000, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final routes = <String>[];
    nav_service.beamToNamedOverride = routes.add;
    final submitted =
        AgentDomainEntity.capture(
              id: 'submitted',
              agentId: 'planner',
              transcript: 'Already submitted',
              capturedAt: capturedAt,
              createdAt: capturedAt,
              vectorClock: null,
              dayId: 'dayplan-2026-07-18',
            )
            as CaptureEntity;
    final entries = [
      DayActivityEntry(
        id: 'ready',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        activityEntryId: 'ready',
        processingJob: job(
          id: 'job-ready',
          activityId: 'ready',
          status: DayProcessingJobStatus.succeeded,
          transcript: 'Use this to refine the plan.',
        ),
      ),
      DayActivityEntry(
        id: 'saved',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        activityEntryId: 'saved',
      ),
      DayActivityEntry(
        id: 'submitted',
        kind: DayActivityEntryKind.checkIn,
        createdAt: capturedAt,
        activityEntryId: 'submitted',
        capture: submitted,
      ),
      DayActivityEntry(
        id: 'setup',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        activityEntryId: 'setup',
        processingJob: job(
          id: 'job-setup',
          activityId: 'setup',
          status: DayProcessingJobStatus.waitingForUser,
          failureClass: DayProcessingFailureClass.setupRequired,
        ),
      ),
    ];
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayActivityView(
          date: date,
          hasPlan: true,
          actualBlocks: const [],
          onUseEntry: (_) {},
        ),
        overrides: [
          dayActivityProvider.overrideWith((ref, date) async => entries),
        ],
        mediaQueryData: const MediaQueryData(size: Size(1000, 2000)),
      ),
    );
    await tester.pump();
    final messages = tester.element(find.byType(DayActivityView)).messages;

    for (final text in [
      messages.dailyOsNextActivitySubmitted,
      messages.dailyOsNextActivitySaved,
      messages.dailyOsNextActivityUseToRefine,
      messages.dailyOsNextActivityOpenSetup,
      // A setup-required job stays manually retryable so the user can
      // resume it right after configuring a model.
      messages.dailyOsNextActivityRetry,
    ]) {
      expect(
        find.text(text),
        text == messages.dailyOsNextActivityUseToRefine
            ? findsNWidgets(2)
            : findsOneWidget,
      );
    }
    await tester.tap(find.text(messages.dailyOsNextActivityOpenSetup));
    expect(routes, ['/settings/ai']);
  });

  testWidgets('retries a failed local projection and shows an empty day', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayActivityView(
          date: date,
          hasPlan: false,
          actualBlocks: const [],
          onUseEntry: (_) {},
        ),
        overrides: [
          dayActivityProvider.overrideWith((ref, date) {
            loads += 1;
            if (loads == 1) throw StateError('database unavailable');
            return const <DayActivityEntry>[];
          }),
        ],
      ),
    );
    await tester.pump();
    final messages = tester.element(find.byType(DayActivityView)).messages;

    await tester.tap(find.text(messages.dailyOsNextActivityRetryLoad));
    await tester.pump();

    expect(loads, 2);
    expect(find.text(messages.dailyOsNextActivityEmpty), findsOneWidget);
    expect(find.text(messages.dailyOsNextActivityLoadFailed), findsNothing);
  });

  testWidgets(
    'embeds playback and the in-place journal editor for a saved recording',
    (tester) async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EditorStateService>(
            MockEditorStateService(),
          );
        },
      );
      addTearDown(tearDownTestGetIt);
      final root = Directory.systemTemp.createTempSync('day-activity-audio-');
      addTearDown(() => root.deleteSync(recursive: true));
      final audioFile = File('${root.path}/recording.wav')
        ..writeAsBytesSync([0]);
      final audio = JournalAudio(
        meta: Metadata(
          id: 'audio-local',
          createdAt: capturedAt,
          updatedAt: capturedAt,
          dateFrom: capturedAt,
          dateTo: capturedAt.add(const Duration(seconds: 1)),
        ),
        data: AudioData(
          dateFrom: capturedAt,
          dateTo: capturedAt.add(const Duration(seconds: 1)),
          audioFile: 'recording.wav',
          audioDirectory: root.path,
          duration: const Duration(seconds: 1),
        ),
        entryText: const EntryText(
          plainText: 'Reviewed wording',
          markdown: 'Reviewed wording',
        ),
      );
      final entry = DayActivityEntry(
        id: 'local',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        activityEntryId: 'local',
        audio: audio,
        audioPath: audioFile.path,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          DayActivityView(
            date: date,
            hasPlan: false,
            actualBlocks: const [],
            onUseEntry: (_) {},
          ),
          overrides: [
            dayActivityProvider.overrideWith((ref, date) async => [entry]),
            audioWaveformProvider.overrideWith((ref, request) async => null),
            createEntryControllerOverride(audio),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      // The saved wording is edited in place through the shared journal
      // editor, keyed by the recording's journal id; the plain transcript
      // line disappears in favour of the editable document.
      final editor = tester.widget<EditorWidget>(find.byType(EditorWidget));
      expect(editor.entryId, 'audio-local');
      expect(find.text('Reviewed wording'), findsNothing);
    },
  );

  testWidgets(
    'keeps the pending status line and editor for a not-yet-transcribed '
    'recording, but no editor once submitted',
    (tester) async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EditorStateService>(
            MockEditorStateService(),
          );
        },
      );
      addTearDown(tearDownTestGetIt);
      final audio = JournalAudio(
        meta: Metadata(
          id: 'audio-pending',
          createdAt: capturedAt,
          updatedAt: capturedAt,
          dateFrom: capturedAt,
          dateTo: capturedAt.add(const Duration(seconds: 1)),
        ),
        data: AudioData(
          dateFrom: capturedAt,
          dateTo: capturedAt.add(const Duration(seconds: 1)),
          audioFile: 'missing.wav',
          audioDirectory: '/nowhere/',
          duration: const Duration(seconds: 1),
        ),
      );
      final pending = DayActivityEntry(
        id: 'pending',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        activityEntryId: 'pending',
        audio: audio,
        audioPath: '/nowhere/missing.wav',
      );
      final submitted = DayActivityEntry(
        id: 'submitted',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt.add(const Duration(minutes: 1)),
        activityEntryId: 'submitted',
        audio: audio,
        audioPath: '/nowhere/missing.wav',
        capture:
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: 'planner',
                  transcript: 'Submitted wording',
                  capturedAt: capturedAt,
                  createdAt: capturedAt,
                  vectorClock: null,
                  dayId: 'dayplan-2026-07-18',
                  audioRef: 'audio-pending',
                )
                as CaptureEntity,
      );
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
              (ref, date) async => [pending, submitted],
            ),
            createEntryControllerOverride(audio),
          ],
        ),
      );
      await tester.pump();

      final messages = tester.element(find.byType(DayActivityView)).messages;
      // With no saved text yet, the status line stays while the empty
      // editor invites typing; the submitted card is read-only.
      expect(
        find.text(messages.dailyOsNextActivityTranscriptPending),
        findsOneWidget,
      );
      expect(find.byType(EditorWidget), findsOneWidget);
      expect(find.text('Submitted wording'), findsOneWidget);
    },
  );

  testWidgets('deleting a recording cancels its job and soft-deletes the '
      'journal entry', (tester) async {
    final outbox = MockDayProcessingOutboxRepository();
    final journalRepository = MockJournalRepository();
    when(() => outbox.cancel(any())).thenAnswer((_) async => null);
    when(
      () => journalRepository.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
    final entry = DayActivityEntry(
      id: 'doomed',
      kind: DayActivityEntryKind.recording,
      createdAt: capturedAt,
      activityEntryId: 'doomed',
      processingJob: job(
        id: 'job-doomed',
        activityId: 'doomed',
        status: DayProcessingJobStatus.queued,
      ),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DayActivityView(
          date: date,
          hasPlan: false,
          actualBlocks: const [],
          onUseEntry: (_) {},
        ),
        overrides: [
          dayActivityProvider.overrideWith((ref, date) async => [entry]),
          dayProcessingOutboxRepositoryProvider.overrideWithValue(outbox),
          journalRepositoryProvider.overrideWithValue(journalRepository),
        ],
      ),
    );
    await tester.pump();
    final messages = tester.element(find.byType(DayActivityView)).messages;

    await tester.tap(find.text(messages.dailyOsNextActivityDeleteRecording));
    await tester.pump();
    // Cancelling keeps the recording until the user confirms.
    await tester.tap(find.text(messages.dailyOsNextDayDeleteDialogCancel));
    await tester.pump();
    verifyNever(() => outbox.cancel(any()));

    await tester.tap(find.text(messages.dailyOsNextActivityDeleteRecording));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        messages.dailyOsNextDayDeleteDialogConfirm,
      ),
    );
    await tester.pump();

    verify(() => outbox.cancel('job-doomed')).called(1);
    verify(
      () => journalRepository.deleteJournalEntity('audio-doomed'),
    ).called(1);
  });
}
