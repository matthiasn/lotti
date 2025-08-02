// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recorder_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AudioRecorderState {
  /// Current status of the recorder.
  AudioRecorderStatus get status => throw _privateConstructorUsedError;

  /// Duration of the current recording.
  Duration get progress => throw _privateConstructorUsedError;

  /// Current audio level in decibels (0-160 range).
  /// Used for VU meter visualization.
  double get vu => throw _privateConstructorUsedError;
  double get dBFS => throw _privateConstructorUsedError;

  /// Whether to show the floating recording indicator.
  /// Only relevant when recording and modal is not visible.
  bool get showIndicator => throw _privateConstructorUsedError;

  /// Whether the recording modal is currently visible.
  /// Used to coordinate with indicator display.
  bool get modalVisible => throw _privateConstructorUsedError;

  /// Selected language for transcription.
  /// Empty string means auto-detect.
  String? get language => throw _privateConstructorUsedError;

  /// Optional ID to link recording to existing journal entry.
  String? get linkedId => throw _privateConstructorUsedError;

  /// Whether to trigger speech recognition after recording.
  /// If null, uses category default settings.
  bool? get enableSpeechRecognition => throw _privateConstructorUsedError;

  /// Whether to trigger task summary after recording (if linked to task).
  /// If null, uses category default settings.
  bool? get enableTaskSummary => throw _privateConstructorUsedError;

  /// Create a copy of AudioRecorderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioRecorderStateCopyWith<AudioRecorderState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioRecorderStateCopyWith<$Res> {
  factory $AudioRecorderStateCopyWith(
          AudioRecorderState value, $Res Function(AudioRecorderState) then) =
      _$AudioRecorderStateCopyWithImpl<$Res, AudioRecorderState>;
  @useResult
  $Res call(
      {AudioRecorderStatus status,
      Duration progress,
      double vu,
      double dBFS,
      bool showIndicator,
      bool modalVisible,
      String? language,
      String? linkedId,
      bool? enableSpeechRecognition,
      bool? enableTaskSummary});
}

/// @nodoc
class _$AudioRecorderStateCopyWithImpl<$Res, $Val extends AudioRecorderState>
    implements $AudioRecorderStateCopyWith<$Res> {
  _$AudioRecorderStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    Object? language = freezed,
    Object? linkedId = freezed,
    Object? enableSpeechRecognition = freezed,
    Object? enableTaskSummary = freezed,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioRecorderStatus,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      vu: null == vu
          ? _value.vu
          : vu // ignore: cast_nullable_to_non_nullable
              as double,
      dBFS: null == dBFS
          ? _value.dBFS
          : dBFS // ignore: cast_nullable_to_non_nullable
              as double,
      showIndicator: null == showIndicator
          ? _value.showIndicator
          : showIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
      modalVisible: null == modalVisible
          ? _value.modalVisible
          : modalVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      linkedId: freezed == linkedId
          ? _value.linkedId
          : linkedId // ignore: cast_nullable_to_non_nullable
              as String?,
      enableSpeechRecognition: freezed == enableSpeechRecognition
          ? _value.enableSpeechRecognition
          : enableSpeechRecognition // ignore: cast_nullable_to_non_nullable
              as bool?,
      enableTaskSummary: freezed == enableTaskSummary
          ? _value.enableTaskSummary
          : enableTaskSummary // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AudioRecorderStateImplCopyWith<$Res>
    implements $AudioRecorderStateCopyWith<$Res> {
  factory _$$AudioRecorderStateImplCopyWith(_$AudioRecorderStateImpl value,
          $Res Function(_$AudioRecorderStateImpl) then) =
      __$$AudioRecorderStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {AudioRecorderStatus status,
      Duration progress,
      double vu,
      double dBFS,
      bool showIndicator,
      bool modalVisible,
      String? language,
      String? linkedId,
      bool? enableSpeechRecognition,
      bool? enableTaskSummary});
}

