// Human-label calibration helpers for the eval judge.
//
// Pure, non-IO code: callers load a calibration set from JSON, run/grade traces
// normally, and pass both here to measure judge/human agreement.

import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_statistics.dart';

const _calibrationTemplateSchemaVersion = 2;
const _calibrationTemplateSelectionPolicy = 'stratified-v2';

/// One independent human review captured before final gold-label adjudication.
///
/// Reviews intentionally store only rubric outcomes and reviewer provenance.
/// They must not copy trace text, model output, prompts, tool arguments, or
/// protected scenario details.
class JudgeCalibrationHumanReview {
  const JudgeCalibrationHumanReview({
    required this.reviewer,
    required this.expectedPass,
    required this.goalAttainment,
    required this.quality,
    required this.efficiency,
    this.blindToJudgeVerdict = false,
    this.blindToModelIdentity = false,
    this.blindToPeerVotes = false,
  });

  factory JudgeCalibrationHumanReview.fromJson(Map<String, dynamic> json) {
    final review = JudgeCalibrationHumanReview(
      reviewer: ((json['reviewer'] as String?) ?? '').trim(),
      expectedPass: json['expectedPass'] as bool,
      goalAttainment: (json['goalAttainment'] as num).toInt(),
      quality: (json['quality'] as num).toInt(),
      efficiency: (json['efficiency'] as num).toInt(),
      blindToJudgeVerdict: json['blindToJudgeVerdict'] as bool? ?? false,
      blindToModelIdentity: json['blindToModelIdentity'] as bool? ?? false,
      blindToPeerVotes: json['blindToPeerVotes'] as bool? ?? false,
    )..validate();
    return review;
  }

  final String reviewer;
  final bool expectedPass;
  final int goalAttainment;
  final int quality;
  final int efficiency;
  final bool blindToJudgeVerdict;
  final bool blindToModelIdentity;
  final bool blindToPeerVotes;

  bool get fullyBlinded =>
      blindToJudgeVerdict && blindToModelIdentity && blindToPeerVotes;

  void validate() {
    if (reviewer.isEmpty) {
      throw const FormatException('Human reviews must include reviewer');
    }
    _validateScore(label: 'goalAttainment', value: goalAttainment);
    _validateScore(label: 'quality', value: quality);
    _validateScore(label: 'efficiency', value: efficiency);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'reviewer': reviewer,
    'expectedPass': expectedPass,
    'goalAttainment': goalAttainment,
    'quality': quality,
    'efficiency': efficiency,
    'blindToJudgeVerdict': blindToJudgeVerdict,
    'blindToModelIdentity': blindToModelIdentity,
    'blindToPeerVotes': blindToPeerVotes,
  };
}

/// A stable key for one trace cell in the eval matrix.
class EvalTraceKey {
  const EvalTraceKey({
    required this.scenarioId,
    required this.profileName,
    required this.agentDirectiveVariantName,
    required this.trialIndex,
    this.cascadeWake,
  });

  factory EvalTraceKey.fromTrace(EvalTrace trace) => EvalTraceKey(
    scenarioId: trace.scenario.id,
    profileName: trace.profile.name,
    agentDirectiveVariantName: trace.agentDirectiveVariant.name,
    trialIndex: trace.trialIndex,
    cascadeWake: trace.cascadeWake,
  );

  factory EvalTraceKey.fromJson(Map<String, dynamic> json) => EvalTraceKey(
    scenarioId: json['scenarioId'] as String,
    profileName: json['profileName'] as String,
    agentDirectiveVariantName:
        (json['agentDirectiveVariantName'] as String?) ??
        const EvalAgentDirectiveVariant().name,
    trialIndex: (json['trialIndex'] as num).toInt(),
    cascadeWake: json['cascadeWake'] == null
        ? null
        : EvalTraceCascadeWake.fromJson(
            json['cascadeWake'] as Map<String, dynamic>,
          ),
  );

  final String scenarioId;
  final String profileName;
  final String agentDirectiveVariantName;
  final int trialIndex;
  final EvalTraceCascadeWake? cascadeWake;

  String get id {
    final suffix = cascadeWake == null ? '' : '::${cascadeWake!.keySuffix}';
    return '$scenarioId::$profileName::prompt-$agentDirectiveVariantName::'
        'trial-$trialIndex$suffix';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scenarioId': scenarioId,
    'profileName': profileName,
    'agentDirectiveVariantName': agentDirectiveVariantName,
    'trialIndex': trialIndex,
    if (cascadeWake != null) 'cascadeWake': cascadeWake!.toJson(),
  };
}

/// One human-labeled verdict used to calibrate an LLM judge.
///
/// Labels intentionally reference trace ids, provenance digests, and score
/// bands only. They do not store raw prompts, transcripts, model outputs, tool
/// arguments, or API keys.
class JudgeCalibrationLabel {
  const JudgeCalibrationLabel({
    required this.key,
    required this.scenarioDigest,
    required this.profileDigest,
    required this.agentDirectiveVariantDigest,
    required this.expectedPass,
    required this.goalAttainmentMin,
    required this.goalAttainmentMax,
    required this.qualityMin,
    required this.qualityMax,
    required this.efficiencyMin,
    required this.efficiencyMax,
    this.traceDigest,
    this.verdictDigest,
    this.labeler = '',
    this.labelerCount = 1,
    this.adjudicationStatus = '',
    this.rationale = '',
    this.independentReviews = const <JudgeCalibrationHumanReview>[],
  });

