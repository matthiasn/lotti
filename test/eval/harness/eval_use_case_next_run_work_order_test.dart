import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';

const _workOrderInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_NEXT_RUN_WORK_ORDER_INPUT',
);
const _workOrderOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_NEXT_RUN_WORK_ORDER',
);
const _workOrderOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_NEXT_RUN_WORK_ORDER_OVERWRITE',
);

void main() {
  test('builds bounded public-env batches from a ready experiment plan', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'ready-task',
          ready: true,
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
        _report(
          runId: 'ready-planner',
          ready: true,
          primaryCapabilityId: 'planner.workflow',
          promptVariantName: 'metadata-first',
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
      ],
    );

    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: plan,
      generatedAt: DateTime.utc(2026, 6, 12, 12),
      maxRunBatches: 1,
    );

    expect(EvalUseCaseNextRunWorkOrder.validate(workOrder), isEmpty);
    expect(
      EvalProvenance.isDigest(workOrder['workOrderRef'] as String),
      isTrue,
    );
    expect(
      workOrder['workOrderRef'],
      EvalUseCaseNextRunWorkOrder.workOrderRef(workOrder),
    );
    expect(workOrder['status'], 'ready');
    final summary = workOrder['summary'] as Map<String, dynamic>;
    expect(summary['sourceBatchCount'], 2);
    expect(summary['runBatchCount'], 1);
    final runBatches = (workOrder['runBatches'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final batch = runBatches.single;
    expect(batch['objective'], 'collectPromotionEvidence');
    expect(batch['commandTemplateRefs'], ['plan', 'run', 'tune']);
    final publicEnv = batch['publicEnv'] as Map<String, dynamic>;
    expect(
      publicEnv.keys,
      unorderedEquals([
        'EVAL_REQUIRED_CAPABILITIES',
        'EVAL_PROMPT_VARIANT_NAMES',
      ]),
    );
    expect(
      ['planner.workflow', 'task.workflow'],
      contains(publicEnv['EVAL_REQUIRED_CAPABILITIES']),
    );
    expect(
      ['default', 'metadata-first'],
      contains(publicEnv['EVAL_PROMPT_VARIANT_NAMES']),
    );
    expect(
      const JsonEncoder().convert(workOrder),
      allOf(
        isNot(contains('ready-task')),
        isNot(contains('ready-planner')),
        isNot(contains('EVAL_SCENARIO_IDS')),
        isNot(contains('EVAL_PROFILE_NAMES')),
        isNot(contains('/private/')),
      ),
    );
  });

  test('preserves collectData objectives from data-deficient plan batches', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'data-deficient',
        ),
      ],
    );

    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: plan,
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(workOrder['status'], 'ready');
    final batch =
        (workOrder['runBatches'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(batch['objective'], 'collectData');
    expect(batch['sourceEvidenceStatuses'], ['dataDeficient']);
  });

  test('builds digest-bound launch evidence for selected run batches', () {
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: _experimentPlan(
        reports: [_report(runId: 'ready-task', ready: true)],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final batch =
        (workOrder['runBatches'] as List<dynamic>).single
            as Map<String, dynamic>;

    final evidence = EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
      workOrder: workOrder,
      requiredPrimaryCapabilityIds: const {'task.workflow'},
      promptVariantNames: const ['default'],
      workOrderBatchRefs: [batch['workOrderBatchRef'] as String],
    );

    expect(evidence.workOrderRef, workOrder['workOrderRef']);
    expect(evidence.workOrderDigest, EvalProvenance.digestJson(workOrder));
    expect(evidence.workOrderBatchRefs, [batch['workOrderBatchRef']]);
    expect(
      evidence.workOrderBatchSetDigest,
      EvalProvenance.digestJson(evidence.workOrderBatchRefs),
    );
    expect(
      evidence.workOrderLaunchSubjectDigest,
      EvalProvenance.useCaseWorkOrderLaunchSubjectDigest(evidence),
    );
  });

  test('launch evidence rejects mismatched explicit batch selectors', () {
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: _experimentPlan(
        reports: [_report(runId: 'ready-task', ready: true)],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final batch =
        (workOrder['runBatches'] as List<dynamic>).single
            as Map<String, dynamic>;

    expect(
      () => EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
        workOrder: workOrder,
        requiredPrimaryCapabilityIds: const {'planner.workflow'},
        promptVariantNames: const ['default'],
        workOrderBatchRefs: [batch['workOrderBatchRef'] as String],
      ),
      throwsStateError,
    );
  });

  test('refuses invalid, blocked, and selector-deficient experiment plans', () {
    final readyPlan = _experimentPlan(
      reports: [
        _report(runId: 'ready-task', ready: true),
      ],
    );
    final invalidPlan =
        jsonDecode(jsonEncode(readyPlan)) as Map<String, dynamic>
          ..['schemaVersion'] = 99;

    final invalidWorkOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: invalidPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(invalidWorkOrder['status'], 'invalidPlan');
    expect(invalidWorkOrder['runBatches'], isEmpty);

    final blockedPlan = _experimentPlan(
      reports: [
        _report(
          runId: 'run-a',
          ready: true,
          scenarioSetSeed: 'scenario-set-a',
        ),
        _report(
          runId: 'run-b',
          ready: true,
          scenarioSetSeed: 'scenario-set-b',
        ),
      ],
    );
    final blockedWorkOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: blockedPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(blockedWorkOrder['status'], 'blockedPlan');
    expect(blockedWorkOrder['runBatches'], isEmpty);

    final noBatchPlan = _experimentPlan(
      reports: [
        _report(runId: 'ready-task', ready: true),
      ],
      maxCellsPerBatch: 0,
    );
    final noBatchWorkOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: noBatchPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(noBatchWorkOrder['status'], 'noRunnableBatches');
    expect(noBatchWorkOrder['runBatches'], isEmpty);
  });

  test('contract rejects private payloads and command smuggling', () {
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: _experimentPlan(
        reports: [
          _report(runId: 'ready-task', ready: true),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(workOrder)) as Map<String, dynamic>
      ..['scenarioIds'] = const ['protected-case']
      ..['profileNames'] = const ['frontier-private']
      ..['runId'] = 'raw-run-id'
      ..['tracePath'] = '/private/path/trace.json'
      ..['linuxNotes'] = 'read /home/runner/work/work-order.json'
      ..['fileNotes'] = 'read file:///Users/mn/work-order.json'
      ..['providerModelId'] = 'provider-secret-model'
      ..['promptText'] = 'raw private prompt';
    final batch =
        (tampered['runBatches'] as List<dynamic>).single
            as Map<String, dynamic>;
    (batch['publicEnv'] as Map<String, dynamic>)
      ..['EVAL_SCENARIO_IDS'] = 'protected-case'
      ..['EVAL_PROMPT_VARIANT_NAMES'] = 'prompt-123456789abc';
    (batch['publicSelectors'] as Map<String, dynamic>)['promptVariantNames'] =
        const ['prompt-123456789abc'];
    final commandTemplates = (tampered['commandTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    commandTemplates.first
      ..['commandTemplate'] =
          'bash -lc "EVAL_SCENARIO_IDS=protected eval/run_level2.sh run private"'
      ..['env'] = const {'EVAL_PROFILE_NAMES': 'frontier-private'}
      ..['command'] = 'eval/run_level2.sh run raw-run-id'
      ..['shell'] = 'bash';

    final issues = EvalUseCaseNextRunWorkOrder.validate(tampered);

    expect(
      issues,
      contains('workOrder must not contain unsupported field scenarioIds'),
    );
    expect(
      issues,
      contains('workOrder.scenarioIds must not expose scenario ids'),
    );
    expect(
      issues,
      contains('workOrder.profileNames must not expose profile selectors'),
    );
    expect(issues, contains('workOrder.runId must not expose run ids'));
    expect(
      issues,
      contains('workOrder.tracePath must not expose private paths'),
    );
    expect(
      issues,
      contains('workOrder.tracePath must not contain private paths'),
    );
    expect(
      issues,
      contains('workOrder.linuxNotes must not contain private paths'),
    );
    expect(
      issues,
      contains('workOrder.fileNotes must not contain private paths'),
    );
    expect(
      issues,
      contains(
        'workOrder.providerModelId must not expose provider or model ids',
      ),
    );
    expect(
      issues,
      contains('workOrder.promptText must not expose raw prompt text'),
    );
    expect(
      issues,
      contains('runBatches[0].publicEnv must not contain EVAL_SCENARIO_IDS'),
    );
    expect(
      issues,
      contains(
        'runBatches[0].publicEnv.EVAL_PROMPT_VARIANT_NAMES contains unsafe selector values',
      ),
    );
    expect(
      issues,
      contains(
        'runBatches[0].publicSelectors.promptVariantNames contains unsafe selector values',
      ),
    );
    expect(
      issues,
      contains(
        'commandTemplates[0].commandTemplate must be eval/run_level2.sh plan <nextRunId>',
      ),
    );
    expect(
      issues,
      contains(
        'commandTemplates[0].commandTemplate must not contain shell wrappers or inline env',
      ),
    );
    expect(
      issues,
      contains('commandTemplates[0] must not contain env values'),
    );
    expect(
      issues,
      contains('commandTemplates[0] must use commandTemplate only'),
    );
    expect(
      issues,
      contains('commandTemplates[0] must not contain unsupported field shell'),
    );
  });

  test('contract binds work-order batch refs to source refs and public env', () {
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: _experimentPlan(
        reports: [
          _report(runId: 'ready-task', ready: true),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(workOrder)) as Map<String, dynamic>;
    final batch =
        (tampered['runBatches'] as List<dynamic>).single
            as Map<String, dynamic>;
    batch['workOrderBatchRef'] = EvalProvenance.digestText('tampered');

    expect(
      EvalUseCaseNextRunWorkOrder.validate(tampered),
      contains(
        'runBatches[0].workOrderBatchRef must bind source refs and public env',
      ),
    );
  });

  test('contract binds adversarial review tasks to work-order sources', () {
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: _experimentPlan(
        reports: [
          _report(runId: 'ready-task', ready: true),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(workOrder)) as Map<String, dynamic>;
    final tasks =
        ((tampered['adversarialReviewQueue'] as Map<String, dynamic>)['tasks']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    final task = tasks.first;
    (task['sourceRefs'] as Map<String, dynamic>)['sourcePlanDigest'] =
        EvalProvenance.digestText('other-plan');
    task['reviewRef'] = EvalProvenance.digestText('other-review');
    tampered['workOrderRef'] = EvalUseCaseNextRunWorkOrder.workOrderRef(
      tampered,
    );

    final issues = EvalUseCaseNextRunWorkOrder.validate(tampered);

    expect(
      issues,
      contains(
        'adversarialReviewQueue.tasks[0].reviewRef must bind work-order review sources',
      ),
    );
    expect(
      issues,
      contains(
        'adversarialReviewQueue.tasks[0].sourceRefs must match work-order review sources',
      ),
    );
  });

  test('contract requires exact command template refs', () {
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: _experimentPlan(
        reports: [
          _report(runId: 'ready-task', ready: true),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(workOrder)) as Map<String, dynamic>;
    final batch =
        (tampered['runBatches'] as List<dynamic>).single
            as Map<String, dynamic>;
    batch['commandTemplateRefs'] = const ['plan', 'run'];
    (tampered['commandTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .removeLast();
    tampered['workOrderRef'] = EvalUseCaseNextRunWorkOrder.workOrderRef(
      tampered,
    );

    final issues = EvalUseCaseNextRunWorkOrder.validate(tampered);

    expect(
      issues,
      contains(
        'runBatches[0].commandTemplateRefs must be exactly plan, run, tune',
      ),
    );
    expect(
      issues,
      contains('commandTemplates refs must be exactly plan, run, tune'),
    );
  });

  test('source-aware validation rejects maliciously restamped work orders', () {
    final sourcePlan = _experimentPlan(
      reports: [
        _report(runId: 'ready-task', ready: true),
      ],
    );
    final unrelatedPlan = _experimentPlan(
      reports: [
        _report(
          runId: 'ready-planner',
          ready: true,
          primaryCapabilityId: 'planner.workflow',
          requiredCapabilities: const ['planner.workflow'],
        ),
      ],
    );
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: sourcePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final restamped = _restampWorkOrderToPlan(workOrder, unrelatedPlan);

    expect(EvalUseCaseNextRunWorkOrder.validate(restamped), isEmpty);
    expect(
      EvalUseCaseNextRunWorkOrder.validateAgainstExperimentPlan(
        restamped,
        experimentPlan: sourcePlan,
      ),
      contains('sourceExperimentPlan.planDigest must match experimentPlan'),
    );
  });

  test('contract rejects stale work-order subject refs', () {
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: _experimentPlan(
        reports: [
          _report(runId: 'ready-task', ready: true),
        ],
      ),
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(workOrder)) as Map<String, dynamic>;
    final queue = tampered['adversarialReviewQueue'] as Map<String, dynamic>
      ..['status'] = 'complete';

    final issues = EvalUseCaseNextRunWorkOrder.validate(tampered);

    expect(queue['status'], 'complete');
    expect(
      issues,
      contains('workOrderRef must match next-run work-order subject'),
    );
  });

  test(
    'writes use-case next-run work order',
    () {
      final plan =
          jsonDecode(File(_workOrderInputPath).readAsStringSync())
              as Map<String, dynamic>;
      final workOrder = EvalUseCaseNextRunWorkOrder.build(
        experimentPlan: plan,
      );
      EvalUseCaseNextRunWorkOrder.assertValid(workOrder);
      EvalUseCaseNextRunWorkOrder.assertMatchesExperimentPlan(
        workOrder,
        experimentPlan: plan,
      );
      writeEvalJsonArtifact(
        workOrder,
        path: _workOrderOutputPath,
        overwrite: _workOrderOverwrite == '1',
        description: 'use-case next-run work order',
      );
    },
    skip: _workOrderInputPath.isEmpty || _workOrderOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_NEXT_RUN_WORK_ORDER_INPUT=<json> and '
              'EVAL_USE_CASE_NEXT_RUN_WORK_ORDER=<json> to write a work order.'
        : false,
  );
}

Map<String, dynamic> _experimentPlan({
  required List<Map<String, dynamic>> reports,
  int maxBatches = 6,
  int maxCellsPerBatch = 1,
}) {
  final matrix = EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: reports,
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
  return EvalUseCaseExperimentPlan.build(
    matrix: matrix,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
    maxBatches: maxBatches,
    maxCellsPerBatch: maxCellsPerBatch,
  );
}

Map<String, dynamic> _restampWorkOrderToPlan(
  Map<String, dynamic> workOrder,
  Map<String, dynamic> plan,
) {
  final restamped = jsonDecode(jsonEncode(workOrder)) as Map<String, dynamic>;
  final sourcePlan = restamped['sourceExperimentPlan'] as Map<String, dynamic>;
  final sourceMatrix = plan['sourceMatrix'] as Map<String, dynamic>;
  final planDigest = EvalProvenance.digestJson(plan);
  final sourceMatrixDigest = sourceMatrix['matrixDigest'] as String;
  sourcePlan
    ..['status'] = plan['status']
    ..['planDigest'] = planDigest
    ..['sourceMatrixDigest'] = sourceMatrixDigest
    ..['sourceBatchCount'] = (plan['batches'] as List<dynamic>).length
    ..['contractIssueCount'] = 0;

  final batches = (restamped['runBatches'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final batch in batches) {
    batch['workOrderBatchRef'] = EvalProvenance.digestJson(
      <String, dynamic>{
        'planDigest': planDigest,
        'sourceMatrixDigest': sourceMatrixDigest,
        'sourcePlanBatchRef': batch['sourcePlanBatchRef'],
        'compatibilityKey': batch['compatibilityKey'],
        'sourceCellKeys': batch['sourceCellKeys'],
        'publicEnv': batch['publicEnv'],
      },
    );
  }

  final batchRefs = [
    for (final batch in batches) batch['workOrderBatchRef'] as String,
  ]..sort();
  final blockedCodes = List<String>.from(
    restamped['blockedReasonCodes'] as List<dynamic>,
  )..sort();
  final tasks =
      ((restamped['adversarialReviewQueue'] as Map<String, dynamic>)['tasks']
              as List<dynamic>)
          .cast<Map<String, dynamic>>();
  for (final task in tasks) {
    final category = task['category'] as String;
    final source = <String, dynamic>{
      'category': category,
      'sourcePlanDigest': planDigest,
      'sourceMatrixDigest': sourceMatrixDigest,
      'blockedCodes': blockedCodes,
      'batchRefs': batchRefs,
    };
    task
      ..['reviewRef'] = EvalProvenance.digestJson(source)
      ..['sourceRefs'] = <String, dynamic>{
        'sourcePlanDigest': planDigest,
        'sourceMatrixDigest': sourceMatrixDigest,
        'workOrderBatchRefs': batchRefs,
        'blockedReasonCodes': blockedCodes,
      };
  }
  restamped['workOrderRef'] = EvalUseCaseNextRunWorkOrder.workOrderRef(
    restamped,
  );
  return restamped;
}

Map<String, dynamic> _report({
  required String runId,
  bool ready = false,
  String promotionStatus = 'notRequested',
  String scenarioId = 'task_workflow_structured_update',
  String scenarioSetSeed = 'scenario-set',
  String primaryCapabilityId = 'task.workflow',
  String modelClass = 'frontier',
  String promptVariantName = 'default',
  List<String> requiredCapabilities = const ['task.workflow'],
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
        'requiredPrimaryCapabilityIds': requiredCapabilities,
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
      'missingRequiredPrimaryCapabilityIds': const <String>[],
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
      'missingRequiredPrimaryCapabilityIds': const <String>[],
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
      'requiredCapabilities': requiredCapabilities,
      'suggestedCapabilities': requiredCapabilities,
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
