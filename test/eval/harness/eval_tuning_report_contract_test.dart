import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';

void main() {
  test('accepts a valid minimal tuning report', () {
    final report = _validReport();

    expect(EvalTuningReportContract.validate(report), isEmpty);
    expect(() => EvalTuningReportContract.assertValid(report), returnsNormally);
  });

  test('reports schema, digest, count, gate, and next-plan violations', () {
    final report = _mutableValidReport()
      ..['schemaVersion'] = 2
      ..['generatedAt'] = 'not-a-date';
    final run = report['run'] as Map<String, dynamic>
      ..['manifestDigest'] = 'not-a-digest';
    final snapshot = run['artifactSnapshot'] as Map<String, dynamic>
      ..['artifactCount'] = 2
      ..['manifestDigest'] = _digest('other-manifest');
    final policy = report['policy'] as Map<String, dynamic>;
    (policy['payload'] as Map<String, dynamic>)['name'] = 'driftedPolicy';
    final status = report['status'] as Map<String, dynamic>
      ..['ready'] = true
      ..['failureCount'] = 0
      ..['warningCount'] = 1;
    final coverage = report['coverage'] as Map<String, dynamic>
      ..['expectedTraceCount'] = 1
      ..['traceCount'] = 2
      ..['judgedTraceCount'] = 2;
    final readiness = report['readiness'] as Map<String, dynamic>
      ..['policyDigest'] = _digest('different-policy');
    final gates = report['gates'] as List<dynamic>;
    (gates.single as Map<String, dynamic>)['status'] = 'maybe';
    final plan = report['nextExperimentPlan'] as Map<String, dynamic>
      ..['baseRunId'] = 'other-run'
      ..['status'] = 'ready';

    final issues = EvalTuningReportContract.validate(report);

    expect(issues, contains('schemaVersion must be 1'));
    expect(issues, contains('generatedAt must be an ISO-8601 timestamp'));
    expect(issues, contains('run.manifestDigest must be a sha256 digest'));
    expect(
      issues,
      contains(
        'run.artifactSnapshot.artifactCount must be >= '
        '1 + traceCount + judgedTraceCount',
      ),
    );
    expect(issues, contains('policy.digest must match policy.payload'));
    expect(issues, contains('status.ready must match readiness.ready'));
    expect(
      issues,
      contains('status.failureCount must match readiness.failures'),
    );
    expect(
      issues,
      contains('status.warningCount must match readiness.warnings'),
    );
    expect(
      issues,
      contains(
        'coverage.expectedTraceCount must match readiness.expectedTraceCount',
      ),
    );
    expect(
      issues,
      contains(
        'coverage.judgedTraceCount must match readiness.judgedTraceCount',
      ),
    );
    expect(
      issues,
      contains('coverage.traceCount must be <= expectedTraceCount'),
    );
    expect(issues, contains('readiness.policyDigest must match policy.digest'));
    expect(issues, contains('gates[0].status must be pass or fail'));
    expect(
      issues,
      contains('nextExperimentPlan.baseRunId must match run.runId'),
    );
    expect(
      issues,
      contains('nextExperimentPlan.status must match readiness.ready'),
    );
    expect(
      () => EvalTuningReportContract.assertValid(report),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Invalid tuning report contract'),
        ),
      ),
    );

    // Keep these mutated locals visibly used so future edits do not silently
    // remove one of the intended malformed sections.
    expect(snapshot['manifestDigest'], _digest('other-manifest'));
    expect(status['ready'], isTrue);
    expect(coverage['traceCount'], 2);
    expect(readiness['policyDigest'], _digest('different-policy'));
    expect(plan['status'], 'ready');
  });
}

Map<String, dynamic> _mutableValidReport() =>
    jsonDecode(jsonEncode(_validReport())) as Map<String, dynamic>;

