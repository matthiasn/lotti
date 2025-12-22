// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recorder_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioRecorderState {
  /// Current status of the recorder.
  AudioRecorderStatus get status;

  /// Duration of the current recording.
  Duration get progress;

  /// Current audio level in decibels (0-160 range).
  /// Used for VU meter visualization.
  double get vu;
  double get dBFS;

  /// Whether to show the floating recording indicator.
  /// Only relevant when recording and modal is not visible.
  bool get showIndicator;

  /// Whether the recording modal is currently visible.
  /// Used to coordinate with indicator display.
  bool get modalVisible;

  /// Optional ID to link recording to existing journal entry.
  String? get linkedId;

  /// Whether to trigger speech recognition after recording.
  /// If null, uses category default settings.
  bool? get enableSpeechRecognition;

  /// Whether to trigger task summary after recording (if linked to task).
  /// If null, uses category default settings.
  bool? get enableTaskSummary;

  /// Whether to trigger checklist updates after recording (if linked to task).
  /// If null, uses category default settings.
  bool? get enableChecklistUpdates;

  /// Create a copy of AudioRecorderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AudioRecorderStateCopyWith<AudioRecorderState> get copyWith =>
      _$AudioRecorderStateCopyWithImpl<AudioRecorderState>(
          this as AudioRecorderState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AudioRecorderState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.vu, vu) || other.vu == vu) &&
            (identical(other.dBFS, dBFS) || other.dBFS == dBFS) &&
            (identical(other.showIndicator, showIndicator) ||
                other.showIndicator == showIndicator) &&
            (identical(other.modalVisible, modalVisible) ||
                other.modalVisible == modalVisible) &&
            (identical(other.linkedId, linkedId) ||
                other.linkedId == linkedId) &&
            (identical(
                    other.enableSpeechRecognition, enableSpeechRecognition) ||
                other.enableSpeechRecognition == enableSpeechRecognition) &&
            (identical(other.enableTaskSummary, enableTaskSummary) ||
                other.enableTaskSummary == enableTaskSummary) &&
            (identical(other.enableChecklistUpdates, enableChecklistUpdates) ||
                other.enableChecklistUpdates == enableChecklistUpdates));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      progress,
      vu,
      dBFS,
      showIndicator,
      modalVisible,
      linkedId,
      enableSpeechRecognition,
      enableTaskSummary,
      enableChecklistUpdates);

  @override
  String toString() {
    return 'AudioRecorderState(status: $status, progress: $progress, vu: $vu, dBFS: $dBFS, showIndicator: $showIndicator, modalVisible: $modalVisible, linkedId: $linkedId, enableSpeechRecognition: $enableSpeechRecognition, enableTaskSummary: $enableTaskSummary, enableChecklistUpdates: $enableChecklistUpdates)';
  }
}

/// @nodoc
abstract mixin class $AudioRecorderStateCopyWith<$Res> {
  factory $AudioRecorderStateCopyWith(
          AudioRecorderState value, $Res Function(AudioRecorderState) _then) =
      _$AudioRecorderStateCopyWithImpl;
  @useResult
  $Res call(
      {AudioRecorderStatus status,
      Duration progress,
      double vu,
      double dBFS,
      bool showIndicator,
      bool modalVisible,
      String? linkedId,
      bool? enableSpeechRecognition,
      bool? enableTaskSummary,
      bool? enableChecklistUpdates});
}

