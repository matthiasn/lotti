import 'dart:convert';
import 'dart:io';

import 'package:lotti/features/ai/model/inference_usage.dart';

import 'eval_decision_ledger_source_replay_test_utils.dart';
import 'eval_harness.dart';
import 'eval_profile_config.dart';
import 'eval_tuning_source_replay_test_utils.dart';
import 'eval_use_case_runtime_source_replay_test_utils.dart' as source_replay;

Map<String, dynamic> buildReleasePlanFixture({
  bool accepted = true,
  String compatibilitySeed = 'task-compat',
  String primaryCapabilityId = 'task.workflow',
  String modelClass = 'frontierFast',
  String promptVariantName = 'metadata-first-v2',
  String cellSeed = 'task-frontier-fast',
  String reportSeed = 'task-report',
  String agentKind = releaseFixtureAgentKind,
}) {
  final fixture = ReleaseScopeFixture(
    compatibilitySeed: compatibilitySeed,
    primaryCapabilityId: primaryCapabilityId,
    agentKind: agentKind,
    modelClass: modelClass,
    promptVariantName: promptVariantName,
    cellSeed: cellSeed,
    reportSeed: reportSeed,
  );
  final ledger = buildReleaseDecisionLedgerFixture(
    accepted ? fixture.acceptedDecision() : fixture.blockedDecision(),
  );
  final roadmap = EvalUseCaseTuningRoadmap.build(
    ledgers: [ledger],
    generatedAt: DateTime.utc(2026, 6, 12, 15),
  );
  return EvalUseCaseTuningReleasePlan.build(
    roadmap: roadmap,
    sourceDecisionLedgers: [ledger],
    generatedAt: DateTime.utc(2026, 6, 12, 16),
  );
}

final class DecisionLedgerSourceBoundReleaseFixture {
  const DecisionLedgerSourceBoundReleaseFixture({
    required this.ledger,
    required this.roadmap,
    required this.releasePlan,
  });

  final Map<String, dynamic> ledger;
  final Map<String, dynamic> roadmap;
  final Map<String, dynamic> releasePlan;
}

/// Builds a compact release fixture with a process-local decision-ledger source
/// marker. Use manifest replay helpers for full matrix/campaign source replay.
DecisionLedgerSourceBoundReleaseFixture
buildDecisionLedgerSourceBoundReleaseFixture({
  String primaryCapabilityId = 'task.workflow',
  String promptVariantName = 'default',
  String baseRunId = 'source-replayed-base-ready',
  String followUpRunId = 'source-replayed-follow-up-promote',
}) {
  final base = _sourceReplayReport(
    runId: baseRunId,
    modelClass: 'frontier',
    ready: true,
    primaryCapabilityId: primaryCapabilityId,
    promptVariantName: promptVariantName,
  );
  final followUp = _sourceReplayReport(
    runId: followUpRunId,
    modelClass: 'frontier',
    ready: true,
    promotionStatus: 'promote',
    primaryCapabilityId: primaryCapabilityId,
    promptVariantName: promptVariantName,
  );
  final campaignMatrix = EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: [base],
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
  final plan = EvalUseCaseExperimentPlan.build(
    matrix: campaignMatrix,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
  );
  final workOrder = EvalUseCaseNextRunWorkOrder.build(
    experimentPlan: plan,
    generatedAt: DateTime.utc(2026, 6, 12, 11, 30),
  );
  final coverage = _modelClassCoverageForWorkOrderFixture(
    workOrder,
    sourceExperimentPlan: plan,
  );
  final campaign = _withInputReportSourceChecksFixture(
    EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [followUp],
      modelClassExecutionCoverages: [coverage],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    ),
  );
  final matrix = _withInputReportSourceChecksFixture(
    EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [followUp],
      generatedAt: DateTime.utc(2026, 6, 12, 12, 30),
    ),
  );
  final reviewAttestations = _approvedAdversarialReviewAttestations(campaign);
  final ledger = EvalUseCaseTuningDecisionLedger.build(
    matrix: matrix,
    campaign: campaign,
    reviewAttestations: reviewAttestations,
    requireMatrixSourceReplay: false,
    requireCampaignSourceReplay: false,
    generatedAt: DateTime.utc(2026, 6, 12, 13),
  );
  EvalUseCaseTuningDecisionLedger.assertMatchesSources(
    ledger,
    matrix: matrix,
    campaign: campaign,
    reviewAttestations: reviewAttestations,
    requireMatrixSourceReplay: false,
    requireCampaignSourceReplay: false,
  );
  final roadmap = EvalUseCaseTuningRoadmap.build(
    ledgers: [ledger],
    requireDecisionLedgerSourceReplay: true,
    generatedAt: DateTime.utc(2026, 6, 12, 15),
  );
  EvalUseCaseTuningRoadmap.assertMatchesDecisionLedgers(
    roadmap,
    ledgers: [ledger],
    requireDecisionLedgerSourceReplay: true,
  );
  final releasePlan = EvalUseCaseTuningReleasePlan.build(
    roadmap: roadmap,
    sourceDecisionLedgers: [ledger],
    requireDecisionLedgerSourceReplay: true,
    generatedAt: DateTime.utc(2026, 6, 12, 16),
  );
  EvalUseCaseTuningReleasePlan.assertMatchesSources(
    releasePlan,
    roadmap: roadmap,
    sourceDecisionLedgers: [ledger],
    requireDecisionLedgerSourceReplay: true,
  );
  return DecisionLedgerSourceBoundReleaseFixture(
    ledger: ledger,
    roadmap: roadmap,
    releasePlan: releasePlan,
  );
}

