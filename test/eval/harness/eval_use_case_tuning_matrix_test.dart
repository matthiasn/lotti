import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_tuning_source_replay_test_utils.dart';

const _runsRoot = String.fromEnvironment(
  'EVAL_RUNS_ROOT',
  defaultValue: 'eval/runs',
);
const _scenarioCatalogPath = String.fromEnvironment('EVAL_SCENARIOS');
const _scenarioCatalogMode = String.fromEnvironment('EVAL_SCENARIOS_MODE');
const _scenarioIds = String.fromEnvironment('EVAL_SCENARIO_IDS');
const _profileCatalogPath = String.fromEnvironment('EVAL_PROFILES');
const _profileNames = String.fromEnvironment('EVAL_PROFILE_NAMES');
const _promptVariantCatalogPath = String.fromEnvironment(
  'EVAL_PROMPT_VARIANTS',
);
const _promptVariantNames = String.fromEnvironment(
  'EVAL_PROMPT_VARIANT_NAMES',
);
const _calibrationPath = String.fromEnvironment('EVAL_CALIBRATION');
const _promotionPlanPath = String.fromEnvironment('EVAL_PROMOTION_PLAN');
const _matrixInputPaths = String.fromEnvironment('EVAL_TUNING_REPORTS');
const _matrixOutputPath = String.fromEnvironment('EVAL_USE_CASE_MATRIX_REPORT');
const _matrixOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_MATRIX_OVERWRITE',
);

