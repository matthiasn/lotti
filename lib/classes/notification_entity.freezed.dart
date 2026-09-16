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
                case 'relationshipCheckIn':
          return RelationshipCheckInNotification.fromJson(
            json
          );
                case 'habitAutoCompleted':
          return HabitAutoCompletedNotification.fromJson(
            json
          );
                case 'goalOffTrack':
          return GoalOffTrackNotification.fromJson(
            json
          );
                case 'dayPlanOutcome':
          return DayPlanOutcomeNotification.fromJson(
            json
          );
                case 'syncConflict':
          return SyncConflictNotification.fromJson(
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

 NotificationMeta get meta; String get title; String get body;
/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationEntityCopyWith<NotificationEntity> get copyWith => _$NotificationEntityCopyWithImpl<NotificationEntity>(this as NotificationEntity, _$identity);

  /// Serializes this NotificationEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationEntity&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,title,body);

@override
String toString() {
  return 'NotificationEntity(meta: $meta, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $NotificationEntityCopyWith<$Res>  {
  factory $NotificationEntityCopyWith(NotificationEntity value, $Res Function(NotificationEntity) _then) = _$NotificationEntityCopyWithImpl;
@useResult
$Res call({
 NotificationMeta meta, String title, String body
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
@pragma('vm:prefer-inline') @override $Res call({Object? meta = null,Object? title = null,Object? body = null,}) {
  return _then(_self.copyWith(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TaskSuggestionNotification value)?  taskSuggestion,TResult Function( TaskOverdueNotification value)?  taskOverdue,TResult Function( RelationshipCheckInNotification value)?  relationshipCheckIn,TResult Function( HabitAutoCompletedNotification value)?  habitAutoCompleted,TResult Function( GoalOffTrackNotification value)?  goalOffTrack,TResult Function( DayPlanOutcomeNotification value)?  dayPlanOutcome,TResult Function( SyncConflictNotification value)?  syncConflict,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that);case RelationshipCheckInNotification() when relationshipCheckIn != null:
return relationshipCheckIn(_that);case HabitAutoCompletedNotification() when habitAutoCompleted != null:
return habitAutoCompleted(_that);case GoalOffTrackNotification() when goalOffTrack != null:
return goalOffTrack(_that);case DayPlanOutcomeNotification() when dayPlanOutcome != null:
return dayPlanOutcome(_that);case SyncConflictNotification() when syncConflict != null:
return syncConflict(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TaskSuggestionNotification value)  taskSuggestion,required TResult Function( TaskOverdueNotification value)  taskOverdue,required TResult Function( RelationshipCheckInNotification value)  relationshipCheckIn,required TResult Function( HabitAutoCompletedNotification value)  habitAutoCompleted,required TResult Function( GoalOffTrackNotification value)  goalOffTrack,required TResult Function( DayPlanOutcomeNotification value)  dayPlanOutcome,required TResult Function( SyncConflictNotification value)  syncConflict,}){
final _that = this;
switch (_that) {
case TaskSuggestionNotification():
return taskSuggestion(_that);case TaskOverdueNotification():
return taskOverdue(_that);case RelationshipCheckInNotification():
return relationshipCheckIn(_that);case HabitAutoCompletedNotification():
return habitAutoCompleted(_that);case GoalOffTrackNotification():
return goalOffTrack(_that);case DayPlanOutcomeNotification():
return dayPlanOutcome(_that);case SyncConflictNotification():
return syncConflict(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TaskSuggestionNotification value)?  taskSuggestion,TResult? Function( TaskOverdueNotification value)?  taskOverdue,TResult? Function( RelationshipCheckInNotification value)?  relationshipCheckIn,TResult? Function( HabitAutoCompletedNotification value)?  habitAutoCompleted,TResult? Function( GoalOffTrackNotification value)?  goalOffTrack,TResult? Function( DayPlanOutcomeNotification value)?  dayPlanOutcome,TResult? Function( SyncConflictNotification value)?  syncConflict,}){
final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that);case RelationshipCheckInNotification() when relationshipCheckIn != null:
return relationshipCheckIn(_that);case HabitAutoCompletedNotification() when habitAutoCompleted != null:
return habitAutoCompleted(_that);case GoalOffTrackNotification() when goalOffTrack != null:
return goalOffTrack(_that);case DayPlanOutcomeNotification() when dayPlanOutcome != null:
return dayPlanOutcome(_that);case SyncConflictNotification() when syncConflict != null:
return syncConflict(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( NotificationMeta meta,  String linkedTaskId,  int suggestionCount,  String title,  String body)?  taskSuggestion,TResult Function( NotificationMeta meta,  String linkedTaskId,  String title,  String body)?  taskOverdue,TResult Function( NotificationMeta meta,  String linkedRelationshipId,  String title,  String body)?  relationshipCheckIn,TResult Function( NotificationMeta meta,  List<String> linkedHabitIds,  String dayKey,  String title,  String body)?  habitAutoCompleted,TResult Function( NotificationMeta meta,  String linkedGoalAgentId,  String title,  String body)?  goalOffTrack,TResult Function( NotificationMeta meta,  String dayId,  bool succeeded,  String title,  String body)?  dayPlanOutcome,TResult Function( NotificationMeta meta,  int conflictCount,  String title,  String body)?  syncConflict,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that.meta,_that.linkedTaskId,_that.suggestionCount,_that.title,_that.body);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that.meta,_that.linkedTaskId,_that.title,_that.body);case RelationshipCheckInNotification() when relationshipCheckIn != null:
return relationshipCheckIn(_that.meta,_that.linkedRelationshipId,_that.title,_that.body);case HabitAutoCompletedNotification() when habitAutoCompleted != null:
return habitAutoCompleted(_that.meta,_that.linkedHabitIds,_that.dayKey,_that.title,_that.body);case GoalOffTrackNotification() when goalOffTrack != null:
return goalOffTrack(_that.meta,_that.linkedGoalAgentId,_that.title,_that.body);case DayPlanOutcomeNotification() when dayPlanOutcome != null:
return dayPlanOutcome(_that.meta,_that.dayId,_that.succeeded,_that.title,_that.body);case SyncConflictNotification() when syncConflict != null:
return syncConflict(_that.meta,_that.conflictCount,_that.title,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( NotificationMeta meta,  String linkedTaskId,  int suggestionCount,  String title,  String body)  taskSuggestion,required TResult Function( NotificationMeta meta,  String linkedTaskId,  String title,  String body)  taskOverdue,required TResult Function( NotificationMeta meta,  String linkedRelationshipId,  String title,  String body)  relationshipCheckIn,required TResult Function( NotificationMeta meta,  List<String> linkedHabitIds,  String dayKey,  String title,  String body)  habitAutoCompleted,required TResult Function( NotificationMeta meta,  String linkedGoalAgentId,  String title,  String body)  goalOffTrack,required TResult Function( NotificationMeta meta,  String dayId,  bool succeeded,  String title,  String body)  dayPlanOutcome,required TResult Function( NotificationMeta meta,  int conflictCount,  String title,  String body)  syncConflict,}) {final _that = this;
switch (_that) {
case TaskSuggestionNotification():
return taskSuggestion(_that.meta,_that.linkedTaskId,_that.suggestionCount,_that.title,_that.body);case TaskOverdueNotification():
return taskOverdue(_that.meta,_that.linkedTaskId,_that.title,_that.body);case RelationshipCheckInNotification():
return relationshipCheckIn(_that.meta,_that.linkedRelationshipId,_that.title,_that.body);case HabitAutoCompletedNotification():
return habitAutoCompleted(_that.meta,_that.linkedHabitIds,_that.dayKey,_that.title,_that.body);case GoalOffTrackNotification():
return goalOffTrack(_that.meta,_that.linkedGoalAgentId,_that.title,_that.body);case DayPlanOutcomeNotification():
return dayPlanOutcome(_that.meta,_that.dayId,_that.succeeded,_that.title,_that.body);case SyncConflictNotification():
return syncConflict(_that.meta,_that.conflictCount,_that.title,_that.body);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( NotificationMeta meta,  String linkedTaskId,  int suggestionCount,  String title,  String body)?  taskSuggestion,TResult? Function( NotificationMeta meta,  String linkedTaskId,  String title,  String body)?  taskOverdue,TResult? Function( NotificationMeta meta,  String linkedRelationshipId,  String title,  String body)?  relationshipCheckIn,TResult? Function( NotificationMeta meta,  List<String> linkedHabitIds,  String dayKey,  String title,  String body)?  habitAutoCompleted,TResult? Function( NotificationMeta meta,  String linkedGoalAgentId,  String title,  String body)?  goalOffTrack,TResult? Function( NotificationMeta meta,  String dayId,  bool succeeded,  String title,  String body)?  dayPlanOutcome,TResult? Function( NotificationMeta meta,  int conflictCount,  String title,  String body)?  syncConflict,}) {final _that = this;
switch (_that) {
case TaskSuggestionNotification() when taskSuggestion != null:
return taskSuggestion(_that.meta,_that.linkedTaskId,_that.suggestionCount,_that.title,_that.body);case TaskOverdueNotification() when taskOverdue != null:
return taskOverdue(_that.meta,_that.linkedTaskId,_that.title,_that.body);case RelationshipCheckInNotification() when relationshipCheckIn != null:
return relationshipCheckIn(_that.meta,_that.linkedRelationshipId,_that.title,_that.body);case HabitAutoCompletedNotification() when habitAutoCompleted != null:
return habitAutoCompleted(_that.meta,_that.linkedHabitIds,_that.dayKey,_that.title,_that.body);case GoalOffTrackNotification() when goalOffTrack != null:
return goalOffTrack(_that.meta,_that.linkedGoalAgentId,_that.title,_that.body);case DayPlanOutcomeNotification() when dayPlanOutcome != null:
return dayPlanOutcome(_that.meta,_that.dayId,_that.succeeded,_that.title,_that.body);case SyncConflictNotification() when syncConflict != null:
return syncConflict(_that.meta,_that.conflictCount,_that.title,_that.body);case _:
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
 final  String linkedTaskId;
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
 final  String linkedTaskId;
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
@JsonSerializable()

class RelationshipCheckInNotification implements NotificationEntity {
  const RelationshipCheckInNotification({required this.meta, required this.linkedRelationshipId, required this.title, required this.body, final  String? $type}): $type = $type ?? 'relationshipCheckIn';
  factory RelationshipCheckInNotification.fromJson(Map<String, dynamic> json) => _$RelationshipCheckInNotificationFromJson(json);

@override final  NotificationMeta meta;
 final  String linkedRelationshipId;
@override final  String title;
@override final  String body;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelationshipCheckInNotificationCopyWith<RelationshipCheckInNotification> get copyWith => _$RelationshipCheckInNotificationCopyWithImpl<RelationshipCheckInNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelationshipCheckInNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelationshipCheckInNotification&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.linkedRelationshipId, linkedRelationshipId) || other.linkedRelationshipId == linkedRelationshipId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,linkedRelationshipId,title,body);

@override
String toString() {
  return 'NotificationEntity.relationshipCheckIn(meta: $meta, linkedRelationshipId: $linkedRelationshipId, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $RelationshipCheckInNotificationCopyWith<$Res> implements $NotificationEntityCopyWith<$Res> {
  factory $RelationshipCheckInNotificationCopyWith(RelationshipCheckInNotification value, $Res Function(RelationshipCheckInNotification) _then) = _$RelationshipCheckInNotificationCopyWithImpl;
@override @useResult
$Res call({
 NotificationMeta meta, String linkedRelationshipId, String title, String body
});


@override $NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$RelationshipCheckInNotificationCopyWithImpl<$Res>
    implements $RelationshipCheckInNotificationCopyWith<$Res> {
  _$RelationshipCheckInNotificationCopyWithImpl(this._self, this._then);

  final RelationshipCheckInNotification _self;
  final $Res Function(RelationshipCheckInNotification) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? linkedRelationshipId = null,Object? title = null,Object? body = null,}) {
  return _then(RelationshipCheckInNotification(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,linkedRelationshipId: null == linkedRelationshipId ? _self.linkedRelationshipId : linkedRelationshipId // ignore: cast_nullable_to_non_nullable
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
@JsonSerializable()

class HabitAutoCompletedNotification implements NotificationEntity {
  const HabitAutoCompletedNotification({required this.meta, required final  List<String> linkedHabitIds, required this.dayKey, required this.title, required this.body, final  String? $type}): _linkedHabitIds = linkedHabitIds,$type = $type ?? 'habitAutoCompleted';
  factory HabitAutoCompletedNotification.fromJson(Map<String, dynamic> json) => _$HabitAutoCompletedNotificationFromJson(json);

@override final  NotificationMeta meta;
 final  List<String> _linkedHabitIds;
 List<String> get linkedHabitIds {
  if (_linkedHabitIds is EqualUnmodifiableListView) return _linkedHabitIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_linkedHabitIds);
}

 final  String dayKey;
@override final  String title;
@override final  String body;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HabitAutoCompletedNotificationCopyWith<HabitAutoCompletedNotification> get copyWith => _$HabitAutoCompletedNotificationCopyWithImpl<HabitAutoCompletedNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HabitAutoCompletedNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HabitAutoCompletedNotification&&(identical(other.meta, meta) || other.meta == meta)&&const DeepCollectionEquality().equals(other._linkedHabitIds, _linkedHabitIds)&&(identical(other.dayKey, dayKey) || other.dayKey == dayKey)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,const DeepCollectionEquality().hash(_linkedHabitIds),dayKey,title,body);

@override
String toString() {
  return 'NotificationEntity.habitAutoCompleted(meta: $meta, linkedHabitIds: $linkedHabitIds, dayKey: $dayKey, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $HabitAutoCompletedNotificationCopyWith<$Res> implements $NotificationEntityCopyWith<$Res> {
  factory $HabitAutoCompletedNotificationCopyWith(HabitAutoCompletedNotification value, $Res Function(HabitAutoCompletedNotification) _then) = _$HabitAutoCompletedNotificationCopyWithImpl;
@override @useResult
$Res call({
 NotificationMeta meta, List<String> linkedHabitIds, String dayKey, String title, String body
});


@override $NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$HabitAutoCompletedNotificationCopyWithImpl<$Res>
    implements $HabitAutoCompletedNotificationCopyWith<$Res> {
  _$HabitAutoCompletedNotificationCopyWithImpl(this._self, this._then);

  final HabitAutoCompletedNotification _self;
  final $Res Function(HabitAutoCompletedNotification) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? linkedHabitIds = null,Object? dayKey = null,Object? title = null,Object? body = null,}) {
  return _then(HabitAutoCompletedNotification(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,linkedHabitIds: null == linkedHabitIds ? _self._linkedHabitIds : linkedHabitIds // ignore: cast_nullable_to_non_nullable
as List<String>,dayKey: null == dayKey ? _self.dayKey : dayKey // ignore: cast_nullable_to_non_nullable
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
@JsonSerializable()

class GoalOffTrackNotification implements NotificationEntity {
  const GoalOffTrackNotification({required this.meta, required this.linkedGoalAgentId, required this.title, required this.body, final  String? $type}): $type = $type ?? 'goalOffTrack';
  factory GoalOffTrackNotification.fromJson(Map<String, dynamic> json) => _$GoalOffTrackNotificationFromJson(json);

@override final  NotificationMeta meta;
 final  String linkedGoalAgentId;
@override final  String title;
@override final  String body;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalOffTrackNotificationCopyWith<GoalOffTrackNotification> get copyWith => _$GoalOffTrackNotificationCopyWithImpl<GoalOffTrackNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalOffTrackNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalOffTrackNotification&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.linkedGoalAgentId, linkedGoalAgentId) || other.linkedGoalAgentId == linkedGoalAgentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,linkedGoalAgentId,title,body);

@override
String toString() {
  return 'NotificationEntity.goalOffTrack(meta: $meta, linkedGoalAgentId: $linkedGoalAgentId, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $GoalOffTrackNotificationCopyWith<$Res> implements $NotificationEntityCopyWith<$Res> {
  factory $GoalOffTrackNotificationCopyWith(GoalOffTrackNotification value, $Res Function(GoalOffTrackNotification) _then) = _$GoalOffTrackNotificationCopyWithImpl;
@override @useResult
$Res call({
 NotificationMeta meta, String linkedGoalAgentId, String title, String body
});


@override $NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$GoalOffTrackNotificationCopyWithImpl<$Res>
    implements $GoalOffTrackNotificationCopyWith<$Res> {
  _$GoalOffTrackNotificationCopyWithImpl(this._self, this._then);

  final GoalOffTrackNotification _self;
  final $Res Function(GoalOffTrackNotification) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? linkedGoalAgentId = null,Object? title = null,Object? body = null,}) {
  return _then(GoalOffTrackNotification(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,linkedGoalAgentId: null == linkedGoalAgentId ? _self.linkedGoalAgentId : linkedGoalAgentId // ignore: cast_nullable_to_non_nullable
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
@JsonSerializable()

class DayPlanOutcomeNotification implements NotificationEntity {
  const DayPlanOutcomeNotification({required this.meta, required this.dayId, required this.succeeded, required this.title, required this.body, final  String? $type}): $type = $type ?? 'dayPlanOutcome';
  factory DayPlanOutcomeNotification.fromJson(Map<String, dynamic> json) => _$DayPlanOutcomeNotificationFromJson(json);

@override final  NotificationMeta meta;
 final  String dayId;
 final  bool succeeded;
@override final  String title;
@override final  String body;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayPlanOutcomeNotificationCopyWith<DayPlanOutcomeNotification> get copyWith => _$DayPlanOutcomeNotificationCopyWithImpl<DayPlanOutcomeNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DayPlanOutcomeNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DayPlanOutcomeNotification&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.succeeded, succeeded) || other.succeeded == succeeded)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,dayId,succeeded,title,body);

@override
String toString() {
  return 'NotificationEntity.dayPlanOutcome(meta: $meta, dayId: $dayId, succeeded: $succeeded, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $DayPlanOutcomeNotificationCopyWith<$Res> implements $NotificationEntityCopyWith<$Res> {
  factory $DayPlanOutcomeNotificationCopyWith(DayPlanOutcomeNotification value, $Res Function(DayPlanOutcomeNotification) _then) = _$DayPlanOutcomeNotificationCopyWithImpl;
@override @useResult
$Res call({
 NotificationMeta meta, String dayId, bool succeeded, String title, String body
});


@override $NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$DayPlanOutcomeNotificationCopyWithImpl<$Res>
    implements $DayPlanOutcomeNotificationCopyWith<$Res> {
  _$DayPlanOutcomeNotificationCopyWithImpl(this._self, this._then);

  final DayPlanOutcomeNotification _self;
  final $Res Function(DayPlanOutcomeNotification) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? dayId = null,Object? succeeded = null,Object? title = null,Object? body = null,}) {
  return _then(DayPlanOutcomeNotification(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,dayId: null == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String,succeeded: null == succeeded ? _self.succeeded : succeeded // ignore: cast_nullable_to_non_nullable
as bool,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
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

class SyncConflictNotification implements NotificationEntity {
  const SyncConflictNotification({required this.meta, required this.conflictCount, required this.title, required this.body, final  String? $type}): $type = $type ?? 'syncConflict';
  factory SyncConflictNotification.fromJson(Map<String, dynamic> json) => _$SyncConflictNotificationFromJson(json);

@override final  NotificationMeta meta;
 final  int conflictCount;
@override final  String title;
@override final  String body;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncConflictNotificationCopyWith<SyncConflictNotification> get copyWith => _$SyncConflictNotificationCopyWithImpl<SyncConflictNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncConflictNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncConflictNotification&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.conflictCount, conflictCount) || other.conflictCount == conflictCount)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta,conflictCount,title,body);

@override
String toString() {
  return 'NotificationEntity.syncConflict(meta: $meta, conflictCount: $conflictCount, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $SyncConflictNotificationCopyWith<$Res> implements $NotificationEntityCopyWith<$Res> {
  factory $SyncConflictNotificationCopyWith(SyncConflictNotification value, $Res Function(SyncConflictNotification) _then) = _$SyncConflictNotificationCopyWithImpl;
@override @useResult
$Res call({
 NotificationMeta meta, int conflictCount, String title, String body
});


@override $NotificationMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$SyncConflictNotificationCopyWithImpl<$Res>
    implements $SyncConflictNotificationCopyWith<$Res> {
  _$SyncConflictNotificationCopyWithImpl(this._self, this._then);

  final SyncConflictNotification _self;
  final $Res Function(SyncConflictNotification) _then;

/// Create a copy of NotificationEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? conflictCount = null,Object? title = null,Object? body = null,}) {
  return _then(SyncConflictNotification(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as NotificationMeta,conflictCount: null == conflictCount ? _self.conflictCount : conflictCount // ignore: cast_nullable_to_non_nullable
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
