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
    _rejectUnknownFields(json, 'independentReviews[]', const {
      'reviewer',
      'expectedPass',
      'goalAttainment',
      'quality',
      'efficiency',
      'blindToJudgeVerdict',
      'blindToModelIdentity',
      'blindToPeerVotes',
    });
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

  factory EvalTraceKey.fromJson(Map<String, dynamic> json) {
    _rejectUnknownFields(json, 'key', const {
      'scenarioId',
      'profileName',
      'agentDirectiveVariantName',
      'trialIndex',
      'cascadeWake',
    });
    final rawCascadeWake = json['cascadeWake'];
    final rawCascadeWakeJson = rawCascadeWake == null
        ? null
        : rawCascadeWake as Map<String, dynamic>;
    if (rawCascadeWake != null) {
      _rejectUnknownFields(
        rawCascadeWakeJson!,
        'key.cascadeWake',
        const {
          'cascadeId',
          'wakeIndex',
          'wakeCount',
        },
      );
    }
    return EvalTraceKey(
      scenarioId: json['scenarioId'] as String,
      profileName: json['profileName'] as String,
      agentDirectiveVariantName:
          (json['agentDirectiveVariantName'] as String?) ??
          const EvalAgentDirectiveVariant().name,
      trialIndex: (json['trialIndex'] as num).toInt(),
      cascadeWake: rawCascadeWakeJson == null
          ? null
          : EvalTraceCascadeWake.fromJson(
              rawCascadeWakeJson,
            ),
    );
  }

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
    _rejectUnknownFields(json, 'labels[]', const {
      'key',
      'scenarioDigest',
      'profileDigest',
      'agentDirectiveVariantDigest',
      'traceDigest',
      'verdictDigest',
      'expectedPass',
      'goalAttainmentMin',
      'goalAttainmentMax',
      'qualityMin',
      'qualityMax',
      'efficiencyMin',
      'efficiencyMax',
      'goalAttainment',
      'quality',
      'efficiency',
      'scoreTolerance',
      'labeler',
      'labelerCount',
      'adjudicationStatus',
      'rationale',
      'independentReviews',
    });
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

/// Non-secret run envelope copied from a generated human-label template.
///
/// This binds a completed calibration set to the manifest and catalog bundle
/// that produced the trace/verdict artifacts under review, without copying raw
/// trace payloads or protected scenario ids into the label file.
class JudgeCalibrationSourceRun {
  const JudgeCalibrationSourceRun({
    required this.runId,
    required this.scenarioSetDigest,
    required this.profileSetDigest,
    required this.agentDirectiveVariantSetDigest,
    required this.promptDigest,
    required this.toolSchemaDigest,
    required this.traceSchemaVersion,
    this.manifestDigest,
    this.scenarioCatalogEvidence,
  });

  factory JudgeCalibrationSourceRun.fromManifest(EvalRunManifest manifest) {
    return JudgeCalibrationSourceRun(
      runId: manifest.runId,
      manifestDigest: manifest.manifestDigest,
      scenarioSetDigest: manifest.scenarioSetDigest,
      profileSetDigest: manifest.profileSetDigest,
      agentDirectiveVariantSetDigest: manifest.agentDirectiveVariantSetDigest,
      promptDigest: manifest.promptDigest,
      toolSchemaDigest: manifest.toolSchemaDigest,
      traceSchemaVersion: manifest.traceSchemaVersion,
      scenarioCatalogEvidence: manifest.scenarioCatalogEvidence == null
          ? null
          : JudgeCalibrationSourceRunCatalogEvidence.fromCatalogEvidence(
              manifest.scenarioCatalogEvidence!,
            ),
    );
  }

  factory JudgeCalibrationSourceRun.fromJson(Map<String, dynamic> json) {
    _rejectUnknownFields(json, 'sourceRun', const {
      'runId',
      'manifestDigest',
      'scenarioSetDigest',
      'profileSetDigest',
      'agentDirectiveVariantSetDigest',
      'promptDigest',
      'toolSchemaDigest',
      'traceSchemaVersion',
      'scenarioCatalogEvidence',
    });
    final sourceRun = JudgeCalibrationSourceRun(
      runId: _requiredSourceString(json, 'runId'),
      manifestDigest: _optionalSourceString(json, 'manifestDigest'),
      scenarioSetDigest: _requiredSourceString(json, 'scenarioSetDigest'),
      profileSetDigest: _requiredSourceString(json, 'profileSetDigest'),
      agentDirectiveVariantSetDigest: _requiredSourceString(
        json,
        'agentDirectiveVariantSetDigest',
      ),
      promptDigest: _requiredSourceString(json, 'promptDigest'),
      toolSchemaDigest: _requiredSourceString(json, 'toolSchemaDigest'),
      traceSchemaVersion: _requiredSourceInt(json, 'traceSchemaVersion'),
      scenarioCatalogEvidence: json['scenarioCatalogEvidence'] == null
          ? null
          : JudgeCalibrationSourceRunCatalogEvidence.fromJson(
              json['scenarioCatalogEvidence'] as Map<String, dynamic>,
            ),
    )..validate();
    return sourceRun;
  }

  final String runId;
  final String? manifestDigest;
  final String scenarioSetDigest;
  final String profileSetDigest;
  final String agentDirectiveVariantSetDigest;
  final String promptDigest;
  final String toolSchemaDigest;
  final int traceSchemaVersion;
  final JudgeCalibrationSourceRunCatalogEvidence? scenarioCatalogEvidence;

