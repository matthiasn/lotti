// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_list_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CheckListItem _$CheckListItemFromJson(Map<String, dynamic> json) {
  return _CheckListItem.fromJson(json);
}

/// @nodoc
mixin _$CheckListItem {
  String get id => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  int get utcOffset => throw _privateConstructorUsedError;
  String get plainText => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError;
  Geolocation? get geolocation => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CheckListItemCopyWith<CheckListItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckListItemCopyWith<$Res> {
  factory $CheckListItemCopyWith(
          CheckListItem value, $Res Function(CheckListItem) then) =
      _$CheckListItemCopyWithImpl<$Res, CheckListItem>;
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String plainText,
      String? timezone,
      Geolocation? geolocation,
      DateTime? updatedAt});

  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class _$CheckListItemCopyWithImpl<$Res, $Val extends CheckListItem>
    implements $CheckListItemCopyWith<$Res> {
  _$CheckListItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? plainText = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      plainText: null == plainText
          ? _value.plainText
          : plainText // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_value.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_value.geolocation!, (value) {
      return _then(_value.copyWith(geolocation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CheckListItemImplCopyWith<$Res>
    implements $CheckListItemCopyWith<$Res> {
  factory _$$CheckListItemImplCopyWith(
          _$CheckListItemImpl value, $Res Function(_$CheckListItemImpl) then) =
      __$$CheckListItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String plainText,
      String? timezone,
      Geolocation? geolocation,
      DateTime? updatedAt});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$CheckListItemImplCopyWithImpl<$Res>
    extends _$CheckListItemCopyWithImpl<$Res, _$CheckListItemImpl>
    implements _$$CheckListItemImplCopyWith<$Res> {
  __$$CheckListItemImplCopyWithImpl(
      _$CheckListItemImpl _value, $Res Function(_$CheckListItemImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? plainText = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$CheckListItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      plainText: null == plainText
          ? _value.plainText
          : plainText // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CheckListItemImpl implements _CheckListItem {
  const _$CheckListItemImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.plainText,
      this.timezone,
      this.geolocation,
      this.updatedAt});

  factory _$CheckListItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckListItemImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String plainText;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'CheckListItem(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, plainText: $plainText, timezone: $timezone, geolocation: $geolocation, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckListItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.plainText, plainText) ||
                other.plainText == plainText) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, createdAt, utcOffset,
      plainText, timezone, geolocation, updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckListItemImplCopyWith<_$CheckListItemImpl> get copyWith =>
      __$$CheckListItemImplCopyWithImpl<_$CheckListItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckListItemImplToJson(
      this,
    );
  }
}

abstract class _CheckListItem implements CheckListItem {
  const factory _CheckListItem(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      required final String plainText,
      final String? timezone,
      final Geolocation? geolocation,
      final DateTime? updatedAt}) = _$CheckListItemImpl;

  factory _CheckListItem.fromJson(Map<String, dynamic> json) =
      _$CheckListItemImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  @override
  String get plainText;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$CheckListItemImplCopyWith<_$CheckListItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
