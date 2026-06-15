// Pairwise preference judgments for subjective A/B eval review.
//
// Deterministic Level 1 checks are intentionally narrow. This module models
// the subjective layer: multiple LLM or human reviewers compare two trace
// artifacts for the same scenario/trial and produce an auditable quorum result.

import 'dart:math' as math;

import 'eval_models.dart';
import 'eval_provenance.dart';

enum EvalPairwisePreferenceChoice {
  optionA,
  optionB,
  tie;

  static EvalPairwisePreferenceChoice fromName(String name) =>
      EvalPairwisePreferenceChoice.values.firstWhere((v) => v.name == name);
}

enum EvalPairwiseReviewerKind {
  llmJudge,
  human;

  static EvalPairwiseReviewerKind fromName(String name) =>
      EvalPairwiseReviewerKind.values.firstWhere((v) => v.name == name);
}

enum EvalPairwisePreferenceStatus {
  optionAWins,
  optionBWins,
  tie,
  noConsensus,
  incomplete,
  invalid,
}

enum EvalPairwiseComparisonAxis {
  profile,
  promptVariant,
  invalid,
}

/// Audit binding proving a raw pairwise vote came from a blinded pair packet.
class BlindedPairwisePreferenceImportRecord {
  const BlindedPairwisePreferenceImportRecord({
    required this.blindedPairId,
    required this.reviewPayloadDigest,
    required this.judgeManifestDigest,
    required this.privateKeyDigest,
    required this.sourceManifestDigest,
    required this.optionARawTraceDigest,
    required this.optionBRawTraceDigest,
  });

  factory BlindedPairwisePreferenceImportRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    _rejectUnknownFields(json, 'BlindedPairwisePreferenceImportRecord', {
      'schemaVersion',
      'kind',
      'blindedPairId',
      'reviewPayloadDigest',
      'judgeManifestDigest',
      'privateKeyDigest',
      'sourceManifestDigest',
      'optionARawTraceDigest',
      'optionBRawTraceDigest',
    });
    final rawVersion = json['schemaVersion'];
    if (rawVersion != schemaVersion) {
      throw FormatException(
        'Unsupported BlindedPairwisePreferenceImportRecord schemaVersion '
        '$rawVersion (expected $schemaVersion)',
      );
    }
    final kind = _requiredNonEmptyString(json, 'kind');
    if (kind != kindValue) {
      throw FormatException(
        'Unsupported BlindedPairwisePreferenceImportRecord kind "$kind" '
        '(expected $kindValue)',
      );
    }
    return BlindedPairwisePreferenceImportRecord(
      blindedPairId: _requiredNonEmptyString(json, 'blindedPairId'),
      reviewPayloadDigest: _requiredDigest(json, 'reviewPayloadDigest'),
      judgeManifestDigest: _requiredDigest(json, 'judgeManifestDigest'),
      privateKeyDigest: _requiredDigest(json, 'privateKeyDigest'),
      sourceManifestDigest: _requiredDigest(json, 'sourceManifestDigest'),
      optionARawTraceDigest: _requiredDigest(json, 'optionARawTraceDigest'),
      optionBRawTraceDigest: _requiredDigest(json, 'optionBRawTraceDigest'),
    );
  }

  static const schemaVersion = 1;
  static const kindValue = 'lotti.blindedPairwisePreferenceImport';

  final String blindedPairId;
  final String reviewPayloadDigest;
  final String judgeManifestDigest;
  final String privateKeyDigest;
  final String sourceManifestDigest;
  final String optionARawTraceDigest;
  final String optionBRawTraceDigest;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'kind': kindValue,
    'blindedPairId': blindedPairId,
    'reviewPayloadDigest': reviewPayloadDigest,
    'judgeManifestDigest': judgeManifestDigest,
    'privateKeyDigest': privateKeyDigest,
    'sourceManifestDigest': sourceManifestDigest,
    'optionARawTraceDigest': optionARawTraceDigest,
    'optionBRawTraceDigest': optionBRawTraceDigest,
  };
}

class EvalPairwiseTraceRef {
  const EvalPairwiseTraceRef({
    required this.runId,
    required this.scenarioId,
    required this.profileName,
    required this.agentDirectiveVariantName,
    required this.agentKind,
    required this.modelClass,
    required this.capabilityId,
    required this.trialIndex,
    required this.traceDigest,
    required this.scenarioDigest,
    required this.profileDigest,
    required this.agentDirectiveVariantDigest,
    this.cascadeWake,
  });

