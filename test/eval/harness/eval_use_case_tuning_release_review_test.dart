import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_decision_ledger_source_replay_test_utils.dart';
import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_tuning_source_replay_test_utils.dart';
import 'eval_use_case_runtime_source_replay_test_utils.dart' as source_replay;
import 'eval_use_case_tuning_release_test_utils.dart';

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
const _releaseReviewSourcePath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_SOURCE',
);
const _releaseReviewSourceRoadmapPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_ROADMAP_INPUT',
);
const _releaseReviewSourceDecisionLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_DECISION_LEDGERS',
);
const _releaseReviewDecisionLedgerSourceManifestPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS',
);
const _releaseReviewPreviousReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_PREVIOUS_RELEASE_PLAN',
);
const _releaseReviewRuntimeRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_ROLLOUT_LEDGERS',
);
const _releaseReviewRuntimePreviousRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_PREVIOUS_ROLLOUT_LEDGERS',
);
const _releaseReviewRuntimeLedgerReleaseGatePaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_RELEASE_GATES',
);
const _releaseReviewRuntimeLedgerReleaseReviewAttestations =
    String.fromEnvironment(
      'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS',
    );
const _releaseReviewRuntimeVerificationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_VERIFICATIONS',
);
const _releaseReviewRuntimeLedgerResolverSnapshotPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS',
);
const _releaseReviewRuntimeLedgerResolverPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_RESOLVER_PACKETS',
);
const _releaseReviewRuntimeLedgerLocatorPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_LOCATOR_PACKETS',
);
const _releaseReviewRuntimeLedgerResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_RESOLVER_INPUTS',
);
const _releaseReviewRuntimeLedgerDirectObservationPaths =
    String.fromEnvironment(
      'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_DIRECT_OBSERVATIONS',
    );
const _releaseReviewRuntimeLedgerStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_LEDGER_STATE_INPUTS',
);
const _releaseReviewPacketPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_PACKET',
);
const _releaseReviewPacketOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_PACKET_OVERWRITE',
);
const _releaseReviewInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_INPUT',
);
const _releaseReviewAttestationsPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_ATTESTATIONS',
);
const _releaseReviewAttestationsOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_REVIEW_ATTESTATIONS_OVERWRITE',
);

