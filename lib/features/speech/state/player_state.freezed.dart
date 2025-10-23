// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioPlayerState {
  AudioPlayerStatus get status;
  Duration get totalDuration;
  Duration get progress;
  Duration get pausedAt;
  double get speed;
  bool get showTranscriptsList;
  Duration get buffered;
  AudioWaveformStatus get waveformStatus;
  List<double> get waveform;
  Duration get waveformBucketDuration;
  JournalAudio? get audioNote;

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AudioPlayerStateCopyWith<AudioPlayerState> get copyWith =>
      _$AudioPlayerStateCopyWithImpl<AudioPlayerState>(
          this as AudioPlayerState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AudioPlayerState &&
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
            (identical(other.buffered, buffered) ||
                other.buffered == buffered) &&
            (identical(other.waveformStatus, waveformStatus) ||
                other.waveformStatus == waveformStatus) &&
            const DeepCollectionEquality().equals(other.waveform, waveform) &&
            (identical(other.waveformBucketDuration, waveformBucketDuration) ||
                other.waveformBucketDuration == waveformBucketDuration) &&
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
      buffered,
      waveformStatus,
      const DeepCollectionEquality().hash(waveform),
      waveformBucketDuration,
      const DeepCollectionEquality().hash(audioNote));

  @override
  String toString() {
    return 'AudioPlayerState(status: $status, totalDuration: $totalDuration, progress: $progress, pausedAt: $pausedAt, speed: $speed, showTranscriptsList: $showTranscriptsList, buffered: $buffered, waveformStatus: $waveformStatus, waveform: $waveform, waveformBucketDuration: $waveformBucketDuration, audioNote: $audioNote)';
  }
}

/// @nodoc
abstract mixin class $AudioPlayerStateCopyWith<$Res> {
  factory $AudioPlayerStateCopyWith(
          AudioPlayerState value, $Res Function(AudioPlayerState) _then) =
      _$AudioPlayerStateCopyWithImpl;
  @useResult
  $Res call(
      {AudioPlayerStatus status,
      Duration totalDuration,
      Duration progress,
      Duration pausedAt,
      double speed,
      bool showTranscriptsList,
      Duration buffered,
      AudioWaveformStatus waveformStatus,
      List<double> waveform,
      Duration waveformBucketDuration,
      JournalAudio? audioNote});
}

/// @nodoc
class _$AudioPlayerStateCopyWithImpl<$Res>
    implements $AudioPlayerStateCopyWith<$Res> {
  _$AudioPlayerStateCopyWithImpl(this._self, this._then);

  final AudioPlayerState _self;
  final $Res Function(AudioPlayerState) _then;

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
    Object? buffered = null,
    Object? waveformStatus = null,
    Object? waveform = null,
    Object? waveformBucketDuration = null,
    Object? audioNote = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioPlayerStatus,
      totalDuration: null == totalDuration
          ? _self.totalDuration
          : totalDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      pausedAt: null == pausedAt
          ? _self.pausedAt
          : pausedAt // ignore: cast_nullable_to_non_nullable
              as Duration,
      speed: null == speed
          ? _self.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double,
      showTranscriptsList: null == showTranscriptsList
          ? _self.showTranscriptsList
          : showTranscriptsList // ignore: cast_nullable_to_non_nullable
              as bool,
      buffered: null == buffered
          ? _self.buffered
          : buffered // ignore: cast_nullable_to_non_nullable
              as Duration,
      waveformStatus: null == waveformStatus
          ? _self.waveformStatus
          : waveformStatus // ignore: cast_nullable_to_non_nullable
              as AudioWaveformStatus,
      waveform: null == waveform
          ? _self.waveform
          : waveform // ignore: cast_nullable_to_non_nullable
              as List<double>,
      waveformBucketDuration: null == waveformBucketDuration
          ? _self.waveformBucketDuration
          : waveformBucketDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      audioNote: freezed == audioNote
          ? _self.audioNote
          : audioNote // ignore: cast_nullable_to_non_nullable
              as JournalAudio?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AudioPlayerState].
