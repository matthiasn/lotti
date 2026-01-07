// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'whats_new_release.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WhatsNewRelease {
  String get version;
  DateTime get date;
  String get title;
  String get folder;

  /// Create a copy of WhatsNewRelease
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WhatsNewReleaseCopyWith<WhatsNewRelease> get copyWith =>
      _$WhatsNewReleaseCopyWithImpl<WhatsNewRelease>(
          this as WhatsNewRelease, _$identity);

  /// Serializes this WhatsNewRelease to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WhatsNewRelease &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.folder, folder) || other.folder == folder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, version, date, title, folder);

  @override
  String toString() {
    return 'WhatsNewRelease(version: $version, date: $date, title: $title, folder: $folder)';
  }
}

/// @nodoc
abstract mixin class $WhatsNewReleaseCopyWith<$Res> {
  factory $WhatsNewReleaseCopyWith(
          WhatsNewRelease value, $Res Function(WhatsNewRelease) _then) =
      _$WhatsNewReleaseCopyWithImpl;
  @useResult
  $Res call({String version, DateTime date, String title, String folder});
}

/// @nodoc
class _$WhatsNewReleaseCopyWithImpl<$Res>
    implements $WhatsNewReleaseCopyWith<$Res> {
  _$WhatsNewReleaseCopyWithImpl(this._self, this._then);

  final WhatsNewRelease _self;
  final $Res Function(WhatsNewRelease) _then;

  /// Create a copy of WhatsNewRelease
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? date = null,
    Object? title = null,
    Object? folder = null,
  }) {
    return _then(_self.copyWith(
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _self.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [WhatsNewRelease].
extension WhatsNewReleasePatterns on WhatsNewRelease {
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
    TResult Function(_WhatsNewRelease value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WhatsNewRelease() when $default != null:
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
    TResult Function(_WhatsNewRelease value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewRelease():
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
    TResult? Function(_WhatsNewRelease value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewRelease() when $default != null:
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
            String version, DateTime date, String title, String folder)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WhatsNewRelease() when $default != null:
        return $default(_that.version, _that.date, _that.title, _that.folder);
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
    TResult Function(String version, DateTime date, String title, String folder)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewRelease():
        return $default(_that.version, _that.date, _that.title, _that.folder);
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
            String version, DateTime date, String title, String folder)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WhatsNewRelease() when $default != null:
        return $default(_that.version, _that.date, _that.title, _that.folder);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _WhatsNewRelease implements WhatsNewRelease {
  const _WhatsNewRelease(
      {required this.version,
      required this.date,
      required this.title,
      required this.folder});
  factory _WhatsNewRelease.fromJson(Map<String, dynamic> json) =>
      _$WhatsNewReleaseFromJson(json);

  @override
  final String version;
  @override
  final DateTime date;
  @override
  final String title;
  @override
  final String folder;

  /// Create a copy of WhatsNewRelease
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WhatsNewReleaseCopyWith<_WhatsNewRelease> get copyWith =>
      __$WhatsNewReleaseCopyWithImpl<_WhatsNewRelease>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$WhatsNewReleaseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WhatsNewRelease &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.folder, folder) || other.folder == folder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, version, date, title, folder);

  @override
  String toString() {
    return 'WhatsNewRelease(version: $version, date: $date, title: $title, folder: $folder)';
  }
}

/// @nodoc
abstract mixin class _$WhatsNewReleaseCopyWith<$Res>
    implements $WhatsNewReleaseCopyWith<$Res> {
  factory _$WhatsNewReleaseCopyWith(
          _WhatsNewRelease value, $Res Function(_WhatsNewRelease) _then) =
      __$WhatsNewReleaseCopyWithImpl;
  @override
  @useResult
  $Res call({String version, DateTime date, String title, String folder});
}

/// @nodoc
class __$WhatsNewReleaseCopyWithImpl<$Res>
    implements _$WhatsNewReleaseCopyWith<$Res> {
  __$WhatsNewReleaseCopyWithImpl(this._self, this._then);

  final _WhatsNewRelease _self;
  final $Res Function(_WhatsNewRelease) _then;

  /// Create a copy of WhatsNewRelease
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? version = null,
    Object? date = null,
    Object? title = null,
    Object? folder = null,
  }) {
    return _then(_WhatsNewRelease(
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      folder: null == folder
          ? _self.folder
          : folder // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