  factory EvalPairwiseTraceRef.fromTrace(
    EvalTrace trace, {
    required String traceDigest,
  }) => EvalPairwiseTraceRef(
    runId: trace.runId,
    scenarioId: trace.scenario.id,
    profileName: trace.profile.name,
    agentDirectiveVariantName: trace.agentDirectiveVariant.name,
    agentKind: trace.scenario.agentKind,
    modelClass: trace.profile.modelClass,
    capabilityId: trace.scenario.metadata.primaryCapabilityId ?? '',
    trialIndex: trace.trialIndex,
    cascadeWake: trace.cascadeWake,
    traceDigest: traceDigest,
    scenarioDigest: trace.provenance.scenarioDigest,
    profileDigest: trace.provenance.profileDigest,
    agentDirectiveVariantDigest: trace.provenance.agentDirectiveVariantDigest,
  );

  factory EvalPairwiseTraceRef.fromJson(Map<String, dynamic> json) {
    _rejectUnknownFields(json, 'EvalPairwiseTraceRef', {
      'runId',
      'scenarioId',
      'profileName',
      'agentDirectiveVariantName',
      'agentKind',
      'modelClass',
      'capabilityId',
      'trialIndex',
      'cascadeWake',
      'traceDigest',
      'scenarioDigest',
      'profileDigest',
      'agentDirectiveVariantDigest',
    });
    return EvalPairwiseTraceRef(
      runId: _requiredNonEmptyString(json, 'runId'),
      scenarioId: _requiredNonEmptyString(json, 'scenarioId'),
      profileName: _requiredNonEmptyString(json, 'profileName'),
      agentDirectiveVariantName: _requiredNonEmptyString(
        json,
        'agentDirectiveVariantName',
      ),
      agentKind: AgentKind.fromName(_requiredNonEmptyString(json, 'agentKind')),
      modelClass: EvalModelClass.fromName(
        _requiredNonEmptyString(json, 'modelClass'),
      ),
      capabilityId: _requiredNonEmptyString(json, 'capabilityId'),
      trialIndex: _requiredInt(json, 'trialIndex'),
      cascadeWake: json['cascadeWake'] == null
          ? null
          : EvalTraceCascadeWake.fromJson(
              _requiredObject(json, 'cascadeWake'),
            ),
      traceDigest: _requiredDigest(json, 'traceDigest'),
      scenarioDigest: _requiredDigest(json, 'scenarioDigest'),
      profileDigest: _requiredDigest(json, 'profileDigest'),
      agentDirectiveVariantDigest: _requiredDigest(
        json,
        'agentDirectiveVariantDigest',
      ),
    );
  }

  final String runId;
  final String scenarioId;
  final String profileName;
  final String agentDirectiveVariantName;
  final AgentKind agentKind;
  final EvalModelClass modelClass;
  final String capabilityId;
  final int trialIndex;
  final EvalTraceCascadeWake? cascadeWake;
  final String traceDigest;
  final String scenarioDigest;
  final String profileDigest;
  final String agentDirectiveVariantDigest;

  String get traceKey {
    final suffix = cascadeWake == null ? '' : '::${cascadeWake!.keySuffix}';
    final variantSegment = agentDirectiveVariantName == 'default'
        ? ''
        : '::$agentDirectiveVariantName';
    return '$runId::$scenarioId::$profileName$variantSegment::trial-'
        '$trialIndex$suffix';
  }

  String get artifactKey => '$traceKey::$traceDigest';

  String get baseComparisonContextKey {
    final suffix = cascadeWake == null ? '' : '::${cascadeWake!.keySuffix}';
    return '$runId::$scenarioId::trial-$trialIndex$suffix';
  }

  String get profileComparisonContextKey =>
      '$baseComparisonContextKey::prompt-$agentDirectiveVariantName';

  String get promptVariantComparisonContextKey =>
      '$baseComparisonContextKey::profile-$profileName';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'runId': runId,
    'scenarioId': scenarioId,
    'profileName': profileName,
    'agentDirectiveVariantName': agentDirectiveVariantName,
    'agentKind': agentKind.name,
    'modelClass': modelClass.name,
    'capabilityId': capabilityId,
    'trialIndex': trialIndex,
    if (cascadeWake != null) 'cascadeWake': cascadeWake!.toJson(),
    'traceDigest': traceDigest,
    'scenarioDigest': scenarioDigest,
    'profileDigest': profileDigest,
    'agentDirectiveVariantDigest': agentDirectiveVariantDigest,
  };
}

class EvalPairwisePreferenceVote {
  const EvalPairwisePreferenceVote({
    required this.voteId,
    required this.optionA,
    required this.optionB,
    required this.reviewerId,
    required this.reviewerKind,
    required this.promptDigest,
    required this.calibrationSetVersion,
    required this.profileVisible,
    required this.modelIdentityVisible,
    required this.peerVotesVisible,
    required this.traceOrderRandomized,
    required this.choice,
    required this.rationale,
    this.reviewerModel,
    this.blindedImport,
    this.issues = const <String>[],
  });

