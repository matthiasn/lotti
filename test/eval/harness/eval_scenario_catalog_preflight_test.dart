import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_scenario_catalog_preflight.dart';
import 'eval_tuning_readiness.dart';

void main() {
  test('reviewed protected catalog can produce ready artifact without ids', () {
    final fixture = _readyFixture();
    final artifact = _artifact(fixture);

    expect(artifact['kind'], EvalScenarioCatalogPreflight.kind);
    expect(artifact['status'], 'catalogReady');
    expect(
      (artifact['limitations'] as Map<String, dynamic>)['tracesEvaluated'],
      isFalse,
    );
    expect(
      (artifact['limitations']
          as Map<String, dynamic>)['promotionReadinessEvaluated'],
      isFalse,
    );
    expect(
      (artifact['issues'] as List<dynamic>).map(
        (issue) => (issue as Map<String, dynamic>)['code'],
      ),
      isEmpty,
    );
    EvalScenarioCatalogPreflight.assertValid(artifact);
    final coverage = artifact['coverage'] as Map<String, dynamic>;
    expect(
      coverage['primaryCapabilitySplitCounts'],
      containsPair('development::cap.task', 1),
    );
    expect(
      coverage['primaryCapabilitySplitCounts'],
      containsPair('holdout::cap.plan', 1),
    );
    final adversarial = artifact['adversarial'] as Map<String, dynamic>;
    expect(
      adversarial['stressTagAgentKindCounts'],
      containsPair('planningAgent::scope-boundary', 1),
    );
    final holdout = artifact['holdout'] as Map<String, dynamic>;
    expect(
      holdout['protectedHoldoutPrimaryCapabilityCounts'],
      containsPair('cap.plan', 1),
    );

    final encoded = jsonEncode(artifact);
    expect(encoded, isNot(contains('private_task_holdout')));
    expect(encoded, isNot(contains('<protected-scenario>')));
    expect(encoded, isNot(contains('EVAL_SCENARIO_IDS')));
    final plan = artifact['nextExperimentPlan'] as Map<String, dynamic>;
    final commands = (plan['recommendedCommands'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(commands.first, containsPair('commandTemplate', isA<String>()));
    expect(commands.first, isNot(contains('command')));
    expect(commands.first, isNot(contains('env')));
  });

  test('public-only insufficient catalog is catalog-blocked only', () {
    final scenarios = [
      _scenario(
        id: 'public_task',
        agentKind: AgentKind.taskAgent,
        capabilityId: 'cap.task',
      ),
    ];
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: scenarios,
      profiles: _profiles,
      policy: _governancePolicy,
      scenarioCatalogEvidence: EvalScenarioCatalogEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
        publicScenarioCount: scenarios.length,
        externalScenarioCount: 0,
        protectedHoldout: false,
        protectedScenarioIds: const [],
        protectedHoldoutScenarioIds: const [],
      ),
    );
    final artifact = _artifact(_Fixture(scenarios: scenarios, report: report));
    final issueCodes = _issueCodes(artifact);
    final commandModes = _recommendedCommandModes(artifact);

    expect(artifact['status'], 'catalogBlocked');
    expect(issueCodes, contains('holdout.protectedEvidenceMissing'));
    expect(commandModes, ['catalog']);
    expect(jsonEncode(artifact), isNot(contains('promotionReady')));
    EvalScenarioCatalogPreflight.assertValid(artifact);
  });

  test(
    'protectedHoldout false blocks production replay holdout laundering',
    () {
      final holdout = _reviewedScenario(
        id: 'external_holdout',
        agentKind: AgentKind.planningAgent,
        capabilityId: 'cap.plan',
        split: EvalScenarioSplit.holdout,
        source: EvalScenarioSource.productionReplay,
        isAdversarial: true,
        tags: const {'scope-boundary'},
      );
      final scenarios = [
        _scenario(
          id: 'public_task',
          agentKind: AgentKind.taskAgent,
          capabilityId: 'cap.task',
        ),
        holdout,
      ];
      final report = EvalTuningReadiness.assessScenarioCatalog(
        scenarios: scenarios,
        profiles: _profiles,
        policy: _governancePolicy,
        scenarioCatalogEvidence: EvalScenarioCatalogEvidence(
          scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
          publicScenarioCount: 1,
          externalScenarioCount: 1,
          externalCatalogDigest: EvalProvenance.digestText('external-catalog'),
          externalCatalogId: 'catalog.private.v1',
          protectedHoldout: false,
          protectedScenarioIds: const [],
          protectedHoldoutScenarioIds: const [],
        ),
      );
      final artifact = _artifact(
        _Fixture(scenarios: scenarios, report: report),
      );

      expect(artifact['status'], 'catalogBlocked');
      expect(_issueCodes(artifact), contains('holdout.protectedFlagFalse'));
      expect(
        (artifact['holdout']
            as Map<String, dynamic>)['protectedHoldoutScenarioCount'],
        0,
      );
      EvalScenarioCatalogPreflight.assertValid(artifact);
    },
  );

  test('review blockers are grouped by code and count', () {
    final blocked = _scenario(
      id: 'private_needs_review',
      agentKind: AgentKind.planningAgent,
      capabilityId: 'cap.plan',
      split: EvalScenarioSplit.holdout,
      source: EvalScenarioSource.productionReplay,
      isAdversarial: true,
      tags: const {'scope-boundary'},
    );
    final scenarios = [
      _scenario(
        id: 'public_task',
        agentKind: AgentKind.taskAgent,
        capabilityId: 'cap.task',
      ),
      blocked,
    ];
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: scenarios,
      profiles: _profiles,
      policy: _governancePolicy,
      scenarioCatalogEvidence: _evidence(
        scenarios,
        protectedIds: const ['private_needs_review'],
      ),
    );
    final artifact = _artifact(_Fixture(scenarios: scenarios, report: report));

    expect(_issueCodes(artifact), contains('review.missing'));
    expect(
      (artifact['reviews'] as Map<String, dynamic>)['missingCount'],
      1,
    );
    expect(jsonEncode(artifact), isNot(contains('private_needs_review')));
    EvalScenarioCatalogPreflight.assertValid(artifact);
  });

  test('duplicate protected source digests are counted without values', () {
    final sourceDigest = EvalProvenance.digestText('same-private-source');
    final first = _reviewedScenario(
      id: 'private_task_one',
      agentKind: AgentKind.taskAgent,
      capabilityId: 'cap.task',
      split: EvalScenarioSplit.holdout,
      source: EvalScenarioSource.productionReplay,
      sourceDigest: sourceDigest,
    );
    final second = _reviewedScenario(
      id: 'private_plan_two',
      agentKind: AgentKind.planningAgent,
      capabilityId: 'cap.plan',
      split: EvalScenarioSplit.holdout,
      source: EvalScenarioSource.productionReplay,
      isAdversarial: true,
      tags: const {'scope-boundary'},
      sourceDigest: sourceDigest,
    );
    final scenarios = [first, second];
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: scenarios,
      profiles: _profiles,
      policy: const EvalTuningPolicy(
        name: 'duplicateSourceDigestTest',
        requiredSplits: {EvalScenarioSplit.holdout},
        requiredAgentKinds: {
          AgentKind.taskAgent,
          AgentKind.planningAgent,
        },
        minScenarioCount: 2,
        minScenariosPerAgentKind: 1,
        minCapabilityCount: 2,
        minProductionReplayHoldoutScenarios: 2,
        minProtectedHoldoutScenarios: 2,
        requireProtectedHoldout: true,
        requireReviewedScenarioEvidence: true,
      ),
      scenarioCatalogEvidence: _evidence(
        scenarios,
        protectedIds: const ['private_task_one', 'private_plan_two'],
      ),
    );
    final artifact = _artifact(_Fixture(scenarios: scenarios, report: report));

    expect(
      (artifact['holdout']
          as Map<
            String,
            dynamic
          >)['duplicateProtectedHoldoutSourceDigestCount'],
      1,
    );
    expect(
      _issueCodes(artifact),
      contains('holdout.duplicateProtectedSourceDigest'),
    );
    expect(jsonEncode(artifact), isNot(contains(sourceDigest)));
    EvalScenarioCatalogPreflight.assertValid(artifact);
  });

  test('selected subsets withhold scenario selectors from plans', () {
    final fixture = _readyFixture();
    final artifact = _artifact(fixture, selectedSubset: true);
    final plan = artifact['nextExperimentPlan'] as Map<String, dynamic>;
    final withheld = plan['withheldSelectors'] as Map<String, dynamic>;

    expect(
      (artifact['selection'] as Map<String, dynamic>)['selectedSubset'],
      isTrue,
    );
    expect(withheld['selectedSubsetScenarioCount'], fixture.scenarios.length);
    expect(jsonEncode(plan), isNot(contains('EVAL_SCENARIO_IDS')));
    expect(jsonEncode(plan), isNot(contains('private_task_holdout')));
    EvalScenarioCatalogPreflight.assertValid(artifact);
  });

  test('protected id values reused as selectors are omitted everywhere', () {
    const protectedId = 'private_task_holdout';
    final scenarios = [
      _reviewedScenario(
        id: protectedId,
        agentKind: AgentKind.taskAgent,
        capabilityId: protectedId,
        split: EvalScenarioSplit.holdout,
        source: EvalScenarioSource.productionReplay,
        isAdversarial: true,
        tags: const {protectedId, 'scope-boundary'},
      ),
    ];
    const policy = EvalTuningPolicy(
      name: 'protectedValueReuse',
      requiredPrimaryCapabilityIds: {protectedId},
      requiredSplits: {EvalScenarioSplit.holdout},
      requiredAgentKinds: {AgentKind.taskAgent},
      minAdversarialScenarioCount: 1,
      requiredAdversarialTags: {protectedId, 'scope-boundary'},
      minProductionReplayHoldoutScenarios: 1,
      minProtectedHoldoutScenarios: 1,
      requireProtectedHoldout: true,
      requireReviewedScenarioEvidence: true,
    );
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: scenarios,
      profiles: _profiles,
      policy: policy,
      scenarioCatalogEvidence: _evidence(
        scenarios,
        protectedIds: const [protectedId],
      ),
    );
    final artifact = _artifact(_Fixture(scenarios: scenarios, report: report));
    final coverage = artifact['coverage'] as Map<String, dynamic>;
    final adversarial = artifact['adversarial'] as Map<String, dynamic>;
    final plan = artifact['nextExperimentPlan'] as Map<String, dynamic>;
    final selectors = plan['safeSelectors'] as Map<String, dynamic>;

    expect(jsonEncode(artifact), isNot(contains(protectedId)));
    expect(coverage['protectedPrimaryCapabilityValueOmittedCount'], 3);
    expect(adversarial['protectedAdversarialValueOmittedCount'], 2);
    expect(selectors['capabilities'], isNot(contains(protectedId)));
    expect(selectors['adversarialTags'], isNot(contains(protectedId)));
    EvalScenarioCatalogPreflight.assertValid(
      artifact,
      protectedValues: const {protectedId},
    );
  });

  test('profiles below trial minimum are emitted as opaque slots only', () {
    final scenarios = [
      _reviewedScenario(
        id: 'private_task_holdout',
        agentKind: AgentKind.taskAgent,
        capabilityId: 'cap.task',
        split: EvalScenarioSplit.holdout,
        source: EvalScenarioSource.productionReplay,
      ),
    ];
    const profiles = [
      EvalProfile(
        name: 'frontier-private-prod',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'frontier-private-model',
      ),
    ];
    const policy = EvalTuningPolicy(
      name: 'profileNameOmission',
      requiredPrimaryCapabilityIds: {'cap.task'},
      requiredSplits: {EvalScenarioSplit.holdout},
      requiredAgentKinds: {AgentKind.taskAgent},
      minProductionReplayHoldoutScenarios: 1,
      minProtectedHoldoutScenarios: 1,
      minTrialsPerProfile: 2,
      requireProtectedHoldout: true,
      requireReviewedScenarioEvidence: true,
    );
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: scenarios,
      profiles: profiles,
      policy: policy,
      scenarioCatalogEvidence: _evidence(
        scenarios,
        protectedIds: const ['private_task_holdout'],
      ),
    );
    final artifact = EvalScenarioCatalogPreflight.build(
      report: report,
      scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
      profileSetDigest: EvalProvenance.profileSetDigest(profiles),
      catalogMode: 'replace',
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );

    final encoded = jsonEncode(artifact);
    final profilesJson = artifact['profiles'] as Map<String, dynamic>;

    expect(encoded, isNot(contains('frontier-private-prod')));
    expect(encoded, isNot(contains('frontier-private-model')));
    expect(
      profilesJson['profilesBelowMinTrialCountProfileNamesOmitted'],
      isTrue,
    );
    expect(
      (profilesJson['profilesBelowMinTrialCount'] as Map<String, dynamic>).keys,
      ['profile-001'],
    );
    EvalScenarioCatalogPreflight.assertValid(artifact);
  });

  test('contract rejects scenario-id fields and protected placeholders', () {
    final artifact = _artifact(_readyFixture());
    final source = artifact['source'] as Map<String, dynamic>
      ..['protectedScenarioIds'] = ['private_task_holdout'];
    final coverage = artifact['coverage'] as Map<String, dynamic>;
    coverage['primaryCapabilityCounts'] = {
      ...coverage['primaryCapabilityCounts'] as Map<String, dynamic>,
      'private_task_holdout': 1,
    };
    artifact['selection'] = {
      ...(artifact['selection'] as Map<String, dynamic>),
      'reason': 'contains <protected-scenario>',
    };
    artifact['source'] = source;
    artifact['coverage'] = coverage;

    final issues = EvalScenarioCatalogPreflight.validate(
      artifact,
      protectedValues: const {'private_task_holdout'},
    );

    expect(
      issues,
      contains(
        'preflight.source.protectedScenarioIds must not expose scenario ids',
      ),
    );
    expect(
      issues,
      contains(
        'preflight.selection.reason must not contain protected scenario placeholders',
      ),
    );
    expect(
      issues,
      contains(
        'preflight.source.protectedScenarioIds[0] must not expose protected values',
      ),
    );
    expect(
      issues,
      contains(
        'preflight.coverage.primaryCapabilityCounts.private_task_holdout must not expose protected values',
      ),
    );
  });

  test('contract rejects private handoff payloads and executable commands', () {
    final artifact = _artifact(_readyFixture())
      ..['profileNames'] = const ['frontier-private']
      ..['runId'] = 'private-run'
      ..['tracePath'] = '/private/tmp/private.trace.json'
      ..['promptText'] = 'raw private prompt';
    final plan = artifact['nextExperimentPlan'] as Map<String, dynamic>;
    (plan['nextRunEnv'] as Map<String, dynamic>)
      ..['EVAL_PROFILE_NAMES'] = 'frontier-private'
      ..['EVAL_SCENARIOS_MODE'] = 'replace; EVAL_SCENARIO_IDS=private';
    final commands = (plan['recommendedCommands'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    commands.first
      ..['commandTemplate'] =
          'bash -lc "EVAL_PROFILE_NAMES=frontier-private eval/run_level2.sh run private-run"'
      ..['env'] = const {'EVAL_PROFILE_NAMES': 'frontier-private'}
      ..['command'] = 'eval/run_level2.sh run private-run'
      ..['shell'] = 'bash';

    final issues = EvalScenarioCatalogPreflight.validate(artifact);

    expect(
      issues,
      contains('preflight must not contain unsupported field profileNames'),
    );
    expect(
      issues,
      contains('preflight.profileNames must not expose profile selectors'),
    );
    expect(issues, contains('preflight.runId must not expose run ids'));
    expect(
      issues,
      contains('preflight.tracePath must not expose private paths'),
    );
    expect(
      issues,
      contains('preflight.tracePath must not contain private paths'),
    );
    expect(
      issues,
      contains('preflight.promptText must not expose raw prompt text'),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.nextRunEnv must not contain EVAL_PROFILE_NAMES',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.nextRunEnv must not contain value-bearing EVAL_PROFILE_NAMES',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.nextRunEnv.EVAL_SCENARIOS_MODE must be append or replace',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.recommendedCommands[0].commandTemplate must be eval/run_level2.sh catalog',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.recommendedCommands[0].commandTemplate must not contain shell wrappers or inline env',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.recommendedCommands[0] must not contain env values',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.recommendedCommands[0] must use commandTemplate only',
      ),
    );
    expect(
      issues,
      contains(
        'nextExperimentPlan.recommendedCommands[0] must not contain unsupported field shell',
      ),
    );
  });

  test('unsafe selector values are omitted from env and safe selectors', () {
    final scenarios = [
      _reviewedScenario(
        id: 'private_task_holdout',
        agentKind: AgentKind.taskAgent,
        capabilityId: 'cap.safe',
        split: EvalScenarioSplit.holdout,
        source: EvalScenarioSource.productionReplay,
      ),
    ];
    const policy = EvalTuningPolicy(
      name: 'unsafeSelectors',
      requiredPrimaryCapabilityIds: {'cap.safe', 'unsafe value'},
      requiredSplits: {EvalScenarioSplit.holdout},
      requiredAgentKinds: {AgentKind.taskAgent},
      minCapabilityCount: 2,
      minProductionReplayHoldoutScenarios: 1,
      minProtectedHoldoutScenarios: 1,
      requireProtectedHoldout: true,
      requireReviewedScenarioEvidence: true,
    );
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: scenarios,
      profiles: _profiles,
      policy: policy,
      scenarioCatalogEvidence: _evidence(
        scenarios,
        protectedIds: const ['private_task_holdout'],
      ),
    );
    final artifact = _artifact(_Fixture(scenarios: scenarios, report: report));
    final plan = artifact['nextExperimentPlan'] as Map<String, dynamic>;
    final safeSelectors = plan['safeSelectors'] as Map<String, dynamic>;
    final env = plan['nextRunEnv'] as Map<String, dynamic>;

    expect(safeSelectors['capabilities'], contains('cap.safe'));
    expect(safeSelectors['capabilities'], isNot(contains('unsafe value')));
    expect(env['EVAL_REQUIRED_CAPABILITIES'], isNot(contains('unsafe value')));
    EvalScenarioCatalogPreflight.assertValid(artifact);
  });
}