extension AudioPlayerStatePatterns on AudioPlayerState {
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
    TResult Function(_AudioPlayerState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioPlayerState() when $default != null:
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
    TResult Function(_AudioPlayerState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioPlayerState():
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
    TResult? Function(_AudioPlayerState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioPlayerState() when $default != null:
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
            AudioPlayerStatus status,
            Duration totalDuration,
            Duration progress,
            Duration pausedAt,
            double speed,
            bool showTranscriptsList,
            Duration buffered,
            AudioWaveformStatus waveformStatus,
            List<double> waveform,
            Duration waveformBucketDuration,
            JournalAudio? audioNote)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioPlayerState() when $default != null:
        return $default(
            _that.status,
            _that.totalDuration,
            _that.progress,
            _that.pausedAt,
            _that.speed,
            _that.showTranscriptsList,
            _that.buffered,
            _that.waveformStatus,
            _that.waveform,
            _that.waveformBucketDuration,
            _that.audioNote);
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
            AudioPlayerStatus status,
            Duration totalDuration,
            Duration progress,
            Duration pausedAt,
            double speed,
            bool showTranscriptsList,
            Duration buffered,
            AudioWaveformStatus waveformStatus,
            List<double> waveform,
            Duration waveformBucketDuration,
            JournalAudio? audioNote)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioPlayerState():
        return $default(
            _that.status,
            _that.totalDuration,
            _that.progress,
            _that.pausedAt,
            _that.speed,
            _that.showTranscriptsList,
            _that.buffered,
            _that.waveformStatus,
            _that.waveform,
            _that.waveformBucketDuration,
            _that.audioNote);
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
            AudioPlayerStatus status,
            Duration totalDuration,
            Duration progress,
            Duration pausedAt,
            double speed,
            bool showTranscriptsList,
            Duration buffered,
            AudioWaveformStatus waveformStatus,
            List<double> waveform,
            Duration waveformBucketDuration,
            JournalAudio? audioNote)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioPlayerState() when $default != null:
        return $default(
            _that.status,
            _that.totalDuration,
            _that.progress,
            _that.pausedAt,
            _that.speed,
            _that.showTranscriptsList,
            _that.buffered,
            _that.waveformStatus,
            _that.waveform,
            _that.waveformBucketDuration,
            _that.audioNote);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AudioPlayerState implements AudioPlayerState {
  _AudioPlayerState(
      {required this.status,
      required this.totalDuration,
      required this.progress,
      required this.pausedAt,
      required this.speed,
      required this.showTranscriptsList,
      this.buffered = Duration.zero,
      this.waveformStatus = AudioWaveformStatus.initial,
      final List<double> waveform = const <double>[],
      this.waveformBucketDuration = Duration.zero,
      this.audioNote})
      : _waveform = waveform;

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
  @JsonKey()
  final Duration buffered;
  @override
  @JsonKey()
  final AudioWaveformStatus waveformStatus;
  final List<double> _waveform;
  @override
  @JsonKey()
  List<double> get waveform {
    if (_waveform is EqualUnmodifiableListView) return _waveform;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_waveform);
  }

  @override
  @JsonKey()
  final Duration waveformBucketDuration;
  @override
  final JournalAudio? audioNote;

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AudioPlayerStateCopyWith<_AudioPlayerState> get copyWith =>
      __$AudioPlayerStateCopyWithImpl<_AudioPlayerState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioPlayerState &&
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
            (identical(other.buffered, buffered) ||
                other.buffered == buffered) &&
            (identical(other.waveformStatus, waveformStatus) ||
                other.waveformStatus == waveformStatus) &&
            const DeepCollectionEquality().equals(other._waveform, _waveform) &&
            (identical(other.waveformBucketDuration, waveformBucketDuration) ||
                other.waveformBucketDuration == waveformBucketDuration) &&
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
      buffered,
      waveformStatus,
      const DeepCollectionEquality().hash(_waveform),
      waveformBucketDuration,
      const DeepCollectionEquality().hash(audioNote));

  @override
  String toString() {
    return 'AudioPlayerState(status: $status, totalDuration: $totalDuration, progress: $progress, pausedAt: $pausedAt, speed: $speed, showTranscriptsList: $showTranscriptsList, buffered: $buffered, waveformStatus: $waveformStatus, waveform: $waveform, waveformBucketDuration: $waveformBucketDuration, audioNote: $audioNote)';
  }
}

/// @nodoc
abstract mixin class _$AudioPlayerStateCopyWith<$Res>
    implements $AudioPlayerStateCopyWith<$Res> {
  factory _$AudioPlayerStateCopyWith(
          _AudioPlayerState value, $Res Function(_AudioPlayerState) _then) =
      __$AudioPlayerStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {AudioPlayerStatus status,
      Duration totalDuration,
      Duration progress,
      Duration pausedAt,
      double speed,
      bool showTranscriptsList,
      Duration buffered,
      AudioWaveformStatus waveformStatus,
      List<double> waveform,
      Duration waveformBucketDuration,
      JournalAudio? audioNote});
}

/// @nodoc
class __$AudioPlayerStateCopyWithImpl<$Res>
    implements _$AudioPlayerStateCopyWith<$Res> {
  __$AudioPlayerStateCopyWithImpl(this._self, this._then);

  final _AudioPlayerState _self;
  final $Res Function(_AudioPlayerState) _then;

  /// Create a copy of AudioPlayerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? totalDuration = null,
    Object? progress = null,
    Object? pausedAt = null,
    Object? speed = null,
    Object? showTranscriptsList = null,
    Object? buffered = null,
    Object? waveformStatus = null,
    Object? waveform = null,
    Object? waveformBucketDuration = null,
    Object? audioNote = freezed,
  }) {
    return _then(_AudioPlayerState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioPlayerStatus,
      totalDuration: null == totalDuration
          ? _self.totalDuration
          : totalDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      pausedAt: null == pausedAt
          ? _self.pausedAt
          : pausedAt // ignore: cast_nullable_to_non_nullable
              as Duration,
      speed: null == speed
          ? _self.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double,
      showTranscriptsList: null == showTranscriptsList
          ? _self.showTranscriptsList
          : showTranscriptsList // ignore: cast_nullable_to_non_nullable
              as bool,
      buffered: null == buffered
          ? _self.buffered
          : buffered // ignore: cast_nullable_to_non_nullable
              as Duration,
      waveformStatus: null == waveformStatus
          ? _self.waveformStatus
          : waveformStatus // ignore: cast_nullable_to_non_nullable
              as AudioWaveformStatus,
      waveform: null == waveform
          ? _self._waveform
          : waveform // ignore: cast_nullable_to_non_nullable
              as List<double>,
      waveformBucketDuration: null == waveformBucketDuration
          ? _self.waveformBucketDuration
          : waveformBucketDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      audioNote: freezed == audioNote
          ? _self.audioNote
          : audioNote // ignore: cast_nullable_to_non_nullable
              as JournalAudio?,
    ));
  }
}

// dart format on
