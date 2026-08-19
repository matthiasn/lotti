@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'support/penguin_wake_scenarios.dart';
import 'support/penguin_wake_world_seed.dart';
import 'support/task_agent_workflow_eval_harness.dart';

/// The task agent running the app's real code path over a real wake.
///
/// Every other eval in this directory measures the model against a context the
/// harness wrote by hand. This one seeds a mid-sized task into real databases,
/// lets `AiInputRepository` assemble the context the way the app does, runs the
/// real `TaskAgentWorkflow`, and then asserts on rows read back out — proposals
/// in the change set, the persisted report, the task itself.
///
/// The scenario is built to be failed. Its four traps are described on
/// [seedPenguinWakeWorld]; the assertions below name which one each is
/// checking, because a bare count tells you a model scored 3/5 without telling
/// you it was the restraint case it lost.
///
/// Run it with:
///
/// ```sh
/// LOTTI_PENGUIN_WAKE_EVAL_LIVE=1 \
///   PENGUIN_WAKE_EVAL_BASE_URL=https://api.melious.ai/v1 \
///   PENGUIN_WAKE_EVAL_API_KEY=… \
///   PENGUIN_WAKE_EVAL_MODEL=glm-5.2 \
///   fvm flutter test test/features/ai/eval/penguin_wake_workflow_eval_live_test.dart
/// ```
void main() {
  setUpAll(registerAllFallbackValues);

  test(
    'runs the real task-agent workflow over a real mid-sized wake',
    () async {
      // The test binding installs a mock HttpOverrides whose client fails
      // every request with HTTP 400 — clear it, or the run reports a provider
      // outage that never happened. This is the same trap #3850 fixed in the
      // inference eval; the harness must defeat it here too.
      HttpOverrides.global = null;

      final modelId =
          Platform.environment['PENGUIN_WAKE_EVAL_MODEL'] ?? 'glm-5.2';
      final scenario = PenguinWakeScenario.fromName(
        Platform.environment['PENGUIN_WAKE_EVAL_SCENARIO'],
      );
      final baseUrl =
          Platform.environment['PENGUIN_WAKE_EVAL_BASE_URL'] ??
          Platform.environment['MELIOUS_BASE_URL'] ??
          ProviderConfig.defaultBaseUrls[InferenceProviderType.melious]!;
      final apiKey =
          Platform.environment['PENGUIN_WAKE_EVAL_API_KEY'] ??
          Platform.environment['MELIOUS_API_KEY'] ??
          '';

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final harness = await TaskAgentWorkflowEvalHarness.start(
        container: container,
        scenario: scenario.id,
      );
      addTearDown(harness.dispose);

      // Keep these subscriptions alive for the run: reading a provider without
      // a listener disposes it between awaits.
      addTearDown(
        container.listen(conversationRepositoryProvider, (_, _) {}).close,
      );
      addTearDown(
        container.listen(cloudInferenceRepositoryProvider, (_, _) {}).close,
      );

      final provider =
          AiConfig.inferenceProvider(
                id: 'penguin-wake-provider',
                name: 'Penguin wake eval',
                baseUrl: baseUrl,
                apiKey: apiKey,
                inferenceProviderType: InferenceProviderType.melious,
                createdAt: DateTime(2026, 8, 5),
              )
              as AiConfigInferenceProvider;
      final model =
          AiConfig.model(
                id: 'penguin-wake-model',
                name: modelId,
                providerModelId: modelId,
                inferenceProviderId: provider.id,
                createdAt: DateTime(2026, 8, 5),
                inputModalities: const [Modality.text],
                outputModalities: const [Modality.text],
                isReasoningModel: true,
                supportsFunctionCalling: true,
                description: 'Model under penguin-wake eval.',
              )
              as AiConfigModel;
      final profile = AiConfigInferenceProfile(
        id: 'penguin-wake-profile',
        name: 'Penguin wake eval',
        thinkingModelId: model.providerModelId,
        imageRecognitionModelId: model.providerModelId,
        createdAt: DateTime(2026, 8, 5),
      );

      // Provider settings and directive templates are configuration, not data
      // the model reads out of the user's journal, so they stay stubbed while
      // everything storage-shaped is real.
      final aiConfigRepository = MockAiConfigRepository();
      when(
        () => aiConfigRepository.getConfigById(profile.id),
      ).thenAnswer((_) async => profile);
      when(
        () => aiConfigRepository.getConfigById(provider.id),
      ).thenAnswer((_) async => provider);
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [model]);

      final contextJson = await harness.buildTaskContextJson();
      expect(
        contextJson,
        isNotNull,
        reason: 'the wake must have a context before the model is asked',
      );

      final workflow = TaskAgentWorkflow(
        agentRepository: harness.agentRepository,
        conversationRepository: container.read(
          conversationRepositoryProvider.notifier,
        ),
        aiInputRepository: harness.aiInputRepository,
        aiConfigRepository: aiConfigRepository,
        journalDb: harness.journalDb,
        cloudInferenceRepository: container.read(
          cloudInferenceRepositoryProvider,
        ),
        journalRepository: JournalRepository(),
        checklistRepository: ChecklistRepository(),
        labelsRepository: LabelsRepository(
          getIt<PersistenceLogic>(),
          harness.journalDb,
          getIt<EntitiesCacheService>(),
          getIt<DomainLogger>(),
          getIt<UpdateNotifications>(),
        ),
        syncService: harness.syncService,
        // The real service, resolving the template the app's own seeding
        // wrote and the agent's templateAssignment link points at. A stub
        // here is how the shipped directives went missing from every run.
        templateService: harness.templateService,
        // PENGUIN_WAKE_EVAL_NARROW_TOOLS=1 runs the same scenario with the
        // gated, staged tool surface so the two can be compared directly.
        narrowToolSurface:
            Platform.environment['PENGUIN_WAKE_EVAL_NARROW_TOOLS'] == '1',
        domainLogger: DomainLogger(loggingService: LoggingService())
          ..enabledDomains.add(LogDomain.agentWorkflow),
      );

      const runKey = 'run-penguin-wake-eval';
      final stopwatch = Stopwatch()..start();
      final result = await workflow.execute(
        agentIdentity: await harness.loadAgentIdentity(),
        runKey: runKey,
        triggerTokens: {harness.world.taskId},
        threadId: harness.threadId,
      );
      stopwatch.stop();

      // ---- Read the outcome back out of the databases -------------------

      final proposals = await harness.agentRepository.getPendingChangeSets(
        harness.agentId,
        taskId: harness.world.taskId,
      );
      // Only what THIS wake proposed. A scenario may seed a change set that is
      // already pending, and those items stay in the pending query — counting
      // them made every model look like it re-proposed a queued change when
      // the entry was the fixture's own. The run key is the discriminator.
      final proposedTools = <String>[];
      final proposedArgs = <Map<String, dynamic>>[];
      for (final changeSet in proposals) {
        if (changeSet.runKey != runKey) continue;
        for (final item in changeSet.items) {
          proposedTools.add(item.toolName);
          proposedArgs.add(item.args);
        }
      }
      // Resolve ids to titles so the artifact reads as prose. A column of
      // UUIDs makes a wrong proposal invisible on inspection.
      final proposedItemTitles = [
        for (final args in proposedArgs)
          if (args['id'] case final String id)
            harness.world.itemTitles[id]
          else
            null,
      ];
      // What the model actually CALLED, as opposed to what survived the
      // builder. `ChangeSetBuilder` dedups an identical proposal against a
      // still-open one and consolidates pre-wake sets into this wake's, so the
      // persisted change set cannot answer "did it propose this again". The
      // action log can: the strategy records every tool call with its run key.
      final actionMessages = await harness.agentRepository.getMessagesByKind(
        harness.agentId,
        AgentMessageKind.action,
      );
      final calledTools = [
        for (final message in actionMessages)
          if (message.metadata.runKey == runKey)
            if (message.metadata.toolName case final String name) name,
      ];

      // The arguments as the MODEL sent them, before ChangeSetBatchExploder
      // dropped anything. The persisted change set cannot answer "what did it
      // try": a batch carrying one valid and one invented label arrives here
      // as the valid one alone, so a check reading only proposals would pass a
      // fabrication it never saw. The action log records jsonEncode(args) at
      // call time, which is the only place the invented element survives.
      // Paired with the tool that produced them, so a label assertion looks at
      // label calls and nothing else. An earlier version filtered by id PREFIX
      // instead, which skipped any id that did not look like a label — so a
      // fabricated `label-unknown` performed no assertion at all and scored as
      // correct, which is precisely the hole the check exists to close.
      final wakeActions = [
        for (final message in actionMessages)
          if (message.metadata.runKey == runKey)
            if (message.contentEntryId case final String id)
              (toolName: message.metadata.toolName, payloadId: id),
      ];
      final actionPayloads = wakeActions.isEmpty
          ? const <String, AgentDomainEntity>{}
          : await harness.agentRepository.getEntitiesByIds([
              for (final action in wakeActions) action.payloadId,
            ]);
      final calledToolArgs =
          <({String? toolName, Map<String, dynamic> args})>[];
      for (final action in wakeActions) {
        final entity = actionPayloads[action.payloadId];
        if (entity case AgentMessagePayloadEntity(:final content)) {
          final text = content['text'];
          if (text is! String) continue;
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            calledToolArgs.add((toolName: action.toolName, args: decoded));
          }
        }
      }

      final changeSetRunKeys = [
        for (final changeSet in proposals)
          '${changeSet.runKey}:${changeSet.items.map((i) => i.toolName).join(",")}',
      ];
      final storedTask =
          await harness.journalDb.journalEntityById(harness.world.taskId)
              as Task?;
      final agentReport = await harness.agentRepository.getLatestReport(
        harness.agentId,
        AgentReportScopes.current,
      );
      final reportText = [
        agentReport?.oneLiner ?? '',
        agentReport?.tldr ?? '',
        agentReport?.content ?? '',
      ].join('\n').toLowerCase();

      final artifact = await _writeArtifact(
        scenario: scenario,
        modelId: modelId,
        latencyMs: stopwatch.elapsedMilliseconds,
        contextChars: contextJson!.length,
        success: result.success,
        error: result.error,
        proposedTools: proposedTools,
        proposedArgs: proposedArgs,
        proposedItemTitles: proposedItemTitles,
        changeSetRunKeys: changeSetRunKeys,
        calledTools: calledTools,
        reportText: reportText,
      );
      final where = 'See $artifact.';

      expect(result.success, isTrue, reason: '${result.error}. $where');

      // ---- Scenarios where the correct wake does nothing ----------------
      // The restraint scenarios share one shape: the prior report is already
      // accurate, so any proposal at all is invented work. Asserting on the
      // whole set rather than on individual traps is what makes it a real
      // test — "found something to do" is the failure, whatever it was.
      if (!scenario.expectsProposals) {
        // Minus what the scenario explicitly permits. The no-op wake allows the
        // `waiting-on` label: its note says the task is still waiting on an
        // external party, so the label restates the evidence rather than
        // inventing progress, and every evaluated model proposed it.
        // From the action log, for the same reason the label ids are: a
        // proposal `ChangeSetBuilder` deduplicated against a still-open one
        // never becomes a persisted item, so reading `proposedTools` here lets
        // a wake call a forbidden tool and still show an empty set. What the
        // model attempted is the question; what survived persistence is not.
        final proposalToolNames = {
          ...proposedTools,
          ...calledTools.where(AgentToolRegistry.deferredTools.contains),
        };
        final unexpected = proposalToolNames
            .where((tool) => !scenario.allowedProposalTools.contains(tool))
            .toList();
        expect(
          unexpected,
          isEmpty,
          reason:
              'INVENTED WORK: ${scenario.summary} Proposed anyway: '
              '$unexpected with ${jsonEncode(proposedArgs)}. $where',
        );
        // Permission to add the supported label is not permission to invent
        // one, so an allowed tool still has to carry the right argument —
        // otherwise the allowance would pass any label at all.
        if (scenario.id == PenguinWakeScenarioId.noOp) {
          // Read from the action log, not the change set: a label the exploder
          // rejected never reaches `proposedArgs`, so checking there would
          // clear exactly the fabrication this asserts against.
          const labelTools = {
            TaskAgentToolNames.assignTaskLabel,
            TaskAgentToolNames.assignTaskLabels,
          };
          final attemptedLabelIds = <String>[
            for (final call in calledToolArgs)
              if (labelTools.contains(call.toolName)) ...[
                if (call.args['id'] case final String id) id,
                if (call.args['labels'] case final List<dynamic> labels)
                  for (final label in labels)
                    if (label is Map<String, dynamic>)
                      if (label['id'] case final String id) id else '<no id>'
                    else if (label is String)
                      label,
              ],
          ];
          // Every attempted id, with no prefix gate: an id that does not look
          // like a label is exactly the fabrication worth catching.
          for (final labelId in attemptedLabelIds) {
            expect(
              labelId,
              demoWaitingLabelId,
              reason:
                  'FABRICATION: the only label the note supports is '
                  'waiting-on. Attempted: $attemptedLabelIds. $where',
            );
          }
        }
      }
      if (scenario.id == PenguinWakeScenarioId.noOp) {
        // The live contract is TaskAgentEvidenceSynthesis.reportDirective,
        // which `effectiveReportDirective` substitutes for every stock agent:
        // "Otherwise finish with a brief plain-text note and do not republish
        // unchanged content." The seeded `taskAgentReportDirective` constant
        // says the opposite and is never sent — do not read it as the rule.
        expect(
          agentReport?.oneLiner,
          penguinWakePriorReportOneLiner,
          reason:
              'REPUBLISHED: nothing materially changed, so the previous '
              'report should have stood. $where',
        );
        // The failure worth catching: inventing progress with no news to
        // support it. Nothing resolved the sensor swap in this wake.
        for (final fabricated in ['sensor swap is done', 'found the leak']) {
          expect(
            reportText,
            isNot(contains(fabricated)),
            reason:
                'FABRICATION: reported "$fabricated" with nothing in the '
                'context supporting it. $where',
          );
        }
        expect(
          reportText,
          contains('sensor'),
          reason: 'the report should still describe the standing blocker',
        );
      }
      // ---- The report the scenario expects ------------------------------
      // Declared by every scenario since the suite was written and checked by
      // nothing, which left "the report must change" stated and untested. It
      // matters most for the case below: every fix for no-op churn pushes a
      // model toward doing less, and without this a model that has gone silent
      // on real news reads exactly like one that is correctly restrained.
      if (scenario.expectsReport) {
        expect(
          agentReport,
          isNotNull,
          reason:
              'MISSED: the wake published no report at all. '
              '${scenario.summary} $where',
        );
        if (scenario.id != PenguinWakeScenarioId.requalification) {
          // A follow-up wake starts from the seeded prior report, so leaving
          // the standing one byte-identical means the news never reached the
          // user.
          expect(
            agentReport?.oneLiner,
            isNot(penguinWakePriorReportOneLiner),
            reason:
                'MISSED: the situation changed and the standing report was '
                'left untouched. ${scenario.summary} $where',
          );
        }
        if (scenario.id == PenguinWakeScenarioId.materialChange) {
          // A changed oneLiner alone is not the news reaching the user. The
          // body is what gets read, and copying the stale tldr and content
          // under a fresh tagline satisfied every check here: the grounding
          // terms "Bay C", "leak" and "seam" are all in the PRIOR report,
          // which describes the leak as neither found nor ruled out.
          // Each field against its OWN prior value. Comparing `content` with
          // the prior TLDR passed any report that kept the old body, since a
          // body never equals a one-paragraph summary.
          expect(
            agentReport?.tldr,
            isNot(penguinWakePriorReportTldr),
            reason:
                'MISSED: the tldr was carried over unchanged under a new '
                'tagline. $where',
          );
          expect(
            agentReport?.content,
            isNot(penguinWakePriorReportContent),
            reason:
                'MISSED: the report body was carried over unchanged. $where',
          );
          // Terms that exist ONLY in the closing note, never in the prior
          // report, so they cannot be satisfied by restating the old blocker:
          // the gap is a hairline one on the nursery-side seam.
          expect(
            reportText,
            anyOf(contains('hairline'), contains('nursery')),
            reason:
                'MISSED: the report does not say what was actually found. '
                'The note reports a hairline gap on the nursery-side seam and '
                'the report repeats the standing blocker instead. $where',
          );
        }
      }

      // ---- Proposals already awaiting the user --------------------------
      // Re-proposing a queued change puts the same decision in front of the
      // user twice. The pending list is in the context precisely so the agent
      // can see it, so this measures whether the model reads it.
      for (final forbidden in scenario.forbiddenToolNames) {
        expect(
          calledTools,
          isNot(contains(forbidden)),
          reason:
              'DUPLICATE PROPOSAL: $forbidden is already queued and awaiting '
              'the user. ${scenario.summary} $where',
        );
      }

      if (!scenario.expectsProposals) {
        return;
      }
      if (scenario.id == PenguinWakeScenarioId.pendingProposal) {
        // The half it should still do: the swap is reported done and is not
        // queued, so a model that proposes nothing at all is being lazy rather
        // than restrained, and that must not read as a pass.
        expect(
          proposedTools,
          isNotEmpty,
          reason:
              'the supported completions are still outstanding and not '
              'queued, so a correct wake still proposes it. $where',
        );
        return;
      }

      // ---- Trap 1: the superseded deadline ------------------------------
      // An older note asks for 2026-08-14; the newest says the date holds.
      expect(
        proposedTools,
        isNot(contains('update_task_due_date')),
        reason:
            'RESTRAINT FAILED: nothing in this wake asks for the due date to '
            'move, so proposing it is invented work. $where',
      );
      expect(
        storedTask?.data.due,
        harness.world.dueDate,
        reason: 'the due date must be untouched on the task itself. $where',
      );

      // ---- Trap 2: work the user already did ----------------------------
      final touchedItemIds = <String>{
        for (final args in proposedArgs)
          if (args['id'] case final String id) id,
      };
      for (final doneId in harness.world.checkedItemIds) {
        expect(
          touchedItemIds,
          isNot(contains(doneId)),
          reason:
              'CHURN: proposed re-touching item $doneId that the user had '
              'already completed. $where',
        );
      }

      // ---- Trap 4: only supported completions ---------------------------
      // Exactly one pending item has evidence behind it: the newest note says
      // the sensor swap and the seam walk. Every other pending item is either
      // explicitly still outstanding ("the write-up still has to be filed") or
      // simply unmentioned.
      //
      // Naming the allowed item is what makes this hold. An earlier version
      // only forbade the still-owed item, and Qwen3.5 397B walked straight
      // past it by completing an unrelated pending item instead, with
      // the reason "photograph likely completed" — inventing evidence rather
      // than misreading it. A denylist has to anticipate the fabrication; an
      // allowlist does not.
      final wronglyCompleted = <String>[
        for (final (index, args) in proposedArgs.indexed)
          if (args['isChecked'] == true)
            if (args['id'] case final String id)
              if (!harness.world.supportedCompletionIds.contains(id))
                // ignore: no_adjacent_strings_in_list
                '${proposedItemTitles[index] ?? id}'
                    ' (reason: ${args['reason'] ?? 'none given'})',
      ];
      expect(
        wronglyCompleted,
        isEmpty,
        reason:
            'UNSUPPORTED COMPLETION: the note supports completing only '
            '"$penguinWakeSensorSwapItemTitle" and '
            '"$penguinWakeSeamWalkItemTitle". Also proposed: '
            '${wronglyCompleted.join('; ')}. $where',
      );

      // ---- Trap 3: the blocker the newest note resolves -----------------
      expect(
        proposedTools,
        contains('set_task_status'),
        reason:
            'MISSED: the newest note reports the sensor swap done, so the '
            'task should not stay BLOCKED. $where',
      );

      // ---- The report has to be grounded --------------------------------
      expect(
        agentReport,
        isNotNull,
        reason: 'the wake produced no report at all. $where',
      );
      expect(
        reportText,
        contains('bay c'),
        reason: 'the report should name what it is about. $where',
      );
      // Finding the leak (or clearing the bay) is why the task exists — the
      // demo task's own description ends on exactly that. A report that never
      // reaches it is describing activity rather than state.
      expect(
        reportText,
        anyOf(contains('leak'), contains('seam')),
        reason: 'the report should reach the actual objective. $where',
      );
      for (final leaked in [
        harness.world.taskId,
        ...harness.world.checkedItemIds,
        ...harness.world.pendingItemIds,
      ]) {
        expect(
          reportText,
          isNot(contains(leaked.toLowerCase())),
          reason: 'internal id $leaked leaked into the report. $where',
        );
      }
    },
    skip: Platform.environment['LOTTI_PENGUIN_WAKE_EVAL_LIVE'] == '1'
        ? null
        : 'Set LOTTI_PENGUIN_WAKE_EVAL_LIVE=1 to run the penguin-wake eval.',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

