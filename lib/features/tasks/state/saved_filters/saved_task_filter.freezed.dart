// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_task_filter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SavedTaskFilter {

 String get id; String get name; TasksFilter get filter;
/// Create a copy of SavedTaskFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedTaskFilterCopyWith<SavedTaskFilter> get copyWith => _$SavedTaskFilterCopyWithImpl<SavedTaskFilter>(this as SavedTaskFilter, _$identity);

  /// Serializes this SavedTaskFilter to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedTaskFilter&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.filter, filter) || other.filter == filter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,filter);

@override
String toString() {
  return 'SavedTaskFilter(id: $id, name: $name, filter: $filter)';
}


}

/// @nodoc
abstract mixin class $SavedTaskFilterCopyWith<$Res>  {
  factory $SavedTaskFilterCopyWith(SavedTaskFilter value, $Res Function(SavedTaskFilter) _then) = _$SavedTaskFilterCopyWithImpl;
@useResult
$Res call({
 String id, String name, TasksFilter filter
});


$TasksFilterCopyWith<$Res> get filter;

}
/// @nodoc
class _$SavedTaskFilterCopyWithImpl<$Res>
    implements $SavedTaskFilterCopyWith<$Res> {
  _$SavedTaskFilterCopyWithImpl(this._self, this._then);

  final SavedTaskFilter _self;
  final $Res Function(SavedTaskFilter) _then;

/// Create a copy of SavedTaskFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? filter = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as TasksFilter,
  ));
}
/// Create a copy of SavedTaskFilter
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TasksFilterCopyWith<$Res> get filter {
  
  return $TasksFilterCopyWith<$Res>(_self.filter, (value) {
    return _then(_self.copyWith(filter: value));
  });
}
}


/// Adds pattern-matching-related methods to [SavedTaskFilter].
extension SavedTaskFilterPatterns on SavedTaskFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedTaskFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedTaskFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedTaskFilter value)  $default,){
final _that = this;
switch (_that) {
case _SavedTaskFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedTaskFilter value)?  $default,){
final _that = this;
switch (_that) {
case _SavedTaskFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  TasksFilter filter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedTaskFilter() when $default != null:
return $default(_that.id,_that.name,_that.filter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  TasksFilter filter)  $default,) {final _that = this;
switch (_that) {
case _SavedTaskFilter():
return $default(_that.id,_that.name,_that.filter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  TasksFilter filter)?  $default,) {final _that = this;
switch (_that) {
case _SavedTaskFilter() when $default != null:
return $default(_that.id,_that.name,_that.filter);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _SavedTaskFilter implements SavedTaskFilter {
  const _SavedTaskFilter({required this.id, required this.name, required this.filter});
  factory _SavedTaskFilter.fromJson(Map<String, dynamic> json) => _$SavedTaskFilterFromJson(json);

@override final  String id;
@override final  String name;
@override final  TasksFilter filter;

/// Create a copy of SavedTaskFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedTaskFilterCopyWith<_SavedTaskFilter> get copyWith => __$SavedTaskFilterCopyWithImpl<_SavedTaskFilter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SavedTaskFilterToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedTaskFilter&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.filter, filter) || other.filter == filter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,filter);

@override
String toString() {
  return 'SavedTaskFilter(id: $id, name: $name, filter: $filter)';
}


}

/// @nodoc
abstract mixin class _$SavedTaskFilterCopyWith<$Res> implements $SavedTaskFilterCopyWith<$Res> {
  factory _$SavedTaskFilterCopyWith(_SavedTaskFilter value, $Res Function(_SavedTaskFilter) _then) = __$SavedTaskFilterCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, TasksFilter filter
});


@override $TasksFilterCopyWith<$Res> get filter;

}
/// @nodoc
class __$SavedTaskFilterCopyWithImpl<$Res>
    implements _$SavedTaskFilterCopyWith<$Res> {
  __$SavedTaskFilterCopyWithImpl(this._self, this._then);

  final _SavedTaskFilter _self;
  final $Res Function(_SavedTaskFilter) _then;

/// Create a copy of SavedTaskFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? filter = null,}) {
  return _then(_SavedTaskFilter(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as TasksFilter,
  ));
}

/// Create a copy of SavedTaskFilter
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TasksFilterCopyWith<$Res> get filter {
  
  return $TasksFilterCopyWith<$Res>(_self.filter, (value) {
    return _then(_self.copyWith(filter: value));
  });
}
}

// dart format on