const _governancePolicy = EvalTuningPolicy(
  name: 'catalogGovernanceTest',
  requiredPrimaryCapabilityIds: {'cap.task', 'cap.plan'},
  requiredSplits: {
    EvalScenarioSplit.development,
    EvalScenarioSplit.holdout,
  },
  requiredAgentKinds: {
    AgentKind.taskAgent,
    AgentKind.planningAgent,
  },
  minScenarioCount: 2,
  minScenariosPerAgentKind: 1,
  minScenariosPerCapability: 1,
  minCapabilityCount: 2,
  minAdversarialScenarioCount: 1,
  requiredAdversarialTags: {'scope-boundary'},
  minProductionReplayHoldoutScenarios: 1,
  minProtectedHoldoutScenarios: 1,
  requireProtectedHoldout: true,
  requireReviewedScenarioEvidence: true,
);

const _profiles = [
  EvalProfile(
    name: 'local-small',
    isLocal: true,
    modelClass: EvalModelClass.localSmall,
    modelId: 'local-small-model',
  ),
  EvalProfile(
    name: 'frontier-fast',
    isLocal: false,
    modelClass: EvalModelClass.frontierFast,
    modelId: 'frontier-fast-model',
  ),
];

class _Fixture {
  const _Fixture({required this.scenarios, required this.report});

