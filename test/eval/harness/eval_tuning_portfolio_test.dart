import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';

const _portfolioInputPaths = String.fromEnvironment('EVAL_TUNING_REPORTS');
const _portfolioOutputPath = String.fromEnvironment(
  'EVAL_TUNING_PORTFOLIO_REPORT',
);
const _portfolioOverwrite = String.fromEnvironment(
  'EVAL_TUNING_PORTFOLIO_OVERWRITE',
);

void main() {
  test('selects promotion-ready candidates ahead of unready diagnostics', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        _report(
          runId: 'frontier-run',
          modelClass: 'frontier',
          ready: true,
          promotionStatus: 'promote',
          passRateLowerBound: 0.72,
          passRate: 0.91,
          meanGoalAttainment: 4.6,
        ),
        _report(
          runId: 'local-run',
          modelClass: 'local',
          blockingReasonCodes: const ['calibration.missingHumanLabels'],
          passRateLowerBound: 0.82,
          passRate: 0.97,
          meanGoalAttainment: 4.9,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(portfolio['status'], 'promotionReady');
    final group = _singleMap(portfolio, 'compatibilityGroups');
    expect(group['status'], 'promotionReady');
    final family = _singleMap(group, 'families');
    expect(family['status'], 'promotionReady');
    expect(
      family['promotionReadyCandidateKeys'],
      contains('task.workflow@taskAgent@frontier@default@frontier-run'),
    );
    final leader = family['leader'] as Map<String, dynamic>;
    expect(leader['runId'], 'frontier-run');
    expect(leader['promotionEvidence'], isTrue);

    final candidates = (family['candidates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(candidates.first['evidenceStatus'], 'promotionReady');
    expect(candidates.last['evidenceStatus'], 'dataDeficient');
    expect(
      family['dataDeficiencyCodes'],
      contains('calibration.missingHumanLabels'),
    );
  });

  test('keeps incompatible fixed evidence in separate unranked groups', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        _report(runId: 'same-policy-a', modelClass: 'frontier'),
        _report(
          runId: 'different-scenarios',
          modelClass: 'frontier',
          scenarioSetSeed: 'different-scenario-set',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(portfolio['status'], 'incompatible');
    expect(
      portfolio['issues'],
      contains(
        isA<Map<String, dynamic>>().having(
          (issue) => issue['code'],
          'code',
          'compatibility.multipleGroups',
        ),
      ),
    );
    expect(portfolio['compatibilityGroups'], hasLength(2));
  });

  test('surfaces invalid report contracts before comparison', () {
    final invalid = _report(runId: 'bad-run', modelClass: 'frontier')
      ..['schemaVersion'] = 2;

    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        invalid,
        _report(runId: 'valid-run', modelClass: 'local'),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(portfolio['status'], 'invalid');
    final inputReports = (portfolio['inputReports'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(inputReports.first['contractStatus'], 'invalid');
    expect(
      inputReports.first['contractIssues'],
      contains('schemaVersion must be 1'),
    );
    expect(
      portfolio['issues'],
      contains(
        isA<Map<String, dynamic>>().having(
          (issue) => issue['code'],
          'code',
          'report.contractInvalid',
        ),
      ),
    );
  });

  test('does not leak protected scenario ids from redacted reports', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        _report(
          runId: 'private-a',
          modelClass: 'frontier',
          protectedIdsRedacted: true,
          scenarioId: 'private_task_holdout_alpha',
        ),
        _report(
          runId: 'private-b',
          modelClass: 'local',
          protectedIdsRedacted: true,
          scenarioId: 'private_task_holdout_alpha',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final encoded = jsonEncode(portfolio);

    expect(EvalTuningPortfolio.validate(portfolio), isEmpty);
    expect(portfolio['status'], 'dataDeficient');
    expect(encoded, isNot(contains('private_task_holdout_alpha')));
    expect(encoded, isNot(contains('<redacted-scenario')));
  });

  test(
    'adds group-scoped next experiment plans without scenario selectors',
    () {
      final portfolio = EvalTuningPortfolio.compare(
        reports: [
          _report(
            runId: 'frontier-run',
            modelClass: 'frontier',
            ready: true,
            promotionStatus: 'promote',
          ),
          _report(
            runId: 'local-run',
            modelClass: 'local',
            blockingReasonCodes: const ['calibration.missingHumanLabels'],
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 10),
      );

      expect(EvalTuningPortfolio.validate(portfolio), isEmpty);
      final plan = portfolio['nextExperimentPlan'] as Map<String, dynamic>;
      expect(plan['kind'], EvalTuningPortfolio.nextExperimentPlanKind);
      expect(plan['status'], 'promotionReady');
      expect(plan['sourceCompatibilityKeys'], hasLength(1));
      expect(plan['sourceRunIds'], ['frontier-run', 'local-run']);
      expect(
        plan['blockedReasonCodes'],
        contains('calibration.missingHumanLabels'),
      );
      final withheld = plan['withheldSelectors'] as Map<String, dynamic>;
      expect(withheld['scenarioIdsOmitted'], isTrue);
      expect(withheld['sourceReportScenarioSuggestionCount'], 2);

      final groupPlan = _singleMap(plan, 'groupPlans');
      expect(groupPlan['status'], 'promotionReady');
      final safeSelectors = groupPlan['safeSelectors'] as Map<String, dynamic>;
      expect(safeSelectors['capabilities'], ['task.workflow']);
      expect(safeSelectors['profileNames'], [
        'profile-frontier',
        'profile-local',
      ]);
      expect(safeSelectors['promptVariantNames'], ['default']);
      expect(
        groupPlan['manualPrerequisites'],
        contains(
          isA<Map<String, dynamic>>().having(
            (item) => item['action'],
            'action',
            'completeHumanCalibration',
          ),
        ),
      );
      final commands = (groupPlan['recommendedCommands'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(commands.map((command) => command['mode']), ['compare-tuning']);
      expect(commands.any((command) => command.containsKey('env')), isFalse);
      expect(
        jsonEncode(plan),
        isNot(
          anyOf(
            contains('EVAL_SCENARIO_IDS'),
            contains('task_workflow_structured_update'),
          ),
        ),
      );
    },
  );

  test('keeps incompatible next plans group-scoped instead of merging env', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        _report(runId: 'frontier-run', modelClass: 'frontier'),
        _report(
          runId: 'other-scenarios',
          modelClass: 'local',
          scenarioSetSeed: 'other-scenario-set',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final plan = portfolio['nextExperimentPlan'] as Map<String, dynamic>;

    expect(portfolio['status'], 'incompatible');
    expect(plan['status'], 'incompatible');
    expect(plan['groupPlans'], hasLength(2));
    expect(plan, isNot(contains('nextRunEnv')));
    expect(
      plan['blockedReasonCodes'],
      contains('compatibility.multipleGroups'),
    );
  });

  test('omits unsafe selector values from env and commands', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        _report(
          runId: 'unsafe-profile-run',
          modelClass: 'frontier',
          profileName: 'bad;rm',
        ),
        _report(runId: 'safe-profile-run', modelClass: 'local'),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(EvalTuningPortfolio.validate(portfolio), isEmpty);
    final plan = portfolio['nextExperimentPlan'] as Map<String, dynamic>;
    final groupPlan = _singleMap(plan, 'groupPlans');
    final safeSelectors = groupPlan['safeSelectors'] as Map<String, dynamic>;
    final nextRunEnv = groupPlan['nextRunEnv'] as Map<String, dynamic>;
    final commands = (groupPlan['recommendedCommands'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final encodedCommands = jsonEncode(commands);

    expect(safeSelectors['profileNames'], ['profile-local']);
    expect(nextRunEnv['EVAL_PROFILE_NAMES'], 'profile-local');
    expect(commands.any((command) => command.containsKey('env')), isFalse);
    expect(encodedCommands, isNot(contains('bad;rm')));
    expect(
      (groupPlan['withheldSelectors']
          as Map<String, dynamic>)['unsafeSelectorValueCount'],
      1,
    );
  });

  test('contract rejects scenario env keys and command handoffs in plans', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        _report(runId: 'frontier-run', modelClass: 'frontier'),
        _report(runId: 'local-run', modelClass: 'local'),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final tampered = jsonDecode(jsonEncode(portfolio)) as Map<String, dynamic>;
    final plan = tampered['nextExperimentPlan'] as Map<String, dynamic>;
    final groupPlan = _singleMap(plan, 'groupPlans');
    (groupPlan['nextRunEnv'] as Map<String, dynamic>)['EVAL_SCENARIO_IDS'] =
        'task_workflow_structured_update';
    final command =
        ((groupPlan['recommendedCommands'] as List<dynamic>).first
              as Map<String, dynamic>)
          ..['mode'] = 'run'
          ..['command'] = 'eval/run_level2.sh run <nextRunId>'
          ..['env'] = const {'EVAL_PROFILE_NAMES': 'profile-local'};

    final issues = EvalTuningPortfolio.validate(tampered);

    expect(command['env'], contains('EVAL_PROFILE_NAMES'));
    expect(
      issues,
      contains(
        'nextExperimentPlan.groupPlans[0].nextRunEnv must not contain EVAL_SCENARIO_IDS',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.groupPlans[0].recommendedCommands[0].mode is unsupported',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.groupPlans[0].recommendedCommands[0].command must not recommend live run commands',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.groupPlans[0].recommendedCommands[0] must not contain env values',
      ),
    );
  });

  test('validates generated portfolio contract and rejects drift', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        _report(runId: 'frontier-run', modelClass: 'frontier'),
        _report(runId: 'local-run', modelClass: 'local'),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(EvalTuningPortfolio.validate(portfolio), isEmpty);
    expect(() => EvalTuningPortfolio.assertValid(portfolio), returnsNormally);

    final drifted = jsonDecode(jsonEncode(portfolio)) as Map<String, dynamic>;
    final summary = drifted['summary'] as Map<String, dynamic>
      ..['inputReportCount'] = 99;
    expect(summary['inputReportCount'], 99);
    final group = _singleMap(drifted, 'compatibilityGroups')
      ..['compatibilityKey'] = _digest('wrong-compatibility-key');
    final family = _singleMap(group, 'families');
    final candidates = family['candidates'] as List<dynamic>;
    (candidates.first as Map<String, dynamic>)['scenarioIds'] = const [
      'private_task_holdout_alpha',
    ];

    final issues = EvalTuningPortfolio.validate(drifted);

    expect(
      issues,
      contains('summary.inputReportCount must match inputReports.length'),
    );
    expect(
      issues,
      contains(
        'compatibilityGroups[0].compatibilityKey must match fixedEvidence',
      ),
    );
    expect(
      issues,
      contains(
        'portfolio.compatibilityGroups[0].families[0].candidates[0]'
        '.scenarioIds must not expose scenario ids',
      ),
    );
  });

  test('keeps malformed invalid inputs contract-valid as diagnostics', () {
    final portfolio = EvalTuningPortfolio.compare(
      reports: [
        const <String, dynamic>{'schemaVersion': 99},
        _report(runId: 'valid-run', modelClass: 'frontier'),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    expect(portfolio['status'], 'invalid');
    expect(EvalTuningPortfolio.validate(portfolio), isEmpty);
    final inputReports = (portfolio['inputReports'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(inputReports.first['runId'], 'report-0');
    expect(inputReports.first['contractIssues'], isNotEmpty);
  });

  test(
    'writes tuning portfolio report',
    () {
      final reports = [
        for (final path
            in _portfolioInputPaths
                .split(',')
                .map((path) => path.trim())
                .where((path) => path.isNotEmpty))
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
      ];
      final portfolio = EvalTuningPortfolio.compare(reports: reports);
      EvalTuningPortfolio.assertValid(portfolio);
      expect(
        portfolio['status'],
        isNot('invalid'),
        reason: const JsonEncoder.withIndent('  ').convert(portfolio),
      );
      writeEvalJsonArtifact(
        portfolio,
        path: _portfolioOutputPath,
        overwrite: _portfolioOverwrite == '1',
        description: 'tuning portfolio report',
      );
    },
    skip: _portfolioInputPaths.isEmpty || _portfolioOutputPath.isEmpty
        ? 'Set EVAL_TUNING_REPORTS=<a.json,b.json> and '
              'EVAL_TUNING_PORTFOLIO_REPORT=<json> to write a portfolio.'
        : false,
  );
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
  String promptVariantName = 'default',
  List<String> blockingReasonCodes = const ['verdict.missing'],
  double passRateLowerBound = 0.55,
  double passRate = 0.75,
  double meanGoalAttainment = 4,
}) {
  final effectiveBlockers = ready ? const <String>[] : blockingReasonCodes;
  final effectiveProfileName = profileName ?? 'profile-$modelClass';
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
        'scenarioIds': protectedIdsRedacted ? const <String>[] : [scenarioId],
        'profileNames': [effectiveProfileName],
        'promptVariantNames': [promptVariantName],
        'requiredPrimaryCapabilityIds': const ['task.workflow'],
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
    'promotion': <String, dynamic>{
      'present': promotionStatus != 'notRequested',
      'status': promotionStatus,
      'evidencePlan': promotionStatus == 'notRequested'
          ? null
          : const <String, dynamic>{'status': 'matched'},
    },
    'useCaseModelSlices': [
      <String, dynamic>{
        'sliceKey': 'task.workflow@taskAgent@$modelClass@$promptVariantName',
        'primaryCapabilityId': 'task.workflow',
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

String _digest(String value) => EvalProvenance.digestText(value);
