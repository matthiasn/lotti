// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_note.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioNote {
  DateTime get createdAt;
  String get audioFile;
  String get audioDirectory;
  Duration get duration;

  /// Create a copy of AudioNote
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AudioNoteCopyWith<AudioNote> get copyWith =>
      _$AudioNoteCopyWithImpl<AudioNote>(this as AudioNote, _$identity);

  /// Serializes this AudioNote to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AudioNote &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.audioFile, audioFile) ||
                other.audioFile == audioFile) &&
            (identical(other.audioDirectory, audioDirectory) ||
                other.audioDirectory == audioDirectory) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, createdAt, audioFile, audioDirectory, duration);

  @override
  String toString() {
    return 'AudioNote(createdAt: $createdAt, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration)';
  }
}

/// @nodoc
abstract mixin class $AudioNoteCopyWith<$Res> {
  factory $AudioNoteCopyWith(AudioNote value, $Res Function(AudioNote) _then) =
      _$AudioNoteCopyWithImpl;
  @useResult
  $Res call(
      {DateTime createdAt,
      String audioFile,
      String audioDirectory,
      Duration duration});
}

/// @nodoc
class _$AudioNoteCopyWithImpl<$Res> implements $AudioNoteCopyWith<$Res> {
  _$AudioNoteCopyWithImpl(this._self, this._then);

  final AudioNote _self;
  final $Res Function(AudioNote) _then;

  /// Create a copy of AudioNote
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
  }) {
    return _then(_self.copyWith(
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _self.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _self.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// Adds pattern-matching-related methods to [AudioNote].
extension AudioNotePatterns on AudioNote {
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
    TResult Function(_AudioNote value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioNote() when $default != null:
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
    TResult Function(_AudioNote value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioNote():
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
    TResult? Function(_AudioNote value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioNote() when $default != null:
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
    TResult Function(DateTime createdAt, String audioFile,
            String audioDirectory, Duration duration)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioNote() when $default != null:
        return $default(_that.createdAt, _that.audioFile, _that.audioDirectory,
            _that.duration);
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
    TResult Function(DateTime createdAt, String audioFile,
            String audioDirectory, Duration duration)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioNote():
        return $default(_that.createdAt, _that.audioFile, _that.audioDirectory,
            _that.duration);
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
    TResult? Function(DateTime createdAt, String audioFile,
            String audioDirectory, Duration duration)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioNote() when $default != null:
        return $default(_that.createdAt, _that.audioFile, _that.audioDirectory,
            _that.duration);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AudioNote implements AudioNote {
  const _AudioNote(
      {required this.createdAt,
      required this.audioFile,
      required this.audioDirectory,
      required this.duration});
  factory _AudioNote.fromJson(Map<String, dynamic> json) =>
      _$AudioNoteFromJson(json);

  @override
  final DateTime createdAt;
  @override
  final String audioFile;
  @override
  final String audioDirectory;
  @override
  final Duration duration;

  /// Create a copy of AudioNote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AudioNoteCopyWith<_AudioNote> get copyWith =>
      __$AudioNoteCopyWithImpl<_AudioNote>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AudioNoteToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioNote &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.audioFile, audioFile) ||
                other.audioFile == audioFile) &&
            (identical(other.audioDirectory, audioDirectory) ||
                other.audioDirectory == audioDirectory) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, createdAt, audioFile, audioDirectory, duration);

  @override
  String toString() {
    return 'AudioNote(createdAt: $createdAt, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration)';
  }
}

/// @nodoc
abstract mixin class _$AudioNoteCopyWith<$Res>
    implements $AudioNoteCopyWith<$Res> {
  factory _$AudioNoteCopyWith(
          _AudioNote value, $Res Function(_AudioNote) _then) =
      __$AudioNoteCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime createdAt,
      String audioFile,
      String audioDirectory,
      Duration duration});
}

/// @nodoc
class __$AudioNoteCopyWithImpl<$Res> implements _$AudioNoteCopyWith<$Res> {
  __$AudioNoteCopyWithImpl(this._self, this._then);

  final _AudioNote _self;
  final $Res Function(_AudioNote) _then;

  /// Create a copy of AudioNote
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? createdAt = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
  }) {
    return _then(_AudioNote(
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _self.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _self.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _self.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

// dart format on
