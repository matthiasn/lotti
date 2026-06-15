import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
const _ledgerReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_PLAN',
);
const _ledgerReleaseGatePath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_GATE',
);
const _ledgerReleaseReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS',
);
const _ledgerRoadmapInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_ROADMAP_INPUT',
);
const _ledgerDecisionLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_DECISION_LEDGERS',
);
const _ledgerDecisionLedgerSourceManifestPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS',
);
const _ledgerPreviousReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_PREVIOUS_RELEASE_PLAN',
);
const _ledgerRuntimeRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_ROLLOUT_LEDGERS',
);
const _ledgerRuntimePreviousRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_PREVIOUS_ROLLOUT_LEDGERS',
);
const _ledgerRuntimeLedgerReleaseGatePaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_RELEASE_GATES',
);
const _ledgerRuntimeLedgerReleaseReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS',
);
const _ledgerRuntimeVerificationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_VERIFICATIONS',
);
const _ledgerRuntimeLedgerResolverSnapshotPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS',
);
const _ledgerRuntimeLedgerResolverPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_RESOLVER_PACKETS',
);
const _ledgerRuntimeLedgerLocatorPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_LOCATOR_PACKETS',
);
const _ledgerRuntimeLedgerResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_RESOLVER_INPUTS',
);
const _ledgerRuntimeLedgerDirectObservationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_DIRECT_OBSERVATIONS',
);
const _ledgerRuntimeLedgerStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_LEDGER_STATE_INPUTS',
);
const _ledgerVerificationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFICATIONS',
);
const _ledgerResolverSnapshotPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS',
);
const _ledgerResolverPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_PACKETS',
);
const _ledgerLocatorPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_LOCATOR_PACKETS',
);
const _ledgerResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_INPUTS',
);
const _ledgerDirectObservationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_DIRECT_OBSERVATIONS',
);
const _ledgerStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_STATE_INPUTS',
);
const _ledgerPath = String.fromEnvironment('EVAL_USE_CASE_RUNTIME_LEDGER');
const _ledgerOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LEDGER_OVERWRITE',
);

