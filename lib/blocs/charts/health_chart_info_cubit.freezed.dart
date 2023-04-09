// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_chart_info_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$HealthChartInfoState {
  Observation? get selected => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $HealthChartInfoStateCopyWith<HealthChartInfoState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HealthChartInfoStateCopyWith<$Res> {
  factory $HealthChartInfoStateCopyWith(HealthChartInfoState value,
          $Res Function(HealthChartInfoState) then) =
      _$HealthChartInfoStateCopyWithImpl<$Res, HealthChartInfoState>;
  @useResult
  $Res call({Observation? selected});
}

/// @nodoc
class _$HealthChartInfoStateCopyWithImpl<$Res,
        $Val extends HealthChartInfoState>
    implements $HealthChartInfoStateCopyWith<$Res> {
  _$HealthChartInfoStateCopyWithImpl(this._value, this._then);

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
abstract class _$$_HealthChartInfoStateCopyWith<$Res>
    implements $HealthChartInfoStateCopyWith<$Res> {
  factory _$$_HealthChartInfoStateCopyWith(_$_HealthChartInfoState value,
          $Res Function(_$_HealthChartInfoState) then) =
      __$$_HealthChartInfoStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Observation? selected});
}

/// @nodoc
class __$$_HealthChartInfoStateCopyWithImpl<$Res>
    extends _$HealthChartInfoStateCopyWithImpl<$Res, _$_HealthChartInfoState>
    implements _$$_HealthChartInfoStateCopyWith<$Res> {
  __$$_HealthChartInfoStateCopyWithImpl(_$_HealthChartInfoState _value,
      $Res Function(_$_HealthChartInfoState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selected = freezed,
  }) {
    return _then(_$_HealthChartInfoState(
      selected: freezed == selected
          ? _value.selected
          : selected // ignore: cast_nullable_to_non_nullable
              as Observation?,
    ));
  }
}

/// @nodoc

class _$_HealthChartInfoState implements _HealthChartInfoState {
  _$_HealthChartInfoState({required this.selected});

  @override
  final Observation? selected;

  @override
  String toString() {
    return 'HealthChartInfoState(selected: $selected)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_HealthChartInfoState &&
            (identical(other.selected, selected) ||
                other.selected == selected));
  }

  @override
  int get hashCode => Object.hash(runtimeType, selected);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_HealthChartInfoStateCopyWith<_$_HealthChartInfoState> get copyWith =>
      __$$_HealthChartInfoStateCopyWithImpl<_$_HealthChartInfoState>(
          this, _$identity);
}

abstract class _HealthChartInfoState implements HealthChartInfoState {
  factory _HealthChartInfoState({required final Observation? selected}) =
      _$_HealthChartInfoState;

  @override
  Observation? get selected;
  @override
  @JsonKey(ignore: true)
  _$$_HealthChartInfoStateCopyWith<_$_HealthChartInfoState> get copyWith =>
      throw _privateConstructorUsedError;
}
