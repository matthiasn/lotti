// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provisioning_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProvisioningState {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is ProvisioningState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ProvisioningState()';
  }
}

/// @nodoc
class $ProvisioningStateCopyWith<$Res> {
  $ProvisioningStateCopyWith(
      ProvisioningState _, $Res Function(ProvisioningState) __);
}

/// Adds pattern-matching-related methods to [ProvisioningState].
extension ProvisioningStatePatterns on ProvisioningState {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_BundleDecoded value)? bundleDecoded,
    TResult Function(_LoggingIn value)? loggingIn,
    TResult Function(_JoiningRoom value)? joiningRoom,
    TResult Function(_RotatingPassword value)? rotatingPassword,
    TResult Function(_Ready value)? ready,
    TResult Function(_Done value)? done,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial(_that);
      case _BundleDecoded() when bundleDecoded != null:
        return bundleDecoded(_that);
      case _LoggingIn() when loggingIn != null:
        return loggingIn(_that);
      case _JoiningRoom() when joiningRoom != null:
        return joiningRoom(_that);
      case _RotatingPassword() when rotatingPassword != null:
        return rotatingPassword(_that);
      case _Ready() when ready != null:
        return ready(_that);
      case _Done() when done != null:
        return done(_that);
      case _Error() when error != null:
        return error(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_BundleDecoded value) bundleDecoded,
    required TResult Function(_LoggingIn value) loggingIn,
    required TResult Function(_JoiningRoom value) joiningRoom,
    required TResult Function(_RotatingPassword value) rotatingPassword,
    required TResult Function(_Ready value) ready,
    required TResult Function(_Done value) done,
    required TResult Function(_Error value) error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial():
        return initial(_that);
      case _BundleDecoded():
        return bundleDecoded(_that);
      case _LoggingIn():
        return loggingIn(_that);
      case _JoiningRoom():
        return joiningRoom(_that);
      case _RotatingPassword():
        return rotatingPassword(_that);
      case _Ready():
        return ready(_that);
      case _Done():
        return done(_that);
      case _Error():
        return error(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_BundleDecoded value)? bundleDecoded,
    TResult? Function(_LoggingIn value)? loggingIn,
    TResult? Function(_JoiningRoom value)? joiningRoom,
    TResult? Function(_RotatingPassword value)? rotatingPassword,
    TResult? Function(_Ready value)? ready,
    TResult? Function(_Done value)? done,
    TResult? Function(_Error value)? error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial(_that);
      case _BundleDecoded() when bundleDecoded != null:
        return bundleDecoded(_that);
      case _LoggingIn() when loggingIn != null:
        return loggingIn(_that);
      case _JoiningRoom() when joiningRoom != null:
        return joiningRoom(_that);
      case _RotatingPassword() when rotatingPassword != null:
        return rotatingPassword(_that);
      case _Ready() when ready != null:
        return ready(_that);
      case _Done() when done != null:
        return done(_that);
      case _Error() when error != null:
        return error(_that);
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
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? initial,
    TResult Function(SyncProvisioningBundle bundle)? bundleDecoded,
    TResult Function()? loggingIn,
    TResult Function()? joiningRoom,
    TResult Function()? rotatingPassword,
    TResult Function(String handoverBase64)? ready,
    TResult Function()? done,
    TResult Function(ProvisioningError error)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial();
      case _BundleDecoded() when bundleDecoded != null:
        return bundleDecoded(_that.bundle);
      case _LoggingIn() when loggingIn != null:
        return loggingIn();
      case _JoiningRoom() when joiningRoom != null:
        return joiningRoom();
      case _RotatingPassword() when rotatingPassword != null:
        return rotatingPassword();
      case _Ready() when ready != null:
        return ready(_that.handoverBase64);
      case _Done() when done != null:
        return done();
      case _Error() when error != null:
        return error(_that.error);
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
  TResult when<TResult extends Object?>({
    required TResult Function() initial,
    required TResult Function(SyncProvisioningBundle bundle) bundleDecoded,
    required TResult Function() loggingIn,
    required TResult Function() joiningRoom,
    required TResult Function() rotatingPassword,
    required TResult Function(String handoverBase64) ready,
    required TResult Function() done,
    required TResult Function(ProvisioningError error) error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial():
        return initial();
      case _BundleDecoded():
        return bundleDecoded(_that.bundle);
      case _LoggingIn():
        return loggingIn();
      case _JoiningRoom():
        return joiningRoom();
      case _RotatingPassword():
        return rotatingPassword();
      case _Ready():
        return ready(_that.handoverBase64);
      case _Done():
        return done();
      case _Error():
        return error(_that.error);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? initial,
    TResult? Function(SyncProvisioningBundle bundle)? bundleDecoded,
    TResult? Function()? loggingIn,
    TResult? Function()? joiningRoom,
    TResult? Function()? rotatingPassword,
    TResult? Function(String handoverBase64)? ready,
    TResult? Function()? done,
    TResult? Function(ProvisioningError error)? error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial();
      case _BundleDecoded() when bundleDecoded != null:
        return bundleDecoded(_that.bundle);
      case _LoggingIn() when loggingIn != null:
        return loggingIn();
      case _JoiningRoom() when joiningRoom != null:
        return joiningRoom();
      case _RotatingPassword() when rotatingPassword != null:
        return rotatingPassword();
      case _Ready() when ready != null:
        return ready(_that.handoverBase64);
      case _Done() when done != null:
        return done();
      case _Error() when error != null:
        return error(_that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Initial implements ProvisioningState {
  const _Initial();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Initial);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ProvisioningState.initial()';
  }
}

/// @nodoc

class _BundleDecoded implements ProvisioningState {
  const _BundleDecoded(this.bundle);

  final SyncProvisioningBundle bundle;

  /// Create a copy of ProvisioningState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BundleDecodedCopyWith<_BundleDecoded> get copyWith =>
      __$BundleDecodedCopyWithImpl<_BundleDecoded>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BundleDecoded &&
            (identical(other.bundle, bundle) || other.bundle == bundle));
  }

  @override
  int get hashCode => Object.hash(runtimeType, bundle);

  @override
  String toString() {
    return 'ProvisioningState.bundleDecoded(bundle: $bundle)';
  }
}

