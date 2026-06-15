import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_decision_ledger_source_replay_test_utils.dart';
import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_tuning_source_replay_test_utils.dart';

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
const _roadmapInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGERS',
);
const _roadmapSourceManifestPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS',
);
const _roadmapOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_TUNING_ROADMAP',
);
const _roadmapOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_TUNING_ROADMAP_OVERWRITE',
);

void main() {
  test('aggregates accepted choices across independent use-case scopes', () {
    const taskScope = _ScopeFixture(
      compatibilitySeed: 'compat-task',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontier',
      promptVariantName: 'default',
      cellSeed: 'task-frontier',
      reportSeed: 'task-report',
    );
    const groomingScope = _ScopeFixture(
      compatibilitySeed: 'compat-grooming',
      primaryCapabilityId: 'task.grooming',
      modelClass: 'local',
      promptVariantName: 'structured',
      cellSeed: 'grooming-local',
      reportSeed: 'grooming-report',
    );

    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [
        _ledgerFor(taskScope.acceptedDecision()),
        _ledgerFor(groomingScope.acceptedDecision()),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    expect(EvalUseCaseTuningRoadmap.validate(roadmap), isEmpty);
    expect(roadmap['status'], 'accepted');
    final summary = roadmap['summary'] as Map<String, dynamic>;
    expect(summary['sourceLedgerCount'], 2);
    expect(summary['scopeCount'], 2);
    expect(summary['acceptedScopeCount'], 2);
    final scopes = _scopes(roadmap);
    expect(
      scopes.map((scope) => scope['primaryCapabilityId']),
      containsAll(['task.workflow', 'task.grooming']),
    );
    for (final scope in scopes) {
      expect(scope['status'], 'accepted');
      expect(scope['uniqueAcceptedChoiceCount'], 1);
      final choice =
          (scope['acceptedChoices'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(
        EvalProvenance.isDigest(
          choice['modelClassCoverageProofRef'] as String,
        ),
        isTrue,
      );
      expect(
        EvalProvenance.isDigest(choice['workOrderBatchRef'] as String),
        isTrue,
      );
      expect(
        EvalProvenance.isDigest(choice['modelClassCoverageRef'] as String),
        isTrue,
      );
      expect(
        EvalProvenance.isDigest(
          choice['modelClassCoverageClassRef'] as String,
        ),
        isTrue,
      );
      expect(
        EvalProvenance.isDigest(
          choice['modelClassCoverageDigest'] as String,
        ),
        isTrue,
      );
      expect(
        EvalProvenance.isDigest(choice['sourceWorkOrderDigest'] as String),
        isTrue,
      );
      expect(scope['blockerCodes'], isEmpty);
    }
  });

  test('flags cross-ledger accepted-choice conflicts for the same scope', () {
    const baseline = _ScopeFixture(
      compatibilitySeed: 'same-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontier',
      promptVariantName: 'default',
      cellSeed: 'frontier-cell',
      reportSeed: 'frontier-report',
    );
    final competing = baseline.copyWith(
      modelClass: 'local',
      promptVariantName: 'short-context',
      cellSeed: 'local-cell',
      reportSeed: 'local-report',
    );

    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [
        _ledgerFor(baseline.acceptedDecision()),
        _ledgerFor(competing.acceptedDecision()),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    expect(roadmap['status'], 'conflict');
    final scope = _singleScope(roadmap);
    expect(scope['status'], 'conflict');
    expect(scope['acceptedChoiceCount'], 2);
    expect(scope['uniqueAcceptedChoiceCount'], 2);
    expect(
      scope['blockerCodes'],
      contains('roadmap.multipleAcceptedChoices'),
    );
    expect(
      roadmap['blockedReasonCodes'],
      contains('roadmap.scopeConflict'),
    );
  });

  test('requires revalidation when accepted evidence is later contested', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'same-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontier',
      promptVariantName: 'default',
      cellSeed: 'frontier-cell',
      reportSeed: 'frontier-report',
    );

    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [
        _ledgerFor(fixture.acceptedDecision()),
        _ledgerFor(
          fixture.blockedDecision(
            blockerCodes: const ['verdict.regression'],
          ),
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    expect(roadmap['status'], 'revalidateRequired');
    final scope = _singleScope(roadmap);
    expect(scope['status'], 'revalidateRequired');
    expect(
      scope['blockerCodes'],
      contains('roadmap.acceptedChoiceHasContestedEvidence'),
    );
    expect(scope['blockerCodes'], contains('verdict.regression'));
  });

  test('carries rollback continuity into the aggregate roadmap', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'same-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontier',
      promptVariantName: 'default',
      cellSeed: 'frontier-cell',
      reportSeed: 'frontier-report',
    );
    final continuity = fixture.rollbackContinuity();

    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [
        _ledgerFor(
          fixture.blockedDecision(
            blockerCodes: const ['decision.previousAcceptedBlocked'],
          ),
          continuity: [continuity],
          status: 'blocked',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    expect(roadmap['status'], 'rollbackRequired');
    final scope = _singleScope(roadmap);
    expect(scope['status'], 'rollbackRequired');
    expect(scope['continuityStatuses'], contains('rollbackRequired'));
    expect(
      roadmap['blockedReasonCodes'],
      contains('roadmap.scopeRollbackRequired'),
    );
  });

  test(
    'keeps compatible-looking scopes separate across compatibility keys',
    () {
      const frontier = _ScopeFixture(
        compatibilitySeed: 'frontier-compat',
        primaryCapabilityId: 'task.workflow',
        modelClass: 'frontier',
        promptVariantName: 'default',
        cellSeed: 'frontier-cell',
        reportSeed: 'frontier-report',
      );
      final protectedHoldout = frontier.copyWith(
        compatibilitySeed: 'protected-holdout-compat',
        cellSeed: 'holdout-cell',
        reportSeed: 'holdout-report',
      );

      final roadmap = EvalUseCaseTuningRoadmap.build(
        ledgers: [
          _ledgerFor(frontier.acceptedDecision()),
          _ledgerFor(protectedHoldout.acceptedDecision()),
        ],
        generatedAt: DateTime.utc(2026, 6, 12, 14),
      );

      expect(roadmap['status'], 'accepted');
      expect(_scopes(roadmap), hasLength(2));
      expect(
        _scopes(roadmap).map((scope) => scope['compatibilityKey']).toSet(),
        hasLength(2),
      );
    },
  );

  test(
    'invalid source ledgers block the roadmap without leaking issue text',
    () {
      const fixture = _ScopeFixture(
        compatibilitySeed: 'same-compat',
        primaryCapabilityId: 'task.workflow',
        modelClass: 'frontier',
        promptVariantName: 'default',
        cellSeed: 'frontier-cell',
        reportSeed: 'frontier-report',
      );
      final invalid = _ledgerFor(fixture.acceptedDecision())
        ..['kind'] = 'lotti.invalid'
        ..['status'] = '/Users/mn/private-status'
        ..['blockedReasonCodes'] = const ['/Users/mn/private-ledger.json'];

      final roadmap = EvalUseCaseTuningRoadmap.build(
        ledgers: [invalid],
        generatedAt: DateTime.utc(2026, 6, 12, 14),
      );

      expect(roadmap['status'], 'invalid');
      expect(_scopes(roadmap), isEmpty);
      final source = _singleMap(roadmap, 'sourceLedgers');
      expect(source['status'], 'invalid');
      expect(source['contractIssueCount'], greaterThan(0));
      expect(source['blockedReasonCodes'], isEmpty);
      final issue = _singleMap(roadmap, 'issues');
      expect(issue['code'], 'roadmap.sourceLedgerInvalid');
      expect(issue.containsKey('messages'), isFalse);
      expect(roadmap.toString(), isNot(contains('/Users/mn')));
    },
  );

  test(
    'contract rejects private selectors, paths, env maps, and live commands',
    () {
      const fixture = _ScopeFixture(
        compatibilitySeed: 'same-compat',
        primaryCapabilityId: 'task.workflow',
        modelClass: 'frontier',
        promptVariantName: 'default',
        cellSeed: 'frontier-cell',
        reportSeed: 'frontier-report',
      );
      final roadmap = EvalUseCaseTuningRoadmap.build(
        ledgers: [_ledgerFor(fixture.acceptedDecision())],
        generatedAt: DateTime.utc(2026, 6, 12, 14),
      );
      final scope = _singleScope(roadmap);
      scope['scenarioIds'] = const ['task_workflow_private'];
      scope['privatePath'] = '/Users/mn/private-ledger.json';
      (roadmap['recommendedCommands'] as List<dynamic>).add(
        <String, dynamic>{
          'mode': 'run',
          'command': 'eval/run_level2.sh run private',
          'env': const <String, dynamic>{
            'EVAL_USE_CASE_DECISION_LEDGERS': '/private/tmp/ledger.json',
          },
        },
      );

      final issues = EvalUseCaseTuningRoadmap.validate(roadmap);

      expect(
        issues,
        contains('roadmap.scopes[0].scenarioIds must not expose scenario ids'),
      );
      expect(
        issues,
        contains(
          'roadmap.scopes[0].privatePath must not contain private paths',
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
    },
  );

  test('contract rejects non-digest model-class coverage refs', () {
    const fixture = _ScopeFixture(
      compatibilitySeed: 'same-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontier',
      promptVariantName: 'default',
      cellSeed: 'frontier-cell',
      reportSeed: 'frontier-report',
    );
    final roadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [_ledgerFor(fixture.acceptedDecision())],
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );
    final choice =
        (_singleScope(roadmap)['acceptedChoices'] as List<dynamic>).single
              as Map<String, dynamic>
          ..['modelClassCoverageRef'] = 'forged-coverage-ref';

    final issues = EvalUseCaseTuningRoadmap.validate(roadmap);

    expect(choice['modelClassCoverageRef'], 'forged-coverage-ref');
    expect(
      issues,
      contains(
        'scopes[0].acceptedChoices[0].modelClassCoverageRef must be a sha256 digest',
      ),
    );
  });

  test('source-aware validation rejects restamped source ledgers', () {
    const original = _ScopeFixture(
      compatibilitySeed: 'task-compat',
      primaryCapabilityId: 'task.workflow',
      modelClass: 'frontier',
      promptVariantName: 'default',
      cellSeed: 'frontier-cell',
      reportSeed: 'frontier-report',
    );
    final replacement = original.copyWith(
      modelClass: 'local',
      promptVariantName: 'short-context',
      cellSeed: 'local-cell',
      reportSeed: 'local-report',
    );
    final originalLedger = _ledgerFor(original.acceptedDecision());
    final replacementLedger = _ledgerFor(replacement.acceptedDecision());
    final forgedRoadmap = _restampRoadmapSourceLedger(
      EvalUseCaseTuningRoadmap.build(
        ledgers: [originalLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 14),
      ),
      replacementRoadmap: EvalUseCaseTuningRoadmap.build(
        ledgers: [replacementLedger],
        generatedAt: DateTime.utc(2026, 6, 12, 14),
      ),
    );

    expect(EvalUseCaseTuningRoadmap.validate(forgedRoadmap), isEmpty);

    final issues = EvalUseCaseTuningRoadmap.validateAgainstDecisionLedgers(
      forgedRoadmap,
      ledgers: [replacementLedger],
    );

    expect(issues, contains('roadmap must match source decision ledgers'));
  });

  test('source replay requirement rejects serialized decision ledgers', () {
    final matrix = EvalUseCaseTuningMatrix.build(
      reports: const [],
      requireSourceChecks: false,
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    EvalUseCaseTuningMatrix.assertMatchesSources(
      matrix,
      reports: const [],
      requireSourceChecks: false,
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: matrix,
      requireMatrixSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    EvalUseCaseTuningDecisionLedger.assertMatchesSources(
      ledger,
      matrix: matrix,
      requireCampaignSourceReplay: false,
    );
    final serializedLedger =
        jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;

    final serializedRoadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [serializedLedger],
      requireDecisionLedgerSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    final serializedSource = _singleMap(serializedRoadmap, 'sourceLedgers');
    expect(serializedSource['status'], 'invalid');
    expect(serializedSource['contractIssueCount'], 1);
    expect(
      _singleMap(serializedRoadmap, 'issues')['code'],
      'roadmap.sourceLedgerInvalid',
    );

    final replayedRoadmap = EvalUseCaseTuningRoadmap.build(
      ledgers: [ledger],
      requireDecisionLedgerSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    final replayedSource = _singleMap(replayedRoadmap, 'sourceLedgers');
    expect(replayedSource['contractIssueCount'], 0);
    expect(replayedRoadmap['issues'], isEmpty);
  });

  test(
    'writes use-case tuning roadmap',
    () async {
      final ledgers = [
        for (final path in _roadmapInputPaths.split(','))
          if (path.trim().isNotEmpty)
            jsonDecode(File(path.trim()).readAsStringSync())
                as Map<String, dynamic>,
      ];
      final replayedLedgers = await evalReplayDecisionLedgerSourceManifests(
        ledgers: ledgers,
        manifests: evalReadDecisionLedgerSourceManifestFiles(
          _roadmapSourceManifestPaths,
        ),
        config: _sourceReplayConfig(),
      );
      final roadmap = EvalUseCaseTuningRoadmap.build(
        ledgers: replayedLedgers,
        requireDecisionLedgerSourceReplay: true,
      );
      EvalUseCaseTuningRoadmap.assertValid(roadmap);
      EvalUseCaseTuningRoadmap.assertMatchesDecisionLedgers(
        roadmap,
        ledgers: replayedLedgers,
        requireDecisionLedgerSourceReplay: true,
      );
      writeEvalJsonArtifact(
        roadmap,
        path: _roadmapOutputPath,
        overwrite: _roadmapOverwrite == '1',
        description: 'use-case tuning roadmap',
      );
    },
    skip:
        _roadmapInputPaths.isEmpty ||
            _roadmapSourceManifestPaths.isEmpty ||
            _roadmapOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_DECISION_LEDGERS=<json,...>, '
              'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=<json,...>, and '
              'EVAL_USE_CASE_TUNING_ROADMAP=<json> to write a roadmap.'
        : false,
  );
}

Map<String, dynamic> _restampRoadmapSourceLedger(
  Map<String, dynamic> roadmap, {
  required Map<String, dynamic> replacementRoadmap,
}) {
  final forged = jsonDecode(jsonEncode(roadmap)) as Map<String, dynamic>;
  final replacementSourceLedger =
      (replacementRoadmap['sourceLedgers'] as List<dynamic>).single
          as Map<String, dynamic>;
  final replacementLedgerRef = replacementSourceLedger['ledgerRef'] as String;
  forged['sourceLedgers'] = [replacementSourceLedger];
  final scope =
      (forged['scopes'] as List<dynamic>).single as Map<String, dynamic>;
  scope['sourceLedgerRefs'] = [replacementLedgerRef];
  final choice =
      (scope['acceptedChoices'] as List<dynamic>).single
          as Map<String, dynamic>;
  choice['sourceLedgerRefs'] = [replacementLedgerRef];
  return forged;
}

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

List<Map<String, dynamic>> _scopes(Map<String, dynamic> roadmap) =>
    (roadmap['scopes'] as List<dynamic>).cast<Map<String, dynamic>>();

Map<String, dynamic> _singleScope(Map<String, dynamic> roadmap) {
  final scopes = _scopes(roadmap);
  expect(scopes, hasLength(1));
  return scopes.single;
}

Map<String, dynamic> _singleMap(Map<String, dynamic> root, String key) {
  final list = root[key] as List<dynamic>;
  expect(list, hasLength(1));
  return list.single as Map<String, dynamic>;
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

List<String> _stringList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      ]
    : const <String>[];

List<String> _sortedStrings(Iterable<String> values) =>
    values.where((value) => value.isNotEmpty).toSet().toList()..sort();

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

final class _ScopeFixture {
  const _ScopeFixture({
    required this.compatibilitySeed,
    required this.primaryCapabilityId,
    required this.modelClass,
    required this.promptVariantName,
    required this.cellSeed,
    required this.reportSeed,
    this.agentKind = 'taskAgent',
  });

  final String compatibilitySeed;
  final String primaryCapabilityId;
  final String agentKind;
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
    String? agentKind,
    String? modelClass,
    String? promptVariantName,
    String? cellSeed,
    String? reportSeed,
  }) => _ScopeFixture(
    compatibilitySeed: compatibilitySeed ?? this.compatibilitySeed,
    primaryCapabilityId: primaryCapabilityId ?? this.primaryCapabilityId,
    agentKind: agentKind ?? this.agentKind,
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