void main() {
  test('builds a pending release review packet from every required task', () {
    final releasePlan = buildReleasePlanFixture();

    final packet = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: releasePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(EvalUseCaseTuningReleaseReview.validatePacket(packet), isEmpty);
    expect(packet['status'], 'readyForReview');
    expect(
      packet['releaseReviewPacketRef'],
      EvalUseCaseTuningReleaseReview.releaseReviewPacketRef(packet),
    );
    final packetRef = packet['releaseReviewPacketRef'];
    final source = packet['sourceReleasePlan'] as Map<String, dynamic>;
    expect(source['releasePlanRef'], releasePlan['releasePlanRef']);
    expect(source['sourceReleaseReviewPacketRef'], packetRef);
    expect(
      source['sourceRoadmapDigest'],
      sourceRoadmapDigestFixture(releasePlan),
    );
    expect(source['sourceQueueDigest'], isA<String>());
    final queue = releasePlan['releaseReviewQueue'] as Map<String, dynamic>;
    final sourceTasks = (queue['tasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final tasks = (packet['reviewTasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(tasks, hasLength(sourceTasks.length));
    expect(tasks.map((task) => task['reviewRef']).toSet(), {
      for (final task in sourceTasks) task['reviewRef'],
    });
    expect(tasks.every((task) => task['assignmentRefsDigest'] is String), true);
    expect(
      tasks.every((task) => task['sourceReleaseReviewPacketRef'] == packetRef),
      true,
    );
    expect(
      tasks.every((task) => task['sourceReviewTaskDigest'] is String),
      true,
    );
    expect(
      tasks.every((task) => task['assignmentProofSummaryDigest'] is String),
      true,
    );
    expect(
      tasks.every(
        (task) => task['modelClassCoverageProofSummaryDigest'] is String,
      ),
      true,
    );
    final templates = (packet['attestationTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(templates, hasLength(tasks.length));
    expect(
      templates.every(
        (template) => template['sourceReleaseReviewPacketRef'] == packetRef,
      ),
      true,
    );
    expect(
      templates.every(
        (template) => template['sourceReviewTaskDigest'] is String,
      ),
      true,
    );
    expect(
      templates.every(
        (template) => template['assignmentProofSummaryDigest'] is String,
      ),
      true,
    );
    expect(
      templates.every(
        (template) =>
            template['modelClassCoverageProofSummaryDigest'] is String,
      ),
      true,
    );
    expect(templates.map((template) => template['status']).toSet(), {
      'pending',
    });
    expect(templates.map((template) => template['evidenceDigest']).toSet(), {
      '',
    });
    expect(
      const JsonEncoder().convert(packet),
      allOf(
        isNot(contains('profile-frontier')),
        isNot(contains('scenario-task.workflow')),
        isNot(contains('TaskAgentService.updateAgentProfile')),
      ),
    );
  });

  test('imports approved release review attestations', () {
    final releasePlan = buildReleasePlanFixture();
    final attestations = approvedReleaseReviewAttestations(releasePlan);

    final bundle = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
      releasePlan: releasePlan,
      attestations: attestations,
      generatedAt: DateTime.utc(2026, 6, 12, 18),
    );

    expect(EvalUseCaseTuningReleaseReview.validateBundle(bundle), isEmpty);
    expect(bundle['status'], 'approved');
    expect(
      bundle['attestationBundleRef'],
      EvalUseCaseTuningReleaseReview.attestationBundleRef(bundle),
    );
    final summary = bundle['summary'] as Map<String, dynamic>;
    expect(summary['approvedAttestationCount'], attestations.length);
    expect(summary['issueCount'], 0);
    final source = bundle['sourceReleasePlan'] as Map<String, dynamic>;
    final sourcePacketRef = source['sourceReleaseReviewPacketRef'];
    expect(
      EvalUseCaseTuningReleaseReview.approvedAttestationsFromValidBundles([
        bundle,
      ]),
      hasLength(attestations.length),
    );
    final bundleAttestations = (bundle['attestations'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      bundleAttestations.every(
        (attestation) =>
            attestation['sourceReleaseReviewPacketRef'] == sourcePacketRef,
      ),
      true,
    );
    expect(
      bundleAttestations.every(
        (attestation) => attestation['sourceReviewTaskDigest'] is String,
      ),
      true,
    );
    expect(
      bundleAttestations.every(
        (attestation) =>
            attestation['evidenceDigest'] ==
            EvalUseCaseTuningReleaseReview.attestationEvidenceDigest(
              attestation,
            ),
      ),
      true,
    );
  });

  test('packet contract rejects stale release-review packet refs', () {
    final releasePlan = buildReleasePlanFixture();
    final packet = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: releasePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
    (tampered['sourceReleasePlan'] as Map<String, dynamic>)['status'] =
        'approvedForManualApply';

    final issues = EvalUseCaseTuningReleaseReview.validatePacket(tampered);

    expect(
      issues,
      contains(
        'releaseReviewPacketRef must match release review packet subject digest',
      ),
    );
  });

  test('source-aware packet build rejects restamped release plans', () {
    const fixture = ReleaseScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      agentKind: releaseFixtureAgentKind,
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = buildReleaseDecisionLedgerFixture(
      fixture.acceptedDecision(),
    );
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );
    final forged = restampReleasePlanAssignmentProofFixture(
      releasePlan,
      modelClassCoverageRef: digestFixture('forged-coverage-ref'),
    );

    expect(EvalUseCaseTuningReleasePlan.validate(forged), isEmpty);
    expect(
      EvalUseCaseTuningReleaseReview.buildPacket(
        releasePlan: forged,
        generatedAt: DateTime.utc(2026, 6, 12, 17),
      )['status'],
      'readyForReview',
    );

    final packet = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: forged,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(EvalUseCaseTuningReleaseReview.validatePacket(packet), isEmpty);
    expect(packet['status'], 'invalidReleasePlan');
    final source = packet['sourceReleasePlan'] as Map<String, dynamic>;
    expect(source['contractIssueCount'], greaterThan(0));
    expect(packet['reviewTasks'], isEmpty);
    expect(packet['attestationTemplates'], isEmpty);
  });

  test('source-aware packet build rejects serialized source ledgers', () {
    final sourceFixture = buildDecisionLedgerSourceBoundReleaseFixture();
    final replayedPacket = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: sourceFixture.releasePlan,
      sourceRoadmap: sourceFixture.roadmap,
      sourceDecisionLedgers: [sourceFixture.ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );
    final serializedLedger =
        jsonDecode(jsonEncode(sourceFixture.ledger)) as Map<String, dynamic>;

    final serializedPacket = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: sourceFixture.releasePlan,
      sourceRoadmap: sourceFixture.roadmap,
      sourceDecisionLedgers: [serializedLedger],
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );

    expect(
      EvalUseCaseTuningReleaseReview.validatePacket(replayedPacket),
      isEmpty,
    );
    expect(replayedPacket['status'], 'readyForReview');
    expect(serializedPacket['status'], 'invalidReleasePlan');
    final source =
        serializedPacket['sourceReleasePlan'] as Map<String, dynamic>;
    expect(source['contractIssueCount'], greaterThan(0));
    final issues = (serializedPacket['issues'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      issues,
      contains(
        containsPair(
          'message',
          'release plan must match source roadmap and ledgers',
        ),
      ),
    );
  });

  test(
    'source-aware packet build accepts source-replayed runtime continuity',
    () {
      final sourceFixture = buildDecisionLedgerSourceBoundReleaseFixture();
      final ledger = sourceFixture.ledger;
      final roadmap = sourceFixture.roadmap;
      final previousPlan = sourceFixture.releasePlan;
      final releaseReviewBundle = buildReleaseReviewBundleFixture(
        releasePlan: previousPlan,
      );
      final releaseGate = EvalUseCaseTuningReleaseGate.build(
        releasePlan: previousPlan,
        releaseReviewBundles: [releaseReviewBundle],
        generatedAt: DateTime.utc(2026, 6, 12, 19),
      );
      final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
        releasePlan: previousPlan,
        releaseGate: releaseGate,
        releaseReviewBundles: [releaseReviewBundle],
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 13, 7),
      );
      final completedBindings = _completedRuntimeBindings(resolverPacket);
      final resolverSnapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
        releasePlan: previousPlan,
        releaseGate: releaseGate,
        completedBindings: completedBindings,
        runtimeObservationSource:
            EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
              resolverPacket: resolverPacket,
              mode: EvalUseCaseRuntimeResolverSnapshot
                  .runtimeObservationModeManualCompletedBindingImport,
            ),
        capturedAt: DateTime.utc(2026, 6, 13, 7, 30),
      );
      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: previousPlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        runtimeResolverPacket: resolverPacket,
        releaseReviewBundles: [releaseReviewBundle],
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 13, 7, 45),
      );
      final runtimeLedger = EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: previousPlan,
        releaseGate: releaseGate,
        runtimeVerifications: [verification],
        runtimeResolverSnapshots: [resolverSnapshot],
        runtimeResolverPackets: [resolverPacket],
        releaseReviewBundles: [releaseReviewBundle],
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      );
      final replayedRuntimeLedger =
          jsonDecode(jsonEncode(runtimeLedger)) as Map<String, dynamic>;

      final artifactOnlyPlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        sourceRuntimeRolloutLedgers: [replayedRuntimeLedger],
        previousReleasePlan: previousPlan,
        requireDecisionLedgerSourceReplay: true,
        generatedAt: DateTime.utc(2026, 6, 13, 9),
      );
      expect(artifactOnlyPlan['status'], 'invalid');

      markRuntimeRolloutLedgerSourcesFixture(
        [replayedRuntimeLedger],
        previousPlan: previousPlan,
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        previousRuntimeRolloutLedgers: const [],
        releaseGates: [releaseGate],
        releaseReviewBundles: [releaseReviewBundle],
        runtimeVerifications: [verification],
        runtimeResolverSnapshots: [resolverSnapshot],
        runtimeResolverPackets: [resolverPacket],
        runtimeLocatorPackets: const [],
        completedBindingSources: [completedBindings],
        directObservationSources: const [],
        privateRuntimeStates: const [],
      );
      final releasePlan = EvalUseCaseTuningReleasePlan.build(
        roadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        sourceRuntimeRolloutLedgers: [replayedRuntimeLedger],
        previousReleasePlan: previousPlan,
        requireDecisionLedgerSourceReplay: true,
        generatedAt: DateTime.utc(2026, 6, 13, 9),
      );

      expect(EvalUseCaseTuningReleasePlan.validate(releasePlan), isEmpty);
      expect(releasePlan['status'], 'readyForReleaseReview');

      final packet = EvalUseCaseTuningReleaseReview.buildPacket(
        releasePlan: releasePlan,
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        sourceRuntimeRolloutLedgers: [replayedRuntimeLedger],
        previousReleasePlan: previousPlan,
        generatedAt: DateTime.utc(2026, 6, 13, 10),
      );

      expect(EvalUseCaseTuningReleaseReview.validatePacket(packet), isEmpty);
      expect(packet['status'], 'readyForReview');
      expect(packet['reviewTasks'] as List<dynamic>, isNotEmpty);
    },
  );

  test('bundle contract rejects stale release-review bundle refs', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
      releasePlan: releasePlan,
      attestations: approvedReleaseReviewAttestations(releasePlan),
      generatedAt: DateTime.utc(2026, 6, 12, 18),
    );
    final tampered = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
    (tampered['sourceReleasePlan'] as Map<String, dynamic>)['status'] =
        'readyForRuntimeResolution';

    final issues = EvalUseCaseTuningReleaseReview.validateBundle(tampered);

    expect(
      issues,
      contains(
        'attestationBundleRef must match release review bundle subject digest',
      ),
    );
  });

  test(
    'source-aware bundle validation rejects restamped release plan summary',
    () {
      final releasePlan = buildReleasePlanFixture();
      final bundle = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
        releasePlan: releasePlan,
        attestations: approvedReleaseReviewAttestations(releasePlan),
        generatedAt: DateTime.utc(2026, 6, 12, 18),
      );
      final restamped = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
      (restamped['sourceReleasePlan'] as Map<String, dynamic>)
        ..['status'] = 'readyForReleaseReview'
        ..['releasePlanRef'] = digestFixture('forged-release-plan-ref')
        ..['contractIssueCount'] = 0
        ..['assignmentCount'] = 42
        ..['reviewTaskCount'] = 99;
      restamped['attestationBundleRef'] =
          EvalUseCaseTuningReleaseReview.attestationBundleRef(restamped);

      expect(EvalUseCaseTuningReleaseReview.validateBundle(restamped), isEmpty);

      final issues =
          EvalUseCaseTuningReleaseReview.validateBundleAgainstReleasePlan(
            restamped,
            releasePlan: releasePlan,
          );

      expect(
        issues,
        contains('sourceReleasePlan.releasePlanRef must match releasePlan'),
      );
      expect(
        issues,
        contains('sourceReleasePlan.assignmentCount must match releasePlan'),
      );
      expect(
        issues,
        contains('sourceReleasePlan.reviewTaskCount must match releasePlan'),
      );
    },
  );

  test('source-aware bundle import rejects restamped release plans', () {
    const fixture = ReleaseScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      agentKind: releaseFixtureAgentKind,
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = buildReleaseDecisionLedgerFixture(
      fixture.acceptedDecision(),
    );
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 15),
    );
    final releasePlan = EvalUseCaseTuningReleasePlan.build(
      roadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 16),
    );
    final forged = restampReleasePlanAssignmentProofFixture(
      releasePlan,
      modelClassCoverageRef: digestFixture('forged-coverage-ref'),
    );
    final forgedAttestations = approvedReleaseReviewAttestations(forged);

    final localBundle = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
      releasePlan: forged,
      attestations: forgedAttestations,
      generatedAt: DateTime.utc(2026, 6, 12, 18),
    );
    expect(localBundle['status'], 'approved');

    expect(
      () => EvalUseCaseTuningReleaseReview.buildAttestationBundle(
        releasePlan: forged,
        attestations: forgedAttestations,
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
        generatedAt: DateTime.utc(2026, 6, 12, 18),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'attestations[0].sourceReleaseReviewPacketRef must match '
            'sourceReleasePlan.sourceReleaseReviewPacketRef',
          ),
        ),
      ),
    );
  });

  test('packet contract rejects tampered review task refs and digests', () {
    final releasePlan = buildReleasePlanFixture();
    final packet = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: releasePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
    ((tampered['reviewTasks'] as List<dynamic>).first as Map<String, dynamic>)
      ..['sourceReleasePlanDigest'] = digestFixture(
        'wrong-review-task-source',
      )
      ..['assignmentRefs'] = [digestFixture('wrong-review-assignment-ref')]
      ..['assignmentRefsDigest'] = digestFixture(
        'wrong-review-assignment-set',
      )
      ..['reviewRef'] = digestFixture('wrong-review-task-ref');

    final issues = EvalUseCaseTuningReleaseReview.validatePacket(tampered);

    expect(
      issues,
      contains(
        'reviewTasks[0].sourceReleasePlanDigest must match sourceReleasePlan.releasePlanDigest',
      ),
    );
    expect(
      issues,
      contains('reviewTasks[0].assignmentRefsDigest must match assignmentRefs'),
    );
    expect(
      issues,
      contains('reviewTasks[0].reviewRef must match review subject digest'),
    );
    expect(
      issues,
      contains('attestationTemplates[0] must match a review task'),
    );
  });

  test('bundle contract rejects tampered required review tasks', () {
    final releasePlan = buildReleasePlanFixture();
    final attestations = approvedReleaseReviewAttestations(releasePlan);
    final bundle = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
      releasePlan: releasePlan,
      attestations: attestations,
      generatedAt: DateTime.utc(2026, 6, 12, 18),
    );
    final tampered = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
    final task =
        (tampered['requiredReviewTasks'] as List<dynamic>).first
            as Map<String, dynamic>;

    task['reviewRef'] = digestFixture('wrong-required-review-task-ref');

    final issues = EvalUseCaseTuningReleaseReview.validateBundle(tampered);

    expect(
      issues,
      contains(
        'requiredReviewTasks[0].reviewRef must match review subject digest',
      ),
    );
    expect(issues, contains('attestations[0] must match a review task'));
  });

  test(
    'rejects stale, pending, duplicate, and mismatched release attestations',
    () {
      final releasePlan = buildReleasePlanFixture();
      final approved = approvedReleaseReviewAttestations(releasePlan);
      final wrongCategory = differentReleaseReviewCategory(
        approved.first['category'] as String,
      );

      for (final scenario in <String, List<Map<String, dynamic>>>{
        'stale source digest': [
          {
            ...approved.first,
            'sourceReleasePlanDigest': digestFixture('wrong-source'),
          },
          ...approved.skip(1),
        ],
        'stale queue digest': [
          {
            ...approved.first,
            'sourceQueueDigest': digestFixture('wrong-queue'),
          },
          ...approved.skip(1),
        ],
        'stale packet ref': [
          {
            ...approved.first,
            'sourceReleaseReviewPacketRef': digestFixture('wrong-packet'),
          },
          ...approved.skip(1),
        ],
        'stale review task digest': [
          {
            ...approved.first,
            'sourceReviewTaskDigest': digestFixture('wrong-review-task'),
          },
          ...approved.skip(1),
        ],
        'wrong review ref': [
          {...approved.first, 'reviewRef': digestFixture('wrong-review-ref')},
          ...approved.skip(1),
        ],
        'wrong category': [
          {...approved.first, 'category': wrongCategory},
          ...approved.skip(1),
        ],
        'wrong assignment refs': [
          {
            ...approved.first,
            'assignmentRefsDigest': digestFixture('wrong-assignment-set'),
          },
          ...approved.skip(1),
        ],
        'wrong assignment proof summary': [
          {
            ...approved.first,
            'assignmentProofSummaryDigest': digestFixture(
              'wrong-assignment-proof-summary',
            ),
          },
          ...approved.skip(1),
        ],
        'wrong model-class coverage proof summary': [
          {
            ...approved.first,
            'assignmentProofSummaryDigest': digestFixture(
              'wrong-model-class-coverage-proof-summary',
            ),
            'modelClassCoverageProofSummaryDigest': digestFixture(
              'wrong-model-class-coverage-proof-summary',
            ),
          },
          ...approved.skip(1),
        ],
        'wrong evidence digest': [
          {
            ...approved.first,
            'evidenceDigest': digestFixture('wrong-review-evidence'),
          },
          ...approved.skip(1),
        ],
        'wrong reviewer digest': [
          {
            ...approved.first,
            'reviewerRefDigest': digestFixture('wrong-release-reviewer'),
          },
          ...approved.skip(1),
        ],
        'wrong reviewed timestamp': [
          {
            ...approved.first,
            'reviewedAt': DateTime.utc(2026, 6, 12, 18).toIso8601String(),
          },
          ...approved.skip(1),
        ],
        'pending templates': releaseReviewPacketTemplates(releasePlan),
        'missing task': [...approved.skip(1)],
        'duplicate task': [...approved, approved.first],
        'unmatched extra task': [
          ...approved,
          {
            ...approved.first,
            'reviewRef': digestFixture('extra-review-ref'),
            'assignmentRefsDigest': digestFixture('extra-assignment-set'),
            'assignmentProofSummaryDigest': digestFixture(
              'extra-assignment-proof-summary',
            ),
            'modelClassCoverageProofSummaryDigest': digestFixture(
              'extra-assignment-proof-summary',
            ),
          },
        ],
      }.entries) {
        expect(
          () => EvalUseCaseTuningReleaseReview.buildAttestationBundle(
            releasePlan: releasePlan,
            attestations: scenario.value,
            generatedAt: DateTime.utc(2026, 6, 12, 18),
          ),
          throwsStateError,
          reason: scenario.key,
        );
      }
    },
  );

  test('rejects restamped attestations without source packet provenance', () {
    final sourcePlan = buildReleasePlanFixture();
    final targetPlan = buildReleasePlanFixture(
      compatibilitySeed: 'target-task-compat',
      modelClass: 'localPrecise',
      promptVariantName: 'compact-v1',
      cellSeed: 'target-task-local',
      reportSeed: 'target-task-report',
    );
    final sourceApproved = approvedReleaseReviewAttestations(sourcePlan);
    final targetTemplates = releaseReviewPacketTemplates(targetPlan);
    final restamped = [
      for (final indexed in sourceApproved.indexed)
        _restampReleaseReviewAttestation(
          indexed.$2,
          targetTemplate: targetTemplates[indexed.$1],
        ),
    ];

    expect(
      () => EvalUseCaseTuningReleaseReview.buildAttestationBundle(
        releasePlan: targetPlan,
        attestations: restamped,
        generatedAt: DateTime.utc(2026, 6, 12, 18),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'attestations[0].sourceReleaseReviewPacketRef must match '
            'sourceReleasePlan.sourceReleaseReviewPacketRef',
          ),
        ),
      ),
    );
  });

  test('rejected release reviews do not become approval evidence', () {
    final releasePlan = buildReleasePlanFixture();
    final rejected = [
      for (final attestation in approvedReleaseReviewAttestations(releasePlan))
        releaseReviewAttestationWithStatus(
          attestation,
          attestation['category'] == 'privacyAudit'
              ? 'needsChanges'
              : 'rejected',
        ),
    ];

    final bundle = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
      releasePlan: releasePlan,
      attestations: rejected,
      generatedAt: DateTime.utc(2026, 6, 12, 18),
    );

    expect(bundle['status'], 'changesRequested');
    expect(
      EvalUseCaseTuningReleaseReview.approvedAttestationsFromBundles([bundle]),
      isEmpty,
    );

    final mixed = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
      releasePlan: releasePlan,
      attestations: [
        releaseReviewAttestationWithStatus(
          approvedReleaseReviewAttestations(releasePlan).first,
          'needsChanges',
        ),
        ...approvedReleaseReviewAttestations(releasePlan).skip(1),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 18, 30),
    );

    expect(mixed['status'], 'changesRequested');
    expect(
      EvalUseCaseTuningReleaseReview.approvedAttestationsFromBundles([mixed]),
      isEmpty,
    );
  });

  test('non-ready release plans cannot be approved', () {
    final blockedPlan = buildReleasePlanFixture(accepted: false);

    expect(
      () => EvalUseCaseTuningReleaseReview.buildAttestationBundle(
        releasePlan: blockedPlan,
        attestations: const [],
        generatedAt: DateTime.utc(2026, 6, 12, 18),
      ),
      throwsStateError,
    );
  });

  test('contract rejects private ids, paths, env keys, and commands', () {
    final releasePlan = buildReleasePlanFixture();
    final packet = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: releasePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 17),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>
      ..['profileId'] = 'private-profile-id';
    ((tampered['reviewTasks'] as List<dynamic>).first as Map<String, dynamic>)
      ..['agentId'] = 'private-agent-id'
      ..['notes'] =
          'Read file:///private/tmp/plan.json and run fvm dart analyze with EVAL_USE_CASE_RELEASE_PLAN.';
    (tampered['recommendedCommands'] as List<dynamic>).add(
      const <String, dynamic>{
        'mode': 'mutate',
        'command': 'fvm flutter test eval/run_level2.sh run',
        'env': {'EVAL_USE_CASE_RELEASE_REVIEW_SOURCE': '/private/tmp/source'},
      },
    );
    ((tampered['attestationTemplates'] as List<dynamic>).first
          as Map<String, dynamic>)
      ..['reviewer'] = 'alice'
      ..['command'] = 'TaskAgentService.updateAgentProfile';

    final issues = EvalUseCaseTuningReleaseReview.validatePacket(tampered);

    expect(
      issues,
      contains('packet.profileId must not expose private runtime ids'),
    );
    expect(
      issues,
      contains(
        'packet.reviewTasks[0].agentId must not expose private runtime ids',
      ),
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
        'packet.reviewTasks[0].notes must not contain mutation commands',
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
        'recommendedCommands[3].command must not recommend live run commands',
      ),
    );
    expect(
      issues,
      contains(
        'recommendedCommands[3].command must not recommend mutation commands',
      ),
    );
    expect(
      issues,
      contains('recommendedCommands[3] must not contain env values'),
    );
  });

  test(
    'writes use-case tuning release review packet',
    () async {
      final releasePlan =
          jsonDecode(File(_releaseReviewSourcePath).readAsStringSync())
              as Map<String, dynamic>;
      final sourceInputs = await _readReleasePlanSourceInputs();
      final packet = EvalUseCaseTuningReleaseReview.buildPacket(
        releasePlan: releasePlan,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      EvalUseCaseTuningReleaseReview.assertValidPacket(packet);
      writeEvalJsonArtifact(
        packet,
        path: _releaseReviewPacketPath,
        overwrite: _releaseReviewPacketOverwrite == '1',
        description: 'use-case tuning release review packet',
      );
    },
    skip:
        _releaseReviewSourcePath.isEmpty ||
            _releaseReviewSourceRoadmapPath.isEmpty ||
            _releaseReviewSourceDecisionLedgerPaths.isEmpty ||
            _releaseReviewDecisionLedgerSourceManifestPaths.isEmpty ||
            _releaseReviewPacketPath.isEmpty
        ? 'Set EVAL_USE_CASE_RELEASE_REVIEW_SOURCE=<json>, '
              'EVAL_USE_CASE_RELEASE_REVIEW_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RELEASE_REVIEW_DECISION_LEDGERS=<json>, and '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json> to '
              'source-replay decision ledgers, and '
              'EVAL_USE_CASE_RELEASE_REVIEW_PACKET=<json> to write a packet.'
        : false,
  );

  test(
    'writes use-case tuning release review attestation bundle',
    () async {
      final releasePlan =
          jsonDecode(File(_releaseReviewSourcePath).readAsStringSync())
              as Map<String, dynamic>;
      final attestations = _readJsonList(_releaseReviewInputPath);
      final sourceInputs = await _readReleasePlanSourceInputs();
      final bundle = EvalUseCaseTuningReleaseReview.buildAttestationBundle(
        releasePlan: releasePlan,
        attestations: attestations,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      EvalUseCaseTuningReleaseReview.assertValidBundle(bundle);
      writeEvalJsonArtifact(
        bundle,
        path: _releaseReviewAttestationsPath,
        overwrite: _releaseReviewAttestationsOverwrite == '1',
        description: 'use-case tuning release review attestation bundle',
      );
    },
    skip:
        _releaseReviewSourcePath.isEmpty ||
            _releaseReviewSourceRoadmapPath.isEmpty ||
            _releaseReviewSourceDecisionLedgerPaths.isEmpty ||
            _releaseReviewDecisionLedgerSourceManifestPaths.isEmpty ||
            _releaseReviewInputPath.isEmpty ||
            _releaseReviewAttestationsPath.isEmpty
        ? 'Set EVAL_USE_CASE_RELEASE_REVIEW_SOURCE=<json>, '
              'EVAL_USE_CASE_RELEASE_REVIEW_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RELEASE_REVIEW_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RELEASE_REVIEW_INPUT=<json>, and '
              'EVAL_USE_CASE_RELEASE_REVIEW_ATTESTATIONS=<json> to write a bundle.'
        : false,
  );
}

List<Map<String, dynamic>> _readJsonList(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is List) {
    return [for (final item in decoded) item as Map<String, dynamic>];
  }
  if (decoded is Map<String, dynamic>) {
    if (decoded['kind'] == EvalUseCaseTuningReleaseReview.packetKind) {
      return (decoded['attestationTemplates'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    if (decoded['kind'] == EvalUseCaseTuningReleaseReview.bundleKind) {
      return (decoded['attestations'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    return [decoded];
  }
  throw StateError('Expected release review input JSON object or list.');
}

Map<String, dynamic>? _readOptionalJsonMap(String path) {
  if (path.trim().isEmpty) {
    return null;
  }
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw StateError('Expected release review source JSON object.');
}

List<Map<String, dynamic>> _readJsonListOrEmpty(String paths) {
  if (paths.trim().isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  return [
    for (final path in paths.split(','))
      if (path.trim().isNotEmpty) ..._readJsonList(path.trim()),
  ];
}

Future<_ReleasePlanSourceInputs> _readReleasePlanSourceInputs() async {
  final previousReleasePlan = _readOptionalJsonMap(
    _releaseReviewPreviousReleasePlanPath,
  );
  final roadmap = _readOptionalJsonMap(_releaseReviewSourceRoadmapPath);
  final sourceDecisionLedgers = _readJsonListOrEmpty(
    _releaseReviewSourceDecisionLedgerPaths,
  );
  final decisionLedgers =
      _releaseReviewDecisionLedgerSourceManifestPaths.trim().isEmpty
      ? sourceDecisionLedgers
      : await evalReplayDecisionLedgerSourceManifests(
          ledgers: sourceDecisionLedgers,
          manifests: evalReadDecisionLedgerSourceManifestFiles(
            _releaseReviewDecisionLedgerSourceManifestPaths,
          ),
          config: _sourceReplayConfig(),
        );
  final runtimeRolloutLedgers = _readJsonListOrEmpty(
    _releaseReviewRuntimeRolloutLedgerPaths,
  );
  if (runtimeRolloutLedgers.isNotEmpty) {
    final previousPlan = previousReleasePlan;
    if (previousPlan == null) {
      throw StateError(
        'EVAL_USE_CASE_RELEASE_REVIEW_PREVIOUS_RELEASE_PLAN is required '
        'with EVAL_USE_CASE_RELEASE_REVIEW_RUNTIME_ROLLOUT_LEDGERS.',
      );
    }
    markRuntimeRolloutLedgerSourcesFixture(
      runtimeRolloutLedgers,
      previousPlan: previousPlan,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: decisionLedgers,
      previousRuntimeRolloutLedgers: _readJsonListOrEmpty(
        _releaseReviewRuntimePreviousRolloutLedgerPaths,
      ),
      releaseGates: _readJsonListOrEmpty(
        _releaseReviewRuntimeLedgerReleaseGatePaths,
      ),
      releaseReviewBundles: readReleaseReviewBundlesFixture(
        _releaseReviewRuntimeLedgerReleaseReviewAttestations,
      ),
      runtimeVerifications: _readJsonListOrEmpty(
        _releaseReviewRuntimeVerificationPaths,
      ),
      runtimeResolverSnapshots: _readJsonListOrEmpty(
        _releaseReviewRuntimeLedgerResolverSnapshotPaths,
      ),
      runtimeResolverPackets: _readJsonListOrEmpty(
        _releaseReviewRuntimeLedgerResolverPacketPaths,
      ),
      runtimeLocatorPackets: _readJsonListOrEmpty(
        _releaseReviewRuntimeLedgerLocatorPacketPaths,
      ),
      completedBindingSources: source_replay.readCompletedBindingSources(
        _releaseReviewRuntimeLedgerResolverInputPaths,
      ),
      directObservationSources: source_replay.readDirectObservationSources(
        _releaseReviewRuntimeLedgerDirectObservationPaths,
      ),
      privateRuntimeStates: source_replay.readJsonObjects(
        _releaseReviewRuntimeLedgerStateInputPaths,
      ),
    );
  }
  return _ReleasePlanSourceInputs(
    roadmap: roadmap,
    decisionLedgers: decisionLedgers,
    previousReleasePlan: previousReleasePlan,
    runtimeRolloutLedgers: runtimeRolloutLedgers,
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

final class _ReleasePlanSourceInputs {
  const _ReleasePlanSourceInputs({
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

List<Map<String, dynamic>> _completedRuntimeBindings(
  Map<String, dynamic> resolverPacket,
) {
  return [
    for (final template
        in (resolverPacket['bindingTemplates'] as List<dynamic>)
            .cast<Map<String, dynamic>>())
      _completedRuntimeBinding(template),
  ];
}

Map<String, dynamic> _completedRuntimeBinding(
  Map<String, dynamic> template,
) {
  final assignmentRef = template['assignmentRef'] as String;
  final expected = <String, dynamic>{
    'resolvedProfileDigest': digestFixture('profile-$assignmentRef'),
    'providerModelBindingDigest': digestFixture(
      'provider-model-$assignmentRef',
    ),
    'thinkingModelBindingDigest': digestFixture(
      'thinking-model-$assignmentRef',
    ),
    'promptVariantDigest': digestFixture('prompt-variant-$assignmentRef'),
    'promptDirectiveDigest': digestFixture('prompt-directive-$assignmentRef'),
  };
  return <String, dynamic>{
    ...template,
    'status': 'resolved',
    'resolutionStatus': 'applied',
    'runtimeTargetRef': digestFixture('runtime-target-$assignmentRef'),
    'expected': expected,
    'observed': expected,
    'privateRuntimeIds': <String, dynamic>{
      'agentId': 'agent-private-$assignmentRef',
      'templateId': 'template-private-$assignmentRef',
      'profileId': 'profile-private-$assignmentRef',
    },
  };
}

Map<String, dynamic> _restampReleaseReviewAttestation(
  Map<String, dynamic> sourceAttestation, {
  required Map<String, dynamic> targetTemplate,
}) {
  final restamped = <String, dynamic>{
    ...targetTemplate,
    'sourceReleaseReviewPacketRef':
        sourceAttestation['sourceReleaseReviewPacketRef'],
    'sourceReviewTaskDigest': sourceAttestation['sourceReviewTaskDigest'],
    'status': sourceAttestation['status'],
    'reviewerRefDigest': sourceAttestation['reviewerRefDigest'],
    'reviewedAt': sourceAttestation['reviewedAt'],
  };
  return <String, dynamic>{
    ...restamped,
    'evidenceDigest': EvalUseCaseTuningReleaseReview.attestationEvidenceDigest(
      restamped,
    ),
  };
}