  factory EvalPairwisePreferenceVote.fromJson(Map<String, dynamic> json) {
    _rejectUnknownFields(json, 'EvalPairwisePreferenceVote', {
      'schemaVersion',
      'voteId',
      'optionA',
      'optionB',
      'reviewerId',
      'reviewerKind',
      'reviewerModel',
      'promptDigest',
      'calibrationSetVersion',
      'profileVisible',
      'modelIdentityVisible',
      'peerVotesVisible',
      'traceOrderRandomized',
      'choice',
      'rationale',
      'blindedImport',
      'issues',
    });
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != EvalPairwisePreferenceVote.schemaVersion) {
      throw FormatException(
        'Unsupported EvalPairwisePreferenceVote schemaVersion '
        '$schemaVersion (expected ${EvalPairwisePreferenceVote.schemaVersion})',
      );
    }
    return EvalPairwisePreferenceVote(
      voteId: _requiredNonEmptyString(json, 'voteId'),
      optionA: EvalPairwiseTraceRef.fromJson(
        _requiredObject(json, 'optionA'),
      ),
      optionB: EvalPairwiseTraceRef.fromJson(
        _requiredObject(json, 'optionB'),
      ),
      reviewerId: _requiredNonEmptyString(json, 'reviewerId'),
      reviewerKind: EvalPairwiseReviewerKind.fromName(
        _requiredNonEmptyString(json, 'reviewerKind'),
      ),
      reviewerModel: _optionalNonEmptyString(json, 'reviewerModel'),
      promptDigest: _requiredDigest(json, 'promptDigest'),
      calibrationSetVersion: _requiredNonEmptyString(
        json,
        'calibrationSetVersion',
      ),
      profileVisible: _requiredBool(json, 'profileVisible'),
      modelIdentityVisible: _requiredBool(json, 'modelIdentityVisible'),
      peerVotesVisible: _requiredBool(json, 'peerVotesVisible'),
      traceOrderRandomized: _requiredBool(json, 'traceOrderRandomized'),
      choice: EvalPairwisePreferenceChoice.fromName(
        _requiredNonEmptyString(json, 'choice'),
      ),
      rationale: _requiredNonEmptyString(json, 'rationale'),
      blindedImport: json['blindedImport'] == null
          ? null
          : BlindedPairwisePreferenceImportRecord.fromJson(
              _requiredObject(json, 'blindedImport'),
            ),
      issues: _optionalStringList(json, 'issues'),
    );
  }

  static const schemaVersion = 1;

  final String voteId;
  final EvalPairwiseTraceRef optionA;
  final EvalPairwiseTraceRef optionB;
  final String reviewerId;
  final EvalPairwiseReviewerKind reviewerKind;
  final String? reviewerModel;
  final String promptDigest;
  final String calibrationSetVersion;
  final bool profileVisible;
  final bool modelIdentityVisible;
  final bool peerVotesVisible;
  final bool traceOrderRandomized;
  final EvalPairwisePreferenceChoice choice;
  final String rationale;
  final BlindedPairwisePreferenceImportRecord? blindedImport;
  final List<String> issues;

  bool get isCanonicalOrder =>
      optionA.artifactKey.compareTo(optionB.artifactKey) <= 0;

  EvalPairwiseTraceRef get canonicalOptionA =>
      isCanonicalOrder ? optionA : optionB;

  EvalPairwiseTraceRef get canonicalOptionB =>
      isCanonicalOrder ? optionB : optionA;

  EvalPairwisePreferenceChoice get canonicalChoice {
    if (isCanonicalOrder) return choice;
    return switch (choice) {
      EvalPairwisePreferenceChoice.optionA =>
        EvalPairwisePreferenceChoice.optionB,
      EvalPairwisePreferenceChoice.optionB =>
        EvalPairwisePreferenceChoice.optionA,
      EvalPairwisePreferenceChoice.tie => EvalPairwisePreferenceChoice.tie,
    };
  }

  String get reviewProtocolFingerprint => [
    'kind=${reviewerKind.name}',
    'model=${reviewerModel ?? ''}',
    'prompt=$promptDigest',
    'calibration=$calibrationSetVersion',
    'profileVisible=$profileVisible',
    'modelIdentityVisible=$modelIdentityVisible',
    'peerVotesVisible=$peerVotesVisible',
    'traceOrderRandomized=$traceOrderRandomized',
  ].join('|');

  EvalPairwiseComparisonAxis get comparisonAxis {
    final profileDiffers = optionA.profileName != optionB.profileName;
    final variantDiffers =
        optionA.agentDirectiveVariantName != optionB.agentDirectiveVariantName;
    if (profileDiffers && !variantDiffers) {
      return EvalPairwiseComparisonAxis.profile;
    }
    if (!profileDiffers && variantDiffers) {
      return EvalPairwiseComparisonAxis.promptVariant;
    }
    return EvalPairwiseComparisonAxis.invalid;
  }

  String get comparisonKey =>
      '${comparisonAxis.name}::${_comparisonContextKey()}::'
      '${canonicalOptionA.artifactKey}::'
      '${canonicalOptionB.artifactKey}';

  String _comparisonContextKey() => switch (comparisonAxis) {
    EvalPairwiseComparisonAxis.profile =>
      canonicalOptionA.profileComparisonContextKey,
    EvalPairwiseComparisonAxis.promptVariant =>
      canonicalOptionA.promptVariantComparisonContextKey,
    EvalPairwiseComparisonAxis.invalid =>
      canonicalOptionA.baseComparisonContextKey,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'voteId': voteId,
    'optionA': optionA.toJson(),
    'optionB': optionB.toJson(),
    'reviewerId': reviewerId,
    'reviewerKind': reviewerKind.name,
    if (reviewerModel != null) 'reviewerModel': reviewerModel,
    'promptDigest': promptDigest,
    'calibrationSetVersion': calibrationSetVersion,
    'profileVisible': profileVisible,
    'modelIdentityVisible': modelIdentityVisible,
    'peerVotesVisible': peerVotesVisible,
    'traceOrderRandomized': traceOrderRandomized,
    'choice': choice.name,
    'rationale': rationale,
    if (blindedImport != null) 'blindedImport': blindedImport!.toJson(),
    'issues': issues,
  };

  EvalPairwisePreferenceVote withBlindedImport(
    BlindedPairwisePreferenceImportRecord provenance,
  ) => EvalPairwisePreferenceVote(
    voteId: voteId,
    optionA: optionA,
    optionB: optionB,
    reviewerId: reviewerId,
    reviewerKind: reviewerKind,
    reviewerModel: reviewerModel,
    promptDigest: promptDigest,
    calibrationSetVersion: calibrationSetVersion,
    profileVisible: profileVisible,
    modelIdentityVisible: modelIdentityVisible,
    peerVotesVisible: peerVotesVisible,
    traceOrderRandomized: traceOrderRandomized,
    choice: choice,
    rationale: rationale,
    blindedImport: provenance,
    issues: issues,
  );

  List<String> validate(EvalPairwisePreferencePolicy policy) {
    final failures = <String>[];
    _requireNonEmpty(failures, 'voteId', voteId);
    _requireNonEmpty(failures, 'reviewerId', reviewerId);
    _requireNonEmpty(
      failures,
      'calibrationSetVersion',
      calibrationSetVersion,
    );
    _requireNonEmpty(failures, 'rationale', rationale);
    _requireDigest(failures, 'promptDigest', promptDigest);
    _validateTraceRef(failures, 'optionA', optionA);
    _validateTraceRef(failures, 'optionB', optionB);
    if (optionA.baseComparisonContextKey != optionB.baseComparisonContextKey) {
      failures.add(
        'option A and option B traces must share scenario, trial, and '
        'cascade wake',
      );
    }
    if (optionA.scenarioDigest != optionB.scenarioDigest) {
      failures.add('option A and option B traces must share scenarioDigest');
    }
    if (optionA.capabilityId != optionB.capabilityId) {
      failures.add('option A and option B traces must share capabilityId');
    }
    if (optionA.agentKind != optionB.agentKind) {
      failures.add('option A and option B traces must share agentKind');
    }
    switch (comparisonAxis) {
      case EvalPairwiseComparisonAxis.profile:
        if (optionA.agentDirectiveVariantDigest !=
            optionB.agentDirectiveVariantDigest) {
          failures.add(
            'profile comparisons must share agentDirectiveVariantDigest',
          );
        }
      case EvalPairwiseComparisonAxis.promptVariant:
        if (optionA.profileDigest != optionB.profileDigest) {
          failures.add('prompt variant comparisons must share profileDigest');
        }
      case EvalPairwiseComparisonAxis.invalid:
        failures.add(
          'option A and option B must differ by exactly one tuning axis: '
          'profile or prompt variant',
        );
    }
    if (policy.requireModelIdentityBlind && modelIdentityVisible) {
      failures.add('reviewer saw exact model identity');
    }
    if (policy.requireProfileBlind && profileVisible) {
      failures.add('reviewer saw profile identity');
    }
    if (policy.requirePeerVoteBlind && peerVotesVisible) {
      failures.add('reviewer saw peer votes');
    }
    if (policy.requireTraceOrderRandomized && !traceOrderRandomized) {
      failures.add('trace order was not randomized');
    }
    if (policy.requireBlindedImport && blindedImport == null) {
      failures.add('missing blinded pairwise import provenance');
    }
    if (reviewerKind == EvalPairwiseReviewerKind.llmJudge &&
        (reviewerModel == null || reviewerModel!.trim().isEmpty)) {
      failures.add('llmJudge reviewerModel is empty');
    }
    if (reviewerKind == EvalPairwiseReviewerKind.human &&
        reviewerModel != null &&
        reviewerModel!.trim().isNotEmpty) {
      failures.add('human reviewerModel must be empty');
    }
    _validateBlindedImportRecord(failures, this);
    return failures;
  }
}

