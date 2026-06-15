import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';

const _matrixInputPath = String.fromEnvironment('EVAL_USE_CASE_MATRIX_INPUT');
const _planOutputPath = String.fromEnvironment('EVAL_USE_CASE_EXPERIMENT_PLAN');
const _planOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_EXPERIMENT_PLAN_OVERWRITE',
);

void main() {
  test('builds bounded runnable batches from diagnostic matrix cells', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
      maxBatches: 1,
    );

    expect(plan['status'], 'ready');
    expect(EvalUseCaseExperimentPlan.validate(plan), isEmpty);
    final batches = (plan['batches'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(batches, hasLength(1));
    final batch = batches.single;
    expect(batch['status'], 'collectPromotionEvidence');
    final env = batch['nextRunEnv'] as Map<String, dynamic>;
    expect(env['EVAL_REQUIRED_CAPABILITIES'], 'task.workflow');
    expect(env['EVAL_PROMPT_VARIANT_NAMES'], 'default');
    expect(
      _batchCommands(plan).map((command) => command['mode']),
      ['experiment-plan', 'next-run-work-order'],
    );
    expect(
      _batchCommands(plan).any((command) => command.containsKey('env')),
      isFalse,
    );
    expect(
      _topCommands(plan).map((command) => command['mode']),
      ['experiment-plan', 'next-run-work-order'],
    );
    expect(
      _topCommands(plan).any((command) => command.containsKey('env')),
      isFalse,
    );
  });

  test('stratifies bounded runnable batches across tuning cells', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'alpha-frontier',
          modelClass: 'frontierFast',
          ready: true,
          primaryCapabilityId: 'task.alpha',
        ),
        _report(
          runId: 'alpha-local',
          modelClass: 'localSmall',
          ready: true,
          primaryCapabilityId: 'task.alpha',
        ),
        _report(
          runId: 'beta-local',
          modelClass: 'localSmall',
          primaryCapabilityId: 'task.beta',
          blockingReasonCodes: const ['coverage.betaMissing'],
        ),
        _report(
          runId: 'gamma-reasoning',
          modelClass: 'localReasoning',
          primaryCapabilityId: 'task.gamma',
          promptVariantName: 'reasoning',
          blockingReasonCodes: const ['calibration.missingHumanLabels'],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final groups = (matrix['compatibilityGroups'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final cells = (groups.single['matrixCells'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    groups.single['matrixCells'] = <Map<String, dynamic>>[
      for (final cell in cells)
        if (cell['primaryCapabilityId'] == 'task.alpha') cell,
      for (final cell in cells)
        if (cell['primaryCapabilityId'] != 'task.alpha') cell,
    ];

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
      maxBatches: 2,
    );

    expect(EvalUseCaseExperimentPlan.validate(plan), isEmpty);
    final batches = (plan['batches'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(batches, hasLength(2));
    final capabilities = [
      for (final batch in batches)
        ...((batch['safeSelectors'] as Map<String, dynamic>)['capabilities']
                as List<dynamic>)
            .cast<String>(),
    ];
    final evidenceStatuses = [
      for (final batch in batches)
        ...(batch['evidenceStatuses'] as List<dynamic>).cast<String>(),
    ];

    expect(capabilities, contains('task.alpha'));
    expect(capabilities, contains('task.beta'));
    expect(capabilities.toSet(), hasLength(2));
    expect(evidenceStatuses, containsAll(['diagnosticOnly', 'dataDeficient']));
  });

  test('adds pending adversarial review tasks for ready batches', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
      maxBatches: 1,
    );

    final queue = plan['adversarialReviewQueue'] as Map<String, dynamic>;
    expect(queue['status'], 'pending');
    expect(queue['completionClaimsCreated'], isFalse);
    final summary = queue['summary'] as Map<String, dynamic>;
    expect(summary['completedTaskCount'], 0);
    final tasks = (queue['tasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      tasks.map((task) => task['category']),
      containsAll([
        'privacyAudit',
        'commandSafetyAudit',
        'selectorSafetyAudit',
        'evidenceSufficiencyAudit',
      ]),
    );
    expect(
      tasks.every((task) => task['status'] == 'pending'),
      isTrue,
    );
    expect(
      tasks.every((task) => task['requiredBefore'] == 'batchExecution'),
      isTrue,
    );
    expect(
      const JsonEncoder().convert(queue),
      allOf(
        isNot(contains('EVAL_SCENARIO_IDS')),
        isNot(contains('ready-run')),
        isNot(contains('/private/')),
      ),
    );
  });

  test(
    'blocks missing required capability gaps without leaking protected ids',
    () {
      final matrix = EvalUseCaseTuningMatrix.build(
        requireSourceChecks: false,
        reports: [
          _report(
            runId: 'missing-capability-run',
            modelClass: 'frontier',
            ready: true,
            promotionStatus: 'promote',
            scenarioId: 'protected-missing-capability',
            missingRequiredPrimaryCapabilities: const [
              'protected-missing-capability',
            ],
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );

      final plan = EvalUseCaseExperimentPlan.build(
        matrix: matrix,
        generatedAt: DateTime.utc(2026, 6, 12, 11),
      );

      expect(plan['status'], 'blocked');
      expect(plan['batches'], isEmpty);
      expect(
        plan['blockedReasonCodes'],
        contains('coverage.capabilityMissing'),
      );
      expect(
        const JsonEncoder().convert(plan),
        isNot(contains('protected-missing-capability')),
      );
      expect(
        _topCommands(plan).map((command) => command['mode']),
        isNot(contains(anyOf('plan', 'run', 'tune'))),
      );
    },
  );

  test('keeps incompatible matrices non-runnable', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'run-a',
          modelClass: 'frontier',
          ready: true,
          scenarioSetSeed: 'scenario-set-a',
        ),
        _report(
          runId: 'run-b',
          modelClass: 'local-small',
          ready: true,
          scenarioSetSeed: 'scenario-set-b',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );

    expect(plan['status'], 'incompatible');
    expect(plan['batches'], isEmpty);
    expect(plan['blockedReasonCodes'], contains('matrix.incompatible'));
    expect(
      _topCommands(plan).map((command) => command['mode']),
      isNot(contains(anyOf('plan', 'run', 'tune'))),
    );
  });

  test(
    'withholds opaque protected selectors instead of broad runnable env',
    () {
      final matrix = EvalUseCaseTuningMatrix.build(
        requireSourceChecks: false,
        reports: [
          _report(
            runId: 'protected-run',
            modelClass: 'frontier',
            ready: true,
            scenarioId: 'protected-case',
            primaryCapabilityId: 'protected-case',
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );

      final plan = EvalUseCaseExperimentPlan.build(
        matrix: matrix,
        generatedAt: DateTime.utc(2026, 6, 12, 11),
      );

      expect(plan['status'], 'noRunnableBatches');
      expect(plan['batches'], isEmpty);
      expect(
        plan['blockedReasonCodes'],
        contains('experiment.noSafeRunnableSelectors'),
      );
      expect(
        const JsonEncoder().convert(plan),
        isNot(contains('protected-case')),
      );
    },
  );

  test('does not re-emit model class labels from source matrix cells', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final groups = (matrix['compatibilityGroups'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final cells = (groups.single['matrixCells'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    cells.single['modelClass'] = 'private-run-id';

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );

    expect(plan['status'], 'ready');
    expect(
      const JsonEncoder().convert(plan),
      isNot(contains('private-run-id')),
    );
  });

  test('treats non-positive batch bounds as no runnable batches', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
      maxCellsPerBatch: 0,
    );

    expect(plan['status'], 'noRunnableBatches');
    expect(plan['batches'], isEmpty);
    final summary = plan['summary'] as Map<String, dynamic>;
    expect(summary['maxCellsPerBatch'], 0);
  });

  test('operator handoff maps blockers to safe command templates', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'blocked-run',
          modelClass: 'frontier',
          blockingReasonCodes: const [
            'calibration.missing',
            'judge.verdictMissing',
            'pairwise.reviewMissing',
          ],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );

    expect(EvalUseCaseExperimentPlan.validate(plan), isEmpty);
    final handoff = plan['operatorHandoff'] as Map<String, dynamic>;
    final actions = (handoff['actions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      actions.map((action) => action['action']),
      containsAll([
        'completeHumanCalibration',
        'gradeMissingVerdicts',
        'completePairwiseReview',
      ]),
    );
    final templates = (handoff['commandTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      templates.map((template) => template['mode']),
      containsAll([
        'template',
        'calibrate',
        'grade',
        'report',
        'use-case-matrix',
        'experiment-plan',
      ]),
    );
    expect(templates.any((template) => template.containsKey('env')), isFalse);
    expect(
      const JsonEncoder().convert(handoff),
      allOf(
        isNot(contains('EVAL_SCENARIO_IDS')),
        isNot(contains('/private/')),
        isNot(contains('blocked-run')),
      ),
    );
  });

  test('operator handoff maps holdout and review blockers to catalog work', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'catalog-blocked-run',
          modelClass: 'frontier',
          blockingReasonCodes: const [
            'coverage.protectedHoldoutMissing',
            'catalog.sourceDigestMissing',
            'scenario.reviewMetadataMissing',
          ],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );

    expect(EvalUseCaseExperimentPlan.validate(plan), isEmpty);
    final handoff = plan['operatorHandoff'] as Map<String, dynamic>;
    final actions = (handoff['actions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      actions.map((action) => action['action']),
      containsAll([
        'runCatalogPreflight',
        'completeScenarioReviewMetadata',
      ]),
    );
    final templates = (handoff['commandTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(templates.map((template) => template['mode']), contains('catalog'));
    final queue = plan['adversarialReviewQueue'] as Map<String, dynamic>;
    final tasks = (queue['tasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      tasks.map((task) => task['category']),
      contains('holdoutCatalogGovernanceAudit'),
    );
  });

  test(
    'does not copy private upstream model or profile selectors into handoff',
    () {
      final matrix = EvalUseCaseTuningMatrix.build(
        requireSourceChecks: false,
        reports: [
          _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );
      final nextPlan = matrix['nextExperimentPlan'] as Map<String, dynamic>;
      nextPlan['safeSelectors'] = const <String, dynamic>{
        'modelClasses': ['private-model-class'],
        'profileNames': ['private-profile'],
      };

      final plan = EvalUseCaseExperimentPlan.build(
        matrix: matrix,
        generatedAt: DateTime.utc(2026, 6, 12, 11),
      );

      expect(
        const JsonEncoder().convert(plan),
        allOf(
          isNot(contains('private-model-class')),
          isNot(contains('private-profile')),
        ),
      );
    },
  );

  test(
    'contract rejects unsafe operator handoff commands and env values',
    () {
      final matrix = EvalUseCaseTuningMatrix.build(
        requireSourceChecks: false,
        reports: [
          _report(
            runId: 'missing-capability-run',
            modelClass: 'frontier',
            ready: true,
            promotionStatus: 'promote',
            scenarioId: 'protected-missing-capability',
            missingRequiredPrimaryCapabilities: const [
              'protected-missing-capability',
            ],
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );
      final plan = EvalUseCaseExperimentPlan.build(
        matrix: matrix,
        generatedAt: DateTime.utc(2026, 6, 12, 11),
      );
      final tampered = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
      final handoff = tampered['operatorHandoff'] as Map<String, dynamic>;
      handoff['profileNames'] = const ['private-profile'];
      handoff['runId'] = 'raw-run-id';
      handoff['notes'] =
          'Use EVAL_PROFILE_NAMES=/private/path/profiles.json for this pass.';
      (handoff['commandTemplates'] as List<dynamic>).add(
        <String, dynamic>{
          'mode': 'shell',
          'command': "bash -lc 'eval/run_level2.sh run'",
          'envKeys': const ['EVAL_SCENARIO_IDS'],
          'env': const {'EVAL_SCENARIOS': '/private/path/catalog.json'},
          'privateInputsRequired': true,
          'valuesOmitted': false,
        },
      );

      final issues = EvalUseCaseExperimentPlan.validate(tampered);

      expect(
        issues,
        contains(
          'operatorHandoff.commandTemplates[3].mode is not a safe '
          'handoff mode',
        ),
      );
      expect(
        issues,
        contains(
          'operatorHandoff.commandTemplates[3].command must not recommend '
          'live run commands',
        ),
      );
      expect(
        issues,
        contains(
          'operatorHandoff.commandTemplates[3].envKeys must not contain '
          'EVAL_SCENARIO_IDS',
        ),
      );
      expect(
        issues,
        contains(
          'operatorHandoff.commandTemplates[3] must list envKeys, not '
          'env values',
        ),
      );
      expect(
        issues,
        contains(
          'plan.operatorHandoff.profileNames must not expose profile '
          'selectors',
        ),
      );
      expect(
        issues,
        contains('plan.operatorHandoff.runId must not expose run ids'),
      );
      expect(
        issues,
        contains('plan.operatorHandoff.notes must not contain private paths'),
      );
      expect(
        issues,
        contains(
          'plan.operatorHandoff.notes must not contain private env value keys',
        ),
      );
      expect(
        issues,
        contains(
          'plan.operatorHandoff.commandTemplates[3].env.EVAL_SCENARIOS must '
          'not expose private env values',
        ),
      );
      expect(
        issues,
        contains(
          'operatorHandoff.commandTemplates[3].valuesOmitted must be true',
        ),
      );
    },
  );

  test('contract binds summary counts and status to runnable batches', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );
    final tampered = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>
      ..['status'] = 'blocked';
    (tampered['summary'] as Map<String, dynamic>)
      ..['batchCount'] = 0
      ..['blockedReasonCount'] = 99;

    final issues = EvalUseCaseExperimentPlan.validate(tampered);

    expect(issues, contains('summary.batchCount must match batches.length'));
    expect(
      issues,
      contains(
        'summary.blockedReasonCount must match blockedReasonCodes.length',
      ),
    );
    expect(issues, contains('batches must be empty when status is blocked'));
    expect(
      issues,
      contains(
        'operatorHandoff.status must be manualWorkRequired for blocked',
      ),
    );
  });

  test(
    'contract rejects adversarial review completion and command smuggling',
    () {
      final matrix = EvalUseCaseTuningMatrix.build(
        requireSourceChecks: false,
        reports: [
          _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );
      final plan = EvalUseCaseExperimentPlan.build(
        matrix: matrix,
        generatedAt: DateTime.utc(2026, 6, 12, 11),
      );
      final tampered = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
      final queue = tampered['adversarialReviewQueue'] as Map<String, dynamic>;
      queue['status'] = 'complete';
      queue['completionClaimsCreated'] = true;
      final summary = queue['summary'] as Map<String, dynamic>
        ..['completedTaskCount'] = 1
        ..['pendingTaskCount'] = 0
        ..['taskCount'] = 99;
      expect(summary['taskCount'], 99);
      final tasks = (queue['tasks'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      tasks.first
        ..['status'] = 'complete'
        ..['command'] = 'eval/run_level2.sh run <nextRunId>'
        ..['recommendedCommands'] = const [
          {'mode': 'run', 'command': 'eval/run_level2.sh run <nextRunId>'},
        ]
        ..['nextRunEnv'] = const {'EVAL_PROFILE_NAMES': 'private-profile'}
        ..['env'] = const {'EVAL_SCENARIOS': '/private/path/catalog.json'}
        ..['scenarioIds'] = const ['private-scenario']
        ..['profileNames'] = const ['private-profile']
        ..['runId'] = 'raw-run-id'
        ..['baseRunId'] = 'raw-base-run-id'
        ..['notes'] = 'Use EVAL_PROFILE_NAMES with /private/path/profiles.json'
        ..['passed'] = true
        ..['reviewedBy'] = 'agent-a'
        ..['findingCount'] = 0
        ..['completionEvidence'] = const {'reviewer': 'agent-a'};

      final issues = EvalUseCaseExperimentPlan.validate(tampered);

      expect(
        issues,
        contains('adversarialReviewQueue.status must be pending'),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.completionClaimsCreated must be false',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.summary.completedTaskCount must be 0',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.summary.taskCount must match tasks.length',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.summary.pendingTaskCount must match '
          'tasks.length',
        ),
      );
      expect(
        issues,
        contains('adversarialReviewQueue.tasks[0].status must be pending'),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not contain executable field '
          'command',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not contain executable field '
          'recommendedCommands',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not contain executable field '
          'nextRunEnv',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not contain executable field '
          'env',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not contain completionEvidence',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not claim review completion '
          'via passed',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not claim review completion '
          'via reviewedBy',
        ),
      );
      expect(
        issues,
        contains(
          'adversarialReviewQueue.tasks[0] must not claim review completion '
          'via findingCount',
        ),
      );
      expect(
        issues,
        contains(
          'plan.adversarialReviewQueue.tasks[0].env.EVAL_SCENARIOS must not '
          'expose private env values',
        ),
      );
      expect(
        issues,
        contains(
          'plan.adversarialReviewQueue.tasks[0].profileNames must not expose '
          'profile selectors',
        ),
      );
      expect(
        issues,
        contains(
          'plan.adversarialReviewQueue.tasks[0].scenarioIds must not expose '
          'scenario ids',
        ),
      );
      expect(
        issues,
        contains(
          'plan.adversarialReviewQueue.tasks[0].runId must not expose run ids',
        ),
      );
      expect(
        issues,
        contains(
          'plan.adversarialReviewQueue.tasks[0].baseRunId must not expose run '
          'ids',
        ),
      );
      expect(
        issues,
        contains(
          'plan.adversarialReviewQueue.tasks[0].notes must not contain '
          'private env value keys',
        ),
      );
      expect(
        issues,
        contains(
          'plan.adversarialReviewQueue.tasks[0].notes must not contain '
          'private paths',
        ),
      );
    },
  );

  test('contract binds holdout audit presence to blocker codes', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'catalog-blocked-run',
          modelClass: 'frontier',
          blockingReasonCodes: const [
            'coverage.protectedHoldoutMissing',
          ],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );
    final missing = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
    final missingQueue =
        missing['adversarialReviewQueue'] as Map<String, dynamic>;
    (missingQueue['tasks'] as List<dynamic>).removeWhere(
      (task) =>
          task is Map<String, dynamic> &&
          task['category'] == 'holdoutCatalogGovernanceAudit',
    );

    expect(
      EvalUseCaseExperimentPlan.validate(missing),
      contains(
        'adversarialReviewQueue.tasks must include '
        'holdoutCatalogGovernanceAudit for catalog blockers',
      ),
    );

    final extraMatrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final extra = EvalUseCaseExperimentPlan.build(
      matrix: extraMatrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );
    final extraQueue = extra['adversarialReviewQueue'] as Map<String, dynamic>;
    final extraTasks = extraQueue['tasks'] as List<dynamic>;
    final privacyTask =
        jsonDecode(
              jsonEncode(extraTasks.first),
            )
            as Map<String, dynamic>;
    privacyTask['category'] = 'holdoutCatalogGovernanceAudit';
    extraTasks.add(privacyTask);

    expect(
      EvalUseCaseExperimentPlan.validate(extra),
      contains(
        'adversarialReviewQueue.tasks must not include '
        'holdoutCatalogGovernanceAudit without catalog blockers',
      ),
    );
  });

  test('contract rejects scenario id fields and scenario env recursively', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );
    final tampered = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>
      ..['status'] = 'blocked'
      ..['scenarioIds'] = const ['protected-case'];
    final batch =
        (tampered['batches'] as List<dynamic>).single as Map<String, dynamic>;
    batch['nextRunEnv'] = <String, dynamic>{
      ...batch['nextRunEnv'] as Map<String, dynamic>,
      'EVAL_SCENARIO_IDS': 'protected-case',
    };
    ((batch['recommendedCommands'] as List<dynamic>).first
          as Map<String, dynamic>)
      ..['mode'] = 'run'
      ..['command'] = 'eval/run_level2.sh run <nextRunId>'
      ..['env'] = const {'EVAL_REQUIRED_CAPABILITIES': 'task.workflow'};

    final issues = EvalUseCaseExperimentPlan.validate(tampered);

    expect(issues, contains('plan.scenarioIds must not expose scenario ids'));
    expect(
      issues,
      contains('batches[0].nextRunEnv must not contain EVAL_SCENARIO_IDS'),
    );
    expect(
      issues,
      contains(
        'batches[0].recommendedCommands[0].mode is unsupported',
      ),
    );
    expect(
      issues,
      contains(
        'batches[0].recommendedCommands[0].command must not recommend live run '
        'commands',
      ),
    );
    expect(
      issues,
      contains(
        'batches[0].recommendedCommands[0] must not contain env values',
      ),
    );
  });

  test(
    'writes use-case experiment plan',
    () {
      final matrix =
          jsonDecode(File(_matrixInputPath).readAsStringSync())
              as Map<String, dynamic>;
      final plan = EvalUseCaseExperimentPlan.build(matrix: matrix);
      EvalUseCaseExperimentPlan.assertValid(plan);
      writeEvalJsonArtifact(
        plan,
        path: _planOutputPath,
        overwrite: _planOverwrite == '1',
        description: 'use-case experiment plan',
      );
    },
    skip: _matrixInputPath.isEmpty || _planOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_MATRIX_INPUT=<json> and '
              'EVAL_USE_CASE_EXPERIMENT_PLAN=<json> to write a plan.'
        : false,
  );
}

List<Map<String, dynamic>> _topCommands(Map<String, dynamic> plan) {
  return (plan['recommendedCommands'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
}

List<Map<String, dynamic>> _batchCommands(Map<String, dynamic> plan) {
  final batches = (plan['batches'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return (batches.single['recommendedCommands'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
}

Map<String, dynamic> _report({
  required String runId,
  required String modelClass,
  bool ready = false,
  String promotionStatus = 'notRequested',
  String scenarioId = 'task_workflow_structured_update',
  String scenarioSetSeed = 'scenario-set',
  String primaryCapabilityId = 'task.workflow',
  String promptVariantName = 'default',
  List<String> missingRequiredPrimaryCapabilities = const <String>[],
  List<String> blockingReasonCodes = const ['verdict.missing'],
}) {
  final effectiveBlockers = ready ? const <String>[] : blockingReasonCodes;
  const policyPayload = <String, dynamic>{
    'name': 'modelClassTuning',
    'minJudgePassRateLowerBound': 0.7,
  };
  final policyDigest = EvalProvenance.digestJson(policyPayload);
  final manifestDigest = _digest('manifest-$runId');
  return <String, dynamic>{
    'schemaVersion': EvalTuningReportContract.schemaVersion,
    'kind': EvalTuningReportContract.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 9).toIso8601String(),
    'run': <String, dynamic>{
      'runId': runId,
      'targetKind': 'fixture',
      'manifestDigest': manifestDigest,
      'createdAt': DateTime.utc(2026, 6, 12, 8).toIso8601String(),
      'scenarioSetDigest': _digest(scenarioSetSeed),
      'profileSetDigest': _digest('profiles-$modelClass'),
      'profileBindingSetDigest': _digest('bindings-$modelClass'),
      'agentDirectiveVariantSetDigest': _digest(
        'prompt-variants-$promptVariantName',
      ),
      'selectors': <String, dynamic>{
        'scenarioIds': [scenarioId],
        'profileNames': ['profile-$modelClass'],
        'promptVariantNames': [promptVariantName],
        'requiredPrimaryCapabilityIds': const ['task.workflow'],
      },
      'protectedIdsRedacted': false,
      'artifactSnapshot': <String, dynamic>{
        'artifactCount': 9,
        'traceCount': 4,
        'judgedTraceCount': 4,
        'manifestDigest': manifestDigest,
        'ownedArtifactRefsDigest': _digest('owned-$runId'),
        'loadedTraceContentDigest': _digest('loaded-$runId'),
      },
    },
    'policy': <String, dynamic>{
      'name': 'modelClassTuning',
      'digest': policyDigest,
      'payload': policyPayload,
    },
    'status': <String, dynamic>{
      'ready': ready,
      'label': ready ? 'ready' : 'blocked',
      'failureCount': effectiveBlockers.length,
      'warningCount': 0,
    },
    'gates': [
      for (final code in effectiveBlockers)
        <String, dynamic>{
          'id': 'gate-$code',
          'status': 'fail',
          'scope': const <String, dynamic>{},
          'actual': 0,
          'required': 1,
          'comparator': '>=',
          'evidenceRefs': const <String>[],
          'blockerCode': code,
        },
    ],
    'coverage': <String, dynamic>{
      'scenarioCount': 1,
      'profileCount': 1,
      'promptVariantCount': 1,
      'expectedTraceCount': 4,
      'traceCount': 4,
      'judgedTraceCount': 4,
      'missingRequiredPrimaryCapabilityIds': missingRequiredPrimaryCapabilities,
    },
    'readiness': <String, dynamic>{
      'ready': ready,
      'evidenceLabel': ready ? 'ready' : 'blocked',
      'policyName': 'modelClassTuning',
      'policyDigest': policyDigest,
      'expectedTraceCount': 4,
      'traceCount': 4,
      'judgedTraceCount': 4,
      'failures': effectiveBlockers,
      'warnings': const <String>[],
      'missingRequiredPrimaryCapabilityIds': missingRequiredPrimaryCapabilities,
    },
    'outcomes': const <String, dynamic>{
      'aggregate': <String, dynamic>{},
      'slices': <dynamic>[],
      'failingTraceCount': 0,
    },
    'calibration': const <String, dynamic>{'present': false},
    'pairwise': const <String, dynamic>{'present': false},
    'promotion': <String, dynamic>{
      'present': promotionStatus != 'notRequested',
      'status': promotionStatus,
      'evidencePlan': promotionStatus == 'notRequested'
          ? null
          : const <String, dynamic>{'status': 'matched'},
    },
    'useCaseModelSlices': [
      <String, dynamic>{
        'sliceKey':
            '$primaryCapabilityId@taskAgent@$modelClass@$promptVariantName',
        'primaryCapabilityId': primaryCapabilityId,
        'agentKind': 'taskAgent',
        'modelClass': modelClass,
        'promptVariantName': promptVariantName,
        'scenarioIds': [scenarioId],
        'profileNames': ['profile-$modelClass'],
        'traceCount': 4,
        'judgedTraceCount': 4,
        'passCount': 3,
        'level1PassCount': 4,
        'passRate': 0.75,
        'passRateLowerBound': 0.55,
        'meanGoalAttainment': 4,
        'meanQuality': 4.4,
        'meanEfficiency': 4.2,
        'meanTokenBudgetRatio': 0.42,
        'weightedCostTraceCount': 0,
        'missingWeightedCostCount': 0,
        'meanWeightedCostBudgetRatio': 0,
        'recommendation': ready ? 'keep' : 'gradeVerdicts',
        'blockingReasons': effectiveBlockers,
        'gates': const <dynamic>[],
      },
    ],
    'blockedReasons': [
      for (final code in effectiveBlockers)
        <String, dynamic>{
          'code': code,
          'severity': 'blocking',
          'message': 'Synthetic test blocker.',
          'nextAction': 'collectEvidence',
          'scope': const <String, dynamic>{},
        },
    ],
    'recommendations': const <Map<String, dynamic>>[],
    'nextExperimentPlan': <String, dynamic>{
      'schemaVersion': EvalTuningReportContract.schemaVersion,
      'kind': EvalTuningReportContract.nextExperimentPlanKind,
      'baseRunId': runId,
      'objective': ready ? 'readyForPromotionReview' : 'closeReadinessGaps',
      'status': ready ? 'ready' : 'blocked',
      'blockedReasonCodes': effectiveBlockers,
      'requiredCapabilities': const ['task.workflow'],
      'suggestedCapabilities': const ['task.workflow'],
      'suggestedScenarioIds': [scenarioId],
      'suggestedProfileNames': ['profile-$modelClass'],
      'suggestedPromptVariantNames': [promptVariantName],
      'requiredPairwiseIntentKeys': const <String>[],
      'missingOrFailedPairwiseKeys': const <String>[],
      'nextRunEnv': const <String, dynamic>{},
      'recommendedCommands': const [
        <String, dynamic>{
          'mode': 'tune',
          'command': 'eval/run_level2.sh tune <nextRunId>',
        },
      ],
    },
  };
}

String _digest(String value) => EvalProvenance.digestText(value);
