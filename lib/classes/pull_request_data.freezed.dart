// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PullRequestData {

/// Repository owner, a user or organisation login.
 String get owner;/// Repository name.
 String get repo;/// The pull request's number in [owner]/[repo].
 int get number;/// What the last successful refresh observed; null until the first one.
 PullRequestSnapshot? get snapshot;
/// Create a copy of PullRequestData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestDataCopyWith<PullRequestData> get copyWith => _$PullRequestDataCopyWithImpl<PullRequestData>(this as PullRequestData, _$identity);

  /// Serializes this PullRequestData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestData&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.repo, repo) || other.repo == repo)&&(identical(other.number, number) || other.number == number)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,owner,repo,number,snapshot);

@override
String toString() {
  return 'PullRequestData(owner: $owner, repo: $repo, number: $number, snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class $PullRequestDataCopyWith<$Res>  {
  factory $PullRequestDataCopyWith(PullRequestData value, $Res Function(PullRequestData) _then) = _$PullRequestDataCopyWithImpl;
@useResult
$Res call({
 String owner, String repo, int number, PullRequestSnapshot? snapshot
});


$PullRequestSnapshotCopyWith<$Res>? get snapshot;

}
/// @nodoc
class _$PullRequestDataCopyWithImpl<$Res>
    implements $PullRequestDataCopyWith<$Res> {
  _$PullRequestDataCopyWithImpl(this._self, this._then);

  final PullRequestData _self;
  final $Res Function(PullRequestData) _then;

/// Create a copy of PullRequestData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? owner = null,Object? repo = null,Object? number = null,Object? snapshot = freezed,}) {
  return _then(_self.copyWith(
owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as PullRequestSnapshot?,
  ));
}
/// Create a copy of PullRequestData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestSnapshotCopyWith<$Res>? get snapshot {
    if (_self.snapshot == null) {
    return null;
  }

  return $PullRequestSnapshotCopyWith<$Res>(_self.snapshot!, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [PullRequestData].
extension PullRequestDataPatterns on PullRequestData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PullRequestData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PullRequestData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PullRequestData value)  $default,){
final _that = this;
switch (_that) {
case _PullRequestData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PullRequestData value)?  $default,){
final _that = this;
switch (_that) {
case _PullRequestData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String owner,  String repo,  int number,  PullRequestSnapshot? snapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PullRequestData() when $default != null:
return $default(_that.owner,_that.repo,_that.number,_that.snapshot);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String owner,  String repo,  int number,  PullRequestSnapshot? snapshot)  $default,) {final _that = this;
switch (_that) {
case _PullRequestData():
return $default(_that.owner,_that.repo,_that.number,_that.snapshot);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String owner,  String repo,  int number,  PullRequestSnapshot? snapshot)?  $default,) {final _that = this;
switch (_that) {
case _PullRequestData() when $default != null:
return $default(_that.owner,_that.repo,_that.number,_that.snapshot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PullRequestData implements PullRequestData {
  const _PullRequestData({required this.owner, required this.repo, required this.number, this.snapshot});
  factory _PullRequestData.fromJson(Map<String, dynamic> json) => _$PullRequestDataFromJson(json);

/// Repository owner, a user or organisation login.
@override final  String owner;
/// Repository name.
@override final  String repo;
/// The pull request's number in [owner]/[repo].
@override final  int number;
/// What the last successful refresh observed; null until the first one.
@override final  PullRequestSnapshot? snapshot;

/// Create a copy of PullRequestData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestDataCopyWith<_PullRequestData> get copyWith => __$PullRequestDataCopyWithImpl<_PullRequestData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestData&&(identical(other.owner, owner) || other.owner == owner)&&(identical(other.repo, repo) || other.repo == repo)&&(identical(other.number, number) || other.number == number)&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,owner,repo,number,snapshot);

@override
String toString() {
  return 'PullRequestData(owner: $owner, repo: $repo, number: $number, snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class _$PullRequestDataCopyWith<$Res> implements $PullRequestDataCopyWith<$Res> {
  factory _$PullRequestDataCopyWith(_PullRequestData value, $Res Function(_PullRequestData) _then) = __$PullRequestDataCopyWithImpl;
@override @useResult
$Res call({
 String owner, String repo, int number, PullRequestSnapshot? snapshot
});


@override $PullRequestSnapshotCopyWith<$Res>? get snapshot;

}
/// @nodoc
class __$PullRequestDataCopyWithImpl<$Res>
    implements _$PullRequestDataCopyWith<$Res> {
  __$PullRequestDataCopyWithImpl(this._self, this._then);

  final _PullRequestData _self;
  final $Res Function(_PullRequestData) _then;

/// Create a copy of PullRequestData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? owner = null,Object? repo = null,Object? number = null,Object? snapshot = freezed,}) {
  return _then(_PullRequestData(
owner: null == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,snapshot: freezed == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as PullRequestSnapshot?,
  ));
}

/// Create a copy of PullRequestData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestSnapshotCopyWith<$Res>? get snapshot {
    if (_self.snapshot == null) {
    return null;
  }

  return $PullRequestSnapshotCopyWith<$Res>(_self.snapshot!, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// @nodoc
mixin _$PullRequestSnapshot {

/// When GitHub produced the response: its `Date` header, in UTC. The
/// server's clock, shared by every device, orders observations; the
/// device clock never stamps one.
 DateTime get observedAt; String get title; PullRequestStatus get status; String get htmlUrl; String get headSha; String get headRef; String get baseRef;/// The description, Markdown; null when the pull request has none.
 String? get body; bool get draft; String? get authorLogin; DateTime? get mergedAt; DateTime? get closedAt;@JsonKey(unknownEnumValue: PullRequestMergeability.unknown) PullRequestMergeability get mergeability; PullRequestChecks get checks; PullRequestReviews get reviews; int? get additions; int? get deletions; int? get changedFiles; int? get commits;
/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestSnapshotCopyWith<PullRequestSnapshot> get copyWith => _$PullRequestSnapshotCopyWithImpl<PullRequestSnapshot>(this as PullRequestSnapshot, _$identity);

  /// Serializes this PullRequestSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestSnapshot&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl)&&(identical(other.headSha, headSha) || other.headSha == headSha)&&(identical(other.headRef, headRef) || other.headRef == headRef)&&(identical(other.baseRef, baseRef) || other.baseRef == baseRef)&&(identical(other.body, body) || other.body == body)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.authorLogin, authorLogin) || other.authorLogin == authorLogin)&&(identical(other.mergedAt, mergedAt) || other.mergedAt == mergedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.mergeability, mergeability) || other.mergeability == mergeability)&&(identical(other.checks, checks) || other.checks == checks)&&(identical(other.reviews, reviews) || other.reviews == reviews)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.changedFiles, changedFiles) || other.changedFiles == changedFiles)&&(identical(other.commits, commits) || other.commits == commits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,observedAt,title,status,htmlUrl,headSha,headRef,baseRef,body,draft,authorLogin,mergedAt,closedAt,mergeability,checks,reviews,additions,deletions,changedFiles,commits]);

@override
String toString() {
  return 'PullRequestSnapshot(observedAt: $observedAt, title: $title, status: $status, htmlUrl: $htmlUrl, headSha: $headSha, headRef: $headRef, baseRef: $baseRef, body: $body, draft: $draft, authorLogin: $authorLogin, mergedAt: $mergedAt, closedAt: $closedAt, mergeability: $mergeability, checks: $checks, reviews: $reviews, additions: $additions, deletions: $deletions, changedFiles: $changedFiles, commits: $commits)';
}


}

/// @nodoc
abstract mixin class $PullRequestSnapshotCopyWith<$Res>  {
  factory $PullRequestSnapshotCopyWith(PullRequestSnapshot value, $Res Function(PullRequestSnapshot) _then) = _$PullRequestSnapshotCopyWithImpl;
@useResult
$Res call({
 DateTime observedAt, String title, PullRequestStatus status, String htmlUrl, String headSha, String headRef, String baseRef, String? body, bool draft, String? authorLogin, DateTime? mergedAt, DateTime? closedAt,@JsonKey(unknownEnumValue: PullRequestMergeability.unknown) PullRequestMergeability mergeability, PullRequestChecks checks, PullRequestReviews reviews, int? additions, int? deletions, int? changedFiles, int? commits
});


$PullRequestChecksCopyWith<$Res> get checks;$PullRequestReviewsCopyWith<$Res> get reviews;

}
/// @nodoc
class _$PullRequestSnapshotCopyWithImpl<$Res>
    implements $PullRequestSnapshotCopyWith<$Res> {
  _$PullRequestSnapshotCopyWithImpl(this._self, this._then);

  final PullRequestSnapshot _self;
  final $Res Function(PullRequestSnapshot) _then;

/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? observedAt = null,Object? title = null,Object? status = null,Object? htmlUrl = null,Object? headSha = null,Object? headRef = null,Object? baseRef = null,Object? body = freezed,Object? draft = null,Object? authorLogin = freezed,Object? mergedAt = freezed,Object? closedAt = freezed,Object? mergeability = null,Object? checks = null,Object? reviews = null,Object? additions = freezed,Object? deletions = freezed,Object? changedFiles = freezed,Object? commits = freezed,}) {
  return _then(_self.copyWith(
observedAt: null == observedAt ? _self.observedAt : observedAt // ignore: cast_nullable_to_non_nullable
as DateTime,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PullRequestStatus,htmlUrl: null == htmlUrl ? _self.htmlUrl : htmlUrl // ignore: cast_nullable_to_non_nullable
as String,headSha: null == headSha ? _self.headSha : headSha // ignore: cast_nullable_to_non_nullable
as String,headRef: null == headRef ? _self.headRef : headRef // ignore: cast_nullable_to_non_nullable
as String,baseRef: null == baseRef ? _self.baseRef : baseRef // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool,authorLogin: freezed == authorLogin ? _self.authorLogin : authorLogin // ignore: cast_nullable_to_non_nullable
as String?,mergedAt: freezed == mergedAt ? _self.mergedAt : mergedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,mergeability: null == mergeability ? _self.mergeability : mergeability // ignore: cast_nullable_to_non_nullable
as PullRequestMergeability,checks: null == checks ? _self.checks : checks // ignore: cast_nullable_to_non_nullable
as PullRequestChecks,reviews: null == reviews ? _self.reviews : reviews // ignore: cast_nullable_to_non_nullable
as PullRequestReviews,additions: freezed == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int?,deletions: freezed == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int?,changedFiles: freezed == changedFiles ? _self.changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as int?,commits: freezed == commits ? _self.commits : commits // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestChecksCopyWith<$Res> get checks {
  
  return $PullRequestChecksCopyWith<$Res>(_self.checks, (value) {
    return _then(_self.copyWith(checks: value));
  });
}/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestReviewsCopyWith<$Res> get reviews {
  
  return $PullRequestReviewsCopyWith<$Res>(_self.reviews, (value) {
    return _then(_self.copyWith(reviews: value));
  });
}
}


/// Adds pattern-matching-related methods to [PullRequestSnapshot].
extension PullRequestSnapshotPatterns on PullRequestSnapshot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PullRequestSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PullRequestSnapshot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PullRequestSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _PullRequestSnapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PullRequestSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _PullRequestSnapshot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime observedAt,  String title,  PullRequestStatus status,  String htmlUrl,  String headSha,  String headRef,  String baseRef,  String? body,  bool draft,  String? authorLogin,  DateTime? mergedAt,  DateTime? closedAt, @JsonKey(unknownEnumValue: PullRequestMergeability.unknown)  PullRequestMergeability mergeability,  PullRequestChecks checks,  PullRequestReviews reviews,  int? additions,  int? deletions,  int? changedFiles,  int? commits)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PullRequestSnapshot() when $default != null:
return $default(_that.observedAt,_that.title,_that.status,_that.htmlUrl,_that.headSha,_that.headRef,_that.baseRef,_that.body,_that.draft,_that.authorLogin,_that.mergedAt,_that.closedAt,_that.mergeability,_that.checks,_that.reviews,_that.additions,_that.deletions,_that.changedFiles,_that.commits);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime observedAt,  String title,  PullRequestStatus status,  String htmlUrl,  String headSha,  String headRef,  String baseRef,  String? body,  bool draft,  String? authorLogin,  DateTime? mergedAt,  DateTime? closedAt, @JsonKey(unknownEnumValue: PullRequestMergeability.unknown)  PullRequestMergeability mergeability,  PullRequestChecks checks,  PullRequestReviews reviews,  int? additions,  int? deletions,  int? changedFiles,  int? commits)  $default,) {final _that = this;
switch (_that) {
case _PullRequestSnapshot():
return $default(_that.observedAt,_that.title,_that.status,_that.htmlUrl,_that.headSha,_that.headRef,_that.baseRef,_that.body,_that.draft,_that.authorLogin,_that.mergedAt,_that.closedAt,_that.mergeability,_that.checks,_that.reviews,_that.additions,_that.deletions,_that.changedFiles,_that.commits);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime observedAt,  String title,  PullRequestStatus status,  String htmlUrl,  String headSha,  String headRef,  String baseRef,  String? body,  bool draft,  String? authorLogin,  DateTime? mergedAt,  DateTime? closedAt, @JsonKey(unknownEnumValue: PullRequestMergeability.unknown)  PullRequestMergeability mergeability,  PullRequestChecks checks,  PullRequestReviews reviews,  int? additions,  int? deletions,  int? changedFiles,  int? commits)?  $default,) {final _that = this;
switch (_that) {
case _PullRequestSnapshot() when $default != null:
return $default(_that.observedAt,_that.title,_that.status,_that.htmlUrl,_that.headSha,_that.headRef,_that.baseRef,_that.body,_that.draft,_that.authorLogin,_that.mergedAt,_that.closedAt,_that.mergeability,_that.checks,_that.reviews,_that.additions,_that.deletions,_that.changedFiles,_that.commits);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PullRequestSnapshot implements PullRequestSnapshot {
  const _PullRequestSnapshot({required this.observedAt, required this.title, required this.status, required this.htmlUrl, required this.headSha, required this.headRef, required this.baseRef, this.body, this.draft = false, this.authorLogin, this.mergedAt, this.closedAt, @JsonKey(unknownEnumValue: PullRequestMergeability.unknown) this.mergeability = PullRequestMergeability.unknown, this.checks = const PullRequestChecks(), this.reviews = const PullRequestReviews(), this.additions, this.deletions, this.changedFiles, this.commits});
  factory _PullRequestSnapshot.fromJson(Map<String, dynamic> json) => _$PullRequestSnapshotFromJson(json);

/// When GitHub produced the response: its `Date` header, in UTC. The
/// server's clock, shared by every device, orders observations; the
/// device clock never stamps one.
@override final  DateTime observedAt;
@override final  String title;
@override final  PullRequestStatus status;
@override final  String htmlUrl;
@override final  String headSha;
@override final  String headRef;
@override final  String baseRef;
/// The description, Markdown; null when the pull request has none.
@override final  String? body;
@override@JsonKey() final  bool draft;
@override final  String? authorLogin;
@override final  DateTime? mergedAt;
@override final  DateTime? closedAt;
@override@JsonKey(unknownEnumValue: PullRequestMergeability.unknown) final  PullRequestMergeability mergeability;
@override@JsonKey() final  PullRequestChecks checks;
@override@JsonKey() final  PullRequestReviews reviews;
@override final  int? additions;
@override final  int? deletions;
@override final  int? changedFiles;
@override final  int? commits;

/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestSnapshotCopyWith<_PullRequestSnapshot> get copyWith => __$PullRequestSnapshotCopyWithImpl<_PullRequestSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestSnapshot&&(identical(other.observedAt, observedAt) || other.observedAt == observedAt)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl)&&(identical(other.headSha, headSha) || other.headSha == headSha)&&(identical(other.headRef, headRef) || other.headRef == headRef)&&(identical(other.baseRef, baseRef) || other.baseRef == baseRef)&&(identical(other.body, body) || other.body == body)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.authorLogin, authorLogin) || other.authorLogin == authorLogin)&&(identical(other.mergedAt, mergedAt) || other.mergedAt == mergedAt)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.mergeability, mergeability) || other.mergeability == mergeability)&&(identical(other.checks, checks) || other.checks == checks)&&(identical(other.reviews, reviews) || other.reviews == reviews)&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions)&&(identical(other.changedFiles, changedFiles) || other.changedFiles == changedFiles)&&(identical(other.commits, commits) || other.commits == commits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,observedAt,title,status,htmlUrl,headSha,headRef,baseRef,body,draft,authorLogin,mergedAt,closedAt,mergeability,checks,reviews,additions,deletions,changedFiles,commits]);

