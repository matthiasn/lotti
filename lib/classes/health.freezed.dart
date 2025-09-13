// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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
  DateTime get dateFrom;
  DateTime get dateTo;
  num get value;
  String get dataType;
  String get unit;
  String? get deviceType;
  String? get platformType;

  /// Create a copy of QuantitativeData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $QuantitativeDataCopyWith<QuantitativeData> get copyWith =>
      _$QuantitativeDataCopyWithImpl<QuantitativeData>(
          this as QuantitativeData, _$identity);

  /// Serializes this QuantitativeData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is QuantitativeData &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dateFrom, dateTo, value,
      dataType, unit, deviceType, platformType);

  @override
  String toString() {
    return 'QuantitativeData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataType: $dataType, unit: $unit, deviceType: $deviceType, platformType: $platformType)';
  }
}

/// @nodoc
abstract mixin class $QuantitativeDataCopyWith<$Res> {
  factory $QuantitativeDataCopyWith(
          QuantitativeData value, $Res Function(QuantitativeData) _then) =
      _$QuantitativeDataCopyWithImpl;
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
class _$QuantitativeDataCopyWithImpl<$Res>
    implements $QuantitativeDataCopyWith<$Res> {
  _$QuantitativeDataCopyWithImpl(this._self, this._then);

  final QuantitativeData _self;
  final $Res Function(QuantitativeData) _then;

  /// Create a copy of QuantitativeData
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataType: null == dataType
          ? _self.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      deviceType: freezed == deviceType
          ? _self.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      platformType: freezed == platformType
          ? _self.platformType
          : platformType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [QuantitativeData].
extension QuantitativeDataPatterns on QuantitativeData {
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
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult Function(DiscreteQuantityData value)? discreteQuantityData,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case CumulativeQuantityData() when cumulativeQuantityData != null:
        return cumulativeQuantityData(_that);
      case DiscreteQuantityData() when discreteQuantityData != null:
        return discreteQuantityData(_that);
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
  TResult map<TResult extends Object?>({
    required TResult Function(CumulativeQuantityData value)
        cumulativeQuantityData,
    required TResult Function(DiscreteQuantityData value) discreteQuantityData,
  }) {
    final _that = this;
    switch (_that) {
      case CumulativeQuantityData():
        return cumulativeQuantityData(_that);
      case DiscreteQuantityData():
        return discreteQuantityData(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CumulativeQuantityData value)? cumulativeQuantityData,
    TResult? Function(DiscreteQuantityData value)? discreteQuantityData,
  }) {
    final _that = this;
    switch (_that) {
      case CumulativeQuantityData() when cumulativeQuantityData != null:
        return cumulativeQuantityData(_that);
      case DiscreteQuantityData() when discreteQuantityData != null:
        return discreteQuantityData(_that);
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
    final _that = this;
    switch (_that) {
      case CumulativeQuantityData() when cumulativeQuantityData != null:
        return cumulativeQuantityData(_that.dateFrom, _that.dateTo, _that.value,
            _that.dataType, _that.unit, _that.deviceType, _that.platformType);
      case DiscreteQuantityData() when discreteQuantityData != null:
        return discreteQuantityData(
            _that.dateFrom,
            _that.dateTo,
            _that.value,
            _that.dataType,
            _that.unit,
            _that.deviceType,
            _that.platformType,
            _that.sourceName,
            _that.sourceId,
            _that.deviceId);
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
    final _that = this;
    switch (_that) {
      case CumulativeQuantityData():
        return cumulativeQuantityData(_that.dateFrom, _that.dateTo, _that.value,
            _that.dataType, _that.unit, _that.deviceType, _that.platformType);
      case DiscreteQuantityData():
        return discreteQuantityData(
            _that.dateFrom,
            _that.dateTo,
            _that.value,
            _that.dataType,
            _that.unit,
            _that.deviceType,
            _that.platformType,
            _that.sourceName,
            _that.sourceId,
            _that.deviceId);
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
    final _that = this;
    switch (_that) {
      case CumulativeQuantityData() when cumulativeQuantityData != null:
        return cumulativeQuantityData(_that.dateFrom, _that.dateTo, _that.value,
            _that.dataType, _that.unit, _that.deviceType, _that.platformType);
      case DiscreteQuantityData() when discreteQuantityData != null:
        return discreteQuantityData(
            _that.dateFrom,
            _that.dateTo,
            _that.value,
            _that.dataType,
            _that.unit,
            _that.deviceType,
            _that.platformType,
            _that.sourceName,
            _that.sourceId,
            _that.deviceId);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class CumulativeQuantityData implements QuantitativeData {
  const CumulativeQuantityData(
      {required this.dateFrom,
      required this.dateTo,
      required this.value,
      required this.dataType,
      required this.unit,
      this.deviceType,
      this.platformType,
      final String? $type})
      : $type = $type ?? 'cumulativeQuantityData';
  factory CumulativeQuantityData.fromJson(Map<String, dynamic> json) =>
      _$CumulativeQuantityDataFromJson(json);

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

  /// Create a copy of QuantitativeData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CumulativeQuantityDataCopyWith<CumulativeQuantityData> get copyWith =>
      _$CumulativeQuantityDataCopyWithImpl<CumulativeQuantityData>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CumulativeQuantityDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CumulativeQuantityData &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dateFrom, dateTo, value,
      dataType, unit, deviceType, platformType);

  @override
  String toString() {
    return 'QuantitativeData.cumulativeQuantityData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataType: $dataType, unit: $unit, deviceType: $deviceType, platformType: $platformType)';
  }
}

/// @nodoc
abstract mixin class $CumulativeQuantityDataCopyWith<$Res>
    implements $QuantitativeDataCopyWith<$Res> {
  factory $CumulativeQuantityDataCopyWith(CumulativeQuantityData value,
          $Res Function(CumulativeQuantityData) _then) =
      _$CumulativeQuantityDataCopyWithImpl;
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
class _$CumulativeQuantityDataCopyWithImpl<$Res>
    implements $CumulativeQuantityDataCopyWith<$Res> {
  _$CumulativeQuantityDataCopyWithImpl(this._self, this._then);

  final CumulativeQuantityData _self;
  final $Res Function(CumulativeQuantityData) _then;

  /// Create a copy of QuantitativeData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? value = null,
    Object? dataType = null,
    Object? unit = null,
    Object? deviceType = freezed,
    Object? platformType = freezed,
  }) {
    return _then(CumulativeQuantityData(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataType: null == dataType
          ? _self.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      deviceType: freezed == deviceType
          ? _self.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      platformType: freezed == platformType
          ? _self.platformType
          : platformType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class DiscreteQuantityData implements QuantitativeData {
  const DiscreteQuantityData(
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
  factory DiscreteQuantityData.fromJson(Map<String, dynamic> json) =>
      _$DiscreteQuantityDataFromJson(json);

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
  final String? sourceName;
  final String? sourceId;
  final String? deviceId;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of QuantitativeData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DiscreteQuantityDataCopyWith<DiscreteQuantityData> get copyWith =>
      _$DiscreteQuantityDataCopyWithImpl<DiscreteQuantityData>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DiscreteQuantityDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DiscreteQuantityData &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, dateFrom, dateTo, value,
      dataType, unit, deviceType, platformType, sourceName, sourceId, deviceId);

  @override
  String toString() {
    return 'QuantitativeData.discreteQuantityData(dateFrom: $dateFrom, dateTo: $dateTo, value: $value, dataType: $dataType, unit: $unit, deviceType: $deviceType, platformType: $platformType, sourceName: $sourceName, sourceId: $sourceId, deviceId: $deviceId)';
  }
}

/// @nodoc
abstract mixin class $DiscreteQuantityDataCopyWith<$Res>
    implements $QuantitativeDataCopyWith<$Res> {
  factory $DiscreteQuantityDataCopyWith(DiscreteQuantityData value,
          $Res Function(DiscreteQuantityData) _then) =
      _$DiscreteQuantityDataCopyWithImpl;
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
class _$DiscreteQuantityDataCopyWithImpl<$Res>
    implements $DiscreteQuantityDataCopyWith<$Res> {
  _$DiscreteQuantityDataCopyWithImpl(this._self, this._then);

  final DiscreteQuantityData _self;
  final $Res Function(DiscreteQuantityData) _then;

  /// Create a copy of QuantitativeData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(DiscreteQuantityData(
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as num,
      dataType: null == dataType
          ? _self.dataType
          : dataType // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      deviceType: freezed == deviceType
          ? _self.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      platformType: freezed == platformType
          ? _self.platformType
          : platformType // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceName: freezed == sourceName
          ? _self.sourceName
          : sourceName // ignore: cast_nullable_to_non_nullable
              as String?,
      sourceId: freezed == sourceId
          ? _self.sourceId
          : sourceId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceId: freezed == deviceId
          ? _self.deviceId
          : deviceId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
