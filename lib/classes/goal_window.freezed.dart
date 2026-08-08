// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_window.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
GoalWindow _$GoalWindowFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'day':
          return GoalWindowDay.fromJson(
            json
          );
                case 'rollingDays':
          return GoalWindowRollingDays.fromJson(
            json
          );
                case 'calendarWeek':
          return GoalWindowCalendarWeek.fromJson(
            json
          );
                case 'calendarMonth':
          return GoalWindowCalendarMonth.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'GoalWindow',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$GoalWindow {



  /// Serializes this GoalWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalWindow);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'GoalWindow()';
}


}

/// @nodoc
class $GoalWindowCopyWith<$Res>  {
$GoalWindowCopyWith(GoalWindow _, $Res Function(GoalWindow) __);
}


/// Adds pattern-matching-related methods to [GoalWindow].
extension GoalWindowPatterns on GoalWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( GoalWindowDay value)?  day,TResult Function( GoalWindowRollingDays value)?  rollingDays,TResult Function( GoalWindowCalendarWeek value)?  calendarWeek,TResult Function( GoalWindowCalendarMonth value)?  calendarMonth,required TResult orElse(),}){
final _that = this;
switch (_that) {
case GoalWindowDay() when day != null:
return day(_that);case GoalWindowRollingDays() when rollingDays != null:
return rollingDays(_that);case GoalWindowCalendarWeek() when calendarWeek != null:
return calendarWeek(_that);case GoalWindowCalendarMonth() when calendarMonth != null:
return calendarMonth(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( GoalWindowDay value)  day,required TResult Function( GoalWindowRollingDays value)  rollingDays,required TResult Function( GoalWindowCalendarWeek value)  calendarWeek,required TResult Function( GoalWindowCalendarMonth value)  calendarMonth,}){
final _that = this;
switch (_that) {
case GoalWindowDay():
return day(_that);case GoalWindowRollingDays():
return rollingDays(_that);case GoalWindowCalendarWeek():
return calendarWeek(_that);case GoalWindowCalendarMonth():
return calendarMonth(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( GoalWindowDay value)?  day,TResult? Function( GoalWindowRollingDays value)?  rollingDays,TResult? Function( GoalWindowCalendarWeek value)?  calendarWeek,TResult? Function( GoalWindowCalendarMonth value)?  calendarMonth,}){
final _that = this;
switch (_that) {
case GoalWindowDay() when day != null:
return day(_that);case GoalWindowRollingDays() when rollingDays != null:
return rollingDays(_that);case GoalWindowCalendarWeek() when calendarWeek != null:
return calendarWeek(_that);case GoalWindowCalendarMonth() when calendarMonth != null:
return calendarMonth(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  day,TResult Function( int count)?  rollingDays,TResult Function()?  calendarWeek,TResult Function()?  calendarMonth,required TResult orElse(),}) {final _that = this;
switch (_that) {
case GoalWindowDay() when day != null:
return day();case GoalWindowRollingDays() when rollingDays != null:
return rollingDays(_that.count);case GoalWindowCalendarWeek() when calendarWeek != null:
return calendarWeek();case GoalWindowCalendarMonth() when calendarMonth != null:
return calendarMonth();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  day,required TResult Function( int count)  rollingDays,required TResult Function()  calendarWeek,required TResult Function()  calendarMonth,}) {final _that = this;
switch (_that) {
case GoalWindowDay():
return day();case GoalWindowRollingDays():
return rollingDays(_that.count);case GoalWindowCalendarWeek():
return calendarWeek();case GoalWindowCalendarMonth():
return calendarMonth();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  day,TResult? Function( int count)?  rollingDays,TResult? Function()?  calendarWeek,TResult? Function()?  calendarMonth,}) {final _that = this;
switch (_that) {
case GoalWindowDay() when day != null:
return day();case GoalWindowRollingDays() when rollingDays != null:
return rollingDays(_that.count);case GoalWindowCalendarWeek() when calendarWeek != null:
return calendarWeek();case GoalWindowCalendarMonth() when calendarMonth != null:
return calendarMonth();case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class GoalWindowDay extends GoalWindow {
  const GoalWindowDay({final  String? $type}): $type = $type ?? 'day',super._();
  factory GoalWindowDay.fromJson(Map<String, dynamic> json) => _$GoalWindowDayFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$GoalWindowDayToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalWindowDay);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'GoalWindow.day()';
}


}




/// @nodoc
@JsonSerializable()

class GoalWindowRollingDays extends GoalWindow {
  const GoalWindowRollingDays({required this.count, final  String? $type}): $type = $type ?? 'rollingDays',super._();
  factory GoalWindowRollingDays.fromJson(Map<String, dynamic> json) => _$GoalWindowRollingDaysFromJson(json);

 final  int count;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of GoalWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalWindowRollingDaysCopyWith<GoalWindowRollingDays> get copyWith => _$GoalWindowRollingDaysCopyWithImpl<GoalWindowRollingDays>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalWindowRollingDaysToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalWindowRollingDays&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,count);

@override
String toString() {
  return 'GoalWindow.rollingDays(count: $count)';
}


}

/// @nodoc
abstract mixin class $GoalWindowRollingDaysCopyWith<$Res> implements $GoalWindowCopyWith<$Res> {
  factory $GoalWindowRollingDaysCopyWith(GoalWindowRollingDays value, $Res Function(GoalWindowRollingDays) _then) = _$GoalWindowRollingDaysCopyWithImpl;
@useResult
$Res call({
 int count
});




}
/// @nodoc
class _$GoalWindowRollingDaysCopyWithImpl<$Res>
    implements $GoalWindowRollingDaysCopyWith<$Res> {
  _$GoalWindowRollingDaysCopyWithImpl(this._self, this._then);

  final GoalWindowRollingDays _self;
  final $Res Function(GoalWindowRollingDays) _then;

/// Create a copy of GoalWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? count = null,}) {
  return _then(GoalWindowRollingDays(
count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class GoalWindowCalendarWeek extends GoalWindow {
  const GoalWindowCalendarWeek({final  String? $type}): $type = $type ?? 'calendarWeek',super._();
  factory GoalWindowCalendarWeek.fromJson(Map<String, dynamic> json) => _$GoalWindowCalendarWeekFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$GoalWindowCalendarWeekToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalWindowCalendarWeek);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'GoalWindow.calendarWeek()';
}


}




/// @nodoc
@JsonSerializable()

class GoalWindowCalendarMonth extends GoalWindow {
  const GoalWindowCalendarMonth({final  String? $type}): $type = $type ?? 'calendarMonth',super._();
  factory GoalWindowCalendarMonth.fromJson(Map<String, dynamic> json) => _$GoalWindowCalendarMonthFromJson(json);



@JsonKey(name: 'runtimeType')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$GoalWindowCalendarMonthToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalWindowCalendarMonth);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'GoalWindow.calendarMonth()';
}


}




// dart format on