  void validate() {
    if (runId.trim().isEmpty) {
      throw const FormatException('sourceRun.runId must not be empty');
    }
    final manifestDigest = this.manifestDigest;
    if (manifestDigest != null) {
      _validateDigest(label: 'sourceRun.manifestDigest', value: manifestDigest);
    }
    _validateDigest(
      label: 'sourceRun.scenarioSetDigest',
      value: scenarioSetDigest,
    );
    _validateDigest(
      label: 'sourceRun.profileSetDigest',
      value: profileSetDigest,
    );
    _validateDigest(
      label: 'sourceRun.agentDirectiveVariantSetDigest',
      value: agentDirectiveVariantSetDigest,
    );
    _validateDigest(label: 'sourceRun.promptDigest', value: promptDigest);
    _validateDigest(
      label: 'sourceRun.toolSchemaDigest',
      value: toolSchemaDigest,
    );
    if (traceSchemaVersion < 1) {
      throw const FormatException(
        'sourceRun.traceSchemaVersion must be at least 1',
      );
    }
    scenarioCatalogEvidence?.validate();
  }

  List<String> validateManifestBinding(EvalRunManifest? manifest) {
    if (manifest == null) {
      return const [
        'calibration sourceRun cannot be checked without run manifest',
      ];
    }
    final failures = <String>[];
    void compare(String field, Object? actual, Object? expected) {
      if (actual == expected) return;
      failures.add(
        'calibration sourceRun $field is $actual, expected $expected',
      );
    }

    compare('runId', runId, manifest.runId);
    final manifestDigest = this.manifestDigest;
    if (manifestDigest == null) {
      failures.add('calibration sourceRun manifestDigest is missing');
    } else {
      compare('manifestDigest', manifestDigest, manifest.manifestDigest);
    }
    compare('scenarioSetDigest', scenarioSetDigest, manifest.scenarioSetDigest);
    compare('profileSetDigest', profileSetDigest, manifest.profileSetDigest);
    compare(
      'agentDirectiveVariantSetDigest',
      agentDirectiveVariantSetDigest,
      manifest.agentDirectiveVariantSetDigest,
    );
    compare('promptDigest', promptDigest, manifest.promptDigest);
    compare('toolSchemaDigest', toolSchemaDigest, manifest.toolSchemaDigest);
    compare(
      'traceSchemaVersion',
      traceSchemaVersion,
      manifest.traceSchemaVersion,
    );

    final expectedCatalogEvidence = manifest.scenarioCatalogEvidence == null
        ? null
        : JudgeCalibrationSourceRunCatalogEvidence.fromCatalogEvidence(
            manifest.scenarioCatalogEvidence!,
          );
    final actualCatalogEvidence = scenarioCatalogEvidence;
    if (expectedCatalogEvidence == null) {
      if (actualCatalogEvidence != null) {
        failures.add(
          'calibration sourceRun scenarioCatalogEvidence is present but '
          'manifest has none',
        );
      }
    } else if (actualCatalogEvidence == null) {
      failures.add('calibration sourceRun scenarioCatalogEvidence is missing');
    } else {
      failures.addAll(
        actualCatalogEvidence.validateBinding(expectedCatalogEvidence),
      );
    }
    return failures;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'runId': runId,
    if (manifestDigest != null) 'manifestDigest': manifestDigest,
    'scenarioSetDigest': scenarioSetDigest,
    'profileSetDigest': profileSetDigest,
    'agentDirectiveVariantSetDigest': agentDirectiveVariantSetDigest,
    'promptDigest': promptDigest,
    'toolSchemaDigest': toolSchemaDigest,
    'traceSchemaVersion': traceSchemaVersion,
    if (scenarioCatalogEvidence != null)
      'scenarioCatalogEvidence': scenarioCatalogEvidence!.toJson(),
  };
}

class JudgeCalibrationSourceRunCatalogEvidence {
  const JudgeCalibrationSourceRunCatalogEvidence({
    required this.scenarioSetDigest,
    required this.publicScenarioCount,
    required this.externalScenarioCount,
    required this.protectedHoldout,
    required this.protectedScenarioCount,
    required this.protectedHoldoutScenarioCount,
    this.externalCatalogDigest,
  });

  factory JudgeCalibrationSourceRunCatalogEvidence.fromCatalogEvidence(
    EvalScenarioCatalogEvidence evidence,
  ) {
    return JudgeCalibrationSourceRunCatalogEvidence(
      scenarioSetDigest: evidence.scenarioSetDigest,
      publicScenarioCount: evidence.publicScenarioCount,
      externalScenarioCount: evidence.externalScenarioCount,
      externalCatalogDigest: evidence.externalCatalogDigest,
      protectedHoldout: evidence.protectedHoldout,
      protectedScenarioCount: evidence.protectedScenarioIds.length,
      protectedHoldoutScenarioCount:
          evidence.protectedHoldoutScenarioIds.length,
    );
  }

  factory JudgeCalibrationSourceRunCatalogEvidence.fromJson(
    Map<String, dynamic> json,
  ) {
    _rejectUnknownFields(json, 'sourceRun.scenarioCatalogEvidence', const {
      'scenarioSetDigest',
      'publicScenarioCount',
      'externalScenarioCount',
      'externalCatalogDigest',
      'protectedHoldout',
      'protectedScenarioCount',
      'protectedHoldoutScenarioCount',
    });
    final evidence = JudgeCalibrationSourceRunCatalogEvidence(
      scenarioSetDigest: _requiredSourceString(json, 'scenarioSetDigest'),
      publicScenarioCount: _requiredSourceInt(json, 'publicScenarioCount'),
      externalScenarioCount: _requiredSourceInt(json, 'externalScenarioCount'),
      externalCatalogDigest: _optionalSourceString(
        json,
        'externalCatalogDigest',
      ),
      protectedHoldout: json['protectedHoldout'] as bool,
      protectedScenarioCount: _requiredSourceInt(
        json,
        'protectedScenarioCount',
      ),
      protectedHoldoutScenarioCount: _requiredSourceInt(
        json,
        'protectedHoldoutScenarioCount',
      ),
    )..validate();
    return evidence;
  }

  final String scenarioSetDigest;
  final int publicScenarioCount;
  final int externalScenarioCount;
  final String? externalCatalogDigest;
  final bool protectedHoldout;
  final int protectedScenarioCount;
  final int protectedHoldoutScenarioCount;

