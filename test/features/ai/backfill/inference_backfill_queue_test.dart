import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_queue.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'backfill_fixtures.dart';

const _taskId = 'task-1';

InferenceBackfillCandidate _candidate(
  String entryId, [
  InferenceBackfillKind kind = InferenceBackfillKind.imageAnalysis,
]) => InferenceBackfillCandidate(
  entryId: entryId,
  kind: kind,
  capturedAt: testFixedDate,
);

/// A handled result whose profile names [modelId], so a test can tell which
/// resolution a run was given.
AutomationResult _handled(String modelId) => AutomationResult(
  handled: true,
  skill: findBuiltInSkill(skillImageAnalysisContextId),
  resolvedProfile: ResolvedProfile(
    thinkingModelId: modelId,
    thinkingProvider: AiTestDataFactory.createTestProvider(),
  ),
);

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(_candidate('fallback'));
    registerFallbackValue(AutomationResult.notHandled);
  });

  late MockInferenceBackfillDetector detector;
  late MockProfileAutomationService automation;
  late MockSkillInferenceRunner runner;
  late MockDomainLogger logger;
  late ProviderContainer container;

  InferenceBackfillQueue queue() =>
      container.read(inferenceBackfillQueueProvider.notifier);

  setUp(() {
    detector = MockInferenceBackfillDetector();
    automation = MockProfileAutomationService();
    runner = MockSkillInferenceRunner();
    logger = MockDomainLogger();
    container = ProviderContainer(
      overrides: [
        inferenceBackfillDetectorProvider.overrideWithValue(detector),
        profileAutomationServiceProvider.overrideWithValue(automation),
        skillInferenceRunnerProvider.overrideWithValue(runner),
        domainLoggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(container.dispose);

    when(() => detector.isStillMissing(any())).thenAnswer((_) async => true);
    when(
      () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
    ).thenAnswer((_) async => _handled('vision-model'));
    when(
      () => runner.runImageAnalysis(
        imageEntryId: any(named: 'imageEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    ).thenAnswer((_) async {});
  });

  void verifySkipped(String reason) => verify(
    () => logger.log(
      LogDomain.ai,
      any(that: contains(reason)),
      subDomain: 'inferenceBackfill',
    ),
  ).called(1);

  test('runs an accepted image analysis in task context with the model the '
      'task resolves to', () async {
    final result = _handled('vision-model');
    when(
      () => automation.tryAnalyzeImage(subjectId: _taskId),
    ).thenAnswer((_) async => result);

    expect(
      queue().enqueue(taskId: _taskId, candidate: _candidate('img')),
      isTrue,
    );
    await queue().idle;

    verify(
      () => runner.runImageAnalysis(
        imageEntryId: 'img',
        automationResult: result,
        linkedTaskId: _taskId,
      ),
    ).called(1);
    expect(container.read(inferenceBackfillQueueProvider), isEmpty);
  });

  test('runs transcription and summaries through their own runs', () async {
    final transcription = _handled('speech-model');
    final summary = _handled('thinking-model');
    when(
      () => automation.tryTranscribe(subjectId: _taskId),
    ).thenAnswer((_) async => transcription);
    when(
      () => automation.trySummarizeAudio(subjectId: _taskId),
    ).thenAnswer((_) async => summary);
    when(
      () => runner.runTranscription(
        audioEntryId: any(named: 'audioEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => runner.runAudioSummary(
        audioEntryId: any(named: 'audioEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    ).thenAnswer((_) async {});

    queue()
      ..enqueue(
        taskId: _taskId,
        candidate: _candidate('rec', InferenceBackfillKind.transcription),
      )
      ..enqueue(
        taskId: _taskId,
        candidate: _candidate('long', InferenceBackfillKind.audioSummary),
      );
    await queue().idle;

    verify(
      () => runner.runTranscription(
        audioEntryId: 'rec',
        automationResult: transcription,
        linkedTaskId: _taskId,
      ),
    ).called(1);
    verify(
      () => runner.runAudioSummary(
        audioEntryId: 'long',
        automationResult: summary,
        linkedTaskId: _taskId,
      ),
    ).called(1);
  });

  test('accept-all queues every suggestion and runs them one at a time, in '
      'order', () async {
    final releases = <String, Completer<void>>{};
    final started = <String>[];
    when(
      () => runner.runImageAnalysis(
        imageEntryId: any(named: 'imageEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    ).thenAnswer((invocation) {
      final id = invocation.namedArguments[#imageEntryId] as String;
      started.add(id);
      return (releases[id] = Completer<void>()).future;
    });

    for (final id in ['a', 'b', 'c']) {
      queue().enqueue(taskId: _taskId, candidate: _candidate(id));
    }
    expect(container.read(inferenceBackfillQueueProvider), {
      'imageAnalysis:a',
      'imageAnalysis:b',
      'imageAnalysis:c',
    });

    await pumpEventQueue();
    expect(started, ['a'], reason: 'b and c wait for a');

    releases['a']!.complete();
    await pumpEventQueue();
    expect(started, ['a', 'b']);
    expect(container.read(inferenceBackfillQueueProvider), {
      'imageAnalysis:b',
      'imageAnalysis:c',
    });

    releases['b']!.complete();
    await pumpEventQueue();
    releases['c']!.complete();
    await queue().idle;

    expect(started, ['a', 'b', 'c']);
    expect(container.read(inferenceBackfillQueueProvider), isEmpty);
  });

  test('accepting a queued suggestion again does not run it twice', () async {
    expect(
      queue().enqueue(taskId: _taskId, candidate: _candidate('img')),
      isTrue,
    );
    expect(
      queue().enqueue(taskId: _taskId, candidate: _candidate('img')),
      isFalse,
    );
    await queue().idle;

    verify(
      () => runner.runImageAnalysis(
        imageEntryId: 'img',
        automationResult: any(named: 'automationResult'),
        linkedTaskId: _taskId,
      ),
    ).called(1);
  });

  test(
    'resolves the model when the job runs, not when it was accepted',
    () async {
      final first = Completer<void>();
      when(
        () => runner.runImageAnalysis(
          imageEntryId: 'a',
          automationResult: any(named: 'automationResult'),
          linkedTaskId: _taskId,
        ),
      ).thenAnswer((_) => first.future);

      queue()
        ..enqueue(taskId: _taskId, candidate: _candidate('a'))
        ..enqueue(taskId: _taskId, candidate: _candidate('b'));
      await pumpEventQueue();

      // The task's profile changes while b waits its turn.
      final switched = _handled('new-vision-model');
      when(
        () => automation.tryAnalyzeImage(subjectId: _taskId),
      ).thenAnswer((_) async => switched);
      first.complete();
      await queue().idle;

      verify(
        () => runner.runImageAnalysis(
          imageEntryId: 'b',
          automationResult: switched,
          linkedTaskId: _taskId,
        ),
      ).called(1);
    },
  );

  for (final (kind, runningType) in [
    (InferenceBackfillKind.imageAnalysis, AiResponseType.imageAnalysis),
    (InferenceBackfillKind.transcription, AiResponseType.audioTranscription),
    (InferenceBackfillKind.audioSummary, AiResponseType.audioTranscription),
  ]) {
    test('skips ${kind.name} while ${runningType.name} is already running for '
        'the entry', () async {
      final status = (id: 'entry', aiResponseType: runningType);
      final keepAlive = container.listen(
        inferenceStatusControllerProvider(status),
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      container
          .read(inferenceStatusControllerProvider(status).notifier)
          .setStatus(InferenceStatus.running);

      queue().enqueue(taskId: _taskId, candidate: _candidate('entry', kind));
      await queue().idle;

      verifySkipped('already running');
      verifyNever(() => detector.isStillMissing(any()));
      expect(container.read(inferenceBackfillQueueProvider), isEmpty);
    });
  }

  test('skips an entry whose inference landed after it was offered', () async {
    when(() => detector.isStillMissing(any())).thenAnswer((_) async => false);

    queue().enqueue(taskId: _taskId, candidate: _candidate('img'));
    await queue().idle;

    verifySkipped('no longer missing');
    verifyNever(
      () => automation.tryAnalyzeImage(subjectId: any(named: 'subjectId')),
    );
  });

  test('runs nothing once automation stops handling it — e.g. the category '
      'switched automatic inference off', () async {
    when(
      () => automation.tryAnalyzeImage(subjectId: _taskId),
    ).thenAnswer((_) async => AutomationResult.notHandled);

    queue().enqueue(taskId: _taskId, candidate: _candidate('img'));
    await queue().idle;

    verifySkipped('no longer handles it');
    verifyNever(
      () => runner.runImageAnalysis(
        imageEntryId: any(named: 'imageEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    );
  });

  test('a failing job is logged and the queue carries on', () async {
    final failure = StateError('provider down');
    when(
      () => runner.runImageAnalysis(
        imageEntryId: 'a',
        automationResult: any(named: 'automationResult'),
        linkedTaskId: _taskId,
      ),
    ).thenAnswer((_) async => throw failure);

    queue()
      ..enqueue(taskId: _taskId, candidate: _candidate('a'))
      ..enqueue(taskId: _taskId, candidate: _candidate('b'));
    await queue().idle;

    verify(
      () => logger.error(
        LogDomain.ai,
        failure,
        stackTrace: any(named: 'stackTrace', that: isNotNull),
        subDomain: 'inferenceBackfill',
      ),
    ).called(1);
    verify(
      () => runner.runImageAnalysis(
        imageEntryId: 'b',
        automationResult: any(named: 'automationResult'),
        linkedTaskId: _taskId,
      ),
    ).called(1);
    expect(container.read(inferenceBackfillQueueProvider), isEmpty);
  });

  test('inferenceBackfillDetectorProvider scans through the app journal and '
      'automation service', () async {
    final db = MockJournalDb();
    final service = MockProfileAutomationService();
    final wired = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(db),
        profileAutomationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(wired.dispose);
    when(
      () => db.journalEntityById(_taskId),
    ).thenAnswer((_) async => TestTaskFactory.create(id: _taskId));
    when(
      () => db.getLinkedEntities(_taskId),
    ).thenAnswer((_) async => [backfillImage(id: 'img')]);
    when(
      () => db.getBulkLinkedEntities({'img'}),
    ).thenAnswer((_) async => const {});
    when(
      () => service.hasAutomatedSkillType(
        subjectId: _taskId,
        skillType: InferenceBackfillKind.imageAnalysis.skillType,
      ),
    ).thenAnswer((_) async => true);

    final scan = await wired
        .read(inferenceBackfillDetectorProvider)
        .scan(
          _taskId,
        );

    expect(scan.candidates.map((c) => c.entryId), ['img']);
  });
}
