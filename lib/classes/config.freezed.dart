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
mixin _$ImapConfig {
  String get host;
  String get folder;
  String get userName;
  String get password;
  int get port;

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<ImapConfig> get copyWith =>
      _$ImapConfigCopyWithImpl<ImapConfig>(this as ImapConfig, _$identity);

  /// Serializes this ImapConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImapConfig &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.folder, folder) || other.folder == folder) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.port, port) || other.port == port));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, host, folder, userName, password, port);

  @override
  String toString() {
    return 'ImapConfig(host: $host, folder: $folder, userName: $userName, password: $password, port: $port)';
  }
}

/// @nodoc
abstract mixin class $ImapConfigCopyWith<$Res> {
  factory $ImapConfigCopyWith(
          ImapConfig value, $Res Function(ImapConfig) _then) =
      _$ImapConfigCopyWithImpl;
  @useResult
  $Res call(
      {String host, String folder, String userName, String password, int port});
}

/// @nodoc
class _$ImapConfigCopyWithImpl<$Res> implements $ImapConfigCopyWith<$Res> {
  _$ImapConfigCopyWithImpl(this._self, this._then);

  final ImapConfig _self;
  final $Res Function(ImapConfig) _then;

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? folder = null,
    Object? userName = null,
    Object? password = null,
    Object? port = null,
  }) {
    return _then(_self.copyWith(
      host: null == host
          ? _self.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _self.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
      userName: null == userName
          ? _self.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _self.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [ImapConfig].
extension ImapConfigPatterns on ImapConfig {
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
    TResult Function(_ImapConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImapConfig() when $default != null:
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
    TResult Function(_ImapConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImapConfig():
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
    TResult? Function(_ImapConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImapConfig() when $default != null:
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
    TResult Function(String host, String folder, String userName,
            String password, int port)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ImapConfig() when $default != null:
        return $default(_that.host, _that.folder, _that.userName,
            _that.password, _that.port);
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
    TResult Function(String host, String folder, String userName,
            String password, int port)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImapConfig():
        return $default(_that.host, _that.folder, _that.userName,
            _that.password, _that.port);
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
    TResult? Function(String host, String folder, String userName,
            String password, int port)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ImapConfig() when $default != null:
        return $default(_that.host, _that.folder, _that.userName,
            _that.password, _that.port);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ImapConfig implements ImapConfig {
  const _ImapConfig(
      {required this.host,
      required this.folder,
      required this.userName,
      required this.password,
      required this.port});
  factory _ImapConfig.fromJson(Map<String, dynamic> json) =>
      _$ImapConfigFromJson(json);

  @override
  final String host;
  @override
  final String folder;
  @override
  final String userName;
  @override
  final String password;
  @override
  final int port;

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ImapConfigCopyWith<_ImapConfig> get copyWith =>
      __$ImapConfigCopyWithImpl<_ImapConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ImapConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ImapConfig &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.folder, folder) || other.folder == folder) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.port, port) || other.port == port));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, host, folder, userName, password, port);

  @override
  String toString() {
    return 'ImapConfig(host: $host, folder: $folder, userName: $userName, password: $password, port: $port)';
  }
}

/// @nodoc
abstract mixin class _$ImapConfigCopyWith<$Res>
    implements $ImapConfigCopyWith<$Res> {
  factory _$ImapConfigCopyWith(
          _ImapConfig value, $Res Function(_ImapConfig) _then) =
      __$ImapConfigCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String host, String folder, String userName, String password, int port});
}

/// @nodoc
class __$ImapConfigCopyWithImpl<$Res> implements _$ImapConfigCopyWith<$Res> {
  __$ImapConfigCopyWithImpl(this._self, this._then);

  final _ImapConfig _self;
  final $Res Function(_ImapConfig) _then;