void main() {
  test('verified runtime verification produces unblocked rollout ledger', () {
    final fixture = _RuntimeLedgerFixture.create();

    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(ledger['status'], 'verified');
    expect(
      (ledger['summary'] as Map<String, dynamic>)['runtimeVerifiedCount'],
      1,
    );
    expect(_recommendedModes(ledger), ['roadmap', 'release-plan']);
    expect(ledger['blockers'], isEmpty);
    final assignment = _singleAssignment(ledger);
    final releaseAssignment =
        (fixture.releasePlan['runtimeAssignments'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(assignment['runtimeStatus'], 'runtimeVerified');
    expect(assignment['nextAction'], 'continueReleasePlanning');
    expect(
      assignment['modelClassCoverageClassRef'],
      releaseAssignment['modelClassCoverageClassRef'],
    );
    final proofSummary =
        fixture.releasePlan['modelClassCoverageProofSummary']
            as Map<String, dynamic>;
    expect(
      (ledger['sourceReleasePlan']
          as Map<String, dynamic>)['modelClassCoverageProofSummaryDigest'],
      proofSummary['proofSummaryDigest'],
    );
    expect(
      (ledger['sourceReleaseGate']
          as Map<String, dynamic>)['modelClassCoverageProofSummaryDigest'],
      proofSummary['proofSummaryDigest'],
    );
    final verificationSource =
        (ledger['runtimeVerificationSources'] as List<dynamic>).single
            as Map<String, dynamic>;
    final snapshotSource =
        (ledger['runtimeResolverSnapshotSources'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(
      verificationSource['modelClassCoverageProofSummaryDigest'],
      proofSummary['proofSummaryDigest'],
    );
    expect(
      verificationSource['runtimeResolverSnapshotRef'],
      snapshotSource['runtimeResolverSnapshotRef'],
    );
    expect(
      verificationSource['runtimeResolverSnapshotDigest'],
      snapshotSource['runtimeResolverSnapshotDigest'],
    );
    expect(
      (ledger['summary']
          as Map<String, dynamic>)['runtimeResolverSnapshotCount'],
      1,
    );
  });

  test('private locator runtime verification requires source packets', () {
    final fixture = _RuntimeLedgerFixture.create(privateLocatorMode: true);

    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: fixture.releasePlan,
        releaseGate: fixture.releaseGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains(
              'runtime resolver snapshots require source resolver packet',
            ),
            contains(
              'private runtime resolver snapshots require source locator packet',
            ),
          ),
        ),
      ),
    );

    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      runtimeLocatorPackets: [fixture.locatorPacket!],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(ledger['status'], 'verified');
    expect(
      EvalUseCaseRuntimeRolloutLedger.validateAgainstSources(
        ledger,
        releasePlan: fixture.releasePlan,
        releaseGate: fixture.releaseGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        runtimeResolverPackets: [fixture.resolverPacket],
        runtimeLocatorPackets: [fixture.locatorPacket!],
      ),
      isEmpty,
    );
  });

  test('not-applied runtime verification blocks unchanged rollout', () {
    final fixture = _RuntimeLedgerFixture.create(
      resolutionStatus: 'notApplied',
    );

    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(ledger['status'], 'blocked');
    expect(
      _recommendedModes(ledger),
      [
        'runtime-locator-packet',
        'observe-runtime-state',
        'runtime-verify',
      ],
    );
    expect((ledger['summary'] as Map<String, dynamic>)['notAppliedCount'], 1);
    final assignment = _singleAssignment(ledger);
    expect(assignment['runtimeStatus'], 'notApplied');
    expect(assignment['blockerCodes'], ['runtime.notApplied']);
    expect(assignment['nextAction'], 'applyRuntimeAssignmentThenReverify');
  });

  test('ledger contract rejects tampered previous-ledger provenance', () {
    final fixture = _RuntimeLedgerFixture.create();
    final previousLedger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      previousLedger: previousLedger,
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;

    (tampered['sourcePreviousLedger'] as Map<String, dynamic>)
      ..['ledgerDigest'] = digestFixture('wrong-previous-ledger')
      ..['status'] = 'blocked';

    final issues = EvalUseCaseRuntimeRolloutLedger.validate(tampered);

    expect(
      issues,
      contains('rolloutLedgerRef must match rollout ledger subject digest'),
    );
  });

  test('build rejects release gate source assignment-ref digest drift', () {
    final fixture = _RuntimeLedgerFixture.create();
    final tamperedGate = releaseGateWithTamperedApprovedRefs(
      gate: fixture.releaseGate,
      approvedAssignmentRefs: const [],
      rewriteSourceAssignmentRefsDigest: true,
    );

    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: fixture.releasePlan,
        releaseGate: tamperedGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        runtimeResolverPackets: [fixture.resolverPacket],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('approvedAssignmentRefs must match releasePlan assignments'),
        ),
      ),
    );
  });

  test('build rejects release gate source review-bundle provenance drift', () {
    final fixture = _RuntimeLedgerFixture.create();
    final tamperedGate = releaseGateWithTamperedSourceBundle(
      gate: fixture.releaseGate,
      sourceReleaseReviewPacketRef: digestFixture(
        'runtime-rollout-forged-review-packet',
      ),
    );

    expect(EvalUseCaseTuningReleaseGate.validate(tamperedGate), isEmpty);

    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: fixture.releasePlan,
        releaseGate: tamperedGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        runtimeResolverPackets: [fixture.resolverPacket],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'sourceReviewBundles[0].sourceReleaseReviewPacketRef must match releasePlan',
          ),
        ),
      ),
    );
  });

  test('build requires resolver snapshot evidence for each verification', () {
    final fixture = _RuntimeLedgerFixture.create();

    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: fixture.releasePlan,
        releaseGate: fixture.releaseGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: const [],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('Runtime rollout ledger needs resolver snapshot evidence'),
        ),
      ),
    );
  });

  test('source-aware validation rejects restamped verification sources', () {
    final fixture = _RuntimeLedgerFixture.create();
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final restamped = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final fakeVerificationDigest = digestFixture(
      'restamped-runtime-verification-source',
    );
    ((restamped['runtimeVerificationSources'] as List<dynamic>).single
            as Map<String, dynamic>)['runtimeVerificationDigest'] =
        fakeVerificationDigest;
    ((restamped['assignments'] as List<dynamic>).single
            as Map<String, dynamic>)['runtimeVerificationDigest'] =
        fakeVerificationDigest;
    restamped['rolloutLedgerRef'] =
        EvalUseCaseRuntimeRolloutLedger.rolloutLedgerRef(restamped);

    expect(EvalUseCaseRuntimeRolloutLedger.validate(restamped), isEmpty);

    final issues = EvalUseCaseRuntimeRolloutLedger.validateAgainstSources(
      restamped,
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
    );

    expect(
      issues,
      contains('rolloutLedgerRef must match source runtime artifacts'),
    );
    expect(
      issues,
      contains(
        'runtimeVerificationSources must match source runtime artifacts',
      ),
    );
    expect(
      issues,
      contains('assignments must match source runtime artifacts'),
    );
  });

  test('ledger contract rejects forged assignment outcomes', () {
    final fixture = _RuntimeLedgerFixture.create(
      resolutionStatus: 'notApplied',
    );
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final summary = tampered['summary'] as Map<String, dynamic>;
    final assignment =
        (tampered['assignments'] as List<dynamic>).single
            as Map<String, dynamic>;

    tampered
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

    final issues = EvalUseCaseRuntimeRolloutLedger.validate(tampered);

    expect(
      issues,
      contains('rolloutLedgerRef must match rollout ledger subject digest'),
    );
  });

  test('ledger contract rejects restamped blocker waivers', () {
    final fixture = _RuntimeLedgerFixture.create(drift: true);
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final assignment =
        (tampered['assignments'] as List<dynamic>).single
            as Map<String, dynamic>;

    tampered
      ..['status'] = 'verified'
      ..['blockers'] = <Map<String, dynamic>>[];
    (tampered['summary'] as Map<String, dynamic>)['blockerCount'] = 0;
    assignment
      ..['blockerCodes'] = <String>[]
      ..['blockers'] = <Map<String, dynamic>>[];
    tampered['rolloutLedgerRef'] =
        EvalUseCaseRuntimeRolloutLedger.rolloutLedgerRef(tampered);

    final issues = EvalUseCaseRuntimeRolloutLedger.validate(tampered);

    expect(
      issues,
      contains(
        'verified rollout ledgers require every assignment to be runtimeVerified',
      ),
    );
    expect(
      issues,
      contains('assignments[0].blockerCodes must match runtimeStatus'),
    );
    expect(
      issues,
      contains('assignments[0].blockers must contain one blocker'),
    );
  });

  test('ledger contract rejects restamped assignment source swaps', () {
    final fixture = _RuntimeLedgerFixture.create();
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final assignment =
        (tampered['assignments'] as List<dynamic>).single
            as Map<String, dynamic>;

    assignment['runtimeVerificationDigest'] = digestFixture(
      'wrong-runtime-verification-source',
    );
    tampered['rolloutLedgerRef'] =
        EvalUseCaseRuntimeRolloutLedger.rolloutLedgerRef(tampered);

    final issues = EvalUseCaseRuntimeRolloutLedger.validate(tampered);

    expect(
      issues,
      contains(
        'assignments[0] must reference a runtimeVerificationSources entry',
      ),
    );
  });

  test('drift runtime verification produces revalidation blocker', () {
    final fixture = _RuntimeLedgerFixture.create(drift: true);

    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(ledger['status'], 'blocked');
    expect((ledger['summary'] as Map<String, dynamic>)['driftCount'], 1);
    final assignment = _singleAssignment(ledger);
    expect(assignment['runtimeStatus'], 'drift');
    expect(assignment['blockerCodes'], ['runtime.drift']);
    expect(
      assignment['sourceIssueCodes'],
      contains('runtime.effectiveBindingDrift'),
    );
  });

  test('stale runtime verification source is rejected', () {
    final fixture = _RuntimeLedgerFixture.create();
    final changedPlan = buildReleasePlanFixture(
      promptVariantName: 'metadata-first-v3',
    );
    final changedGate = _releaseGate(changedPlan);

    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: changedPlan,
        releaseGate: changedGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        runtimeResolverPackets: [fixture.resolverPacket],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'sourceReleasePlan.releasePlanDigest must match releasePlan',
          ),
        ),
      ),
    );
  });

  test(
    'restamped verification coverage class relabels are rejected by sources',
    () {
      final fixture = _RuntimeLedgerFixture.create();
      final forged =
          jsonDecode(jsonEncode(fixture.verification)) as Map<String, dynamic>;
      final expectedAssignment =
          (forged['expectedAssignments'] as List<dynamic>).single
              as Map<String, dynamic>;
      final observedBinding =
          (forged['observedRuntimeBindings'] as List<dynamic>).single
              as Map<String, dynamic>;

      expectedAssignment['modelClassCoverageClassRef'] = digestFixture(
        'restamped-coverage-class',
      );
      observedBinding['modelClassCoverageClassRef'] = digestFixture(
        'restamped-coverage-class',
      );
      observedBinding['resolverBindingDigest'] =
          EvalUseCaseRuntimeVerification.runtimeResolverBindingDigest(
            observedBinding,
          );
      forged['runtimeVerificationRef'] =
          EvalUseCaseRuntimeVerification.runtimeVerificationRef(forged);

      expect(EvalUseCaseRuntimeVerification.validate(forged), isEmpty);
      expect(
        () => EvalUseCaseRuntimeRolloutLedger.build(
          releasePlan: fixture.releasePlan,
          releaseGate: fixture.releaseGate,
          runtimeVerifications: [forged],
          runtimeResolverSnapshots: [fixture.resolverSnapshot],
          runtimeResolverPackets: [fixture.resolverPacket],
          generatedAt: DateTime.utc(2026, 6, 13, 8),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains(
              'expectedAssignments must match releasePlan and releaseGate',
            ),
          ),
        ),
      );
    },
  );

  test('duplicate runtime verification artifacts fail closed', () {
    final fixture = _RuntimeLedgerFixture.create();

    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: fixture.releasePlan,
        releaseGate: fixture.releaseGate,
        runtimeVerifications: [fixture.verification, fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        runtimeResolverPackets: [fixture.resolverPacket],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('Duplicate runtime verification artifact'),
        ),
      ),
    );
  });

  test('ledger contract rejects private payloads', () {
    final fixture = _RuntimeLedgerFixture.create();
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    (tampered['sourceReleaseGate']
            as Map<String, dynamic>)['modelClassCoverageProofSummaryDigest'] =
        digestFixture('wrong-ledger-gate-proof-summary');
    ((tampered['runtimeVerificationSources'] as List<dynamic>).first
            as Map<String, dynamic>)['modelClassCoverageProofSummaryDigest'] =
        digestFixture('wrong-ledger-verification-proof-summary');
    (tampered['assignments'] as List<dynamic>).first as Map<String, dynamic>
      ..['privateRuntimeIds'] = {'agentId': 'agent-private'}
      ..['notes'] =
          'Read /private/tmp/runtime.json with EVAL_USE_CASE_RUNTIME_LEDGER.';

    final issues = EvalUseCaseRuntimeRolloutLedger.validate(tampered);

    expect(
      issues,
      contains(
        'runtimeRolloutLedger.assignments[0].privateRuntimeIds must not expose private runtime payloads',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeRolloutLedger.assignments[0].notes must not contain private paths',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeRolloutLedger.assignments[0].notes must not contain private env value keys',
      ),
    );
    expect(
      issues,
      contains(
        'sourceReleaseGate.modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeVerificationSources[0].modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      ),
    );
  });

  test('ledger contract rejects live-run recommendations', () {
    final fixture = _RuntimeLedgerFixture.create();
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    (tampered['recommendedCommands'] as List<dynamic>).add(
      const <String, dynamic>{
        'mode': 'run',
        'command': 'eval/run_level2.sh run',
      },
    );

    final issues = EvalUseCaseRuntimeRolloutLedger.validate(tampered);

    expect(
      issues,
      contains(
        'recommendedCommands[2].command must not recommend live run commands',
      ),
    );
  });

  test('ledger contract rejects restamped recommended command templates', () {
    final fixture = _RuntimeLedgerFixture.create();
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 1),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    ((tampered['recommendedCommands'] as List<dynamic>).first
          as Map<String, dynamic>)
      ..['mode'] = 'report'
      ..['command'] = 'eval/run_level2.sh report';

    final issues = EvalUseCaseRuntimeRolloutLedger.validate(tampered);

    expect(
      issues,
      contains(
        'recommendedCommands must match static recommended command templates',
      ),
    );
  });

  test('source-aware rollout ledger requires release review bundles', () {
    final fixture = _SourceAwareRuntimeLedgerFixture.create();

    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: fixture.releasePlan,
        releaseGate: fixture.releaseGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        runtimeResolverPackets: [fixture.resolverPacket],
        sourceRoadmap: fixture.roadmap,
        sourceDecisionLedgers: [fixture.decisionLedger],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('release gate review sources must be supplied'),
        ),
      ),
    );

    final localOnlyLedger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    expect(EvalUseCaseRuntimeRolloutLedger.validate(localOnlyLedger), isEmpty);
    expect(
      EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(localOnlyLedger),
      isFalse,
    );
    EvalUseCaseRuntimeRolloutLedger.assertMatchesSources(
      localOnlyLedger,
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
    );
    expect(
      EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(localOnlyLedger),
      isFalse,
    );

    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      releaseReviewBundles: [fixture.releaseReviewBundle],
      sourceRoadmap: fixture.roadmap,
      sourceDecisionLedgers: [fixture.decisionLedger],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );

    expect(ledger['status'], 'verified');
    expect(EvalUseCaseRuntimeRolloutLedger.validate(ledger), isEmpty);
    expect(EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(ledger), isTrue);
  });

  test('source-aware rollout ledger requires replayed previous source', () {
    final fixture = _SourceAwareRuntimeLedgerFixture.create();
    final serializedPreviousLedger =
        jsonDecode(jsonEncode(fixture.ledger)) as Map<String, dynamic>;

    expect(EvalUseCaseRuntimeRolloutLedger.validate(fixture.ledger), isEmpty);
    expect(
      EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(fixture.ledger),
      isTrue,
    );
    expect(
      EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(
        serializedPreviousLedger,
      ),
      isFalse,
    );
    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: fixture.releasePlan,
        releaseGate: fixture.releaseGate,
        runtimeVerifications: [fixture.verification],
        runtimeResolverSnapshots: [fixture.resolverSnapshot],
        runtimeResolverPackets: [fixture.resolverPacket],
        releaseReviewBundles: [fixture.releaseReviewBundle],
        sourceRoadmap: fixture.roadmap,
        sourceDecisionLedgers: [fixture.decisionLedger],
        previousLedger: serializedPreviousLedger,
        generatedAt: DateTime.utc(2026, 6, 13, 9),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'Previous runtime rollout ledger source replay must be verified',
          ),
        ),
      ),
    );

    final chainedLedger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: fixture.releasePlan,
      releaseGate: fixture.releaseGate,
      runtimeVerifications: [fixture.verification],
      runtimeResolverSnapshots: [fixture.resolverSnapshot],
      runtimeResolverPackets: [fixture.resolverPacket],
      releaseReviewBundles: [fixture.releaseReviewBundle],
      sourceRoadmap: fixture.roadmap,
      sourceDecisionLedgers: [fixture.decisionLedger],
      previousLedger: fixture.ledger,
      generatedAt: DateTime.utc(2026, 6, 13, 9),
    );

    expect(EvalUseCaseRuntimeRolloutLedger.validate(chainedLedger), isEmpty);
    expect(
      EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(chainedLedger),
      isTrue,
    );
    expect(
      (chainedLedger['sourcePreviousLedger']
          as Map<String, dynamic>)['ledgerDigest'],
      EvalProvenance.digestJson(fixture.ledger),
    );
  });

  test('source-aware rollout ledger rejects mismatched previous source', () {
    final previousFixture = _SourceAwareRuntimeLedgerFixture.create(
      baseRunId: 'previous-source-base-ready',
      followUpRunId: 'previous-source-follow-up-promote',
    );
    final currentFixture = _SourceAwareRuntimeLedgerFixture.create(
      baseRunId: 'current-source-base-ready',
      followUpRunId: 'current-source-follow-up-promote',
    );

    expect(
      EvalProvenance.digestJson(previousFixture.releasePlan),
      isNot(EvalProvenance.digestJson(currentFixture.releasePlan)),
    );
    expect(
      EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(
        previousFixture.ledger,
      ),
      isTrue,
    );
    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: currentFixture.releasePlan,
        releaseGate: currentFixture.releaseGate,
        runtimeVerifications: [currentFixture.verification],
        runtimeResolverSnapshots: [currentFixture.resolverSnapshot],
        runtimeResolverPackets: [currentFixture.resolverPacket],
        releaseReviewBundles: [currentFixture.releaseReviewBundle],
        sourceRoadmap: currentFixture.roadmap,
        sourceDecisionLedgers: [currentFixture.decisionLedger],
        previousLedger: previousFixture.ledger,
        generatedAt: DateTime.utc(2026, 6, 13, 9),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'Previous runtime rollout ledger source release plan must match',
          ),
        ),
      ),
    );
  });

  test(
    'writes use-case runtime rollout ledger',
    () async {
      final releasePlan = _readJson(_ledgerReleasePlanPath);
      final releaseGate = _readJson(_ledgerReleaseGatePath);
      final verifications = _readJsonList(_ledgerVerificationPaths);
      final resolverSnapshots = _readJsonList(_ledgerResolverSnapshotPaths);
      final resolverPackets = _readJsonList(_ledgerResolverPacketPaths);
      final locatorPackets = _readJsonList(_ledgerLocatorPacketPaths);
      final releaseReviewBundles = readReleaseReviewBundlesFixture(
        _ledgerReleaseReviewAttestations,
      );
      final sourceInputs = await _readReleasePlanSourceInputs();
      for (final resolverPacket in resolverPackets) {
        EvalUseCaseRuntimeResolverSnapshot.assertPacketMatchesSources(
          resolverPacket,
          releasePlan: releasePlan,
          releaseGate: releaseGate,
          releaseReviewBundles: releaseReviewBundles,
          sourceRoadmap: sourceInputs.roadmap,
          sourceDecisionLedgers: sourceInputs.decisionLedgers,
          previousReleasePlan: sourceInputs.previousReleasePlan,
          sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
        );
      }
      source_replay.assertRuntimeResolverSnapshotsMatchSources(
        resolverSnapshots,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        resolverPackets: resolverPackets,
        locatorPackets: locatorPackets,
        completedBindingSources: source_replay.readCompletedBindingSources(
          _ledgerResolverInputPaths,
        ),
        directObservationSources: source_replay.readDirectObservationSources(
          _ledgerDirectObservationPaths,
        ),
        privateRuntimeStates: source_replay.readJsonObjects(
          _ledgerStateInputPaths,
        ),
      );
      final ledger = EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeVerifications: verifications,
        runtimeResolverSnapshots: resolverSnapshots,
        runtimeResolverPackets: resolverPackets,
        runtimeLocatorPackets: locatorPackets,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      EvalUseCaseRuntimeRolloutLedger.assertMatchesSources(
        ledger,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeVerifications: verifications,
        runtimeResolverSnapshots: resolverSnapshots,
        runtimeResolverPackets: resolverPackets,
        runtimeLocatorPackets: locatorPackets,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      writeEvalJsonArtifact(
        ledger,
        path: _ledgerPath,
        overwrite: _ledgerOverwrite == '1',
        description: 'use-case runtime rollout ledger',
      );
    },
    skip:
        _ledgerReleasePlanPath.isEmpty ||
            _ledgerReleaseGatePath.isEmpty ||
            _ledgerReleaseReviewAttestations.isEmpty ||
            _ledgerRoadmapInputPath.isEmpty ||
            _ledgerDecisionLedgerPaths.isEmpty ||
            _ledgerDecisionLedgerSourceManifestPaths.isEmpty ||
            _ledgerVerificationPaths.isEmpty ||
            _ledgerResolverSnapshotPaths.isEmpty ||
            _ledgerResolverPacketPaths.isEmpty ||
            (_ledgerResolverInputPaths.isEmpty &&
                _ledgerDirectObservationPaths.isEmpty &&
                _ledgerStateInputPaths.isEmpty) ||
            _ledgerPath.isEmpty
        ? 'Set EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_PLAN=<json>, '
              'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_GATE=<json>, '
              'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS=<json>, '
              'EVAL_USE_CASE_RUNTIME_LEDGER_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RUNTIME_LEDGER_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RUNTIME_VERIFICATIONS=<a.json,b.json>, '
              'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS=<a.json,b.json>, and '
              'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_PACKETS=<a.json,b.json>, and '
              'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_INPUTS=<a.json,b.json>, '
              'EVAL_USE_CASE_RUNTIME_LEDGER_DIRECT_OBSERVATIONS=<a.json,b.json>, '
              'or EVAL_USE_CASE_RUNTIME_LEDGER_STATE_INPUTS=<a.json,b.json>, and '
              'EVAL_USE_CASE_RUNTIME_LEDGER=<json> to write a ledger. '
              'For privateRuntimeStateLocator snapshots, also set '
              'EVAL_USE_CASE_RUNTIME_LEDGER_LOCATOR_PACKETS=<a.json,b.json>.'
        : false,
  );
}