Map<String, dynamic> _validReport() {
  final manifestDigest = _digest('manifest');
  const policyPayload = <String, dynamic>{'name': 'contractPolicy'};
  final policyDigest = EvalProvenance.digestJson(policyPayload);
  return <String, dynamic>{
    'schemaVersion': EvalTuningReportContract.schemaVersion,
    'kind': EvalTuningReportContract.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 9).toIso8601String(),
    'run': <String, dynamic>{
      'runId': 'contract-run',
      'targetKind': 'fixture',
      'manifestDigest': manifestDigest,
      'createdAt': DateTime.utc(2026, 6, 12, 8).toIso8601String(),
      'scenarioSetDigest': _digest('scenarios'),
      'profileSetDigest': _digest('profiles'),
      'profileBindingSetDigest': _digest('profile-bindings'),
      'agentDirectiveVariantSetDigest': _digest('prompt-variants'),
      'selectors': const <String, dynamic>{
        'scenarioIds': ['scenario-a'],
        'profileNames': ['frontier'],
        'promptVariantNames': ['default'],
        'requiredPrimaryCapabilityIds': ['task.workflow'],
      },
      'protectedIdsRedacted': false,
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
      'name': 'contractPolicy',
      'digest': policyDigest,
      'payload': policyPayload,
    },
    'status': const <String, dynamic>{
      'ready': false,
      'label': 'blocked',
      'failureCount': 1,
      'warningCount': 0,
    },
    'gates': [
      const <String, dynamic>{
        'id': 'coverage.trace_count',
        'status': 'fail',
        'scope': <String, dynamic>{},
        'actual': 2,
        'required': 3,
        'comparator': '>=',
        'evidenceRefs': <String>[],
        'blockerCode': 'coverage.traceCountLow',
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
      'policyName': 'contractPolicy',
      'policyDigest': policyDigest,
      'expectedTraceCount': 3,
      'traceCount': 2,
      'judgedTraceCount': 1,
      'failures': const ['coverage.traceCountLow'],
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
    'useCaseModelSlices': const [
      <String, dynamic>{
        'primaryCapabilityId': 'task.workflow',
        'agentKind': 'taskAgent',
        'modelClass': 'frontier',
        'promptVariantName': 'default',
        'blockingReasons': ['coverage.traceCountLow'],
        'gates': <dynamic>[],
      },
    ],
    'blockedReasons': const [
      <String, dynamic>{
        'code': 'coverage.traceCountLow',
        'severity': 'blocking',
        'message': 'Need more traces.',
        'nextAction': 'addScenarios',
        'scope': <String, dynamic>{},
      },
    ],
    'recommendations': const [
      <String, dynamic>{
        'id': 'rec-001',
        'priority': 1,
        'action': 'addScenarios',
        'status': 'recommended',
        'scope': <String, dynamic>{},
        'selectors': <String, dynamic>{},
        'blockedBy': ['coverage.traceCountLow'],
        'rationaleCodes': ['coverage.traceCountLow'],
      },
    ],
    'nextExperimentPlan': const <String, dynamic>{
      'schemaVersion': EvalTuningReportContract.schemaVersion,
      'kind': EvalTuningReportContract.nextExperimentPlanKind,
      'baseRunId': 'contract-run',
      'objective': 'closeReadinessGaps',
      'status': 'blocked',
      'blockedReasonCodes': ['coverage.traceCountLow'],
      'requiredCapabilities': ['task.workflow'],
      'suggestedCapabilities': ['task.workflow'],
      'suggestedScenarioIds': ['scenario-a'],
      'suggestedProfileNames': ['frontier'],
      'suggestedPromptVariantNames': ['default'],
      'requiredPairwiseIntentKeys': <String>[],
      'missingOrFailedPairwiseKeys': <String>[],
      'nextRunEnv': <String, dynamic>{},
      'recommendedCommands': [
        <String, dynamic>{
          'mode': 'tune',
          'command': 'eval/run_level2.sh tune <nextRunId>',
        },
      ],
    },
  };
}

String _digest(String value) => EvalProvenance.digestText(value);