Map<String, dynamic> buildReleaseDecisionLedgerFixture(
  Map<String, dynamic> decision,
) {
  final decisions = [decision];
  final blockedReasonCodes = stringListFixture(decision['blockerCodes']);
  final ledger = <String, dynamic>{
    'schemaVersion': EvalUseCaseTuningDecisionLedger.schemaVersion,
    'kind': EvalUseCaseTuningDecisionLedger.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 13).toIso8601String(),
    'status': _ledgerStatus(decision),
    'sourceMatrix': <String, dynamic>{
      'kind': EvalUseCaseTuningMatrix.kind,
      'schemaVersion': EvalUseCaseTuningMatrix.schemaVersion,
      'status': 'ready',
      'matrixDigest': digestFixture('matrix-${decision['scopeKey']}'),
      'contractIssueCount': 0,
      'inputReportDigestCount': 1,
      'sourceCheckedInputReportDigestCount': 1,
    },
    'sourceCampaign': <String, dynamic>{
      'present': true,
      'kind': EvalUseCaseTuningCampaign.kind,
      'schemaVersion': EvalUseCaseTuningCampaign.schemaVersion,
      'status': 'ready',
      'campaignRef': digestFixture('campaign-ref-${decision['scopeKey']}'),
      'campaignDigest': digestFixture('campaign-${decision['scopeKey']}'),
      'contractIssueCount': 0,
      'readyReportDigestCount': 1,
      'sourceCheckedReadyReportDigestCount': 1,
      'readyModelClassCoverageDigestCount': 1,
      'missingReadyReportDigestCount': 0,
    },
    'summary': <String, dynamic>{
      'decisionCount': decisions.length,
      'acceptedDecisionCount': _decisionCount(decisions, 'accepted'),
      'conflictDecisionCount': _decisionCount(decisions, 'conflict'),
      'watchDecisionCount': _decisionCount(decisions, 'watch'),
      'blockedDecisionCount': _decisionCount(decisions, 'blocked'),
      'previousAcceptedDecisionCount': 0,
      'rollbackRequiredCount': 0,
      'reviewRequirementCount': 0,
      'missingReviewAttestationCount': 0,
      'blockedReasonCount': blockedReasonCodes.length,
    },
    'privacy': const <String, dynamic>{
      'scenarioIdsOmitted': true,
      'rawRunIdsOmitted': true,
      'profileNamesOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
      'promotionClaimsRequireSourceEvidence': true,
    },
    'limitations': const <String, dynamic>{
      'consumesMatrixCampaignAndAttestationsOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'liveCommandsCreated': false,
    },
    'blockedReasonCodes': blockedReasonCodes,
    'reviewGate': const <String, dynamic>{
      'approved': true,
      'requiredReviewCount': 0,
      'attestationCount': 0,
      'missingRequirementCount': 0,
      'requirements': <dynamic>[],
      'missingRequirements': <dynamic>[],
      'approvedAttestationEvidence': <dynamic>[],
    },
    'matrixRefreshEvidence': const <String, dynamic>{
      'readyCampaignReportDigestCount': 1,
      'matrixReportDigestCount': 1,
      'missingReadyReportDigestCount': 0,
      'missingReadyReportDigests': <String>[],
    },
    'decisions': decisions,
    'previousDecisionContinuity': const <dynamic>[],
    'issues': const <dynamic>[],
    'recommendedCommands': const [
      <String, dynamic>{
        'mode': 'decision-gate',
        'command': 'eval/run_level2.sh decision-gate',
      },
    ],
  };
  ledger['decisionLedgerRef'] =
      EvalUseCaseTuningDecisionLedger.decisionLedgerRef(ledger);
  final issues = EvalUseCaseTuningDecisionLedger.validate(ledger);
  if (issues.isNotEmpty) {
    throw StateError('Invalid decision ledger fixture:\n${issues.join('\n')}');
  }
  return ledger;
}

