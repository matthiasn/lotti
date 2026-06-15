import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_decision_ledger_source_replay_test_utils.dart';
import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_tuning_source_replay_test_utils.dart';
import 'eval_use_case_runtime_source_replay_test_utils.dart' as source_replay;
import 'eval_use_case_tuning_release_test_utils.dart' as release_utils;

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
const _releaseRoadmapInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_ROADMAP_INPUT',
);
const _releaseDecisionLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_DECISION_LEDGERS',
);
const _releaseDecisionLedgerSourceManifestPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS',
);
const _releasePreviousPlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_PREVIOUS_RELEASE_PLAN',
);
const _releaseRuntimeRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_ROLLOUT_LEDGERS',
);
const _releaseRuntimePreviousRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_PREVIOUS_ROLLOUT_LEDGERS',
);
const _releaseRuntimeLedgerReleaseGatePaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RELEASE_GATES',
);
const _releaseRuntimeLedgerReleaseReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS',
);
const _releaseRuntimeVerificationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_VERIFICATIONS',
);
const _releaseRuntimeLedgerResolverSnapshotPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS',
);
const _releaseRuntimeLedgerResolverPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_PACKETS',
);
const _releaseRuntimeLedgerLocatorPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_LOCATOR_PACKETS',
);
const _releaseRuntimeLedgerResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_INPUTS',
);
const _releaseRuntimeLedgerDirectObservationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_DIRECT_OBSERVATIONS',
);
const _releaseRuntimeLedgerStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_STATE_INPUTS',
);
const _releaseOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_PLAN',
);
const _releaseOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_PLAN_OVERWRITE',
);

