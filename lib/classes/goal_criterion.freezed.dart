// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_criterion.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoalDailyTimeRange {

 int get startMinute; int get endMinute;
/// Create a copy of GoalDailyTimeRange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalDailyTimeRangeCopyWith<GoalDailyTimeRange> get copyWith => _$GoalDailyTimeRangeCopyWithImpl<GoalDailyTimeRange>(this as GoalDailyTimeRange, _$identity);

  /// Serializes this GoalDailyTimeRange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalDailyTimeRange&&(identical(other.startMinute, startMinute) || other.startMinute == startMinute)&&(identical(other.endMinute, endMinute) || other.endMinute == endMinute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startMinute,endMinute);

@override
String toString() {
  return 'GoalDailyTimeRange(startMinute: $startMinute, endMinute: $endMinute)';
}


}

/// @nodoc
abstract mixin class $GoalDailyTimeRangeCopyWith<$Res>  {
  factory $GoalDailyTimeRangeCopyWith(GoalDailyTimeRange value, $Res Function(GoalDailyTimeRange) _then) = _$GoalDailyTimeRangeCopyWithImpl;
@useResult
$Res call({
 int startMinute, int endMinute
});




}
/// @nodoc
class _$GoalDailyTimeRangeCopyWithImpl<$Res>
    implements $GoalDailyTimeRangeCopyWith<$Res> {
  _$GoalDailyTimeRangeCopyWithImpl(this._self, this._then);

  final GoalDailyTimeRange _self;
  final $Res Function(GoalDailyTimeRange) _then;

/// Create a copy of GoalDailyTimeRange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startMinute = null,Object? endMinute = null,}) {
  return _then(_self.copyWith(
startMinute: null == startMinute ? _self.startMinute : startMinute // ignore: cast_nullable_to_non_nullable
as int,endMinute: null == endMinute ? _self.endMinute : endMinute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalDailyTimeRange].
extension GoalDailyTimeRangePatterns on GoalDailyTimeRange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalDailyTimeRange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalDailyTimeRange() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalDailyTimeRange value)  $default,){
final _that = this;
switch (_that) {
case _GoalDailyTimeRange():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalDailyTimeRange value)?  $default,){
final _that = this;
switch (_that) {
case _GoalDailyTimeRange() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startMinute,  int endMinute)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalDailyTimeRange() when $default != null:
return $default(_that.startMinute,_that.endMinute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startMinute,  int endMinute)  $default,) {final _that = this;
switch (_that) {
case _GoalDailyTimeRange():
return $default(_that.startMinute,_that.endMinute);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startMinute,  int endMinute)?  $default,) {final _that = this;
switch (_that) {
case _GoalDailyTimeRange() when $default != null:
return $default(_that.startMinute,_that.endMinute);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalDailyTimeRange implements GoalDailyTimeRange {
  const _GoalDailyTimeRange({required this.startMinute, required this.endMinute});
  factory _GoalDailyTimeRange.fromJson(Map<String, dynamic> json) => _$GoalDailyTimeRangeFromJson(json);

@override final  int startMinute;
@override final  int endMinute;

/// Create a copy of GoalDailyTimeRange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalDailyTimeRangeCopyWith<_GoalDailyTimeRange> get copyWith => __$GoalDailyTimeRangeCopyWithImpl<_GoalDailyTimeRange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalDailyTimeRangeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalDailyTimeRange&&(identical(other.startMinute, startMinute) || other.startMinute == startMinute)&&(identical(other.endMinute, endMinute) || other.endMinute == endMinute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,startMinute,endMinute);

@override
String toString() {
  return 'GoalDailyTimeRange(startMinute: $startMinute, endMinute: $endMinute)';
}


}

/// @nodoc
abstract mixin class _$GoalDailyTimeRangeCopyWith<$Res> implements $GoalDailyTimeRangeCopyWith<$Res> {
  factory _$GoalDailyTimeRangeCopyWith(_GoalDailyTimeRange value, $Res Function(_GoalDailyTimeRange) _then) = __$GoalDailyTimeRangeCopyWithImpl;
@override @useResult
$Res call({
 int startMinute, int endMinute
});




}
/// @nodoc
class __$GoalDailyTimeRangeCopyWithImpl<$Res>
    implements _$GoalDailyTimeRangeCopyWith<$Res> {
  __$GoalDailyTimeRangeCopyWithImpl(this._self, this._then);

  final _GoalDailyTimeRange _self;
  final $Res Function(_GoalDailyTimeRange) _then;

/// Create a copy of GoalDailyTimeRange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startMinute = null,Object? endMinute = null,}) {
  return _then(_GoalDailyTimeRange(
startMinute: null == startMinute ? _self.startMinute : startMinute // ignore: cast_nullable_to_non_nullable
as int,endMinute: null == endMinute ? _self.endMinute : endMinute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

GoalCriterion _$GoalCriterionFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'metric':
          return GoalCriterionMetric.fromJson(
            json
          );
                case 'habit':
          return GoalCriterionHabit.fromJson(
            json
          );
                case 'measurable':
          return GoalCriterionMeasurable.fromJson(
            json
          );
                case 'categoryTime':
          return GoalCriterionCategoryTime.fromJson(
            json
          );
                case 'labelTime':
          return GoalCriterionLabelTime.fromJson(
            json
          );
                case 'allOf':
          return GoalCriterionAllOf.fromJson(
            json
          );
                case 'anyOf':
          return GoalCriterionAnyOf.fromJson(
            json
          );
                case 'atLeastCount':
          return GoalCriterionAtLeastCount.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'GoalCriterion',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$GoalCriterion {

 String get criterionId; String? get title;
/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionCopyWith<GoalCriterion> get copyWith => _$GoalCriterionCopyWithImpl<GoalCriterion>(this as GoalCriterion, _$identity);

  /// Serializes this GoalCriterion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterion&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,title);

@override
String toString() {
  return 'GoalCriterion(criterionId: $criterionId, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionCopyWith<$Res>  {
  factory $GoalCriterionCopyWith(GoalCriterion value, $Res Function(GoalCriterion) _then) = _$GoalCriterionCopyWithImpl;
@useResult
$Res call({
 String criterionId, String? title
});




}
/// @nodoc
class _$GoalCriterionCopyWithImpl<$Res>
    implements $GoalCriterionCopyWith<$Res> {
  _$GoalCriterionCopyWithImpl(this._self, this._then);

  final GoalCriterion _self;
  final $Res Function(GoalCriterion) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? criterionId = null,Object? title = freezed,}) {
  return _then(_self.copyWith(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalCriterion].
extension GoalCriterionPatterns on GoalCriterion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( GoalCriterionMetric value)?  metric,TResult Function( GoalCriterionHabit value)?  habit,TResult Function( GoalCriterionMeasurable value)?  measurable,TResult Function( GoalCriterionCategoryTime value)?  categoryTime,TResult Function( GoalCriterionLabelTime value)?  labelTime,TResult Function( GoalCriterionAllOf value)?  allOf,TResult Function( GoalCriterionAnyOf value)?  anyOf,TResult Function( GoalCriterionAtLeastCount value)?  atLeastCount,required TResult orElse(),}){
final _that = this;
switch (_that) {
case GoalCriterionMetric() when metric != null:
return metric(_that);case GoalCriterionHabit() when habit != null:
return habit(_that);case GoalCriterionMeasurable() when measurable != null:
return measurable(_that);case GoalCriterionCategoryTime() when categoryTime != null:
return categoryTime(_that);case GoalCriterionLabelTime() when labelTime != null:
return labelTime(_that);case GoalCriterionAllOf() when allOf != null:
return allOf(_that);case GoalCriterionAnyOf() when anyOf != null:
return anyOf(_that);case GoalCriterionAtLeastCount() when atLeastCount != null:
return atLeastCount(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( GoalCriterionMetric value)  metric,required TResult Function( GoalCriterionHabit value)  habit,required TResult Function( GoalCriterionMeasurable value)  measurable,required TResult Function( GoalCriterionCategoryTime value)  categoryTime,required TResult Function( GoalCriterionLabelTime value)  labelTime,required TResult Function( GoalCriterionAllOf value)  allOf,required TResult Function( GoalCriterionAnyOf value)  anyOf,required TResult Function( GoalCriterionAtLeastCount value)  atLeastCount,}){
final _that = this;
switch (_that) {
case GoalCriterionMetric():
return metric(_that);case GoalCriterionHabit():
return habit(_that);case GoalCriterionMeasurable():
return measurable(_that);case GoalCriterionCategoryTime():
return categoryTime(_that);case GoalCriterionLabelTime():
return labelTime(_that);case GoalCriterionAllOf():
return allOf(_that);case GoalCriterionAnyOf():
return anyOf(_that);case GoalCriterionAtLeastCount():
return atLeastCount(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( GoalCriterionMetric value)?  metric,TResult? Function( GoalCriterionHabit value)?  habit,TResult? Function( GoalCriterionMeasurable value)?  measurable,TResult? Function( GoalCriterionCategoryTime value)?  categoryTime,TResult? Function( GoalCriterionLabelTime value)?  labelTime,TResult? Function( GoalCriterionAllOf value)?  allOf,TResult? Function( GoalCriterionAnyOf value)?  anyOf,TResult? Function( GoalCriterionAtLeastCount value)?  atLeastCount,}){
final _that = this;
switch (_that) {
case GoalCriterionMetric() when metric != null:
return metric(_that);case GoalCriterionHabit() when habit != null:
return habit(_that);case GoalCriterionMeasurable() when measurable != null:
return measurable(_that);case GoalCriterionCategoryTime() when categoryTime != null:
return categoryTime(_that);case GoalCriterionLabelTime() when labelTime != null:
return labelTime(_that);case GoalCriterionAllOf() when allOf != null:
return allOf(_that);case GoalCriterionAnyOf() when anyOf != null:
return anyOf(_that);case GoalCriterionAtLeastCount() when atLeastCount != null:
return atLeastCount(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String criterionId,  String dataType,  GoalWindow window,  GoalAggregation aggregation,  num target,  GoalDirection direction,  String? title)?  metric,TResult Function( String criterionId,  String habitId,  GoalWindow window,  int targetCount,  String? title)?  habit,TResult Function( String criterionId,  String dataTypeId,  GoalWindow window,  GoalAggregation aggregation,  num target,  GoalDirection direction,  String? title)?  measurable,TResult Function( String criterionId,  String categoryId,  GoalWindow window,  GoalAggregation aggregation,  num targetHours,  GoalDirection direction,  GoalDailyTimeRange? dailyTimeRange,  String? title)?  categoryTime,TResult Function( String criterionId,  String labelId,  GoalWindow window,  GoalAggregation aggregation,  num targetHours,  GoalDirection direction,  String? categoryId,  GoalDailyTimeRange? dailyTimeRange,  String? title)?  labelTime,TResult Function( String criterionId,  List<GoalCriterion> criteria,  String? title)?  allOf,TResult Function( String criterionId,  List<GoalCriterion> criteria,  String? title)?  anyOf,TResult Function( String criterionId,  List<GoalCriterion> criteria,  int successes,  String? title)?  atLeastCount,required TResult orElse(),}) {final _that = this;
switch (_that) {
case GoalCriterionMetric() when metric != null:
return metric(_that.criterionId,_that.dataType,_that.window,_that.aggregation,_that.target,_that.direction,_that.title);case GoalCriterionHabit() when habit != null:
return habit(_that.criterionId,_that.habitId,_that.window,_that.targetCount,_that.title);case GoalCriterionMeasurable() when measurable != null:
return measurable(_that.criterionId,_that.dataTypeId,_that.window,_that.aggregation,_that.target,_that.direction,_that.title);case GoalCriterionCategoryTime() when categoryTime != null:
return categoryTime(_that.criterionId,_that.categoryId,_that.window,_that.aggregation,_that.targetHours,_that.direction,_that.dailyTimeRange,_that.title);case GoalCriterionLabelTime() when labelTime != null:
return labelTime(_that.criterionId,_that.labelId,_that.window,_that.aggregation,_that.targetHours,_that.direction,_that.categoryId,_that.dailyTimeRange,_that.title);case GoalCriterionAllOf() when allOf != null:
return allOf(_that.criterionId,_that.criteria,_that.title);case GoalCriterionAnyOf() when anyOf != null:
return anyOf(_that.criterionId,_that.criteria,_that.title);case GoalCriterionAtLeastCount() when atLeastCount != null:
return atLeastCount(_that.criterionId,_that.criteria,_that.successes,_that.title);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String criterionId,  String dataType,  GoalWindow window,  GoalAggregation aggregation,  num target,  GoalDirection direction,  String? title)  metric,required TResult Function( String criterionId,  String habitId,  GoalWindow window,  int targetCount,  String? title)  habit,required TResult Function( String criterionId,  String dataTypeId,  GoalWindow window,  GoalAggregation aggregation,  num target,  GoalDirection direction,  String? title)  measurable,required TResult Function( String criterionId,  String categoryId,  GoalWindow window,  GoalAggregation aggregation,  num targetHours,  GoalDirection direction,  GoalDailyTimeRange? dailyTimeRange,  String? title)  categoryTime,required TResult Function( String criterionId,  String labelId,  GoalWindow window,  GoalAggregation aggregation,  num targetHours,  GoalDirection direction,  String? categoryId,  GoalDailyTimeRange? dailyTimeRange,  String? title)  labelTime,required TResult Function( String criterionId,  List<GoalCriterion> criteria,  String? title)  allOf,required TResult Function( String criterionId,  List<GoalCriterion> criteria,  String? title)  anyOf,required TResult Function( String criterionId,  List<GoalCriterion> criteria,  int successes,  String? title)  atLeastCount,}) {final _that = this;
switch (_that) {
case GoalCriterionMetric():
return metric(_that.criterionId,_that.dataType,_that.window,_that.aggregation,_that.target,_that.direction,_that.title);case GoalCriterionHabit():
return habit(_that.criterionId,_that.habitId,_that.window,_that.targetCount,_that.title);case GoalCriterionMeasurable():
return measurable(_that.criterionId,_that.dataTypeId,_that.window,_that.aggregation,_that.target,_that.direction,_that.title);case GoalCriterionCategoryTime():
return categoryTime(_that.criterionId,_that.categoryId,_that.window,_that.aggregation,_that.targetHours,_that.direction,_that.dailyTimeRange,_that.title);case GoalCriterionLabelTime():
return labelTime(_that.criterionId,_that.labelId,_that.window,_that.aggregation,_that.targetHours,_that.direction,_that.categoryId,_that.dailyTimeRange,_that.title);case GoalCriterionAllOf():
return allOf(_that.criterionId,_that.criteria,_that.title);case GoalCriterionAnyOf():
return anyOf(_that.criterionId,_that.criteria,_that.title);case GoalCriterionAtLeastCount():
return atLeastCount(_that.criterionId,_that.criteria,_that.successes,_that.title);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String criterionId,  String dataType,  GoalWindow window,  GoalAggregation aggregation,  num target,  GoalDirection direction,  String? title)?  metric,TResult? Function( String criterionId,  String habitId,  GoalWindow window,  int targetCount,  String? title)?  habit,TResult? Function( String criterionId,  String dataTypeId,  GoalWindow window,  GoalAggregation aggregation,  num target,  GoalDirection direction,  String? title)?  measurable,TResult? Function( String criterionId,  String categoryId,  GoalWindow window,  GoalAggregation aggregation,  num targetHours,  GoalDirection direction,  GoalDailyTimeRange? dailyTimeRange,  String? title)?  categoryTime,TResult? Function( String criterionId,  String labelId,  GoalWindow window,  GoalAggregation aggregation,  num targetHours,  GoalDirection direction,  String? categoryId,  GoalDailyTimeRange? dailyTimeRange,  String? title)?  labelTime,TResult? Function( String criterionId,  List<GoalCriterion> criteria,  String? title)?  allOf,TResult? Function( String criterionId,  List<GoalCriterion> criteria,  String? title)?  anyOf,TResult? Function( String criterionId,  List<GoalCriterion> criteria,  int successes,  String? title)?  atLeastCount,}) {final _that = this;
switch (_that) {
case GoalCriterionMetric() when metric != null:
return metric(_that.criterionId,_that.dataType,_that.window,_that.aggregation,_that.target,_that.direction,_that.title);case GoalCriterionHabit() when habit != null:
return habit(_that.criterionId,_that.habitId,_that.window,_that.targetCount,_that.title);case GoalCriterionMeasurable() when measurable != null:
return measurable(_that.criterionId,_that.dataTypeId,_that.window,_that.aggregation,_that.target,_that.direction,_that.title);case GoalCriterionCategoryTime() when categoryTime != null:
return categoryTime(_that.criterionId,_that.categoryId,_that.window,_that.aggregation,_that.targetHours,_that.direction,_that.dailyTimeRange,_that.title);case GoalCriterionLabelTime() when labelTime != null:
return labelTime(_that.criterionId,_that.labelId,_that.window,_that.aggregation,_that.targetHours,_that.direction,_that.categoryId,_that.dailyTimeRange,_that.title);case GoalCriterionAllOf() when allOf != null:
return allOf(_that.criterionId,_that.criteria,_that.title);case GoalCriterionAnyOf() when anyOf != null:
return anyOf(_that.criterionId,_that.criteria,_that.title);case GoalCriterionAtLeastCount() when atLeastCount != null:
return atLeastCount(_that.criterionId,_that.criteria,_that.successes,_that.title);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class GoalCriterionMetric extends GoalCriterion {
  const GoalCriterionMetric({required this.criterionId, required this.dataType, required this.window, required this.aggregation, required this.target, this.direction = GoalDirection.atLeast, this.title, final  String? $type}): $type = $type ?? 'metric',super._();
  factory GoalCriterionMetric.fromJson(Map<String, dynamic> json) => _$GoalCriterionMetricFromJson(json);

@override final  String criterionId;
 final  String dataType;
 final  GoalWindow window;
 final  GoalAggregation aggregation;
 final  num target;
@JsonKey() final  GoalDirection direction;
@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionMetricCopyWith<GoalCriterionMetric> get copyWith => _$GoalCriterionMetricCopyWithImpl<GoalCriterionMetric>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionMetricToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionMetric&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.dataType, dataType) || other.dataType == dataType)&&(identical(other.window, window) || other.window == window)&&(identical(other.aggregation, aggregation) || other.aggregation == aggregation)&&(identical(other.target, target) || other.target == target)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,dataType,window,aggregation,target,direction,title);

@override
String toString() {
  return 'GoalCriterion.metric(criterionId: $criterionId, dataType: $dataType, window: $window, aggregation: $aggregation, target: $target, direction: $direction, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionMetricCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionMetricCopyWith(GoalCriterionMetric value, $Res Function(GoalCriterionMetric) _then) = _$GoalCriterionMetricCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, String dataType, GoalWindow window, GoalAggregation aggregation, num target, GoalDirection direction, String? title
});


$GoalWindowCopyWith<$Res> get window;

}
/// @nodoc
class _$GoalCriterionMetricCopyWithImpl<$Res>
    implements $GoalCriterionMetricCopyWith<$Res> {
  _$GoalCriterionMetricCopyWithImpl(this._self, this._then);

  final GoalCriterionMetric _self;
  final $Res Function(GoalCriterionMetric) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? dataType = null,Object? window = null,Object? aggregation = null,Object? target = null,Object? direction = null,Object? title = freezed,}) {
  return _then(GoalCriterionMetric(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,dataType: null == dataType ? _self.dataType : dataType // ignore: cast_nullable_to_non_nullable
as String,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as GoalWindow,aggregation: null == aggregation ? _self.aggregation : aggregation // ignore: cast_nullable_to_non_nullable
as GoalAggregation,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as num,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as GoalDirection,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalWindowCopyWith<$Res> get window {
  
  return $GoalWindowCopyWith<$Res>(_self.window, (value) {
    return _then(_self.copyWith(window: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GoalCriterionHabit extends GoalCriterion {
  const GoalCriterionHabit({required this.criterionId, required this.habitId, required this.window, required this.targetCount, this.title, final  String? $type}): $type = $type ?? 'habit',super._();
  factory GoalCriterionHabit.fromJson(Map<String, dynamic> json) => _$GoalCriterionHabitFromJson(json);

@override final  String criterionId;
 final  String habitId;
 final  GoalWindow window;
 final  int targetCount;
@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionHabitCopyWith<GoalCriterionHabit> get copyWith => _$GoalCriterionHabitCopyWithImpl<GoalCriterionHabit>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionHabitToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionHabit&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.habitId, habitId) || other.habitId == habitId)&&(identical(other.window, window) || other.window == window)&&(identical(other.targetCount, targetCount) || other.targetCount == targetCount)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,habitId,window,targetCount,title);

@override
String toString() {
  return 'GoalCriterion.habit(criterionId: $criterionId, habitId: $habitId, window: $window, targetCount: $targetCount, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionHabitCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionHabitCopyWith(GoalCriterionHabit value, $Res Function(GoalCriterionHabit) _then) = _$GoalCriterionHabitCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, String habitId, GoalWindow window, int targetCount, String? title
});


$GoalWindowCopyWith<$Res> get window;

}
/// @nodoc
class _$GoalCriterionHabitCopyWithImpl<$Res>
    implements $GoalCriterionHabitCopyWith<$Res> {
  _$GoalCriterionHabitCopyWithImpl(this._self, this._then);

  final GoalCriterionHabit _self;
  final $Res Function(GoalCriterionHabit) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? habitId = null,Object? window = null,Object? targetCount = null,Object? title = freezed,}) {
  return _then(GoalCriterionHabit(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,habitId: null == habitId ? _self.habitId : habitId // ignore: cast_nullable_to_non_nullable
as String,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as GoalWindow,targetCount: null == targetCount ? _self.targetCount : targetCount // ignore: cast_nullable_to_non_nullable
as int,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalWindowCopyWith<$Res> get window {
  
  return $GoalWindowCopyWith<$Res>(_self.window, (value) {
    return _then(_self.copyWith(window: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GoalCriterionMeasurable extends GoalCriterion {
  const GoalCriterionMeasurable({required this.criterionId, required this.dataTypeId, required this.window, required this.aggregation, required this.target, this.direction = GoalDirection.atLeast, this.title, final  String? $type}): $type = $type ?? 'measurable',super._();
  factory GoalCriterionMeasurable.fromJson(Map<String, dynamic> json) => _$GoalCriterionMeasurableFromJson(json);

@override final  String criterionId;
 final  String dataTypeId;
 final  GoalWindow window;
 final  GoalAggregation aggregation;
 final  num target;
@JsonKey() final  GoalDirection direction;
@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionMeasurableCopyWith<GoalCriterionMeasurable> get copyWith => _$GoalCriterionMeasurableCopyWithImpl<GoalCriterionMeasurable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionMeasurableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionMeasurable&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.dataTypeId, dataTypeId) || other.dataTypeId == dataTypeId)&&(identical(other.window, window) || other.window == window)&&(identical(other.aggregation, aggregation) || other.aggregation == aggregation)&&(identical(other.target, target) || other.target == target)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,dataTypeId,window,aggregation,target,direction,title);

@override
String toString() {
  return 'GoalCriterion.measurable(criterionId: $criterionId, dataTypeId: $dataTypeId, window: $window, aggregation: $aggregation, target: $target, direction: $direction, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionMeasurableCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionMeasurableCopyWith(GoalCriterionMeasurable value, $Res Function(GoalCriterionMeasurable) _then) = _$GoalCriterionMeasurableCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, String dataTypeId, GoalWindow window, GoalAggregation aggregation, num target, GoalDirection direction, String? title
});


$GoalWindowCopyWith<$Res> get window;

}
/// @nodoc
class _$GoalCriterionMeasurableCopyWithImpl<$Res>
    implements $GoalCriterionMeasurableCopyWith<$Res> {
  _$GoalCriterionMeasurableCopyWithImpl(this._self, this._then);

  final GoalCriterionMeasurable _self;
  final $Res Function(GoalCriterionMeasurable) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? dataTypeId = null,Object? window = null,Object? aggregation = null,Object? target = null,Object? direction = null,Object? title = freezed,}) {
  return _then(GoalCriterionMeasurable(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,dataTypeId: null == dataTypeId ? _self.dataTypeId : dataTypeId // ignore: cast_nullable_to_non_nullable
as String,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as GoalWindow,aggregation: null == aggregation ? _self.aggregation : aggregation // ignore: cast_nullable_to_non_nullable
as GoalAggregation,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as num,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as GoalDirection,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalWindowCopyWith<$Res> get window {
  
  return $GoalWindowCopyWith<$Res>(_self.window, (value) {
    return _then(_self.copyWith(window: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GoalCriterionCategoryTime extends GoalCriterion {
  const GoalCriterionCategoryTime({required this.criterionId, required this.categoryId, required this.window, required this.aggregation, required this.targetHours, this.direction = GoalDirection.atMost, this.dailyTimeRange, this.title, final  String? $type}): $type = $type ?? 'categoryTime',super._();
  factory GoalCriterionCategoryTime.fromJson(Map<String, dynamic> json) => _$GoalCriterionCategoryTimeFromJson(json);

@override final  String criterionId;
 final  String categoryId;
 final  GoalWindow window;
 final  GoalAggregation aggregation;
 final  num targetHours;
@JsonKey() final  GoalDirection direction;
 final  GoalDailyTimeRange? dailyTimeRange;
@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionCategoryTimeCopyWith<GoalCriterionCategoryTime> get copyWith => _$GoalCriterionCategoryTimeCopyWithImpl<GoalCriterionCategoryTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionCategoryTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionCategoryTime&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.window, window) || other.window == window)&&(identical(other.aggregation, aggregation) || other.aggregation == aggregation)&&(identical(other.targetHours, targetHours) || other.targetHours == targetHours)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.dailyTimeRange, dailyTimeRange) || other.dailyTimeRange == dailyTimeRange)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,categoryId,window,aggregation,targetHours,direction,dailyTimeRange,title);

@override
String toString() {
  return 'GoalCriterion.categoryTime(criterionId: $criterionId, categoryId: $categoryId, window: $window, aggregation: $aggregation, targetHours: $targetHours, direction: $direction, dailyTimeRange: $dailyTimeRange, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionCategoryTimeCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionCategoryTimeCopyWith(GoalCriterionCategoryTime value, $Res Function(GoalCriterionCategoryTime) _then) = _$GoalCriterionCategoryTimeCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, String categoryId, GoalWindow window, GoalAggregation aggregation, num targetHours, GoalDirection direction, GoalDailyTimeRange? dailyTimeRange, String? title
});


$GoalWindowCopyWith<$Res> get window;$GoalDailyTimeRangeCopyWith<$Res>? get dailyTimeRange;

}
/// @nodoc
class _$GoalCriterionCategoryTimeCopyWithImpl<$Res>
    implements $GoalCriterionCategoryTimeCopyWith<$Res> {
  _$GoalCriterionCategoryTimeCopyWithImpl(this._self, this._then);

  final GoalCriterionCategoryTime _self;
  final $Res Function(GoalCriterionCategoryTime) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? categoryId = null,Object? window = null,Object? aggregation = null,Object? targetHours = null,Object? direction = null,Object? dailyTimeRange = freezed,Object? title = freezed,}) {
  return _then(GoalCriterionCategoryTime(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as GoalWindow,aggregation: null == aggregation ? _self.aggregation : aggregation // ignore: cast_nullable_to_non_nullable
as GoalAggregation,targetHours: null == targetHours ? _self.targetHours : targetHours // ignore: cast_nullable_to_non_nullable
as num,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as GoalDirection,dailyTimeRange: freezed == dailyTimeRange ? _self.dailyTimeRange : dailyTimeRange // ignore: cast_nullable_to_non_nullable
as GoalDailyTimeRange?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalWindowCopyWith<$Res> get window {
  
  return $GoalWindowCopyWith<$Res>(_self.window, (value) {
    return _then(_self.copyWith(window: value));
  });
}/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalDailyTimeRangeCopyWith<$Res>? get dailyTimeRange {
    if (_self.dailyTimeRange == null) {
    return null;
  }

  return $GoalDailyTimeRangeCopyWith<$Res>(_self.dailyTimeRange!, (value) {
    return _then(_self.copyWith(dailyTimeRange: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GoalCriterionLabelTime extends GoalCriterion {
  const GoalCriterionLabelTime({required this.criterionId, required this.labelId, required this.window, required this.aggregation, required this.targetHours, this.direction = GoalDirection.atLeast, this.categoryId, this.dailyTimeRange, this.title, final  String? $type}): $type = $type ?? 'labelTime',super._();
  factory GoalCriterionLabelTime.fromJson(Map<String, dynamic> json) => _$GoalCriterionLabelTimeFromJson(json);

@override final  String criterionId;
 final  String labelId;
 final  GoalWindow window;
 final  GoalAggregation aggregation;
 final  num targetHours;
@JsonKey() final  GoalDirection direction;
 final  String? categoryId;
 final  GoalDailyTimeRange? dailyTimeRange;
@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionLabelTimeCopyWith<GoalCriterionLabelTime> get copyWith => _$GoalCriterionLabelTimeCopyWithImpl<GoalCriterionLabelTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionLabelTimeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionLabelTime&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&(identical(other.labelId, labelId) || other.labelId == labelId)&&(identical(other.window, window) || other.window == window)&&(identical(other.aggregation, aggregation) || other.aggregation == aggregation)&&(identical(other.targetHours, targetHours) || other.targetHours == targetHours)&&(identical(other.direction, direction) || other.direction == direction)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.dailyTimeRange, dailyTimeRange) || other.dailyTimeRange == dailyTimeRange)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,labelId,window,aggregation,targetHours,direction,categoryId,dailyTimeRange,title);

@override
String toString() {
  return 'GoalCriterion.labelTime(criterionId: $criterionId, labelId: $labelId, window: $window, aggregation: $aggregation, targetHours: $targetHours, direction: $direction, categoryId: $categoryId, dailyTimeRange: $dailyTimeRange, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionLabelTimeCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionLabelTimeCopyWith(GoalCriterionLabelTime value, $Res Function(GoalCriterionLabelTime) _then) = _$GoalCriterionLabelTimeCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, String labelId, GoalWindow window, GoalAggregation aggregation, num targetHours, GoalDirection direction, String? categoryId, GoalDailyTimeRange? dailyTimeRange, String? title
});


$GoalWindowCopyWith<$Res> get window;$GoalDailyTimeRangeCopyWith<$Res>? get dailyTimeRange;

}
/// @nodoc
class _$GoalCriterionLabelTimeCopyWithImpl<$Res>
    implements $GoalCriterionLabelTimeCopyWith<$Res> {
  _$GoalCriterionLabelTimeCopyWithImpl(this._self, this._then);

  final GoalCriterionLabelTime _self;
  final $Res Function(GoalCriterionLabelTime) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? labelId = null,Object? window = null,Object? aggregation = null,Object? targetHours = null,Object? direction = null,Object? categoryId = freezed,Object? dailyTimeRange = freezed,Object? title = freezed,}) {
  return _then(GoalCriterionLabelTime(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,labelId: null == labelId ? _self.labelId : labelId // ignore: cast_nullable_to_non_nullable
as String,window: null == window ? _self.window : window // ignore: cast_nullable_to_non_nullable
as GoalWindow,aggregation: null == aggregation ? _self.aggregation : aggregation // ignore: cast_nullable_to_non_nullable
as GoalAggregation,targetHours: null == targetHours ? _self.targetHours : targetHours // ignore: cast_nullable_to_non_nullable
as num,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as GoalDirection,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,dailyTimeRange: freezed == dailyTimeRange ? _self.dailyTimeRange : dailyTimeRange // ignore: cast_nullable_to_non_nullable
as GoalDailyTimeRange?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalWindowCopyWith<$Res> get window {
  
  return $GoalWindowCopyWith<$Res>(_self.window, (value) {
    return _then(_self.copyWith(window: value));
  });
}/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GoalDailyTimeRangeCopyWith<$Res>? get dailyTimeRange {
    if (_self.dailyTimeRange == null) {
    return null;
  }

  return $GoalDailyTimeRangeCopyWith<$Res>(_self.dailyTimeRange!, (value) {
    return _then(_self.copyWith(dailyTimeRange: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class GoalCriterionAllOf extends GoalCriterion {
  const GoalCriterionAllOf({required this.criterionId, required final  List<GoalCriterion> criteria, this.title, final  String? $type}): _criteria = criteria,$type = $type ?? 'allOf',super._();
  factory GoalCriterionAllOf.fromJson(Map<String, dynamic> json) => _$GoalCriterionAllOfFromJson(json);

@override final  String criterionId;
 final  List<GoalCriterion> _criteria;
 List<GoalCriterion> get criteria {
  if (_criteria is EqualUnmodifiableListView) return _criteria;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_criteria);
}

@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionAllOfCopyWith<GoalCriterionAllOf> get copyWith => _$GoalCriterionAllOfCopyWithImpl<GoalCriterionAllOf>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionAllOfToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionAllOf&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&const DeepCollectionEquality().equals(other._criteria, _criteria)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,const DeepCollectionEquality().hash(_criteria),title);

@override
String toString() {
  return 'GoalCriterion.allOf(criterionId: $criterionId, criteria: $criteria, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionAllOfCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionAllOfCopyWith(GoalCriterionAllOf value, $Res Function(GoalCriterionAllOf) _then) = _$GoalCriterionAllOfCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, List<GoalCriterion> criteria, String? title
});




}
/// @nodoc
class _$GoalCriterionAllOfCopyWithImpl<$Res>
    implements $GoalCriterionAllOfCopyWith<$Res> {
  _$GoalCriterionAllOfCopyWithImpl(this._self, this._then);

  final GoalCriterionAllOf _self;
  final $Res Function(GoalCriterionAllOf) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? criteria = null,Object? title = freezed,}) {
  return _then(GoalCriterionAllOf(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self._criteria : criteria // ignore: cast_nullable_to_non_nullable
as List<GoalCriterion>,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class GoalCriterionAnyOf extends GoalCriterion {
  const GoalCriterionAnyOf({required this.criterionId, required final  List<GoalCriterion> criteria, this.title, final  String? $type}): _criteria = criteria,$type = $type ?? 'anyOf',super._();
  factory GoalCriterionAnyOf.fromJson(Map<String, dynamic> json) => _$GoalCriterionAnyOfFromJson(json);

@override final  String criterionId;
 final  List<GoalCriterion> _criteria;
 List<GoalCriterion> get criteria {
  if (_criteria is EqualUnmodifiableListView) return _criteria;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_criteria);
}

@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionAnyOfCopyWith<GoalCriterionAnyOf> get copyWith => _$GoalCriterionAnyOfCopyWithImpl<GoalCriterionAnyOf>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionAnyOfToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionAnyOf&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&const DeepCollectionEquality().equals(other._criteria, _criteria)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,const DeepCollectionEquality().hash(_criteria),title);

@override
String toString() {
  return 'GoalCriterion.anyOf(criterionId: $criterionId, criteria: $criteria, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionAnyOfCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionAnyOfCopyWith(GoalCriterionAnyOf value, $Res Function(GoalCriterionAnyOf) _then) = _$GoalCriterionAnyOfCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, List<GoalCriterion> criteria, String? title
});




}
/// @nodoc
class _$GoalCriterionAnyOfCopyWithImpl<$Res>
    implements $GoalCriterionAnyOfCopyWith<$Res> {
  _$GoalCriterionAnyOfCopyWithImpl(this._self, this._then);

  final GoalCriterionAnyOf _self;
  final $Res Function(GoalCriterionAnyOf) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? criteria = null,Object? title = freezed,}) {
  return _then(GoalCriterionAnyOf(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self._criteria : criteria // ignore: cast_nullable_to_non_nullable
as List<GoalCriterion>,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class GoalCriterionAtLeastCount extends GoalCriterion {
  const GoalCriterionAtLeastCount({required this.criterionId, required final  List<GoalCriterion> criteria, required this.successes, this.title, final  String? $type}): _criteria = criteria,$type = $type ?? 'atLeastCount',super._();
  factory GoalCriterionAtLeastCount.fromJson(Map<String, dynamic> json) => _$GoalCriterionAtLeastCountFromJson(json);

@override final  String criterionId;
 final  List<GoalCriterion> _criteria;
 List<GoalCriterion> get criteria {
  if (_criteria is EqualUnmodifiableListView) return _criteria;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_criteria);
}

 final  int successes;
@override final  String? title;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCriterionAtLeastCountCopyWith<GoalCriterionAtLeastCount> get copyWith => _$GoalCriterionAtLeastCountCopyWithImpl<GoalCriterionAtLeastCount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalCriterionAtLeastCountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalCriterionAtLeastCount&&(identical(other.criterionId, criterionId) || other.criterionId == criterionId)&&const DeepCollectionEquality().equals(other._criteria, _criteria)&&(identical(other.successes, successes) || other.successes == successes)&&(identical(other.title, title) || other.title == title));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,criterionId,const DeepCollectionEquality().hash(_criteria),successes,title);

@override
String toString() {
  return 'GoalCriterion.atLeastCount(criterionId: $criterionId, criteria: $criteria, successes: $successes, title: $title)';
}


}

/// @nodoc
abstract mixin class $GoalCriterionAtLeastCountCopyWith<$Res> implements $GoalCriterionCopyWith<$Res> {
  factory $GoalCriterionAtLeastCountCopyWith(GoalCriterionAtLeastCount value, $Res Function(GoalCriterionAtLeastCount) _then) = _$GoalCriterionAtLeastCountCopyWithImpl;
@override @useResult
$Res call({
 String criterionId, List<GoalCriterion> criteria, int successes, String? title
});




}
/// @nodoc
class _$GoalCriterionAtLeastCountCopyWithImpl<$Res>
    implements $GoalCriterionAtLeastCountCopyWith<$Res> {
  _$GoalCriterionAtLeastCountCopyWithImpl(this._self, this._then);

  final GoalCriterionAtLeastCount _self;
  final $Res Function(GoalCriterionAtLeastCount) _then;

/// Create a copy of GoalCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? criterionId = null,Object? criteria = null,Object? successes = null,Object? title = freezed,}) {
  return _then(GoalCriterionAtLeastCount(
criterionId: null == criterionId ? _self.criterionId : criterionId // ignore: cast_nullable_to_non_nullable
as String,criteria: null == criteria ? _self._criteria : criteria // ignore: cast_nullable_to_non_nullable
as List<GoalCriterion>,successes: null == successes ? _self.successes : successes // ignore: cast_nullable_to_non_nullable
as int,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