@override
String toString() {
  return 'PullRequestSnapshot(observedAt: $observedAt, title: $title, status: $status, htmlUrl: $htmlUrl, headSha: $headSha, headRef: $headRef, baseRef: $baseRef, body: $body, draft: $draft, authorLogin: $authorLogin, mergedAt: $mergedAt, closedAt: $closedAt, mergeability: $mergeability, checks: $checks, reviews: $reviews, additions: $additions, deletions: $deletions, changedFiles: $changedFiles, commits: $commits)';
}


}

/// @nodoc
abstract mixin class _$PullRequestSnapshotCopyWith<$Res> implements $PullRequestSnapshotCopyWith<$Res> {
  factory _$PullRequestSnapshotCopyWith(_PullRequestSnapshot value, $Res Function(_PullRequestSnapshot) _then) = __$PullRequestSnapshotCopyWithImpl;
@override @useResult
$Res call({
 DateTime observedAt, String title, PullRequestStatus status, String htmlUrl, String headSha, String headRef, String baseRef, String? body, bool draft, String? authorLogin, DateTime? mergedAt, DateTime? closedAt,@JsonKey(unknownEnumValue: PullRequestMergeability.unknown) PullRequestMergeability mergeability, PullRequestChecks checks, PullRequestReviews reviews, int? additions, int? deletions, int? changedFiles, int? commits
});


@override $PullRequestChecksCopyWith<$Res> get checks;@override $PullRequestReviewsCopyWith<$Res> get reviews;

}
/// @nodoc
class __$PullRequestSnapshotCopyWithImpl<$Res>
    implements _$PullRequestSnapshotCopyWith<$Res> {
  __$PullRequestSnapshotCopyWithImpl(this._self, this._then);

  final _PullRequestSnapshot _self;
  final $Res Function(_PullRequestSnapshot) _then;

/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? observedAt = null,Object? title = null,Object? status = null,Object? htmlUrl = null,Object? headSha = null,Object? headRef = null,Object? baseRef = null,Object? body = freezed,Object? draft = null,Object? authorLogin = freezed,Object? mergedAt = freezed,Object? closedAt = freezed,Object? mergeability = null,Object? checks = null,Object? reviews = null,Object? additions = freezed,Object? deletions = freezed,Object? changedFiles = freezed,Object? commits = freezed,}) {
  return _then(_PullRequestSnapshot(
observedAt: null == observedAt ? _self.observedAt : observedAt // ignore: cast_nullable_to_non_nullable
as DateTime,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PullRequestStatus,htmlUrl: null == htmlUrl ? _self.htmlUrl : htmlUrl // ignore: cast_nullable_to_non_nullable
as String,headSha: null == headSha ? _self.headSha : headSha // ignore: cast_nullable_to_non_nullable
as String,headRef: null == headRef ? _self.headRef : headRef // ignore: cast_nullable_to_non_nullable
as String,baseRef: null == baseRef ? _self.baseRef : baseRef // ignore: cast_nullable_to_non_nullable
as String,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,draft: null == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool,authorLogin: freezed == authorLogin ? _self.authorLogin : authorLogin // ignore: cast_nullable_to_non_nullable
as String?,mergedAt: freezed == mergedAt ? _self.mergedAt : mergedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,mergeability: null == mergeability ? _self.mergeability : mergeability // ignore: cast_nullable_to_non_nullable
as PullRequestMergeability,checks: null == checks ? _self.checks : checks // ignore: cast_nullable_to_non_nullable
as PullRequestChecks,reviews: null == reviews ? _self.reviews : reviews // ignore: cast_nullable_to_non_nullable
as PullRequestReviews,additions: freezed == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int?,deletions: freezed == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int?,changedFiles: freezed == changedFiles ? _self.changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as int?,commits: freezed == commits ? _self.commits : commits // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestChecksCopyWith<$Res> get checks {
  
  return $PullRequestChecksCopyWith<$Res>(_self.checks, (value) {
    return _then(_self.copyWith(checks: value));
  });
}/// Create a copy of PullRequestSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PullRequestReviewsCopyWith<$Res> get reviews {
  
  return $PullRequestReviewsCopyWith<$Res>(_self.reviews, (value) {
    return _then(_self.copyWith(reviews: value));
  });
}
}


