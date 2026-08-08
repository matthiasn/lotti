// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_progress_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoalCriterionProgress {

 String get criterionId; num get actual; num get target; double get ratio; bool get satisfied; int get sampleCount; bool? get paceFeasible;
/// Create a copy of GoalCriterionProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionProgressCopyWith<GoalCriterionProgress> get copyWith => _$GoalCriterionProgressCopyWithImpl<GoalCriterionProgress>(this as GoalCriterionProgress, _$identity);

  /// Serializes this GoalCriterionProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionProgress&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.actual, actual) || other.actual == actual)&&(identical(other.target, target) || other.target == target)&&(identical(other.ratio, ratio) || other.ratio == ratio)&&(identical(other.satisfied, satisfied) || other.satisfied == satisfied)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount)&&(identical(other.paceFeasible, paceFeasible) || other.paceFeasible == paceFeasible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,actual,target,ratio,satisfied,sampleCount,paceFeasible);

@override
String toString() {
  return 'GoalCriterionProgress(criterionId: $criterionId, actual: $actual, target: $target, ratio: $ratio, satisfied: $satisfied, sampleCount: $sampleCount, paceFeasible: $paceFeasible)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionProgressCopyWith<$Res>  {
  factory $GoalCriterionProgressCopyWith(GoalCriterionProgress value, $Res Function(GoalCriterionProgress) _then) = _$GoalCriterionProgressCopyWithImpl;
@useResult
$Res call({
 String criterionId, num actual, num target, double ratio, bool satisfied, int sampleCount, bool? paceFeasible
});




}
/// @nodoc
class _$GoalCriterionProgressCopyWithImpl<$Res>
    implements $GoalCriterionProgressCopyWith<$Res> {
  _$GoalCriterionProgressCopyWithImpl(this._self, this._then);

  final GoalCriterionProgress _self;
  final $Res Function(GoalCriterionProgress) _then;

/// Create a copy of GoalCriterionProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? criterionId = null,Object? actual = null,Object? target = null,Object? ratio = null,Object? satisfied = null,Object? sampleCount = null,Object? paceFeasible = freezed,}) {
  return _then(_self.copyWith(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,actual: null == actual ? _self.actual : actual // ignore: cast_nullable_to_non_nullable
as num,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as num,ratio: null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as double,satisfied: null == satisfied ? _self.satisfied : satisfied // ignore: cast_nullable_to_non_nullable
as bool,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,paceFeasible: freezed == paceFeasible ? _self.paceFeasible : paceFeasible // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalCriterionProgress].
extension GoalCriterionProgressPatterns on GoalCriterionProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalCriterionProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalCriterionProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalCriterionProgress value)  $default,){
final _that = this;
switch (_that) {
case _GoalCriterionProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalCriterionProgress value)?  $default,){
final _that = this;
switch (_that) {
case _GoalCriterionProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String criterionId,  num actual,  num target,  double ratio,  bool satisfied,  int sampleCount,  bool? paceFeasible)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalCriterionProgress() when $default != null:
return $default(_that.criterionId,_that.actual,_that.target,_that.ratio,_that.satisfied,_that.sampleCount,_that.paceFeasible);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String criterionId,  num actual,  num target,  double ratio,  bool satisfied,  int sampleCount,  bool? paceFeasible)  $default,) {final _that = this;
switch (_that) {
case _GoalCriterionProgress():
return $default(_that.criterionId,_that.actual,_that.target,_that.ratio,_that.satisfied,_that.sampleCount,_that.paceFeasible);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String criterionId,  num actual,  num target,  double ratio,  bool satisfied,  int sampleCount,  bool? paceFeasible)?  $default,) {final _that = this;
switch (_that) {
case _GoalCriterionProgress() when $default != null:
return $default(_that.criterionId,_that.actual,_that.target,_that.ratio,_that.satisfied,_that.sampleCount,_that.paceFeasible);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalCriterionProgress implements GoalCriterionProgress {
  const _GoalCriterionProgress({required this.criterionId, required this.actual, required this.target, required this.ratio, required this.satisfied, required this.sampleCount, this.paceFeasible});
  factory _GoalCriterionProgress.fromJson(Map<String, dynamic> json) => _$GoalCriterionProgressFromJson(json);

@override final  String criterionId;
@override final  num actual;
@override final  num target;
@override final  double ratio;
@override final  bool satisfied;
@override final  int sampleCount;
@override final  bool? paceFeasible;

/// Create a copy of GoalCriterionProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalCriterionProgressCopyWith<_GoalCriterionProgress> get copyWith => __$GoalCriterionProgressCopyWithImpl<_GoalCriterionProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalCriterionProgress&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.actual, actual) || other.actual == actual)&&(identical(other.target, target) || other.target == target)&&(identical(other.ratio, ratio) || other.ratio == ratio)&&(identical(other.satisfied, satisfied) || other.satisfied == satisfied)&&(identical(other.sampleCount, sampleCount) || other.sampleCount == sampleCount)&&(identical(other.paceFeasible, paceFeasible) || other.paceFeasible == paceFeasible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,actual,target,ratio,satisfied,sampleCount,paceFeasible);

@override
String toString() {
  return 'GoalCriterionProgress(criterionId: $criterionId, actual: $actual, target: $target, ratio: $ratio, satisfied: $satisfied, sampleCount: $sampleCount, paceFeasible: $paceFeasible)';
}


}

/// @nodoc
abstract mixin class _$GoalCriterionProgressCopyWith<$Res> implements $GoalCriterionProgressCopyWith<$Res> {
  factory _$GoalCriterionProgressCopyWith(_GoalCriterionProgress value, $Res Function(_GoalCriterionProgress) _then) = __$GoalCriterionProgressCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, num actual, num target, double ratio, bool satisfied, int sampleCount, bool? paceFeasible
});




}
/// @nodoc
class __$GoalCriterionProgressCopyWithImpl<$Res>
    implements _$GoalCriterionProgressCopyWith<$Res> {
  __$GoalCriterionProgressCopyWithImpl(this._self, this._then);

  final _GoalCriterionProgress _self;
  final $Res Function(_GoalCriterionProgress) _then;

/// Create a copy of GoalCriterionProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? actual = null,Object? target = null,Object? ratio = null,Object? satisfied = null,Object? sampleCount = null,Object? paceFeasible = freezed,}) {
  return _then(_GoalCriterionProgress(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,actual: null == actual ? _self.actual : actual // ignore: cast_nullable_to_non_nullable
as num,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as num,ratio: null == ratio ? _self.ratio : ratio // ignore: cast_nullable_to_non_nullable
as double,satisfied: null == satisfied ? _self.satisfied : satisfied // ignore: cast_nullable_to_non_nullable
as bool,sampleCount: null == sampleCount ? _self.sampleCount : sampleCount // ignore: cast_nullable_to_non_nullable
as int,paceFeasible: freezed == paceFeasible ? _self.paceFeasible : paceFeasible // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
