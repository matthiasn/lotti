import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../scenarios/eval_scenario_catalog.dart';
import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_profile_config.dart';

const _evidenceWorkOrderInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_WORK_ORDER',
);
const _evidenceExperimentPlanInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN',
);
const _evidenceRunIds = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS',
);
const _evidenceOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE',
);
const _evidenceOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE_OVERWRITE',
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
  test('extracts sanitized rows that cover every enum model class', () {
    final fixture = _runFixture();
    final sourceExperimentPlan = _experimentPlan();
    final workOrder = _workOrder(experimentPlan: sourceExperimentPlan);
    expect(_verificationErrors(fixture.run), isEmpty);
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: workOrder,
      runs: [fixture.run],
      sourceExperimentPlan: sourceExperimentPlan,
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(EvalUseCaseModelClassExecutionEvidence.validate(evidence), isEmpty);
    expect(
      EvalProvenance.isDigest(evidence['executionEvidenceRef'] as String),
      isTrue,
    );
    expect(
      evidence['executionEvidenceRef'],
      EvalUseCaseModelClassExecutionEvidence.executionEvidenceRef(evidence),
    );
    expect(
      evidence['status'],
      'ready',
      reason: const JsonEncoder.withIndent('  ').convert(evidence['issues']),
    );
    final rows = _evidenceRows(evidence);
    expect(rows, hasLength(EvalModelClass.values.length));
    expect(
      rows.map((row) => row['sourceRunRef']).toSet(),
      hasLength(1),
    );
    expect(
      rows.map(
        (row) => EvalProvenance.isDigest(row['evidenceRowRef'] as String),
      ),
      everyElement(isTrue),
    );
    expect(
      rows.map((row) => row['modelClass']),
      unorderedEquals(
        EvalModelClass.values.map((modelClass) => modelClass.name),
      ),
    );
    expect(
      rows.map((row) => row['expectedTraceCount']),
      everyElement(1),
    );
    expect(
      const JsonEncoder().convert(evidence),
      allOf([
        isNot(contains('private-scenario')),
        isNot(contains('frontier-reasoning-private')),
        isNot(contains('provider-model')),
        isNot(contains('provider-id')),
        isNot(contains('model-config')),
        isNot(contains('profile-id')),
        isNot(contains('/private/')),
        isNot(contains('EVAL_PROFILE_NAMES')),
      ]),
    );

    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: [evidence],
      sourceCheckProof:
          EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources(
            workOrder: workOrder,
            sourceExecutionEvidenceBundles: [evidence],
            runs: [fixture.run],
            sourceExperimentPlan: sourceExperimentPlan,
          ),
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );

    expect(coverage['status'], 'covered');
  });

  test('sanitized rows expose missing model classes to coverage', () {
    final fixture = _runFixture(
      modelClasses: const [
        EvalModelClass.localSmall,
        EvalModelClass.localReasoning,
        EvalModelClass.frontierFast,
      ],
    );
    final sourceExperimentPlan = _experimentPlan();
    final workOrder = _workOrder(experimentPlan: sourceExperimentPlan);
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: workOrder,
      runs: [fixture.run],
      sourceExperimentPlan: sourceExperimentPlan,
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(
      evidence['status'],
      'ready',
      reason: const JsonEncoder.withIndent('  ').convert(evidence['issues']),
    );
    final coverage = EvalUseCaseModelClassExecutionCoverage.build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: [evidence],
      sourceCheckProof:
          EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources(
            workOrder: workOrder,
            sourceExecutionEvidenceBundles: [evidence],
            runs: [fixture.run],
            sourceExperimentPlan: sourceExperimentPlan,
          ),
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );

    expect(coverage['status'], 'partialCoverage');
    final classes = (coverage['modelClassCoverage'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      classes.singleWhere(
        (entry) => entry['modelClass'] == EvalModelClass.frontierReasoning.name,
      )['status'],
      'missing',
    );
  });

  test('duplicate source runs are blocked without inflating counts', () {
    final fixture = _runFixture();
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: _workOrder(),
      runs: [fixture.run, fixture.run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(evidence['status'], 'invalidSource');
    expect(
      _issueCodes(evidence),
      contains('execution.duplicateSourceRun'),
    );
    expect(
      (evidence['summary'] as Map<String, dynamic>)['observedTraceCount'],
      EvalModelClass.values.length,
    );
  });

  test('stale manifest digest blocks source evidence', () {
    final fixture = _runFixture(staleManifestDigest: true);
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: _workOrder(),
      runs: [fixture.run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(evidence['status'], 'invalidSource');
    expect(_issueCodes(evidence), contains('execution.manifestDigestStale'));
    expect(_issueCodes(evidence), contains('execution.verifierFailed'));
  });

  test('missing work-order launch evidence blocks source evidence', () {
    final fixture = _runFixture(omitWorkOrderLaunchEvidence: true);
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: _workOrder(),
      runs: [fixture.run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(evidence['status'], 'invalidSource');
    expect(
      _issueCodes(evidence),
      contains('execution.workOrderLaunchEvidenceMissing'),
    );
    expect(_evidenceRows(evidence), isEmpty);
  });

  test('same-plan stale work-order launches emit no rows', () {
    final launchedWorkOrder = _workOrder(
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final currentWorkOrder = _workOrder(
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    expect(
      launchedWorkOrder['workOrderRef'],
      currentWorkOrder['workOrderRef'],
    );
    expect(
      EvalProvenance.digestJson(launchedWorkOrder),
      isNot(EvalProvenance.digestJson(currentWorkOrder)),
    );
    expect(
      _runBatchRefs(launchedWorkOrder),
      _runBatchRefs(currentWorkOrder),
    );
    final fixture = _runFixture(workOrder: launchedWorkOrder);

    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: currentWorkOrder,
      runs: [fixture.run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(evidence['status'], 'invalidSource');
    expect(
      _issueCodes(evidence),
      contains('execution.workOrderLaunchDigestMismatch'),
    );
    expect(
      _issueCodes(evidence),
      isNot(contains('execution.workOrderBatchLaunchEvidenceMissing')),
    );
    expect(_evidenceRows(evidence), isEmpty);
    expect(
      (evidence['summary'] as Map<String, dynamic>)['observedTraceCount'],
      0,
    );
  });

  test('selector-compatible stale work-order launches do not count', () {
    final launchedWorkOrder = _workOrder(runId: 'ready-run-a');
    final currentWorkOrder = _workOrder(runId: 'ready-run-b');
    final fixture = _runFixture(workOrder: launchedWorkOrder);

    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: currentWorkOrder,
      runs: [fixture.run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(evidence['status'], 'invalidSource');
    expect(
      _issueCodes(evidence),
      contains('execution.workOrderLaunchDigestMismatch'),
    );
    expect(
      _issueCodes(evidence),
      contains('execution.workOrderLaunchRefMismatch'),
    );
    expect(
      _issueCodes(evidence),
      isNot(contains('execution.workOrderBatchLaunchEvidenceMissing')),
    );
    expect(_evidenceRows(evidence), isEmpty);
  });

  test('source plan and matrix launch restamps emit no rows', () {
    final fixture = _runFixture(
      rewriteWorkOrderLaunchEvidence: (evidence) {
        final restamped = EvalUseCaseWorkOrderLaunchEvidence(
          workOrderRef: evidence.workOrderRef,
          workOrderDigest: evidence.workOrderDigest,
          sourceExperimentPlanDigest: EvalProvenance.digestText(
            'restamped-plan',
          ),
          sourceMatrixDigest: EvalProvenance.digestText('restamped-matrix'),
          workOrderBatchRefs: evidence.workOrderBatchRefs,
          workOrderBatchSetDigest: evidence.workOrderBatchSetDigest,
          requiredPrimaryCapabilityIds: evidence.requiredPrimaryCapabilityIds,
          promptVariantNames: evidence.promptVariantNames,
          workOrderLaunchSubjectDigest: '',
        );
        return EvalUseCaseWorkOrderLaunchEvidence(
          workOrderRef: restamped.workOrderRef,
          workOrderDigest: restamped.workOrderDigest,
          sourceExperimentPlanDigest: restamped.sourceExperimentPlanDigest,
          sourceMatrixDigest: restamped.sourceMatrixDigest,
          workOrderBatchRefs: restamped.workOrderBatchRefs,
          workOrderBatchSetDigest: restamped.workOrderBatchSetDigest,
          requiredPrimaryCapabilityIds: restamped.requiredPrimaryCapabilityIds,
          promptVariantNames: restamped.promptVariantNames,
          workOrderLaunchSubjectDigest:
              EvalProvenance.useCaseWorkOrderLaunchSubjectDigest(restamped),
        );
      },
    );

    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: _workOrder(),
      runs: [fixture.run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(evidence['status'], 'invalidSource');
    expect(
      _issueCodes(evidence),
      contains('execution.workOrderLaunchSourcePlanDigestMismatch'),
    );
    expect(
      _issueCodes(evidence),
      contains('execution.workOrderLaunchSourceMatrixDigestMismatch'),
    );
    expect(_evidenceRows(evidence), isEmpty);
  });

  test(
    'missing runtime evidence survives only as partial sanitized counts',
    () {
      final fixture = _runFixture(omitResolvedModelForFirstTrace: true);
      final evidence = EvalUseCaseModelClassExecutionEvidence.build(
        workOrder: _workOrder(),
        runs: [fixture.run],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      );

      expect(evidence['status'], 'invalidSource');
      expect(
        _issueCodes(evidence),
        contains('execution.resolvedModelEvidenceMissing'),
      );
      final affectedRow = _evidenceRows(evidence).singleWhere(
        (row) => row['modelClass'] == EvalModelClass.localSmall.name,
      );
      expect(affectedRow['observedTraceCount'], 1);
      expect(affectedRow['verifiedResolvedModelTraceCount'], 0);
      expect(affectedRow['resolvedModelEvidence'], isFalse);
    },
  );

  test('contract rejects recursive private payloads', () {
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: _workOrder(),
      runs: [_runFixture().run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(evidence)) as Map<String, dynamic>
      ..['scenarioIds'] = const ['private-scenario']
      ..['profileNames'] = const ['frontier-reasoning-private']
      ..['runId'] = 'private-run-id'
      ..['providerModelId'] = 'provider-model-secret'
      ..['modelId'] = 'model-config-secret'
      ..['providerId'] = 'provider-secret'
      ..['path'] = '/private/tmp/evidence.json'
      ..['promptText'] = 'raw private prompt'
      ..['notes'] = 'Use EVAL_PROFILE_NAMES from /private/tmp/profiles.json';

    final issues = EvalUseCaseModelClassExecutionEvidence.validate(tampered);

    expect(
      issues,
      contains('evidence.scenarioIds must not expose scenario ids'),
    );
    expect(
      issues,
      contains('evidence.profileNames must not expose profile selectors'),
    );
    expect(issues, contains('evidence.runId must not expose run ids'));
    expect(
      issues,
      contains(
        'evidence.providerModelId must not expose provider or model ids',
      ),
    );
    expect(issues, contains('evidence.path must not expose private paths'));
    expect(issues, contains('evidence.path must not contain private paths'));
    expect(issues, contains('evidence.promptText must not expose prompt text'));
    expect(
      issues,
      contains('evidence.notes must not contain private env value keys'),
    );
  });

  test('contract rejects stale evidence row refs', () {
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: _workOrder(),
      runs: [_runFixture().run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(evidence)) as Map<String, dynamic>;
    final row =
        (tampered['evidenceRows'] as List<dynamic>).first
              as Map<String, dynamic>
          ..['observedTraceCount'] = 99;

    final issues = EvalUseCaseModelClassExecutionEvidence.validate(tampered);

    expect(row['observedTraceCount'], 99);
    expect(
      issues,
      contains('evidenceRows[0].evidenceRowRef must bind evidence row fields'),
    );
  });

  test('contract rejects ready bundles without source runs', () {
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: _workOrder(),
      runs: [_runFixture().run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(evidence)) as Map<String, dynamic>;
    tampered['sourceRuns'] = const <Map<String, dynamic>>[];
    (tampered['summary'] as Map<String, dynamic>)['sourceRunCount'] = 0;
    tampered['executionEvidenceRef'] =
        EvalUseCaseModelClassExecutionEvidence.executionEvidenceRef(tampered);

    final issues = EvalUseCaseModelClassExecutionEvidence.validate(tampered);

    expect(issues, contains('ready status requires sourceRuns'));
    expect(issues, contains('evidenceRows require sourceRuns'));
  });

  test('source-aware validation rejects restamped source runs', () {
    final fixture = _runFixture();
    final workOrder = _workOrder();
    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: workOrder,
      runs: [fixture.run],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final restamped = jsonDecode(jsonEncode(evidence)) as Map<String, dynamic>;
    final sourceRun =
        (restamped['sourceRuns'] as List<dynamic>).single
            as Map<String, dynamic>;
    sourceRun['manifestDigest'] = EvalProvenance.digestText(
      'fabricated-manifest',
    );
    sourceRun['sourceRunRef'] = _sourceRunRef(sourceRun);
    for (final row
        in (restamped['evidenceRows'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      row['sourceRunRef'] = sourceRun['sourceRunRef'];
      row['evidenceRowRef'] =
          EvalUseCaseModelClassExecutionEvidence.evidenceRowRef(row);
    }
    restamped['executionEvidenceRef'] =
        EvalUseCaseModelClassExecutionEvidence.executionEvidenceRef(restamped);

    expect(EvalUseCaseModelClassExecutionEvidence.validate(restamped), isEmpty);
    expect(
      EvalUseCaseModelClassExecutionEvidence.validateAgainstSources(
        restamped,
        workOrder: workOrder,
        runs: [fixture.run],
      ),
      contains('sourceRuns must match source work order and runs'),
    );
  });

  test('source experiment-plan mismatch blocks evidence extraction', () {
    final sourcePlan = _experimentPlan();
    final unrelatedPlan = _experimentPlan(
      runId: 'unrelated-run',
      primaryCapabilityId: 'planner.workflow',
    );
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: sourcePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    final evidence = EvalUseCaseModelClassExecutionEvidence.build(
      workOrder: workOrder,
      runs: [_runFixture().run],
      sourceExperimentPlan: unrelatedPlan,
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(evidence['status'], 'invalidSource');
    expect(
      (evidence['sourceWorkOrder']
              as Map<String, dynamic>)['contractIssueCount']
          as int,
      greaterThan(0),
    );
    expect(
      (evidence['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['code'],
      ),
      contains('execution.workOrderContractInvalid'),
    );
  });

  test(
    'writes use-case model-class execution evidence',
    () async {
      final workOrder =
          jsonDecode(File(_evidenceWorkOrderInputPath).readAsStringSync())
              as Map<String, dynamic>;
      final experimentPlan =
          jsonDecode(File(_evidenceExperimentPlanInputPath).readAsStringSync())
              as Map<String, dynamic>;
      EvalUseCaseNextRunWorkOrder.assertMatchesExperimentPlan(
        workOrder,
        experimentPlan: experimentPlan,
      );
      const writer = TraceWriter(runsRoot: _runsRoot);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final runs = <EvalUseCaseModelClassExecutionRun>[];
      for (final runId in _csv(_evidenceRunIds)) {
        runs.add(
          EvalUseCaseModelClassExecutionRun(
            artifacts: await writer.readRun(runId),
            scenarios: catalog.scenarios,
            profiles: profiles,
            agentDirectiveVariants: promptVariants,
          ),
        );
      }
      final evidence = EvalUseCaseModelClassExecutionEvidence.build(
        workOrder: workOrder,
        runs: runs,
        sourceExperimentPlan: experimentPlan,
      );
      EvalUseCaseModelClassExecutionEvidence.assertMatchesSources(
        evidence,
        workOrder: workOrder,
        runs: runs,
        sourceExperimentPlan: experimentPlan,
      );
      writeEvalJsonArtifact(
        evidence,
        path: _evidenceOutputPath,
        overwrite: _evidenceOverwrite == '1',
        description: 'use-case model-class execution evidence',
      );
    },
    skip:
        _evidenceWorkOrderInputPath.isEmpty ||
            _evidenceExperimentPlanInputPath.isEmpty ||
            _evidenceRunIds.isEmpty ||
            _evidenceOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_MODEL_CLASS_EXECUTION_WORK_ORDER=<json>, '
              'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN=<json>, '
              'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS=<id,...>, and '
              'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE=<json> to write '
              'sanitized execution evidence.'
        : false,
  );
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

_RunFixture _runFixture({
  List<EvalModelClass> modelClasses = EvalModelClass.values,
  bool staleManifestDigest = false,
  bool omitResolvedModelForFirstTrace = false,
  bool omitWorkOrderLaunchEvidence = false,
  Map<String, dynamic>? workOrder,
  List<String> launchedBatchRefs = const <String>[],
  EvalUseCaseWorkOrderLaunchEvidence Function(
    EvalUseCaseWorkOrderLaunchEvidence evidence,
  )?
  rewriteWorkOrderLaunchEvidence,
}) {
  final sourceWorkOrder = workOrder ?? _workOrder();
  final scenario = _scenario();
  final profiles = [
    for (final modelClass in modelClasses) _profile(modelClass, trialCount: 1),
  ];
  final readinessContractEvidence =
      EvalProvenance.tuningReadinessContractEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest([scenario]),
        requiredPrimaryCapabilityIds: {'task.workflow'},
      );
  final rawWorkOrderLaunchEvidence = omitWorkOrderLaunchEvidence
      ? null
      : EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
          workOrder: sourceWorkOrder,
          requiredPrimaryCapabilityIds: {'task.workflow'},
          promptVariantNames: const ['default'],
          workOrderBatchRefs: launchedBatchRefs,
        );
  final workOrderLaunchEvidence = rawWorkOrderLaunchEvidence == null
      ? null
      : rewriteWorkOrderLaunchEvidence?.call(rawWorkOrderLaunchEvidence) ??
            rawWorkOrderLaunchEvidence;
  final manifest = EvalProvenance.captureRunManifest(
    runId: 'private-run-${modelClasses.map((value) => value.name).join('-')}',
    targetName: 'fixture target',
    targetKind: 'fixture',
    scenarios: [scenario],
    profiles: profiles,
    createdAt: DateTime.utc(2026, 6, 13, 7),
    command: 'eval/run_level2.sh run private-run',
    environment: const {},
    tuningReadinessContractEvidence: readinessContractEvidence,
    useCaseWorkOrderLaunchEvidence: workOrderLaunchEvidence,
  );
  final effectiveManifest = staleManifestDigest
      ? manifest.withManifestDigest(EvalProvenance.digestText('stale-manifest'))
      : manifest;
  var traceIndex = 0;
  final traces = [
    for (final profile in profiles)
      _trace(
        manifest: effectiveManifest,
        scenario: scenario,
        profile: profile,
        omitResolvedModel: omitResolvedModelForFirstTrace && traceIndex++ == 0,
      ),
  ];
  return _RunFixture(
    run: EvalUseCaseModelClassExecutionRun(
      artifacts: EvalRunArtifacts(
        manifest: effectiveManifest,
        traces: traces,
        artifactNames: const ['manifest.json'],
      ),
      scenarios: [scenario],
      profiles: profiles,
    ),
    manifest: effectiveManifest,
    traces: traces,
    scenarios: [scenario],
    profiles: profiles,
  );
}

EvalScenario _scenario() {
  return EvalScenario(
    id: 'private-scenario',
    title: 'Private scenario',
    agentKind: AgentKind.taskAgent,
    appState: MockedAppState(now: DateTime(2026, 6, 13, 7)),
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
  bool omitResolvedModel = false,
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
    resolvedModel: omitResolvedModel
        ? null
        : ResolvedModelRecord(
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

Map<String, dynamic> _workOrder({
  String runId = 'ready-run',
  DateTime? generatedAt,
  Map<String, dynamic>? experimentPlan,
}) {
  return EvalUseCaseNextRunWorkOrder.build(
    experimentPlan: experimentPlan ?? _experimentPlan(runId: runId),
    generatedAt: generatedAt ?? DateTime.utc(2026, 6, 12, 12),
  );
}

Set<String> _runBatchRefs(Map<String, dynamic> workOrder) =>
    (workOrder['runBatches'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((batch) => batch['workOrderBatchRef'] as String)
        .toSet();

Map<String, dynamic> _experimentPlan({
  String runId = 'ready-run',
  String primaryCapabilityId = 'task.workflow',
}) {
  final matrix = EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: [
      _report(
        runId: runId,
        ready: true,
        primaryCapabilityId: primaryCapabilityId,
      ),
    ],
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
  return EvalUseCaseExperimentPlan.build(
    matrix: matrix,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
  );
}

Map<String, dynamic> _report({
  required String runId,
  bool ready = false,
  String scenarioId = 'private-scenario',
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
        'artifactCount': 3,
        'traceCount': 1,
        'judgedTraceCount': 1,
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
      'expectedTraceCount': 1,
      'traceCount': 1,
      'judgedTraceCount': 1,
      'missingRequiredPrimaryCapabilityIds': <String>[],
    },
    'readiness': <String, dynamic>{
      'ready': ready,
      'evidenceLabel': ready ? 'ready' : 'blocked',
      'policyName': 'modelClassTuning',
      'policyDigest': policyDigest,
      'expectedTraceCount': 1,
      'traceCount': 1,
      'judgedTraceCount': 1,
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
        'traceCount': 1,
        'judgedTraceCount': 1,
        'passCount': 1,
        'level1PassCount': 1,
        'passRate': 1,
        'passRateLowerBound': 0.8,
        'meanGoalAttainment': 4,
        'meanQuality': 4,
        'meanEfficiency': 4,
        'meanTokenBudgetRatio': 0.2,
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

List<Map<String, dynamic>> _evidenceRows(Map<String, dynamic> evidence) =>
    (evidence['evidenceRows'] as List<dynamic>).cast<Map<String, dynamic>>();

String _sourceRunRef(
  Map<String, dynamic> sourceRun,
) => EvalProvenance.digestJson(<String, dynamic>{
  'actualManifestDigest': sourceRun['actualManifestDigest'],
  'manifestDigest': sourceRun['manifestDigest'],
  'workOrderLaunchSubjectDigest': sourceRun['workOrderLaunchSubjectDigest'],
  'workOrderDigest': sourceRun['workOrderDigest'],
  'workOrderRef': sourceRun['workOrderRef'],
  'workOrderBatchSetDigest': sourceRun['workOrderBatchSetDigest'],
  'profileBindingSetDigest': sourceRun['profileBindingSetDigest'],
  'scenarioSetDigest': sourceRun['scenarioSetDigest'],
  'profileSetDigest': sourceRun['profileSetDigest'],
  'agentDirectiveVariantSetDigest': sourceRun['agentDirectiveVariantSetDigest'],
  'readinessContractSubjectDigest': sourceRun['readinessContractSubjectDigest'],
});

Iterable<Object?> _issueCodes(Map<String, dynamic> evidence) =>
    (evidence['issues'] as List<dynamic>).map(
      (issue) => (issue as Map<String, dynamic>)['code'],
    );

List<String> _verificationErrors(EvalUseCaseModelClassExecutionRun run) {
  return EvalRunVerifier.verify(
    runId: run.artifacts.manifest.runId,
    traces: run.artifacts.traces,
    scenarios: run.scenarios,
    profiles: run.profiles,
    agentDirectiveVariants: run.agentDirectiveVariants,
    manifest: run.artifacts.manifest,
    artifactNames: run.artifacts.artifactNames,
    requireVerdicts: run.requireVerdicts,
  ).errors;
}

List<String> _csv(String value) => [
  for (final part in value.split(',').map((part) => part.trim()))
    if (part.isNotEmpty) part,
];

final class _RunFixture {
  const _RunFixture({
    required this.run,
    required this.manifest,
    required this.traces,
    required this.scenarios,
    required this.profiles,
  });

  final EvalUseCaseModelClassExecutionRun run;
  final EvalRunManifest manifest;
  final List<EvalTrace> traces;
  final List<EvalScenario> scenarios;
  final List<EvalProfile> profiles;
}