void main() {
  test('accepted roadmap creates reviewable non-mutating assignments', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(EvalUseCaseTuningReleasePlan.validate(releasePlan), isEmpty);
    expect(releasePlan['status'], 'readyForReleaseReview');
    final assignment = _singleMap(releasePlan, 'runtimeAssignments');
    expect(assignment['primaryCapabilityId'], 'task.workflow');
    expect(assignment['agentKind'], 'taskAgent');
    expect(assignment['modelClass'], 'frontierFast');
    expect(assignment['promptVariantName'], 'metadata-first-v2');
    final roadmapScope =
        (roadmap['scopes'] as List<dynamic>).single as Map<String, dynamic>;
    final choice =
        (roadmapScope['acceptedChoices'] as List<dynamic>).single
            as Map<String, dynamic>;
    final proofRef = choice['modelClassCoverageProofRef'] as String;
    expect(assignment['modelClassCoverageProofRef'], proofRef);
    expect(assignment['workOrderBatchRef'], choice['workOrderBatchRef']);
    expect(
      assignment['modelClassCoverageRef'],
      choice['modelClassCoverageRef'],
    );
    expect(
      assignment['modelClassCoverageClassRef'],
      choice['modelClassCoverageClassRef'],
    );
    expect(
      assignment['modelClassCoverageDigest'],
      choice['modelClassCoverageDigest'],
    );
    expect(
      assignment['sourceWorkOrderDigest'],
      choice['sourceWorkOrderDigest'],
    );
    expect(assignment['assignmentRef'], assignment['evidenceDigest']);
    expect(
      assignment['evidenceDigest'],
      EvalProvenance.digestJson(<String, dynamic>{
        'sourceRoadmapDigest':
            (releasePlan['sourceRoadmap']
                as Map<String, dynamic>)['roadmapDigest'],
        'scopeKey': assignment['scopeKey'],
        'acceptedCellKey': assignment['acceptedCellKey'],
        'reportDigest': assignment['reportDigest'],
        'modelClassCoverageProofRef': proofRef,
        'workOrderBatchRef': assignment['workOrderBatchRef'],
        'modelClassCoverageRef': assignment['modelClassCoverageRef'],
        'modelClassCoverageClassRef': assignment['modelClassCoverageClassRef'],
        'modelClassCoverageDigest': assignment['modelClassCoverageDigest'],
        'sourceWorkOrderDigest': assignment['sourceWorkOrderDigest'],
        'modelClass': assignment['modelClass'],
        'promptVariantName': assignment['promptVariantName'],
      }),
    );
    expect(assignment['targetSurface'], 'agentInferenceRouting');
    expect(assignment['applyState'], 'notApplied');
    expect(assignment.containsKey('profileId'), isFalse);
    expect(assignment.containsKey('modelConfigId'), isFalse);
    final limitations = releasePlan['limitations'] as Map<String, dynamic>;
    expect(limitations['runtimeConfigurationApplied'], isFalse);
    expect(limitations['aiConfigMutationsWritten'], isFalse);
    final reviewQueue =
        releasePlan['releaseReviewQueue'] as Map<String, dynamic>;
    expect(reviewQueue['status'], 'pending');
    expect(reviewQueue['requiredReviewCount'], greaterThanOrEqualTo(3));
    final proofSummary =
        releasePlan['modelClassCoverageProofSummary'] as Map<String, dynamic>;
    expect(proofSummary['assignmentCount'], 1);
    expect(proofSummary['proofSummaryDigest'], isA<String>());
    expect(
      reviewQueue['modelClassCoverageProofSummaryDigest'],
      proofSummary['proofSummaryDigest'],
    );
    final reviewTask =
        (reviewQueue['tasks'] as List<dynamic>).first as Map<String, dynamic>;
    expect(
      reviewTask['modelClassCoverageProofSummaryDigest'],
      proofSummary['proofSummaryDigest'],
    );
  });

  test('contract rejects tampered proof-bound assignment fields', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );
    final tampered =
        jsonDecode(jsonEncode(releasePlan)) as Map<String, dynamic>;
    ((tampered['runtimeAssignments'] as List<dynamic>).first
        as Map<String, dynamic>)['modelClassCoverageDigest'] = release_utils
        .digestFixture(
          'tampered-coverage',
        );
    (tampered['modelClassCoverageProofSummary']
        as Map<String, dynamic>)['proofSummaryDigest'] = release_utils
        .digestFixture('tampered-proof-summary');

    final issues = EvalUseCaseTuningReleasePlan.validate(tampered);

    expect(
      issues,
      contains(
        'runtimeAssignments[0].assignmentRef must match proof-bound assignment digest',
      ),
    );
    expect(
      issues,
      contains(
        'modelClassCoverageProofSummary.proofSummaryDigest must match entries',
      ),
    );
    expect(
      issues,
      contains('releasePlanRef must match release plan subject digest'),
    );
  });

  test('contract rejects non-digest model-class coverage refs', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );
    final tampered =
        jsonDecode(jsonEncode(releasePlan)) as Map<String, dynamic>;
    final assignment =
        (tampered['runtimeAssignments'] as List<dynamic>).single
              as Map<String, dynamic>
          ..['modelClassCoverageRef'] = 'forged-coverage-ref';

    final issues = EvalUseCaseTuningReleasePlan.validate(tampered);

    expect(assignment['modelClassCoverageRef'], 'forged-coverage-ref');
    expect(
      issues,
      contains(
        'runtimeAssignments[0].modelClassCoverageRef must be a sha256 digest',
      ),
    );
  });

  test('contract rejects tampered source decision ledger summaries', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );
    final tampered =
        jsonDecode(jsonEncode(releasePlan)) as Map<String, dynamic>;
    ((tampered['sourceDecisionLedgers'] as List<dynamic>).single
          as Map<String, dynamic>)
      ..['ledgerRef'] = release_utils.digestFixture(
        'tampered-source-ledger-ref',
      )
      ..['ledgerDigest'] = release_utils.digestFixture(
        'tampered-source-ledger-digest',
      )
      ..['status'] = 'accepted'
      ..['contractIssueCount'] = 0
      ..['decisionCount'] = 7
      ..['previousDecisionContinuityCount'] = 3;

    final issues = EvalUseCaseTuningReleasePlan.validate(tampered);

    expect(issues, [
      'releasePlanRef must match release plan subject digest',
    ]);
  });

  test('accepted roadmap requires matching source decision ledgers', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(EvalUseCaseTuningReleasePlan.validate(releasePlan), isEmpty);
    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.sourceDecisionLedgerEvidenceMissing'),
    );
    expect(releasePlan['runtimeAssignments'], isEmpty);
  });

  test('forged accepted roadmap without source ledgers cannot release', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final forged = jsonDecode(jsonEncode(roadmap)) as Map<String, dynamic>;
    forged['sourceLedgers'] = const <Map<String, dynamic>>[];
    (forged['summary'] as Map<String, dynamic>)['sourceLedgerCount'] = 0;
    for (final scope
        in (forged['scopes'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      scope['sourceLedgerRefs'] = const <String>[];
      for (final choice
          in (scope['acceptedChoices'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        choice['sourceLedgerRefs'] = const <String>[];
      }
    }

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: forged,
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(
      EvalUseCaseTuningRoadmap.validate(forged),
      contains('accepted roadmap requires source ledger evidence'),
    );
    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.sourceDecisionLedgerEvidenceMissing'),
    );
    expect(releasePlan['runtimeAssignments'], isEmpty);
  });

  test('accepted roadmap rejects mismatched source decision ledgers', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final tamperedRoadmap =
        jsonDecode(jsonEncode(roadmap)) as Map<String, dynamic>;
    ((tamperedRoadmap['sourceLedgers'] as List<dynamic>).single
        as Map<String, dynamic>)['ledgerDigest'] = release_utils.digestFixture(
      'stale-decision-ledger-digest',
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: tamperedRoadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.sourceDecisionLedgerEvidenceMismatch'),
    );
    expect(releasePlan['runtimeAssignments'], isEmpty);
  });

  test('accepted roadmap rejects restamped source ledger claims', () {
    const original = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final replacement = original.copyWith(
      compatibilitySeed: 'other-task-compat',
      modelClass: 'localPrecise',
      promptVariantName: 'compact-v1',
      cellSeed: 'task-local-precise',
      reportSeed: 'task-local-report',
    );
    final originalLedger = _ledgerFor(original.acceptedDecision());
    final replacementLedger = _ledgerFor(replacement.acceptedDecision());
    final forgedRoadmap = _restampRoadmapSourceLedger(
      EvalUseCaseTuningRoadmap.build(
        ledgers: [originalLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      ),
      replacementRoadmap: EvalUseCaseTuningRoadmap.build(
        ledgers: [replacementLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      ),
    );

    expect(EvalUseCaseTuningRoadmap.validate(forgedRoadmap), isEmpty);

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: forgedRoadmap,
      sourceDecisionLedgers: [replacementLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.roadmapSourceDecisionLedgersMismatch'),
    );
    expect(releasePlan['runtimeAssignments'], isEmpty);
  });

  test(
    'source-aware validation rejects restamped assignment proof anchors',
    () {
      const fixture = _ScopeFixture(
        compatibilitySeed: 'task-compat',
        primaryCapabilityId: 'task.workflow',
        modelClass: 'frontierFast',
        promptVariantName: 'metadata-first-v2',
        cellSeed: 'task-frontier-fast',
        reportSeed: 'task-report',
      );
      final ledger = _ledgerFor(fixture.acceptedDecision());
      final roadmap = EvalUseCaseTuningRoadmap.build(
        ledgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      );
      final releasePlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 12, 16),
      );
      final forged = _restampReleasePlanAssignmentProof(
        releasePlan,
        modelClassCoverageRef: _digest('forged-coverage-ref'),
      );

      expect(EvalUseCaseTuningReleasePlan.validate(forged), isEmpty);

      final issues = EvalUseCaseTuningReleasePlan.validateAgainstSources(
        forged,
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
      );

      expect(
        issues,
        contains('release plan must match source roadmap and ledgers'),
      );
    },
  );

  test('release plan builder rejects restamped rollback roadmap', () {
    const original = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final replacement = original.copyWith(
      compatibilitySeed: 'other-task-compat',
      modelClass: 'localPrecise',
      promptVariantName: 'compact-v1',
      cellSeed: 'task-local-precise',
      reportSeed: 'task-local-report',
    );
    final originalLedger = _ledgerFor(
      original.blockedDecision(
        blockerCodes: const ['decision.previousAcceptedBlocked'],
      ),
      continuity: [original.rollbackContinuity()],
      status: 'blocked',
    );
    final replacementLedger = _ledgerFor(
      replacement.blockedDecision(
        blockerCodes: const ['decision.previousAcceptedBlocked'],
      ),
      continuity: [replacement.rollbackContinuity()],
      status: 'blocked',
    );
    final forgedRoadmap = _restampRoadmapSourceLedger(
      EvalUseCaseTuningRoadmap.build(
        ledgers: [originalLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      ),
      replacementRoadmap: EvalUseCaseTuningRoadmap.build(
        ledgers: [replacementLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      ),
    );

    expect(EvalUseCaseTuningRoadmap.validate(forgedRoadmap), isEmpty);

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: forgedRoadmap,
      sourceDecisionLedgers: [replacementLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.roadmapSourceDecisionLedgersMismatch'),
    );
  });

  test('release plan builder rejects restamped revalidation roadmap', () {
    const original = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final replacement = original.copyWith(
      modelClass: 'localPrecise',
      promptVariantName: 'compact-v1',
      cellSeed: 'task-local-precise',
      reportSeed: 'task-local-report',
    );
    final originalAcceptedLedger = _ledgerFor(original.acceptedDecision());
    final originalBlockedLedger = _ledgerFor(original.blockedDecision());
    final replacementAcceptedLedger = _ledgerFor(
      replacement.acceptedDecision(),
    );
    final replacementBlockedLedger = _ledgerFor(replacement.blockedDecision());
    final forgedRoadmap = _restampRoadmapSourceLedger(
      EvalUseCaseTuningRoadmap.build(
        ledgers: [originalAcceptedLedger, originalBlockedLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      ),
      replacementRoadmap: EvalUseCaseTuningRoadmap.build(
        ledgers: [replacementAcceptedLedger, replacementBlockedLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      ),
    );

    expect(EvalUseCaseTuningRoadmap.validate(forgedRoadmap), isEmpty);

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: forgedRoadmap,
      sourceDecisionLedgers: [
        replacementAcceptedLedger,
        replacementBlockedLedger,
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.roadmapSourceDecisionLedgersMismatch'),
    );
  });

  test('assignment refs bind proof identity changes', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );
    final changedDecision =
        jsonDecode(jsonEncode(fixture.acceptedDecision()))
            as Map<String, dynamic>;
    final changedProof = _retargetCoverageProof(
      (((changedDecision['acceptedCandidate']
                  as Map<String, dynamic>)['modelClassCoverageProof'])
              as Map<String, dynamic>)
          .cast<String, dynamic>(),
      sourceWorkOrderDigest: _digest('changed-source-work-order'),
    );
    (changedDecision['acceptedCandidate']
            as Map<String, dynamic>)['modelClassCoverageProof'] =
        changedProof;
    (((changedDecision['candidates'] as List<dynamic>).single)
            as Map<String, dynamic>)['modelClassCoverageProof'] =
        changedProof;
    final changedLedger = _ledgerFor(changedDecision);
    final changedRoadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [changedLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final changedReleasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: changedRoadmap,
      sourceDecisionLedgers: [changedLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    final assignment = _singleMap(releasePlan, 'runtimeAssignments');
    final changedAssignment = _singleMap(
      changedReleasePlan,
      'runtimeAssignments',
    );
    expect(changedAssignment['acceptedCellKey'], assignment['acceptedCellKey']);
    expect(changedAssignment['reportDigest'], assignment['reportDigest']);
    expect(
      changedAssignment['modelClassCoverageProofRef'],
      isNot(assignment['modelClassCoverageProofRef']),
    );
    expect(
      changedAssignment['assignmentRef'],
      isNot(assignment['assignmentRef']),
    );
  });

  test('runtime rollout ledger blocks unchanged assignment revalidation', () {
    final sourceFixture = release_utils
        .buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final previousPlan = sourceFixture.releasePlan;
    final runtimeLedger = _runtimeRolloutLedger(
      previousPlan,
      resolutionStatus: 'notApplied',
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      sourceRuntimeRolloutLedgers: [runtimeLedger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(EvalUseCaseTuningReleasePlan.validate(releasePlan), isEmpty);
    expect(releasePlan['status'], 'revalidateRequired');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('runtime.notApplied'),
    );
    final source = _singleMap(releasePlan, 'sourceRuntimeRolloutLedgers');
    expect(source['status'], 'blocked');
    expect(source['blockedAssignmentCount'], 1);
    expect(source['ledgerRef'], runtimeLedger['rolloutLedgerRef']);
    final continuity = _singleMap(releasePlan, 'previousAssignmentContinuity');
    expect(continuity['runtimeLedgerRef'], runtimeLedger['rolloutLedgerRef']);
    expect(continuity['status'], 'revalidateRequired');
    expect(continuity['runtimeStatus'], 'notApplied');
    expect(continuity['blockerCodes'], contains('runtime.notApplied'));
    expect(
      (releasePlan['summary']
          as Map<String, dynamic>)['runtimeAssignmentEvidenceCount'],
      1,
    );
  });

  test(
    'source replay requirement rejects serialized previous release plans',
    () {
      final sourceFixture = release_utils
          .buildDecisionLedgerSourceBoundReleaseFixture();
      final ledger = sourceFixture.ledger;
      final roadmap = sourceFixture.roadmap;
      final previousPlan = sourceFixture.releasePlan;
      final serializedPreviousPlan =
          jsonDecode(jsonEncode(previousPlan)) as Map<String, dynamic>;

      expect(
        EvalUseCaseTuningReleasePlan.validate(serializedPreviousPlan),
        isEmpty,
      );

      final serializedReleasePlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        previousReleasePlan: serializedPreviousPlan,
        requireDecisionLedgerSourceReplay: true,
        requirePreviousReleasePlanSourceReplay: true,
        generatedAt: DateTime.utc(2026, 6, 12, 17),
      );

      expect(serializedReleasePlan['status'], 'invalid');
      expect(
        serializedReleasePlan['issues'],
        contains(
          containsPair(
            'message',
            'previous release plan source replay must be verified',
          ),
        ),
      );

      final replayedReleasePlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        previousReleasePlan: previousPlan,
        requireDecisionLedgerSourceReplay: true,
        requirePreviousReleasePlanSourceReplay: true,
        generatedAt: DateTime.utc(2026, 6, 12, 17),
      );

      expect(
        replayedReleasePlan['issues'],
        isNot(
          contains(
            containsPair(
              'message',
              'previous release plan source replay must be verified',
            ),
          ),
        ),
      );
    },
  );

  test(
    'artifact-only runtime rollout ledger replay cannot waive continuity',
    () {
      const fixture = _ScopeFixture(
        compatibilitySeed: 'task-compat',
        primaryCapabilityId: 'task.workflow',
        modelClass: 'frontierFast',
        promptVariantName: 'metadata-first-v2',
        cellSeed: 'task-frontier-fast',
        reportSeed: 'task-report',
      );
      final ledger = _ledgerFor(fixture.acceptedDecision());
      final roadmap = EvalUseCaseTuningRoadmap.build(
        ledgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      );
      final previousPlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 12, 16),
      );
      final runtimeLedger = _runtimeRolloutLedger(previousPlan);
      final replayedRuntimeLedger =
          jsonDecode(jsonEncode(runtimeLedger)) as Map<String, dynamic>;

      expect(
        EvalUseCaseRuntimeRolloutLedger.validate(replayedRuntimeLedger),
        isEmpty,
      );
      EvalUseCaseRuntimeRolloutLedger.assertValid(replayedRuntimeLedger);

      final releasePlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        sourceRuntimeRolloutLedgers: [replayedRuntimeLedger],
        previousReleasePlan: previousPlan,
        generatedAt: DateTime.utc(2026, 6, 12, 17),
      );

      expect(releasePlan['status'], 'invalid');
      expect(
        releasePlan['blockedReasonCodes'],
        contains('release.sourceRuntimeRolloutLedgerInvalid'),
      );
      final source = _singleMap(releasePlan, 'sourceRuntimeRolloutLedgers');
      expect(source['status'], 'invalid');
      expect(source['sourceArtifactVerified'], isFalse);
      expect(
        releasePlan['issues'],
        contains(
          allOf(
            containsPair('code', 'release.sourceRuntimeRolloutLedgerInvalid'),
            containsPair(
              'message',
              contains('source artifacts not verified'),
            ),
          ),
        ),
      );
    },
  );

  test('source replay marks JSON-loaded runtime rollout ledgers', () {
    final sourceFixture = release_utils
        .buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final previousPlan = sourceFixture.releasePlan;
    final runtimeFixture = _RuntimeRolloutLedgerFixture.build(
      previousPlan,
      resolutionStatus: 'notApplied',
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
    );
    final replayedRuntimeLedger =
        jsonDecode(jsonEncode(runtimeFixture.ledger)) as Map<String, dynamic>;

    final artifactOnlyPlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      sourceRuntimeRolloutLedgers: [replayedRuntimeLedger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );
    expect(artifactOnlyPlan['status'], 'invalid');

    _markRuntimeRolloutLedgerSources(
      [replayedRuntimeLedger],
      previousPlan: previousPlan,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      previousRuntimeRolloutLedgers: const [],
      releaseGates: [runtimeFixture.releaseGate],
      releaseReviewBundles: [runtimeFixture.releaseReviewBundle],
      runtimeVerifications: [runtimeFixture.verification],
      runtimeResolverSnapshots: [runtimeFixture.resolverSnapshot],
      runtimeResolverPackets: [runtimeFixture.resolverPacket],
      runtimeLocatorPackets: const [],
      completedBindingSources: [runtimeFixture.completedBindings],
      directObservationSources: const [],
      privateRuntimeStates: const [],
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      sourceRuntimeRolloutLedgers: [replayedRuntimeLedger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(EvalUseCaseTuningReleasePlan.validate(releasePlan), isEmpty);
    expect(releasePlan['status'], 'revalidateRequired');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('runtime.notApplied'),
    );
    final source = _singleMap(releasePlan, 'sourceRuntimeRolloutLedgers');
    expect(source['status'], 'blocked');
    expect(source['sourceArtifactVerified'], isTrue);
  });

  test('source replay rejects missing runtime resolver packet evidence', () {
    final sourceFixture = release_utils
        .buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final previousPlan = sourceFixture.releasePlan;
    final runtimeFixture = _RuntimeRolloutLedgerFixture.build(
      previousPlan,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
    );
    final replayedRuntimeLedger =
        jsonDecode(jsonEncode(runtimeFixture.ledger)) as Map<String, dynamic>;

    expect(
      () => _markRuntimeRolloutLedgerSources(
        [replayedRuntimeLedger],
        previousPlan: previousPlan,
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        previousRuntimeRolloutLedgers: const [],
        releaseGates: [runtimeFixture.releaseGate],
        releaseReviewBundles: [runtimeFixture.releaseReviewBundle],
        runtimeVerifications: [runtimeFixture.verification],
        runtimeResolverSnapshots: [runtimeFixture.resolverSnapshot],
        runtimeResolverPackets: const [],
        runtimeLocatorPackets: const [],
        completedBindingSources: [runtimeFixture.completedBindings],
        directObservationSources: const [],
        privateRuntimeStates: const [],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('Missing runtime resolver packet source artifact'),
        ),
      ),
    );
  });

  test('source replay marks runtime rollout ledger chains', () {
    final sourceFixture = release_utils
        .buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final previousPlan = sourceFixture.releasePlan;
    final runtimeFixture = _RuntimeRolloutLedgerFixture.build(
      previousPlan,
      resolutionStatus: 'notApplied',
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
    );
    final chainedLedger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: previousPlan,
      releaseGate: runtimeFixture.releaseGate,
      runtimeVerifications: [runtimeFixture.verification],
      runtimeResolverSnapshots: [runtimeFixture.resolverSnapshot],
      runtimeResolverPackets: [runtimeFixture.resolverPacket],
      releaseReviewBundles: [runtimeFixture.releaseReviewBundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      previousLedger: runtimeFixture.ledger,
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );
    final replayedPreviousLedger =
        jsonDecode(jsonEncode(runtimeFixture.ledger)) as Map<String, dynamic>;
    final replayedChainedLedger =
        jsonDecode(jsonEncode(chainedLedger)) as Map<String, dynamic>;

    _markRuntimeRolloutLedgerSources(
      [replayedChainedLedger],
      previousPlan: previousPlan,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      previousRuntimeRolloutLedgers: [replayedPreviousLedger],
      releaseGates: [runtimeFixture.releaseGate],
      releaseReviewBundles: [runtimeFixture.releaseReviewBundle],
      runtimeVerifications: [runtimeFixture.verification],
      runtimeResolverSnapshots: [runtimeFixture.resolverSnapshot],
      runtimeResolverPackets: [runtimeFixture.resolverPacket],
      runtimeLocatorPackets: const [],
      completedBindingSources: [runtimeFixture.completedBindings],
      directObservationSources: const [],
      privateRuntimeStates: const [],
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      sourceRuntimeRolloutLedgers: [replayedChainedLedger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(EvalUseCaseTuningReleasePlan.validate(releasePlan), isEmpty);
    expect(releasePlan['status'], 'revalidateRequired');
    final source = _singleMap(releasePlan, 'sourceRuntimeRolloutLedgers');
    expect(source['sourceArtifactVerified'], isTrue);
    expect(
      source['ledgerDigest'],
      EvalProvenance.digestJson(replayedChainedLedger),
    );
  });

  test(
    'source replay rejects missing previous runtime rollout ledger evidence',
    () {
      final sourceFixture = release_utils
          .buildDecisionLedgerSourceBoundReleaseFixture();
      final ledger = sourceFixture.ledger;
      final roadmap = sourceFixture.roadmap;
      final previousPlan = sourceFixture.releasePlan;
      final runtimeFixture = _RuntimeRolloutLedgerFixture.build(
        previousPlan,
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
      );
      final chainedLedger = EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: previousPlan,
        releaseGate: runtimeFixture.releaseGate,
        runtimeVerifications: [runtimeFixture.verification],
        runtimeResolverSnapshots: [runtimeFixture.resolverSnapshot],
        runtimeResolverPackets: [runtimeFixture.resolverPacket],
        releaseReviewBundles: [runtimeFixture.releaseReviewBundle],
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        previousLedger: runtimeFixture.ledger,
        generatedAt: DateTime.utc(2026, 6, 13, 9),
      );
      final replayedChainedLedger =
          jsonDecode(jsonEncode(chainedLedger)) as Map<String, dynamic>;

      expect(
        () => _markRuntimeRolloutLedgerSources(
          [replayedChainedLedger],
          previousPlan: previousPlan,
          sourceRoadmap: roadmap,
          sourceDecisionLedgers: [ledger],
          previousRuntimeRolloutLedgers: const [],
          releaseGates: [runtimeFixture.releaseGate],
          releaseReviewBundles: [runtimeFixture.releaseReviewBundle],
          runtimeVerifications: [runtimeFixture.verification],
          runtimeResolverSnapshots: [runtimeFixture.resolverSnapshot],
          runtimeResolverPackets: [runtimeFixture.resolverPacket],
          runtimeLocatorPackets: const [],
          completedBindingSources: [runtimeFixture.completedBindings],
          directObservationSources: const [],
          privateRuntimeStates: const [],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains(
              'Missing runtime rollout previous ledger source artifact',
            ),
          ),
        ),
      );
    },
  );

  test('missing runtime rollout evidence blocks unchanged continuity', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final previousPlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(EvalUseCaseTuningReleasePlan.validate(releasePlan), isEmpty);
    expect(releasePlan['status'], 'revalidateRequired');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('runtime.evidenceMissing'),
    );
    final continuity = _singleMap(releasePlan, 'previousAssignmentContinuity');
    expect(continuity['status'], 'revalidateRequired');
    expect(continuity['blockerCodes'], contains('runtime.evidenceMissing'));
    expect(
      (releasePlan['summary']
          as Map<String, dynamic>)['runtimeAssignmentEvidenceCount'],
      0,
    );
  });

  test('forged runtime rollout blocker waivers invalidate release plan', () {
    final sourceFixture = release_utils
        .buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final previousPlan = sourceFixture.releasePlan;
    final runtimeLedger = _runtimeRolloutLedger(
      previousPlan,
      resolutionStatus: 'notApplied',
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
    );
    final forgedRuntimeLedger =
        jsonDecode(jsonEncode(runtimeLedger)) as Map<String, dynamic>;
    final summary = forgedRuntimeLedger['summary'] as Map<String, dynamic>;
    final assignment =
        (forgedRuntimeLedger['assignments'] as List<dynamic>).single
            as Map<String, dynamic>;
    forgedRuntimeLedger
      ..['status'] = 'verified'
      ..['blockers'] = <Map<String, dynamic>>[];
    summary
      ..['runtimeVerifiedCount'] = 1
      ..['notAppliedCount'] = 0
      ..['blockerCount'] = 0;
    assignment
      ..['runtimeStatus'] = 'runtimeVerified'
      ..['sourceIssueCodes'] = <String>[]
      ..['blockerCodes'] = <String>[]
      ..['blockers'] = <Map<String, dynamic>>[]
      ..['nextAction'] = 'continueReleasePlanning';
    forgedRuntimeLedger['rolloutLedgerRef'] =
        EvalUseCaseRuntimeRolloutLedger.rolloutLedgerRef(forgedRuntimeLedger);

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      sourceRuntimeRolloutLedgers: [forgedRuntimeLedger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.sourceRuntimeRolloutLedgerInvalid'),
    );
    final source = _singleMap(releasePlan, 'sourceRuntimeRolloutLedgers');
    expect(source['status'], 'invalid');
    expect(source['contractIssueCount'], greaterThan(0));
    expect(
      releasePlan['issues'],
      contains(
        containsPair('code', 'release.sourceRuntimeRolloutLedgerInvalid'),
      ),
    );
  });

  test('release plan contract rejects restamped continuity waivers', () {
    final sourceFixture = release_utils
        .buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final previousPlan = sourceFixture.releasePlan;
    final runtimeLedger = _runtimeRolloutLedger(
      previousPlan,
      resolutionStatus: 'notApplied',
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      sourceRuntimeRolloutLedgers: [runtimeLedger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );
    final tampered =
        jsonDecode(jsonEncode(releasePlan)) as Map<String, dynamic>;
    final summary = tampered['summary'] as Map<String, dynamic>;
    final continuity =
        (tampered['previousAssignmentContinuity'] as List<dynamic>).single
            as Map<String, dynamic>;

    tampered
      ..['status'] = 'readyForReleaseReview'
      ..['blockedReasonCodes'] = <String>[]
      ..['issues'] = <Map<String, dynamic>>[];
    summary
      ..['revalidateRequiredCount'] = 0
      ..['blockedReasonCount'] = 0;
    continuity
      ..['status'] = 'unchanged'
      ..['blockerCodes'] = <String>[];
    tampered['releasePlanRef'] = EvalUseCaseTuningReleasePlan.releasePlanRef(
      tampered,
    );

    final issues = EvalUseCaseTuningReleasePlan.validate(tampered);

    expect(
      issues,
      contains(
        'previousAssignmentContinuity[0].status must match continuity evidence',
      ),
    );
    expect(
      issues,
      contains(
        'previousAssignmentContinuity[0].runtimeStatus must be runtimeVerified when unchanged',
      ),
    );
  });

  test('stale runtime rollout ledger blocks release plan as invalid', () {
    final sourceFixture = release_utils
        .buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final previousPlan = sourceFixture.releasePlan;
    final stalePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16, 30),
    );
    final staleRuntimeLedger = _runtimeRolloutLedger(
      stalePlan,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      sourceRuntimeRolloutLedgers: [staleRuntimeLedger],
      previousReleasePlan: previousPlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(releasePlan['status'], 'invalid');
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.sourceRuntimeRolloutLedgerInvalid'),
    );
    expect(
      releasePlan['issues'],
      contains(
        containsPair('code', 'release.sourceRuntimeRolloutLedgerInvalid'),
      ),
    );
  });

  test('non-accepted roadmaps emit no runtime assignments', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'default',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final blockedLedger = _ledgerFor(fixture.blockedDecision());
    final blockedRoadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [blockedLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: blockedRoadmap,
      sourceDecisionLedgers: [blockedLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(releasePlan['status'], 'blockedRoadmap');
    expect(releasePlan['runtimeAssignments'], isEmpty);
    expect(
      releasePlan['blockedReasonCodes'],
      contains('release.roadmapNotAccepted'),
    );
  });

  test(
    'rollback roadmap requires source decision-ledger continuity evidence',
    () {
      const fixture = _ScopeFixture(
        compatibilitySeed: 'task-compat',
        primaryCapabilityId: 'task.workflow',
        modelClass: 'frontierFast',
        promptVariantName: 'default',
        cellSeed: 'task-frontier-fast',
        reportSeed: 'task-report',
      );
      final ledger = _ledgerFor(
        fixture.blockedDecision(
          blockerCodes: const ['decision.previousAcceptedBlocked'],
        ),
        continuity: [fixture.rollbackContinuity()],
        status: 'blocked',
      );
      final roadmap = EvalUseCaseTuningRoadmap.build(
        ledgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 12, 15),
      );

      final withoutEvidence = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        generatedAt: DateTime.utc(2026, 6, 12, 16),
      );
      expect(withoutEvidence['status'], 'rollbackRequired');
      expect(
        withoutEvidence['blockedReasonCodes'],
        contains('release.rollbackEvidenceMissing'),
      );
      expect(withoutEvidence['runtimeAssignments'], isEmpty);

      final withEvidence = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 12, 16),
      );
      expect(withEvidence['status'], 'rollbackRequired');
      expect(
        withEvidence['blockedReasonCodes'],
        isNot(contains('release.rollbackEvidenceMissing')),
      );
      final continuity = _singleMap(
        withEvidence,
        'decisionLedgerContinuityEvidence',
      );
      expect(continuity['status'], 'rollbackRequired');
      expect(continuity['previousAcceptedCellKey'], fixture.cellKey);
    },
  );

  test('invalid source decision ledgers are sanitized and block release', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'default',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final acceptedLedger = _ledgerFor(fixture.acceptedDecision());
    final invalidLedger = _ledgerFor(fixture.acceptedDecision())
      ..['kind'] = 'lotti.invalid'
      ..['status'] = '/Users/mn/private-status';
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [acceptedLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );

    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [invalidLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );

    expect(releasePlan['status'], 'invalid');
    final source = _singleMap(releasePlan, 'sourceDecisionLedgers');
    expect(source['status'], 'invalid');
    expect(source['contractIssueCount'], greaterThan(0));
    expect(releasePlan.toString(), isNot(contains('/Users/mn')));
  });

  test('contract rejects private ids, selectors, paths, and command smuggling', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontierFast',
      promptVariantName: 'default',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = _ledgerFor(fixture.acceptedDecision());
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );
    final assignment = _singleMap(releasePlan, 'runtimeAssignments');
    assignment['agentId'] = 'agent-private';
    assignment['promptVariantName'] = 'bash -lc sqlite3';
    assignment['privatePath'] = '/private/tmp/release.json';
    final reviewQueue =
        releasePlan['releaseReviewQueue'] as Map<String, dynamic>;
    final task =
        (reviewQueue['tasks'] as List<dynamic>).first as Map<String, dynamic>;
    task['notes'] = 'TaskAgentService.updateAgentProfile now';
    (releasePlan['recommendedCommands'] as List<dynamic>).add(
      <String, dynamic>{
        'mode': 'run',
        'command': 'eval/run_level2.sh run private',
        'env': const <String, dynamic>{'EVAL_PROFILE_NAMES': 'private'},
      },
    );

    final issues = EvalUseCaseTuningReleasePlan.validate(releasePlan);

    expect(
      issues,
      contains(
        'releasePlan.runtimeAssignments[0].agentId must not expose private runtime ids',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeAssignments[0].promptVariantName must be a safe public token',
      ),
    );
    expect(
      issues,
      contains(
        'releasePlan.runtimeAssignments[0].promptVariantName must not contain mutation commands',
      ),
    );
    expect(
      issues,
      contains(
        'releasePlan.runtimeAssignments[0].privatePath must not contain private paths',
      ),
    );
    expect(
      issues,
      contains(
        'releasePlan.releaseReviewQueue.tasks[0].notes must not contain mutation commands',
      ),
    );
    expect(
      issues,
      contains(
        'recommendedCommands[1].command must not recommend live run commands',
      ),
    );
    expect(
      issues,
      contains('recommendedCommands[1] must not contain env values'),
    );
  });

  test(
    'writes use-case tuning release plan',
    () async {
      final roadmap =
          jsonDecode(File(_releaseRoadmapInputPath).readAsStringSync())
              as Map<String, dynamic>;
      final sourceLedgers = [
        for (final path in _releaseDecisionLedgerPaths.split(','))
          if (path.trim().isNotEmpty)
            jsonDecode(File(path.trim()).readAsStringSync())
                as Map<String, dynamic>,
      ];
      if (roadmap['status'] == 'accepted' && sourceLedgers.isEmpty) {
        throw StateError(
          'EVAL_USE_CASE_RELEASE_DECISION_LEDGERS is required for accepted '
          'roadmaps.',
        );
      }
      final replayedSourceLedgers = sourceLedgers.isEmpty
          ? const <Map<String, dynamic>>[]
          : await evalReplayDecisionLedgerSourceManifests(
              ledgers: sourceLedgers,
              manifests: evalReadDecisionLedgerSourceManifestFiles(
                _releaseDecisionLedgerSourceManifestPaths,
              ),
              config: _sourceReplayConfig(),
            );
      if (replayedSourceLedgers.isNotEmpty) {
        EvalUseCaseTuningRoadmap.assertMatchesDecisionLedgers(
          roadmap,
          ledgers: replayedSourceLedgers,
          requireDecisionLedgerSourceReplay: true,
        );
      }
      final previousPlan = _releasePreviousPlanPath.isEmpty
          ? null
          : jsonDecode(File(_releasePreviousPlanPath).readAsStringSync())
                as Map<String, dynamic>;
      final runtimeRolloutLedgers = [
        for (final path in _releaseRuntimeRolloutLedgerPaths.split(','))
          if (path.trim().isNotEmpty)
            jsonDecode(File(path.trim()).readAsStringSync())
                as Map<String, dynamic>,
      ];
      if (runtimeRolloutLedgers.isNotEmpty) {
        if (previousPlan == null) {
          throw StateError(
            'EVAL_USE_CASE_PREVIOUS_RELEASE_PLAN is required with '
            'EVAL_USE_CASE_RUNTIME_ROLLOUT_LEDGERS.',
          );
        }
        _markRuntimeRolloutLedgerSources(
          runtimeRolloutLedgers,
          previousPlan: previousPlan,
          sourceRoadmap: roadmap,
          sourceDecisionLedgers: replayedSourceLedgers,
          previousRuntimeRolloutLedgers: _readJsonList(
            _releaseRuntimePreviousRolloutLedgerPaths,
          ),
          releaseGates: _readJsonList(_releaseRuntimeLedgerReleaseGatePaths),
          releaseReviewBundles: _readReviewBundles(
            _releaseRuntimeLedgerReleaseReviewAttestations,
          ),
          runtimeVerifications: _readJsonList(
            _releaseRuntimeVerificationPaths,
          ),
          runtimeResolverSnapshots: _readJsonList(
            _releaseRuntimeLedgerResolverSnapshotPaths,
          ),
          runtimeResolverPackets: _readJsonList(
            _releaseRuntimeLedgerResolverPacketPaths,
          ),
          runtimeLocatorPackets: _readJsonList(
            _releaseRuntimeLedgerLocatorPacketPaths,
          ),
          completedBindingSources: source_replay.readCompletedBindingSources(
            _releaseRuntimeLedgerResolverInputPaths,
          ),
          directObservationSources: source_replay.readDirectObservationSources(
            _releaseRuntimeLedgerDirectObservationPaths,
          ),
          privateRuntimeStates: source_replay.readJsonObjects(
            _releaseRuntimeLedgerStateInputPaths,
          ),
        );
      }
      final releasePlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: replayedSourceLedgers,
        sourceRuntimeRolloutLedgers: runtimeRolloutLedgers,
        previousReleasePlan: previousPlan,
        requireDecisionLedgerSourceReplay: replayedSourceLedgers.isNotEmpty,
      );
      EvalUseCaseTuningReleasePlan.assertValid(releasePlan);
      EvalUseCaseTuningReleasePlan.assertMatchesSources(
        releasePlan,
        roadmap: roadmap,
        sourceDecisionLedgers: replayedSourceLedgers,
        sourceRuntimeRolloutLedgers: runtimeRolloutLedgers,
        previousReleasePlan: previousPlan,
        requireDecisionLedgerSourceReplay: replayedSourceLedgers.isNotEmpty,
      );
      writeEvalJsonArtifact(
        releasePlan,
        path: _releaseOutputPath,
        overwrite: _releaseOverwrite == '1',
        description: 'use-case tuning release plan',
      );
    },
    skip: _releaseRoadmapInputPath.isEmpty || _releaseOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_RELEASE_ROADMAP_INPUT=<json> and '
              'EVAL_USE_CASE_RELEASE_PLAN=<json> to write a release plan.'
        : false,
  );
}

