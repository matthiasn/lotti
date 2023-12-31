// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'measurables_chart_info_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$MeasurablesChartInfoState {
  Observation? get selected => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MeasurablesChartInfoStateCopyWith<MeasurablesChartInfoState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeasurablesChartInfoStateCopyWith<$Res> {
  factory $MeasurablesChartInfoStateCopyWith(MeasurablesChartInfoState value,
          $Res Function(MeasurablesChartInfoState) then) =
      _$MeasurablesChartInfoStateCopyWithImpl<$Res, MeasurablesChartInfoState>;
  @useResult
  $Res call({Observation? selected});
}

/// @nodoc
class _$MeasurablesChartInfoStateCopyWithImpl<$Res,
        $Val extends MeasurablesChartInfoState>
    implements $MeasurablesChartInfoStateCopyWith<$Res> {
  _$MeasurablesChartInfoStateCopyWithImpl(this._value, this._then);

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
abstract class _$$MeasurablesChartInfoStateImplCopyWith<$Res>
    implements $MeasurablesChartInfoStateCopyWith<$Res> {
  factory _$$MeasurablesChartInfoStateImplCopyWith(
          _$MeasurablesChartInfoStateImpl value,
          $Res Function(_$MeasurablesChartInfoStateImpl) then) =
      __$$MeasurablesChartInfoStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Observation? selected});
}

/// @nodoc
class __$$MeasurablesChartInfoStateImplCopyWithImpl<$Res>
    extends _$MeasurablesChartInfoStateCopyWithImpl<$Res,
        _$MeasurablesChartInfoStateImpl>
    implements _$$MeasurablesChartInfoStateImplCopyWith<$Res> {
  __$$MeasurablesChartInfoStateImplCopyWithImpl(
      _$MeasurablesChartInfoStateImpl _value,
      $Res Function(_$MeasurablesChartInfoStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selected = freezed,
  }) {
    return _then(_$MeasurablesChartInfoStateImpl(
      selected: freezed == selected
          ? _value.selected
          : selected // ignore: cast_nullable_to_non_nullable
              as Observation?,
    ));
  }
}

/// @nodoc

class _$MeasurablesChartInfoStateImpl implements _MeasurablesChartInfoState {
  _$MeasurablesChartInfoStateImpl({required this.selected});

  @override
  final Observation? selected;

  @override
  String toString() {
    return 'MeasurablesChartInfoState(selected: $selected)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeasurablesChartInfoStateImpl &&
            (identical(other.selected, selected) ||
                other.selected == selected));
  }

  @override
  int get hashCode => Object.hash(runtimeType, selected);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MeasurablesChartInfoStateImplCopyWith<_$MeasurablesChartInfoStateImpl>
      get copyWith => __$$MeasurablesChartInfoStateImplCopyWithImpl<
          _$MeasurablesChartInfoStateImpl>(this, _$identity);
}

abstract class _MeasurablesChartInfoState implements MeasurablesChartInfoState {
  factory _MeasurablesChartInfoState({required final Observation? selected}) =
      _$MeasurablesChartInfoStateImpl;

  @override
  Observation? get selected;
  @override
  @JsonKey(ignore: true)
  _$$MeasurablesChartInfoStateImplCopyWith<_$MeasurablesChartInfoStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