  factory JudgeCalibrationLabel.fromJson(Map<String, dynamic> json) {
    final rawKey = json['key'] as Map<String, dynamic>;
    if (!rawKey.containsKey('agentDirectiveVariantName')) {
      throw const FormatException(
        'Completed labels must include key.agentDirectiveVariantName',
      );
    }
    final agentDirectiveVariantDigest =
        json['agentDirectiveVariantDigest'] as String?;
    if (agentDirectiveVariantDigest == null) {
      throw const FormatException(
        'Completed labels must include agentDirectiveVariantDigest',
      );
    }
    final rawReviews = json['independentReviews'];
    final label = JudgeCalibrationLabel(
      key: EvalTraceKey.fromJson(rawKey),
      scenarioDigest: json['scenarioDigest'] as String,
      profileDigest: json['profileDigest'] as String,
      agentDirectiveVariantDigest: agentDirectiveVariantDigest,
      traceDigest: json['traceDigest'] as String?,
      verdictDigest: json['verdictDigest'] as String?,
      expectedPass: json['expectedPass'] as bool,
      goalAttainmentMin: _scoreMin(json, 'goalAttainment'),
      goalAttainmentMax: _scoreMax(json, 'goalAttainment'),
      qualityMin: _scoreMin(json, 'quality'),
      qualityMax: _scoreMax(json, 'quality'),
      efficiencyMin: _scoreMin(json, 'efficiency'),
      efficiencyMax: _scoreMax(json, 'efficiency'),
      labeler: ((json['labeler'] as String?) ?? '').trim(),
      labelerCount: (json['labelerCount'] as num?)?.toInt() ?? 1,
      adjudicationStatus: ((json['adjudicationStatus'] as String?) ?? '')
          .trim(),
      rationale: ((json['rationale'] as String?) ?? '').trim(),
      independentReviews: rawReviews == null
          ? const <JudgeCalibrationHumanReview>[]
          : (rawReviews as List)
                .map(
                  (e) => JudgeCalibrationHumanReview.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
    );
    _validateScoreBand(
      label: 'goalAttainment',
      min: label.goalAttainmentMin,
      max: label.goalAttainmentMax,
    );
    _validateScoreBand(
      label: 'quality',
      min: label.qualityMin,
      max: label.qualityMax,
    );
    _validateScoreBand(
      label: 'efficiency',
      min: label.efficiencyMin,
      max: label.efficiencyMax,
    );
    label.validateCompleted();
    if (label.expectedPass &&
        (label.goalAttainmentMax < 3 ||
            label.qualityMax < 3 ||
            label.efficiencyMax < 3)) {
      throw const FormatException(
        'Passing labels must allow a passing score in every dimension',
      );
    }
    return label;
  }

  final EvalTraceKey key;
  final String scenarioDigest;
  final String profileDigest;
  final String agentDirectiveVariantDigest;
  final String? traceDigest;
  final String? verdictDigest;
  final bool expectedPass;
  final int goalAttainmentMin;
  final int goalAttainmentMax;
  final int qualityMin;
  final int qualityMax;
  final int efficiencyMin;
  final int efficiencyMax;
  final String labeler;
  final int labelerCount;
  final String adjudicationStatus;
  final String rationale;
  final List<JudgeCalibrationHumanReview> independentReviews;

  void validateCompleted() {
    _validateDigest(label: 'scenarioDigest', value: scenarioDigest);
    _validateDigest(label: 'profileDigest', value: profileDigest);
    _validateDigest(
      label: 'agentDirectiveVariantDigest',
      value: agentDirectiveVariantDigest,
    );
    final traceDigest = this.traceDigest;
    if (traceDigest == null) {
      throw const FormatException('Completed labels must include traceDigest');
    }
    _validateDigest(label: 'traceDigest', value: traceDigest);
    final verdictDigest = this.verdictDigest;
    if (verdictDigest == null) {
      throw const FormatException(
        'Completed labels must include verdictDigest',
      );
    }
    _validateDigest(label: 'verdictDigest', value: verdictDigest);
    if (labelerCount < 1) {
      throw const FormatException('labelerCount must be at least 1');
    }
    if (labeler.isEmpty) {
      throw const FormatException('Completed labels must include labeler');
    }
    if (rationale.isEmpty) {
      throw const FormatException('Completed labels must include rationale');
    }
    if (adjudicationStatus != 'reviewed' &&
        adjudicationStatus != 'adjudicated') {
      throw const FormatException(
        'Completed calibration labels must be reviewed or adjudicated',
      );
    }
    _validateIndependentReviews();
  }

  void _validateIndependentReviews() {
    if (independentReviews.isEmpty) return;
    if (independentReviews.length < 2) {
      throw const FormatException(
        'independentReviews must include at least two reviews',
      );
    }
    final reviewers = <String>{};
    for (final review in independentReviews) {
      review.validate();
      if (!reviewers.add(review.reviewer)) {
        throw FormatException(
          'duplicate independent reviewer: ${review.reviewer}',
        );
      }
    }
    if (labelerCount != independentReviews.length) {
      throw const FormatException(
        'labelerCount must match independentReviews length',
      );
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key.toJson(),
    'scenarioDigest': scenarioDigest,
    'profileDigest': profileDigest,
    'agentDirectiveVariantDigest': agentDirectiveVariantDigest,
    if (traceDigest != null) 'traceDigest': traceDigest,
    if (verdictDigest != null) 'verdictDigest': verdictDigest,
    'expectedPass': expectedPass,
    'goalAttainmentMin': goalAttainmentMin,
    'goalAttainmentMax': goalAttainmentMax,
    'qualityMin': qualityMin,
    'qualityMax': qualityMax,
    'efficiencyMin': efficiencyMin,
    'efficiencyMax': efficiencyMax,
    if (labeler.isNotEmpty) 'labeler': labeler,
    if (labelerCount != 1) 'labelerCount': labelerCount,
    if (adjudicationStatus.isNotEmpty) 'adjudicationStatus': adjudicationStatus,
    if (rationale.isNotEmpty) 'rationale': rationale,
    if (independentReviews.isNotEmpty)
      'independentReviews': independentReviews
          .map((review) => review.toJson())
          .toList(),
  };
}

/// Versioned human-label set for judge calibration.
class JudgeCalibrationSet {
  const JudgeCalibrationSet({
    required this.version,
    required this.labels,
    String? judgeCalibrationSetVersion,
  }) : judgeCalibrationSetVersion = judgeCalibrationSetVersion ?? version;

  factory JudgeCalibrationSet.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('calibrationTemplateSchemaVersion') ||
        json.containsKey('labelTemplates')) {
      throw const FormatException(
        'Calibration template must be completed before calibrate can read it',
      );
    }
    final version = (json['version'] as String?)?.trim();
    if (version == null || version.isEmpty) {
      throw const FormatException('Calibration set version must not be empty');
    }
    final judgeCalibrationSetVersion =
        (json['judgeCalibrationSetVersion'] as String?)?.trim() ?? version;
    if (judgeCalibrationSetVersion.isEmpty) {
      throw const FormatException(
        'Judge calibration set version must not be empty',
      );
    }
    final rawLabels = json['labels'];
    if (rawLabels is! List || rawLabels.isEmpty) {
      throw const FormatException(
        'Calibration set must contain at least one label',
      );
    }
    return JudgeCalibrationSet(
      version: version,
      judgeCalibrationSetVersion: judgeCalibrationSetVersion,
      labels: rawLabels
          .map(
            (e) => JudgeCalibrationLabel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String version;
  final String judgeCalibrationSetVersion;
  final List<JudgeCalibrationLabel> labels;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'judgeCalibrationSetVersion': judgeCalibrationSetVersion,
    'labels': labels.map((label) => label.toJson()).toList(),
  };
}

enum JudgeCalibrationFindingKind {
  duplicateGoldLabel,
  missingTrace,
  duplicateTrace,
  missingVerdict,
  unlabeledVerdict,
  staleGoldLabel,
  unblindedVerdict,
  judgeCalibrationVersionMismatch,
  passMismatch,
  scoreMismatch,
  unresolvedHumanDisagreement,
  unblindedHumanReview,
}

class JudgeCalibrationFinding {
  const JudgeCalibrationFinding({
    required this.kind,
    required this.key,
    required this.detail,
  });

  final JudgeCalibrationFindingKind kind;
  final String key;
  final String detail;
}

class JudgeCalibrationSliceSummary {
  const JudgeCalibrationSliceSummary({
    required this.name,
    required this.labelCount,
    required this.evaluatedCount,
    required this.staleLabelCount,
    required this.missingTraceCount,
    required this.missingVerdictCount,
    required this.falsePassCount,
    required this.falseFailCount,
    required this.judgeCalibrationMismatchCount,
    required this.passAgreementCount,
    required this.scoreAgreementCount,
  });

  final String name;
  final int labelCount;
  final int evaluatedCount;
  final int staleLabelCount;
  final int missingTraceCount;
  final int missingVerdictCount;
  final int falsePassCount;
  final int falseFailCount;
  final int judgeCalibrationMismatchCount;
  final int passAgreementCount;
  final int scoreAgreementCount;

  double get passAgreementRate =>
      evaluatedCount == 0 ? 0 : passAgreementCount / evaluatedCount;

  double get scoreAgreementRate =>
      evaluatedCount == 0 ? 0 : scoreAgreementCount / evaluatedCount;
}

class JudgeCalibrationReport {
  const JudgeCalibrationReport({
    required this.calibrationSetVersion,
    required this.judgeCalibrationSetVersion,
    required this.labelCount,
    required this.judgedTraceCount,
    required this.evaluatedCount,
    required this.staleLabelCount,
    required this.missingTraceCount,
    required this.missingVerdictCount,
    required this.unlabeledVerdictCount,
    required this.falsePassCount,
    required this.falseFailCount,
    required this.unblindedVerdictCount,
    required this.judgeCalibrationMismatchCount,
    required this.passAgreementCount,
    required this.scoreAgreementCount,
    required this.capabilitySummaries,
    required this.modelClassSummaries,
    required this.findings,
    this.humanReviewPairCount = 0,
    this.humanPassAgreementPairCount = 0,
    this.humanScoreAgreementPairCount = 0,
    this.unresolvedHumanDisagreementCount = 0,
    this.unblindedHumanReviewCount = 0,
  });

  final String calibrationSetVersion;
  final String judgeCalibrationSetVersion;
  final int labelCount;
  final int judgedTraceCount;
  final int evaluatedCount;
  final int staleLabelCount;
  final int missingTraceCount;
  final int missingVerdictCount;
  final int unlabeledVerdictCount;
  final int falsePassCount;
  final int falseFailCount;
  final int unblindedVerdictCount;
  final int judgeCalibrationMismatchCount;
  final int passAgreementCount;
  final int scoreAgreementCount;
  final int humanReviewPairCount;
  final int humanPassAgreementPairCount;
  final int humanScoreAgreementPairCount;
  final int unresolvedHumanDisagreementCount;
  final int unblindedHumanReviewCount;
  final List<JudgeCalibrationSliceSummary> capabilitySummaries;
  final List<JudgeCalibrationSliceSummary> modelClassSummaries;
  final List<JudgeCalibrationFinding> findings;

  double get goldCoverageRate =>
      judgedTraceCount == 0 ? 0 : evaluatedCount / judgedTraceCount;

  double get passAgreementRate =>
      evaluatedCount == 0 ? 0 : passAgreementCount / evaluatedCount;

  double get scoreAgreementRate =>
      evaluatedCount == 0 ? 0 : scoreAgreementCount / evaluatedCount;

  double get humanPassAgreementRate => humanReviewPairCount == 0
      ? 0
      : humanPassAgreementPairCount / humanReviewPairCount;

  double get humanScoreAgreementRate => humanReviewPairCount == 0
      ? 0
      : humanScoreAgreementPairCount / humanReviewPairCount;

  bool get modelIdentityBlinded => unblindedVerdictCount == 0;

  RateEstimate get goldCoverageEstimate => RateEstimate.wilson(
    successes: evaluatedCount,
    total: judgedTraceCount,
  );

  RateEstimate get passAgreementEstimate => RateEstimate.wilson(
    successes: passAgreementCount,
    total: evaluatedCount,
  );

  RateEstimate get scoreAgreementEstimate => RateEstimate.wilson(
    successes: scoreAgreementCount,
    total: evaluatedCount,
  );

  RateEstimate get humanPassAgreementEstimate => RateEstimate.wilson(
    successes: humanPassAgreementPairCount,
    total: humanReviewPairCount,
  );

  RateEstimate get humanScoreAgreementEstimate => RateEstimate.wilson(
    successes: humanScoreAgreementPairCount,
    total: humanReviewPairCount,
  );
}

abstract final class EvalJudgeCalibration {
  static Map<String, dynamic> labelTemplateJson({
    required String version,
    required List<EvalTrace> traces,
    EvalRunManifest? manifest,
    String labeler = '',
    int labelerCount = 1,
    int? maxRows,
  }) {
    if (version.trim().isEmpty) {
      throw ArgumentError.value(version, 'version', 'must not be empty');
    }
    if (labelerCount < 1) {
      throw ArgumentError.value(
        labelerCount,
        'labelerCount',
        'must be at least 1',
      );
    }
    if (traces.isEmpty) {
      throw ArgumentError.value(traces, 'traces', 'must not be empty');
    }
    if (maxRows != null && maxRows < 1) {
      throw ArgumentError.value(maxRows, 'maxRows', 'must be at least 1');
    }
    final rows = [
      for (final trace in traces)
        (key: EvalTraceKey.fromTrace(trace), trace: trace),
    ]..sort((a, b) => a.key.id.compareTo(b.key.id));

    final seenKeys = <String>{};
    final judgeCalibrationSetVersions = <String>{};
    final candidates = <_CalibrationTemplateCandidate>[];
    final protectedScenarioIds =
        manifest?.scenarioCatalogEvidence?.protectedScenarioIds.toSet() ??
        const <String>{};
    for (final row in rows) {
      if (!seenKeys.add(row.key.id)) {
        throw ArgumentError('duplicate trace key: ${row.key.id}');
      }
      final trace = row.trace;
      final verdict = trace.verdict;
      if (verdict == null) {
        throw ArgumentError(
          'missing verdict for calibration template row ${row.key.id}',
        );
      }
      if (verdict.traceDigest == null) {
        throw ArgumentError(
          'missing verdict traceDigest for calibration template row '
          '${row.key.id}',
        );
      }
      final judgeCalibrationSetVersion = verdict.judge.calibrationSetVersion
          .trim();
      if (judgeCalibrationSetVersion.isEmpty) {
        throw ArgumentError(
          'missing judge calibrationSetVersion for calibration template row '
          '${row.key.id}',
        );
      }
      judgeCalibrationSetVersions.add(judgeCalibrationSetVersion);
      if (judgeCalibrationSetVersions.length > 1) {
        throw ArgumentError(
          'mixed judge calibrationSetVersion values in calibration template',
        );
      }
      final verdictDigest = EvalProvenance.digestJson(verdict.toJson());
      candidates.add(
        _CalibrationTemplateCandidate(
          key: row.key,
          trace: trace,
          verdict: verdict,
          verdictDigest: verdictDigest,
          protectedTrace: protectedScenarioIds.contains(trace.scenario.id),
        ),
      );
    }
    final selection = maxRows == null
        ? _CalibrationTemplateSelection.full(candidates)
        : _selectCalibrationTemplateCandidates(
            candidates: candidates,
            maxRows: maxRows,
          );
    final labels = [
      for (final candidate in selection.candidates)
        _labelTemplateRow(
          candidate: candidate,
          labeler: labeler,
          labelerCount: labelerCount,
        ),
    ];
    return <String, dynamic>{
      'calibrationTemplateSchemaVersion': _calibrationTemplateSchemaVersion,
      'version': version,
      'judgeCalibrationSetVersion': judgeCalibrationSetVersions.single,
      if (manifest != null) 'sourceRun': _sourceRunJson(manifest),
      if (selection.report != null)
        'calibrationTemplateSelection': selection.report!.toJson(),
      'labelTemplates': labels,
    };
  }

  static Map<String, dynamic> _labelTemplateRow({
    required _CalibrationTemplateCandidate candidate,
    required String labeler,
    required int labelerCount,
  }) {
    final trace = candidate.trace;
    return <String, dynamic>{
      'key': candidate.key.toJson(),
      'scenarioDigest': trace.provenance.scenarioDigest,
      'profileDigest': trace.provenance.profileDigest,
      'agentDirectiveVariantDigest':
          trace.provenance.agentDirectiveVariantDigest,
      'traceDigest': candidate.verdict.traceDigest,
      'verdictDigest': candidate.verdictDigest,
      'expectedPass': null,
      'goalAttainmentMin': null,
      'goalAttainmentMax': null,
      'qualityMin': null,
      'qualityMax': null,
      'efficiencyMin': null,
      'efficiencyMax': null,
      'labeler': labeler,
      'labelerCount': labelerCount,
      'adjudicationStatus': 'needs_review',
      'rationale': '',
    };
  }

  static Map<String, dynamic> _sourceRunJson(EvalRunManifest manifest) {
    return <String, dynamic>{
      'runId': manifest.runId,
      if (manifest.manifestDigest != null)
        'manifestDigest': manifest.manifestDigest,
      'scenarioSetDigest': manifest.scenarioSetDigest,
      'profileSetDigest': manifest.profileSetDigest,
      'agentDirectiveVariantSetDigest': manifest.agentDirectiveVariantSetDigest,
      'promptDigest': manifest.promptDigest,
      'toolSchemaDigest': manifest.toolSchemaDigest,
      'traceSchemaVersion': manifest.traceSchemaVersion,
      if (manifest.scenarioCatalogEvidence != null)
        'scenarioCatalogEvidence': _sourceRunCatalogEvidenceJson(
          manifest.scenarioCatalogEvidence!,
        ),
    };
  }

  static Map<String, dynamic> _sourceRunCatalogEvidenceJson(
    EvalScenarioCatalogEvidence evidence,
  ) {
    return <String, dynamic>{
      'scenarioSetDigest': evidence.scenarioSetDigest,
      'publicScenarioCount': evidence.publicScenarioCount,
      'externalScenarioCount': evidence.externalScenarioCount,
      if (evidence.externalCatalogDigest != null)
        'externalCatalogDigest': evidence.externalCatalogDigest,
      'protectedHoldout': evidence.protectedHoldout,
      'protectedScenarioCount': evidence.protectedScenarioIds.length,
      'protectedHoldoutScenarioCount':
          evidence.protectedHoldoutScenarioIds.length,
    };
  }

  static JudgeCalibrationReport evaluate({
    required List<EvalTrace> traces,
    required JudgeCalibrationSet calibrationSet,
  }) {
    final findings = <JudgeCalibrationFinding>[];
    final labelsByKey = <String, JudgeCalibrationLabel>{};
    for (final label in calibrationSet.labels) {
      label.validateCompleted();
      final previous = labelsByKey[label.key.id];
      if (previous != null) {
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.duplicateGoldLabel,
            key: label.key.id,
            detail: 'multiple calibration labels for trace key',
          ),
        );
        continue;
      }
      labelsByKey[label.key.id] = label;
    }

    final tracesByKey = <String, List<EvalTrace>>{};
    var judgedTraceCount = 0;
    for (final trace in traces) {
      tracesByKey
          .putIfAbsent(EvalTraceKey.fromTrace(trace).id, () => <EvalTrace>[])
          .add(trace);
      if (trace.verdict != null) judgedTraceCount++;
    }

    var evaluatedCount = 0;
    var staleLabelCount = 0;
    var missingTraceCount = 0;
    var missingVerdictCount = 0;
    var passAgreementCount = 0;
    var scoreAgreementCount = 0;
    var falsePassCount = 0;
    var falseFailCount = 0;
    var judgeCalibrationMismatchCount = 0;
    var humanReviewPairCount = 0;
    var humanPassAgreementPairCount = 0;
    var humanScoreAgreementPairCount = 0;
    var unresolvedHumanDisagreementCount = 0;
    var unblindedHumanReviewCount = 0;
    final capabilityAccumulators = <String, _CalibrationAccumulator>{};
    final modelClassAccumulators = <String, _CalibrationAccumulator>{};

    for (final label in labelsByKey.values) {
      final matches = tracesByKey[label.key.id] ?? const <EvalTrace>[];
      if (matches.isEmpty) {
        missingTraceCount++;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.missingTrace,
            key: label.key.id,
            detail: 'no trace found for calibration label',
          ),
        );
        continue;
      }
      if (matches.length != 1) {
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.duplicateTrace,
            key: label.key.id,
            detail: 'multiple traces found for calibration label',
          ),
        );
        continue;
      }

      final trace = matches.single;
      final capabilityId =
          trace.scenario.metadata.primaryCapabilityId ?? 'uncategorized';
      final modelClass = trace.profile.modelClass.name;
      final capability = capabilityAccumulators.putIfAbsent(
        capabilityId,
        () => _CalibrationAccumulator(capabilityId),
      );
      capability.labelCount++;
      final modelClassAccumulator = modelClassAccumulators.putIfAbsent(
        modelClass,
        () => _CalibrationAccumulator(modelClass),
      );
      modelClassAccumulator.labelCount++;

      final staleReasons = _staleLabelReasons(label: label, trace: trace);
      if (staleReasons.isNotEmpty) {
        staleLabelCount++;
        capability.staleLabelCount++;
        modelClassAccumulator.staleLabelCount++;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.staleGoldLabel,
            key: label.key.id,
            detail: staleReasons.join('; '),
          ),
        );
        continue;
      }

      final verdict = trace.verdict;
      if (verdict == null) {
        missingVerdictCount++;
        capability.missingVerdictCount++;
        modelClassAccumulator.missingVerdictCount++;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.missingVerdict,
            key: label.key.id,
            detail: 'trace has no judge verdict',
          ),
        );
        continue;
      }

      final traceDigest = label.traceDigest;
      if (traceDigest != null && traceDigest != verdict.traceDigest) {
        staleLabelCount++;
        capability.staleLabelCount++;
        modelClassAccumulator.staleLabelCount++;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.staleGoldLabel,
            key: label.key.id,
            detail:
                'trace digest mismatch: label=$traceDigest, '
                'verdict=${verdict.traceDigest ?? 'missing'}',
          ),
        );
        continue;
      }
      final verdictDigest = label.verdictDigest;
      if (verdictDigest != null) {
        final actualVerdictDigest = EvalProvenance.digestJson(verdict.toJson());
        if (verdictDigest != actualVerdictDigest) {
          staleLabelCount++;
          capability.staleLabelCount++;
          modelClassAccumulator.staleLabelCount++;
          findings.add(
            JudgeCalibrationFinding(
              kind: JudgeCalibrationFindingKind.staleGoldLabel,
              key: label.key.id,
              detail:
                  'verdict digest mismatch: label=$verdictDigest, '
                  'verdict=$actualVerdictDigest',
            ),
          );
          continue;
        }
      }
      if (verdict.judge.calibrationSetVersion !=
          calibrationSet.judgeCalibrationSetVersion) {
        judgeCalibrationMismatchCount++;
        capability.judgeCalibrationMismatchCount++;
        modelClassAccumulator.judgeCalibrationMismatchCount++;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.judgeCalibrationVersionMismatch,
            key: label.key.id,
            detail:
                'verdict calibration=${verdict.judge.calibrationSetVersion}, '
                'gold calibration=${calibrationSet.judgeCalibrationSetVersion}',
          ),
        );
        continue;
      }

      evaluatedCount++;
      capability.evaluatedCount++;
      modelClassAccumulator.evaluatedCount++;

      final passMatches = verdict.pass == label.expectedPass;
      final scoresMatch =
          _scoreWithinBand(
            actual: verdict.goalAttainment,
            min: label.goalAttainmentMin,
            max: label.goalAttainmentMax,
          ) &&
          _scoreWithinBand(
            actual: verdict.quality,
            min: label.qualityMin,
            max: label.qualityMax,
          ) &&
          _scoreWithinBand(
            actual: verdict.efficiency,
            min: label.efficiencyMin,
            max: label.efficiencyMax,
          );

      if (passMatches) {
        passAgreementCount++;
        capability.passAgreementCount++;
        modelClassAccumulator.passAgreementCount++;
      } else {
        if (verdict.pass && !label.expectedPass) {
          falsePassCount++;
          capability.falsePassCount++;
          modelClassAccumulator.falsePassCount++;
        } else if (!verdict.pass && label.expectedPass) {
          falseFailCount++;
          capability.falseFailCount++;
          modelClassAccumulator.falseFailCount++;
        }
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.passMismatch,
            key: label.key.id,
            detail:
                'judge pass=${verdict.pass}, human pass=${label.expectedPass}',
          ),
        );
      }
      if (scoresMatch) {
        scoreAgreementCount++;
        capability.scoreAgreementCount++;
        modelClassAccumulator.scoreAgreementCount++;
      } else {
        final scoreMismatchDetail = _scoreMismatchDetail(
          verdict: verdict,
          label: label,
        );
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.scoreMismatch,
            key: label.key.id,
            detail: scoreMismatchDetail,
          ),
        );
      }

      final humanReliability = _humanReliability(label);
      humanReviewPairCount += humanReliability.pairCount;
      humanPassAgreementPairCount += humanReliability.passAgreementPairCount;
      humanScoreAgreementPairCount += humanReliability.scoreAgreementPairCount;
      if (humanReliability.unresolvedDisagreement) {
        unresolvedHumanDisagreementCount++;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.unresolvedHumanDisagreement,
            key: label.key.id,
            detail:
                'independent human reviews disagree but label is not '
                'adjudicated',
          ),
        );
      }
      if (humanReliability.unblindedReviewCount > 0) {
        unblindedHumanReviewCount += humanReliability.unblindedReviewCount;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.unblindedHumanReview,
            key: label.key.id,
            detail:
                '${humanReliability.unblindedReviewCount} independent human '
                'review(s) missing blinding protocol flags',
          ),
        );
      }
    }

    var unlabeledVerdictCount = 0;
    var unblindedVerdictCount = 0;
    for (final trace in traces) {
      final verdict = trace.verdict;
      if (verdict == null) continue;
      final key = EvalTraceKey.fromTrace(trace).id;
      if (verdict.judge.modelIdentityVisible) {
        unblindedVerdictCount++;
        findings.add(
          JudgeCalibrationFinding(
            kind: JudgeCalibrationFindingKind.unblindedVerdict,
            key: key,
            detail: 'judge saw exact provider/model identity',
          ),
        );
      }
      if (labelsByKey.containsKey(key)) continue;
      unlabeledVerdictCount++;
      findings.add(
        JudgeCalibrationFinding(
          kind: JudgeCalibrationFindingKind.unlabeledVerdict,
          key: key,
          detail: 'judged trace is not covered by the calibration set',
        ),
      );
    }

    return JudgeCalibrationReport(
      calibrationSetVersion: calibrationSet.version,
      judgeCalibrationSetVersion: calibrationSet.judgeCalibrationSetVersion,
      labelCount: labelsByKey.length,
      judgedTraceCount: judgedTraceCount,
      evaluatedCount: evaluatedCount,
      staleLabelCount: staleLabelCount,
      missingTraceCount: missingTraceCount,
      missingVerdictCount: missingVerdictCount,
      unlabeledVerdictCount: unlabeledVerdictCount,
      falsePassCount: falsePassCount,
      falseFailCount: falseFailCount,
      unblindedVerdictCount: unblindedVerdictCount,
      judgeCalibrationMismatchCount: judgeCalibrationMismatchCount,
      passAgreementCount: passAgreementCount,
      scoreAgreementCount: scoreAgreementCount,
      humanReviewPairCount: humanReviewPairCount,
      humanPassAgreementPairCount: humanPassAgreementPairCount,
      humanScoreAgreementPairCount: humanScoreAgreementPairCount,
      unresolvedHumanDisagreementCount: unresolvedHumanDisagreementCount,
      unblindedHumanReviewCount: unblindedHumanReviewCount,
      capabilitySummaries: _summaries(capabilityAccumulators),
      modelClassSummaries: _summaries(modelClassAccumulators),
      findings: findings,
    );
  }

  static String render(JudgeCalibrationReport report) {
    final buffer = StringBuffer()
      ..writeln(
        'Judge calibration '
        '(${report.calibrationSetVersion}; '
        'judge=${report.judgeCalibrationSetVersion})',
      )
      ..writeln(
        'labels  judged  evaluated  coverage  stale  missing traces  '
        'missing verdicts  unlabeled  unblinded  false pass  false fail  '
        'cal mismatch  pass agree  score agree  human pairs  human pass  '
        'human score  unresolved human  unblinded human',
      )
      ..writeln(
        '------  ------  ---------  --------  -----  --------------  '
        '----------------  ---------  ---------  ----------  ----------  '
        '------------  ----------  -----------  -----------  ----------  '
        '-----------  ----------------  ---------------',
      )
      ..writeln(
        '${report.labelCount.toString().padLeft(6)}  '
        '${report.judgedTraceCount.toString().padLeft(6)}  '
        '${report.evaluatedCount.toString().padLeft(9)}  '
        '${_pct(report.goldCoverageRate).padLeft(8)}  '
        '${report.staleLabelCount.toString().padLeft(5)}  '
        '${report.missingTraceCount.toString().padLeft(14)}  '
        '${report.missingVerdictCount.toString().padLeft(16)}  '
        '${report.unlabeledVerdictCount.toString().padLeft(9)}  '
        '${report.unblindedVerdictCount.toString().padLeft(9)}  '
        '${report.falsePassCount.toString().padLeft(10)}  '
        '${report.falseFailCount.toString().padLeft(10)}  '
        '${report.judgeCalibrationMismatchCount.toString().padLeft(12)}  '
        '${_pct(report.passAgreementRate).padLeft(10)}  '
        '${_pct(report.scoreAgreementRate).padLeft(11)}  '
        '${report.humanReviewPairCount.toString().padLeft(11)}  '
        '${_pct(report.humanPassAgreementRate).padLeft(10)}  '
        '${_pct(report.humanScoreAgreementRate).padLeft(11)}  '
        '${report.unresolvedHumanDisagreementCount.toString().padLeft(16)}  '
        '${report.unblindedHumanReviewCount.toString().padLeft(15)}',
      );

    _renderSlices(buffer, 'Capability calibration', report.capabilitySummaries);
    _renderSlices(
      buffer,
      'Model-class calibration',
      report.modelClassSummaries,
    );
    if (report.findings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Calibration findings');
      for (final finding in report.findings) {
        buffer.writeln(
          '- ${finding.kind.name} ${finding.key}: ${finding.detail}',
        );
      }
    }
    return buffer.toString();
  }

  static bool _scoreWithinBand({
    required int actual,
    required int min,
    required int max,
  }) => min <= actual && actual <= max;

  static List<String> _staleLabelReasons({
    required JudgeCalibrationLabel label,
    required EvalTrace trace,
  }) {
    final reasons = <String>[];
    if (label.scenarioDigest != trace.provenance.scenarioDigest) {
      reasons.add(
        'scenario digest mismatch: label=${label.scenarioDigest}, '
        'trace=${trace.provenance.scenarioDigest}',
      );
    }
    if (label.profileDigest != trace.provenance.profileDigest) {
      reasons.add(
        'profile digest mismatch: label=${label.profileDigest}, '
        'trace=${trace.provenance.profileDigest}',
      );
    }
    if (label.agentDirectiveVariantDigest !=
        trace.provenance.agentDirectiveVariantDigest) {
      reasons.add(
        'agent directive variant digest mismatch: '
        'label=${label.agentDirectiveVariantDigest}, '
        'trace=${trace.provenance.agentDirectiveVariantDigest}',
      );
    }
    return reasons;
  }

  static String _scoreMismatchDetail({
    required JudgeVerdict verdict,
    required JudgeCalibrationLabel label,
  }) {
    final mismatches = <String>[];
    void addIfOutside(String name, int actual, int min, int max) {
      if (!_scoreWithinBand(actual: actual, min: min, max: max)) {
        mismatches.add('$name=$actual outside $min-$max');
      }
    }

    addIfOutside(
      'goalAttainment',
      verdict.goalAttainment,
      label.goalAttainmentMin,
      label.goalAttainmentMax,
    );
    addIfOutside(
      'quality',
      verdict.quality,
      label.qualityMin,
      label.qualityMax,
    );
    addIfOutside(
      'efficiency',
      verdict.efficiency,
      label.efficiencyMin,
      label.efficiencyMax,
    );
    return mismatches.join(', ');
  }

  static _HumanReviewReliability _humanReliability(
    JudgeCalibrationLabel label,
  ) {
    final reviews = label.independentReviews;
    if (reviews.length < 2) return const _HumanReviewReliability.empty();

    var pairCount = 0;
    var passAgreementPairCount = 0;
    var scoreAgreementPairCount = 0;
    for (var i = 0; i < reviews.length; i++) {
      for (var j = i + 1; j < reviews.length; j++) {
        final first = reviews[i];
        final second = reviews[j];
        pairCount++;
        if (first.expectedPass == second.expectedPass) {
          passAgreementPairCount++;
        }
        if (_humanReviewScoresAgree(first, second)) {
          scoreAgreementPairCount++;
        }
      }
    }

    return _HumanReviewReliability(
      pairCount: pairCount,
      passAgreementPairCount: passAgreementPairCount,
      scoreAgreementPairCount: scoreAgreementPairCount,
      unresolvedDisagreement:
          label.adjudicationStatus != 'adjudicated' &&
          reviews.any((review) => !_reviewMatchesGoldLabel(review, label)),
      unblindedReviewCount: reviews
          .where((review) => !review.fullyBlinded)
          .length,
    );
  }

  static bool _humanReviewScoresAgree(
    JudgeCalibrationHumanReview first,
    JudgeCalibrationHumanReview second,
  ) {
    return (first.goalAttainment - second.goalAttainment).abs() <= 1 &&
        (first.quality - second.quality).abs() <= 1 &&
        (first.efficiency - second.efficiency).abs() <= 1;
  }

  static bool _reviewMatchesGoldLabel(
    JudgeCalibrationHumanReview review,
    JudgeCalibrationLabel label,
  ) {
    return review.expectedPass == label.expectedPass &&
        _scoreWithinBand(
          actual: review.goalAttainment,
          min: label.goalAttainmentMin,
          max: label.goalAttainmentMax,
        ) &&
        _scoreWithinBand(
          actual: review.quality,
          min: label.qualityMin,
          max: label.qualityMax,
        ) &&
        _scoreWithinBand(
          actual: review.efficiency,
          min: label.efficiencyMin,
          max: label.efficiencyMax,
        );
  }

  static List<JudgeCalibrationSliceSummary> _summaries(
    Map<String, _CalibrationAccumulator> accumulators,
  ) {
    final summaries = [
      for (final accumulator in accumulators.values)
        JudgeCalibrationSliceSummary(
          name: accumulator.name,
          labelCount: accumulator.labelCount,
          evaluatedCount: accumulator.evaluatedCount,
          staleLabelCount: accumulator.staleLabelCount,
          missingTraceCount: accumulator.missingTraceCount,
          missingVerdictCount: accumulator.missingVerdictCount,
          falsePassCount: accumulator.falsePassCount,
          falseFailCount: accumulator.falseFailCount,
          judgeCalibrationMismatchCount:
              accumulator.judgeCalibrationMismatchCount,
          passAgreementCount: accumulator.passAgreementCount,
          scoreAgreementCount: accumulator.scoreAgreementCount,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return summaries;
  }

  static void _renderSlices(
    StringBuffer buffer,
    String title,
    List<JudgeCalibrationSliceSummary> summaries,
  ) {
    if (summaries.isEmpty) return;
    buffer
      ..writeln()
      ..writeln(title)
      ..writeln(
        'name                               labels  eval  stale  '
        'missing verdicts  false pass  false fail  cal mismatch  '
        'pass agree  score agree',
      )
      ..writeln(
        '---------------------------------  ------  ----  -----  '
        '----------------  ----------  ----------  ------------  '
        '----------  -----------',
      );
    for (final summary in summaries) {
      buffer.writeln(
        '${_clip(summary.name, 33).padRight(33)}  '
        '${summary.labelCount.toString().padLeft(6)}  '
        '${summary.evaluatedCount.toString().padLeft(4)}  '
        '${summary.staleLabelCount.toString().padLeft(5)}  '
        '${summary.missingVerdictCount.toString().padLeft(16)}  '
        '${summary.falsePassCount.toString().padLeft(10)}  '
        '${summary.falseFailCount.toString().padLeft(10)}  '
        '${summary.judgeCalibrationMismatchCount.toString().padLeft(12)}  '
        '${_pct(summary.passAgreementRate).padLeft(10)}  '
        '${_pct(summary.scoreAgreementRate).padLeft(11)}',
      );
    }
  }

  static String _pct(double value) => '${(value * 100).round()}%';

  static String _clip(String value, int width) {
    if (value.length <= width) return value;
    return value.substring(0, width - 1);
  }
}

class _CalibrationTemplateCandidate {
  const _CalibrationTemplateCandidate({
    required this.key,
    required this.trace,
    required this.verdict,
    required this.verdictDigest,
    required this.protectedTrace,
  });

  final EvalTraceKey key;
  final EvalTrace trace;
  final JudgeVerdict verdict;
  final String verdictDigest;
  final bool protectedTrace;

  String get sortKey => key.id;

  Set<String> get requiredStrata => <String>{
    'agentKind:${trace.scenario.agentKind.name}',
    'modelClass:${trace.profile.modelClass.name}',
    'promptVariant:${trace.agentDirectiveVariant.name}',
    'verdict:${verdict.pass ? 'pass' : 'fail'}',
    'protection:${protectedTrace ? 'protected' : 'nonProtected'}',
    'primaryCapability:${trace.scenario.metadata.primaryCapabilityId ?? 'uncategorized'}',
  };
}

class _HumanReviewReliability {
  const _HumanReviewReliability({
    required this.pairCount,
    required this.passAgreementPairCount,
    required this.scoreAgreementPairCount,
    required this.unresolvedDisagreement,
    required this.unblindedReviewCount,
  });

  const _HumanReviewReliability.empty()
    : pairCount = 0,
      passAgreementPairCount = 0,
      scoreAgreementPairCount = 0,
      unresolvedDisagreement = false,
      unblindedReviewCount = 0;

  final int pairCount;
  final int passAgreementPairCount;
  final int scoreAgreementPairCount;
  final bool unresolvedDisagreement;
  final int unblindedReviewCount;
}

class _CalibrationTemplateSelection {
  const _CalibrationTemplateSelection({
    required this.candidates,
    this.report,
  });

  factory _CalibrationTemplateSelection.full(
    List<_CalibrationTemplateCandidate> candidates,
  ) => _CalibrationTemplateSelection(candidates: candidates);

  final List<_CalibrationTemplateCandidate> candidates;
  final _CalibrationTemplateSelectionReport? report;
}

class _CalibrationTemplateSelectionReport {
  const _CalibrationTemplateSelectionReport({
    required this.policy,
    required this.maxRows,
    required this.candidateTraceCount,
    required this.selectedTraceCount,
    required this.omittedTraceCount,
    required this.requiredCoverageRows,
    required this.candidateSetDigest,
    required this.selectedKeyDigest,
    required this.candidateCoverage,
    required this.selectedCoverage,
    required this.candidateCrossCellCoverage,
    required this.selectedCrossCellCoverage,
  });

  final String policy;
  final int maxRows;
  final int candidateTraceCount;
  final int selectedTraceCount;
  final int omittedTraceCount;
  final int requiredCoverageRows;
  final String candidateSetDigest;
  final String selectedKeyDigest;
  final Map<String, int> candidateCoverage;
  final Map<String, int> selectedCoverage;
  final Map<String, int> candidateCrossCellCoverage;
  final Map<String, int> selectedCrossCellCoverage;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': 1,
    'policy': policy,
    'maxRows': maxRows,
    'candidateTraceCount': candidateTraceCount,
    'selectedTraceCount': selectedTraceCount,
    'omittedTraceCount': omittedTraceCount,
    'requiredCoverageRows': requiredCoverageRows,
    'candidateSetDigest': candidateSetDigest,
    'selectedKeyDigest': selectedKeyDigest,
    'candidateCoverage': candidateCoverage,
    'selectedCoverage': selectedCoverage,
    'candidateCrossCellCoverage': candidateCrossCellCoverage,
    'selectedCrossCellCoverage': selectedCrossCellCoverage,
  };
}