  void validate() {
    _validateDigest(
      label: 'sourceRun.scenarioCatalogEvidence.scenarioSetDigest',
      value: scenarioSetDigest,
    );
    final externalCatalogDigest = this.externalCatalogDigest;
    if (externalCatalogDigest != null) {
      _validateDigest(
        label: 'sourceRun.scenarioCatalogEvidence.externalCatalogDigest',
        value: externalCatalogDigest,
      );
    }
    void nonNegative(String field, int value) {
      if (value < 0) {
        throw FormatException(
          'sourceRun.scenarioCatalogEvidence.$field must be at least 0',
        );
      }
    }

    nonNegative('publicScenarioCount', publicScenarioCount);
    nonNegative('externalScenarioCount', externalScenarioCount);
    nonNegative('protectedScenarioCount', protectedScenarioCount);
    nonNegative(
      'protectedHoldoutScenarioCount',
      protectedHoldoutScenarioCount,
    );
  }

  List<String> validateBinding(
    JudgeCalibrationSourceRunCatalogEvidence expected,
  ) {
    final failures = <String>[];
    void compare(String field, Object? actual, Object? expectedValue) {
      if (actual == expectedValue) return;
      failures.add(
        'calibration sourceRun scenarioCatalogEvidence.$field is $actual, '
        'expected $expectedValue',
      );
    }

    compare('scenarioSetDigest', scenarioSetDigest, expected.scenarioSetDigest);
    compare(
      'publicScenarioCount',
      publicScenarioCount,
      expected.publicScenarioCount,
    );
    compare(
      'externalScenarioCount',
      externalScenarioCount,
      expected.externalScenarioCount,
    );
    compare(
      'externalCatalogDigest',
      externalCatalogDigest,
      expected.externalCatalogDigest,
    );
    compare('protectedHoldout', protectedHoldout, expected.protectedHoldout);
    compare(
      'protectedScenarioCount',
      protectedScenarioCount,
      expected.protectedScenarioCount,
    );
    compare(
      'protectedHoldoutScenarioCount',
      protectedHoldoutScenarioCount,
      expected.protectedHoldoutScenarioCount,
    );
    return failures;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scenarioSetDigest': scenarioSetDigest,
    'publicScenarioCount': publicScenarioCount,
    'externalScenarioCount': externalScenarioCount,
    if (externalCatalogDigest != null)
      'externalCatalogDigest': externalCatalogDigest,
    'protectedHoldout': protectedHoldout,
    'protectedScenarioCount': protectedScenarioCount,
    'protectedHoldoutScenarioCount': protectedHoldoutScenarioCount,
  };
}