void _markRuntimeRolloutLedgerSources(
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
  final verificationByDigest = _artifactsByDigest(
    runtimeVerifications,
    'runtime verification',
  );
  final snapshotByDigest = _artifactsByDigest(
    runtimeResolverSnapshots,
    'runtime resolver snapshot',
  );
  final resolverPacketByDigest = _artifactsByDigest(
    runtimeResolverPackets,
    'runtime resolver packet',
  );
  final locatorPacketByDigest = _artifactsByDigest(
    runtimeLocatorPackets,
    'runtime locator packet',
  );
  final runtimeLedgerByDigest = _artifactsByDigest(
    [
      ...runtimeRolloutLedgers,
      ...previousRuntimeRolloutLedgers,
    ],
    'runtime rollout ledger',
  );
  final visitedLedgerDigests = <String>{};
  final visitingLedgerDigests = <String>{};

  for (final ledger in runtimeRolloutLedgers) {
    _markRuntimeRolloutLedgerSource(
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

void _markRuntimeRolloutLedgerSource(
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
  final sourcePreviousLedger = _mapValue(ledger['sourcePreviousLedger']);
  if (sourcePreviousLedger.isNotEmpty) {
    final previousLedgerDigest = _requiredString(
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
    _markRuntimeRolloutLedgerSource(
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

  final releaseGate = _releaseGateForRuntimeLedger(ledger, releaseGates);
  final ledgerVerifications = _sourceArtifactsForDigests(
    verificationByDigest,
    [
      for (final source in _mapList(ledger['runtimeVerificationSources']))
        _requiredString(
          source,
          'runtimeVerificationDigest',
          'runtime verification source digest',
        ),
    ],
    'runtime verification',
  );
  final ledgerSnapshots = _sourceArtifactsForDigests(
    snapshotByDigest,
    [
      for (final source in _mapList(ledger['runtimeResolverSnapshotSources']))
        _requiredString(
          source,
          'runtimeResolverSnapshotDigest',
          'runtime resolver snapshot source digest',
        ),
    ],
    'runtime resolver snapshot',
  );
  final ledgerResolverPackets = _sourceArtifactsForDigests(
    resolverPacketByDigest,
    [
      for (final snapshot in ledgerSnapshots)
        _requiredString(
          _mapValue(snapshot['runtimeObservationSource']),
          'sourceResolverPacketDigest',
          'runtime resolver packet source digest',
        ),
    ],
    'runtime resolver packet',
  );
  final ledgerLocatorPackets = _sourceArtifactsForDigests(
    locatorPacketByDigest,
    [
      for (final snapshot in ledgerSnapshots)
        _string(
          _mapValue(
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

List<Map<String, dynamic>> _readJsonList(String paths) => [
  for (final path
      in paths
          .split(',')
          .map((path) => path.trim())
          .where(
            (path) => path.isNotEmpty,
          ))
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
];

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

List<Map<String, dynamic>> _readReviewBundles(String paths) {
  return [
    for (final path in paths.split(','))
      if (path.trim().isNotEmpty) ..._readReviewBundleFile(path.trim()),
  ];
}

List<Map<String, dynamic>> _readReviewBundleFile(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is List) {
    return [
      for (final item in decoded)
        _releaseReviewBundleObject(item as Map<String, dynamic>),
    ];
  }
  if (decoded is Map<String, dynamic>) {
    return [_releaseReviewBundleObject(decoded)];
  }
  throw StateError('Expected release review bundle JSON object or list.');
}

Map<String, dynamic> _releaseReviewBundleObject(Map<String, dynamic> bundle) {
  if (bundle['kind'] != EvalUseCaseTuningReleaseReview.bundleKind) {
    throw StateError(
      'Expected a use-case tuning release review attestation bundle.',
    );
  }
  EvalUseCaseTuningReleaseReview.assertValidBundle(bundle);
  return bundle;
}

Map<String, Map<String, dynamic>> _artifactsByDigest(
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

Map<String, dynamic> _releaseGateForRuntimeLedger(
  Map<String, dynamic> ledger,
  List<Map<String, dynamic>> releaseGates,
) {
  final sourceGate = _mapValue(ledger['sourceReleaseGate']);
  final expectedDigest = _requiredString(
    sourceGate,
    'releaseGateDigest',
    'runtime rollout ledger source release gate digest',
  );
  final expectedRef = _requiredString(
    sourceGate,
    'releaseGateRef',
    'runtime rollout ledger source release gate ref',
  );
  final matches = [
    for (final gate in releaseGates)
      if (EvalProvenance.digestJson(gate) == expectedDigest &&
          _string(gate['releaseGateRef']) == expectedRef)
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

List<Map<String, dynamic>> _sourceArtifactsForDigests(
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

String _requiredString(
  Map<String, dynamic> artifact,
  String key,
  String description,
) {
  final value = _string(artifact[key]);
  if (value.isNotEmpty) return value;
  throw StateError('Missing $description.');
}

Map<String, dynamic> _mapValue(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map<String, dynamic>) item,
      ]
    : const <Map<String, dynamic>>[];

String _string(Object? value) => value is String ? value : '';

Map<String, dynamic> _ledgerFor(
  Map<String, dynamic> decision, {
  List<Map<String, dynamic>> continuity = const [],
  String? status,
}) {
  final blockedReasonCodes = _sortedStrings({
    for (final code in _stringList(decision['blockerCodes'])) code,
    for (final entry in continuity) ..._stringList(entry['blockerCodes']),
  });
  final decisions = [decision];
  final ledger = <String, dynamic>{
    'schemaVersion': EvalUseCaseTuningDecisionLedger.schemaVersion,
    'kind': EvalUseCaseTuningDecisionLedger.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 13).toIso8601String(),
    'status': status ?? _ledgerStatus(decision),
    'sourceMatrix': <String, dynamic>{
      'kind': EvalUseCaseTuningMatrix.kind,
      'schemaVersion': EvalUseCaseTuningMatrix.schemaVersion,
      'status': 'ready',
      'matrixDigest': _digest('matrix-${decision['scopeKey']}'),
      'contractIssueCount': 0,
      'inputReportDigestCount': 1,
      'sourceCheckedInputReportDigestCount': 1,
    },
    'sourceCampaign': <String, dynamic>{
      'present': true,
      'kind': EvalUseCaseTuningCampaign.kind,
      'schemaVersion': EvalUseCaseTuningCampaign.schemaVersion,
      'status': 'ready',
      'campaignRef': _digest('campaign-ref-${decision['scopeKey']}'),
      'campaignDigest': _digest('campaign-${decision['scopeKey']}'),
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
      'previousAcceptedDecisionCount': continuity.length,
      'rollbackRequiredCount': _decisionCount(continuity, 'rollbackRequired'),
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
    'previousDecisionContinuity': continuity,
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
  expect(EvalUseCaseTuningDecisionLedger.validate(ledger), isEmpty);
  return ledger;
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

Map<String, dynamic> _singleMap(Map<String, dynamic> root, String key) {
  final list = root[key] as List<dynamic>;
  expect(list, hasLength(1));
  return list.single as Map<String, dynamic>;
}

Map<String, dynamic> _runtimeRolloutLedger(
  Map<String, dynamic> releasePlan, {
  String resolutionStatus = 'applied',
  bool drift = false,
  Map<String, dynamic>? sourceRoadmap,
  List<Map<String, dynamic>> sourceDecisionLedgers = const [],
}) => _RuntimeRolloutLedgerFixture.build(
  releasePlan,
  resolutionStatus: resolutionStatus,
  drift: drift,
  sourceRoadmap: sourceRoadmap,
  sourceDecisionLedgers: sourceDecisionLedgers,
).ledger;

final class _RuntimeRolloutLedgerFixture {
  const _RuntimeRolloutLedgerFixture({
    required this.releaseReviewBundle,
    required this.releaseGate,
    required this.resolverPacket,
    required this.completedBindings,
    required this.resolverSnapshot,
    required this.verification,
    required this.ledger,
  });

  factory _RuntimeRolloutLedgerFixture.build(
    Map<String, dynamic> releasePlan, {
    String resolutionStatus = 'applied',
    bool drift = false,
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
  }) {
    final releaseReviewBundle = release_utils.buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
    );
    final releaseGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [releaseReviewBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 18),
    );
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      releaseReviewBundles: [releaseReviewBundle],
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      generatedAt: DateTime.utc(2026, 6, 13, 7),
    );
    final completedBindings = [
      for (final template
          in (packet['bindingTemplates'] as List<dynamic>)
              .cast<Map<String, dynamic>>())
        _completedRuntimeBinding(
          template,
          resolutionStatus: resolutionStatus,
          drift: drift,
        ),
    ];
    final snapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      completedBindings: completedBindings,
      runtimeObservationSource:
          EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
            resolverPacket: packet,
            mode: EvalUseCaseRuntimeResolverSnapshot
                .runtimeObservationModeManualCompletedBindingImport,
          ),
      capturedAt: DateTime.utc(2026, 6, 13, 7, 30),
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: snapshot,
      runtimeResolverPacket: packet,
      releaseReviewBundles: [releaseReviewBundle],
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      generatedAt: DateTime.utc(2026, 6, 13, 7, 45),
    );
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeVerifications: [verification],
      runtimeResolverSnapshots: [snapshot],
      runtimeResolverPackets: [packet],
      releaseReviewBundles: [releaseReviewBundle],
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    return _RuntimeRolloutLedgerFixture(
      releaseReviewBundle: releaseReviewBundle,
      releaseGate: releaseGate,
      resolverPacket: packet,
      completedBindings: completedBindings,
      resolverSnapshot: snapshot,
      verification: verification,
      ledger: ledger,
    );
  }

  final Map<String, dynamic> releaseReviewBundle;
  final Map<String, dynamic> releaseGate;
  final Map<String, dynamic> resolverPacket;
  final List<Map<String, dynamic>> completedBindings;
  final Map<String, dynamic> resolverSnapshot;
  final Map<String, dynamic> verification;
  final Map<String, dynamic> ledger;
}

Map<String, dynamic> _completedRuntimeBinding(
  Map<String, dynamic> template, {
  required String resolutionStatus,
  required bool drift,
}) {
  final assignmentRef = template['assignmentRef'] as String;
  final expected = <String, dynamic>{
    'resolvedProfileDigest': _digest('profile-$assignmentRef'),
    'providerModelBindingDigest': _digest('provider-model-$assignmentRef'),
    'thinkingModelBindingDigest': _digest('thinking-model-$assignmentRef'),
    'promptVariantDigest': _digest('prompt-variant-$assignmentRef'),
    'promptDirectiveDigest': _digest('prompt-directive-$assignmentRef'),
  };
  final observed = {
    ...expected,
    if (drift)
      'promptDirectiveDigest': _digest(
        'changed-prompt-directive-$assignmentRef',
      ),
  };
  return <String, dynamic>{
    ...template,
    'status': 'resolved',
    'resolutionStatus': resolutionStatus,
    'runtimeTargetRef': _digest('runtime-target-$assignmentRef'),
    'expected': expected,
    'observed': observed,
    'privateRuntimeIds': <String, dynamic>{
      'agentId': 'agent-private-$assignmentRef',
      'templateId': 'template-private-$assignmentRef',
      'profileId': 'profile-private-$assignmentRef',
    },
  };
}

String _scopeKey({
  required String compatibilityKey,
  required String primaryCapabilityId,
  required String agentKind,
}) => EvalProvenance.digestJson(<String, dynamic>{
  'compatibilityKey': compatibilityKey,
  'primaryCapabilityId': primaryCapabilityId,
  'agentKind': agentKind,
});

String _digest(String value) => EvalProvenance.digestText(value);

Map<String, dynamic> _restampRoadmapSourceLedger(
  Map<String, dynamic> roadmap, {
  required Map<String, dynamic> replacementRoadmap,
}) {
  final forged = jsonDecode(jsonEncode(roadmap)) as Map<String, dynamic>;
  forged['sourceLedgers'] = replacementRoadmap['sourceLedgers'];
  final scopes = (forged['scopes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final replacementScopes = (replacementRoadmap['scopes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final (index, scope) in scopes.indexed) {
    final replacementScope = replacementScopes[index];
    scope['sourceLedgerRefs'] = replacementScope['sourceLedgerRefs'];
    final choices = (scope['acceptedChoices'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final replacementChoices =
        (replacementScope['acceptedChoices'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
    for (final (choiceIndex, choice) in choices.indexed) {
      choice['sourceLedgerRefs'] =
          replacementChoices[choiceIndex]['sourceLedgerRefs'];
    }
  }
  return forged;
}

Map<String, dynamic> _restampReleasePlanAssignmentProof(
  Map<String, dynamic> releasePlan, {
  required String modelClassCoverageRef,
}) {
  final forged = jsonDecode(jsonEncode(releasePlan)) as Map<String, dynamic>;
  final sourceRoadmapDigest = _string(
    _mapValue(forged['sourceRoadmap'])['roadmapDigest'],
  );
  final assignment =
      (forged['runtimeAssignments'] as List<dynamic>).single
            as Map<String, dynamic>
        ..['modelClassCoverageRef'] = modelClassCoverageRef;
  final assignmentRef = EvalProvenance.digestJson(
    _assignmentDigestSubject(
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
    for (final entry in _mapList(forged['runtimeAssignments']))
      _assignmentProofSummary(entry),
  ];
  final proofSummaryDigest = EvalProvenance.digestJson(proofEntries);
  proofSummary
    ..['status'] = proofEntries.isEmpty ? 'empty' : 'ready'
    ..['assignmentCount'] = proofEntries.length
    ..['proofSummaryDigest'] = proofSummaryDigest
    ..['entries'] = proofEntries;

  _restampReleaseReviewQueue(
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

void _restampReleaseReviewQueue(
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
  for (final task in _mapList(queue['tasks'])) {
    final category = _string(task['category']);
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
  for (final template in _mapList(queue['attestationTemplates'])) {
    final category = _string(template['category']);
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

Map<String, dynamic> _assignmentDigestSubject(
  Map<String, dynamic> assignment, {
  required String sourceRoadmapDigest,
}) => <String, dynamic>{
  'sourceRoadmapDigest': sourceRoadmapDigest,
  'scopeKey': _string(assignment['scopeKey']),
  'acceptedCellKey': _string(assignment['acceptedCellKey']),
  'reportDigest': _string(assignment['reportDigest']),
  'modelClassCoverageProofRef': _string(
    assignment['modelClassCoverageProofRef'],
  ),
  'workOrderBatchRef': _string(assignment['workOrderBatchRef']),
  'modelClassCoverageRef': _string(assignment['modelClassCoverageRef']),
  'modelClassCoverageClassRef': _string(
    assignment['modelClassCoverageClassRef'],
  ),
  'modelClassCoverageDigest': _string(assignment['modelClassCoverageDigest']),
  'sourceWorkOrderDigest': _string(assignment['sourceWorkOrderDigest']),
  'modelClass': _string(assignment['modelClass']),
  'promptVariantName': _string(assignment['promptVariantName']),
};

Map<String, dynamic> _assignmentProofSummary(
  Map<String, dynamic> assignment,
) => <String, dynamic>{
  'assignmentRef': _string(assignment['assignmentRef']),
  'scopeKey': _string(assignment['scopeKey']),
  'primaryCapabilityId': _string(assignment['primaryCapabilityId']),
  'agentKind': _string(assignment['agentKind']),
  'modelClass': _string(assignment['modelClass']),
  'promptVariantName': _string(assignment['promptVariantName']),
  'acceptedCellKey': _string(assignment['acceptedCellKey']),
  'reportDigest': _string(assignment['reportDigest']),
  'modelClassCoverageProofRef': _string(
    assignment['modelClassCoverageProofRef'],
  ),
  'workOrderBatchRef': _string(assignment['workOrderBatchRef']),
  'modelClassCoverageRef': _string(assignment['modelClassCoverageRef']),
  'modelClassCoverageClassRef': _string(
    assignment['modelClassCoverageClassRef'],
  ),
  'modelClassCoverageDigest': _string(assignment['modelClassCoverageDigest']),
  'sourceWorkOrderDigest': _string(assignment['sourceWorkOrderDigest']),
};

Map<String, dynamic> _retargetCoverageProof(
  Map<String, dynamic> proof, {
  required String sourceWorkOrderDigest,
}) {
  final proofSource = <String, dynamic>{
    'compatibilityKey': proof['compatibilityKey'],
    'primaryCapabilityId': proof['primaryCapabilityId'],
    'modelClass': proof['modelClass'],
    'promptVariantName': proof['promptVariantName'],
    'reportDigest': proof['reportDigest'],
    'workOrderBatchRef': proof['workOrderBatchRef'],
    'modelClassCoverageRef': proof['modelClassCoverageRef'],
    'modelClassCoverageClassRef': proof['modelClassCoverageClassRef'],
    'modelClassCoverageDigest': proof['modelClassCoverageDigest'],
    'sourceWorkOrderDigest': sourceWorkOrderDigest,
  };
  return <String, dynamic>{
    ...proofSource,
    'proofRef': EvalProvenance.digestJson(proofSource),
  };
}

List<String> _stringList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      ]
    : const <String>[];

List<String> _sortedStrings(Iterable<String> values) =>
    values.where((value) => value.isNotEmpty).toSet().toList()..sort();

final class _ScopeFixture {
  const _ScopeFixture({
    required this.compatibilitySeed,
    required this.primaryCapabilityId,
    required this.modelClass,
    required this.promptVariantName,
    required this.cellSeed,
    required this.reportSeed,
  });

  final String compatibilitySeed;
  final String primaryCapabilityId;
  final String modelClass;
  final String promptVariantName;
  final String cellSeed;
  final String reportSeed;

  String get compatibilityKey => _digest(compatibilitySeed);

  String get scopeKey => _scopeKey(
    compatibilityKey: compatibilityKey,
    primaryCapabilityId: primaryCapabilityId,
    agentKind: agentKind,
  );

  String get cellKey => _digest(cellSeed);

  String get reportDigest => _digest(reportSeed);

  _ScopeFixture copyWith({
    String? compatibilitySeed,
    String? primaryCapabilityId,
    String? modelClass,
    String? promptVariantName,
    String? cellSeed,
    String? reportSeed,
  }) => _ScopeFixture(
    compatibilitySeed: compatibilitySeed ?? this.compatibilitySeed,
    primaryCapabilityId: primaryCapabilityId ?? this.primaryCapabilityId,
    modelClass: modelClass ?? this.modelClass,
    promptVariantName: promptVariantName ?? this.promptVariantName,
    cellSeed: cellSeed ?? this.cellSeed,
    reportSeed: reportSeed ?? this.reportSeed,
  );

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

  Map<String, dynamic> blockedDecision({
    List<String> blockerCodes = const ['verdict.missing'],
  }) => <String, dynamic>{
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
        blockingReasonCodes: blockerCodes,
      ),
    ],
    'blockerCodes': blockerCodes,
    'nextAction': 'continueEvidenceCollection',
  };

  Map<String, dynamic> rollbackContinuity() => <String, dynamic>{
    'scopeKey': scopeKey,
    'previousAcceptedCellKey': cellKey,
    'currentDecisionStatus': 'blocked',
    'status': 'rollbackRequired',
    'blockerCodes': const ['decision.previousAcceptedBlocked'],
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
      'workOrderBatchRef': _digest('work-order-batch-$cellSeed'),
      'modelClassCoverageRef': _digest('coverage-ref-$cellSeed'),
      'modelClassCoverageClassRef': _digest(
        'coverage-class-$cellSeed-$modelClass',
      ),
      'modelClassCoverageDigest': _digest('coverage-$cellSeed'),
      'sourceWorkOrderDigest': _digest('source-work-order-$cellSeed'),
    };
    return <String, dynamic>{
      ...proofSource,
      'proofRef': EvalProvenance.digestJson(proofSource),
    };
  }
}

String get agentKind => 'taskAgent';
