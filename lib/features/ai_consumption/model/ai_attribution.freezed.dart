// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_attribution.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiActorSnapshot {

 AiActorType get type; String get id; String get displayName; String? get humanPrincipalId;
/// Create a copy of AiActorSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<AiActorSnapshot> get copyWith => _$AiActorSnapshotCopyWithImpl<AiActorSnapshot>(this as AiActorSnapshot, _$identity);

  /// Serializes this AiActorSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiActorSnapshot&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.humanPrincipalId, humanPrincipalId) || other.humanPrincipalId == humanPrincipalId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,displayName,humanPrincipalId);

@override
String toString() {
  return 'AiActorSnapshot(type: $type, id: $id, displayName: $displayName, humanPrincipalId: $humanPrincipalId)';
}


}

/// @nodoc
abstract mixin class $AiActorSnapshotCopyWith<$Res>  {
  factory $AiActorSnapshotCopyWith(AiActorSnapshot value, $Res Function(AiActorSnapshot) _then) = _$AiActorSnapshotCopyWithImpl;
@useResult
$Res call({
 AiActorType type, String id, String displayName, String? humanPrincipalId
});




}
/// @nodoc
class _$AiActorSnapshotCopyWithImpl<$Res>
    implements $AiActorSnapshotCopyWith<$Res> {
  _$AiActorSnapshotCopyWithImpl(this._self, this._then);

  final AiActorSnapshot _self;
  final $Res Function(AiActorSnapshot) _then;

/// Create a copy of AiActorSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = null,Object? displayName = null,Object? humanPrincipalId = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiActorType,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,humanPrincipalId: freezed == humanPrincipalId ? _self.humanPrincipalId : humanPrincipalId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiActorSnapshot].
extension AiActorSnapshotPatterns on AiActorSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiActorSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiActorSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiActorSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _AiActorSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiActorSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _AiActorSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AiActorType type,  String id,  String displayName,  String? humanPrincipalId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiActorSnapshot() when $default != null:
return $default(_that.type,_that.id,_that.displayName,_that.humanPrincipalId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AiActorType type,  String id,  String displayName,  String? humanPrincipalId)  $default,) {final _that = this;
switch (_that) {
case _AiActorSnapshot():
return $default(_that.type,_that.id,_that.displayName,_that.humanPrincipalId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AiActorType type,  String id,  String displayName,  String? humanPrincipalId)?  $default,) {final _that = this;
switch (_that) {
case _AiActorSnapshot() when $default != null:
return $default(_that.type,_that.id,_that.displayName,_that.humanPrincipalId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiActorSnapshot implements AiActorSnapshot {
  const _AiActorSnapshot({required this.type, required this.id, required this.displayName, this.humanPrincipalId});
  factory _AiActorSnapshot.fromJson(Map<String, dynamic> json) => _$AiActorSnapshotFromJson(json);

@override final  AiActorType type;
@override final  String id;
@override final  String displayName;
@override final  String? humanPrincipalId;

/// Create a copy of AiActorSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiActorSnapshotCopyWith<_AiActorSnapshot> get copyWith => __$AiActorSnapshotCopyWithImpl<_AiActorSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiActorSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiActorSnapshot&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.humanPrincipalId, humanPrincipalId) || other.humanPrincipalId == humanPrincipalId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,displayName,humanPrincipalId);

@override
String toString() {
  return 'AiActorSnapshot(type: $type, id: $id, displayName: $displayName, humanPrincipalId: $humanPrincipalId)';
}


}

/// @nodoc
abstract mixin class _$AiActorSnapshotCopyWith<$Res> implements $AiActorSnapshotCopyWith<$Res> {
  factory _$AiActorSnapshotCopyWith(_AiActorSnapshot value, $Res Function(_AiActorSnapshot) _then) = __$AiActorSnapshotCopyWithImpl;
@override @useResult
$Res call({
 AiActorType type, String id, String displayName, String? humanPrincipalId
});




}
/// @nodoc
class __$AiActorSnapshotCopyWithImpl<$Res>
    implements _$AiActorSnapshotCopyWith<$Res> {
  __$AiActorSnapshotCopyWithImpl(this._self, this._then);

  final _AiActorSnapshot _self;
  final $Res Function(_AiActorSnapshot) _then;

/// Create a copy of AiActorSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = null,Object? displayName = null,Object? humanPrincipalId = freezed,}) {
  return _then(_AiActorSnapshot(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiActorType,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,humanPrincipalId: freezed == humanPrincipalId ? _self.humanPrincipalId : humanPrincipalId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AiTriggerSnapshot {

 AiTriggerType get type; String? get skillId; String? get promptId; String? get profileId; String? get agentId; String? get wakeRunKey; String? get automationRuleId;
/// Create a copy of AiTriggerSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<AiTriggerSnapshot> get copyWith => _$AiTriggerSnapshotCopyWithImpl<AiTriggerSnapshot>(this as AiTriggerSnapshot, _$identity);

  /// Serializes this AiTriggerSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiTriggerSnapshot&&(identical(other.type, type) || other.type == type)&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.promptId, promptId) || other.promptId == promptId)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.wakeRunKey, wakeRunKey) || other.wakeRunKey == wakeRunKey)&&(identical(other.automationRuleId, automationRuleId) || other.automationRuleId == automationRuleId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,skillId,promptId,profileId,agentId,wakeRunKey,automationRuleId);

@override
String toString() {
  return 'AiTriggerSnapshot(type: $type, skillId: $skillId, promptId: $promptId, profileId: $profileId, agentId: $agentId, wakeRunKey: $wakeRunKey, automationRuleId: $automationRuleId)';
}


}

/// @nodoc
abstract mixin class $AiTriggerSnapshotCopyWith<$Res>  {
  factory $AiTriggerSnapshotCopyWith(AiTriggerSnapshot value, $Res Function(AiTriggerSnapshot) _then) = _$AiTriggerSnapshotCopyWithImpl;
@useResult
$Res call({
 AiTriggerType type, String? skillId, String? promptId, String? profileId, String? agentId, String? wakeRunKey, String? automationRuleId
});




}
/// @nodoc
class _$AiTriggerSnapshotCopyWithImpl<$Res>
    implements $AiTriggerSnapshotCopyWith<$Res> {
  _$AiTriggerSnapshotCopyWithImpl(this._self, this._then);

  final AiTriggerSnapshot _self;
  final $Res Function(AiTriggerSnapshot) _then;

/// Create a copy of AiTriggerSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? skillId = freezed,Object? promptId = freezed,Object? profileId = freezed,Object? agentId = freezed,Object? wakeRunKey = freezed,Object? automationRuleId = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiTriggerType,skillId: freezed == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as String?,promptId: freezed == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,wakeRunKey: freezed == wakeRunKey ? _self.wakeRunKey : wakeRunKey // ignore: cast_nullable_to_non_nullable
as String?,automationRuleId: freezed == automationRuleId ? _self.automationRuleId : automationRuleId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiTriggerSnapshot].
extension AiTriggerSnapshotPatterns on AiTriggerSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiTriggerSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiTriggerSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiTriggerSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _AiTriggerSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiTriggerSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _AiTriggerSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AiTriggerType type,  String? skillId,  String? promptId,  String? profileId,  String? agentId,  String? wakeRunKey,  String? automationRuleId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiTriggerSnapshot() when $default != null:
return $default(_that.type,_that.skillId,_that.promptId,_that.profileId,_that.agentId,_that.wakeRunKey,_that.automationRuleId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AiTriggerType type,  String? skillId,  String? promptId,  String? profileId,  String? agentId,  String? wakeRunKey,  String? automationRuleId)  $default,) {final _that = this;
switch (_that) {
case _AiTriggerSnapshot():
return $default(_that.type,_that.skillId,_that.promptId,_that.profileId,_that.agentId,_that.wakeRunKey,_that.automationRuleId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AiTriggerType type,  String? skillId,  String? promptId,  String? profileId,  String? agentId,  String? wakeRunKey,  String? automationRuleId)?  $default,) {final _that = this;
switch (_that) {
case _AiTriggerSnapshot() when $default != null:
return $default(_that.type,_that.skillId,_that.promptId,_that.profileId,_that.agentId,_that.wakeRunKey,_that.automationRuleId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiTriggerSnapshot implements AiTriggerSnapshot {
  const _AiTriggerSnapshot({required this.type, this.skillId, this.promptId, this.profileId, this.agentId, this.wakeRunKey, this.automationRuleId});
  factory _AiTriggerSnapshot.fromJson(Map<String, dynamic> json) => _$AiTriggerSnapshotFromJson(json);

@override final  AiTriggerType type;
@override final  String? skillId;
@override final  String? promptId;
@override final  String? profileId;
@override final  String? agentId;
@override final  String? wakeRunKey;
@override final  String? automationRuleId;

/// Create a copy of AiTriggerSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiTriggerSnapshotCopyWith<_AiTriggerSnapshot> get copyWith => __$AiTriggerSnapshotCopyWithImpl<_AiTriggerSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiTriggerSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiTriggerSnapshot&&(identical(other.type, type) || other.type == type)&&(identical(other.skillId, skillId) || other.skillId == skillId)&&(identical(other.promptId, promptId) || other.promptId == promptId)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.wakeRunKey, wakeRunKey) || other.wakeRunKey == wakeRunKey)&&(identical(other.automationRuleId, automationRuleId) || other.automationRuleId == automationRuleId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,skillId,promptId,profileId,agentId,wakeRunKey,automationRuleId);

@override
String toString() {
  return 'AiTriggerSnapshot(type: $type, skillId: $skillId, promptId: $promptId, profileId: $profileId, agentId: $agentId, wakeRunKey: $wakeRunKey, automationRuleId: $automationRuleId)';
}


}

/// @nodoc
abstract mixin class _$AiTriggerSnapshotCopyWith<$Res> implements $AiTriggerSnapshotCopyWith<$Res> {
  factory _$AiTriggerSnapshotCopyWith(_AiTriggerSnapshot value, $Res Function(_AiTriggerSnapshot) _then) = __$AiTriggerSnapshotCopyWithImpl;
@override @useResult
$Res call({
 AiTriggerType type, String? skillId, String? promptId, String? profileId, String? agentId, String? wakeRunKey, String? automationRuleId
});




}
/// @nodoc
class __$AiTriggerSnapshotCopyWithImpl<$Res>
    implements _$AiTriggerSnapshotCopyWith<$Res> {
  __$AiTriggerSnapshotCopyWithImpl(this._self, this._then);

  final _AiTriggerSnapshot _self;
  final $Res Function(_AiTriggerSnapshot) _then;

/// Create a copy of AiTriggerSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? skillId = freezed,Object? promptId = freezed,Object? profileId = freezed,Object? agentId = freezed,Object? wakeRunKey = freezed,Object? automationRuleId = freezed,}) {
  return _then(_AiTriggerSnapshot(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiTriggerType,skillId: freezed == skillId ? _self.skillId : skillId // ignore: cast_nullable_to_non_nullable
as String?,promptId: freezed == promptId ? _self.promptId : promptId // ignore: cast_nullable_to_non_nullable
as String?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,agentId: freezed == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String?,wakeRunKey: freezed == wakeRunKey ? _self.wakeRunKey : wakeRunKey // ignore: cast_nullable_to_non_nullable
as String?,automationRuleId: freezed == automationRuleId ? _self.automationRuleId : automationRuleId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AiExecutorSnapshot {

 String get hostId; String get displayName; String? get appVersion;
/// Create a copy of AiExecutorSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiExecutorSnapshotCopyWith<AiExecutorSnapshot> get copyWith => _$AiExecutorSnapshotCopyWithImpl<AiExecutorSnapshot>(this as AiExecutorSnapshot, _$identity);

  /// Serializes this AiExecutorSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiExecutorSnapshot&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hostId,displayName,appVersion);

@override
String toString() {
  return 'AiExecutorSnapshot(hostId: $hostId, displayName: $displayName, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class $AiExecutorSnapshotCopyWith<$Res>  {
  factory $AiExecutorSnapshotCopyWith(AiExecutorSnapshot value, $Res Function(AiExecutorSnapshot) _then) = _$AiExecutorSnapshotCopyWithImpl;
@useResult
$Res call({
 String hostId, String displayName, String? appVersion
});




}
/// @nodoc
class _$AiExecutorSnapshotCopyWithImpl<$Res>
    implements $AiExecutorSnapshotCopyWith<$Res> {
  _$AiExecutorSnapshotCopyWithImpl(this._self, this._then);

  final AiExecutorSnapshot _self;
  final $Res Function(AiExecutorSnapshot) _then;

/// Create a copy of AiExecutorSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostId = null,Object? displayName = null,Object? appVersion = freezed,}) {
  return _then(_self.copyWith(
hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiExecutorSnapshot].
extension AiExecutorSnapshotPatterns on AiExecutorSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiExecutorSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiExecutorSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiExecutorSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _AiExecutorSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiExecutorSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _AiExecutorSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hostId,  String displayName,  String? appVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiExecutorSnapshot() when $default != null:
return $default(_that.hostId,_that.displayName,_that.appVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hostId,  String displayName,  String? appVersion)  $default,) {final _that = this;
switch (_that) {
case _AiExecutorSnapshot():
return $default(_that.hostId,_that.displayName,_that.appVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hostId,  String displayName,  String? appVersion)?  $default,) {final _that = this;
switch (_that) {
case _AiExecutorSnapshot() when $default != null:
return $default(_that.hostId,_that.displayName,_that.appVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiExecutorSnapshot implements AiExecutorSnapshot {
  const _AiExecutorSnapshot({required this.hostId, required this.displayName, this.appVersion});
  factory _AiExecutorSnapshot.fromJson(Map<String, dynamic> json) => _$AiExecutorSnapshotFromJson(json);

@override final  String hostId;
@override final  String displayName;
@override final  String? appVersion;

/// Create a copy of AiExecutorSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiExecutorSnapshotCopyWith<_AiExecutorSnapshot> get copyWith => __$AiExecutorSnapshotCopyWithImpl<_AiExecutorSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiExecutorSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiExecutorSnapshot&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hostId,displayName,appVersion);

@override
String toString() {
  return 'AiExecutorSnapshot(hostId: $hostId, displayName: $displayName, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class _$AiExecutorSnapshotCopyWith<$Res> implements $AiExecutorSnapshotCopyWith<$Res> {
  factory _$AiExecutorSnapshotCopyWith(_AiExecutorSnapshot value, $Res Function(_AiExecutorSnapshot) _then) = __$AiExecutorSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String hostId, String displayName, String? appVersion
});




}
/// @nodoc
class __$AiExecutorSnapshotCopyWithImpl<$Res>
    implements _$AiExecutorSnapshotCopyWith<$Res> {
  __$AiExecutorSnapshotCopyWithImpl(this._self, this._then);

  final _AiExecutorSnapshot _self;
  final $Res Function(_AiExecutorSnapshot) _then;

/// Create a copy of AiExecutorSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostId = null,Object? displayName = null,Object? appVersion = freezed,}) {
  return _then(_AiExecutorSnapshot(
hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AiArtifactReference {

 AiArtifactType get type; String get id; String? get subId;
/// Create a copy of AiArtifactReference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiArtifactReferenceCopyWith<AiArtifactReference> get copyWith => _$AiArtifactReferenceCopyWithImpl<AiArtifactReference>(this as AiArtifactReference, _$identity);

  /// Serializes this AiArtifactReference to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiArtifactReference&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.subId, subId) || other.subId == subId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,subId);

@override
String toString() {
  return 'AiArtifactReference(type: $type, id: $id, subId: $subId)';
}


}

/// @nodoc
abstract mixin class $AiArtifactReferenceCopyWith<$Res>  {
  factory $AiArtifactReferenceCopyWith(AiArtifactReference value, $Res Function(AiArtifactReference) _then) = _$AiArtifactReferenceCopyWithImpl;
@useResult
$Res call({
 AiArtifactType type, String id, String? subId
});




}
/// @nodoc
class _$AiArtifactReferenceCopyWithImpl<$Res>
    implements $AiArtifactReferenceCopyWith<$Res> {
  _$AiArtifactReferenceCopyWithImpl(this._self, this._then);

  final AiArtifactReference _self;
  final $Res Function(AiArtifactReference) _then;

/// Create a copy of AiArtifactReference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? id = null,Object? subId = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiArtifactType,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subId: freezed == subId ? _self.subId : subId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiArtifactReference].
extension AiArtifactReferencePatterns on AiArtifactReference {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiArtifactReference value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiArtifactReference() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiArtifactReference value)  $default,){
final _that = this;
switch (_that) {
case _AiArtifactReference():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiArtifactReference value)?  $default,){
final _that = this;
switch (_that) {
case _AiArtifactReference() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AiArtifactType type,  String id,  String? subId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiArtifactReference() when $default != null:
return $default(_that.type,_that.id,_that.subId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AiArtifactType type,  String id,  String? subId)  $default,) {final _that = this;
switch (_that) {
case _AiArtifactReference():
return $default(_that.type,_that.id,_that.subId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AiArtifactType type,  String id,  String? subId)?  $default,) {final _that = this;
switch (_that) {
case _AiArtifactReference() when $default != null:
return $default(_that.type,_that.id,_that.subId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiArtifactReference implements AiArtifactReference {
  const _AiArtifactReference({required this.type, required this.id, this.subId});
  factory _AiArtifactReference.fromJson(Map<String, dynamic> json) => _$AiArtifactReferenceFromJson(json);

@override final  AiArtifactType type;
@override final  String id;
@override final  String? subId;

/// Create a copy of AiArtifactReference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiArtifactReferenceCopyWith<_AiArtifactReference> get copyWith => __$AiArtifactReferenceCopyWithImpl<_AiArtifactReference>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiArtifactReferenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiArtifactReference&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.subId, subId) || other.subId == subId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,id,subId);

@override
String toString() {
  return 'AiArtifactReference(type: $type, id: $id, subId: $subId)';
}


}

/// @nodoc
abstract mixin class _$AiArtifactReferenceCopyWith<$Res> implements $AiArtifactReferenceCopyWith<$Res> {
  factory _$AiArtifactReferenceCopyWith(_AiArtifactReference value, $Res Function(_AiArtifactReference) _then) = __$AiArtifactReferenceCopyWithImpl;
@override @useResult
$Res call({
 AiArtifactType type, String id, String? subId
});




}
/// @nodoc
class __$AiArtifactReferenceCopyWithImpl<$Res>
    implements _$AiArtifactReferenceCopyWith<$Res> {
  __$AiArtifactReferenceCopyWithImpl(this._self, this._then);

  final _AiArtifactReference _self;
  final $Res Function(_AiArtifactReference) _then;

/// Create a copy of AiArtifactReference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? id = null,Object? subId = freezed,}) {
  return _then(_AiArtifactReference(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiArtifactType,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subId: freezed == subId ? _self.subId : subId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AiAttributionLink {

 String get id; String get attributionId; AiAttributionLinkRole get role; AiArtifactReference get artifact; String? get contentDigest;
/// Create a copy of AiAttributionLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiAttributionLinkCopyWith<AiAttributionLink> get copyWith => _$AiAttributionLinkCopyWithImpl<AiAttributionLink>(this as AiAttributionLink, _$identity);

  /// Serializes this AiAttributionLink to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiAttributionLink&&(identical(other.id, id) || other.id == id)&&(identical(other.attributionId, attributionId) || other.attributionId == attributionId)&&(identical(other.role, role) || other.role == role)&&(identical(other.artifact, artifact) || other.artifact == artifact)&&(identical(other.contentDigest, contentDigest) || other.contentDigest == contentDigest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attributionId,role,artifact,contentDigest);

@override
String toString() {
  return 'AiAttributionLink(id: $id, attributionId: $attributionId, role: $role, artifact: $artifact, contentDigest: $contentDigest)';
}


}

/// @nodoc
abstract mixin class $AiAttributionLinkCopyWith<$Res>  {
  factory $AiAttributionLinkCopyWith(AiAttributionLink value, $Res Function(AiAttributionLink) _then) = _$AiAttributionLinkCopyWithImpl;
@useResult
$Res call({
 String id, String attributionId, AiAttributionLinkRole role, AiArtifactReference artifact, String? contentDigest
});


$AiArtifactReferenceCopyWith<$Res> get artifact;

}
/// @nodoc
class _$AiAttributionLinkCopyWithImpl<$Res>
    implements $AiAttributionLinkCopyWith<$Res> {
  _$AiAttributionLinkCopyWithImpl(this._self, this._then);

  final AiAttributionLink _self;
  final $Res Function(AiAttributionLink) _then;

/// Create a copy of AiAttributionLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? attributionId = null,Object? role = null,Object? artifact = null,Object? contentDigest = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attributionId: null == attributionId ? _self.attributionId : attributionId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AiAttributionLinkRole,artifact: null == artifact ? _self.artifact : artifact // ignore: cast_nullable_to_non_nullable
as AiArtifactReference,contentDigest: freezed == contentDigest ? _self.contentDigest : contentDigest // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AiAttributionLink
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiArtifactReferenceCopyWith<$Res> get artifact {
  
  return $AiArtifactReferenceCopyWith<$Res>(_self.artifact, (value) {
    return _then(_self.copyWith(artifact: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiAttributionLink].
extension AiAttributionLinkPatterns on AiAttributionLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiAttributionLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiAttributionLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiAttributionLink value)  $default,){
final _that = this;
switch (_that) {
case _AiAttributionLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiAttributionLink value)?  $default,){
final _that = this;
switch (_that) {
case _AiAttributionLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String attributionId,  AiAttributionLinkRole role,  AiArtifactReference artifact,  String? contentDigest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiAttributionLink() when $default != null:
return $default(_that.id,_that.attributionId,_that.role,_that.artifact,_that.contentDigest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String attributionId,  AiAttributionLinkRole role,  AiArtifactReference artifact,  String? contentDigest)  $default,) {final _that = this;
switch (_that) {
case _AiAttributionLink():
return $default(_that.id,_that.attributionId,_that.role,_that.artifact,_that.contentDigest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String attributionId,  AiAttributionLinkRole role,  AiArtifactReference artifact,  String? contentDigest)?  $default,) {final _that = this;
switch (_that) {
case _AiAttributionLink() when $default != null:
return $default(_that.id,_that.attributionId,_that.role,_that.artifact,_that.contentDigest);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiAttributionLink implements AiAttributionLink {
  const _AiAttributionLink({required this.id, required this.attributionId, required this.role, required this.artifact, this.contentDigest});
  factory _AiAttributionLink.fromJson(Map<String, dynamic> json) => _$AiAttributionLinkFromJson(json);

@override final  String id;
@override final  String attributionId;
@override final  AiAttributionLinkRole role;
@override final  AiArtifactReference artifact;
@override final  String? contentDigest;

/// Create a copy of AiAttributionLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiAttributionLinkCopyWith<_AiAttributionLink> get copyWith => __$AiAttributionLinkCopyWithImpl<_AiAttributionLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiAttributionLinkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiAttributionLink&&(identical(other.id, id) || other.id == id)&&(identical(other.attributionId, attributionId) || other.attributionId == attributionId)&&(identical(other.role, role) || other.role == role)&&(identical(other.artifact, artifact) || other.artifact == artifact)&&(identical(other.contentDigest, contentDigest) || other.contentDigest == contentDigest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attributionId,role,artifact,contentDigest);

@override
String toString() {
  return 'AiAttributionLink(id: $id, attributionId: $attributionId, role: $role, artifact: $artifact, contentDigest: $contentDigest)';
}


}

/// @nodoc
abstract mixin class _$AiAttributionLinkCopyWith<$Res> implements $AiAttributionLinkCopyWith<$Res> {
  factory _$AiAttributionLinkCopyWith(_AiAttributionLink value, $Res Function(_AiAttributionLink) _then) = __$AiAttributionLinkCopyWithImpl;
@override @useResult
$Res call({
 String id, String attributionId, AiAttributionLinkRole role, AiArtifactReference artifact, String? contentDigest
});


@override $AiArtifactReferenceCopyWith<$Res> get artifact;

}
/// @nodoc
class __$AiAttributionLinkCopyWithImpl<$Res>
    implements _$AiAttributionLinkCopyWith<$Res> {
  __$AiAttributionLinkCopyWithImpl(this._self, this._then);

  final _AiAttributionLink _self;
  final $Res Function(_AiAttributionLink) _then;

/// Create a copy of AiAttributionLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? attributionId = null,Object? role = null,Object? artifact = null,Object? contentDigest = freezed,}) {
  return _then(_AiAttributionLink(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attributionId: null == attributionId ? _self.attributionId : attributionId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AiAttributionLinkRole,artifact: null == artifact ? _self.artifact : artifact // ignore: cast_nullable_to_non_nullable
as AiArtifactReference,contentDigest: freezed == contentDigest ? _self.contentDigest : contentDigest // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AiAttributionLink
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiArtifactReferenceCopyWith<$Res> get artifact {
  
  return $AiArtifactReferenceCopyWith<$Res>(_self.artifact, (value) {
    return _then(_self.copyWith(artifact: value));
  });
}
}


/// @nodoc
mixin _$AiContentPart {

 AiContentPartType get type; String? get text; String? get name; Map<String, dynamic>? get arguments; AiArtifactReference? get attachment; String? get mediaType; String? get sha256; int? get byteLength;
/// Create a copy of AiContentPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiContentPartCopyWith<AiContentPart> get copyWith => _$AiContentPartCopyWithImpl<AiContentPart>(this as AiContentPart, _$identity);

  /// Serializes this AiContentPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiContentPart&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.attachment, attachment) || other.attachment == attachment)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.byteLength, byteLength) || other.byteLength == byteLength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text,name,const DeepCollectionEquality().hash(arguments),attachment,mediaType,sha256,byteLength);

@override
String toString() {
  return 'AiContentPart(type: $type, text: $text, name: $name, arguments: $arguments, attachment: $attachment, mediaType: $mediaType, sha256: $sha256, byteLength: $byteLength)';
}


}

/// @nodoc
abstract mixin class $AiContentPartCopyWith<$Res>  {
  factory $AiContentPartCopyWith(AiContentPart value, $Res Function(AiContentPart) _then) = _$AiContentPartCopyWithImpl;
@useResult
$Res call({
 AiContentPartType type, String? text, String? name, Map<String, dynamic>? arguments, AiArtifactReference? attachment, String? mediaType, String? sha256, int? byteLength
});


$AiArtifactReferenceCopyWith<$Res>? get attachment;

}
/// @nodoc
class _$AiContentPartCopyWithImpl<$Res>
    implements $AiContentPartCopyWith<$Res> {
  _$AiContentPartCopyWithImpl(this._self, this._then);

  final AiContentPart _self;
  final $Res Function(AiContentPart) _then;

/// Create a copy of AiContentPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? text = freezed,Object? name = freezed,Object? arguments = freezed,Object? attachment = freezed,Object? mediaType = freezed,Object? sha256 = freezed,Object? byteLength = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiContentPartType,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,attachment: freezed == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as AiArtifactReference?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,byteLength: freezed == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of AiContentPart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiArtifactReferenceCopyWith<$Res>? get attachment {
    if (_self.attachment == null) {
    return null;
  }

  return $AiArtifactReferenceCopyWith<$Res>(_self.attachment!, (value) {
    return _then(_self.copyWith(attachment: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiContentPart].
extension AiContentPartPatterns on AiContentPart {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiContentPart value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiContentPart() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiContentPart value)  $default,){
final _that = this;
switch (_that) {
case _AiContentPart():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiContentPart value)?  $default,){
final _that = this;
switch (_that) {
case _AiContentPart() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AiContentPartType type,  String? text,  String? name,  Map<String, dynamic>? arguments,  AiArtifactReference? attachment,  String? mediaType,  String? sha256,  int? byteLength)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiContentPart() when $default != null:
return $default(_that.type,_that.text,_that.name,_that.arguments,_that.attachment,_that.mediaType,_that.sha256,_that.byteLength);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AiContentPartType type,  String? text,  String? name,  Map<String, dynamic>? arguments,  AiArtifactReference? attachment,  String? mediaType,  String? sha256,  int? byteLength)  $default,) {final _that = this;
switch (_that) {
case _AiContentPart():
return $default(_that.type,_that.text,_that.name,_that.arguments,_that.attachment,_that.mediaType,_that.sha256,_that.byteLength);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AiContentPartType type,  String? text,  String? name,  Map<String, dynamic>? arguments,  AiArtifactReference? attachment,  String? mediaType,  String? sha256,  int? byteLength)?  $default,) {final _that = this;
switch (_that) {
case _AiContentPart() when $default != null:
return $default(_that.type,_that.text,_that.name,_that.arguments,_that.attachment,_that.mediaType,_that.sha256,_that.byteLength);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiContentPart implements AiContentPart {
  const _AiContentPart({required this.type, this.text, this.name, final  Map<String, dynamic>? arguments, this.attachment, this.mediaType, this.sha256, this.byteLength}): _arguments = arguments;
  factory _AiContentPart.fromJson(Map<String, dynamic> json) => _$AiContentPartFromJson(json);

@override final  AiContentPartType type;
@override final  String? text;
@override final  String? name;
 final  Map<String, dynamic>? _arguments;
@override Map<String, dynamic>? get arguments {
  final value = _arguments;
  if (value == null) return null;
  if (_arguments is EqualUnmodifiableMapView) return _arguments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  AiArtifactReference? attachment;
@override final  String? mediaType;
@override final  String? sha256;
@override final  int? byteLength;

/// Create a copy of AiContentPart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiContentPartCopyWith<_AiContentPart> get copyWith => __$AiContentPartCopyWithImpl<_AiContentPart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiContentPartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiContentPart&&(identical(other.type, type) || other.type == type)&&(identical(other.text, text) || other.text == text)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._arguments, _arguments)&&(identical(other.attachment, attachment) || other.attachment == attachment)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.byteLength, byteLength) || other.byteLength == byteLength));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,text,name,const DeepCollectionEquality().hash(_arguments),attachment,mediaType,sha256,byteLength);

@override
String toString() {
  return 'AiContentPart(type: $type, text: $text, name: $name, arguments: $arguments, attachment: $attachment, mediaType: $mediaType, sha256: $sha256, byteLength: $byteLength)';
}


}

/// @nodoc
abstract mixin class _$AiContentPartCopyWith<$Res> implements $AiContentPartCopyWith<$Res> {
  factory _$AiContentPartCopyWith(_AiContentPart value, $Res Function(_AiContentPart) _then) = __$AiContentPartCopyWithImpl;
@override @useResult
$Res call({
 AiContentPartType type, String? text, String? name, Map<String, dynamic>? arguments, AiArtifactReference? attachment, String? mediaType, String? sha256, int? byteLength
});


@override $AiArtifactReferenceCopyWith<$Res>? get attachment;

}
/// @nodoc
class __$AiContentPartCopyWithImpl<$Res>
    implements _$AiContentPartCopyWith<$Res> {
  __$AiContentPartCopyWithImpl(this._self, this._then);

  final _AiContentPart _self;
  final $Res Function(_AiContentPart) _then;

/// Create a copy of AiContentPart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? text = freezed,Object? name = freezed,Object? arguments = freezed,Object? attachment = freezed,Object? mediaType = freezed,Object? sha256 = freezed,Object? byteLength = freezed,}) {
  return _then(_AiContentPart(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as AiContentPartType,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,arguments: freezed == arguments ? _self._arguments : arguments // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,attachment: freezed == attachment ? _self.attachment : attachment // ignore: cast_nullable_to_non_nullable
as AiArtifactReference?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,sha256: freezed == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String?,byteLength: freezed == byteLength ? _self.byteLength : byteLength // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of AiContentPart
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiArtifactReferenceCopyWith<$Res>? get attachment {
    if (_self.attachment == null) {
    return null;
  }

  return $AiArtifactReferenceCopyWith<$Res>(_self.attachment!, (value) {
    return _then(_self.copyWith(attachment: value));
  });
}
}


/// @nodoc
mixin _$AiInteractionPayload {

 String get id; String get interactionId; List<AiContentPart> get request; List<AiContentPart> get response; Map<String, dynamic> get parameters; String get requestDigest; String get responseDigest; AiPayloadCapturePolicy get capturePolicy; AiPrivacyClassification get privacyClassification; DateTime get createdAt; Map<String, dynamic>? get providerMetadata;
/// Create a copy of AiInteractionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiInteractionPayloadCopyWith<AiInteractionPayload> get copyWith => _$AiInteractionPayloadCopyWithImpl<AiInteractionPayload>(this as AiInteractionPayload, _$identity);

  /// Serializes this AiInteractionPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiInteractionPayload&&(identical(other.id, id) || other.id == id)&&(identical(other.interactionId, interactionId) || other.interactionId == interactionId)&&const DeepCollectionEquality().equals(other.request, request)&&const DeepCollectionEquality().equals(other.response, response)&&const DeepCollectionEquality().equals(other.parameters, parameters)&&(identical(other.requestDigest, requestDigest) || other.requestDigest == requestDigest)&&(identical(other.responseDigest, responseDigest) || other.responseDigest == responseDigest)&&(identical(other.capturePolicy, capturePolicy) || other.capturePolicy == capturePolicy)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.providerMetadata, providerMetadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,interactionId,const DeepCollectionEquality().hash(request),const DeepCollectionEquality().hash(response),const DeepCollectionEquality().hash(parameters),requestDigest,responseDigest,capturePolicy,privacyClassification,createdAt,const DeepCollectionEquality().hash(providerMetadata));

@override
String toString() {
  return 'AiInteractionPayload(id: $id, interactionId: $interactionId, request: $request, response: $response, parameters: $parameters, requestDigest: $requestDigest, responseDigest: $responseDigest, capturePolicy: $capturePolicy, privacyClassification: $privacyClassification, createdAt: $createdAt, providerMetadata: $providerMetadata)';
}


}

/// @nodoc
abstract mixin class $AiInteractionPayloadCopyWith<$Res>  {
  factory $AiInteractionPayloadCopyWith(AiInteractionPayload value, $Res Function(AiInteractionPayload) _then) = _$AiInteractionPayloadCopyWithImpl;
@useResult
$Res call({
 String id, String interactionId, List<AiContentPart> request, List<AiContentPart> response, Map<String, dynamic> parameters, String requestDigest, String responseDigest, AiPayloadCapturePolicy capturePolicy, AiPrivacyClassification privacyClassification, DateTime createdAt, Map<String, dynamic>? providerMetadata
});




}
/// @nodoc
class _$AiInteractionPayloadCopyWithImpl<$Res>
    implements $AiInteractionPayloadCopyWith<$Res> {
  _$AiInteractionPayloadCopyWithImpl(this._self, this._then);

  final AiInteractionPayload _self;
  final $Res Function(AiInteractionPayload) _then;

/// Create a copy of AiInteractionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? interactionId = null,Object? request = null,Object? response = null,Object? parameters = null,Object? requestDigest = null,Object? responseDigest = null,Object? capturePolicy = null,Object? privacyClassification = null,Object? createdAt = null,Object? providerMetadata = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,interactionId: null == interactionId ? _self.interactionId : interactionId // ignore: cast_nullable_to_non_nullable
as String,request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as List<AiContentPart>,response: null == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as List<AiContentPart>,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,requestDigest: null == requestDigest ? _self.requestDigest : requestDigest // ignore: cast_nullable_to_non_nullable
as String,responseDigest: null == responseDigest ? _self.responseDigest : responseDigest // ignore: cast_nullable_to_non_nullable
as String,capturePolicy: null == capturePolicy ? _self.capturePolicy : capturePolicy // ignore: cast_nullable_to_non_nullable
as AiPayloadCapturePolicy,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,providerMetadata: freezed == providerMetadata ? _self.providerMetadata : providerMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiInteractionPayload].
extension AiInteractionPayloadPatterns on AiInteractionPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiInteractionPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiInteractionPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiInteractionPayload value)  $default,){
final _that = this;
switch (_that) {
case _AiInteractionPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiInteractionPayload value)?  $default,){
final _that = this;
switch (_that) {
case _AiInteractionPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String interactionId,  List<AiContentPart> request,  List<AiContentPart> response,  Map<String, dynamic> parameters,  String requestDigest,  String responseDigest,  AiPayloadCapturePolicy capturePolicy,  AiPrivacyClassification privacyClassification,  DateTime createdAt,  Map<String, dynamic>? providerMetadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiInteractionPayload() when $default != null:
return $default(_that.id,_that.interactionId,_that.request,_that.response,_that.parameters,_that.requestDigest,_that.responseDigest,_that.capturePolicy,_that.privacyClassification,_that.createdAt,_that.providerMetadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String interactionId,  List<AiContentPart> request,  List<AiContentPart> response,  Map<String, dynamic> parameters,  String requestDigest,  String responseDigest,  AiPayloadCapturePolicy capturePolicy,  AiPrivacyClassification privacyClassification,  DateTime createdAt,  Map<String, dynamic>? providerMetadata)  $default,) {final _that = this;
switch (_that) {
case _AiInteractionPayload():
return $default(_that.id,_that.interactionId,_that.request,_that.response,_that.parameters,_that.requestDigest,_that.responseDigest,_that.capturePolicy,_that.privacyClassification,_that.createdAt,_that.providerMetadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String interactionId,  List<AiContentPart> request,  List<AiContentPart> response,  Map<String, dynamic> parameters,  String requestDigest,  String responseDigest,  AiPayloadCapturePolicy capturePolicy,  AiPrivacyClassification privacyClassification,  DateTime createdAt,  Map<String, dynamic>? providerMetadata)?  $default,) {final _that = this;
switch (_that) {
case _AiInteractionPayload() when $default != null:
return $default(_that.id,_that.interactionId,_that.request,_that.response,_that.parameters,_that.requestDigest,_that.responseDigest,_that.capturePolicy,_that.privacyClassification,_that.createdAt,_that.providerMetadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiInteractionPayload implements AiInteractionPayload {
  const _AiInteractionPayload({required this.id, required this.interactionId, required final  List<AiContentPart> request, required final  List<AiContentPart> response, required final  Map<String, dynamic> parameters, required this.requestDigest, required this.responseDigest, required this.capturePolicy, required this.privacyClassification, required this.createdAt, final  Map<String, dynamic>? providerMetadata}): _request = request,_response = response,_parameters = parameters,_providerMetadata = providerMetadata;
  factory _AiInteractionPayload.fromJson(Map<String, dynamic> json) => _$AiInteractionPayloadFromJson(json);

@override final  String id;
@override final  String interactionId;
 final  List<AiContentPart> _request;
@override List<AiContentPart> get request {
  if (_request is EqualUnmodifiableListView) return _request;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_request);
}

 final  List<AiContentPart> _response;
@override List<AiContentPart> get response {
  if (_response is EqualUnmodifiableListView) return _response;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_response);
}

 final  Map<String, dynamic> _parameters;
@override Map<String, dynamic> get parameters {
  if (_parameters is EqualUnmodifiableMapView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_parameters);
}

@override final  String requestDigest;
@override final  String responseDigest;
@override final  AiPayloadCapturePolicy capturePolicy;
@override final  AiPrivacyClassification privacyClassification;
@override final  DateTime createdAt;
 final  Map<String, dynamic>? _providerMetadata;
@override Map<String, dynamic>? get providerMetadata {
  final value = _providerMetadata;
  if (value == null) return null;
  if (_providerMetadata is EqualUnmodifiableMapView) return _providerMetadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of AiInteractionPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiInteractionPayloadCopyWith<_AiInteractionPayload> get copyWith => __$AiInteractionPayloadCopyWithImpl<_AiInteractionPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiInteractionPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiInteractionPayload&&(identical(other.id, id) || other.id == id)&&(identical(other.interactionId, interactionId) || other.interactionId == interactionId)&&const DeepCollectionEquality().equals(other._request, _request)&&const DeepCollectionEquality().equals(other._response, _response)&&const DeepCollectionEquality().equals(other._parameters, _parameters)&&(identical(other.requestDigest, requestDigest) || other.requestDigest == requestDigest)&&(identical(other.responseDigest, responseDigest) || other.responseDigest == responseDigest)&&(identical(other.capturePolicy, capturePolicy) || other.capturePolicy == capturePolicy)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._providerMetadata, _providerMetadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,interactionId,const DeepCollectionEquality().hash(_request),const DeepCollectionEquality().hash(_response),const DeepCollectionEquality().hash(_parameters),requestDigest,responseDigest,capturePolicy,privacyClassification,createdAt,const DeepCollectionEquality().hash(_providerMetadata));

@override
String toString() {
  return 'AiInteractionPayload(id: $id, interactionId: $interactionId, request: $request, response: $response, parameters: $parameters, requestDigest: $requestDigest, responseDigest: $responseDigest, capturePolicy: $capturePolicy, privacyClassification: $privacyClassification, createdAt: $createdAt, providerMetadata: $providerMetadata)';
}


}

/// @nodoc
abstract mixin class _$AiInteractionPayloadCopyWith<$Res> implements $AiInteractionPayloadCopyWith<$Res> {
  factory _$AiInteractionPayloadCopyWith(_AiInteractionPayload value, $Res Function(_AiInteractionPayload) _then) = __$AiInteractionPayloadCopyWithImpl;
@override @useResult
$Res call({
 String id, String interactionId, List<AiContentPart> request, List<AiContentPart> response, Map<String, dynamic> parameters, String requestDigest, String responseDigest, AiPayloadCapturePolicy capturePolicy, AiPrivacyClassification privacyClassification, DateTime createdAt, Map<String, dynamic>? providerMetadata
});




}
/// @nodoc
class __$AiInteractionPayloadCopyWithImpl<$Res>
    implements _$AiInteractionPayloadCopyWith<$Res> {
  __$AiInteractionPayloadCopyWithImpl(this._self, this._then);

  final _AiInteractionPayload _self;
  final $Res Function(_AiInteractionPayload) _then;

/// Create a copy of AiInteractionPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? interactionId = null,Object? request = null,Object? response = null,Object? parameters = null,Object? requestDigest = null,Object? responseDigest = null,Object? capturePolicy = null,Object? privacyClassification = null,Object? createdAt = null,Object? providerMetadata = freezed,}) {
  return _then(_AiInteractionPayload(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,interactionId: null == interactionId ? _self.interactionId : interactionId // ignore: cast_nullable_to_non_nullable
as String,request: null == request ? _self._request : request // ignore: cast_nullable_to_non_nullable
as List<AiContentPart>,response: null == response ? _self._response : response // ignore: cast_nullable_to_non_nullable
as List<AiContentPart>,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,requestDigest: null == requestDigest ? _self.requestDigest : requestDigest // ignore: cast_nullable_to_non_nullable
as String,responseDigest: null == responseDigest ? _self.responseDigest : responseDigest // ignore: cast_nullable_to_non_nullable
as String,capturePolicy: null == capturePolicy ? _self.capturePolicy : capturePolicy // ignore: cast_nullable_to_non_nullable
as AiPayloadCapturePolicy,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,providerMetadata: freezed == providerMetadata ? _self._providerMetadata : providerMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}


/// @nodoc
mixin _$AiInteractionCost {

 String get id; String get interactionId; AiCostSource get source; DateTime get assessedAt; String? get originalAmountDecimal; String? get originalUnit; int? get reportingAmountMicros; String? get reportingCurrency; String? get supersedesCostId; String? get providerType; String? get billingAccountKey; String? get billingSource; String? get externalRecordId; Map<String, dynamic>? get pricingSnapshot;
/// Create a copy of AiInteractionCost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiInteractionCostCopyWith<AiInteractionCost> get copyWith => _$AiInteractionCostCopyWithImpl<AiInteractionCost>(this as AiInteractionCost, _$identity);

  /// Serializes this AiInteractionCost to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiInteractionCost&&(identical(other.id, id) || other.id == id)&&(identical(other.interactionId, interactionId) || other.interactionId == interactionId)&&(identical(other.source, source) || other.source == source)&&(identical(other.assessedAt, assessedAt) || other.assessedAt == assessedAt)&&(identical(other.originalAmountDecimal, originalAmountDecimal) || other.originalAmountDecimal == originalAmountDecimal)&&(identical(other.originalUnit, originalUnit) || other.originalUnit == originalUnit)&&(identical(other.reportingAmountMicros, reportingAmountMicros) || other.reportingAmountMicros == reportingAmountMicros)&&(identical(other.reportingCurrency, reportingCurrency) || other.reportingCurrency == reportingCurrency)&&(identical(other.supersedesCostId, supersedesCostId) || other.supersedesCostId == supersedesCostId)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.billingAccountKey, billingAccountKey) || other.billingAccountKey == billingAccountKey)&&(identical(other.billingSource, billingSource) || other.billingSource == billingSource)&&(identical(other.externalRecordId, externalRecordId) || other.externalRecordId == externalRecordId)&&const DeepCollectionEquality().equals(other.pricingSnapshot, pricingSnapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,interactionId,source,assessedAt,originalAmountDecimal,originalUnit,reportingAmountMicros,reportingCurrency,supersedesCostId,providerType,billingAccountKey,billingSource,externalRecordId,const DeepCollectionEquality().hash(pricingSnapshot));

@override
String toString() {
  return 'AiInteractionCost(id: $id, interactionId: $interactionId, source: $source, assessedAt: $assessedAt, originalAmountDecimal: $originalAmountDecimal, originalUnit: $originalUnit, reportingAmountMicros: $reportingAmountMicros, reportingCurrency: $reportingCurrency, supersedesCostId: $supersedesCostId, providerType: $providerType, billingAccountKey: $billingAccountKey, billingSource: $billingSource, externalRecordId: $externalRecordId, pricingSnapshot: $pricingSnapshot)';
}


}

/// @nodoc
abstract mixin class $AiInteractionCostCopyWith<$Res>  {
  factory $AiInteractionCostCopyWith(AiInteractionCost value, $Res Function(AiInteractionCost) _then) = _$AiInteractionCostCopyWithImpl;
@useResult
$Res call({
 String id, String interactionId, AiCostSource source, DateTime assessedAt, String? originalAmountDecimal, String? originalUnit, int? reportingAmountMicros, String? reportingCurrency, String? supersedesCostId, String? providerType, String? billingAccountKey, String? billingSource, String? externalRecordId, Map<String, dynamic>? pricingSnapshot
});




}
/// @nodoc
class _$AiInteractionCostCopyWithImpl<$Res>
    implements $AiInteractionCostCopyWith<$Res> {
  _$AiInteractionCostCopyWithImpl(this._self, this._then);

  final AiInteractionCost _self;
  final $Res Function(AiInteractionCost) _then;

/// Create a copy of AiInteractionCost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? interactionId = null,Object? source = null,Object? assessedAt = null,Object? originalAmountDecimal = freezed,Object? originalUnit = freezed,Object? reportingAmountMicros = freezed,Object? reportingCurrency = freezed,Object? supersedesCostId = freezed,Object? providerType = freezed,Object? billingAccountKey = freezed,Object? billingSource = freezed,Object? externalRecordId = freezed,Object? pricingSnapshot = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,interactionId: null == interactionId ? _self.interactionId : interactionId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as AiCostSource,assessedAt: null == assessedAt ? _self.assessedAt : assessedAt // ignore: cast_nullable_to_non_nullable
as DateTime,originalAmountDecimal: freezed == originalAmountDecimal ? _self.originalAmountDecimal : originalAmountDecimal // ignore: cast_nullable_to_non_nullable
as String?,originalUnit: freezed == originalUnit ? _self.originalUnit : originalUnit // ignore: cast_nullable_to_non_nullable
as String?,reportingAmountMicros: freezed == reportingAmountMicros ? _self.reportingAmountMicros : reportingAmountMicros // ignore: cast_nullable_to_non_nullable
as int?,reportingCurrency: freezed == reportingCurrency ? _self.reportingCurrency : reportingCurrency // ignore: cast_nullable_to_non_nullable
as String?,supersedesCostId: freezed == supersedesCostId ? _self.supersedesCostId : supersedesCostId // ignore: cast_nullable_to_non_nullable
as String?,providerType: freezed == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as String?,billingAccountKey: freezed == billingAccountKey ? _self.billingAccountKey : billingAccountKey // ignore: cast_nullable_to_non_nullable
as String?,billingSource: freezed == billingSource ? _self.billingSource : billingSource // ignore: cast_nullable_to_non_nullable
as String?,externalRecordId: freezed == externalRecordId ? _self.externalRecordId : externalRecordId // ignore: cast_nullable_to_non_nullable
as String?,pricingSnapshot: freezed == pricingSnapshot ? _self.pricingSnapshot : pricingSnapshot // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [AiInteractionCost].
extension AiInteractionCostPatterns on AiInteractionCost {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiInteractionCost value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiInteractionCost() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiInteractionCost value)  $default,){
final _that = this;
switch (_that) {
case _AiInteractionCost():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiInteractionCost value)?  $default,){
final _that = this;
switch (_that) {
case _AiInteractionCost() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String interactionId,  AiCostSource source,  DateTime assessedAt,  String? originalAmountDecimal,  String? originalUnit,  int? reportingAmountMicros,  String? reportingCurrency,  String? supersedesCostId,  String? providerType,  String? billingAccountKey,  String? billingSource,  String? externalRecordId,  Map<String, dynamic>? pricingSnapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiInteractionCost() when $default != null:
return $default(_that.id,_that.interactionId,_that.source,_that.assessedAt,_that.originalAmountDecimal,_that.originalUnit,_that.reportingAmountMicros,_that.reportingCurrency,_that.supersedesCostId,_that.providerType,_that.billingAccountKey,_that.billingSource,_that.externalRecordId,_that.pricingSnapshot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String interactionId,  AiCostSource source,  DateTime assessedAt,  String? originalAmountDecimal,  String? originalUnit,  int? reportingAmountMicros,  String? reportingCurrency,  String? supersedesCostId,  String? providerType,  String? billingAccountKey,  String? billingSource,  String? externalRecordId,  Map<String, dynamic>? pricingSnapshot)  $default,) {final _that = this;
switch (_that) {
case _AiInteractionCost():
return $default(_that.id,_that.interactionId,_that.source,_that.assessedAt,_that.originalAmountDecimal,_that.originalUnit,_that.reportingAmountMicros,_that.reportingCurrency,_that.supersedesCostId,_that.providerType,_that.billingAccountKey,_that.billingSource,_that.externalRecordId,_that.pricingSnapshot);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String interactionId,  AiCostSource source,  DateTime assessedAt,  String? originalAmountDecimal,  String? originalUnit,  int? reportingAmountMicros,  String? reportingCurrency,  String? supersedesCostId,  String? providerType,  String? billingAccountKey,  String? billingSource,  String? externalRecordId,  Map<String, dynamic>? pricingSnapshot)?  $default,) {final _that = this;
switch (_that) {
case _AiInteractionCost() when $default != null:
return $default(_that.id,_that.interactionId,_that.source,_that.assessedAt,_that.originalAmountDecimal,_that.originalUnit,_that.reportingAmountMicros,_that.reportingCurrency,_that.supersedesCostId,_that.providerType,_that.billingAccountKey,_that.billingSource,_that.externalRecordId,_that.pricingSnapshot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiInteractionCost implements AiInteractionCost {
  const _AiInteractionCost({required this.id, required this.interactionId, required this.source, required this.assessedAt, this.originalAmountDecimal, this.originalUnit, this.reportingAmountMicros, this.reportingCurrency, this.supersedesCostId, this.providerType, this.billingAccountKey, this.billingSource, this.externalRecordId, final  Map<String, dynamic>? pricingSnapshot}): _pricingSnapshot = pricingSnapshot;
  factory _AiInteractionCost.fromJson(Map<String, dynamic> json) => _$AiInteractionCostFromJson(json);

@override final  String id;
@override final  String interactionId;
@override final  AiCostSource source;
@override final  DateTime assessedAt;
@override final  String? originalAmountDecimal;
@override final  String? originalUnit;
@override final  int? reportingAmountMicros;
@override final  String? reportingCurrency;
@override final  String? supersedesCostId;
@override final  String? providerType;
@override final  String? billingAccountKey;
@override final  String? billingSource;
@override final  String? externalRecordId;
 final  Map<String, dynamic>? _pricingSnapshot;
@override Map<String, dynamic>? get pricingSnapshot {
  final value = _pricingSnapshot;
  if (value == null) return null;
  if (_pricingSnapshot is EqualUnmodifiableMapView) return _pricingSnapshot;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of AiInteractionCost
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiInteractionCostCopyWith<_AiInteractionCost> get copyWith => __$AiInteractionCostCopyWithImpl<_AiInteractionCost>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiInteractionCostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiInteractionCost&&(identical(other.id, id) || other.id == id)&&(identical(other.interactionId, interactionId) || other.interactionId == interactionId)&&(identical(other.source, source) || other.source == source)&&(identical(other.assessedAt, assessedAt) || other.assessedAt == assessedAt)&&(identical(other.originalAmountDecimal, originalAmountDecimal) || other.originalAmountDecimal == originalAmountDecimal)&&(identical(other.originalUnit, originalUnit) || other.originalUnit == originalUnit)&&(identical(other.reportingAmountMicros, reportingAmountMicros) || other.reportingAmountMicros == reportingAmountMicros)&&(identical(other.reportingCurrency, reportingCurrency) || other.reportingCurrency == reportingCurrency)&&(identical(other.supersedesCostId, supersedesCostId) || other.supersedesCostId == supersedesCostId)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.billingAccountKey, billingAccountKey) || other.billingAccountKey == billingAccountKey)&&(identical(other.billingSource, billingSource) || other.billingSource == billingSource)&&(identical(other.externalRecordId, externalRecordId) || other.externalRecordId == externalRecordId)&&const DeepCollectionEquality().equals(other._pricingSnapshot, _pricingSnapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,interactionId,source,assessedAt,originalAmountDecimal,originalUnit,reportingAmountMicros,reportingCurrency,supersedesCostId,providerType,billingAccountKey,billingSource,externalRecordId,const DeepCollectionEquality().hash(_pricingSnapshot));

@override
String toString() {
  return 'AiInteractionCost(id: $id, interactionId: $interactionId, source: $source, assessedAt: $assessedAt, originalAmountDecimal: $originalAmountDecimal, originalUnit: $originalUnit, reportingAmountMicros: $reportingAmountMicros, reportingCurrency: $reportingCurrency, supersedesCostId: $supersedesCostId, providerType: $providerType, billingAccountKey: $billingAccountKey, billingSource: $billingSource, externalRecordId: $externalRecordId, pricingSnapshot: $pricingSnapshot)';
}


}

/// @nodoc
abstract mixin class _$AiInteractionCostCopyWith<$Res> implements $AiInteractionCostCopyWith<$Res> {
  factory _$AiInteractionCostCopyWith(_AiInteractionCost value, $Res Function(_AiInteractionCost) _then) = __$AiInteractionCostCopyWithImpl;
@override @useResult
$Res call({
 String id, String interactionId, AiCostSource source, DateTime assessedAt, String? originalAmountDecimal, String? originalUnit, int? reportingAmountMicros, String? reportingCurrency, String? supersedesCostId, String? providerType, String? billingAccountKey, String? billingSource, String? externalRecordId, Map<String, dynamic>? pricingSnapshot
});




}
/// @nodoc
class __$AiInteractionCostCopyWithImpl<$Res>
    implements _$AiInteractionCostCopyWith<$Res> {
  __$AiInteractionCostCopyWithImpl(this._self, this._then);

  final _AiInteractionCost _self;
  final $Res Function(_AiInteractionCost) _then;

/// Create a copy of AiInteractionCost
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? interactionId = null,Object? source = null,Object? assessedAt = null,Object? originalAmountDecimal = freezed,Object? originalUnit = freezed,Object? reportingAmountMicros = freezed,Object? reportingCurrency = freezed,Object? supersedesCostId = freezed,Object? providerType = freezed,Object? billingAccountKey = freezed,Object? billingSource = freezed,Object? externalRecordId = freezed,Object? pricingSnapshot = freezed,}) {
  return _then(_AiInteractionCost(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,interactionId: null == interactionId ? _self.interactionId : interactionId // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as AiCostSource,assessedAt: null == assessedAt ? _self.assessedAt : assessedAt // ignore: cast_nullable_to_non_nullable
as DateTime,originalAmountDecimal: freezed == originalAmountDecimal ? _self.originalAmountDecimal : originalAmountDecimal // ignore: cast_nullable_to_non_nullable
as String?,originalUnit: freezed == originalUnit ? _self.originalUnit : originalUnit // ignore: cast_nullable_to_non_nullable
as String?,reportingAmountMicros: freezed == reportingAmountMicros ? _self.reportingAmountMicros : reportingAmountMicros // ignore: cast_nullable_to_non_nullable
as int?,reportingCurrency: freezed == reportingCurrency ? _self.reportingCurrency : reportingCurrency // ignore: cast_nullable_to_non_nullable
as String?,supersedesCostId: freezed == supersedesCostId ? _self.supersedesCostId : supersedesCostId // ignore: cast_nullable_to_non_nullable
as String?,providerType: freezed == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as String?,billingAccountKey: freezed == billingAccountKey ? _self.billingAccountKey : billingAccountKey // ignore: cast_nullable_to_non_nullable
as String?,billingSource: freezed == billingSource ? _self.billingSource : billingSource // ignore: cast_nullable_to_non_nullable
as String?,externalRecordId: freezed == externalRecordId ? _self.externalRecordId : externalRecordId // ignore: cast_nullable_to_non_nullable
as String?,pricingSnapshot: freezed == pricingSnapshot ? _self._pricingSnapshot : pricingSnapshot // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}


/// @nodoc
mixin _$AiWorkAttribution {

 String get id; AiWorkType get workType; AiWorkStatus get status; AiActorSnapshot get initiator; AiTriggerSnapshot get trigger; AiExecutorSnapshot get executor; AiPrivacyClassification get privacyClassification; DateTime get startedAt; DateTime get completedAt; VectorClock? get vectorClock; List<AiAttributionLink> get links; String? get parentAttributionId; String? get taskId; String? get categoryId; AiArtifactReference? get primaryOutput; String? get errorCode; String? get errorSummary; int get schemaVersion;
/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiWorkAttributionCopyWith<AiWorkAttribution> get copyWith => _$AiWorkAttributionCopyWithImpl<AiWorkAttribution>(this as AiWorkAttribution, _$identity);

  /// Serializes this AiWorkAttribution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiWorkAttribution&&(identical(other.id, id) || other.id == id)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.status, status) || other.status == status)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.executor, executor) || other.executor == executor)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&const DeepCollectionEquality().equals(other.links, links)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.primaryOutput, primaryOutput) || other.primaryOutput == primaryOutput)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorSummary, errorSummary) || other.errorSummary == errorSummary)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workType,status,initiator,trigger,executor,privacyClassification,startedAt,completedAt,vectorClock,const DeepCollectionEquality().hash(links),parentAttributionId,taskId,categoryId,primaryOutput,errorCode,errorSummary,schemaVersion);

@override
String toString() {
  return 'AiWorkAttribution(id: $id, workType: $workType, status: $status, initiator: $initiator, trigger: $trigger, executor: $executor, privacyClassification: $privacyClassification, startedAt: $startedAt, completedAt: $completedAt, vectorClock: $vectorClock, links: $links, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, primaryOutput: $primaryOutput, errorCode: $errorCode, errorSummary: $errorSummary, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $AiWorkAttributionCopyWith<$Res>  {
  factory $AiWorkAttributionCopyWith(AiWorkAttribution value, $Res Function(AiWorkAttribution) _then) = _$AiWorkAttributionCopyWithImpl;
@useResult
$Res call({
 String id, AiWorkType workType, AiWorkStatus status, AiActorSnapshot initiator, AiTriggerSnapshot trigger, AiExecutorSnapshot executor, AiPrivacyClassification privacyClassification, DateTime startedAt, DateTime completedAt, VectorClock? vectorClock, List<AiAttributionLink> links, String? parentAttributionId, String? taskId, String? categoryId, AiArtifactReference? primaryOutput, String? errorCode, String? errorSummary, int schemaVersion
});


$AiActorSnapshotCopyWith<$Res> get initiator;$AiTriggerSnapshotCopyWith<$Res> get trigger;$AiExecutorSnapshotCopyWith<$Res> get executor;$AiArtifactReferenceCopyWith<$Res>? get primaryOutput;

}
/// @nodoc
class _$AiWorkAttributionCopyWithImpl<$Res>
    implements $AiWorkAttributionCopyWith<$Res> {
  _$AiWorkAttributionCopyWithImpl(this._self, this._then);

  final AiWorkAttribution _self;
  final $Res Function(AiWorkAttribution) _then;

/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workType = null,Object? status = null,Object? initiator = null,Object? trigger = null,Object? executor = null,Object? privacyClassification = null,Object? startedAt = null,Object? completedAt = null,Object? vectorClock = freezed,Object? links = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? primaryOutput = freezed,Object? errorCode = freezed,Object? errorSummary = freezed,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AiWorkStatus,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,executor: null == executor ? _self.executor : executor // ignore: cast_nullable_to_non_nullable
as AiExecutorSnapshot,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as List<AiAttributionLink>,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,primaryOutput: freezed == primaryOutput ? _self.primaryOutput : primaryOutput // ignore: cast_nullable_to_non_nullable
as AiArtifactReference?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorSummary: freezed == errorSummary ? _self.errorSummary : errorSummary // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiExecutorSnapshotCopyWith<$Res> get executor {
  
  return $AiExecutorSnapshotCopyWith<$Res>(_self.executor, (value) {
    return _then(_self.copyWith(executor: value));
  });
}/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiArtifactReferenceCopyWith<$Res>? get primaryOutput {
    if (_self.primaryOutput == null) {
    return null;
  }

  return $AiArtifactReferenceCopyWith<$Res>(_self.primaryOutput!, (value) {
    return _then(_self.copyWith(primaryOutput: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiWorkAttribution].
extension AiWorkAttributionPatterns on AiWorkAttribution {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiWorkAttribution value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiWorkAttribution() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiWorkAttribution value)  $default,){
final _that = this;
switch (_that) {
case _AiWorkAttribution():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiWorkAttribution value)?  $default,){
final _that = this;
switch (_that) {
case _AiWorkAttribution() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AiWorkType workType,  AiWorkStatus status,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  DateTime startedAt,  DateTime completedAt,  VectorClock? vectorClock,  List<AiAttributionLink> links,  String? parentAttributionId,  String? taskId,  String? categoryId,  AiArtifactReference? primaryOutput,  String? errorCode,  String? errorSummary,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiWorkAttribution() when $default != null:
return $default(_that.id,_that.workType,_that.status,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.startedAt,_that.completedAt,_that.vectorClock,_that.links,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.primaryOutput,_that.errorCode,_that.errorSummary,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AiWorkType workType,  AiWorkStatus status,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  DateTime startedAt,  DateTime completedAt,  VectorClock? vectorClock,  List<AiAttributionLink> links,  String? parentAttributionId,  String? taskId,  String? categoryId,  AiArtifactReference? primaryOutput,  String? errorCode,  String? errorSummary,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _AiWorkAttribution():
return $default(_that.id,_that.workType,_that.status,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.startedAt,_that.completedAt,_that.vectorClock,_that.links,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.primaryOutput,_that.errorCode,_that.errorSummary,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AiWorkType workType,  AiWorkStatus status,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  DateTime startedAt,  DateTime completedAt,  VectorClock? vectorClock,  List<AiAttributionLink> links,  String? parentAttributionId,  String? taskId,  String? categoryId,  AiArtifactReference? primaryOutput,  String? errorCode,  String? errorSummary,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _AiWorkAttribution() when $default != null:
return $default(_that.id,_that.workType,_that.status,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.startedAt,_that.completedAt,_that.vectorClock,_that.links,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.primaryOutput,_that.errorCode,_that.errorSummary,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiWorkAttribution implements AiWorkAttribution {
  const _AiWorkAttribution({required this.id, required this.workType, required this.status, required this.initiator, required this.trigger, required this.executor, required this.privacyClassification, required this.startedAt, required this.completedAt, required this.vectorClock, required final  List<AiAttributionLink> links, this.parentAttributionId, this.taskId, this.categoryId, this.primaryOutput, this.errorCode, this.errorSummary, this.schemaVersion = 1}): _links = links;
  factory _AiWorkAttribution.fromJson(Map<String, dynamic> json) => _$AiWorkAttributionFromJson(json);

@override final  String id;
@override final  AiWorkType workType;
@override final  AiWorkStatus status;
@override final  AiActorSnapshot initiator;
@override final  AiTriggerSnapshot trigger;
@override final  AiExecutorSnapshot executor;
@override final  AiPrivacyClassification privacyClassification;
@override final  DateTime startedAt;
@override final  DateTime completedAt;
@override final  VectorClock? vectorClock;
 final  List<AiAttributionLink> _links;
@override List<AiAttributionLink> get links {
  if (_links is EqualUnmodifiableListView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_links);
}

@override final  String? parentAttributionId;
@override final  String? taskId;
@override final  String? categoryId;
@override final  AiArtifactReference? primaryOutput;
@override final  String? errorCode;
@override final  String? errorSummary;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiWorkAttributionCopyWith<_AiWorkAttribution> get copyWith => __$AiWorkAttributionCopyWithImpl<_AiWorkAttribution>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiWorkAttributionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiWorkAttribution&&(identical(other.id, id) || other.id == id)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.status, status) || other.status == status)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.executor, executor) || other.executor == executor)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&const DeepCollectionEquality().equals(other._links, _links)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.primaryOutput, primaryOutput) || other.primaryOutput == primaryOutput)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorSummary, errorSummary) || other.errorSummary == errorSummary)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workType,status,initiator,trigger,executor,privacyClassification,startedAt,completedAt,vectorClock,const DeepCollectionEquality().hash(_links),parentAttributionId,taskId,categoryId,primaryOutput,errorCode,errorSummary,schemaVersion);

@override
String toString() {
  return 'AiWorkAttribution(id: $id, workType: $workType, status: $status, initiator: $initiator, trigger: $trigger, executor: $executor, privacyClassification: $privacyClassification, startedAt: $startedAt, completedAt: $completedAt, vectorClock: $vectorClock, links: $links, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, primaryOutput: $primaryOutput, errorCode: $errorCode, errorSummary: $errorSummary, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$AiWorkAttributionCopyWith<$Res> implements $AiWorkAttributionCopyWith<$Res> {
  factory _$AiWorkAttributionCopyWith(_AiWorkAttribution value, $Res Function(_AiWorkAttribution) _then) = __$AiWorkAttributionCopyWithImpl;
@override @useResult
$Res call({
 String id, AiWorkType workType, AiWorkStatus status, AiActorSnapshot initiator, AiTriggerSnapshot trigger, AiExecutorSnapshot executor, AiPrivacyClassification privacyClassification, DateTime startedAt, DateTime completedAt, VectorClock? vectorClock, List<AiAttributionLink> links, String? parentAttributionId, String? taskId, String? categoryId, AiArtifactReference? primaryOutput, String? errorCode, String? errorSummary, int schemaVersion
});


@override $AiActorSnapshotCopyWith<$Res> get initiator;@override $AiTriggerSnapshotCopyWith<$Res> get trigger;@override $AiExecutorSnapshotCopyWith<$Res> get executor;@override $AiArtifactReferenceCopyWith<$Res>? get primaryOutput;

}
/// @nodoc
class __$AiWorkAttributionCopyWithImpl<$Res>
    implements _$AiWorkAttributionCopyWith<$Res> {
  __$AiWorkAttributionCopyWithImpl(this._self, this._then);

  final _AiWorkAttribution _self;
  final $Res Function(_AiWorkAttribution) _then;

/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workType = null,Object? status = null,Object? initiator = null,Object? trigger = null,Object? executor = null,Object? privacyClassification = null,Object? startedAt = null,Object? completedAt = null,Object? vectorClock = freezed,Object? links = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? primaryOutput = freezed,Object? errorCode = freezed,Object? errorSummary = freezed,Object? schemaVersion = null,}) {
  return _then(_AiWorkAttribution(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AiWorkStatus,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,executor: null == executor ? _self.executor : executor // ignore: cast_nullable_to_non_nullable
as AiExecutorSnapshot,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as List<AiAttributionLink>,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,primaryOutput: freezed == primaryOutput ? _self.primaryOutput : primaryOutput // ignore: cast_nullable_to_non_nullable
as AiArtifactReference?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorSummary: freezed == errorSummary ? _self.errorSummary : errorSummary // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiExecutorSnapshotCopyWith<$Res> get executor {
  
  return $AiExecutorSnapshotCopyWith<$Res>(_self.executor, (value) {
    return _then(_self.copyWith(executor: value));
  });
}/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiArtifactReferenceCopyWith<$Res>? get primaryOutput {
    if (_self.primaryOutput == null) {
    return null;
  }

  return $AiArtifactReferenceCopyWith<$Res>(_self.primaryOutput!, (value) {
    return _then(_self.copyWith(primaryOutput: value));
  });
}
}


/// @nodoc
mixin _$AiAttributionRecoveryCapsule {

 String get id; String get attributionId; AiWorkType get workType; AiActorSnapshot get initiator; AiTriggerSnapshot get trigger; AiExecutorSnapshot get executor; AiPrivacyClassification get privacyClassification; DateTime get startedAt; List<AiArtifactReference> get intendedOutputs; String get digestAlgorithm; int get omittedReferenceCount; String? get parentAttributionId; String? get taskId; String? get categoryId; int get schemaVersion;
/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiAttributionRecoveryCapsuleCopyWith<AiAttributionRecoveryCapsule> get copyWith => _$AiAttributionRecoveryCapsuleCopyWithImpl<AiAttributionRecoveryCapsule>(this as AiAttributionRecoveryCapsule, _$identity);

  /// Serializes this AiAttributionRecoveryCapsule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiAttributionRecoveryCapsule&&(identical(other.id, id) || other.id == id)&&(identical(other.attributionId, attributionId) || other.attributionId == attributionId)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.executor, executor) || other.executor == executor)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other.intendedOutputs, intendedOutputs)&&(identical(other.digestAlgorithm, digestAlgorithm) || other.digestAlgorithm == digestAlgorithm)&&(identical(other.omittedReferenceCount, omittedReferenceCount) || other.omittedReferenceCount == omittedReferenceCount)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attributionId,workType,initiator,trigger,executor,privacyClassification,startedAt,const DeepCollectionEquality().hash(intendedOutputs),digestAlgorithm,omittedReferenceCount,parentAttributionId,taskId,categoryId,schemaVersion);

@override
String toString() {
  return 'AiAttributionRecoveryCapsule(id: $id, attributionId: $attributionId, workType: $workType, initiator: $initiator, trigger: $trigger, executor: $executor, privacyClassification: $privacyClassification, startedAt: $startedAt, intendedOutputs: $intendedOutputs, digestAlgorithm: $digestAlgorithm, omittedReferenceCount: $omittedReferenceCount, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $AiAttributionRecoveryCapsuleCopyWith<$Res>  {
  factory $AiAttributionRecoveryCapsuleCopyWith(AiAttributionRecoveryCapsule value, $Res Function(AiAttributionRecoveryCapsule) _then) = _$AiAttributionRecoveryCapsuleCopyWithImpl;
@useResult
$Res call({
 String id, String attributionId, AiWorkType workType, AiActorSnapshot initiator, AiTriggerSnapshot trigger, AiExecutorSnapshot executor, AiPrivacyClassification privacyClassification, DateTime startedAt, List<AiArtifactReference> intendedOutputs, String digestAlgorithm, int omittedReferenceCount, String? parentAttributionId, String? taskId, String? categoryId, int schemaVersion
});


$AiActorSnapshotCopyWith<$Res> get initiator;$AiTriggerSnapshotCopyWith<$Res> get trigger;$AiExecutorSnapshotCopyWith<$Res> get executor;

}
/// @nodoc
class _$AiAttributionRecoveryCapsuleCopyWithImpl<$Res>
    implements $AiAttributionRecoveryCapsuleCopyWith<$Res> {
  _$AiAttributionRecoveryCapsuleCopyWithImpl(this._self, this._then);

  final AiAttributionRecoveryCapsule _self;
  final $Res Function(AiAttributionRecoveryCapsule) _then;

/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? attributionId = null,Object? workType = null,Object? initiator = null,Object? trigger = null,Object? executor = null,Object? privacyClassification = null,Object? startedAt = null,Object? intendedOutputs = null,Object? digestAlgorithm = null,Object? omittedReferenceCount = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attributionId: null == attributionId ? _self.attributionId : attributionId // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,executor: null == executor ? _self.executor : executor // ignore: cast_nullable_to_non_nullable
as AiExecutorSnapshot,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intendedOutputs: null == intendedOutputs ? _self.intendedOutputs : intendedOutputs // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,digestAlgorithm: null == digestAlgorithm ? _self.digestAlgorithm : digestAlgorithm // ignore: cast_nullable_to_non_nullable
as String,omittedReferenceCount: null == omittedReferenceCount ? _self.omittedReferenceCount : omittedReferenceCount // ignore: cast_nullable_to_non_nullable
as int,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiExecutorSnapshotCopyWith<$Res> get executor {
  
  return $AiExecutorSnapshotCopyWith<$Res>(_self.executor, (value) {
    return _then(_self.copyWith(executor: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiAttributionRecoveryCapsule].
extension AiAttributionRecoveryCapsulePatterns on AiAttributionRecoveryCapsule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiAttributionRecoveryCapsule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiAttributionRecoveryCapsule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiAttributionRecoveryCapsule value)  $default,){
final _that = this;
switch (_that) {
case _AiAttributionRecoveryCapsule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiAttributionRecoveryCapsule value)?  $default,){
final _that = this;
switch (_that) {
case _AiAttributionRecoveryCapsule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String attributionId,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  DateTime startedAt,  List<AiArtifactReference> intendedOutputs,  String digestAlgorithm,  int omittedReferenceCount,  String? parentAttributionId,  String? taskId,  String? categoryId,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiAttributionRecoveryCapsule() when $default != null:
return $default(_that.id,_that.attributionId,_that.workType,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.startedAt,_that.intendedOutputs,_that.digestAlgorithm,_that.omittedReferenceCount,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String attributionId,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  DateTime startedAt,  List<AiArtifactReference> intendedOutputs,  String digestAlgorithm,  int omittedReferenceCount,  String? parentAttributionId,  String? taskId,  String? categoryId,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _AiAttributionRecoveryCapsule():
return $default(_that.id,_that.attributionId,_that.workType,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.startedAt,_that.intendedOutputs,_that.digestAlgorithm,_that.omittedReferenceCount,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String attributionId,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  DateTime startedAt,  List<AiArtifactReference> intendedOutputs,  String digestAlgorithm,  int omittedReferenceCount,  String? parentAttributionId,  String? taskId,  String? categoryId,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _AiAttributionRecoveryCapsule() when $default != null:
return $default(_that.id,_that.attributionId,_that.workType,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.startedAt,_that.intendedOutputs,_that.digestAlgorithm,_that.omittedReferenceCount,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiAttributionRecoveryCapsule implements AiAttributionRecoveryCapsule {
  const _AiAttributionRecoveryCapsule({required this.id, required this.attributionId, required this.workType, required this.initiator, required this.trigger, required this.executor, required this.privacyClassification, required this.startedAt, required final  List<AiArtifactReference> intendedOutputs, this.digestAlgorithm = 'sha256-v1', this.omittedReferenceCount = 0, this.parentAttributionId, this.taskId, this.categoryId, this.schemaVersion = 1}): _intendedOutputs = intendedOutputs;
  factory _AiAttributionRecoveryCapsule.fromJson(Map<String, dynamic> json) => _$AiAttributionRecoveryCapsuleFromJson(json);

@override final  String id;
@override final  String attributionId;
@override final  AiWorkType workType;
@override final  AiActorSnapshot initiator;
@override final  AiTriggerSnapshot trigger;
@override final  AiExecutorSnapshot executor;
@override final  AiPrivacyClassification privacyClassification;
@override final  DateTime startedAt;
 final  List<AiArtifactReference> _intendedOutputs;
@override List<AiArtifactReference> get intendedOutputs {
  if (_intendedOutputs is EqualUnmodifiableListView) return _intendedOutputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_intendedOutputs);
}

@override@JsonKey() final  String digestAlgorithm;
@override@JsonKey() final  int omittedReferenceCount;
@override final  String? parentAttributionId;
@override final  String? taskId;
@override final  String? categoryId;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiAttributionRecoveryCapsuleCopyWith<_AiAttributionRecoveryCapsule> get copyWith => __$AiAttributionRecoveryCapsuleCopyWithImpl<_AiAttributionRecoveryCapsule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiAttributionRecoveryCapsuleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiAttributionRecoveryCapsule&&(identical(other.id, id) || other.id == id)&&(identical(other.attributionId, attributionId) || other.attributionId == attributionId)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.executor, executor) || other.executor == executor)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other._intendedOutputs, _intendedOutputs)&&(identical(other.digestAlgorithm, digestAlgorithm) || other.digestAlgorithm == digestAlgorithm)&&(identical(other.omittedReferenceCount, omittedReferenceCount) || other.omittedReferenceCount == omittedReferenceCount)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attributionId,workType,initiator,trigger,executor,privacyClassification,startedAt,const DeepCollectionEquality().hash(_intendedOutputs),digestAlgorithm,omittedReferenceCount,parentAttributionId,taskId,categoryId,schemaVersion);

@override
String toString() {
  return 'AiAttributionRecoveryCapsule(id: $id, attributionId: $attributionId, workType: $workType, initiator: $initiator, trigger: $trigger, executor: $executor, privacyClassification: $privacyClassification, startedAt: $startedAt, intendedOutputs: $intendedOutputs, digestAlgorithm: $digestAlgorithm, omittedReferenceCount: $omittedReferenceCount, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$AiAttributionRecoveryCapsuleCopyWith<$Res> implements $AiAttributionRecoveryCapsuleCopyWith<$Res> {
  factory _$AiAttributionRecoveryCapsuleCopyWith(_AiAttributionRecoveryCapsule value, $Res Function(_AiAttributionRecoveryCapsule) _then) = __$AiAttributionRecoveryCapsuleCopyWithImpl;
@override @useResult
$Res call({
 String id, String attributionId, AiWorkType workType, AiActorSnapshot initiator, AiTriggerSnapshot trigger, AiExecutorSnapshot executor, AiPrivacyClassification privacyClassification, DateTime startedAt, List<AiArtifactReference> intendedOutputs, String digestAlgorithm, int omittedReferenceCount, String? parentAttributionId, String? taskId, String? categoryId, int schemaVersion
});


@override $AiActorSnapshotCopyWith<$Res> get initiator;@override $AiTriggerSnapshotCopyWith<$Res> get trigger;@override $AiExecutorSnapshotCopyWith<$Res> get executor;

}
/// @nodoc
class __$AiAttributionRecoveryCapsuleCopyWithImpl<$Res>
    implements _$AiAttributionRecoveryCapsuleCopyWith<$Res> {
  __$AiAttributionRecoveryCapsuleCopyWithImpl(this._self, this._then);

  final _AiAttributionRecoveryCapsule _self;
  final $Res Function(_AiAttributionRecoveryCapsule) _then;

/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? attributionId = null,Object? workType = null,Object? initiator = null,Object? trigger = null,Object? executor = null,Object? privacyClassification = null,Object? startedAt = null,Object? intendedOutputs = null,Object? digestAlgorithm = null,Object? omittedReferenceCount = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? schemaVersion = null,}) {
  return _then(_AiAttributionRecoveryCapsule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attributionId: null == attributionId ? _self.attributionId : attributionId // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,executor: null == executor ? _self.executor : executor // ignore: cast_nullable_to_non_nullable
as AiExecutorSnapshot,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intendedOutputs: null == intendedOutputs ? _self._intendedOutputs : intendedOutputs // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,digestAlgorithm: null == digestAlgorithm ? _self.digestAlgorithm : digestAlgorithm // ignore: cast_nullable_to_non_nullable
as String,omittedReferenceCount: null == omittedReferenceCount ? _self.omittedReferenceCount : omittedReferenceCount // ignore: cast_nullable_to_non_nullable
as int,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of AiAttributionRecoveryCapsule
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiExecutorSnapshotCopyWith<$Res> get executor {
  
  return $AiExecutorSnapshotCopyWith<$Res>(_self.executor, (value) {
    return _then(_self.copyWith(executor: value));
  });
}
}


/// @nodoc
mixin _$AiTerminalAttributionEnvelope {

 String get id; AiWorkAttribution get attribution; String get digestAlgorithm; int get schemaVersion;
/// Create a copy of AiTerminalAttributionEnvelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiTerminalAttributionEnvelopeCopyWith<AiTerminalAttributionEnvelope> get copyWith => _$AiTerminalAttributionEnvelopeCopyWithImpl<AiTerminalAttributionEnvelope>(this as AiTerminalAttributionEnvelope, _$identity);

  /// Serializes this AiTerminalAttributionEnvelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiTerminalAttributionEnvelope&&(identical(other.id, id) || other.id == id)&&(identical(other.attribution, attribution) || other.attribution == attribution)&&(identical(other.digestAlgorithm, digestAlgorithm) || other.digestAlgorithm == digestAlgorithm)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attribution,digestAlgorithm,schemaVersion);

@override
String toString() {
  return 'AiTerminalAttributionEnvelope(id: $id, attribution: $attribution, digestAlgorithm: $digestAlgorithm, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $AiTerminalAttributionEnvelopeCopyWith<$Res>  {
  factory $AiTerminalAttributionEnvelopeCopyWith(AiTerminalAttributionEnvelope value, $Res Function(AiTerminalAttributionEnvelope) _then) = _$AiTerminalAttributionEnvelopeCopyWithImpl;
@useResult
$Res call({
 String id, AiWorkAttribution attribution, String digestAlgorithm, int schemaVersion
});


$AiWorkAttributionCopyWith<$Res> get attribution;

}
/// @nodoc
class _$AiTerminalAttributionEnvelopeCopyWithImpl<$Res>
    implements $AiTerminalAttributionEnvelopeCopyWith<$Res> {
  _$AiTerminalAttributionEnvelopeCopyWithImpl(this._self, this._then);

  final AiTerminalAttributionEnvelope _self;
  final $Res Function(AiTerminalAttributionEnvelope) _then;

/// Create a copy of AiTerminalAttributionEnvelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? attribution = null,Object? digestAlgorithm = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as AiWorkAttribution,digestAlgorithm: null == digestAlgorithm ? _self.digestAlgorithm : digestAlgorithm // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of AiTerminalAttributionEnvelope
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiWorkAttributionCopyWith<$Res> get attribution {
  
  return $AiWorkAttributionCopyWith<$Res>(_self.attribution, (value) {
    return _then(_self.copyWith(attribution: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiTerminalAttributionEnvelope].
extension AiTerminalAttributionEnvelopePatterns on AiTerminalAttributionEnvelope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiTerminalAttributionEnvelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiTerminalAttributionEnvelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiTerminalAttributionEnvelope value)  $default,){
final _that = this;
switch (_that) {
case _AiTerminalAttributionEnvelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiTerminalAttributionEnvelope value)?  $default,){
final _that = this;
switch (_that) {
case _AiTerminalAttributionEnvelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AiWorkAttribution attribution,  String digestAlgorithm,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiTerminalAttributionEnvelope() when $default != null:
return $default(_that.id,_that.attribution,_that.digestAlgorithm,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AiWorkAttribution attribution,  String digestAlgorithm,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _AiTerminalAttributionEnvelope():
return $default(_that.id,_that.attribution,_that.digestAlgorithm,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AiWorkAttribution attribution,  String digestAlgorithm,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _AiTerminalAttributionEnvelope() when $default != null:
return $default(_that.id,_that.attribution,_that.digestAlgorithm,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiTerminalAttributionEnvelope implements AiTerminalAttributionEnvelope {
  const _AiTerminalAttributionEnvelope({required this.id, required this.attribution, this.digestAlgorithm = 'sha256-v1', this.schemaVersion = 1});
  factory _AiTerminalAttributionEnvelope.fromJson(Map<String, dynamic> json) => _$AiTerminalAttributionEnvelopeFromJson(json);

@override final  String id;
@override final  AiWorkAttribution attribution;
@override@JsonKey() final  String digestAlgorithm;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of AiTerminalAttributionEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiTerminalAttributionEnvelopeCopyWith<_AiTerminalAttributionEnvelope> get copyWith => __$AiTerminalAttributionEnvelopeCopyWithImpl<_AiTerminalAttributionEnvelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiTerminalAttributionEnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiTerminalAttributionEnvelope&&(identical(other.id, id) || other.id == id)&&(identical(other.attribution, attribution) || other.attribution == attribution)&&(identical(other.digestAlgorithm, digestAlgorithm) || other.digestAlgorithm == digestAlgorithm)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,attribution,digestAlgorithm,schemaVersion);

@override
String toString() {
  return 'AiTerminalAttributionEnvelope(id: $id, attribution: $attribution, digestAlgorithm: $digestAlgorithm, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$AiTerminalAttributionEnvelopeCopyWith<$Res> implements $AiTerminalAttributionEnvelopeCopyWith<$Res> {
  factory _$AiTerminalAttributionEnvelopeCopyWith(_AiTerminalAttributionEnvelope value, $Res Function(_AiTerminalAttributionEnvelope) _then) = __$AiTerminalAttributionEnvelopeCopyWithImpl;
@override @useResult
$Res call({
 String id, AiWorkAttribution attribution, String digestAlgorithm, int schemaVersion
});


@override $AiWorkAttributionCopyWith<$Res> get attribution;

}
/// @nodoc
class __$AiTerminalAttributionEnvelopeCopyWithImpl<$Res>
    implements _$AiTerminalAttributionEnvelopeCopyWith<$Res> {
  __$AiTerminalAttributionEnvelopeCopyWithImpl(this._self, this._then);

  final _AiTerminalAttributionEnvelope _self;
  final $Res Function(_AiTerminalAttributionEnvelope) _then;

/// Create a copy of AiTerminalAttributionEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? attribution = null,Object? digestAlgorithm = null,Object? schemaVersion = null,}) {
  return _then(_AiTerminalAttributionEnvelope(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attribution: null == attribution ? _self.attribution : attribution // ignore: cast_nullable_to_non_nullable
as AiWorkAttribution,digestAlgorithm: null == digestAlgorithm ? _self.digestAlgorithm : digestAlgorithm // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of AiTerminalAttributionEnvelope
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiWorkAttributionCopyWith<$Res> get attribution {
  
  return $AiWorkAttributionCopyWith<$Res>(_self.attribution, (value) {
    return _then(_self.copyWith(attribution: value));
  });
}
}


/// @nodoc
mixin _$AiAttributionPendingSession {

 String get id; String get attributionId; AiWorkType get workType; AiActorSnapshot get initiator; AiTriggerSnapshot get trigger; AiExecutorSnapshot get executor; AiPrivacyClassification get privacyClassification; AiAttributionPendingPhase get phase; DateTime get startedAt; DateTime get lastUpdatedAt; List<AiArtifactReference> get intendedOutputs; List<AiArtifactReference> get sourceArtifacts; List<AiArtifactReference> get contextArtifacts; List<String> get interactionIds; String? get parentAttributionId; String? get taskId; String? get categoryId; String? get terminalAttributionId; String? get errorCode;
/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiAttributionPendingSessionCopyWith<AiAttributionPendingSession> get copyWith => _$AiAttributionPendingSessionCopyWithImpl<AiAttributionPendingSession>(this as AiAttributionPendingSession, _$identity);

  /// Serializes this AiAttributionPendingSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiAttributionPendingSession&&(identical(other.id, id) || other.id == id)&&(identical(other.attributionId, attributionId) || other.attributionId == attributionId)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.executor, executor) || other.executor == executor)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.lastUpdatedAt, lastUpdatedAt) || other.lastUpdatedAt == lastUpdatedAt)&&const DeepCollectionEquality().equals(other.intendedOutputs, intendedOutputs)&&const DeepCollectionEquality().equals(other.sourceArtifacts, sourceArtifacts)&&const DeepCollectionEquality().equals(other.contextArtifacts, contextArtifacts)&&const DeepCollectionEquality().equals(other.interactionIds, interactionIds)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.terminalAttributionId, terminalAttributionId) || other.terminalAttributionId == terminalAttributionId)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,attributionId,workType,initiator,trigger,executor,privacyClassification,phase,startedAt,lastUpdatedAt,const DeepCollectionEquality().hash(intendedOutputs),const DeepCollectionEquality().hash(sourceArtifacts),const DeepCollectionEquality().hash(contextArtifacts),const DeepCollectionEquality().hash(interactionIds),parentAttributionId,taskId,categoryId,terminalAttributionId,errorCode]);

@override
String toString() {
  return 'AiAttributionPendingSession(id: $id, attributionId: $attributionId, workType: $workType, initiator: $initiator, trigger: $trigger, executor: $executor, privacyClassification: $privacyClassification, phase: $phase, startedAt: $startedAt, lastUpdatedAt: $lastUpdatedAt, intendedOutputs: $intendedOutputs, sourceArtifacts: $sourceArtifacts, contextArtifacts: $contextArtifacts, interactionIds: $interactionIds, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, terminalAttributionId: $terminalAttributionId, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class $AiAttributionPendingSessionCopyWith<$Res>  {
  factory $AiAttributionPendingSessionCopyWith(AiAttributionPendingSession value, $Res Function(AiAttributionPendingSession) _then) = _$AiAttributionPendingSessionCopyWithImpl;
@useResult
$Res call({
 String id, String attributionId, AiWorkType workType, AiActorSnapshot initiator, AiTriggerSnapshot trigger, AiExecutorSnapshot executor, AiPrivacyClassification privacyClassification, AiAttributionPendingPhase phase, DateTime startedAt, DateTime lastUpdatedAt, List<AiArtifactReference> intendedOutputs, List<AiArtifactReference> sourceArtifacts, List<AiArtifactReference> contextArtifacts, List<String> interactionIds, String? parentAttributionId, String? taskId, String? categoryId, String? terminalAttributionId, String? errorCode
});


$AiActorSnapshotCopyWith<$Res> get initiator;$AiTriggerSnapshotCopyWith<$Res> get trigger;$AiExecutorSnapshotCopyWith<$Res> get executor;

}
/// @nodoc
class _$AiAttributionPendingSessionCopyWithImpl<$Res>
    implements $AiAttributionPendingSessionCopyWith<$Res> {
  _$AiAttributionPendingSessionCopyWithImpl(this._self, this._then);

  final AiAttributionPendingSession _self;
  final $Res Function(AiAttributionPendingSession) _then;

/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? attributionId = null,Object? workType = null,Object? initiator = null,Object? trigger = null,Object? executor = null,Object? privacyClassification = null,Object? phase = null,Object? startedAt = null,Object? lastUpdatedAt = null,Object? intendedOutputs = null,Object? sourceArtifacts = null,Object? contextArtifacts = null,Object? interactionIds = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? terminalAttributionId = freezed,Object? errorCode = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attributionId: null == attributionId ? _self.attributionId : attributionId // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,executor: null == executor ? _self.executor : executor // ignore: cast_nullable_to_non_nullable
as AiExecutorSnapshot,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as AiAttributionPendingPhase,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastUpdatedAt: null == lastUpdatedAt ? _self.lastUpdatedAt : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intendedOutputs: null == intendedOutputs ? _self.intendedOutputs : intendedOutputs // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,sourceArtifacts: null == sourceArtifacts ? _self.sourceArtifacts : sourceArtifacts // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,contextArtifacts: null == contextArtifacts ? _self.contextArtifacts : contextArtifacts // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,interactionIds: null == interactionIds ? _self.interactionIds : interactionIds // ignore: cast_nullable_to_non_nullable
as List<String>,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,terminalAttributionId: freezed == terminalAttributionId ? _self.terminalAttributionId : terminalAttributionId // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiExecutorSnapshotCopyWith<$Res> get executor {
  
  return $AiExecutorSnapshotCopyWith<$Res>(_self.executor, (value) {
    return _then(_self.copyWith(executor: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiAttributionPendingSession].
extension AiAttributionPendingSessionPatterns on AiAttributionPendingSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiAttributionPendingSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiAttributionPendingSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiAttributionPendingSession value)  $default,){
final _that = this;
switch (_that) {
case _AiAttributionPendingSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiAttributionPendingSession value)?  $default,){
final _that = this;
switch (_that) {
case _AiAttributionPendingSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String attributionId,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  AiAttributionPendingPhase phase,  DateTime startedAt,  DateTime lastUpdatedAt,  List<AiArtifactReference> intendedOutputs,  List<AiArtifactReference> sourceArtifacts,  List<AiArtifactReference> contextArtifacts,  List<String> interactionIds,  String? parentAttributionId,  String? taskId,  String? categoryId,  String? terminalAttributionId,  String? errorCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiAttributionPendingSession() when $default != null:
return $default(_that.id,_that.attributionId,_that.workType,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.phase,_that.startedAt,_that.lastUpdatedAt,_that.intendedOutputs,_that.sourceArtifacts,_that.contextArtifacts,_that.interactionIds,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.terminalAttributionId,_that.errorCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String attributionId,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  AiAttributionPendingPhase phase,  DateTime startedAt,  DateTime lastUpdatedAt,  List<AiArtifactReference> intendedOutputs,  List<AiArtifactReference> sourceArtifacts,  List<AiArtifactReference> contextArtifacts,  List<String> interactionIds,  String? parentAttributionId,  String? taskId,  String? categoryId,  String? terminalAttributionId,  String? errorCode)  $default,) {final _that = this;
switch (_that) {
case _AiAttributionPendingSession():
return $default(_that.id,_that.attributionId,_that.workType,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.phase,_that.startedAt,_that.lastUpdatedAt,_that.intendedOutputs,_that.sourceArtifacts,_that.contextArtifacts,_that.interactionIds,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.terminalAttributionId,_that.errorCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String attributionId,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  AiExecutorSnapshot executor,  AiPrivacyClassification privacyClassification,  AiAttributionPendingPhase phase,  DateTime startedAt,  DateTime lastUpdatedAt,  List<AiArtifactReference> intendedOutputs,  List<AiArtifactReference> sourceArtifacts,  List<AiArtifactReference> contextArtifacts,  List<String> interactionIds,  String? parentAttributionId,  String? taskId,  String? categoryId,  String? terminalAttributionId,  String? errorCode)?  $default,) {final _that = this;
switch (_that) {
case _AiAttributionPendingSession() when $default != null:
return $default(_that.id,_that.attributionId,_that.workType,_that.initiator,_that.trigger,_that.executor,_that.privacyClassification,_that.phase,_that.startedAt,_that.lastUpdatedAt,_that.intendedOutputs,_that.sourceArtifacts,_that.contextArtifacts,_that.interactionIds,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.terminalAttributionId,_that.errorCode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiAttributionPendingSession implements AiAttributionPendingSession {
  const _AiAttributionPendingSession({required this.id, required this.attributionId, required this.workType, required this.initiator, required this.trigger, required this.executor, required this.privacyClassification, required this.phase, required this.startedAt, required this.lastUpdatedAt, required final  List<AiArtifactReference> intendedOutputs, final  List<AiArtifactReference> sourceArtifacts = const <AiArtifactReference>[], final  List<AiArtifactReference> contextArtifacts = const <AiArtifactReference>[], final  List<String> interactionIds = const <String>[], this.parentAttributionId, this.taskId, this.categoryId, this.terminalAttributionId, this.errorCode}): _intendedOutputs = intendedOutputs,_sourceArtifacts = sourceArtifacts,_contextArtifacts = contextArtifacts,_interactionIds = interactionIds;
  factory _AiAttributionPendingSession.fromJson(Map<String, dynamic> json) => _$AiAttributionPendingSessionFromJson(json);

@override final  String id;
@override final  String attributionId;
@override final  AiWorkType workType;
@override final  AiActorSnapshot initiator;
@override final  AiTriggerSnapshot trigger;
@override final  AiExecutorSnapshot executor;
@override final  AiPrivacyClassification privacyClassification;
@override final  AiAttributionPendingPhase phase;
@override final  DateTime startedAt;
@override final  DateTime lastUpdatedAt;
 final  List<AiArtifactReference> _intendedOutputs;
@override List<AiArtifactReference> get intendedOutputs {
  if (_intendedOutputs is EqualUnmodifiableListView) return _intendedOutputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_intendedOutputs);
}

 final  List<AiArtifactReference> _sourceArtifacts;
@override@JsonKey() List<AiArtifactReference> get sourceArtifacts {
  if (_sourceArtifacts is EqualUnmodifiableListView) return _sourceArtifacts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceArtifacts);
}

 final  List<AiArtifactReference> _contextArtifacts;
@override@JsonKey() List<AiArtifactReference> get contextArtifacts {
  if (_contextArtifacts is EqualUnmodifiableListView) return _contextArtifacts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contextArtifacts);
}

 final  List<String> _interactionIds;
@override@JsonKey() List<String> get interactionIds {
  if (_interactionIds is EqualUnmodifiableListView) return _interactionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_interactionIds);
}

@override final  String? parentAttributionId;
@override final  String? taskId;
@override final  String? categoryId;
@override final  String? terminalAttributionId;
@override final  String? errorCode;

/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiAttributionPendingSessionCopyWith<_AiAttributionPendingSession> get copyWith => __$AiAttributionPendingSessionCopyWithImpl<_AiAttributionPendingSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiAttributionPendingSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiAttributionPendingSession&&(identical(other.id, id) || other.id == id)&&(identical(other.attributionId, attributionId) || other.attributionId == attributionId)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.executor, executor) || other.executor == executor)&&(identical(other.privacyClassification, privacyClassification) || other.privacyClassification == privacyClassification)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.lastUpdatedAt, lastUpdatedAt) || other.lastUpdatedAt == lastUpdatedAt)&&const DeepCollectionEquality().equals(other._intendedOutputs, _intendedOutputs)&&const DeepCollectionEquality().equals(other._sourceArtifacts, _sourceArtifacts)&&const DeepCollectionEquality().equals(other._contextArtifacts, _contextArtifacts)&&const DeepCollectionEquality().equals(other._interactionIds, _interactionIds)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.terminalAttributionId, terminalAttributionId) || other.terminalAttributionId == terminalAttributionId)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,attributionId,workType,initiator,trigger,executor,privacyClassification,phase,startedAt,lastUpdatedAt,const DeepCollectionEquality().hash(_intendedOutputs),const DeepCollectionEquality().hash(_sourceArtifacts),const DeepCollectionEquality().hash(_contextArtifacts),const DeepCollectionEquality().hash(_interactionIds),parentAttributionId,taskId,categoryId,terminalAttributionId,errorCode]);

@override
String toString() {
  return 'AiAttributionPendingSession(id: $id, attributionId: $attributionId, workType: $workType, initiator: $initiator, trigger: $trigger, executor: $executor, privacyClassification: $privacyClassification, phase: $phase, startedAt: $startedAt, lastUpdatedAt: $lastUpdatedAt, intendedOutputs: $intendedOutputs, sourceArtifacts: $sourceArtifacts, contextArtifacts: $contextArtifacts, interactionIds: $interactionIds, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, terminalAttributionId: $terminalAttributionId, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class _$AiAttributionPendingSessionCopyWith<$Res> implements $AiAttributionPendingSessionCopyWith<$Res> {
  factory _$AiAttributionPendingSessionCopyWith(_AiAttributionPendingSession value, $Res Function(_AiAttributionPendingSession) _then) = __$AiAttributionPendingSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String attributionId, AiWorkType workType, AiActorSnapshot initiator, AiTriggerSnapshot trigger, AiExecutorSnapshot executor, AiPrivacyClassification privacyClassification, AiAttributionPendingPhase phase, DateTime startedAt, DateTime lastUpdatedAt, List<AiArtifactReference> intendedOutputs, List<AiArtifactReference> sourceArtifacts, List<AiArtifactReference> contextArtifacts, List<String> interactionIds, String? parentAttributionId, String? taskId, String? categoryId, String? terminalAttributionId, String? errorCode
});


@override $AiActorSnapshotCopyWith<$Res> get initiator;@override $AiTriggerSnapshotCopyWith<$Res> get trigger;@override $AiExecutorSnapshotCopyWith<$Res> get executor;

}
/// @nodoc
class __$AiAttributionPendingSessionCopyWithImpl<$Res>
    implements _$AiAttributionPendingSessionCopyWith<$Res> {
  __$AiAttributionPendingSessionCopyWithImpl(this._self, this._then);

  final _AiAttributionPendingSession _self;
  final $Res Function(_AiAttributionPendingSession) _then;

/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? attributionId = null,Object? workType = null,Object? initiator = null,Object? trigger = null,Object? executor = null,Object? privacyClassification = null,Object? phase = null,Object? startedAt = null,Object? lastUpdatedAt = null,Object? intendedOutputs = null,Object? sourceArtifacts = null,Object? contextArtifacts = null,Object? interactionIds = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? terminalAttributionId = freezed,Object? errorCode = freezed,}) {
  return _then(_AiAttributionPendingSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,attributionId: null == attributionId ? _self.attributionId : attributionId // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,executor: null == executor ? _self.executor : executor // ignore: cast_nullable_to_non_nullable
as AiExecutorSnapshot,privacyClassification: null == privacyClassification ? _self.privacyClassification : privacyClassification // ignore: cast_nullable_to_non_nullable
as AiPrivacyClassification,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as AiAttributionPendingPhase,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastUpdatedAt: null == lastUpdatedAt ? _self.lastUpdatedAt : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intendedOutputs: null == intendedOutputs ? _self._intendedOutputs : intendedOutputs // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,sourceArtifacts: null == sourceArtifacts ? _self._sourceArtifacts : sourceArtifacts // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,contextArtifacts: null == contextArtifacts ? _self._contextArtifacts : contextArtifacts // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,interactionIds: null == interactionIds ? _self._interactionIds : interactionIds // ignore: cast_nullable_to_non_nullable
as List<String>,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,terminalAttributionId: freezed == terminalAttributionId ? _self.terminalAttributionId : terminalAttributionId // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of AiAttributionPendingSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiExecutorSnapshotCopyWith<$Res> get executor {
  
  return $AiExecutorSnapshotCopyWith<$Res>(_self.executor, (value) {
    return _then(_self.copyWith(executor: value));
  });
}
}

// dart format on
