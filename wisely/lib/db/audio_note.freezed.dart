// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'audio_note.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

AudioNote _$AudioNoteFromJson(Map<String, dynamic> json) {
  return _AudioNote.fromJson(json);
}

/// @nodoc
class _$AudioNoteTearOff {
  const _$AudioNoteTearOff();

  _AudioNote call(
      {required String id,
      required int timestamp,
      required DateTime createdAt,
      required int utcOffset,
      required String timezone,
      required String audioFile,
      required String audioDirectory,
      required Duration duration,
      DateTime? updatedAt,
      String? transcript,
      double? latitude,
      double? longitude,
      VectorClock? vectorClock}) {
    return _AudioNote(
      id: id,
      timestamp: timestamp,
      createdAt: createdAt,
      utcOffset: utcOffset,
      timezone: timezone,
      audioFile: audioFile,
      audioDirectory: audioDirectory,
      duration: duration,
      updatedAt: updatedAt,
      transcript: transcript,
      latitude: latitude,
      longitude: longitude,
      vectorClock: vectorClock,
    );
  }

  AudioNote fromJson(Map<String, Object?> json) {
    return AudioNote.fromJson(json);
  }
}

/// @nodoc
const $AudioNote = _$AudioNoteTearOff();

/// @nodoc
mixin _$AudioNote {
  String get id => throw _privateConstructorUsedError;
  int get timestamp => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  int get utcOffset => throw _privateConstructorUsedError;
  String get timezone => throw _privateConstructorUsedError;
  String get audioFile => throw _privateConstructorUsedError;
  String get audioDirectory => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  String? get transcript => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  VectorClock? get vectorClock => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $AudioNoteCopyWith<AudioNote> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioNoteCopyWith<$Res> {
  factory $AudioNoteCopyWith(AudioNote value, $Res Function(AudioNote) then) =
      _$AudioNoteCopyWithImpl<$Res>;
  $Res call(
      {String id,
      int timestamp,
      DateTime createdAt,
      int utcOffset,
      String timezone,
      String audioFile,
      String audioDirectory,
      Duration duration,
      DateTime? updatedAt,
      String? transcript,
      double? latitude,
      double? longitude,
      VectorClock? vectorClock});
}

/// @nodoc
class _$AudioNoteCopyWithImpl<$Res> implements $AudioNoteCopyWith<$Res> {
  _$AudioNoteCopyWithImpl(this._value, this._then);

  final AudioNote _value;
  // ignore: unused_field
  final $Res Function(AudioNote) _then;

  @override
  $Res call({
    Object? id = freezed,
    Object? timestamp = freezed,
    Object? createdAt = freezed,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? audioFile = freezed,
    Object? audioDirectory = freezed,
    Object? duration = freezed,
    Object? updatedAt = freezed,
    Object? transcript = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? vectorClock = freezed,
  }) {
    return _then(_value.copyWith(
      id: id == freezed
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: timestamp == freezed
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: createdAt == freezed
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: utcOffset == freezed
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: timezone == freezed
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      audioFile: audioFile == freezed
          ? _value.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: audioDirectory == freezed
          ? _value.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: duration == freezed
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      updatedAt: updatedAt == freezed
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      transcript: transcript == freezed
          ? _value.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: latitude == freezed
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: longitude == freezed
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      vectorClock: vectorClock == freezed
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
    ));
  }
}

/// @nodoc
abstract class _$AudioNoteCopyWith<$Res> implements $AudioNoteCopyWith<$Res> {
  factory _$AudioNoteCopyWith(
          _AudioNote value, $Res Function(_AudioNote) then) =
      __$AudioNoteCopyWithImpl<$Res>;
  @override
  $Res call(
      {String id,
      int timestamp,
      DateTime createdAt,
      int utcOffset,
      String timezone,
      String audioFile,
      String audioDirectory,
      Duration duration,
      DateTime? updatedAt,
      String? transcript,
      double? latitude,
      double? longitude,
      VectorClock? vectorClock});
}

/// @nodoc
class __$AudioNoteCopyWithImpl<$Res> extends _$AudioNoteCopyWithImpl<$Res>
    implements _$AudioNoteCopyWith<$Res> {
  __$AudioNoteCopyWithImpl(_AudioNote _value, $Res Function(_AudioNote) _then)
      : super(_value, (v) => _then(v as _AudioNote));

  @override
  _AudioNote get _value => super._value as _AudioNote;

  @override
  $Res call({
    Object? id = freezed,
    Object? timestamp = freezed,
    Object? createdAt = freezed,
    Object? utcOffset = freezed,
    Object? timezone = freezed,
    Object? audioFile = freezed,
    Object? audioDirectory = freezed,
    Object? duration = freezed,
    Object? updatedAt = freezed,
    Object? transcript = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? vectorClock = freezed,
  }) {
    return _then(_AudioNote(
      id: id == freezed
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: timestamp == freezed
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: createdAt == freezed
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: utcOffset == freezed
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: timezone == freezed
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String,
      audioFile: audioFile == freezed
          ? _value.audioFile
          : audioFile // ignore: cast_nullable_to_non_nullable
              as String,
      audioDirectory: audioDirectory == freezed
          ? _value.audioDirectory
          : audioDirectory // ignore: cast_nullable_to_non_nullable
              as String,
      duration: duration == freezed
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      updatedAt: updatedAt == freezed
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      transcript: transcript == freezed
          ? _value.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: latitude == freezed
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: longitude == freezed
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      vectorClock: vectorClock == freezed
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_AudioNote implements _AudioNote {
  _$_AudioNote(
      {required this.id,
      required this.timestamp,
      required this.createdAt,
      required this.utcOffset,
      required this.timezone,
      required this.audioFile,
      required this.audioDirectory,
      required this.duration,
      this.updatedAt,
      this.transcript,
      this.latitude,
      this.longitude,
      this.vectorClock});

  factory _$_AudioNote.fromJson(Map<String, dynamic> json) =>
      _$$_AudioNoteFromJson(json);

  @override
  final String id;
  @override
  final int timestamp;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String timezone;
  @override
  final String audioFile;
  @override
  final String audioDirectory;
  @override
  final Duration duration;
  @override
  final DateTime? updatedAt;
  @override
  final String? transcript;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  final VectorClock? vectorClock;

  @override
  String toString() {
    return 'AudioNote(id: $id, timestamp: $timestamp, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, audioFile: $audioFile, audioDirectory: $audioDirectory, duration: $duration, updatedAt: $updatedAt, transcript: $transcript, latitude: $latitude, longitude: $longitude, vectorClock: $vectorClock)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioNote &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.audioFile, audioFile) ||
                other.audioFile == audioFile) &&
            (identical(other.audioDirectory, audioDirectory) ||
                other.audioDirectory == audioDirectory) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.transcript, transcript) ||
                other.transcript == transcript) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      timestamp,
      createdAt,
      utcOffset,
      timezone,
      audioFile,
      audioDirectory,
      duration,
      updatedAt,
      transcript,
      latitude,
      longitude,
      vectorClock);

  @JsonKey(ignore: true)
  @override
  _$AudioNoteCopyWith<_AudioNote> get copyWith =>
      __$AudioNoteCopyWithImpl<_AudioNote>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_AudioNoteToJson(this);
  }
}

abstract class _AudioNote implements AudioNote {
  factory _AudioNote(
      {required String id,
      required int timestamp,
      required DateTime createdAt,
      required int utcOffset,
      required String timezone,
      required String audioFile,
      required String audioDirectory,
      required Duration duration,
      DateTime? updatedAt,
      String? transcript,
      double? latitude,
      double? longitude,
      VectorClock? vectorClock}) = _$_AudioNote;

  factory _AudioNote.fromJson(Map<String, dynamic> json) =
      _$_AudioNote.fromJson;

  @override
  String get id;
  @override
  int get timestamp;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  @override
  String get timezone;
  @override
  String get audioFile;
  @override
  String get audioDirectory;
  @override
  Duration get duration;
  @override
  DateTime? get updatedAt;
  @override
  String? get transcript;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  VectorClock? get vectorClock;
  @override
  @JsonKey(ignore: true)
  _$AudioNoteCopyWith<_AudioNote> get copyWith =>
      throw _privateConstructorUsedError;
}