  final List<EvalScenario> scenarios;
  final EvalScenarioCatalogPreflightReport report;
}

_Fixture _readyFixture() {
  final scenarios = [
    _scenario(
      id: 'public_task',
      agentKind: AgentKind.taskAgent,
      capabilityId: 'cap.task',
    ),
    _reviewedScenario(
      id: 'private_task_holdout',
      agentKind: AgentKind.planningAgent,
      capabilityId: 'cap.plan',
      split: EvalScenarioSplit.holdout,
      source: EvalScenarioSource.productionReplay,
      isAdversarial: true,
      tags: const {'scope-boundary'},
    ),
  ];
  final report = EvalTuningReadiness.assessScenarioCatalog(
    scenarios: scenarios,
    profiles: _profiles,
    policy: _governancePolicy,
    scenarioCatalogEvidence: _evidence(
      scenarios,
      protectedIds: const ['private_task_holdout'],
    ),
  );
  return _Fixture(scenarios: scenarios, report: report);
}

Map<String, dynamic> _artifact(
  _Fixture fixture, {
  bool selectedSubset = false,
}) {
  return EvalScenarioCatalogPreflight.build(
    report: fixture.report,
    scenarioSetDigest: EvalProvenance.scenarioSetDigest(fixture.scenarios),
    profileSetDigest: EvalProvenance.profileSetDigest(_profiles),
    catalogMode: 'replace',
    selectedSubset: selectedSubset,
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
}

EvalScenarioCatalogEvidence _evidence(
  List<EvalScenario> scenarios, {
  required List<String> protectedIds,
}) {
  return EvalScenarioCatalogEvidence(
    scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
    publicScenarioCount: 0,
    externalScenarioCount: scenarios.length,
    externalCatalogDigest: EvalProvenance.digestText('external-catalog'),
    externalCatalogId: 'catalog.private.v1',
    protectedHoldout: protectedIds.isNotEmpty,
    protectedScenarioIds: protectedIds,
    protectedHoldoutScenarioIds: protectedIds,
  );
}

EvalScenario _reviewedScenario({
  required String id,
  required AgentKind agentKind,
  required String capabilityId,
  EvalScenarioSplit split = EvalScenarioSplit.development,
  EvalScenarioSource source = EvalScenarioSource.handAuthored,
  bool isAdversarial = false,
  Set<String> tags = const {},
  String? sourceDigest,
}) {
  final base = _scenario(
    id: id,
    agentKind: agentKind,
    capabilityId: capabilityId,
    split: split,
    source: source,
    isAdversarial: isAdversarial,
    tags: tags,
  );
  return _scenario(
    id: id,
    agentKind: agentKind,
    capabilityId: capabilityId,
    split: split,
    source: source,
    isAdversarial: isAdversarial,
    tags: tags,
    review: EvalScenarioReview(
      status: EvalScenarioReviewStatus.reviewed,
      reviewer: 'eval-governance',
      reviewedAt: '2026-06-12T10:00:00.000Z',
      subjectDigest: EvalProvenance.scenarioReviewSubjectDigest(base),
      rationale: 'Reviewed fixture scenario for catalog governance tests.',
      sourceDigest: sourceDigest ?? EvalProvenance.digestText('source-$id'),
    ),
  );
}

EvalScenario _scenario({
  required String id,
  required AgentKind agentKind,
  required String capabilityId,
  EvalScenarioSplit split = EvalScenarioSplit.development,
  EvalScenarioSource source = EvalScenarioSource.handAuthored,
  bool isAdversarial = false,
  Set<String> tags = const {},
  EvalScenarioReview? review,
}) {
  return EvalScenario(
    id: id,
    title: 'Scenario $id',
    agentKind: agentKind,
    appState: MockedAppState(now: DateTime.utc(2026, 6, 12, 10)),
    userInput: UserInput(
      transcript: 'Run scenario $id.',
      triggerTokens: {'run'},
    ),
    metadata: EvalScenarioMetadata(
      capabilityIds: [capabilityId],
      split: split,
      source: source,
      isAdversarial: isAdversarial,
      tags: isAdversarial ? {'adversarial', ...tags} : tags,
      review: review,
    ),
  );
}

Set<String> _issueCodes(Map<String, dynamic> artifact) {
  return {
    for (final issue in artifact['issues'] as List<dynamic>)
      (issue as Map<String, dynamic>)['code'] as String,
  };
}

List<String> _recommendedCommandModes(Map<String, dynamic> artifact) {
  final plan = artifact['nextExperimentPlan'] as Map<String, dynamic>;
  return [
    for (final command in plan['recommendedCommands'] as List<dynamic>)
      (command as Map<String, dynamic>)['mode'] as String,
  ];
}
