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
const _releaseGatePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_PLAN_INPUT',
);
const _releaseGateRoadmapInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_ROADMAP_INPUT',
);
const _releaseGateDecisionLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_DECISION_LEDGERS',
);
const _releaseGateDecisionLedgerSourceManifestPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS',
);
const _releaseGatePreviousReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_PREVIOUS_RELEASE_PLAN',
);
const _releaseGateRuntimeRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_ROLLOUT_LEDGERS',
);
const _releaseGateRuntimePreviousRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_PREVIOUS_ROLLOUT_LEDGERS',
);
const _releaseGateRuntimeLedgerReleaseGatePaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_RELEASE_GATES',
);
const _releaseGateRuntimeLedgerReleaseReviewAttestations =
    String.fromEnvironment(
      'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS',
    );
const _releaseGateRuntimeVerificationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_VERIFICATIONS',
);
const _releaseGateRuntimeLedgerResolverSnapshotPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS',
);
const _releaseGateRuntimeLedgerResolverPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_RESOLVER_PACKETS',
);
const _releaseGateRuntimeLedgerLocatorPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_LOCATOR_PACKETS',
);
const _releaseGateRuntimeLedgerResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_RESOLVER_INPUTS',
);
const _releaseGateRuntimeLedgerDirectObservationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_DIRECT_OBSERVATIONS',
);
const _releaseGateRuntimeLedgerStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_RUNTIME_LEDGER_STATE_INPUTS',
);
const _releaseGateReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_REVIEW_ATTESTATIONS',
);
const _releaseGateOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE',
);
const _releaseGateOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RELEASE_GATE_OVERWRITE',
);

