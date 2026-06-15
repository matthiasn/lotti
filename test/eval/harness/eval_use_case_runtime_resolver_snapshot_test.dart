import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_tuning_source_replay_test_utils.dart';
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
const _resolverReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN',
);
const _resolverRoadmapInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT',
);
const _resolverDecisionLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS',
);
const _resolverDecisionLedgerSourceManifestPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS',
);
const _resolverPreviousReleasePlanPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_PREVIOUS_RELEASE_PLAN',
);
const _resolverRuntimeRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_ROLLOUT_LEDGERS',
);
const _resolverRuntimePreviousRolloutLedgerPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_PREVIOUS_ROLLOUT_LEDGERS',
);
const _resolverRuntimeLedgerReleaseGatePaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_RELEASE_GATES',
);
const _resolverRuntimeLedgerReleaseReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS',
);
const _resolverRuntimeVerificationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_VERIFICATIONS',
);
const _resolverRuntimeLedgerResolverSnapshotPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS',
);
const _resolverRuntimeLedgerResolverPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_RESOLVER_PACKETS',
);
const _resolverRuntimeLedgerLocatorPacketPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_LOCATOR_PACKETS',
);
const _resolverRuntimeLedgerResolverInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_RESOLVER_INPUTS',
);
const _resolverRuntimeLedgerDirectObservationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_DIRECT_OBSERVATIONS',
);
const _resolverRuntimeLedgerStateInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RUNTIME_LEDGER_STATE_INPUTS',
);
const _resolverReleaseGatePath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE',
);
const _resolverReleaseReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS',
);
const _resolverPacketPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET',
);
const _resolverPacketOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET_OVERWRITE',
);
const _resolverInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_INPUT',
);
const _resolverSnapshotPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT',
);
const _resolverSnapshotOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT_OVERWRITE',
);