Map<String, dynamic> _releaseGate(Map<String, dynamic> releasePlan) {
  final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
  return EvalUseCaseTuningReleaseGate.build(
    releasePlan: releasePlan,
    releaseReviewBundles: [bundle],
    generatedAt: DateTime.utc(2026, 6, 12, 19),
  );
}

Map<String, dynamic> _singleAssignment(Map<String, dynamic> ledger) {
  return (ledger['assignments'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .single;
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _readJsonList(String paths) => [
  for (final path
      in paths
          .split(',')
          .map((path) => path.trim())
          .where(
            (path) => path.isNotEmpty,
          ))
    _readJson(path),
];

Future<ReleasePlanSourceInputsFixture>
_readReleasePlanSourceInputs() => readReleasePlanSourceInputsFixture(
  roadmapInputPath: _ledgerRoadmapInputPath,
  decisionLedgerPaths: _ledgerDecisionLedgerPaths,
  decisionLedgerSourceManifestPaths: _ledgerDecisionLedgerSourceManifestPaths,
  previousReleasePlanPath: _ledgerPreviousReleasePlanPath,
  runtimeRolloutLedgerPaths: _ledgerRuntimeRolloutLedgerPaths,
  runtimePreviousRolloutLedgerPaths: _ledgerRuntimePreviousRolloutLedgerPaths,
  runtimeLedgerReleaseGatePaths: _ledgerRuntimeLedgerReleaseGatePaths,
  runtimeLedgerReleaseReviewAttestations:
      _ledgerRuntimeLedgerReleaseReviewAttestations,
  runtimeVerificationPaths: _ledgerRuntimeVerificationPaths,
  runtimeLedgerResolverSnapshotPaths: _ledgerRuntimeLedgerResolverSnapshotPaths,
  runtimeLedgerResolverPacketPaths: _ledgerRuntimeLedgerResolverPacketPaths,
  runtimeLedgerLocatorPacketPaths: _ledgerRuntimeLedgerLocatorPacketPaths,
  runtimeLedgerResolverInputPaths: _ledgerRuntimeLedgerResolverInputPaths,
  runtimeLedgerDirectObservationPaths:
      _ledgerRuntimeLedgerDirectObservationPaths,
  runtimeLedgerStateInputPaths: _ledgerRuntimeLedgerStateInputPaths,
  previousReleasePlanEnvName:
      'EVAL_USE_CASE_RUNTIME_LEDGER_PREVIOUS_RELEASE_PLAN',
  runtimeRolloutLedgersEnvName:
      'EVAL_USE_CASE_RUNTIME_LEDGER_RUNTIME_ROLLOUT_LEDGERS',
  sourceReplayConfig: _sourceReplayConfig(),
);

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

final class _RuntimeLedgerFixture {
  const _RuntimeLedgerFixture({
    required this.releasePlan,
    required this.releaseGate,
    required this.resolverSnapshot,
    required this.verification,
    required this.resolverPacket,
    this.locatorPacket,
  });

  factory _RuntimeLedgerFixture.create({
    String resolutionStatus = 'applied',
    bool drift = false,
    bool privateLocatorMode = false,
  }) {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 13, 7),
    );
    final locatorPacket = privateLocatorMode
        ? EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
            resolverPacket: packet,
            locators: [
              for (final template
                  in (packet['bindingTemplates'] as List<dynamic>)
                      .cast<Map<String, dynamic>>())
                EvalRuntimeBindingLocator(
                  assignmentRef: template['assignmentRef'] as String,
                  agentId: 'agent-private-${template['assignmentRef']}',
                ),
            ],
            generatedAt: DateTime.utc(2026, 6, 13, 7, 15),
          )
        : null;
    final snapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      completedBindings: [
        for (final template
            in (packet['bindingTemplates'] as List<dynamic>)
                .cast<Map<String, dynamic>>())
          _completedBinding(
            template,
            resolutionStatus: resolutionStatus,
            drift: drift,
          ),
      ],
      runtimeObservationSource: privateLocatorMode
          ? EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceForPrivateRuntimeStateLocator(
              resolverPacket: packet,
              locatorPacket: locatorPacket!,
            )
          : EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
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
      runtimeLocatorPacket: privateLocatorMode ? locatorPacket : null,
      generatedAt: DateTime.utc(2026, 6, 13, 7, 45),
    );
    return _RuntimeLedgerFixture(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolverSnapshot: snapshot,
      verification: verification,
      resolverPacket: packet,
      locatorPacket: privateLocatorMode ? locatorPacket : null,
    );
  }

  final Map<String, dynamic> releasePlan;
  final Map<String, dynamic> releaseGate;
  final Map<String, dynamic> resolverSnapshot;
  final Map<String, dynamic> verification;
  final Map<String, dynamic> resolverPacket;
  final Map<String, dynamic>? locatorPacket;
}

