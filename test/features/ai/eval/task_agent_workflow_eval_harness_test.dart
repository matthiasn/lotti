import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/seeded_directive_content.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_prompt_builder.dart';

import '../../../helpers/fallbacks.dart';
import 'support/penguin_wake_scenarios.dart';
import 'support/penguin_wake_world_seed.dart';
import 'support/task_agent_workflow_eval_harness.dart';

/// Covers the real-database eval harness without needing a provider.
///
/// The live workflow eval is tagged `eval-live` and never runs in CI, so
/// without this the seeding, the GetIt wiring and the real context builder
/// would only ever be exercised by hand. A break in any of them would surface
/// as a confusing live-run failure attributed to the model.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);

  late ProviderContainer container;
  late TaskAgentWorkflowEvalHarness harness;

  setUp(() async {
    container = ProviderContainer();
    harness = await TaskAgentWorkflowEvalHarness.start(container: container);
  });

  tearDown(() async {
    await harness.dispose();
    container.dispose();
  });

  group('TaskAgentWorkflowEvalHarness', () {
    test(
      'seeds the wake task with its full checklist into a real db',
      () async {
        final stored = await harness.journalDb.journalEntityById(
          harness.world.taskId,
        );

        expect(stored, isA<Task>());
        final task = stored! as Task;
        expect(task.data.status, isA<TaskBlocked>());
        expect(task.data.due, harness.world.dueDate);
        // The demo task's own checklist: four items, one already done.
        expect(task.data.checklistIds, hasLength(1));
        expect(harness.world.checkedItemIds, hasLength(1));
        expect(harness.world.pendingItemIds, hasLength(3));
        // Demo labels must survive into the world the wake reads.
        expect(harness.world.labelIds, hasLength(2));
      },
    );

    test(
      'links every note to the task so the context can reach them',
      () async {
        final linked = await harness.journalDb.getLinkedEntities(
          harness.world.taskId,
        );
        final linkedIds = linked.map((entity) => entity.meta.id).toSet();

        for (final noteId in harness.world.noteIds) {
          expect(
            linkedIds,
            contains(noteId),
            reason: 'note $noteId must be reachable from the task',
          );
        }
      },
    );

    test('the real context builder produces a mid-sized wake', () async {
      final context = await harness.buildTaskContextJson();

      expect(context, isNotNull);
      final json = context!;

      // The whole point of the harness. The hand-written fixture it replaces
      // was 921-2,207 characters with an empty checklist; a real wake carries
      // the description, three checklists and three weeks of notes.
      // Measured at 9,004 characters against the 921-2,207 the synthetic
      // scenarios carry. The floor is what matters: if a change to the context
      // builder quietly drops the checklists or the linked notes, the suite
      // goes back to measuring models on a quarter of a real wake without
      // anyone noticing.
      expect(
        json.length,
        greaterThan(2500),
        reason: 'a real context should dwarf the old hand-written fixture',
      );

      // Built, not declared: these strings exist only in the seeded rows.
      expect(json, contains('Bay C'));
      expect(
        json,
        contains(penguinWakeSeamWalkItemTitle),
        reason: 'checklist items must reach the model through the real builder',
      );
      // The label path only runs with a real EntitiesCacheService; a mocked one
      // resolves every label to null and the model never sees one.
      expect(
        json,
        anyOf(contains('Habitat critical'), contains('Blocked')),
        reason: 'demo labels must resolve into the context',
      );
    });

    test('the context carries the contradiction the wake turns on', () async {
      final json = (await harness.buildTaskContextJson())!;

      // The superseded request and the instruction that overrides it must both
      // be present, or the restraint trap tests nothing.
      expect(
        json,
        contains('Sensor swap is done'),
        reason: 'the unblocking instruction must be visible',
      );
      expect(
        json,
        contains('still has to be filed'),
        reason: 'the outstanding-work clause must be visible',
      );
    });

    test('the no-op scenario seeds a wake with nothing to do', () async {
      // Built separately: the default harness in setUp is the unblocking
      // scenario, and the no-op world has to be the state before it.
      final noOpContainer = ProviderContainer();
      addTearDown(noOpContainer.dispose);
      await harness.dispose();
      final noOp = await TaskAgentWorkflowEvalHarness.start(
        container: noOpContainer,
        scenario: PenguinWakeScenarioId.noOp,
      );
      addTearDown(noOp.dispose);

      final json = (await noOp.buildTaskContextJson())!;

      // The prior report must reach the model, or the wake reads as a first
      // wake and writing a report becomes correct rather than churn.
      final priorReport = await noOp.agentRepository.getLatestReport(
        noOp.agentId,
        AgentReportScopes.current,
      );
      expect(
        priorReport?.oneLiner,
        penguinWakePriorReportOneLiner,
        reason: 'the no-op wake must be a follow-up, not a first wake',
      );

      // The sensor swap must still be outstanding, or the world contradicts
      // that report and the model is right to act.
      expect(
        json,
        contains('Still no date from the parts store'),
        reason: 'the closing note must be the one that reports nothing new',
      );
      expect(
        json,
        isNot(contains('Sensor swap is done')),
        reason: 'the unblocking instruction must not leak into the no-op wake',
      );
      expect(
        noOp.scenario.expectsProposals,
        isFalse,
        reason: 'a correct no-op wake proposes nothing',
      );

      // Re-seed the default world so tearDown has a live harness to dispose.
      harness = await TaskAgentWorkflowEvalHarness.start(container: container);
    });

    test('the pending-proposal scenario queues a real change set', () async {
      final pendingContainer = ProviderContainer();
      addTearDown(pendingContainer.dispose);
      await harness.dispose();
      final pending = await TaskAgentWorkflowEvalHarness.start(
        container: pendingContainer,
        scenario: PenguinWakeScenarioId.pendingProposal,
      );
      addTearDown(pending.dispose);

      final changeSets = await pending.agentRepository.getPendingChangeSets(
        pending.agentId,
        taskId: pending.world.taskId,
      );
      final queued = changeSets.expand((set) => set.items).toList();

      expect(
        queued.map((item) => item.toolName),
        [TaskAgentToolNames.setTaskStatus],
        reason: 'exactly the status change is queued, nothing else',
      );
      expect(
        pending.scenario.forbiddenToolNames,
        contains(TaskAgentToolNames.setTaskStatus),
        reason: 'the queued tool is the one a correct wake must not repeat',
      );
      // The other half must remain genuinely open, or "propose nothing" would
      // be a correct wake and the scenario could not tell restraint from
      // laziness.
      expect(
        pending.world.pendingItemIds,
        containsAll(pending.world.supportedCompletionIds),
        reason: 'the supported completions must still be outstanding',
      );

      // The guard the model actually reads comes from the proposal ledger, not
      // from getPendingChangeSets. If the seeded set does not reach the ledger
      // the model is never told, and the scenario would be blaming models for
      // something the app never showed them.
      final ledger = await pending.agentRepository.getProposalLedger(
        pending.agentId,
        taskId: pending.world.taskId,
      );
      expect(
        ledger.open.map((entry) => entry.toolName),
        contains(TaskAgentToolNames.setTaskStatus),
        reason: 'the queued proposal must reach the ledger the prompt renders',
      );

      harness = await TaskAgentWorkflowEvalHarness.start(container: container);
    });

    test('the built prompt carries the live no-op rule', () {
      // Assert against a BUILT prompt, never a seeded constant. The seeded
      // `taskAgentReportDirective` says "You MUST call update_report ... do not
      // end your turn with a plain text message", and is never sent: both an
      // empty and a stock directive count as built-in, so
      // `effectiveReportDirective` substitutes
      // TaskAgentEvidenceSynthesis.reportDirective instead. Reading the
      // constant as the rule caused a valid noOp result to be retracted in
      // error. If the substitution ever changes, this fails here rather than
      // silently inverting a scenario.
      final prompt = TaskAgentPromptBuilder.buildSystemPrompt(
        version: buildEvalTemplate(profileId: 'p').version,
        soulVersion: null,
        modelId: 'glm-5.2',
      );

      expect(
        prompt,
        contains('do not republish unchanged content'),
        reason: 'the no-op rule the scenario tests must be in the real prompt',
      );
      expect(
        prompt,
        isNot(contains('MANDATORY FINAL TOOL CALL')),
        reason: 'the seeded directive is superseded and must not reach a wake',
      );
    });

    test('the eval template carries the shipped directives', () {
      final template = buildEvalTemplate(profileId: 'profile-1');

      // makeTestTemplateVersion defaults to empty directives and "You are a
      // helpful agent.". Running with those silently strips the wake protocol,
      // the report contract and every restraint rule from the system prompt,
      // so the suite measures models against a prompt the app never sends.
      expect(
        template.version.generalDirective,
        taskAgentGeneralDirective,
        reason: 'the shipped general directive must reach the model',
      );
      expect(
        template.version.reportDirective,
        taskAgentReportDirective,
        reason: 'the shipped report directive must reach the model',
      );
      expect(template.version.generalDirective, isNotEmpty);
      expect(template.version.reportDirective, isNotEmpty);
    });

    test(
      'the agent and its state are stored in a real agent database',
      () async {
        final agent = await harness.agentRepository.getEntity(harness.agentId);

        expect(agent, isNotNull);
        expect(
          agent,
          isA<AgentIdentityEntity>().having(
            (entity) => entity.allowedCategoryIds,
            'allowedCategoryIds',
            contains(harness.world.categoryId),
          ),
          reason:
              'category policy must permit the seeded task, or every '
              'mutation is denied and the run measures nothing',
        );
      },
    );
  });
}
