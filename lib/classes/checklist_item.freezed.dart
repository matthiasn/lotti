// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChecklistItemData _$ChecklistItemDataFromJson(Map<String, dynamic> json) {
  return _ChecklistItemData.fromJson(json);
}

/// @nodoc
mixin _$ChecklistItemData {
  String get title => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChecklistItemDataCopyWith<ChecklistItemData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistItemDataCopyWith<$Res> {
  factory $ChecklistItemDataCopyWith(
          ChecklistItemData value, $Res Function(ChecklistItemData) then) =
      _$ChecklistItemDataCopyWithImpl<$Res, ChecklistItemData>;
  @useResult
  $Res call({String title});
}

/// @nodoc
class _$ChecklistItemDataCopyWithImpl<$Res, $Val extends ChecklistItemData>
    implements $ChecklistItemDataCopyWith<$Res> {
  _$ChecklistItemDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChecklistItemDataImplCopyWith<$Res>
    implements $ChecklistItemDataCopyWith<$Res> {
  factory _$$ChecklistItemDataImplCopyWith(_$ChecklistItemDataImpl value,
          $Res Function(_$ChecklistItemDataImpl) then) =
      __$$ChecklistItemDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title});
}

/// @nodoc
class __$$ChecklistItemDataImplCopyWithImpl<$Res>
    extends _$ChecklistItemDataCopyWithImpl<$Res, _$ChecklistItemDataImpl>
    implements _$$ChecklistItemDataImplCopyWith<$Res> {
  __$$ChecklistItemDataImplCopyWithImpl(_$ChecklistItemDataImpl _value,
      $Res Function(_$ChecklistItemDataImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
  }) {
    return _then(_$ChecklistItemDataImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistItemDataImpl implements _ChecklistItemData {
  const _$ChecklistItemDataImpl({required this.title});

  factory _$ChecklistItemDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistItemDataImplFromJson(json);

  @override
  final String title;

  @override
  String toString() {
    return 'ChecklistItemData(title: $title)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistItemDataImpl &&
            (identical(other.title, title) || other.title == title));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, title);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistItemDataImplCopyWith<_$ChecklistItemDataImpl> get copyWith =>
      __$$ChecklistItemDataImplCopyWithImpl<_$ChecklistItemDataImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistItemDataImplToJson(
      this,
    );
  }
}

abstract class _ChecklistItemData implements ChecklistItemData {
  const factory _ChecklistItemData({required final String title}) =
      _$ChecklistItemDataImpl;

  factory _ChecklistItemData.fromJson(Map<String, dynamic> json) =
      _$ChecklistItemDataImpl.fromJson;

  @override
  String get title;
  @override
  @JsonKey(ignore: true)
  _$$ChecklistItemDataImplCopyWith<_$ChecklistItemDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
