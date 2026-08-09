// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BackfillRequestEntry {

/// The host UUID that originated the missing entry
 String get hostId;/// The monotonic counter for that host
 int get counter;
/// Create a copy of BackfillRequestEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BackfillRequestEntryCopyWith<BackfillRequestEntry> get copyWith => _$BackfillRequestEntryCopyWithImpl<BackfillRequestEntry>(this as BackfillRequestEntry, _$identity);

  /// Serializes this BackfillRequestEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BackfillRequestEntry&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.counter, counter) || other.counter == counter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hostId,counter);

@override
String toString() {
  return 'BackfillRequestEntry(hostId: $hostId, counter: $counter)';
}


}

/// @nodoc
abstract mixin class $BackfillRequestEntryCopyWith<$Res>  {
  factory $BackfillRequestEntryCopyWith(BackfillRequestEntry value, $Res Function(BackfillRequestEntry) _then) = _$BackfillRequestEntryCopyWithImpl;
@useResult
$Res call({
 String hostId, int counter
});




}
/// @nodoc
class _$BackfillRequestEntryCopyWithImpl<$Res>
    implements $BackfillRequestEntryCopyWith<$Res> {
  _$BackfillRequestEntryCopyWithImpl(this._self, this._then);

  final BackfillRequestEntry _self;
  final $Res Function(BackfillRequestEntry) _then;

/// Create a copy of BackfillRequestEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostId = null,Object? counter = null,}) {
  return _then(_self.copyWith(
hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,counter: null == counter ? _self.counter : counter // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BackfillRequestEntry].
extension BackfillRequestEntryPatterns on BackfillRequestEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BackfillRequestEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BackfillRequestEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BackfillRequestEntry value)  $default,){
final _that = this;
switch (_that) {
case _BackfillRequestEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BackfillRequestEntry value)?  $default,){
final _that = this;
switch (_that) {
case _BackfillRequestEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hostId,  int counter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BackfillRequestEntry() when $default != null:
return $default(_that.hostId,_that.counter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hostId,  int counter)  $default,) {final _that = this;
switch (_that) {
case _BackfillRequestEntry():
return $default(_that.hostId,_that.counter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hostId,  int counter)?  $default,) {final _that = this;
switch (_that) {
case _BackfillRequestEntry() when $default != null:
return $default(_that.hostId,_that.counter);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BackfillRequestEntry implements BackfillRequestEntry {
  const _BackfillRequestEntry({required this.hostId, required this.counter});
  factory _BackfillRequestEntry.fromJson(Map<String, dynamic> json) => _$BackfillRequestEntryFromJson(json);

/// The host UUID that originated the missing entry
@override final  String hostId;
/// The monotonic counter for that host
@override final  int counter;

/// Create a copy of BackfillRequestEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BackfillRequestEntryCopyWith<_BackfillRequestEntry> get copyWith => __$BackfillRequestEntryCopyWithImpl<_BackfillRequestEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BackfillRequestEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BackfillRequestEntry&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.counter, counter) || other.counter == counter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hostId,counter);

@override
String toString() {
  return 'BackfillRequestEntry(hostId: $hostId, counter: $counter)';
}


}

/// @nodoc
abstract mixin class _$BackfillRequestEntryCopyWith<$Res> implements $BackfillRequestEntryCopyWith<$Res> {
  factory _$BackfillRequestEntryCopyWith(_BackfillRequestEntry value, $Res Function(_BackfillRequestEntry) _then) = __$BackfillRequestEntryCopyWithImpl;
@override @useResult
$Res call({
 String hostId, int counter
});




}
/// @nodoc
class __$BackfillRequestEntryCopyWithImpl<$Res>
    implements _$BackfillRequestEntryCopyWith<$Res> {
  __$BackfillRequestEntryCopyWithImpl(this._self, this._then);

  final _BackfillRequestEntry _self;
  final $Res Function(_BackfillRequestEntry) _then;

/// Create a copy of BackfillRequestEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostId = null,Object? counter = null,}) {
  return _then(_BackfillRequestEntry(
hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,counter: null == counter ? _self.counter : counter // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SyncCounterRange {

 int get start; int get end;
/// Create a copy of SyncCounterRange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncCounterRangeCopyWith<SyncCounterRange> get copyWith => _$SyncCounterRangeCopyWithImpl<SyncCounterRange>(this as SyncCounterRange, _$identity);

  /// Serializes this SyncCounterRange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncCounterRange&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,start,end);

@override
String toString() {
  return 'SyncCounterRange(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class $SyncCounterRangeCopyWith<$Res>  {
  factory $SyncCounterRangeCopyWith(SyncCounterRange value, $Res Function(SyncCounterRange) _then) = _$SyncCounterRangeCopyWithImpl;
@useResult
$Res call({
 int start, int end
});




}
/// @nodoc
class _$SyncCounterRangeCopyWithImpl<$Res>
    implements $SyncCounterRangeCopyWith<$Res> {
  _$SyncCounterRangeCopyWithImpl(this._self, this._then);

  final SyncCounterRange _self;
  final $Res Function(SyncCounterRange) _then;

/// Create a copy of SyncCounterRange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = null,Object? end = null,}) {
  return _then(_self.copyWith(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncCounterRange].
extension SyncCounterRangePatterns on SyncCounterRange {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncCounterRange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncCounterRange() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncCounterRange value)  $default,){
final _that = this;
switch (_that) {
case _SyncCounterRange():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncCounterRange value)?  $default,){
final _that = this;
switch (_that) {
case _SyncCounterRange() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int start,  int end)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncCounterRange() when $default != null:
return $default(_that.start,_that.end);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int start,  int end)  $default,) {final _that = this;
switch (_that) {
case _SyncCounterRange():
return $default(_that.start,_that.end);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int start,  int end)?  $default,) {final _that = this;
switch (_that) {
case _SyncCounterRange() when $default != null:
return $default(_that.start,_that.end);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncCounterRange implements SyncCounterRange {
  const _SyncCounterRange({required this.start, required this.end});
  factory _SyncCounterRange.fromJson(Map<String, dynamic> json) => _$SyncCounterRangeFromJson(json);

@override final  int start;
@override final  int end;

/// Create a copy of SyncCounterRange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncCounterRangeCopyWith<_SyncCounterRange> get copyWith => __$SyncCounterRangeCopyWithImpl<_SyncCounterRange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncCounterRangeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncCounterRange&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,start,end);

@override
String toString() {
  return 'SyncCounterRange(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$SyncCounterRangeCopyWith<$Res> implements $SyncCounterRangeCopyWith<$Res> {
  factory _$SyncCounterRangeCopyWith(_SyncCounterRange value, $Res Function(_SyncCounterRange) _then) = __$SyncCounterRangeCopyWithImpl;
@override @useResult
$Res call({
 int start, int end
});




}
/// @nodoc
class __$SyncCounterRangeCopyWithImpl<$Res>
    implements _$SyncCounterRangeCopyWith<$Res> {
  __$SyncCounterRangeCopyWithImpl(this._self, this._then);

  final _SyncCounterRange _self;
  final $Res Function(_SyncCounterRange) _then;

/// Create a copy of SyncCounterRange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = null,Object? end = null,}) {
  return _then(_SyncCounterRange(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as int,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

SyncMessage _$SyncMessageFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'journalEntity':
          return SyncJournalEntity.fromJson(
            json
          );
                case 'entityDefinition':
          return SyncEntityDefinition.fromJson(
            json
          );
                case 'entryLink':
          return SyncEntryLink.fromJson(
            json
          );
                case 'aiConfig':
          return SyncAiConfig.fromJson(
            json
          );
                case 'syncNodeProfile':
          return SyncSyncNodeProfile.fromJson(
            json
          );
                case 'aiConfigDelete':
          return SyncAiConfigDelete.fromJson(
            json
          );
                case 'savedTaskFilter':
          return SyncSavedTaskFilter.fromJson(
            json
          );
                case 'savedTaskFilterDelete':
          return SyncSavedTaskFilterDelete.fromJson(
            json
          );
                case 'configFlag':
          return SyncConfigFlag.fromJson(
            json
          );
                case 'themingSelection':
          return SyncThemingSelection.fromJson(
            json
          );
                case 'dailyOsUserName':
          return SyncDailyOsUserName.fromJson(
            json
          );
                case 'notification':
          return SyncNotification.fromJson(
            json
          );
                case 'notificationStateUpdate':
          return SyncNotificationStateUpdate.fromJson(
            json
          );
                case 'onboardingSnapshotBegin':
          return SyncOnboardingSnapshotBegin.fromJson(
            json
          );
                case 'onboardingSnapshotAccepted':
          return SyncOnboardingSnapshotAccepted.fromJson(
            json
          );
                case 'onboardingTerminalCounters':
          return SyncOnboardingTerminalCounters.fromJson(
            json
          );
                case 'onboardingSnapshotEnd':
          return SyncOnboardingSnapshotEnd.fromJson(
            json
          );
                case 'backfillRequest':
          return SyncBackfillRequest.fromJson(
            json
          );
                case 'backfillResponse':
          return SyncBackfillResponse.fromJson(
            json
          );
                case 'mediaRequest':
          return SyncMediaRequest.fromJson(
            json
          );
                case 'agentEntity':
          return SyncAgentEntity.fromJson(
            json
          );
                case 'agentLink':
          return SyncAgentLink.fromJson(
            json
          );
                case 'consumptionEvent':
          return SyncConsumptionEvent.fromJson(
            json
          );
                case 'agentBundle':
          return SyncAgentBundle.fromJson(
            json
          );
                case 'outboxBundle':
          return SyncOutboxBundle.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'SyncMessage',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$SyncMessage {



  /// Serializes this SyncMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncMessage);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SyncMessage()';
}


}

/// @nodoc
class $SyncMessageCopyWith<$Res>  {
$SyncMessageCopyWith(SyncMessage _, $Res Function(SyncMessage) __);
}


/// Adds pattern-matching-related methods to [SyncMessage].
extension SyncMessagePatterns on SyncMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SyncJournalEntity value)?  journalEntity,TResult Function( SyncEntityDefinition value)?  entityDefinition,TResult Function( SyncEntryLink value)?  entryLink,TResult Function( SyncAiConfig value)?  aiConfig,TResult Function( SyncSyncNodeProfile value)?  syncNodeProfile,TResult Function( SyncAiConfigDelete value)?  aiConfigDelete,TResult Function( SyncSavedTaskFilter value)?  savedTaskFilter,TResult Function( SyncSavedTaskFilterDelete value)?  savedTaskFilterDelete,TResult Function( SyncConfigFlag value)?  configFlag,TResult Function( SyncThemingSelection value)?  themingSelection,TResult Function( SyncDailyOsUserName value)?  dailyOsUserName,TResult Function( SyncNotification value)?  notification,TResult Function( SyncNotificationStateUpdate value)?  notificationStateUpdate,TResult Function( SyncOnboardingSnapshotBegin value)?  onboardingSnapshotBegin,TResult Function( SyncOnboardingSnapshotAccepted value)?  onboardingSnapshotAccepted,TResult Function( SyncOnboardingTerminalCounters value)?  onboardingTerminalCounters,TResult Function( SyncOnboardingSnapshotEnd value)?  onboardingSnapshotEnd,TResult Function( SyncBackfillRequest value)?  backfillRequest,TResult Function( SyncBackfillResponse value)?  backfillResponse,TResult Function( SyncMediaRequest value)?  mediaRequest,TResult Function( SyncAgentEntity value)?  agentEntity,TResult Function( SyncAgentLink value)?  agentLink,TResult Function( SyncConsumptionEvent value)?  consumptionEvent,TResult Function( SyncAgentBundle value)?  agentBundle,TResult Function( SyncOutboxBundle value)?  outboxBundle,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SyncJournalEntity() when journalEntity != null:
return journalEntity(_that);case SyncEntityDefinition() when entityDefinition != null:
return entityDefinition(_that);case SyncEntryLink() when entryLink != null:
return entryLink(_that);case SyncAiConfig() when aiConfig != null:
return aiConfig(_that);case SyncSyncNodeProfile() when syncNodeProfile != null:
return syncNodeProfile(_that);case SyncAiConfigDelete() when aiConfigDelete != null:
return aiConfigDelete(_that);case SyncSavedTaskFilter() when savedTaskFilter != null:
return savedTaskFilter(_that);case SyncSavedTaskFilterDelete() when savedTaskFilterDelete != null:
return savedTaskFilterDelete(_that);case SyncConfigFlag() when configFlag != null:
return configFlag(_that);case SyncThemingSelection() when themingSelection != null:
return themingSelection(_that);case SyncDailyOsUserName() when dailyOsUserName != null:
return dailyOsUserName(_that);case SyncNotification() when notification != null:
return notification(_that);case SyncNotificationStateUpdate() when notificationStateUpdate != null:
return notificationStateUpdate(_that);case SyncOnboardingSnapshotBegin() when onboardingSnapshotBegin != null:
return onboardingSnapshotBegin(_that);case SyncOnboardingSnapshotAccepted() when onboardingSnapshotAccepted != null:
return onboardingSnapshotAccepted(_that);case SyncOnboardingTerminalCounters() when onboardingTerminalCounters != null:
return onboardingTerminalCounters(_that);case SyncOnboardingSnapshotEnd() when onboardingSnapshotEnd != null:
return onboardingSnapshotEnd(_that);case SyncBackfillRequest() when backfillRequest != null:
return backfillRequest(_that);case SyncBackfillResponse() when backfillResponse != null:
return backfillResponse(_that);case SyncMediaRequest() when mediaRequest != null:
return mediaRequest(_that);case SyncAgentEntity() when agentEntity != null:
return agentEntity(_that);case SyncAgentLink() when agentLink != null:
return agentLink(_that);case SyncConsumptionEvent() when consumptionEvent != null:
return consumptionEvent(_that);case SyncAgentBundle() when agentBundle != null:
return agentBundle(_that);case SyncOutboxBundle() when outboxBundle != null:
return outboxBundle(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SyncJournalEntity value)  journalEntity,required TResult Function( SyncEntityDefinition value)  entityDefinition,required TResult Function( SyncEntryLink value)  entryLink,required TResult Function( SyncAiConfig value)  aiConfig,required TResult Function( SyncSyncNodeProfile value)  syncNodeProfile,required TResult Function( SyncAiConfigDelete value)  aiConfigDelete,required TResult Function( SyncSavedTaskFilter value)  savedTaskFilter,required TResult Function( SyncSavedTaskFilterDelete value)  savedTaskFilterDelete,required TResult Function( SyncConfigFlag value)  configFlag,required TResult Function( SyncThemingSelection value)  themingSelection,required TResult Function( SyncDailyOsUserName value)  dailyOsUserName,required TResult Function( SyncNotification value)  notification,required TResult Function( SyncNotificationStateUpdate value)  notificationStateUpdate,required TResult Function( SyncOnboardingSnapshotBegin value)  onboardingSnapshotBegin,required TResult Function( SyncOnboardingSnapshotAccepted value)  onboardingSnapshotAccepted,required TResult Function( SyncOnboardingTerminalCounters value)  onboardingTerminalCounters,required TResult Function( SyncOnboardingSnapshotEnd value)  onboardingSnapshotEnd,required TResult Function( SyncBackfillRequest value)  backfillRequest,required TResult Function( SyncBackfillResponse value)  backfillResponse,required TResult Function( SyncMediaRequest value)  mediaRequest,required TResult Function( SyncAgentEntity value)  agentEntity,required TResult Function( SyncAgentLink value)  agentLink,required TResult Function( SyncConsumptionEvent value)  consumptionEvent,required TResult Function( SyncAgentBundle value)  agentBundle,required TResult Function( SyncOutboxBundle value)  outboxBundle,}){
final _that = this;
switch (_that) {
case SyncJournalEntity():
return journalEntity(_that);case SyncEntityDefinition():
return entityDefinition(_that);case SyncEntryLink():
return entryLink(_that);case SyncAiConfig():
return aiConfig(_that);case SyncSyncNodeProfile():
return syncNodeProfile(_that);case SyncAiConfigDelete():
return aiConfigDelete(_that);case SyncSavedTaskFilter():
return savedTaskFilter(_that);case SyncSavedTaskFilterDelete():
return savedTaskFilterDelete(_that);case SyncConfigFlag():
return configFlag(_that);case SyncThemingSelection():
return themingSelection(_that);case SyncDailyOsUserName():
return dailyOsUserName(_that);case SyncNotification():
return notification(_that);case SyncNotificationStateUpdate():
return notificationStateUpdate(_that);case SyncOnboardingSnapshotBegin():
return onboardingSnapshotBegin(_that);case SyncOnboardingSnapshotAccepted():
return onboardingSnapshotAccepted(_that);case SyncOnboardingTerminalCounters():
return onboardingTerminalCounters(_that);case SyncOnboardingSnapshotEnd():
return onboardingSnapshotEnd(_that);case SyncBackfillRequest():
return backfillRequest(_that);case SyncBackfillResponse():
return backfillResponse(_that);case SyncMediaRequest():
return mediaRequest(_that);case SyncAgentEntity():
return agentEntity(_that);case SyncAgentLink():
return agentLink(_that);case SyncConsumptionEvent():
return consumptionEvent(_that);case SyncAgentBundle():
return agentBundle(_that);case SyncOutboxBundle():
return outboxBundle(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SyncJournalEntity value)?  journalEntity,TResult? Function( SyncEntityDefinition value)?  entityDefinition,TResult? Function( SyncEntryLink value)?  entryLink,TResult? Function( SyncAiConfig value)?  aiConfig,TResult? Function( SyncSyncNodeProfile value)?  syncNodeProfile,TResult? Function( SyncAiConfigDelete value)?  aiConfigDelete,TResult? Function( SyncSavedTaskFilter value)?  savedTaskFilter,TResult? Function( SyncSavedTaskFilterDelete value)?  savedTaskFilterDelete,TResult? Function( SyncConfigFlag value)?  configFlag,TResult? Function( SyncThemingSelection value)?  themingSelection,TResult? Function( SyncDailyOsUserName value)?  dailyOsUserName,TResult? Function( SyncNotification value)?  notification,TResult? Function( SyncNotificationStateUpdate value)?  notificationStateUpdate,TResult? Function( SyncOnboardingSnapshotBegin value)?  onboardingSnapshotBegin,TResult? Function( SyncOnboardingSnapshotAccepted value)?  onboardingSnapshotAccepted,TResult? Function( SyncOnboardingTerminalCounters value)?  onboardingTerminalCounters,TResult? Function( SyncOnboardingSnapshotEnd value)?  onboardingSnapshotEnd,TResult? Function( SyncBackfillRequest value)?  backfillRequest,TResult? Function( SyncBackfillResponse value)?  backfillResponse,TResult? Function( SyncMediaRequest value)?  mediaRequest,TResult? Function( SyncAgentEntity value)?  agentEntity,TResult? Function( SyncAgentLink value)?  agentLink,TResult? Function( SyncConsumptionEvent value)?  consumptionEvent,TResult? Function( SyncAgentBundle value)?  agentBundle,TResult? Function( SyncOutboxBundle value)?  outboxBundle,}){
final _that = this;
switch (_that) {
case SyncJournalEntity() when journalEntity != null:
return journalEntity(_that);case SyncEntityDefinition() when entityDefinition != null:
return entityDefinition(_that);case SyncEntryLink() when entryLink != null:
return entryLink(_that);case SyncAiConfig() when aiConfig != null:
return aiConfig(_that);case SyncSyncNodeProfile() when syncNodeProfile != null:
return syncNodeProfile(_that);case SyncAiConfigDelete() when aiConfigDelete != null:
return aiConfigDelete(_that);case SyncSavedTaskFilter() when savedTaskFilter != null:
return savedTaskFilter(_that);case SyncSavedTaskFilterDelete() when savedTaskFilterDelete != null:
return savedTaskFilterDelete(_that);case SyncConfigFlag() when configFlag != null:
return configFlag(_that);case SyncThemingSelection() when themingSelection != null:
return themingSelection(_that);case SyncDailyOsUserName() when dailyOsUserName != null:
return dailyOsUserName(_that);case SyncNotification() when notification != null:
return notification(_that);case SyncNotificationStateUpdate() when notificationStateUpdate != null:
return notificationStateUpdate(_that);case SyncOnboardingSnapshotBegin() when onboardingSnapshotBegin != null:
return onboardingSnapshotBegin(_that);case SyncOnboardingSnapshotAccepted() when onboardingSnapshotAccepted != null:
return onboardingSnapshotAccepted(_that);case SyncOnboardingTerminalCounters() when onboardingTerminalCounters != null:
return onboardingTerminalCounters(_that);case SyncOnboardingSnapshotEnd() when onboardingSnapshotEnd != null:
return onboardingSnapshotEnd(_that);case SyncBackfillRequest() when backfillRequest != null:
return backfillRequest(_that);case SyncBackfillResponse() when backfillResponse != null:
return backfillResponse(_that);case SyncMediaRequest() when mediaRequest != null:
return mediaRequest(_that);case SyncAgentEntity() when agentEntity != null:
return agentEntity(_that);case SyncAgentLink() when agentLink != null:
return agentLink(_that);case SyncConsumptionEvent() when consumptionEvent != null:
return consumptionEvent(_that);case SyncAgentBundle() when agentBundle != null:
return agentBundle(_that);case SyncOutboxBundle() when outboxBundle != null:
return outboxBundle(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String jsonPath,  VectorClock? vectorClock,  SyncEntryStatus status,  String? attachmentEventId,  List<EntryLink>? entryLinks,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks,  bool? includeAttachments)?  journalEntity,TResult Function( EntityDefinition entityDefinition,  SyncEntryStatus status)?  entityDefinition,TResult Function( EntryLink entryLink,  SyncEntryStatus status,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  entryLink,TResult Function( AiConfig aiConfig,  SyncEntryStatus status)?  aiConfig,TResult Function( SyncNodeProfile profile)?  syncNodeProfile,TResult Function( String id,  bool? hardDelete)?  aiConfigDelete,TResult Function( SavedTaskFilter filter,  SyncEntryStatus status)?  savedTaskFilter,TResult Function( String id)?  savedTaskFilterDelete,TResult Function( String name,  String description,  bool status,  String? originatingHostId)?  configFlag,TResult Function( String lightThemeName,  String darkThemeName,  String themeMode,  int updatedAt,  SyncEntryStatus status)?  themingSelection,TResult Function( String userName,  int updatedAt,  SyncEntryStatus status)?  dailyOsUserName,TResult Function( String id,  String jsonPath,  VectorClock vectorClock,  String originatingHostId,  String? attachmentEventId,  List<VectorClock>? coveredVectorClocks)?  notification,TResult Function( String id,  VectorClock vectorClock,  String originatingHostId,  DateTime? seenAt,  DateTime? actedOnAt,  DateTime? deletedAt)?  notificationStateUpdate,TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String senderUserId,  String senderDeviceId,  String recipientUserId,  String recipientDeviceId,  Map<String, int> coverageUpperBounds,  int leaseSeconds)?  onboardingSnapshotBegin,TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String senderUserId,  String senderDeviceId,  String recipientHostId,  String recipientDeviceId)?  onboardingSnapshotAccepted,TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String recipientUserId,  String recipientDeviceId,  List<SyncCounterRange> ranges)?  onboardingTerminalCounters,TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String recipientUserId,  String recipientDeviceId,  OnboardingSyncEndReason reason)?  onboardingSnapshotEnd,TResult Function( List<BackfillRequestEntry> entries,  String requesterId)?  backfillRequest,TResult Function( String hostId,  int counter,  bool deleted,  bool? unresolvable,  String? entryId,  SyncSequencePayloadType? payloadType,  String? payloadId)?  backfillResponse,TResult Function( List<String> entryIds,  String requesterId)?  mediaRequest,TResult Function( SyncEntryStatus status, @JsonKey(toJson: _agentDomainEntityToJson)  AgentDomainEntity? agentEntity,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  agentEntity,TResult Function( SyncEntryStatus status,  AgentLink? agentLink,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  agentLink,TResult Function( AiConsumptionEvent event,  SyncEntryStatus status,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  consumptionEvent,TResult Function( String agentId,  String wakeRunKey,  List<SyncAgentEntity> entities,  List<SyncAgentLink> links,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId)?  agentBundle,TResult Function( List<SyncMessage> children,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId)?  outboxBundle,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SyncJournalEntity() when journalEntity != null:
return journalEntity(_that.id,_that.jsonPath,_that.vectorClock,_that.status,_that.attachmentEventId,_that.entryLinks,_that.originatingHostId,_that.coveredVectorClocks,_that.includeAttachments);case SyncEntityDefinition() when entityDefinition != null:
return entityDefinition(_that.entityDefinition,_that.status);case SyncEntryLink() when entryLink != null:
return entryLink(_that.entryLink,_that.status,_that.originatingHostId,_that.coveredVectorClocks);case SyncAiConfig() when aiConfig != null:
return aiConfig(_that.aiConfig,_that.status);case SyncSyncNodeProfile() when syncNodeProfile != null:
return syncNodeProfile(_that.profile);case SyncAiConfigDelete() when aiConfigDelete != null:
return aiConfigDelete(_that.id,_that.hardDelete);case SyncSavedTaskFilter() when savedTaskFilter != null:
return savedTaskFilter(_that.filter,_that.status);case SyncSavedTaskFilterDelete() when savedTaskFilterDelete != null:
return savedTaskFilterDelete(_that.id);case SyncConfigFlag() when configFlag != null:
return configFlag(_that.name,_that.description,_that.status,_that.originatingHostId);case SyncThemingSelection() when themingSelection != null:
return themingSelection(_that.lightThemeName,_that.darkThemeName,_that.themeMode,_that.updatedAt,_that.status);case SyncDailyOsUserName() when dailyOsUserName != null:
return dailyOsUserName(_that.userName,_that.updatedAt,_that.status);case SyncNotification() when notification != null:
return notification(_that.id,_that.jsonPath,_that.vectorClock,_that.originatingHostId,_that.attachmentEventId,_that.coveredVectorClocks);case SyncNotificationStateUpdate() when notificationStateUpdate != null:
return notificationStateUpdate(_that.id,_that.vectorClock,_that.originatingHostId,_that.seenAt,_that.actedOnAt,_that.deletedAt);case SyncOnboardingSnapshotBegin() when onboardingSnapshotBegin != null:
return onboardingSnapshotBegin(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.senderUserId,_that.senderDeviceId,_that.recipientUserId,_that.recipientDeviceId,_that.coverageUpperBounds,_that.leaseSeconds);case SyncOnboardingSnapshotAccepted() when onboardingSnapshotAccepted != null:
return onboardingSnapshotAccepted(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.senderUserId,_that.senderDeviceId,_that.recipientHostId,_that.recipientDeviceId);case SyncOnboardingTerminalCounters() when onboardingTerminalCounters != null:
return onboardingTerminalCounters(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.recipientUserId,_that.recipientDeviceId,_that.ranges);case SyncOnboardingSnapshotEnd() when onboardingSnapshotEnd != null:
return onboardingSnapshotEnd(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.recipientUserId,_that.recipientDeviceId,_that.reason);case SyncBackfillRequest() when backfillRequest != null:
return backfillRequest(_that.entries,_that.requesterId);case SyncBackfillResponse() when backfillResponse != null:
return backfillResponse(_that.hostId,_that.counter,_that.deleted,_that.unresolvable,_that.entryId,_that.payloadType,_that.payloadId);case SyncMediaRequest() when mediaRequest != null:
return mediaRequest(_that.entryIds,_that.requesterId);case SyncAgentEntity() when agentEntity != null:
return agentEntity(_that.status,_that.agentEntity,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId,_that.coveredVectorClocks);case SyncAgentLink() when agentLink != null:
return agentLink(_that.status,_that.agentLink,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId,_that.coveredVectorClocks);case SyncConsumptionEvent() when consumptionEvent != null:
return consumptionEvent(_that.event,_that.status,_that.originatingHostId,_that.coveredVectorClocks);case SyncAgentBundle() when agentBundle != null:
return agentBundle(_that.agentId,_that.wakeRunKey,_that.entities,_that.links,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId);case SyncOutboxBundle() when outboxBundle != null:
return outboxBundle(_that.children,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String jsonPath,  VectorClock? vectorClock,  SyncEntryStatus status,  String? attachmentEventId,  List<EntryLink>? entryLinks,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks,  bool? includeAttachments)  journalEntity,required TResult Function( EntityDefinition entityDefinition,  SyncEntryStatus status)  entityDefinition,required TResult Function( EntryLink entryLink,  SyncEntryStatus status,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)  entryLink,required TResult Function( AiConfig aiConfig,  SyncEntryStatus status)  aiConfig,required TResult Function( SyncNodeProfile profile)  syncNodeProfile,required TResult Function( String id,  bool? hardDelete)  aiConfigDelete,required TResult Function( SavedTaskFilter filter,  SyncEntryStatus status)  savedTaskFilter,required TResult Function( String id)  savedTaskFilterDelete,required TResult Function( String name,  String description,  bool status,  String? originatingHostId)  configFlag,required TResult Function( String lightThemeName,  String darkThemeName,  String themeMode,  int updatedAt,  SyncEntryStatus status)  themingSelection,required TResult Function( String userName,  int updatedAt,  SyncEntryStatus status)  dailyOsUserName,required TResult Function( String id,  String jsonPath,  VectorClock vectorClock,  String originatingHostId,  String? attachmentEventId,  List<VectorClock>? coveredVectorClocks)  notification,required TResult Function( String id,  VectorClock vectorClock,  String originatingHostId,  DateTime? seenAt,  DateTime? actedOnAt,  DateTime? deletedAt)  notificationStateUpdate,required TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String senderUserId,  String senderDeviceId,  String recipientUserId,  String recipientDeviceId,  Map<String, int> coverageUpperBounds,  int leaseSeconds)  onboardingSnapshotBegin,required TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String senderUserId,  String senderDeviceId,  String recipientHostId,  String recipientDeviceId)  onboardingSnapshotAccepted,required TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String recipientUserId,  String recipientDeviceId,  List<SyncCounterRange> ranges)  onboardingTerminalCounters,required TResult Function( int protocolVersion,  String roundId,  String senderHostId,  String recipientUserId,  String recipientDeviceId,  OnboardingSyncEndReason reason)  onboardingSnapshotEnd,required TResult Function( List<BackfillRequestEntry> entries,  String requesterId)  backfillRequest,required TResult Function( String hostId,  int counter,  bool deleted,  bool? unresolvable,  String? entryId,  SyncSequencePayloadType? payloadType,  String? payloadId)  backfillResponse,required TResult Function( List<String> entryIds,  String requesterId)  mediaRequest,required TResult Function( SyncEntryStatus status, @JsonKey(toJson: _agentDomainEntityToJson)  AgentDomainEntity? agentEntity,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)  agentEntity,required TResult Function( SyncEntryStatus status,  AgentLink? agentLink,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)  agentLink,required TResult Function( AiConsumptionEvent event,  SyncEntryStatus status,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)  consumptionEvent,required TResult Function( String agentId,  String wakeRunKey,  List<SyncAgentEntity> entities,  List<SyncAgentLink> links,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId)  agentBundle,required TResult Function( List<SyncMessage> children,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId)  outboxBundle,}) {final _that = this;
switch (_that) {
case SyncJournalEntity():
return journalEntity(_that.id,_that.jsonPath,_that.vectorClock,_that.status,_that.attachmentEventId,_that.entryLinks,_that.originatingHostId,_that.coveredVectorClocks,_that.includeAttachments);case SyncEntityDefinition():
return entityDefinition(_that.entityDefinition,_that.status);case SyncEntryLink():
return entryLink(_that.entryLink,_that.status,_that.originatingHostId,_that.coveredVectorClocks);case SyncAiConfig():
return aiConfig(_that.aiConfig,_that.status);case SyncSyncNodeProfile():
return syncNodeProfile(_that.profile);case SyncAiConfigDelete():
return aiConfigDelete(_that.id,_that.hardDelete);case SyncSavedTaskFilter():
return savedTaskFilter(_that.filter,_that.status);case SyncSavedTaskFilterDelete():
return savedTaskFilterDelete(_that.id);case SyncConfigFlag():
return configFlag(_that.name,_that.description,_that.status,_that.originatingHostId);case SyncThemingSelection():
return themingSelection(_that.lightThemeName,_that.darkThemeName,_that.themeMode,_that.updatedAt,_that.status);case SyncDailyOsUserName():
return dailyOsUserName(_that.userName,_that.updatedAt,_that.status);case SyncNotification():
return notification(_that.id,_that.jsonPath,_that.vectorClock,_that.originatingHostId,_that.attachmentEventId,_that.coveredVectorClocks);case SyncNotificationStateUpdate():
return notificationStateUpdate(_that.id,_that.vectorClock,_that.originatingHostId,_that.seenAt,_that.actedOnAt,_that.deletedAt);case SyncOnboardingSnapshotBegin():
return onboardingSnapshotBegin(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.senderUserId,_that.senderDeviceId,_that.recipientUserId,_that.recipientDeviceId,_that.coverageUpperBounds,_that.leaseSeconds);case SyncOnboardingSnapshotAccepted():
return onboardingSnapshotAccepted(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.senderUserId,_that.senderDeviceId,_that.recipientHostId,_that.recipientDeviceId);case SyncOnboardingTerminalCounters():
return onboardingTerminalCounters(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.recipientUserId,_that.recipientDeviceId,_that.ranges);case SyncOnboardingSnapshotEnd():
return onboardingSnapshotEnd(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.recipientUserId,_that.recipientDeviceId,_that.reason);case SyncBackfillRequest():
return backfillRequest(_that.entries,_that.requesterId);case SyncBackfillResponse():
return backfillResponse(_that.hostId,_that.counter,_that.deleted,_that.unresolvable,_that.entryId,_that.payloadType,_that.payloadId);case SyncMediaRequest():
return mediaRequest(_that.entryIds,_that.requesterId);case SyncAgentEntity():
return agentEntity(_that.status,_that.agentEntity,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId,_that.coveredVectorClocks);case SyncAgentLink():
return agentLink(_that.status,_that.agentLink,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId,_that.coveredVectorClocks);case SyncConsumptionEvent():
return consumptionEvent(_that.event,_that.status,_that.originatingHostId,_that.coveredVectorClocks);case SyncAgentBundle():
return agentBundle(_that.agentId,_that.wakeRunKey,_that.entities,_that.links,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId);case SyncOutboxBundle():
return outboxBundle(_that.children,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String jsonPath,  VectorClock? vectorClock,  SyncEntryStatus status,  String? attachmentEventId,  List<EntryLink>? entryLinks,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks,  bool? includeAttachments)?  journalEntity,TResult? Function( EntityDefinition entityDefinition,  SyncEntryStatus status)?  entityDefinition,TResult? Function( EntryLink entryLink,  SyncEntryStatus status,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  entryLink,TResult? Function( AiConfig aiConfig,  SyncEntryStatus status)?  aiConfig,TResult? Function( SyncNodeProfile profile)?  syncNodeProfile,TResult? Function( String id,  bool? hardDelete)?  aiConfigDelete,TResult? Function( SavedTaskFilter filter,  SyncEntryStatus status)?  savedTaskFilter,TResult? Function( String id)?  savedTaskFilterDelete,TResult? Function( String name,  String description,  bool status,  String? originatingHostId)?  configFlag,TResult? Function( String lightThemeName,  String darkThemeName,  String themeMode,  int updatedAt,  SyncEntryStatus status)?  themingSelection,TResult? Function( String userName,  int updatedAt,  SyncEntryStatus status)?  dailyOsUserName,TResult? Function( String id,  String jsonPath,  VectorClock vectorClock,  String originatingHostId,  String? attachmentEventId,  List<VectorClock>? coveredVectorClocks)?  notification,TResult? Function( String id,  VectorClock vectorClock,  String originatingHostId,  DateTime? seenAt,  DateTime? actedOnAt,  DateTime? deletedAt)?  notificationStateUpdate,TResult? Function( int protocolVersion,  String roundId,  String senderHostId,  String senderUserId,  String senderDeviceId,  String recipientUserId,  String recipientDeviceId,  Map<String, int> coverageUpperBounds,  int leaseSeconds)?  onboardingSnapshotBegin,TResult? Function( int protocolVersion,  String roundId,  String senderHostId,  String senderUserId,  String senderDeviceId,  String recipientHostId,  String recipientDeviceId)?  onboardingSnapshotAccepted,TResult? Function( int protocolVersion,  String roundId,  String senderHostId,  String recipientUserId,  String recipientDeviceId,  List<SyncCounterRange> ranges)?  onboardingTerminalCounters,TResult? Function( int protocolVersion,  String roundId,  String senderHostId,  String recipientUserId,  String recipientDeviceId,  OnboardingSyncEndReason reason)?  onboardingSnapshotEnd,TResult? Function( List<BackfillRequestEntry> entries,  String requesterId)?  backfillRequest,TResult? Function( String hostId,  int counter,  bool deleted,  bool? unresolvable,  String? entryId,  SyncSequencePayloadType? payloadType,  String? payloadId)?  backfillResponse,TResult? Function( List<String> entryIds,  String requesterId)?  mediaRequest,TResult? Function( SyncEntryStatus status, @JsonKey(toJson: _agentDomainEntityToJson)  AgentDomainEntity? agentEntity,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  agentEntity,TResult? Function( SyncEntryStatus status,  AgentLink? agentLink,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  agentLink,TResult? Function( AiConsumptionEvent event,  SyncEntryStatus status,  String? originatingHostId,  List<VectorClock>? coveredVectorClocks)?  consumptionEvent,TResult? Function( String agentId,  String wakeRunKey,  List<SyncAgentEntity> entities,  List<SyncAgentLink> links,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId)?  agentBundle,TResult? Function( List<SyncMessage> children,  String? jsonPath,  String? attachmentEventId,  String? originatingHostId)?  outboxBundle,}) {final _that = this;
switch (_that) {
case SyncJournalEntity() when journalEntity != null:
return journalEntity(_that.id,_that.jsonPath,_that.vectorClock,_that.status,_that.attachmentEventId,_that.entryLinks,_that.originatingHostId,_that.coveredVectorClocks,_that.includeAttachments);case SyncEntityDefinition() when entityDefinition != null:
return entityDefinition(_that.entityDefinition,_that.status);case SyncEntryLink() when entryLink != null:
return entryLink(_that.entryLink,_that.status,_that.originatingHostId,_that.coveredVectorClocks);case SyncAiConfig() when aiConfig != null:
return aiConfig(_that.aiConfig,_that.status);case SyncSyncNodeProfile() when syncNodeProfile != null:
return syncNodeProfile(_that.profile);case SyncAiConfigDelete() when aiConfigDelete != null:
return aiConfigDelete(_that.id,_that.hardDelete);case SyncSavedTaskFilter() when savedTaskFilter != null:
return savedTaskFilter(_that.filter,_that.status);case SyncSavedTaskFilterDelete() when savedTaskFilterDelete != null:
return savedTaskFilterDelete(_that.id);case SyncConfigFlag() when configFlag != null:
return configFlag(_that.name,_that.description,_that.status,_that.originatingHostId);case SyncThemingSelection() when themingSelection != null:
return themingSelection(_that.lightThemeName,_that.darkThemeName,_that.themeMode,_that.updatedAt,_that.status);case SyncDailyOsUserName() when dailyOsUserName != null:
return dailyOsUserName(_that.userName,_that.updatedAt,_that.status);case SyncNotification() when notification != null:
return notification(_that.id,_that.jsonPath,_that.vectorClock,_that.originatingHostId,_that.attachmentEventId,_that.coveredVectorClocks);case SyncNotificationStateUpdate() when notificationStateUpdate != null:
return notificationStateUpdate(_that.id,_that.vectorClock,_that.originatingHostId,_that.seenAt,_that.actedOnAt,_that.deletedAt);case SyncOnboardingSnapshotBegin() when onboardingSnapshotBegin != null:
return onboardingSnapshotBegin(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.senderUserId,_that.senderDeviceId,_that.recipientUserId,_that.recipientDeviceId,_that.coverageUpperBounds,_that.leaseSeconds);case SyncOnboardingSnapshotAccepted() when onboardingSnapshotAccepted != null:
return onboardingSnapshotAccepted(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.senderUserId,_that.senderDeviceId,_that.recipientHostId,_that.recipientDeviceId);case SyncOnboardingTerminalCounters() when onboardingTerminalCounters != null:
return onboardingTerminalCounters(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.recipientUserId,_that.recipientDeviceId,_that.ranges);case SyncOnboardingSnapshotEnd() when onboardingSnapshotEnd != null:
return onboardingSnapshotEnd(_that.protocolVersion,_that.roundId,_that.senderHostId,_that.recipientUserId,_that.recipientDeviceId,_that.reason);case SyncBackfillRequest() when backfillRequest != null:
return backfillRequest(_that.entries,_that.requesterId);case SyncBackfillResponse() when backfillResponse != null:
return backfillResponse(_that.hostId,_that.counter,_that.deleted,_that.unresolvable,_that.entryId,_that.payloadType,_that.payloadId);case SyncMediaRequest() when mediaRequest != null:
return mediaRequest(_that.entryIds,_that.requesterId);case SyncAgentEntity() when agentEntity != null:
return agentEntity(_that.status,_that.agentEntity,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId,_that.coveredVectorClocks);case SyncAgentLink() when agentLink != null:
return agentLink(_that.status,_that.agentLink,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId,_that.coveredVectorClocks);case SyncConsumptionEvent() when consumptionEvent != null:
return consumptionEvent(_that.event,_that.status,_that.originatingHostId,_that.coveredVectorClocks);case SyncAgentBundle() when agentBundle != null:
return agentBundle(_that.agentId,_that.wakeRunKey,_that.entities,_that.links,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId);case SyncOutboxBundle() when outboxBundle != null:
return outboxBundle(_that.children,_that.jsonPath,_that.attachmentEventId,_that.originatingHostId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class SyncJournalEntity implements SyncMessage {
  const SyncJournalEntity({required this.id, required this.jsonPath, required this.vectorClock, required this.status, this.attachmentEventId, final  List<EntryLink>? entryLinks, this.originatingHostId, final  List<VectorClock>? coveredVectorClocks, this.includeAttachments, final  String? $type}): _entryLinks = entryLinks,_coveredVectorClocks = coveredVectorClocks,$type = $type ?? 'journalEntity';
  factory SyncJournalEntity.fromJson(Map<String, dynamic> json) => _$SyncJournalEntityFromJson(json);

 final  String id;
 final  String jsonPath;
 final  VectorClock? vectorClock;
 final  SyncEntryStatus status;
/// Matrix event id of the exact JSON attachment generation referenced by
/// this envelope. Null only for legacy peers that identify payloads by
/// mutable `jsonPath`.
 final  String? attachmentEventId;
 final  List<EntryLink>? _entryLinks;
 List<EntryLink>? get entryLinks {
  final value = _entryLinks;
  if (value == null) return null;
  if (_entryLinks is EqualUnmodifiableListView) return _entryLinks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// The host UUID that created/modified this entry version.
/// Used for sequence tracking to detect gaps in sync.
 final  String? originatingHostId;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries. Receivers should pre-mark
/// superseded counters as covered/received to prevent false gap detection;
/// the current vector clock is ignored for pre-marking.
 final  List<VectorClock>? _coveredVectorClocks;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries. Receivers should pre-mark
/// superseded counters as covered/received to prevent false gap detection;
/// the current vector clock is ignored for pre-marking.
 List<VectorClock>? get coveredVectorClocks {
  final value = _coveredVectorClocks;
  if (value == null) return null;
  if (_coveredVectorClocks is EqualUnmodifiableListView) return _coveredVectorClocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Forces the entry's media file (image/audio) to ride along with this
/// payload even though `status` is [SyncEntryStatus.update].
///
/// Set by the flows that re-send existing history to a peer holding none —
/// the sync-setup re-send (`maintenance.dart`) and backfill responses.
/// Those necessarily use `update` status (the entry is not new *here*),
/// but the receiving device has no blob, so JSON alone leaves it with an
/// entry it can never render. Absent (`null`) on payloads from 0.9.1103
/// and earlier, and on ordinary edits, which send JSON only.
///
/// Consumed via `shouldSendJournalAttachments` in
/// `sync_attachment_policy.dart` — never read directly, so the enqueue
/// writer and the sender cannot drift apart.
 final  bool? includeAttachments;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncJournalEntityCopyWith<SyncJournalEntity> get copyWith => _$SyncJournalEntityCopyWithImpl<SyncJournalEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncJournalEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncJournalEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.status, status) || other.status == status)&&(identical(other.attachmentEventId, attachmentEventId) || other.attachmentEventId == attachmentEventId)&&const DeepCollectionEquality().equals(other._entryLinks, _entryLinks)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&const DeepCollectionEquality().equals(other._coveredVectorClocks, _coveredVectorClocks)&&(identical(other.includeAttachments, includeAttachments) || other.includeAttachments == includeAttachments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,jsonPath,vectorClock,status,attachmentEventId,const DeepCollectionEquality().hash(_entryLinks),originatingHostId,const DeepCollectionEquality().hash(_coveredVectorClocks),includeAttachments);

@override
String toString() {
  return 'SyncMessage.journalEntity(id: $id, jsonPath: $jsonPath, vectorClock: $vectorClock, status: $status, attachmentEventId: $attachmentEventId, entryLinks: $entryLinks, originatingHostId: $originatingHostId, coveredVectorClocks: $coveredVectorClocks, includeAttachments: $includeAttachments)';
}


}

/// @nodoc
abstract mixin class $SyncJournalEntityCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncJournalEntityCopyWith(SyncJournalEntity value, $Res Function(SyncJournalEntity) _then) = _$SyncJournalEntityCopyWithImpl;
@useResult
$Res call({
 String id, String jsonPath, VectorClock? vectorClock, SyncEntryStatus status, String? attachmentEventId, List<EntryLink>? entryLinks, String? originatingHostId, List<VectorClock>? coveredVectorClocks, bool? includeAttachments
});




}
/// @nodoc
class _$SyncJournalEntityCopyWithImpl<$Res>
    implements $SyncJournalEntityCopyWith<$Res> {
  _$SyncJournalEntityCopyWithImpl(this._self, this._then);

  final SyncJournalEntity _self;
  final $Res Function(SyncJournalEntity) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? jsonPath = null,Object? vectorClock = freezed,Object? status = null,Object? attachmentEventId = freezed,Object? entryLinks = freezed,Object? originatingHostId = freezed,Object? coveredVectorClocks = freezed,Object? includeAttachments = freezed,}) {
  return _then(SyncJournalEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,jsonPath: null == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,attachmentEventId: freezed == attachmentEventId ? _self.attachmentEventId : attachmentEventId // ignore: cast_nullable_to_non_nullable
as String?,entryLinks: freezed == entryLinks ? _self._entryLinks : entryLinks // ignore: cast_nullable_to_non_nullable
as List<EntryLink>?,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,coveredVectorClocks: freezed == coveredVectorClocks ? _self._coveredVectorClocks : coveredVectorClocks // ignore: cast_nullable_to_non_nullable
as List<VectorClock>?,includeAttachments: freezed == includeAttachments ? _self.includeAttachments : includeAttachments // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncEntityDefinition implements SyncMessage {
  const SyncEntityDefinition({required this.entityDefinition, required this.status, final  String? $type}): $type = $type ?? 'entityDefinition';
  factory SyncEntityDefinition.fromJson(Map<String, dynamic> json) => _$SyncEntityDefinitionFromJson(json);

 final  EntityDefinition entityDefinition;
 final  SyncEntryStatus status;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncEntityDefinitionCopyWith<SyncEntityDefinition> get copyWith => _$SyncEntityDefinitionCopyWithImpl<SyncEntityDefinition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncEntityDefinitionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEntityDefinition&&(identical(other.entityDefinition, entityDefinition) || other.entityDefinition == entityDefinition)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,entityDefinition,status);

@override
String toString() {
  return 'SyncMessage.entityDefinition(entityDefinition: $entityDefinition, status: $status)';
}


}

/// @nodoc
abstract mixin class $SyncEntityDefinitionCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncEntityDefinitionCopyWith(SyncEntityDefinition value, $Res Function(SyncEntityDefinition) _then) = _$SyncEntityDefinitionCopyWithImpl;
@useResult
$Res call({
 EntityDefinition entityDefinition, SyncEntryStatus status
});


$EntityDefinitionCopyWith<$Res> get entityDefinition;

}
/// @nodoc
class _$SyncEntityDefinitionCopyWithImpl<$Res>
    implements $SyncEntityDefinitionCopyWith<$Res> {
  _$SyncEntityDefinitionCopyWithImpl(this._self, this._then);

  final SyncEntityDefinition _self;
  final $Res Function(SyncEntityDefinition) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entityDefinition = null,Object? status = null,}) {
  return _then(SyncEntityDefinition(
entityDefinition: null == entityDefinition ? _self.entityDefinition : entityDefinition // ignore: cast_nullable_to_non_nullable
as EntityDefinition,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EntityDefinitionCopyWith<$Res> get entityDefinition {
  
  return $EntityDefinitionCopyWith<$Res>(_self.entityDefinition, (value) {
    return _then(_self.copyWith(entityDefinition: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncEntryLink implements SyncMessage {
  const SyncEntryLink({required this.entryLink, required this.status, this.originatingHostId, final  List<VectorClock>? coveredVectorClocks, final  String? $type}): _coveredVectorClocks = coveredVectorClocks,$type = $type ?? 'entryLink';
  factory SyncEntryLink.fromJson(Map<String, dynamic> json) => _$SyncEntryLinkFromJson(json);

 final  EntryLink entryLink;
 final  SyncEntryStatus status;
/// The host UUID that created/modified this entry link version.
/// Used for sequence tracking to detect gaps in sync.
 final  String? originatingHostId;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries. Receivers should pre-mark
/// superseded counters as covered/received to prevent false gap detection;
/// the current vector clock is ignored for pre-marking.
 final  List<VectorClock>? _coveredVectorClocks;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries. Receivers should pre-mark
/// superseded counters as covered/received to prevent false gap detection;
/// the current vector clock is ignored for pre-marking.
 List<VectorClock>? get coveredVectorClocks {
  final value = _coveredVectorClocks;
  if (value == null) return null;
  if (_coveredVectorClocks is EqualUnmodifiableListView) return _coveredVectorClocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncEntryLinkCopyWith<SyncEntryLink> get copyWith => _$SyncEntryLinkCopyWithImpl<SyncEntryLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncEntryLinkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncEntryLink&&(identical(other.entryLink, entryLink) || other.entryLink == entryLink)&&(identical(other.status, status) || other.status == status)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&const DeepCollectionEquality().equals(other._coveredVectorClocks, _coveredVectorClocks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,entryLink,status,originatingHostId,const DeepCollectionEquality().hash(_coveredVectorClocks));

@override
String toString() {
  return 'SyncMessage.entryLink(entryLink: $entryLink, status: $status, originatingHostId: $originatingHostId, coveredVectorClocks: $coveredVectorClocks)';
}


}

/// @nodoc
abstract mixin class $SyncEntryLinkCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncEntryLinkCopyWith(SyncEntryLink value, $Res Function(SyncEntryLink) _then) = _$SyncEntryLinkCopyWithImpl;
@useResult
$Res call({
 EntryLink entryLink, SyncEntryStatus status, String? originatingHostId, List<VectorClock>? coveredVectorClocks
});


$EntryLinkCopyWith<$Res> get entryLink;

}
/// @nodoc
class _$SyncEntryLinkCopyWithImpl<$Res>
    implements $SyncEntryLinkCopyWith<$Res> {
  _$SyncEntryLinkCopyWithImpl(this._self, this._then);

  final SyncEntryLink _self;
  final $Res Function(SyncEntryLink) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entryLink = null,Object? status = null,Object? originatingHostId = freezed,Object? coveredVectorClocks = freezed,}) {
  return _then(SyncEntryLink(
entryLink: null == entryLink ? _self.entryLink : entryLink // ignore: cast_nullable_to_non_nullable
as EntryLink,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,coveredVectorClocks: freezed == coveredVectorClocks ? _self._coveredVectorClocks : coveredVectorClocks // ignore: cast_nullable_to_non_nullable
as List<VectorClock>?,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$EntryLinkCopyWith<$Res> get entryLink {
  
  return $EntryLinkCopyWith<$Res>(_self.entryLink, (value) {
    return _then(_self.copyWith(entryLink: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncAiConfig implements SyncMessage {
  const SyncAiConfig({required this.aiConfig, required this.status, final  String? $type}): $type = $type ?? 'aiConfig';
  factory SyncAiConfig.fromJson(Map<String, dynamic> json) => _$SyncAiConfigFromJson(json);

 final  AiConfig aiConfig;
 final  SyncEntryStatus status;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncAiConfigCopyWith<SyncAiConfig> get copyWith => _$SyncAiConfigCopyWithImpl<SyncAiConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncAiConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncAiConfig&&(identical(other.aiConfig, aiConfig) || other.aiConfig == aiConfig)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,aiConfig,status);

@override
String toString() {
  return 'SyncMessage.aiConfig(aiConfig: $aiConfig, status: $status)';
}


}

/// @nodoc
abstract mixin class $SyncAiConfigCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncAiConfigCopyWith(SyncAiConfig value, $Res Function(SyncAiConfig) _then) = _$SyncAiConfigCopyWithImpl;
@useResult
$Res call({
 AiConfig aiConfig, SyncEntryStatus status
});


$AiConfigCopyWith<$Res> get aiConfig;

}
/// @nodoc
class _$SyncAiConfigCopyWithImpl<$Res>
    implements $SyncAiConfigCopyWith<$Res> {
  _$SyncAiConfigCopyWithImpl(this._self, this._then);

  final SyncAiConfig _self;
  final $Res Function(SyncAiConfig) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? aiConfig = null,Object? status = null,}) {
  return _then(SyncAiConfig(
aiConfig: null == aiConfig ? _self.aiConfig : aiConfig // ignore: cast_nullable_to_non_nullable
as AiConfig,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiConfigCopyWith<$Res> get aiConfig {
  
  return $AiConfigCopyWith<$Res>(_self.aiConfig, (value) {
    return _then(_self.copyWith(aiConfig: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncSyncNodeProfile implements SyncMessage {
  const SyncSyncNodeProfile({required this.profile, final  String? $type}): $type = $type ?? 'syncNodeProfile';
  factory SyncSyncNodeProfile.fromJson(Map<String, dynamic> json) => _$SyncSyncNodeProfileFromJson(json);

 final  SyncNodeProfile profile;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncSyncNodeProfileCopyWith<SyncSyncNodeProfile> get copyWith => _$SyncSyncNodeProfileCopyWithImpl<SyncSyncNodeProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncSyncNodeProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncSyncNodeProfile&&(identical(other.profile, profile) || other.profile == profile));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,profile);

@override
String toString() {
  return 'SyncMessage.syncNodeProfile(profile: $profile)';
}


}

/// @nodoc
abstract mixin class $SyncSyncNodeProfileCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncSyncNodeProfileCopyWith(SyncSyncNodeProfile value, $Res Function(SyncSyncNodeProfile) _then) = _$SyncSyncNodeProfileCopyWithImpl;
@useResult
$Res call({
 SyncNodeProfile profile
});


$SyncNodeProfileCopyWith<$Res> get profile;

}
/// @nodoc
class _$SyncSyncNodeProfileCopyWithImpl<$Res>
    implements $SyncSyncNodeProfileCopyWith<$Res> {
  _$SyncSyncNodeProfileCopyWithImpl(this._self, this._then);

  final SyncSyncNodeProfile _self;
  final $Res Function(SyncSyncNodeProfile) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? profile = null,}) {
  return _then(SyncSyncNodeProfile(
profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as SyncNodeProfile,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SyncNodeProfileCopyWith<$Res> get profile {
  
  return $SyncNodeProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncAiConfigDelete implements SyncMessage {
  const SyncAiConfigDelete({required this.id, this.hardDelete, final  String? $type}): $type = $type ?? 'aiConfigDelete';
  factory SyncAiConfigDelete.fromJson(Map<String, dynamic> json) => _$SyncAiConfigDeleteFromJson(json);

 final  String id;
 final  bool? hardDelete;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncAiConfigDeleteCopyWith<SyncAiConfigDelete> get copyWith => _$SyncAiConfigDeleteCopyWithImpl<SyncAiConfigDelete>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncAiConfigDeleteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncAiConfigDelete&&(identical(other.id, id) || other.id == id)&&(identical(other.hardDelete, hardDelete) || other.hardDelete == hardDelete));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,hardDelete);

@override
String toString() {
  return 'SyncMessage.aiConfigDelete(id: $id, hardDelete: $hardDelete)';
}


}

/// @nodoc
abstract mixin class $SyncAiConfigDeleteCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncAiConfigDeleteCopyWith(SyncAiConfigDelete value, $Res Function(SyncAiConfigDelete) _then) = _$SyncAiConfigDeleteCopyWithImpl;
@useResult
$Res call({
 String id, bool? hardDelete
});




}
/// @nodoc
class _$SyncAiConfigDeleteCopyWithImpl<$Res>
    implements $SyncAiConfigDeleteCopyWith<$Res> {
  _$SyncAiConfigDeleteCopyWithImpl(this._self, this._then);

  final SyncAiConfigDelete _self;
  final $Res Function(SyncAiConfigDelete) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? hardDelete = freezed,}) {
  return _then(SyncAiConfigDelete(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hardDelete: freezed == hardDelete ? _self.hardDelete : hardDelete // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncSavedTaskFilter implements SyncMessage {
  const SyncSavedTaskFilter({required this.filter, required this.status, final  String? $type}): $type = $type ?? 'savedTaskFilter';
  factory SyncSavedTaskFilter.fromJson(Map<String, dynamic> json) => _$SyncSavedTaskFilterFromJson(json);

 final  SavedTaskFilter filter;
 final  SyncEntryStatus status;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncSavedTaskFilterCopyWith<SyncSavedTaskFilter> get copyWith => _$SyncSavedTaskFilterCopyWithImpl<SyncSavedTaskFilter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncSavedTaskFilterToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncSavedTaskFilter&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,filter,status);

@override
String toString() {
  return 'SyncMessage.savedTaskFilter(filter: $filter, status: $status)';
}


}

/// @nodoc
abstract mixin class $SyncSavedTaskFilterCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncSavedTaskFilterCopyWith(SyncSavedTaskFilter value, $Res Function(SyncSavedTaskFilter) _then) = _$SyncSavedTaskFilterCopyWithImpl;
@useResult
$Res call({
 SavedTaskFilter filter, SyncEntryStatus status
});


$SavedTaskFilterCopyWith<$Res> get filter;

}
/// @nodoc
class _$SyncSavedTaskFilterCopyWithImpl<$Res>
    implements $SyncSavedTaskFilterCopyWith<$Res> {
  _$SyncSavedTaskFilterCopyWithImpl(this._self, this._then);

  final SyncSavedTaskFilter _self;
  final $Res Function(SyncSavedTaskFilter) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? filter = null,Object? status = null,}) {
  return _then(SyncSavedTaskFilter(
filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as SavedTaskFilter,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SavedTaskFilterCopyWith<$Res> get filter {
  
  return $SavedTaskFilterCopyWith<$Res>(_self.filter, (value) {
    return _then(_self.copyWith(filter: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncSavedTaskFilterDelete implements SyncMessage {
  const SyncSavedTaskFilterDelete({required this.id, final  String? $type}): $type = $type ?? 'savedTaskFilterDelete';
  factory SyncSavedTaskFilterDelete.fromJson(Map<String, dynamic> json) => _$SyncSavedTaskFilterDeleteFromJson(json);

 final  String id;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncSavedTaskFilterDeleteCopyWith<SyncSavedTaskFilterDelete> get copyWith => _$SyncSavedTaskFilterDeleteCopyWithImpl<SyncSavedTaskFilterDelete>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncSavedTaskFilterDeleteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncSavedTaskFilterDelete&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'SyncMessage.savedTaskFilterDelete(id: $id)';
}


}

/// @nodoc
abstract mixin class $SyncSavedTaskFilterDeleteCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncSavedTaskFilterDeleteCopyWith(SyncSavedTaskFilterDelete value, $Res Function(SyncSavedTaskFilterDelete) _then) = _$SyncSavedTaskFilterDeleteCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$SyncSavedTaskFilterDeleteCopyWithImpl<$Res>
    implements $SyncSavedTaskFilterDeleteCopyWith<$Res> {
  _$SyncSavedTaskFilterDeleteCopyWithImpl(this._self, this._then);

  final SyncSavedTaskFilterDelete _self;
  final $Res Function(SyncSavedTaskFilterDelete) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(SyncSavedTaskFilterDelete(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncConfigFlag implements SyncMessage {
  const SyncConfigFlag({required this.name, required this.description, required this.status, this.originatingHostId, final  String? $type}): $type = $type ?? 'configFlag';
  factory SyncConfigFlag.fromJson(Map<String, dynamic> json) => _$SyncConfigFlagFromJson(json);

 final  String name;
 final  String description;
 final  bool status;
 final  String? originatingHostId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncConfigFlagCopyWith<SyncConfigFlag> get copyWith => _$SyncConfigFlagCopyWithImpl<SyncConfigFlag>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncConfigFlagToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncConfigFlag&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,status,originatingHostId);

@override
String toString() {
  return 'SyncMessage.configFlag(name: $name, description: $description, status: $status, originatingHostId: $originatingHostId)';
}


}

/// @nodoc
abstract mixin class $SyncConfigFlagCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncConfigFlagCopyWith(SyncConfigFlag value, $Res Function(SyncConfigFlag) _then) = _$SyncConfigFlagCopyWithImpl;
@useResult
$Res call({
 String name, String description, bool status, String? originatingHostId
});




}
/// @nodoc
class _$SyncConfigFlagCopyWithImpl<$Res>
    implements $SyncConfigFlagCopyWith<$Res> {
  _$SyncConfigFlagCopyWithImpl(this._self, this._then);

  final SyncConfigFlag _self;
  final $Res Function(SyncConfigFlag) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? status = null,Object? originatingHostId = freezed,}) {
  return _then(SyncConfigFlag(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as bool,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncThemingSelection implements SyncMessage {
  const SyncThemingSelection({required this.lightThemeName, required this.darkThemeName, required this.themeMode, required this.updatedAt, required this.status, final  String? $type}): $type = $type ?? 'themingSelection';
  factory SyncThemingSelection.fromJson(Map<String, dynamic> json) => _$SyncThemingSelectionFromJson(json);

 final  String lightThemeName;
 final  String darkThemeName;
 final  String themeMode;
 final  int updatedAt;
 final  SyncEntryStatus status;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncThemingSelectionCopyWith<SyncThemingSelection> get copyWith => _$SyncThemingSelectionCopyWithImpl<SyncThemingSelection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncThemingSelectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncThemingSelection&&(identical(other.lightThemeName, lightThemeName) || other.lightThemeName == lightThemeName)&&(identical(other.darkThemeName, darkThemeName) || other.darkThemeName == darkThemeName)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lightThemeName,darkThemeName,themeMode,updatedAt,status);

@override
String toString() {
  return 'SyncMessage.themingSelection(lightThemeName: $lightThemeName, darkThemeName: $darkThemeName, themeMode: $themeMode, updatedAt: $updatedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class $SyncThemingSelectionCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncThemingSelectionCopyWith(SyncThemingSelection value, $Res Function(SyncThemingSelection) _then) = _$SyncThemingSelectionCopyWithImpl;
@useResult
$Res call({
 String lightThemeName, String darkThemeName, String themeMode, int updatedAt, SyncEntryStatus status
});




}
/// @nodoc
class _$SyncThemingSelectionCopyWithImpl<$Res>
    implements $SyncThemingSelectionCopyWith<$Res> {
  _$SyncThemingSelectionCopyWithImpl(this._self, this._then);

  final SyncThemingSelection _self;
  final $Res Function(SyncThemingSelection) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? lightThemeName = null,Object? darkThemeName = null,Object? themeMode = null,Object? updatedAt = null,Object? status = null,}) {
  return _then(SyncThemingSelection(
lightThemeName: null == lightThemeName ? _self.lightThemeName : lightThemeName // ignore: cast_nullable_to_non_nullable
as String,darkThemeName: null == darkThemeName ? _self.darkThemeName : darkThemeName // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncDailyOsUserName implements SyncMessage {
  const SyncDailyOsUserName({required this.userName, required this.updatedAt, required this.status, final  String? $type}): $type = $type ?? 'dailyOsUserName';
  factory SyncDailyOsUserName.fromJson(Map<String, dynamic> json) => _$SyncDailyOsUserNameFromJson(json);

 final  String userName;
 final  int updatedAt;
 final  SyncEntryStatus status;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncDailyOsUserNameCopyWith<SyncDailyOsUserName> get copyWith => _$SyncDailyOsUserNameCopyWithImpl<SyncDailyOsUserName>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncDailyOsUserNameToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncDailyOsUserName&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userName,updatedAt,status);

@override
String toString() {
  return 'SyncMessage.dailyOsUserName(userName: $userName, updatedAt: $updatedAt, status: $status)';
}


}

/// @nodoc
abstract mixin class $SyncDailyOsUserNameCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncDailyOsUserNameCopyWith(SyncDailyOsUserName value, $Res Function(SyncDailyOsUserName) _then) = _$SyncDailyOsUserNameCopyWithImpl;
@useResult
$Res call({
 String userName, int updatedAt, SyncEntryStatus status
});




}
/// @nodoc
class _$SyncDailyOsUserNameCopyWithImpl<$Res>
    implements $SyncDailyOsUserNameCopyWith<$Res> {
  _$SyncDailyOsUserNameCopyWithImpl(this._self, this._then);

  final SyncDailyOsUserName _self;
  final $Res Function(SyncDailyOsUserName) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userName = null,Object? updatedAt = null,Object? status = null,}) {
  return _then(SyncDailyOsUserName(
userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncNotification implements SyncMessage {
  const SyncNotification({required this.id, required this.jsonPath, required this.vectorClock, required this.originatingHostId, this.attachmentEventId, final  List<VectorClock>? coveredVectorClocks, final  String? $type}): _coveredVectorClocks = coveredVectorClocks,$type = $type ?? 'notification';
  factory SyncNotification.fromJson(Map<String, dynamic> json) => _$SyncNotificationFromJson(json);

 final  String id;
 final  String jsonPath;
 final  VectorClock vectorClock;
 final  String originatingHostId;
 final  String? attachmentEventId;
 final  List<VectorClock>? _coveredVectorClocks;
 List<VectorClock>? get coveredVectorClocks {
  final value = _coveredVectorClocks;
  if (value == null) return null;
  if (_coveredVectorClocks is EqualUnmodifiableListView) return _coveredVectorClocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncNotificationCopyWith<SyncNotification> get copyWith => _$SyncNotificationCopyWithImpl<SyncNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&(identical(other.attachmentEventId, attachmentEventId) || other.attachmentEventId == attachmentEventId)&&const DeepCollectionEquality().equals(other._coveredVectorClocks, _coveredVectorClocks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,jsonPath,vectorClock,originatingHostId,attachmentEventId,const DeepCollectionEquality().hash(_coveredVectorClocks));

@override
String toString() {
  return 'SyncMessage.notification(id: $id, jsonPath: $jsonPath, vectorClock: $vectorClock, originatingHostId: $originatingHostId, attachmentEventId: $attachmentEventId, coveredVectorClocks: $coveredVectorClocks)';
}


}

/// @nodoc
abstract mixin class $SyncNotificationCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncNotificationCopyWith(SyncNotification value, $Res Function(SyncNotification) _then) = _$SyncNotificationCopyWithImpl;
@useResult
$Res call({
 String id, String jsonPath, VectorClock vectorClock, String originatingHostId, String? attachmentEventId, List<VectorClock>? coveredVectorClocks
});




}
/// @nodoc
class _$SyncNotificationCopyWithImpl<$Res>
    implements $SyncNotificationCopyWith<$Res> {
  _$SyncNotificationCopyWithImpl(this._self, this._then);

  final SyncNotification _self;
  final $Res Function(SyncNotification) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? jsonPath = null,Object? vectorClock = null,Object? originatingHostId = null,Object? attachmentEventId = freezed,Object? coveredVectorClocks = freezed,}) {
  return _then(SyncNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,jsonPath: null == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String,vectorClock: null == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock,originatingHostId: null == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String,attachmentEventId: freezed == attachmentEventId ? _self.attachmentEventId : attachmentEventId // ignore: cast_nullable_to_non_nullable
as String?,coveredVectorClocks: freezed == coveredVectorClocks ? _self._coveredVectorClocks : coveredVectorClocks // ignore: cast_nullable_to_non_nullable
as List<VectorClock>?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncNotificationStateUpdate implements SyncMessage {
  const SyncNotificationStateUpdate({required this.id, required this.vectorClock, required this.originatingHostId, this.seenAt, this.actedOnAt, this.deletedAt, final  String? $type}): $type = $type ?? 'notificationStateUpdate';
  factory SyncNotificationStateUpdate.fromJson(Map<String, dynamic> json) => _$SyncNotificationStateUpdateFromJson(json);

 final  String id;
 final  VectorClock vectorClock;
 final  String originatingHostId;
 final  DateTime? seenAt;
 final  DateTime? actedOnAt;
 final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncNotificationStateUpdateCopyWith<SyncNotificationStateUpdate> get copyWith => _$SyncNotificationStateUpdateCopyWithImpl<SyncNotificationStateUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncNotificationStateUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncNotificationStateUpdate&&(identical(other.id, id) || other.id == id)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&(identical(other.seenAt, seenAt) || other.seenAt == seenAt)&&(identical(other.actedOnAt, actedOnAt) || other.actedOnAt == actedOnAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,vectorClock,originatingHostId,seenAt,actedOnAt,deletedAt);

@override
String toString() {
  return 'SyncMessage.notificationStateUpdate(id: $id, vectorClock: $vectorClock, originatingHostId: $originatingHostId, seenAt: $seenAt, actedOnAt: $actedOnAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $SyncNotificationStateUpdateCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncNotificationStateUpdateCopyWith(SyncNotificationStateUpdate value, $Res Function(SyncNotificationStateUpdate) _then) = _$SyncNotificationStateUpdateCopyWithImpl;
@useResult
$Res call({
 String id, VectorClock vectorClock, String originatingHostId, DateTime? seenAt, DateTime? actedOnAt, DateTime? deletedAt
});




}
/// @nodoc
class _$SyncNotificationStateUpdateCopyWithImpl<$Res>
    implements $SyncNotificationStateUpdateCopyWith<$Res> {
  _$SyncNotificationStateUpdateCopyWithImpl(this._self, this._then);

  final SyncNotificationStateUpdate _self;
  final $Res Function(SyncNotificationStateUpdate) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? vectorClock = null,Object? originatingHostId = null,Object? seenAt = freezed,Object? actedOnAt = freezed,Object? deletedAt = freezed,}) {
  return _then(SyncNotificationStateUpdate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,vectorClock: null == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock,originatingHostId: null == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String,seenAt: freezed == seenAt ? _self.seenAt : seenAt // ignore: cast_nullable_to_non_nullable
as DateTime?,actedOnAt: freezed == actedOnAt ? _self.actedOnAt : actedOnAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncOnboardingSnapshotBegin implements SyncMessage {
  const SyncOnboardingSnapshotBegin({required this.protocolVersion, required this.roundId, required this.senderHostId, required this.senderUserId, required this.senderDeviceId, required this.recipientUserId, required this.recipientDeviceId, required final  Map<String, int> coverageUpperBounds, required this.leaseSeconds, final  String? $type}): _coverageUpperBounds = coverageUpperBounds,$type = $type ?? 'onboardingSnapshotBegin';
  factory SyncOnboardingSnapshotBegin.fromJson(Map<String, dynamic> json) => _$SyncOnboardingSnapshotBeginFromJson(json);

 final  int protocolVersion;
 final  String roundId;
 final  String senderHostId;
 final  String senderUserId;
 final  String senderDeviceId;
 final  String recipientUserId;
 final  String recipientDeviceId;
 final  Map<String, int> _coverageUpperBounds;
 Map<String, int> get coverageUpperBounds {
  if (_coverageUpperBounds is EqualUnmodifiableMapView) return _coverageUpperBounds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_coverageUpperBounds);
}

 final  int leaseSeconds;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncOnboardingSnapshotBeginCopyWith<SyncOnboardingSnapshotBegin> get copyWith => _$SyncOnboardingSnapshotBeginCopyWithImpl<SyncOnboardingSnapshotBegin>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncOnboardingSnapshotBeginToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncOnboardingSnapshotBegin&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.roundId, roundId) || other.roundId == roundId)&&(identical(other.senderHostId, senderHostId) || other.senderHostId == senderHostId)&&(identical(other.senderUserId, senderUserId) || other.senderUserId == senderUserId)&&(identical(other.senderDeviceId, senderDeviceId) || other.senderDeviceId == senderDeviceId)&&(identical(other.recipientUserId, recipientUserId) || other.recipientUserId == recipientUserId)&&(identical(other.recipientDeviceId, recipientDeviceId) || other.recipientDeviceId == recipientDeviceId)&&const DeepCollectionEquality().equals(other._coverageUpperBounds, _coverageUpperBounds)&&(identical(other.leaseSeconds, leaseSeconds) || other.leaseSeconds == leaseSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,roundId,senderHostId,senderUserId,senderDeviceId,recipientUserId,recipientDeviceId,const DeepCollectionEquality().hash(_coverageUpperBounds),leaseSeconds);

@override
String toString() {
  return 'SyncMessage.onboardingSnapshotBegin(protocolVersion: $protocolVersion, roundId: $roundId, senderHostId: $senderHostId, senderUserId: $senderUserId, senderDeviceId: $senderDeviceId, recipientUserId: $recipientUserId, recipientDeviceId: $recipientDeviceId, coverageUpperBounds: $coverageUpperBounds, leaseSeconds: $leaseSeconds)';
}


}

/// @nodoc
abstract mixin class $SyncOnboardingSnapshotBeginCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncOnboardingSnapshotBeginCopyWith(SyncOnboardingSnapshotBegin value, $Res Function(SyncOnboardingSnapshotBegin) _then) = _$SyncOnboardingSnapshotBeginCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, String roundId, String senderHostId, String senderUserId, String senderDeviceId, String recipientUserId, String recipientDeviceId, Map<String, int> coverageUpperBounds, int leaseSeconds
});




}
/// @nodoc
class _$SyncOnboardingSnapshotBeginCopyWithImpl<$Res>
    implements $SyncOnboardingSnapshotBeginCopyWith<$Res> {
  _$SyncOnboardingSnapshotBeginCopyWithImpl(this._self, this._then);

  final SyncOnboardingSnapshotBegin _self;
  final $Res Function(SyncOnboardingSnapshotBegin) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? roundId = null,Object? senderHostId = null,Object? senderUserId = null,Object? senderDeviceId = null,Object? recipientUserId = null,Object? recipientDeviceId = null,Object? coverageUpperBounds = null,Object? leaseSeconds = null,}) {
  return _then(SyncOnboardingSnapshotBegin(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,roundId: null == roundId ? _self.roundId : roundId // ignore: cast_nullable_to_non_nullable
as String,senderHostId: null == senderHostId ? _self.senderHostId : senderHostId // ignore: cast_nullable_to_non_nullable
as String,senderUserId: null == senderUserId ? _self.senderUserId : senderUserId // ignore: cast_nullable_to_non_nullable
as String,senderDeviceId: null == senderDeviceId ? _self.senderDeviceId : senderDeviceId // ignore: cast_nullable_to_non_nullable
as String,recipientUserId: null == recipientUserId ? _self.recipientUserId : recipientUserId // ignore: cast_nullable_to_non_nullable
as String,recipientDeviceId: null == recipientDeviceId ? _self.recipientDeviceId : recipientDeviceId // ignore: cast_nullable_to_non_nullable
as String,coverageUpperBounds: null == coverageUpperBounds ? _self._coverageUpperBounds : coverageUpperBounds // ignore: cast_nullable_to_non_nullable
as Map<String, int>,leaseSeconds: null == leaseSeconds ? _self.leaseSeconds : leaseSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncOnboardingSnapshotAccepted implements SyncMessage {
  const SyncOnboardingSnapshotAccepted({required this.protocolVersion, required this.roundId, required this.senderHostId, required this.senderUserId, required this.senderDeviceId, required this.recipientHostId, required this.recipientDeviceId, final  String? $type}): $type = $type ?? 'onboardingSnapshotAccepted';
  factory SyncOnboardingSnapshotAccepted.fromJson(Map<String, dynamic> json) => _$SyncOnboardingSnapshotAcceptedFromJson(json);

 final  int protocolVersion;
 final  String roundId;
 final  String senderHostId;
 final  String senderUserId;
 final  String senderDeviceId;
 final  String recipientHostId;
 final  String recipientDeviceId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncOnboardingSnapshotAcceptedCopyWith<SyncOnboardingSnapshotAccepted> get copyWith => _$SyncOnboardingSnapshotAcceptedCopyWithImpl<SyncOnboardingSnapshotAccepted>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncOnboardingSnapshotAcceptedToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncOnboardingSnapshotAccepted&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.roundId, roundId) || other.roundId == roundId)&&(identical(other.senderHostId, senderHostId) || other.senderHostId == senderHostId)&&(identical(other.senderUserId, senderUserId) || other.senderUserId == senderUserId)&&(identical(other.senderDeviceId, senderDeviceId) || other.senderDeviceId == senderDeviceId)&&(identical(other.recipientHostId, recipientHostId) || other.recipientHostId == recipientHostId)&&(identical(other.recipientDeviceId, recipientDeviceId) || other.recipientDeviceId == recipientDeviceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,roundId,senderHostId,senderUserId,senderDeviceId,recipientHostId,recipientDeviceId);

@override
String toString() {
  return 'SyncMessage.onboardingSnapshotAccepted(protocolVersion: $protocolVersion, roundId: $roundId, senderHostId: $senderHostId, senderUserId: $senderUserId, senderDeviceId: $senderDeviceId, recipientHostId: $recipientHostId, recipientDeviceId: $recipientDeviceId)';
}


}

/// @nodoc
abstract mixin class $SyncOnboardingSnapshotAcceptedCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncOnboardingSnapshotAcceptedCopyWith(SyncOnboardingSnapshotAccepted value, $Res Function(SyncOnboardingSnapshotAccepted) _then) = _$SyncOnboardingSnapshotAcceptedCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, String roundId, String senderHostId, String senderUserId, String senderDeviceId, String recipientHostId, String recipientDeviceId
});




}
/// @nodoc
class _$SyncOnboardingSnapshotAcceptedCopyWithImpl<$Res>
    implements $SyncOnboardingSnapshotAcceptedCopyWith<$Res> {
  _$SyncOnboardingSnapshotAcceptedCopyWithImpl(this._self, this._then);

  final SyncOnboardingSnapshotAccepted _self;
  final $Res Function(SyncOnboardingSnapshotAccepted) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? roundId = null,Object? senderHostId = null,Object? senderUserId = null,Object? senderDeviceId = null,Object? recipientHostId = null,Object? recipientDeviceId = null,}) {
  return _then(SyncOnboardingSnapshotAccepted(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,roundId: null == roundId ? _self.roundId : roundId // ignore: cast_nullable_to_non_nullable
as String,senderHostId: null == senderHostId ? _self.senderHostId : senderHostId // ignore: cast_nullable_to_non_nullable
as String,senderUserId: null == senderUserId ? _self.senderUserId : senderUserId // ignore: cast_nullable_to_non_nullable
as String,senderDeviceId: null == senderDeviceId ? _self.senderDeviceId : senderDeviceId // ignore: cast_nullable_to_non_nullable
as String,recipientHostId: null == recipientHostId ? _self.recipientHostId : recipientHostId // ignore: cast_nullable_to_non_nullable
as String,recipientDeviceId: null == recipientDeviceId ? _self.recipientDeviceId : recipientDeviceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class SyncOnboardingTerminalCounters implements SyncMessage {
  const SyncOnboardingTerminalCounters({required this.protocolVersion, required this.roundId, required this.senderHostId, required this.recipientUserId, required this.recipientDeviceId, required final  List<SyncCounterRange> ranges, final  String? $type}): _ranges = ranges,$type = $type ?? 'onboardingTerminalCounters';
  factory SyncOnboardingTerminalCounters.fromJson(Map<String, dynamic> json) => _$SyncOnboardingTerminalCountersFromJson(json);

 final  int protocolVersion;
 final  String roundId;
 final  String senderHostId;
 final  String recipientUserId;
 final  String recipientDeviceId;
 final  List<SyncCounterRange> _ranges;
 List<SyncCounterRange> get ranges {
  if (_ranges is EqualUnmodifiableListView) return _ranges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ranges);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncOnboardingTerminalCountersCopyWith<SyncOnboardingTerminalCounters> get copyWith => _$SyncOnboardingTerminalCountersCopyWithImpl<SyncOnboardingTerminalCounters>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncOnboardingTerminalCountersToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncOnboardingTerminalCounters&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.roundId, roundId) || other.roundId == roundId)&&(identical(other.senderHostId, senderHostId) || other.senderHostId == senderHostId)&&(identical(other.recipientUserId, recipientUserId) || other.recipientUserId == recipientUserId)&&(identical(other.recipientDeviceId, recipientDeviceId) || other.recipientDeviceId == recipientDeviceId)&&const DeepCollectionEquality().equals(other._ranges, _ranges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,roundId,senderHostId,recipientUserId,recipientDeviceId,const DeepCollectionEquality().hash(_ranges));

@override
String toString() {
  return 'SyncMessage.onboardingTerminalCounters(protocolVersion: $protocolVersion, roundId: $roundId, senderHostId: $senderHostId, recipientUserId: $recipientUserId, recipientDeviceId: $recipientDeviceId, ranges: $ranges)';
}


}

/// @nodoc
abstract mixin class $SyncOnboardingTerminalCountersCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncOnboardingTerminalCountersCopyWith(SyncOnboardingTerminalCounters value, $Res Function(SyncOnboardingTerminalCounters) _then) = _$SyncOnboardingTerminalCountersCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, String roundId, String senderHostId, String recipientUserId, String recipientDeviceId, List<SyncCounterRange> ranges
});




}
/// @nodoc
class _$SyncOnboardingTerminalCountersCopyWithImpl<$Res>
    implements $SyncOnboardingTerminalCountersCopyWith<$Res> {
  _$SyncOnboardingTerminalCountersCopyWithImpl(this._self, this._then);

  final SyncOnboardingTerminalCounters _self;
  final $Res Function(SyncOnboardingTerminalCounters) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? roundId = null,Object? senderHostId = null,Object? recipientUserId = null,Object? recipientDeviceId = null,Object? ranges = null,}) {
  return _then(SyncOnboardingTerminalCounters(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,roundId: null == roundId ? _self.roundId : roundId // ignore: cast_nullable_to_non_nullable
as String,senderHostId: null == senderHostId ? _self.senderHostId : senderHostId // ignore: cast_nullable_to_non_nullable
as String,recipientUserId: null == recipientUserId ? _self.recipientUserId : recipientUserId // ignore: cast_nullable_to_non_nullable
as String,recipientDeviceId: null == recipientDeviceId ? _self.recipientDeviceId : recipientDeviceId // ignore: cast_nullable_to_non_nullable
as String,ranges: null == ranges ? _self._ranges : ranges // ignore: cast_nullable_to_non_nullable
as List<SyncCounterRange>,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncOnboardingSnapshotEnd implements SyncMessage {
  const SyncOnboardingSnapshotEnd({required this.protocolVersion, required this.roundId, required this.senderHostId, required this.recipientUserId, required this.recipientDeviceId, required this.reason, final  String? $type}): $type = $type ?? 'onboardingSnapshotEnd';
  factory SyncOnboardingSnapshotEnd.fromJson(Map<String, dynamic> json) => _$SyncOnboardingSnapshotEndFromJson(json);

 final  int protocolVersion;
 final  String roundId;
 final  String senderHostId;
 final  String recipientUserId;
 final  String recipientDeviceId;
 final  OnboardingSyncEndReason reason;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncOnboardingSnapshotEndCopyWith<SyncOnboardingSnapshotEnd> get copyWith => _$SyncOnboardingSnapshotEndCopyWithImpl<SyncOnboardingSnapshotEnd>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncOnboardingSnapshotEndToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncOnboardingSnapshotEnd&&(identical(other.protocolVersion, protocolVersion) || other.protocolVersion == protocolVersion)&&(identical(other.roundId, roundId) || other.roundId == roundId)&&(identical(other.senderHostId, senderHostId) || other.senderHostId == senderHostId)&&(identical(other.recipientUserId, recipientUserId) || other.recipientUserId == recipientUserId)&&(identical(other.recipientDeviceId, recipientDeviceId) || other.recipientDeviceId == recipientDeviceId)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,protocolVersion,roundId,senderHostId,recipientUserId,recipientDeviceId,reason);

@override
String toString() {
  return 'SyncMessage.onboardingSnapshotEnd(protocolVersion: $protocolVersion, roundId: $roundId, senderHostId: $senderHostId, recipientUserId: $recipientUserId, recipientDeviceId: $recipientDeviceId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SyncOnboardingSnapshotEndCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncOnboardingSnapshotEndCopyWith(SyncOnboardingSnapshotEnd value, $Res Function(SyncOnboardingSnapshotEnd) _then) = _$SyncOnboardingSnapshotEndCopyWithImpl;
@useResult
$Res call({
 int protocolVersion, String roundId, String senderHostId, String recipientUserId, String recipientDeviceId, OnboardingSyncEndReason reason
});




}
/// @nodoc
class _$SyncOnboardingSnapshotEndCopyWithImpl<$Res>
    implements $SyncOnboardingSnapshotEndCopyWith<$Res> {
  _$SyncOnboardingSnapshotEndCopyWithImpl(this._self, this._then);

  final SyncOnboardingSnapshotEnd _self;
  final $Res Function(SyncOnboardingSnapshotEnd) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? protocolVersion = null,Object? roundId = null,Object? senderHostId = null,Object? recipientUserId = null,Object? recipientDeviceId = null,Object? reason = null,}) {
  return _then(SyncOnboardingSnapshotEnd(
protocolVersion: null == protocolVersion ? _self.protocolVersion : protocolVersion // ignore: cast_nullable_to_non_nullable
as int,roundId: null == roundId ? _self.roundId : roundId // ignore: cast_nullable_to_non_nullable
as String,senderHostId: null == senderHostId ? _self.senderHostId : senderHostId // ignore: cast_nullable_to_non_nullable
as String,recipientUserId: null == recipientUserId ? _self.recipientUserId : recipientUserId // ignore: cast_nullable_to_non_nullable
as String,recipientDeviceId: null == recipientDeviceId ? _self.recipientDeviceId : recipientDeviceId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as OnboardingSyncEndReason,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncBackfillRequest implements SyncMessage {
  const SyncBackfillRequest({required final  List<BackfillRequestEntry> entries, required this.requesterId, final  String? $type}): _entries = entries,$type = $type ?? 'backfillRequest';
  factory SyncBackfillRequest.fromJson(Map<String, dynamic> json) => _$SyncBackfillRequestFromJson(json);

/// List of missing entries to request, each with hostId and counter
 final  List<BackfillRequestEntry> _entries;
/// List of missing entries to request, each with hostId and counter
 List<BackfillRequestEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

/// The host UUID of the device requesting the backfill
 final  String requesterId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncBackfillRequestCopyWith<SyncBackfillRequest> get copyWith => _$SyncBackfillRequestCopyWithImpl<SyncBackfillRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncBackfillRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncBackfillRequest&&const DeepCollectionEquality().equals(other._entries, _entries)&&(identical(other.requesterId, requesterId) || other.requesterId == requesterId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_entries),requesterId);

@override
String toString() {
  return 'SyncMessage.backfillRequest(entries: $entries, requesterId: $requesterId)';
}


}

/// @nodoc
abstract mixin class $SyncBackfillRequestCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncBackfillRequestCopyWith(SyncBackfillRequest value, $Res Function(SyncBackfillRequest) _then) = _$SyncBackfillRequestCopyWithImpl;
@useResult
$Res call({
 List<BackfillRequestEntry> entries, String requesterId
});




}
/// @nodoc
class _$SyncBackfillRequestCopyWithImpl<$Res>
    implements $SyncBackfillRequestCopyWith<$Res> {
  _$SyncBackfillRequestCopyWithImpl(this._self, this._then);

  final SyncBackfillRequest _self;
  final $Res Function(SyncBackfillRequest) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entries = null,Object? requesterId = null,}) {
  return _then(SyncBackfillRequest(
entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<BackfillRequestEntry>,requesterId: null == requesterId ? _self.requesterId : requesterId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncBackfillResponse implements SyncMessage {
  const SyncBackfillResponse({required this.hostId, required this.counter, required this.deleted, this.unresolvable, this.entryId, this.payloadType, this.payloadId, final  String? $type}): $type = $type ?? 'backfillResponse';
  factory SyncBackfillResponse.fromJson(Map<String, dynamic> json) => _$SyncBackfillResponseFromJson(json);

/// The host UUID that originated the entry
 final  String hostId;
/// The monotonic counter for that host
 final  int counter;
/// True if the entry was deleted/purged and cannot be backfilled
 final  bool deleted;
/// True if the originating host cannot resolve its own counter.
/// This happens when a counter was superseded before being recorded
/// (e.g., rapid edits where intermediate versions were never persisted).
/// Receivers should mark this counter as permanently unresolvable.
 final  bool? unresolvable;
/// Legacy: The journal entry ID if found (null if deleted).
///
/// For newer clients, prefer `payloadType` + `payloadId`.
 final  String? entryId;
/// Identifies what kind of payload this backfill response refers to.
/// If omitted, defaults to `SyncSequencePayloadType.journalEntity`.
 final  SyncSequencePayloadType? payloadType;
/// The payload ID if found (null if deleted). For journal entities this is
/// the journal entry ID, for entry links it's the link ID.
 final  String? payloadId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncBackfillResponseCopyWith<SyncBackfillResponse> get copyWith => _$SyncBackfillResponseCopyWithImpl<SyncBackfillResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncBackfillResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncBackfillResponse&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.counter, counter) || other.counter == counter)&&(identical(other.deleted, deleted) || other.deleted == deleted)&&(identical(other.unresolvable, unresolvable) || other.unresolvable == unresolvable)&&(identical(other.entryId, entryId) || other.entryId == entryId)&&(identical(other.payloadType, payloadType) || other.payloadType == payloadType)&&(identical(other.payloadId, payloadId) || other.payloadId == payloadId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hostId,counter,deleted,unresolvable,entryId,payloadType,payloadId);

@override
String toString() {
  return 'SyncMessage.backfillResponse(hostId: $hostId, counter: $counter, deleted: $deleted, unresolvable: $unresolvable, entryId: $entryId, payloadType: $payloadType, payloadId: $payloadId)';
}


}

/// @nodoc
abstract mixin class $SyncBackfillResponseCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncBackfillResponseCopyWith(SyncBackfillResponse value, $Res Function(SyncBackfillResponse) _then) = _$SyncBackfillResponseCopyWithImpl;
@useResult
$Res call({
 String hostId, int counter, bool deleted, bool? unresolvable, String? entryId, SyncSequencePayloadType? payloadType, String? payloadId
});




}
/// @nodoc
class _$SyncBackfillResponseCopyWithImpl<$Res>
    implements $SyncBackfillResponseCopyWith<$Res> {
  _$SyncBackfillResponseCopyWithImpl(this._self, this._then);

  final SyncBackfillResponse _self;
  final $Res Function(SyncBackfillResponse) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? hostId = null,Object? counter = null,Object? deleted = null,Object? unresolvable = freezed,Object? entryId = freezed,Object? payloadType = freezed,Object? payloadId = freezed,}) {
  return _then(SyncBackfillResponse(
hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,counter: null == counter ? _self.counter : counter // ignore: cast_nullable_to_non_nullable
as int,deleted: null == deleted ? _self.deleted : deleted // ignore: cast_nullable_to_non_nullable
as bool,unresolvable: freezed == unresolvable ? _self.unresolvable : unresolvable // ignore: cast_nullable_to_non_nullable
as bool?,entryId: freezed == entryId ? _self.entryId : entryId // ignore: cast_nullable_to_non_nullable
as String?,payloadType: freezed == payloadType ? _self.payloadType : payloadType // ignore: cast_nullable_to_non_nullable
as SyncSequencePayloadType?,payloadId: freezed == payloadId ? _self.payloadId : payloadId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncMediaRequest implements SyncMessage {
  const SyncMediaRequest({required final  List<String> entryIds, required this.requesterId, final  String? $type}): _entryIds = entryIds,$type = $type ?? 'mediaRequest';
  factory SyncMediaRequest.fromJson(Map<String, dynamic> json) => _$SyncMediaRequestFromJson(json);

/// Ids of the journal entries whose media is missing on `requesterId`.
 final  List<String> _entryIds;
/// Ids of the journal entries whose media is missing on `requesterId`.
 List<String> get entryIds {
  if (_entryIds is EqualUnmodifiableListView) return _entryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entryIds);
}

/// The host UUID asking for the blobs. Peers ignore their own requests.
 final  String requesterId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncMediaRequestCopyWith<SyncMediaRequest> get copyWith => _$SyncMediaRequestCopyWithImpl<SyncMediaRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncMediaRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncMediaRequest&&const DeepCollectionEquality().equals(other._entryIds, _entryIds)&&(identical(other.requesterId, requesterId) || other.requesterId == requesterId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_entryIds),requesterId);

@override
String toString() {
  return 'SyncMessage.mediaRequest(entryIds: $entryIds, requesterId: $requesterId)';
}


}

/// @nodoc
abstract mixin class $SyncMediaRequestCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncMediaRequestCopyWith(SyncMediaRequest value, $Res Function(SyncMediaRequest) _then) = _$SyncMediaRequestCopyWithImpl;
@useResult
$Res call({
 List<String> entryIds, String requesterId
});




}
/// @nodoc
class _$SyncMediaRequestCopyWithImpl<$Res>
    implements $SyncMediaRequestCopyWith<$Res> {
  _$SyncMediaRequestCopyWithImpl(this._self, this._then);

  final SyncMediaRequest _self;
  final $Res Function(SyncMediaRequest) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entryIds = null,Object? requesterId = null,}) {
  return _then(SyncMediaRequest(
entryIds: null == entryIds ? _self._entryIds : entryIds // ignore: cast_nullable_to_non_nullable
as List<String>,requesterId: null == requesterId ? _self.requesterId : requesterId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncAgentEntity implements SyncMessage {
  const SyncAgentEntity({required this.status, @JsonKey(toJson: _agentDomainEntityToJson) this.agentEntity, this.jsonPath, this.attachmentEventId, this.originatingHostId, final  List<VectorClock>? coveredVectorClocks, final  String? $type}): _coveredVectorClocks = coveredVectorClocks,$type = $type ?? 'agentEntity';
  factory SyncAgentEntity.fromJson(Map<String, dynamic> json) => _$SyncAgentEntityFromJson(json);

 final  SyncEntryStatus status;
@JsonKey(toJson: _agentDomainEntityToJson) final  AgentDomainEntity? agentEntity;
 final  String? jsonPath;
/// Matrix event id of the exact JSON attachment generation referenced by
/// this envelope. Legacy envelopes omit it and retain path-only fallback.
 final  String? attachmentEventId;
/// The host UUID that created/modified this agent entity version.
/// Used for sequence tracking to detect gaps in sync.
 final  String? originatingHostId;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries.
 final  List<VectorClock>? _coveredVectorClocks;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries.
 List<VectorClock>? get coveredVectorClocks {
  final value = _coveredVectorClocks;
  if (value == null) return null;
  if (_coveredVectorClocks is EqualUnmodifiableListView) return _coveredVectorClocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncAgentEntityCopyWith<SyncAgentEntity> get copyWith => _$SyncAgentEntityCopyWithImpl<SyncAgentEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncAgentEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncAgentEntity&&(identical(other.status, status) || other.status == status)&&(identical(other.agentEntity, agentEntity) || other.agentEntity == agentEntity)&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.attachmentEventId, attachmentEventId) || other.attachmentEventId == attachmentEventId)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&const DeepCollectionEquality().equals(other._coveredVectorClocks, _coveredVectorClocks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,agentEntity,jsonPath,attachmentEventId,originatingHostId,const DeepCollectionEquality().hash(_coveredVectorClocks));

@override
String toString() {
  return 'SyncMessage.agentEntity(status: $status, agentEntity: $agentEntity, jsonPath: $jsonPath, attachmentEventId: $attachmentEventId, originatingHostId: $originatingHostId, coveredVectorClocks: $coveredVectorClocks)';
}


}

/// @nodoc
abstract mixin class $SyncAgentEntityCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncAgentEntityCopyWith(SyncAgentEntity value, $Res Function(SyncAgentEntity) _then) = _$SyncAgentEntityCopyWithImpl;
@useResult
$Res call({
 SyncEntryStatus status,@JsonKey(toJson: _agentDomainEntityToJson) AgentDomainEntity? agentEntity, String? jsonPath, String? attachmentEventId, String? originatingHostId, List<VectorClock>? coveredVectorClocks
});


$AgentDomainEntityCopyWith<$Res>? get agentEntity;

}
/// @nodoc
class _$SyncAgentEntityCopyWithImpl<$Res>
    implements $SyncAgentEntityCopyWith<$Res> {
  _$SyncAgentEntityCopyWithImpl(this._self, this._then);

  final SyncAgentEntity _self;
  final $Res Function(SyncAgentEntity) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? status = null,Object? agentEntity = freezed,Object? jsonPath = freezed,Object? attachmentEventId = freezed,Object? originatingHostId = freezed,Object? coveredVectorClocks = freezed,}) {
  return _then(SyncAgentEntity(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,agentEntity: freezed == agentEntity ? _self.agentEntity : agentEntity // ignore: cast_nullable_to_non_nullable
as AgentDomainEntity?,jsonPath: freezed == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String?,attachmentEventId: freezed == attachmentEventId ? _self.attachmentEventId : attachmentEventId // ignore: cast_nullable_to_non_nullable
as String?,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,coveredVectorClocks: freezed == coveredVectorClocks ? _self._coveredVectorClocks : coveredVectorClocks // ignore: cast_nullable_to_non_nullable
as List<VectorClock>?,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentDomainEntityCopyWith<$Res>? get agentEntity {
    if (_self.agentEntity == null) {
    return null;
  }

  return $AgentDomainEntityCopyWith<$Res>(_self.agentEntity!, (value) {
    return _then(_self.copyWith(agentEntity: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncAgentLink implements SyncMessage {
  const SyncAgentLink({required this.status, this.agentLink, this.jsonPath, this.attachmentEventId, this.originatingHostId, final  List<VectorClock>? coveredVectorClocks, final  String? $type}): _coveredVectorClocks = coveredVectorClocks,$type = $type ?? 'agentLink';
  factory SyncAgentLink.fromJson(Map<String, dynamic> json) => _$SyncAgentLinkFromJson(json);

 final  SyncEntryStatus status;
 final  AgentLink? agentLink;
 final  String? jsonPath;
 final  String? attachmentEventId;
/// The host UUID that created/modified this agent link version.
/// Used for sequence tracking to detect gaps in sync.
 final  String? originatingHostId;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries.
 final  List<VectorClock>? _coveredVectorClocks;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries.
 List<VectorClock>? get coveredVectorClocks {
  final value = _coveredVectorClocks;
  if (value == null) return null;
  if (_coveredVectorClocks is EqualUnmodifiableListView) return _coveredVectorClocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncAgentLinkCopyWith<SyncAgentLink> get copyWith => _$SyncAgentLinkCopyWithImpl<SyncAgentLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncAgentLinkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncAgentLink&&(identical(other.status, status) || other.status == status)&&(identical(other.agentLink, agentLink) || other.agentLink == agentLink)&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.attachmentEventId, attachmentEventId) || other.attachmentEventId == attachmentEventId)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&const DeepCollectionEquality().equals(other._coveredVectorClocks, _coveredVectorClocks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,agentLink,jsonPath,attachmentEventId,originatingHostId,const DeepCollectionEquality().hash(_coveredVectorClocks));

@override
String toString() {
  return 'SyncMessage.agentLink(status: $status, agentLink: $agentLink, jsonPath: $jsonPath, attachmentEventId: $attachmentEventId, originatingHostId: $originatingHostId, coveredVectorClocks: $coveredVectorClocks)';
}


}

/// @nodoc
abstract mixin class $SyncAgentLinkCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncAgentLinkCopyWith(SyncAgentLink value, $Res Function(SyncAgentLink) _then) = _$SyncAgentLinkCopyWithImpl;
@useResult
$Res call({
 SyncEntryStatus status, AgentLink? agentLink, String? jsonPath, String? attachmentEventId, String? originatingHostId, List<VectorClock>? coveredVectorClocks
});


$AgentLinkCopyWith<$Res>? get agentLink;

}
/// @nodoc
class _$SyncAgentLinkCopyWithImpl<$Res>
    implements $SyncAgentLinkCopyWith<$Res> {
  _$SyncAgentLinkCopyWithImpl(this._self, this._then);

  final SyncAgentLink _self;
  final $Res Function(SyncAgentLink) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? status = null,Object? agentLink = freezed,Object? jsonPath = freezed,Object? attachmentEventId = freezed,Object? originatingHostId = freezed,Object? coveredVectorClocks = freezed,}) {
  return _then(SyncAgentLink(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,agentLink: freezed == agentLink ? _self.agentLink : agentLink // ignore: cast_nullable_to_non_nullable
as AgentLink?,jsonPath: freezed == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String?,attachmentEventId: freezed == attachmentEventId ? _self.attachmentEventId : attachmentEventId // ignore: cast_nullable_to_non_nullable
as String?,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,coveredVectorClocks: freezed == coveredVectorClocks ? _self._coveredVectorClocks : coveredVectorClocks // ignore: cast_nullable_to_non_nullable
as List<VectorClock>?,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentLinkCopyWith<$Res>? get agentLink {
    if (_self.agentLink == null) {
    return null;
  }

  return $AgentLinkCopyWith<$Res>(_self.agentLink!, (value) {
    return _then(_self.copyWith(agentLink: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncConsumptionEvent implements SyncMessage {
  const SyncConsumptionEvent({required this.event, required this.status, this.originatingHostId, final  List<VectorClock>? coveredVectorClocks, final  String? $type}): _coveredVectorClocks = coveredVectorClocks,$type = $type ?? 'consumptionEvent';
  factory SyncConsumptionEvent.fromJson(Map<String, dynamic> json) => _$SyncConsumptionEventFromJson(json);

 final  AiConsumptionEvent event;
 final  SyncEntryStatus status;
/// The host UUID that created this consumption event.
/// Used for sequence tracking to detect gaps in sync.
 final  String? originatingHostId;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries.
 final  List<VectorClock>? _coveredVectorClocks;
/// Vector clocks covered by this payload, including the current vector
/// clock and superseded outbox entries.
 List<VectorClock>? get coveredVectorClocks {
  final value = _coveredVectorClocks;
  if (value == null) return null;
  if (_coveredVectorClocks is EqualUnmodifiableListView) return _coveredVectorClocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncConsumptionEventCopyWith<SyncConsumptionEvent> get copyWith => _$SyncConsumptionEventCopyWithImpl<SyncConsumptionEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncConsumptionEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncConsumptionEvent&&(identical(other.event, event) || other.event == event)&&(identical(other.status, status) || other.status == status)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId)&&const DeepCollectionEquality().equals(other._coveredVectorClocks, _coveredVectorClocks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,event,status,originatingHostId,const DeepCollectionEquality().hash(_coveredVectorClocks));

@override
String toString() {
  return 'SyncMessage.consumptionEvent(event: $event, status: $status, originatingHostId: $originatingHostId, coveredVectorClocks: $coveredVectorClocks)';
}


}

/// @nodoc
abstract mixin class $SyncConsumptionEventCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncConsumptionEventCopyWith(SyncConsumptionEvent value, $Res Function(SyncConsumptionEvent) _then) = _$SyncConsumptionEventCopyWithImpl;
@useResult
$Res call({
 AiConsumptionEvent event, SyncEntryStatus status, String? originatingHostId, List<VectorClock>? coveredVectorClocks
});


$AiConsumptionEventCopyWith<$Res> get event;

}
/// @nodoc
class _$SyncConsumptionEventCopyWithImpl<$Res>
    implements $SyncConsumptionEventCopyWith<$Res> {
  _$SyncConsumptionEventCopyWithImpl(this._self, this._then);

  final SyncConsumptionEvent _self;
  final $Res Function(SyncConsumptionEvent) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? event = null,Object? status = null,Object? originatingHostId = freezed,Object? coveredVectorClocks = freezed,}) {
  return _then(SyncConsumptionEvent(
event: null == event ? _self.event : event // ignore: cast_nullable_to_non_nullable
as AiConsumptionEvent,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SyncEntryStatus,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,coveredVectorClocks: freezed == coveredVectorClocks ? _self._coveredVectorClocks : coveredVectorClocks // ignore: cast_nullable_to_non_nullable
as List<VectorClock>?,
  ));
}

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiConsumptionEventCopyWith<$Res> get event {
  
  return $AiConsumptionEventCopyWith<$Res>(_self.event, (value) {
    return _then(_self.copyWith(event: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SyncAgentBundle implements SyncMessage {
  const SyncAgentBundle({required this.agentId, required this.wakeRunKey, final  List<SyncAgentEntity> entities = const <SyncAgentEntity>[], final  List<SyncAgentLink> links = const <SyncAgentLink>[], this.jsonPath, this.attachmentEventId, this.originatingHostId, final  String? $type}): _entities = entities,_links = links,$type = $type ?? 'agentBundle';
  factory SyncAgentBundle.fromJson(Map<String, dynamic> json) => _$SyncAgentBundleFromJson(json);

 final  String agentId;
 final  String wakeRunKey;
 final  List<SyncAgentEntity> _entities;
@JsonKey() List<SyncAgentEntity> get entities {
  if (_entities is EqualUnmodifiableListView) return _entities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entities);
}

 final  List<SyncAgentLink> _links;
@JsonKey() List<SyncAgentLink> get links {
  if (_links is EqualUnmodifiableListView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_links);
}

 final  String? jsonPath;
 final  String? attachmentEventId;
 final  String? originatingHostId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncAgentBundleCopyWith<SyncAgentBundle> get copyWith => _$SyncAgentBundleCopyWithImpl<SyncAgentBundle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncAgentBundleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncAgentBundle&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.wakeRunKey, wakeRunKey) || other.wakeRunKey == wakeRunKey)&&const DeepCollectionEquality().equals(other._entities, _entities)&&const DeepCollectionEquality().equals(other._links, _links)&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.attachmentEventId, attachmentEventId) || other.attachmentEventId == attachmentEventId)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,agentId,wakeRunKey,const DeepCollectionEquality().hash(_entities),const DeepCollectionEquality().hash(_links),jsonPath,attachmentEventId,originatingHostId);

@override
String toString() {
  return 'SyncMessage.agentBundle(agentId: $agentId, wakeRunKey: $wakeRunKey, entities: $entities, links: $links, jsonPath: $jsonPath, attachmentEventId: $attachmentEventId, originatingHostId: $originatingHostId)';
}


}

/// @nodoc
abstract mixin class $SyncAgentBundleCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncAgentBundleCopyWith(SyncAgentBundle value, $Res Function(SyncAgentBundle) _then) = _$SyncAgentBundleCopyWithImpl;
@useResult
$Res call({
 String agentId, String wakeRunKey, List<SyncAgentEntity> entities, List<SyncAgentLink> links, String? jsonPath, String? attachmentEventId, String? originatingHostId
});




}
/// @nodoc
class _$SyncAgentBundleCopyWithImpl<$Res>
    implements $SyncAgentBundleCopyWith<$Res> {
  _$SyncAgentBundleCopyWithImpl(this._self, this._then);

  final SyncAgentBundle _self;
  final $Res Function(SyncAgentBundle) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? agentId = null,Object? wakeRunKey = null,Object? entities = null,Object? links = null,Object? jsonPath = freezed,Object? attachmentEventId = freezed,Object? originatingHostId = freezed,}) {
  return _then(SyncAgentBundle(
agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,wakeRunKey: null == wakeRunKey ? _self.wakeRunKey : wakeRunKey // ignore: cast_nullable_to_non_nullable
as String,entities: null == entities ? _self._entities : entities // ignore: cast_nullable_to_non_nullable
as List<SyncAgentEntity>,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as List<SyncAgentLink>,jsonPath: freezed == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String?,attachmentEventId: freezed == attachmentEventId ? _self.attachmentEventId : attachmentEventId // ignore: cast_nullable_to_non_nullable
as String?,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SyncOutboxBundle implements SyncMessage {
  const SyncOutboxBundle({required final  List<SyncMessage> children, this.jsonPath, this.attachmentEventId, this.originatingHostId, final  String? $type}): _children = children,$type = $type ?? 'outboxBundle';
  factory SyncOutboxBundle.fromJson(Map<String, dynamic> json) => _$SyncOutboxBundleFromJson(json);

 final  List<SyncMessage> _children;
 List<SyncMessage> get children {
  if (_children is EqualUnmodifiableListView) return _children;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_children);
}

 final  String? jsonPath;
 final  String? attachmentEventId;
 final  String? originatingHostId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncOutboxBundleCopyWith<SyncOutboxBundle> get copyWith => _$SyncOutboxBundleCopyWithImpl<SyncOutboxBundle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncOutboxBundleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncOutboxBundle&&const DeepCollectionEquality().equals(other._children, _children)&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.attachmentEventId, attachmentEventId) || other.attachmentEventId == attachmentEventId)&&(identical(other.originatingHostId, originatingHostId) || other.originatingHostId == originatingHostId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_children),jsonPath,attachmentEventId,originatingHostId);

@override
String toString() {
  return 'SyncMessage.outboxBundle(children: $children, jsonPath: $jsonPath, attachmentEventId: $attachmentEventId, originatingHostId: $originatingHostId)';
}


}

/// @nodoc
abstract mixin class $SyncOutboxBundleCopyWith<$Res> implements $SyncMessageCopyWith<$Res> {
  factory $SyncOutboxBundleCopyWith(SyncOutboxBundle value, $Res Function(SyncOutboxBundle) _then) = _$SyncOutboxBundleCopyWithImpl;
@useResult
$Res call({
 List<SyncMessage> children, String? jsonPath, String? attachmentEventId, String? originatingHostId
});




}
/// @nodoc
class _$SyncOutboxBundleCopyWithImpl<$Res>
    implements $SyncOutboxBundleCopyWith<$Res> {
  _$SyncOutboxBundleCopyWithImpl(this._self, this._then);

  final SyncOutboxBundle _self;
  final $Res Function(SyncOutboxBundle) _then;

/// Create a copy of SyncMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? children = null,Object? jsonPath = freezed,Object? attachmentEventId = freezed,Object? originatingHostId = freezed,}) {
  return _then(SyncOutboxBundle(
children: null == children ? _self._children : children // ignore: cast_nullable_to_non_nullable
as List<SyncMessage>,jsonPath: freezed == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String?,attachmentEventId: freezed == attachmentEventId ? _self.attachmentEventId : attachmentEventId // ignore: cast_nullable_to_non_nullable
as String?,originatingHostId: freezed == originatingHostId ? _self.originatingHostId : originatingHostId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