class EvalPairwisePreferencePolicy {
  const EvalPairwisePreferencePolicy({
    this.minVotes = 3,
    this.quorumFraction = 2 / 3,
    this.requireModelIdentityBlind = true,
    this.requireProfileBlind = false,
    this.requirePeerVoteBlind = true,
    this.requireTraceOrderRandomized = false,
    this.requireBlindedImport = false,
  });

  factory EvalPairwisePreferencePolicy.fromJson(Map<String, dynamic> json) {
    final unknown = json.keys.where(
      (key) => !const {
        'minVotes',
        'quorumFraction',
        'requireModelIdentityBlind',
        'requireProfileBlind',
        'requirePeerVoteBlind',
        'requireTraceOrderRandomized',
        'requireBlindedImport',
      }.contains(key),
    );
    if (unknown.isNotEmpty) {
      throw FormatException(
        'EvalPairwisePreferencePolicy has unsupported field ${unknown.first}',
      );
    }
    return EvalPairwisePreferencePolicy(
      minVotes: _requiredInt(json, 'minVotes'),
      quorumFraction: _requiredDouble(json, 'quorumFraction'),
      requireModelIdentityBlind: _requiredBool(
        json,
        'requireModelIdentityBlind',
      ),
      requireProfileBlind: _requiredBool(json, 'requireProfileBlind'),
      requirePeerVoteBlind: _requiredBool(json, 'requirePeerVoteBlind'),
      requireTraceOrderRandomized: _requiredBool(
        json,
        'requireTraceOrderRandomized',
      ),
      requireBlindedImport: _requiredBool(json, 'requireBlindedImport'),
    );
  }

