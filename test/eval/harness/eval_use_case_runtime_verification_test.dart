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
const _runtimeVerifyReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_PLAN',
);
const _runtimeVerifyReleaseGatePath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_GATE',
);
const _runtimeVerifyReleaseReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_REVIEW_ATTESTATIONS',
);
const _runtimeVerifyRoadmapInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_ROADMAP_INPUT',
);
const _runtimeVerifyDecisionLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_DECISION_LEDGERS',
);
const _runtimeVerifyDecisionLedgerSourceManifestPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS',
);
const _runtimeVerifyPreviousReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_PREVIOUS_RELEASE_PLAN',
);
const _runtimeVerifyRuntimeRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_ROLLOUT_LEDGERS',
);
const _runtimeVerifyRuntimePreviousRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_PREVIOUS_ROLLOUT_LEDGERS',
);
const _runtimeVerifyRuntimeLedgerReleaseGatePaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_RELEASE_GATES',
);
const _runtimeVerifyRuntimeLedgerReleaseReviewAttestations =
    String.fromEnvironment(
      'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS',
    );
const _runtimeVerifyRuntimeVerificationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_VERIFICATIONS',
);
const _runtimeVerifyRuntimeLedgerResolverSnapshotPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS',
);
const _runtimeVerifyRuntimeLedgerResolverPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_RESOLVER_PACKETS',
);
const _runtimeVerifyRuntimeLedgerLocatorPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_LOCATOR_PACKETS',
);
const _runtimeVerifyRuntimeLedgerResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_RESOLVER_INPUTS',
);
const _runtimeVerifyRuntimeLedgerDirectObservationPaths =
    String.fromEnvironment(
      'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_DIRECT_OBSERVATIONS',
    );
const _runtimeVerifyRuntimeLedgerStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_LEDGER_STATE_INPUTS',
);
const _runtimeStateSnapshotPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_STATE_SNAPSHOT',
);
const _runtimeResolverSnapshotPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT',
);
const _runtimeResolverPacketPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET',
);
const _runtimeLocatorPacketPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET',
);
const _runtimeVerifyResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_RESOLVER_INPUTS',
);
const _runtimeVerifyDirectObservationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_DIRECT_OBSERVATIONS',
);
const _runtimeVerifyStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFY_STATE_INPUTS',
);
const _runtimeVerificationOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFICATION',
);
const _runtimeVerificationOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_VERIFICATION_OVERWRITE',
);