void main() {
  test('builds a promotion-ready matrix from promoted clean slices', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'frontier-run',
          modelClass: 'frontier',
          ready: true,
          promotionStatus: 'promote',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(matrix['status'], 'promotionReady');
    expect(EvalUseCaseTuningMatrix.validate(matrix), isEmpty);
    final cell = _singleMap(matrix, 'matrixCells');
    expect(cell['evidenceStatus'], 'promotionReady');
    expect(cell['promotionEvidence'], isTrue);
    final commands = _commands(matrix);
    expect(
      commands.map((command) => command['mode']),
      ['use-case-matrix', 'experiment-plan'],
    );
    expect(commands.any((command) => command.containsKey('env')), isFalse);
  });

  test('source-check-required matrix rejects missing source evidence', () {
    final report = _report(
      runId: 'restamped-run',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );

    final matrix = EvalUseCaseTuningMatrix.build(
      reports: [report],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(EvalUseCaseTuningMatrix.validate(matrix), isEmpty);
    expect(matrix['status'], 'invalid');
    final summary = matrix['summary'] as Map<String, dynamic>;
    expect(summary['validReportCount'], 0);
    expect(matrix['matrixCells'], isEmpty);
    final input = _singleMap(matrix, 'inputReports');
    expect(input['contractStatus'], 'invalid');
    expect(input['sourceCheckStatus'], 'sourceMissing');
    expect(input['sourceIssueCodes'], ['report.sourceCheckMissing']);
  });

  test('source-check-required matrix rejects invalid source evidence', () {
    final report = _report(
      runId: 'restamped-run',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );

    final matrix = EvalUseCaseTuningMatrix.build(
      reports: [report],
      sourceChecksByReportDigest: {
        EvalProvenance.digestJson(report): _invalidSourceCheck(
          report,
          'report.sourceStatusMismatch',
        ),
      },
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(EvalUseCaseTuningMatrix.validate(matrix), isEmpty);
    expect(matrix['status'], 'invalid');
    expect(matrix['matrixCells'], isEmpty);
    final input = _singleMap(matrix, 'inputReports');
    expect(input['sourceCheckStatus'], 'sourceInvalid');
    expect(input['sourceIssueCodes'], ['report.sourceStatusMismatch']);
  });

  test('source-check-required matrix rejects fabricated source checks', () {
    final report = _report(
      runId: 'fabricated-source-check',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );

    final matrix = EvalUseCaseTuningMatrix.build(
      reports: [report],
      sourceChecksByReportDigest: {
        EvalProvenance.digestJson(report): _fabricatedSourceCheck(report),
      },
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(EvalUseCaseTuningMatrix.validate(matrix), isEmpty);
    expect(matrix['status'], 'invalid');
    expect(matrix['matrixCells'], isEmpty);
    final input = _singleMap(matrix, 'inputReports');
    expect(input['sourceCheckStatus'], 'sourceChecked');
    expect(input['sourceIssueCodes'], ['report.sourceCheckUnvalidated']);
  });

  test('source replay marks matrix and rejects restamped artifacts', () {
    final report = _report(
      runId: 'restamped-matrix',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [report],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(EvalUseCaseTuningMatrix.hasVerifiedSourceReplay(matrix), isFalse);
    EvalUseCaseTuningMatrix.assertMatchesSources(
      matrix,
      reports: [report],
      requireSourceChecks: false,
    );
    expect(EvalUseCaseTuningMatrix.hasVerifiedSourceReplay(matrix), isTrue);

    final serialized = jsonDecode(jsonEncode(matrix)) as Map<String, dynamic>;
    final inputReport =
        (serialized['inputReports'] as List<dynamic>).single
            as Map<String, dynamic>;
    inputReport
      ..['sourceCheckStatus'] = 'sourceChecked'
      ..['sourceIssueCount'] = 0
      ..['sourceIssueCodes'] = const <String>[];

    expect(EvalUseCaseTuningMatrix.validate(serialized), isEmpty);
    expect(
      EvalUseCaseTuningMatrix.hasVerifiedSourceReplay(serialized),
      isFalse,
    );
    expect(
      () => EvalUseCaseTuningMatrix.assertMatchesSources(
        serialized,
        reports: [report],
        requireSourceChecks: false,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('inputReports must match matrix source artifacts'),
        ),
      ),
    );
  });

  test('keeps clean ready slices diagnostic without promotion evidence', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(matrix['status'], 'diagnosticOnly');
    final cell = _singleMap(matrix, 'matrixCells');
    expect(cell['evidenceStatus'], 'diagnosticOnly');
    expect(cell['promotionEvidence'], isFalse);
  });

  test('does not promote strong slices from unready reports', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'unready-run',
          modelClass: 'frontier',
          passRate: 1,
          passRateLowerBound: 0.95,
          meanGoalAttainment: 5,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(matrix['status'], 'dataDeficient');
    final cell = _singleMap(matrix, 'matrixCells');
    expect(cell['evidenceStatus'], 'dataDeficient');
    expect(cell['promotionEvidence'], isFalse);
    expect(cell['blockingReasonCodes'], contains('verdict.missing'));
  });

  test('keeps protected blocker values as opaque blockers', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'protected-blocker-run',
          modelClass: 'frontier',
          ready: true,
          promotionStatus: 'promote',
          scenarioId: 'protected-case-blocker',
          forcedSliceBlockingReasons: const ['protected-case-blocker'],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(matrix['status'], 'blocked');
    final cell = _singleMap(matrix, 'matrixCells');
    expect(cell['evidenceStatus'], 'blocked');
    expect(cell['promotionEvidence'], isFalse);
    expect(cell['blockingReasonCodes'], everyElement(startsWith('blocker-')));
    expect(
      const JsonEncoder().convert(matrix),
      isNot(contains('protected-case-blocker')),
    );
  });

  test(
    'keeps incompatible reports in separate groups without global live commands',
    () {
      final matrix = EvalUseCaseTuningMatrix.build(
        requireSourceChecks: false,
        reports: [
          _report(
            runId: 'frontier-run',
            modelClass: 'frontier',
            ready: true,
            promotionStatus: 'promote',
            scenarioSetSeed: 'scenario-set-a',
          ),
          _report(
            runId: 'local-run',
            modelClass: 'local-small',
            ready: true,
            promotionStatus: 'promote',
            scenarioSetSeed: 'scenario-set-b',
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );

      expect(matrix['status'], 'incompatible');
      expect(matrix['compatibilityGroups'], hasLength(2));
      expect(
        _commands(matrix).map((command) => command['mode']),
        isNot(contains(anyOf('plan', 'run', 'tune'))),
      );
      final plan = matrix['nextExperimentPlan'] as Map<String, dynamic>;
      final groupPlans = (plan['groupPlans'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final groupPlan in groupPlans) {
        final commands = (groupPlan['recommendedCommands'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(
          commands.map((command) => command['mode']),
          ['use-case-matrix', 'experiment-plan'],
        );
        expect(commands.any((command) => command.containsKey('env')), isFalse);
      }
    },
  );

  test(
    'does not merge protected required capabilities after visible redaction',
    () {
      final matrix = EvalUseCaseTuningMatrix.build(
        requireSourceChecks: false,
        reports: [
          _report(
            runId: 'secret-a',
            modelClass: 'frontier',
            ready: true,
            scenarioId: 'protected-case-a',
            primaryCapabilityId: 'protected-case-a',
            requiredCapabilities: const ['protected-case-a'],
          ),
          _report(
            runId: 'secret-b',
            modelClass: 'frontier',
            ready: true,
            scenarioId: 'protected-case-b',
            primaryCapabilityId: 'protected-case-b',
            requiredCapabilities: const ['protected-case-b'],
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );

      expect(matrix['status'], 'incompatible');
      expect(matrix['compatibilityGroups'], hasLength(2));
      expect(
        const JsonEncoder().convert(matrix),
        allOf(
          isNot(contains('protected-case-a')),
          isNot(contains('protected-case-b')),
        ),
      );
      final cells = (matrix['matrixCells'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        cells.map((cell) => cell['primaryCapabilityId']),
        everyElement(startsWith('capability-')),
      );
      final plan = matrix['nextExperimentPlan'] as Map<String, dynamic>;
      final groupPlans = (plan['groupPlans'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final groupPlan in groupPlans) {
        final selectors = groupPlan['safeSelectors'] as Map<String, dynamic>;
        expect(selectors['capabilities'], isEmpty);
        final env = groupPlan['nextRunEnv'] as Map<String, dynamic>;
        expect(env, isNot(contains('EVAL_REQUIRED_CAPABILITIES')));
      }
    },
  );

  test('redacts raw run ids reused as public dimensions', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'private-run-id',
          modelClass: 'private-run-id',
          ready: true,
          primaryCapabilityId: 'cap-private-run-id',
          promptVariantName: 'prompt-private-run-id',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final json = const JsonEncoder().convert(matrix);
    expect(json, isNot(contains('private-run-id')));
    final cell = _singleMap(matrix, 'matrixCells');
    expect(cell['primaryCapabilityId'], startsWith('capability-'));
    expect(cell['modelClass'], startsWith('model-'));
    expect(cell['promptVariantName'], startsWith('prompt-'));
  });

  test(
    'surfaces missing required capabilities without leaking protected ids',
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

      expect(matrix['status'], 'blocked');
      final summary = matrix['summary'] as Map<String, dynamic>;
      expect(summary['evidenceGapCount'], 1);
      final gaps = (matrix['gaps'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(gaps, hasLength(1));
      expect(gaps.single['gapKind'], 'requiredPrimaryCapability');
      expect(
        gaps.single['blockerCodes'],
        contains('coverage.capabilityMissing'),
      );
      expect(gaps.single['missingRequiredPrimaryCapabilityCount'], 1);
      expect(gaps.single['publicMissingRequiredPrimaryCapabilities'], isEmpty);
      expect(
        gaps.single['omittedMissingRequiredPrimaryCapabilityValueCount'],
        1,
      );
      final plan = matrix['nextExperimentPlan'] as Map<String, dynamic>;
      expect(
        plan['blockedReasonCodes'],
        contains('coverage.capabilityMissing'),
      );
      expect(
        _commands(matrix).map((command) => command['mode']),
        isNot(contains(anyOf('plan', 'run', 'tune'))),
      );
      expect(
        const JsonEncoder().convert(matrix),
        isNot(contains('protected-missing-capability')),
      );
    },
  );

  test('keeps same visible dimensions separate for different bindings', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(
          runId: 'frontier-a',
          modelClass: 'frontier',
          ready: true,
          profileBindingSeed: 'binding-a',
        ),
        _report(
          runId: 'frontier-b',
          modelClass: 'frontier',
          ready: true,
          profileBindingSeed: 'binding-b',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(matrix['status'], 'diagnosticOnly');
    final cells = (matrix['matrixCells'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(cells, hasLength(2));
    expect(cells.map((cell) => cell['cellKey']).toSet(), hasLength(2));
    expect(
      cells.map((cell) => cell['profileBindingSetDigest']).toSet(),
      hasLength(2),
    );
  });

  test('records invalid inputs without aggregating their slices', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        const <String, dynamic>{'schemaVersion': 99},
        _report(runId: 'valid-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(matrix['status'], 'invalid');
    expect(EvalUseCaseTuningMatrix.validate(matrix), isEmpty);
    final inputReports = (matrix['inputReports'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(inputReports.first['reportRef'], 'report-0');
    expect(inputReports.first['contractStatus'], 'invalid');
    expect(matrix['matrixCells'], hasLength(1));
    expect(
      _commands(matrix).map((command) => command['mode']),
      isNot(contains(anyOf('plan', 'run', 'tune'))),
    );
    expect(
      const JsonEncoder().convert(matrix),
      allOf(
        isNot(contains('run.selectors.scenarioIds')),
        isNot(contains('suggestedScenarioIds')),
      ),
    );
  });

  test('contract rejects scenario id fields and placeholders recursively', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final tampered = jsonDecode(jsonEncode(matrix)) as Map<String, dynamic>
      ..['scenarioIds'] = const ['protected-case']
      ..['notes'] = '<redacted-scenario-001>';

    final issues = EvalUseCaseTuningMatrix.validate(tampered);

    expect(issues, contains('matrix.scenarioIds must not expose scenario ids'));
    expect(
      issues,
      contains('matrix.notes must not contain redacted scenario placeholders'),
    );
  });

  test('contract rejects live commands and command env maps', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [
        _report(runId: 'ready-run', modelClass: 'frontier', ready: true),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final tampered = jsonDecode(jsonEncode(matrix)) as Map<String, dynamic>;
    final plan = tampered['nextExperimentPlan'] as Map<String, dynamic>;
    ((plan['recommendedCommands'] as List<dynamic>).first
          as Map<String, dynamic>)
      ..['mode'] = 'tune'
      ..['command'] = 'eval/run_level2.sh tune <nextRunId>'
      ..['env'] = const {'EVAL_REQUIRED_CAPABILITIES': 'task.workflow'};
    final groupPlan =
        (plan['groupPlans'] as List<dynamic>).single as Map<String, dynamic>;
    final groupCommand =
        (groupPlan['recommendedCommands'] as List<dynamic>).first
            as Map<String, dynamic>;
    groupCommand['env'] = const {'EVAL_PROMPT_VARIANT_NAMES': 'default'};

    final issues = EvalUseCaseTuningMatrix.validate(tampered);

    expect(
      issues,
      contains('nextExperimentPlan.recommendedCommands[0].mode is unsupported'),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.recommendedCommands[0].command must not recommend live run commands',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.recommendedCommands[0] must not contain env values',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.groupPlans[0].recommendedCommands[0] must not contain env values',
      ),
    );
  });

  test(
    'writes use-case tuning matrix report',
    () async {
      final reports = [
        for (final path
            in _matrixInputPaths
                .split(',')
                .map((path) => path.trim())
                .where((path) => path.isNotEmpty))
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
      ];
      final sourceChecks = await evalSourceChecksForReports(
        reports,
        config: _sourceReplayConfig(),
      );
      final matrix = EvalUseCaseTuningMatrix.build(
        reports: reports,
        sourceChecksByReportDigest: sourceChecks,
      );
      EvalUseCaseTuningMatrix.assertValid(matrix);
      expect(
        matrix['status'],
        isNot('invalid'),
        reason: const JsonEncoder.withIndent('  ').convert(matrix),
      );
      writeEvalJsonArtifact(
        matrix,
        path: _matrixOutputPath,
        overwrite: _matrixOverwrite == '1',
        description: 'use-case tuning matrix report',
      );
    },
    skip: _matrixInputPaths.isEmpty || _matrixOutputPath.isEmpty
        ? 'Set EVAL_TUNING_REPORTS=<a.json,b.json> and '
              'EVAL_USE_CASE_MATRIX_REPORT=<json> to write a matrix.'
        : false,
  );
}

EvalTuningSourceReplayConfig _sourceReplayConfig() =>
    const EvalTuningSourceReplayConfig(
      runsRoot: _runsRoot,
      scenarioCatalogPath: _scenarioCatalogPath,
      scenarioCatalogMode: _scenarioCatalogMode,
      scenarioIds: _scenarioIds,
      profileCatalogPath: _profileCatalogPath,
      profileNames: _profileNames,
      promptVariantCatalogPath: _promptVariantCatalogPath,
      promptVariantNames: _promptVariantNames,
      calibrationPath: _calibrationPath,
      promotionPlanPath: _promotionPlanPath,
    );

List<Map<String, dynamic>> _commands(Map<String, dynamic> matrix) {
  final plan = matrix['nextExperimentPlan'] as Map<String, dynamic>;
  return (plan['recommendedCommands'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
}

Map<String, dynamic> _singleMap(Map<String, dynamic> root, String key) {
  final list = root[key] as List<dynamic>;
  expect(list, hasLength(1));
  return list.single as Map<String, dynamic>;
}

Map<String, dynamic> _report({
  required String runId,
  required String modelClass,
  String? profileName,
  bool ready = false,
  String promotionStatus = 'notRequested',
  bool protectedIdsRedacted = false,
  String scenarioId = 'task_workflow_structured_update',
  String scenarioSetSeed = 'scenario-set',
  String primaryCapabilityId = 'task.workflow',
  String promptVariantName = 'default',
  String? profileBindingSeed,
  List<String> requiredCapabilities = const ['task.workflow'],
  List<String> missingRequiredPrimaryCapabilities = const <String>[],
  List<String> blockingReasonCodes = const ['verdict.missing'],
  List<String>? forcedSliceBlockingReasons,
  double passRateLowerBound = 0.55,
  double passRate = 0.75,
  double meanGoalAttainment = 4,
}) {
  final effectiveBlockers = ready ? const <String>[] : blockingReasonCodes;
  final sliceBlockers = forcedSliceBlockingReasons ?? effectiveBlockers;
  final effectiveProfileName = profileName ?? 'profile-$modelClass';
  const policyPayload = <String, dynamic>{
    'name': 'modelClassTuning',
    'minJudgePassRateLowerBound': 0.7,
  };
  final policyDigest = EvalProvenance.digestJson(policyPayload);
  final manifestDigest = _digest('manifest-$runId');
  final bindingSeed = profileBindingSeed ?? 'bindings-$modelClass';
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
      'profileBindingSetDigest': _digest(bindingSeed),
      'agentDirectiveVariantSetDigest': _digest(
        'prompt-variants-$promptVariantName',
      ),
      'selectors': <String, dynamic>{
        'scenarioIds': protectedIdsRedacted ? const <String>[] : [scenarioId],
        'profileNames': [effectiveProfileName],
        'promptVariantNames': [promptVariantName],
        'requiredPrimaryCapabilityIds': requiredCapabilities,
      },
      'protectedIdsRedacted': protectedIdsRedacted,
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
        'scenarioIds': protectedIdsRedacted
            ? const ['<redacted-scenario-001>']
            : [scenarioId],
        'profileNames': [effectiveProfileName],
        'traceCount': 4,
        'judgedTraceCount': 4,
        'passCount': (passRate * 4).round(),
        'level1PassCount': 4,
        'passRate': passRate,
        'passRateLowerBound': passRateLowerBound,
        'meanGoalAttainment': meanGoalAttainment,
        'meanQuality': 4.4,
        'meanEfficiency': 4.2,
        'meanTokenBudgetRatio': 0.42,
        'weightedCostTraceCount': 0,
        'missingWeightedCostCount': 0,
        'meanWeightedCostBudgetRatio': 0,
        'recommendation': sliceBlockers.isEmpty ? 'keep' : 'gradeVerdicts',
        'blockingReasons': sliceBlockers,
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
      'suggestedScenarioIds': protectedIdsRedacted
          ? const <String>[]
          : [scenarioId],
      'suggestedProfileNames': [effectiveProfileName],
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

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String _string(Object? value) => value is String ? value : '';

EvalTuningReportSourceCheckResult _invalidSourceCheck(
  Map<String, dynamic> report,
  String issueCode,
) {
  return EvalTuningReportSourceCheckResult(
    reportDigest: EvalProvenance.digestJson(report),
    sourceCheckStatus: EvalTuningReportSourceCheckStatus.sourceInvalid,
    sourceIssueCodes: [issueCode],
    sourceSummary: const <String, dynamic>{},
  );
}

EvalTuningReportSourceCheckResult _fabricatedSourceCheck(
  Map<String, dynamic> report,
) {
  return EvalTuningReportSourceCheckResult(
    reportDigest: EvalProvenance.digestJson(report),
    sourceCheckStatus: EvalTuningReportSourceCheckStatus.sourceChecked,
    sourceIssueCodes: const <String>[],
    sourceSummary: const <String, dynamic>{},
  );
}

String _digest(String value) => EvalProvenance.digestText(value);