_CalibrationTemplateSelection _selectCalibrationTemplateCandidates({
  required List<_CalibrationTemplateCandidate> candidates,
  required int maxRows,
}) {
  final sorted = [...candidates]
    ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  final requiredStrata = <String>{
    for (final candidate in sorted) ...candidate.requiredStrata,
  };
  final selected = <_CalibrationTemplateCandidate>[];
  final selectedKeys = <String>{};
  final covered = <String>{};

  void addCandidate(_CalibrationTemplateCandidate candidate) {
    selected.add(candidate);
    selectedKeys.add(candidate.sortKey);
    covered.addAll(candidate.requiredStrata);
  }

  while (!covered.containsAll(requiredStrata)) {
    if (selected.length >= maxRows) {
      final missing = requiredStrata.difference(covered);
      throw ArgumentError(
        'maxRows $maxRows is too small for calibration template '
        '$_calibrationTemplateSelectionPolicy coverage; missing '
        '${_strataFamilyCounts(missing)}',
      );
    }
    final token = (requiredStrata.difference(covered).toList()..sort()).first;
    final eligible = sorted
        .where(
          (candidate) =>
              !selectedKeys.contains(candidate.sortKey) &&
              candidate.requiredStrata.contains(token),
        )
        .toList();
    if (eligible.isEmpty) {
      throw StateError('No calibration candidate covers required stratum');
    }
    eligible.sort((a, b) {
      final aCoverage = a.requiredStrata
          .intersection(
            requiredStrata.difference(covered),
          )
          .length;
      final bCoverage = b.requiredStrata
          .intersection(
            requiredStrata.difference(covered),
          )
          .length;
      final byCoverage = bCoverage.compareTo(aCoverage);
      if (byCoverage != 0) return byCoverage;
      return a.sortKey.compareTo(b.sortKey);
    });
    addCandidate(eligible.first);
  }

  final requiredCoverageRows = selected.length;
  for (final candidate in sorted) {
    if (selected.length >= maxRows) break;
    if (selectedKeys.contains(candidate.sortKey)) continue;
    addCandidate(candidate);
  }

  return _CalibrationTemplateSelection(
    candidates: selected,
    report: _CalibrationTemplateSelectionReport(
      policy: _calibrationTemplateSelectionPolicy,
      maxRows: maxRows,
      candidateTraceCount: candidates.length,
      selectedTraceCount: selected.length,
      omittedTraceCount: candidates.length - selected.length,
      requiredCoverageRows: requiredCoverageRows,
      candidateSetDigest: _keyDigest(candidates),
      selectedKeyDigest: _keyDigest(selected),
      candidateCoverage: _coverageCounts(candidates),
      selectedCoverage: _coverageCounts(selected),
      candidateCrossCellCoverage: _crossCellCoverageCounts(candidates),
      selectedCrossCellCoverage: _crossCellCoverageCounts(selected),
    ),
  );
}

