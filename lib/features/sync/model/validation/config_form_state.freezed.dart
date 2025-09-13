// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config_form_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LoginFormState {
  HomeServer get homeServer;
  UserName get userName;
  Password get password;
  FormzSubmissionStatus get status;
  bool get isLoggedIn;
  bool get loginFailed;

  /// Create a copy of LoginFormState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LoginFormStateCopyWith<LoginFormState> get copyWith =>
      _$LoginFormStateCopyWithImpl<LoginFormState>(
          this as LoginFormState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LoginFormState &&
            (identical(other.homeServer, homeServer) ||
                other.homeServer == homeServer) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isLoggedIn, isLoggedIn) ||
                other.isLoggedIn == isLoggedIn) &&
            (identical(other.loginFailed, loginFailed) ||
                other.loginFailed == loginFailed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, homeServer, userName, password,
      status, isLoggedIn, loginFailed);
}

/// @nodoc
abstract mixin class $LoginFormStateCopyWith<$Res> {
  factory $LoginFormStateCopyWith(
          LoginFormState value, $Res Function(LoginFormState) _then) =
      _$LoginFormStateCopyWithImpl;
  @useResult
  $Res call(
      {HomeServer homeServer,
      UserName userName,
      Password password,
      FormzSubmissionStatus status,
      bool isLoggedIn,
      bool loginFailed});
}

/// @nodoc
class _$LoginFormStateCopyWithImpl<$Res>
    implements $LoginFormStateCopyWith<$Res> {
  _$LoginFormStateCopyWithImpl(this._self, this._then);

  final LoginFormState _self;
  final $Res Function(LoginFormState) _then;

  /// Create a copy of LoginFormState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? homeServer = null,
    Object? userName = null,
    Object? password = null,
    Object? status = null,
    Object? isLoggedIn = null,
    Object? loginFailed = null,
  }) {
    return _then(_self.copyWith(
      homeServer: null == homeServer
          ? _self.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as HomeServer,
      userName: null == userName
          ? _self.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as UserName,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as Password,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as FormzSubmissionStatus,
      isLoggedIn: null == isLoggedIn
          ? _self.isLoggedIn
          : isLoggedIn // ignore: cast_nullable_to_non_nullable
              as bool,
      loginFailed: null == loginFailed
          ? _self.loginFailed
          : loginFailed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [LoginFormState].
extension LoginFormStatePatterns on LoginFormState {
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
    TResult Function(_LoginFormState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LoginFormState() when $default != null:
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
    TResult Function(_LoginFormState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginFormState():
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
    TResult? Function(_LoginFormState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginFormState() when $default != null:
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
    TResult Function(
            HomeServer homeServer,
            UserName userName,
            Password password,
            FormzSubmissionStatus status,
            bool isLoggedIn,
            bool loginFailed)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LoginFormState() when $default != null:
        return $default(_that.homeServer, _that.userName, _that.password,
            _that.status, _that.isLoggedIn, _that.loginFailed);
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
    TResult Function(
            HomeServer homeServer,
            UserName userName,
            Password password,
            FormzSubmissionStatus status,
            bool isLoggedIn,
            bool loginFailed)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginFormState():
        return $default(_that.homeServer, _that.userName, _that.password,
            _that.status, _that.isLoggedIn, _that.loginFailed);
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
    TResult? Function(
            HomeServer homeServer,
            UserName userName,
            Password password,
            FormzSubmissionStatus status,
            bool isLoggedIn,
            bool loginFailed)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LoginFormState() when $default != null:
        return $default(_that.homeServer, _that.userName, _that.password,
            _that.status, _that.isLoggedIn, _that.loginFailed);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _LoginFormState implements LoginFormState {
  const _LoginFormState(
      {this.homeServer = const HomeServer.pure(),
      this.userName = const UserName.pure(),
      this.password = const Password.pure(),
      this.status = FormzSubmissionStatus.initial,
      this.isLoggedIn = false,
      this.loginFailed = false});

  @override
  @JsonKey()
  final HomeServer homeServer;
  @override
  @JsonKey()
  final UserName userName;
  @override
  @JsonKey()
  final Password password;
  @override
  @JsonKey()
  final FormzSubmissionStatus status;
  @override
  @JsonKey()
  final bool isLoggedIn;
  @override
  @JsonKey()
  final bool loginFailed;

  /// Create a copy of LoginFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LoginFormStateCopyWith<_LoginFormState> get copyWith =>
      __$LoginFormStateCopyWithImpl<_LoginFormState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LoginFormState &&
            (identical(other.homeServer, homeServer) ||
                other.homeServer == homeServer) &&
            (identical(other.userName, userName) ||
                other.userName == userName) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isLoggedIn, isLoggedIn) ||
                other.isLoggedIn == isLoggedIn) &&
            (identical(other.loginFailed, loginFailed) ||
                other.loginFailed == loginFailed));
  }

  @override
  int get hashCode => Object.hash(runtimeType, homeServer, userName, password,
      status, isLoggedIn, loginFailed);
}

/// @nodoc
abstract mixin class _$LoginFormStateCopyWith<$Res>
    implements $LoginFormStateCopyWith<$Res> {
  factory _$LoginFormStateCopyWith(
          _LoginFormState value, $Res Function(_LoginFormState) _then) =
      __$LoginFormStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {HomeServer homeServer,
      UserName userName,
      Password password,
      FormzSubmissionStatus status,
      bool isLoggedIn,
      bool loginFailed});
}

/// @nodoc
class __$LoginFormStateCopyWithImpl<$Res>
    implements _$LoginFormStateCopyWith<$Res> {
  __$LoginFormStateCopyWithImpl(this._self, this._then);

  final _LoginFormState _self;
  final $Res Function(_LoginFormState) _then;

  /// Create a copy of LoginFormState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? homeServer = null,
    Object? userName = null,
    Object? password = null,
    Object? status = null,
    Object? isLoggedIn = null,
    Object? loginFailed = null,
  }) {
    return _then(_LoginFormState(
      homeServer: null == homeServer
          ? _self.homeServer
          : homeServer // ignore: cast_nullable_to_non_nullable
              as HomeServer,
      userName: null == userName
          ? _self.userName
          : userName // ignore: cast_nullable_to_non_nullable
              as UserName,
      password: null == password
          ? _self.password
          : password // ignore: cast_nullable_to_non_nullable
              as Password,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as FormzSubmissionStatus,
      isLoggedIn: null == isLoggedIn
          ? _self.isLoggedIn
          : isLoggedIn // ignore: cast_nullable_to_non_nullable
              as bool,
      loginFailed: null == loginFailed
          ? _self.loginFailed
          : loginFailed // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
