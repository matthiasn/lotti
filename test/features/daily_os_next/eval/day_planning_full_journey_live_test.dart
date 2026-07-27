@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';

import '../../../helpers/fallbacks.dart';
import '../../../widget_test_utils.dart';
import '../../ai_consumption/test_utils.dart';
import '../integration/day_agent_journey_support.dart';
import '../integration/day_agent_pipeline_harness.dart';
import '../integration/realistic_day_planning_scenarios.dart';
import 'framework/eval_models.dart';
import 'framework/eval_runner.dart';
import 'framework/eval_scenario.dart';
import 'framework/eval_test_setup.dart';

/// Runs the user-facing capture -> parse -> selection -> draft journey and the
/// coordinator's follow-up digest against live Melious models.
///
/// Unlike the drafting-only live matrix, this intentionally does not seed
/// a parsed capture or a coordinator directive. It measures the expensive,
/// multi-agent path the user actually waits for, including durable outbox
/// scheduling. Model-quality findings are reported rather than asserted.
///
/// ```sh
/// set -a; source .env; set +a
/// LOTTI_DAY_PLANNING_FULL_JOURNEY_LIVE=1 \
/// DAY_PLANNING_EVAL_MODELS=glm-5.2,qwen3.5-397b-a17b \
///   fvm flutter test \
///   test/features/daily_os_next/eval/day_planning_full_journey_live_test.dart
/// ```
void main() {
  setUpAll(registerAllFallbackValues);

  final environment = Platform.environment;
  final live = environment['LOTTI_DAY_PLANNING_FULL_JOURNEY_LIVE'] == '1';
  final modelIds = _csv(
    environment['DAY_PLANNING_EVAL_MODELS'],
    'glm-5.2',
  );
  final scenarioIds = _csv(
    environment['DAY_PLANNING_EVAL_SCENARIOS'],
    '',
  );
  final scenarios = scenarioIds.isEmpty
      ? realisticDayPlanningScenarios
      : [
          for (final scenario in realisticDayPlanningScenarios)
            if (scenarioIds.contains(scenario.id)) scenario,
        ];
  final unknownScenarioIds = [
    for (final id in scenarioIds)
      if (!realisticDayPlanningScenarios.any(
        (scenario) => scenario.id == id,
      ))
        id,
  ];

  test(
    'reports realistic live capture, planning, and coordinator journeys',
    () async {
      if (unknownScenarioIds.isNotEmpty) {
        fail(
          'DAY_PLANNING_EVAL_SCENARIOS names unknown scenario(s): '
          '${unknownScenarioIds.join(', ')}.',
        );
      }
      final validatedScenarios =
          <({EvalScenario scenario, int startHour, String transcript})>[];
      for (final scenario in scenarios) {
        final startHour = scenario.startHour;
        if (startHour == null) {
          fail(
            'Full-journey scenario "${scenario.id}" must define startHour.',
          );
        }
        final transcript = scenario.captureTranscript;
        if (transcript == null || transcript.trim().isEmpty) {
          fail(
            'Full-journey scenario "${scenario.id}" must define a non-empty '
            'captureTranscript.',
          );
        }
        validatedScenarios.add((
          scenario: scenario,
          startHour: startHour,
          transcript: transcript,
        ));
      }
      final apiKey = environment['MELIOUS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'MELIOUS_API_KEY is not set — source .env before running the live '
          'full-journey eval.',
        );
      }

      final attribution = AiInteractionCaptureTestBench.create();
      await setUpEvalGetIt(attribution);
      addTearDown(tearDownTestGetIt);
      HttpOverrides.global = null;

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final conversationSubscription = container.listen(
        conversationRepositoryProvider,
        (_, _) {},
      );
      addTearDown(conversationSubscription.close);
      final cloudSubscription = container.listen(
        cloudInferenceRepositoryProvider,
        (_, _) {},
      );
      addTearDown(cloudSubscription.close);

      final provider =
          AiConfig.inferenceProvider(
                id: 'provider-day-planning-full-journey',
                name: 'Melious (day-planning full journey)',
                baseUrl:
                    environment['MELIOUS_BASE_URL'] ??
                    ProviderConfig.defaultBaseUrls[InferenceProviderType
                        .melious]!,
                apiKey: apiKey,
                inferenceProviderType: InferenceProviderType.melious,
                createdAt: DateTime(2026, 7, 27),
              )
              as AiConfigInferenceProvider;
      final reports = <Map<String, Object?>>[];

      for (final modelId in modelIds) {
        final profile = AiConfigInferenceProfile(
          id: 'profile-full-journey-$modelId',
          name: 'Day-planning full journey ($modelId)',
          thinkingModelId: modelId,
          createdAt: DateTime(2026, 7, 27),
        );
        final model =
            AiConfig.model(
                  id: 'model-full-journey-$modelId',
                  name: modelId,
                  providerModelId: modelId,
                  inferenceProviderId: provider.id,
                  createdAt: DateTime(2026, 7, 27),
                  inputModalities: const [Modality.text],
                  outputModalities: const [Modality.text],
                  isReasoningModel: true,
                  supportsFunctionCalling: true,
                  description: 'Model under the full-journey planning eval.',
                )
                as AiConfigModel;

        for (final journey in validatedScenarios) {
          final scenario = journey.scenario;
          final realNow = DateTime.now();
          final anchoredAt = DateTime(
            realNow.year,
            realNow.month,
            realNow.day,
            journey.startHour,
          );
          final runningClock = Stopwatch()..start();
          final report = await withClock(
            Clock(() => anchoredAt.add(runningClock.elapsed)),
            () => _runJourney(
              scenario: scenario,
              captureTranscript: journey.transcript,
              modelId: modelId,
              conversationRepository: container.read(
                conversationRepositoryProvider.notifier,
              ),
              cloudInferenceRepository: container.read(
                cloudInferenceRepositoryProvider,
              ),
              profile: profile,
              model: model,
              provider: provider,
              attribution: attribution,
            ),
          );
          reports.add(report);
          debugPrint(
            '${report['scenarioId']}/$modelId: '
            '${report['totalLatencyMs']}ms total, '
            '${report['parsedItemCount']} parsed, '
            '${report['planBlockCount']} planned, '
            '${report['error'] ?? 'completed'}',
          );
        }
      }

      final outputDirectory = Directory(
        environment['DAY_PLANNING_EVAL_DIR'] ?? 'tmp/day-planning-eval',
      )..createSync(recursive: true);
      final timestamp = DateTime.now().toIso8601String().replaceAll(
        RegExp('[:.]'),
        '-',
      );
      final output =
          File(
            '${outputDirectory.path}/full-journey-$timestamp.json',
          )..writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert({
              'generatedAt': DateTime.now().toIso8601String(),
              'provider': 'melious',
              'runs': reports,
            }),
          );
      debugPrint('day-planning full-journey report: ${output.path}');
    },
    skip: live
        ? null
        : 'Set LOTTI_DAY_PLANNING_FULL_JOURNEY_LIVE=1 and source Melious '
              'credentials to run.',
    timeout: Timeout(
      Duration(minutes: 12 * scenarios.length * modelIds.length + 10),
    ),
  );
}