void main() {
  test('builds a private resolver packet from an approved release gate', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);

    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(EvalUseCaseRuntimeResolverSnapshot.validatePacket(packet), isEmpty);
    expect(packet['status'], 'readyForRuntimeResolution');
    final sourceGate = packet['sourceReleaseGate'] as Map<String, dynamic>;
    expect(sourceGate['releaseGateRef'], releaseGate['releaseGateRef']);
    expect(
      sourceGate['releaseGateDigest'],
      EvalProvenance.digestJson(releaseGate),
    );
    final proofSummary =
        releasePlan['modelClassCoverageProofSummary'] as Map<String, dynamic>;
    expect(
      sourceGate['modelClassCoverageProofSummaryDigest'],
      proofSummary['proofSummaryDigest'],
    );
    final bindings = (packet['requiredRuntimeBindings'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final templates = (packet['bindingTemplates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final releaseAssignment =
        (releasePlan['runtimeAssignments'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(bindings, hasLength(1));
    expect(templates, hasLength(bindings.length));
    expect(templates.single['status'], 'pending');
    expect(templates.single['productionAgentKind'], 'task_agent');
    expect(
      bindings.single['modelClassCoverageClassRef'],
      releaseAssignment['modelClassCoverageClassRef'],
    );
    expect(
      templates.single['modelClassCoverageClassRef'],
      releaseAssignment['modelClassCoverageClassRef'],
    );
    expect(
      templates.single['requiredDigestFields'],
      containsAll(EvalUseCaseRuntimeResolverSnapshot.runtimeDigestFields),
    );
    expect(
      templates.single['modelClassCoverageProofSummaryDigest'],
      proofSummary['proofSummaryDigest'],
    );
    final recommendedModes = (packet['recommendedCommands'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((command) => command['mode'])
        .toList();
    expect(
      recommendedModes,
      containsAll([
        'runtime-resolver-packet',
        'runtime-locator-packet',
        'observe-runtime-state',
        'import-runtime-resolver',
        'runtime-verify',
      ]),
    );
  });

  test('imports completed bindings into a canonical resolver snapshot', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final bindings = _completedBindings(packet);

    final snapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      completedBindings: bindings,
      runtimeObservationSource:
          EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
            resolverPacket: packet,
            mode: EvalUseCaseRuntimeResolverSnapshot
                .runtimeObservationModeManualCompletedBindingImport,
          ),
      capturedAt: DateTime.utc(2026, 6, 12, 20, 30),
    );

    expect(
      EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(snapshot),
      isEmpty,
    );
    expect(
      snapshot['runtimeResolverSnapshotRef'],
      EvalUseCaseRuntimeVerification.runtimeResolverSnapshotRef(snapshot),
    );
    final observationSource =
        snapshot['runtimeObservationSource'] as Map<String, dynamic>;
    expect(
      observationSource['mode'],
      EvalUseCaseRuntimeResolverSnapshot
          .runtimeObservationModeManualCompletedBindingImport,
    );
    expect(
      observationSource['sourceResolverPacketRequiredBindingCount'],
      bindings.length,
    );
    expect(
      observationSource,
      isNot(contains('sourceLocatorPacketDigest')),
    );
    final tamperedSourceSnapshot =
        jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    (tamperedSourceSnapshot['runtimeObservationSource']
        as Map<String, dynamic>)['mode'] = EvalUseCaseRuntimeResolverSnapshot
        .runtimeObservationModeDirectRuntimeObservation;
    expect(
      EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
        tamperedSourceSnapshot,
      ),
      contains(
        'runtimeResolverSnapshotRef must match runtime resolver snapshot subject digest',
      ),
    );
    final runtimeBinding =
        (snapshot['runtimeBindings'] as List<dynamic>).single
            as Map<String, dynamic>;
    final releaseAssignment =
        (releasePlan['runtimeAssignments'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(
      runtimeBinding['modelClassCoverageClassRef'],
      releaseAssignment['modelClassCoverageClassRef'],
    );
    expect(
      runtimeBinding['resolverBindingDigest'],
      EvalUseCaseRuntimeVerification.runtimeResolverBindingDigest(
        runtimeBinding,
      ),
    );
    expect(
      const JsonEncoder().convert(snapshot),
      allOf(
        contains('agent-private-'),
        isNot(contains('/private/tmp')),
        isNot(contains('OPENAI_API_KEY')),
      ),
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: snapshot,
      runtimeResolverPacket: packet,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    expect(verification['status'], 'verified');
  });

  test('snapshot import rejects stale custom observation sources', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final staleReleasePlan = buildReleasePlanFixture(
      compatibilitySeed: 'stale-task-compat',
      primaryCapabilityId: 'task.workflow.stale',
      cellSeed: 'stale-task-frontier-fast',
      reportSeed: 'stale-task-report',
    );
    final staleReleaseGate = _releaseGate(staleReleasePlan);
    final stalePacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: staleReleasePlan,
      releaseGate: staleReleaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    expect(
      () => EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        completedBindings: _completedBindings(packet),
        runtimeObservationSource:
            EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceForDirectObservation(
              resolverPacket: stalePacket,
            ),
        capturedAt: DateTime.utc(2026, 6, 12, 20, 30),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'runtimeObservationSource.sourceResolverPacketSourceReleasePlanDigest '
            'must match snapshot.sourceReleasePlanDigest',
          ),
        ),
      ),
    );
  });

  test('packet rejects gate source assignment-ref digest drift', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final tamperedGate = releaseGateWithTamperedApprovedRefs(
      gate: releaseGate,
      approvedAssignmentRefs: const [],
      rewriteSourceAssignmentRefsDigest: true,
    );

    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: tamperedGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(packet['status'], 'invalidReleaseGate');
    expect(
      packet['issues'],
      contains(
        containsPair('code', 'runtimeResolver.releaseGateContractInvalid'),
      ),
    );
    expect(
      packet['issues'],
      contains(
        containsPair(
          'message',
          'approvedAssignmentRefs must match releasePlan assignments',
        ),
      ),
    );
    expect(packet['requiredRuntimeBindings'], isEmpty);
  });

  test('source-aware packet rejects restamped release plan and gate', () {
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
    final forgedGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: forged,
      releaseReviewBundles: [forgedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    final localPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: forged,
      releaseGate: forgedGate,
      releaseReviewBundles: [forgedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    expect(localPacket['status'], 'readyForRuntimeResolution');

    final sourceAwarePacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: forged,
      releaseGate: forgedGate,
      releaseReviewBundles: [forgedBundle],
      sourceRoadmap: roadmap,
      sourceDecisionLedgers: [ledger],
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(
      EvalUseCaseRuntimeResolverSnapshot.validatePacket(sourceAwarePacket),
      isEmpty,
    );
    expect(sourceAwarePacket['status'], 'invalidReleasePlan');
    expect(sourceAwarePacket['requiredRuntimeBindings'], isEmpty);
    expect(
      sourceAwarePacket['issues'],
      contains(
        allOf(
          containsPair('code', 'runtimeResolver.releasePlanContractInvalid'),
          containsPair(
            'message',
            contains('release plan must match source roadmap and ledgers'),
          ),
        ),
      ),
    );
  });

  test('packet rejects restamped release gate source bundle summaries', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final tamperedGate =
        jsonDecode(jsonEncode(releaseGate)) as Map<String, dynamic>;
    ((tamperedGate['sourceReviewBundles'] as List<dynamic>).single
        as Map<String, dynamic>)['sourceQueueDigest'] = digestFixture(
      'forged-release-review-queue',
    );
    tamperedGate['releaseGateRef'] = releaseGateRefFixture(tamperedGate);

    expect(EvalUseCaseTuningReleaseGate.validate(tamperedGate), isEmpty);

    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: tamperedGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(packet['status'], 'invalidReleaseGate');
    expect(
      packet['issues'],
      contains(
        containsPair('code', 'runtimeResolver.releaseGateContractInvalid'),
      ),
    );
    expect(packet['requiredRuntimeBindings'], isEmpty);
  });

  test('packet rejects artifact-only approved release gate replay', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate =
        jsonDecode(jsonEncode(_releaseGate(releasePlan)))
            as Map<String, dynamic>;

    expect(EvalUseCaseTuningReleaseGate.validate(releaseGate), isEmpty);

    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );

    expect(packet['status'], 'invalidReleaseGate');
    expect(packet['requiredRuntimeBindings'], isEmpty);
    expect(
      packet['issues'],
      contains(
        containsPair(
          'message',
          'releaseGate review sources must be verified',
        ),
      ),
    );
  });

  test('packet source replay marks JSON-loaded resolver packets', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseReviewBundle = buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
    );
    final releaseGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [releaseReviewBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      releaseReviewBundles: [releaseReviewBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final replayed = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;

    expect(
      EvalUseCaseRuntimeResolverSnapshot.hasVerifiedPacketSources(replayed),
      isFalse,
    );
    expect(
      EvalUseCaseRuntimeResolverSnapshot.validatePacketAgainstSources(
        replayed,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        releaseReviewBundles: [releaseReviewBundle],
      ),
      isEmpty,
    );

    EvalUseCaseRuntimeResolverSnapshot.assertPacketMatchesSources(
      replayed,
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      releaseReviewBundles: [releaseReviewBundle],
    );

    expect(
      EvalUseCaseRuntimeResolverSnapshot.hasVerifiedPacketSources(replayed),
      isTrue,
    );
  });

  test('packet source replay rejects missing release-review evidence', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseReviewBundle = buildReleaseReviewBundleFixture(
      releasePlan: releasePlan,
    );
    final releaseGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      releaseReviewBundles: [releaseReviewBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      releaseReviewBundles: [releaseReviewBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final replayedGate =
        jsonDecode(jsonEncode(releaseGate)) as Map<String, dynamic>;
    final replayed = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;

    final issues =
        EvalUseCaseRuntimeResolverSnapshot.validatePacketAgainstSources(
          replayed,
          releasePlan: releasePlan,
          releaseGate: replayedGate,
        );

    expect(
      issues,
      contains('runtime resolver packet must match source artifacts'),
    );
    expect(
      EvalUseCaseRuntimeResolverSnapshot.hasVerifiedPacketSources(replayed),
      isFalse,
    );
  });

  test('packet contract rejects forged ready status for blocked gates', () {
    final releasePlan = buildReleasePlanFixture();
    final approvedGate = _releaseGate(releasePlan);
    final approvedPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: approvedGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final blockedGate = EvalUseCaseTuningReleaseGate.build(
      releasePlan: releasePlan,
      generatedAt: DateTime.utc(2026, 6, 12, 19),
    );
    final forged =
        EvalUseCaseRuntimeResolverSnapshot.buildPacket(
            releasePlan: releasePlan,
            releaseGate: blockedGate,
            generatedAt: DateTime.utc(2026, 6, 12, 20),
          )
          ..['status'] = 'readyForRuntimeResolution'
          ..['requiredRuntimeBindings'] = jsonDecode(
            jsonEncode(approvedPacket['requiredRuntimeBindings']),
          )
          ..['bindingTemplates'] = jsonDecode(
            jsonEncode(approvedPacket['bindingTemplates']),
          );
    final summary = forged['summary'] as Map<String, dynamic>
      ..['requiredRuntimeBindingCount'] = 1
      ..['bindingTemplateCount'] = 1;

    expect(summary['requiredRuntimeBindingCount'], 1);
    final issues = EvalUseCaseRuntimeResolverSnapshot.validatePacket(forged);

    expect(
      issues,
      contains('status must match resolver packet source readiness'),
    );
    expect(
      () => EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
        resolverPacket: forged,
        locators: const [],
        generatedAt: DateTime.utc(2026, 6, 12, 21),
      ),
      throwsStateError,
    );
  });

  test('packet contract rejects stale binding source digests', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
    final wrongDigest = digestFixture('wrong-resolver-proof-summary');

    ((tampered['requiredRuntimeBindings'] as List<dynamic>).first
            as Map<String, dynamic>)['modelClassCoverageProofSummaryDigest'] =
        wrongDigest;
    ((tampered['bindingTemplates'] as List<dynamic>).first
            as Map<String, dynamic>)['modelClassCoverageProofSummaryDigest'] =
        wrongDigest;

    final issues = EvalUseCaseRuntimeResolverSnapshot.validatePacket(tampered);

    expect(
      issues,
      contains(
        'requiredRuntimeBindings[0].modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      ),
    );
    expect(
      issues,
      contains(
        'bindingTemplates[0].modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      ),
    );
  });

  test(
    'rejects stale, missing, duplicate, pending, and mismatched bindings',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        generatedAt: DateTime.utc(2026, 6, 12, 20),
      );
      final completed = _completedBindings(packet);
      final first = completed.first;

      for (final scenario in <String, List<Map<String, dynamic>>>{
        'missing': const [],
        'duplicate': [first, first],
        'unapproved': [
          first,
          {...first, 'assignmentRef': digestFixture('unapproved')},
        ],
        'pending': [
          {...first, 'status': 'pending'},
        ],
        'wrong source': [
          {...first, 'sourceReleaseGateDigest': digestFixture('wrong-gate')},
        ],
        'wrong proof summary': [
          {
            ...first,
            'modelClassCoverageProofSummaryDigest': digestFixture(
              'wrong-proof-summary',
            ),
          },
        ],
        'wrong dimension': [
          {...first, 'modelClass': 'frontierReasoning'},
        ],
        'wrong production kind': [
          {...first, 'productionAgentKind': 'day_agent'},
        ],
      }.entries) {
        expect(
          () => EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            completedBindings: scenario.value,
            capturedAt: DateTime.utc(2026, 6, 12, 20, 30),
          ),
          throwsStateError,
          reason: scenario.key,
        );
      }
    },
  );

  test('packet contract rejects private ids, env keys, paths, and commands', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>
      ..['profileId'] = 'private-profile-id'
      ..['notes'] =
          'Read file:///private/tmp/packet.json with EVAL_USE_CASE_RUNTIME_RESOLVER_INPUT.';
    ((tampered['bindingTemplates'] as List<dynamic>).first
          as Map<String, dynamic>)
      ..['agentId'] = 'private-agent-id'
      ..['command'] = 'TaskAgentService.updateAgentProfile';

    final issues = EvalUseCaseRuntimeResolverSnapshot.validatePacket(tampered);

    expect(
      issues,
      contains('packet.profileId must not expose private runtime ids'),
    );
    expect(issues, contains('packet.notes must not contain private paths'));
    expect(
      issues,
      contains('packet.notes must not contain private env value keys'),
    );
    expect(
      issues,
      contains(
        'packet.bindingTemplates[0].agentId must not expose private runtime ids',
      ),
    );
    expect(
      issues,
      contains(
        'packet.bindingTemplates[0].command must not contain mutation commands',
      ),
    );
  });

  test('packet contract rejects restamped recommended command templates', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 20),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
    ((tampered['recommendedCommands'] as List<dynamic>).first
          as Map<String, dynamic>)
      ..['mode'] = 'report'
      ..['command'] = 'eval/run_level2.sh report';

    final issues = EvalUseCaseRuntimeResolverSnapshot.validatePacket(tampered);

    expect(
      issues,
      contains(
        'recommendedCommands must match static recommended command templates',
      ),
    );
  });

  test(
    'writes use-case runtime resolver packet',
    () async {
      final releasePlan =
          jsonDecode(File(_resolverReleasePlanPath).readAsStringSync())
              as Map<String, dynamic>;
      final releaseGate =
          jsonDecode(File(_resolverReleaseGatePath).readAsStringSync())
              as Map<String, dynamic>;
      final releaseReviewBundles = _readReviewBundles(
        _resolverReleaseReviewAttestations,
      );
      final sourceInputs = await _readReleasePlanSourceInputs();
      final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      EvalUseCaseRuntimeResolverSnapshot.assertValidPacket(packet);
      writeEvalJsonArtifact(
        packet,
        path: _resolverPacketPath,
        overwrite: _resolverPacketOverwrite == '1',
        description: 'use-case runtime resolver packet',
      );
    },
    skip:
        _resolverReleasePlanPath.isEmpty ||
            _resolverRoadmapInputPath.isEmpty ||
            _resolverDecisionLedgerPaths.isEmpty ||
            _resolverDecisionLedgerSourceManifestPaths.isEmpty ||
            _resolverReleaseGatePath.isEmpty ||
            _resolverReleaseReviewAttestations.isEmpty ||
            _resolverPacketPath.isEmpty
        ? 'Set EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=<json>, and '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=<json>, and '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=<json> to write a packet.'
        : false,
  );

  test(
    'writes use-case runtime resolver snapshot',
    () async {
      final releasePlan =
          jsonDecode(File(_resolverReleasePlanPath).readAsStringSync())
              as Map<String, dynamic>;
      final releaseGate =
          jsonDecode(File(_resolverReleaseGatePath).readAsStringSync())
              as Map<String, dynamic>;
      final reviewBundles = _readReviewBundles(
        _resolverReleaseReviewAttestations,
      );
      final sourceInputs = await _readReleasePlanSourceInputs();
      final resolverPacket =
          jsonDecode(File(_resolverPacketPath).readAsStringSync())
              as Map<String, dynamic>;
      EvalUseCaseRuntimeResolverSnapshot.assertPacketMatchesSources(
        resolverPacket,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        releaseReviewBundles: reviewBundles,
        sourceRoadmap: sourceInputs.roadmap,
        sourceDecisionLedgers: sourceInputs.decisionLedgers,
        previousReleasePlan: sourceInputs.previousReleasePlan,
        sourceRuntimeRolloutLedgers: sourceInputs.runtimeRolloutLedgers,
      );
      final bindings = _readBindingInput(_resolverInputPath);
      final snapshot = EvalUseCaseRuntimeResolverSnapshot.buildSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        completedBindings: bindings,
        runtimeObservationSource:
            EvalUseCaseRuntimeResolverSnapshot.runtimeObservationSourceFromResolverPacket(
              resolverPacket: resolverPacket,
              mode: EvalUseCaseRuntimeResolverSnapshot
                  .runtimeObservationModeManualCompletedBindingImport,
            ),
      );
      writeEvalJsonArtifact(
        snapshot,
        path: _resolverSnapshotPath,
        overwrite: _resolverSnapshotOverwrite == '1',
        description: 'use-case runtime resolver snapshot',
      );
    },
    skip:
        _resolverReleasePlanPath.isEmpty ||
            _resolverRoadmapInputPath.isEmpty ||
            _resolverDecisionLedgerPaths.isEmpty ||
            _resolverDecisionLedgerSourceManifestPaths.isEmpty ||
            _resolverReleaseGatePath.isEmpty ||
            _resolverReleaseReviewAttestations.isEmpty ||
            _resolverPacketPath.isEmpty ||
            _resolverInputPath.isEmpty ||
            _resolverSnapshotPath.isEmpty
        ? 'Set EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_INPUT=<json>, and '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT=<json> to write a snapshot.'
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