List<Map<String, dynamic>> releaseReviewPacketTemplates(
  Map<String, dynamic> releasePlan,
) {
  final packet = EvalUseCaseTuningReleaseReview.buildPacket(
    releasePlan: releasePlan,
    generatedAt: DateTime.utc(2026, 6, 12, 17),
  );
  return (packet['attestationTemplates'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
}

List<Map<String, dynamic>> approvedReleaseReviewAttestations(
  Map<String, dynamic> releasePlan,
) {
  return [
    for (final template in releaseReviewPacketTemplates(releasePlan))
      _approvedReleaseReviewAttestation(template),
  ];
}

Map<String, dynamic> _approvedReleaseReviewAttestation(
  Map<String, dynamic> template,
) {
  final attestation = <String, dynamic>{
    ...template,
    'status': 'approved',
    'reviewerRefDigest': EvalProvenance.digestText('release-reviewer'),
    'reviewedAt': DateTime.utc(2026, 6, 12, 17, 30).toIso8601String(),
  };
  return <String, dynamic>{
    ...attestation,
    'evidenceDigest': releaseReviewEvidenceDigest(
      attestation,
      status: 'approved',
    ),
  };
}

String releaseReviewEvidenceDigest(
  Map<String, dynamic> attestation, {
  required String status,
}) => EvalUseCaseTuningReleaseReview.attestationEvidenceDigest(
  {...attestation, 'status': status},
);

Map<String, dynamic> buildReleaseReviewBundleFixture({
  required Map<String, dynamic> releasePlan,
  bool approved = true,
}) {
  final attestations = [
    for (final attestation in approvedReleaseReviewAttestations(releasePlan))
      if (approved)
        attestation
      else
        releaseReviewAttestationWithStatus(
          attestation,
          attestation['category'] == 'privacyAudit'
              ? 'needsChanges'
              : 'rejected',
        ),
  ];
  return EvalUseCaseTuningReleaseReview.buildAttestationBundle(
    releasePlan: releasePlan,
    attestations: attestations,
    generatedAt: DateTime.utc(2026, 6, 12, 18),
  );
}

Map<String, dynamic> restampReleasePlanAssignmentProofFixture(
  Map<String, dynamic> releasePlan, {
  required String modelClassCoverageRef,
}) {
  final forged = jsonDecode(jsonEncode(releasePlan)) as Map<String, dynamic>;
  final sourceRoadmapDigest = _stringValue(
    _mapValueFixture(forged['sourceRoadmap'])['roadmapDigest'],
  );
  final assignment =
      (forged['runtimeAssignments'] as List<dynamic>).single
            as Map<String, dynamic>
        ..['modelClassCoverageRef'] = modelClassCoverageRef;
  final assignmentRef = EvalProvenance.digestJson(
    _releaseAssignmentDigestSubject(
      assignment,
      sourceRoadmapDigest: sourceRoadmapDigest,
    ),
  );
  assignment
    ..['assignmentRef'] = assignmentRef
    ..['evidenceDigest'] = assignmentRef;

  final proofSummary =
      forged['modelClassCoverageProofSummary'] as Map<String, dynamic>;
  final proofEntries = [
    for (final entry in _mapListFixture(forged['runtimeAssignments']))
      _releaseAssignmentProofSummary(entry),
  ];
  final proofSummaryDigest = EvalProvenance.digestJson(proofEntries);
  proofSummary
    ..['status'] = proofEntries.isEmpty ? 'empty' : 'ready'
    ..['assignmentCount'] = proofEntries.length
    ..['proofSummaryDigest'] = proofSummaryDigest
    ..['entries'] = proofEntries;

  _restampReleaseReviewQueueFixture(
    forged['releaseReviewQueue'] as Map<String, dynamic>,
    sourceRoadmapDigest: sourceRoadmapDigest,
    assignmentRefs: [assignmentRef],
    proofSummaryDigest: proofSummaryDigest,
    proofSummaryCount: proofEntries.length,
  );
  forged['releasePlanRef'] = EvalUseCaseTuningReleasePlan.releasePlanRef(
    forged,
  );
  return forged;
}

void markRuntimeRolloutLedgerSourcesFixture(
  List<Map<String, dynamic>> runtimeRolloutLedgers, {
  required Map<String, dynamic> previousPlan,
  required List<Map<String, dynamic>> previousRuntimeRolloutLedgers,
  required List<Map<String, dynamic>> releaseGates,
  required List<Map<String, dynamic>> releaseReviewBundles,
  required List<Map<String, dynamic>> runtimeVerifications,
  required List<Map<String, dynamic>> runtimeResolverSnapshots,
  required List<Map<String, dynamic>> runtimeResolverPackets,
  required List<Map<String, dynamic>> runtimeLocatorPackets,
  required List<List<Map<String, dynamic>>> completedBindingSources,
  required List<Map<String, dynamic>> directObservationSources,
  required List<Map<String, dynamic>> privateRuntimeStates,
  Map<String, dynamic>? sourceRoadmap,
  List<Map<String, dynamic>> sourceDecisionLedgers = const [],
}) {
  final verificationByDigest = _artifactsByDigestFixture(
    runtimeVerifications,
    'runtime verification',
  );
  final snapshotByDigest = _artifactsByDigestFixture(
    runtimeResolverSnapshots,
    'runtime resolver snapshot',
  );
  final resolverPacketByDigest = _artifactsByDigestFixture(
    runtimeResolverPackets,
    'runtime resolver packet',
  );
  final locatorPacketByDigest = _artifactsByDigestFixture(
    runtimeLocatorPackets,
    'runtime locator packet',
  );
  final runtimeLedgerByDigest = _artifactsByDigestFixture(
    [
      ...runtimeRolloutLedgers,
      ...previousRuntimeRolloutLedgers,
    ],
    'runtime rollout ledger',
  );
  final visitedLedgerDigests = <String>{};
  final visitingLedgerDigests = <String>{};

  for (final ledger in runtimeRolloutLedgers) {
    _markRuntimeRolloutLedgerSourceFixture(
      ledger,
      previousPlan: previousPlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      releaseGates: releaseGates,
      releaseReviewBundles: releaseReviewBundles,
      verificationByDigest: verificationByDigest,
      snapshotByDigest: snapshotByDigest,
      resolverPacketByDigest: resolverPacketByDigest,
      locatorPacketByDigest: locatorPacketByDigest,
      runtimeLedgerByDigest: runtimeLedgerByDigest,
      completedBindingSources: completedBindingSources,
      directObservationSources: directObservationSources,
      privateRuntimeStates: privateRuntimeStates,
      visitedLedgerDigests: visitedLedgerDigests,
      visitingLedgerDigests: visitingLedgerDigests,
    );
  }
}

Future<ReleasePlanSourceInputsFixture> readReleasePlanSourceInputsFixture({
  required String roadmapInputPath,
  required String decisionLedgerPaths,
  required String decisionLedgerSourceManifestPaths,
  required String previousReleasePlanPath,
  required String runtimeRolloutLedgerPaths,
  required String runtimePreviousRolloutLedgerPaths,
  required String runtimeLedgerReleaseGatePaths,
  required String runtimeLedgerReleaseReviewAttestations,
  required String runtimeVerificationPaths,
  required String runtimeLedgerResolverSnapshotPaths,
  required String runtimeLedgerResolverPacketPaths,
  required String runtimeLedgerLocatorPacketPaths,
  required String runtimeLedgerResolverInputPaths,
  required String runtimeLedgerDirectObservationPaths,
  required String runtimeLedgerStateInputPaths,
  String previousReleasePlanEnvName =
      'EVAL_USE_CASE_RUNTIME_RESOLVER_PREVIOUS_RELEASE_PLAN',
  String runtimeRolloutLedgersEnvName =
      'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_ROLLOUT_LEDGERS',
  EvalTuningSourceReplayConfig? sourceReplayConfig,
}) async {
  final previousReleasePlan = _readOptionalJsonMapFixture(
    previousReleasePlanPath,
  );
  final roadmap = _readOptionalJsonMapFixture(roadmapInputPath);
  final sourceDecisionLedgers = _readJsonListOrEmptyFixture(
    decisionLedgerPaths,
  );
  final decisionLedgers = decisionLedgerSourceManifestPaths.trim().isEmpty
      ? sourceDecisionLedgers
      : await evalReplayDecisionLedgerSourceManifests(
          ledgers: sourceDecisionLedgers,
          manifests: evalReadDecisionLedgerSourceManifestFiles(
            decisionLedgerSourceManifestPaths,
          ),
          config:
              sourceReplayConfig ??
              (throw StateError(
                'sourceReplayConfig is required when replaying decision '
                'ledger source manifests.',
              )),
        );
  if (previousReleasePlan != null && roadmap != null) {
    EvalUseCaseTuningReleasePlan.assertMatchesSources(
      previousReleasePlan,
      roadmap: roadmap,
      sourceDecisionLedgers: decisionLedgers,
      requireDecisionLedgerSourceReplay: decisionLedgerSourceManifestPaths
          .trim()
          .isNotEmpty,
    );
  }
  final runtimeRolloutLedgers = _readJsonListOrEmptyFixture(
    runtimeRolloutLedgerPaths,
  );
  if (runtimeRolloutLedgers.isNotEmpty) {
    final previousPlan = previousReleasePlan;
    if (previousPlan == null) {
      throw StateError(
        '$previousReleasePlanEnvName is required with '
        '$runtimeRolloutLedgersEnvName.',
      );
    }
    markRuntimeRolloutLedgerSourcesFixture(
      runtimeRolloutLedgers,
      previousPlan: previousPlan,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: decisionLedgers,
      previousRuntimeRolloutLedgers: _readJsonListOrEmptyFixture(
        runtimePreviousRolloutLedgerPaths,
      ),
      releaseGates: _readJsonListOrEmptyFixture(
        runtimeLedgerReleaseGatePaths,
      ),
      releaseReviewBundles: readReleaseReviewBundlesFixture(
        runtimeLedgerReleaseReviewAttestations,
      ),
      runtimeVerifications: _readJsonListOrEmptyFixture(
        runtimeVerificationPaths,
      ),
      runtimeResolverSnapshots: _readJsonListOrEmptyFixture(
        runtimeLedgerResolverSnapshotPaths,
      ),
      runtimeResolverPackets: _readJsonListOrEmptyFixture(
        runtimeLedgerResolverPacketPaths,
      ),
      runtimeLocatorPackets: _readJsonListOrEmptyFixture(
        runtimeLedgerLocatorPacketPaths,
      ),
      completedBindingSources: source_replay.readCompletedBindingSources(
        runtimeLedgerResolverInputPaths,
      ),
      directObservationSources: source_replay.readDirectObservationSources(
        runtimeLedgerDirectObservationPaths,
      ),
      privateRuntimeStates: source_replay.readJsonObjects(
        runtimeLedgerStateInputPaths,
      ),
    );
  }
  return ReleasePlanSourceInputsFixture(
    roadmap: roadmap,
    decisionLedgers: decisionLedgers,
    previousReleasePlan: previousReleasePlan,
    runtimeRolloutLedgers: runtimeRolloutLedgers,
  );
}

List<Map<String, dynamic>> readReleaseReviewBundlesFixture(String paths) {
  return [
    for (final path in paths.split(','))
      if (path.trim().isNotEmpty)
        ..._readReleaseReviewBundleFileFixture(path.trim()),
  ];
}

Map<String, dynamic>? _readOptionalJsonMapFixture(String path) {
  if (path.trim().isEmpty) {
    return null;
  }
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw StateError('Expected release plan source JSON object.');
}

List<Map<String, dynamic>> _readJsonListOrEmptyFixture(String paths) {
  if (paths.trim().isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  return [
    for (final path in paths.split(','))
      if (path.trim().isNotEmpty) ..._readJsonListFixture(path.trim()),
  ];
}

List<Map<String, dynamic>> _readJsonListFixture(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is List) {
    return [for (final item in decoded) item as Map<String, dynamic>];
  }
  if (decoded is Map<String, dynamic>) {
    return [decoded];
  }
  throw StateError('Expected release plan source JSON object or list.');
}

final class ReleasePlanSourceInputsFixture {
  const ReleasePlanSourceInputsFixture({
    required this.roadmap,
    required this.decisionLedgers,
    required this.previousReleasePlan,
    required this.runtimeRolloutLedgers,
  });

  final Map<String, dynamic>? roadmap;
  final List<Map<String, dynamic>> decisionLedgers;
  final Map<String, dynamic>? previousReleasePlan;
  final List<Map<String, dynamic>> runtimeRolloutLedgers;
}

Map<String, dynamic> releaseGateWithTamperedApprovedRefs({
  required Map<String, dynamic> gate,
  required List<String> approvedAssignmentRefs,
  bool rewriteSourceAssignmentRefsDigest = false,
}) {
  final tampered = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;
  tampered['approvedAssignmentRefs'] = approvedAssignmentRefs;
  (tampered['summary'] as Map<String, dynamic>)['approvedAssignmentRefCount'] =
      approvedAssignmentRefs.length;
  if (rewriteSourceAssignmentRefsDigest) {
    (tampered['sourceReleasePlan']
            as Map<String, dynamic>)['assignmentRefsDigest'] =
        EvalProvenance.digestJson(approvedAssignmentRefs);
  }
  tampered['releaseGateRef'] = releaseGateRefFixture(tampered);
  return tampered;
}

Map<String, dynamic> releaseGateWithTamperedSourceBundle({
  required Map<String, dynamic> gate,
  String? sourceReleaseReviewPacketRef,
  String? sourceQueueDigest,
  String? approvedReviewTaskDigestsDigest,
}) {
  final tampered = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;
  final sourceBundle =
      (tampered['sourceReviewBundles'] as List<dynamic>).single
          as Map<String, dynamic>;
  if (sourceReleaseReviewPacketRef != null) {
    sourceBundle['sourceReleaseReviewPacketRef'] = sourceReleaseReviewPacketRef;
  }
  if (sourceQueueDigest != null) {
    sourceBundle['sourceQueueDigest'] = sourceQueueDigest;
  }
  if (approvedReviewTaskDigestsDigest != null) {
    sourceBundle['approvedReviewTaskDigestsDigest'] =
        approvedReviewTaskDigestsDigest;
  }
  tampered['releaseGateRef'] = releaseGateRefFixture(tampered);
  return tampered;
}

String releaseGateRefFixture(Map<String, dynamic> gate) {
  final sourcePlan = gate['sourceReleasePlan'] as Map<String, dynamic>;
  final releaseGate = gate['releaseGate'] as Map<String, dynamic>;
  final summary = gate['summary'] as Map<String, dynamic>;
  final sourceReviewBundles = (gate['sourceReviewBundles'] as List)
      .whereType<Map<String, dynamic>>()
      .toList();
  final approvedAssignmentRefs = (gate['approvedAssignmentRefs'] as List)
      .whereType<String>()
      .toList();
  return EvalProvenance.digestJson(<String, dynamic>{
    'kind': EvalUseCaseTuningReleaseGate.kind,
    'schemaVersion': EvalUseCaseTuningReleaseGate.schemaVersion,
    'sourceReleasePlanDigest': sourcePlan['releasePlanDigest'],
    'sourceQueueDigest': sourcePlan['sourceQueueDigest'],
    'assignmentRefsDigest': sourcePlan['assignmentRefsDigest'],
    'approvedReviewKeys': (releaseGate['approvedReviewKeys'] as List)
        .whereType<String>()
        .toList(),
    'sourceReviewBundlesDigest': EvalProvenance.digestJson(
      sourceReviewBundles,
    ),
    'summaryDigest': EvalProvenance.digestJson(summary),
    'approvedAssignmentRefsDigest': EvalProvenance.digestJson(
      approvedAssignmentRefs,
    ),
    'modelClassCoverageProofSummaryDigest':
        sourcePlan['modelClassCoverageProofSummaryDigest'],
    'approved': releaseGate['approved'] == true,
  });
}

Map<String, dynamic> releaseReviewAttestationWithStatus(
  Map<String, dynamic> attestation,
  String status,
) => <String, dynamic>{
  ...attestation,
  'status': status,
  'evidenceDigest': releaseReviewEvidenceDigest(
    attestation,
    status: status,
  ),
};

String differentReleaseReviewCategory(String category) =>
    category == 'privacyAudit' ? 'runtimeBindingAudit' : 'privacyAudit';

String sourceRoadmapDigestFixture(Map<String, dynamic> releasePlan) =>
    (releasePlan['sourceRoadmap'] as Map<String, dynamic>)['roadmapDigest']
        as String;

String scopeKeyFixture({
  required String compatibilityKey,
  required String primaryCapabilityId,
  required String agentKind,
}) => EvalProvenance.digestJson(<String, dynamic>{
  'compatibilityKey': compatibilityKey,
  'primaryCapabilityId': primaryCapabilityId,
  'agentKind': agentKind,
});

String digestFixture(String value) => EvalProvenance.digestText(value);

List<String> stringListFixture(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      ]
    : const <String>[];

void _markRuntimeRolloutLedgerSourceFixture(
  Map<String, dynamic> ledger, {
  required Map<String, dynamic> previousPlan,
  required List<Map<String, dynamic>> releaseGates,
  required List<Map<String, dynamic>> releaseReviewBundles,
  required Map<String, Map<String, dynamic>> verificationByDigest,
  required Map<String, Map<String, dynamic>> snapshotByDigest,
  required Map<String, Map<String, dynamic>> resolverPacketByDigest,
  required Map<String, Map<String, dynamic>> locatorPacketByDigest,
  required Map<String, Map<String, dynamic>> runtimeLedgerByDigest,
  required List<List<Map<String, dynamic>>> completedBindingSources,
  required List<Map<String, dynamic>> directObservationSources,
  required List<Map<String, dynamic>> privateRuntimeStates,
  required Set<String> visitedLedgerDigests,
  required Set<String> visitingLedgerDigests,
  Map<String, dynamic>? sourceRoadmap,
  List<Map<String, dynamic>> sourceDecisionLedgers = const [],
}) {
  final ledgerDigest = EvalProvenance.digestJson(ledger);
  if (visitedLedgerDigests.contains(ledgerDigest)) return;
  if (!visitingLedgerDigests.add(ledgerDigest)) {
    throw StateError('Runtime rollout ledger previous-ledger cycle detected.');
  }

  Map<String, dynamic>? previousLedger;
  final sourcePreviousLedger = _mapValueFixture(ledger['sourcePreviousLedger']);
  if (sourcePreviousLedger.isNotEmpty) {
    final previousLedgerDigest = _requiredStringFixture(
      sourcePreviousLedger,
      'ledgerDigest',
      'runtime rollout previous ledger digest',
    );
    previousLedger = runtimeLedgerByDigest[previousLedgerDigest];
    if (previousLedger == null) {
      throw StateError(
        'Missing runtime rollout previous ledger source artifact: '
        '$previousLedgerDigest.',
      );
    }
    _markRuntimeRolloutLedgerSourceFixture(
      previousLedger,
      previousPlan: previousPlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      releaseGates: releaseGates,
      releaseReviewBundles: releaseReviewBundles,
      verificationByDigest: verificationByDigest,
      snapshotByDigest: snapshotByDigest,
      resolverPacketByDigest: resolverPacketByDigest,
      locatorPacketByDigest: locatorPacketByDigest,
      runtimeLedgerByDigest: runtimeLedgerByDigest,
      completedBindingSources: completedBindingSources,
      directObservationSources: directObservationSources,
      privateRuntimeStates: privateRuntimeStates,
      visitedLedgerDigests: visitedLedgerDigests,
      visitingLedgerDigests: visitingLedgerDigests,
    );
  }

  final releaseGate = _releaseGateForRuntimeLedgerFixture(
    ledger,
    releaseGates,
  );
  final ledgerVerifications = _sourceArtifactsForDigestsFixture(
    verificationByDigest,
    [
      for (final source in _mapListFixture(
        ledger['runtimeVerificationSources'],
      ))
        _requiredStringFixture(
          source,
          'runtimeVerificationDigest',
          'runtime verification source digest',
        ),
    ],
    'runtime verification',
  );
  final ledgerSnapshots = _sourceArtifactsForDigestsFixture(
    snapshotByDigest,
    [
      for (final source in _mapListFixture(
        ledger['runtimeResolverSnapshotSources'],
      ))
        _requiredStringFixture(
          source,
          'runtimeResolverSnapshotDigest',
          'runtime resolver snapshot source digest',
        ),
    ],
    'runtime resolver snapshot',
  );
  final ledgerResolverPackets = _sourceArtifactsForDigestsFixture(
    resolverPacketByDigest,
    [
      for (final snapshot in ledgerSnapshots)
        _requiredStringFixture(
          _mapValueFixture(snapshot['runtimeObservationSource']),
          'sourceResolverPacketDigest',
          'runtime resolver packet source digest',
        ),
    ],
    'runtime resolver packet',
  );
  final ledgerLocatorPackets = _sourceArtifactsForDigestsFixture(
    locatorPacketByDigest,
    [
      for (final snapshot in ledgerSnapshots)
        _stringValue(
          _mapValueFixture(
            snapshot['runtimeObservationSource'],
          )['sourceLocatorPacketDigest'],
        ),
    ],
    'runtime locator packet',
  );

  for (final resolverPacket in ledgerResolverPackets) {
    EvalUseCaseRuntimeResolverSnapshot.assertPacketMatchesSources(
      resolverPacket,
      releasePlan: previousPlan,
      releaseGate: releaseGate,
      releaseReviewBundles: releaseReviewBundles,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
    );
  }
  source_replay.assertRuntimeResolverSnapshotsMatchSources(
    ledgerSnapshots,
    releasePlan: previousPlan,
    releaseGate: releaseGate,
    resolverPackets: ledgerResolverPackets,
    locatorPackets: ledgerLocatorPackets,
    completedBindingSources: completedBindingSources,
    directObservationSources: directObservationSources,
    privateRuntimeStates: privateRuntimeStates,
  );
  EvalUseCaseRuntimeRolloutLedger.assertMatchesSources(
    ledger,
    releasePlan: previousPlan,
    releaseGate: releaseGate,
    runtimeVerifications: ledgerVerifications,
    runtimeResolverSnapshots: ledgerSnapshots,
    runtimeResolverPackets: ledgerResolverPackets,
    runtimeLocatorPackets: ledgerLocatorPackets,
    releaseReviewBundles: releaseReviewBundles,
    sourceRoadmap: sourceRoadmap,
    sourceDecisionLedgers: sourceDecisionLedgers,
    previousLedger: previousLedger,
  );
  visitingLedgerDigests.remove(ledgerDigest);
  visitedLedgerDigests.add(ledgerDigest);
}

void _restampReleaseReviewQueueFixture(
  Map<String, dynamic> queue, {
  required String sourceRoadmapDigest,
  required List<String> assignmentRefs,
  required String proofSummaryDigest,
  required int proofSummaryCount,
}) {
  queue
    ..['sourceRoadmapDigest'] = sourceRoadmapDigest
    ..['assignmentRefCount'] = assignmentRefs.length
    ..['assignmentProofSummaryCount'] = proofSummaryCount
    ..['assignmentProofSummaryDigest'] = proofSummaryDigest
    ..['modelClassCoverageProofSummaryDigest'] = proofSummaryDigest;
  for (final task in _mapListFixture(queue['tasks'])) {
    final category = _stringValue(task['category']);
    task
      ..['sourceRoadmapDigest'] = sourceRoadmapDigest
      ..['assignmentRefs'] = assignmentRefs
      ..['assignmentProofSummaryDigest'] = proofSummaryDigest
      ..['modelClassCoverageProofSummaryDigest'] = proofSummaryDigest
      ..['reviewRef'] = EvalProvenance.digestJson(<String, dynamic>{
        'sourceRoadmapDigest': sourceRoadmapDigest,
        'category': category,
        'assignmentRefs': assignmentRefs,
        'assignmentProofSummaryDigest': proofSummaryDigest,
        'modelClassCoverageProofSummaryDigest': proofSummaryDigest,
      });
  }
  for (final template in _mapListFixture(queue['attestationTemplates'])) {
    final category = _stringValue(template['category']);
    template
      ..['sourceRoadmapDigest'] = sourceRoadmapDigest
      ..['assignmentProofSummaryDigest'] = proofSummaryDigest
      ..['modelClassCoverageProofSummaryDigest'] = proofSummaryDigest
      ..['reviewRef'] = EvalProvenance.digestJson(<String, dynamic>{
        'sourceRoadmapDigest': sourceRoadmapDigest,
        'category': category,
        'assignmentRefs': assignmentRefs,
        'assignmentProofSummaryDigest': proofSummaryDigest,
        'modelClassCoverageProofSummaryDigest': proofSummaryDigest,
      });
  }
}

Map<String, dynamic> _releaseAssignmentDigestSubject(
  Map<String, dynamic> assignment, {
  required String sourceRoadmapDigest,
}) => <String, dynamic>{
  'sourceRoadmapDigest': sourceRoadmapDigest,
  'scopeKey': _stringValue(assignment['scopeKey']),
  'acceptedCellKey': _stringValue(assignment['acceptedCellKey']),
  'reportDigest': _stringValue(assignment['reportDigest']),
  'modelClassCoverageProofRef': _stringValue(
    assignment['modelClassCoverageProofRef'],
  ),
  'workOrderBatchRef': _stringValue(assignment['workOrderBatchRef']),
  'modelClassCoverageRef': _stringValue(assignment['modelClassCoverageRef']),
  'modelClassCoverageClassRef': _stringValue(
    assignment['modelClassCoverageClassRef'],
  ),
  'modelClassCoverageDigest': _stringValue(
    assignment['modelClassCoverageDigest'],
  ),
  'sourceWorkOrderDigest': _stringValue(assignment['sourceWorkOrderDigest']),
  'modelClass': _stringValue(assignment['modelClass']),
  'promptVariantName': _stringValue(assignment['promptVariantName']),
};

Map<String, dynamic> _releaseAssignmentProofSummary(
  Map<String, dynamic> assignment,
) => <String, dynamic>{
  'assignmentRef': _stringValue(assignment['assignmentRef']),
  'scopeKey': _stringValue(assignment['scopeKey']),
  'primaryCapabilityId': _stringValue(assignment['primaryCapabilityId']),
  'agentKind': _stringValue(assignment['agentKind']),
  'modelClass': _stringValue(assignment['modelClass']),
  'promptVariantName': _stringValue(assignment['promptVariantName']),
  'acceptedCellKey': _stringValue(assignment['acceptedCellKey']),
  'reportDigest': _stringValue(assignment['reportDigest']),
  'modelClassCoverageProofRef': _stringValue(
    assignment['modelClassCoverageProofRef'],
  ),
  'workOrderBatchRef': _stringValue(assignment['workOrderBatchRef']),
  'modelClassCoverageRef': _stringValue(assignment['modelClassCoverageRef']),
  'modelClassCoverageClassRef': _stringValue(
    assignment['modelClassCoverageClassRef'],
  ),
  'modelClassCoverageDigest': _stringValue(
    assignment['modelClassCoverageDigest'],
  ),
  'sourceWorkOrderDigest': _stringValue(assignment['sourceWorkOrderDigest']),
};

Map<String, dynamic> _modelClassCoverageForWorkOrderFixture(
  Map<String, dynamic> workOrder, {
  required Map<String, dynamic> sourceExperimentPlan,
}) {
  final runs = [
    for (final batch in _mapListFixture(workOrder['runBatches']))
      _modelClassExecutionRunFixture(workOrder: workOrder, batch: batch),
  ];
  final evidenceBundle = EvalUseCaseModelClassExecutionEvidence.build(
    workOrder: workOrder,
    runs: runs,
    sourceExperimentPlan: sourceExperimentPlan,
    generatedAt: DateTime.utc(2026, 6, 12, 11, 40),
  );
  final coverage = EvalUseCaseModelClassExecutionCoverage.build(
    workOrder: workOrder,
    sourceExecutionEvidenceBundles: [evidenceBundle],
    sourceCheckProof:
        EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources(
          workOrder: workOrder,
          sourceExecutionEvidenceBundles: [evidenceBundle],
          runs: runs,
          sourceExperimentPlan: sourceExperimentPlan,
        ),
    generatedAt: DateTime.utc(2026, 6, 12, 11, 45),
  );
  EvalUseCaseModelClassExecutionCoverage.assertMatchesSources(
    coverage,
    workOrder: workOrder,
    sourceExecutionEvidenceBundles: [evidenceBundle],
    runs: runs,
    sourceExperimentPlan: sourceExperimentPlan,
  );
  return coverage;
}

EvalUseCaseModelClassExecutionRun _modelClassExecutionRunFixture({
  required Map<String, dynamic> workOrder,
  required Map<String, dynamic> batch,
}) {
  final capabilityIds = _batchCapabilityIdsFixture(batch);
  final scenario = EvalScenario(
    id: 'private-release-source-scenario',
    title: 'Private release source scenario',
    agentKind: _agentKindForCapabilityFixture(capabilityIds.first),
    appState: MockedAppState(now: DateTime(2026, 6, 12, 11)),
    userInput: const UserInput(
      transcript: 'Arrange the release source task list',
      triggerTokens: {'trigger:task'},
    ),
    metadata: EvalScenarioMetadata(capabilityIds: capabilityIds.toList()),
  );
  final profiles = [
    for (final modelClass in EvalModelClass.values)
      _profileFixture(modelClass, trialCount: 1),
  ];
  final readinessContractEvidence =
      EvalProvenance.tuningReadinessContractEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest([scenario]),
        requiredPrimaryCapabilityIds: capabilityIds,
      );
  final manifest = EvalProvenance.captureRunManifest(
    runId:
        'private-release-model-class-${_stringValue(batch['workOrderBatchRef'])}',
    targetName: 'release source fixture target',
    targetKind: 'fixture',
    scenarios: [scenario],
    profiles: profiles,
    createdAt: DateTime.utc(2026, 6, 12, 11, 35),
    command: 'eval/run_level2.sh run private-release-model-class',
    environment: const {},
    tuningReadinessContractEvidence: readinessContractEvidence,
    useCaseWorkOrderLaunchEvidence:
        EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
          workOrder: workOrder,
          requiredPrimaryCapabilityIds: capabilityIds,
          promptVariantNames: _batchPromptVariantNamesFixture(batch),
          workOrderBatchRefs: [_stringValue(batch['workOrderBatchRef'])],
        ),
  );
  final traces = [
    for (final profile in profiles)
      _traceFixture(manifest: manifest, scenario: scenario, profile: profile),
  ];
  return EvalUseCaseModelClassExecutionRun(
    artifacts: EvalRunArtifacts(
      manifest: manifest,
      traces: traces,
      artifactNames: const ['manifest.json'],
    ),
    scenarios: [scenario],
    profiles: profiles,
  );
}

