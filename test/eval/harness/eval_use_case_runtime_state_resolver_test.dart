import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

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
const _resolverReleaseGatePath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE',
);
const _resolverReleaseReviewAttestations = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS',
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
const _resolverPacketPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET',
);
const _locatorInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LOCATOR_INPUT',
);
const _locatorPacketPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET',
);
const _locatorPacketOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET_OVERWRITE',
);
const _runtimeStateInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_STATE_INPUT',
);
const _resolverSnapshotPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT',
);
const _resolverSnapshotOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT_OVERWRITE',
);

void main() {
  test(
    'observes task runtime rows through a private locator and verifies snapshot',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final assignmentRef = _assignmentRef(releasePlan);
      final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
      final observations = EvalUseCaseRuntimeStateResolver.resolveObservations(
        locators: [
          EvalRuntimeBindingLocator(
            assignmentRef: assignmentRef,
            taskId: fixture.taskId,
          ),
        ],
        agents: [fixture.agent],
        templates: [fixture.template],
        activeVersions: [fixture.version],
        links: fixture.links,
        aiConfigs: fixture.aiConfigs,
      );

      final snapshot = EvalUseCaseRuntimeStateResolver.buildResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        observations: observations,
        capturedAt: DateTime.utc(2026, 6, 12, 22),
      );
      final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        generatedAt: DateTime.utc(2026, 6, 12, 22),
      );
      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: snapshot,
        runtimeResolverPacket: resolverPacket,
        generatedAt: DateTime.utc(2026, 6, 12, 22, 30),
      );

      expect(verification['status'], 'verified');
      expect(
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          snapshot,
        ),
        isEmpty,
      );
      final encoded = const JsonEncoder().convert(snapshot);
      expect(encoded, contains(fixture.agent.agentId));
      expect(encoded, isNot(contains(fixture.provider.apiKey)));
      expect(encoded, isNot(contains(fixture.provider.baseUrl)));
      expect(encoded, isNot(contains(fixture.version.generalDirective)));
      expect(encoded, isNot(contains(fixture.version.reportDirective)));
    },
  );

  test('builds a private locator packet and resolves observations from it', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);

    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final observations =
        EvalUseCaseRuntimeStateResolver.resolveObservationsFromLocatorPacket(
          resolverPacket: resolverPacket,
          locatorPacket: locatorPacket,
          agents: [fixture.agent],
          templates: [fixture.template],
          activeVersions: [fixture.version],
          links: fixture.links,
          aiConfigs: fixture.aiConfigs,
        );

    expect(
      EvalUseCaseRuntimeStateResolver.validateLocatorPacket(locatorPacket),
      isEmpty,
    );
    expect(observations, hasLength(1));
    expect(observations.single.agent.agentId, fixture.agent.agentId);
    final encoded = const JsonEncoder().convert(locatorPacket);
    expect(encoded, contains(fixture.taskId));
    expect(encoded, isNot(contains(fixture.provider.apiKey)));
    expect(encoded, isNot(contains(fixture.provider.baseUrl)));
  });

  test(
    'observes private runtime state export and writes a canonical snapshot',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        generatedAt: DateTime.utc(2026, 6, 12, 21),
      );
      final assignmentRef = _assignmentRef(releasePlan);
      final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
      final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
        resolverPacket: resolverPacket,
        locators: [
          EvalRuntimeBindingLocator(
            assignmentRef: assignmentRef,
            taskId: fixture.taskId,
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
      );

      final snapshot =
          EvalUseCaseRuntimeStateResolver.buildResolverSnapshotFromPrivateRuntimeState(
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            resolverPacket: resolverPacket,
            locatorPacket: locatorPacket,
            privateRuntimeState: _privateRuntimeState(fixture),
            capturedAt: DateTime.utc(2026, 6, 12, 22),
          );
      final verification = EvalUseCaseRuntimeVerification.build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: snapshot,
        runtimeResolverPacket: resolverPacket,
        runtimeLocatorPacket: locatorPacket,
        generatedAt: DateTime.utc(2026, 6, 12, 22, 30),
      );

      expect(verification['status'], 'verified');
      expect(
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          snapshot,
        ),
        isEmpty,
      );
      final observationSource =
          snapshot['runtimeObservationSource'] as Map<String, dynamic>;
      expect(
        observationSource['mode'],
        EvalUseCaseRuntimeResolverSnapshot
            .runtimeObservationModePrivateRuntimeStateLocator,
      );
      expect(
        observationSource['sourceResolverPacketDigest'],
        EvalProvenance.digestJson(resolverPacket),
      );
      expect(
        observationSource['sourceLocatorPacketDigest'],
        EvalProvenance.digestJson(locatorPacket),
      );
      final tamperedSnapshot =
          jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      (tamperedSnapshot['runtimeObservationSource']
          as Map<String, dynamic>)['sourceLocatorPacketDigest'] = digestFixture(
        'different-locator-packet',
      );
      expect(
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          tamperedSnapshot,
        ),
        contains(
          'runtimeResolverSnapshotRef must match runtime resolver snapshot subject digest',
        ),
      );
      final binding = _singleBinding(snapshot);
      expect(binding['resolutionStatus'], 'applied');
      expect(
        (binding['privateRuntimeIds'] as Map<String, dynamic>)['agentId'],
        fixture.agent.agentId,
      );
      final encoded = const JsonEncoder().convert(snapshot);
      expect(encoded, isNot(contains(fixture.provider.apiKey)));
      expect(encoded, isNot(contains(fixture.provider.baseUrl)));
      expect(encoded, isNot(contains(fixture.version.directives)));
      expect(encoded, isNot(contains(fixture.version.generalDirective)));
      expect(encoded, isNot(contains(fixture.version.reportDirective)));
    },
  );

  test('private runtime state export rejects proof fields', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final privateState = _privateRuntimeState(fixture);
    (privateState['agentEntities'] as List<dynamic>).first
          as Map<String, dynamic>
      ..['expectedDigests'] = {
        'resolvedProfileDigest': digestFixture('self-certified'),
      }
      ..['resolutionStatus'] = 'applied';

    expect(
      () =>
          EvalUseCaseRuntimeStateResolver.buildResolverSnapshotFromPrivateRuntimeState(
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            resolverPacket: resolverPacket,
            locatorPacket: locatorPacket,
            privateRuntimeState: privateState,
            capturedAt: DateTime.utc(2026, 6, 12, 22),
          ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'privateRuntimeState.agentEntities[0].expectedDigests '
            'must not be supplied by runtime state export',
          ),
        ),
      ),
    );
  });

  test('private runtime state export refuses source drift', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final changedPlan = buildReleasePlanFixture(
      promptVariantName: 'metadata-first-v3',
    );
    final changedGate = _releaseGate(changedPlan);

    expect(
      () =>
          EvalUseCaseRuntimeStateResolver.buildResolverSnapshotFromPrivateRuntimeState(
            releasePlan: changedPlan,
            releaseGate: changedGate,
            resolverPacket: resolverPacket,
            locatorPacket: locatorPacket,
            privateRuntimeState: _privateRuntimeState(fixture),
            capturedAt: DateTime.utc(2026, 6, 12, 22),
          ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains(
            'Runtime resolver packet source release plan/gate digest drift',
          ),
        ),
      ),
    );
  });

  test('private runtime state export fails closed for missing row targets', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final privateState = _privateRuntimeState(fixture)
      ..['agentEntities'] = [
        fixture.template.toJson(),
        fixture.version.toJson(),
      ];

    expect(
      () =>
          EvalUseCaseRuntimeStateResolver.resolveObservationsFromPrivateRuntimeState(
            resolverPacket: resolverPacket,
            locatorPacket: locatorPacket,
            privateRuntimeState: privateState,
          ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('did not contain runtime rows for assignment refs'),
        ),
      ),
    );
  });

  test(
    'private runtime state export rejects duplicate private row identities',
    () {
      final releasePlan = buildReleasePlanFixture();
      final releaseGate = _releaseGate(releasePlan);
      final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        generatedAt: DateTime.utc(2026, 6, 12, 21),
      );
      final assignmentRef = _assignmentRef(releasePlan);
      final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
      final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
        resolverPacket: resolverPacket,
        locators: [
          EvalRuntimeBindingLocator(
            assignmentRef: assignmentRef,
            taskId: fixture.taskId,
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
      );
      final privateState = _privateRuntimeState(fixture);
      (privateState['agentEntities'] as List<dynamic>).add(
        _jsonMap(fixture.agent.toJson()),
      );

      expect(
        () =>
            EvalUseCaseRuntimeStateResolver.resolveObservationsFromPrivateRuntimeState(
              resolverPacket: resolverPacket,
              locatorPacket: locatorPacket,
              privateRuntimeState: privateState,
            ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains(
              'privateRuntimeState.agentEntities.agent.agentId must not contain '
              'duplicate private row identities',
            ),
          ),
        ),
      );
    },
  );

  test('locator packet rejects artifact-only resolver packet replay', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final replayedResolverPacket =
        jsonDecode(jsonEncode(resolverPacket)) as Map<String, dynamic>;
    final locator = EvalRuntimeBindingLocator(
      assignmentRef: _assignmentRef(releasePlan),
      taskId: 'task-private-1',
    );

    expect(
      () => EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
        resolverPacket: replayedResolverPacket,
        locators: [locator],
        generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('Runtime locator packet requires verified packet sources'),
        ),
      ),
    );
  });

  test('source-aware runtime state rejects restamped resolver packets', () {
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
    final localPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: forged,
      releaseGate: forgedGate,
      releaseReviewBundles: [forgedBundle],
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    expect(localPacket['status'], 'readyForRuntimeResolution');

    final assignmentRef = _assignmentRef(forged);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: localPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final snapshot =
        EvalUseCaseRuntimeStateResolver.buildResolverSnapshotFromPrivateRuntimeState(
          releasePlan: forged,
          releaseGate: forgedGate,
          resolverPacket: localPacket,
          locatorPacket: locatorPacket,
          privateRuntimeState: _privateRuntimeState(fixture),
          capturedAt: DateTime.utc(2026, 6, 12, 22),
        );
    expect(_singleBinding(snapshot)['resolutionStatus'], 'applied');

    expect(
      () => EvalUseCaseRuntimeResolverSnapshot.assertPacketMatchesSources(
        localPacket,
        releasePlan: forged,
        releaseGate: forgedGate,
        releaseReviewBundles: [forgedBundle],
        sourceRoadmap: roadmap,
        sourceDecisionLedgers: [ledger],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('runtime resolver packet must match source artifacts'),
        ),
      ),
    );
  });

  test('locator packet rejects coverage gaps, extras, and private payloads', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final locator = EvalRuntimeBindingLocator(
      assignmentRef: assignmentRef,
      taskId: 'task-private-1',
    );

    for (final locators in <List<EvalRuntimeBindingLocator>>[
      const [],
      [locator, locator],
      [
        EvalRuntimeBindingLocator(
          assignmentRef: digestFixture('unapproved-assignment'),
          taskId: 'task-private-1',
        ),
      ],
    ]) {
      expect(
        () => EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
          resolverPacket: resolverPacket,
          locators: locators,
          generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
        ),
        throwsStateError,
      );
    }

    final packet = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [locator],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final tampered = jsonDecode(jsonEncode(packet)) as Map<String, dynamic>;
    ((tampered['locators'] as List<dynamic>).single as Map<String, dynamic>)
      ..['apiKey'] = 'secret-api-key'
      ..['expectedDigests'] = {'resolvedProfileDigest': digestFixture('fake')}
      ..['notes'] = 'read /private/tmp/runtime.json'
      ..['command'] = 'TaskAgentService.updateAgentProfile';

    final issues = EvalUseCaseRuntimeStateResolver.validateLocatorPacket(
      tampered,
    );

    expect(
      issues,
      contains(
        'locatorPacket.locators[0].apiKey must not expose API keys or secrets',
      ),
    );
    expect(
      issues,
      contains(
        'locators[0].expectedDigests must not be supplied by locator packets',
      ),
    );
    expect(
      issues,
      contains(
        'locatorPacket.locators[0].notes must not contain private paths',
      ),
    );
    expect(
      issues,
      contains(
        'locatorPacket.locators[0].command must not contain mutation commands',
      ),
    );
  });

  test('locator packet source matcher rejects restamped required refs', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final unapprovedRef = digestFixture('unapproved-locator-required-ref');
    final stale = jsonDecode(jsonEncode(locatorPacket)) as Map<String, dynamic>
      ..['requiredAssignmentRefs'] = [unapprovedRef];
    ((stale['locators'] as List<dynamic>).single
            as Map<String, dynamic>)['assignmentRef'] =
        unapprovedRef;

    expect(
      EvalUseCaseRuntimeStateResolver.validateLocatorPacket(stale),
      contains(
        'sourceResolverPacket.requiredAssignmentRefsDigest must match requiredAssignmentRefs',
      ),
    );

    final restamped = jsonDecode(jsonEncode(stale)) as Map<String, dynamic>;
    (restamped['sourceResolverPacket']
            as Map<String, dynamic>)['requiredAssignmentRefsDigest'] =
        EvalProvenance.digestJson([unapprovedRef]);
    restamped['locatorPacketRef'] =
        EvalUseCaseRuntimeStateResolver.locatorPacketRef(restamped);

    expect(
      EvalUseCaseRuntimeStateResolver.validateLocatorPacket(restamped),
      isEmpty,
    );

    final countTampered =
        jsonDecode(jsonEncode(locatorPacket)) as Map<String, dynamic>
          ..['requiredAssignmentRefs'] = const <String>[]
          ..['locators'] = const <Map<String, dynamic>>[];
    (countTampered['summary'] as Map<String, dynamic>)['locatorCount'] = 0;
    (countTampered['sourceResolverPacket']
            as Map<String, dynamic>)['requiredAssignmentRefsDigest'] =
        EvalProvenance.digestJson(const <String>[]);

    expect(
      EvalUseCaseRuntimeStateResolver.validateLocatorPacket(countTampered),
      contains(
        'sourceResolverPacket.requiredRuntimeBindingCount must match requiredAssignmentRefs.length',
      ),
    );
    expect(
      () =>
          EvalUseCaseRuntimeStateResolver.assertLocatorPacketMatchesResolverPacket(
            locatorPacket: restamped,
            resolverPacket: resolverPacket,
          ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('Runtime locator packet source resolver digest drift'),
        ),
      ),
    );
  });

  test('locator input rows reject proof fields and private payloads', () {
    final assignmentRef = digestFixture('assignment');
    final rows = [
      {
        'assignmentRef': assignmentRef,
        'taskId': 'task-private-1',
        'expected': {
          'resolvedProfileDigest': digestFixture('self-certified'),
        },
        'notes': 'read /private/tmp/runtime.json',
      },
    ];

    expect(
      () => EvalUseCaseRuntimeStateResolver.locatorsFromInputRows(rows),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains(
              'locators[0].expected must not be supplied by locator packets',
            ),
            contains('locators[0].notes must not contain private paths'),
          ),
        ),
      ),
    );
  });

  test('locator packet rejects selectors that contradict runtime links', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final other = _RuntimeFixture.create(
      assignmentRef: assignmentRef,
      agentId: 'agent-private-other',
      taskId: 'task-private-other',
      templateId: 'template-private-other',
    );

    for (final locator in [
      EvalRuntimeBindingLocator(
        assignmentRef: assignmentRef,
        agentId: fixture.agent.agentId,
        taskId: other.taskId,
      ),
      EvalRuntimeBindingLocator(
        assignmentRef: assignmentRef,
        agentId: fixture.agent.agentId,
        templateId: other.template.id,
      ),
      EvalRuntimeBindingLocator(
        assignmentRef: assignmentRef,
        agentId: fixture.agent.agentId,
        templateId: fixture.template.id,
        activeTemplateVersionId: 'template-version-private-inactive',
      ),
    ]) {
      final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
        resolverPacket: resolverPacket,
        locators: [locator],
        generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
      );
      expect(
        () =>
            EvalUseCaseRuntimeStateResolver.resolveObservationsFromLocatorPacket(
              resolverPacket: resolverPacket,
              locatorPacket: locatorPacket,
              agents: [fixture.agent, other.agent],
              templates: [fixture.template, other.template],
              activeVersions: [
                fixture.version,
                other.version,
                fixture.version.copyWith(
                  id: 'template-version-private-inactive',
                  status: AgentTemplateVersionStatus.archived,
                ),
              ],
              links: [...fixture.links, ...other.links],
              aiConfigs: fixture.aiConfigs,
            ),
        throwsStateError,
      );
    }
  });

  test('locator packet refuses a stale resolver packet source', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final changedPlan = buildReleasePlanFixture(
      promptVariantName: 'metadata-first-v3',
    );
    final changedGate = _releaseGate(changedPlan);
    final changedResolverPacket =
        EvalUseCaseRuntimeResolverSnapshot.buildPacket(
          releasePlan: changedPlan,
          releaseGate: changedGate,
          generatedAt: DateTime.utc(2026, 6, 12, 21),
        );

    expect(
      () =>
          EvalUseCaseRuntimeStateResolver.resolveObservationsFromLocatorPacket(
            resolverPacket: changedResolverPacket,
            locatorPacket: locatorPacket,
            agents: [fixture.agent],
            templates: [fixture.template],
            activeVersions: [fixture.version],
            links: fixture.links,
            aiConfigs: fixture.aiConfigs,
          ),
      throwsStateError,
    );
  });

  test('locator input rejects stale full locator packet objects', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
      resolverPacket: resolverPacket,
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: fixture.taskId,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
    );
    final freshResolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 22),
    );
    final tempDir = Directory.systemTemp.createTempSync(
      'lotti-runtime-locator-input-',
    );

    try {
      final input = File('${tempDir.path}/locator_packet.json')
        ..writeAsStringSync(jsonEncode(locatorPacket));

      expect(
        () => _readLocatorInput(
          input.path,
          resolverPacket: freshResolverPacket,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Runtime locator packet source resolver digest drift'),
          ),
        ),
      );
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'observes planning-agent runtime rows through direct day-agent locator',
    () {
      final releasePlan = _planningReleasePlan();
      final releaseGate = _releaseGate(releasePlan);
      final assignmentRef = _assignmentRef(releasePlan);
      final fixture = _RuntimeFixture.create(
        assignmentRef: assignmentRef,
        agentId: 'agent-private-day',
        templateId: 'template-private-day',
        agentKind: AgentKinds.dayAgent,
        templateKind: AgentTemplateKind.dayAgent,
      );
      final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        generatedAt: DateTime.utc(2026, 6, 12, 21),
      );
      final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
        resolverPacket: resolverPacket,
        locators: [
          EvalRuntimeBindingLocator(
            assignmentRef: assignmentRef,
            agentId: fixture.agent.agentId,
          ),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 21, 30),
      );
      final observations =
          EvalUseCaseRuntimeStateResolver.resolveObservationsFromLocatorPacket(
            resolverPacket: resolverPacket,
            locatorPacket: locatorPacket,
            agents: [fixture.agent],
            templates: [fixture.template],
            activeVersions: [fixture.version],
            links: fixture.links,
            aiConfigs: fixture.aiConfigs,
          );

      final snapshot = EvalUseCaseRuntimeStateResolver.buildResolverSnapshot(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        observations: observations,
        capturedAt: DateTime.utc(2026, 6, 12, 22),
      );

      final binding = _singleBinding(snapshot);
      expect(binding['agentKind'], 'planningAgent');
      expect(binding['productionAgentKind'], AgentKinds.dayAgent);
      expect(binding['resolutionStatus'], 'applied');
    },
  );

  test('uses agent profile before version and template profile defaults', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(
      assignmentRef: assignmentRef,
      versionProfileId: 'profile-private-version',
      templateProfileId: 'profile-private-template',
    );

    final snapshot = EvalUseCaseRuntimeStateResolver.buildResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      observations: [fixture.observation],
      capturedAt: DateTime.utc(2026, 6, 12, 22),
    );

    final binding = _singleBinding(snapshot);
    final privateIds = binding['privateRuntimeIds'] as Map<String, dynamic>;
    expect(privateIds['profileId'], 'profile-private-agent');
    expect(binding['shadowedTemplateOverride'], isTrue);
    expect(binding['resolutionStatus'], 'applied');
  });

  test('falls back to legacy model when configured profile is missing', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(
      assignmentRef: assignmentRef,
      agentProfileId: 'profile-private-missing',
      profileIdsToCreate: const {},
    );

    final snapshot = EvalUseCaseRuntimeStateResolver.buildResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      observations: [fixture.observation],
      capturedAt: DateTime.utc(2026, 6, 12, 22),
    );

    final binding = _singleBinding(snapshot);
    final privateIds = binding['privateRuntimeIds'] as Map<String, dynamic>;
    expect(binding['resolutionStatus'], 'applied');
    expect(privateIds['unresolvedProfileId'], 'profile-private-missing');
    expect(privateIds['thinkingModelConfigId'], fixture.model.id);
  });

  test('task locators use primary agent and template links', () {
    final releasePlan = buildReleasePlanFixture();
    final assignmentRef = _assignmentRef(releasePlan);
    final older = _RuntimeFixture.create(
      assignmentRef: assignmentRef,
      agentId: 'agent-private-old',
      templateId: 'template-private-old',
      taskLinkId: 'task-link-private-old',
      taskLinkCreatedAt: DateTime.utc(2026, 6, 12, 18),
    );
    final newer = _RuntimeFixture.create(
      assignmentRef: assignmentRef,
      agentId: 'agent-private-new',
      templateId: 'template-private-new',
      taskId: older.taskId,
      taskLinkId: 'task-link-private-new',
      taskLinkCreatedAt: DateTime.utc(2026, 6, 12, 19),
    );

    final observations = EvalUseCaseRuntimeStateResolver.resolveObservations(
      locators: [
        EvalRuntimeBindingLocator(
          assignmentRef: assignmentRef,
          taskId: older.taskId,
        ),
      ],
      agents: [older.agent, newer.agent],
      templates: [older.template, newer.template],
      activeVersions: [older.version, newer.version],
      links: [...older.links, ...newer.links],
      aiConfigs: newer.aiConfigs,
    );

    expect(observations, hasLength(1));
    expect(observations.single.agent.agentId, newer.agent.agentId);
    expect(observations.single.template.id, newer.template.id);
  });

  test('active directive changes produce verification drift', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final assignmentRef = _assignmentRef(releasePlan);
    final baseline = _RuntimeFixture.create(assignmentRef: assignmentRef);
    final packet = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 21),
    );
    final baselineBinding =
        EvalUseCaseRuntimeStateResolver.buildCompletedBindings(
          resolverPacket: packet,
          observations: [baseline.observation],
        ).single;
    final changed = baseline.copyWith(
      version: baseline.version.copyWith(
        id: 'template-version-private-2',
        version: 2,
        generalDirective: 'Private changed general directive',
      ),
    );
    final driftObservation = EvalRuntimeStateObservation(
      assignmentRef: assignmentRef,
      agent: changed.agent,
      template: changed.template,
      activeVersion: changed.version,
      aiConfigs: changed.aiConfigs,
      expectedDigests: baselineBinding['observed'] as Map<String, dynamic>,
    );

    final snapshot = EvalUseCaseRuntimeStateResolver.buildResolverSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      observations: [driftObservation],
      capturedAt: DateTime.utc(2026, 6, 12, 22),
    );
    final resolverPacket = EvalUseCaseRuntimeResolverSnapshot.buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: DateTime.utc(2026, 6, 12, 22),
    );
    final verification = EvalUseCaseRuntimeVerification.build(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: snapshot,
      runtimeResolverPacket: resolverPacket,
      generatedAt: DateTime.utc(2026, 6, 12, 22, 30),
    );

    expect(verification['status'], 'drift');
    final issues = (verification['issues'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      issues,
      contains(
        allOf(
          containsPair('code', 'runtime.effectiveBindingDrift'),
          containsPair('field', 'promptDirectiveDigest'),
        ),
      ),
    );
  });

  test('resolver report omits private locators, directives, and secrets', () {
    final releasePlan = buildReleasePlanFixture();
    final releaseGate = _releaseGate(releasePlan);
    final assignmentRef = _assignmentRef(releasePlan);
    final fixture = _RuntimeFixture.create(assignmentRef: assignmentRef);

    final report = EvalUseCaseRuntimeStateResolver.buildResolverReport(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      observations: [fixture.observation],
      generatedAt: DateTime.utc(2026, 6, 12, 22),
    );

    final encoded = const JsonEncoder().convert(report);
    expect(encoded, contains(assignmentRef));
    expect(encoded, isNot(contains(fixture.agent.agentId)));
    expect(encoded, isNot(contains(fixture.template.id)));
    expect(encoded, isNot(contains(fixture.provider.apiKey)));
    expect(encoded, isNot(contains(fixture.provider.baseUrl)));
    expect(encoded, isNot(contains(fixture.version.generalDirective)));
  });

  test(
    'writes use-case runtime locator packet',
    () async {
      final releasePlan = _readJson(_resolverReleasePlanPath);
      final releaseGate = _readJson(_resolverReleaseGatePath);
      final resolverPacket = _readJson(_resolverPacketPath);
      final releaseReviewBundles = readReleaseReviewBundlesFixture(
        _resolverReleaseReviewAttestations,
      );
      final sourceInputs = await _readReleasePlanSourceInputs();
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
      final locators = _readLocatorInput(
        _locatorInputPath,
        resolverPacket: resolverPacket,
      );
      final locatorPacket = EvalUseCaseRuntimeStateResolver.buildLocatorPacket(
        resolverPacket: resolverPacket,
        locators: locators,
      );
      writeEvalJsonArtifact(
        locatorPacket,
        path: _locatorPacketPath,
        overwrite: _locatorPacketOverwrite == '1',
        description: 'use-case runtime locator packet',
      );
    },
    skip:
        _resolverReleasePlanPath.isEmpty ||
            _resolverReleaseGatePath.isEmpty ||
            _resolverReleaseReviewAttestations.isEmpty ||
            _resolverRoadmapInputPath.isEmpty ||
            _resolverDecisionLedgerPaths.isEmpty ||
            _resolverDecisionLedgerSourceManifestPaths.isEmpty ||
            _resolverPacketPath.isEmpty ||
            _locatorInputPath.isEmpty ||
            _locatorPacketPath.isEmpty
        ? 'Set EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=<json>, '
              'EVAL_USE_CASE_RUNTIME_LOCATOR_INPUT=<json>, and '
              'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET=<json> to write a locator packet.'
        : false,
  );

  test(
    'writes use-case runtime resolver snapshot from private runtime state',
    () async {
      final releasePlan = _readJson(_resolverReleasePlanPath);
      final releaseGate = _readJson(_resolverReleaseGatePath);
      final resolverPacket = _readJson(_resolverPacketPath);
      final releaseReviewBundles = readReleaseReviewBundlesFixture(
        _resolverReleaseReviewAttestations,
      );
      final sourceInputs = await _readReleasePlanSourceInputs();
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
      final locatorPacket = _readJson(_locatorPacketPath);
      final privateRuntimeState = _readJson(_runtimeStateInputPath);
      final snapshot =
          EvalUseCaseRuntimeStateResolver.buildResolverSnapshotFromPrivateRuntimeState(
            releasePlan: releasePlan,
            releaseGate: releaseGate,
            resolverPacket: resolverPacket,
            locatorPacket: locatorPacket,
            privateRuntimeState: privateRuntimeState,
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
            _resolverReleaseGatePath.isEmpty ||
            _resolverReleaseReviewAttestations.isEmpty ||
            _resolverRoadmapInputPath.isEmpty ||
            _resolverDecisionLedgerPaths.isEmpty ||
            _resolverDecisionLedgerSourceManifestPaths.isEmpty ||
            _resolverPacketPath.isEmpty ||
            _locatorPacketPath.isEmpty ||
            _runtimeStateInputPath.isEmpty ||
            _resolverSnapshotPath.isEmpty
        ? 'Set EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=<json>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json>, '
              'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=<json>, '
              'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET=<json>, '
              'EVAL_USE_CASE_RUNTIME_STATE_INPUT=<json>, and '
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

String _assignmentRef(Map<String, dynamic> releasePlan) {
  final assignments = (releasePlan['runtimeAssignments'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  return assignments.single['assignmentRef'] as String;
}

Map<String, dynamic> _planningReleasePlan() {
  return buildReleasePlanFixture(
    compatibilitySeed: 'planning-compat',
    primaryCapabilityId: 'planning.workflow',
    agentKind: 'planningAgent',
    promptVariantName: 'planner-metadata-first-v2',
    cellSeed: 'planning-frontier-fast',
    reportSeed: 'planning-report',
  );
}

Map<String, dynamic> _singleBinding(Map<String, dynamic> snapshot) {
  return (snapshot['runtimeBindings'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .single;
}

Map<String, dynamic> _privateRuntimeState(_RuntimeFixture fixture) {
  return <String, dynamic>{
    'schemaVersion':
        EvalUseCaseRuntimeStateResolver.privateRuntimeStateSchemaVersion,
    'kind': EvalUseCaseRuntimeStateResolver.privateRuntimeStateKind,
    'capturedAt': DateTime.utc(2026, 6, 12, 21, 45).toIso8601String(),
    'agentEntities': [
      _jsonMap(fixture.agent.toJson()),
      _jsonMap(fixture.template.toJson()),
      _jsonMap(fixture.version.toJson()),
    ],
    'links': [
      for (final link in fixture.links) _jsonMap(link.toJson()),
    ],
    'aiConfigs': [
      for (final config in fixture.aiConfigs) _jsonMap(config.toJson()),
    ],
  };
}

Map<String, dynamic> _jsonMap(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<EvalRuntimeBindingLocator> _readLocatorInput(
  String path, {
  required Map<String, dynamic> resolverPacket,
}) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  final rows = switch (decoded) {
    List<dynamic>() => decoded,
    Map<String, dynamic>()
        when decoded['kind'] ==
            EvalUseCaseRuntimeStateResolver.locatorPacketKind =>
      () {
        EvalUseCaseRuntimeStateResolver.assertLocatorPacketMatchesResolverPacket(
          locatorPacket: decoded,
          resolverPacket: resolverPacket,
        );
        return decoded['locators'] as List<dynamic>;
      }(),
    Map<String, dynamic>() when decoded['locators'] is List<dynamic> =>
      decoded['locators'] as List<dynamic>,
    _ => throw StateError(
      'Runtime locator input must be a JSON list or object with locators.',
    ),
  };
  return EvalUseCaseRuntimeStateResolver.locatorsFromInputRows(rows);
}

final class _RuntimeFixture {
  const _RuntimeFixture({
    required this.assignmentRef,
    required this.taskId,
    required this.agent,
    required this.template,
    required this.version,
    required this.provider,
    required this.model,
    required this.aiConfigs,
    required this.links,
  });

  factory _RuntimeFixture.create({
    required String assignmentRef,
    String agentId = 'agent-private-task',
    String taskId = 'task-private-1',
    String templateId = 'template-private-task',
    String taskLinkId = 'task-link-private',
    DateTime? taskLinkCreatedAt,
    String? agentProfileId = 'profile-private-agent',
    String? versionProfileId,
    String? templateProfileId,
    Set<String> profileIdsToCreate = const {'profile-private-agent'},
    String agentKind = AgentKinds.taskAgent,
    AgentTemplateKind templateKind = AgentTemplateKind.taskAgent,
  }) {
    final effectiveTaskLinkCreatedAt = taskLinkCreatedAt ?? _createdAt;
    final provider = AiConfigInferenceProvider(
      id: 'provider-private-openai',
      baseUrl: 'https://secret.invalid/v1',
      apiKey: 'secret-api-key',
      name: 'Private Provider',
      createdAt: _createdAt,
      inferenceProviderType: InferenceProviderType.openAi,
    );
    final model = AiConfigModel(
      id: 'model-config-private-fast',
      name: 'Private Fast Model',
      providerModelId: 'private-provider-model',
      inferenceProviderId: provider.id,
      createdAt: _createdAt,
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: true,
    );
    final agent = AgentIdentityEntity(
      id: 'agent-entity-$agentId',
      agentId: agentId,
      kind: agentKind,
      displayName: 'Private Agent',
      lifecycle: AgentLifecycle.active,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {'category-private'},
      currentStateId: 'state-private-$agentId',
      config: AgentConfig(
        modelId: model.providerModelId,
        profileId: agentProfileId,
      ),
      createdAt: _createdAt,
      updatedAt: _createdAt,
      vectorClock: null,
    );
    final template = AgentTemplateEntity(
      id: templateId,
      agentId: templateId,
      displayName: 'Private Template',
      kind: templateKind,
      modelId: model.providerModelId,
      categoryIds: const {'category-private'},
      profileId: templateProfileId,
      createdAt: _createdAt,
      updatedAt: _createdAt,
      vectorClock: null,
    );
    final version = AgentTemplateVersionEntity(
      id: '$templateId-version-1',
      agentId: templateId,
      version: 1,
      status: AgentTemplateVersionStatus.active,
      directives: 'Private legacy directive',
      generalDirective: 'Private general directive',
      reportDirective: 'Private report directive',
      authoredBy: 'test',
      createdAt: _createdAt,
      vectorClock: null,
      modelId: model.providerModelId,
      profileId: versionProfileId,
    );
    final links = [
      AgentLink.agentTask(
        id: taskLinkId,
        fromId: agentId,
        toId: taskId,
        createdAt: effectiveTaskLinkCreatedAt,
        updatedAt: effectiveTaskLinkCreatedAt,
        vectorClock: null,
      ),
      AgentLink.templateAssignment(
        id: '$templateId-template-link',
        fromId: templateId,
        toId: agentId,
        createdAt: _createdAt,
        updatedAt: _createdAt,
        vectorClock: null,
      ),
    ];
    final profiles = {
      if (agentProfileId != null && profileIdsToCreate.contains(agentProfileId))
        agentProfileId,
      if (versionProfileId != null &&
          profileIdsToCreate.contains(versionProfileId))
        versionProfileId,
      if (templateProfileId != null &&
          profileIdsToCreate.contains(templateProfileId))
        templateProfileId,
    };
    return _RuntimeFixture(
      assignmentRef: assignmentRef,
      taskId: taskId,
      agent: agent,
      template: template,
      version: version,
      provider: provider,
      model: model,
      aiConfigs: [
        provider,
        model,
        for (final profileId in profiles)
          AiConfig.inferenceProfile(
            id: profileId,
            name: 'Private Profile',
            createdAt: _createdAt,
            thinkingModelId: model.id,
          ),
      ],
      links: links,
    );
  }

  static final _createdAt = DateTime.utc(2026, 6, 12, 20);

  final String assignmentRef;
  final String taskId;
  final AgentIdentityEntity agent;
  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;
  final AiConfigInferenceProvider provider;
  final AiConfigModel model;
  final List<AiConfig> aiConfigs;
  final List<AgentLink> links;

  EvalRuntimeStateObservation get observation => EvalRuntimeStateObservation(
    assignmentRef: assignmentRef,
    agent: agent,
    template: template,
    activeVersion: version,
    aiConfigs: aiConfigs,
  );

  _RuntimeFixture copyWith({
    AgentIdentityEntity? agent,
    AgentTemplateEntity? template,
    AgentTemplateVersionEntity? version,
  }) {
    return _RuntimeFixture(
      assignmentRef: assignmentRef,
      taskId: taskId,
      agent: agent ?? this.agent,
      template: template ?? this.template,
      version: version ?? this.version,
      provider: provider,
      model: model,
      aiConfigs: aiConfigs,
      links: links,
    );
  }
}
