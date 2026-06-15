import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import 'eval_harness.dart';
import 'eval_json_artifact_writer.dart';
import 'eval_profile_config.dart';
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
const _decisionMatrixInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_MATRIX_INPUT',
);
const _decisionMatrixReportInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_MATRIX_REPORTS',
);
const _decisionCampaignInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_CAMPAIGN_INPUT',
);
const _decisionCampaignPlanInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_CAMPAIGN_EXPERIMENT_PLAN_INPUT',
);
const _decisionCampaignReportInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_CAMPAIGN_REPORTS',
);
const _decisionCampaignModelClassCoverageInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_MODEL_CLASS_COVERAGE',
);
const _decisionCampaignModelClassCoverageWorkOrderInputPath =
    String.fromEnvironment(
      'EVAL_USE_CASE_DECISION_MODEL_CLASS_COVERAGE_WORK_ORDER',
    );
const _decisionCampaignModelClassExecutionExperimentPlanInputPath =
    String.fromEnvironment(
      'EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN',
    );
const _decisionCampaignModelClassExecutionEvidenceInputPaths =
    String.fromEnvironment(
      'EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_EVIDENCE',
    );
const _decisionCampaignModelClassExecutionRunIds = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_RUNS',
);
const _decisionPreviousLedgerPath = String.fromEnvironment(
  'EVAL_USE_CASE_PREVIOUS_DECISION_LEDGER',
);
const _decisionReviewAttestationPaths = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_REVIEW_ATTESTATIONS',
);
const _decisionOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER',
);
const _decisionOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_DECISION_LEDGER_OVERWRITE',
);

