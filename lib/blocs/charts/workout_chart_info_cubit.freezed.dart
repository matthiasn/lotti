// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_chart_info_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$WorkoutChartInfoState {
  Observation? get selected => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WorkoutChartInfoStateCopyWith<WorkoutChartInfoState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutChartInfoStateCopyWith<$Res> {
  factory $WorkoutChartInfoStateCopyWith(WorkoutChartInfoState value,
          $Res Function(WorkoutChartInfoState) then) =
      _$WorkoutChartInfoStateCopyWithImpl<$Res, WorkoutChartInfoState>;
  @useResult
  $Res call({Observation? selected});
}

/// @nodoc
class _$WorkoutChartInfoStateCopyWithImpl<$Res,
        $Val extends WorkoutChartInfoState>
    implements $WorkoutChartInfoStateCopyWith<$Res> {
  _$WorkoutChartInfoStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selected = freezed,
  }) {
    return _then(_value.copyWith(
      selected: freezed == selected
          ? _value.selected
          : selected // ignore: cast_nullable_to_non_nullable
              as Observation?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_WorkoutChartInfoStateCopyWith<$Res>
    implements $WorkoutChartInfoStateCopyWith<$Res> {
  factory _$$_WorkoutChartInfoStateCopyWith(_$_WorkoutChartInfoState value,
          $Res Function(_$_WorkoutChartInfoState) then) =
      __$$_WorkoutChartInfoStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Observation? selected});
}

/// @nodoc
class __$$_WorkoutChartInfoStateCopyWithImpl<$Res>
    extends _$WorkoutChartInfoStateCopyWithImpl<$Res, _$_WorkoutChartInfoState>
    implements _$$_WorkoutChartInfoStateCopyWith<$Res> {
  __$$_WorkoutChartInfoStateCopyWithImpl(_$_WorkoutChartInfoState _value,
      $Res Function(_$_WorkoutChartInfoState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selected = freezed,
  }) {
    return _then(_$_WorkoutChartInfoState(
      selected: freezed == selected
          ? _value.selected
          : selected // ignore: cast_nullable_to_non_nullable
              as Observation?,
    ));
  }
}

/// @nodoc

class _$_WorkoutChartInfoState implements _WorkoutChartInfoState {
  _$_WorkoutChartInfoState({required this.selected});

  @override
  final Observation? selected;

  @override
  String toString() {
    return 'WorkoutChartInfoState(selected: $selected)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_WorkoutChartInfoState &&
            (identical(other.selected, selected) ||
                other.selected == selected));
  }

  @override
  int get hashCode => Object.hash(runtimeType, selected);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_WorkoutChartInfoStateCopyWith<_$_WorkoutChartInfoState> get copyWith =>
      __$$_WorkoutChartInfoStateCopyWithImpl<_$_WorkoutChartInfoState>(
          this, _$identity);
}

abstract class _WorkoutChartInfoState implements WorkoutChartInfoState {
  factory _WorkoutChartInfoState({required final Observation? selected}) =
      _$_WorkoutChartInfoState;

  @override
  Observation? get selected;
  @override
  @JsonKey(ignore: true)
  _$$_WorkoutChartInfoStateCopyWith<_$_WorkoutChartInfoState> get copyWith =>
      throw _privateConstructorUsedError;
}
