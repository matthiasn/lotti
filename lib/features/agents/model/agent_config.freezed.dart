// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentConfig {

/// Maximum number of tool-call turns per wake.
 int get maxTurnsPerWake;/// Model identifier to use for inference.
 String get modelId;/// Inference profile ID — takes precedence over [modelId] when set.
 String? get profileId;/// Improver ritual cadence in days. Re-homed from `AgentSlots` (PR 4 B4):
/// it is configuration set once at creation, not mutable derived state.
/// Null falls back to the default window. Reads accept the legacy
/// `AgentSlots.feedbackWindowDays` for agents created before the re-home.
 int? get feedbackWindowDays;/// Improver recursion depth: 0 = task improver, 1 = meta-improver. Re-homed
/// from `AgentSlots` (config, not mutable state); legacy slot value is the
/// read fallback for pre-existing agents.
 int? get recursionDepth;
/// Create a copy of AgentConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentConfigCopyWith<AgentConfig> get copyWith => _$AgentConfigCopyWithImpl<AgentConfig>(this as AgentConfig, _$identity);

  /// Serializes this AgentConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentConfig&&(identical(other.maxTurnsPerWake, maxTurnsPerWake) || other.maxTurnsPerWake == maxTurnsPerWake)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.feedbackWindowDays, feedbackWindowDays) || other.feedbackWindowDays == feedbackWindowDays)&&(identical(other.recursionDepth, recursionDepth) || other.recursionDepth == recursionDepth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,maxTurnsPerWake,modelId,profileId,feedbackWindowDays,recursionDepth);

@override
String toString() {
  return 'AgentConfig(maxTurnsPerWake: $maxTurnsPerWake, modelId: $modelId, profileId: $profileId, feedbackWindowDays: $feedbackWindowDays, recursionDepth: $recursionDepth)';
}


}