Map<String, int> _coverageCounts(
  Iterable<_CalibrationTemplateCandidate> candidates,
) {
  final agentKinds = <String>{};
  final modelClasses = <String>{};
  final promptVariants = <String>{};
  final verdictOutcomes = <String>{};
  final protectionBuckets = <String>{};
  final primaryCapabilities = <String>{};
  for (final candidate in candidates) {
    agentKinds.add(candidate.trace.scenario.agentKind.name);
    modelClasses.add(candidate.trace.profile.modelClass.name);
    promptVariants.add(candidate.trace.agentDirectiveVariant.name);
    verdictOutcomes.add(candidate.verdict.pass ? 'pass' : 'fail');
    protectionBuckets.add(
      candidate.protectedTrace ? 'protected' : 'nonProtected',
    );
    primaryCapabilities.add(
      candidate.trace.scenario.metadata.primaryCapabilityId ?? 'uncategorized',
    );
  }
  return <String, int>{
    'agentKinds': agentKinds.length,
    'modelClasses': modelClasses.length,
    'promptVariants': promptVariants.length,
    'verdictOutcomes': verdictOutcomes.length,
    'protectionBuckets': protectionBuckets.length,
    'primaryCapabilities': primaryCapabilities.length,
  };
}

Map<String, int> _crossCellCoverageCounts(
  Iterable<_CalibrationTemplateCandidate> candidates,
) {
  final agentKindByVerdict = <String>{};
  final modelClassByVerdict = <String>{};
  final protectionByVerdict = <String>{};
  for (final candidate in candidates) {
    final verdict = candidate.verdict.pass ? 'pass' : 'fail';
    agentKindByVerdict.add(
      '${candidate.trace.scenario.agentKind.name}:$verdict',
    );
    modelClassByVerdict.add(
      '${candidate.trace.profile.modelClass.name}:$verdict',
    );
    protectionByVerdict.add(
      '${candidate.protectedTrace ? 'protected' : 'nonProtected'}:$verdict',
    );
  }
  return <String, int>{
    'agentKindByVerdict': agentKindByVerdict.length,
    'modelClassByVerdict': modelClassByVerdict.length,
    'protectionByVerdict': protectionByVerdict.length,
  };
}