  /// Create a copy of ImapConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? host = null,
    Object? folder = null,
    Object? userName = null,
    Object? password = null,
    Object? port = null,
  }) {
    return _then(_ImapConfig(
      host: null == host
          ? _self.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _self.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
      userName: null == userName
          ? _self.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as String,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as String,
      port: null == port
          ? _self.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

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

  @override
  String toString() {
    return 'MatrixConfig(homeServer: $homeServer, user: $user, password: $password)';
  }
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

  @override
  String toString() {
    return 'MatrixConfig(homeServer: $homeServer, user: $user, password: $password)';
  }
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
mixin _$SyncConfig {
  ImapConfig get imapConfig;
  String get sharedSecret;

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncConfigCopyWith<SyncConfig> get copyWith =>
      _$SyncConfigCopyWithImpl<SyncConfig>(this as SyncConfig, _$identity);

  /// Serializes this SyncConfig to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncConfig &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig) &&
            (identical(other.sharedSecret, sharedSecret) ||
                other.sharedSecret == sharedSecret));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, imapConfig, sharedSecret);

  @override
  String toString() {
    return 'SyncConfig(imapConfig: $imapConfig, sharedSecret: $sharedSecret)';
  }
}

/// @nodoc
abstract mixin class $SyncConfigCopyWith<$Res> {
  factory $SyncConfigCopyWith(
          SyncConfig value, $Res Function(SyncConfig) _then) =
      _$SyncConfigCopyWithImpl;
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class _$SyncConfigCopyWithImpl<$Res> implements $SyncConfigCopyWith<$Res> {
  _$SyncConfigCopyWithImpl(this._self, this._then);

  final SyncConfig _self;
  final $Res Function(SyncConfig) _then;

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_self.copyWith(
      imapConfig: null == imapConfig
          ? _self.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
      sharedSecret: null == sharedSecret
          ? _self.sharedSecret
          : sharedSecret // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_self.imapConfig, (value) {
      return _then(_self.copyWith(imapConfig: value));
    });
  }
}

/// Adds pattern-matching-related methods to [SyncConfig].
extension SyncConfigPatterns on SyncConfig {
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
    TResult Function(_SyncConfig value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncConfig() when $default != null:
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
    TResult Function(_SyncConfig value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncConfig():
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
    TResult? Function(_SyncConfig value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncConfig() when $default != null:
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
    TResult Function(ImapConfig imapConfig, String sharedSecret)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncConfig() when $default != null:
        return $default(_that.imapConfig, _that.sharedSecret);
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
    TResult Function(ImapConfig imapConfig, String sharedSecret) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncConfig():
        return $default(_that.imapConfig, _that.sharedSecret);
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
    TResult? Function(ImapConfig imapConfig, String sharedSecret)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncConfig() when $default != null:
        return $default(_that.imapConfig, _that.sharedSecret);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SyncConfig implements SyncConfig {
  const _SyncConfig({required this.imapConfig, required this.sharedSecret});
  factory _SyncConfig.fromJson(Map<String, dynamic> json) =>
      _$SyncConfigFromJson(json);

  @override
  final ImapConfig imapConfig;
  @override
  final String sharedSecret;

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SyncConfigCopyWith<_SyncConfig> get copyWith =>
      __$SyncConfigCopyWithImpl<_SyncConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SyncConfig &&
            (identical(other.imapConfig, imapConfig) ||
                other.imapConfig == imapConfig) &&
            (identical(other.sharedSecret, sharedSecret) ||
                other.sharedSecret == sharedSecret));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, imapConfig, sharedSecret);

  @override
  String toString() {
    return 'SyncConfig(imapConfig: $imapConfig, sharedSecret: $sharedSecret)';
  }
}

/// @nodoc
abstract mixin class _$SyncConfigCopyWith<$Res>
    implements $SyncConfigCopyWith<$Res> {
  factory _$SyncConfigCopyWith(
          _SyncConfig value, $Res Function(_SyncConfig) _then) =
      __$SyncConfigCopyWithImpl;
  @override
  @useResult
  $Res call({ImapConfig imapConfig, String sharedSecret});

  @override
  $ImapConfigCopyWith<$Res> get imapConfig;
}

/// @nodoc
class __$SyncConfigCopyWithImpl<$Res> implements _$SyncConfigCopyWith<$Res> {
  __$SyncConfigCopyWithImpl(this._self, this._then);

  final _SyncConfig _self;
  final $Res Function(_SyncConfig) _then;

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? imapConfig = null,
    Object? sharedSecret = null,
  }) {
    return _then(_SyncConfig(
      imapConfig: null == imapConfig
          ? _self.imapConfig
          : imapConfig // ignore: cast_nullable_to_non_nullable
              as ImapConfig,
      sharedSecret: null == sharedSecret
          ? _self.sharedSecret
          : sharedSecret // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }

  /// Create a copy of SyncConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ImapConfigCopyWith<$Res> get imapConfig {
    return $ImapConfigCopyWith<$Res>(_self.imapConfig, (value) {
      return _then(_self.copyWith(imapConfig: value));
    });
  }
}

// dart format on