void main() {
  test('accepts exactly one promotion-ready campaign-ready cell', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final matrix = _matrixFor([followUp]);

    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: matrix,
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(EvalUseCaseTuningDecisionLedger.validate(ledger), isEmpty);
    expect(ledger['status'], 'accepted');
    expect(
      (ledger['sourceMatrix']
          as Map<String, dynamic>)['sourceCheckedInputReportDigestCount'],
      1,
    );
    expect(
      (ledger['sourceCampaign']
          as Map<String, dynamic>)['sourceCheckedReadyReportDigestCount'],
      1,
    );
    expect(
      EvalProvenance.isDigest(ledger['decisionLedgerRef'] as String),
      isTrue,
    );
    final decision = _singleMap(ledger, 'decisions');
    expect(decision['status'], 'accepted');
    expect(decision['promotionCandidateCount'], 1);
    expect(decision['campaignReadyCandidateCount'], 1);
    final accepted = decision['acceptedCandidate'] as Map<String, dynamic>;
    expect(accepted['sourceChecked'], isTrue);
    expect(accepted['modelClass'], _fixtureModelClassName('frontier'));
    expect(accepted['promptVariantName'], 'default');
    final proof = accepted['modelClassCoverageProof'] as Map<String, dynamic>;
    expect(
      proof.keys.toSet(),
      {
        'proofRef',
        'compatibilityKey',
        'primaryCapabilityId',
        'modelClass',
        'promptVariantName',
        'reportDigest',
        'workOrderBatchRef',
        'modelClassCoverageRef',
        'modelClassCoverageClassRef',
        'modelClassCoverageDigest',
        'sourceWorkOrderDigest',
      },
    );
    expect(proof['modelClass'], _fixtureModelClassName('frontier'));
    expect(
      EvalProvenance.isDigest(proof['modelClassCoverageRef'] as String),
      isTrue,
    );
    expect(
      EvalProvenance.isDigest(
        proof['modelClassCoverageClassRef'] as String,
      ),
      isTrue,
    );
    expect(proof['modelClassCoverageDigest'], isA<String>());
    expect(proof['workOrderBatchRef'], isA<String>());
    expect(proof['sourceWorkOrderDigest'], isA<String>());
    expect(decision['blockerCodes'], isEmpty);
  });

  test('source replay requirement rejects serialized campaigns', () {
    final base = _report(
      runId: 'base-ready',
      modelClass: 'frontier',
      ready: true,
    );
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final matrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [base],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    final plan = EvalUseCaseExperimentPlan.build(
      matrix: matrix,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );
    final workOrder = EvalUseCaseNextRunWorkOrder.build(
      experimentPlan: plan,
      generatedAt: DateTime.utc(2026, 6, 12, 11, 30),
    );
    final coverage = _modelClassCoverageForWorkOrder(
      workOrder,
      sourceExperimentPlan: plan,
    );
    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [followUp],
      modelClassExecutionCoverages: [coverage],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final serializedCampaign =
        jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;

    final serializedLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: serializedCampaign,
      reviewAttestations: _reviewAttestations(serializedCampaign),
      requireCampaignSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(serializedLedger['status'], 'invalid');
    expect(
      serializedLedger['issues'],
      contains(
        containsPair('message', 'campaign source replay must be verified'),
      ),
    );

    EvalUseCaseTuningCampaign.assertMatchesSources(
      campaign,
      experimentPlan: plan,
      reports: [followUp],
      requireSourceChecks: false,
      modelClassExecutionCoverages: [coverage],
      modelClassExecutionWorkOrders: [workOrder],
    );
    final replayedLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      requireCampaignSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(
      (replayedLedger['sourceCampaign']
          as Map<String, dynamic>)['contractIssueCount'],
      0,
    );
    expect(
      replayedLedger['issues'],
      isNot(
        contains(
          containsPair('message', 'campaign source replay must be verified'),
        ),
      ),
    );
  });

  test('source replay requirement rejects serialized matrices', () {
    final report = _report(
      runId: 'restamped-matrix-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final serializedMatrix = _matrixFor([report]);

    final serializedLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: serializedMatrix,
      requireMatrixSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(serializedLedger['status'], 'invalid');
    expect(
      (serializedLedger['sourceMatrix']
          as Map<String, dynamic>)['contractIssueCount'],
      1,
    );
    expect(
      serializedLedger['issues'],
      contains(
        containsPair('message', 'matrix source replay must be verified'),
      ),
    );

    final replayedMatrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [report],
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );
    EvalUseCaseTuningMatrix.assertMatchesSources(
      replayedMatrix,
      reports: [report],
      requireSourceChecks: false,
    );

    final replayedLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: replayedMatrix,
      requireMatrixSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(
      (replayedLedger['sourceMatrix']
          as Map<String, dynamic>)['contractIssueCount'],
      0,
    );
    expect(
      replayedLedger['issues'],
      isNot(
        contains(
          containsPair('message', 'matrix source replay must be verified'),
        ),
      ),
    );
  });

  test('source replay requirement rejects serialized previous ledgers', () {
    final previousReport = _report(
      runId: 'previous-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final previousMatrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [previousReport],
      generatedAt: DateTime.utc(2026, 6, 12, 10),
    );
    EvalUseCaseTuningMatrix.assertMatchesSources(
      previousMatrix,
      reports: [previousReport],
      requireSourceChecks: false,
    );
    final previousLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: previousMatrix,
      requireMatrixSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 11),
    );
    EvalUseCaseTuningDecisionLedger.assertMatchesSources(
      previousLedger,
      matrix: previousMatrix,
    );

    final currentReport = _report(
      runId: 'current-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final currentMatrix = EvalUseCaseTuningMatrix.build(
      requireSourceChecks: false,
      reports: [currentReport],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    EvalUseCaseTuningMatrix.assertMatchesSources(
      currentMatrix,
      reports: [currentReport],
      requireSourceChecks: false,
    );
    final serializedPreviousLedger =
        jsonDecode(jsonEncode(previousLedger)) as Map<String, dynamic>;

    final serializedLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: currentMatrix,
      previousLedger: serializedPreviousLedger,
      requireMatrixSourceReplay: true,
      requirePreviousLedgerSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(serializedLedger['status'], 'invalid');
    expect(
      serializedLedger['issues'],
      contains(
        containsPair(
          'message',
          'previous ledger source replay must be verified',
        ),
      ),
    );

    final replayedLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: currentMatrix,
      previousLedger: previousLedger,
      requireMatrixSourceReplay: true,
      requirePreviousLedgerSourceReplay: true,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(
      replayedLedger['issues'],
      isNot(
        contains(
          containsPair(
            'message',
            'previous ledger source replay must be verified',
          ),
        ),
      ),
    );
  });

  test('blocks promotion-ready matrix reports without source checks', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );

    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp], sourceChecked: false),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(EvalUseCaseTuningDecisionLedger.validate(ledger), isEmpty);
    expect(ledger['status'], 'blocked');
    expect(
      (ledger['sourceMatrix']
          as Map<String, dynamic>)['sourceCheckedInputReportDigestCount'],
      0,
    );
    final decision = _singleMap(ledger, 'decisions');
    expect(decision['status'], 'staleEvidence');
    expect(decision['campaignReadyCandidateCount'], 1);
    final candidate = _singleMap(decision, 'candidates');
    expect(candidate['sourceChecked'], isFalse);
    expect(
      decision['blockerCodes'],
      contains('decision.matrixReportSourceUnchecked'),
    );
    expect(decision.containsKey('acceptedCandidate'), isFalse);
  });

  test('blocks campaign-ready reports without campaign source checks', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
      sourceChecked: false,
    );

    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(EvalUseCaseTuningDecisionLedger.validate(ledger), isEmpty);
    expect(ledger['status'], 'blocked');
    expect(
      (ledger['sourceCampaign']
          as Map<String, dynamic>)['sourceCheckedReadyReportDigestCount'],
      0,
    );
    final decision = _singleMap(ledger, 'decisions');
    expect(decision['status'], 'staleEvidence');
    expect(decision['campaignReadyCandidateCount'], 0);
    expect(
      decision['blockerCodes'],
      contains('decision.campaignReportSourceUnchecked'),
    );
    expect(
      decision['blockerCodes'],
      isNot(contains('decision.campaignEvidenceMissing')),
    );
    expect(decision.containsKey('acceptedCandidate'), isFalse);
  });

  test('does not accept campaign-ready reports without coverage proof', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
      includeModelClassCoverage: false,
    );

    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(ledger['status'], 'blocked');
    final decision = _singleMap(ledger, 'decisions');
    expect(decision['status'], 'staleEvidence');
    expect(decision['campaignReadyCandidateCount'], 0);
    expect(
      decision['blockerCodes'],
      contains('decision.campaignEvidenceMissing'),
    );
  });

  test('blocks review attestations that match category but not reviewRef', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final wrongRefAttestations = [
      for (final (index, attestation) in _reviewAttestations(campaign).indexed)
        _stampedReviewAttestation(<String, dynamic>{
          ...attestation,
          if (index == 0) 'reviewRef': EvalProvenance.digestText('wrong-ref'),
        }),
    ];

    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: wrongRefAttestations,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(ledger['status'], 'invalid');
    final reviewGate = ledger['reviewGate'] as Map<String, dynamic>;
    expect(reviewGate['approved'], isFalse);
    expect(reviewGate['missingRequirementCount'], 1);
    expect(_singleMap(ledger, 'decisions')['status'], 'reviewBlocked');
  });

  test('blocks loose extra attestations outside the campaign review queue', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final otherCampaign = _campaignFor(
      baseReports: [
        _report(runId: 'other-base', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [
        _report(
          runId: 'other-follow-up-promote',
          modelClass: 'frontier',
          ready: true,
          promotionStatus: 'promote',
        ),
      ],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: [
        ..._reviewAttestations(campaign),
        _reviewAttestations(otherCampaign).first,
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(ledger['status'], 'invalid');
    expect(_singleMap(ledger, 'decisions')['status'], 'reviewBlocked');
    expect(
      ledger['issues'],
      contains(
        isA<Map<String, dynamic>>()
            .having(
              (issue) => issue['code'],
              'code',
              'reviewAttestation.contractInvalid',
            )
            .having(
              (issue) => issue['message'],
              'message',
              contains('must match a campaign review requirement'),
            ),
      ),
    );
  });

  test('contract rejects relabelled missing review gate approval', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>
      ..['status'] = 'accepted';
    final reviewGate = tampered['reviewGate'] as Map<String, dynamic>
      ..['approved'] = true
      ..['missingRequirementCount'] = 0
      ..['missingRequirements'] = const <dynamic>[];
    expect(reviewGate['requirements'], isNotEmpty);
    (tampered['summary']
            as Map<String, dynamic>)['missingReviewAttestationCount'] =
        0;
    tampered['decisionLedgerRef'] =
        EvalUseCaseTuningDecisionLedger.decisionLedgerRef(tampered);

    final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

    expect(
      issues,
      contains(
        'reviewGate.approvedAttestationEvidence must cover every requirement when approved',
      ),
    );
    expect(issues, contains('status must match ledger-derived state'));
  });

  test(
    'keeps diagnostic and data-deficient cells out of accepted decisions',
    () {
      final diagnostic = _report(
        runId: 'ready-source',
        modelClass: 'frontier',
        ready: true,
        passRate: 1,
        passRateLowerBound: 0.95,
        meanGoalAttainment: 5,
      );
      final diagnosticCampaign = _campaignFor(
        baseReports: [diagnostic],
        followUpReports: [diagnostic],
      );
      final diagnosticLedger = EvalUseCaseTuningDecisionLedger.build(
        matrix: _matrixFor([diagnostic]),
        campaign: diagnosticCampaign,
        reviewAttestations: _reviewAttestations(diagnosticCampaign),
        generatedAt: DateTime.utc(2026, 6, 12, 13),
      );

      expect(diagnosticLedger['status'], 'watchOnly');
      expect(_singleMap(diagnosticLedger, 'decisions')['status'], 'watch');

      final blocked = _report(
        runId: 'data-deficient',
        modelClass: 'frontier',
        passRate: 1,
        passRateLowerBound: 0.95,
        meanGoalAttainment: 5,
      );
      final blockedCampaign = _campaignFor(
        baseReports: [
          _report(runId: 'blocked-base', modelClass: 'frontier', ready: true),
        ],
        followUpReports: [blocked],
      );
      final blockedLedger = EvalUseCaseTuningDecisionLedger.build(
        matrix: _matrixFor([blocked]),
        campaign: blockedCampaign,
        reviewAttestations: _reviewAttestations(blockedCampaign),
        generatedAt: DateTime.utc(2026, 6, 12, 13),
      );

      expect(blockedLedger['status'], 'blocked');
      expect(_singleMap(blockedLedger, 'decisions')['status'], 'blocked');
    },
  );

  test(
    'blocks when refreshed matrix is missing campaign-ready report digests',
    () {
      final campaignFollowUp = _report(
        runId: 'campaign-follow-up',
        modelClass: 'frontier',
        ready: true,
        promotionStatus: 'promote',
      );
      final staleMatrixReport = _report(
        runId: 'stale-matrix-report',
        modelClass: 'frontier',
        ready: true,
        promotionStatus: 'promote',
      );
      final campaign = _campaignFor(
        baseReports: [
          _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
        ],
        followUpReports: [campaignFollowUp],
      );

      final ledger = EvalUseCaseTuningDecisionLedger.build(
        matrix: _matrixFor([staleMatrixReport]),
        campaign: campaign,
        reviewAttestations: _reviewAttestations(campaign),
        generatedAt: DateTime.utc(2026, 6, 12, 13),
      );

      expect(ledger['status'], 'staleMatrix');
      expect(
        ledger['blockedReasonCodes'],
        contains('decision.matrixMissingCampaignEvidence'),
      );
      final refresh = ledger['matrixRefreshEvidence'] as Map<String, dynamic>;
      expect(refresh['missingReadyReportDigestCount'], 1);
      expect(_singleMap(ledger, 'decisions')['status'], 'staleEvidence');
    },
  );

  test('marks same-scope promotion candidates as conflicts', () {
    final frontier = _report(
      runId: 'frontier-follow-up',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final local = _report(
      runId: 'local-follow-up',
      modelClass: 'local',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [frontier, local],
    );

    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([frontier, local]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(ledger['status'], 'conflict');
    final decision = _singleMap(ledger, 'decisions');
    expect(decision['status'], 'conflict');
    expect(decision['promotionCandidateCount'], 2);
    expect(
      decision['blockerCodes'],
      contains('decision.promotionConflict'),
    );
  });

  test(
    'keeps same-scope conflict when only one promotion candidate has coverage proof',
    () {
      final frontier = _report(
        runId: 'frontier-follow-up',
        modelClass: 'frontier',
        ready: true,
        promotionStatus: 'promote',
      );
      final local = _report(
        runId: 'local-follow-up',
        modelClass: 'local',
        ready: true,
        promotionStatus: 'promote',
      );
      final campaign = _campaignFor(
        baseReports: [
          _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
        ],
        followUpReports: [frontier],
      );

      final ledger = EvalUseCaseTuningDecisionLedger.build(
        matrix: _matrixFor([frontier, local]),
        campaign: campaign,
        reviewAttestations: _reviewAttestations(campaign),
        generatedAt: DateTime.utc(2026, 6, 12, 13),
      );

      expect(ledger['status'], 'conflict');
      final decision = _singleMap(ledger, 'decisions');
      expect(decision['status'], 'conflict');
      expect(decision['promotionCandidateCount'], 2);
      expect(decision['campaignReadyCandidateCount'], 1);
      expect(decision.containsKey('acceptedCandidate'), isFalse);
      expect(
        decision['blockerCodes'],
        contains('decision.promotionConflict'),
      );
    },
  );

  test('blocks matched coverage refs that do not cover the ready batch', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final tamperedCampaign =
        jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;
    final coverage =
        (tamperedCampaign['inputModelClassExecutionCoverages'] as List<dynamic>)
                  .single
              as Map<String, dynamic>
          ..['coveredWorkOrderBatchRefs'] = [
            EvalProvenance.digestText('other-batch'),
          ];
    coverage['coverageRef'] = _campaignCoverageSnapshotRef(coverage);
    tamperedCampaign['campaignRef'] = EvalUseCaseTuningCampaign.campaignRef(
      tamperedCampaign,
    );

    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: tamperedCampaign,
      reviewAttestations: _reviewAttestations(tamperedCampaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(coverage['contractStatus'], 'valid');
    expect(ledger['status'], 'blocked');
    final decision = _singleMap(ledger, 'decisions');
    expect(decision['status'], 'staleEvidence');
    expect(decision['campaignReadyCandidateCount'], 0);
    expect(
      decision['blockerCodes'],
      contains('decision.campaignEvidenceMissing'),
    );
  });

  test('requires rollback when a previous accepted scope is now blocked', () {
    final previousFollowUp = _report(
      runId: 'previous-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final previousCampaign = _campaignFor(
      baseReports: [
        _report(runId: 'previous-base', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [previousFollowUp],
    );
    final previousLedger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([previousFollowUp]),
      campaign: previousCampaign,
      reviewAttestations: _reviewAttestations(previousCampaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    final blockedFollowUp = _report(
      runId: 'blocked-follow-up',
      modelClass: 'frontier',
    );
    final blockedCampaign = _campaignFor(
      baseReports: [
        _report(runId: 'blocked-base', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [blockedFollowUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([blockedFollowUp]),
      campaign: blockedCampaign,
      previousLedger: previousLedger,
      reviewAttestations: _reviewAttestations(blockedCampaign),
      generatedAt: DateTime.utc(2026, 6, 12, 14),
    );

    expect(ledger['status'], 'blocked');
    final continuity = _singleMap(ledger, 'previousDecisionContinuity');
    expect(continuity['status'], 'rollbackRequired');
    expect(
      continuity['blockerCodes'],
      contains('decision.previousAcceptedBlocked'),
    );
  });

  test('keeps incompatible compatibility groups isolated', () {
    final groupA = _report(
      runId: 'group-a',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
      scenarioSetSeed: 'scenario-set-a',
    );
    final groupB = _report(
      runId: 'group-b',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
      scenarioSetSeed: 'scenario-set-b',
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([groupA, groupB]),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );

    expect(ledger['status'], 'blockedCampaign');
    final decisions = (ledger['decisions'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(decisions, hasLength(2));
    expect(decisions.map((decision) => decision['status']).toSet(), {
      'staleEvidence',
    });
    expect(
      decisions.map((decision) => decision['compatibilityKey']).toSet(),
      hasLength(2),
    );
  });

  test('contract rejects private payload and live command tampering', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>
      ..['scenarioIds'] = const ['private-case'];
    final decision =
        ((tampered['decisions'] as List<dynamic>).single
              as Map<String, dynamic>)
          ..['runId'] = 'raw-run-id'
          ..['notes'] =
              'Use EVAL_USE_CASE_DECISION_MATRIX_INPUT from /private/path/matrix.json'
          ..['linuxNotes'] = 'read /home/runner/work/decision.json';
    expect(decision, isNotEmpty);
    (tampered['recommendedCommands'] as List<dynamic>).add(
      const <String, dynamic>{
        'mode': 'run',
        'command': "bash -lc 'eval/run_level2.sh run'",
        'env': {'EVAL_SCENARIO_IDS': 'private-case'},
      },
    );
    final reviewGate = tampered['reviewGate'] as Map<String, dynamic>
      ..['profileNames'] = const ['private-profile'];
    expect(reviewGate, isNotEmpty);

    final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

    expect(issues, contains('ledger.scenarioIds must not expose scenario ids'));
    expect(
      issues,
      contains('ledger.decisions[0].runId must not expose run ids'),
    );
    expect(
      issues,
      contains('ledger.decisions[0].notes must not contain private paths'),
    );
    expect(
      issues,
      contains(
        'ledger.decisions[0].notes must not contain private env value keys',
      ),
    );
    expect(
      issues,
      contains(
        'ledger.decisions[0].linuxNotes must not contain private paths',
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
    expect(
      issues,
      contains(
        'ledger.reviewGate.profileNames must not expose profile selectors',
      ),
    );
  });

  test('contract rejects accepted decisions with forged coverage proof', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final accepted =
        ((tampered['decisions'] as List<dynamic>).single
                as Map<String, dynamic>)['acceptedCandidate']
            as Map<String, dynamic>;
    final proof = accepted['modelClassCoverageProof'] as Map<String, dynamic>
      ..['modelClassCoverageDigest'] = EvalProvenance.digestText('forged');

    final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

    expect(proof['modelClassCoverageDigest'], isA<String>());
    expect(
      issues,
      contains(
        'decisions[0].acceptedCandidate.modelClassCoverageProof.proofRef must bind model-class coverage proof',
      ),
    );
  });

  test('contract rejects restamped non-digest model-class coverage ref', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final accepted =
        ((tampered['decisions'] as List<dynamic>).single
                as Map<String, dynamic>)['acceptedCandidate']
            as Map<String, dynamic>;
    final proof = accepted['modelClassCoverageProof'] as Map<String, dynamic>
      ..['modelClassCoverageRef'] = 'forged-coverage-ref';
    final proofSource = <String, dynamic>{...proof}..remove('proofRef');
    proof['proofRef'] = EvalProvenance.digestJson(proofSource);
    tampered['decisionLedgerRef'] =
        EvalUseCaseTuningDecisionLedger.decisionLedgerRef(tampered);

    final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

    expect(proof['modelClassCoverageRef'], 'forged-coverage-ref');
    expect(
      issues,
      contains(
        'decisions[0].acceptedCandidate.modelClassCoverageProof.modelClassCoverageRef must be a sha256 digest',
      ),
    );
    expect(
      issues,
      isNot(
        contains(
          'decisions[0].acceptedCandidate.modelClassCoverageProof.proofRef must bind model-class coverage proof',
        ),
      ),
    );
    expect(
      issues,
      isNot(
        contains('decisionLedgerRef must match decision ledger subject digest'),
      ),
    );
  });

  test('contract rejects restamped coverage proof for wrong model class', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final accepted =
        ((tampered['decisions'] as List<dynamic>).single
                  as Map<String, dynamic>)['acceptedCandidate']
              as Map<String, dynamic>
          ..['modelClass'] = _fixtureModelClassName('local');
    final proof = accepted['modelClassCoverageProof'] as Map<String, dynamic>;
    tampered['decisionLedgerRef'] =
        EvalUseCaseTuningDecisionLedger.decisionLedgerRef(tampered);

    final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

    expect(proof['modelClass'], _fixtureModelClassName('frontier'));
    expect(accepted['modelClass'], _fixtureModelClassName('local'));
    expect(
      issues,
      contains(
        'decisions[0].acceptedCandidate.modelClassCoverageProof.modelClass must match candidate',
      ),
    );
    expect(
      issues,
      isNot(
        contains('decisionLedgerRef must match decision ledger subject digest'),
      ),
    );
  });

  test('contract rejects tampered accepted decision subject ref', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final accepted =
        ((tampered['decisions'] as List<dynamic>).single
                  as Map<String, dynamic>)['acceptedCandidate']
              as Map<String, dynamic>
          ..['modelClass'] = _fixtureModelClassName('local');

    final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

    expect(accepted['modelClass'], _fixtureModelClassName('local'));
    expect(
      issues,
      contains('decisionLedgerRef must match decision ledger subject digest'),
    );
  });

  test(
    'contract rejects restamped accepted candidate without source check',
    () {
      final followUp = _report(
        runId: 'follow-up-promote',
        modelClass: 'frontier',
        ready: true,
        promotionStatus: 'promote',
      );
      final campaign = _campaignFor(
        baseReports: [
          _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
        ],
        followUpReports: [followUp],
      );
      final ledger = EvalUseCaseTuningDecisionLedger.build(
        matrix: _matrixFor([followUp]),
        campaign: campaign,
        reviewAttestations: _reviewAttestations(campaign),
        generatedAt: DateTime.utc(2026, 6, 12, 13),
      );
      final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
      final accepted =
          ((tampered['decisions'] as List<dynamic>).single
                    as Map<String, dynamic>)['acceptedCandidate']
                as Map<String, dynamic>
            ..['sourceChecked'] = false;
      tampered['decisionLedgerRef'] =
          EvalUseCaseTuningDecisionLedger.decisionLedgerRef(tampered);

      final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

      expect(accepted['sourceChecked'], isFalse);
      expect(
        issues,
        contains('decisions[0].acceptedCandidate.sourceChecked must be true'),
      );
      expect(
        issues,
        isNot(
          contains(
            'decisionLedgerRef must match decision ledger subject digest',
          ),
        ),
      );
    },
  );

  test(
    'contract rejects restamped accepted candidate outside candidates list',
    () {
      final followUp = _report(
        runId: 'follow-up-promote',
        modelClass: 'frontier',
        ready: true,
        promotionStatus: 'promote',
      );
      final campaign = _campaignFor(
        baseReports: [
          _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
        ],
        followUpReports: [followUp],
      );
      final ledger = EvalUseCaseTuningDecisionLedger.build(
        matrix: _matrixFor([followUp]),
        campaign: campaign,
        reviewAttestations: _reviewAttestations(campaign),
        generatedAt: DateTime.utc(2026, 6, 12, 13),
      );
      final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
      final decision =
          (tampered['decisions'] as List<dynamic>).single
              as Map<String, dynamic>;
      final accepted = decision['acceptedCandidate'] as Map<String, dynamic>
        ..['cellKey'] = EvalProvenance.digestText('restamped-other-cell');
      decision['acceptedCellKey'] = accepted['cellKey'];
      tampered['decisionLedgerRef'] =
          EvalUseCaseTuningDecisionLedger.decisionLedgerRef(tampered);

      final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

      expect(
        issues,
        contains(
          'decisions[0].acceptedCandidate must match one candidates entry',
        ),
      );
      expect(
        issues,
        isNot(
          contains(
            'decisionLedgerRef must match decision ledger subject digest',
          ),
        ),
      );
    },
  );

  test('contract rejects private coverage evidence inside proof', () {
    final followUp = _report(
      runId: 'follow-up-promote',
      modelClass: 'frontier',
      ready: true,
      promotionStatus: 'promote',
    );
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [followUp],
    );
    final ledger = EvalUseCaseTuningDecisionLedger.build(
      matrix: _matrixFor([followUp]),
      campaign: campaign,
      reviewAttestations: _reviewAttestations(campaign),
      generatedAt: DateTime.utc(2026, 6, 12, 13),
    );
    final tampered = jsonDecode(jsonEncode(ledger)) as Map<String, dynamic>;
    final accepted =
        ((tampered['decisions'] as List<dynamic>).single
                as Map<String, dynamic>)['acceptedCandidate']
            as Map<String, dynamic>;
    final proof = accepted['modelClassCoverageProof'] as Map<String, dynamic>
      ..['coverageCells'] = const [
        {'sourceRunRef': 'private-run-ref'},
      ];

    final issues = EvalUseCaseTuningDecisionLedger.validate(tampered);

    expect(proof['coverageCells'], isA<List<dynamic>>());
    expect(
      issues,
      contains(
        'decisions[0].acceptedCandidate.modelClassCoverageProof.coverageCells must not be present',
      ),
    );
  });

  test('review attestation import requires bundle artifacts', () {
    final campaign = _campaignFor(
      baseReports: [
        _report(runId: 'base-ready', modelClass: 'frontier', ready: true),
      ],
      followUpReports: [
        _report(
          runId: 'follow-up-promote',
          modelClass: 'frontier',
          ready: true,
          promotionStatus: 'promote',
        ),
      ],
    );

    expect(
      () => _reviewAttestationJson(jsonEncode(_reviewAttestations(campaign))),
      throwsStateError,
    );
  });

  test(
    'writes use-case tuning decision ledger',
    () async {
      final matrix = _readJsonMap(_decisionMatrixInputPath);
      final matrixReports = _readJsonMaps(_decisionMatrixReportInputPaths);
      final matrixSourceChecks = await evalSourceChecksForReports(
        matrixReports,
        config: _sourceReplayConfig(),
      );
      EvalUseCaseTuningMatrix.assertMatchesSources(
        matrix,
        reports: matrixReports,
        sourceChecksByReportDigest: matrixSourceChecks,
      );
      final campaign = _decisionCampaignInputPath.isEmpty
          ? null
          : _readJsonMap(_decisionCampaignInputPath);
      if (campaign != null) {
        final campaignPlan = _readJsonMap(_decisionCampaignPlanInputPath);
        final campaignReports = _readJsonMaps(
          _decisionCampaignReportInputPaths,
        );
        final campaignSourceChecks = await evalSourceChecksForReports(
          campaignReports,
          config: _sourceReplayConfig(),
        );
        final campaignHasModelClassCoverage = _mapList(
          campaign['inputModelClassExecutionCoverages'],
        ).isNotEmpty;
        if (campaignHasModelClassCoverage &&
            _decisionCampaignModelClassCoverageInputPaths.isEmpty) {
          throw StateError(
            'Campaign source replay requires '
            'EVAL_USE_CASE_DECISION_MODEL_CLASS_COVERAGE for campaigns that '
            'contain model-class execution coverage.',
          );
        }
        final coverages = _readJsonMaps(
          _decisionCampaignModelClassCoverageInputPaths,
        );
        Map<String, dynamic>? coverageWorkOrder;
        if (coverages.isNotEmpty) {
          if (_decisionCampaignModelClassCoverageWorkOrderInputPath.isEmpty ||
              _decisionCampaignModelClassExecutionExperimentPlanInputPath
                  .isEmpty ||
              _decisionCampaignModelClassExecutionEvidenceInputPaths.isEmpty ||
              _decisionCampaignModelClassExecutionRunIds.isEmpty) {
            throw StateError(
              'Campaign source replay with model-class coverage requires '
              'EVAL_USE_CASE_DECISION_MODEL_CLASS_COVERAGE_WORK_ORDER, '
              'EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN, '
              'EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_EVIDENCE, and '
              'EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_RUNS.',
            );
          }
          coverageWorkOrder = _readJsonMap(
            _decisionCampaignModelClassCoverageWorkOrderInputPath,
          );
          final coverageExperimentPlan = _readJsonMap(
            _decisionCampaignModelClassExecutionExperimentPlanInputPath,
          );
          final evidenceBundles = _readJsonMaps(
            _decisionCampaignModelClassExecutionEvidenceInputPaths,
          );
          if (evidenceBundles.length != 1) {
            throw StateError(
              'Decision campaign source replay requires exactly one '
              'model-class execution-evidence bundle.',
            );
          }
          final runs = await evalLoadModelClassExecutionRuns(
            config: _sourceReplayConfig(),
            runIds: _csv(_decisionCampaignModelClassExecutionRunIds),
          );
          for (final coverage in coverages) {
            EvalUseCaseModelClassExecutionCoverage.assertMatchesSources(
              coverage,
              workOrder: coverageWorkOrder!,
              sourceExecutionEvidenceBundles: evidenceBundles,
              runs: runs,
              sourceExperimentPlan: coverageExperimentPlan,
            );
          }
        }
        EvalUseCaseTuningCampaign.assertMatchesSources(
          campaign,
          experimentPlan: campaignPlan,
          reports: campaignReports,
          sourceChecksByReportDigest: campaignSourceChecks,
          modelClassExecutionCoverages: coverages,
          modelClassExecutionWorkOrders: [
            ?coverageWorkOrder,
          ],
        );
      }
      final previousLedger = _decisionPreviousLedgerPath.isEmpty
          ? null
          : _readJsonMap(_decisionPreviousLedgerPath);
      final reviewAttestations = _readReviewAttestations(
        _decisionReviewAttestationPaths,
      );
      final ledger = EvalUseCaseTuningDecisionLedger.build(
        matrix: matrix,
        campaign: campaign,
        previousLedger: previousLedger,
        reviewAttestations: reviewAttestations,
        requireMatrixSourceReplay: true,
        requireCampaignSourceReplay: campaign != null,
      );
      EvalUseCaseTuningDecisionLedger.assertValid(ledger);
      EvalUseCaseTuningDecisionLedger.assertMatchesSources(
        ledger,
        matrix: matrix,
        campaign: campaign,
        previousLedger: previousLedger,
        reviewAttestations: reviewAttestations,
      );
      writeEvalJsonArtifact(
        ledger,
        path: _decisionOutputPath,
        overwrite: _decisionOverwrite == '1',
        description: 'use-case tuning decision ledger',
      );
    },
    skip:
        _decisionMatrixInputPath.isEmpty ||
            _decisionMatrixReportInputPaths.isEmpty ||
            _decisionOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_DECISION_MATRIX_INPUT=<json>, '
              'EVAL_USE_CASE_DECISION_MATRIX_REPORTS=<a.json,b.json>, and '
              'EVAL_USE_CASE_DECISION_LEDGER=<json> to write a ledger.'
        : false,
  );
}

Map<String, dynamic> _matrixFor(
  List<Map<String, dynamic>> reports, {
  bool sourceChecked = true,
}) => _withInputReportSourceChecks(
  EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: reports,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
  ),
  sourceChecked: sourceChecked,
);

Map<String, dynamic> _withInputReportSourceChecks(
  Map<String, dynamic> artifact, {
  required bool sourceChecked,
}) {
  final copy = jsonDecode(jsonEncode(artifact)) as Map<String, dynamic>;
  final inputReports = (copy['inputReports'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final report in inputReports) {
    report['sourceCheckStatus'] = sourceChecked
        ? 'sourceChecked'
        : 'notRequired';
    report['sourceIssueCount'] = 0;
    report['sourceIssueCodes'] = const <String>[];
  }
  if (copy['kind'] == EvalUseCaseTuningCampaign.kind) {
    copy['campaignRef'] = EvalUseCaseTuningCampaign.campaignRef(copy);
  }
  return copy;
}

Map<String, dynamic> _campaignFor({
  required List<Map<String, dynamic>> baseReports,
  required List<Map<String, dynamic>> followUpReports,
  bool includeModelClassCoverage = true,
  bool sourceChecked = true,
}) {
  final matrix = EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: baseReports,
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
  final plan = EvalUseCaseExperimentPlan.build(
    matrix: matrix,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
  );
  final workOrder = EvalUseCaseNextRunWorkOrder.build(
    experimentPlan: plan,
    generatedAt: DateTime.utc(2026, 6, 12, 11, 30),
  );
  return _withInputReportSourceChecks(
    EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: followUpReports,
      modelClassExecutionCoverages: includeModelClassCoverage
          ? [
              _modelClassCoverageForWorkOrder(
                workOrder,
                sourceExperimentPlan: plan,
              ),
            ]
          : const [],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    ),
    sourceChecked: sourceChecked,
  );
}

Map<String, dynamic> _modelClassCoverageForWorkOrder(
  Map<String, dynamic> workOrder, {
  required Map<String, dynamic> sourceExperimentPlan,
}) {
  final runs = [
    for (final batch in _mapList(workOrder['runBatches']))
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
  final capabilityIds = _batchCapabilityIds(batch);
  final scenario = EvalScenario(
    id: 'private-decision-scenario',
    title: 'Private decision scenario',
    agentKind: _agentKindForCapability(capabilityIds.first),
    appState: MockedAppState(now: DateTime(2026, 6, 12, 11)),
    userInput: const UserInput(
      transcript: 'Arrange the decision task list',
      triggerTokens: {'trigger:task'},
    ),
    metadata: EvalScenarioMetadata(capabilityIds: capabilityIds.toList()),
  );
  final profiles = [
    for (final modelClass in EvalModelClass.values)
      _profile(modelClass, trialCount: 1),
  ];
  final readinessContractEvidence =
      EvalProvenance.tuningReadinessContractEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest([scenario]),
        requiredPrimaryCapabilityIds: capabilityIds,
      );
  final manifest = EvalProvenance.captureRunManifest(
    runId:
        'private-decision-model-class-${_string(batch['workOrderBatchRef'])}',
    targetName: 'decision fixture target',
    targetKind: 'fixture',
    scenarios: [scenario],
    profiles: profiles,
    createdAt: DateTime.utc(2026, 6, 12, 11, 35),
    command: 'eval/run_level2.sh run private-decision-model-class',
    environment: const {},
    tuningReadinessContractEvidence: readinessContractEvidence,
    useCaseWorkOrderLaunchEvidence:
        EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
          workOrder: workOrder,
          requiredPrimaryCapabilityIds: capabilityIds,
          promptVariantNames: _batchPromptVariantNames(batch),
          workOrderBatchRefs: [_string(batch['workOrderBatchRef'])],
        ),
  );
  final traces = [
    for (final profile in profiles)
      _trace(manifest: manifest, scenario: scenario, profile: profile),
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

EvalProfile _profile(EvalModelClass modelClass, {required int trialCount}) {
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

EvalTrace _trace({
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

Set<String> _batchCapabilityIds(Map<String, dynamic> batch) {
  final values = _csv(
    _string(_map(batch['publicEnv'])['EVAL_REQUIRED_CAPABILITIES']),
  ).toSet();
  return values.isEmpty ? {'task.workflow'} : values;
}

List<String> _batchPromptVariantNames(Map<String, dynamic> batch) {
  final values = _csv(
    _string(_map(batch['publicEnv'])['EVAL_PROMPT_VARIANT_NAMES']),
  );
  return values.isEmpty ? ['default'] : values;
}

AgentKind _agentKindForCapability(String capabilityId) {
  return capabilityId.startsWith('planner.')
      ? AgentKind.planningAgent
      : AgentKind.taskAgent;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

Map<String, dynamic> _readJsonMap(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _readJsonMaps(String paths) => [
  for (final path in _csv(paths)) _readJsonMap(path),
];

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String _string(Object? value) => value is String ? value : '';

List<String> _csv(String value) => [
  for (final part in value.split(',').map((part) => part.trim()))
    if (part.isNotEmpty) part,
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

String _campaignCoverageSnapshotRef(Map<String, dynamic> coverage) =>
    EvalProvenance.digestJson(<String, dynamic>{
      'coverageDigest': coverage['coverageDigest'],
      'status': coverage['status'],
      'sourceExperimentPlanDigest': coverage['sourceExperimentPlanDigest'],
      'sourceMatrixDigest': coverage['sourceMatrixDigest'],
      'sourceWorkOrderDigest': coverage['sourceWorkOrderDigest'],
      'coveredWorkOrderBatchRefs': coverage['coveredWorkOrderBatchRefs'],
      'modelClassCoverageRefs': coverage['modelClassCoverageRefs'],
    });

String _fixtureModelClassName(String modelClass) => switch (modelClass) {
  'frontier' => EvalModelClass.frontierFast.name,
  'local' => EvalModelClass.localReasoning.name,
  _ => modelClass,
};

List<Map<String, dynamic>> _reviewAttestations(Map<String, dynamic> campaign) {
  final packet = EvalUseCaseAdversarialReview.buildPacket(
    campaign: campaign,
    generatedAt: DateTime.utc(2026, 6, 12, 12, 30),
  );
  final templates = (packet['attestationTemplates'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final approved = [
    for (final template in templates)
      _stampedReviewAttestation(<String, dynamic>{
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

Map<String, dynamic> _stampedReviewAttestation(
  Map<String, dynamic> attestation,
) {
  attestation['evidenceDigest'] =
      EvalUseCaseAdversarialReview.attestationEvidenceDigest(attestation);
  return attestation;
}

Map<String, dynamic> _report({
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
  final manifestDigest = _digest('manifest-$runId');
  return <String, dynamic>{
    'schemaVersion': EvalTuningReportContract.schemaVersion,
    'kind': EvalTuningReportContract.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 9).toIso8601String(),
    'run': <String, dynamic>{
      'runId': runId,
      'targetKind': 'fixture',
      'manifestDigest': manifestDigest,
      'createdAt': DateTime.utc(2026, 6, 12, 8).toIso8601String(),
      'scenarioSetDigest': _digest(scenarioSetSeed),
      'profileSetDigest': _digest('profiles-$effectiveModelClass'),
      'profileBindingSetDigest': _digest('bindings-$effectiveModelClass'),
      'agentDirectiveVariantSetDigest': _digest(
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
        'ownedArtifactRefsDigest': _digest('owned-$runId'),
        'loadedTraceContentDigest': _digest('loaded-$runId'),
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
    'coverage': <String, dynamic>{
      'scenarioCount': 1,
      'profileCount': 1,
      'promptVariantCount': 1,
      'expectedTraceCount': 4,
      'traceCount': 4,
      'judgedTraceCount': 4,
      'missingRequiredPrimaryCapabilityIds': const <String>[],
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
        'agentKind': 'taskAgent',
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

List<Map<String, dynamic>> _readReviewAttestations(String paths) {
  return [
    for (final path in paths.split(','))
      if (path.trim().isNotEmpty)
        ..._reviewAttestationJson(File(path.trim()).readAsStringSync()),
  ];
}

List<Map<String, dynamic>> _reviewAttestationJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw StateError(
      'Expected a use-case adversarial review attestation bundle.',
    );
  }
  final object = decoded;
  if (object['kind'] == EvalUseCaseAdversarialReview.bundleKind) {
    return EvalUseCaseAdversarialReview.approvedAttestationsFromValidBundles([
      object,
    ]);
  }
  throw StateError(
    'Expected a use-case adversarial review attestation bundle.',
  );
}

Map<String, dynamic> _singleMap(Map<String, dynamic> root, String key) {
  final list = root[key] as List<dynamic>;
  expect(list, hasLength(1));
  return list.single as Map<String, dynamic>;
}

String _digest(String value) => EvalProvenance.digestText(value);
