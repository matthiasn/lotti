// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_node_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SyncNodeProfile {

 String get hostId; String get displayName; String get platform; List<NodeCapability> get capabilities; DateTime get updatedAt; String? get osVersion; String? get cpuModel; int? get ramMb; String? get gpuModel; String? get appVersion;
/// Create a copy of SyncNodeProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncNodeProfileCopyWith<SyncNodeProfile> get copyWith => _$SyncNodeProfileCopyWithImpl<SyncNodeProfile>(this as SyncNodeProfile, _$identity);

  /// Serializes this SyncNodeProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncNodeProfile&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.platform, platform) || other.platform == platform)&&const DeepCollectionEquality().equals(other.capabilities, capabilities)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.osVersion, osVersion) || other.osVersion == osVersion)&&(identical(other.cpuModel, cpuModel) || other.cpuModel == cpuModel)&&(identical(other.ramMb, ramMb) || other.ramMb == ramMb)&&(identical(other.gpuModel, gpuModel) || other.gpuModel == gpuModel)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hostId,displayName,platform,const DeepCollectionEquality().hash(capabilities),updatedAt,osVersion,cpuModel,ramMb,gpuModel,appVersion);

@override
String toString() {
  return 'SyncNodeProfile(hostId: $hostId, displayName: $displayName, platform: $platform, capabilities: $capabilities, updatedAt: $updatedAt, osVersion: $osVersion, cpuModel: $cpuModel, ramMb: $ramMb, gpuModel: $gpuModel, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class $SyncNodeProfileCopyWith<$Res>  {
  factory $SyncNodeProfileCopyWith(SyncNodeProfile value, $Res Function(SyncNodeProfile) _then) = _$SyncNodeProfileCopyWithImpl;
@useResult
$Res call({
 String hostId, String displayName, String platform, List<NodeCapability> capabilities, DateTime updatedAt, String? osVersion, String? cpuModel, int? ramMb, String? gpuModel, String? appVersion
});




}
/// @nodoc
class _$SyncNodeProfileCopyWithImpl<$Res>
    implements $SyncNodeProfileCopyWith<$Res> {
  _$SyncNodeProfileCopyWithImpl(this._self, this._then);

  final SyncNodeProfile _self;
  final $Res Function(SyncNodeProfile) _then;

/// Create a copy of SyncNodeProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hostId = null,Object? displayName = null,Object? platform = null,Object? capabilities = null,Object? updatedAt = null,Object? osVersion = freezed,Object? cpuModel = freezed,Object? ramMb = freezed,Object? gpuModel = freezed,Object? appVersion = freezed,}) {
  return _then(_self.copyWith(
hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as List<NodeCapability>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,osVersion: freezed == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String?,cpuModel: freezed == cpuModel ? _self.cpuModel : cpuModel // ignore: cast_nullable_to_non_nullable
as String?,ramMb: freezed == ramMb ? _self.ramMb : ramMb // ignore: cast_nullable_to_non_nullable
as int?,gpuModel: freezed == gpuModel ? _self.gpuModel : gpuModel // ignore: cast_nullable_to_non_nullable
as String?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SyncNodeProfile].
extension SyncNodeProfilePatterns on SyncNodeProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncNodeProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncNodeProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncNodeProfile value)  $default,){
final _that = this;
switch (_that) {
case _SyncNodeProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncNodeProfile value)?  $default,){
final _that = this;
switch (_that) {
case _SyncNodeProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String hostId,  String displayName,  String platform,  List<NodeCapability> capabilities,  DateTime updatedAt,  String? osVersion,  String? cpuModel,  int? ramMb,  String? gpuModel,  String? appVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncNodeProfile() when $default != null:
return $default(_that.hostId,_that.displayName,_that.platform,_that.capabilities,_that.updatedAt,_that.osVersion,_that.cpuModel,_that.ramMb,_that.gpuModel,_that.appVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String hostId,  String displayName,  String platform,  List<NodeCapability> capabilities,  DateTime updatedAt,  String? osVersion,  String? cpuModel,  int? ramMb,  String? gpuModel,  String? appVersion)  $default,) {final _that = this;
switch (_that) {
case _SyncNodeProfile():
return $default(_that.hostId,_that.displayName,_that.platform,_that.capabilities,_that.updatedAt,_that.osVersion,_that.cpuModel,_that.ramMb,_that.gpuModel,_that.appVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String hostId,  String displayName,  String platform,  List<NodeCapability> capabilities,  DateTime updatedAt,  String? osVersion,  String? cpuModel,  int? ramMb,  String? gpuModel,  String? appVersion)?  $default,) {final _that = this;
switch (_that) {
case _SyncNodeProfile() when $default != null:
return $default(_that.hostId,_that.displayName,_that.platform,_that.capabilities,_that.updatedAt,_that.osVersion,_that.cpuModel,_that.ramMb,_that.gpuModel,_that.appVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncNodeProfile implements SyncNodeProfile {
  const _SyncNodeProfile({required this.hostId, required this.displayName, required this.platform, required final  List<NodeCapability> capabilities, required this.updatedAt, this.osVersion, this.cpuModel, this.ramMb, this.gpuModel, this.appVersion}): _capabilities = capabilities;
  factory _SyncNodeProfile.fromJson(Map<String, dynamic> json) => _$SyncNodeProfileFromJson(json);

@override final  String hostId;
@override final  String displayName;
@override final  String platform;
 final  List<NodeCapability> _capabilities;
@override List<NodeCapability> get capabilities {
  if (_capabilities is EqualUnmodifiableListView) return _capabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_capabilities);
}

@override final  DateTime updatedAt;
@override final  String? osVersion;
@override final  String? cpuModel;
@override final  int? ramMb;
@override final  String? gpuModel;
@override final  String? appVersion;

/// Create a copy of SyncNodeProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncNodeProfileCopyWith<_SyncNodeProfile> get copyWith => __$SyncNodeProfileCopyWithImpl<_SyncNodeProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncNodeProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncNodeProfile&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.platform, platform) || other.platform == platform)&&const DeepCollectionEquality().equals(other._capabilities, _capabilities)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.osVersion, osVersion) || other.osVersion == osVersion)&&(identical(other.cpuModel, cpuModel) || other.cpuModel == cpuModel)&&(identical(other.ramMb, ramMb) || other.ramMb == ramMb)&&(identical(other.gpuModel, gpuModel) || other.gpuModel == gpuModel)&&(identical(other.appVersion, appVersion) || other.appVersion == appVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hostId,displayName,platform,const DeepCollectionEquality().hash(_capabilities),updatedAt,osVersion,cpuModel,ramMb,gpuModel,appVersion);

@override
String toString() {
  return 'SyncNodeProfile(hostId: $hostId, displayName: $displayName, platform: $platform, capabilities: $capabilities, updatedAt: $updatedAt, osVersion: $osVersion, cpuModel: $cpuModel, ramMb: $ramMb, gpuModel: $gpuModel, appVersion: $appVersion)';
}


}

/// @nodoc
abstract mixin class _$SyncNodeProfileCopyWith<$Res> implements $SyncNodeProfileCopyWith<$Res> {
  factory _$SyncNodeProfileCopyWith(_SyncNodeProfile value, $Res Function(_SyncNodeProfile) _then) = __$SyncNodeProfileCopyWithImpl;
@override @useResult
$Res call({
 String hostId, String displayName, String platform, List<NodeCapability> capabilities, DateTime updatedAt, String? osVersion, String? cpuModel, int? ramMb, String? gpuModel, String? appVersion
});




}
/// @nodoc
class __$SyncNodeProfileCopyWithImpl<$Res>
    implements _$SyncNodeProfileCopyWith<$Res> {
  __$SyncNodeProfileCopyWithImpl(this._self, this._then);

  final _SyncNodeProfile _self;
  final $Res Function(_SyncNodeProfile) _then;

/// Create a copy of SyncNodeProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hostId = null,Object? displayName = null,Object? platform = null,Object? capabilities = null,Object? updatedAt = null,Object? osVersion = freezed,Object? cpuModel = freezed,Object? ramMb = freezed,Object? gpuModel = freezed,Object? appVersion = freezed,}) {
  return _then(_SyncNodeProfile(
hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,platform: null == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String,capabilities: null == capabilities ? _self._capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as List<NodeCapability>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,osVersion: freezed == osVersion ? _self.osVersion : osVersion // ignore: cast_nullable_to_non_nullable
as String?,cpuModel: freezed == cpuModel ? _self.cpuModel : cpuModel // ignore: cast_nullable_to_non_nullable
as String?,ramMb: freezed == ramMb ? _self.ramMb : ramMb // ignore: cast_nullable_to_non_nullable
as int?,gpuModel: freezed == gpuModel ? _self.gpuModel : gpuModel // ignore: cast_nullable_to_non_nullable
as String?,appVersion: freezed == appVersion ? _self.appVersion : appVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
