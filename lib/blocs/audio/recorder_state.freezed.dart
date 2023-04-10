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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$AudioRecorderState {
  AudioRecorderStatus get status => throw _privateConstructorUsedError;
  Duration get progress => throw _privateConstructorUsedError;
  double get decibels => throw _privateConstructorUsedError;
  bool get showIndicator => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
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
      double decibels,
      bool showIndicator});
}

/// @nodoc
class _$AudioRecorderStateCopyWithImpl<$Res, $Val extends AudioRecorderState>
    implements $AudioRecorderStateCopyWith<$Res> {
  _$AudioRecorderStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? progress = null,
    Object? decibels = null,
    Object? showIndicator = null,
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
      decibels: null == decibels
          ? _value.decibels
          : decibels // ignore: cast_nullable_to_non_nullable
              as double,
      showIndicator: null == showIndicator
          ? _value.showIndicator
          : showIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_AudioRecorderStateCopyWith<$Res>
    implements $AudioRecorderStateCopyWith<$Res> {
  factory _$$_AudioRecorderStateCopyWith(_$_AudioRecorderState value,
          $Res Function(_$_AudioRecorderState) then) =
      __$$_AudioRecorderStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {AudioRecorderStatus status,
      Duration progress,
      double decibels,
      bool showIndicator});
}

/// @nodoc
class __$$_AudioRecorderStateCopyWithImpl<$Res>
    extends _$AudioRecorderStateCopyWithImpl<$Res, _$_AudioRecorderState>
    implements _$$_AudioRecorderStateCopyWith<$Res> {
  __$$_AudioRecorderStateCopyWithImpl(
      _$_AudioRecorderState _value, $Res Function(_$_AudioRecorderState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? progress = null,
    Object? decibels = null,
    Object? showIndicator = null,
  }) {
    return _then(_$_AudioRecorderState(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioRecorderStatus,
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      decibels: null == decibels
          ? _value.decibels
          : decibels // ignore: cast_nullable_to_non_nullable
              as double,
      showIndicator: null == showIndicator
          ? _value.showIndicator
          : showIndicator // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$_AudioRecorderState implements _AudioRecorderState {
  _$_AudioRecorderState(
      {required this.status,
      required this.progress,
      required this.decibels,
      required this.showIndicator});

  @override
  final AudioRecorderStatus status;
  @override
  final Duration progress;
  @override
  final double decibels;
  @override
  final bool showIndicator;

  @override
  String toString() {
    return 'AudioRecorderState(status: $status, progress: $progress, decibels: $decibels, showIndicator: $showIndicator)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_AudioRecorderState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.decibels, decibels) ||
                other.decibels == decibels) &&
            (identical(other.showIndicator, showIndicator) ||
                other.showIndicator == showIndicator));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, status, progress, decibels, showIndicator);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_AudioRecorderStateCopyWith<_$_AudioRecorderState> get copyWith =>
      __$$_AudioRecorderStateCopyWithImpl<_$_AudioRecorderState>(
          this, _$identity);
}

abstract class _AudioRecorderState implements AudioRecorderState {
  factory _AudioRecorderState(
      {required final AudioRecorderStatus status,
      required final Duration progress,
      required final double decibels,
      required final bool showIndicator}) = _$_AudioRecorderState;

  @override
  AudioRecorderStatus get status;
  @override
  Duration get progress;
  @override
  double get decibels;
  @override
  bool get showIndicator;
  @override
  @JsonKey(ignore: true)
  _$$_AudioRecorderStateCopyWith<_$_AudioRecorderState> get copyWith =>
      throw _privateConstructorUsedError;
}