final class _SourceAwareRuntimeLedgerFixture {
  const _SourceAwareRuntimeLedgerFixture({
    required this.decisionLedger,
    required this.roadmap,
    required this.releasePlan,
    required this.releaseReviewBundle,
    required this.releaseGate,
    required this.resolverPacket,
    required this.resolverSnapshot,
    required this.verification,
    required this.ledger,
  });

  factory _SourceAwareRuntimeLedgerFixture.create({
    String primaryCapabilityId = 'task.workflow',
    String promptVariantName = 'default',
    String baseRunId = 'source-replayed-base-ready',
    String followUpRunId = 'source-replayed-follow-up-promote',
  }) {
    final sourceFixture = buildDecisionLedgerSourceBoundReleaseFixture(
      primaryCapabilityId: primaryCapabilityId,
      promptVariantName: promptVariantName,
      baseRunId: baseRunId,
      followUpRunId: followUpRunId,
    );
    final decisionLedger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final releasePlan = sourceFixture.releasePlan;
    final releaseReviewBundle = buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
    );
    final releaseGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [releaseReviewBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      releaseReviewBundles: [releaseReviewBundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [decisionLedger],
      generatedAt: DateTime.utc(2026, 6, 13, 7),
    );
    final completedBindings = [
      for (final template
          in (resolverPacket['bindingTemplates'] as List<dynamic>)
              .cast<Map<String, dynamic>>())
        _completedBinding(
          template,
          resolutionStatus: 'applied',
          drift: false,
        ),
    ];
    final resolverSnapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: releasePlan,
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
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: resolverPacket,
      releaseReviewBundles: [releaseReviewBundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [decisionLedger],
      generatedAt: DateTime.utc(2026, 6, 13, 7, 45),
    );
    final ledger = EvalUseCaseRuntimeRolloutLedger.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeVerifications: [verification],
      runtimeResolverSnapshots: [resolverSnapshot],
      runtimeResolverPackets: [resolverPacket],
      releaseReviewBundles: [releaseReviewBundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [decisionLedger],
      generatedAt: DateTime.utc(2026, 6, 13, 8),
    );
    return _SourceAwareRuntimeLedgerFixture(
      decisionLedger: decisionLedger,
      roadmap: roadmap,
      releasePlan: releasePlan,
      releaseReviewBundle: releaseReviewBundle,
      releaseGate: releaseGate,
      resolverPacket: resolverPacket,
      resolverSnapshot: resolverSnapshot,
      verification: verification,
      ledger: ledger,
    );
  }

