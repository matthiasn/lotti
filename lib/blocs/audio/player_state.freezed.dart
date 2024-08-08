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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AudioPlayerState {
  AudioPlayerStatus get status => throw _privateConstructorUsedError;
  Duration get totalDuration => throw _privateConstructorUsedError;
  Duration get progress => throw _privateConstructorUsedError;
  Duration get pausedAt => throw _privateConstructorUsedError;
  double get speed => throw _privateConstructorUsedError;
  bool get showTranscriptsList => throw _privateConstructorUsedError;
  JournalAudio? get audioNote => throw _privateConstructorUsedError;

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      bool showTranscriptsList,
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

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? totalDuration = null,
    Object? progress = null,
    Object? pausedAt = null,
    Object? speed = null,
    Object? showTranscriptsList = null,
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
      showTranscriptsList: null == showTranscriptsList
          ? _value.showTranscriptsList
          : showTranscriptsList // ignore: cast_nullable_to_non_nullable
              as bool,
      audioNote: freezed == audioNote
          ? _value.audioNote
          : audioNote // ignore: cast_nullable_to_non_nullable
              as JournalAudio?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AudioPlayerStateImplCopyWith<$Res>
    implements $AudioPlayerStateCopyWith<$Res> {
  factory _$$AudioPlayerStateImplCopyWith(_$AudioPlayerStateImpl value,
          $Res Function(_$AudioPlayerStateImpl) then) =
      __$$AudioPlayerStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {AudioPlayerStatus status,
      Duration totalDuration,
      Duration progress,
      Duration pausedAt,
      double speed,
      bool showTranscriptsList,
      JournalAudio? audioNote});
}

/// @nodoc
class __$$AudioPlayerStateImplCopyWithImpl<$Res>
    extends _$AudioPlayerStateCopyWithImpl<$Res, _$AudioPlayerStateImpl>
    implements _$$AudioPlayerStateImplCopyWith<$Res> {
  __$$AudioPlayerStateImplCopyWithImpl(_$AudioPlayerStateImpl _value,
      $Res Function(_$AudioPlayerStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? totalDuration = null,
    Object? progress = null,
    Object? pausedAt = null,
    Object? speed = null,
    Object? showTranscriptsList = null,
    Object? audioNote = freezed,
  }) {
    return _then(_$AudioPlayerStateImpl(
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
      showTranscriptsList: null == showTranscriptsList
          ? _value.showTranscriptsList
          : showTranscriptsList // ignore: cast_nullable_to_non_nullable
              as bool,
      audioNote: freezed == audioNote
          ? _value.audioNote
          : audioNote // ignore: cast_nullable_to_non_nullable
              as JournalAudio?,
    ));
  }
}

/// @nodoc

class _$AudioPlayerStateImpl implements _AudioPlayerState {
  _$AudioPlayerStateImpl(
      {required this.status,
      required this.totalDuration,
      required this.progress,
      required this.pausedAt,
      required this.speed,
      required this.showTranscriptsList,
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
  final bool showTranscriptsList;
  @override
  final JournalAudio? audioNote;

  @override
  String toString() {
    return 'AudioPlayerState(status: $status, totalDuration: $totalDuration, progress: $progress, pausedAt: $pausedAt, speed: $speed, showTranscriptsList: $showTranscriptsList, audioNote: $audioNote)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioPlayerStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.totalDuration, totalDuration) ||
                other.totalDuration == totalDuration) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.pausedAt, pausedAt) ||
                other.pausedAt == pausedAt) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            (identical(other.showTranscriptsList, showTranscriptsList) ||
                other.showTranscriptsList == showTranscriptsList) &&
            const DeepCollectionEquality().equals(other.audioNote, audioNote));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      totalDuration,
      progress,
      pausedAt,
      speed,
      showTranscriptsList,
      const DeepCollectionEquality().hash(audioNote));

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioPlayerStateImplCopyWith<_$AudioPlayerStateImpl> get copyWith =>
      __$$AudioPlayerStateImplCopyWithImpl<_$AudioPlayerStateImpl>(
          this, _$identity);
}

abstract class _AudioPlayerState implements AudioPlayerState {
  factory _AudioPlayerState(
      {required final AudioPlayerStatus status,
      required final Duration totalDuration,
      required final Duration progress,
      required final Duration pausedAt,
      required final double speed,
      required final bool showTranscriptsList,
      final JournalAudio? audioNote}) = _$AudioPlayerStateImpl;

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
  bool get showTranscriptsList;
  @override
  JournalAudio? get audioNote;

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioPlayerStateImplCopyWith<_$AudioPlayerStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