List<Map<String, dynamic>> _readReviewBundles(String paths) {
  return [
    for (final path in paths.split(','))
      if (path.trim().isNotEmpty) ..._readReviewBundleFile(path.trim()),
  ];
}

Future<ReleasePlanSourceInputsFixture>
_readReleasePlanSourceInputs() => readReleasePlanSourceInputsFixture(
  roadmapInputPath: _resolverRoadmapInputPath,
  decisionLedgerPaths: _resolverDecisionLedgerPaths,
  decisionLedgerSourceManifestPaths: _resolverDecisionLedgerSourceManifestPaths,
  previousReleasePlanPath: _resolverPreviousReleasePlanPath,
  runtimeRolloutLedgerPaths: _resolverRuntimeRolloutLedgerPaths,
  runtimePreviousRolloutLedgerPaths: _resolverRuntimePreviousRolloutLedgerPaths,
  runtimeLedgerReleaseGatePaths: _resolverRuntimeLedgerReleaseGatePaths,
  runtimeLedgerReleaseReviewAttestations:
      _resolverRuntimeLedgerReleaseReviewAttestations,
  runtimeVerificationPaths: _resolverRuntimeVerificationPaths,
  runtimeLedgerResolverSnapshotPaths:
      _resolverRuntimeLedgerResolverSnapshotPaths,
  runtimeLedgerResolverPacketPaths: _resolverRuntimeLedgerResolverPacketPaths,
  runtimeLedgerLocatorPacketPaths: _resolverRuntimeLedgerLocatorPacketPaths,
  runtimeLedgerResolverInputPaths: _resolverRuntimeLedgerResolverInputPaths,
  runtimeLedgerDirectObservationPaths:
      _resolverRuntimeLedgerDirectObservationPaths,
  runtimeLedgerStateInputPaths: _resolverRuntimeLedgerStateInputPaths,
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

List<Map<String, dynamic>> _completedBindings(Map<String, dynamic> packet) {
  return [
    for (final template
        in (packet['bindingTemplates'] as List<dynamic>)
            .cast<Map<String, dynamic>>())
      _completeBinding(template),
  ];
}

Map<String, dynamic> _completeBinding(Map<String, dynamic> template) {
  final assignmentRef = template['assignmentRef'] as String;
  final digests = <String, dynamic>{
    'resolvedProfileDigest': digestFixture('profile-$assignmentRef'),
    'providerModelBindingDigest': digestFixture(
      'provider-model-${template['modelClass']}',
    ),
    'thinkingModelBindingDigest': digestFixture(
      'thinking-model-${template['modelClass']}',
    ),
    'promptVariantDigest': digestFixture(
      'prompt-variant-${template['promptVariantName']}',
    ),
    'promptDirectiveDigest': digestFixture(
      'prompt-directive-${template['promptVariantName']}',
    ),
  };
  return <String, dynamic>{
    ...template,
    'status': 'resolved',
    'resolutionStatus': 'applied',
    'runtimeTargetRef': digestFixture('runtime-target-$assignmentRef'),
    'expected': digests,
    'observed': digests,
    'privateRuntimeIds': <String, dynamic>{
      'agentId': 'agent-private-$assignmentRef',
      'templateId': 'template-private-$assignmentRef',
      'profileId': 'profile-private-$assignmentRef',
    },
  };
}

List<Map<String, dynamic>> _readBindingInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is List) {
    return [for (final item in decoded) item as Map<String, dynamic>];
  }
  if (decoded is Map<String, dynamic>) {
    if (decoded['kind'] == EvalUseCaseRuntimeResolverSnapshot.packetKind) {
      return (decoded['bindingTemplates'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    if (decoded['kind'] ==
        EvalUseCaseRuntimeVerification.resolverSnapshotKind) {
      return (decoded['runtimeBindings'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }
    return [decoded];
  }
  throw StateError('Expected resolver binding input JSON object or list.');
}