  final int minVotes;
  final double quorumFraction;
  final bool requireModelIdentityBlind;
  final bool requireProfileBlind;
  final bool requirePeerVoteBlind;
  final bool requireTraceOrderRandomized;
  final bool requireBlindedImport;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'minVotes': minVotes,
    'quorumFraction': quorumFraction,
    'requireModelIdentityBlind': requireModelIdentityBlind,
    'requireProfileBlind': requireProfileBlind,
    'requirePeerVoteBlind': requirePeerVoteBlind,
    'requireTraceOrderRandomized': requireTraceOrderRandomized,
    'requireBlindedImport': requireBlindedImport,
  };

  List<String> validate() {
    final failures = <String>[];
    if (minVotes < 1) {
      failures.add('minVotes must be at least 1');
    }
    if (!quorumFraction.isFinite || quorumFraction <= 0 || quorumFraction > 1) {
      failures.add('quorumFraction must be finite and in (0, 1]');
    }
    return failures;
  }
}

class EvalPairwisePreferenceSummary {
  const EvalPairwisePreferenceSummary({
    required this.comparisonKey,
    required this.optionA,
    required this.optionB,
    required this.status,
    required this.voteCount,
    required this.validVoteCount,
    required this.invalidVoteCount,
    required this.optionAVoteCount,
    required this.optionBVoteCount,
    required this.tieVoteCount,
    required this.quorumThreshold,
    required this.findings,
    required this.axis,
  });

  final String comparisonKey;
  final EvalPairwiseTraceRef optionA;
  final EvalPairwiseTraceRef optionB;
  final EvalPairwisePreferenceStatus status;
  final int voteCount;
  final int validVoteCount;
  final int invalidVoteCount;
  final int optionAVoteCount;
  final int optionBVoteCount;
  final int tieVoteCount;
  final int quorumThreshold;
  final List<String> findings;
  final EvalPairwiseComparisonAxis axis;

  bool get hasWinner =>
      status == EvalPairwisePreferenceStatus.optionAWins ||
      status == EvalPairwisePreferenceStatus.optionBWins;

  bool get hasDecision =>
      hasWinner || status == EvalPairwisePreferenceStatus.tie;