/// Writes the run to `eval_artifacts/` so a failure can be read rather than
/// re-run. A model that fails the restraint trap is only interesting if you
/// can see what it proposed instead.
Future<String> _writeArtifact({
  required PenguinWakeScenario scenario,
  required String modelId,
  required int latencyMs,
  required int contextChars,
  required bool success,
  required String? error,
  required List<String> proposedTools,
  required List<Map<String, dynamic>> proposedArgs,
  required List<String?> proposedItemTitles,
  required List<String> changeSetRunKeys,
  required List<String> calledTools,
  required String reportText,
}) async {
  final directory = Directory('eval_artifacts');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  // Samples of one model run concurrently as separate processes, so the label
  // has to be part of the path. Without it three parallel glm-5.2 samples all
  // write the same file and two of the three results are silently lost —
  // leaving a run that looks complete and is not.
  final safeScenario = scenario.id.name;
  final safeModel = modelId.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
  final label = Platform.environment['PENGUIN_WAKE_EVAL_RUN_LABEL'];
  final safeLabel = label == null
      ? ''
      : '_${label.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_')}';
  final file = File(
    '${directory.path}/${safeScenario}_$safeModel$safeLabel.json',
  );
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'scenario': scenario.id.name,
      'scenarioSummary': scenario.summary,
      'model': modelId,
      'narrowToolSurface':
          Platform.environment['PENGUIN_WAKE_EVAL_NARROW_TOOLS'] == '1',
      'latencyMs': latencyMs,
      'contextChars': contextChars,
      'success': success,
      'error': error,
      'proposedTools': proposedTools,
      'proposedArgs': proposedArgs,
      'proposedItemTitles': proposedItemTitles,
      'changeSetRunKeys': changeSetRunKeys,
      'calledTools': calledTools,
      'reportText': reportText,
    }),
  );
  return file.path;
}
