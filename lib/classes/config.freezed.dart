// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MatrixConfig {

 String get homeServer; String get user; String get password;/// The operator's signature over this account's identity, kept from the
/// bundle that provisioned it so every handover this device issues
/// carries it on. Null for self-hosted and hand-typed accounts.
@JsonKey(includeIfNull: false) BundleAttestation? get attestation;
/// Create a copy of MatrixConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MatrixConfigCopyWith<MatrixConfig> get copyWith => _$MatrixConfigCopyWithImpl<MatrixConfig>(this as MatrixConfig, _$identity);

  /// Serializes this MatrixConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MatrixConfig&&(identical(other.homeServer, homeServer) || other.homeServer == homeServer)&&(identical(other.user, user) || other.user == user)&&(identical(other.password, password) || other.password == password)&&(identical(other.attestation, attestation) || other.attestation == attestation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,homeServer,user,password,attestation);



}

/// @nodoc
abstract mixin class $MatrixConfigCopyWith<$Res>  {
  factory $MatrixConfigCopyWith(MatrixConfig value, $Res Function(MatrixConfig) _then) = _$MatrixConfigCopyWithImpl;
@useResult
$Res call({
 String homeServer, String user, String password,@JsonKey(includeIfNull: false) BundleAttestation? attestation
});


$BundleAttestationCopyWith<$Res>? get attestation;

}
/// @nodoc
class _$MatrixConfigCopyWithImpl<$Res>
    implements $MatrixConfigCopyWith<$Res> {
  _$MatrixConfigCopyWithImpl(this._self, this._then);

  final MatrixConfig _self;
  final $Res Function(MatrixConfig) _then;

/// Create a copy of MatrixConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? homeServer = null,Object? user = null,Object? password = null,Object? attestation = freezed,}) {
  return _then(_self.copyWith(
homeServer: null == homeServer ? _self.homeServer : homeServer // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,attestation: freezed == attestation ? _self.attestation : attestation // ignore: cast_nullable_to_non_nullable
as BundleAttestation?,
  ));
}
/// Create a copy of MatrixConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BundleAttestationCopyWith<$Res>? get attestation {
    if (_self.attestation == null) {
    return null;
  }

  return $BundleAttestationCopyWith<$Res>(_self.attestation!, (value) {
    return _then(_self.copyWith(attestation: value));
  });
}
}