Future<Map<String, Object?>> _runJourney({
  required EvalScenario scenario,
  required String captureTranscript,
  required String modelId,
  required ConversationRepository conversationRepository,
  required CloudInferenceRepository cloudInferenceRepository,
  required AiConfigInferenceProfile profile,
  required AiConfigModel model,
  required AiConfigInferenceProvider provider,
  required AiInteractionCaptureTestBench attribution,
}) async {
  final total = Stopwatch()..start();
  final parse = Stopwatch();
  final draft = Stopwatch();
  final digest = Stopwatch();
  final recorder = EvalPromptRecorder(conversationRepository);
  final planDate = DateTime(
    clock.now().year,
    clock.now().month,
    clock.now().day,
  );
  final dayId = dayAgentIdForDate(planDate);
  DayAgentPipelineHarness? harness;
  DayProcessingJob? parseJob;
  var parsedItems = const <ParsedItem>[];
  var plan = DraftPlan.emptyForDay(planDate);
  Object? error;
  attribution.clearRecordedInteractions();

  try {
    harness = DayAgentPipelineHarness.create(
      now: clock.now(),
      conversationRepository: recorder,
      cloudInferenceRepository: cloudInferenceRepository,
      profile: profile,
      model: model,
      provider: provider,
      dependencyResolver: EvalFixtureDependencyResolver(
        scenario.blockedStatus,
      ),
      config: DayAgentConfig(
        capacityMinutes: scenario.capacityMinutes,
        workingHoursStart: '08:00',
        workingHoursEnd: '18:00',
      ),
      logToStdout: true,
    );
    seedScenarioCorpus(
      journalDb: harness.journalDb,
      scenario: scenario,
      planDate: planDate,
      journalRepository: harness.journalRepository,
    );

    parse.start();
    final captureId = await harness.realDayAgent.submitCapture(
      transcript: captureTranscript,
      capturedAt: clock.now(),
      dayDate: planDate,
    );
    parseJob = await waitForTerminalDayProcessingJob(
      harness.outbox,
      DayProcessingOutboxRepository.parseJobId(captureId.value),
    );
    parsedItems = await harness.realDayAgent.parseCaptureToItems(captureId);
    parse.stop();

    final decidedTaskIds = [
      for (final item in parsedItems) ?item.matchedTaskId,
    ];
    final decidedCaptureItemIds = [
      for (final item in parsedItems)
        if (item.matchedTaskId == null) item.id,
    ];

    draft.start();
    plan = await harness.realDayAgent.draftDayPlan(
      captureId: captureId,
      decidedTaskIds: decidedTaskIds,
      decidedCaptureItemIds: decidedCaptureItemIds,
      dayDate: planDate,
    );
    draft.stop();

    final coordinator = await harness.dayAgentService.getOrCreatePlannerAgent();
    digest.start();
    await runPlannerDigest(
      harness: harness,
      coordinator: coordinator,
      dayId: dayId,
    );
    digest.stop();
  } catch (caught) {
    error = caught;
    if (parse.isRunning) parse.stop();
    if (draft.isRunning) draft.stop();
    if (digest.isRunning) digest.stop();
  } finally {
    total.stop();
  }

  final expectedIds = scenario.decidedTaskIds;
  final matchedIds = {
    for (final item in parsedItems) ?item.matchedTaskId,
  };
  final plannedTaskIds = {
    for (final block in plan.blocks) ?block.taskId,
  };
  final statusEvents = harness == null
      ? const <DayStatusEventEntity>[]
      : await harness.agentRepository.getDayStatusEventsSince(DateTime(2020));
  final draftJob = harness == null
      ? null
      : await harness.outbox.getById(
          DayProcessingOutboxRepository.draftJobId(dayId),
        );
  final toolCalls = harness == null
      ? const <EvalToolCall>[]
      : evalToolCallsFrom(harness.agentRepository.entities);
  final result = <String, Object?>{
    'scenarioId': scenario.id,
    'intent': scenario.intent,
    'modelId': modelId,
    'totalLatencyMs': total.elapsedMilliseconds,
    'userVisibleLatencyMs':
        parse.elapsedMilliseconds + draft.elapsedMilliseconds,
    'parseLatencyMs': parse.elapsedMilliseconds,
    'draftLatencyMs': draft.elapsedMilliseconds,
    'plannerDigestLatencyMs': digest.elapsedMilliseconds,
    'parseJobStatus': parseJob?.status.name,
    'parseJobAttempts': parseJob?.attempts,
    'draftJobStatus': draftJob?.status.name,
    'draftJobAttempts': draftJob?.attempts,
    'parsedItemCount': parsedItems.length,
    'parsedItems': [
      for (final item in parsedItems)
        {
          'id': item.id,
          'kind': item.kind.name,
          'title': item.title,
          'spokenPhrase': item.spokenPhrase,
          'matchedTaskId': item.matchedTaskId,
          'timeAnchor': item.timeAnchor,
        },
    ],
    'expectedMentionedTaskIds': expectedIds,
    'missingExpectedMatches': [
      for (final id in expectedIds)
        if (!matchedIds.contains(id)) id,
    ],
    'planBlockCount': plan.blocks.length,
    'plannedTaskIds': plannedTaskIds.toList()..sort(),
    'selectedMatchedTaskIdsNotPlaced': [
      for (final id in matchedIds)
        if (!plannedTaskIds.contains(id)) id,
    ],
    'statusEvents': [
      for (final event in statusEvents)
        {
          'status': event.status.name,
          'reasons': event.reasons.map((reason) => reason.name).toList(),
          'note': event.note,
        },
    ],
    'wakes': [
      for (final wake in recorder.wakes)
        {
          'conversationId': wake.conversationId,
          'messages': wake.userMessages.length,
          'forcedRetry': wake.forcedRetry,
          'roles': [
            for (final message in wake.userMessages) _messageRole(message),
          ],
        },
    ],
    'providerInteractions': attribution.recordedInteractions.length,
    'toolCalls': [
      for (final call in toolCalls)
        {
          'name': call.name,
          'accepted': call.accepted,
          'rejectionMessage': call.rejectionMessage,
        },
    ],
    'error': error?.toString(),
  };
  try {
    await harness?.dispose();
  } catch (disposeError) {
    result['disposeError'] = disposeError.toString();
  }
  return result;
}

String _messageRole(String message) {
  if (message.contains('<digest>')) return 'plannerDigest';
  if (message.contains('<drafting>')) return 'dayDraft';
  if (message.contains('<capture>')) return 'captureParse';
  return 'other';
}

List<String> _csv(String? raw, String fallback) => (raw ?? fallback)
    .split(',')
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList();
