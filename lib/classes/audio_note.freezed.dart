// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_note.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AudioNote _$AudioNoteFromJson(Map<String, dynamic> json) {
  return _AudioNote.fromJson(json);
}

/// @nodoc
mixin _$AudioNote {
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get audioFile => throw _privateConstructorUsedError;
  String get audioDirectory => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AudioNoteCopyWith<AudioNote> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioNoteCopyWith<$Res> {
  factory $AudioNoteCopyWith(AudioNote value, $Res Function(AudioNote) then) =
      _$AudioNoteCopyWithImpl<$Res, AudioNote>;
  @useResult
  $Res call(
      {DateTime createdAt,
      String audioFile,
      String audioDirectory,
      Duration duration});
}

/// @nodoc
class _$AudioNoteCopyWithImpl<$Res, $Val extends AudioNote>
    implements $AudioNoteCopyWith<$Res> {
  _$AudioNoteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
  }) {
    return _then(_value.copyWith(
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _value.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _value.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AudioNoteImplCopyWith<$Res>
    implements $AudioNoteCopyWith<$Res> {
  factory _$$AudioNoteImplCopyWith(
          _$AudioNoteImpl value, $Res Function(_$AudioNoteImpl) then) =
      __$$AudioNoteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime createdAt,
      String audioFile,
      String audioDirectory,
      Duration duration});
}

/// @nodoc
class __$$AudioNoteImplCopyWithImpl<$Res>
    extends _$AudioNoteCopyWithImpl<$Res, _$AudioNoteImpl>
    implements _$$AudioNoteImplCopyWith<$Res> {
  __$$AudioNoteImplCopyWithImpl(
      _$AudioNoteImpl _value, $Res Function(_$AudioNoteImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? createdAt = null,
    Object? audioFile = null,
    Object? audioDirectory = null,
    Object? duration = null,
  }) {
    return _then(_$AudioNoteImpl(
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      audioFile: null == audioFile
          ? _value.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: null == audioDirectory
          ? _value.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioNoteImpl implements _AudioNote {
  const _$AudioNoteImpl(
      {required this.createdAt,
      required this.audioFile,
      required this.audioDirectory,
      required this.duration});

  factory _$AudioNoteImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioNoteImplFromJson(json);

  @override
  final DateTime createdAt;
  @override
  final String audioFile;
  @override
  final String audioDirectory;
  @override
  final Duration duration;

  @override
  String toString() {
    return 'AudioNote(createdAt: $createdAt, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioNoteImpl &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.audioFile, audioFile) ||
                other.audioFile == audioFile) &&
            (identical(other.audioDirectory, audioDirectory) ||
                other.audioDirectory == audioDirectory) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, createdAt, audioFile, audioDirectory, duration);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioNoteImplCopyWith<_$AudioNoteImpl> get copyWith =>
      __$$AudioNoteImplCopyWithImpl<_$AudioNoteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioNoteImplToJson(
      this,
    );
  }
}

abstract class _AudioNote implements AudioNote {
  const factory _AudioNote(
      {required final DateTime createdAt,
      required final String audioFile,
      required final String audioDirectory,
      required final Duration duration}) = _$AudioNoteImpl;

  factory _AudioNote.fromJson(Map<String, dynamic> json) =
      _$AudioNoteImpl.fromJson;

  @override
  DateTime get createdAt;
  @override
  String get audioFile;
  @override
  String get audioDirectory;
  @override
  Duration get duration;
  @override
  @JsonKey(ignore: true)
  _$$AudioNoteImplCopyWith<_$AudioNoteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