  EvalPairwiseTraceRef? get preferredTrace => switch (status) {
    EvalPairwisePreferenceStatus.optionAWins => optionA,
    EvalPairwisePreferenceStatus.optionBWins => optionB,
    EvalPairwisePreferenceStatus.tie ||
    EvalPairwisePreferenceStatus.noConsensus ||
    EvalPairwisePreferenceStatus.incomplete ||
    EvalPairwisePreferenceStatus.invalid => null,
  };
}

abstract final class EvalPairwisePreferenceReporter {
  static List<EvalPairwisePreferenceSummary> summarize(
    List<EvalPairwisePreferenceVote> votes, {
    EvalPairwisePreferencePolicy policy = const EvalPairwisePreferencePolicy(),
  }) {
    final policyFailures = policy.validate();
    if (policyFailures.isNotEmpty) {
      throw ArgumentError.value(policy, 'policy', policyFailures.join('; '));
    }
    final byComparison = <String, List<EvalPairwisePreferenceVote>>{};
    for (final vote in votes) {
      byComparison.putIfAbsent(vote.comparisonKey, () => []).add(vote);
    }
    final summaries = [
      for (final entry in byComparison.entries)
        _summarizeComparison(entry.key, entry.value, policy),
    ]..sort((a, b) => a.comparisonKey.compareTo(b.comparisonKey));
    return summaries;
  }

  static String render(List<EvalPairwisePreferenceSummary> summaries) {
    if (summaries.isEmpty) return 'No pairwise preferences to report.';
    final buffer = StringBuffer()
      ..writeln(
        'Subjective A/B preference votes (diagnostic only): '
        '${summaries.length} pairs',
      )
      ..writeln(
        'axis           option A          option B          scenario                           '
        'status        votes  valid  A/B/T  quorum  findings',
      )
      ..writeln(
        '-------------  ----------------  ----------------  ---------------------------------  '
        '------------  -----  -----  -----  ------  --------',
      );
    for (final summary in summaries) {
      buffer.writeln(
        '${summary.axis.name.padRight(13)}  '
        '${_clip(_optionLabel(summary.optionA, summary.axis), 16).padRight(16)}  '
        '${_clip(_optionLabel(summary.optionB, summary.axis), 16).padRight(16)}  '
        '${_clip(summary.optionA.scenarioId, 33).padRight(33)}  '
        '${summary.status.name.padRight(12)}  '
        '${summary.voteCount.toString().padLeft(5)}  '
        '${summary.validVoteCount.toString().padLeft(5)}  '
        '${'${summary.optionAVoteCount}/${summary.optionBVoteCount}/${summary.tieVoteCount}'.padLeft(5)}  '
        '${summary.quorumThreshold.toString().padLeft(6)}  '
        '${summary.findings.join('; ')}',
      );
    }
    return buffer.toString();
  }

