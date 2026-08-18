// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoalData {

/// The goal's short name, as the user wrote it ("Blood pressure").
 String get title;/// The speakable form: "Average 10,000 steps a day over a rolling week."
 String get statement;/// The criteria tree success is defined in. Its leaves reference habit,
/// measurable, category and label definitions by their stable ids.
 GoalCriterion get criteria;/// Monotonic ordinal of the current definition, 1-based. Increments on
/// every accepted revision.
 int get specVersion;/// Id of the snapshot row holding this exact definition. Registers and
/// reflections pin to it, so their verdicts stay attributable to the
/// criteria that produced them.
 String get specVersionId;/// When the goal starts counting; null means "from creation".
 DateTime? get startDate;/// Optional deadline. Once passed, the track policy resolves to
/// achieved/off-track instead of granting grace.
 DateTime? get targetDate;/// Why this definition was chosen, when a revision recorded a reason.
 String? get rationale;/// Set **only on an immutable spec snapshot**, naming the goal entry it
/// belongs to; null on the goal itself. Denormalized into the journal
/// row's `subtype` (the `HabitCompletionData.habitId` precedent) so a
/// goal's version history is an indexed `type + subtype` lookup rather
/// than a scan, and so a snapshot emits its goal as a precise wake token.
 String? get snapshotOf;
/// Create a copy of GoalData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalDataCopyWith<GoalData> get copyWith => _$GoalDataCopyWithImpl<GoalData>(this as GoalData, _$identity);

  /// Serializes this GoalData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalData&&(identical(other.title, title) || other.title == title)&&(identical(other.statement, statement) || other.statement == statement)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.specVersion, specVersion) || other.specVersion == specVersion)&&(identical(other.specVersionId, specVersionId) || other.specVersionId == specVersionId)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.snapshotOf, snapshotOf) || other.snapshotOf == snapshotOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,statement,criteria,specVersion,specVersionId,startDate,targetDate,rationale,snapshotOf);

@override
String toString() {
  return 'GoalData(title: $title, statement: $statement, criteria: $criteria, specVersion: $specVersion, specVersionId: $specVersionId, startDate: $startDate, targetDate: $targetDate, rationale: $rationale, snapshotOf: $snapshotOf)';
}


}

/// @nodoc
abstract mixin class $GoalDataCopyWith<$Res>  {
  factory $GoalDataCopyWith(GoalData value, $Res Function(GoalData) _then) = _$GoalDataCopyWithImpl;
@useResult
$Res call({
 String title, String statement, GoalCriterion criteria, int specVersion, String specVersionId, DateTime? startDate, DateTime? targetDate, String? rationale, String? snapshotOf
});


$GoalCriterionCopyWith<$Res> get criteria;

}
/// @nodoc
class _$GoalDataCopyWithImpl<$Res>
    implements $GoalDataCopyWith<$Res> {
  _$GoalDataCopyWithImpl(this._self, this._then);

  final GoalData _self;
  final $Res Function(GoalData) _then;

/// Create a copy of GoalData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? statement = null,Object? criteria = null,Object? specVersion = null,Object? specVersionId = null,Object? startDate = freezed,Object? targetDate = freezed,Object? rationale = freezed,Object? snapshotOf = freezed,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,statement: null == statement ? _self.statement : statement // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as GoalCriterion,specVersion: null == specVersion ? _self.specVersion : specVersion // ignore: cast_nullable_to_non_nullable
as int,specVersionId: null == specVersionId ? _self.specVersionId : specVersionId // ignore: cast_nullable_to_non_nullable
as String,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime?,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rationale: freezed == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String?,snapshotOf: freezed == snapshotOf ? _self.snapshotOf : snapshotOf // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of GoalData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalCriterionCopyWith<$Res> get criteria {
  
  return $GoalCriterionCopyWith<$Res>(_self.criteria, (value) {
    return _then(_self.copyWith(criteria: value));
  });
}
}


