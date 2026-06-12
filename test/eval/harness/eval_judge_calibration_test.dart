import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  const frontierProfile = EvalProfile(
    name: 'frontier-calibration',
    isLocal: false,
    modelClass: EvalModelClass.frontierFast,
    modelId: 'frontier-calibration-model',
    tokenBudget: 10000,
  );
  const localProfile = EvalProfile(
    name: 'local-calibration',
    isLocal: true,
    modelClass: EvalModelClass.localReasoning,
    modelId: 'local-calibration-model',
    tokenBudget: 3000,
  );

  test('trace keys include cascade wake identity', () {
    final key = EvalTraceKey.fromTrace(
      _trace(
        scenario: taskWorkflowChecklistTranscriptCascadeScenario,
        profile: frontierProfile,
        trialIndex: 2,
        cascadeWake: const EvalTraceCascadeWake(
          cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
          wakeIndex: 1,
          wakeCount: 3,
        ),
      ),
    );
    final roundTripped = EvalTraceKey.fromJson(key.toJson());

    expect(
      key.id,
      'task_workflow_checklist_transcript_cascade::frontier-calibration::'
      'prompt-default::trial-2::cascade-task-log::wake-1-of-3',
    );
    expect(roundTripped.id, key.id);
    expect(roundTripped.agentDirectiveVariantName, 'default');
    expect(roundTripped.cascadeWake?.wakeIndex, 1);
  });

  test('trace keys include prompt variant identity', () {
    const variant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final key = EvalTraceKey.fromTrace(
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        agentDirectiveVariant: variant,
      ),
    );
    final roundTripped = EvalTraceKey.fromJson(key.toJson());

    expect(
      key.id,
      'task_release_notes::frontier-calibration::'
      'prompt-metadata-first-v2::trial-0',
    );
    expect(roundTripped.id, key.id);
    expect(roundTripped.agentDirectiveVariantName, 'metadata-first-v2');
  });

  test('calibration templates distinguish prompt variants', () {
    const variant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
        ),
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        agentDirectiveVariant: variant,
        verdict: _verdict(
          pass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 4,
        ),
      ),
    ];

    final template = EvalJudgeCalibration.labelTemplateJson(
      version: 'human-gold-v1',
      traces: traces,
      manifest: _manifestFor(traces),
    );
    final labels = template['labelTemplates']! as List<Map<String, dynamic>>;
    final ids = [
      for (final label in labels)
        EvalTraceKey.fromJson(label['key']! as Map<String, dynamic>).id,
    ];

    expect(
      ids,
      [
        'task_release_notes::frontier-calibration::'
            'prompt-default::trial-0',
        'task_release_notes::frontier-calibration::'
            'prompt-metadata-first-v2::trial-0',
      ],
    );
    expect(
      labels.map((label) => label['agentDirectiveVariantDigest']),
      everyElement(startsWith('sha256:')),
    );
  });

  test('prompt variant labels do not bind default prompt traces', () {
    const variant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final defaultTrace = _trace(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
      verdict: _verdict(
        pass: true,
        goalAttainment: 5,
        quality: 4,
        efficiency: 3,
      ),
    );

    final report = EvalJudgeCalibration.evaluate(
      traces: [defaultTrace],
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        labels: [
          _label(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            agentDirectiveVariant: variant,
            expectedPass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
          ),
        ],
      ),
    );

    expect(report.evaluatedCount, 0);
    expect(report.missingTraceCount, 1);
    expect(report.unlabeledVerdictCount, 1);
    expect(
      report.findings.map((finding) => finding.kind),
      containsAll([
        JudgeCalibrationFindingKind.missingTrace,
        JudgeCalibrationFindingKind.unlabeledVerdict,
      ]),
    );
    expect(
      report.findings
          .singleWhere(
            (finding) =>
                finding.kind == JudgeCalibrationFindingKind.missingTrace,
          )
          .key,
      contains('prompt-metadata-first-v2'),
    );
  });

  test('reports judge agreement and calibration coverage gaps', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
        ),
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: false,
          goalAttainment: 2,
          quality: 2,
          efficiency: 4,
        ),
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: localProfile,
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: localProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 5,
        ),
      ),
      _trace(
        scenario: taskWorkflowPendingProposalMergeScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
      ),
      _trace(
        scenario: taskWorkflowRejectedProposalStickinessScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 4,
        ),
      ),
    ];
    final labels = JudgeCalibrationSet(
      version: 'human-gold-v1',
      labels: [
        _label(
          scenario: taskReleaseNotesScenario,
          profile: frontierProfile,
          expectedPass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
          traceDigest: _traceDigest(5, 4, 3),
        ),
        _label(
          scenario: taskReleaseNotesScenario,
          profile: frontierProfile,
          expectedPass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
        ),
        _label(
          scenario: taskWorkflowReleaseNotesScenario,
          profile: frontierProfile,
          expectedPass: true,
          goalAttainment: 4,
          quality: 2,
          efficiency: 4,
          traceDigest: _traceDigest(2, 2, 4),
          verdictDigest: _verdictDigest(
            pass: false,
            goalAttainment: 2,
            quality: 2,
            efficiency: 4,
          ),
        ),
        _label(
          scenario: taskReleaseNotesScenario,
          profile: localProfile,
          expectedPass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 4,
          traceDigest: _traceDigest(4, 4, 4),
        ),
        _missingTraceLabel(
          scenarioId: 'missing-scenario',
          profileName: frontierProfile.name,
        ),
        _label(
          scenario: taskWorkflowPendingProposalMergeScenario,
          profile: frontierProfile,
          expectedPass: false,
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
          traceDigest: _traceDigest(5, 5, 4),
          verdictDigest: _verdictDigest(
            pass: true,
            goalAttainment: 5,
            quality: 5,
            efficiency: 4,
          ),
        ),
        _label(
          scenario: taskWorkflowRejectedProposalStickinessScenario,
          profile: frontierProfile,
          expectedPass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 4,
          traceDigest: EvalProvenance.digestText('old-trace'),
        ),
      ],
    );

    final report = EvalJudgeCalibration.evaluate(
      traces: traces,
      calibrationSet: labels,
    );

    expect(report.calibrationSetVersion, 'human-gold-v1');
    expect(report.labelCount, 6);
    expect(report.judgedTraceCount, 5);
    expect(report.evaluatedCount, 3);
    expect(report.goldCoverageRate, 0.6);
    expect(report.staleLabelCount, 1);
    expect(report.missingTraceCount, 1);
    expect(report.missingVerdictCount, 1);
    expect(report.unlabeledVerdictCount, 1);
    expect(report.falsePassCount, 1);
    expect(report.falseFailCount, 1);
    expect(report.unblindedVerdictCount, 5);
    expect(report.judgeCalibrationMismatchCount, 0);
    expect(report.modelIdentityBlinded, isFalse);
    expect(report.passAgreementCount, 1);
    expect(report.scoreAgreementCount, 2);
    expect(report.passAgreementRate, closeTo(1 / 3, 0.0001));
    expect(report.scoreAgreementRate, closeTo(2 / 3, 0.0001));
    expect(report.goldCoverageEstimate.successes, 3);
    expect(report.goldCoverageEstimate.total, 5);
    expect(report.passAgreementEstimate.successes, 1);
    expect(report.passAgreementEstimate.total, 3);
    expect(
      report.findings.map((finding) => finding.kind),
      containsAll([
        JudgeCalibrationFindingKind.duplicateGoldLabel,
        JudgeCalibrationFindingKind.passMismatch,
        JudgeCalibrationFindingKind.scoreMismatch,
        JudgeCalibrationFindingKind.missingVerdict,
        JudgeCalibrationFindingKind.missingTrace,
        JudgeCalibrationFindingKind.staleGoldLabel,
        JudgeCalibrationFindingKind.unlabeledVerdict,
        JudgeCalibrationFindingKind.unblindedVerdict,
      ]),
    );
    final scoreMismatch = report.findings.singleWhere(
      (finding) => finding.kind == JudgeCalibrationFindingKind.scoreMismatch,
    );
    expect(scoreMismatch.detail, contains('goalAttainment'));

    final basic = report.capabilitySummaries.singleWhere(
      (summary) => summary.name == 'task.grooming.basic',
    );
    expect(basic.labelCount, 2);
    expect(basic.evaluatedCount, 1);
    expect(basic.missingVerdictCount, 1);
    expect(basic.passAgreementRate, 1);

    final labelsSummary = report.capabilitySummaries.singleWhere(
      (summary) => summary.name == 'task.grooming.labels',
    );
    expect(labelsSummary.labelCount, 1);
    expect(labelsSummary.falseFailCount, 1);
    expect(labelsSummary.passAgreementRate, 0);
    expect(labelsSummary.scoreAgreementRate, 0);

    final mergeSummary = report.capabilitySummaries.singleWhere(
      (summary) => summary.name == 'task.proposals.mergepending',
    );
    expect(mergeSummary.falsePassCount, 1);
    expect(mergeSummary.scoreAgreementRate, 1);

    final staleSummary = report.capabilitySummaries.singleWhere(
      (summary) => summary.name == 'task.proposals.rejectedhistory',
    );
    expect(staleSummary.labelCount, 1);
    expect(staleSummary.staleLabelCount, 1);
    expect(staleSummary.evaluatedCount, 0);

    final frontier = report.modelClassSummaries.singleWhere(
      (summary) => summary.name == EvalModelClass.frontierFast.name,
    );
    expect(frontier.labelCount, 4);
    expect(frontier.evaluatedCount, 3);
    expect(frontier.staleLabelCount, 1);
    expect(frontier.falsePassCount, 1);
    expect(frontier.falseFailCount, 1);

    final local = report.modelClassSummaries.singleWhere(
      (summary) => summary.name == EvalModelClass.localReasoning.name,
    );
    expect(local.labelCount, 1);
    expect(local.missingVerdictCount, 1);

    final promptVariant = report.promptVariantSummaries.singleWhere(
      (summary) => summary.name == 'default',
    );
    expect(promptVariant.labelCount, 5);
    expect(promptVariant.evaluatedCount, 3);
    expect(promptVariant.staleLabelCount, 1);
    expect(promptVariant.missingVerdictCount, 1);
    expect(promptVariant.falsePassCount, 1);
    expect(promptVariant.falseFailCount, 1);

    final frontierDefault = report.modelClassPromptVariantSummaries.singleWhere(
      (summary) =>
          summary.name == '${EvalModelClass.frontierFast.name}@default',
    );
    expect(frontierDefault.labelCount, 4);
    expect(frontierDefault.evaluatedCount, 3);
    expect(frontierDefault.staleLabelCount, 1);

    final rendered = EvalJudgeCalibration.render(report);
    expect(
      rendered,
      contains('Judge calibration (human-gold-v1; judge=human-gold-v1)'),
    );
    expect(rendered, contains('coverage'));
    expect(rendered, contains('Capability calibration'));
    expect(rendered, contains('Model-class calibration'));
    expect(rendered, contains('Prompt-variant calibration'));
    expect(rendered, contains('Model-class prompt-variant calibration'));
    expect(rendered, contains('passMismatch'));
    expect(rendered, contains('staleGoldLabel'));
    expect(rendered, contains('unblindedVerdict'));
  });

  test('stale scenario or profile digest is not evaluated', () {
    final report = EvalJudgeCalibration.evaluate(
      traces: [
        _trace(
          scenario: taskReleaseNotesScenario,
          profile: frontierProfile,
          verdict: _verdict(
            pass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
          ),
        ),
      ],
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        labels: [
          _label(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            expectedPass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
            scenarioDigest: EvalProvenance.digestText('old-scenario'),
            profileDigest: EvalProvenance.digestText('old-profile'),
          ),
        ],
      ),
    );

    expect(report.evaluatedCount, 0);
    expect(report.staleLabelCount, 1);
    expect(report.passAgreementCount, 0);
    expect(report.scoreAgreementCount, 0);
    expect(
      report.findings
          .singleWhere(
            (finding) =>
                finding.kind == JudgeCalibrationFindingKind.staleGoldLabel,
          )
          .detail,
      allOf(contains('scenario digest mismatch'), contains('profile digest')),
    );
  });

  test('stale prompt variant digest is not evaluated', () {
    const variant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final report = EvalJudgeCalibration.evaluate(
      traces: [
        _trace(
          scenario: taskReleaseNotesScenario,
          profile: frontierProfile,
          agentDirectiveVariant: variant,
          verdict: _verdict(
            pass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
          ),
        ),
      ],
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        labels: [
          _label(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            agentDirectiveVariant: variant,
            expectedPass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
            agentDirectiveVariantDigest: EvalProvenance.digestText(
              'old-prompt-variant',
            ),
          ),
        ],
      ),
    );

    expect(report.evaluatedCount, 0);
    expect(report.staleLabelCount, 1);
    expect(report.passAgreementCount, 0);
    final promptVariant = report.promptVariantSummaries.singleWhere(
      (summary) => summary.name == 'metadata-first-v2',
    );
    expect(promptVariant.labelCount, 1);
    expect(promptVariant.staleLabelCount, 1);
    expect(promptVariant.evaluatedCount, 0);
    expect(
      report.findings
          .singleWhere(
            (finding) =>
                finding.kind == JudgeCalibrationFindingKind.staleGoldLabel,
          )
          .detail,
      contains('agent directive variant digest mismatch'),
    );
  });

  test('reports independent human review reliability', () {
    final agreeingVerdict = _verdict(
      pass: true,
      goalAttainment: 5,
      quality: 4,
      efficiency: 3,
      modelIdentityVisible: false,
    );
    final unresolvedVerdict = _verdict(
      pass: false,
      goalAttainment: 2,
      quality: 2,
      efficiency: 4,
      modelIdentityVisible: false,
    );
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        verdict: agreeingVerdict,
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: frontierProfile,
        verdict: unresolvedVerdict,
      ),
    ];
    final report = EvalJudgeCalibration.evaluate(
      traces: traces,
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        labels: [
          _label(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            expectedPass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
            traceDigest: agreeingVerdict.traceDigest,
            verdictDigest: EvalProvenance.digestJson(agreeingVerdict.toJson()),
            labelerCount: 2,
            independentReviews: const [
              JudgeCalibrationHumanReview(
                reviewer: 'reviewer-a',
                expectedPass: true,
                goalAttainment: 5,
                quality: 4,
                efficiency: 3,
                blindToJudgeVerdict: true,
                blindToModelIdentity: true,
                blindToPeerVotes: true,
              ),
              JudgeCalibrationHumanReview(
                reviewer: 'reviewer-b',
                expectedPass: true,
                goalAttainment: 5,
                quality: 4,
                efficiency: 3,
                blindToJudgeVerdict: true,
                blindToModelIdentity: true,
                blindToPeerVotes: true,
              ),
            ],
          ),
          _label(
            scenario: taskWorkflowReleaseNotesScenario,
            profile: frontierProfile,
            expectedPass: false,
            goalAttainment: 2,
            quality: 2,
            efficiency: 4,
            traceDigest: unresolvedVerdict.traceDigest,
            verdictDigest: EvalProvenance.digestJson(
              unresolvedVerdict.toJson(),
            ),
            labelerCount: 2,
            independentReviews: const [
              JudgeCalibrationHumanReview(
                reviewer: 'reviewer-c',
                expectedPass: false,
                goalAttainment: 2,
                quality: 2,
                efficiency: 4,
                blindToJudgeVerdict: true,
                blindToModelIdentity: true,
                blindToPeerVotes: true,
              ),
              JudgeCalibrationHumanReview(
                reviewer: 'reviewer-d',
                expectedPass: true,
                goalAttainment: 5,
                quality: 5,
                efficiency: 4,
                blindToJudgeVerdict: true,
                blindToModelIdentity: true,
                blindToPeerVotes: true,
              ),
            ],
          ),
        ],
      ),
    );

    expect(report.evaluatedCount, 2);
    expect(report.humanReviewPairCount, 2);
    expect(report.humanPassAgreementPairCount, 1);
    expect(report.humanScoreAgreementPairCount, 1);
    expect(report.humanPassAgreementRate, 0.5);
    expect(report.humanScoreAgreementRate, 0.5);
    expect(report.unresolvedHumanDisagreementCount, 1);
    expect(report.unblindedHumanReviewCount, 0);
    expect(
      report.findings.map((finding) => finding.kind),
      contains(JudgeCalibrationFindingKind.unresolvedHumanDisagreement),
    );
    final rendered = EvalJudgeCalibration.render(report);
    expect(rendered, contains('human pairs'));
    expect(rendered, contains('unresolved human'));
  });

  test('judge calibration version mismatch is not evaluated', () {
    final report = EvalJudgeCalibration.evaluate(
      traces: [
        _trace(
          scenario: taskReleaseNotesScenario,
          profile: frontierProfile,
          verdict: _verdict(
            pass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
            calibrationSetVersion: 'uncalibrated',
          ),
        ),
      ],
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        labels: [
          _label(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            expectedPass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
            traceDigest: _traceDigest(5, 4, 3),
            verdictDigest: _verdictDigest(
              pass: true,
              goalAttainment: 5,
              quality: 4,
              efficiency: 3,
              calibrationSetVersion: 'uncalibrated',
            ),
          ),
        ],
      ),
    );

    expect(report.evaluatedCount, 0);
    expect(report.judgeCalibrationMismatchCount, 1);
    expect(report.passAgreementCount, 0);
    expect(
      report.findings.map((finding) => finding.kind),
      contains(JudgeCalibrationFindingKind.judgeCalibrationVersionMismatch),
    );
  });

  test('calibration labels round-trip without trace payloads', () {
    final set = JudgeCalibrationSet(
      version: 'human-gold-v1',
      labels: [
        _label(
          scenario: taskReleaseNotesScenario,
          profile: frontierProfile,
          expectedPass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
          traceDigest: _traceDigest(5, 4, 3),
          verdictDigest: EvalProvenance.digestText('reviewed-verdict'),
          labelerCount: 2,
          adjudicationStatus: 'adjudicated',
          rationale: 'Matches the expected durable task update.',
        ),
      ],
    );

    final roundTripped = JudgeCalibrationSet.fromJson(set.toJson());

    expect(roundTripped.version, set.version);
    expect(roundTripped.labels.single.key.id, set.labels.single.key.id);
    expect(roundTripped.labels.single.scenarioDigest, startsWith('sha256:'));
    expect(roundTripped.labels.single.profileDigest, startsWith('sha256:'));
    expect(roundTripped.labels.single.expectedPass, isTrue);
    expect(roundTripped.labels.single.goalAttainmentMin, 5);
    expect(roundTripped.labels.single.goalAttainmentMax, 5);
    expect(roundTripped.labels.single.labeler, 'reviewer-a');
    expect(roundTripped.labels.single.labelerCount, 2);
    expect(roundTripped.labels.single.adjudicationStatus, 'adjudicated');
    expect(roundTripped.toJson().toString(), isNot(contains('transcript')));
    expect(roundTripped.toJson().toString(), isNot(contains('apiKey')));
  });

  test('builds non-secret incomplete human-label templates', () {
    final traces = [
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: localProfile,
        verdict: _verdict(
          pass: false,
          goalAttainment: 2,
          quality: 3,
          efficiency: 4,
          rationale: 'SENTINEL_JUDGE_RATIONALE_DO_NOT_COPY',
          issues: const ['SENTINEL_JUDGE_ISSUE_DO_NOT_COPY'],
        ),
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
        ),
      ),
    ];

    final template = EvalJudgeCalibration.labelTemplateJson(
      version: 'human-gold-v1',
      traces: traces,
      manifest: _manifestFor(traces),
      labeler: 'reviewer-a',
      labelerCount: 2,
    );
    final labels = template['labelTemplates']! as List<Map<String, dynamic>>;

    expect(template['calibrationTemplateSchemaVersion'], 2);
    expect(template['version'], 'human-gold-v1');
    expect(template['judgeCalibrationSetVersion'], 'human-gold-v1');
    expect(template, isNot(contains('calibrationTemplateSelection')));
    final sourceRun = template['sourceRun']! as Map<String, dynamic>;
    expect(sourceRun['runId'], 'run-1');
    expect(sourceRun['manifestDigest'], startsWith('sha256:'));
    expect(sourceRun['scenarioSetDigest'], startsWith('sha256:'));
    expect(sourceRun['profileSetDigest'], startsWith('sha256:'));
    expect(sourceRun['agentDirectiveVariantSetDigest'], startsWith('sha256:'));
    expect(sourceRun['promptDigest'], startsWith('sha256:'));
    expect(sourceRun['toolSchemaDigest'], startsWith('sha256:'));
    expect(sourceRun['traceSchemaVersion'], EvalTrace.schemaVersion);
    expect(
      labels.map((label) {
        final key = label['key']! as Map<String, dynamic>;
        return EvalTraceKey.fromJson(key).id;
      }),
      [
        'task_release_notes::frontier-calibration::prompt-default::trial-0',
        'task_workflow_release_notes::local-calibration::prompt-default::'
            'trial-0',
      ],
    );
    expect(labels.first['traceDigest'], _traceDigest(5, 4, 3));
    expect(labels.first['verdictDigest'], startsWith('sha256:'));
    expect(labels.last['traceDigest'], _traceDigest(2, 3, 4));
    expect(labels.last['verdictDigest'], startsWith('sha256:'));
    for (final label in labels) {
      expect(label['scenarioDigest'], startsWith('sha256:'));
      expect(label['profileDigest'], startsWith('sha256:'));
      expect(label['expectedPass'], isNull);
      expect(label['goalAttainmentMin'], isNull);
      expect(label['goalAttainmentMax'], isNull);
      expect(label['qualityMin'], isNull);
      expect(label['qualityMax'], isNull);
      expect(label['efficiencyMin'], isNull);
      expect(label['efficiencyMax'], isNull);
      expect(label['labeler'], 'reviewer-a');
      expect(label['labelerCount'], 2);
      expect(label['adjudicationStatus'], 'needs_review');
    }
    final json = template.toString();
    expect(json, isNot(contains(taskReleaseNotesScenario.title)));
    expect(
      json,
      isNot(contains(taskReleaseNotesScenario.userInput.transcript)),
    );
    expect(json, isNot(contains('The wake produced durable state')));
    expect(json, isNot(contains('SENTINEL_JUDGE_RATIONALE_DO_NOT_COPY')));
    expect(json, isNot(contains('SENTINEL_JUDGE_ISSUE_DO_NOT_COPY')));
    expect(
      () => JudgeCalibrationSet.fromJson(template),
      throwsFormatException,
    );
  });

  test('stratified template selection covers calibration review strata', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
        ),
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: localProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 3,
        ),
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: localProfile,
        verdict: _verdict(
          pass: false,
          goalAttainment: 2,
          quality: 3,
          efficiency: 4,
        ),
      ),
      _trace(
        scenario: plannerWorkflowFocusBoundaryScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: false,
          goalAttainment: 2,
          quality: 3,
          efficiency: 3,
        ),
      ),
      _trace(
        scenario: plannerCaptureAmbiguousPersonScenario,
        profile: localProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 4,
        ),
      ),
    ];

    final manifest = _manifestFor(
      traces,
      scenarioCatalogEvidence: EvalScenarioCatalogEvidence(
        scenarioSetDigest: EvalProvenance.digestText(
          'private-and-public-scenarios',
        ),
        publicScenarioCount: 3,
        externalScenarioCount: 2,
        externalCatalogDigest: EvalProvenance.digestText('private-catalog'),
        protectedHoldout: true,
        protectedScenarioIds: const [
          'planner_workflow_focus_boundary',
          'planner_capture_ambiguous_person',
        ],
        protectedHoldoutScenarioIds: const [
          'planner_workflow_focus_boundary',
          'planner_capture_ambiguous_person',
        ],
      ),
    );
    final template = EvalJudgeCalibration.labelTemplateJson(
      version: 'human-gold-v1',
      traces: traces,
      manifest: manifest,
      maxRows: 4,
    );
    final reversedTemplate = EvalJudgeCalibration.labelTemplateJson(
      version: 'human-gold-v1',
      traces: traces.reversed.toList(),
      manifest: manifest,
      maxRows: 4,
    );
    final labels = template['labelTemplates']! as List<Map<String, dynamic>>;
    final selection =
        template['calibrationTemplateSelection']! as Map<String, dynamic>;
    final reversedLabels =
        reversedTemplate['labelTemplates']! as List<Map<String, dynamic>>;
    final reversedSelection =
        reversedTemplate['calibrationTemplateSelection']!
            as Map<String, dynamic>;

    expect(labels, hasLength(4));
    expect(selection['policy'], 'stratified-v2');
    expect(selection['maxRows'], 4);
    expect(selection['candidateTraceCount'], 5);
    expect(selection['selectedTraceCount'], 4);
    expect(selection['omittedTraceCount'], 1);
    expect(selection['requiredCoverageRows'], 4);
    expect(selection['candidateSetDigest'], startsWith('sha256:'));
    expect(selection['selectedKeyDigest'], startsWith('sha256:'));
    expect(selection['candidateCoverage'], {
      'agentKinds': 2,
      'modelClasses': 2,
      'promptVariants': 1,
      'verdictOutcomes': 2,
      'protectionBuckets': 2,
      'primaryCapabilities': 4,
    });
    expect(selection['selectedCoverage'], {
      'agentKinds': 2,
      'modelClasses': 2,
      'promptVariants': 1,
      'verdictOutcomes': 2,
      'protectionBuckets': 2,
      'primaryCapabilities': 4,
    });
    expect(selection['candidateCrossCellCoverage'], {
      'agentKindByVerdict': 4,
      'modelClassByVerdict': 4,
      'protectionByVerdict': 4,
    });
    expect(selection['selectedCrossCellCoverage'], {
      'agentKindByVerdict': 4,
      'modelClassByVerdict': 4,
      'protectionByVerdict': 4,
    });
    expect(
      labels.map((label) {
        final key = label['key']! as Map<String, dynamic>;
        return EvalTraceKey.fromJson(key).id;
      }),
      [
        'planner_capture_ambiguous_person::local-calibration::'
            'prompt-default::trial-0',
        'task_release_notes::frontier-calibration::prompt-default::trial-0',
        'planner_workflow_focus_boundary::frontier-calibration::'
            'prompt-default::trial-0',
        'task_workflow_release_notes::local-calibration::prompt-default::'
            'trial-0',
      ],
    );
    expect(
      reversedLabels.map((label) {
        final key = label['key']! as Map<String, dynamic>;
        return EvalTraceKey.fromJson(key).id;
      }),
      [
        'planner_capture_ambiguous_person::local-calibration::'
            'prompt-default::trial-0',
        'task_release_notes::frontier-calibration::prompt-default::trial-0',
        'planner_workflow_focus_boundary::frontier-calibration::'
            'prompt-default::trial-0',
        'task_workflow_release_notes::local-calibration::prompt-default::'
            'trial-0',
      ],
    );
    expect(reversedSelection, selection);
    expect(selection.toString(), isNot(contains('private-catalog')));
    expect(selection.toString(), isNot(contains('planner_workflow')));
  });

  test('stratified template selection covers prompt variants', () {
    const variant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final traces = [
      _trace(
        scenario: plannerCaptureAmbiguousPersonScenario,
        profile: localProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 4,
        ),
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
        ),
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        agentDirectiveVariant: variant,
        verdict: _verdict(
          pass: true,
          goalAttainment: 4,
          quality: 4,
          efficiency: 4,
        ),
      ),
    ];

    final template = EvalJudgeCalibration.labelTemplateJson(
      version: 'human-gold-v1',
      traces: traces,
      manifest: _manifestFor(traces),
      maxRows: 2,
    );
    final labels = template['labelTemplates']! as List<Map<String, dynamic>>;
    final selection =
        template['calibrationTemplateSelection']! as Map<String, dynamic>;

    expect(labels, hasLength(2));
    expect(selection['policy'], 'stratified-v2');
    expect(selection['requiredCoverageRows'], 2);
    expect(selection['selectedCoverage'], containsPair('promptVariants', 2));
    expect(
      labels.map((label) {
        final key = label['key']! as Map<String, dynamic>;
        return EvalTraceKey.fromJson(key).id;
      }),
      [
        'planner_capture_ambiguous_person::local-calibration::'
            'prompt-default::trial-0',
        'task_release_notes::frontier-calibration::'
            'prompt-metadata-first-v2::trial-0',
      ],
    );
  });

  test('stratified template selection rejects too-small budgets', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierProfile,
        verdict: _verdict(
          pass: true,
          goalAttainment: 5,
          quality: 4,
          efficiency: 3,
        ),
      ),
      _trace(
        scenario: taskWorkflowReleaseNotesScenario,
        profile: localProfile,
        verdict: _verdict(
          pass: false,
          goalAttainment: 2,
          quality: 3,
          efficiency: 4,
        ),
      ),
    ];

    expect(
      () => EvalJudgeCalibration.labelTemplateJson(
        version: 'human-gold-v1',
        traces: traces,
        maxRows: 1,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('too small for calibration template stratified-v2'),
        ),
      ),
    );
  });

  test('template generation records the judged calibration provenance', () {
    final trace = _trace(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
      verdict: _verdict(
        pass: true,
        goalAttainment: 5,
        quality: 4,
        efficiency: 3,
        calibrationSetVersion: 'uncalibrated',
      ),
    );

    final template = EvalJudgeCalibration.labelTemplateJson(
      version: 'human-gold-v1',
      traces: [trace],
    );

    expect(template['version'], 'human-gold-v1');
    expect(template['judgeCalibrationSetVersion'], 'uncalibrated');
  });

  test('template sourceRun omits protected scenario id lists', () {
    final trace = _trace(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
      verdict: _verdict(
        pass: true,
        goalAttainment: 5,
        quality: 4,
        efficiency: 3,
      ),
    );

    final template = EvalJudgeCalibration.labelTemplateJson(
      version: 'human-gold-v1',
      traces: [trace],
      manifest: _manifestFor(
        [trace],
        scenarioCatalogEvidence: EvalScenarioCatalogEvidence(
          scenarioSetDigest: EvalProvenance.digestText('private-scenarios'),
          publicScenarioCount: 0,
          externalScenarioCount: 2,
          externalCatalogDigest: EvalProvenance.digestText('private-catalog'),
          externalCatalogId: 'private-production-replay-v1',
          externalSourceLabel: 'private_scenarios.json',
          protectedHoldout: true,
          protectedScenarioIds: const [
            'SENTINEL_PROTECTED_SCENARIO_ID',
            'another-protected-scenario',
          ],
          protectedHoldoutScenarioIds: const [
            'SENTINEL_PROTECTED_SCENARIO_ID',
          ],
        ),
      ),
    );

    final sourceRun = template['sourceRun']! as Map<String, dynamic>;
    final evidence =
        sourceRun['scenarioCatalogEvidence']! as Map<String, dynamic>;
    expect(evidence['externalScenarioCount'], 2);
    expect(evidence['externalCatalogDigest'], startsWith('sha256:'));
    expect(evidence['protectedScenarioCount'], 2);
    expect(evidence['protectedHoldoutScenarioCount'], 1);
    expect(evidence, isNot(contains('externalCatalogId')));
    expect(evidence, isNot(contains('externalSourceLabel')));
    expect(evidence, isNot(contains('protectedScenarioIds')));
    expect(evidence, isNot(contains('protectedHoldoutScenarioIds')));
    expect(
      template.toString(),
      allOf(
        isNot(contains('SENTINEL_PROTECTED_SCENARIO_ID')),
        isNot(contains('private-production-replay-v1')),
        isNot(contains('private_scenarios.json')),
      ),
    );
  });

  test('template generation rejects mixed judge calibration versions', () {
    expect(
      () => EvalJudgeCalibration.labelTemplateJson(
        version: 'human-gold-v1',
        traces: [
          _trace(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            verdict: _verdict(
              pass: true,
              goalAttainment: 5,
              quality: 4,
              efficiency: 3,
              calibrationSetVersion: 'uncalibrated',
            ),
          ),
          _trace(
            scenario: taskWorkflowReleaseNotesScenario,
            profile: frontierProfile,
            verdict: _verdict(
              pass: true,
              goalAttainment: 4,
              quality: 4,
              efficiency: 3,
              calibrationSetVersion: 'human-gold-v0',
            ),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('template generation requires verdict digests by default', () {
    final trace = _trace(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
    );

    expect(
      () => EvalJudgeCalibration.labelTemplateJson(
        version: 'human-gold-v1',
        traces: [trace],
        maxRows: 1,
      ),
      throwsArgumentError,
    );
  });

  test('template generation rejects duplicate trace keys', () {
    final trace = _trace(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
      verdict: _verdict(
        pass: true,
        goalAttainment: 5,
        quality: 4,
        efficiency: 3,
      ),
    );

    expect(
      () => EvalJudgeCalibration.labelTemplateJson(
        version: 'human-gold-v1',
        traces: [trace, trace],
      ),
      throwsArgumentError,
    );
  });

  test('calibration set parser rejects empty and template files', () {
    expect(
      () => JudgeCalibrationSet.fromJson(const {
        'version': '',
        'labels': <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationSet.fromJson(const {
        'version': 'human-gold-v1',
        'labels': <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationSet.fromJson(const {
        'calibrationTemplateSchemaVersion': 2,
        'version': 'human-gold-v1',
        'labelTemplates': <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
  });

  test('completed calibration labels reject incomplete review metadata', () {
    final label = _label(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
      expectedPass: true,
      goalAttainment: 5,
      quality: 4,
      efficiency: 3,
      traceDigest: _traceDigest(5, 4, 3),
      verdictDigest: EvalProvenance.digestText('reviewed-verdict'),
      adjudicationStatus: 'adjudicated',
    ).toJson();

    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...label,
        'traceDigest': null,
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...label,
        'verdictDigest': null,
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...label,
        'adjudicationStatus': 'needs_review',
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...label,
        'labelerCount': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...label,
        'labeler': '',
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...label,
        'adjudicationStatus': '',
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...label,
        'rationale': '',
      }),
      throwsFormatException,
    );
  });

  test('stale verdict digest is not evaluated', () {
    final verdict = _verdict(
      pass: true,
      goalAttainment: 5,
      quality: 4,
      efficiency: 3,
    );
    final report = EvalJudgeCalibration.evaluate(
      traces: [
        _trace(
          scenario: taskReleaseNotesScenario,
          profile: frontierProfile,
          verdict: verdict,
        ),
      ],
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        labels: [
          _label(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            expectedPass: true,
            goalAttainment: 5,
            quality: 4,
            efficiency: 3,
            traceDigest: verdict.traceDigest,
            verdictDigest: EvalProvenance.digestText('old-verdict'),
          ),
        ],
      ),
    );

    expect(report.evaluatedCount, 0);
    expect(report.staleLabelCount, 1);
    expect(
      report.findings
          .singleWhere(
            (finding) =>
                finding.kind == JudgeCalibrationFindingKind.staleGoldLabel,
          )
          .detail,
      contains('verdict digest mismatch'),
    );
  });

  test(
    'bootstrap uncalibrated verdicts can be calibrated by human gold set',
    () {
      final report = EvalJudgeCalibration.evaluate(
        traces: [
          _trace(
            scenario: taskReleaseNotesScenario,
            profile: frontierProfile,
            verdict: _verdict(
              pass: true,
              goalAttainment: 5,
              quality: 4,
              efficiency: 3,
              calibrationSetVersion: 'uncalibrated',
            ),
          ),
        ],
        calibrationSet: JudgeCalibrationSet(
          version: 'human-gold-v1',
          judgeCalibrationSetVersion: 'uncalibrated',
          labels: [
            _label(
              scenario: taskReleaseNotesScenario,
              profile: frontierProfile,
              expectedPass: true,
              goalAttainment: 5,
              quality: 4,
              efficiency: 3,
              traceDigest: _traceDigest(5, 4, 3),
              verdictDigest: _verdictDigest(
                pass: true,
                goalAttainment: 5,
                quality: 4,
                efficiency: 3,
                calibrationSetVersion: 'uncalibrated',
              ),
            ),
          ],
        ),
      );

      expect(report.calibrationSetVersion, 'human-gold-v1');
      expect(report.judgeCalibrationSetVersion, 'uncalibrated');
      expect(report.evaluatedCount, 1);
      expect(report.judgeCalibrationMismatchCount, 0);
      expect(report.passAgreementCount, 1);
      expect(report.scoreAgreementCount, 1);
      expect(
        EvalJudgeCalibration.render(report),
        contains('Judge calibration (human-gold-v1; judge=uncalibrated)'),
      );
    },
  );

  test('legacy exact scores parse as digest-bound bands', () {
    final provenance = EvalProvenance.capture(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
    );
    final label = JudgeCalibrationLabel.fromJson({
      'key': const EvalTraceKey(
        scenarioId: 'task_release_notes',
        profileName: 'frontier-calibration',
        agentDirectiveVariantName: 'default',
        trialIndex: 0,
      ).toJson(),
      'scenarioDigest': provenance.scenarioDigest,
      'profileDigest': provenance.profileDigest,
      'agentDirectiveVariantDigest': provenance.agentDirectiveVariantDigest,
      'traceDigest': _traceDigest(5, 4, 3),
      'verdictDigest': EvalProvenance.digestText('reviewed-verdict'),
      'expectedPass': true,
      'goalAttainment': 5,
      'quality': 4,
      'efficiency': 3,
      'scoreTolerance': 1,
      'labeler': 'reviewer-a',
      'adjudicationStatus': 'reviewed',
      'rationale': 'Legacy score fixture with completed review metadata.',
    });

    expect(label.goalAttainmentMin, 4);
    expect(label.goalAttainmentMax, 5);
    expect(label.qualityMin, 3);
    expect(label.qualityMax, 5);
    expect(label.efficiencyMin, 2);
    expect(label.efficiencyMax, 4);
  });

  test('label JSON rejects invalid digests and score bands', () {
    final provenance = EvalProvenance.capture(
      scenario: taskReleaseNotesScenario,
      profile: frontierProfile,
    );
    final valid = {
      'key': const EvalTraceKey(
        scenarioId: 'task_release_notes',
        profileName: 'frontier-calibration',
        agentDirectiveVariantName: 'default',
        trialIndex: 0,
      ).toJson(),
      'scenarioDigest': provenance.scenarioDigest,
      'profileDigest': provenance.profileDigest,
      'agentDirectiveVariantDigest': provenance.agentDirectiveVariantDigest,
      'traceDigest': _traceDigest(5, 4, 3),
      'verdictDigest': EvalProvenance.digestText('reviewed-verdict'),
      'expectedPass': true,
      'goalAttainmentMin': 5,
      'goalAttainmentMax': 5,
      'qualityMin': 4,
      'qualityMax': 4,
      'efficiencyMin': 3,
      'efficiencyMax': 3,
      'labeler': 'reviewer-a',
      'adjudicationStatus': 'reviewed',
      'rationale': 'Valid completed review metadata.',
    };

    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...valid,
        'scenarioDigest': 'sha256:not-a-digest',
      }),
      throwsFormatException,
    );
    final keyWithoutPromptVariant = <String, dynamic>{
      ...(valid['key']! as Map<String, dynamic>),
    }..remove('agentDirectiveVariantName');
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...valid,
        'key': keyWithoutPromptVariant,
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson(
        {
          ...valid,
        }..remove('agentDirectiveVariantDigest'),
      ),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...valid,
        'qualityMin': 5,
        'qualityMax': 4,
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...valid,
        'efficiencyMin': 1,
        'efficiencyMax': 2,
      }),
      throwsFormatException,
    );
    expect(
      () => JudgeCalibrationLabel.fromJson({
        ...valid,
        'labelerCount': 2,
        'independentReviews': [
          {
            'reviewer': 'reviewer-a',
            'expectedPass': true,
            'goalAttainment': 5,
            'quality': 4,
            'efficiency': 3,
            'blindToJudgeVerdict': true,
            'blindToModelIdentity': true,
            'blindToPeerVotes': true,
          },
          {
            'reviewer': 'reviewer-a',
            'expectedPass': true,
            'goalAttainment': 5,
            'quality': 4,
            'efficiency': 3,
            'blindToJudgeVerdict': true,
            'blindToModelIdentity': true,
            'blindToPeerVotes': true,
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('rate estimate rejects impossible counts', () {
    expect(
      () => RateEstimate.wilson(successes: -1, total: 1),
      throwsArgumentError,
    );
    expect(
      () => RateEstimate.wilson(successes: 1, total: -1),
      throwsArgumentError,
    );
    expect(
      () => RateEstimate.wilson(successes: 2, total: 1),
      throwsArgumentError,
    );
  });
}

EvalTrace _trace({
  required EvalScenario scenario,
  required EvalProfile profile,
  JudgeVerdict? verdict,
  int trialIndex = 0,
  EvalAgentDirectiveVariant agentDirectiveVariant =
      const EvalAgentDirectiveVariant(),
  EvalTraceCascadeWake? cascadeWake,
}) {
  return EvalTrace(
    runId: 'run-1',
    scenario: scenario,
    profile: profile,
    agentDirectiveVariant: agentDirectiveVariant,
    provenance: EvalProvenance.capture(
      scenario: scenario,
      profile: profile,
      agentDirectiveVariant: agentDirectiveVariant,
    ),
    trialIndex: trialIndex,
    cascadeWake: cascadeWake,
    output: const AgentRunOutput(
      success: true,
      usage: InferenceUsage(inputTokens: 100, outputTokens: 50),
      report: AgentReportRecord(
        oneLiner: 'Handled',
        tldr: 'The wake produced durable state.',
        content: 'Done.',
      ),
    ),
    level1Checks: const [EvalCheck(name: 'example', passed: true)],
    verdict: verdict,
  );
}

EvalRunManifest _manifestFor(
  List<EvalTrace> traces, {
  EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
}) {
  return EvalProvenance.captureRunManifest(
    runId: 'run-1',
    targetName: 'calibration-test',
    targetKind: 'live',
    scenarios: {
      for (final trace in traces) trace.scenario.id: trace.scenario,
    }.values.toList(),
    profiles: {
      for (final trace in traces) trace.profile.name: trace.profile,
    }.values.toList(),
    agentDirectiveVariants: {
      for (final trace in traces)
        trace.agentDirectiveVariant.name: trace.agentDirectiveVariant,
    }.values.toList(),
    createdAt: DateTime(2026, 6, 10, 12),
    command: 'calibration-test',
    environment: const <String, String>{},
    scenarioCatalogEvidence: scenarioCatalogEvidence,
  );
}

JudgeCalibrationLabel _label({
  required EvalScenario scenario,
  required EvalProfile profile,
  required bool expectedPass,
  required int goalAttainment,
  required int quality,
  required int efficiency,
  EvalAgentDirectiveVariant agentDirectiveVariant =
      const EvalAgentDirectiveVariant(),
  String? scenarioDigest,
  String? profileDigest,
  String? agentDirectiveVariantDigest,
  String? traceDigest,
  String? verdictDigest,
  String labeler = 'reviewer-a',
  int labelerCount = 1,
  String adjudicationStatus = 'reviewed',
  String rationale = 'Reviewed against the trace and verdict.',
  List<JudgeCalibrationHumanReview> independentReviews =
      const <JudgeCalibrationHumanReview>[],
}) {
  final provenance = EvalProvenance.capture(
    scenario: scenario,
    profile: profile,
    agentDirectiveVariant: agentDirectiveVariant,
  );
  return JudgeCalibrationLabel(
    key: EvalTraceKey(
      scenarioId: scenario.id,
      profileName: profile.name,
      agentDirectiveVariantName: agentDirectiveVariant.name,
      trialIndex: 0,
    ),
    scenarioDigest: scenarioDigest ?? provenance.scenarioDigest,
    profileDigest: profileDigest ?? provenance.profileDigest,
    agentDirectiveVariantDigest:
        agentDirectiveVariantDigest ?? provenance.agentDirectiveVariantDigest,
    traceDigest:
        traceDigest ?? _traceDigest(goalAttainment, quality, efficiency),
    verdictDigest:
        verdictDigest ??
        _verdictDigest(
          pass: expectedPass,
          goalAttainment: goalAttainment,
          quality: quality,
          efficiency: efficiency,
        ),
    expectedPass: expectedPass,
    goalAttainmentMin: goalAttainment,
    goalAttainmentMax: goalAttainment,
    qualityMin: quality,
    qualityMax: quality,
    efficiencyMin: efficiency,
    efficiencyMax: efficiency,
    labeler: labeler,
    labelerCount: labelerCount,
    adjudicationStatus: adjudicationStatus,
    rationale: rationale,
    independentReviews: independentReviews,
  );
}

JudgeCalibrationLabel _missingTraceLabel({
  required String scenarioId,
  required String profileName,
  String agentDirectiveVariantName = 'default',
}) {
  return JudgeCalibrationLabel(
    key: EvalTraceKey(
      scenarioId: scenarioId,
      profileName: profileName,
      agentDirectiveVariantName: agentDirectiveVariantName,
      trialIndex: 0,
    ),
    scenarioDigest: EvalProvenance.digestText('missing-scenario'),
    profileDigest: EvalProvenance.digestText(profileName),
    agentDirectiveVariantDigest: EvalProvenance.digestText(
      'missing-agent-directive-variant',
    ),
    traceDigest: EvalProvenance.digestText('missing-trace'),
    verdictDigest: EvalProvenance.digestText('missing-verdict'),
    expectedPass: false,
    goalAttainmentMin: 2,
    goalAttainmentMax: 2,
    qualityMin: 2,
    qualityMax: 2,
    efficiencyMin: 2,
    efficiencyMax: 2,
    labeler: 'reviewer-a',
    adjudicationStatus: 'reviewed',
    rationale: 'Reviewed trace is missing from this run.',
  );
}

JudgeVerdict _verdict({
  required bool pass,
  required int goalAttainment,
  required int quality,
  required int efficiency,
  bool modelIdentityVisible = true,
  String calibrationSetVersion = 'human-gold-v1',
  String rationale = '',
  List<String> issues = const <String>[],
}) {
  return JudgeVerdict(
    traceDigest: _traceDigest(goalAttainment, quality, efficiency),
    goalAttainment: goalAttainment,
    quality: quality,
    efficiency: efficiency,
    pass: pass,
    judge: JudgeProvenanceRecord(
      judgeName: 'claude-code',
      judgeModel: 'test-judge',
      promptDigest: EvalProvenance.promptDigest(),
      calibrationSetVersion: calibrationSetVersion,
      profileVisible: true,
      modelIdentityVisible: modelIdentityVisible,
    ),
    rationale: rationale,
    issues: issues,
  );
}

String _traceDigest(int goalAttainment, int quality, int efficiency) =>
    EvalProvenance.digestText('trace-$goalAttainment-$quality-$efficiency');

String _verdictDigest({
  required bool pass,
  required int goalAttainment,
  required int quality,
  required int efficiency,
  String calibrationSetVersion = 'human-gold-v1',
}) {
  return EvalProvenance.digestJson(
    _verdict(
      pass: pass,
      goalAttainment: goalAttainment,
      quality: quality,
      efficiency: efficiency,
      calibrationSetVersion: calibrationSetVersion,
    ).toJson(),
  );
}