void main() {
  test(
    'verifies applied runtime bindings for approved release assignments',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );

      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        runtimeResolverPacket: _runtimeResolverPacket(releasePlan, releaseGate),
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );

      expect(EvalUseCaseRuntimeVerification.validate(verification), isEmpty);
      expect(verification['status'], 'verified');
      final summary = verification['summary'] as Map<String, dynamic>;
      expect(
        summary['verifiedAssignmentCount'],
        summary['expectedAssignmentCount'],
      );
      expect(_recommendedModes(verification), ['runtime-verify']);
      expect(summary['driftCount'], 0);
      expect(summary['notAppliedCount'], 0);
      final proofSummary =
          releasePlan['modelClassCoverageProofSummary'] as Map<String, dynamic>;
      final sourcePlan =
          verification['sourceReleasePlan'] as Map<String, dynamic>;
      final sourceGate =
          verification['sourceReleaseGate'] as Map<String, dynamic>;
      final snapshotSource =
          verification['runtimeResolverSnapshot'] as Map<String, dynamic>;
      expect(
        snapshotSource['runtimeResolverSnapshotRef'],
        resolverSnapshot['runtimeResolverSnapshotRef'],
      );
      expect(
        snapshotSource['runtimeObservationSourceDigest'],
        EvalProvenance.digestJson(
          resolverSnapshot['runtimeObservationSource'] as Map<String, dynamic>,
        ),
      );
      expect(
        sourcePlan['modelClassCoverageProofSummaryDigest'],
        proofSummary['proofSummaryDigest'],
      );
      expect(
        sourceGate['modelClassCoverageProofSummaryDigest'],
        proofSummary['proofSummaryDigest'],
      );
      expect(
        snapshotSource['modelClassCoverageProofSummaryDigest'],
        proofSummary['proofSummaryDigest'],
      );
      final releaseAssignment =
          (releasePlan['runtimeAssignments'] as List<dynamic>).single
              as Map<String, dynamic>;
      final expectedAssignment =
          (verification['expectedAssignments'] as List<dynamic>).single
              as Map<String, dynamic>;
      final observedBinding =
          (verification['observedRuntimeBindings'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(
        expectedAssignment['modelClassCoverageClassRef'],
        releaseAssignment['modelClassCoverageClassRef'],
      );
      expect(
        observedBinding['modelClassCoverageClassRef'],
        releaseAssignment['modelClassCoverageClassRef'],
      );
      final limitations = verification['limitations'] as Map<String, dynamic>;
      expect(limitations['runtimeStateObservedOnly'], isTrue);
      expect(limitations['runtimeConfigurationAppliedByHarness'], isFalse);
      expect(limitations['aiConfigMutationsWrittenByHarness'], isFalse);
      expect(
        const JsonEncoder().convert(verification),
        allOf(
          isNot(contains('agent-private-')),
          isNot(contains('template-private-')),
          isNot(contains('profile-private-')),
        ),
      );
    },
  );

  test(
    'source-aware validation rejects fabricated resolver snapshot evidence',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );
      final fabricated =
          jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;
      (fabricated['runtimeResolverSnapshot'] as Map<String, dynamic>)
        ..['runtimeResolverSnapshotRef'] = digestFixture(
          'fabricated-runtime-snapshot-ref',
        )
        ..['snapshotDigest'] = digestFixture('fabricated-runtime-snapshot');
      fabricated['runtimeVerificationRef'] =
          EvalUseCaseRuntimeVerification.runtimeVerificationRef(fabricated);

      expect(EvalUseCaseRuntimeVerification.validate(fabricated), isEmpty);

      final issues =
          EvalUseCaseRuntimeVerification.validateAgainstRuntimeResolverSnapshot(
            fabricated,
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            runtimeResolverSnapshot: resolverSnapshot,
          );

      expect(
        issues,
        contains(
          'runtimeResolverSnapshot.runtimeResolverSnapshotRef must match source snapshot',
        ),
      );
      expect(
        issues,
        contains(
          'runtimeResolverSnapshot.snapshotDigest must match source snapshot',
        ),
      );
    },
  );

  test(
    'runtime verification rejects forged private locator snapshots without source packets',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final forgedSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final observationSource =
          forgedSnapshot['runtimeObservationSource'] as Map<String, dynamic>;
      final runtimeBindingCount =
          (forgedSnapshot['runtimeBindings'] as List<dynamic>).length;
      observationSource
        ..['mode'] = EvalUseCaseRuntimeResolverSnapshot
            .runtimeObservationModePrivateRuntimeStateLocator
        ..['sourceResolverPacketDigest'] = digestFixture(
          'forged-runtime-resolver-packet',
        )
        ..['sourceLocatorPacketDigest'] = digestFixture(
          'forged-runtime-locator-packet',
        )
        ..['sourceLocatorPacketRef'] = digestFixture(
          'forged-runtime-locator-ref',
        )
        ..['sourceLocatorPacketRequiredAssignmentRefsDigest'] =
            observationSource['sourceResolverPacketRequiredAssignmentRefsDigest']
        ..['sourceLocatorPacketLocatorCount'] = runtimeBindingCount;
      forgedSnapshot['runtimeResolverSnapshotRef'] =
          EvalUseCaseRuntimeVerification.runtimeResolverSnapshotRef(
            forgedSnapshot,
          );

      expect(
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          forgedSnapshot,
        ),
        isEmpty,
      );

      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: forgedSnapshot,
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );

      expect(verification['status'], 'invalid');
      expect(
        verification['verifiedAssignmentRefs'],
        isEmpty,
      );
      expect(
        verification['issues'],
        contains(
          allOf(
            containsPair('code', 'runtime.resolverSnapshotContractInvalid'),
            containsPair(
              'message',
              'runtime resolver snapshots require source resolver packet',
            ),
          ),
        ),
      );
      expect(
        verification['issues'],
        contains(
          allOf(
            containsPair('code', 'runtime.resolverSnapshotContractInvalid'),
            containsPair(
              'message',
              'private runtime resolver snapshots require source locator packet',
            ),
          ),
        ),
      );
    },
  );

  test(
    'source-aware validation rejects restamped resolver snapshot metadata',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );
      final restamped =
          jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;
      (restamped['runtimeResolverSnapshot'] as Map<String, dynamic>)
        ..['capturedAt'] = DateTime.utc(2026, 6, 13).toIso8601String()
        ..['contractIssueCount'] = 7
        ..['runtimeBindingCount'] = 7;

      expect(EvalUseCaseRuntimeVerification.validate(restamped), isEmpty);

      final issues =
          EvalUseCaseRuntimeVerification.validateAgainstRuntimeResolverSnapshot(
            restamped,
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            runtimeResolverSnapshot: resolverSnapshot,
          );

      expect(
        issues,
        contains(
          'runtimeResolverSnapshot.capturedAt must match source snapshot',
        ),
      );
      expect(
        issues,
        contains(
          'runtimeResolverSnapshot.contractIssueCount must match source snapshot',
        ),
      );
      expect(
        issues,
        contains(
          'runtimeResolverSnapshot.runtimeBindingCount must match source snapshot',
        ),
      );
    },
  );

  test('runtime verification rejects artifact-only resolver packet replay', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = _runtimeResolverPacket(releasePlan, releaseGate);
    final replayedPacket =
        jsonDecode(jsonEncode(resolverPacket)) as Map<String, dynamic>;
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );

    expect(
      EvalUseCaseRuntimeResolverSnapshot.validatePacket(replayedPacket),
      isEmpty,
    );

    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: replayedPacket,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(verification['status'], 'invalid');
    expect(
      verification['issues'],
      contains(
        allOf(
          containsPair('code', 'runtime.resolverSnapshotContractInvalid'),
          containsPair(
            'message',
            'source runtime resolver packet sources must be verified',
          ),
        ),
      ),
    );
  });

  test(
    'runtime verification rejects artifact-only resolver snapshot replay',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverPacket = _runtimeResolverPacket(releasePlan, releaseGate);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final replayedSnapshot =
          jsonDecode(jsonEncode(resolverSnapshot)) as Map<String, dynamic>;

      expect(
        EvalUseCaseRuntimeResolverSnapshot.hasVerifiedSnapshotSources(
          replayedSnapshot,
        ),
        isFalse,
      );

      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: replayedSnapshot,
        runtimeResolverPacket: resolverPacket,
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );

      expect(verification['status'], 'invalid');
      expect(
        verification['issues'],
        contains(
          allOf(
            containsPair('code', 'runtime.resolverSnapshotContractInvalid'),
            containsPair(
              'message',
              'source runtime resolver snapshot sources must be verified',
            ),
          ),
        ),
      );
    },
  );

  test(
    'source replay rejects direct observation relabeled from manual input',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverPacket = _runtimeResolverPacket(releasePlan, releaseGate);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final relabeled =
          jsonDecode(jsonEncode(resolverSnapshot)) as Map<String, dynamic>;
      final observationSource =
          relabeled['runtimeObservationSource'] as Map<String, dynamic>;
      observationSource['mode'] = EvalUseCaseRuntimeResolverSnapshot
          .runtimeObservationModeDirectRuntimeObservation;
      relabeled['runtimeResolverSnapshotRef'] =
          EvalUseCaseRuntimeVerification.runtimeResolverSnapshotRef(relabeled);

      expect(
        () => source_replay.assertRuntimeResolverSnapshotMatchesSources(
          relabeled,
          releasePlan: releasePlan,
          releaseGate: releaseGate,
          resolverPackets: [resolverPacket],
          locatorPackets: const [],
          completedBindingSources: [
            (resolverSnapshot['runtimeBindings'] as List<dynamic>)
                .cast<Map<String, dynamic>>(),
          ],
          privateRuntimeStates: const [],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains(
              'Runtime resolver snapshot mode directRuntimeObservation '
              'requires direct source evidence',
            ),
          ),
        ),
      );
    },
  );

  test(
    'source replay accepts source-bound direct observation evidence',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverPacket = _runtimeResolverPacket(releasePlan, releaseGate);
      final completedBindings = _runtimeCompletedBindings(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final directSource =
          EvalUseCaseRuntimeResolverSnapshot.buildDirectObservationSource(
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            resolverPacket: resolverPacket,
            completedBindings: completedBindings,
            observedAt: DateTime.utc(2026, 6, 12, 19, 30),
          );
      final directSnapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        completedBindings: completedBindings,
        runtimeObservationSource:
            EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceForDirectObservation(
              resolverPacket: resolverPacket,
            ),
        capturedAt: DateTime.utc(2026, 6, 12, 19, 30),
      );
      final replayedSnapshot =
          jsonDecode(jsonEncode(directSnapshot)) as Map<String, dynamic>;
      final replayedSource =
          jsonDecode(jsonEncode(directSource)) as Map<String, dynamic>;

      source_replay.assertRuntimeResolverSnapshotMatchesSources(
        replayedSnapshot,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        resolverPackets: [resolverPacket],
        locatorPackets: const [],
        completedBindingSources: const [],
        directObservationSources: [replayedSource],
        privateRuntimeStates: const [],
      );

      expect(
        EvalUseCaseRuntimeResolverSnapshot.hasVerifiedSnapshotSources(
          replayedSnapshot,
        ),
        isTrue,
      );
    },
  );

  test(
    'source replay rejects direct observation evidence with extra metadata',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverPacket = _runtimeResolverPacket(releasePlan, releaseGate);
      final completedBindings = _runtimeCompletedBindings(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final directSource =
          EvalUseCaseRuntimeResolverSnapshot.buildDirectObservationSource(
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            resolverPacket: resolverPacket,
            completedBindings: completedBindings,
            observedAt: DateTime.utc(2026, 6, 12, 19, 30),
          );
      final directSnapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        completedBindings: completedBindings,
        runtimeObservationSource:
            EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceForDirectObservation(
              resolverPacket: resolverPacket,
            ),
        capturedAt: DateTime.utc(2026, 6, 12, 19, 30),
      );
      final replayedSource =
          jsonDecode(jsonEncode(directSource)) as Map<String, dynamic>
            ..['operatorScratchpad'] = 'post-hoc reviewer note';

      expect(
        () => source_replay.assertRuntimeResolverSnapshotMatchesSources(
          directSnapshot,
          releasePlan: releasePlan,
          releaseGate: releaseGate,
          resolverPackets: [resolverPacket],
          locatorPackets: const [],
          completedBindingSources: const [],
          directObservationSources: [replayedSource],
          privateRuntimeStates: const [],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains(
              'directObservationSource contains unknown fields: '
              'operatorScratchpad',
            ),
          ),
        ),
      );
    },
  );

  test('private resolver snapshot rejects stale snapshot subject refs', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );
    final tampered =
        jsonDecode(jsonEncode(resolverSnapshot)) as Map<String, dynamic>;

    (tampered['summary'] as Map<String, dynamic>)['runtimeBindingCount'] = 42;

    final issues =
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          tampered,
        );

    expect(
      issues,
      contains(
        'runtimeResolverSnapshotRef must match runtime resolver snapshot subject digest',
      ),
    );
  });

  test('private resolver snapshot ref binds capturedAt', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );
    final tampered =
        jsonDecode(jsonEncode(resolverSnapshot)) as Map<String, dynamic>
          ..['capturedAt'] = DateTime.utc(
            2026,
            6,
            13,
          ).toIso8601String();

    final issues =
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          tampered,
        );

    expect(
      issues,
      contains(
        'runtimeResolverSnapshotRef must match runtime resolver snapshot subject digest',
      ),
    );
  });

  test('private resolver snapshot binding digest binds source dimensions', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );
    final tampered =
        jsonDecode(jsonEncode(resolverSnapshot)) as Map<String, dynamic>;
    ((tampered['runtimeBindings'] as List<dynamic>).single
            as Map<String, dynamic>)
        .addAll(<String, dynamic>{
          'modelClass': 'frontierReasoning',
          'sourceWorkOrderDigest': digestFixture(
            'tampered-resolver-source-work-order',
          ),
        });
    tampered['runtimeResolverSnapshotRef'] =
        EvalUseCaseRuntimeVerification.runtimeResolverSnapshotRef(tampered);

    final issues =
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          tampered,
        );

    expect(
      issues,
      contains(
        'runtimeBindings[0].resolverBindingDigest must match resolver binding subject digest',
      ),
    );
  });

  test('reports not-applied runtime bindings without pretending drift', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolutionStatus: 'notApplied',
    );

    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: _runtimeResolverPacket(releasePlan, releaseGate),
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(verification['status'], 'notApplied');
    expect(
      verification['issues'],
      contains(containsPair('code', 'runtime.assignmentNotApplied')),
    );
    final summary = verification['summary'] as Map<String, dynamic>;
    expect(summary['notAppliedCount'], summary['expectedAssignmentCount']);
    expect(summary['driftCount'], 0);
  });

  test('rejects restamped not-applied verification relabeled as verified', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolutionStatus: 'notApplied',
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final forged = jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;
    final assignmentRefs = [
      for (final assignment in forged['expectedAssignments'] as List<dynamic>)
        (assignment as Map<String, dynamic>)['assignmentRef'] as String,
    ];

    forged
      ..['status'] = 'verified'
      ..['issues'] = <Map<String, dynamic>>[]
      ..['verifiedAssignmentRefs'] = assignmentRefs;
    (forged['summary'] as Map<String, dynamic>)
      ..['verifiedAssignmentCount'] = assignmentRefs.length
      ..['notAppliedCount'] = 0
      ..['issueCount'] = 0;
    forged['runtimeVerificationRef'] =
        EvalUseCaseRuntimeVerification.runtimeVerificationRef(forged);

    final issues = EvalUseCaseRuntimeVerification.validate(forged);

    expect(
      issues,
      contains(
        'issues must match runtime verification derived assignment issues',
      ),
    );
    expect(
      issues,
      contains(
        'verifiedAssignmentRefs must match derived runtime verification state',
      ),
    );
    expect(
      issues,
      contains('status must match derived runtime verification state'),
    );
    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeVerifications: [forged],
        runtimeResolverSnapshots: [resolverSnapshot],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsStateError,
    );
  });

  test('rejects global-only drift forged from not-applied evidence', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolutionStatus: 'notApplied',
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final forged = jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;
    final assignmentRefs = [
      for (final assignment in forged['expectedAssignments'] as List<dynamic>)
        (assignment as Map<String, dynamic>)['assignmentRef'] as String,
    ];

    forged
      ..['status'] = 'drift'
      ..['issues'] = const [
        <String, dynamic>{
          'code': 'runtime.syntheticGlobalBlocker',
          'severity': 'blocking',
        },
      ]
      ..['verifiedAssignmentRefs'] = assignmentRefs;
    (forged['summary'] as Map<String, dynamic>)
      ..['verifiedAssignmentCount'] = assignmentRefs.length
      ..['notAppliedCount'] = 0
      ..['issueCount'] = 1;
    forged['runtimeVerificationRef'] =
        EvalUseCaseRuntimeVerification.runtimeVerificationRef(forged);

    final issues = EvalUseCaseRuntimeVerification.validate(forged);

    expect(
      issues,
      contains(
        'issues must match runtime verification derived assignment issues',
      ),
    );
    expect(
      issues,
      contains(
        'verifiedAssignmentRefs must match derived runtime verification state',
      ),
    );
    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeVerifications: [forged],
        runtimeResolverSnapshots: [resolverSnapshot],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsStateError,
    );
  });

  test('rejects unsubstantiated source-blocking issue smuggling', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolutionStatus: 'notApplied',
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final forged = jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;
    final assignmentRefs = [
      for (final assignment in forged['expectedAssignments'] as List<dynamic>)
        (assignment as Map<String, dynamic>)['assignmentRef'] as String,
    ];

    forged
      ..['status'] = 'blockedReleaseGate'
      ..['issues'] = const [
        <String, dynamic>{
          'code': 'runtime.releaseGateNotApproved',
          'severity': 'blocking',
          'releaseGateStatus': 'changesRequested',
        },
      ]
      ..['verifiedAssignmentRefs'] = assignmentRefs;
    (forged['summary'] as Map<String, dynamic>)
      ..['verifiedAssignmentCount'] = assignmentRefs.length
      ..['notAppliedCount'] = 0
      ..['issueCount'] = 1;
    forged['runtimeVerificationRef'] =
        EvalUseCaseRuntimeVerification.runtimeVerificationRef(forged);

    final issues = EvalUseCaseRuntimeVerification.validate(forged);

    expect(
      issues,
      contains(
        'runtime.releaseGateNotApproved issue must match sourceReleaseGate.status',
      ),
    );
    expect(
      issues,
      contains(
        'verifiedAssignmentRefs must match derived runtime verification state',
      ),
    );
    expect(
      () => EvalUseCaseRuntimeRolloutLedger.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeVerifications: [forged],
        runtimeResolverSnapshots: [resolverSnapshot],
        generatedAt: DateTime.utc(2026, 6, 13, 8),
      ),
      throwsStateError,
    );
  });

  test('public verification ref rejects relabeled resolver snapshot refs', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final tampered =
        jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;

    (tampered['runtimeResolverSnapshot']
        as Map<String, dynamic>)['runtimeResolverSnapshotRef'] = digestFixture(
      'wrong-runtime-resolver-snapshot-ref',
    );

    final issues = EvalUseCaseRuntimeVerification.validate(tampered);

    expect(
      issues,
      contains(
        'runtimeVerificationRef must match runtime verification subject digest',
      ),
    );
  });

  test('public verification ref rejects tampered observed rows', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final tampered =
        jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;
    final observedBinding =
        (tampered['observedRuntimeBindings'] as List<dynamic>).first
            as Map<String, dynamic>;

    (observedBinding['observed']
        as Map<String, dynamic>)['promptDirectiveDigest'] = digestFixture(
      'tampered-public-observed-directive',
    );
    observedBinding['resolverBindingDigest'] = _resolverBindingDigest(
      observedBinding,
    );

    final issues = EvalUseCaseRuntimeVerification.validate(tampered);

    expect(
      issues,
      contains(
        'runtimeVerificationRef must match runtime verification subject digest',
      ),
    );
  });

  test('rejects release gate source assignment-ref digest drift', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final tamperedGate = releaseGateWithTamperedApprovedRefs(
      gate: releaseGate,
      approvedAssignmentRefs: const [],
      rewriteSourceAssignmentRefsDigest: true,
    );
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );

    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: tamperedGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: _runtimeResolverPacket(releasePlan, releaseGate),
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(verification['status'], 'invalid');
    expect(
      verification['issues'],
      contains(
        containsPair('code', 'runtime.releaseGateContractInvalid'),
      ),
    );
    expect(
      verification['issues'],
      contains(
        containsPair(
          'message',
          'approvedAssignmentRefs must match releasePlan assignments',
        ),
      ),
    );
  });

  test('rejects release gate source review-bundle provenance drift', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseReviewBundle = buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
    );
    final releaseGate = _releaseGate(releasePlan);
    final tamperedGate = releaseGateWithTamperedSourceBundle(
      gate: releaseGate,
      sourceReleaseReviewPacketRef: digestFixture(
        'runtime-verification-forged-review-packet',
      ),
    );
    expect(EvalUseCaseTuningReleaseGate.validate(tamperedGate), isEmpty);

    final issues = EvalUseCaseTuningReleaseGate.validateAgainstSources(
      tamperedGate,
      releasePlan: releasePlan,
      releaseReviewBundles: [releaseReviewBundle],
    );

    expect(
      issues,
      contains(
        'sourceReviewBundles must match release review bundles',
      ),
    );
  });

  test(
    'restamped private resolver source relabels invalidate source marker',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final tampered =
          jsonDecode(jsonEncode(resolverSnapshot)) as Map<String, dynamic>;
      final binding =
          (tampered['runtimeBindings'] as List<dynamic>).single
              as Map<String, dynamic>;

      binding['sourceWorkOrderDigest'] = digestFixture(
        'tampered-restamped-source-work-order',
      );
      binding['resolverBindingDigest'] =
          EvalUseCaseRuntimeVerification.runtimeResolverBindingDigest(binding);
      tampered['runtimeResolverSnapshotRef'] =
          EvalUseCaseRuntimeVerification.runtimeResolverSnapshotRef(tampered);

      expect(
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          tampered,
        ),
        isEmpty,
      );

      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: tampered,
        runtimeResolverPacket: _runtimeResolverPacket(releasePlan, releaseGate),
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );

      expect(verification['status'], 'invalid');
      expect(
        verification['issues'],
        contains(
          allOf(
            containsPair('code', 'runtime.resolverSnapshotContractInvalid'),
            containsPair(
              'message',
              'source runtime resolver snapshot sources must be verified',
            ),
          ),
        ),
      );
    },
  );

  test('detects prompt directive digest drift', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      observedDigestOverrides: <String, String>{
        'promptDirectiveDigest': digestFixture('wrong-active-directive'),
      },
    );

    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: _runtimeResolverPacket(releasePlan, releaseGate),
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(verification['status'], 'drift');
    expect(
      verification['issues'],
      contains(
        allOf(
          containsPair('code', 'runtime.effectiveBindingDrift'),
          containsPair('field', 'promptDirectiveDigest'),
        ),
      ),
    );
  });

  test(
    'rejects unapproved extras after snapshot source marking',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      (resolverSnapshot['runtimeBindings'] as List<dynamic>).add(
        _extraBinding(),
      );
      (resolverSnapshot['summary']
              as Map<String, dynamic>)['runtimeBindingCount'] =
          (resolverSnapshot['runtimeBindings'] as List<dynamic>).length;
      resolverSnapshot['runtimeResolverSnapshotRef'] =
          EvalUseCaseRuntimeVerification.runtimeResolverSnapshotRef(
            resolverSnapshot,
          );

      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        runtimeResolverPacket: _runtimeResolverPacket(releasePlan, releaseGate),
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );

      expect(verification['status'], 'invalid');
      expect(
        verification['issues'],
        contains(
          allOf(
            containsPair('code', 'runtime.resolverSnapshotContractInvalid'),
            containsPair(
              'message',
              'source runtime resolver snapshot sources must be verified',
            ),
          ),
        ),
      );
    },
  );

  test('rejects stale release gate and resolver snapshot bindings', () {
    final releasePlan = buildReleasePlanFixture();
    final stalePlan = buildReleasePlanFixture(
      modelClass: 'frontierReasoning',
      promptVariantName: 'reasoning-v1',
      cellSeed: 'task-frontier-reasoning',
      reportSeed: 'task-report-reasoning',
    );
    final staleGate = _releaseGate(stalePlan);
    final staleSnapshot = _runtimeResolverSnapshot(
      releasePlan: stalePlan,
      releaseGate: staleGate,
    );

    final staleGateVerification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: staleGate,
      runtimeResolverSnapshot: staleSnapshot,
      runtimeResolverPacket: _runtimeResolverPacket(stalePlan, staleGate),
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    expect(staleGateVerification['status'], 'invalid');
    expect(
      staleGateVerification['issues'],
      contains(containsPair('code', 'runtime.releaseGateSourceMismatch')),
    );
    expect(
      staleGateVerification['issues'],
      contains(containsPair('code', 'runtime.releaseGateProofSummaryMismatch')),
    );

    final releaseGate = _releaseGate(releasePlan);
    final staleSnapshotVerification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: staleSnapshot,
      runtimeResolverPacket: _runtimeResolverPacket(stalePlan, staleGate),
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    expect(staleSnapshotVerification['status'], 'invalid');
    expect(
      staleSnapshotVerification['issues'],
      contains(
        containsPair('code', 'runtime.resolverSnapshotReleasePlanMismatch'),
      ),
    );
    expect(
      staleSnapshotVerification['issues'],
      contains(
        containsPair('code', 'runtime.resolverSnapshotProofSummaryMismatch'),
      ),
    );
  });

  test('blocks runtime verification until release gate is approved', () {
    final releasePlan = buildReleasePlanFixture();
    final blockedGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(
      () => _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: blockedGate,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('runtimeResolver.releaseGateNotApproved'),
        ),
      ),
    );
  });

  test('private resolver snapshot allows ids but rejects paths and commands', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );

    expect(
      EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
        resolverSnapshot,
      ),
      isEmpty,
    );

    final tampered =
        jsonDecode(jsonEncode(resolverSnapshot)) as Map<String, dynamic>
          ..['notes'] =
              'Use file:///private/tmp/runtime.json with EVAL_USE_CASE_RUNTIME_VERIFICATION and TaskAgentService.updateAgentProfile.';
    final binding =
        ((tampered['runtimeBindings'] as List<dynamic>).first
              as Map<String, dynamic>)
          ..['resolverBindingDigest'] = digestFixture(
            'wrong-resolver-binding',
          )
          ..['command'] = 'sqlite3 prod.db';

    expect(binding, isNotEmpty);
    final issues =
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          tampered,
        );

    expect(
      issues,
      contains(
        'runtimeResolverSnapshot.notes must not contain private paths',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeResolverSnapshot.notes must not contain private env value keys',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeResolverSnapshot.notes must not contain mutation commands',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeResolverSnapshot.runtimeBindings[0].command must not contain mutation commands',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeBindings[0].resolverBindingDigest must match resolver binding subject digest',
      ),
    );
  });

  test('public verification rejects leaked private ids and env commands', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverSnapshot = _runtimeResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final tampered =
        jsonDecode(jsonEncode(verification)) as Map<String, dynamic>
          ..['profileId'] = 'private-profile-id'
          ..['runtimeVerificationRef'] = digestFixture(
            'wrong-runtime-verification-ref',
          )
          ..['notes'] = 'EVAL_USE_CASE_RUNTIME_VERIFICATION';
    (tampered['sourceReleaseGate']
            as Map<String, dynamic>)['modelClassCoverageProofSummaryDigest'] =
        digestFixture('wrong-source-gate-proof-summary');
    ((tampered['observedRuntimeBindings'] as List<dynamic>).first
        as Map<String, dynamic>)['privateRuntimeIds'] = const <String, dynamic>{
      'agentId': 'agent-private-1',
    };

    final issues = EvalUseCaseRuntimeVerification.validate(tampered);

    expect(
      issues,
      contains(
        'runtimeVerification.profileId must not expose private runtime ids',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeVerification.notes must not contain private env value keys',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeVerificationRef must match runtime verification subject digest',
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
        'observedRuntimeBindings[0] must not contain privateRuntimeIds',
      ),
    );
    expect(
      issues,
      contains(
        'runtimeVerification.observedRuntimeBindings[0].privateRuntimeIds must not expose private runtime ids',
      ),
    );
  });

  test(
    'public verification rejects restamped recommended command templates',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverSnapshot = _runtimeResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      );
      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );
      final tampered =
          jsonDecode(jsonEncode(verification)) as Map<String, dynamic>;
      ((tampered['recommendedCommands'] as List<dynamic>).single
            as Map<String, dynamic>)
        ..['mode'] = 'report'
        ..['command'] = 'eval/run_level2.sh report';

      final issues = EvalUseCaseRuntimeVerification.validate(tampered);

      expect(
        issues,
        contains(
          'recommendedCommands must match static recommended command templates',
        ),
      );
    },
  );

  test('source-aware runtime verification rejects restamped resolver chain', () {
    const releaseFixture = ReleaseScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      agentKind: releaseFixtureAgentKind,
      modelClass: 'frontierFast',
      promptVariantName: 'metadata-first-v2',
      cellSeed: 'task-frontier-fast',
      reportSeed: 'task-report',
    );
    final ledger = buildReleaseDecisionLedgerFixture(
      releaseFixture.acceptedDecision(),
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
    final forgedGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: forged,
      releaseReviewBundles: [forgedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: forged,
      releaseGate: forgedGate,
      releaseReviewBundles: [forgedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19, 30),
    );
    final resolverSnapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: forged,
      releaseGate: forgedGate,
      completedBindings: _runtimeCompletedBindings(
        releasePlan: forged,
        releaseGate: forgedGate,
      ),
      runtimeObservationSource:
          EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
            resolverPacket: resolverPacket,
            mode: EvalUseCaseRuntimeResolverSnapshot
                .runtimeObservationModeManualCompletedBindingImport,
          ),
      capturedAt: DateTime.utc(2026, 6, 12, 19, 45),
    );

    final localVerification = EvalUseCaseRuntimeVerification.build(
      releasePlan: forged,
      releaseGate: forgedGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: resolverPacket,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    expect(localVerification['status'], 'verified');

    final sourceAwareVerification = EvalUseCaseRuntimeVerification.build(
      releasePlan: forged,
      releaseGate: forgedGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: resolverPacket,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(sourceAwareVerification['status'], 'invalid');
    expect(
      sourceAwareVerification['issues'],
      contains(
        allOf(
          containsPair('code', 'runtime.releasePlanContractInvalid'),
          containsPair(
            'message',
            contains('release plan must match source roadmap and ledgers'),
          ),
        ),
      ),
    );
  });

  test('source-aware runtime verification requires release review bundles', () {
    final sourceFixture = buildDecisionLedgerSourceBoundReleaseFixture();
    final ledger = sourceFixture.ledger;
    final roadmap = sourceFixture.roadmap;
    final releasePlan = sourceFixture.releasePlan;
    final bundle = buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
    );
    final releaseGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [bundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      releaseReviewBundles: [bundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 19, 30),
    );
    final resolverSnapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      completedBindings: _runtimeCompletedBindings(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      ),
      runtimeObservationSource:
          EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
            resolverPacket: resolverPacket,
            mode: EvalUseCaseRuntimeResolverSnapshot
                .runtimeObservationModeManualCompletedBindingImport,
          ),
      capturedAt: DateTime.utc(2026, 6, 12, 19, 45),
    );

    final withoutBundles = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: resolverPacket,
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    expect(withoutBundles['status'], 'invalid');
    expect(
      withoutBundles['issues'],
      contains(
        allOf(
          containsPair('code', 'runtime.releaseGateContractInvalid'),
          containsPair(
            'message',
            contains('release gate review sources must be supplied'),
          ),
        ),
      ),
    );

    final withBundles = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: resolverSnapshot,
      runtimeResolverPacket: resolverPacket,
      releaseReviewBundles: [bundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    expect(withBundles['status'], 'verified');
  });

  test(
    'writes use-case runtime verification',
    () async {
      final releasePlan =
          jsonDecode(File(_runtimeVerifyReleasePlanPath).readAsStringSync())
              as Map<String, dynamic>;
      final releaseGate =
          jsonDecode(File(_runtimeVerifyReleaseGatePath).readAsStringSync())
              as Map<String, dynamic>;
      final resolverSnapshot =
          jsonDecode(
                File(_effectiveRuntimeResolverSnapshotPath).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final resolverPacket = _readOptionalJson(_runtimeResolverPacketPath);
      final locatorPacket = _readOptionalJson(_runtimeLocatorPacketPath);
      final releaseReviewBundles = readReleaseReviewBundlesFixture(
        _runtimeVerifyReleaseReviewAttestations,
      );
      final sourceInputs = await _readReleasePlanSourceInputs();
      if (resolverPacket != null) {
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
      source_replay.assertRuntimeResolverSnapshotMatchesSources(
        resolverSnapshot,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        resolverPackets: resolverPacket == null
            ? const <Map<String, dynamic>>[]
            : [resolverPacket],
        locatorPackets: locatorPacket == null
            ? const <Map<String, dynamic>>[]
            : [locatorPacket],
        completedBindingSources: source_replay.readCompletedBindingSources(
          _runtimeVerifyResolverInputPaths,
        ),
        directObservationSources: source_replay.readDirectObservationSources(
          _runtimeVerifyDirectObservationPaths,
        ),
        privateRuntimeStates: source_replay.readJsonObjects(
          _runtimeVerifyStateInputPaths,
        ),
      );
      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        runtimeResolverPacket: resolverPacket,
        runtimeLocatorPacket: locatorPacket,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      EvalUseCaseRuntimeVerification.assertValid(verification);
      EvalUseCaseRuntimeVerification.assertMatchesRuntimeResolverSnapshot(
        verification,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        runtimeResolverPacket: resolverPacket,
        runtimeLocatorPacket: locatorPacket,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      writeEvalJsonArtifact(
        verification,
        path: _runtimeVerificationOutputPath,
        overwrite: _runtimeVerificationOverwrite == '1',
        description: 'use-case runtime verification',
      );
    },
    skip:
        _runtimeVerifyReleasePlanPath.isEmpty ||
            _runtimeVerifyReleaseGatePath.isEmpty ||
            _runtimeVerifyReleaseReviewAttestations.isEmpty ||
            _runtimeVerifyRoadmapInputPath.isEmpty ||
            _runtimeVerifyDecisionLedgerPaths.isEmpty ||
            _runtimeVerifyDecisionLedgerSourceManifestPaths.isEmpty ||
            _runtimeResolverPacketPath.isEmpty ||
            (_runtimeVerifyResolverInputPaths.isEmpty &&
                _runtimeVerifyDirectObservationPaths.isEmpty &&
                _runtimeVerifyStateInputPaths.isEmpty) ||
            _effectiveRuntimeResolverSnapshotPath.isEmpty ||
            _runtimeVerificationOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_PLAN=<json>, '
              'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_GATE=<json>, '
              'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_REVIEW_ATTESTATIONS=<json>, '
              'EVAL_USE_CASE_RUNTIME_VERIFY_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RUNTIME_VERIFY_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=<json>, '
              'EVAL_USE_CASE_RUNTIME_VERIFY_RESOLVER_INPUTS=<a.json,b.json>, '
              'EVAL_USE_CASE_RUNTIME_VERIFY_DIRECT_OBSERVATIONS=<a.json,b.json>, '
              'or EVAL_USE_CASE_RUNTIME_VERIFY_STATE_INPUTS=<a.json,b.json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT=<json>, and '
              'EVAL_USE_CASE_RUNTIME_VERIFICATION=<json> to write runtime verification. '
              'For privateRuntimeStateLocator snapshots, also set '
              'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET=<json>.'
        : false,
  );
}

String get _effectiveRuntimeResolverSnapshotPath =>
    _runtimeResolverSnapshotPath.isNotEmpty
    ? _runtimeResolverSnapshotPath
    : _runtimeStateSnapshotPath;

Map<String, dynamic>? _readOptionalJson(String path) {
  if (path.isEmpty) return null;
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Future<ReleasePlanSourceInputsFixture> _readReleasePlanSourceInputs() =>
    readReleasePlanSourceInputsFixture(
      roadmapInputPath: _runtimeVerifyRoadmapInputPath,
      decisionLedgerPaths: _runtimeVerifyDecisionLedgerPaths,
      decisionLedgerSourceManifestPaths:
          _runtimeVerifyDecisionLedgerSourceManifestPaths,
      previousReleasePlanPath: _runtimeVerifyPreviousReleasePlanPath,
      runtimeRolloutLedgerPaths: _runtimeVerifyRuntimeRolloutLedgerPaths,
      runtimePreviousRolloutLedgerPaths:
          _runtimeVerifyRuntimePreviousRolloutLedgerPaths,
      runtimeLedgerReleaseGatePaths:
          _runtimeVerifyRuntimeLedgerReleaseGatePaths,
      runtimeLedgerReleaseReviewAttestations:
          _runtimeVerifyRuntimeLedgerReleaseReviewAttestations,
      runtimeVerificationPaths: _runtimeVerifyRuntimeVerificationPaths,
      runtimeLedgerResolverSnapshotPaths:
          _runtimeVerifyRuntimeLedgerResolverSnapshotPaths,
      runtimeLedgerResolverPacketPaths:
          _runtimeVerifyRuntimeLedgerResolverPacketPaths,
      runtimeLedgerLocatorPacketPaths:
          _runtimeVerifyRuntimeLedgerLocatorPacketPaths,
      runtimeLedgerResolverInputPaths:
          _runtimeVerifyRuntimeLedgerResolverInputPaths,
      runtimeLedgerDirectObservationPaths:
          _runtimeVerifyRuntimeLedgerDirectObservationPaths,
      runtimeLedgerStateInputPaths: _runtimeVerifyRuntimeLedgerStateInputPaths,
      previousReleasePlanEnvName:
          'EVAL_USE_CASE_RUNTIME_VERIFY_PREVIOUS_RELEASE_PLAN',
      runtimeRolloutLedgersEnvName:
          'EVAL_USE_CASE_RUNTIME_VERIFY_RUNTIME_ROLLOUT_LEDGERS',
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

Map<String, dynamic> _releaseGate(Map<String, dynamic> releasePlan) {
  final bundle = buildReleaseReviewBundleFixture(releasePlan: releasePlan);
  return EvalUseCaseTuningReleaseGate.build(
    releasePlan: releasePlan,
    releaseReviewBundles: [bundle],
    generatedAt: DateTime.utc(2026, 6, 12, 19),
  );
}

Map<String, dynamic> _runtimeResolverPacket(
  Map<String, dynamic> releasePlan,
  Map<String, dynamic> releaseGate,
) {
  return EvalUseCaseRuntimeResolverSnapshot.buildPacket(
    releasePlan: releasePlan,
    releaseGate: releaseGate,
    generatedAt: DateTime.utc(2026, 6, 12, 19, 30),
  );
}

Map<String, dynamic> _runtimeResolverSnapshot({
  required Map<String, dynamic> releasePlan,
  required Map<String, dynamic> releaseGate,
  String resolutionStatus = 'applied',
  Map<String, dynamic> overrides = const {},
  Map<String, String> observedDigestOverrides = const {},
}) {
  final bindings = _runtimeCompletedBindings(
    releasePlan: releasePlan,
    releaseGate: releaseGate,
    resolutionStatus: resolutionStatus,
    overrides: overrides,
    observedDigestOverrides: observedDigestOverrides,
  );
  final resolverPacket = _runtimeResolverPacket(releasePlan, releaseGate);
  return EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
    releasePlan: releasePlan,
    releaseGate: releaseGate,
    completedBindings: bindings,
    runtimeObservationSource:
        EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
          resolverPacket: resolverPacket,
          mode: EvalUseCaseRuntimeResolverSnapshot
              .runtimeObservationModeManualCompletedBindingImport,
        ),
    capturedAt: DateTime.utc(2026, 6, 12, 19, 30),
  );
}

List<Map<String, dynamic>> _runtimeCompletedBindings({
  required Map<String, dynamic> releasePlan,
  required Map<String, dynamic> releaseGate,
  String resolutionStatus = 'applied',
  Map<String, dynamic> overrides = const {},
  Map<String, String> observedDigestOverrides = const {},
}) {
  final approvedRefs = _stringList(releaseGate['approvedAssignmentRefs'])
    ..sort();
  final approvedRefSet = approvedRefs.toSet();
  return [
    for (final assignment in _mapList(releasePlan['runtimeAssignments']))
      if (approvedRefSet.contains(assignment['assignmentRef']))
        _bindingFor(
          assignment: assignment,
          releasePlan: releasePlan,
          releaseGate: releaseGate,
          approvedAssignmentRefsDigest: EvalProvenance.digestJson(
            approvedRefs,
          ),
          resolutionStatus: resolutionStatus,
          overrides: overrides,
          observedDigestOverrides: observedDigestOverrides,
        ),
  ];
}

Map<String, dynamic> _bindingFor({
  required Map<String, dynamic> assignment,
  required Map<String, dynamic> releasePlan,
  required Map<String, dynamic> releaseGate,
  required String approvedAssignmentRefsDigest,
  required String resolutionStatus,
  required Map<String, dynamic> overrides,
  required Map<String, String> observedDigestOverrides,
}) {
  final assignmentRef = assignment['assignmentRef'] as String;
  final expectedDigests = _runtimeDigests(assignment);
  final observedDigests = <String, dynamic>{
    ...expectedDigests,
    ...observedDigestOverrides,
  };
  final binding = <String, dynamic>{
    'assignmentRef': assignmentRef,
    'sourceReleasePlanDigest': EvalProvenance.digestJson(releasePlan),
    'sourceReleaseGateRef': releaseGate['releaseGateRef'],
    'sourceReleaseGateDigest': EvalProvenance.digestJson(releaseGate),
    'approvedAssignmentRefsDigest': approvedAssignmentRefsDigest,
    'modelClassCoverageProofSummaryDigest':
        (releasePlan['modelClassCoverageProofSummary']
            as Map<String, dynamic>)['proofSummaryDigest'],
    'scopeKey': assignment['scopeKey'],
    'targetSurface': assignment['targetSurface'],
    'primaryCapabilityId': assignment['primaryCapabilityId'],
    'agentKind': assignment['agentKind'],
    'productionAgentKind': 'task_agent',
    'modelClass': assignment['modelClass'],
    'promptVariantName': assignment['promptVariantName'],
    'modelClassCoverageProofRef': assignment['modelClassCoverageProofRef'],
    'modelClassCoverageClassRef': assignment['modelClassCoverageClassRef'],
    'workOrderBatchRef': assignment['workOrderBatchRef'],
    'modelClassCoverageRef': assignment['modelClassCoverageRef'],
    'modelClassCoverageDigest': assignment['modelClassCoverageDigest'],
    'sourceWorkOrderDigest': assignment['sourceWorkOrderDigest'],
    'requiredDigestFields':
        EvalUseCaseRuntimeResolverSnapshot.runtimeDigestFields,
    'requiredRuntimeSurfaces': const [
      'ProfileResolver',
      'TaskAgentService',
      'AgentTemplateService',
      'AiConfigRepository',
    ],
    'status': 'resolved',
    'resolutionStatus': resolutionStatus,
    'runtimeTargetRef': digestFixture('runtime-target-$assignmentRef'),
    'expected': expectedDigests,
    'observed': observedDigests,
    'privateRuntimeIds': <String, dynamic>{
      'agentId': 'agent-private-$assignmentRef',
      'templateId': 'template-private-$assignmentRef',
      'profileId': 'profile-private-$assignmentRef',
    },
    ...overrides,
  };
  binding['resolverBindingDigest'] = _resolverBindingDigest(binding);
  return binding;
}

Map<String, dynamic> _extraBinding() {
  final assignmentRef = digestFixture('unapproved-assignment');
  final digests = <String, dynamic>{
    'resolvedProfileDigest': digestFixture('extra-profile'),
    'providerModelBindingDigest': digestFixture('extra-provider-model'),
    'thinkingModelBindingDigest': digestFixture('extra-thinking-model'),
    'promptVariantDigest': digestFixture('extra-prompt-variant'),
    'promptDirectiveDigest': digestFixture('extra-prompt-directive'),
  };
  final binding = <String, dynamic>{
    'assignmentRef': assignmentRef,
    'scopeKey': digestFixture('extra-scope'),
    'targetSurface': 'taskDefaults',
    'primaryCapabilityId': 'task.extra',
    'agentKind': 'taskAgent',
    'productionAgentKind': 'task_agent',
    'modelClass': 'frontierFast',
    'promptVariantName': 'metadata-first-v2',
    'modelClassCoverageProofRef': digestFixture('extra-proof'),
    'modelClassCoverageClassRef': digestFixture('extra-proof-class'),
    'workOrderBatchRef': digestFixture('extra-work-order-batch'),
    'modelClassCoverageRef': 'coverage-extra',
    'modelClassCoverageDigest': digestFixture('extra-coverage'),
    'sourceWorkOrderDigest': digestFixture('extra-source-work-order'),
    'resolutionStatus': 'applied',
    'runtimeTargetRef': digestFixture('extra-runtime-target'),
    'expected': digests,
    'observed': digests,
    'privateRuntimeIds': const <String, dynamic>{
      'agentId': 'agent-private-extra',
    },
  };
  binding['resolverBindingDigest'] = _resolverBindingDigest(binding);
  return binding;
}

String _resolverBindingDigest(Map<String, dynamic> binding) =>
    EvalUseCaseRuntimeVerification.runtimeResolverBindingDigest(binding);

Map<String, dynamic> _runtimeDigests(Map<String, dynamic> assignment) {
  final assignmentRef = assignment['assignmentRef'] as String;
  return <String, dynamic>{
    'resolvedProfileDigest': digestFixture('profile-$assignmentRef'),
    'providerModelBindingDigest': digestFixture(
      'provider-model-${assignment['modelClass']}',
    ),
    'thinkingModelBindingDigest': digestFixture(
      'thinking-model-${assignment['modelClass']}',
    ),
    'promptVariantDigest': digestFixture(
      'prompt-variant-${assignment['promptVariantName']}',
    ),
    'promptDirectiveDigest': digestFixture(
      'prompt-directive-${assignment['promptVariantName']}',
    ),
  };
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

List<String> _stringList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      ]
    : const <String>[];

List<String> _recommendedModes(Map<String, dynamic> artifact) =>
    (artifact['recommendedCommands'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((command) => command['mode'] as String)
        .toList();