/// Digest-bound provenance for a bounded calibration template selection.
///
/// This is copied from `calibrationTemplateSelection` when humans complete a
/// sampled label template. It contains only counts and digests, not trace text
/// or protected scenario ids.
class JudgeCalibrationTemplateSelectionEvidence {
  const JudgeCalibrationTemplateSelectionEvidence({
    required this.templateSchemaVersion,
    required this.policy,
    required this.maxRows,
    required this.sourceRunDigest,
    required this.sourceTemplateDigest,
    required this.selectedTemplateRowsDigest,
    required this.candidateTraceMaterialDigest,
    required this.templateMetadataDigest,
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

  factory JudgeCalibrationTemplateSelectionEvidence.fromJson(
    Map<String, dynamic> json,
  ) {
    final unknown = json.keys.where(
      (key) => !const {
        'schemaVersion',
        'templateSchemaVersion',
        'policy',
        'maxRows',
        'sourceRunDigest',
        'sourceTemplateDigest',
        'selectedTemplateRowsDigest',
        'candidateTraceMaterialDigest',
        'templateMetadataDigest',
        'candidateTraceCount',
        'selectedTraceCount',
        'omittedTraceCount',
        'requiredCoverageRows',
        'candidateSetDigest',
        'selectedKeyDigest',
        'candidateCoverage',
        'selectedCoverage',
        'candidateCrossCellCoverage',
        'selectedCrossCellCoverage',
      }.contains(key),
    );
    if (unknown.isNotEmpty) {
      throw FormatException(
        'calibrationTemplateSelection has unsupported field ${unknown.first}',
      );
    }
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != 1) {
      throw FormatException(
        'calibrationTemplateSelection schemaVersion must be 1, got '
        '$schemaVersion',
      );
    }
    final evidence = JudgeCalibrationTemplateSelectionEvidence(
      templateSchemaVersion: _requiredSourceInt(
        json,
        'templateSchemaVersion',
      ),
      policy: _requiredSourceString(json, 'policy'),
      maxRows: _requiredSourceInt(json, 'maxRows'),
      sourceRunDigest: _requiredSourceString(json, 'sourceRunDigest'),
      sourceTemplateDigest: _requiredSourceString(
        json,
        'sourceTemplateDigest',
      ),
      selectedTemplateRowsDigest: _requiredSourceString(
        json,
        'selectedTemplateRowsDigest',
      ),
      candidateTraceMaterialDigest: _requiredSourceString(
        json,
        'candidateTraceMaterialDigest',
      ),
      templateMetadataDigest: _requiredSourceString(
        json,
        'templateMetadataDigest',
      ),
      candidateTraceCount: _requiredSourceInt(json, 'candidateTraceCount'),
      selectedTraceCount: _requiredSourceInt(json, 'selectedTraceCount'),
      omittedTraceCount: _requiredSourceInt(json, 'omittedTraceCount'),
      requiredCoverageRows: _requiredSourceInt(json, 'requiredCoverageRows'),
      candidateSetDigest: _requiredSourceString(json, 'candidateSetDigest'),
      selectedKeyDigest: _requiredSourceString(json, 'selectedKeyDigest'),
      candidateCoverage: _intMap(
        json,
        'candidateCoverage',
        _coverageMapKeys,
      ),
      selectedCoverage: _intMap(json, 'selectedCoverage', _coverageMapKeys),
      candidateCrossCellCoverage: _intMap(
        json,
        'candidateCrossCellCoverage',
        _crossCellCoverageMapKeys,
      ),
      selectedCrossCellCoverage: _intMap(
        json,
        'selectedCrossCellCoverage',
        _crossCellCoverageMapKeys,
      ),
    )..validate();
    return evidence;
  }

  final int templateSchemaVersion;
  final String policy;
  final int maxRows;
  final String sourceRunDigest;
  final String sourceTemplateDigest;
  final String selectedTemplateRowsDigest;
  final String candidateTraceMaterialDigest;
  final String templateMetadataDigest;
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

  bool get sampled => selectedTraceCount < candidateTraceCount;

  void validate() {
    if (templateSchemaVersion != _calibrationTemplateSchemaVersion) {
      throw const FormatException(
        'calibrationTemplateSelection templateSchemaVersion must be '
        '$_calibrationTemplateSchemaVersion',
      );
    }
    if (policy != _calibrationTemplateSelectionPolicy) {
      throw const FormatException(
        'calibrationTemplateSelection policy must be '
        '$_calibrationTemplateSelectionPolicy',
      );
    }
    void nonNegative(String field, int value) {
      if (value < 0) {
        throw FormatException(
          'calibrationTemplateSelection.$field must be at least 0',
        );
      }
    }

    if (maxRows < 1) {
      throw const FormatException(
        'calibrationTemplateSelection.maxRows must be at least 1',
      );
    }
    nonNegative('candidateTraceCount', candidateTraceCount);
    nonNegative('selectedTraceCount', selectedTraceCount);
    nonNegative('omittedTraceCount', omittedTraceCount);
    nonNegative('requiredCoverageRows', requiredCoverageRows);
    if (selectedTraceCount > candidateTraceCount) {
      throw const FormatException(
        'calibrationTemplateSelection selectedTraceCount exceeds '
        'candidateTraceCount',
      );
    }
    if (omittedTraceCount != candidateTraceCount - selectedTraceCount) {
      throw const FormatException(
        'calibrationTemplateSelection omittedTraceCount must equal '
        'candidateTraceCount - selectedTraceCount',
      );
    }
    _validateDigest(
      label: 'calibrationTemplateSelection.sourceRunDigest',
      value: sourceRunDigest,
    );
    _validateDigest(
      label: 'calibrationTemplateSelection.sourceTemplateDigest',
      value: sourceTemplateDigest,
    );
    _validateDigest(
      label: 'calibrationTemplateSelection.selectedTemplateRowsDigest',
      value: selectedTemplateRowsDigest,
    );
    _validateDigest(
      label: 'calibrationTemplateSelection.candidateTraceMaterialDigest',
      value: candidateTraceMaterialDigest,
    );
    _validateDigest(
      label: 'calibrationTemplateSelection.templateMetadataDigest',
      value: templateMetadataDigest,
    );
    _validateDigest(
      label: 'calibrationTemplateSelection.candidateSetDigest',
      value: candidateSetDigest,
    );
    _validateDigest(
      label: 'calibrationTemplateSelection.selectedKeyDigest',
      value: selectedKeyDigest,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': 1,
    'templateSchemaVersion': templateSchemaVersion,
    'policy': policy,
    'maxRows': maxRows,
    'sourceRunDigest': sourceRunDigest,
    'sourceTemplateDigest': sourceTemplateDigest,
    'selectedTemplateRowsDigest': selectedTemplateRowsDigest,
    'candidateTraceMaterialDigest': candidateTraceMaterialDigest,
    'templateMetadataDigest': templateMetadataDigest,
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

  static const _coverageMapKeys = {
    'agentKinds',
    'modelClasses',
    'promptVariants',
    'verdictOutcomes',
    'protectionBuckets',
    'primaryCapabilities',
  };

  static const _crossCellCoverageMapKeys = {
    'agentKindByVerdict',
    'modelClassByVerdict',
    'protectionByVerdict',
    'modelClassByCapability',
    'protectionByCapability',
  };

  static Map<String, int> _intMap(
    Map<String, dynamic> json,
    String key,
    Set<String> allowedKeys,
  ) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw FormatException('calibrationTemplateSelection.$key must be a map');
    }
    final unknown = value.keys.where((mapKey) => !allowedKeys.contains(mapKey));
    if (unknown.isNotEmpty) {
      throw FormatException(
        'calibrationTemplateSelection.$key has unsupported key '
        '${unknown.first}',
      );
    }
    return {
      for (final entry in value.entries)
        entry.key: switch (entry.value) {
          final num count when count.isFinite && count == count.toInt() =>
            count.toInt(),
          _ => throw FormatException(
            'calibrationTemplateSelection.$key.${entry.key} must be an int',
          ),
        },
    };
  }
}

/// Versioned human-label set for judge calibration.
class JudgeCalibrationSet {
  const JudgeCalibrationSet({
    required this.version,
    required this.labels,
    String? judgeCalibrationSetVersion,
    this.sourceRun,
    this.templateSelection,
  }) : judgeCalibrationSetVersion = judgeCalibrationSetVersion ?? version;