void main() {
  test('approves a ready release plan with exact approved review coverage', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(EvalUseCaseTuningReleaseGate.validate(gate), isEmpty);
    expect(
      EvalUseCaseTuningReleaseGate.validateAgainstReleasePlan(
        gate,
        releasePlan: releasePlan,
      ),
      isEmpty,
    );
    expect(gate['status'], 'approvedForManualApply');
    expect(gate['releaseGateRef'], releaseGateRefFixture(gate));
    final sourceBundle =
        (gate['sourceReviewBundles'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(sourceBundle['bundleRef'], bundle['attestationBundleRef']);
    expect(sourceBundle['bundleDigest'], isA<String>());
    expect(sourceBundle['sourceReleaseReviewPacketRef'], isA<String>());
    expect(sourceBundle['approvedReviewTaskDigestsDigest'], isA<String>());
    final reviewGate = gate['releaseGate'] as Map<String, dynamic>;
    expect(reviewGate['approved'], isTrue);
    expect(reviewGate['missingRequirementCount'], 0);
    final summary = gate['summary'] as Map<String, dynamic>;
    expect(
      summary['approvedAssignmentRefCount'],
      summary['assignmentCount'],
    );
    final limitations = gate['limitations'] as Map<String, dynamic>;
    expect(limitations['runtimeConfigurationApplied'], isFalse);
    expect(limitations['aiConfigMutationsWritten'], isFalse);
    expect(limitations['releaseApprovalAppliesConfig'], isFalse);
  });

  test('contract rejects relabeled source review bundle evidence', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final tampered = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;
    final sourceBundle =
        (tampered['sourceReviewBundles'] as List<dynamic>).single
            as Map<String, dynamic>;
    sourceBundle['bundleDigest'] = digestFixture('wrong-review-bundle');

    final issues = EvalUseCaseTuningReleaseGate.validate(tampered);

    expect(
      issues,
      contains('releaseGateRef must match release gate subject digest'),
    );
  });

  test('source-aware validation rejects restamped source release plan', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final restamped = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;
    (restamped['sourceReleasePlan'] as Map<String, dynamic>).addAll(
      <String, dynamic>{
        'releasePlanDigest': digestFixture('forged-release-plan'),
        'releasePlanRef': digestFixture('forged-release-plan-ref'),
      },
    );
    restamped['releaseGateRef'] = releaseGateRefFixture(restamped);

    expect(EvalUseCaseTuningReleaseGate.validate(restamped), isEmpty);

    final issues = EvalUseCaseTuningReleaseGate.validateAgainstReleasePlan(
      restamped,
      releasePlan: releasePlan,
    );

    expect(
      issues,
      contains('sourceReleasePlan.releasePlanRef must match releasePlan'),
    );
    expect(
      issues,
      contains('sourceReleasePlan.releasePlanDigest must match releasePlan'),
    );
  });

  test('source-aware validation rejects fabricated gates without evidence', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final fabricated = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;
    fabricated['sourceReviewBundles'] = const <Map<String, dynamic>>[];
    (fabricated['summary'] as Map<String, dynamic>)
      ..['reviewBundleCount'] = 0
      ..['validReviewBundleCount'] = 0;
    fabricated['releaseGateRef'] = releaseGateRefFixture(fabricated);

    expect(
      EvalUseCaseTuningReleaseGate.validate(fabricated),
      contains('sourceReviewBundles must include approved review evidence'),
    );

    final sourceIssues =
        EvalUseCaseTuningReleaseGate.validateAgainstReleasePlan(
          fabricated,
          releasePlan: releasePlan,
        );

    expect(
      sourceIssues,
      contains('sourceReviewBundles must include approved review evidence'),
    );
  });

  test('source-aware validation rejects restamped review bundle summaries', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final restamped = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;
    ((restamped['sourceReviewBundles'] as List<dynamic>).single
          as Map<String, dynamic>)
      ..['bundleRef'] = digestFixture('forged-review-bundle-ref')
      ..['bundleDigest'] = digestFixture('forged-review-bundle-digest');
    restamped['releaseGateRef'] = releaseGateRefFixture(restamped);

    expect(EvalUseCaseTuningReleaseGate.validate(restamped), isEmpty);
    expect(
      EvalUseCaseTuningReleaseGate.validateAgainstReleasePlan(
        restamped,
        releasePlan: releasePlan,
      ),
      isEmpty,
    );

    final issues = EvalUseCaseTuningReleaseGate.validateAgainstSources(
      restamped,
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
    );

    expect(
      issues,
      contains('sourceReviewBundles must match release review bundles'),
    );
  });

  test('source-aware build rejects restamped release plans and bundles', () {
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
    final forgedBundle = buildReleaseReviewBundleFixture(
      releasePlan: forged,
    );

    final localGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: forged,
      releaseReviewBundles: [forgedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    expect(localGate['status'], 'approvedForManualApply');

    final sourceAwareGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: forged,
      releaseReviewBundles: [forgedBundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(EvalUseCaseTuningReleaseGate.validate(sourceAwareGate), isEmpty);
    expect(sourceAwareGate['status'], 'invalid');
    expect(sourceAwareGate['approvedAssignmentRefs'], isEmpty);
    final sourceReleasePlan =
        sourceAwareGate['sourceReleasePlan'] as Map<String, dynamic>;
    expect(sourceReleasePlan['contractIssueCount'], greaterThan(0));
    expect(
      sourceAwareGate['issues'],
      contains(
        allOf(
          containsPair('code', 'releaseGate.releasePlanContractInvalid'),
          containsPair(
            'message',
            contains('release plan must match source roadmap and ledgers'),
          ),
        ),
      ),
    );
  });

  test('contract rejects tampered approved assignment refs', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final tampered = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;

    (tampered['approvedAssignmentRefs'] as List<dynamic>).clear();
    (tampered['summary']
            as Map<String, dynamic>)['approvedAssignmentRefCount'] =
        0;

    final issues = EvalUseCaseTuningReleaseGate.validate(tampered);

    expect(
      issues,
      contains('releaseGateRef must match release gate subject digest'),
    );
  });

  test('contract rejects tampered release gate summary counts', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final tampered = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>;
    (tampered['summary'] as Map<String, dynamic>)
      ..['assignmentCount'] = 0
      ..['validReviewBundleCount'] = 0
      ..['duplicateApprovedAttestationCount'] = 99
      ..['unmatchedApprovedAttestationCount'] = 99;

    final issues = EvalUseCaseTuningReleaseGate.validate(tampered);

    expect(
      issues,
      contains('releaseGateRef must match release gate subject digest'),
    );
    expect(
      issues,
      contains(
        'summary.assignmentCount must match sourceReleasePlan.assignmentCount',
      ),
    );
    expect(
      issues,
      contains(
        'summary.validReviewBundleCount must match valid source review bundles',
      ),
    );
    expect(
      issues,
      contains(
        'summary.duplicateApprovedAttestationCount must match releaseGate.duplicateRequirements.length',
      ),
    );
    expect(
      issues,
      contains(
        'summary.unmatchedApprovedAttestationCount must match releaseGate.unmatchedAttestations.length',
      ),
    );
  });

  test('contract rejects recomputed gate refs with dropped assignments', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final tampered = releaseGateWithTamperedApprovedRefs(
      gate: gate,
      approvedAssignmentRefs: const [],
    );

    final issues = EvalUseCaseTuningReleaseGate.validate(tampered);

    expect(
      issues,
      contains(
        'approvedAssignmentRefs must match sourceReleasePlan.assignmentRefsDigest when releaseGate.approved is true',
      ),
    );
  });

  test('blocks missing or rejected release review coverage', () {
    final releasePlan = buildReleasePlanFixture();
    final rejectedBundle = buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
      approved: false,
    );
    final mixedBundle = _mixedChangesRequestedBundle(releasePlan);

    for (final scenario in <String, List<Map<String, dynamic>>>{
      'no bundle': const [],
      'changes requested': [rejectedBundle],
      'partial approval changes requested': [mixedBundle],
    }.entries) {
      final gate = EvalUseCaseTuningReleaseGate.build(
        releasePlan: releasePlan,
        releaseReviewBundles: scenario.value,
        generatedAt: DateTime.utc(2026, 6, 12, 19),
      );

      expect(gate['status'], 'blockedReleaseReview', reason: scenario.key);
      expect(gate['approvedAssignmentRefs'], isEmpty, reason: scenario.key);
      expect(
        gate['issues'],
        contains(
          containsPair('code', 'releaseGate.reviewAttestationMissing'),
        ),
        reason: scenario.key,
      );
    }
  });

  test('blocks duplicate approved release review bundles', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle, bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(gate['status'], 'blockedReleaseReview');
    expect(
      gate['issues'],
      contains(
        containsPair('code', 'releaseGate.reviewAttestationDuplicate'),
      ),
    );
  });

  test('ignores approvals inside changes-requested review bundles', () {
    final releasePlan = buildReleasePlanFixture();
    final mixedBundle = _mixedChangesRequestedBundle(releasePlan);

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [mixedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    final reviewGate = gate['releaseGate'] as Map<String, dynamic>;
    expect(gate['status'], 'blockedReleaseReview');
    expect(reviewGate['approvedAttestationCount'], 0);
    expect(
      reviewGate['missingRequirementCount'],
      reviewGate['requiredReviewCount'],
    );
    expect(
      gate['issues'],
      contains(containsPair('code', 'releaseGate.reviewBundleNotApproved')),
    );
  });

  test(
    'contract rejects restamped approval status without review approval',
    () {
      final releasePlan = buildReleasePlanFixture();
      final rejectedBundle = buildReleaseReviewBundleFixture(
        releasePlan: releasePlan,
        approved: false,
      );
      final gate = EvalUseCaseTuningReleaseGate.build(
        releasePlan: releasePlan,
        releaseReviewBundles: [rejectedBundle],
        generatedAt: DateTime.utc(2026, 6, 12, 19),
      );
      final tampered = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>
        ..['status'] = 'approvedForManualApply';

      final issues = EvalUseCaseTuningReleaseGate.validate(tampered);

      expect(
        issues,
        contains('status must match release gate approval state'),
      );
    },
  );

  test(
    'blocks non-ready release plans before counting review attestations',
    () {
      final blockedPlan = buildReleasePlanFixture(accepted: false);

      final gate = EvalUseCaseTuningReleaseGate.build(
        releasePlan: blockedPlan,
        generatedAt: DateTime.utc(2026, 6, 12, 19),
      );

      expect(gate['status'], 'blockedReleasePlan');
      expect(gate['approvedAssignmentRefs'], isEmpty);
      expect(
        gate['issues'],
        contains(containsPair('code', 'releaseGate.sourceNotReady')),
      );
    },
  );

  test('blocks stale release review bundles for another release plan', () {
    final releasePlan = buildReleasePlanFixture();
    final stalePlan = buildReleasePlanFixture(
      modelClass: 'frontierReasoning',
      promptVariantName: 'reasoning-v1',
      cellSeed: 'task-frontier-reasoning',
      reportSeed: 'task-report-reasoning',
    );
    final staleBundle = buildReleaseReviewBundleFixture(releasePlan: stalePlan);

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [staleBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(gate['status'], 'invalid');
    expect(
      gate['issues'],
      contains(
        containsPair('code', 'releaseGate.reviewBundleContractInvalid'),
      ),
    );
    expect(
      gate['issues'],
      contains(
        containsPair('code', 'releaseGate.reviewAttestationMissing'),
      ),
    );
  });

  test('blocks standalone-valid bundles with restamped packet provenance', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final restampedBundle = _releaseReviewBundleWithPacketRef(
      bundle,
      digestFixture('forged-release-review-packet-ref'),
    );

    expect(
      EvalUseCaseTuningReleaseReview.validateBundle(restampedBundle),
      isEmpty,
    );

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [restampedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(gate['status'], 'invalid');
    expect(
      gate['issues'],
      contains(
        containsPair('code', 'releaseGate.reviewBundleContractInvalid'),
      ),
    );

    final sourceIssues =
        EvalUseCaseTuningReleaseReview.validateBundleAgainstReleasePlan(
          restampedBundle,
          releasePlan: releasePlan,
        );

    expect(
      sourceIssues,
      contains(
        'sourceReleasePlan.sourceReleaseReviewPacketRef must match releasePlan',
      ),
    );
  });

  test('blocks standalone-valid bundles with restamped source summaries', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final restampedBundle =
        jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
    (restampedBundle['sourceReleasePlan'] as Map<String, dynamic>)
      ..['releasePlanRef'] = digestFixture('forged-release-plan-ref')
      ..['assignmentCount'] = 42
      ..['reviewTaskCount'] = 99;
    restampedBundle['attestationBundleRef'] =
        EvalUseCaseTuningReleaseReview.attestationBundleRef(restampedBundle);

    expect(
      EvalUseCaseTuningReleaseReview.validateBundle(restampedBundle),
      isEmpty,
    );

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [restampedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(gate['status'], 'invalid');
    expect(
      gate['issues'],
      contains(containsPair('code', 'releaseGate.reviewBundleContractInvalid')),
    );
  });

  test('blocks approved review attestations for a stale proof summary', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final tamperedBundle =
        jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
    final firstAttestation =
        (tamperedBundle['attestations'] as List<dynamic>).first
            as Map<String, dynamic>;
    final wrongDigest = digestFixture('stale-model-class-proof-summary');
    firstAttestation
      ..['assignmentProofSummaryDigest'] = wrongDigest
      ..['modelClassCoverageProofSummaryDigest'] = wrongDigest;
    firstAttestation['evidenceDigest'] = releaseReviewEvidenceDigest(
      firstAttestation,
      status: 'approved',
    );

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [tamperedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(gate['status'], 'invalid');
    expect(
      gate['issues'],
      contains(
        containsPair('code', 'releaseGate.reviewBundleContractInvalid'),
      ),
    );
  });

  test('invalid release review bundles invalidate the gate artifact', () {
    final releasePlan = buildReleasePlanFixture();
    final invalidBundle = buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
    )..['kind'] = 'lotti.invalid';

    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [invalidBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(gate['status'], 'invalid');
    final sourceBundle =
        (gate['sourceReviewBundles'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(sourceBundle['status'], 'invalid');
    expect(sourceBundle['contractIssueCount'], greaterThan(0));
    expect(
      gate['issues'],
      contains(
        containsPair('code', 'releaseGate.reviewBundleContractInvalid'),
      ),
    );
  });

  test('contract rejects private ids, paths, env keys, and commands', () {
    final releasePlan = buildReleasePlanFixture();
    final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
    final gate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final tampered = jsonDecode(jsonEncode(gate)) as Map<String, dynamic>
      ..['agentId'] = 'private-agent'
      ..['releaseGateRef'] = digestFixture('wrong-release-gate-ref')
      ..['notes'] =
          'Use file:///private/tmp/release.json with EVAL_USE_CASE_RELEASE_GATE.';
    (tampered['recommendedCommands'] as List<dynamic>).add(
      const <String, dynamic>{
        'mode': 'mutate',
        'command': 'bash -lc "fvm flutter test"',
        'env': {'EVAL_USE_CASE_RELEASE_GATE': '/private/tmp/gate.json'},
      },
    );
    final sourceBundle =
        ((tampered['sourceReviewBundles'] as List<dynamic>).first
              as Map<String, dynamic>)
          ..['profileId'] = 'private-profile';

    expect(sourceBundle, isNotEmpty);
    final issues = EvalUseCaseTuningReleaseGate.validate(tampered);

    expect(
      issues,
      contains('releaseGate.agentId must not expose private runtime ids'),
    );
    expect(
      issues,
      contains('releaseGateRef must match release gate subject digest'),
    );
    expect(
      issues,
      contains('releaseGate.notes must not contain private paths'),
    );
    expect(
      issues,
      contains('releaseGate.notes must not contain private env value keys'),
    );
    expect(
      issues,
      contains(
        'releaseGate.sourceReviewBundles[0].profileId must not expose private runtime ids',
      ),
    );
    expect(
      issues,
      contains(
        'recommendedCommands[1].command must not recommend mutation commands',
      ),
    );
    expect(
      issues,
      contains('recommendedCommands[1] must not contain env values'),
    );
  });

  test('release gate import requires review bundle artifacts', () {
    final tempDir = Directory.systemTemp.createTempSync(
      'lotti-release-gate-import-',
    );
    try {
      final packetPath = '${tempDir.path}/packet.json';
      final listPath = '${tempDir.path}/attestations.json';
      final releasePlan = buildReleasePlanFixture();
      final packet = EvalUseCaseTuningReleaseReview.buildPacket(
        releasePlan: releasePlan,
        generatedAt: DateTime.utc(2026, 6, 12, 17),
      );
      File(packetPath).writeAsStringSync(jsonEncode(packet));
      File(listPath).writeAsStringSync(
        jsonEncode(approvedReleaseReviewAttestations(releasePlan)),
      );

      expect(() => _readReviewBundleFile(packetPath), throwsStateError);
      expect(() => _readReviewBundleFile(listPath), throwsStateError);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'writes use-case tuning release gate',
    () async {
      final releasePlan =
          jsonDecode(File(_releaseGatePlanPath).readAsStringSync())
              as Map<String, dynamic>;
      final bundles = _readReviewBundles(_releaseGateReviewAttestations);
      final sourceInputs = await _readReleasePlanSourceInputs();
      final gate = EvalUseCaseTuningReleaseGate.build(
        releasePlan: releasePlan,
        releaseReviewBundles: bundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      EvalUseCaseTuningReleaseGate.assertValid(gate);
      EvalUseCaseTuningReleaseGate.assertMatchesSources(
        gate,
        releasePlan: releasePlan,
        releaseReviewBundles: bundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      writeEvalJsonArtifact(
        gate,
        path: _releaseGateOutputPath,
        overwrite: _releaseGateOverwrite == '1',
        description: 'use-case tuning release gate',
      );
    },
    skip:
        _releaseGatePlanPath.isEmpty ||
            _releaseGateRoadmapInputPath.isEmpty ||
            _releaseGateDecisionLedgerPaths.isEmpty ||
            _releaseGateDecisionLedgerSourceManifestPaths.isEmpty ||
            _releaseGateReviewAttestations.isEmpty ||
            _releaseGateOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_RELEASE_GATE_PLAN_INPUT=<json>, '
              'EVAL_USE_CASE_RELEASE_GATE_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RELEASE_GATE_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RELEASE_GATE_REVIEW_ATTESTATIONS=<json>, and '
              'EVAL_USE_CASE_RELEASE_GATE=<json> to write a release gate.'
        : false,
  );
}

Map<String, dynamic> _mixedChangesRequestedBundle(
  Map<String, dynamic> releasePlan,
) {
  final attestations = approvedReleaseReviewAttestations(releasePlan);
  return EvalUseCaseTuningReleaseReview.buildAttestationBundle(
    releasePlan: releasePlan,
    attestations: [
      releaseReviewAttestationWithStatus(attestations.first, 'rejected'),
      ...attestations.skip(1),
    ],
    generatedAt: DateTime.utc(2026, 6, 12, 18),
  );
}

Map<String, dynamic> _releaseReviewBundleWithPacketRef(
  Map<String, dynamic> bundle,
  String sourceReleaseReviewPacketRef,
) {
  final tampered = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
  (tampered['sourceReleasePlan']
          as Map<String, dynamic>)['sourceReleaseReviewPacketRef'] =
      sourceReleaseReviewPacketRef;
  for (final task
      in (tampered['requiredReviewTasks'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
    task['sourceReleaseReviewPacketRef'] = sourceReleaseReviewPacketRef;
  }
  for (final attestation
      in (tampered['attestations'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
    attestation['sourceReleaseReviewPacketRef'] = sourceReleaseReviewPacketRef;
    attestation['evidenceDigest'] =
        EvalUseCaseTuningReleaseReview.attestationEvidenceDigest(
          attestation,
        );
  }
  tampered['attestationBundleRef'] =
      EvalUseCaseTuningReleaseReview.attestationBundleRef(tampered);
  return tampered;
}

List<Map<String, dynamic>> _readReviewBundles(String paths) {
  return [
    for (final path in paths.split(','))
      if (path.trim().isNotEmpty) ..._readReviewBundleFile(path.trim()),
  ];
}

Future<_ReleasePlanSourceInputs> _readReleasePlanSourceInputs() async {
  final previousReleasePlan = _readOptionalJsonMap(
    _releaseGatePreviousReleasePlanPath,
  );
  final roadmap = _readOptionalJsonMap(_releaseGateRoadmapInputPath);
  final sourceDecisionLedgers = _readJsonListOrEmpty(
    _releaseGateDecisionLedgerPaths,
  );
  final decisionLedgers =
      _releaseGateDecisionLedgerSourceManifestPaths.trim().isEmpty
      ? sourceDecisionLedgers
      : await evalReplayDecisionLedgerSourceManifests(
          ledgers: sourceDecisionLedgers,
          manifests: evalReadDecisionLedgerSourceManifestFiles(
            _releaseGateDecisionLedgerSourceManifestPaths,
          ),
          config: _sourceReplayConfig(),
        );
  final runtimeRolloutLedgers = _readJsonListOrEmpty(
    _releaseGateRuntimeRolloutLedgerPaths,
  );
  if (runtimeRolloutLedgers.isNotEmpty) {
    final previousPlan = previousReleasePlan;
    if (previousPlan == null) {
      throw StateError(
        'EVAL_USE_CASE_RELEASE_GATE_PREVIOUS_RELEASE_PLAN is required '
        'with EVAL_USE_CASE_RELEASE_GATE_RUNTIME_ROLLOUT_LEDGERS.',
      );
    }
    markRuntimeRolloutLedgerSourcesFixture(
      runtimeRolloutLedgers,
      previousPlan: previousPlan,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: decisionLedgers,
      previousRuntimeRolloutLedgers: _readJsonListOrEmpty(
        _releaseGateRuntimePreviousRolloutLedgerPaths,
      ),
      releaseGates: _readJsonListOrEmpty(
        _releaseGateRuntimeLedgerReleaseGatePaths,
      ),
      releaseReviewBundles: readReleaseReviewBundlesFixture(
        _releaseGateRuntimeLedgerReleaseReviewAttestations,
      ),
      runtimeVerifications: _readJsonListOrEmpty(
        _releaseGateRuntimeVerificationPaths,
      ),
      runtimeResolverSnapshots: _readJsonListOrEmpty(
        _releaseGateRuntimeLedgerResolverSnapshotPaths,
      ),
      runtimeResolverPackets: _readJsonListOrEmpty(
        _releaseGateRuntimeLedgerResolverPacketPaths,
      ),
      runtimeLocatorPackets: _readJsonListOrEmpty(
        _releaseGateRuntimeLedgerLocatorPacketPaths,
      ),
      completedBindingSources: source_replay.readCompletedBindingSources(
        _releaseGateRuntimeLedgerResolverInputPaths,
      ),
      directObservationSources: source_replay.readDirectObservationSources(
        _releaseGateRuntimeLedgerDirectObservationPaths,
      ),
      privateRuntimeStates: source_replay.readJsonObjects(
        _releaseGateRuntimeLedgerStateInputPaths,
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

Map<String, dynamic>? _readOptionalJsonMap(String path) {
  if (path.trim().isEmpty) {
    return null;
  }
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw StateError('Expected release gate source JSON object.');
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

List<Map<String, dynamic>> _readJsonList(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is List) {
    return [for (final item in decoded) item as Map<String, dynamic>];
  }
  if (decoded is Map<String, dynamic>) {
    return [decoded];
  }
  throw StateError('Expected release gate source JSON object or list.');
}

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
