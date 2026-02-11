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
  String get homeServer;
  String get user;
  String get password;

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MatrixConfigCopyWith<MatrixConfig> get copyWith =>
      _$MatrixConfigCopyWithImpl<MatrixConfig>(
          this as MatrixConfig, _$identity);

  /// Serializes this MatrixConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MatrixConfig &&
            (identical(other.homeServer, homeServer) ||
                other.homeServer == homeServer) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.password, password) ||
                other.password == password));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, homeServer, user, password);
}

/// @nodoc
abstract mixin class $MatrixConfigCopyWith<$Res> {
  factory $MatrixConfigCopyWith(
          MatrixConfig value, $Res Function(MatrixConfig) _then) =
      _$MatrixConfigCopyWithImpl;
  @useResult
  $Res call({String homeServer, String user, String password});
}

/// @nodoc
class _$MatrixConfigCopyWithImpl<$Res> implements $MatrixConfigCopyWith<$Res> {
  _$MatrixConfigCopyWithImpl(this._self, this._then);

  final MatrixConfig _self;
  final $Res Function(MatrixConfig) _then;

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? homeServer = null,
    Object? user = null,
    Object? password = null,
  }) {
    return _then(_self.copyWith(
      homeServer: null == homeServer
          ? _self.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
    ));
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_MatrixConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MatrixConfig() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_MatrixConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MatrixConfig():
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_MatrixConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MatrixConfig() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String homeServer, String user, String password)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MatrixConfig() when $default != null:
        return $default(_that.homeServer, _that.user, _that.password);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String homeServer, String user, String password) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MatrixConfig():
        return $default(_that.homeServer, _that.user, _that.password);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String homeServer, String user, String password)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MatrixConfig() when $default != null:
        return $default(_that.homeServer, _that.user, _that.password);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MatrixConfig implements MatrixConfig {
  const _MatrixConfig(
      {required this.homeServer, required this.user, required this.password});
  factory _MatrixConfig.fromJson(Map<String, dynamic> json) =>
      _$MatrixConfigFromJson(json);

  @override
  final String homeServer;
  @override
  final String user;
  @override
  final String password;

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MatrixConfigCopyWith<_MatrixConfig> get copyWith =>
      __$MatrixConfigCopyWithImpl<_MatrixConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MatrixConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MatrixConfig &&
            (identical(other.homeServer, homeServer) ||
                other.homeServer == homeServer) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.password, password) ||
                other.password == password));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, homeServer, user, password);
}

/// @nodoc
abstract mixin class _$MatrixConfigCopyWith<$Res>
    implements $MatrixConfigCopyWith<$Res> {
  factory _$MatrixConfigCopyWith(
          _MatrixConfig value, $Res Function(_MatrixConfig) _then) =
      __$MatrixConfigCopyWithImpl;
  @override
  @useResult
  $Res call({String homeServer, String user, String password});
}

