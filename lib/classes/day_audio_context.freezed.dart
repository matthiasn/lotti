// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'day_audio_context.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DayAudioContext {

 String get dayId; DateTime get planDate; String get recordingSessionId; String get activityEntryId; String get processingJobId; DateTime get capturedAt; String get intent; int get schemaVersion; String? get originHostId; String? get continuationOperationId; String? get baselineRevisionId;
/// Create a copy of DayAudioContext
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayAudioContextCopyWith<DayAudioContext> get copyWith => _$DayAudioContextCopyWithImpl<DayAudioContext>(this as DayAudioContext, _$identity);

  /// Serializes this DayAudioContext to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DayAudioContext&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.planDate, planDate) || other.planDate == planDate)&&(identical(other.recordingSessionId, recordingSessionId) || other.recordingSessionId == recordingSessionId)&&(identical(other.activityEntryId, activityEntryId) || other.activityEntryId == activityEntryId)&&(identical(other.processingJobId, processingJobId) || other.processingJobId == processingJobId)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.intent, intent) || other.intent == intent)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.originHostId, originHostId) || other.originHostId == originHostId)&&(identical(other.continuationOperationId, continuationOperationId) || other.continuationOperationId == continuationOperationId)&&(identical(other.baselineRevisionId, baselineRevisionId) || other.baselineRevisionId == baselineRevisionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dayId,planDate,recordingSessionId,activityEntryId,processingJobId,capturedAt,intent,schemaVersion,originHostId,continuationOperationId,baselineRevisionId);

@override
String toString() {
  return 'DayAudioContext(dayId: $dayId, planDate: $planDate, recordingSessionId: $recordingSessionId, activityEntryId: $activityEntryId, processingJobId: $processingJobId, capturedAt: $capturedAt, intent: $intent, schemaVersion: $schemaVersion, originHostId: $originHostId, continuationOperationId: $continuationOperationId, baselineRevisionId: $baselineRevisionId)';
}


}

/// @nodoc
abstract mixin class $DayAudioContextCopyWith<$Res>  {
  factory $DayAudioContextCopyWith(DayAudioContext value, $Res Function(DayAudioContext) _then) = _$DayAudioContextCopyWithImpl;
@useResult
$Res call({
 String dayId, DateTime planDate, String recordingSessionId, String activityEntryId, String processingJobId, DateTime capturedAt, String intent, int schemaVersion, String? originHostId, String? continuationOperationId, String? baselineRevisionId
});




}
/// @nodoc
class _$DayAudioContextCopyWithImpl<$Res>
    implements $DayAudioContextCopyWith<$Res> {
  _$DayAudioContextCopyWithImpl(this._self, this._then);

  final DayAudioContext _self;
  final $Res Function(DayAudioContext) _then;

/// Create a copy of DayAudioContext
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? dayId = null,Object? planDate = null,Object? recordingSessionId = null,Object? activityEntryId = null,Object? processingJobId = null,Object? capturedAt = null,Object? intent = null,Object? schemaVersion = null,Object? originHostId = freezed,Object? continuationOperationId = freezed,Object? baselineRevisionId = freezed,}) {
  return _then(_self.copyWith(
dayId: null == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String,planDate: null == planDate ? _self.planDate : planDate // ignore: cast_nullable_to_non_nullable
as DateTime,recordingSessionId: null == recordingSessionId ? _self.recordingSessionId : recordingSessionId // ignore: cast_nullable_to_non_nullable
as String,activityEntryId: null == activityEntryId ? _self.activityEntryId : activityEntryId // ignore: cast_nullable_to_non_nullable
as String,processingJobId: null == processingJobId ? _self.processingJobId : processingJobId // ignore: cast_nullable_to_non_nullable
as String,capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intent: null == intent ? _self.intent : intent // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,originHostId: freezed == originHostId ? _self.originHostId : originHostId // ignore: cast_nullable_to_non_nullable
as String?,continuationOperationId: freezed == continuationOperationId ? _self.continuationOperationId : continuationOperationId // ignore: cast_nullable_to_non_nullable
as String?,baselineRevisionId: freezed == baselineRevisionId ? _self.baselineRevisionId : baselineRevisionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DayAudioContext].
extension DayAudioContextPatterns on DayAudioContext {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DayAudioContext value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DayAudioContext() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DayAudioContext value)  $default,){
final _that = this;
switch (_that) {
case _DayAudioContext():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DayAudioContext value)?  $default,){
final _that = this;
switch (_that) {
case _DayAudioContext() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String dayId,  DateTime planDate,  String recordingSessionId,  String activityEntryId,  String processingJobId,  DateTime capturedAt,  String intent,  int schemaVersion,  String? originHostId,  String? continuationOperationId,  String? baselineRevisionId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DayAudioContext() when $default != null:
return $default(_that.dayId,_that.planDate,_that.recordingSessionId,_that.activityEntryId,_that.processingJobId,_that.capturedAt,_that.intent,_that.schemaVersion,_that.originHostId,_that.continuationOperationId,_that.baselineRevisionId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String dayId,  DateTime planDate,  String recordingSessionId,  String activityEntryId,  String processingJobId,  DateTime capturedAt,  String intent,  int schemaVersion,  String? originHostId,  String? continuationOperationId,  String? baselineRevisionId)  $default,) {final _that = this;
switch (_that) {
case _DayAudioContext():
return $default(_that.dayId,_that.planDate,_that.recordingSessionId,_that.activityEntryId,_that.processingJobId,_that.capturedAt,_that.intent,_that.schemaVersion,_that.originHostId,_that.continuationOperationId,_that.baselineRevisionId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String dayId,  DateTime planDate,  String recordingSessionId,  String activityEntryId,  String processingJobId,  DateTime capturedAt,  String intent,  int schemaVersion,  String? originHostId,  String? continuationOperationId,  String? baselineRevisionId)?  $default,) {final _that = this;
switch (_that) {
case _DayAudioContext() when $default != null:
return $default(_that.dayId,_that.planDate,_that.recordingSessionId,_that.activityEntryId,_that.processingJobId,_that.capturedAt,_that.intent,_that.schemaVersion,_that.originHostId,_that.continuationOperationId,_that.baselineRevisionId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DayAudioContext implements DayAudioContext {
  const _DayAudioContext({required this.dayId, required this.planDate, required this.recordingSessionId, required this.activityEntryId, required this.processingJobId, required this.capturedAt, required this.intent, this.schemaVersion = 1, this.originHostId, this.continuationOperationId, this.baselineRevisionId});
  factory _DayAudioContext.fromJson(Map<String, dynamic> json) => _$DayAudioContextFromJson(json);

@override final  String dayId;
@override final  DateTime planDate;
@override final  String recordingSessionId;
@override final  String activityEntryId;
@override final  String processingJobId;
@override final  DateTime capturedAt;
@override final  String intent;
@override@JsonKey() final  int schemaVersion;
@override final  String? originHostId;
@override final  String? continuationOperationId;
@override final  String? baselineRevisionId;

/// Create a copy of DayAudioContext
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DayAudioContextCopyWith<_DayAudioContext> get copyWith => __$DayAudioContextCopyWithImpl<_DayAudioContext>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DayAudioContextToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DayAudioContext&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.planDate, planDate) || other.planDate == planDate)&&(identical(other.recordingSessionId, recordingSessionId) || other.recordingSessionId == recordingSessionId)&&(identical(other.activityEntryId, activityEntryId) || other.activityEntryId == activityEntryId)&&(identical(other.processingJobId, processingJobId) || other.processingJobId == processingJobId)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.intent, intent) || other.intent == intent)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.originHostId, originHostId) || other.originHostId == originHostId)&&(identical(other.continuationOperationId, continuationOperationId) || other.continuationOperationId == continuationOperationId)&&(identical(other.baselineRevisionId, baselineRevisionId) || other.baselineRevisionId == baselineRevisionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,dayId,planDate,recordingSessionId,activityEntryId,processingJobId,capturedAt,intent,schemaVersion,originHostId,continuationOperationId,baselineRevisionId);

@override
String toString() {
  return 'DayAudioContext(dayId: $dayId, planDate: $planDate, recordingSessionId: $recordingSessionId, activityEntryId: $activityEntryId, processingJobId: $processingJobId, capturedAt: $capturedAt, intent: $intent, schemaVersion: $schemaVersion, originHostId: $originHostId, continuationOperationId: $continuationOperationId, baselineRevisionId: $baselineRevisionId)';
}


}