  static EvalPairwisePreferenceSummary _summarizeComparison(
    String comparisonKey,
    List<EvalPairwisePreferenceVote> votes,
    EvalPairwisePreferencePolicy policy,
  ) {
    final findings = <String>[];
    final invalidVoteIds = <String>{};
    for (final vote in votes) {
      final failures = vote.validate(policy);
      if (failures.isEmpty) continue;
      invalidVoteIds.add(vote.voteId);
      findings.add('${vote.voteId}: ${failures.join(', ')}');
    }
    final reviewerCounts = <String, int>{};
    for (final vote in votes) {
      reviewerCounts.update(
        vote.reviewerId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final duplicateReviewers = {
      for (final entry in reviewerCounts.entries)
        if (entry.key.trim().isNotEmpty && entry.value > 1) entry.key,
    };
    if (duplicateReviewers.isNotEmpty) {
      findings.add(
        'duplicate reviewer vote(s): ${(duplicateReviewers.toList()..sort()).join(', ')}',
      );
      for (final vote in votes) {
        if (duplicateReviewers.contains(vote.reviewerId)) {
          invalidVoteIds.add(vote.voteId);
        }
      }
    }
    final protocolKeys = <String, List<EvalPairwisePreferenceVote>>{};
    for (final vote in votes) {
      if (invalidVoteIds.contains(vote.voteId)) continue;
      protocolKeys.putIfAbsent(_reviewProtocolKey(vote), () => []).add(vote);
    }
    if (protocolKeys.length > 1) {
      findings.add(
        'mixed review protocol(s): '
        '${(_reviewProtocolLabels(protocolKeys)..sort()).join(', ')}',
      );
      for (final vote in protocolKeys.values.expand((votes) => votes)) {
        invalidVoteIds.add(vote.voteId);
      }
    }

    final validVotes = [
      for (final vote in votes)
        if (!invalidVoteIds.contains(vote.voteId)) vote,
    ];
    if (!policy.requireBlindedImport) {
      final unverifiedImportCount = validVotes
          .where((vote) => vote.blindedImport != null)
          .length;
      if (unverifiedImportCount > 0) {
        findings.add(
          'blinded import provenance present but not readiness-plan verified: '
          '$unverifiedImportCount vote(s)',
        );
      }
    }
    final optionACount = _choiceCount(
      validVotes,
      EvalPairwisePreferenceChoice.optionA,
    );
    final optionBCount = _choiceCount(
      validVotes,
      EvalPairwisePreferenceChoice.optionB,
    );
    final tieCount = _choiceCount(validVotes, EvalPairwisePreferenceChoice.tie);
    final quorumThreshold = validVotes.isEmpty
        ? 0
        : math.max(1, (validVotes.length * policy.quorumFraction).ceil());
    final status = _status(
      policy: policy,
      invalidVoteCount: invalidVoteIds.length,
      validVoteCount: validVotes.length,
      optionACount: optionACount,
      optionBCount: optionBCount,
      tieCount: tieCount,
      quorumThreshold: quorumThreshold,
    );
    if (status == EvalPairwisePreferenceStatus.incomplete) {
      findings.add(
        'valid votes ${validVotes.length} < minVotes ${policy.minVotes}',
      );
    } else if (status == EvalPairwisePreferenceStatus.noConsensus) {
      findings.add('no choice reached quorum');
    }
    return EvalPairwisePreferenceSummary(
      comparisonKey: comparisonKey,
      optionA: votes.first.canonicalOptionA,
      optionB: votes.first.canonicalOptionB,
      status: status,
      voteCount: votes.length,
      validVoteCount: validVotes.length,
      invalidVoteCount: invalidVoteIds.length,
      optionAVoteCount: optionACount,
      optionBVoteCount: optionBCount,
      tieVoteCount: tieCount,
      quorumThreshold: quorumThreshold,
      findings: List.unmodifiable(findings),
      axis: votes.first.comparisonAxis,
    );
  }

  static EvalPairwisePreferenceStatus _status({
    required EvalPairwisePreferencePolicy policy,
    required int invalidVoteCount,
    required int validVoteCount,
    required int optionACount,
    required int optionBCount,
    required int tieCount,
    required int quorumThreshold,
  }) {
    if (invalidVoteCount > 0) return EvalPairwisePreferenceStatus.invalid;
    if (validVoteCount < policy.minVotes) {
      return EvalPairwisePreferenceStatus.incomplete;
    }
    final maxCount = math.max(optionACount, math.max(optionBCount, tieCount));
    final leaders = [
      if (optionACount == maxCount) EvalPairwisePreferenceStatus.optionAWins,
      if (optionBCount == maxCount) EvalPairwisePreferenceStatus.optionBWins,
      if (tieCount == maxCount) EvalPairwisePreferenceStatus.tie,
    ];
    if (leaders.length != 1 || maxCount < quorumThreshold) {
      return EvalPairwisePreferenceStatus.noConsensus;
    }
    return leaders.single;
  }

  static int _choiceCount(
    List<EvalPairwisePreferenceVote> votes,
    EvalPairwisePreferenceChoice choice,
  ) => votes.where((vote) => vote.canonicalChoice == choice).length;
}

void _validateTraceRef(
  List<String> failures,
  String label,
  EvalPairwiseTraceRef ref,
) {
  _requireNonEmpty(failures, '$label.runId', ref.runId);
  _requireNonEmpty(failures, '$label.scenarioId', ref.scenarioId);
  _requireNonEmpty(failures, '$label.profileName', ref.profileName);
  _requireNonEmpty(
    failures,
    '$label.agentDirectiveVariantName',
    ref.agentDirectiveVariantName,
  );
  _requireNonEmpty(failures, '$label.capabilityId', ref.capabilityId);
  _requireDigest(failures, '$label.traceDigest', ref.traceDigest);
  _requireDigest(failures, '$label.scenarioDigest', ref.scenarioDigest);
  _requireDigest(failures, '$label.profileDigest', ref.profileDigest);
  _requireDigest(
    failures,
    '$label.agentDirectiveVariantDigest',
    ref.agentDirectiveVariantDigest,
  );
}

void _requireNonEmpty(List<String> failures, String field, String value) {
  if (value.trim().isEmpty) failures.add('$field is empty');
}

void _requireDigest(List<String> failures, String field, String value) {
  if (!EvalProvenance.isDigest(value)) {
    failures.add('$field is not a sha256 digest');
  }
}

void _validateBlindedImportRecord(
  List<String> failures,
  EvalPairwisePreferenceVote vote,
) {
  final provenance = vote.blindedImport;
  if (provenance == null) return;
  _requireNonEmpty(
    failures,
    'blindedImport.blindedPairId',
    provenance.blindedPairId,
  );
  _requireDigest(
    failures,
    'blindedImport.reviewPayloadDigest',
    provenance.reviewPayloadDigest,
  );
  _requireDigest(
    failures,
    'blindedImport.judgeManifestDigest',
    provenance.judgeManifestDigest,
  );
  _requireDigest(
    failures,
    'blindedImport.privateKeyDigest',
    provenance.privateKeyDigest,
  );
  _requireDigest(
    failures,
    'blindedImport.sourceManifestDigest',
    provenance.sourceManifestDigest,
  );
  _requireDigest(
    failures,
    'blindedImport.optionARawTraceDigest',
    provenance.optionARawTraceDigest,
  );
  _requireDigest(
    failures,
    'blindedImport.optionBRawTraceDigest',
    provenance.optionBRawTraceDigest,
  );
  if (provenance.optionARawTraceDigest != vote.optionA.traceDigest) {
    failures.add(
      'blindedImport.optionARawTraceDigest does not match option A traceDigest',
    );
  }
  if (provenance.optionBRawTraceDigest != vote.optionB.traceDigest) {
    failures.add(
      'blindedImport.optionBRawTraceDigest does not match option B traceDigest',
    );
  }
  if (vote.profileVisible) {
    failures.add('blindedImport is present but profile identity was visible');
  }
  if (vote.modelIdentityVisible) {
    failures.add(
      'blindedImport is present but exact model identity was visible',
    );
  }
  if (vote.peerVotesVisible) {
    failures.add('blindedImport is present but peer votes were visible');
  }
  if (!vote.traceOrderRandomized) {
    failures.add('blindedImport is present but trace order was not randomized');
  }
}

void _rejectUnknownFields(
  Map<String, dynamic> json,
  String typeName,
  Set<String> allowed,
) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList()
    ..sort();
  if (unknown.isNotEmpty) {
    throw FormatException(
      '$typeName has unknown field(s): ${unknown.join(', ')}',
    );
  }
}

String _requiredNonEmptyString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value;
}

