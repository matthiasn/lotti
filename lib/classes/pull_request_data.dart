import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';

part 'pull_request_data.freezed.dart';
part 'pull_request_data.g.dart';

/// Payload of a `JournalEntity.pullRequest` — a GitHub pull request linked to
/// a task, and the snapshot of it the last successful refresh observed.
///
/// The identity ([owner], [repo], [number]) is fixed when the pull request is
/// linked; only [snapshot] changes. Refreshes, the merge of concurrent
/// versions, and what a task context may claim from it follow the design
/// model `specs/tla/PullRequestSnapshot.tla`.
@freezed
abstract class PullRequestData with _$PullRequestData {
  const factory PullRequestData({
    /// Repository owner, a user or organisation login.
    required String owner,

    /// Repository name.
    required String repo,

    /// The pull request's number in [owner]/[repo].
    required int number,

    /// What the last successful refresh observed; null until the first one.
    PullRequestSnapshot? snapshot,
  }) = _PullRequestData;

  factory PullRequestData.fromJson(Map<String, dynamic> json) =>
      _$PullRequestDataFromJson(json);
}

/// The state of a pull request at [observedAt], as GitHub reported it.
///
/// Everything here was true at [observedAt] and is claimed for no later
/// instant: the app labels it with its age, and a task context calls it
/// current only when its own refresh just observed it.
@freezed
abstract class PullRequestSnapshot with _$PullRequestSnapshot {
  const factory PullRequestSnapshot({
    /// When GitHub produced the response: its `Date` header, in UTC. The
    /// server's clock, shared by every device, orders observations; the
    /// device clock never stamps one.
    required DateTime observedAt,
    required String title,
    required PullRequestStatus status,
    required String htmlUrl,
    required String headSha,
    required String headRef,
    required String baseRef,

    /// The description, Markdown; null when the pull request has none.
    String? body,
    @Default(false) bool draft,
    String? authorLogin,
    DateTime? mergedAt,
    DateTime? closedAt,
    @JsonKey(unknownEnumValue: PullRequestMergeability.unknown)
    @Default(PullRequestMergeability.unknown)
    PullRequestMergeability mergeability,
    @Default(PullRequestChecks()) PullRequestChecks checks,
    @Default(PullRequestReviews()) PullRequestReviews reviews,
    int? additions,
    int? deletions,
    int? changedFiles,
    int? commits,
  }) = _PullRequestSnapshot;

  factory PullRequestSnapshot.fromJson(Map<String, dynamic> json) =>
      _$PullRequestSnapshotFromJson(json);
}

/// Open, closed without merging, or merged. A merged pull request never
/// changes status again; a closed one can be reopened.
@JsonEnum()
enum PullRequestStatus { open, closed, merged }

/// Whether the head can be merged into the base, from GitHub's `mergeable`
/// and `mergeable_state`.
@JsonEnum()
enum PullRequestMergeability {
  /// Mergeable as it stands.
  clean,

  /// Merge conflicts with the base.
  conflicting,

  /// Behind the base, and the base requires an up-to-date branch.
  behind,

  /// Blocked by branch protection: a required review or check is missing.
  blocked,

  /// Not known: GitHub is still computing it, or reported a state this
  /// version does not recognise.
  unknown,
}

/// The rollup of every check run and commit status on the head commit.
@JsonEnum()
enum PullRequestCheckRollup { passing, failing, pending, none }

@freezed
abstract class PullRequestChecks with _$PullRequestChecks {
  const factory PullRequestChecks({
    @JsonKey(unknownEnumValue: PullRequestCheckRollup.none)
    @Default(PullRequestCheckRollup.none)
    PullRequestCheckRollup rollup,
    @Default(0) int total,
    @Default(0) int passed,
    @Default(0) int failed,
    @Default(0) int pending,

    /// Names of the failing checks, at most [maxFailingNames] of them.
    @Default(<String>[]) List<String> failingNames,
  }) = _PullRequestChecks;

  factory PullRequestChecks.fromJson(Map<String, dynamic> json) =>
      _$PullRequestChecksFromJson(json);

  /// How many failing check names a snapshot keeps.
  static const maxFailingNames = 10;
}

/// The review decision: each reviewer's latest review counts once.
@JsonEnum()
enum PullRequestReviewDecision { approved, changesRequested, pending, none }

@freezed
abstract class PullRequestReviews with _$PullRequestReviews {
  const factory PullRequestReviews({
    @JsonKey(unknownEnumValue: PullRequestReviewDecision.none)
    @Default(PullRequestReviewDecision.none)
    PullRequestReviewDecision decision,
    @Default(0) int approvals,
    @Default(0) int changesRequested,
  }) = _PullRequestReviews;

  factory PullRequestReviews.fromJson(Map<String, dynamic> json) =>
      _$PullRequestReviewsFromJson(json);
}

extension PullRequestDataX on PullRequestData {
  PullRequestRef get ref =>
      PullRequestRef(owner: owner, repo: repo, number: number);

  /// [PullRequestRef.key]: the journal row's subtype, so a duplicate link is
  /// an indexed lookup.
  String get key => ref.key;
}