/// Adds pattern-matching-related methods to [MatrixConfig].
extension MatrixConfigPatterns on MatrixConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MatrixConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MatrixConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MatrixConfig value)  $default,){
final _that = this;
switch (_that) {
case _MatrixConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MatrixConfig value)?  $default,){
final _that = this;
switch (_that) {
case _MatrixConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String homeServer,  String user,  String password, @JsonKey(includeIfNull: false)  BundleAttestation? attestation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MatrixConfig() when $default != null:
return $default(_that.homeServer,_that.user,_that.password,_that.attestation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String homeServer,  String user,  String password, @JsonKey(includeIfNull: false)  BundleAttestation? attestation)  $default,) {final _that = this;
switch (_that) {
case _MatrixConfig():
return $default(_that.homeServer,_that.user,_that.password,_that.attestation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String homeServer,  String user,  String password, @JsonKey(includeIfNull: false)  BundleAttestation? attestation)?  $default,) {final _that = this;
switch (_that) {
case _MatrixConfig() when $default != null:
return $default(_that.homeServer,_that.user,_that.password,_that.attestation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MatrixConfig implements MatrixConfig {
  const _MatrixConfig({required this.homeServer, required this.user, required this.password, @JsonKey(includeIfNull: false) this.attestation});
  factory _MatrixConfig.fromJson(Map<String, dynamic> json) => _$MatrixConfigFromJson(json);

@override final  String homeServer;
@override final  String user;
@override final  String password;
/// The operator's signature over this account's identity, kept from the
/// bundle that provisioned it so every handover this device issues
/// carries it on. Null for self-hosted and hand-typed accounts.
@override@JsonKey(includeIfNull: false) final  BundleAttestation? attestation;

/// Create a copy of MatrixConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MatrixConfigCopyWith<_MatrixConfig> get copyWith => __$MatrixConfigCopyWithImpl<_MatrixConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MatrixConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MatrixConfig&&(identical(other.homeServer, homeServer) || other.homeServer == homeServer)&&(identical(other.user, user) || other.user == user)&&(identical(other.password, password) || other.password == password)&&(identical(other.attestation, attestation) || other.attestation == attestation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,homeServer,user,password,attestation);



}

/// @nodoc
abstract mixin class _$MatrixConfigCopyWith<$Res> implements $MatrixConfigCopyWith<$Res> {
  factory _$MatrixConfigCopyWith(_MatrixConfig value, $Res Function(_MatrixConfig) _then) = __$MatrixConfigCopyWithImpl;
@override @useResult
$Res call({
 String homeServer, String user, String password,@JsonKey(includeIfNull: false) BundleAttestation? attestation
});


@override $BundleAttestationCopyWith<$Res>? get attestation;

}
/// @nodoc
class __$MatrixConfigCopyWithImpl<$Res>
    implements _$MatrixConfigCopyWith<$Res> {
  __$MatrixConfigCopyWithImpl(this._self, this._then);

  final _MatrixConfig _self;
  final $Res Function(_MatrixConfig) _then;

/// Create a copy of MatrixConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? homeServer = null,Object? user = null,Object? password = null,Object? attestation = freezed,}) {
  return _then(_MatrixConfig(
homeServer: null == homeServer ? _self.homeServer : homeServer // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,attestation: freezed == attestation ? _self.attestation : attestation // ignore: cast_nullable_to_non_nullable
as BundleAttestation?,
  ));
}

/// Create a copy of MatrixConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BundleAttestationCopyWith<$Res>? get attestation {
    if (_self.attestation == null) {
    return null;
  }

  return $BundleAttestationCopyWith<$Res>(_self.attestation!, (value) {
    return _then(_self.copyWith(attestation: value));
  });
}
}


/// @nodoc
mixin _$BundleAttestation {

 String get kid; int get iat; int get exp; String get sig;
/// Create a copy of BundleAttestation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BundleAttestationCopyWith<BundleAttestation> get copyWith => _$BundleAttestationCopyWithImpl<BundleAttestation>(this as BundleAttestation, _$identity);

  /// Serializes this BundleAttestation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BundleAttestation&&(identical(other.kid, kid) || other.kid == kid)&&(identical(other.iat, iat) || other.iat == iat)&&(identical(other.exp, exp) || other.exp == exp)&&(identical(other.sig, sig) || other.sig == sig));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kid,iat,exp,sig);

@override
String toString() {
  return 'BundleAttestation(kid: $kid, iat: $iat, exp: $exp, sig: $sig)';
}


}

/// @nodoc
abstract mixin class $BundleAttestationCopyWith<$Res>  {
  factory $BundleAttestationCopyWith(BundleAttestation value, $Res Function(BundleAttestation) _then) = _$BundleAttestationCopyWithImpl;
@useResult
$Res call({
 String kid, int iat, int exp, String sig
});




}
/// @nodoc
class _$BundleAttestationCopyWithImpl<$Res>
    implements $BundleAttestationCopyWith<$Res> {
  _$BundleAttestationCopyWithImpl(this._self, this._then);

  final BundleAttestation _self;
  final $Res Function(BundleAttestation) _then;

/// Create a copy of BundleAttestation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kid = null,Object? iat = null,Object? exp = null,Object? sig = null,}) {
  return _then(_self.copyWith(
kid: null == kid ? _self.kid : kid // ignore: cast_nullable_to_non_nullable
as String,iat: null == iat ? _self.iat : iat // ignore: cast_nullable_to_non_nullable
as int,exp: null == exp ? _self.exp : exp // ignore: cast_nullable_to_non_nullable
as int,sig: null == sig ? _self.sig : sig // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BundleAttestation].
extension BundleAttestationPatterns on BundleAttestation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BundleAttestation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BundleAttestation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BundleAttestation value)  $default,){
final _that = this;
switch (_that) {
case _BundleAttestation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BundleAttestation value)?  $default,){
final _that = this;
switch (_that) {
case _BundleAttestation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kid,  int iat,  int exp,  String sig)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BundleAttestation() when $default != null:
return $default(_that.kid,_that.iat,_that.exp,_that.sig);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kid,  int iat,  int exp,  String sig)  $default,) {final _that = this;
switch (_that) {
case _BundleAttestation():
return $default(_that.kid,_that.iat,_that.exp,_that.sig);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kid,  int iat,  int exp,  String sig)?  $default,) {final _that = this;
switch (_that) {
case _BundleAttestation() when $default != null:
return $default(_that.kid,_that.iat,_that.exp,_that.sig);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BundleAttestation implements BundleAttestation {
  const _BundleAttestation({required this.kid, required this.iat, required this.exp, required this.sig});
  factory _BundleAttestation.fromJson(Map<String, dynamic> json) => _$BundleAttestationFromJson(json);

@override final  String kid;
@override final  int iat;
@override final  int exp;
@override final  String sig;

/// Create a copy of BundleAttestation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BundleAttestationCopyWith<_BundleAttestation> get copyWith => __$BundleAttestationCopyWithImpl<_BundleAttestation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BundleAttestationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BundleAttestation&&(identical(other.kid, kid) || other.kid == kid)&&(identical(other.iat, iat) || other.iat == iat)&&(identical(other.exp, exp) || other.exp == exp)&&(identical(other.sig, sig) || other.sig == sig));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kid,iat,exp,sig);

@override
String toString() {
  return 'BundleAttestation(kid: $kid, iat: $iat, exp: $exp, sig: $sig)';
}


}

/// @nodoc
abstract mixin class _$BundleAttestationCopyWith<$Res> implements $BundleAttestationCopyWith<$Res> {
  factory _$BundleAttestationCopyWith(_BundleAttestation value, $Res Function(_BundleAttestation) _then) = __$BundleAttestationCopyWithImpl;
@override @useResult
$Res call({
 String kid, int iat, int exp, String sig
});




}
/// @nodoc
class __$BundleAttestationCopyWithImpl<$Res>
    implements _$BundleAttestationCopyWith<$Res> {
  __$BundleAttestationCopyWithImpl(this._self, this._then);

  final _BundleAttestation _self;
  final $Res Function(_BundleAttestation) _then;

/// Create a copy of BundleAttestation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kid = null,Object? iat = null,Object? exp = null,Object? sig = null,}) {
  return _then(_BundleAttestation(
kid: null == kid ? _self.kid : kid // ignore: cast_nullable_to_non_nullable
as String,iat: null == iat ? _self.iat : iat // ignore: cast_nullable_to_non_nullable
as int,exp: null == exp ? _self.exp : exp // ignore: cast_nullable_to_non_nullable
as int,sig: null == sig ? _self.sig : sig // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SyncProvisioningBundle {

 int get v; SyncBundleKind get kind; String get homeServer; String get user; String get password; String get roomId;@JsonKey(includeIfNull: false) BundleAttestation? get att;
/// Create a copy of SyncProvisioningBundle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SyncProvisioningBundleCopyWith<SyncProvisioningBundle> get copyWith => _$SyncProvisioningBundleCopyWithImpl<SyncProvisioningBundle>(this as SyncProvisioningBundle, _$identity);

  /// Serializes this SyncProvisioningBundle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SyncProvisioningBundle&&(identical(other.v, v) || other.v == v)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.homeServer, homeServer) || other.homeServer == homeServer)&&(identical(other.user, user) || other.user == user)&&(identical(other.password, password) || other.password == password)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.att, att) || other.att == att));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,v,kind,homeServer,user,password,roomId,att);



}

/// @nodoc
abstract mixin class $SyncProvisioningBundleCopyWith<$Res>  {
  factory $SyncProvisioningBundleCopyWith(SyncProvisioningBundle value, $Res Function(SyncProvisioningBundle) _then) = _$SyncProvisioningBundleCopyWithImpl;
@useResult
$Res call({
 int v, SyncBundleKind kind, String homeServer, String user, String password, String roomId,@JsonKey(includeIfNull: false) BundleAttestation? att
});


$BundleAttestationCopyWith<$Res>? get att;

}
/// @nodoc
class _$SyncProvisioningBundleCopyWithImpl<$Res>
    implements $SyncProvisioningBundleCopyWith<$Res> {
  _$SyncProvisioningBundleCopyWithImpl(this._self, this._then);

  final SyncProvisioningBundle _self;
  final $Res Function(SyncProvisioningBundle) _then;

/// Create a copy of SyncProvisioningBundle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? v = null,Object? kind = null,Object? homeServer = null,Object? user = null,Object? password = null,Object? roomId = null,Object? att = freezed,}) {
  return _then(_self.copyWith(
v: null == v ? _self.v : v // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as SyncBundleKind,homeServer: null == homeServer ? _self.homeServer : homeServer // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,att: freezed == att ? _self.att : att // ignore: cast_nullable_to_non_nullable
as BundleAttestation?,
  ));
}
/// Create a copy of SyncProvisioningBundle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BundleAttestationCopyWith<$Res>? get att {
    if (_self.att == null) {
    return null;
  }

  return $BundleAttestationCopyWith<$Res>(_self.att!, (value) {
    return _then(_self.copyWith(att: value));
  });
}
}


/// Adds pattern-matching-related methods to [SyncProvisioningBundle].
extension SyncProvisioningBundlePatterns on SyncProvisioningBundle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SyncProvisioningBundle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SyncProvisioningBundle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SyncProvisioningBundle value)  $default,){
final _that = this;
switch (_that) {
case _SyncProvisioningBundle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SyncProvisioningBundle value)?  $default,){
final _that = this;
switch (_that) {
case _SyncProvisioningBundle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int v,  SyncBundleKind kind,  String homeServer,  String user,  String password,  String roomId, @JsonKey(includeIfNull: false)  BundleAttestation? att)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SyncProvisioningBundle() when $default != null:
return $default(_that.v,_that.kind,_that.homeServer,_that.user,_that.password,_that.roomId,_that.att);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int v,  SyncBundleKind kind,  String homeServer,  String user,  String password,  String roomId, @JsonKey(includeIfNull: false)  BundleAttestation? att)  $default,) {final _that = this;
switch (_that) {
case _SyncProvisioningBundle():
return $default(_that.v,_that.kind,_that.homeServer,_that.user,_that.password,_that.roomId,_that.att);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int v,  SyncBundleKind kind,  String homeServer,  String user,  String password,  String roomId, @JsonKey(includeIfNull: false)  BundleAttestation? att)?  $default,) {final _that = this;
switch (_that) {
case _SyncProvisioningBundle() when $default != null:
return $default(_that.v,_that.kind,_that.homeServer,_that.user,_that.password,_that.roomId,_that.att);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SyncProvisioningBundle extends SyncProvisioningBundle {
  const _SyncProvisioningBundle({required this.v, required this.kind, required this.homeServer, required this.user, required this.password, required this.roomId, @JsonKey(includeIfNull: false) this.att}): super._();
  factory _SyncProvisioningBundle.fromJson(Map<String, dynamic> json) => _$SyncProvisioningBundleFromJson(json);

@override final  int v;
@override final  SyncBundleKind kind;
@override final  String homeServer;
@override final  String user;
@override final  String password;
@override final  String roomId;
@override@JsonKey(includeIfNull: false) final  BundleAttestation? att;

/// Create a copy of SyncProvisioningBundle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SyncProvisioningBundleCopyWith<_SyncProvisioningBundle> get copyWith => __$SyncProvisioningBundleCopyWithImpl<_SyncProvisioningBundle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SyncProvisioningBundleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SyncProvisioningBundle&&(identical(other.v, v) || other.v == v)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.homeServer, homeServer) || other.homeServer == homeServer)&&(identical(other.user, user) || other.user == user)&&(identical(other.password, password) || other.password == password)&&(identical(other.roomId, roomId) || other.roomId == roomId)&&(identical(other.att, att) || other.att == att));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,v,kind,homeServer,user,password,roomId,att);



}

/// @nodoc
abstract mixin class _$SyncProvisioningBundleCopyWith<$Res> implements $SyncProvisioningBundleCopyWith<$Res> {
  factory _$SyncProvisioningBundleCopyWith(_SyncProvisioningBundle value, $Res Function(_SyncProvisioningBundle) _then) = __$SyncProvisioningBundleCopyWithImpl;
@override @useResult
$Res call({
 int v, SyncBundleKind kind, String homeServer, String user, String password, String roomId,@JsonKey(includeIfNull: false) BundleAttestation? att
});


@override $BundleAttestationCopyWith<$Res>? get att;

}
/// @nodoc
class __$SyncProvisioningBundleCopyWithImpl<$Res>
    implements _$SyncProvisioningBundleCopyWith<$Res> {
  __$SyncProvisioningBundleCopyWithImpl(this._self, this._then);

  final _SyncProvisioningBundle _self;
  final $Res Function(_SyncProvisioningBundle) _then;

/// Create a copy of SyncProvisioningBundle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? v = null,Object? kind = null,Object? homeServer = null,Object? user = null,Object? password = null,Object? roomId = null,Object? att = freezed,}) {
  return _then(_SyncProvisioningBundle(
v: null == v ? _self.v : v // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as SyncBundleKind,homeServer: null == homeServer ? _self.homeServer : homeServer // ignore: cast_nullable_to_non_nullable
as String,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,roomId: null == roomId ? _self.roomId : roomId // ignore: cast_nullable_to_non_nullable
as String,att: freezed == att ? _self.att : att // ignore: cast_nullable_to_non_nullable
as BundleAttestation?,
  ));
}

/// Create a copy of SyncProvisioningBundle
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BundleAttestationCopyWith<$Res>? get att {
    if (_self.att == null) {
    return null;
  }

  return $BundleAttestationCopyWith<$Res>(_self.att!, (value) {
    return _then(_self.copyWith(att: value));
  });
}
}

// dart format on
