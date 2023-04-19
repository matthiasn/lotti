// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$AudioPlayerState {
  AudioPlayerStatus get status => throw _privateConstructorUsedError;
  Duration get totalDuration => throw _privateConstructorUsedError;
  Duration get progress => throw _privateConstructorUsedError;
  Duration get pausedAt => throw _privateConstructorUsedError;
  double get speed => throw _privateConstructorUsedError;
  JournalAudio? get audioNote => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $AudioPlayerStateCopyWith<AudioPlayerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioPlayerStateCopyWith<$Res> {
  factory $AudioPlayerStateCopyWith(
          AudioPlayerState value, $Res Function(AudioPlayerState) then) =
      _$AudioPlayerStateCopyWithImpl<$Res, AudioPlayerState>;
  @useResult
  $Res call(
      {AudioPlayerStatus status,
      Duration totalDuration,
      Duration progress,
      Duration pausedAt,
      double speed,
      JournalAudio? audioNote});
}

/// @nodoc
class _$AudioPlayerStateCopyWithImpl<$Res, $Val extends AudioPlayerState>
    implements $AudioPlayerStateCopyWith<$Res> {
  _$AudioPlayerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? totalDuration = null,
    Object? progress = null,
    Object? pausedAt = null,
    Object? speed = null,
    Object? audioNote = freezed,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioPlayerStatus,
      totalDuration: null == totalDuration
          ? _value.totalDuration
          : totalDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      pausedAt: null == pausedAt
          ? _value.pausedAt
          : pausedAt // ignore: cast_nullable_to_non_nullable
              as Duration,
      speed: null == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double,
      audioNote: freezed == audioNote
          ? _value.audioNote
          : audioNote // ignore: cast_nullable_to_non_nullable
              as JournalAudio?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_AudioPlayerStateCopyWith<$Res>
    implements $AudioPlayerStateCopyWith<$Res> {
  factory _$$_AudioPlayerStateCopyWith(
          _$_AudioPlayerState value, $Res Function(_$_AudioPlayerState) then) =
      __$$_AudioPlayerStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {AudioPlayerStatus status,
      Duration totalDuration,
      Duration progress,
      Duration pausedAt,
      double speed,
      JournalAudio? audioNote});
}

/// @nodoc
class __$$_AudioPlayerStateCopyWithImpl<$Res>
    extends _$AudioPlayerStateCopyWithImpl<$Res, _$_AudioPlayerState>
    implements _$$_AudioPlayerStateCopyWith<$Res> {
  __$$_AudioPlayerStateCopyWithImpl(
      _$_AudioPlayerState _value, $Res Function(_$_AudioPlayerState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? totalDuration = null,
    Object? progress = null,
    Object? pausedAt = null,
    Object? speed = null,
    Object? audioNote = freezed,
  }) {
    return _then(_$_AudioPlayerState(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioPlayerStatus,
      totalDuration: null == totalDuration
          ? _value.totalDuration
          : totalDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      pausedAt: null == pausedAt
          ? _value.pausedAt
          : pausedAt // ignore: cast_nullable_to_non_nullable
              as Duration,
      speed: null == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double,
      audioNote: freezed == audioNote
          ? _value.audioNote
          : audioNote // ignore: cast_nullable_to_non_nullable
              as JournalAudio?,
    ));
  }
}

/// @nodoc

class _$_AudioPlayerState implements _AudioPlayerState {
  _$_AudioPlayerState(
      {required this.status,
      required this.totalDuration,
      required this.progress,
      required this.pausedAt,
      required this.speed,
      this.audioNote});

  @override
  final AudioPlayerStatus status;
  @override
  final Duration totalDuration;
  @override
  final Duration progress;
  @override
  final Duration pausedAt;
  @override
  final double speed;
  @override
  final JournalAudio? audioNote;

  @override
  String toString() {
    return 'AudioPlayerState(status: $status, totalDuration: $totalDuration, progress: $progress, pausedAt: $pausedAt, speed: $speed, audioNote: $audioNote)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_AudioPlayerState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.totalDuration, totalDuration) ||
                other.totalDuration == totalDuration) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.pausedAt, pausedAt) ||
                other.pausedAt == pausedAt) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            const DeepCollectionEquality().equals(other.audioNote, audioNote));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, totalDuration, progress,
      pausedAt, speed, const DeepCollectionEquality().hash(audioNote));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_AudioPlayerStateCopyWith<_$_AudioPlayerState> get copyWith =>
      __$$_AudioPlayerStateCopyWithImpl<_$_AudioPlayerState>(this, _$identity);
}

abstract class _AudioPlayerState implements AudioPlayerState {
  factory _AudioPlayerState(
      {required final AudioPlayerStatus status,
      required final Duration totalDuration,
      required final Duration progress,
      required final Duration pausedAt,
      required final double speed,
      final JournalAudio? audioNote}) = _$_AudioPlayerState;

  @override
  AudioPlayerStatus get status;
  @override
  Duration get totalDuration;
  @override
  Duration get progress;
  @override
  Duration get pausedAt;
  @override
  double get speed;
  @override
  JournalAudio? get audioNote;
  @override
  @JsonKey(ignore: true)
  _$$_AudioPlayerStateCopyWith<_$_AudioPlayerState> get copyWith =>
      throw _privateConstructorUsedError;
}
