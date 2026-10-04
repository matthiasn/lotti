// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'skill_assignment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SkillAssignment {

 String get skillId; bool get automate;
/// Create a copy of SkillAssignment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillAssignmentCopyWith<SkillAssignment> get copyWith => _$SkillAssignmentCopyWithImpl<SkillAssignment>(this as SkillAssignment, _$identity);

  /// Serializes this SkillAssignment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SkillAssignment&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.automate, automate) || other.automate == automate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillId,automate);

@override
String toString() {
  return 'SkillAssignment(skillId: $skillId, automate: $automate)';
}


}

/// @nodoc
abstract mixin class $SkillAssignmentCopyWith<$Res>  {
  factory $SkillAssignmentCopyWith(SkillAssignment value, $Res Function(SkillAssignment) _then) = _$SkillAssignmentCopyWithImpl;
@useResult
$Res call({
 String skillId, bool automate
});




}
/// @nodoc
class _$SkillAssignmentCopyWithImpl<$Res>
    implements $SkillAssignmentCopyWith<$Res> {
  _$SkillAssignmentCopyWithImpl(this._self, this._then);

  final SkillAssignment _self;
  final $Res Function(SkillAssignment) _then;

/// Create a copy of SkillAssignment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? skillId = null,Object? automate = null,}) {
  return _then(_self.copyWith(
skillId: null == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as String,automate: null == automate ? _self.automate : automate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SkillAssignment].
extension SkillAssignmentPatterns on SkillAssignment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SkillAssignment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SkillAssignment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SkillAssignment value)  $default,){
final _that = this;
switch (_that) {
case _SkillAssignment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SkillAssignment value)?  $default,){
final _that = this;
switch (_that) {
case _SkillAssignment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String skillId,  bool automate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SkillAssignment() when $default != null:
return $default(_that.skillId,_that.automate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String skillId,  bool automate)  $default,) {final _that = this;
switch (_that) {
case _SkillAssignment():
return $default(_that.skillId,_that.automate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String skillId,  bool automate)?  $default,) {final _that = this;
switch (_that) {
case _SkillAssignment() when $default != null:
return $default(_that.skillId,_that.automate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SkillAssignment implements SkillAssignment {
  const _SkillAssignment({required this.skillId, this.automate = false});
  factory _SkillAssignment.fromJson(Map<String, dynamic> json) => _$SkillAssignmentFromJson(json);

@override final  String skillId;
@override@JsonKey() final  bool automate;

/// Create a copy of SkillAssignment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillAssignmentCopyWith<_SkillAssignment> get copyWith => __$SkillAssignmentCopyWithImpl<_SkillAssignment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillAssignmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkillAssignment&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.automate, automate) || other.automate == automate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,skillId,automate);

@override
String toString() {
  return 'SkillAssignment(skillId: $skillId, automate: $automate)';
}


}

/// @nodoc
abstract mixin class _$SkillAssignmentCopyWith<$Res> implements $SkillAssignmentCopyWith<$Res> {
  factory _$SkillAssignmentCopyWith(_SkillAssignment value, $Res Function(_SkillAssignment) _then) = __$SkillAssignmentCopyWithImpl;
@override @useResult
$Res call({
 String skillId, bool automate
});




}
/// @nodoc
class __$SkillAssignmentCopyWithImpl<$Res>
    implements _$SkillAssignmentCopyWith<$Res> {
  __$SkillAssignmentCopyWithImpl(this._self, this._then);

  final _SkillAssignment _self;
  final $Res Function(_SkillAssignment) _then;

/// Create a copy of SkillAssignment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? skillId = null,Object? automate = null,}) {
  return _then(_SkillAssignment(
skillId: null == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as String,automate: null == automate ? _self.automate : automate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
