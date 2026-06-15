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
const _campaignPlanInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_EXPERIMENT_PLAN_INPUT',
);
const _campaignReportInputPaths = String.fromEnvironment('EVAL_TUNING_REPORTS');
const _campaignModelClassCoverageInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_COVERAGE',
);
const _campaignModelClassCoverageWorkOrderInputPath = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER',
);
const _campaignModelClassExecutionExperimentPlanInputPath =
    String.fromEnvironment(
      'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN',
    );
const _campaignModelClassExecutionEvidenceInputPaths = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE',
);
const _campaignModelClassExecutionRunIds = String.fromEnvironment(
  'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS',
);
const _campaignOutputPath = String.fromEnvironment(
  'EVAL_USE_CASE_CAMPAIGN_REPORT',
);
const _campaignOverwrite = String.fromEnvironment(
  'EVAL_USE_CASE_CAMPAIGN_OVERWRITE',
);

void main() {
  test('tracks ready and blocked follow-up evidence by planned batch', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
        _report(
          runId: 'base-plan',
          ready: true,
          primaryCapabilityId: 'planner.workflow',
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);

    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
        _report(
          runId: 'follow-plan',
          primaryCapabilityId: 'planner.workflow',
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
          blockingReasonCodes: const ['calibration.missingHumanLabels'],
        ),
      ],
      modelClassExecutionCoverages: [
        _modelClassCoverageForWorkOrder(
          workOrder,
          sourceExperimentPlan: plan,
        ),
      ],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
    expect(EvalProvenance.isDigest(campaign['campaignRef'] as String), isTrue);
    expect(
      campaign['campaignRef'],
      EvalUseCaseTuningCampaign.campaignRef(campaign),
    );
    expect(campaign['status'], 'readyForMatrixRefresh');
    final summary = campaign['summary'] as Map<String, dynamic>;
    expect(summary['plannedBatchCount'], 2);
    expect(summary['matchedBatchCount'], 2);
    expect(summary['readyEvidenceBatchCount'], 1);
    final progress = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      progress.map((batch) => batch['status']),
      containsAll(['readyEvidenceCollected', 'blockedFollowUpEvidence']),
    );
    final readyBatch = progress.singleWhere(
      (batch) => batch['status'] == 'readyEvidenceCollected',
    );
    expect(
      (readyBatch['coverage'] as Map<String, dynamic>)['readyEvidenceExists'],
      isTrue,
    );
    expect(
      (readyBatch['coverage']
          as Map<String, dynamic>)['modelClassExecutionCoverageComplete'],
      isTrue,
    );
    final queue = campaign['adversarialReviewQueue'] as Map<String, dynamic>;
    final categories = (queue['tasks'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((task) => task['category']);
    expect(categories, contains('modelClassCoverageAudit'));
    expect(readyBatch['remainingBlockerCodes'], isEmpty);
    final blockedBatch = progress.singleWhere(
      (batch) => batch['status'] == 'blockedFollowUpEvidence',
    );
    expect(
      blockedBatch['remainingBlockerCodes'],
      contains('calibration.missingHumanLabels'),
    );
    expect(
      const JsonEncoder().convert(campaign),
      allOf(
        isNot(contains('follow-task')),
        isNot(contains('follow-plan')),
        isNot(contains('base-task')),
        isNot(contains('base-plan')),
      ),
    );
  });

  test('source replay marks campaign and rejects restamped artifacts', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final followUp = _report(
      runId: 'follow-task',
      ready: true,
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

    expect(
      EvalUseCaseTuningCampaign.hasVerifiedSourceReplay(campaign),
      isFalse,
    );

    EvalUseCaseTuningCampaign.assertMatchesSources(
      campaign,
      experimentPlan: plan,
      reports: [followUp],
      requireSourceChecks: false,
      modelClassExecutionCoverages: [coverage],
      modelClassExecutionWorkOrders: [workOrder],
    );

    expect(EvalUseCaseTuningCampaign.hasVerifiedSourceReplay(campaign), isTrue);
    final serialized = jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;
    expect(
      EvalUseCaseTuningCampaign.hasVerifiedSourceReplay(serialized),
      isFalse,
    );

    final restamped = jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;
    (restamped['sourceExperimentPlan'] as Map<String, dynamic>)['planDigest'] =
        EvalProvenance.digestText('other-plan');
    restamped['campaignRef'] = EvalUseCaseTuningCampaign.campaignRef(
      restamped,
    );

    expect(
      () => EvalUseCaseTuningCampaign.assertMatchesSources(
        restamped,
        experimentPlan: plan,
        reports: [followUp],
        requireSourceChecks: false,
        modelClassExecutionCoverages: [coverage],
        modelClassExecutionWorkOrders: [workOrder],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('sourceExperimentPlan must match campaign source artifacts'),
        ),
      ),
    );
  });

  test('contract rejects stale campaign subject refs', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
        ),
      ],
      modelClassExecutionCoverages: [
        _modelClassCoverageForWorkOrder(
          workOrder,
          sourceExperimentPlan: plan,
        ),
      ],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;
    final batch =
        (tampered['batchProgress'] as List<dynamic>).single
              as Map<String, dynamic>
          ..['nextAction'] = 'runFollowUpBatch';

    final issues = EvalUseCaseTuningCampaign.validate(tampered);

    expect(batch['nextAction'], 'runFollowUpBatch');
    expect(
      issues,
      contains('campaignRef must match campaign subject digest'),
    );
  });

  test('contract rejects recomputed campaigns with missing review tasks', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
        ),
      ],
      modelClassExecutionCoverages: [
        _modelClassCoverageForWorkOrder(
          workOrder,
          sourceExperimentPlan: plan,
        ),
      ],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;
    final queue = tampered['adversarialReviewQueue'] as Map<String, dynamic>;
    final tasks = (queue['tasks'] as List<dynamic>).cast<Map<String, dynamic>>()
      ..removeWhere((task) => task['category'] == 'modelClassCoverageAudit');
    final taskCount = tasks.length;
    queue['summary'] = <String, dynamic>{
      'taskCount': taskCount,
      'pendingTaskCount': taskCount,
      'completedTaskCount': 0,
    };
    tampered['campaignRef'] = EvalUseCaseTuningCampaign.campaignRef(tampered);

    final issues = EvalUseCaseTuningCampaign.validate(tampered);

    expect(
      issues,
      contains(
        'adversarialReviewQueue.tasks categories must match campaign blockers and coverage requirements',
      ),
    );
  });

  test('ready reports do not close a batch without model-class coverage', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
    expect(campaign['status'], 'inProgress');
    final batch = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .single;
    expect(batch['status'], 'blockedFollowUpEvidence');
    final coverage = batch['coverage'] as Map<String, dynamic>;
    expect(coverage['readyEvidenceExists'], isFalse);
    expect(coverage['modelClassExecutionCoverageComplete'], isFalse);
    expect(coverage['matchedModelClassCoverageRefs'], isEmpty);
    expect(
      batch['remainingBlockerCodes'],
      contains('campaign.modelClassExecutionCoverageMissing'),
    );
  });

  test(
    'partial model-class coverage blocks otherwise ready follow-up evidence',
    () {
      final plan = _experimentPlan(
        reports: [
          _report(
            runId: 'base-task',
            ready: true,
          ),
        ],
      );
      final workOrder = _workOrderForPlan(plan);

      final campaign = EvalUseCaseTuningCampaign.build(
        requireSourceChecks: false,
        experimentPlan: plan,
        reports: [
          _report(
            runId: 'follow-task',
            ready: true,
          ),
        ],
        modelClassExecutionCoverages: [
          _modelClassCoverageForWorkOrder(
            workOrder,
            sourceExperimentPlan: plan,
            coveredModelClasses: const [
              EvalModelClass.localSmall,
              EvalModelClass.localReasoning,
              EvalModelClass.frontierFast,
            ],
          ),
        ],
        modelClassExecutionWorkOrders: [workOrder],
        generatedAt: DateTime.utc(2026, 6, 12, 12),
      );

      expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
      expect(campaign['status'], 'inProgress');
      final batch = (campaign['batchProgress'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .single;
      final coverage = batch['coverage'] as Map<String, dynamic>;
      final coverageRef =
          (coverage['matchedModelClassCoverageRefs'] as List<dynamic>).single
              as String;
      expect(EvalProvenance.isDigest(coverageRef), isTrue);
      expect(coverage['modelClassExecutionCoverageComplete'], isFalse);
      expect(
        batch['remainingBlockerCodes'],
        contains('campaign.modelClassExecutionCoverageIncomplete'),
      );
    },
  );

  test(
    'source-aware campaign rejects coverage from an unrelated work order',
    () {
      final plan = _experimentPlan(
        reports: [
          _report(
            runId: 'base-task',
            ready: true,
          ),
        ],
      );
      final workOrder = _workOrderForPlan(plan);
      final unrelatedWorkOrder = _workOrderForPlan(
        _experimentPlan(
          reports: [
            _report(
              runId: 'unrelated-task',
              ready: true,
              primaryCapabilityId: 'planner.workflow',
              requiredCapabilities: const ['planner.workflow'],
            ),
          ],
        ),
      );
      final campaign = EvalUseCaseTuningCampaign.build(
        requireSourceChecks: false,
        experimentPlan: plan,
        reports: [
          _report(
            runId: 'follow-task',
            ready: true,
          ),
        ],
        modelClassExecutionCoverages: [
          _modelClassCoverageForWorkOrder(
            workOrder,
            sourceExperimentPlan: plan,
          ),
        ],
        modelClassExecutionWorkOrders: [unrelatedWorkOrder],
        generatedAt: DateTime.utc(2026, 6, 12, 12),
      );

      expect(campaign['status'], 'invalid');
      expect(
        campaign['blockedReasonCodes'] as List<dynamic>,
        contains('modelClassCoverage.contractInvalid'),
      );
      final inputCoverage =
          (campaign['inputModelClassExecutionCoverages'] as List<dynamic>)
                  .single
              as Map<String, dynamic>;
      expect(inputCoverage['contractIssueCount'], 1);
    },
  );

  test('campaign rejects artifact-only model-class coverage replay', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final artifactOnlyCoverage =
        jsonDecode(
              jsonEncode(
                _modelClassCoverageForWorkOrder(
                  workOrder,
                  sourceExperimentPlan: plan,
                ),
              ),
            )
            as Map<String, dynamic>;

    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
        ),
      ],
      modelClassExecutionCoverages: [artifactOnlyCoverage],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
    expect(campaign['status'], 'invalid');
    expect(
      campaign['blockedReasonCodes'] as List<dynamic>,
      contains('modelClassCoverage.contractInvalid'),
    );
    final inputCoverage =
        (campaign['inputModelClassExecutionCoverages'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(inputCoverage['contractStatus'], 'invalid');
    expect(inputCoverage['contractIssueCount'], 1);
    final batch =
        (campaign['batchProgress'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(batch['status'], 'blockedFollowUpEvidence');
    expect(
      (batch['coverage'] as Map<String, dynamic>)['readyEvidenceExists'],
      isFalse,
    );
  });

  test('coverage without source work order cannot close a campaign batch', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
        ),
      ],
      modelClassExecutionCoverages: [
        _modelClassCoverageForWorkOrder(
          workOrder,
          sourceExperimentPlan: plan,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(campaign['status'], 'invalid');
    expect(
      campaign['blockedReasonCodes'] as List<dynamic>,
      contains('modelClassCoverage.contractInvalid'),
    );
    final inputCoverage =
        (campaign['inputModelClassExecutionCoverages'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(inputCoverage['contractStatus'], 'invalid');
    expect(inputCoverage['contractIssueCount'], 1);
  });

  test('contract rejects tampered model-class coverage snapshot refs', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
        ),
      ],
      modelClassExecutionCoverages: [
        _modelClassCoverageForWorkOrder(
          workOrder,
          sourceExperimentPlan: plan,
        ),
      ],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;
    final coverage =
        (tampered['inputModelClassExecutionCoverages'] as List<dynamic>).single
              as Map<String, dynamic>
          ..['sourceWorkOrderDigest'] = EvalProvenance.digestText(
            'forged-work-order',
          );

    final issues = EvalUseCaseTuningCampaign.validate(tampered);

    expect(coverage['sourceWorkOrderDigest'], isA<String>());
    expect(
      issues,
      contains(
        'inputModelClassExecutionCoverages[0].coverageRef must bind coverage source summary',
      ),
    );
  });

  test('contract rejects ready evidence forged without coverage proof', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>;
    final batch =
        (tampered['batchProgress'] as List<dynamic>).single
              as Map<String, dynamic>
          ..['status'] = 'readyEvidenceCollected'
          ..['remainingBlockerCodes'] = const <String>[];
    final coverage = batch['coverage'] as Map<String, dynamic>
      ..['readyEvidenceExists'] = true;

    final issues = EvalUseCaseTuningCampaign.validate(tampered);

    expect(coverage['modelClassExecutionCoverageComplete'], isFalse);
    expect(
      issues,
      contains(
        'batchProgress[0].coverage.readyEvidenceExists requires model-class execution coverage',
      ),
    );
  });

  test('rejects selector-only matches with incompatible fixed evidence', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'wrong-scenario-set',
          ready: true,
          scenarioSetSeed: 'different-scenario-set',
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    final progress = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final batch = progress.single;
    expect(batch['status'], 'partialFollowUpCoverage');
    expect(batch['matchedReportRefs'], isEmpty);
    expect(batch['compatibilityMismatchedReportRefs'], ['report-1']);
    expect(
      batch['remainingBlockerCodes'],
      containsAll([
        'campaign.noMatchingReport',
        'campaign.partialCoverage',
        'campaign.compatibilityMismatch',
      ]),
    );
    expect(
      (batch['coverage'] as Map<String, dynamic>)['readyEvidenceExists'],
      isFalse,
    );
  });

  test('keeps partial multi-selector coverage from closing a batch', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
        _report(
          runId: 'base-plan',
          ready: true,
          primaryCapabilityId: 'planner.workflow',
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
      ],
      maxCellsPerBatch: 2,
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-task',
          ready: true,
          requiredCapabilities: const [
            'planner.workflow',
            'task.workflow',
          ],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    final batch = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .single;
    expect(batch['status'], 'blockedFollowUpEvidence');
    expect(
      (batch['coverage'] as Map<String, dynamic>)['plannedCoverageComplete'],
      isFalse,
    );
    expect(
      batch['remainingBlockerCodes'],
      contains('campaign.partialCoverage'),
    );
  });

  test('invalid reports are listed but ignored for readiness', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final invalid = _report(
      runId: 'invalid-report',
      ready: true,
    )..['schemaVersion'] = 2;

    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [invalid],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(campaign['status'], 'invalid');
    final inputReports = (campaign['inputReports'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(inputReports.single['contractStatus'], 'invalid');
    expect(inputReports.single['ready'], isTrue);
    final batch = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .single;
    expect(batch['matchedReportRefs'], isEmpty);
    expect(
      batch['remainingBlockerCodes'],
      contains('campaign.noMatchingReport'),
    );
    expect(campaign['blockedReasonCodes'], contains('report.contractInvalid'));
  });

  test('source-check-required campaign ignores missing source evidence', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final report = _report(
      runId: 'restamped-follow-up',
      ready: true,
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      experimentPlan: plan,
      reports: [report],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
    expect(campaign['status'], 'invalid');
    final inputReports = (campaign['inputReports'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(inputReports.single['contractStatus'], 'invalid');
    expect(inputReports.single['sourceCheckStatus'], 'sourceMissing');
    expect(inputReports.single['sourceIssueCodes'], [
      'report.sourceCheckMissing',
    ]);
    final batch = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .single;
    expect(batch['matchedReportRefs'], isEmpty);
    expect(
      (batch['coverage'] as Map<String, dynamic>)['readyEvidenceExists'],
      isFalse,
    );
  });

  test('source-check-required campaign ignores invalid source evidence', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final report = _report(
      runId: 'restamped-follow-up',
      ready: true,
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      experimentPlan: plan,
      reports: [report],
      sourceChecksByReportDigest: {
        EvalProvenance.digestJson(report): _invalidSourceCheck(
          report,
          'report.sourceStatusMismatch',
        ),
      },
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
    expect(campaign['status'], 'invalid');
    final inputReports = (campaign['inputReports'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(inputReports.single['contractStatus'], 'invalid');
    expect(inputReports.single['sourceCheckStatus'], 'sourceInvalid');
    expect(inputReports.single['sourceIssueCodes'], [
      'report.sourceStatusMismatch',
    ]);
    final batch = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .single;
    expect(batch['matchedReportRefs'], isEmpty);
    expect(
      (batch['coverage'] as Map<String, dynamic>)['readyEvidenceExists'],
      isFalse,
    );
  });

  test('campaign rejects fabricated source-checked evidence', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final report = _report(
      runId: 'follow-up-without-launch',
      ready: true,
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      experimentPlan: plan,
      reports: [report],
      sourceChecksByReportDigest: {
        EvalProvenance.digestJson(report): _sourceCheckedReport(report),
      },
      modelClassExecutionCoverages: [
        _modelClassCoverageForWorkOrder(
          workOrder,
          sourceExperimentPlan: plan,
        ),
      ],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
    expect(campaign['status'], 'invalid');
    final inputReport =
        (campaign['inputReports'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(inputReport['contractStatus'], 'invalid');
    expect(inputReport['sourceCheckStatus'], 'sourceChecked');
    expect(inputReport['sourceIssueCodes'], [
      'report.sourceCheckUnvalidated',
    ]);
    final batch =
        (campaign['batchProgress'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(batch['status'], 'awaitingFollowUpReport');
    expect(batch['matchedReportRefs'], isEmpty);
    expect(batch['compatibilityMismatchedReportRefs'], isEmpty);
    expect(
      (batch['coverage'] as Map<String, dynamic>)['readyEvidenceExists'],
      isFalse,
    );
  });

  test('fabricated launch summaries cannot close a campaign batch', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final workOrder = _workOrderForPlan(plan);
    final report = _report(
      runId: 'follow-up-wrong-batch',
      ready: true,
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      experimentPlan: plan,
      reports: [report],
      sourceChecksByReportDigest: {
        EvalProvenance.digestJson(report): _sourceCheckedReport(
          report,
          workOrderLaunch: _workOrderLaunchSummary(
            workOrder: workOrder,
            workOrderBatchRefs: [
              EvalProvenance.digestText('other-work-order-batch'),
            ],
          ),
        ),
      },
      modelClassExecutionCoverages: [
        _modelClassCoverageForWorkOrder(
          workOrder,
          sourceExperimentPlan: plan,
        ),
      ],
      modelClassExecutionWorkOrders: [workOrder],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
    expect(campaign['status'], 'invalid');
    final inputReport =
        (campaign['inputReports'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(inputReport['sourceIssueCodes'], [
      'report.sourceCheckUnvalidated',
    ]);
    final batch =
        (campaign['batchProgress'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(batch['status'], 'awaitingFollowUpReport');
    expect(batch['matchedReportRefs'], isEmpty);
    expect(batch['compatibilityMismatchedReportRefs'], isEmpty);
    expect(
      (batch['coverage'] as Map<String, dynamic>)['readyEvidenceExists'],
      isFalse,
    );
  });

  test('hashes private selector values embedded in blocker codes', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );

    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: [
        _report(
          runId: 'follow-private',
          blockingReasonCodes: const [
            'needs-scenario-task.workflow-labels',
            'missing-profile-frontier-labels',
            'retry-follow-private-before-promotion',
            'verdict.missing',
          ],
        ),
      ],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );

    final encoded = const JsonEncoder().convert(campaign);
    expect(encoded, isNot(contains('scenario-task.workflow')));
    expect(encoded, isNot(contains('profile-frontier')));
    expect(encoded, isNot(contains('follow-private')));
    final batch = (campaign['batchProgress'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .single;
    final remainingBlockers = (batch['remainingBlockerCodes'] as List<dynamic>)
        .cast<String>();
    expect(remainingBlockers, contains('verdict.missing'));
    expect(
      remainingBlockers.where((code) => code.startsWith('protected-blocker.')),
      hasLength(3),
    );
    expect(EvalUseCaseTuningCampaign.validate(campaign), isEmpty);
  });

  test('contract rejects private payload and live command tampering', () {
    final plan = _experimentPlan(
      reports: [
        _report(
          runId: 'base-task',
          ready: true,
        ),
      ],
    );
    final campaign = EvalUseCaseTuningCampaign.build(
      requireSourceChecks: false,
      experimentPlan: plan,
      reports: const [],
      generatedAt: DateTime.utc(2026, 6, 12, 12),
    );
    final tampered = jsonDecode(jsonEncode(campaign)) as Map<String, dynamic>
      ..['scenarioIds'] = const ['private-case'];
    final batch =
        ((tampered['batchProgress'] as List<dynamic>).single
              as Map<String, dynamic>)
          ..['profileNames'] = const ['private-profile']
          ..['runId'] = 'raw-run-id'
          ..['notes'] =
              'Use EVAL_PROFILE_NAMES from /private/path/profiles.json'
          ..['linuxNotes'] = 'read /home/runner/work/campaign.json';
    expect(batch, isNotEmpty);
    (tampered['recommendedCommands'] as List<dynamic>).add(
      const <String, dynamic>{
        'mode': 'shell',
        'command': "bash -lc 'eval/run_level2.sh run'",
        'env': {'EVAL_SCENARIOS': '/private/path/catalog.json'},
      },
    );
    final queue = tampered['adversarialReviewQueue'] as Map<String, dynamic>
      ..['completionClaimsCreated'] = true;
    final task =
        ((queue['tasks'] as List<dynamic>).first as Map<String, dynamic>)
          ..['status'] = 'complete'
          ..['recommendedCommands'] = const [
            {'mode': 'run', 'command': 'eval/run_level2.sh run <nextRunId>'},
          ]
          ..['reviewedBy'] = 'agent-a';
    expect(task, isNotEmpty);

    final issues = EvalUseCaseTuningCampaign.validate(tampered);

    expect(
      issues,
      contains('campaign.scenarioIds must not expose scenario ids'),
    );
    expect(
      issues,
      contains(
        'campaign.batchProgress[0].profileNames must not expose profile selectors',
      ),
    );
    expect(
      issues,
      contains('campaign.batchProgress[0].runId must not expose run ids'),
    );
    expect(
      issues,
      contains(
        'campaign.batchProgress[0].notes must not contain private paths',
      ),
    );
    expect(
      issues,
      contains(
        'campaign.batchProgress[0].notes must not contain private env value keys',
      ),
    );
    expect(
      issues,
      contains(
        'campaign.batchProgress[0].linuxNotes must not contain private paths',
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
      contains('adversarialReviewQueue.completionClaimsCreated must be false'),
    );
    expect(
      issues,
      contains('adversarialReviewQueue.tasks[0].status must be pending'),
    );
    expect(
      issues,
      contains(
        'adversarialReviewQueue.tasks[0] must not contain recommendedCommands',
      ),
    );
    expect(
      issues,
      contains('adversarialReviewQueue.tasks[0] must not contain reviewedBy'),
    );
  });

  test(
    'writes use-case tuning campaign',
    () async {
      final plan =
          jsonDecode(File(_campaignPlanInputPath).readAsStringSync())
              as Map<String, dynamic>;
      final reports = [
        for (final path in _campaignReportInputPaths.split(','))
          if (path.trim().isNotEmpty)
            jsonDecode(File(path.trim()).readAsStringSync())
                as Map<String, dynamic>,
      ];
      final coverages = [
        for (final path in _campaignModelClassCoverageInputPaths.split(','))
          if (path.trim().isNotEmpty)
            jsonDecode(File(path.trim()).readAsStringSync())
                as Map<String, dynamic>,
      ];
      final coverageWorkOrder =
          _campaignModelClassCoverageWorkOrderInputPath.isEmpty
          ? null
          : jsonDecode(
                  File(
                    _campaignModelClassCoverageWorkOrderInputPath,
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
      if (coverages.isNotEmpty && coverageWorkOrder == null) {
        throw StateError(
          'Model-class coverage campaign import requires '
          'EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER.',
        );
      }
      if (coverages.isNotEmpty &&
          (_campaignModelClassExecutionExperimentPlanInputPath.isEmpty ||
              _campaignModelClassExecutionEvidenceInputPaths.isEmpty ||
              _campaignModelClassExecutionRunIds.isEmpty)) {
        throw StateError(
          'Model-class coverage campaign import requires '
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN, '
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE, and '
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS.',
        );
      }
      if (coverageWorkOrder != null && coverages.isNotEmpty) {
        final coverageExperimentPlan =
            jsonDecode(
                  File(
                    _campaignModelClassExecutionExperimentPlanInputPath,
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final evidenceBundles = [
          for (final path
              in _campaignModelClassExecutionEvidenceInputPaths
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty))
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
        ];
        if (evidenceBundles.length != 1) {
          throw StateError(
            'Model-class coverage campaign import requires exactly one '
            'execution-evidence bundle.',
          );
        }
        final runs = await evalLoadModelClassExecutionRuns(
          config: _sourceReplayConfig(),
          runIds: _csv(_campaignModelClassExecutionRunIds),
        );
        for (final coverage in coverages) {
          EvalUseCaseModelClassExecutionCoverage.assertMatchesSources(
            coverage,
            workOrder: coverageWorkOrder,
            sourceExecutionEvidenceBundles: evidenceBundles,
            runs: runs,
            sourceExperimentPlan: coverageExperimentPlan,
          );
        }
      }
      final sourceChecks = await evalSourceChecksForReports(
        reports,
        config: _sourceReplayConfig(),
      );
      final campaign = EvalUseCaseTuningCampaign.build(
        experimentPlan: plan,
        reports: reports,
        sourceChecksByReportDigest: sourceChecks,
        modelClassExecutionCoverages: coverages,
        modelClassExecutionWorkOrders: [
          ?coverageWorkOrder,
        ],
      );
      EvalUseCaseTuningCampaign.assertValid(campaign);
      writeEvalJsonArtifact(
        campaign,
        path: _campaignOutputPath,
        overwrite: _campaignOverwrite == '1',
        description: 'use-case tuning campaign',
      );
    },
    skip: _campaignPlanInputPath.isEmpty || _campaignOutputPath.isEmpty
        ? 'Set EVAL_USE_CASE_EXPERIMENT_PLAN_INPUT=<json> and '
              'EVAL_USE_CASE_CAMPAIGN_REPORT=<json> to write a campaign.'
        : false,
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

Map<String, dynamic> _experimentPlan({
  required List<Map<String, dynamic>> reports,
  int maxCellsPerBatch = 1,
}) {
  final matrix = EvalUseCaseTuningMatrix.build(
    requireSourceChecks: false,
    reports: reports,
    generatedAt: DateTime.utc(2026, 6, 12, 10),
  );
  return EvalUseCaseExperimentPlan.build(
    matrix: matrix,
    generatedAt: DateTime.utc(2026, 6, 12, 11),
    maxCellsPerBatch: maxCellsPerBatch,
  );
}

Map<String, dynamic> _report({
  required String runId,
  String modelClass = 'frontier',
  bool ready = false,
  String scenarioSetSeed = 'scenario-set',
  String primaryCapabilityId = 'task.workflow',
  String promptVariantName = 'default',
  List<String>? requiredCapabilities,
  List<String> blockingReasonCodes = const ['verdict.missing'],
}) {
  final capabilities = requiredCapabilities ?? [primaryCapabilityId];
  final effectiveBlockers = ready ? const <String>[] : blockingReasonCodes;
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
      'profileSetDigest': _digest('profiles-$modelClass'),
      'profileBindingSetDigest': _digest('bindings-$modelClass'),
      'agentDirectiveVariantSetDigest': _digest(
        'prompt-variants-$promptVariantName',
      ),
      'selectors': <String, dynamic>{
        'scenarioIds': ['scenario-$primaryCapabilityId'],
        'profileNames': ['profile-$modelClass'],
        'promptVariantNames': [promptVariantName],
        'requiredPrimaryCapabilityIds': capabilities,
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
    'promotion': const <String, dynamic>{
      'present': false,
      'status': 'notRequested',
      'evidencePlan': null,
    },
    'useCaseModelSlices': [
      <String, dynamic>{
        'sliceKey':
            '$primaryCapabilityId@taskAgent@$modelClass@$promptVariantName',
        'primaryCapabilityId': primaryCapabilityId,
        'agentKind': 'taskAgent',
        'modelClass': modelClass,
        'promptVariantName': promptVariantName,
        'scenarioIds': ['scenario-$primaryCapabilityId'],
        'profileNames': ['profile-$modelClass'],
        'traceCount': 4,
        'judgedTraceCount': 4,
        'passCount': ready ? 4 : 2,
        'level1PassCount': 4,
        'passRate': ready ? 1 : 0.5,
        'passRateLowerBound': ready ? 0.8 : 0.2,
        'meanGoalAttainment': ready ? 5 : 3,
        'meanQuality': ready ? 5 : 3,
        'meanEfficiency': ready ? 5 : 3,
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
      'requiredCapabilities': capabilities,
      'suggestedCapabilities': capabilities,
      'suggestedScenarioIds': ['scenario-$primaryCapabilityId'],
      'suggestedProfileNames': ['profile-$modelClass'],
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

Map<String, dynamic> _workOrderForPlan(Map<String, dynamic> plan) {
  return EvalUseCaseNextRunWorkOrder.build(
    experimentPlan: plan,
    generatedAt: DateTime.utc(2026, 6, 12, 11, 30),
  );
}

Map<String, dynamic> _modelClassCoverageForWorkOrder(
  Map<String, dynamic> workOrder, {
  required Map<String, dynamic> sourceExperimentPlan,
  List<EvalModelClass> coveredModelClasses = EvalModelClass.values,
}) {
  final runs = [
    for (final batch in _mapList(workOrder['runBatches']))
      _modelClassExecutionRunFixture(
        workOrder: workOrder,
        batch: batch,
        modelClasses: coveredModelClasses,
      ),
  ];
  final evidenceBundle = EvalUseCaseModelClassExecutionEvidence.build(
    workOrder: workOrder,
    runs: runs,
    sourceExperimentPlan: sourceExperimentPlan,
    generatedAt: DateTime.utc(2026, 6, 12, 11, 40),
  );
  if (evidenceBundle['status'] != 'ready') {
    final verificationErrors = [
      for (final run in runs)
        ...EvalRunVerifier.verify(
          runId: run.artifacts.manifest.runId,
          traces: run.artifacts.traces,
          scenarios: run.scenarios,
          profiles: run.profiles,
          agentDirectiveVariants: run.agentDirectiveVariants,
          manifest: run.artifacts.manifest,
          artifactNames: run.artifacts.artifactNames,
          requireVerdicts: run.requireVerdicts,
        ).errors,
    ];
    throw StateError(
      'Invalid model-class coverage fixture evidence: '
      '${const JsonEncoder.withIndent('  ').convert(evidenceBundle['issues'])}\n'
      '${verificationErrors.join('\n')}',
    );
  }
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
  required List<EvalModelClass> modelClasses,
}) {
  final capabilityIds = _batchCapabilityIds(batch);
  final scenario = EvalScenario(
    id: 'private-campaign-scenario',
    title: 'Private campaign scenario',
    agentKind: _agentKindForCapability(capabilityIds.first),
    appState: MockedAppState(now: DateTime(2026, 6, 12, 11)),
    userInput: const UserInput(
      transcript: 'Arrange the campaign task list',
      triggerTokens: {'trigger:task'},
    ),
    metadata: EvalScenarioMetadata(capabilityIds: capabilityIds.toList()),
  );
  final profiles = [
    for (final modelClass in modelClasses) _profile(modelClass, trialCount: 1),
  ];
  final readinessContractEvidence =
      EvalProvenance.tuningReadinessContractEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest([scenario]),
        requiredPrimaryCapabilityIds: capabilityIds,
      );
  final manifest = EvalProvenance.captureRunManifest(
    runId:
        'private-campaign-model-class-${modelClasses.map((value) => value.name).join('-')}',
    targetName: 'campaign fixture target',
    targetKind: 'fixture',
    scenarios: [scenario],
    profiles: profiles,
    createdAt: DateTime.utc(2026, 6, 12, 11, 35),
    command: 'eval/run_level2.sh run private-campaign-model-class',
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

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

String _string(Object? value) => value is String ? value : '';

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ]..sort();
}

EvalTuningReportSourceCheckResult _invalidSourceCheck(
  Map<String, dynamic> report,
  String issueCode,
) {
  return EvalTuningReportSourceCheckResult(
    reportDigest: EvalProvenance.digestJson(report),
    sourceCheckStatus: EvalTuningReportSourceCheckStatus.sourceInvalid,
    sourceIssueCodes: [issueCode],
    sourceSummary: const <String, dynamic>{},
  );
}

EvalTuningReportSourceCheckResult _sourceCheckedReport(
  Map<String, dynamic> report, {
  Map<String, dynamic>? workOrderLaunch,
}) {
  return EvalTuningReportSourceCheckResult(
    reportDigest: EvalProvenance.digestJson(report),
    manifestDigest: _string(_map(report['run'])['manifestDigest']),
    sourceCheckStatus: EvalTuningReportSourceCheckStatus.sourceChecked,
    sourceIssueCodes: const <String>[],
    sourceSummary: <String, dynamic>{
      'publicSelectors': <String, dynamic>{
        'requiredPrimaryCapabilityIds': _stringList(
          _map(
            _map(report['run'])['selectors'],
          )['requiredPrimaryCapabilityIds'],
        ),
        'promptVariantNames': _stringList(
          _map(_map(report['run'])['selectors'])['promptVariantNames'],
        ),
      },
      'workOrderLaunch': ?workOrderLaunch,
    },
  );
}

Map<String, dynamic> _workOrderLaunchSummary({
  required Map<String, dynamic> workOrder,
  List<String>? workOrderBatchRefs,
}) {
  final refs =
      workOrderBatchRefs ??
      [
        for (final batch in (workOrder['runBatches'] as List<dynamic>))
          (batch as Map<String, dynamic>)['workOrderBatchRef'] as String,
      ];
  final sortedRefs = [...refs]..sort();
  final sourcePlan = _map(workOrder['sourceExperimentPlan']);
  return <String, dynamic>{
    'workOrderRef': _string(workOrder['workOrderRef']),
    'workOrderDigest': EvalProvenance.digestJson(workOrder),
    'sourceExperimentPlanDigest': _string(sourcePlan['planDigest']),
    'sourceMatrixDigest': _string(sourcePlan['sourceMatrixDigest']),
    'workOrderBatchRefs': sortedRefs,
    'workOrderBatchSetDigest': EvalProvenance.digestJson(sortedRefs),
    'requiredPrimaryCapabilityIds': const ['task.workflow'],
    'promptVariantNames': const ['default'],
    'workOrderLaunchSubjectDigest': EvalProvenance.digestText(
      'launch-${sortedRefs.join(',')}',
    ),
  };
}

List<String> _csv(String value) => [
  for (final part in value.split(',').map((part) => part.trim()))
    if (part.isNotEmpty) part,
];

String _digest(String value) => EvalProvenance.digestText(value);