  final Map<String, dynamic> decisionLedger;
  final Map<String, dynamic> roadmap;
  final Map<String, dynamic> releasePlan;
  final Map<String, dynamic> releaseReviewBundle;
  final Map<String, dynamic> releaseGate;
  final Map<String, dynamic> resolverPacket;
  final Map<String, dynamic> resolverSnapshot;
  final Map<String, dynamic> verification;
  final Map<String, dynamic> ledger;
}

Map<String, dynamic> _completedBinding(
  Map<String, dynamic> template, {
  required String resolutionStatus,
  required bool drift,
}) {
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
  final observed = {
    ...expected,
    if (drift)
      'promptDirectiveDigest': digestFixture(
        'changed-prompt-directive-$assignmentRef',
      ),
  };
  return <String, dynamic>{
    ...template,
    'status': 'resolved',
    'resolutionStatus': resolutionStatus,
    'runtimeTargetRef': digestFixture('runtime-target-$assignmentRef'),
    'expected': expected,
    'observed': observed,
    'privateRuntimeIds': <String, dynamic>{
      'agentId': 'agent-private-$assignmentRef',
      'templateId': 'template-private-$assignmentRef',
      'profileId': 'profile-private-$assignmentRef',
    },
  };
}

List<String> _recommendedModes(Map<String, dynamic> artifact) =>
    (artifact['recommendedCommands'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((command) => command['mode'] as String)
        .toList();
