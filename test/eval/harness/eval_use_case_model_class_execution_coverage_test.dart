import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../scenarios/eval_scenario_catalog.dart';
import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_profile_config.dart';

const _coverageWorkOrderInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER',
);
const _coverageExperimentPlanInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN',
);
const _coverageEvidenceInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE',
);
const _coverageRunIds = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS',
);
const _coverageOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_COVERAGE',
);
const _coverageOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_COVERAGE_OVERWRITE',
);
const _runsRoot = String.fromEnvironment('EVAL_RUNS_ROOT');
const _scenarioCatalogPath = String.fromEnvironment(
  kEvalScenarioCatalogPathEnv,
);
const _scenarioCatalogMode = String.fromEnvironment(
  kEvalScenarioCatalogModeEnv,
);
const _scenarioIds = String.fromEnvironment(kEvalScenarioIdsEnv);
const _profileCatalogValue = String.fromEnvironment(kEvalProfilesPathEnv);
const _profileNames = String.fromEnvironment(kEvalProfileNamesEnv);
const _promptVariantCatalogValue = String.fromEnvironment(
  kEvalPromptVariantsPathEnv,
);
const _promptVariantNames = String.fromEnvironment(
  kEvalPromptVariantNamesEnv,
);

void main() {
  test('covers all enum model classes without private execution values', () {
    final fixture = _sourceCheckedCoverageFixture();
    final coverage = fixture.coverage;

    expect(EvalUseCaseModelClassExecutionCoverage.validate(coverage), isEmpty);
    expect(
      EvalUseCaseModelClassExecutionCoverage.validateAgainstSources(
        coverage,
        workOrder: fixture.workOrder,
        sourceExecutionEvidenceBundles: [fixture.evidenceBundle],
        runs: [fixture.run],
        sourceExperimentPlan: fixture.sourceExperimentPlan,
      ),
      isEmpty,
    );
    expect(
      EvalProvenance.isDigest(coverage['coverageArtifactRef'] as String),
      isTrue,
    );
    expect(
      coverage['coverageArtifactRef'],
      EvalUseCaseModelClassExecutionCoverage.coverageArtifactRef(coverage),
    );
    expect(coverage['status'], 'covered');
    final policy = coverage['coveragePolicy'] as Map<String, dynamic>;
    expect(
      policy['requiredModelClasses'],
      unorderedEquals(
        EvalModelClass.values.map((modelClass) => modelClass.name),
      ),
    );
    final summary = coverage['summary'] as Map<String, dynamic>;
    expect(summary['requiredModelClassCount'], 4);
    expect(summary['coveredModelClassCount'], 4);
    expect(summary['missingModelClassCount'], 0);
    expect(summary['observedTraceCount'], 4);
    expect(
      const JsonEncoder().convert(coverage),
      allOf(
        [
          isNot(contains('frontier-gemini')),
          isNot(contains('provider-model')),
          isNot(contains('provider-id')),
          isNot(contains('profile-id')),
          isNot(contains('raw-run-id')),
          isNot(contains('task_workflow_structured_update')),
          isNot(contains('/private/')),
          isNot(contains('EVAL_PROFILE_NAMES')),
        ],
      ),
    );
  });

  test('source replay rejects narrowed model-class coverage policy', () {
    final fixture = _sourceCheckedCoverageFixture(
      modelClasses: const [EvalModelClass.frontierFast],
    );
    final narrowedCoverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: fixture.workOrder,
      sourceExecutionEvidenceBundles: [fixture.evidenceBundle],
      requiredModelClasses: const [EvalModelClass.frontierFast],
      sourceCheckProof:
          EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources(
            workOrder: fixture.workOrder,
            sourceExecutionEvidenceBundles: [fixture.evidenceBundle],
            runs: [fixture.run],
            sourceExperimentPlan: fixture.sourceExperimentPlan,
          ),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(
      EvalUseCaseModelClassExecutionCoverage.validate(narrowedCoverage),
      isEmpty,
    );
    expect(narrowedCoverage['status'], 'covered');
    expect(
      EvalUseCaseModelClassExecutionCoverage.hasVerifiedConcreteSourceReplay(
        narrowedCoverage,
      ),
      isFalse,
    );
    expect(
      EvalUseCaseModelClassExecutionCoverage.validateAgainstSources(
        narrowedCoverage,
        workOrder: fixture.workOrder,
        sourceExecutionEvidenceBundles: [fixture.evidenceBundle],
        runs: [fixture.run],
        sourceExperimentPlan: fixture.sourceExperimentPlan,
      ),
      contains(
        'coveragePolicy must match source work order, evidence, and runs',
      ),
    );
  });

  test('contract rejects stale coverage artifact refs', () {
    final coverage = _sourceCheckedCoverageFixture().coverage;
    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
    final policy = tampered['coveragePolicy'] as Map<String, dynamic>
      ..['minProfileSlotsPerClass'] = 2;

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(policy['minProfileSlotsPerClass'], 2);
    expect(
      issues,
      contains(
        'coverageArtifactRef must match model-class coverage subject',
      ),
    );
  });

  test('marks partial coverage when a required model class is missing', () {
    final fixture = _sourceCheckedCoverageFixture(
      modelClasses: const [
        EvalModelClass.localSmall,
        EvalModelClass.localReasoning,
        EvalModelClass.frontierFast,
      ],
    );
    final coverage = fixture.coverage;

    expect(coverage['status'], 'partialCoverage');
    final summary = coverage['summary'] as Map<String, dynamic>;
    expect(summary['coveredModelClassCount'], 3);
    expect(summary['missingModelClassCount'], 1);
    final classes = (coverage['modelClassCoverage'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final missing = classes.singleWhere(
      (entry) => entry['modelClass'] == EvalModelClass.frontierReasoning.name,
    );
    expect(missing['status'], 'missing');
    final issues = (coverage['issues'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      issues.map((issue) => issue['code']),
      contains('coverage.modelClassMissing'),
    );
  });

  test('binds source execution evidence bundle digest into coverage refs', () {
    final fixture = _sourceCheckedCoverageFixture();
    final coverage = fixture.coverage;
    final evidenceBundle = fixture.evidenceBundle;

    expect(EvalUseCaseModelClassExecutionCoverage.validate(coverage), isEmpty);
    expect(coverage['status'], 'covered');
    final sourceEvidence =
        coverage['sourceExecutionEvidence'] as Map<String, dynamic>;
    final bundleDigest = EvalProvenance.digestJson(evidenceBundle);
    expect(sourceEvidence['present'], isTrue);
    expect(sourceEvidence['bundleDigests'], [bundleDigest]);
    expect(sourceEvidence['concreteSourceChecked'], isTrue);
    expect(sourceEvidence['sourceCheckProof'], isA<Map<String, dynamic>>());
    expect(
      sourceEvidence['bundleSetDigest'],
      EvalProvenance.digestJson([bundleDigest]),
    );

    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
    (tampered['sourceExecutionEvidence']
        as Map<String, dynamic>)['bundleSetDigest'] = EvalProvenance.digestText(
      'tampered-bundle-set',
    );

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(
      issues,
      contains(
        'sourceExecutionEvidence.bundleSetDigest must bind bundleDigests',
      ),
    );
    expect(
      issues,
      contains(
        'modelClassCoverage[0].coverageRef must bind model-class coverage fields',
      ),
    );
    expect(
      issues,
      contains(
        'coverageCells[0].coverageCellRef must bind coverage cell fields',
      ),
    );
  });

  test('contract rejects forged source-check proof bindings', () {
    final coverage = _sourceCheckedCoverageFixture().coverage;
    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
    final sourceEvidence =
        tampered['sourceExecutionEvidence'] as Map<String, dynamic>;
    sourceEvidence['sourceCheckProof'] as Map<String, dynamic>
      ..['workOrderDigest'] = EvalProvenance.digestText('other-work-order')
      ..['bundleSetDigest'] = EvalProvenance.digestText('other-bundle-set')
      ..['executionEvidenceRefs'] = [
        EvalProvenance.digestText('other-evidence-ref'),
      ]
      ..['sourceRunCount'] = 42
      ..['sourceRunRefsDigest'] = EvalProvenance.digestText(
        'other-source-runs',
      );
    sourceEvidence['sourceCheckSetDigest'] = EvalProvenance.digestText(
      'other-source-check-set',
    );
    tampered['coverageArtifactRef'] =
        EvalUseCaseModelClassExecutionCoverage.coverageArtifactRef(tampered);

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(
      issues,
      contains(
        'sourceExecutionEvidence.sourceCheckSetDigest must bind source check refs',
      ),
    );
    expect(
      issues,
      contains(
        'sourceExecutionEvidence.sourceCheckProof.sourceCheckRef must bind source-check proof fields',
      ),
    );
    expect(
      issues,
      contains(
        'sourceExecutionEvidence.sourceCheckProof.workOrderDigest must match sourceWorkOrder.workOrderDigest',
      ),
    );
    expect(
      issues,
      contains(
        'sourceExecutionEvidence.sourceCheckProof.bundleSetDigest must match sourceExecutionEvidence.bundleSetDigest',
      ),
    );
    expect(
      issues,
      contains(
        'sourceExecutionEvidence.sourceCheckProof.executionEvidenceRefs must match sourceExecutionEvidence.executionEvidenceRefs',
      ),
    );
    expect(
      issues,
      contains(
        'sourceExecutionEvidence.sourceCheckProof.sourceRunCount must match sourceExecutionEvidence.sourceRunCount',
      ),
    );
    expect(
      issues,
      contains(
        'sourceExecutionEvidence.sourceCheckProof.sourceRunRefsDigest must match sourceExecutionEvidence.sourceRunRefsDigest',
      ),
    );
  });

  test('artifact-only source-check proofs cannot mint coverage', () {
    final workOrder = _workOrder();
    final evidenceBundle = _executionEvidenceBundle(workOrder);

    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: [evidenceBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 13),
      sourceCheckProof: _sourceCheckProof(workOrder, [evidenceBundle]),
    );

    expect(EvalUseCaseModelClassExecutionCoverage.validate(coverage), isEmpty);
    expect(coverage['status'], 'invalidSource');
    expect(
      (coverage['sourceExecutionEvidence']
          as Map<String, dynamic>)['concreteSourceChecked'],
      isFalse,
    );
    expect(
      (coverage['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['message'],
      ),
      contains('sourceCheckProof must be concrete source-checked evidence'),
    );
  });

  test('unchecked execution evidence bundles cannot mint coverage', () {
    final workOrder = _workOrder();

    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: [_executionEvidenceBundle(workOrder)],
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(EvalUseCaseModelClassExecutionCoverage.validate(coverage), isEmpty);
    expect(coverage['status'], 'invalidSource');
    expect(
      (coverage['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['code'],
      ),
      contains('coverage.executionEvidenceSourceNotChecked'),
    );
    expect(coverage['modelClassCoverage'], isEmpty);
    expect(coverage['coverageCells'], isEmpty);
  });

  test('forged source-checked flag without proof cannot mint coverage', () {
    final workOrder = _workOrder();
    final evidenceBundle = _executionEvidenceBundle(workOrder);

    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: [evidenceBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 13),
      sourceEvidenceSourceChecked: true,
    );

    expect(EvalUseCaseModelClassExecutionCoverage.validate(coverage), isEmpty);
    expect(coverage['status'], 'invalidSource');
    final sourceEvidence =
        coverage['sourceExecutionEvidence'] as Map<String, dynamic>;
    expect(sourceEvidence['concreteSourceChecked'], isFalse);
    expect(sourceEvidence, isNot(contains('sourceCheckProof')));
    expect(
      (coverage['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['code'],
      ),
      containsAll([
        'coverage.executionEvidenceSourceNotChecked',
        'coverage.executionEvidenceSourceCheckProofMissing',
      ]),
    );
  });

  test('blocks execution evidence bundles bound to a stale work order', () {
    final workOrder = _workOrder();
    final staleWorkOrder = _workOrder(runId: 'stale-ready-run');
    final staleEvidenceBundle = _executionEvidenceBundle(staleWorkOrder);

    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: [staleEvidenceBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 13),
      sourceCheckProof: _sourceCheckProof(staleWorkOrder, [
        staleEvidenceBundle,
      ]),
    );

    expect(coverage['status'], 'invalidSource');
    expect(
      (coverage['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['code'],
      ),
      contains('coverage.executionEvidenceWorkOrderMismatch'),
    );
  });

  test('contract rejects restamped work-order metadata', () {
    final fixture = _sourceCheckedCoverageFixture();
    final staleWorkOrder = _workOrder(runId: 'stale-ready-run');
    final restamped = _restampCoverageToWorkOrder(
      fixture.coverage,
      staleWorkOrder,
    );

    expect(
      EvalUseCaseModelClassExecutionCoverage.validate(restamped),
      contains(
        'sourceExecutionEvidence.sourceWorkOrderDigests must match sourceWorkOrder.workOrderDigest',
      ),
    );
  });

  test('raw execution rows cannot mint public coverage', () {
    final workOrder = _workOrder();

    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      executionEvidence: _evidenceForAllClasses(workOrder),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(EvalUseCaseModelClassExecutionCoverage.validate(coverage), isEmpty);
    expect(coverage['status'], 'invalidSource');
    expect(
      (coverage['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['code'],
      ),
      contains('coverage.executionEvidenceBundleMissing'),
    );
    expect(coverage['modelClassCoverage'], isEmpty);
    expect(coverage['coverageCells'], isEmpty);
  });

  test('rejects non-enum model classes from policy and evidence', () {
    final workOrder = _workOrder();
    final invalidEvidence = [
      _evidence(
        workOrder,
        modelClass: 'frontier',
      ),
    ];
    final invalidEvidenceBundle = _executionEvidenceBundle(
      workOrder,
      evidenceRows: invalidEvidence,
    );

    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: [invalidEvidenceBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 13),
      sourceCheckProof: _sourceCheckProof(workOrder, [invalidEvidenceBundle]),
    );

    expect(coverage['status'], 'invalidSource');
    expect(
      (coverage['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['code'],
      ),
      contains('coverage.executionEvidenceModelClassInvalid'),
    );

    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
    (tampered['coveragePolicy']
        as Map<String, dynamic>)['requiredModelClasses'] = const [
      'frontier',
      'model-123456789abc',
    ];

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(
      issues,
      contains(
        'coveragePolicy.requiredModelClasses contains unsupported model class frontier',
      ),
    );
    expect(
      issues,
      contains(
        'coveragePolicy.requiredModelClasses contains unsupported model class model-123456789abc',
      ),
    );
  });

  test('contract rejects recursive private execution payload', () {
    final coverage = _sourceCheckedCoverageFixture().coverage;
    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>
      ..['profileNames'] = const ['frontier-gemini']
      ..['providerModelId'] = 'provider-model-secret'
      ..['modelId'] = 'model-config-secret'
      ..['providerId'] = 'provider-secret'
      ..['runId'] = 'raw-run-id'
      ..['scenarioIds'] = const ['task_workflow_structured_update']
      ..['path'] = '/private/tmp/coverage.json'
      ..['promptText'] = 'raw private prompt'
      ..['notes'] =
          'Use EVAL_PROFILE_NAMES and OPENAI_API_KEY from /private/tmp/profiles.json';

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(
      issues,
      contains('coverage.profileNames must not expose profile selectors'),
    );
    expect(
      issues,
      contains(
        'coverage.providerModelId must not expose provider or model ids',
      ),
    );
    expect(
      issues,
      contains('coverage.modelId must not expose provider or model ids'),
    );
    expect(
      issues,
      contains('coverage.providerId must not expose provider or model ids'),
    );
    expect(issues, contains('coverage.runId must not expose run ids'));
    expect(
      issues,
      contains('coverage.scenarioIds must not expose scenario ids'),
    );
    expect(issues, contains('coverage.path must not expose private paths'));
    expect(issues, contains('coverage.path must not contain private paths'));
    expect(issues, contains('coverage.promptText must not expose prompt text'));
    expect(
      issues,
      contains('coverage.notes must not contain private env value keys'),
    );
    expect(issues, contains('coverage.notes must not contain private paths'));
  });

  test('contract rejects forged source metadata status strings', () {
    final coverage = _sourceCheckedCoverageFixture().coverage;
    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
    (tampered['sourceWorkOrder'] as Map<String, dynamic>)['status'] =
        'frontier-gemini';
    (tampered['sourceExecutionEvidence']
        as Map<String, dynamic>)['statuses'] = const [
      'profile-frontier-gemini',
    ];

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(
      issues,
      contains('sourceWorkOrder.status must be a work-order status'),
    );
    expect(
      issues,
      contains(
        'sourceExecutionEvidence.statuses must contain evidence statuses',
      ),
    );
  });

  test('contract binds and sanitizes recommended commands', () {
    final coverage = _sourceCheckedCoverageFixture().coverage;
    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
    final command =
        (tampered['recommendedCommands'] as List<dynamic>).first
            as Map<String, dynamic>;
    command['command'] =
        'eval/run_level2.sh model-class-coverage; curl https://example.invalid';

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(
      issues,
      contains(
        'coverageArtifactRef must match model-class coverage subject',
      ),
    );
    expect(
      issues,
      contains(
        'recommendedCommands must match model-class coverage commands',
      ),
    );
  });

  test('contract binds coverage refs to counts, selectors, and batch refs', () {
    final coverage = _sourceCheckedCoverageFixture().coverage;
    final tampered = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
    final cell =
        (tampered['coverageCells'] as List<dynamic>).first
              as Map<String, dynamic>
          ..['observedTraceCount'] = 99
          ..['workOrderBatchRef'] = EvalProvenance.digestText('other-batch');
    (cell['publicSelectors'] as Map<String, dynamic>)['capabilities'] = const [
      'task.workflow.changed',
    ];
    final modelClassCoverage =
        (tampered['modelClassCoverage'] as List<dynamic>).first
            as Map<String, dynamic>;
    modelClassCoverage['observedTraceCount'] = 99;

    final issues = EvalUseCaseModelClassExecutionCoverage.validate(tampered);

    expect(
      issues,
      contains(
        'coverageCells[0].coverageCellRef must bind coverage cell fields',
      ),
    );
    expect(
      issues,
      contains(
        'modelClassCoverage[0].coverageRef must bind model-class coverage fields',
      ),
    );
  });

  test(
    'writes use-case model-class execution coverage',
    () async {
      final workOrder =
          jsonDecode(File(_coverageWorkOrderInputPath).readAsStringSync())
              as Map<String, dynamic>;
      final experimentPlan =
          jsonDecode(
                File(_coverageExperimentPlanInputPath).readAsStringSync(),
              )
              as Map<String, dynamic>;
      EvalUseCaseNextRunWorkOrder.assertMatchesExperimentPlan(
        workOrder,
        experimentPlan: experimentPlan,
      );
      final evidenceBundles = [
        for (final path
            in _coverageEvidenceInputPaths
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty))
          _readEvidenceBundle(path),
      ];
      if (evidenceBundles.length != 1) {
        throw StateError(
          'Model-class coverage writer requires exactly one execution '
          'evidence bundle generated from '
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS.',
        );
      }
      final runs = await _loadSourceRuns();
      final coverage = EvalUseCaseModelClassExecutionCoverage.build(
        workOrder: workOrder,
        sourceExecutionEvidenceBundles: evidenceBundles,
        sourceCheckProof:
            EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources(
              workOrder: workOrder,
              sourceExecutionEvidenceBundles: evidenceBundles,
              runs: runs,
              sourceExperimentPlan: experimentPlan,
            ),
      );
      EvalUseCaseModelClassExecutionCoverage.assertValid(coverage);
      EvalUseCaseModelClassExecutionCoverage.assertMatchesSources(
        coverage,
        workOrder: workOrder,
        sourceExecutionEvidenceBundles: evidenceBundles,
        runs: runs,
        sourceExperimentPlan: experimentPlan,
      );
      writeEvalJsonArtifact(
        coverage,
        path: _coverageOutputPath,
        overwrite: _coverageOverwrite == '1',
        description: 'use-case model-class coverage',
      );
    },
    skip:
        _coverageWorkOrderInputPath.isEmpty ||
            _coverageExperimentPlanInputPath.isEmpty ||
            _coverageEvidenceInputPaths.isEmpty ||
            _coverageRunIds.isEmpty ||
            _coverageOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER=<json>, '
              'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN=<json>, '
              'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE=<json>, '
              'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS=<id,...>, and '
              'EVAL_USE_CASE_MODEL_CLASS_COVERAGE=<json> to write coverage.'
        : false,
  );
}

Future<List<EvalUseCaseModelClassExecutionRun>> _loadSourceRuns() async {
  const writer = TraceWriter(runsRoot: _runsRoot);
  final catalog = _loadScenarioCatalog();
  final profiles = _loadProfiles();
  final promptVariants = _loadPromptVariants();
  final runs = <EvalUseCaseModelClassExecutionRun>[];
  for (final runId in _csv(_coverageRunIds)) {
    runs.add(
      EvalUseCaseModelClassExecutionRun(
        artifacts: await writer.readRun(runId),
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
      ),
    );
  }
  return runs;
}

EvalScenarioCatalog _loadScenarioCatalog() {
  return EvalScenarioCatalogLoader.fromEnvironment(
    Platform.environment,
    // ignore: avoid_redundant_argument_values
    dartDefinePath: _scenarioCatalogPath,
    // ignore: avoid_redundant_argument_values
    dartDefineMode: _scenarioCatalogMode,
    // ignore: avoid_redundant_argument_values
    dartDefineScenarioIds: _scenarioIds,
  );
}

List<EvalProfile> _loadProfiles() {
  return EvalProfileCatalogLoader.fromEnvironment(
    Platform.environment,
    // ignore: avoid_redundant_argument_values
    dartDefineValue: _profileCatalogValue,
    // ignore: avoid_redundant_argument_values
    dartDefineProfileNames: _profileNames,
  ).profiles;
}

List<EvalAgentDirectiveVariant> _loadPromptVariants() {
  return EvalAgentDirectiveVariantCatalogLoader.fromEnvironment(
    Platform.environment,
    // ignore: avoid_redundant_argument_values
    dartDefineValue: _promptVariantCatalogValue,
    // ignore: avoid_redundant_argument_values
    dartDefineVariantNames: _promptVariantNames,
  ).variants;
}

List<String> _csv(String value) => [
  for (final item in value.split(','))
    if (item.trim().isNotEmpty) item.trim(),
];

Map<String, dynamic> _workOrder({
  String runId = 'ready-run',
  Map<String, dynamic>? sourceExperimentPlan,
}) {
  final plan = sourceExperimentPlan ?? _experimentPlan(runId: runId);
  return EvalUseCaseNextRunWorkOrder.build(
    experimentPlan: plan,
    generatedAt: DateTime.utc(2026, 6, 12, 12),
  );
}

Map<String, dynamic> _experimentPlan({String runId = 'ready-run'}) {
  final matrix = EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: [
      _report(runId: runId, ready: true),
    ],
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
  return EvalUseCaseExperimentPlan.build(
    matrix: matrix,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
  );
}

Map<String, dynamic> _restampCoverageToWorkOrder(
  Map<String, dynamic> coverage,
  Map<String, dynamic> workOrder,
) {
  final restamped = jsonDecode(jsonEncode(coverage)) as Map<String, dynamic>;
  final sourceWorkOrder = restamped['sourceWorkOrder'] as Map<String, dynamic>;
  final workOrderSource =
      workOrder['sourceExperimentPlan'] as Map<String, dynamic>;
  sourceWorkOrder
    ..['status'] = workOrder['status']
    ..['workOrderDigest'] = EvalProvenance.digestJson(workOrder)
    ..['sourceExperimentPlanDigest'] = workOrderSource['planDigest']
    ..['sourceMatrixDigest'] = workOrderSource['sourceMatrixDigest']
    ..['runBatchCount'] = (workOrder['runBatches'] as List<dynamic>).length
    ..['contractIssueCount'] = 0;
  final workOrderDigest = sourceWorkOrder['workOrderDigest'] as String;
  final sourceExecutionEvidence =
      restamped['sourceExecutionEvidence'] as Map<String, dynamic>;
  final sourceExecutionEvidenceSetDigest =
      sourceExecutionEvidence['bundleSetDigest'] as String;
  final cells = (restamped['coverageCells'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final cell in cells) {
    cell['coverageCellRef'] = EvalProvenance.digestJson(<String, dynamic>{
      'workOrderDigest': workOrderDigest,
      'sourceExecutionEvidenceSetDigest': sourceExecutionEvidenceSetDigest,
      'workOrderBatchRef': cell['workOrderBatchRef'],
      'modelClass': cell['modelClass'],
      'publicSelectors': cell['publicSelectors'],
      'objective': cell['objective'],
      'expectedTraceCount': cell['expectedTraceCount'],
      'observedTraceCount': cell['observedTraceCount'],
      'verifiedResolvedModelTraceCount':
          cell['verifiedResolvedModelTraceCount'],
      'status': cell['status'],
      'issueCodes': cell['issueCodes'],
    });
  }
  final modelClassCoverage = (restamped['modelClassCoverage'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final coverage in modelClassCoverage) {
    coverage['coverageRef'] = EvalProvenance.digestJson(<String, dynamic>{
      'workOrderDigest': workOrderDigest,
      'sourceExecutionEvidenceSetDigest': sourceExecutionEvidenceSetDigest,
      'modelClass': coverage['modelClass'],
      'status': coverage['status'],
      'expectedProfileSlotCount': coverage['expectedProfileSlotCount'],
      'observedProfileSlotCount': coverage['observedProfileSlotCount'],
      'expectedTraceCount': coverage['expectedTraceCount'],
      'observedTraceCount': coverage['observedTraceCount'],
      'verifiedResolvedModelTraceCount':
          coverage['verifiedResolvedModelTraceCount'],
      'workOrderBatchRefs': coverage['workOrderBatchRefs'],
    });
  }
  restamped['coverageArtifactRef'] =
      EvalUseCaseModelClassExecutionCoverage.coverageArtifactRef(restamped);
  return restamped;
}

Map<String, dynamic> _executionEvidenceBundle(
  Map<String, dynamic> workOrder, {
  List<Map<String, dynamic>>? evidenceRows,
}) {
  final sourceRun = _sourceRunFixture(workOrder);
  final workOrderSource =
      workOrder['sourceExperimentPlan'] as Map<String, dynamic>;
  final runBatchRefs = [
    for (final batch in (workOrder['runBatches'] as List<dynamic>))
      (batch as Map<String, dynamic>)['workOrderBatchRef'] as String,
  ]..sort();
  final rows = [
    for (final row in evidenceRows ?? _evidenceForAllClasses(workOrder))
      _stampedEvidenceRow(
        row,
        sourceRunRef: sourceRun['sourceRunRef'] as String,
      ),
  ];
  final bundle = <String, dynamic>{
    'schemaVersion': EvalUseCaseModelClassExecutionEvidence.schemaVersion,
    'kind': EvalUseCaseModelClassExecutionEvidence.kind,
    'executionEvidenceRef': '',
    'generatedAt': DateTime.utc(2026, 6, 12, 12, 30).toIso8601String(),
    'status': 'ready',
    'sourceWorkOrder': <String, dynamic>{
      'kind': EvalUseCaseNextRunWorkOrder.kind,
      'schemaVersion': EvalUseCaseNextRunWorkOrder.schemaVersion,
      'status': workOrder['status'],
      'workOrderRef': workOrder['workOrderRef'],
      'workOrderDigest': EvalProvenance.digestJson(workOrder),
      'sourceExperimentPlanDigest': workOrderSource['planDigest'],
      'sourceMatrixDigest': workOrderSource['sourceMatrixDigest'],
      'runBatchCount': (workOrder['runBatches'] as List<dynamic>).length,
      'runBatchRefsDigest': EvalProvenance.digestJson(runBatchRefs),
      'contractIssueCount': 0,
    },
    'summary': <String, dynamic>{
      'sourceRunCount': 1,
      'evidenceRowCount': rows.length,
      'expectedTraceCount': _sumRows(rows, 'expectedTraceCount'),
      'observedTraceCount': _sumRows(rows, 'observedTraceCount'),
      'verifiedResolvedModelTraceCount': _sumRows(
        rows,
        'verifiedResolvedModelTraceCount',
      ),
      'issueCount': 0,
    },
    'privacy': const <String, dynamic>{
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
      'rawRunIdsOmitted': true,
      'providerIdsOmitted': true,
      'providerModelIdsOmitted': true,
      'localConfigIdsOmitted': true,
      'providerEndpointsOmitted': true,
      'promptTextOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
    },
    'limitations': const <String, dynamic>{
      'readsPrivateRunArtifacts': true,
      'readsPrivateExpectedCatalogs': true,
      'writesSanitizedEvidenceRowsOnly': true,
      'publicCoverageComputedElsewhere': true,
      'liveModelCallsStarted': false,
    },
    'sourceRuns': [sourceRun],
    'evidenceRows': rows,
    'issues': const <Map<String, dynamic>>[],
  };
  bundle['executionEvidenceRef'] =
      EvalUseCaseModelClassExecutionEvidence.executionEvidenceRef(bundle);
  return bundle;
}

EvalUseCaseModelClassExecutionCoverageSourceCheckProof _sourceCheckProof(
  Map<String, dynamic> workOrder,
  List<Map<String, dynamic>> evidenceBundles,
) {
  return EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromValidatedEvidenceBundles(
    workOrder: workOrder,
    sourceExecutionEvidenceBundles: evidenceBundles,
  );
}

_CoverageFixture _sourceCheckedCoverageFixture({
  Map<String, dynamic>? workOrder,
  List<EvalModelClass> modelClasses = EvalModelClass.values,
  DateTime? coverageGeneratedAt,
}) {
  final sourceExperimentPlan = _experimentPlan();
  final sourceWorkOrder =
      workOrder ?? _workOrder(sourceExperimentPlan: sourceExperimentPlan);
  final runFixture = _runFixture(
    workOrder: sourceWorkOrder,
    modelClasses: modelClasses,
  );
  final evidenceBundle = EvalUseCaseModelClassExecutionEvidence.build(
    workOrder: sourceWorkOrder,
    runs: [runFixture.run],
    sourceExperimentPlan: sourceExperimentPlan,
    generatedAt: DateTime.utc(2026, 6, 12, 12, 30),
  );
  final sourceCheckProof =
      EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources(
        workOrder: sourceWorkOrder,
        sourceExecutionEvidenceBundles: [evidenceBundle],
        runs: [runFixture.run],
        sourceExperimentPlan: sourceExperimentPlan,
      );
  final coverage = EvalUseCaseModelClassExecutionCoverage.build(
    workOrder: sourceWorkOrder,
    sourceExecutionEvidenceBundles: [evidenceBundle],
    generatedAt: coverageGeneratedAt ?? DateTime.utc(2026, 6, 12, 13),
    sourceCheckProof: sourceCheckProof,
  );
  EvalUseCaseModelClassExecutionCoverage.assertMatchesSources(
    coverage,
    workOrder: sourceWorkOrder,
    sourceExecutionEvidenceBundles: [evidenceBundle],
    runs: [runFixture.run],
    sourceExperimentPlan: sourceExperimentPlan,
  );
  return _CoverageFixture(
    workOrder: sourceWorkOrder,
    sourceExperimentPlan: sourceExperimentPlan,
    evidenceBundle: evidenceBundle,
    run: runFixture.run,
    coverage: coverage,
  );
}

_RunFixture _runFixture({
  required Map<String, dynamic> workOrder,
  List<EvalModelClass> modelClasses = EvalModelClass.values,
}) {
  final scenario = _scenario();
  final profiles = [
    for (final modelClass in modelClasses) _profile(modelClass, trialCount: 1),
  ];
  final readinessContractEvidence =
      EvalProvenance.tuningReadinessContractEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest([scenario]),
        requiredPrimaryCapabilityIds: {'task.workflow'},
      );
  final manifest = EvalProvenance.captureRunManifest(
    runId:
        'private-coverage-run-${modelClasses.map((value) => value.name).join('-')}',
    targetName: 'fixture target',
    targetKind: 'fixture',
    scenarios: [scenario],
    profiles: profiles,
    createdAt: DateTime.utc(2026, 6, 12, 12, 15),
    command: 'eval/run_level2.sh run private-coverage-run',
    environment: const {},
    tuningReadinessContractEvidence: readinessContractEvidence,
    useCaseWorkOrderLaunchEvidence:
        EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
          workOrder: workOrder,
          requiredPrimaryCapabilityIds: {'task.workflow'},
          promptVariantNames: const ['default'],
        ),
  );
  final traces = [
    for (final profile in profiles)
      _trace(manifest: manifest, scenario: scenario, profile: profile),
  ];
  return _RunFixture(
    run: EvalUseCaseModelClassExecutionRun(
      artifacts: EvalRunArtifacts(
        manifest: manifest,
        traces: traces,
        artifactNames: const ['manifest.json'],
      ),
      scenarios: [scenario],
      profiles: profiles,
    ),
  );
}

EvalScenario _scenario() {
  return EvalScenario(
    id: 'private-scenario',
    title: 'Private scenario',
    agentKind: AgentKind.taskAgent,
    appState: MockedAppState(now: DateTime(2026, 6, 12, 12)),
    userInput: const UserInput(
      transcript: 'Arrange the task list',
      triggerTokens: {'trigger:task'},
    ),
    metadata: const EvalScenarioMetadata(
      capabilityIds: ['task.workflow'],
    ),
  );
}

EvalProfile _profile(EvalModelClass modelClass, {required int trialCount}) {
  final isLocal =
      modelClass == EvalModelClass.localSmall ||
      modelClass == EvalModelClass.localReasoning;
  return EvalProfile(
    name: '${modelClass.name}-private',
    isLocal: isLocal,
    modelClass: modelClass,
    modelId: '${modelClass.name}-provider-model',
    trialCount: trialCount,
  );
}

EvalTrace _trace({
  required EvalRunManifest manifest,
  required EvalScenario scenario,
  required EvalProfile profile,
}) {
  final binding = manifest.profileExecutionBindings.singleWhere(
    (binding) => binding.profileName == profile.name,
  );
  final runtimePrompt = RuntimePromptRecord(
    systemDigest: EvalProvenance.digestText('system'),
    userDigest: EvalProvenance.digestText('user'),
    toolSchemaDigest: EvalProvenance.digestText('tools'),
  );
  final output = AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 100, outputTokens: 50),
    resolvedModel: ResolvedModelRecord(
      profileId: binding.profileId,
      modelConfigId: binding.modelConfigId,
      providerModelId: binding.providerModelId,
      providerId: binding.providerId,
      providerType: binding.providerType,
      providerEndpointOrigin: binding.providerEndpointOrigin,
      providerBaseUrlDigest: binding.providerBaseUrlDigest,
    ),
    providerDecision: evalProfileConfig(profile).toProviderDecisionRecord(),
    modelInvocations: [
      ModelInvocationRecord(
        invocationIndex: 0,
        providerModelId: binding.providerModelId,
        providerId: binding.providerId,
        providerType: binding.providerType,
        providerEndpointOrigin: binding.providerEndpointOrigin,
        providerBaseUrlDigest: binding.providerBaseUrlDigest,
        runtimePrompt: runtimePrompt,
      ),
    ],
    providerRequests: [
      ProviderRequestRecord(
        invocationIndex: 0,
        requestIndex: 0,
        turnIndex: 0,
        providerModelId: binding.providerModelId,
        providerId: binding.providerId,
        providerType: binding.providerType,
        providerEndpointOrigin: binding.providerEndpointOrigin,
        providerBaseUrlDigest: binding.providerBaseUrlDigest,
        messageDigest: EvalProvenance.digestText('messages'),
        messageCount: 1,
        toolSchemaDigest: EvalProvenance.digestText('tools'),
        toolCount: 0,
        toolNames: const [],
        temperature: binding.providerRequestTemperature,
        thoughtSignatureCount: 0,
      ),
    ],
    turnCount: 1,
  );
  return EvalTrace(
    runId: manifest.runId,
    scenario: scenario,
    profile: profile,
    provenance: EvalTraceProvenance(
      manifestDigest: manifest.manifestDigest!,
      scenarioDigest: EvalProvenance.digestJson(scenario.toJson()),
      profileDigest: EvalProvenance.digestJson(profile.toJson()),
      agentDirectiveVariantDigest: EvalProvenance.agentDirectiveVariantDigest(
        const EvalAgentDirectiveVariant(),
      ),
      promptDigest: manifest.promptDigest,
      toolSchemaDigest: manifest.toolSchemaDigest,
      codeRevision: manifest.codeRevision,
    ),
    output: output,
    level1Checks: runLevel1(scenario, output, profile: profile),
  );
}

Map<String, dynamic> _sourceRunFixture(Map<String, dynamic> workOrder) {
  final launchEvidence = EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
    workOrder: workOrder,
    requiredPrimaryCapabilityIds: {'task.workflow'},
    promptVariantNames: const ['default'],
  );
  final sourceRun = <String, dynamic>{
    'sourceRunRef': '',
    'actualManifestDigest': EvalProvenance.digestText('actual-manifest'),
    'manifestDigest': EvalProvenance.digestText('manifest'),
    'workOrderLaunchSubjectDigest': launchEvidence.workOrderLaunchSubjectDigest,
    'workOrderDigest': launchEvidence.workOrderDigest,
    'workOrderRef': launchEvidence.workOrderRef,
    'workOrderBatchSetDigest': launchEvidence.workOrderBatchSetDigest,
    'workOrderBatchRefs': launchEvidence.workOrderBatchRefs,
    'profileBindingSetDigest': EvalProvenance.digestText('bindings'),
    'scenarioSetDigest': EvalProvenance.digestText('scenario-set'),
    'profileSetDigest': EvalProvenance.digestText('profiles'),
    'agentDirectiveVariantSetDigest': EvalProvenance.digestText(
      'prompt-variants',
    ),
    'readinessContractSubjectDigest': EvalProvenance.digestText(
      'readiness-contract',
    ),
    'traceCount': 4,
    'artifactCount': 8,
    'profileBindingCount': EvalModelClass.values.length,
    'verifierIssueCount': 0,
  };
  sourceRun['sourceRunRef'] = EvalProvenance.digestJson(<String, dynamic>{
    'actualManifestDigest': sourceRun['actualManifestDigest'],
    'manifestDigest': sourceRun['manifestDigest'],
    'workOrderLaunchSubjectDigest': sourceRun['workOrderLaunchSubjectDigest'],
    'workOrderDigest': sourceRun['workOrderDigest'],
    'workOrderRef': sourceRun['workOrderRef'],
    'workOrderBatchSetDigest': sourceRun['workOrderBatchSetDigest'],
    'profileBindingSetDigest': sourceRun['profileBindingSetDigest'],
    'scenarioSetDigest': sourceRun['scenarioSetDigest'],
    'profileSetDigest': sourceRun['profileSetDigest'],
    'agentDirectiveVariantSetDigest':
        sourceRun['agentDirectiveVariantSetDigest'],
    'readinessContractSubjectDigest':
        sourceRun['readinessContractSubjectDigest'],
  });
  return sourceRun;
}

Map<String, dynamic> _stampedEvidenceRow(
  Map<String, dynamic> row, {
  required String sourceRunRef,
}) {
  final stamped = <String, dynamic>{
    'evidenceRowRef': '',
    'sourceRunRef': sourceRunRef,
    ...row,
  };
  stamped['evidenceRowRef'] =
      EvalUseCaseModelClassExecutionEvidence.evidenceRowRef(stamped);
  return stamped;
}

List<Map<String, dynamic>> _evidenceForAllClasses(
  Map<String, dynamic> workOrder,
) {
  return [
    for (final modelClass in EvalModelClass.values)
      _evidence(workOrder, modelClass: modelClass.name),
  ];
}

Map<String, dynamic> _evidence(
  Map<String, dynamic> workOrder, {
  required String modelClass,
}) {
  final batch =
      (workOrder['runBatches'] as List<dynamic>).single as Map<String, dynamic>;
  return <String, dynamic>{
    'workOrderBatchRef': batch['workOrderBatchRef'],
    'modelClass': modelClass,
    'profileSlotRef': EvalProvenance.digestText('slot-$modelClass'),
    'expectedTraceCount': 4,
    'observedTraceCount': 4,
    'verifiedResolvedModelTraceCount': 4,
    'resolvedModelEvidence': true,
    'providerRequestEvidence': true,
  };
}

int _sumRows(List<Map<String, dynamic>> rows, String field) =>
    rows.fold<int>(0, (sum, row) => sum + (row[field] as int));

Map<String, dynamic> _report({
  required String runId,
  bool ready = false,
  String scenarioId = 'task_workflow_structured_update',
  String primaryCapabilityId = 'task.workflow',
  String modelClass = 'frontierReasoning',
  String promptVariantName = 'default',
  List<String> blockingReasonCodes = const ['verdict.missing'],
}) {
  final effectiveBlockers = ready ? const <String>[] : blockingReasonCodes;
  const policyPayload = <String, dynamic>{
    'name': 'modelClassTuning',
    'minJudgePassRateLowerBound': 0.7,
  };
  final policyDigest = EvalProvenance.digestJson(policyPayload);
  final manifestDigest = EvalProvenance.digestText('manifest-$runId');
  return <String, dynamic>{
    'schemaVersion': EvalTuningReportContract.schemaVersion,
    'kind': EvalTuningReportContract.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 9).toIso8601String(),
    'run': <String, dynamic>{
      'runId': runId,
      'targetKind': 'fixture',
      'manifestDigest': manifestDigest,
      'createdAt': DateTime.utc(2026, 6, 12, 8).toIso8601String(),
      'scenarioSetDigest': EvalProvenance.digestText('scenario-set'),
      'profileSetDigest': EvalProvenance.digestText('profiles-$modelClass'),
      'profileBindingSetDigest': EvalProvenance.digestText(
        'bindings-$modelClass',
      ),
      'agentDirectiveVariantSetDigest': EvalProvenance.digestText(
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
        'ownedArtifactRefsDigest': EvalProvenance.digestText('owned-$runId'),
        'loadedTraceContentDigest': EvalProvenance.digestText('loaded-$runId'),
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
    'coverage': const <String, dynamic>{
      'scenarioCount': 1,
      'profileCount': 1,
      'promptVariantCount': 1,
      'expectedTraceCount': 4,
      'traceCount': 4,
      'judgedTraceCount': 4,
      'missingRequiredPrimaryCapabilityIds': <String>[],
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
    'promotion': const <String, dynamic>{
      'present': false,
      'status': 'notRequested',
      'evidencePlan': null,
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

final class _CoverageFixture {
  const _CoverageFixture({
    required this.workOrder,
    required this.sourceExperimentPlan,
    required this.evidenceBundle,
    required this.run,
    required this.coverage,
  });

  final Map<String, dynamic> workOrder;
  final Map<String, dynamic> sourceExperimentPlan;
  final Map<String, dynamic> evidenceBundle;
  final EvalUseCaseModelClassExecutionRun run;
  final Map<String, dynamic> coverage;
}

final class _RunFixture {
  const _RunFixture({required this.run});

  final EvalUseCaseModelClassExecutionRun run;
}

Map<String, dynamic> _readEvidenceBundle(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is Map<String, dynamic> &&
      decoded['kind'] == EvalUseCaseModelClassExecutionEvidence.kind) {
    return decoded;
  }
  throw StateError(
    'Model-class coverage requires '
    '${EvalUseCaseModelClassExecutionEvidence.kind} input: $path.',
  );
}