/// @nodoc
mixin _$PullRequestChecks {

@JsonKey(unknownEnumValue: PullRequestCheckRollup.none) PullRequestCheckRollup get rollup; int get total; int get passed; int get failed; int get pending;/// Names of the failing checks, at most [maxFailingNames] of them.
 List<String> get failingNames;
/// Create a copy of PullRequestChecks
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestChecksCopyWith<PullRequestChecks> get copyWith => _$PullRequestChecksCopyWithImpl<PullRequestChecks>(this as PullRequestChecks, _$identity);

  /// Serializes this PullRequestChecks to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestChecks&&(identical(other.rollup, rollup) || other.rollup == rollup)&&(identical(other.total, total) || other.total == total)&&(identical(other.passed, passed) || other.passed == passed)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.pending, pending) || other.pending == pending)&&const DeepCollectionEquality().equals(other.failingNames, failingNames));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rollup,total,passed,failed,pending,const DeepCollectionEquality().hash(failingNames));

@override
String toString() {
  return 'PullRequestChecks(rollup: $rollup, total: $total, passed: $passed, failed: $failed, pending: $pending, failingNames: $failingNames)';
}


}

/// @nodoc
abstract mixin class $PullRequestChecksCopyWith<$Res>  {
  factory $PullRequestChecksCopyWith(PullRequestChecks value, $Res Function(PullRequestChecks) _then) = _$PullRequestChecksCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: PullRequestCheckRollup.none) PullRequestCheckRollup rollup, int total, int passed, int failed, int pending, List<String> failingNames
});




}
/// @nodoc
class _$PullRequestChecksCopyWithImpl<$Res>
    implements $PullRequestChecksCopyWith<$Res> {
  _$PullRequestChecksCopyWithImpl(this._self, this._then);

  final PullRequestChecks _self;
  final $Res Function(PullRequestChecks) _then;

/// Create a copy of PullRequestChecks
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rollup = null,Object? total = null,Object? passed = null,Object? failed = null,Object? pending = null,Object? failingNames = null,}) {
  return _then(_self.copyWith(
rollup: null == rollup ? _self.rollup : rollup // ignore: cast_nullable_to_non_nullable
as PullRequestCheckRollup,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,passed: null == passed ? _self.passed : passed // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as int,failingNames: null == failingNames ? _self.failingNames : failingNames // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PullRequestChecks].
extension PullRequestChecksPatterns on PullRequestChecks {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PullRequestChecks value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PullRequestChecks() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PullRequestChecks value)  $default,){
final _that = this;
switch (_that) {
case _PullRequestChecks():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PullRequestChecks value)?  $default,){
final _that = this;
switch (_that) {
case _PullRequestChecks() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: PullRequestCheckRollup.none)  PullRequestCheckRollup rollup,  int total,  int passed,  int failed,  int pending,  List<String> failingNames)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PullRequestChecks() when $default != null:
return $default(_that.rollup,_that.total,_that.passed,_that.failed,_that.pending,_that.failingNames);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: PullRequestCheckRollup.none)  PullRequestCheckRollup rollup,  int total,  int passed,  int failed,  int pending,  List<String> failingNames)  $default,) {final _that = this;
switch (_that) {
case _PullRequestChecks():
return $default(_that.rollup,_that.total,_that.passed,_that.failed,_that.pending,_that.failingNames);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: PullRequestCheckRollup.none)  PullRequestCheckRollup rollup,  int total,  int passed,  int failed,  int pending,  List<String> failingNames)?  $default,) {final _that = this;
switch (_that) {
case _PullRequestChecks() when $default != null:
return $default(_that.rollup,_that.total,_that.passed,_that.failed,_that.pending,_that.failingNames);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PullRequestChecks implements PullRequestChecks {
  const _PullRequestChecks({@JsonKey(unknownEnumValue: PullRequestCheckRollup.none) this.rollup = PullRequestCheckRollup.none, this.total = 0, this.passed = 0, this.failed = 0, this.pending = 0, final  List<String> failingNames = const <String>[]}): _failingNames = failingNames;
  factory _PullRequestChecks.fromJson(Map<String, dynamic> json) => _$PullRequestChecksFromJson(json);

@override@JsonKey(unknownEnumValue: PullRequestCheckRollup.none) final  PullRequestCheckRollup rollup;
@override@JsonKey() final  int total;
@override@JsonKey() final  int passed;
@override@JsonKey() final  int failed;
@override@JsonKey() final  int pending;
/// Names of the failing checks, at most [maxFailingNames] of them.
 final  List<String> _failingNames;
/// Names of the failing checks, at most [maxFailingNames] of them.
@override@JsonKey() List<String> get failingNames {
  if (_failingNames is EqualUnmodifiableListView) return _failingNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_failingNames);
}


/// Create a copy of PullRequestChecks
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestChecksCopyWith<_PullRequestChecks> get copyWith => __$PullRequestChecksCopyWithImpl<_PullRequestChecks>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestChecksToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestChecks&&(identical(other.rollup, rollup) || other.rollup == rollup)&&(identical(other.total, total) || other.total == total)&&(identical(other.passed, passed) || other.passed == passed)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.pending, pending) || other.pending == pending)&&const DeepCollectionEquality().equals(other._failingNames, _failingNames));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,rollup,total,passed,failed,pending,const DeepCollectionEquality().hash(_failingNames));

