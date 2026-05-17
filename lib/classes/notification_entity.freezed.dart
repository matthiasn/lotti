// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
NotificationEntity _$NotificationEntityFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'taskSuggestion':
          return TaskSuggestionNotification.fromJson(
            json
          );
                case 'taskOverdue':
          return TaskOverdueNotification.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'NotificationEntity',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$NotificationEntity {

 NotificationMeta get meta; String get linkedTaskId; String get title; String get body;
/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationEntityCopyWith<NotificationEntity> get copyWith => _$NotificationEntityCopyWithImpl<NotificationEntity>(this as NotificationEntity, _$identity);

  /// Serializes this NotificationEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationEntity&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.linkedTaskId, linkedTaskId) || other.linkedTaskId == linkedTaskId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,linkedTaskId,title,body);

@override
String toString() {
  return 'NotificationEntity(meta: $meta, linkedTaskId: $linkedTaskId, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $NotificationEntityCopyWith<$Res>  {
  factory $NotificationEntityCopyWith(NotificationEntity value, $Res Function(NotificationEntity) _then) = _$NotificationEntityCopyWithImpl;
@useResult
$Res call({
 NotificationMeta meta, String linkedTaskId, String title, String body
});


$NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$NotificationEntityCopyWithImpl<$Res>
    implements $NotificationEntityCopyWith<$Res> {
  _$NotificationEntityCopyWithImpl(this._self, this._then);

  final NotificationEntity _self;
  final $Res Function(NotificationEntity) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? meta = null,Object? linkedTaskId = null,Object? title = null,Object? body = null,}) {
  return _then(_self.copyWith(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,linkedTaskId: null == linkedTaskId ? _self.linkedTaskId : linkedTaskId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationMetaCopyWith<$Res> get meta {
  
  return $NotificationMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// Adds pattern-matching-related methods to [NotificationEntity].
extension NotificationEntityPatterns on NotificationEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TaskSuggestionNotification value)?  taskSuggestion,TResult Function( TaskOverdueNotification value)?  taskOverdue,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TaskSuggestionNotification value)  taskSuggestion,required TResult Function( TaskOverdueNotification value)  taskOverdue,}){
final _that = this;
switch (_that) {
case TaskSuggestionNotification():
return taskSuggestion(_that);case TaskOverdueNotification():
return taskOverdue(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TaskSuggestionNotification value)?  taskSuggestion,TResult? Function( TaskOverdueNotification value)?  taskOverdue,}){
final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( NotificationMeta meta,  String linkedTaskId,  int suggestionCount,  String title,  String body)?  taskSuggestion,TResult Function( NotificationMeta meta,  String linkedTaskId,  String title,  String body)?  taskOverdue,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that.meta,_that.linkedTaskId,_that.suggestionCount,_that.title,_that.body);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that.meta,_that.linkedTaskId,_that.title,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( NotificationMeta meta,  String linkedTaskId,  int suggestionCount,  String title,  String body)  taskSuggestion,required TResult Function( NotificationMeta meta,  String linkedTaskId,  String title,  String body)  taskOverdue,}) {final _that = this;
switch (_that) {
case TaskSuggestionNotification():
return taskSuggestion(_that.meta,_that.linkedTaskId,_that.suggestionCount,_that.title,_that.body);case TaskOverdueNotification():
return taskOverdue(_that.meta,_that.linkedTaskId,_that.title,_that.body);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( NotificationMeta meta,  String linkedTaskId,  int suggestionCount,  String title,  String body)?  taskSuggestion,TResult? Function( NotificationMeta meta,  String linkedTaskId,  String title,  String body)?  taskOverdue,}) {final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that.meta,_that.linkedTaskId,_that.suggestionCount,_that.title,_that.body);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that.meta,_that.linkedTaskId,_that.title,_that.body);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class TaskSuggestionNotification implements NotificationEntity {
  const TaskSuggestionNotification({required this.meta, required this.linkedTaskId, required this.suggestionCount, required this.title, required this.body, final  String? $type}): $type = $type ?? 'taskSuggestion';
  factory TaskSuggestionNotification.fromJson(Map<String, dynamic> json) => _$TaskSuggestionNotificationFromJson(json);

@override final  NotificationMeta meta;
@override final  String linkedTaskId;
 final  int suggestionCount;
@override final  String title;
@override final  String body;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskSuggestionNotificationCopyWith<TaskSuggestionNotification> get copyWith => _$TaskSuggestionNotificationCopyWithImpl<TaskSuggestionNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskSuggestionNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskSuggestionNotification&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.linkedTaskId, linkedTaskId) || other.linkedTaskId == linkedTaskId)&&(identical(other.suggestionCount, suggestionCount) || other.suggestionCount == suggestionCount)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,linkedTaskId,suggestionCount,title,body);

