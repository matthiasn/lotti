// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

QuantitativeData _$QuantitativeDataFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'cumulativeQuantityData':
      return CumulativeQuantityData.fromJson(json);
    case 'discreteQuantityData':
      return DiscreteQuantityData.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'QuantitativeData',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$QuantitativeData {
  DateTime get dateFrom => throw _privateConstructorUsedError;
  DateTime get dateTo => throw _privateConstructorUsedError;
  num get value => throw _privateConstructorUsedError;
  String get dataType => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;
  String? get deviceType => throw _privateConstructorUsedError;
  String? get platformType => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)
        cumulativeQuantityData,
    required TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)
        discreteQuantityData,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)?
        cumulativeQuantityData,
    TResult? Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)?
        discreteQuantityData,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)?
        cumulativeQuantityData,
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)?
        discreteQuantityData,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CumulativeQuantityData value)
        cumulativeQuantityData,
    required TResult Function(DiscreteQuantityData value) discreteQuantityData,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult? Function(DiscreteQuantityData value)? discreteQuantityData,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult Function(DiscreteQuantityData value)? discreteQuantityData,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $QuantitativeDataCopyWith<QuantitativeData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuantitativeDataCopyWith<$Res> {
  factory $QuantitativeDataCopyWith(
          QuantitativeData value, $Res Function(QuantitativeData) then) =
      _$QuantitativeDataCopyWithImpl<$Res, QuantitativeData>;
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      num value,
      String dataType,
      String unit,
      String? deviceType,
      String? platformType});
}