@override
String toString() {
  return 'PullRequestChecks(rollup: $rollup, total: $total, passed: $passed, failed: $failed, pending: $pending, failingNames: $failingNames)';
}


}

/// @nodoc
abstract mixin class _$PullRequestChecksCopyWith<$Res> implements $PullRequestChecksCopyWith<$Res> {
  factory _$PullRequestChecksCopyWith(_PullRequestChecks value, $Res Function(_PullRequestChecks) _then) = __$PullRequestChecksCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: PullRequestCheckRollup.none) PullRequestCheckRollup rollup, int total, int passed, int failed, int pending, List<String> failingNames
});




}
/// @nodoc
class __$PullRequestChecksCopyWithImpl<$Res>
    implements _$PullRequestChecksCopyWith<$Res> {
  __$PullRequestChecksCopyWithImpl(this._self, this._then);

  final _PullRequestChecks _self;
  final $Res Function(_PullRequestChecks) _then;

/// Create a copy of PullRequestChecks
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rollup = null,Object? total = null,Object? passed = null,Object? failed = null,Object? pending = null,Object? failingNames = null,}) {
  return _then(_PullRequestChecks(
rollup: null == rollup ? _self.rollup : rollup // ignore: cast_nullable_to_non_nullable
as PullRequestCheckRollup,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,passed: null == passed ? _self.passed : passed // ignore: cast_nullable_to_non_nullable
as int,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as int,pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as int,failingNames: null == failingNames ? _self._failingNames : failingNames // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$PullRequestReviews {

@JsonKey(unknownEnumValue: PullRequestReviewDecision.none) PullRequestReviewDecision get decision; int get approvals; int get changesRequested;
/// Create a copy of PullRequestReviews
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestReviewsCopyWith<PullRequestReviews> get copyWith => _$PullRequestReviewsCopyWithImpl<PullRequestReviews>(this as PullRequestReviews, _$identity);

  /// Serializes this PullRequestReviews to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestReviews&&(identical(other.decision, decision) || other.decision == decision)&&(identical(other.approvals, approvals) || other.approvals == approvals)&&(identical(other.changesRequested, changesRequested) || other.changesRequested == changesRequested));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,decision,approvals,changesRequested);

@override
String toString() {
  return 'PullRequestReviews(decision: $decision, approvals: $approvals, changesRequested: $changesRequested)';
}


}

/// @nodoc
abstract mixin class $PullRequestReviewsCopyWith<$Res>  {
  factory $PullRequestReviewsCopyWith(PullRequestReviews value, $Res Function(PullRequestReviews) _then) = _$PullRequestReviewsCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: PullRequestReviewDecision.none) PullRequestReviewDecision decision, int approvals, int changesRequested
});




}
/// @nodoc
class _$PullRequestReviewsCopyWithImpl<$Res>
    implements $PullRequestReviewsCopyWith<$Res> {
  _$PullRequestReviewsCopyWithImpl(this._self, this._then);

  final PullRequestReviews _self;
  final $Res Function(PullRequestReviews) _then;

/// Create a copy of PullRequestReviews
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? decision = null,Object? approvals = null,Object? changesRequested = null,}) {
  return _then(_self.copyWith(
decision: null == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as PullRequestReviewDecision,approvals: null == approvals ? _self.approvals : approvals // ignore: cast_nullable_to_non_nullable
as int,changesRequested: null == changesRequested ? _self.changesRequested : changesRequested // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PullRequestReviews].
extension PullRequestReviewsPatterns on PullRequestReviews {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PullRequestReviews value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PullRequestReviews() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PullRequestReviews value)  $default,){
final _that = this;
switch (_that) {
case _PullRequestReviews():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PullRequestReviews value)?  $default,){
final _that = this;
switch (_that) {
case _PullRequestReviews() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: PullRequestReviewDecision.none)  PullRequestReviewDecision decision,  int approvals,  int changesRequested)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PullRequestReviews() when $default != null:
return $default(_that.decision,_that.approvals,_that.changesRequested);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(unknownEnumValue: PullRequestReviewDecision.none)  PullRequestReviewDecision decision,  int approvals,  int changesRequested)  $default,) {final _that = this;
switch (_that) {
case _PullRequestReviews():
return $default(_that.decision,_that.approvals,_that.changesRequested);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(unknownEnumValue: PullRequestReviewDecision.none)  PullRequestReviewDecision decision,  int approvals,  int changesRequested)?  $default,) {final _that = this;
switch (_that) {
case _PullRequestReviews() when $default != null:
return $default(_that.decision,_that.approvals,_that.changesRequested);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PullRequestReviews implements PullRequestReviews {
  const _PullRequestReviews({@JsonKey(unknownEnumValue: PullRequestReviewDecision.none) this.decision = PullRequestReviewDecision.none, this.approvals = 0, this.changesRequested = 0});
  factory _PullRequestReviews.fromJson(Map<String, dynamic> json) => _$PullRequestReviewsFromJson(json);

@override@JsonKey(unknownEnumValue: PullRequestReviewDecision.none) final  PullRequestReviewDecision decision;
@override@JsonKey() final  int approvals;
@override@JsonKey() final  int changesRequested;

/// Create a copy of PullRequestReviews
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestReviewsCopyWith<_PullRequestReviews> get copyWith => __$PullRequestReviewsCopyWithImpl<_PullRequestReviews>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestReviewsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestReviews&&(identical(other.decision, decision) || other.decision == decision)&&(identical(other.approvals, approvals) || other.approvals == approvals)&&(identical(other.changesRequested, changesRequested) || other.changesRequested == changesRequested));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,decision,approvals,changesRequested);

@override
String toString() {
  return 'PullRequestReviews(decision: $decision, approvals: $approvals, changesRequested: $changesRequested)';
}


}

/// @nodoc
abstract mixin class _$PullRequestReviewsCopyWith<$Res> implements $PullRequestReviewsCopyWith<$Res> {
  factory _$PullRequestReviewsCopyWith(_PullRequestReviews value, $Res Function(_PullRequestReviews) _then) = __$PullRequestReviewsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: PullRequestReviewDecision.none) PullRequestReviewDecision decision, int approvals, int changesRequested
});




}
/// @nodoc
class __$PullRequestReviewsCopyWithImpl<$Res>
    implements _$PullRequestReviewsCopyWith<$Res> {
  __$PullRequestReviewsCopyWithImpl(this._self, this._then);

  final _PullRequestReviews _self;
  final $Res Function(_PullRequestReviews) _then;

/// Create a copy of PullRequestReviews
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? decision = null,Object? approvals = null,Object? changesRequested = null,}) {
  return _then(_PullRequestReviews(
decision: null == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as PullRequestReviewDecision,approvals: null == approvals ? _self.approvals : approvals // ignore: cast_nullable_to_non_nullable
as int,changesRequested: null == changesRequested ? _self.changesRequested : changesRequested // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
