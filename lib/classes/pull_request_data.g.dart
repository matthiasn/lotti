// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PullRequestData _$PullRequestDataFromJson(Map<String, dynamic> json) =>
    _PullRequestData(
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      number: (json['number'] as num).toInt(),
      snapshot: json['snapshot'] == null
          ? null
          : PullRequestSnapshot.fromJson(
              json['snapshot'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$PullRequestDataToJson(_PullRequestData instance) =>
    <String, dynamic>{
      'owner': instance.owner,
      'repo': instance.repo,
      'number': instance.number,
      'snapshot': instance.snapshot,
    };

_PullRequestSnapshot _$PullRequestSnapshotFromJson(Map<String, dynamic> json) =>
    _PullRequestSnapshot(
      observedAt: DateTime.parse(json['observedAt'] as String),
      title: json['title'] as String,
      status: $enumDecode(_$PullRequestStatusEnumMap, json['status']),
      htmlUrl: json['htmlUrl'] as String,
      headSha: json['headSha'] as String,
      headRef: json['headRef'] as String,
      baseRef: json['baseRef'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      body: json['body'] as String?,
      draft: json['draft'] as bool? ?? false,
      authorLogin: json['authorLogin'] as String?,
      mergedAt: json['mergedAt'] == null
          ? null
          : DateTime.parse(json['mergedAt'] as String),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      mergeability:
          $enumDecodeNullable(
            _$PullRequestMergeabilityEnumMap,
            json['mergeability'],
            unknownValue: PullRequestMergeability.unknown,
          ) ??
          PullRequestMergeability.unknown,
      checks: json['checks'] == null
          ? const PullRequestChecks()
          : PullRequestChecks.fromJson(json['checks'] as Map<String, dynamic>),
      reviews: json['reviews'] == null
          ? const PullRequestReviews()
          : PullRequestReviews.fromJson(
              json['reviews'] as Map<String, dynamic>,
            ),
      additions: (json['additions'] as num?)?.toInt(),
      deletions: (json['deletions'] as num?)?.toInt(),
      changedFiles: (json['changedFiles'] as num?)?.toInt(),
      commits: (json['commits'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PullRequestSnapshotToJson(
  _PullRequestSnapshot instance,
) => <String, dynamic>{
  'observedAt': instance.observedAt.toIso8601String(),
  'title': instance.title,
  'status': _$PullRequestStatusEnumMap[instance.status]!,
  'htmlUrl': instance.htmlUrl,
  'headSha': instance.headSha,
  'headRef': instance.headRef,
  'baseRef': instance.baseRef,
  'createdAt': ?instance.createdAt?.toIso8601String(),
  'body': instance.body,
  'draft': instance.draft,
  'authorLogin': instance.authorLogin,
  'mergedAt': instance.mergedAt?.toIso8601String(),
  'closedAt': instance.closedAt?.toIso8601String(),
  'mergeability': _$PullRequestMergeabilityEnumMap[instance.mergeability]!,
  'checks': instance.checks,
  'reviews': instance.reviews,
  'additions': instance.additions,
  'deletions': instance.deletions,
  'changedFiles': instance.changedFiles,
  'commits': instance.commits,
};

const _$PullRequestStatusEnumMap = {
  PullRequestStatus.open: 'open',
  PullRequestStatus.closed: 'closed',
  PullRequestStatus.merged: 'merged',
};

const _$PullRequestMergeabilityEnumMap = {
  PullRequestMergeability.clean: 'clean',
  PullRequestMergeability.conflicting: 'conflicting',
  PullRequestMergeability.behind: 'behind',
  PullRequestMergeability.blocked: 'blocked',
  PullRequestMergeability.unknown: 'unknown',
};

_PullRequestChecks _$PullRequestChecksFromJson(Map<String, dynamic> json) =>
    _PullRequestChecks(
      rollup:
          $enumDecodeNullable(
            _$PullRequestCheckRollupEnumMap,
            json['rollup'],
            unknownValue: PullRequestCheckRollup.none,
          ) ??
          PullRequestCheckRollup.none,
      total: (json['total'] as num?)?.toInt() ?? 0,
      passed: (json['passed'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      failingNames:
          (json['failingNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      checkRunsHidden: json['checkRunsHidden'] as bool?,
    );

Map<String, dynamic> _$PullRequestChecksToJson(_PullRequestChecks instance) =>
    <String, dynamic>{
      'rollup': _$PullRequestCheckRollupEnumMap[instance.rollup]!,
      'total': instance.total,
      'passed': instance.passed,
      'failed': instance.failed,
      'pending': instance.pending,
      'failingNames': instance.failingNames,
      'checkRunsHidden': ?instance.checkRunsHidden,
    };

const _$PullRequestCheckRollupEnumMap = {
  PullRequestCheckRollup.passing: 'passing',
  PullRequestCheckRollup.failing: 'failing',
  PullRequestCheckRollup.pending: 'pending',
  PullRequestCheckRollup.none: 'none',
};

_PullRequestReviews _$PullRequestReviewsFromJson(Map<String, dynamic> json) =>
    _PullRequestReviews(
      decision:
          $enumDecodeNullable(
            _$PullRequestReviewDecisionEnumMap,
            json['decision'],
            unknownValue: PullRequestReviewDecision.none,
          ) ??
          PullRequestReviewDecision.none,
      approvals: (json['approvals'] as num?)?.toInt() ?? 0,
      changesRequested: (json['changesRequested'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PullRequestReviewsToJson(_PullRequestReviews instance) =>
    <String, dynamic>{
      'decision': _$PullRequestReviewDecisionEnumMap[instance.decision]!,
      'approvals': instance.approvals,
      'changesRequested': instance.changesRequested,
    };

const _$PullRequestReviewDecisionEnumMap = {
  PullRequestReviewDecision.approved: 'approved',
  PullRequestReviewDecision.changesRequested: 'changesRequested',
  PullRequestReviewDecision.pending: 'pending',
  PullRequestReviewDecision.none: 'none',
};