  factory JudgeCalibrationSet.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('calibrationTemplateSchemaVersion') ||
        json.containsKey('labelTemplates')) {
      throw const FormatException(
        'Calibration template must be completed before calibrate can read it',
      );
    }
    _rejectUnknownFields(json, 'JudgeCalibrationSet', const {
      'version',
      'judgeCalibrationSetVersion',
      'sourceRun',
      'calibrationTemplateSelection',
      'labels',
    });
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
      sourceRun: json['sourceRun'] == null
          ? null
          : JudgeCalibrationSourceRun.fromJson(
              json['sourceRun'] as Map<String, dynamic>,
            ),
      templateSelection: json['calibrationTemplateSelection'] == null
          ? null
          : JudgeCalibrationTemplateSelectionEvidence.fromJson(
              json['calibrationTemplateSelection'] as Map<String, dynamic>,
            ),
      labels: rawLabels
          .map(
            (e) => JudgeCalibrationLabel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String version;
  final String judgeCalibrationSetVersion;
  final JudgeCalibrationSourceRun? sourceRun;
  final JudgeCalibrationTemplateSelectionEvidence? templateSelection;
  final List<JudgeCalibrationLabel> labels;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'judgeCalibrationSetVersion': judgeCalibrationSetVersion,
    if (sourceRun != null) 'sourceRun': sourceRun!.toJson(),
    if (templateSelection != null)
      'calibrationTemplateSelection': templateSelection!.toJson(),
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
    required this.modelClassCapabilitySummaries,
    required this.promptVariantSummaries,
    required this.modelClassPromptVariantSummaries,
    required this.findings,
    this.protectedHoldoutLabelCount = 0,
    this.protectedHoldoutEvaluatedCount = 0,
    this.protectedHoldoutCapabilitySummaries = const [],
    this.protectedHoldoutModelClassSummaries = const [],
    this.protectedHoldoutModelClassCapabilitySummaries = const [],
    this.protectedHoldoutPromptVariantSummaries = const [],
    this.protectedHoldoutModelClassPromptVariantSummaries = const [],
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
  final int protectedHoldoutLabelCount;
  final int protectedHoldoutEvaluatedCount;
  final int humanReviewPairCount;
  final int humanPassAgreementPairCount;
  final int humanScoreAgreementPairCount;
  final int unresolvedHumanDisagreementCount;
  final int unblindedHumanReviewCount;
  final List<JudgeCalibrationSliceSummary> capabilitySummaries;
  final List<JudgeCalibrationSliceSummary> modelClassSummaries;
  final List<JudgeCalibrationSliceSummary> modelClassCapabilitySummaries;
  final List<JudgeCalibrationSliceSummary> promptVariantSummaries;
  final List<JudgeCalibrationSliceSummary> modelClassPromptVariantSummaries;
  final List<JudgeCalibrationSliceSummary> protectedHoldoutCapabilitySummaries;
  final List<JudgeCalibrationSliceSummary> protectedHoldoutModelClassSummaries;
  final List<JudgeCalibrationSliceSummary>
  protectedHoldoutModelClassCapabilitySummaries;
  final List<JudgeCalibrationSliceSummary>
  protectedHoldoutPromptVariantSummaries;
  final List<JudgeCalibrationSliceSummary>
  protectedHoldoutModelClassPromptVariantSummaries;
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
    final sourceRunJson = manifest == null
        ? null
        : JudgeCalibrationSourceRun.fromManifest(manifest).toJson();
    final selectionReport = selection.report;
    if (selectionReport != null && sourceRunJson == null) {
      throw ArgumentError.value(
        manifest,
        'manifest',
        'bounded calibration templates require sourceRun manifest binding',
      );
    }
    return <String, dynamic>{
      'calibrationTemplateSchemaVersion': _calibrationTemplateSchemaVersion,
      'version': version,
      'judgeCalibrationSetVersion': judgeCalibrationSetVersions.single,
      'sourceRun': ?sourceRunJson,
      if (selectionReport != null)
        'calibrationTemplateSelection': _templateSelectionEvidenceJson(
          report: selectionReport,
          candidates: candidates,
          selectedCandidates: selection.candidates,
          sourceRunJson: sourceRunJson!,
          version: version,
          judgeCalibrationSetVersion: judgeCalibrationSetVersions.single,
        ),
      'labelTemplates': labels,
    };
  }

  static Map<String, dynamic> _templateSelectionEvidenceJson({
    required _CalibrationTemplateSelectionReport report,
    required List<_CalibrationTemplateCandidate> candidates,
    required List<_CalibrationTemplateCandidate> selectedCandidates,
    required Map<String, dynamic> sourceRunJson,
    required String version,
    required String judgeCalibrationSetVersion,
  }) {
    final sourceRunDigest = EvalProvenance.digestJson(sourceRunJson);
    final reportJson = report.toJson();
    final selectedTemplateRowsDigest = _selectedTemplateRowsDigest(
      selectedCandidates,
    );
    final candidateTraceMaterialDigest = _candidateTraceMaterialDigest(
      candidates,
    );
    final templateMetadataDigest = EvalProvenance.digestJson({
      'calibrationTemplateSchemaVersion': _calibrationTemplateSchemaVersion,
      'version': version,
      'judgeCalibrationSetVersion': judgeCalibrationSetVersion,
    });
    final sourceTemplateDigest = EvalProvenance.digestJson({
      'calibrationTemplateSchemaVersion': _calibrationTemplateSchemaVersion,
      'version': version,
      'judgeCalibrationSetVersion': judgeCalibrationSetVersion,
      'sourceRunDigest': sourceRunDigest,
      'selectedTemplateRowsDigest': selectedTemplateRowsDigest,
      'candidateTraceMaterialDigest': candidateTraceMaterialDigest,
      'templateMetadataDigest': templateMetadataDigest,
      'selection': reportJson,
    });
    return <String, dynamic>{
      ...reportJson,
      'templateSchemaVersion': _calibrationTemplateSchemaVersion,
      'sourceRunDigest': sourceRunDigest,
      'sourceTemplateDigest': sourceTemplateDigest,
      'selectedTemplateRowsDigest': selectedTemplateRowsDigest,
      'candidateTraceMaterialDigest': candidateTraceMaterialDigest,
      'templateMetadataDigest': templateMetadataDigest,
    };
  }

  static String _selectedTemplateRowsDigest(
    List<_CalibrationTemplateCandidate> candidates,
  ) => _candidateTraceMaterialDigest(candidates);

  static String _candidateTraceMaterialDigest(
    List<_CalibrationTemplateCandidate> candidates,
  ) => EvalProvenance.digestJson([
    for (final candidate in [
      ...candidates,
    ]..sort((a, b) => a.sortKey.compareTo(b.sortKey)))
      _candidateTraceMaterialJson(candidate),
  ]);

