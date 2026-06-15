import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';

const _reviewSourcePath = String.fromEnvironment(
  'EVAL_ADVERSARIAL_REVIEW_SOURCE',
);
const _reviewPacketPath = String.fromEnvironment(
  'EVAL_ADVERSARIAL_REVIEW_PACKET',
);
const _reviewPacketOverwrite = String.fromEnvironment(
  'EVAL_ADVERSARIAL_REVIEW_PACKET_OVERWRITE',
);
const _reviewInputPath = String.fromEnvironment(
  'EVAL_ADVERSARIAL_REVIEW_INPUT',
);
const _reviewAttestationsPath = String.fromEnvironment(
  'EVAL_ADVERSARIAL_REVIEW_ATTESTATIONS',
);
const _reviewAttestationsOverwrite = String.fromEnvironment(
  'EVAL_ADVERSARIAL_REVIEW_ATTESTATIONS_OVERWRITE',
);

void main() {
  test('builds a pending review packet from every campaign review task', () {
    final campaign = _campaign();

    final packet = EvalUseCaseAdversarialReview.buildPacket(
      campaign: campaign,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(EvalUseCaseAdversarialReview.validatePacket(packet), isEmpty);
    expect(
      EvalProvenance.isDigest(packet['reviewPacketRef'] as String),
      isTrue,
    );
    expect(
      packet['reviewPacketRef'],
      EvalUseCaseAdversarialReview.reviewPacketRef(packet),
    );
    expect(packet['status'], 'readyForReview');
    final source = packet['sourceCampaign'] as Map<String, dynamic>;
    expect(source['campaignRef'], campaign['campaignRef']);
    expect(source['sourceQueueDigest'], isA<String>());
    final queue = campaign['adversarialReviewQueue'] as Map<String, dynamic>;
    final sourceTasks = (queue['tasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final tasks = (packet['reviewTasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(tasks, hasLength(sourceTasks.length));
    expect(tasks.map((task) => task['reviewRef']).toSet(), {
      for (final task in sourceTasks) task['reviewRef'],
    });
    final templates = (packet['attestationTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(templates, hasLength(tasks.length));
    expect(templates.map((task) => task['status']).toSet(), {'pending'});
    expect(
      const JsonEncoder().convert(packet),
      allOf(
        isNot(contains('follow-up-promote')),
        isNot(contains('scenario-task.workflow')),
        isNot(contains('profile-frontier')),
      ),
    );
  });

  test('imports approved attestations into an exact task-bound bundle', () {
    final campaign = _campaign();
    final attestations = _approvedAttestations(campaign);

    final bundle = EvalUseCaseAdversarialReview.buildAttestationBundle(
      campaign: campaign,
      attestations: attestations,
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    expect(EvalUseCaseAdversarialReview.validateBundle(bundle), isEmpty);
    expect(
      EvalProvenance.isDigest(bundle['attestationBundleRef'] as String),
      isTrue,
    );
    expect(
      bundle['attestationBundleRef'],
      EvalUseCaseAdversarialReview.attestationBundleRef(bundle),
    );
    expect(bundle['status'], 'approved');
    expect(
      (bundle['sourceCampaign'] as Map<String, dynamic>)['campaignRef'],
      campaign['campaignRef'],
    );
    final summary = bundle['summary'] as Map<String, dynamic>;
    expect(summary['approvedAttestationCount'], attestations.length);
    expect(summary['issueCount'], 0);
  });

  test('subject refs reject source summary relabeling', () {
    final campaign = _campaign();
    final packet = EvalUseCaseAdversarialReview.buildPacket(
      campaign: campaign,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tamperedPacket =
        jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
    (tamperedPacket['sourceCampaign'] as Map<String, dynamic>)['campaignRef'] =
        _digest('forged-campaign-ref');

    expect(
      EvalUseCaseAdversarialReview.validatePacket(tamperedPacket),
      contains(
        'reviewPacketRef must match adversarial review packet subject digest',
      ),
    );

    final bundle = EvalUseCaseAdversarialReview.buildAttestationBundle(
      campaign: campaign,
      attestations: _approvedAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );
    final tamperedBundle =
        jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
    (tamperedBundle['sourceCampaign'] as Map<String, dynamic>)['campaignRef'] =
        _digest('forged-campaign-ref');

    expect(
      EvalUseCaseAdversarialReview.validateBundle(tamperedBundle),
      contains(
        'attestationBundleRef must match adversarial review bundle subject digest',
      ),
    );
  });

  test('contract rejects approval relabeling with stale evidence digest', () {
    final campaign = _campaign();
    final packet = EvalUseCaseAdversarialReview.buildPacket(
      campaign: campaign,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final template =
        (packet['attestationTemplates'] as List<dynamic>).first
            as Map<String, dynamic>;
    final forged = <String, dynamic>{
      ...template,
      'status': 'approved',
      'reviewerRefDigest': EvalProvenance.digestText('adversarial-reviewer'),
      'reviewedAt': DateTime.utc(2026, 6, 12, 13, 30).toIso8601String(),
    };

    expect(
      EvalUseCaseAdversarialReview.validateApprovedAttestations([forged]),
      contains(
        'reviewAttestations[0].evidenceDigest must bind review attestation fields',
      ),
    );
  });

  test(
    'rejects stale, missing, duplicate, and mismatched task attestations',
    () {
      final campaign = _campaign();
      final approved = _approvedAttestations(campaign);
      final pending =
          (EvalUseCaseAdversarialReview.buildPacket(
                    campaign: campaign,
                    generatedAt: DateTime.utc(2026, 6, 12, 13),
                  )['attestationTemplates']
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();

      for (final scenario in <String, List<Map<String, dynamic>>>{
        'pending templates': pending,
        'stale source digest': [
          {...approved.first, 'sourceArtifactDigest': _digest('wrong-source')},
          ...approved.skip(1),
        ],
        'stale queue digest': [
          {...approved.first, 'sourceQueueDigest': _digest('wrong-queue')},
          ...approved.skip(1),
        ],
        'wrong review ref': [
          {...approved.first, 'reviewRef': _digest('wrong-review-ref')},
          ...approved.skip(1),
        ],
        'wrong category': [
          {...approved.first, 'category': 'reportLinkageAudit'},
          ...approved.skip(1),
        ],
        'missing task': [...approved.skip(1)],
        'duplicate task': [...approved, approved.first],
      }.entries) {
        expect(
          () => EvalUseCaseAdversarialReview.buildAttestationBundle(
            campaign: campaign,
            attestations: scenario.value,
            generatedAt: DateTime.utc(2026, 6, 12, 14),
          ),
          throwsStateError,
          reason: scenario.key,
        );
      }
    },
  );

  test('contract rejects source-mixed attestation bundles', () {
    final campaign = _campaign();
    final otherCampaign = _campaign(runId: 'other-follow-up-promote');
    final bundle = EvalUseCaseAdversarialReview.buildAttestationBundle(
      campaign: campaign,
      attestations: _approvedAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );
    final mixed = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>
      ..['attestations'] = _approvedAttestations(otherCampaign);
    mixed['attestationBundleRef'] =
        EvalUseCaseAdversarialReview.attestationBundleRef(mixed);

    final issues = EvalUseCaseAdversarialReview.validateBundle(mixed);

    expect(
      issues,
      contains('attestations[0] must match a required review task'),
    );
    expect(
      () => EvalUseCaseAdversarialReview.approvedAttestationsFromValidBundles([
        mixed,
      ]),
      throwsStateError,
    );
  });

  test('rejected and needs-changes attestations do not become approvals', () {
    final campaign = _campaign();
    final rejected = [
      for (final attestation in _approvedAttestations(campaign))
        _stampedAttestation(<String, dynamic>{
          ...attestation,
          'status': attestation['category'] == 'privacyAudit'
              ? 'needsChanges'
              : 'rejected',
        }),
    ];

    final bundle = EvalUseCaseAdversarialReview.buildAttestationBundle(
      campaign: campaign,
      attestations: rejected,
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    expect(bundle['status'], 'changesRequested');
    expect(
      EvalUseCaseAdversarialReview.approvedAttestationsFromBundles([bundle]),
      isEmpty,
    );
  });

  test('contract rejects private payload and command smuggling', () {
    final campaign = _campaign();
    final packet = EvalUseCaseAdversarialReview.buildPacket(
      campaign: campaign,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>
      ..['scenarioIds'] = const ['private-case'];
    final task =
        ((tampered['reviewTasks'] as List<dynamic>).first
              as Map<String, dynamic>)
          ..['profileNames'] = const ['private-profile']
          ..['runId'] = 'raw-run-id'
          ..['notes'] =
              'Use EVAL_USE_CASE_DECISION_MATRIX_INPUT from /private/path/matrix.json'
          ..['linuxNotes'] = 'read /home/runner/work/review.json';
    expect(task, isNotEmpty);
    (tampered['recommendedCommands'] as List<dynamic>).add(
      const <String, dynamic>{
        'mode': 'run',
        'command': "bash -lc 'eval/run_level2.sh run'",
        'env': {'EVAL_SCENARIO_IDS': 'private-case'},
      },
    );
    final template =
        ((tampered['attestationTemplates'] as List<dynamic>).first
              as Map<String, dynamic>)
          ..['reviewer'] = 'alice'
          ..['command'] = 'eval/run_level2.sh run';
    expect(template, isNotEmpty);

    final issues = EvalUseCaseAdversarialReview.validatePacket(tampered);

    expect(issues, contains('packet.scenarioIds must not expose scenario ids'));
    expect(
      issues,
      contains(
        'packet.reviewTasks[0].profileNames must not expose profile selectors',
      ),
    );
    expect(
      issues,
      contains('packet.reviewTasks[0].runId must not expose run ids'),
    );
    expect(
      issues,
      contains('packet.reviewTasks[0].notes must not contain private paths'),
    );
    expect(
      issues,
      contains(
        'packet.reviewTasks[0].notes must not contain private env value keys',
      ),
    );
    expect(
      issues,
      contains(
        'packet.reviewTasks[0].linuxNotes must not contain private paths',
      ),
    );
    expect(
      issues,
      contains('attestationTemplates[0] must not contain reviewer'),
    );
    expect(
      issues,
      contains('attestationTemplates[0] must not contain command'),
    );
    expect(
      issues,
      contains(
        'recommendedCommands[2].command must not recommend live run commands',
      ),
    );
    expect(
      issues,
      contains('recommendedCommands[2] must not contain env values'),
    );
  });

  test(
    'writes use-case adversarial review packet',
    () {
      final campaign =
          jsonDecode(File(_reviewSourcePath).readAsStringSync())
              as Map<String, dynamic>;
      final packet = EvalUseCaseAdversarialReview.buildPacket(
        campaign: campaign,
      );
      EvalUseCaseAdversarialReview.assertValidPacket(packet);
      writeEvalJsonArtifact(
        packet,
        path: _reviewPacketPath,
        overwrite: _reviewPacketOverwrite == '1',
        description: 'use-case adversarial review packet',
      );
    },
    skip: _reviewSourcePath.isEmpty || _reviewPacketPath.isEmpty
        ? 'Set EVAL_ADVERSARIAL_REVIEW_SOURCE=<json> and '
              'EVAL_ADVERSARIAL_REVIEW_PACKET=<json> to write a packet.'
        : false,
  );

  test(
    'writes use-case adversarial review attestation bundle',
    () {
      final campaign =
          jsonDecode(File(_reviewSourcePath).readAsStringSync())
              as Map<String, dynamic>;
      final attestations = _readJsonList(_reviewInputPath);
      final bundle = EvalUseCaseAdversarialReview.buildAttestationBundle(
        campaign: campaign,
        attestations: attestations,
      );
      EvalUseCaseAdversarialReview.assertValidBundle(bundle);
      writeEvalJsonArtifact(
        bundle,
        path: _reviewAttestationsPath,
        overwrite: _reviewAttestationsOverwrite == '1',
        description: 'use-case adversarial review attestation bundle',
      );
    },
    skip:
        _reviewSourcePath.isEmpty ||
            _reviewInputPath.isEmpty ||
            _reviewAttestationsPath.isEmpty
        ? 'Set EVAL_ADVERSARIAL_REVIEW_SOURCE=<json>, '
              'EVAL_ADVERSARIAL_REVIEW_INPUT=<json>, and '
              'EVAL_ADVERSARIAL_REVIEW_ATTESTATIONS=<json> to write a bundle.'
        : false,
  );
}

Map<String, dynamic> _campaign({
  String runId = 'follow-up-promote',
}) {
  final report = _report(
    runId: runId,
    modelClass: 'frontier',
    ready: true,
    promotionStatus: 'promote',
  );
  final matrix = EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: [
      _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
    ],
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
  final plan = EvalUseCaseExperimentPlan.build(
    matrix: matrix,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
  );
  return EvalUseCaseTuningCampaign.build(
    requireSourceChecks: false,
    experimentPlan: plan,
    reports: [report],
    generatedAt: DateTime.utc(2026, 6, 12, 12),
  );
}

List<Map<String, dynamic>> _approvedAttestations(
  Map<String, dynamic> campaign,
) {
  final packet = EvalUseCaseAdversarialReview.buildPacket(
    campaign: campaign,
    generatedAt: DateTime.utc(2026, 6, 12, 13),
  );
  final templates = (packet['attestationTemplates'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return [
    for (final template in templates)
      _stampedAttestation(<String, dynamic>{
        ...template,
        'status': 'approved',
        'reviewerRefDigest': EvalProvenance.digestText('adversarial-reviewer'),
        'reviewedAt': DateTime.utc(2026, 6, 12, 13, 30).toIso8601String(),
      }),
  ];
}

Map<String, dynamic> _stampedAttestation(Map<String, dynamic> attestation) {
  attestation['evidenceDigest'] =
      EvalUseCaseAdversarialReview.attestationEvidenceDigest(attestation);
  return attestation;
}

Map<String, dynamic> _report({
  required String runId,
  required String modelClass,
  bool ready = false,
  String promotionStatus = 'notRequested',
}) {
  final effectiveBlockers = ready
      ? const <String>[]
      : const ['verdict.missing'];
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
      'scenarioSetDigest': _digest('scenario-set'),
      'profileSetDigest': _digest('profiles-$modelClass'),
      'profileBindingSetDigest': _digest('bindings-$modelClass'),
      'agentDirectiveVariantSetDigest': _digest('prompt-variants-default'),
      'selectors': <String, dynamic>{
        'scenarioIds': const ['scenario-task.workflow'],
        'profileNames': ['profile-$modelClass'],
        'promptVariantNames': const ['default'],
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
        'sliceKey': 'task.workflow@taskAgent@$modelClass@default',
        'primaryCapabilityId': 'task.workflow',
        'agentKind': 'taskAgent',
        'modelClass': modelClass,
        'promptVariantName': 'default',
        'scenarioIds': const ['scenario-task.workflow'],
        'profileNames': ['profile-$modelClass'],
        'traceCount': 4,
        'judgedTraceCount': 4,
        'passCount': ready ? 4 : 2,
        'level1PassCount': 4,
        'passRate': ready ? 1 : 0.5,
        'passRateLowerBound': ready ? 0.8 : 0.2,
        'meanGoalAttainment': ready ? 5 : 3,
        'meanQuality': ready ? 5 : 3,
        'meanEfficiency': ready ? 5 : 3,
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
      'suggestedScenarioIds': const ['scenario-task.workflow'],
      'suggestedProfileNames': ['profile-$modelClass'],
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

List<Map<String, dynamic>> _readJsonList(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is List) {
    return [for (final item in decoded) item as Map<String, dynamic>];
  }
  if (decoded is Map<String, dynamic>) {
    if (decoded['kind'] == EvalUseCaseAdversarialReview.packetKind) {
      return (decoded['attestationTemplates'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    if (decoded['kind'] == EvalUseCaseAdversarialReview.bundleKind) {
      return (decoded['attestations'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    return [decoded];
  }
  throw StateError('Expected review input JSON object or list.');
}

String _digest(String value) => EvalProvenance.digestText(value);
