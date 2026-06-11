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

class EvalPairwiseTraceRef {
  const EvalPairwiseTraceRef({
    required this.runId,
    required this.scenarioId,
    required this.profileName,
    required this.agentKind,
    required this.modelClass,
    required this.capabilityId,
    required this.trialIndex,
    required this.traceDigest,
    required this.scenarioDigest,
    required this.profileDigest,
    this.cascadeWake,
  });

  factory EvalPairwiseTraceRef.fromTrace(
    EvalTrace trace, {
    required String traceDigest,
  }) => EvalPairwiseTraceRef(
    runId: trace.runId,
    scenarioId: trace.scenario.id,
    profileName: trace.profile.name,
    agentKind: trace.scenario.agentKind,
    modelClass: trace.profile.modelClass,
    capabilityId: trace.scenario.metadata.primaryCapabilityId ?? '',
    trialIndex: trace.trialIndex,
    cascadeWake: trace.cascadeWake,
    traceDigest: traceDigest,
    scenarioDigest: trace.provenance.scenarioDigest,
    profileDigest: trace.provenance.profileDigest,
  );

  factory EvalPairwiseTraceRef.fromJson(Map<String, dynamic> json) =>
      EvalPairwiseTraceRef(
        runId: json['runId'] as String,
        scenarioId: json['scenarioId'] as String,
        profileName: json['profileName'] as String,
        agentKind: AgentKind.fromName(json['agentKind'] as String),
        modelClass: EvalModelClass.fromName(json['modelClass'] as String),
        capabilityId: (json['capabilityId'] as String?) ?? '',
        trialIndex: (json['trialIndex'] as num).toInt(),
        cascadeWake: json['cascadeWake'] == null
            ? null
            : EvalTraceCascadeWake.fromJson(
                json['cascadeWake'] as Map<String, dynamic>,
              ),
        traceDigest: json['traceDigest'] as String,
        scenarioDigest: json['scenarioDigest'] as String,
        profileDigest: json['profileDigest'] as String,
      );

  final String runId;
  final String scenarioId;
  final String profileName;
  final AgentKind agentKind;
  final EvalModelClass modelClass;
  final String capabilityId;
  final int trialIndex;
  final EvalTraceCascadeWake? cascadeWake;
  final String traceDigest;
  final String scenarioDigest;
  final String profileDigest;

  String get traceKey {
    final suffix = cascadeWake == null ? '' : '::${cascadeWake!.keySuffix}';
    return '$runId::$scenarioId::$profileName::trial-$trialIndex$suffix';
  }

  String get artifactKey => '$traceKey::$traceDigest';

  String get comparableKey {
    final suffix = cascadeWake == null ? '' : '::${cascadeWake!.keySuffix}';
    return '$runId::$scenarioId::trial-$trialIndex$suffix';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'runId': runId,
    'scenarioId': scenarioId,
    'profileName': profileName,
    'agentKind': agentKind.name,
    'modelClass': modelClass.name,
    'capabilityId': capabilityId,
    'trialIndex': trialIndex,
    if (cascadeWake != null) 'cascadeWake': cascadeWake!.toJson(),
    'traceDigest': traceDigest,
    'scenarioDigest': scenarioDigest,
    'profileDigest': profileDigest,
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
    this.issues = const <String>[],
  });

  factory EvalPairwisePreferenceVote.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != EvalPairwisePreferenceVote.schemaVersion) {
      throw FormatException(
        'Unsupported EvalPairwisePreferenceVote schemaVersion '
        '$schemaVersion (expected ${EvalPairwisePreferenceVote.schemaVersion})',
      );
    }
    return EvalPairwisePreferenceVote(
      voteId: json['voteId'] as String,
      optionA: EvalPairwiseTraceRef.fromJson(
        json['optionA'] as Map<String, dynamic>,
      ),
      optionB: EvalPairwiseTraceRef.fromJson(
        json['optionB'] as Map<String, dynamic>,
      ),
      reviewerId: json['reviewerId'] as String,
      reviewerKind: EvalPairwiseReviewerKind.fromName(
        json['reviewerKind'] as String,
      ),
      reviewerModel: json['reviewerModel'] as String?,
      promptDigest: json['promptDigest'] as String,
      calibrationSetVersion: json['calibrationSetVersion'] as String,
      profileVisible: json['profileVisible'] as bool,
      modelIdentityVisible: json['modelIdentityVisible'] as bool,
      peerVotesVisible: json['peerVotesVisible'] as bool,
      traceOrderRandomized: json['traceOrderRandomized'] as bool,
      choice: EvalPairwisePreferenceChoice.fromName(json['choice'] as String),
      rationale: json['rationale'] as String,
      issues: ((json['issues'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => e as String)
          .toList(),
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

  String get comparisonKey =>
      '${canonicalOptionA.comparableKey}::${canonicalOptionA.artifactKey}::'
      '${canonicalOptionB.artifactKey}';

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
    'issues': issues,
  };

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
    if (optionA.profileName == optionB.profileName) {
      failures.add('option A and option B profiles must differ');
    }
    if (optionA.comparableKey != optionB.comparableKey) {
      failures.add(
        'option A and option B traces must share scenario, trial, and '
        'cascade wake',
      );
    }
    if (optionA.capabilityId != optionB.capabilityId) {
      failures.add('option A and option B traces must share capabilityId');
    }
    if (optionA.agentKind != optionB.agentKind) {
      failures.add('option A and option B traces must share agentKind');
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
  });

  final int minVotes;
  final double quorumFraction;
  final bool requireModelIdentityBlind;
  final bool requireProfileBlind;
  final bool requirePeerVoteBlind;
  final bool requireTraceOrderRandomized;
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
        'option A profile  option B profile  scenario                           '
        'status        votes  valid  A/B/T  quorum  findings',
      )
      ..writeln(
        '----------------  ----------------  ---------------------------------  '
        '------------  -----  -----  -----  ------  --------',
      );
    for (final summary in summaries) {
      buffer.writeln(
        '${_clip(summary.optionA.profileName, 16).padRight(16)}  '
        '${_clip(summary.optionB.profileName, 16).padRight(16)}  '
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

    final validVotes = [
      for (final vote in votes)
        if (!invalidVoteIds.contains(vote.voteId)) vote,
    ];
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
  _requireNonEmpty(failures, '$label.capabilityId', ref.capabilityId);
  _requireDigest(failures, '$label.traceDigest', ref.traceDigest);
  _requireDigest(failures, '$label.scenarioDigest', ref.scenarioDigest);
  _requireDigest(failures, '$label.profileDigest', ref.profileDigest);
}

void _requireNonEmpty(List<String> failures, String field, String value) {
  if (value.trim().isEmpty) failures.add('$field is empty');
}

void _requireDigest(List<String> failures, String field, String value) {
  if (!EvalProvenance.isDigest(value)) {
    failures.add('$field is not a sha256 digest');
  }
}

String _clip(String value, int width) {
  if (value.length <= width) return value;
  if (width <= 1) return value.substring(0, width);
  return '${value.substring(0, width - 1)}~';
}