String _keyDigest(Iterable<_CalibrationTemplateCandidate> candidates) {
  final keys = [
    for (final candidate in candidates) candidate.sortKey,
  ]..sort();
  return EvalProvenance.digestJson(keys);
}

Map<String, int> _strataFamilyCounts(Iterable<String> strata) {
  final counts = <String, int>{};
  for (final stratum in strata) {
    final separator = stratum.indexOf(':');
    final family = separator == -1 ? stratum : stratum.substring(0, separator);
    counts[family] = (counts[family] ?? 0) + 1;
  }
  return Map<String, int>.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

class _CalibrationAccumulator {
  _CalibrationAccumulator(this.name);

  final String name;
  int labelCount = 0;
  int evaluatedCount = 0;
  int staleLabelCount = 0;
  int missingTraceCount = 0;
  int missingVerdictCount = 0;
  int falsePassCount = 0;
  int falseFailCount = 0;
  int judgeCalibrationMismatchCount = 0;
  int passAgreementCount = 0;
  int scoreAgreementCount = 0;
}

int _scoreMin(Map<String, dynamic> json, String scoreName) {
  final explicit = json['${scoreName}Min'];
  if (explicit != null) return (explicit as num).toInt();
  final exact = json[scoreName];
  if (exact == null) {
    throw FormatException('Missing ${scoreName}Min/$scoreName');
  }
  final tolerance = (json['scoreTolerance'] as num?)?.toInt() ?? 0;
  return _clampScore((exact as num).toInt() - tolerance);
}

int _scoreMax(Map<String, dynamic> json, String scoreName) {
  final explicit = json['${scoreName}Max'];
  if (explicit != null) return (explicit as num).toInt();
  final exact = json[scoreName];
  if (exact == null) {
    throw FormatException('Missing ${scoreName}Max/$scoreName');
  }
  final tolerance = (json['scoreTolerance'] as num?)?.toInt() ?? 0;
  return _clampScore((exact as num).toInt() + tolerance);
}

int _clampScore(int value) {
  if (value < 1) return 1;
  if (value > 5) return 5;
  return value;
}

void _validateScoreBand({
  required String label,
  required int min,
  required int max,
}) {
  if (min < 1 || min > 5 || max < 1 || max > 5 || min > max) {
    throw FormatException('Invalid $label score band: $min-$max');
  }
}

void _validateScore({
  required String label,
  required int value,
}) {
  if (value < 1 || value > 5) {
    throw FormatException('Invalid $label score: $value');
  }
}

void _validateDigest({
  required String label,
  required String value,
}) {
  if (!_sha256DigestPattern.hasMatch(value)) {
    throw FormatException('Invalid $label digest: $value');
  }
}

final _sha256DigestPattern = RegExp(r'^sha256:[0-9a-f]{64}$');
