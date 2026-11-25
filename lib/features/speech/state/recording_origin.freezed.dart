// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recording_origin.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RecordingOrigin {

/// The app route on screen when the take started, as the navigation
/// service reports it (`/tasks/<id>`, `/calendar`, …).
 String get route;/// The entry the take is linked to — the same value as the recorder's
/// `linkedId`; null for a voice note that stands on its own.
 String? get subjectId;/// How far the origin page had scrolled, for a page that reports it;
/// null where the page does not, which lands at its top.
 double? get scrollOffset;
/// Create a copy of RecordingOrigin
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecordingOriginCopyWith<RecordingOrigin> get copyWith => _$RecordingOriginCopyWithImpl<RecordingOrigin>(this as RecordingOrigin, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecordingOrigin&&(identical(other.route, route) || other.route == route)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.scrollOffset, scrollOffset) || other.scrollOffset == scrollOffset));
}


@override
int get hashCode => Object.hash(runtimeType,route,subjectId,scrollOffset);

@override
String toString() {
  return 'RecordingOrigin(route: $route, subjectId: $subjectId, scrollOffset: $scrollOffset)';
}


}

/// @nodoc
abstract mixin class $RecordingOriginCopyWith<$Res>  {
  factory $RecordingOriginCopyWith(RecordingOrigin value, $Res Function(RecordingOrigin) _then) = _$RecordingOriginCopyWithImpl;
@useResult
$Res call({
 String route, String? subjectId, double? scrollOffset
});




}
/// @nodoc
class _$RecordingOriginCopyWithImpl<$Res>
    implements $RecordingOriginCopyWith<$Res> {
  _$RecordingOriginCopyWithImpl(this._self, this._then);

  final RecordingOrigin _self;
  final $Res Function(RecordingOrigin) _then;

/// Create a copy of RecordingOrigin
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? route = null,Object? subjectId = freezed,Object? scrollOffset = freezed,}) {
  return _then(_self.copyWith(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,scrollOffset: freezed == scrollOffset ? _self.scrollOffset : scrollOffset // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [RecordingOrigin].
extension RecordingOriginPatterns on RecordingOrigin {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecordingOrigin value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecordingOrigin() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecordingOrigin value)  $default,){
final _that = this;
switch (_that) {
case _RecordingOrigin():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecordingOrigin value)?  $default,){
final _that = this;
switch (_that) {
case _RecordingOrigin() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String route,  String? subjectId,  double? scrollOffset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecordingOrigin() when $default != null:
return $default(_that.route,_that.subjectId,_that.scrollOffset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String route,  String? subjectId,  double? scrollOffset)  $default,) {final _that = this;
switch (_that) {
case _RecordingOrigin():
return $default(_that.route,_that.subjectId,_that.scrollOffset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String route,  String? subjectId,  double? scrollOffset)?  $default,) {final _that = this;
switch (_that) {
case _RecordingOrigin() when $default != null:
return $default(_that.route,_that.subjectId,_that.scrollOffset);case _:
  return null;

}
}

}

/// @nodoc


class _RecordingOrigin implements RecordingOrigin {
  const _RecordingOrigin({required this.route, this.subjectId, this.scrollOffset});
  

/// The app route on screen when the take started, as the navigation
/// service reports it (`/tasks/<id>`, `/calendar`, …).
@override final  String route;
/// The entry the take is linked to — the same value as the recorder's
/// `linkedId`; null for a voice note that stands on its own.
@override final  String? subjectId;
/// How far the origin page had scrolled, for a page that reports it;
/// null where the page does not, which lands at its top.
@override final  double? scrollOffset;

/// Create a copy of RecordingOrigin
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecordingOriginCopyWith<_RecordingOrigin> get copyWith => __$RecordingOriginCopyWithImpl<_RecordingOrigin>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecordingOrigin&&(identical(other.route, route) || other.route == route)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.scrollOffset, scrollOffset) || other.scrollOffset == scrollOffset));
}


@override
int get hashCode => Object.hash(runtimeType,route,subjectId,scrollOffset);

@override
String toString() {
  return 'RecordingOrigin(route: $route, subjectId: $subjectId, scrollOffset: $scrollOffset)';
}


}

/// @nodoc
abstract mixin class _$RecordingOriginCopyWith<$Res> implements $RecordingOriginCopyWith<$Res> {
  factory _$RecordingOriginCopyWith(_RecordingOrigin value, $Res Function(_RecordingOrigin) _then) = __$RecordingOriginCopyWithImpl;
@override @useResult
$Res call({
 String route, String? subjectId, double? scrollOffset
});




}
/// @nodoc
class __$RecordingOriginCopyWithImpl<$Res>
    implements _$RecordingOriginCopyWith<$Res> {
  __$RecordingOriginCopyWithImpl(this._self, this._then);

  final _RecordingOrigin _self;
  final $Res Function(_RecordingOrigin) _then;

/// Create a copy of RecordingOrigin
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? route = null,Object? subjectId = freezed,Object? scrollOffset = freezed,}) {
  return _then(_RecordingOrigin(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,scrollOffset: freezed == scrollOffset ? _self.scrollOffset : scrollOffset // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
