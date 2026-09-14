/// Exports the live exercise inventory from the same catalogs the evals use.
/// Run through Flutter's test runner because these catalogs import Flutter.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../test/features/agents/eval/goal/compaction/support/goal_compaction_fixtures.dart';
import '../test/features/agents/eval/goal/support/goal_agent_eval_scenarios.dart';
import '../test/features/agents/eval/goal/support/goal_agent_outcome_eval_scenarios.dart';
import '../test/features/agents/eval/relationship/support/relationship_agent_eval_scenarios.dart';
import '../test/features/ai/eval/support/local_task_agent_inference_eval.dart';
import '../test/features/ai/eval/support/penguin_query_eval.dart';
import '../test/features/ai/eval/support/penguin_task_agent_eval_scenarios.dart';
import '../test/features/ai/eval/support/penguin_wake_scenarios.dart';
import '../test/features/ai/eval/support/query_action_eval.dart';
import '../test/features/daily_os_next/eval/framework/eval_scenario.dart';
import '../test/features/daily_os_next/integration/realistic_day_planning_scenarios.dart';

const _ai = 'test/features/ai/eval';
const _agents = 'test/features/agents/eval';
const _day = 'test/features/daily_os_next/eval';

/// Every runnable suite, its adapter contract and its exact scenario IDs.
/// Query follow-ups share a conversation, so that suite is an indivisible job.
Future<Map<String, Object?>> buildLottiGymCatalog() async {
  final queryDatabase = PenguinQueryDatabase(PenguinQueryCorpus());
  final summarySourceHash = queryDatabase.reportInputsHash;
  final summaryOwnerIds = queryDatabase.reportInputs
      .map((input) => input['ownerId'])
      .toList();
  await queryDatabase.close();
  Map<String, Object?> suite(
    String id,
    String entryPoint,
    String adapter,
    Iterable<String> cases, {
    String? prefix,
    String? gate,
    Map<String, String> environment = const {},
    List<String> dependencies = const [],
    bool grouped = false,
  }) => {
    'id': id,
    'entryPoint': entryPoint,
    'adapter': adapter,
    'cases': cases.toList(),
    'prefix': prefix,
    'gate': gate,
    'environment': environment,
    'dependencies': dependencies,
    'grouped': grouped,
  };

  Map<String, Object?> taskSuite(
    String id,
    List<LocalTaskAgentEvalScenario> cases, {
    Map<String, String> environment = const {},
  }) => suite(
    id,
    '$_ai/local_task_agent_inference_eval_live_test.dart',
    'task',
    cases.map((s) => s.id),
    prefix: 'LOCAL_TASK_AGENT_EVAL',
    gate: 'LOTTI_LOCAL_TASK_AGENT_EVAL_LIVE',
    environment: {
      'LOCAL_TASK_AGENT_EVAL_MATRIX': 'melious',
      'LOCAL_TASK_AGENT_EVAL_PROMPT_VARIANTS': 'production',
      'LOCAL_TASK_AGENT_EVAL_EXECUTION_MODE': 'productionRouting',
      ...environment,
    },
  );

  return {
    'schemaVersion': 1,
    'summarySourceHash': summarySourceHash,
    'summaryOwnerIds': summaryOwnerIds,
    'suites': [
      taskSuite('task-conversation', defaultMeliousTaskAgentEvalScenarios()),
      taskSuite(
        'task-penguin',
        penguinTaskAgentEvalScenarios(),
        environment: {'LOCAL_TASK_AGENT_EVAL_PENGUIN_LANGUAGES': '1'},
      ),
      taskSuite(
        'task-directives',
        evolvedReportDirectiveTaskAgentEvalScenarios(),
        environment: {'LOCAL_TASK_AGENT_EVAL_EVOLVED_DIRECTIVES': '1'},
      ),
      suite(
        'task-workflow',
        '$_ai/local_task_agent_workflow_eval_live_test.dart',
        'workflow',
        ['workflow'],
        prefix: 'LOCAL_TASK_AGENT_WORKFLOW_EVAL',
        gate: 'LOTTI_LOCAL_TASK_AGENT_WORKFLOW_EVAL_LIVE',
      ),
      suite(
        'task-wake',
        '$_ai/penguin_wake_workflow_eval_live_test.dart',
        'wake',
        PenguinWakeScenarioId.values.map((s) => s.name),
        prefix: 'PENGUIN_WAKE_EVAL',
        gate: 'LOTTI_PENGUIN_WAKE_EVAL_LIVE',
      ),
      suite(
        'goals',
        '$_agents/goal/goal_agent_eval_live_test.dart',
        'agent',
        goalAgentEvalScenarios.map((s) => s.id),
        prefix: 'GOAL_AGENT_EVAL',
        gate: 'LOTTI_GOAL_AGENT_EVAL_LIVE',
      ),
      suite(
        'goal-outcomes',
        '$_agents/goal/goal_agent_outcome_eval_live_test.dart',
        'outcome',
        goalOutcomeEvalScenarios.map((s) => s.id),
        prefix: 'GOAL_OUTCOME_EVAL',
        gate: 'LOTTI_GOAL_OUTCOME_EVAL_LIVE',
      ),
      suite(
        'relationships',
        '$_agents/relationship/relationship_agent_eval_live_test.dart',
        'agent',
        (await buildRelationshipAgentEvalScenarios()).map((s) => s.id),
        prefix: 'RELATIONSHIP_AGENT_EVAL',
        gate: 'LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE',
      ),
      suite(
        'query-reports',
        '$_ai/penguin_query_eval_live_test.dart',
        'preparation',
        ['reports'],
        prefix: 'QUERY_EVAL',
        gate: 'LOTTI_QUERY_EVAL_LIVE',
      ),
      suite(
        'query',
        '$_ai/penguin_query_eval_live_test.dart',
        'query',
        [...penguinQueryQuestions, ...penguinQueryHoldoutQuestions].map(
          (s) => s.id,
        ),
        prefix: 'QUERY_EVAL',
        gate: 'LOTTI_QUERY_EVAL_LIVE',
        dependencies: ['query-reports'],
        grouped: true,
      ),
      suite(
        'query-actions',
        '$_ai/query_actions_eval_live_test.dart',
        'actions',
        queryActionEvalCases.map((s) => s.id),
        prefix: 'QUERY_EVAL',
        gate: 'LOTTI_QUERY_ACTION_EVAL_LIVE',
        dependencies: ['query-reports'],
      ),
      suite(
        'day-planning',
        '$_day/day_planning_eval_live_test.dart',
        'planning',
        evalScenarios.map((s) => s.id),
        prefix: 'DAY_PLANNING_EVAL',
        gate: 'LOTTI_DAY_PLANNING_EVAL_LIVE',
      ),
      suite(
        'day-journey',
        '$_day/day_planning_full_journey_live_test.dart',
        'journey',
        realisticDayPlanningScenarios.map((s) => s.id),
        prefix: 'DAY_PLANNING_EVAL',
        gate: 'LOTTI_DAY_PLANNING_FULL_JOURNEY_LIVE',
      ),
      suite(
        'compaction',
        '$_agents/goal/compaction/goal_compaction_eval_live_test.dart',
        'compaction',
        goalCompactionFixtures.map((s) => s.id),
        prefix: 'GOAL_COMPACTION_EVAL',
        gate: 'LOTTI_GOAL_COMPACTION_EVAL_LIVE',
      ),
    ],
    'coverageGaps': {
      'vision': 'No reusable scored production vision suite.',
      'speech': 'Text transcripts do not assess audio transcription.',
      'relationship-persistence': 'The relationship suite scores inference.',
      'query-action-application': 'Actions are proposed, never applied.',
    },
    'excludedEntryPoints': {
      '$_ai/qwen_local_inference_eval_live_test.dart':
          'oMLX-only compatibility harness; not the Melious transport.',
    },
  };
}

void main() {
  test('exports the live exercise inventory without calling a model', () async {
    final path = Platform.environment['LOTTI_GYM_CATALOG'];
    if (path == null) {
      fail('Set LOTTI_GYM_CATALOG to the inventory output path.');
    }
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(await buildLottiGymCatalog()),
      );
  });
}