/// @nodoc
class _$AudioRecorderStateCopyWithImpl<$Res>
    implements $AudioRecorderStateCopyWith<$Res> {
  _$AudioRecorderStateCopyWithImpl(this._self, this._then);

  final AudioRecorderState _self;
  final $Res Function(AudioRecorderState) _then;

  /// Create a copy of AudioRecorderState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? progress = null,
    Object? vu = null,
    Object? dBFS = null,
    Object? showIndicator = null,
    Object? modalVisible = null,
    Object? linkedId = freezed,
    Object? enableSpeechRecognition = freezed,
    Object? enableTaskSummary = freezed,
    Object? enableChecklistUpdates = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioRecorderStatus,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      vu: null == vu
          ? _self.vu
          : vu // ignore: cast_nullable_to_non_nullable
              as double,
      dBFS: null == dBFS
          ? _self.dBFS
          : dBFS // ignore: cast_nullable_to_non_nullable
              as double,
      showIndicator: null == showIndicator
          ? _self.showIndicator
          : showIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
      modalVisible: null == modalVisible
          ? _self.modalVisible
          : modalVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      linkedId: freezed == linkedId
          ? _self.linkedId
          : linkedId // ignore: cast_nullable_to_non_nullable
              as String?,
      enableSpeechRecognition: freezed == enableSpeechRecognition
          ? _self.enableSpeechRecognition
          : enableSpeechRecognition // ignore: cast_nullable_to_non_nullable
              as bool?,
      enableTaskSummary: freezed == enableTaskSummary
          ? _self.enableTaskSummary
          : enableTaskSummary // ignore: cast_nullable_to_non_nullable
              as bool?,
      enableChecklistUpdates: freezed == enableChecklistUpdates
          ? _self.enableChecklistUpdates
          : enableChecklistUpdates // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AudioRecorderState].
extension AudioRecorderStatePatterns on AudioRecorderState {
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
    TResult Function(_AudioRecorderState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioRecorderState() when $default != null:
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
    TResult Function(_AudioRecorderState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioRecorderState():
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
    TResult? Function(_AudioRecorderState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioRecorderState() when $default != null:
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
            AudioRecorderStatus status,
            Duration progress,
            double vu,
            double dBFS,
            bool showIndicator,
            bool modalVisible,
            String? linkedId,
            bool? enableSpeechRecognition,
            bool? enableTaskSummary,
            bool? enableChecklistUpdates)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AudioRecorderState() when $default != null:
        return $default(
            _that.status,
            _that.progress,
            _that.vu,
            _that.dBFS,
            _that.showIndicator,
            _that.modalVisible,
            _that.linkedId,
            _that.enableSpeechRecognition,
            _that.enableTaskSummary,
            _that.enableChecklistUpdates);
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
            AudioRecorderStatus status,
            Duration progress,
            double vu,
            double dBFS,
            bool showIndicator,
            bool modalVisible,
            String? linkedId,
            bool? enableSpeechRecognition,
            bool? enableTaskSummary,
            bool? enableChecklistUpdates)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioRecorderState():
        return $default(
            _that.status,
            _that.progress,
            _that.vu,
            _that.dBFS,
            _that.showIndicator,
            _that.modalVisible,
            _that.linkedId,
            _that.enableSpeechRecognition,
            _that.enableTaskSummary,
            _that.enableChecklistUpdates);
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
            AudioRecorderStatus status,
            Duration progress,
            double vu,
            double dBFS,
            bool showIndicator,
            bool modalVisible,
            String? linkedId,
            bool? enableSpeechRecognition,
            bool? enableTaskSummary,
            bool? enableChecklistUpdates)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AudioRecorderState() when $default != null:
        return $default(
            _that.status,
            _that.progress,
            _that.vu,
            _that.dBFS,
            _that.showIndicator,
            _that.modalVisible,
            _that.linkedId,
            _that.enableSpeechRecognition,
            _that.enableTaskSummary,
            _that.enableChecklistUpdates);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AudioRecorderState implements AudioRecorderState {
  _AudioRecorderState(
      {required this.status,
      required this.progress,
      required this.vu,
      required this.dBFS,
      required this.showIndicator,
      required this.modalVisible,
      this.linkedId,
      this.enableSpeechRecognition,
      this.enableTaskSummary,
      this.enableChecklistUpdates});

  /// Current status of the recorder.
  @override
  final AudioRecorderStatus status;

  /// Duration of the current recording.
  @override
  final Duration progress;

  /// Current audio level in decibels (0-160 range).
  /// Used for VU meter visualization.
  @override
  final double vu;
  @override
  final double dBFS;

  /// Whether to show the floating recording indicator.
  /// Only relevant when recording and modal is not visible.
  @override
  final bool showIndicator;

  /// Whether the recording modal is currently visible.
  /// Used to coordinate with indicator display.
  @override
  final bool modalVisible;

  /// Optional ID to link recording to existing journal entry.
  @override
  final String? linkedId;

  /// Whether to trigger speech recognition after recording.
  /// If null, uses category default settings.
  @override
  final bool? enableSpeechRecognition;

  /// Whether to trigger task summary after recording (if linked to task).
  /// If null, uses category default settings.
  @override
  final bool? enableTaskSummary;

  /// Whether to trigger checklist updates after recording (if linked to task).
  /// If null, uses category default settings.
  @override
  final bool? enableChecklistUpdates;

  /// Create a copy of AudioRecorderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AudioRecorderStateCopyWith<_AudioRecorderState> get copyWith =>
      __$AudioRecorderStateCopyWithImpl<_AudioRecorderState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioRecorderState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.vu, vu) || other.vu == vu) &&
            (identical(other.dBFS, dBFS) || other.dBFS == dBFS) &&
            (identical(other.showIndicator, showIndicator) ||
                other.showIndicator == showIndicator) &&
            (identical(other.modalVisible, modalVisible) ||
                other.modalVisible == modalVisible) &&
            (identical(other.linkedId, linkedId) ||
                other.linkedId == linkedId) &&
            (identical(
                    other.enableSpeechRecognition, enableSpeechRecognition) ||
                other.enableSpeechRecognition == enableSpeechRecognition) &&
            (identical(other.enableTaskSummary, enableTaskSummary) ||
                other.enableTaskSummary == enableTaskSummary) &&
            (identical(other.enableChecklistUpdates, enableChecklistUpdates) ||
                other.enableChecklistUpdates == enableChecklistUpdates));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      progress,
      vu,
      dBFS,
      showIndicator,
      modalVisible,
      linkedId,
      enableSpeechRecognition,
      enableTaskSummary,
      enableChecklistUpdates);

  @override
  String toString() {
    return 'AudioRecorderState(status: $status, progress: $progress, vu: $vu, dBFS: $dBFS, showIndicator: $showIndicator, modalVisible: $modalVisible, linkedId: $linkedId, enableSpeechRecognition: $enableSpeechRecognition, enableTaskSummary: $enableTaskSummary, enableChecklistUpdates: $enableChecklistUpdates)';
  }
}