/// @nodoc
class _$QuantitativeDataCopyWithImpl<$Res, $Val extends QuantitativeData>
    implements $QuantitativeDataCopyWith<$Res> {
  _$QuantitativeDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataType = null,
    Object? unit = null,
    Object? deviceType = freezed,
    Object? platformType = freezed,
  }) {
    return _then(_value.copyWith(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataType: null == dataType
          ? _value.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      deviceType: freezed == deviceType
          ? _value.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      platformType: freezed == platformType
          ? _value.platformType
          : platformType // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CumulativeQuantityDataCopyWith<$Res>
    implements $QuantitativeDataCopyWith<$Res> {
  factory _$$CumulativeQuantityDataCopyWith(_$CumulativeQuantityData value,
          $Res Function(_$CumulativeQuantityData) then) =
      __$$CumulativeQuantityDataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      num value,
      String dataType,
      String unit,
      String? deviceType,
      String? platformType});
}

/// @nodoc
class __$$CumulativeQuantityDataCopyWithImpl<$Res>
    extends _$QuantitativeDataCopyWithImpl<$Res, _$CumulativeQuantityData>
    implements _$$CumulativeQuantityDataCopyWith<$Res> {
  __$$CumulativeQuantityDataCopyWithImpl(_$CumulativeQuantityData _value,
      $Res Function(_$CumulativeQuantityData) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataType = null,
    Object? unit = null,
    Object? deviceType = freezed,
    Object? platformType = freezed,
  }) {
    return _then(_$CumulativeQuantityData(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataType: null == dataType
          ? _value.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      deviceType: freezed == deviceType
          ? _value.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      platformType: freezed == platformType
          ? _value.platformType
          : platformType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CumulativeQuantityData implements CumulativeQuantityData {
  _$CumulativeQuantityData(
      {required this.dateFrom,
      required this.dateTo,
      required this.value,
      required this.dataType,
      required this.unit,
      this.deviceType,
      this.platformType,
      final String? $type})
      : $type = $type ?? 'cumulativeQuantityData';

  factory _$CumulativeQuantityData.fromJson(Map<String, dynamic> json) =>
      _$$CumulativeQuantityDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final num value;
  @override
  final String dataType;
  @override
  final String unit;
  @override
  final String? deviceType;
  @override
  final String? platformType;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'QuantitativeData.cumulativeQuantityData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataType: $dataType, unit: $unit, deviceType: $deviceType, platformType: $platformType)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CumulativeQuantityData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.dataType, dataType) ||
                other.dataType == dataType) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.deviceType, deviceType) ||
                other.deviceType == deviceType) &&
            (identical(other.platformType, platformType) ||
                other.platformType == platformType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, dateFrom, dateTo, value,
      dataType, unit, deviceType, platformType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CumulativeQuantityDataCopyWith<_$CumulativeQuantityData> get copyWith =>
      __$$CumulativeQuantityDataCopyWithImpl<_$CumulativeQuantityData>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)
        cumulativeQuantityData,
    required TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)
        discreteQuantityData,
  }) {
    return cumulativeQuantityData(
        dateFrom, dateTo, value, dataType, unit, deviceType, platformType);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)?
        cumulativeQuantityData,
    TResult? Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)?
        discreteQuantityData,
  }) {
    return cumulativeQuantityData?.call(
        dateFrom, dateTo, value, dataType, unit, deviceType, platformType);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)?
        cumulativeQuantityData,
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)?
        discreteQuantityData,
    required TResult orElse(),
  }) {
    if (cumulativeQuantityData != null) {
      return cumulativeQuantityData(
          dateFrom, dateTo, value, dataType, unit, deviceType, platformType);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CumulativeQuantityData value)
        cumulativeQuantityData,
    required TResult Function(DiscreteQuantityData value) discreteQuantityData,
  }) {
    return cumulativeQuantityData(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult? Function(DiscreteQuantityData value)? discreteQuantityData,
  }) {
    return cumulativeQuantityData?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult Function(DiscreteQuantityData value)? discreteQuantityData,
    required TResult orElse(),
  }) {
    if (cumulativeQuantityData != null) {
      return cumulativeQuantityData(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CumulativeQuantityDataToJson(
      this,
    );
  }
}

abstract class CumulativeQuantityData implements QuantitativeData {
  factory CumulativeQuantityData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final num value,
      required final String dataType,
      required final String unit,
      final String? deviceType,
      final String? platformType}) = _$CumulativeQuantityData;

  factory CumulativeQuantityData.fromJson(Map<String, dynamic> json) =
      _$CumulativeQuantityData.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  num get value;
  @override
  String get dataType;
  @override
  String get unit;
  @override
  String? get deviceType;
  @override
  String? get platformType;
  @override
  @JsonKey(ignore: true)
  _$$CumulativeQuantityDataCopyWith<_$CumulativeQuantityData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DiscreteQuantityDataCopyWith<$Res>
    implements $QuantitativeDataCopyWith<$Res> {
  factory _$$DiscreteQuantityDataCopyWith(_$DiscreteQuantityData value,
          $Res Function(_$DiscreteQuantityData) then) =
      __$$DiscreteQuantityDataCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime dateFrom,
      DateTime dateTo,
      num value,
      String dataType,
      String unit,
      String? deviceType,
      String? platformType,
      String? sourceName,
      String? sourceId,
      String? deviceId});
}