/// Adds pattern-matching-related methods to [GoalData].
extension GoalDataPatterns on GoalData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalData value)  $default,){
final _that = this;
switch (_that) {
case _GoalData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalData value)?  $default,){
final _that = this;
switch (_that) {
case _GoalData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String statement,  GoalCriterion criteria,  int specVersion,  String specVersionId,  DateTime? startDate,  DateTime? targetDate,  String? rationale,  String? snapshotOf)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalData() when $default != null:
return $default(_that.title,_that.statement,_that.criteria,_that.specVersion,_that.specVersionId,_that.startDate,_that.targetDate,_that.rationale,_that.snapshotOf);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String statement,  GoalCriterion criteria,  int specVersion,  String specVersionId,  DateTime? startDate,  DateTime? targetDate,  String? rationale,  String? snapshotOf)  $default,) {final _that = this;
switch (_that) {
case _GoalData():
return $default(_that.title,_that.statement,_that.criteria,_that.specVersion,_that.specVersionId,_that.startDate,_that.targetDate,_that.rationale,_that.snapshotOf);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String statement,  GoalCriterion criteria,  int specVersion,  String specVersionId,  DateTime? startDate,  DateTime? targetDate,  String? rationale,  String? snapshotOf)?  $default,) {final _that = this;
switch (_that) {
case _GoalData() when $default != null:
return $default(_that.title,_that.statement,_that.criteria,_that.specVersion,_that.specVersionId,_that.startDate,_that.targetDate,_that.rationale,_that.snapshotOf);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalData implements GoalData {
  const _GoalData({required this.title, required this.statement, required this.criteria, required this.specVersion, required this.specVersionId, this.startDate, this.targetDate, this.rationale, this.snapshotOf});
  factory _GoalData.fromJson(Map<String, dynamic> json) => _$GoalDataFromJson(json);

/// The goal's short name, as the user wrote it ("Blood pressure").
@override final  String title;
/// The speakable form: "Average 10,000 steps a day over a rolling week."
@override final  String statement;
/// The criteria tree success is defined in. Its leaves reference habit,
/// measurable, category and label definitions by their stable ids.
@override final  GoalCriterion criteria;
/// Monotonic ordinal of the current definition, 1-based. Increments on
/// every accepted revision.
@override final  int specVersion;
/// Id of the snapshot row holding this exact definition. Registers and
/// reflections pin to it, so their verdicts stay attributable to the
/// criteria that produced them.
@override final  String specVersionId;
/// When the goal starts counting; null means "from creation".
@override final  DateTime? startDate;
/// Optional deadline. Once passed, the track policy resolves to
/// achieved/off-track instead of granting grace.
@override final  DateTime? targetDate;
/// Why this definition was chosen, when a revision recorded a reason.
@override final  String? rationale;
/// Set **only on an immutable spec snapshot**, naming the goal entry it
/// belongs to; null on the goal itself. Denormalized into the journal
/// row's `subtype` (the `HabitCompletionData.habitId` precedent) so a
/// goal's version history is an indexed `type + subtype` lookup rather
/// than a scan, and so a snapshot emits its goal as a precise wake token.
@override final  String? snapshotOf;

/// Create a copy of GoalData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalDataCopyWith<_GoalData> get copyWith => __$GoalDataCopyWithImpl<_GoalData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalData&&(identical(other.title, title) || other.title == title)&&(identical(other.statement, statement) || other.statement == statement)&&(identical(other.criteria, criteria) || other.criteria == criteria)&&(identical(other.specVersion, specVersion) || other.specVersion == specVersion)&&(identical(other.specVersionId, specVersionId) || other.specVersionId == specVersionId)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.targetDate, targetDate) || other.targetDate == targetDate)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.snapshotOf, snapshotOf) || other.snapshotOf == snapshotOf));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,statement,criteria,specVersion,specVersionId,startDate,targetDate,rationale,snapshotOf);

@override
String toString() {
  return 'GoalData(title: $title, statement: $statement, criteria: $criteria, specVersion: $specVersion, specVersionId: $specVersionId, startDate: $startDate, targetDate: $targetDate, rationale: $rationale, snapshotOf: $snapshotOf)';
}


}

/// @nodoc
abstract mixin class _$GoalDataCopyWith<$Res> implements $GoalDataCopyWith<$Res> {
  factory _$GoalDataCopyWith(_GoalData value, $Res Function(_GoalData) _then) = __$GoalDataCopyWithImpl;
@override @useResult
$Res call({
 String title, String statement, GoalCriterion criteria, int specVersion, String specVersionId, DateTime? startDate, DateTime? targetDate, String? rationale, String? snapshotOf
});


@override $GoalCriterionCopyWith<$Res> get criteria;

}
/// @nodoc
class __$GoalDataCopyWithImpl<$Res>
    implements _$GoalDataCopyWith<$Res> {
  __$GoalDataCopyWithImpl(this._self, this._then);

  final _GoalData _self;
  final $Res Function(_GoalData) _then;

/// Create a copy of GoalData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? statement = null,Object? criteria = null,Object? specVersion = null,Object? specVersionId = null,Object? startDate = freezed,Object? targetDate = freezed,Object? rationale = freezed,Object? snapshotOf = freezed,}) {
  return _then(_GoalData(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,statement: null == statement ? _self.statement : statement // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self.criteria : criteria // ignore: cast_nullable_to_non_nullable
as GoalCriterion,specVersion: null == specVersion ? _self.specVersion : specVersion // ignore: cast_nullable_to_non_nullable
as int,specVersionId: null == specVersionId ? _self.specVersionId : specVersionId // ignore: cast_nullable_to_non_nullable
as String,startDate: freezed == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime?,targetDate: freezed == targetDate ? _self.targetDate : targetDate // ignore: cast_nullable_to_non_nullable
as DateTime?,rationale: freezed == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String?,snapshotOf: freezed == snapshotOf ? _self.snapshotOf : snapshotOf // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GoalData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalCriterionCopyWith<$Res> get criteria {
  
  return $GoalCriterionCopyWith<$Res>(_self.criteria, (value) {
    return _then(_self.copyWith(criteria: value));
  });
}
}

// dart format on