/// @nodoc
abstract mixin class _$BundleDecodedCopyWith<$Res>
    implements $ProvisioningStateCopyWith<$Res> {
  factory _$BundleDecodedCopyWith(
          _BundleDecoded value, $Res Function(_BundleDecoded) _then) =
      __$BundleDecodedCopyWithImpl;
  @useResult
  $Res call({SyncProvisioningBundle bundle});

  $SyncProvisioningBundleCopyWith<$Res> get bundle;
}

/// @nodoc
class __$BundleDecodedCopyWithImpl<$Res>
    implements _$BundleDecodedCopyWith<$Res> {
  __$BundleDecodedCopyWithImpl(this._self, this._then);

  final _BundleDecoded _self;
  final $Res Function(_BundleDecoded) _then;

  /// Create a copy of ProvisioningState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? bundle = null,
  }) {
    return _then(_BundleDecoded(
      null == bundle
          ? _self.bundle
          : bundle // ignore: cast_nullable_to_non_nullable
              as SyncProvisioningBundle,
    ));
  }

  /// Create a copy of ProvisioningState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SyncProvisioningBundleCopyWith<$Res> get bundle {
    return $SyncProvisioningBundleCopyWith<$Res>(_self.bundle, (value) {
      return _then(_self.copyWith(bundle: value));
    });
  }
}

/// @nodoc

class _LoggingIn implements ProvisioningState {
  const _LoggingIn();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _LoggingIn);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ProvisioningState.loggingIn()';
  }
}

/// @nodoc

class _JoiningRoom implements ProvisioningState {
  const _JoiningRoom();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _JoiningRoom);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ProvisioningState.joiningRoom()';
  }
}

/// @nodoc

class _RotatingPassword implements ProvisioningState {
  const _RotatingPassword();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _RotatingPassword);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ProvisioningState.rotatingPassword()';
  }
}

/// @nodoc

class _Ready implements ProvisioningState {
  const _Ready(this.handoverBase64);

  final String handoverBase64;

  /// Create a copy of ProvisioningState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReadyCopyWith<_Ready> get copyWith =>
      __$ReadyCopyWithImpl<_Ready>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Ready &&
            (identical(other.handoverBase64, handoverBase64) ||
                other.handoverBase64 == handoverBase64));
  }

  @override
  int get hashCode => Object.hash(runtimeType, handoverBase64);

  @override
  String toString() {
    return 'ProvisioningState.ready(handoverBase64: $handoverBase64)';
  }
}

/// @nodoc
abstract mixin class _$ReadyCopyWith<$Res>
    implements $ProvisioningStateCopyWith<$Res> {
  factory _$ReadyCopyWith(_Ready value, $Res Function(_Ready) _then) =
      __$ReadyCopyWithImpl;
  @useResult
  $Res call({String handoverBase64});
}

/// @nodoc
class __$ReadyCopyWithImpl<$Res> implements _$ReadyCopyWith<$Res> {
  __$ReadyCopyWithImpl(this._self, this._then);

  final _Ready _self;
  final $Res Function(_Ready) _then;

  /// Create a copy of ProvisioningState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? handoverBase64 = null,
  }) {
    return _then(_Ready(
      null == handoverBase64
          ? _self.handoverBase64
          : handoverBase64 // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _Done implements ProvisioningState {
  const _Done();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Done);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ProvisioningState.done()';
  }
}

/// @nodoc

class _Error implements ProvisioningState {
  const _Error(this.error);

  final ProvisioningError error;

  /// Create a copy of ProvisioningState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ErrorCopyWith<_Error> get copyWith =>
      __$ErrorCopyWithImpl<_Error>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Error &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, error);

  @override
  String toString() {
    return 'ProvisioningState.error(error: $error)';
  }
}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res>
    implements $ProvisioningStateCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) =
      __$ErrorCopyWithImpl;
  @useResult
  $Res call({ProvisioningError error});
}

/// @nodoc
class __$ErrorCopyWithImpl<$Res> implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

  /// Create a copy of ProvisioningState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? error = null,
  }) {
    return _then(_Error(
      null == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as ProvisioningError,
    ));
  }
}

// dart format on
