// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_qr_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SyncQrPayload {
  /// Version number for future compatibility
  int get version;

  /// Base64-encoded AES-256-GCM encrypted credentials
  String get encryptedData;

  /// Create a copy of SyncQrPayload
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncQrPayloadCopyWith<SyncQrPayload> get copyWith =>
      _$SyncQrPayloadCopyWithImpl<SyncQrPayload>(
          this as SyncQrPayload, _$identity);

  /// Serializes this SyncQrPayload to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncQrPayload &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.encryptedData, encryptedData) ||
                other.encryptedData == encryptedData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, version, encryptedData);
}

/// @nodoc
abstract mixin class $SyncQrPayloadCopyWith<$Res> {
  factory $SyncQrPayloadCopyWith(
          SyncQrPayload value, $Res Function(SyncQrPayload) _then) =
      _$SyncQrPayloadCopyWithImpl;
  @useResult
  $Res call({int version, String encryptedData});
}

/// @nodoc
class _$SyncQrPayloadCopyWithImpl<$Res>
    implements $SyncQrPayloadCopyWith<$Res> {
  _$SyncQrPayloadCopyWithImpl(this._self, this._then);

  final SyncQrPayload _self;
  final $Res Function(SyncQrPayload) _then;

  /// Create a copy of SyncQrPayload
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? encryptedData = null,
  }) {
    return _then(_self.copyWith(
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      encryptedData: null == encryptedData
          ? _self.encryptedData
          : encryptedData // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [SyncQrPayload].
extension SyncQrPayloadPatterns on SyncQrPayload {
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
    TResult Function(_SyncQrPayload value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncQrPayload() when $default != null:
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
    TResult Function(_SyncQrPayload value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncQrPayload():
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
    TResult? Function(_SyncQrPayload value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncQrPayload() when $default != null:
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
    TResult Function(int version, String encryptedData)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SyncQrPayload() when $default != null:
        return $default(_that.version, _that.encryptedData);
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
    TResult Function(int version, String encryptedData) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncQrPayload():
        return $default(_that.version, _that.encryptedData);
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
    TResult? Function(int version, String encryptedData)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SyncQrPayload() when $default != null:
        return $default(_that.version, _that.encryptedData);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SyncQrPayload extends SyncQrPayload {
  const _SyncQrPayload({required this.version, required this.encryptedData})
      : super._();
  factory _SyncQrPayload.fromJson(Map<String, dynamic> json) =>
      _$SyncQrPayloadFromJson(json);

  /// Version number for future compatibility
  @override
  final int version;

  /// Base64-encoded AES-256-GCM encrypted credentials
  @override
  final String encryptedData;

  /// Create a copy of SyncQrPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SyncQrPayloadCopyWith<_SyncQrPayload> get copyWith =>
      __$SyncQrPayloadCopyWithImpl<_SyncQrPayload>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncQrPayloadToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SyncQrPayload &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.encryptedData, encryptedData) ||
                other.encryptedData == encryptedData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, version, encryptedData);
}

/// @nodoc
abstract mixin class _$SyncQrPayloadCopyWith<$Res>
    implements $SyncQrPayloadCopyWith<$Res> {
  factory _$SyncQrPayloadCopyWith(
          _SyncQrPayload value, $Res Function(_SyncQrPayload) _then) =
      __$SyncQrPayloadCopyWithImpl;
  @override
  @useResult
  $Res call({int version, String encryptedData});
}

/// @nodoc
class __$SyncQrPayloadCopyWithImpl<$Res>
    implements _$SyncQrPayloadCopyWith<$Res> {
  __$SyncQrPayloadCopyWithImpl(this._self, this._then);

  final _SyncQrPayload _self;
  final $Res Function(_SyncQrPayload) _then;

  /// Create a copy of SyncQrPayload
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? version = null,
    Object? encryptedData = null,
  }) {
    return _then(_SyncQrPayload(
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      encryptedData: null == encryptedData
          ? _self.encryptedData
          : encryptedData // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