  static Map<String, dynamic> _candidateTraceMaterialJson(
    _CalibrationTemplateCandidate candidate,
  ) => <String, dynamic>{
    'key': candidate.key.toJson(),
    'scenarioDigest': candidate.trace.provenance.scenarioDigest,
    'profileDigest': candidate.trace.provenance.profileDigest,
    'agentDirectiveVariantDigest':
        candidate.trace.provenance.agentDirectiveVariantDigest,
    'traceDigest': candidate.verdict.traceDigest,
    'verdictDigest': candidate.verdictDigest,
    'judgeCalibrationSetVersion': candidate.verdict.judge.calibrationSetVersion,
  };

  static String _completedLabelTraceMaterialDigest({
    required List<JudgeCalibrationLabel> labels,
    required String judgeCalibrationSetVersion,
  }) => EvalProvenance.digestJson([
    for (final label in [
      ...labels,
    ]..sort((a, b) => a.key.id.compareTo(b.key.id)))
      _completedLabelTraceMaterialJson(
        label: label,
        judgeCalibrationSetVersion: judgeCalibrationSetVersion,
      ),
  ]);

  static Map<String, dynamic> _completedLabelTraceMaterialJson({
    required JudgeCalibrationLabel label,
    required String judgeCalibrationSetVersion,
  }) => <String, dynamic>{
    'key': label.key.toJson(),
    'scenarioDigest': label.scenarioDigest,
    'profileDigest': label.profileDigest,
    'agentDirectiveVariantDigest': label.agentDirectiveVariantDigest,
    'traceDigest': label.traceDigest,
    'verdictDigest': label.verdictDigest,
    'judgeCalibrationSetVersion': judgeCalibrationSetVersion,
  };

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

