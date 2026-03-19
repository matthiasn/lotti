// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_detail_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectDetailState {

 ProjectEntry? get project; List<Task> get linkedTasks; bool get isLoading; bool get isSaving; bool get hasChanges; ProjectDetailError? get error;
/// Create a copy of ProjectDetailState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectDetailStateCopyWith<ProjectDetailState> get copyWith => _$ProjectDetailStateCopyWithImpl<ProjectDetailState>(this as ProjectDetailState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectDetailState&&const DeepCollectionEquality().equals(other.project, project)&&const DeepCollectionEquality().equals(other.linkedTasks, linkedTasks)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&(identical(other.hasChanges, hasChanges) || other.hasChanges == hasChanges)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(project),const DeepCollectionEquality().hash(linkedTasks),isLoading,isSaving,hasChanges,error);

@override
String toString() {
  return 'ProjectDetailState(project: $project, linkedTasks: $linkedTasks, isLoading: $isLoading, isSaving: $isSaving, hasChanges: $hasChanges, error: $error)';
}


}

/// @nodoc
abstract mixin class $ProjectDetailStateCopyWith<$Res>  {
  factory $ProjectDetailStateCopyWith(ProjectDetailState value, $Res Function(ProjectDetailState) _then) = _$ProjectDetailStateCopyWithImpl;
@useResult
$Res call({
 ProjectEntry? project, List<Task> linkedTasks, bool isLoading, bool isSaving, bool hasChanges, ProjectDetailError? error
});




}
/// @nodoc
class _$ProjectDetailStateCopyWithImpl<$Res>
    implements $ProjectDetailStateCopyWith<$Res> {
  _$ProjectDetailStateCopyWithImpl(this._self, this._then);

  final ProjectDetailState _self;
  final $Res Function(ProjectDetailState) _then;

/// Create a copy of ProjectDetailState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? project = freezed,Object? linkedTasks = null,Object? isLoading = null,Object? isSaving = null,Object? hasChanges = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
project: freezed == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as ProjectEntry?,linkedTasks: null == linkedTasks ? _self.linkedTasks : linkedTasks // ignore: cast_nullable_to_non_nullable
as List<Task>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,hasChanges: null == hasChanges ? _self.hasChanges : hasChanges // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ProjectDetailError?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectDetailState].
extension ProjectDetailStatePatterns on ProjectDetailState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectDetailState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectDetailState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectDetailState value)  $default,){
final _that = this;
switch (_that) {
case _ProjectDetailState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectDetailState value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectDetailState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProjectEntry? project,  List<Task> linkedTasks,  bool isLoading,  bool isSaving,  bool hasChanges,  ProjectDetailError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectDetailState() when $default != null:
return $default(_that.project,_that.linkedTasks,_that.isLoading,_that.isSaving,_that.hasChanges,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProjectEntry? project,  List<Task> linkedTasks,  bool isLoading,  bool isSaving,  bool hasChanges,  ProjectDetailError? error)  $default,) {final _that = this;
switch (_that) {
case _ProjectDetailState():
return $default(_that.project,_that.linkedTasks,_that.isLoading,_that.isSaving,_that.hasChanges,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProjectEntry? project,  List<Task> linkedTasks,  bool isLoading,  bool isSaving,  bool hasChanges,  ProjectDetailError? error)?  $default,) {final _that = this;
switch (_that) {
case _ProjectDetailState() when $default != null:
return $default(_that.project,_that.linkedTasks,_that.isLoading,_that.isSaving,_that.hasChanges,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectDetailState implements ProjectDetailState {
  const _ProjectDetailState({required this.project, required final  List<Task> linkedTasks, required this.isLoading, required this.isSaving, required this.hasChanges, this.error}): _linkedTasks = linkedTasks;
  

@override final  ProjectEntry? project;
 final  List<Task> _linkedTasks;
@override List<Task> get linkedTasks {
  if (_linkedTasks is EqualUnmodifiableListView) return _linkedTasks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_linkedTasks);
}

@override final  bool isLoading;
@override final  bool isSaving;
@override final  bool hasChanges;
@override final  ProjectDetailError? error;

/// Create a copy of ProjectDetailState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectDetailStateCopyWith<_ProjectDetailState> get copyWith => __$ProjectDetailStateCopyWithImpl<_ProjectDetailState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectDetailState&&const DeepCollectionEquality().equals(other.project, project)&&const DeepCollectionEquality().equals(other._linkedTasks, _linkedTasks)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&(identical(other.hasChanges, hasChanges) || other.hasChanges == hasChanges)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(project),const DeepCollectionEquality().hash(_linkedTasks),isLoading,isSaving,hasChanges,error);

@override
String toString() {
  return 'ProjectDetailState(project: $project, linkedTasks: $linkedTasks, isLoading: $isLoading, isSaving: $isSaving, hasChanges: $hasChanges, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ProjectDetailStateCopyWith<$Res> implements $ProjectDetailStateCopyWith<$Res> {
  factory _$ProjectDetailStateCopyWith(_ProjectDetailState value, $Res Function(_ProjectDetailState) _then) = __$ProjectDetailStateCopyWithImpl;
@override @useResult
$Res call({
 ProjectEntry? project, List<Task> linkedTasks, bool isLoading, bool isSaving, bool hasChanges, ProjectDetailError? error
});




}
/// @nodoc
class __$ProjectDetailStateCopyWithImpl<$Res>
    implements _$ProjectDetailStateCopyWith<$Res> {
  __$ProjectDetailStateCopyWithImpl(this._self, this._then);

  final _ProjectDetailState _self;
  final $Res Function(_ProjectDetailState) _then;

/// Create a copy of ProjectDetailState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? project = freezed,Object? linkedTasks = null,Object? isLoading = null,Object? isSaving = null,Object? hasChanges = null,Object? error = freezed,}) {
  return _then(_ProjectDetailState(
project: freezed == project ? _self.project : project // ignore: cast_nullable_to_non_nullable
as ProjectEntry?,linkedTasks: null == linkedTasks ? _self._linkedTasks : linkedTasks // ignore: cast_nullable_to_non_nullable
as List<Task>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,hasChanges: null == hasChanges ? _self.hasChanges : hasChanges // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as ProjectDetailError?,
  ));
}


}

// dart format on