/// @nodoc
class __$$AudioRecorderStateImplCopyWithImpl<$Res>
    extends _$AudioRecorderStateCopyWithImpl<$Res, _$AudioRecorderStateImpl>
    implements _$$AudioRecorderStateImplCopyWith<$Res> {
  __$$AudioRecorderStateImplCopyWithImpl(_$AudioRecorderStateImpl _value,
      $Res Function(_$AudioRecorderStateImpl) _then)
      : super(_value, _then);

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
    Object? language = freezed,
    Object? linkedId = freezed,
    Object? enableSpeechRecognition = freezed,
    Object? enableTaskSummary = freezed,
  }) {
    return _then(_$AudioRecorderStateImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioRecorderStatus,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      vu: null == vu
          ? _value.vu
          : vu // ignore: cast_nullable_to_non_nullable
              as double,
      dBFS: null == dBFS
          ? _value.dBFS
          : dBFS // ignore: cast_nullable_to_non_nullable
              as double,
      showIndicator: null == showIndicator
          ? _value.showIndicator
          : showIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
      modalVisible: null == modalVisible
          ? _value.modalVisible
          : modalVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      linkedId: freezed == linkedId
          ? _value.linkedId
          : linkedId // ignore: cast_nullable_to_non_nullable
              as String?,
      enableSpeechRecognition: freezed == enableSpeechRecognition
          ? _value.enableSpeechRecognition
          : enableSpeechRecognition // ignore: cast_nullable_to_non_nullable
              as bool?,
      enableTaskSummary: freezed == enableTaskSummary
          ? _value.enableTaskSummary
          : enableTaskSummary // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc

class _$AudioRecorderStateImpl implements _AudioRecorderState {
  _$AudioRecorderStateImpl(
      {required this.status,
      required this.progress,
      required this.vu,
      required this.dBFS,
      required this.showIndicator,
      required this.modalVisible,
      required this.language,
      this.linkedId,
      this.enableSpeechRecognition,
      this.enableTaskSummary});

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

  /// Selected language for transcription.
  /// Empty string means auto-detect.
  @override
  final String? language;

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

  @override
  String toString() {
    return 'AudioRecorderState(status: $status, progress: $progress, vu: $vu, dBFS: $dBFS, showIndicator: $showIndicator, modalVisible: $modalVisible, language: $language, linkedId: $linkedId, enableSpeechRecognition: $enableSpeechRecognition, enableTaskSummary: $enableTaskSummary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioRecorderStateImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.vu, vu) || other.vu == vu) &&
            (identical(other.dBFS, dBFS) || other.dBFS == dBFS) &&
            (identical(other.showIndicator, showIndicator) ||
                other.showIndicator == showIndicator) &&
            (identical(other.modalVisible, modalVisible) ||
                other.modalVisible == modalVisible) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.linkedId, linkedId) ||
                other.linkedId == linkedId) &&
            (identical(
                    other.enableSpeechRecognition, enableSpeechRecognition) ||
                other.enableSpeechRecognition == enableSpeechRecognition) &&
            (identical(other.enableTaskSummary, enableTaskSummary) ||
                other.enableTaskSummary == enableTaskSummary));
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
      language,
      linkedId,
      enableSpeechRecognition,
      enableTaskSummary);

  /// Create a copy of AudioRecorderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioRecorderStateImplCopyWith<_$AudioRecorderStateImpl> get copyWith =>
      __$$AudioRecorderStateImplCopyWithImpl<_$AudioRecorderStateImpl>(
          this, _$identity);
}

abstract class _AudioRecorderState implements AudioRecorderState {
  factory _AudioRecorderState(
      {required final AudioRecorderStatus status,
      required final Duration progress,
      required final double vu,
      required final double dBFS,
      required final bool showIndicator,
      required final bool modalVisible,
      required final String? language,
      final String? linkedId,
      final bool? enableSpeechRecognition,
      final bool? enableTaskSummary}) = _$AudioRecorderStateImpl;

  /// Current status of the recorder.
  @override
  AudioRecorderStatus get status;

  /// Duration of the current recording.
  @override
  Duration get progress;

  /// Current audio level in decibels (0-160 range).
  /// Used for VU meter visualization.
  @override
  double get vu;
  @override
  double get dBFS;

  /// Whether to show the floating recording indicator.
  /// Only relevant when recording and modal is not visible.
  @override
  bool get showIndicator;

  /// Whether the recording modal is currently visible.
  /// Used to coordinate with indicator display.
  @override
  bool get modalVisible;

  /// Selected language for transcription.
  /// Empty string means auto-detect.
  @override
  String? get language;

  /// Optional ID to link recording to existing journal entry.
  @override
  String? get linkedId;

  /// Whether to trigger speech recognition after recording.
  /// If null, uses category default settings.
  @override
  bool? get enableSpeechRecognition;

  /// Whether to trigger task summary after recording (if linked to task).
  /// If null, uses category default settings.
  @override
  bool? get enableTaskSummary;

  /// Create a copy of AudioRecorderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioRecorderStateImplCopyWith<_$AudioRecorderStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
