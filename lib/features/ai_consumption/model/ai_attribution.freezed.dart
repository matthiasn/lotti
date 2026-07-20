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
mixin _$AiWorkAttribution {

 String get id; AiWorkType get workType; AiWorkStatus get status; AiActorSnapshot get initiator; AiTriggerSnapshot get trigger; DateTime get startedAt; DateTime get completedAt; VectorClock? get vectorClock; String? get parentAttributionId; String? get taskId; String? get categoryId; AiArtifactReference? get primaryOutput; String? get errorCode; String? get errorSummary; int get schemaVersion;
/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiWorkAttributionCopyWith<AiWorkAttribution> get copyWith => _$AiWorkAttributionCopyWithImpl<AiWorkAttribution>(this as AiWorkAttribution, _$identity);

  /// Serializes this AiWorkAttribution to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiWorkAttribution&&(identical(other.id, id) || other.id == id)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.status, status) || other.status == status)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.primaryOutput, primaryOutput) || other.primaryOutput == primaryOutput)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorSummary, errorSummary) || other.errorSummary == errorSummary)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workType,status,initiator,trigger,startedAt,completedAt,vectorClock,parentAttributionId,taskId,categoryId,primaryOutput,errorCode,errorSummary,schemaVersion);

@override
String toString() {
  return 'AiWorkAttribution(id: $id, workType: $workType, status: $status, initiator: $initiator, trigger: $trigger, startedAt: $startedAt, completedAt: $completedAt, vectorClock: $vectorClock, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, primaryOutput: $primaryOutput, errorCode: $errorCode, errorSummary: $errorSummary, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $AiWorkAttributionCopyWith<$Res>  {
  factory $AiWorkAttributionCopyWith(AiWorkAttribution value, $Res Function(AiWorkAttribution) _then) = _$AiWorkAttributionCopyWithImpl;
@useResult
$Res call({
 String id, AiWorkType workType, AiWorkStatus status, AiActorSnapshot initiator, AiTriggerSnapshot trigger, DateTime startedAt, DateTime completedAt, VectorClock? vectorClock, String? parentAttributionId, String? taskId, String? categoryId, AiArtifactReference? primaryOutput, String? errorCode, String? errorSummary, int schemaVersion
});


$AiActorSnapshotCopyWith<$Res> get initiator;$AiTriggerSnapshotCopyWith<$Res> get trigger;$AiArtifactReferenceCopyWith<$Res>? get primaryOutput;

}
/// @nodoc
class _$AiWorkAttributionCopyWithImpl<$Res>
    implements $AiWorkAttributionCopyWith<$Res> {
  _$AiWorkAttributionCopyWithImpl(this._self, this._then);

  final AiWorkAttribution _self;
  final $Res Function(AiWorkAttribution) _then;

/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workType = null,Object? status = null,Object? initiator = null,Object? trigger = null,Object? startedAt = null,Object? completedAt = null,Object? vectorClock = freezed,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? primaryOutput = freezed,Object? errorCode = freezed,Object? errorSummary = freezed,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AiWorkStatus,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AiWorkType workType,  AiWorkStatus status,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  DateTime startedAt,  DateTime completedAt,  VectorClock? vectorClock,  String? parentAttributionId,  String? taskId,  String? categoryId,  AiArtifactReference? primaryOutput,  String? errorCode,  String? errorSummary,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiWorkAttribution() when $default != null:
return $default(_that.id,_that.workType,_that.status,_that.initiator,_that.trigger,_that.startedAt,_that.completedAt,_that.vectorClock,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.primaryOutput,_that.errorCode,_that.errorSummary,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AiWorkType workType,  AiWorkStatus status,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  DateTime startedAt,  DateTime completedAt,  VectorClock? vectorClock,  String? parentAttributionId,  String? taskId,  String? categoryId,  AiArtifactReference? primaryOutput,  String? errorCode,  String? errorSummary,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _AiWorkAttribution():
return $default(_that.id,_that.workType,_that.status,_that.initiator,_that.trigger,_that.startedAt,_that.completedAt,_that.vectorClock,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.primaryOutput,_that.errorCode,_that.errorSummary,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AiWorkType workType,  AiWorkStatus status,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  DateTime startedAt,  DateTime completedAt,  VectorClock? vectorClock,  String? parentAttributionId,  String? taskId,  String? categoryId,  AiArtifactReference? primaryOutput,  String? errorCode,  String? errorSummary,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _AiWorkAttribution() when $default != null:
return $default(_that.id,_that.workType,_that.status,_that.initiator,_that.trigger,_that.startedAt,_that.completedAt,_that.vectorClock,_that.parentAttributionId,_that.taskId,_that.categoryId,_that.primaryOutput,_that.errorCode,_that.errorSummary,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiWorkAttribution implements AiWorkAttribution {
  const _AiWorkAttribution({required this.id, required this.workType, required this.status, required this.initiator, required this.trigger, required this.startedAt, required this.completedAt, required this.vectorClock, this.parentAttributionId, this.taskId, this.categoryId, this.primaryOutput, this.errorCode, this.errorSummary, this.schemaVersion = 1});
  factory _AiWorkAttribution.fromJson(Map<String, dynamic> json) => _$AiWorkAttributionFromJson(json);

@override final  String id;
@override final  AiWorkType workType;
@override final  AiWorkStatus status;
@override final  AiActorSnapshot initiator;
@override final  AiTriggerSnapshot trigger;
@override final  DateTime startedAt;
@override final  DateTime completedAt;
@override final  VectorClock? vectorClock;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiWorkAttribution&&(identical(other.id, id) || other.id == id)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.status, status) || other.status == status)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.primaryOutput, primaryOutput) || other.primaryOutput == primaryOutput)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorSummary, errorSummary) || other.errorSummary == errorSummary)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workType,status,initiator,trigger,startedAt,completedAt,vectorClock,parentAttributionId,taskId,categoryId,primaryOutput,errorCode,errorSummary,schemaVersion);