  static JudgeCalibrationReport evaluate({
    required List<EvalTrace> traces,
    required JudgeCalibrationSet calibrationSet,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
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
    var protectedHoldoutLabelCount = 0;
    var protectedHoldoutEvaluatedCount = 0;
    final protectedHoldoutScenarioIds =
        scenarioCatalogEvidence?.protectedHoldoutScenarioIds.toSet() ??
        const <String>{};
    final capabilityAccumulators = <String, _CalibrationAccumulator>{};
    final modelClassAccumulators = <String, _CalibrationAccumulator>{};
    final modelClassCapabilityAccumulators =
        <String, _CalibrationAccumulator>{};
    final promptVariantAccumulators = <String, _CalibrationAccumulator>{};
    final modelClassPromptVariantAccumulators =
        <String, _CalibrationAccumulator>{};
    final protectedHoldoutCapabilityAccumulators =
        <String, _CalibrationAccumulator>{};
    final protectedHoldoutModelClassAccumulators =
        <String, _CalibrationAccumulator>{};
    final protectedHoldoutModelClassCapabilityAccumulators =
        <String, _CalibrationAccumulator>{};
    final protectedHoldoutPromptVariantAccumulators =
        <String, _CalibrationAccumulator>{};
    final protectedHoldoutModelClassPromptVariantAccumulators =
        <String, _CalibrationAccumulator>{};

    for (final label in labelsByKey.values) {
      if (protectedHoldoutScenarioIds.contains(label.key.scenarioId)) {
        protectedHoldoutLabelCount++;
      }
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
      final promptVariant = trace.agentDirectiveVariant.name;
      final modelClassCapability = '$modelClass@$capabilityId';
      final modelClassPromptVariant = '$modelClass@$promptVariant';
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
      final modelClassCapabilityAccumulator = modelClassCapabilityAccumulators
          .putIfAbsent(
            modelClassCapability,
            () => _CalibrationAccumulator(modelClassCapability),
          );
      modelClassCapabilityAccumulator.labelCount++;
      final promptVariantAccumulator = promptVariantAccumulators.putIfAbsent(
        promptVariant,
        () => _CalibrationAccumulator(promptVariant),
      );
      promptVariantAccumulator.labelCount++;
      final modelClassPromptVariantAccumulator =
          modelClassPromptVariantAccumulators.putIfAbsent(
            modelClassPromptVariant,
            () => _CalibrationAccumulator(modelClassPromptVariant),
          );
      modelClassPromptVariantAccumulator.labelCount++;
      final protectedHoldoutTrace = protectedHoldoutScenarioIds.contains(
        trace.scenario.id,
      );
      final protectedAccumulators = <_CalibrationAccumulator>[];
      if (protectedHoldoutTrace) {
        final protectedCapability = protectedHoldoutCapabilityAccumulators
            .putIfAbsent(
              capabilityId,
              () => _CalibrationAccumulator(capabilityId),
            );
        final protectedModelClass = protectedHoldoutModelClassAccumulators
            .putIfAbsent(
              modelClass,
              () => _CalibrationAccumulator(modelClass),
            );
        final protectedModelClassCapability =
            protectedHoldoutModelClassCapabilityAccumulators.putIfAbsent(
              modelClassCapability,
              () => _CalibrationAccumulator(modelClassCapability),
            );
        final protectedPromptVariant = protectedHoldoutPromptVariantAccumulators
            .putIfAbsent(
              promptVariant,
              () => _CalibrationAccumulator(promptVariant),
            );
        final protectedModelClassPromptVariant =
            protectedHoldoutModelClassPromptVariantAccumulators.putIfAbsent(
              modelClassPromptVariant,
              () => _CalibrationAccumulator(modelClassPromptVariant),
            );
        protectedAccumulators.addAll([
          protectedCapability,
          protectedModelClass,
          protectedModelClassCapability,
          protectedPromptVariant,
          protectedModelClassPromptVariant,
        ]);
        for (final accumulator in protectedAccumulators) {
          accumulator.labelCount++;
        }
      }

      void updateProtected(
        void Function(_CalibrationAccumulator accumulator) update,
      ) {
        protectedAccumulators.forEach(update);
      }

      final staleReasons = _staleLabelReasons(label: label, trace: trace);
      if (staleReasons.isNotEmpty) {
        staleLabelCount++;
        capability.staleLabelCount++;
        modelClassAccumulator.staleLabelCount++;
        modelClassCapabilityAccumulator.staleLabelCount++;
        promptVariantAccumulator.staleLabelCount++;
        modelClassPromptVariantAccumulator.staleLabelCount++;
        updateProtected((accumulator) => accumulator.staleLabelCount++);
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
        modelClassCapabilityAccumulator.missingVerdictCount++;
        promptVariantAccumulator.missingVerdictCount++;
        modelClassPromptVariantAccumulator.missingVerdictCount++;
        updateProtected((accumulator) => accumulator.missingVerdictCount++);
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
        modelClassCapabilityAccumulator.staleLabelCount++;
        promptVariantAccumulator.staleLabelCount++;
        modelClassPromptVariantAccumulator.staleLabelCount++;
        updateProtected((accumulator) => accumulator.staleLabelCount++);
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
          modelClassCapabilityAccumulator.staleLabelCount++;
          promptVariantAccumulator.staleLabelCount++;
          modelClassPromptVariantAccumulator.staleLabelCount++;
          updateProtected((accumulator) => accumulator.staleLabelCount++);
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
        modelClassCapabilityAccumulator.judgeCalibrationMismatchCount++;
        promptVariantAccumulator.judgeCalibrationMismatchCount++;
        modelClassPromptVariantAccumulator.judgeCalibrationMismatchCount++;
        updateProtected(
          (accumulator) => accumulator.judgeCalibrationMismatchCount++,
        );
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
      modelClassCapabilityAccumulator.evaluatedCount++;
      promptVariantAccumulator.evaluatedCount++;
      modelClassPromptVariantAccumulator.evaluatedCount++;
      if (protectedHoldoutTrace) {
        protectedHoldoutEvaluatedCount++;
      }
      updateProtected((accumulator) => accumulator.evaluatedCount++);

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
        modelClassCapabilityAccumulator.passAgreementCount++;
        promptVariantAccumulator.passAgreementCount++;
        modelClassPromptVariantAccumulator.passAgreementCount++;
        updateProtected((accumulator) => accumulator.passAgreementCount++);
      } else {
        if (verdict.pass && !label.expectedPass) {
          falsePassCount++;
          capability.falsePassCount++;
          modelClassAccumulator.falsePassCount++;
          modelClassCapabilityAccumulator.falsePassCount++;
          promptVariantAccumulator.falsePassCount++;
          modelClassPromptVariantAccumulator.falsePassCount++;
          updateProtected((accumulator) => accumulator.falsePassCount++);
        } else if (!verdict.pass && label.expectedPass) {
          falseFailCount++;
          capability.falseFailCount++;
          modelClassAccumulator.falseFailCount++;
          modelClassCapabilityAccumulator.falseFailCount++;
          promptVariantAccumulator.falseFailCount++;
          modelClassPromptVariantAccumulator.falseFailCount++;
          updateProtected((accumulator) => accumulator.falseFailCount++);
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
        modelClassCapabilityAccumulator.scoreAgreementCount++;
        promptVariantAccumulator.scoreAgreementCount++;
        modelClassPromptVariantAccumulator.scoreAgreementCount++;
        updateProtected((accumulator) => accumulator.scoreAgreementCount++);
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
      protectedHoldoutLabelCount: protectedHoldoutLabelCount,
      protectedHoldoutEvaluatedCount: protectedHoldoutEvaluatedCount,
      humanReviewPairCount: humanReviewPairCount,
      humanPassAgreementPairCount: humanPassAgreementPairCount,
      humanScoreAgreementPairCount: humanScoreAgreementPairCount,
      unresolvedHumanDisagreementCount: unresolvedHumanDisagreementCount,
      unblindedHumanReviewCount: unblindedHumanReviewCount,
      capabilitySummaries: _summaries(capabilityAccumulators),
      modelClassSummaries: _summaries(modelClassAccumulators),
      modelClassCapabilitySummaries: _summaries(
        modelClassCapabilityAccumulators,
      ),
      promptVariantSummaries: _summaries(promptVariantAccumulators),
      modelClassPromptVariantSummaries: _summaries(
        modelClassPromptVariantAccumulators,
      ),
      protectedHoldoutCapabilitySummaries: _summaries(
        protectedHoldoutCapabilityAccumulators,
      ),
      protectedHoldoutModelClassSummaries: _summaries(
        protectedHoldoutModelClassAccumulators,
      ),
      protectedHoldoutModelClassCapabilitySummaries: _summaries(
        protectedHoldoutModelClassCapabilityAccumulators,
      ),
      protectedHoldoutPromptVariantSummaries: _summaries(
        protectedHoldoutPromptVariantAccumulators,
      ),
      protectedHoldoutModelClassPromptVariantSummaries: _summaries(
        protectedHoldoutModelClassPromptVariantAccumulators,
      ),
      findings: findings,
    );
  }

  static List<String> validateTemplateSelectionBinding({
    required List<EvalTrace> traces,
    required JudgeCalibrationSet calibrationSet,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
  }) {
    final evidence = calibrationSet.templateSelection;
    if (evidence == null) return const <String>[];
    final failures = <String>[];
    final candidates = <_CalibrationTemplateCandidate>[];
    final seenKeys = <String>{};
    final protectedScenarioIds =
        scenarioCatalogEvidence?.protectedScenarioIds.toSet() ??
        const <String>{};
    for (final trace in traces) {
      final key = EvalTraceKey.fromTrace(trace);
      if (!seenKeys.add(key.id)) {
        failures.add('calibration template candidate duplicate key ${key.id}');
        continue;
      }
      final verdict = trace.verdict;
      if (verdict == null) {
        failures.add('calibration template candidate ${key.id} has no verdict');
        continue;
      }
      candidates.add(
        _CalibrationTemplateCandidate(
          key: key,
          trace: trace,
          verdict: verdict,
          verdictDigest: EvalProvenance.digestJson(verdict.toJson()),
          protectedTrace: protectedScenarioIds.contains(trace.scenario.id),
        ),
      );
    }
    if (failures.isNotEmpty) return failures;
    final sourceRun = calibrationSet.sourceRun;
    if (sourceRun == null) {
      failures.add(
        'calibration template sourceRunDigest cannot be checked without '
        'sourceRun',
      );
      return failures;
    }
    final sourceRunJson = sourceRun.toJson();
    final sourceRunDigest = EvalProvenance.digestJson(sourceRunJson);
    if (sourceRunDigest != evidence.sourceRunDigest) {
      failures.add(
        'calibration template sourceRunDigest does not match sourceRun',
      );
    }
    late final _CalibrationTemplateSelection expectedSelection;
    try {
      expectedSelection = _selectCalibrationTemplateCandidates(
        candidates: candidates,
        maxRows: evidence.maxRows,
      );
    } on Object catch (error) {
      failures.add('calibration template selection cannot be replayed: $error');
      return failures;
    }
    final expected = expectedSelection.report!;
    final expectedJson = _templateSelectionEvidenceJson(
      report: expected,
      candidates: candidates,
      selectedCandidates: expectedSelection.candidates,
      sourceRunJson: sourceRunJson,
      version: calibrationSet.version,
      judgeCalibrationSetVersion: calibrationSet.judgeCalibrationSetVersion,
    );
    final actualJson = evidence.toJson();
    final labelKeyDigest = EvalProvenance.digestJson(
      [
        for (final label in calibrationSet.labels) label.key.id,
      ]..sort(),
    );
    if (labelKeyDigest != evidence.selectedKeyDigest) {
      failures.add(
        'calibration template selectedKeyDigest does not match completed '
        'label keys',
      );
    }
    final completedLabelRowsDigest = _completedLabelTraceMaterialDigest(
      labels: calibrationSet.labels,
      judgeCalibrationSetVersion: calibrationSet.judgeCalibrationSetVersion,
    );
    if (completedLabelRowsDigest != evidence.selectedTemplateRowsDigest) {
      failures.add(
        'calibration template selectedTemplateRowsDigest does not match '
        'completed label source rows',
      );
    }
    if (evidence.selectedTraceCount != calibrationSet.labels.length) {
      failures.add(
        'calibration template selectedTraceCount '
        '${evidence.selectedTraceCount} != completed label count '
        '${calibrationSet.labels.length}',
      );
    }
    if (EvalProvenance.digestJson(actualJson) !=
        EvalProvenance.digestJson(expectedJson)) {
      failures.add(
        'calibration template selection evidence does not match current '
        'stratified template',
      );
    }
    return failures;
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
    if (report.protectedHoldoutLabelCount > 0 ||
        report.protectedHoldoutEvaluatedCount > 0) {
      buffer.writeln(
        'protected holdout labels=${report.protectedHoldoutLabelCount} '
        'evaluated=${report.protectedHoldoutEvaluatedCount}',
      );
    }

    _renderSlices(buffer, 'Capability calibration', report.capabilitySummaries);
    _renderSlices(
      buffer,
      'Model-class calibration',
      report.modelClassSummaries,
    );
    _renderSlices(
      buffer,
      'Model-class capability calibration',
      report.modelClassCapabilitySummaries,
    );
    _renderSlices(
      buffer,
      'Prompt-variant calibration',
      report.promptVariantSummaries,
    );
    _renderSlices(
      buffer,
      'Model-class prompt-variant calibration',
      report.modelClassPromptVariantSummaries,
    );
    _renderSlices(
      buffer,
      'Protected holdout capability calibration',
      report.protectedHoldoutCapabilitySummaries,
    );
    _renderSlices(
      buffer,
      'Protected holdout model-class calibration',
      report.protectedHoldoutModelClassSummaries,
    );
    _renderSlices(
      buffer,
      'Protected holdout model-class capability calibration',
      report.protectedHoldoutModelClassCapabilitySummaries,
    );
    _renderSlices(
      buffer,
      'Protected holdout prompt-variant calibration',
      report.protectedHoldoutPromptVariantSummaries,
    );
    _renderSlices(
      buffer,
      'Protected holdout model-class prompt-variant calibration',
      report.protectedHoldoutModelClassPromptVariantSummaries,
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
    'primaryCapability:$primaryCapabilityId',
    'modelClassCapability:${trace.profile.modelClass.name}@$primaryCapabilityId',
    'protectionCapability:${protectedTrace ? 'protected' : 'nonProtected'}@$primaryCapabilityId',
  };

  String get primaryCapabilityId =>
      trace.scenario.metadata.primaryCapabilityId ?? 'uncategorized';
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
  final modelClassByCapability = <String>{};
  final protectionByCapability = <String>{};
  for (final candidate in candidates) {
    final verdict = candidate.verdict.pass ? 'pass' : 'fail';
    final capabilityId = candidate.primaryCapabilityId;
    agentKindByVerdict.add(
      '${candidate.trace.scenario.agentKind.name}:$verdict',
    );
    modelClassByVerdict.add(
      '${candidate.trace.profile.modelClass.name}:$verdict',
    );
    protectionByVerdict.add(
      '${candidate.protectedTrace ? 'protected' : 'nonProtected'}:$verdict',
    );
    modelClassByCapability.add(
      '${candidate.trace.profile.modelClass.name}@$capabilityId',
    );
    protectionByCapability.add(
      '${candidate.protectedTrace ? 'protected' : 'nonProtected'}@$capabilityId',
    );
  }
  return <String, int>{
    'agentKindByVerdict': agentKindByVerdict.length,
    'modelClassByVerdict': modelClassByVerdict.length,
    'protectionByVerdict': protectionByVerdict.length,
    'modelClassByCapability': modelClassByCapability.length,
    'protectionByCapability': protectionByCapability.length,
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

String _requiredSourceString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('sourceRun.$key must be a non-empty string');
}

void _rejectUnknownFields(
  Map<String, dynamic> json,
  String owner,
  Set<String> allowedFields,
) {
  final unknown = json.keys.where((key) => !allowedFields.contains(key));
  if (unknown.isNotEmpty) {
    throw FormatException('$owner has unsupported field ${unknown.first}');
  }
}

String? _optionalSourceString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('sourceRun.$key must be a non-empty string');
}

int _requiredSourceInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('sourceRun.$key must be an integer');
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
