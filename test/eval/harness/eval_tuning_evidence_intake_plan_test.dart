import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';

const _intakeReportPaths = String.fromEnvironment('EVAL_TUNING_REPORTS');
const _intakeOutputPath = String.fromEnvironment(
  'EVAL_TUNING_EVIDENCE_INTAKE_PLAN',
);
const _intakeOverwrite = String.fromEnvironment(
  'EVAL_TUNING_EVIDENCE_INTAKE_PLAN_OVERWRITE',
);

void main() {
  test('turns calibration and holdout blockers into scoped intake tasks', () {
    final report = _report(
      blockedReasonCodes: const [
        'calibration.missingHumanLabels',
        'protectedHoldout.missingCatalogEvidence',
      ],
    );

    final plan = EvalTuningEvidenceIntakePlan.build(
      reports: [report],
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );

    expect(EvalTuningEvidenceIntakePlan.validate(plan), isEmpty);
    expect(plan['status'], 'readyForEvidenceCollection');
    final summary = plan['summary'] as Map<String, dynamic>;
    expect(summary['calibrationTaskCount'], 1);
    expect(summary['protectedHoldoutTaskCount'], 1);
    final tasks = (plan['tasks'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(tasks.map((task) => task['taskType']).toSet(), {
      'calibration',
      'protectedHoldout',
    });
    final calibration = tasks.singleWhere(
      (task) => task['taskType'] == 'calibration',
    );
    expect(
      calibration['action'],
      'completeHumanCalibrationLabelsAndRecalibrate',
    );
    expect(calibration['scope'], containsPair('modelClass', 'frontierFast'));
    expect(calibration['scope'], containsPair('promptVariantName', 'default'));
    expect(
      calibration['blockerCodes'],
      contains('calibration.missingHumanLabels'),
    );
  });

  test('sanitizes private blocker payloads from source reports', () {
    final report = _report(
      scenarioId: 'private_task_holdout_alpha',
      blockedReasonCodes: const [
        'calibration.missingHumanLabels for private_task_holdout_alpha',
        'protectedHoldout.requires /private/tmp/catalog.json',
      ],
    );

    final plan = EvalTuningEvidenceIntakePlan.build(
      reports: [report],
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );
    final encoded = jsonEncode(plan);

    expect(EvalTuningEvidenceIntakePlan.validate(plan), isEmpty);
    expect(encoded, isNot(contains('private_task_holdout_alpha')));
    expect(encoded, isNot(contains('/private/tmp/catalog.json')));
    expect(encoded, contains('protected-blocker.sha256:'));
  });

  test('classifies blockers before private payload sanitization', () {
    final report = _report(
      scenarioId: 'private_task_holdout_alpha',
      blockedReasonCodes: const [
        'calibration.missingHumanLabels for private_task_holdout_alpha',
      ],
    );

    final plan = EvalTuningEvidenceIntakePlan.build(
      reports: [report],
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );

    expect(EvalTuningEvidenceIntakePlan.validate(plan), isEmpty);
    final summary = plan['summary'] as Map<String, dynamic>;
    expect(summary['calibrationTaskCount'], 1);
    expect(summary['protectedHoldoutTaskCount'], 0);
    final task = _singleMap(plan, 'tasks');
    expect(task['taskType'], 'calibration');
    expect(
      task['action'],
      'completeHumanCalibrationLabelsAndRecalibrate',
    );
    expect(
      task['blockerCodes'],
      contains(startsWith('protected-blocker.sha256:')),
    );
  });

  test('invalid reports fail closed without evidence tasks', () {
    final invalid = _report(
      blockedReasonCodes: const ['calibration.missingHumanLabels'],
    )..['schemaVersion'] = 2;

    final plan = EvalTuningEvidenceIntakePlan.build(
      reports: [invalid],
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );

    expect(plan['status'], 'invalid');
    expect(plan['tasks'], isEmpty);
    final source = _singleMap(plan, 'sourceReports');
    expect(source['contractStatus'], 'invalid');
    expect(source['contractIssueCount'], greaterThan(0));
  });

  test('contract rejects forged summary counts', () {
    final plan = EvalTuningEvidenceIntakePlan.build(
      reports: [
        _report(
          blockedReasonCodes: const [
            'calibration.missingHumanLabels',
            'protectedHoldout.missingCatalogEvidence',
          ],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );
    final tampered = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
    tampered['summary'] as Map<String, dynamic>
      ..['invalidReportCount'] = 1
      ..['calibrationTaskCount'] = 0
      ..['protectedHoldoutTaskCount'] = 0;

    final issues = EvalTuningEvidenceIntakePlan.validate(tampered);

    expect(
      issues,
      contains(
        'summary.invalidReportCount must match invalid source reports',
      ),
    );
    expect(
      issues,
      contains('summary.calibrationTaskCount must match calibration tasks'),
    );
    expect(
      issues,
      contains(
        'summary.protectedHoldoutTaskCount must match protectedHoldout tasks',
      ),
    );
  });

  test('contract rejects private payloads and live commands', () {
    final plan = EvalTuningEvidenceIntakePlan.build(
      reports: [
        _report(blockedReasonCodes: const ['calibration.missingHumanLabels']),
      ],
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );
    final tampered = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
    (tampered['tasks'] as List<dynamic>).first as Map<String, dynamic>
      ..['scenarioIds'] = ['private_task_holdout_alpha']
      ..['notes'] = 'Use EVAL_SCENARIO_IDS from /private/tmp/catalog.json';
    (tampered['recommendedCommands'] as List<dynamic>).add(
      const <String, dynamic>{
        'mode': 'run',
        'command': 'eval/run_level2.sh run private',
      },
    );

    final issues = EvalTuningEvidenceIntakePlan.validate(tampered);

    expect(
      issues,
      contains(
        'evidenceIntakePlan.tasks[0].scenarioIds must not expose scenario ids',
      ),
    );
    expect(
      issues,
      contains(
        'evidenceIntakePlan.tasks[0].notes must not contain private paths',
      ),
    );
    expect(
      issues,
      contains(
        'evidenceIntakePlan.tasks[0].notes must not contain private env value keys',
      ),
    );
    expect(
      issues,
      contains(
        'recommendedCommands[6].command must not recommend live run commands',
      ),
    );
  });

  test(
    'writes tuning evidence intake plan',
    () {
      final reports = [
        for (final path in _intakeReportPaths.split(','))
          if (path.trim().isNotEmpty)
            jsonDecode(File(path.trim()).readAsStringSync())
                as Map<String, dynamic>,
      ];
      final plan = EvalTuningEvidenceIntakePlan.build(reports: reports);
      writeEvalJsonArtifact(
        plan,
        path: _intakeOutputPath,
        overwrite: _intakeOverwrite == '1',
        description: 'tuning evidence intake plan',
      );
    },
    skip: _intakeReportPaths.isEmpty || _intakeOutputPath.isEmpty
        ? 'Set EVAL_TUNING_REPORTS=<a.json,b.json> and '
              'EVAL_TUNING_EVIDENCE_INTAKE_PLAN=<json> to write an intake plan.'
        : false,
  );
}

Map<String, dynamic> _singleMap(Map<String, dynamic> root, String key) {
  final list = root[key] as List<dynamic>;
  expect(list, hasLength(1));
  return list.single as Map<String, dynamic>;
}

Map<String, dynamic> _report({
  List<String> blockedReasonCodes = const ['coverage.traceCountLow'],
  String scenarioId = 'task_workflow_structured_update',
}) {
  final manifestDigest = _digest('manifest');
  const policyPayload = <String, dynamic>{'name': 'modelClassTuning'};
  final policyDigest = EvalProvenance.digestJson(policyPayload);
  return <String, dynamic>{
    'schemaVersion': EvalTuningReportContract.schemaVersion,
    'kind': EvalTuningReportContract.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 9).toIso8601String(),
    'run': <String, dynamic>{
      'runId': 'intake-run',
      'targetKind': 'fixture',
      'manifestDigest': manifestDigest,
      'createdAt': DateTime.utc(2026, 6, 12, 8).toIso8601String(),
      'scenarioSetDigest': _digest('scenarios'),
      'profileSetDigest': _digest('profiles'),
      'profileBindingSetDigest': _digest('profile-bindings'),
      'agentDirectiveVariantSetDigest': _digest('prompt-variants'),
      'selectors': <String, dynamic>{
        'scenarioIds': [scenarioId],
        'profileNames': const ['frontier-fast'],
        'promptVariantNames': const ['default'],
        'requiredPrimaryCapabilityIds': const ['task.workflow'],
      },
      'protectedIdsRedacted': true,
      'artifactSnapshot': <String, dynamic>{
        'artifactCount': 4,
        'traceCount': 2,
        'judgedTraceCount': 1,
        'manifestDigest': manifestDigest,
        'ownedArtifactRefsDigest': _digest('owned-artifacts'),
        'loadedTraceContentDigest': _digest('loaded-traces'),
      },
    },
    'policy': <String, dynamic>{
      'name': 'modelClassTuning',
      'digest': policyDigest,
      'payload': policyPayload,
    },
    'status': <String, dynamic>{
      'ready': false,
      'label': 'blocked',
      'failureCount': blockedReasonCodes.length,
      'warningCount': 0,
    },
    'gates': [
      for (final code in blockedReasonCodes)
        <String, dynamic>{
          'id': code,
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
      'expectedTraceCount': 3,
      'traceCount': 2,
      'judgedTraceCount': 1,
      'missingRequiredPrimaryCapabilityIds': <String>[],
    },
    'readiness': <String, dynamic>{
      'ready': false,
      'evidenceLabel': 'blocked',
      'policyName': 'modelClassTuning',
      'policyDigest': policyDigest,
      'expectedTraceCount': 3,
      'traceCount': 2,
      'judgedTraceCount': 1,
      'failures': blockedReasonCodes,
      'warnings': const <String>[],
      'missingRequiredPrimaryCapabilityIds': const <String>[],
    },
    'outcomes': const <String, dynamic>{
      'aggregate': <String, dynamic>{},
      'slices': <dynamic>[],
      'failingTraceCount': 1,
    },
    'calibration': const <String, dynamic>{'present': false},
    'pairwise': const <String, dynamic>{'present': false},
    'promotion': const <String, dynamic>{
      'present': false,
      'status': 'notRequested',
    },
    'useCaseModelSlices': [
      <String, dynamic>{
        'primaryCapabilityId': 'task.workflow',
        'agentKind': 'taskAgent',
        'modelClass': 'frontierFast',
        'promptVariantName': 'default',
        'blockingReasons': blockedReasonCodes,
        'gates': const <dynamic>[],
      },
    ],
    'blockedReasons': [
      for (final code in blockedReasonCodes)
        <String, dynamic>{
          'code': code,
          'severity': 'blocking',
          'message': 'Evidence gap.',
          'nextAction': 'collectEvidence',
          'scope': const <String, dynamic>{},
        },
    ],
    'recommendations': const [
      <String, dynamic>{
        'id': 'rec-001',
        'priority': 1,
        'action': 'collectEvidence',
        'status': 'recommended',
        'scope': <String, dynamic>{},
        'selectors': <String, dynamic>{},
        'blockedBy': <String>[],
        'rationaleCodes': <String>[],
      },
    ],
    'nextExperimentPlan': <String, dynamic>{
      'schemaVersion': EvalTuningReportContract.schemaVersion,
      'kind': EvalTuningReportContract.nextExperimentPlanKind,
      'baseRunId': 'intake-run',
      'objective': 'closeReadinessGaps',
      'status': 'blocked',
      'blockedReasonCodes': blockedReasonCodes,
      'requiredCapabilities': const ['task.workflow'],
      'suggestedCapabilities': const ['task.workflow'],
      'suggestedScenarioIds': [scenarioId],
      'suggestedProfileNames': const ['frontier-fast'],
      'suggestedPromptVariantNames': const ['default'],
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