/// @nodoc
class __$MatrixConfigCopyWithImpl<$Res>
    implements _$MatrixConfigCopyWith<$Res> {
  __$MatrixConfigCopyWithImpl(this._self, this._then);

  final _MatrixConfig _self;
  final $Res Function(_MatrixConfig) _then;

  /// Create a copy of MatrixConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? homeServer = null,
    Object? user = null,
    Object? password = null,
  }) {
    return _then(_MatrixConfig(
      homeServer: null == homeServer
          ? _self.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$SyncProvisioningBundle {
  int get v;
  String get homeServer;
  String get user;
  String get password;
  String get roomId;

  /// Create a copy of SyncProvisioningBundle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncProvisioningBundleCopyWith<SyncProvisioningBundle> get copyWith =>
      _$SyncProvisioningBundleCopyWithImpl<SyncProvisioningBundle>(
          this as SyncProvisioningBundle, _$identity);

  /// Serializes this SyncProvisioningBundle to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncProvisioningBundle &&
            (identical(other.v, v) || other.v == v) &&
            (identical(other.homeServer, homeServer) ||
                other.homeServer == homeServer) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.roomId, roomId) || other.roomId == roomId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, v, homeServer, user, password, roomId);
}

/// @nodoc
abstract mixin class $SyncProvisioningBundleCopyWith<$Res> {
  factory $SyncProvisioningBundleCopyWith(SyncProvisioningBundle value,
          $Res Function(SyncProvisioningBundle) _then) =
      _$SyncProvisioningBundleCopyWithImpl;
  @useResult
  $Res call(
      {int v, String homeServer, String user, String password, String roomId});
}

/// @nodoc
class _$SyncProvisioningBundleCopyWithImpl<$Res>
    implements $SyncProvisioningBundleCopyWith<$Res> {
  _$SyncProvisioningBundleCopyWithImpl(this._self, this._then);

  final SyncProvisioningBundle _self;
  final $Res Function(SyncProvisioningBundle) _then;

  /// Create a copy of SyncProvisioningBundle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? v = null,
    Object? homeServer = null,
    Object? user = null,
    Object? password = null,
    Object? roomId = null,
  }) {
    return _then(_self.copyWith(
      v: null == v
          ? _self.v
          : v // ignore: cast_nullable_to_non_nullable
              as int,
      homeServer: null == homeServer
          ? _self.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _self.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SyncProvisioningBundle value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncProvisioningBundle() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SyncProvisioningBundle value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncProvisioningBundle():
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SyncProvisioningBundle value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncProvisioningBundle() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(int v, String homeServer, String user, String password,
            String roomId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncProvisioningBundle() when $default != null:
        return $default(_that.v, _that.homeServer, _that.user, _that.password,
            _that.roomId);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(int v, String homeServer, String user, String password,
            String roomId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncProvisioningBundle():
        return $default(_that.v, _that.homeServer, _that.user, _that.password,
            _that.roomId);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(int v, String homeServer, String user, String password,
            String roomId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncProvisioningBundle() when $default != null:
        return $default(_that.v, _that.homeServer, _that.user, _that.password,
            _that.roomId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SyncProvisioningBundle extends SyncProvisioningBundle {
  const _SyncProvisioningBundle(
      {required this.v,
      required this.homeServer,
      required this.user,
      required this.password,
      required this.roomId})
      : super._();
  factory _SyncProvisioningBundle.fromJson(Map<String, dynamic> json) =>
      _$SyncProvisioningBundleFromJson(json);

  @override
  final int v;
  @override
  final String homeServer;
  @override
  final String user;
  @override
  final String password;
  @override
  final String roomId;

  /// Create a copy of SyncProvisioningBundle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SyncProvisioningBundleCopyWith<_SyncProvisioningBundle> get copyWith =>
      __$SyncProvisioningBundleCopyWithImpl<_SyncProvisioningBundle>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncProvisioningBundleToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SyncProvisioningBundle &&
            (identical(other.v, v) || other.v == v) &&
            (identical(other.homeServer, homeServer) ||
                other.homeServer == homeServer) &&
            (identical(other.user, user) || other.user == user) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.roomId, roomId) || other.roomId == roomId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, v, homeServer, user, password, roomId);
}

/// @nodoc
abstract mixin class _$SyncProvisioningBundleCopyWith<$Res>
    implements $SyncProvisioningBundleCopyWith<$Res> {
  factory _$SyncProvisioningBundleCopyWith(_SyncProvisioningBundle value,
          $Res Function(_SyncProvisioningBundle) _then) =
      __$SyncProvisioningBundleCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int v, String homeServer, String user, String password, String roomId});
}

/// @nodoc
class __$SyncProvisioningBundleCopyWithImpl<$Res>
    implements _$SyncProvisioningBundleCopyWith<$Res> {
  __$SyncProvisioningBundleCopyWithImpl(this._self, this._then);

  final _SyncProvisioningBundle _self;
  final $Res Function(_SyncProvisioningBundle) _then;

  /// Create a copy of SyncProvisioningBundle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? v = null,
    Object? homeServer = null,
    Object? user = null,
    Object? password = null,
    Object? roomId = null,
  }) {
    return _then(_SyncProvisioningBundle(
      v: null == v
          ? _self.v
          : v // ignore: cast_nullable_to_non_nullable
              as int,
      homeServer: null == homeServer
          ? _self.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as String,
      user: null == user
          ? _self.user
          : user // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      roomId: null == roomId
          ? _self.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