/// @nodoc
abstract mixin class $AgentConfigCopyWith<$Res>  {
  factory $AgentConfigCopyWith(AgentConfig value, $Res Function(AgentConfig) _then) = _$AgentConfigCopyWithImpl;
@useResult
$Res call({
 int maxTurnsPerWake, String modelId, String? profileId, int? feedbackWindowDays, int? recursionDepth
});




}
/// @nodoc
class _$AgentConfigCopyWithImpl<$Res>
    implements $AgentConfigCopyWith<$Res> {
  _$AgentConfigCopyWithImpl(this._self, this._then);

  final AgentConfig _self;
  final $Res Function(AgentConfig) _then;

/// Create a copy of AgentConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? maxTurnsPerWake = null,Object? modelId = null,Object? profileId = freezed,Object? feedbackWindowDays = freezed,Object? recursionDepth = freezed,}) {
  return _then(_self.copyWith(
maxTurnsPerWake: null == maxTurnsPerWake ? _self.maxTurnsPerWake : maxTurnsPerWake // ignore: cast_nullable_to_non_nullable
as int,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,feedbackWindowDays: freezed == feedbackWindowDays ? _self.feedbackWindowDays : feedbackWindowDays // ignore: cast_nullable_to_non_nullable
as int?,recursionDepth: freezed == recursionDepth ? _self.recursionDepth : recursionDepth // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentConfig].
extension AgentConfigPatterns on AgentConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentConfig value)  $default,){
final _that = this;
switch (_that) {
case _AgentConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentConfig value)?  $default,){
final _that = this;
switch (_that) {
case _AgentConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int maxTurnsPerWake,  String modelId,  String? profileId,  int? feedbackWindowDays,  int? recursionDepth)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentConfig() when $default != null:
return $default(_that.maxTurnsPerWake,_that.modelId,_that.profileId,_that.feedbackWindowDays,_that.recursionDepth);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int maxTurnsPerWake,  String modelId,  String? profileId,  int? feedbackWindowDays,  int? recursionDepth)  $default,) {final _that = this;
switch (_that) {
case _AgentConfig():
return $default(_that.maxTurnsPerWake,_that.modelId,_that.profileId,_that.feedbackWindowDays,_that.recursionDepth);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int maxTurnsPerWake,  String modelId,  String? profileId,  int? feedbackWindowDays,  int? recursionDepth)?  $default,) {final _that = this;
switch (_that) {
case _AgentConfig() when $default != null:
return $default(_that.maxTurnsPerWake,_that.modelId,_that.profileId,_that.feedbackWindowDays,_that.recursionDepth);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentConfig implements AgentConfig {
  const _AgentConfig({this.maxTurnsPerWake = 10, this.modelId = 'models/gemini-3-flash-preview', this.profileId, this.feedbackWindowDays, this.recursionDepth});
  factory _AgentConfig.fromJson(Map<String, dynamic> json) => _$AgentConfigFromJson(json);

/// Maximum number of tool-call turns per wake.
@override@JsonKey() final  int maxTurnsPerWake;
/// Model identifier to use for inference.
@override@JsonKey() final  String modelId;
/// Inference profile ID — takes precedence over [modelId] when set.
@override final  String? profileId;
/// Improver ritual cadence in days. Re-homed from `AgentSlots` (PR 4 B4):
/// it is configuration set once at creation, not mutable derived state.
/// Null falls back to the default window. Reads accept the legacy
/// `AgentSlots.feedbackWindowDays` for agents created before the re-home.
@override final  int? feedbackWindowDays;
/// Improver recursion depth: 0 = task improver, 1 = meta-improver. Re-homed
/// from `AgentSlots` (config, not mutable state); legacy slot value is the
/// read fallback for pre-existing agents.
@override final  int? recursionDepth;

/// Create a copy of AgentConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentConfigCopyWith<_AgentConfig> get copyWith => __$AgentConfigCopyWithImpl<_AgentConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentConfig&&(identical(other.maxTurnsPerWake, maxTurnsPerWake) || other.maxTurnsPerWake == maxTurnsPerWake)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.feedbackWindowDays, feedbackWindowDays) || other.feedbackWindowDays == feedbackWindowDays)&&(identical(other.recursionDepth, recursionDepth) || other.recursionDepth == recursionDepth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,maxTurnsPerWake,modelId,profileId,feedbackWindowDays,recursionDepth);

@override
String toString() {
  return 'AgentConfig(maxTurnsPerWake: $maxTurnsPerWake, modelId: $modelId, profileId: $profileId, feedbackWindowDays: $feedbackWindowDays, recursionDepth: $recursionDepth)';
}


}

/// @nodoc
abstract mixin class _$AgentConfigCopyWith<$Res> implements $AgentConfigCopyWith<$Res> {
  factory _$AgentConfigCopyWith(_AgentConfig value, $Res Function(_AgentConfig) _then) = __$AgentConfigCopyWithImpl;
@override @useResult
$Res call({
 int maxTurnsPerWake, String modelId, String? profileId, int? feedbackWindowDays, int? recursionDepth
});




}
/// @nodoc
class __$AgentConfigCopyWithImpl<$Res>
    implements _$AgentConfigCopyWith<$Res> {
  __$AgentConfigCopyWithImpl(this._self, this._then);

  final _AgentConfig _self;
  final $Res Function(_AgentConfig) _then;

/// Create a copy of AgentConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? maxTurnsPerWake = null,Object? modelId = null,Object? profileId = freezed,Object? feedbackWindowDays = freezed,Object? recursionDepth = freezed,}) {
  return _then(_AgentConfig(
maxTurnsPerWake: null == maxTurnsPerWake ? _self.maxTurnsPerWake : maxTurnsPerWake // ignore: cast_nullable_to_non_nullable
as int,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,feedbackWindowDays: freezed == feedbackWindowDays ? _self.feedbackWindowDays : feedbackWindowDays // ignore: cast_nullable_to_non_nullable
as int?,recursionDepth: freezed == recursionDepth ? _self.recursionDepth : recursionDepth // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$AgentSlots {

/// The journal-domain task ID this agent is working on.
 String? get activeTaskId;/// The day-plan ID this agent is working on.
 String? get activeDayId;/// The project ID this agent is working on.
 String? get activeProjectId;/// The template ID this improver agent manages.
 String? get activeTemplateId;/// When the last one-on-one ritual completed.
 DateTime? get lastOneOnOneAt;/// Incremental feedback scan watermark.
 DateTime? get lastFeedbackScanAt;/// Configurable ritual frequency in days (default 7).
 int? get feedbackWindowDays;/// Total one-on-one sessions completed by this improver (per-host G-counter
/// so concurrent multi-device increments converge to the exact total).
@JsonKey(name: 'totalSessionsCompletedByHost') GCounter get totalSessionsCompleted;/// Recursion depth: 0 = task improver, 1 = meta-improver.
 int? get recursionDepth;/// When the last daily wake completed for project agents.
 DateTime? get lastDailyWakeAt;/// When the last weekly review completed for project agents.
 DateTime? get lastWeeklyReviewAt;/// Total weekly review sessions completed by this project agent (per-host
/// G-counter; not yet incremented anywhere — wired up when the feature lands).
@JsonKey(name: 'weeklyReviewCountByHost') GCounter get weeklyReviewCount;/// Most recent project-linked activity that is not reflected in the
/// current project report yet. `null` means the summary is up to date.
 DateTime? get pendingProjectActivityAt;
/// Create a copy of AgentSlots
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentSlotsCopyWith<AgentSlots> get copyWith => _$AgentSlotsCopyWithImpl<AgentSlots>(this as AgentSlots, _$identity);

  /// Serializes this AgentSlots to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentSlots&&(identical(other.activeTaskId, activeTaskId) || other.activeTaskId == activeTaskId)&&(identical(other.activeDayId, activeDayId) || other.activeDayId == activeDayId)&&(identical(other.activeProjectId, activeProjectId) || other.activeProjectId == activeProjectId)&&(identical(other.activeTemplateId, activeTemplateId) || other.activeTemplateId == activeTemplateId)&&(identical(other.lastOneOnOneAt, lastOneOnOneAt) || other.lastOneOnOneAt == lastOneOnOneAt)&&(identical(other.lastFeedbackScanAt, lastFeedbackScanAt) || other.lastFeedbackScanAt == lastFeedbackScanAt)&&(identical(other.feedbackWindowDays, feedbackWindowDays) || other.feedbackWindowDays == feedbackWindowDays)&&(identical(other.totalSessionsCompleted, totalSessionsCompleted) || other.totalSessionsCompleted == totalSessionsCompleted)&&(identical(other.recursionDepth, recursionDepth) || other.recursionDepth == recursionDepth)&&(identical(other.lastDailyWakeAt, lastDailyWakeAt) || other.lastDailyWakeAt == lastDailyWakeAt)&&(identical(other.lastWeeklyReviewAt, lastWeeklyReviewAt) || other.lastWeeklyReviewAt == lastWeeklyReviewAt)&&(identical(other.weeklyReviewCount, weeklyReviewCount) || other.weeklyReviewCount == weeklyReviewCount)&&(identical(other.pendingProjectActivityAt, pendingProjectActivityAt) || other.pendingProjectActivityAt == pendingProjectActivityAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activeTaskId,activeDayId,activeProjectId,activeTemplateId,lastOneOnOneAt,lastFeedbackScanAt,feedbackWindowDays,totalSessionsCompleted,recursionDepth,lastDailyWakeAt,lastWeeklyReviewAt,weeklyReviewCount,pendingProjectActivityAt);

@override
String toString() {
  return 'AgentSlots(activeTaskId: $activeTaskId, activeDayId: $activeDayId, activeProjectId: $activeProjectId, activeTemplateId: $activeTemplateId, lastOneOnOneAt: $lastOneOnOneAt, lastFeedbackScanAt: $lastFeedbackScanAt, feedbackWindowDays: $feedbackWindowDays, totalSessionsCompleted: $totalSessionsCompleted, recursionDepth: $recursionDepth, lastDailyWakeAt: $lastDailyWakeAt, lastWeeklyReviewAt: $lastWeeklyReviewAt, weeklyReviewCount: $weeklyReviewCount, pendingProjectActivityAt: $pendingProjectActivityAt)';
}


}

/// @nodoc
abstract mixin class $AgentSlotsCopyWith<$Res>  {
  factory $AgentSlotsCopyWith(AgentSlots value, $Res Function(AgentSlots) _then) = _$AgentSlotsCopyWithImpl;
@useResult
$Res call({
 String? activeTaskId, String? activeDayId, String? activeProjectId, String? activeTemplateId, DateTime? lastOneOnOneAt, DateTime? lastFeedbackScanAt, int? feedbackWindowDays,@JsonKey(name: 'totalSessionsCompletedByHost') GCounter totalSessionsCompleted, int? recursionDepth, DateTime? lastDailyWakeAt, DateTime? lastWeeklyReviewAt,@JsonKey(name: 'weeklyReviewCountByHost') GCounter weeklyReviewCount, DateTime? pendingProjectActivityAt
});




}
/// @nodoc
class _$AgentSlotsCopyWithImpl<$Res>
    implements $AgentSlotsCopyWith<$Res> {
  _$AgentSlotsCopyWithImpl(this._self, this._then);

  final AgentSlots _self;
  final $Res Function(AgentSlots) _then;

/// Create a copy of AgentSlots
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activeTaskId = freezed,Object? activeDayId = freezed,Object? activeProjectId = freezed,Object? activeTemplateId = freezed,Object? lastOneOnOneAt = freezed,Object? lastFeedbackScanAt = freezed,Object? feedbackWindowDays = freezed,Object? totalSessionsCompleted = null,Object? recursionDepth = freezed,Object? lastDailyWakeAt = freezed,Object? lastWeeklyReviewAt = freezed,Object? weeklyReviewCount = null,Object? pendingProjectActivityAt = freezed,}) {
  return _then(_self.copyWith(
activeTaskId: freezed == activeTaskId ? _self.activeTaskId : activeTaskId // ignore: cast_nullable_to_non_nullable
as String?,activeDayId: freezed == activeDayId ? _self.activeDayId : activeDayId // ignore: cast_nullable_to_non_nullable
as String?,activeProjectId: freezed == activeProjectId ? _self.activeProjectId : activeProjectId // ignore: cast_nullable_to_non_nullable
as String?,activeTemplateId: freezed == activeTemplateId ? _self.activeTemplateId : activeTemplateId // ignore: cast_nullable_to_non_nullable
as String?,lastOneOnOneAt: freezed == lastOneOnOneAt ? _self.lastOneOnOneAt : lastOneOnOneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFeedbackScanAt: freezed == lastFeedbackScanAt ? _self.lastFeedbackScanAt : lastFeedbackScanAt // ignore: cast_nullable_to_non_nullable
as DateTime?,feedbackWindowDays: freezed == feedbackWindowDays ? _self.feedbackWindowDays : feedbackWindowDays // ignore: cast_nullable_to_non_nullable
as int?,totalSessionsCompleted: null == totalSessionsCompleted ? _self.totalSessionsCompleted : totalSessionsCompleted // ignore: cast_nullable_to_non_nullable
as GCounter,recursionDepth: freezed == recursionDepth ? _self.recursionDepth : recursionDepth // ignore: cast_nullable_to_non_nullable
as int?,lastDailyWakeAt: freezed == lastDailyWakeAt ? _self.lastDailyWakeAt : lastDailyWakeAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastWeeklyReviewAt: freezed == lastWeeklyReviewAt ? _self.lastWeeklyReviewAt : lastWeeklyReviewAt // ignore: cast_nullable_to_non_nullable
as DateTime?,weeklyReviewCount: null == weeklyReviewCount ? _self.weeklyReviewCount : weeklyReviewCount // ignore: cast_nullable_to_non_nullable
as GCounter,pendingProjectActivityAt: freezed == pendingProjectActivityAt ? _self.pendingProjectActivityAt : pendingProjectActivityAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentSlots].
extension AgentSlotsPatterns on AgentSlots {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentSlots value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentSlots() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentSlots value)  $default,){
final _that = this;
switch (_that) {
case _AgentSlots():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentSlots value)?  $default,){
final _that = this;
switch (_that) {
case _AgentSlots() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? activeTaskId,  String? activeDayId,  String? activeProjectId,  String? activeTemplateId,  DateTime? lastOneOnOneAt,  DateTime? lastFeedbackScanAt,  int? feedbackWindowDays, @JsonKey(name: 'totalSessionsCompletedByHost')  GCounter totalSessionsCompleted,  int? recursionDepth,  DateTime? lastDailyWakeAt,  DateTime? lastWeeklyReviewAt, @JsonKey(name: 'weeklyReviewCountByHost')  GCounter weeklyReviewCount,  DateTime? pendingProjectActivityAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentSlots() when $default != null:
return $default(_that.activeTaskId,_that.activeDayId,_that.activeProjectId,_that.activeTemplateId,_that.lastOneOnOneAt,_that.lastFeedbackScanAt,_that.feedbackWindowDays,_that.totalSessionsCompleted,_that.recursionDepth,_that.lastDailyWakeAt,_that.lastWeeklyReviewAt,_that.weeklyReviewCount,_that.pendingProjectActivityAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? activeTaskId,  String? activeDayId,  String? activeProjectId,  String? activeTemplateId,  DateTime? lastOneOnOneAt,  DateTime? lastFeedbackScanAt,  int? feedbackWindowDays, @JsonKey(name: 'totalSessionsCompletedByHost')  GCounter totalSessionsCompleted,  int? recursionDepth,  DateTime? lastDailyWakeAt,  DateTime? lastWeeklyReviewAt, @JsonKey(name: 'weeklyReviewCountByHost')  GCounter weeklyReviewCount,  DateTime? pendingProjectActivityAt)  $default,) {final _that = this;
switch (_that) {
case _AgentSlots():
return $default(_that.activeTaskId,_that.activeDayId,_that.activeProjectId,_that.activeTemplateId,_that.lastOneOnOneAt,_that.lastFeedbackScanAt,_that.feedbackWindowDays,_that.totalSessionsCompleted,_that.recursionDepth,_that.lastDailyWakeAt,_that.lastWeeklyReviewAt,_that.weeklyReviewCount,_that.pendingProjectActivityAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? activeTaskId,  String? activeDayId,  String? activeProjectId,  String? activeTemplateId,  DateTime? lastOneOnOneAt,  DateTime? lastFeedbackScanAt,  int? feedbackWindowDays, @JsonKey(name: 'totalSessionsCompletedByHost')  GCounter totalSessionsCompleted,  int? recursionDepth,  DateTime? lastDailyWakeAt,  DateTime? lastWeeklyReviewAt, @JsonKey(name: 'weeklyReviewCountByHost')  GCounter weeklyReviewCount,  DateTime? pendingProjectActivityAt)?  $default,) {final _that = this;
switch (_that) {
case _AgentSlots() when $default != null:
return $default(_that.activeTaskId,_that.activeDayId,_that.activeProjectId,_that.activeTemplateId,_that.lastOneOnOneAt,_that.lastFeedbackScanAt,_that.feedbackWindowDays,_that.totalSessionsCompleted,_that.recursionDepth,_that.lastDailyWakeAt,_that.lastWeeklyReviewAt,_that.weeklyReviewCount,_that.pendingProjectActivityAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentSlots implements AgentSlots {
  const _AgentSlots({this.activeTaskId, this.activeDayId, this.activeProjectId, this.activeTemplateId, this.lastOneOnOneAt, this.lastFeedbackScanAt, this.feedbackWindowDays, @JsonKey(name: 'totalSessionsCompletedByHost') this.totalSessionsCompleted = const GCounter.empty(), this.recursionDepth, this.lastDailyWakeAt, this.lastWeeklyReviewAt, @JsonKey(name: 'weeklyReviewCountByHost') this.weeklyReviewCount = const GCounter.empty(), this.pendingProjectActivityAt});
  factory _AgentSlots.fromJson(Map<String, dynamic> json) => _$AgentSlotsFromJson(json);

/// The journal-domain task ID this agent is working on.
@override final  String? activeTaskId;
/// The day-plan ID this agent is working on.
@override final  String? activeDayId;
/// The project ID this agent is working on.
@override final  String? activeProjectId;
/// The template ID this improver agent manages.
@override final  String? activeTemplateId;
/// When the last one-on-one ritual completed.
@override final  DateTime? lastOneOnOneAt;
/// Incremental feedback scan watermark.
@override final  DateTime? lastFeedbackScanAt;
/// Configurable ritual frequency in days (default 7).
@override final  int? feedbackWindowDays;
/// Total one-on-one sessions completed by this improver (per-host G-counter
/// so concurrent multi-device increments converge to the exact total).
@override@JsonKey(name: 'totalSessionsCompletedByHost') final  GCounter totalSessionsCompleted;
/// Recursion depth: 0 = task improver, 1 = meta-improver.
@override final  int? recursionDepth;
/// When the last daily wake completed for project agents.
@override final  DateTime? lastDailyWakeAt;
/// When the last weekly review completed for project agents.
@override final  DateTime? lastWeeklyReviewAt;
/// Total weekly review sessions completed by this project agent (per-host
/// G-counter; not yet incremented anywhere — wired up when the feature lands).
@override@JsonKey(name: 'weeklyReviewCountByHost') final  GCounter weeklyReviewCount;
/// Most recent project-linked activity that is not reflected in the
/// current project report yet. `null` means the summary is up to date.
@override final  DateTime? pendingProjectActivityAt;

/// Create a copy of AgentSlots
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentSlotsCopyWith<_AgentSlots> get copyWith => __$AgentSlotsCopyWithImpl<_AgentSlots>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentSlotsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentSlots&&(identical(other.activeTaskId, activeTaskId) || other.activeTaskId == activeTaskId)&&(identical(other.activeDayId, activeDayId) || other.activeDayId == activeDayId)&&(identical(other.activeProjectId, activeProjectId) || other.activeProjectId == activeProjectId)&&(identical(other.activeTemplateId, activeTemplateId) || other.activeTemplateId == activeTemplateId)&&(identical(other.lastOneOnOneAt, lastOneOnOneAt) || other.lastOneOnOneAt == lastOneOnOneAt)&&(identical(other.lastFeedbackScanAt, lastFeedbackScanAt) || other.lastFeedbackScanAt == lastFeedbackScanAt)&&(identical(other.feedbackWindowDays, feedbackWindowDays) || other.feedbackWindowDays == feedbackWindowDays)&&(identical(other.totalSessionsCompleted, totalSessionsCompleted) || other.totalSessionsCompleted == totalSessionsCompleted)&&(identical(other.recursionDepth, recursionDepth) || other.recursionDepth == recursionDepth)&&(identical(other.lastDailyWakeAt, lastDailyWakeAt) || other.lastDailyWakeAt == lastDailyWakeAt)&&(identical(other.lastWeeklyReviewAt, lastWeeklyReviewAt) || other.lastWeeklyReviewAt == lastWeeklyReviewAt)&&(identical(other.weeklyReviewCount, weeklyReviewCount) || other.weeklyReviewCount == weeklyReviewCount)&&(identical(other.pendingProjectActivityAt, pendingProjectActivityAt) || other.pendingProjectActivityAt == pendingProjectActivityAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activeTaskId,activeDayId,activeProjectId,activeTemplateId,lastOneOnOneAt,lastFeedbackScanAt,feedbackWindowDays,totalSessionsCompleted,recursionDepth,lastDailyWakeAt,lastWeeklyReviewAt,weeklyReviewCount,pendingProjectActivityAt);

@override
String toString() {
  return 'AgentSlots(activeTaskId: $activeTaskId, activeDayId: $activeDayId, activeProjectId: $activeProjectId, activeTemplateId: $activeTemplateId, lastOneOnOneAt: $lastOneOnOneAt, lastFeedbackScanAt: $lastFeedbackScanAt, feedbackWindowDays: $feedbackWindowDays, totalSessionsCompleted: $totalSessionsCompleted, recursionDepth: $recursionDepth, lastDailyWakeAt: $lastDailyWakeAt, lastWeeklyReviewAt: $lastWeeklyReviewAt, weeklyReviewCount: $weeklyReviewCount, pendingProjectActivityAt: $pendingProjectActivityAt)';
}


}

/// @nodoc
abstract mixin class _$AgentSlotsCopyWith<$Res> implements $AgentSlotsCopyWith<$Res> {
  factory _$AgentSlotsCopyWith(_AgentSlots value, $Res Function(_AgentSlots) _then) = __$AgentSlotsCopyWithImpl;
@override @useResult
$Res call({
 String? activeTaskId, String? activeDayId, String? activeProjectId, String? activeTemplateId, DateTime? lastOneOnOneAt, DateTime? lastFeedbackScanAt, int? feedbackWindowDays,@JsonKey(name: 'totalSessionsCompletedByHost') GCounter totalSessionsCompleted, int? recursionDepth, DateTime? lastDailyWakeAt, DateTime? lastWeeklyReviewAt,@JsonKey(name: 'weeklyReviewCountByHost') GCounter weeklyReviewCount, DateTime? pendingProjectActivityAt
});




}
/// @nodoc
class __$AgentSlotsCopyWithImpl<$Res>
    implements _$AgentSlotsCopyWith<$Res> {
  __$AgentSlotsCopyWithImpl(this._self, this._then);

  final _AgentSlots _self;
  final $Res Function(_AgentSlots) _then;

/// Create a copy of AgentSlots
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activeTaskId = freezed,Object? activeDayId = freezed,Object? activeProjectId = freezed,Object? activeTemplateId = freezed,Object? lastOneOnOneAt = freezed,Object? lastFeedbackScanAt = freezed,Object? feedbackWindowDays = freezed,Object? totalSessionsCompleted = null,Object? recursionDepth = freezed,Object? lastDailyWakeAt = freezed,Object? lastWeeklyReviewAt = freezed,Object? weeklyReviewCount = null,Object? pendingProjectActivityAt = freezed,}) {
  return _then(_AgentSlots(
activeTaskId: freezed == activeTaskId ? _self.activeTaskId : activeTaskId // ignore: cast_nullable_to_non_nullable
as String?,activeDayId: freezed == activeDayId ? _self.activeDayId : activeDayId // ignore: cast_nullable_to_non_nullable
as String?,activeProjectId: freezed == activeProjectId ? _self.activeProjectId : activeProjectId // ignore: cast_nullable_to_non_nullable
as String?,activeTemplateId: freezed == activeTemplateId ? _self.activeTemplateId : activeTemplateId // ignore: cast_nullable_to_non_nullable
as String?,lastOneOnOneAt: freezed == lastOneOnOneAt ? _self.lastOneOnOneAt : lastOneOnOneAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFeedbackScanAt: freezed == lastFeedbackScanAt ? _self.lastFeedbackScanAt : lastFeedbackScanAt // ignore: cast_nullable_to_non_nullable
as DateTime?,feedbackWindowDays: freezed == feedbackWindowDays ? _self.feedbackWindowDays : feedbackWindowDays // ignore: cast_nullable_to_non_nullable
as int?,totalSessionsCompleted: null == totalSessionsCompleted ? _self.totalSessionsCompleted : totalSessionsCompleted // ignore: cast_nullable_to_non_nullable
as GCounter,recursionDepth: freezed == recursionDepth ? _self.recursionDepth : recursionDepth // ignore: cast_nullable_to_non_nullable
as int?,lastDailyWakeAt: freezed == lastDailyWakeAt ? _self.lastDailyWakeAt : lastDailyWakeAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastWeeklyReviewAt: freezed == lastWeeklyReviewAt ? _self.lastWeeklyReviewAt : lastWeeklyReviewAt // ignore: cast_nullable_to_non_nullable
as DateTime?,weeklyReviewCount: null == weeklyReviewCount ? _self.weeklyReviewCount : weeklyReviewCount // ignore: cast_nullable_to_non_nullable
as GCounter,pendingProjectActivityAt: freezed == pendingProjectActivityAt ? _self.pendingProjectActivityAt : pendingProjectActivityAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$AgentMessageMetadata {

/// The run key of the wake that produced this message.
 String? get runKey;/// Tool name if this is an action or toolResult message.
 String? get toolName;/// Operation ID for idempotency tracking.
 String? get operationId;/// Error message if the tool call failed.
 String? get errorMessage;/// Whether the tool call was denied by policy.
 bool get policyDenied;/// Denial reason if policyDenied is true.
 String? get denialReason;/// Tags this message as recording the completion of a wake milestone.
///
/// When set, the message's `createdAt` is the source of truth for the
/// corresponding derived watermark (e.g. `lastWakeAt`,
/// `slots.lastOneOnOneAt`). The State-as-Projection fold (PR 4) reads these
/// markers so watermarks converge across devices instead of being clobbered
/// by LWW. Null on every message today — emission is wired in B2.
///
/// Forward-compatible: a milestone value an older client doesn't recognise
/// deserialises to `null` rather than throwing.
@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AgentMilestone? get milestone;
/// Create a copy of AgentMessageMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentMessageMetadataCopyWith<AgentMessageMetadata> get copyWith => _$AgentMessageMetadataCopyWithImpl<AgentMessageMetadata>(this as AgentMessageMetadata, _$identity);

  /// Serializes this AgentMessageMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentMessageMetadata&&(identical(other.runKey, runKey) || other.runKey == runKey)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.operationId, operationId) || other.operationId == operationId)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.policyDenied, policyDenied) || other.policyDenied == policyDenied)&&(identical(other.denialReason, denialReason) || other.denialReason == denialReason)&&(identical(other.milestone, milestone) || other.milestone == milestone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,runKey,toolName,operationId,errorMessage,policyDenied,denialReason,milestone);

@override
String toString() {
  return 'AgentMessageMetadata(runKey: $runKey, toolName: $toolName, operationId: $operationId, errorMessage: $errorMessage, policyDenied: $policyDenied, denialReason: $denialReason, milestone: $milestone)';
}


}

/// @nodoc
abstract mixin class $AgentMessageMetadataCopyWith<$Res>  {
  factory $AgentMessageMetadataCopyWith(AgentMessageMetadata value, $Res Function(AgentMessageMetadata) _then) = _$AgentMessageMetadataCopyWithImpl;
@useResult
$Res call({
 String? runKey, String? toolName, String? operationId, String? errorMessage, bool policyDenied, String? denialReason,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AgentMilestone? milestone
});




}
/// @nodoc
class _$AgentMessageMetadataCopyWithImpl<$Res>
    implements $AgentMessageMetadataCopyWith<$Res> {
  _$AgentMessageMetadataCopyWithImpl(this._self, this._then);

  final AgentMessageMetadata _self;
  final $Res Function(AgentMessageMetadata) _then;

/// Create a copy of AgentMessageMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? runKey = freezed,Object? toolName = freezed,Object? operationId = freezed,Object? errorMessage = freezed,Object? policyDenied = null,Object? denialReason = freezed,Object? milestone = freezed,}) {
  return _then(_self.copyWith(
runKey: freezed == runKey ? _self.runKey : runKey // ignore: cast_nullable_to_non_nullable
as String?,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,operationId: freezed == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,policyDenied: null == policyDenied ? _self.policyDenied : policyDenied // ignore: cast_nullable_to_non_nullable
as bool,denialReason: freezed == denialReason ? _self.denialReason : denialReason // ignore: cast_nullable_to_non_nullable
as String?,milestone: freezed == milestone ? _self.milestone : milestone // ignore: cast_nullable_to_non_nullable
as AgentMilestone?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentMessageMetadata].
extension AgentMessageMetadataPatterns on AgentMessageMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentMessageMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentMessageMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentMessageMetadata value)  $default,){
final _that = this;
switch (_that) {
case _AgentMessageMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentMessageMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _AgentMessageMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? runKey,  String? toolName,  String? operationId,  String? errorMessage,  bool policyDenied,  String? denialReason, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AgentMilestone? milestone)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentMessageMetadata() when $default != null:
return $default(_that.runKey,_that.toolName,_that.operationId,_that.errorMessage,_that.policyDenied,_that.denialReason,_that.milestone);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? runKey,  String? toolName,  String? operationId,  String? errorMessage,  bool policyDenied,  String? denialReason, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AgentMilestone? milestone)  $default,) {final _that = this;
switch (_that) {
case _AgentMessageMetadata():
return $default(_that.runKey,_that.toolName,_that.operationId,_that.errorMessage,_that.policyDenied,_that.denialReason,_that.milestone);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? runKey,  String? toolName,  String? operationId,  String? errorMessage,  bool policyDenied,  String? denialReason, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  AgentMilestone? milestone)?  $default,) {final _that = this;
switch (_that) {
case _AgentMessageMetadata() when $default != null:
return $default(_that.runKey,_that.toolName,_that.operationId,_that.errorMessage,_that.policyDenied,_that.denialReason,_that.milestone);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentMessageMetadata implements AgentMessageMetadata {
  const _AgentMessageMetadata({this.runKey, this.toolName, this.operationId, this.errorMessage, this.policyDenied = false, this.denialReason, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.milestone});
  factory _AgentMessageMetadata.fromJson(Map<String, dynamic> json) => _$AgentMessageMetadataFromJson(json);

/// The run key of the wake that produced this message.
@override final  String? runKey;
/// Tool name if this is an action or toolResult message.
@override final  String? toolName;
/// Operation ID for idempotency tracking.
@override final  String? operationId;
/// Error message if the tool call failed.
@override final  String? errorMessage;
/// Whether the tool call was denied by policy.
@override@JsonKey() final  bool policyDenied;
/// Denial reason if policyDenied is true.
@override final  String? denialReason;
/// Tags this message as recording the completion of a wake milestone.
///
/// When set, the message's `createdAt` is the source of truth for the
/// corresponding derived watermark (e.g. `lastWakeAt`,
/// `slots.lastOneOnOneAt`). The State-as-Projection fold (PR 4) reads these
/// markers so watermarks converge across devices instead of being clobbered
/// by LWW. Null on every message today — emission is wired in B2.
///
/// Forward-compatible: a milestone value an older client doesn't recognise
/// deserialises to `null` rather than throwing.
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  AgentMilestone? milestone;

/// Create a copy of AgentMessageMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentMessageMetadataCopyWith<_AgentMessageMetadata> get copyWith => __$AgentMessageMetadataCopyWithImpl<_AgentMessageMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentMessageMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentMessageMetadata&&(identical(other.runKey, runKey) || other.runKey == runKey)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.operationId, operationId) || other.operationId == operationId)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.policyDenied, policyDenied) || other.policyDenied == policyDenied)&&(identical(other.denialReason, denialReason) || other.denialReason == denialReason)&&(identical(other.milestone, milestone) || other.milestone == milestone));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,runKey,toolName,operationId,errorMessage,policyDenied,denialReason,milestone);

@override
String toString() {
  return 'AgentMessageMetadata(runKey: $runKey, toolName: $toolName, operationId: $operationId, errorMessage: $errorMessage, policyDenied: $policyDenied, denialReason: $denialReason, milestone: $milestone)';
}


}

/// @nodoc
abstract mixin class _$AgentMessageMetadataCopyWith<$Res> implements $AgentMessageMetadataCopyWith<$Res> {
  factory _$AgentMessageMetadataCopyWith(_AgentMessageMetadata value, $Res Function(_AgentMessageMetadata) _then) = __$AgentMessageMetadataCopyWithImpl;
@override @useResult
$Res call({
 String? runKey, String? toolName, String? operationId, String? errorMessage, bool policyDenied, String? denialReason,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) AgentMilestone? milestone
});




}
/// @nodoc
class __$AgentMessageMetadataCopyWithImpl<$Res>
    implements _$AgentMessageMetadataCopyWith<$Res> {
  __$AgentMessageMetadataCopyWithImpl(this._self, this._then);

  final _AgentMessageMetadata _self;
  final $Res Function(_AgentMessageMetadata) _then;

/// Create a copy of AgentMessageMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? runKey = freezed,Object? toolName = freezed,Object? operationId = freezed,Object? errorMessage = freezed,Object? policyDenied = null,Object? denialReason = freezed,Object? milestone = freezed,}) {
  return _then(_AgentMessageMetadata(
runKey: freezed == runKey ? _self.runKey : runKey // ignore: cast_nullable_to_non_nullable
as String?,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,operationId: freezed == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,policyDenied: null == policyDenied ? _self.policyDenied : policyDenied // ignore: cast_nullable_to_non_nullable
as bool,denialReason: freezed == denialReason ? _self.denialReason : denialReason // ignore: cast_nullable_to_non_nullable
as String?,milestone: freezed == milestone ? _self.milestone : milestone // ignore: cast_nullable_to_non_nullable
as AgentMilestone?,
  ));
}


}

// dart format on