/// @nodoc
abstract mixin class _$DayAudioContextCopyWith<$Res> implements $DayAudioContextCopyWith<$Res> {
  factory _$DayAudioContextCopyWith(_DayAudioContext value, $Res Function(_DayAudioContext) _then) = __$DayAudioContextCopyWithImpl;
@override @useResult
$Res call({
 String dayId, DateTime planDate, String recordingSessionId, String activityEntryId, String processingJobId, DateTime capturedAt, String intent, int schemaVersion, String? originHostId, String? continuationOperationId, String? baselineRevisionId
});




}
/// @nodoc
class __$DayAudioContextCopyWithImpl<$Res>
    implements _$DayAudioContextCopyWith<$Res> {
  __$DayAudioContextCopyWithImpl(this._self, this._then);

  final _DayAudioContext _self;
  final $Res Function(_DayAudioContext) _then;

/// Create a copy of DayAudioContext
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? dayId = null,Object? planDate = null,Object? recordingSessionId = null,Object? activityEntryId = null,Object? processingJobId = null,Object? capturedAt = null,Object? intent = null,Object? schemaVersion = null,Object? originHostId = freezed,Object? continuationOperationId = freezed,Object? baselineRevisionId = freezed,}) {
  return _then(_DayAudioContext(
dayId: null == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String,planDate: null == planDate ? _self.planDate : planDate // ignore: cast_nullable_to_non_nullable
as DateTime,recordingSessionId: null == recordingSessionId ? _self.recordingSessionId : recordingSessionId // ignore: cast_nullable_to_non_nullable
as String,activityEntryId: null == activityEntryId ? _self.activityEntryId : activityEntryId // ignore: cast_nullable_to_non_nullable
as String,processingJobId: null == processingJobId ? _self.processingJobId : processingJobId // ignore: cast_nullable_to_non_nullable
as String,capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intent: null == intent ? _self.intent : intent // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,originHostId: freezed == originHostId ? _self.originHostId : originHostId // ignore: cast_nullable_to_non_nullable
as String?,continuationOperationId: freezed == continuationOperationId ? _self.continuationOperationId : continuationOperationId // ignore: cast_nullable_to_non_nullable
as String?,baselineRevisionId: freezed == baselineRevisionId ? _self.baselineRevisionId : baselineRevisionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