/// @nodoc
abstract mixin class _$AudioRecorderStateCopyWith<$Res>
    implements $AudioRecorderStateCopyWith<$Res> {
  factory _$AudioRecorderStateCopyWith(
          _AudioRecorderState value, $Res Function(_AudioRecorderState) _then) =
      __$AudioRecorderStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {AudioRecorderStatus status,
      Duration progress,
      double vu,
      double dBFS,
      bool showIndicator,
      bool modalVisible,
      String? linkedId,
      bool? enableSpeechRecognition,
      bool? enableTaskSummary,
      bool? enableChecklistUpdates});
}

/// @nodoc
class __$AudioRecorderStateCopyWithImpl<$Res>
    implements _$AudioRecorderStateCopyWith<$Res> {
  __$AudioRecorderStateCopyWithImpl(this._self, this._then);

  final _AudioRecorderState _self;
  final $Res Function(_AudioRecorderState) _then;

  /// Create a copy of AudioRecorderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? progress = null,
    Object? vu = null,
    Object? dBFS = null,
    Object? showIndicator = null,
    Object? modalVisible = null,
    Object? linkedId = freezed,
    Object? enableSpeechRecognition = freezed,
    Object? enableTaskSummary = freezed,
    Object? enableChecklistUpdates = freezed,
  }) {
    return _then(_AudioRecorderState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioRecorderStatus,
      progress: null == progress
          ? _self.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      vu: null == vu
          ? _self.vu
          : vu // ignore: cast_nullable_to_non_nullable
              as double,
      dBFS: null == dBFS
          ? _self.dBFS
          : dBFS // ignore: cast_nullable_to_non_nullable
              as double,
      showIndicator: null == showIndicator
          ? _self.showIndicator
          : showIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
      modalVisible: null == modalVisible
          ? _self.modalVisible
          : modalVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      linkedId: freezed == linkedId
          ? _self.linkedId
          : linkedId // ignore: cast_nullable_to_non_nullable
              as String?,
      enableSpeechRecognition: freezed == enableSpeechRecognition
          ? _self.enableSpeechRecognition
          : enableSpeechRecognition // ignore: cast_nullable_to_non_nullable
              as bool?,
      enableTaskSummary: freezed == enableTaskSummary
          ? _self.enableTaskSummary
          : enableTaskSummary // ignore: cast_nullable_to_non_nullable
              as bool?,
      enableChecklistUpdates: freezed == enableChecklistUpdates
          ? _self.enableChecklistUpdates
          : enableChecklistUpdates // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

// dart format on
