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
abstract class _$$HealthChartInfoStateImplCopyWith<$Res>
    implements $HealthChartInfoStateCopyWith<$Res> {
  factory _$$HealthChartInfoStateImplCopyWith(_$HealthChartInfoStateImpl value,
          $Res Function(_$HealthChartInfoStateImpl) then) =
      __$$HealthChartInfoStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Observation? selected});
}

/// @nodoc
class __$$HealthChartInfoStateImplCopyWithImpl<$Res>
    extends _$HealthChartInfoStateCopyWithImpl<$Res, _$HealthChartInfoStateImpl>
    implements _$$HealthChartInfoStateImplCopyWith<$Res> {
  __$$HealthChartInfoStateImplCopyWithImpl(_$HealthChartInfoStateImpl _value,
      $Res Function(_$HealthChartInfoStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selected = freezed,
  }) {
    return _then(_$HealthChartInfoStateImpl(
      selected: freezed == selected
          ? _value.selected
          : selected // ignore: cast_nullable_to_non_nullable
              as Observation?,
    ));
  }
}

/// @nodoc

class _$HealthChartInfoStateImpl implements _HealthChartInfoState {
  _$HealthChartInfoStateImpl({required this.selected});

  @override
  final Observation? selected;

  @override
  String toString() {
    return 'HealthChartInfoState(selected: $selected)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HealthChartInfoStateImpl &&
            (identical(other.selected, selected) ||
                other.selected == selected));
  }

  @override
  int get hashCode => Object.hash(runtimeType, selected);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HealthChartInfoStateImplCopyWith<_$HealthChartInfoStateImpl>
      get copyWith =>
          __$$HealthChartInfoStateImplCopyWithImpl<_$HealthChartInfoStateImpl>(
              this, _$identity);
}

abstract class _HealthChartInfoState implements HealthChartInfoState {
  factory _HealthChartInfoState({required final Observation? selected}) =
      _$HealthChartInfoStateImpl;

  @override
  Observation? get selected;
  @override
  @JsonKey(ignore: true)
  _$$HealthChartInfoStateImplCopyWith<_$HealthChartInfoStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