EvalProfile _profileFixture(
  EvalModelClass modelClass, {
  required int trialCount,
}) {
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

EvalTrace _traceFixture({
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

Set<String> _batchCapabilityIdsFixture(Map<String, dynamic> batch) {
  final values = _csvFixture(
    _stringValue(
      _mapValueFixture(batch['publicEnv'])['EVAL_REQUIRED_CAPABILITIES'],
    ),
  ).toSet();
  return values.isEmpty ? {'task.workflow'} : values;
}

List<String> _batchPromptVariantNamesFixture(Map<String, dynamic> batch) {
  final values = _csvFixture(
    _stringValue(
      _mapValueFixture(batch['publicEnv'])['EVAL_PROMPT_VARIANT_NAMES'],
    ),
  );
  return values.isEmpty ? ['default'] : values;
}

AgentKind _agentKindForCapabilityFixture(String capabilityId) {
  return capabilityId.startsWith('planner.')
      ? AgentKind.planningAgent
      : AgentKind.taskAgent;
}

List<Map<String, dynamic>> _approvedAdversarialReviewAttestations(
  Map<String, dynamic> campaign,
) {
  final packet = EvalUseCaseAdversarialReview.buildPacket(
    campaign: campaign,
    generatedAt: DateTime.utc(2026, 6, 12, 12, 30),
  );
  final templates = _mapListFixture(packet['attestationTemplates']);
  final approved = [
    for (final template in templates)
      _stampedAdversarialReviewAttestation(<String, dynamic>{
        ...template,
        'status': 'approved',
        'reviewerRefDigest': EvalProvenance.digestText('adversarial-reviewer'),
        'reviewedAt': DateTime.utc(2026, 6, 12, 12, 45).toIso8601String(),
      }),
  ];
  final bundle = EvalUseCaseAdversarialReview.buildAttestationBundle(
    campaign: campaign,
    attestations: approved,
    generatedAt: DateTime.utc(2026, 6, 12, 13),
  );
  return EvalUseCaseAdversarialReview.approvedAttestationsFromBundles([
    bundle,
  ]);
}

Map<String, dynamic> _stampedAdversarialReviewAttestation(
  Map<String, dynamic> attestation,
) {
  attestation['evidenceDigest'] =
      EvalUseCaseAdversarialReview.attestationEvidenceDigest(attestation);
  return attestation;
}

Map<String, dynamic> _withInputReportSourceChecksFixture(
  Map<String, dynamic> artifact,
) {
  final copy = jsonDecode(jsonEncode(artifact)) as Map<String, dynamic>;
  for (final report in _mapListFixture(copy['inputReports'])) {
    report['sourceCheckStatus'] = 'sourceChecked';
    report['sourceIssueCount'] = 0;
    report['sourceIssueCodes'] = const <String>[];
  }
  if (copy['kind'] == EvalUseCaseTuningCampaign.kind) {
    copy['campaignRef'] = EvalUseCaseTuningCampaign.campaignRef(copy);
  }
  return copy;
}

Map<String, dynamic> _sourceReplayReport({
  required String runId,
  required String modelClass,
  String? profileName,
  bool ready = false,
  String promotionStatus = 'notRequested',
  String scenarioSetSeed = 'scenario-set',
  String primaryCapabilityId = 'task.workflow',
  String promptVariantName = 'default',
  List<String> requiredCapabilities = const ['task.workflow'],
  List<String> blockingReasonCodes = const ['verdict.missing'],
  double passRateLowerBound = 0.55,
  double passRate = 0.75,
  double meanGoalAttainment = 4,
}) {
  final effectiveModelClass = _fixtureModelClassName(modelClass);
  final effectiveBlockers = ready ? const <String>[] : blockingReasonCodes;
  final effectiveProfileName = profileName ?? 'profile-$effectiveModelClass';
  const policyPayload = <String, dynamic>{
    'name': 'modelClassTuning',
    'minJudgePassRateLowerBound': 0.7,
  };
  final policyDigest = EvalProvenance.digestJson(policyPayload);
  final manifestDigest = digestFixture('manifest-$runId');
  return <String, dynamic>{
    'schemaVersion': EvalTuningReportContract.schemaVersion,
    'kind': EvalTuningReportContract.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 9).toIso8601String(),
    'run': <String, dynamic>{
      'runId': runId,
      'targetKind': 'fixture',
      'manifestDigest': manifestDigest,
      'createdAt': DateTime.utc(2026, 6, 12, 8).toIso8601String(),
      'scenarioSetDigest': digestFixture(scenarioSetSeed),
      'profileSetDigest': digestFixture('profiles-$effectiveModelClass'),
      'profileBindingSetDigest': digestFixture('bindings-$effectiveModelClass'),
      'agentDirectiveVariantSetDigest': digestFixture(
        'prompt-variants-$promptVariantName',
      ),
      'selectors': <String, dynamic>{
        'scenarioIds': ['scenario-$primaryCapabilityId'],
        'profileNames': [effectiveProfileName],
        'promptVariantNames': [promptVariantName],
        'requiredPrimaryCapabilityIds': requiredCapabilities,
      },
      'protectedIdsRedacted': false,
      'artifactSnapshot': <String, dynamic>{
        'artifactCount': 9,
        'traceCount': 4,
        'judgedTraceCount': 4,
        'manifestDigest': manifestDigest,
        'ownedArtifactRefsDigest': digestFixture('owned-$runId'),
        'loadedTraceContentDigest': digestFixture('loaded-$runId'),
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
        'sliceKey':
            '$primaryCapabilityId@taskAgent@$effectiveModelClass@$promptVariantName',
        'primaryCapabilityId': primaryCapabilityId,
        'agentKind': releaseFixtureAgentKind,
        'modelClass': effectiveModelClass,
        'promptVariantName': promptVariantName,
        'scenarioIds': ['scenario-$primaryCapabilityId'],
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
      'requiredCapabilities': requiredCapabilities,
      'suggestedCapabilities': requiredCapabilities,
      'suggestedScenarioIds': ['scenario-$primaryCapabilityId'],
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

String _fixtureModelClassName(String modelClass) => switch (modelClass) {
  'frontier' => EvalModelClass.frontierFast.name,
  'local' => EvalModelClass.localReasoning.name,
  _ => modelClass,
};

List<String> _csvFixture(String value) => [
  for (final part in value.split(',').map((part) => part.trim()))
    if (part.isNotEmpty) part,
];

Map<String, dynamic> _mapValueFixture(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<Map<String, dynamic>> _mapListFixture(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map<String, dynamic>) item,
      ]
    : const <Map<String, dynamic>>[];

String _stringValue(Object? value) => value is String ? value : '';

Map<String, Map<String, dynamic>> _artifactsByDigestFixture(
  List<Map<String, dynamic>> artifacts,
  String description,
) {
  final artifactsByDigest = <String, Map<String, dynamic>>{};
  for (final artifact in artifacts) {
    final digest = EvalProvenance.digestJson(artifact);
    if (artifactsByDigest.containsKey(digest)) {
      throw StateError('Duplicate $description source artifact: $digest.');
    }
    artifactsByDigest[digest] = artifact;
  }
  return artifactsByDigest;
}

Map<String, dynamic> _releaseGateForRuntimeLedgerFixture(
  Map<String, dynamic> ledger,
  List<Map<String, dynamic>> releaseGates,
) {
  final sourceGate = _mapValueFixture(ledger['sourceReleaseGate']);
  final expectedDigest = _requiredStringFixture(
    sourceGate,
    'releaseGateDigest',
    'runtime rollout ledger source release gate digest',
  );
  final expectedRef = _requiredStringFixture(
    sourceGate,
    'releaseGateRef',
    'runtime rollout ledger source release gate ref',
  );
  final matches = [
    for (final gate in releaseGates)
      if (EvalProvenance.digestJson(gate) == expectedDigest &&
          _stringValue(gate['releaseGateRef']) == expectedRef)
        gate,
  ];
  if (matches.length == 1) return matches.single;
  if (matches.isEmpty) {
    throw StateError(
      'Missing runtime rollout ledger source release gate: $expectedDigest.',
    );
  }
  throw StateError(
    'Duplicate runtime rollout ledger source release gate: $expectedDigest.',
  );
}

List<Map<String, dynamic>> _sourceArtifactsForDigestsFixture(
  Map<String, Map<String, dynamic>> artifactsByDigest,
  Iterable<String> digests,
  String description,
) {
  final artifacts = <Map<String, dynamic>>[];
  final seenDigests = <String>{};
  for (final digest in digests) {
    if (digest.isEmpty || !seenDigests.add(digest)) continue;
    final artifact = artifactsByDigest[digest];
    if (artifact == null) {
      throw StateError('Missing $description source artifact: $digest.');
    }
    artifacts.add(artifact);
  }
  return artifacts;
}

String _requiredStringFixture(
  Map<String, dynamic> artifact,
  String key,
  String description,
) {
  final value = _stringValue(artifact[key]);
  if (value.isNotEmpty) return value;
  throw StateError('Missing $description.');
}

List<Map<String, dynamic>> _readReleaseReviewBundleFileFixture(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is List) {
    return [
      for (final item in decoded)
        _releaseReviewBundleObjectFixture(item as Map<String, dynamic>),
    ];
  }
  if (decoded is Map<String, dynamic>) {
    return [_releaseReviewBundleObjectFixture(decoded)];
  }
  throw StateError('Expected release review bundle JSON object or list.');
}

Map<String, dynamic> _releaseReviewBundleObjectFixture(
  Map<String, dynamic> bundle,
) {
  if (bundle['kind'] != EvalUseCaseTuningReleaseReview.bundleKind) {
    throw StateError(
      'Expected a use-case tuning release review attestation bundle.',
    );
  }
  EvalUseCaseTuningReleaseReview.assertValidBundle(bundle);
  return bundle;
}

String _ledgerStatus(Map<String, dynamic> decision) =>
    switch (decision['status']) {
      'accepted' => 'accepted',
      'conflict' => 'conflict',
      'watch' => 'watchOnly',
      _ => 'blocked',
    };

int _decisionCount(List<Map<String, dynamic>> decisions, String status) =>
    decisions.where((decision) => decision['status'] == status).length;

final class ReleaseScopeFixture {
  const ReleaseScopeFixture({
    required this.compatibilitySeed,
    required this.primaryCapabilityId,
    required this.agentKind,
    required this.modelClass,
    required this.promptVariantName,
    required this.cellSeed,
    required this.reportSeed,
  });

  final String compatibilitySeed;
  final String primaryCapabilityId;
  final String agentKind;
  final String modelClass;
  final String promptVariantName;
  final String cellSeed;
  final String reportSeed;

  String get compatibilityKey => digestFixture(compatibilitySeed);

  String get scopeKey => scopeKeyFixture(
    compatibilityKey: compatibilityKey,
    primaryCapabilityId: primaryCapabilityId,
    agentKind: agentKind,
  );

  String get cellKey => digestFixture(cellSeed);

  String get reportDigest => digestFixture(reportSeed);

  Map<String, dynamic> acceptedDecision() => <String, dynamic>{
    'scopeKey': scopeKey,
    'compatibilityKey': compatibilityKey,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'status': 'accepted',
    'candidateCount': 1,
    'promotionCandidateCount': 1,
    'campaignReadyCandidateCount': 1,
    'acceptedCellKey': cellKey,
    'acceptedCandidate': _candidate(
      evidenceStatus: 'promotionReady',
      promotionEvidence: true,
      reportReady: true,
      sourcePromotionStatus: 'promote',
      blockingReasonCodes: const [],
    ),
    'candidates': [
      _candidate(
        evidenceStatus: 'promotionReady',
        promotionEvidence: true,
        reportReady: true,
        sourcePromotionStatus: 'promote',
        blockingReasonCodes: const [],
      ),
    ],
    'blockerCodes': const <String>[],
    'nextAction': 'applyAcceptedUseCaseChoiceAfterReleaseReview',
  };

  Map<String, dynamic> blockedDecision() => <String, dynamic>{
    'scopeKey': scopeKey,
    'compatibilityKey': compatibilityKey,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'status': 'blocked',
    'candidateCount': 1,
    'promotionCandidateCount': 0,
    'campaignReadyCandidateCount': 0,
    'candidates': [
      _candidate(
        evidenceStatus: 'dataDeficient',
        promotionEvidence: false,
        reportReady: false,
        sourcePromotionStatus: 'notRequested',
        blockingReasonCodes: const ['verdict.missing'],
      ),
    ],
    'blockerCodes': const ['verdict.missing'],
    'nextAction': 'continueEvidenceCollection',
  };

  Map<String, dynamic> _candidate({
    required String evidenceStatus,
    required bool promotionEvidence,
    required bool reportReady,
    required String sourcePromotionStatus,
    required List<String> blockingReasonCodes,
  }) => <String, dynamic>{
    'cellKey': cellKey,
    'compatibilityKey': compatibilityKey,
    'sourceReportRef': 'report-$cellSeed',
    'reportDigest': reportDigest,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'modelClass': modelClass,
    'promptVariantName': promptVariantName,
    'evidenceStatus': evidenceStatus,
    'promotionEvidence': promotionEvidence,
    'reportReady': reportReady,
    'sourceChecked':
        promotionEvidence &&
        reportReady &&
        sourcePromotionStatus == 'promote' &&
        blockingReasonCodes.isEmpty,
    'sourcePromotionStatus': sourcePromotionStatus,
    'recommendation': promotionEvidence ? 'keep' : 'gradeVerdicts',
    'blockingReasonCodes': blockingReasonCodes,
    if (promotionEvidence &&
        reportReady &&
        sourcePromotionStatus == 'promote' &&
        blockingReasonCodes.isEmpty)
      'modelClassCoverageProof': _modelClassCoverageProof(),
  };

  Map<String, dynamic> _modelClassCoverageProof() {
    final proofSource = <String, dynamic>{
      'compatibilityKey': compatibilityKey,
      'primaryCapabilityId': primaryCapabilityId,
      'modelClass': modelClass,
      'promptVariantName': promptVariantName,
      'reportDigest': reportDigest,
      'workOrderBatchRef': digestFixture('work-order-batch-$cellSeed'),
      'modelClassCoverageRef': digestFixture('coverage-ref-$cellSeed'),
      'modelClassCoverageClassRef': digestFixture(
        'coverage-class-$cellSeed-$modelClass',
      ),
      'modelClassCoverageDigest': digestFixture('coverage-$cellSeed'),
      'sourceWorkOrderDigest': digestFixture('source-work-order-$cellSeed'),
    };
    return <String, dynamic>{
      ...proofSource,
      'proofRef': EvalProvenance.digestJson(proofSource),
    };
  }
}

const releaseFixtureAgentKind = 'taskAgent';