@override
String toString() {
  return 'NotificationEntity.taskSuggestion(meta: $meta, linkedTaskId: $linkedTaskId, suggestionCount: $suggestionCount, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $TaskSuggestionNotificationCopyWith<$Res> implements $NotificationEntityCopyWith<$Res> {
  factory $TaskSuggestionNotificationCopyWith(TaskSuggestionNotification value, $Res Function(TaskSuggestionNotification) _then) = _$TaskSuggestionNotificationCopyWithImpl;
@override @useResult
$Res call({
 NotificationMeta meta, String linkedTaskId, int suggestionCount, String title, String body
});


@override $NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$TaskSuggestionNotificationCopyWithImpl<$Res>
    implements $TaskSuggestionNotificationCopyWith<$Res> {
  _$TaskSuggestionNotificationCopyWithImpl(this._self, this._then);

  final TaskSuggestionNotification _self;
  final $Res Function(TaskSuggestionNotification) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? linkedTaskId = null,Object? suggestionCount = null,Object? title = null,Object? body = null,}) {
  return _then(TaskSuggestionNotification(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,linkedTaskId: null == linkedTaskId ? _self.linkedTaskId : linkedTaskId // ignore: cast_nullable_to_non_nullable
as String,suggestionCount: null == suggestionCount ? _self.suggestionCount : suggestionCount // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationMetaCopyWith<$Res> get meta {
  
  return $NotificationMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class TaskOverdueNotification implements NotificationEntity {
  const TaskOverdueNotification({required this.meta, required this.linkedTaskId, required this.title, required this.body, final  String? $type}): $type = $type ?? 'taskOverdue';
  factory TaskOverdueNotification.fromJson(Map<String, dynamic> json) => _$TaskOverdueNotificationFromJson(json);

@override final  NotificationMeta meta;
@override final  String linkedTaskId;
@override final  String title;
@override final  String body;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskOverdueNotificationCopyWith<TaskOverdueNotification> get copyWith => _$TaskOverdueNotificationCopyWithImpl<TaskOverdueNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskOverdueNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskOverdueNotification&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.linkedTaskId, linkedTaskId) || other.linkedTaskId == linkedTaskId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,linkedTaskId,title,body);

@override
String toString() {
  return 'NotificationEntity.taskOverdue(meta: $meta, linkedTaskId: $linkedTaskId, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $TaskOverdueNotificationCopyWith<$Res> implements $NotificationEntityCopyWith<$Res> {
  factory $TaskOverdueNotificationCopyWith(TaskOverdueNotification value, $Res Function(TaskOverdueNotification) _then) = _$TaskOverdueNotificationCopyWithImpl;
@override @useResult
$Res call({
 NotificationMeta meta, String linkedTaskId, String title, String body
});


@override $NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$TaskOverdueNotificationCopyWithImpl<$Res>
    implements $TaskOverdueNotificationCopyWith<$Res> {
  _$TaskOverdueNotificationCopyWithImpl(this._self, this._then);

  final TaskOverdueNotification _self;
  final $Res Function(TaskOverdueNotification) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? linkedTaskId = null,Object? title = null,Object? body = null,}) {
  return _then(TaskOverdueNotification(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,linkedTaskId: null == linkedTaskId ? _self.linkedTaskId : linkedTaskId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationMetaCopyWith<$Res> get meta {
  
  return $NotificationMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// @nodoc
mixin _$NotificationMeta {

 String get id; DateTime get createdAt; DateTime get updatedAt; DateTime get scheduledFor; VectorClock get vectorClock; String get originatingHostId; DateTime? get seenAt; DateTime? get actedOnAt; DateTime? get deletedAt; String? get category;
/// Create a copy of NotificationMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationMetaCopyWith<NotificationMeta> get copyWith => _$NotificationMetaCopyWithImpl<NotificationMeta>(this as NotificationMeta, _$identity);

  /// Serializes this NotificationMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationMeta&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&(identical(other.seenAt, seenAt) || other.seenAt == seenAt)&&(identical(other.actedOnAt, actedOnAt) || other.actedOnAt == actedOnAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,updatedAt,scheduledFor,vectorClock,originatingHostId,seenAt,actedOnAt,deletedAt,category);

@override
String toString() {
  return 'NotificationMeta(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, scheduledFor: $scheduledFor, vectorClock: $vectorClock, originatingHostId: $originatingHostId, seenAt: $seenAt, actedOnAt: $actedOnAt, deletedAt: $deletedAt, category: $category)';
}


}

/// @nodoc
abstract mixin class $NotificationMetaCopyWith<$Res>  {
  factory $NotificationMetaCopyWith(NotificationMeta value, $Res Function(NotificationMeta) _then) = _$NotificationMetaCopyWithImpl;
@useResult
$Res call({
 String id, DateTime createdAt, DateTime updatedAt, DateTime scheduledFor, VectorClock vectorClock, String originatingHostId, DateTime? seenAt, DateTime? actedOnAt, DateTime? deletedAt, String? category
});




}
/// @nodoc
class _$NotificationMetaCopyWithImpl<$Res>
    implements $NotificationMetaCopyWith<$Res> {
  _$NotificationMetaCopyWithImpl(this._self, this._then);

  final NotificationMeta _self;
  final $Res Function(NotificationMeta) _then;

/// Create a copy of NotificationMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? createdAt = null,Object? updatedAt = null,Object? scheduledFor = null,Object? vectorClock = null,Object? originatingHostId = null,Object? seenAt = freezed,Object? actedOnAt = freezed,Object? deletedAt = freezed,Object? category = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: null == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock,originatingHostId: null == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String,seenAt: freezed == seenAt ? _self.seenAt : seenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,actedOnAt: freezed == actedOnAt ? _self.actedOnAt : actedOnAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationMeta].
extension NotificationMetaPatterns on NotificationMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationMeta value)  $default,){
final _that = this;
switch (_that) {
case _NotificationMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationMeta value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  DateTime updatedAt,  DateTime scheduledFor,  VectorClock vectorClock,  String originatingHostId,  DateTime? seenAt,  DateTime? actedOnAt,  DateTime? deletedAt,  String? category)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationMeta() when $default != null:
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.scheduledFor,_that.vectorClock,_that.originatingHostId,_that.seenAt,_that.actedOnAt,_that.deletedAt,_that.category);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime createdAt,  DateTime updatedAt,  DateTime scheduledFor,  VectorClock vectorClock,  String originatingHostId,  DateTime? seenAt,  DateTime? actedOnAt,  DateTime? deletedAt,  String? category)  $default,) {final _that = this;
switch (_that) {
case _NotificationMeta():
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.scheduledFor,_that.vectorClock,_that.originatingHostId,_that.seenAt,_that.actedOnAt,_that.deletedAt,_that.category);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime createdAt,  DateTime updatedAt,  DateTime scheduledFor,  VectorClock vectorClock,  String originatingHostId,  DateTime? seenAt,  DateTime? actedOnAt,  DateTime? deletedAt,  String? category)?  $default,) {final _that = this;
switch (_that) {
case _NotificationMeta() when $default != null:
return $default(_that.id,_that.createdAt,_that.updatedAt,_that.scheduledFor,_that.vectorClock,_that.originatingHostId,_that.seenAt,_that.actedOnAt,_that.deletedAt,_that.category);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationMeta implements NotificationMeta {
  const _NotificationMeta({required this.id, required this.createdAt, required this.updatedAt, required this.scheduledFor, required this.vectorClock, required this.originatingHostId, this.seenAt, this.actedOnAt, this.deletedAt, this.category});
  factory _NotificationMeta.fromJson(Map<String, dynamic> json) => _$NotificationMetaFromJson(json);

@override final  String id;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime scheduledFor;
@override final  VectorClock vectorClock;
@override final  String originatingHostId;
@override final  DateTime? seenAt;
@override final  DateTime? actedOnAt;
@override final  DateTime? deletedAt;
@override final  String? category;

/// Create a copy of NotificationMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationMetaCopyWith<_NotificationMeta> get copyWith => __$NotificationMetaCopyWithImpl<_NotificationMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationMeta&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&(identical(other.seenAt, seenAt) || other.seenAt == seenAt)&&(identical(other.actedOnAt, actedOnAt) || other.actedOnAt == actedOnAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,createdAt,updatedAt,scheduledFor,vectorClock,originatingHostId,seenAt,actedOnAt,deletedAt,category);

@override
String toString() {
  return 'NotificationMeta(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, scheduledFor: $scheduledFor, vectorClock: $vectorClock, originatingHostId: $originatingHostId, seenAt: $seenAt, actedOnAt: $actedOnAt, deletedAt: $deletedAt, category: $category)';
}


}

/// @nodoc
abstract mixin class _$NotificationMetaCopyWith<$Res> implements $NotificationMetaCopyWith<$Res> {
  factory _$NotificationMetaCopyWith(_NotificationMeta value, $Res Function(_NotificationMeta) _then) = __$NotificationMetaCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime createdAt, DateTime updatedAt, DateTime scheduledFor, VectorClock vectorClock, String originatingHostId, DateTime? seenAt, DateTime? actedOnAt, DateTime? deletedAt, String? category
});




}
/// @nodoc
class __$NotificationMetaCopyWithImpl<$Res>
    implements _$NotificationMetaCopyWith<$Res> {
  __$NotificationMetaCopyWithImpl(this._self, this._then);

  final _NotificationMeta _self;
  final $Res Function(_NotificationMeta) _then;

/// Create a copy of NotificationMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? createdAt = null,Object? updatedAt = null,Object? scheduledFor = null,Object? vectorClock = null,Object? originatingHostId = null,Object? seenAt = freezed,Object? actedOnAt = freezed,Object? deletedAt = freezed,Object? category = freezed,}) {
  return _then(_NotificationMeta(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: null == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock,originatingHostId: null == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String,seenAt: freezed == seenAt ? _self.seenAt : seenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,actedOnAt: freezed == actedOnAt ? _self.actedOnAt : actedOnAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