@override
String toString() {
  return 'AiWorkAttribution(id: $id, workType: $workType, status: $status, initiator: $initiator, trigger: $trigger, startedAt: $startedAt, completedAt: $completedAt, vectorClock: $vectorClock, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId, primaryOutput: $primaryOutput, errorCode: $errorCode, errorSummary: $errorSummary, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$AiWorkAttributionCopyWith<$Res> implements $AiWorkAttributionCopyWith<$Res> {
  factory _$AiWorkAttributionCopyWith(_AiWorkAttribution value, $Res Function(_AiWorkAttribution) _then) = __$AiWorkAttributionCopyWithImpl;
@override @useResult
$Res call({
 String id, AiWorkType workType, AiWorkStatus status, AiActorSnapshot initiator, AiTriggerSnapshot trigger, DateTime startedAt, DateTime completedAt, VectorClock? vectorClock, String? parentAttributionId, String? taskId, String? categoryId, AiArtifactReference? primaryOutput, String? errorCode, String? errorSummary, int schemaVersion
});


@override $AiActorSnapshotCopyWith<$Res> get initiator;@override $AiTriggerSnapshotCopyWith<$Res> get trigger;@override $AiArtifactReferenceCopyWith<$Res>? get primaryOutput;

}
/// @nodoc
class __$AiWorkAttributionCopyWithImpl<$Res>
    implements _$AiWorkAttributionCopyWith<$Res> {
  __$AiWorkAttributionCopyWithImpl(this._self, this._then);

  final _AiWorkAttribution _self;
  final $Res Function(_AiWorkAttribution) _then;

/// Create a copy of AiWorkAttribution
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workType = null,Object? status = null,Object? initiator = null,Object? trigger = null,Object? startedAt = null,Object? completedAt = null,Object? vectorClock = freezed,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,Object? primaryOutput = freezed,Object? errorCode = freezed,Object? errorSummary = freezed,Object? schemaVersion = null,}) {
  return _then(_AiWorkAttribution(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AiWorkStatus,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
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
mixin _$AiAttributionSession {

 String get id; AiWorkType get workType; AiActorSnapshot get initiator; AiTriggerSnapshot get trigger; DateTime get startedAt; List<AiArtifactReference> get intendedOutputs; String? get parentAttributionId; String? get taskId; String? get categoryId;
/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AiAttributionSessionCopyWith<AiAttributionSession> get copyWith => _$AiAttributionSessionCopyWithImpl<AiAttributionSession>(this as AiAttributionSession, _$identity);

  /// Serializes this AiAttributionSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AiAttributionSession&&(identical(other.id, id) || other.id == id)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other.intendedOutputs, intendedOutputs)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workType,initiator,trigger,startedAt,const DeepCollectionEquality().hash(intendedOutputs),parentAttributionId,taskId,categoryId);

@override
String toString() {
  return 'AiAttributionSession(id: $id, workType: $workType, initiator: $initiator, trigger: $trigger, startedAt: $startedAt, intendedOutputs: $intendedOutputs, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId)';
}


}

/// @nodoc
abstract mixin class $AiAttributionSessionCopyWith<$Res>  {
  factory $AiAttributionSessionCopyWith(AiAttributionSession value, $Res Function(AiAttributionSession) _then) = _$AiAttributionSessionCopyWithImpl;
@useResult
$Res call({
 String id, AiWorkType workType, AiActorSnapshot initiator, AiTriggerSnapshot trigger, DateTime startedAt, List<AiArtifactReference> intendedOutputs, String? parentAttributionId, String? taskId, String? categoryId
});


$AiActorSnapshotCopyWith<$Res> get initiator;$AiTriggerSnapshotCopyWith<$Res> get trigger;

}
/// @nodoc
class _$AiAttributionSessionCopyWithImpl<$Res>
    implements $AiAttributionSessionCopyWith<$Res> {
  _$AiAttributionSessionCopyWithImpl(this._self, this._then);

  final AiAttributionSession _self;
  final $Res Function(AiAttributionSession) _then;

/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workType = null,Object? initiator = null,Object? trigger = null,Object? startedAt = null,Object? intendedOutputs = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intendedOutputs: null == intendedOutputs ? _self.intendedOutputs : intendedOutputs // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}
}


/// Adds pattern-matching-related methods to [AiAttributionSession].
extension AiAttributionSessionPatterns on AiAttributionSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AiAttributionSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AiAttributionSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AiAttributionSession value)  $default,){
final _that = this;
switch (_that) {
case _AiAttributionSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AiAttributionSession value)?  $default,){
final _that = this;
switch (_that) {
case _AiAttributionSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  DateTime startedAt,  List<AiArtifactReference> intendedOutputs,  String? parentAttributionId,  String? taskId,  String? categoryId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AiAttributionSession() when $default != null:
return $default(_that.id,_that.workType,_that.initiator,_that.trigger,_that.startedAt,_that.intendedOutputs,_that.parentAttributionId,_that.taskId,_that.categoryId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  DateTime startedAt,  List<AiArtifactReference> intendedOutputs,  String? parentAttributionId,  String? taskId,  String? categoryId)  $default,) {final _that = this;
switch (_that) {
case _AiAttributionSession():
return $default(_that.id,_that.workType,_that.initiator,_that.trigger,_that.startedAt,_that.intendedOutputs,_that.parentAttributionId,_that.taskId,_that.categoryId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AiWorkType workType,  AiActorSnapshot initiator,  AiTriggerSnapshot trigger,  DateTime startedAt,  List<AiArtifactReference> intendedOutputs,  String? parentAttributionId,  String? taskId,  String? categoryId)?  $default,) {final _that = this;
switch (_that) {
case _AiAttributionSession() when $default != null:
return $default(_that.id,_that.workType,_that.initiator,_that.trigger,_that.startedAt,_that.intendedOutputs,_that.parentAttributionId,_that.taskId,_that.categoryId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AiAttributionSession implements AiAttributionSession {
  const _AiAttributionSession({required this.id, required this.workType, required this.initiator, required this.trigger, required this.startedAt, final  List<AiArtifactReference> intendedOutputs = const <AiArtifactReference>[], this.parentAttributionId, this.taskId, this.categoryId}): _intendedOutputs = intendedOutputs;
  factory _AiAttributionSession.fromJson(Map<String, dynamic> json) => _$AiAttributionSessionFromJson(json);

@override final  String id;
@override final  AiWorkType workType;
@override final  AiActorSnapshot initiator;
@override final  AiTriggerSnapshot trigger;
@override final  DateTime startedAt;
 final  List<AiArtifactReference> _intendedOutputs;
@override@JsonKey() List<AiArtifactReference> get intendedOutputs {
  if (_intendedOutputs is EqualUnmodifiableListView) return _intendedOutputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_intendedOutputs);
}

@override final  String? parentAttributionId;
@override final  String? taskId;
@override final  String? categoryId;

/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AiAttributionSessionCopyWith<_AiAttributionSession> get copyWith => __$AiAttributionSessionCopyWithImpl<_AiAttributionSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AiAttributionSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AiAttributionSession&&(identical(other.id, id) || other.id == id)&&(identical(other.workType, workType) || other.workType == workType)&&(identical(other.initiator, initiator) || other.initiator == initiator)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&const DeepCollectionEquality().equals(other._intendedOutputs, _intendedOutputs)&&(identical(other.parentAttributionId, parentAttributionId) || other.parentAttributionId == parentAttributionId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workType,initiator,trigger,startedAt,const DeepCollectionEquality().hash(_intendedOutputs),parentAttributionId,taskId,categoryId);

@override
String toString() {
  return 'AiAttributionSession(id: $id, workType: $workType, initiator: $initiator, trigger: $trigger, startedAt: $startedAt, intendedOutputs: $intendedOutputs, parentAttributionId: $parentAttributionId, taskId: $taskId, categoryId: $categoryId)';
}


}

/// @nodoc
abstract mixin class _$AiAttributionSessionCopyWith<$Res> implements $AiAttributionSessionCopyWith<$Res> {
  factory _$AiAttributionSessionCopyWith(_AiAttributionSession value, $Res Function(_AiAttributionSession) _then) = __$AiAttributionSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, AiWorkType workType, AiActorSnapshot initiator, AiTriggerSnapshot trigger, DateTime startedAt, List<AiArtifactReference> intendedOutputs, String? parentAttributionId, String? taskId, String? categoryId
});


@override $AiActorSnapshotCopyWith<$Res> get initiator;@override $AiTriggerSnapshotCopyWith<$Res> get trigger;

}
/// @nodoc
class __$AiAttributionSessionCopyWithImpl<$Res>
    implements _$AiAttributionSessionCopyWith<$Res> {
  __$AiAttributionSessionCopyWithImpl(this._self, this._then);

  final _AiAttributionSession _self;
  final $Res Function(_AiAttributionSession) _then;

/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workType = null,Object? initiator = null,Object? trigger = null,Object? startedAt = null,Object? intendedOutputs = null,Object? parentAttributionId = freezed,Object? taskId = freezed,Object? categoryId = freezed,}) {
  return _then(_AiAttributionSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workType: null == workType ? _self.workType : workType // ignore: cast_nullable_to_non_nullable
as AiWorkType,initiator: null == initiator ? _self.initiator : initiator // ignore: cast_nullable_to_non_nullable
as AiActorSnapshot,trigger: null == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as AiTriggerSnapshot,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,intendedOutputs: null == intendedOutputs ? _self._intendedOutputs : intendedOutputs // ignore: cast_nullable_to_non_nullable
as List<AiArtifactReference>,parentAttributionId: freezed == parentAttributionId ? _self.parentAttributionId : parentAttributionId // ignore: cast_nullable_to_non_nullable
as String?,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiActorSnapshotCopyWith<$Res> get initiator {
  
  return $AiActorSnapshotCopyWith<$Res>(_self.initiator, (value) {
    return _then(_self.copyWith(initiator: value));
  });
}/// Create a copy of AiAttributionSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AiTriggerSnapshotCopyWith<$Res> get trigger {
  
  return $AiTriggerSnapshotCopyWith<$Res>(_self.trigger, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}
}

// dart format on
