// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_progress_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TaskProgressState {
  Duration get progress => throw _privateConstructorUsedError;
  Duration get estimate => throw _privateConstructorUsedError;

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskProgressStateCopyWith<TaskProgressState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskProgressStateCopyWith<$Res> {
  factory $TaskProgressStateCopyWith(
          TaskProgressState value, $Res Function(TaskProgressState) then) =
      _$TaskProgressStateCopyWithImpl<$Res, TaskProgressState>;
  @useResult
  $Res call({Duration progress, Duration estimate});
}

/// @nodoc
class _$TaskProgressStateCopyWithImpl<$Res, $Val extends TaskProgressState>
    implements $TaskProgressStateCopyWith<$Res> {
  _$TaskProgressStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? estimate = null,
  }) {
    return _then(_value.copyWith(
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      estimate: null == estimate
          ? _value.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskProgressStateImplCopyWith<$Res>
    implements $TaskProgressStateCopyWith<$Res> {
  factory _$$TaskProgressStateImplCopyWith(_$TaskProgressStateImpl value,
          $Res Function(_$TaskProgressStateImpl) then) =
      __$$TaskProgressStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Duration progress, Duration estimate});
}

/// @nodoc
class __$$TaskProgressStateImplCopyWithImpl<$Res>
    extends _$TaskProgressStateCopyWithImpl<$Res, _$TaskProgressStateImpl>
    implements _$$TaskProgressStateImplCopyWith<$Res> {
  __$$TaskProgressStateImplCopyWithImpl(_$TaskProgressStateImpl _value,
      $Res Function(_$TaskProgressStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? progress = null,
    Object? estimate = null,
  }) {
    return _then(_$TaskProgressStateImpl(
      progress: null == progress
          ? _value.progress
          : progress // ignore: cast_nullable_to_non_nullable
              as Duration,
      estimate: null == estimate
          ? _value.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc

class _$TaskProgressStateImpl implements _TaskProgressState {
  const _$TaskProgressStateImpl(
      {required this.progress, required this.estimate});

  @override
  final Duration progress;
  @override
  final Duration estimate;

  @override
  String toString() {
    return 'TaskProgressState(progress: $progress, estimate: $estimate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskProgressStateImpl &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.estimate, estimate) ||
                other.estimate == estimate));
  }

  @override
  int get hashCode => Object.hash(runtimeType, progress, estimate);

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskProgressStateImplCopyWith<_$TaskProgressStateImpl> get copyWith =>
      __$$TaskProgressStateImplCopyWithImpl<_$TaskProgressStateImpl>(
          this, _$identity);
}

abstract class _TaskProgressState implements TaskProgressState {
  const factory _TaskProgressState(
      {required final Duration progress,
      required final Duration estimate}) = _$TaskProgressStateImpl;

  @override
  Duration get progress;
  @override
  Duration get estimate;

  /// Create a copy of TaskProgressState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskProgressStateImplCopyWith<_$TaskProgressStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