String? _optionalNonEmptyString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string when present');
  }
  return value;
}

String _requiredDigest(Map<String, dynamic> json, String field) {
  final value = _requiredNonEmptyString(json, field);
  if (!EvalProvenance.isDigest(value)) {
    throw FormatException('$field must be a sha256 digest');
  }
  return value;
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$field must be an object');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! num || value % 1 != 0) {
    throw FormatException('$field must be an integer');
  }
  return value.toInt();
}

double _requiredDouble(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$field must be a finite number');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! bool) {
    throw FormatException('$field must be a boolean');
  }
  return value;
}

List<String> _optionalStringList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return const <String>[];
  if (value is! List<dynamic>) {
    throw FormatException('$field must be a list');
  }
  final issues = <String>[];
  for (var index = 0; index < value.length; index++) {
    final issue = value[index];
    if (issue is! String) {
      throw FormatException('$field[$index] must be a string');
    }
    issues.add(issue);
  }
  return issues;
}

String _clip(String value, int width) {
  if (value.length <= width) return value;
  if (width <= 1) return value.substring(0, width);
  return '${value.substring(0, width - 1)}~';
}

String _optionLabel(
  EvalPairwiseTraceRef ref,
  EvalPairwiseComparisonAxis axis,
) => switch (axis) {
  EvalPairwiseComparisonAxis.profile => ref.profileName,
  EvalPairwiseComparisonAxis.promptVariant => ref.agentDirectiveVariantName,
  EvalPairwiseComparisonAxis.invalid => ref.profileName,
};

String _reviewProtocolKey(EvalPairwisePreferenceVote vote) =>
    vote.reviewProtocolFingerprint;

List<String> _reviewProtocolLabels(
  Map<String, List<EvalPairwisePreferenceVote>> protocolKeys,
) => [
  for (final votes in protocolKeys.values) _reviewProtocolLabel(votes.first),
];

String _reviewProtocolLabel(EvalPairwisePreferenceVote vote) => [
  vote.reviewerKind.name,
  vote.reviewerModel ?? 'unmodeled',
  vote.calibrationSetVersion,
  _clip(vote.promptDigest, 18),
  'profileVisible=${vote.profileVisible}',
  'modelVisible=${vote.modelIdentityVisible}',
  'peerVisible=${vote.peerVotesVisible}',
  'randomized=${vote.traceOrderRandomized}',
].join('/');
