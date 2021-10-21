// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'recorder_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
class _$AudioRecorderStateTearOff {
  const _$AudioRecorderStateTearOff();

  _AudioRecorderState call(
      {required AudioRecorderStatus status,
      required Duration progress,
      required double decibels}) {
    return _AudioRecorderState(
      status: status,
      progress: progress,
      decibels: decibels,
    );
  }
}

/// @nodoc
const $AudioRecorderState = _$AudioRecorderStateTearOff();

/// @nodoc
mixin _$AudioRecorderState {
  AudioRecorderStatus get status => throw _privateConstructorUsedError;
  Duration get progress => throw _privateConstructorUsedError;
  double get decibels => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $AudioRecorderStateCopyWith<AudioRecorderState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioRecorderStateCopyWith<$Res> {
  factory $AudioRecorderStateCopyWith(
          AudioRecorderState value, $Res Function(AudioRecorderState) then) =
      _$AudioRecorderStateCopyWithImpl<$Res>;
  $Res call({AudioRecorderStatus status, Duration progress, double decibels});
}

/// @nodoc
class _$AudioRecorderStateCopyWithImpl<$Res>
    implements $AudioRecorderStateCopyWith<$Res> {
  _$AudioRecorderStateCopyWithImpl(this._value, this._then);

  final AudioRecorderState _value;
  // ignore: unused_field
  final $Res Function(AudioRecorderState) _then;

  @override
  $Res call({
    Object? status = freezed,
    Object? progress = freezed,
    Object? decibels = freezed,
  }) {
    return _then(_value.copyWith(
      status: status == freezed
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioRecorderStatus,
      progress: progress == freezed
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      decibels: decibels == freezed
          ? _value.decibels
          : decibels // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
abstract class _$AudioRecorderStateCopyWith<$Res>
    implements $AudioRecorderStateCopyWith<$Res> {
  factory _$AudioRecorderStateCopyWith(
          _AudioRecorderState value, $Res Function(_AudioRecorderState) then) =
      __$AudioRecorderStateCopyWithImpl<$Res>;
  @override
  $Res call({AudioRecorderStatus status, Duration progress, double decibels});
}

/// @nodoc
class __$AudioRecorderStateCopyWithImpl<$Res>
    extends _$AudioRecorderStateCopyWithImpl<$Res>
    implements _$AudioRecorderStateCopyWith<$Res> {
  __$AudioRecorderStateCopyWithImpl(
      _AudioRecorderState _value, $Res Function(_AudioRecorderState) _then)
      : super(_value, (v) => _then(v as _AudioRecorderState));

  @override
  _AudioRecorderState get _value => super._value as _AudioRecorderState;

  @override
  $Res call({
    Object? status = freezed,
    Object? progress = freezed,
    Object? decibels = freezed,
  }) {
    return _then(_AudioRecorderState(
      status: status == freezed
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as AudioRecorderStatus,
      progress: progress == freezed
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      decibels: decibels == freezed
          ? _value.decibels
          : decibels // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$_AudioRecorderState implements _AudioRecorderState {
  _$_AudioRecorderState(
      {required this.status, required this.progress, required this.decibels});

  @override
  final AudioRecorderStatus status;
  @override
  final Duration progress;
  @override
  final double decibels;

  @override
  String toString() {
    return 'AudioRecorderState(status: $status, progress: $progress, decibels: $decibels)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AudioRecorderState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.decibels, decibels) ||
                other.decibels == decibels));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, progress, decibels);

  @JsonKey(ignore: true)
  @override
  _$AudioRecorderStateCopyWith<_AudioRecorderState> get copyWith =>
      __$AudioRecorderStateCopyWithImpl<_AudioRecorderState>(this, _$identity);
}

abstract class _AudioRecorderState implements AudioRecorderState {
  factory _AudioRecorderState(
      {required AudioRecorderStatus status,
      required Duration progress,
      required double decibels}) = _$_AudioRecorderState;

  @override
  AudioRecorderStatus get status;
  @override
  Duration get progress;
  @override
  double get decibels;
  @override
  @JsonKey(ignore: true)
  _$AudioRecorderStateCopyWith<_AudioRecorderState> get copyWith =>
      throw _privateConstructorUsedError;
}