/// @nodoc
class __$$DiscreteQuantityDataCopyWithImpl<$Res>
    extends _$QuantitativeDataCopyWithImpl<$Res, _$DiscreteQuantityData>
    implements _$$DiscreteQuantityDataCopyWith<$Res> {
  __$$DiscreteQuantityDataCopyWithImpl(_$DiscreteQuantityData _value,
      $Res Function(_$DiscreteQuantityData) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataType = null,
    Object? unit = null,
    Object? deviceType = freezed,
    Object? platformType = freezed,
    Object? sourceName = freezed,
    Object? sourceId = freezed,
    Object? deviceId = freezed,
  }) {
    return _then(_$DiscreteQuantityData(
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataType: null == dataType
          ? _value.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      deviceType: freezed == deviceType
          ? _value.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      platformType: freezed == platformType
          ? _value.platformType
          : platformType // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceName: freezed == sourceName
          ? _value.sourceName
          : sourceName // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceId: freezed == sourceId
          ? _value.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceId: freezed == deviceId
          ? _value.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DiscreteQuantityData implements DiscreteQuantityData {
  _$DiscreteQuantityData(
      {required this.dateFrom,
      required this.dateTo,
      required this.value,
      required this.dataType,
      required this.unit,
      this.deviceType,
      this.platformType,
      this.sourceName,
      this.sourceId,
      this.deviceId,
      final String? $type})
      : $type = $type ?? 'discreteQuantityData';

  factory _$DiscreteQuantityData.fromJson(Map<String, dynamic> json) =>
      _$$DiscreteQuantityDataFromJson(json);

  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  @override
  final num value;
  @override
  final String dataType;
  @override
  final String unit;
  @override
  final String? deviceType;
  @override
  final String? platformType;
  @override
  final String? sourceName;
  @override
  final String? sourceId;
  @override
  final String? deviceId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'QuantitativeData.discreteQuantityData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataType: $dataType, unit: $unit, deviceType: $deviceType, platformType: $platformType, sourceName: $sourceName, sourceId: $sourceId, deviceId: $deviceId)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DiscreteQuantityData &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.dataType, dataType) ||
                other.dataType == dataType) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.deviceType, deviceType) ||
                other.deviceType == deviceType) &&
            (identical(other.platformType, platformType) ||
                other.platformType == platformType) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourceId, sourceId) ||
                other.sourceId == sourceId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, dateFrom, dateTo, value,
      dataType, unit, deviceType, platformType, sourceName, sourceId, deviceId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DiscreteQuantityDataCopyWith<_$DiscreteQuantityData> get copyWith =>
      __$$DiscreteQuantityDataCopyWithImpl<_$DiscreteQuantityData>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)
        cumulativeQuantityData,
    required TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)
        discreteQuantityData,
  }) {
    return discreteQuantityData(dateFrom, dateTo, value, dataType, unit,
        deviceType, platformType, sourceName, sourceId, deviceId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)?
        cumulativeQuantityData,
    TResult? Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)?
        discreteQuantityData,
  }) {
    return discreteQuantityData?.call(dateFrom, dateTo, value, dataType, unit,
        deviceType, platformType, sourceName, sourceId, deviceId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType)?
        cumulativeQuantityData,
    TResult Function(
            DateTime dateFrom,
            DateTime dateTo,
            num value,
            String dataType,
            String unit,
            String? deviceType,
            String? platformType,
            String? sourceName,
            String? sourceId,
            String? deviceId)?
        discreteQuantityData,
    required TResult orElse(),
  }) {
    if (discreteQuantityData != null) {
      return discreteQuantityData(dateFrom, dateTo, value, dataType, unit,
          deviceType, platformType, sourceName, sourceId, deviceId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CumulativeQuantityData value)
        cumulativeQuantityData,
    required TResult Function(DiscreteQuantityData value) discreteQuantityData,
  }) {
    return discreteQuantityData(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult? Function(DiscreteQuantityData value)? discreteQuantityData,
  }) {
    return discreteQuantityData?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult Function(DiscreteQuantityData value)? discreteQuantityData,
    required TResult orElse(),
  }) {
    if (discreteQuantityData != null) {
      return discreteQuantityData(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DiscreteQuantityDataToJson(
      this,
    );
  }
}

abstract class DiscreteQuantityData implements QuantitativeData {
  factory DiscreteQuantityData(
      {required final DateTime dateFrom,
      required final DateTime dateTo,
      required final num value,
      required final String dataType,
      required final String unit,
      final String? deviceType,
      final String? platformType,
      final String? sourceName,
      final String? sourceId,
      final String? deviceId}) = _$DiscreteQuantityData;

  factory DiscreteQuantityData.fromJson(Map<String, dynamic> json) =
      _$DiscreteQuantityData.fromJson;

  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  num get value;
  @override
  String get dataType;
  @override
  String get unit;
  @override
  String? get deviceType;
  @override
  String? get platformType;
  String? get sourceName;
  String? get sourceId;
  String? get deviceId;
  @override
  @JsonKey(ignore: true)
  _$$DiscreteQuantityDataCopyWith<_$DiscreteQuantityData> get copyWith =>
      throw _privateConstructorUsedError;
}
