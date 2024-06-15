// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ChecklistData _$ChecklistDataFromJson(Map<String, dynamic> json) {
  return _ChecklistData.fromJson(json);
}

/// @nodoc
mixin _$ChecklistData {
  String get title => throw _privateConstructorUsedError;
  bool get isChecked => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ChecklistDataCopyWith<ChecklistData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistDataCopyWith<$Res> {
  factory $ChecklistDataCopyWith(
          ChecklistData value, $Res Function(ChecklistData) then) =
      _$ChecklistDataCopyWithImpl<$Res, ChecklistData>;
  @useResult
  $Res call({String title, bool isChecked});
}

/// @nodoc
class _$ChecklistDataCopyWithImpl<$Res, $Val extends ChecklistData>
    implements $ChecklistDataCopyWith<$Res> {
  _$ChecklistDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? isChecked = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      isChecked: null == isChecked
          ? _value.isChecked
          : isChecked // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChecklistDataImplCopyWith<$Res>
    implements $ChecklistDataCopyWith<$Res> {
  factory _$$ChecklistDataImplCopyWith(
          _$ChecklistDataImpl value, $Res Function(_$ChecklistDataImpl) then) =
      __$$ChecklistDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, bool isChecked});
}

/// @nodoc
class __$$ChecklistDataImplCopyWithImpl<$Res>
    extends _$ChecklistDataCopyWithImpl<$Res, _$ChecklistDataImpl>
    implements _$$ChecklistDataImplCopyWith<$Res> {
  __$$ChecklistDataImplCopyWithImpl(
      _$ChecklistDataImpl _value, $Res Function(_$ChecklistDataImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? isChecked = null,
  }) {
    return _then(_$ChecklistDataImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      isChecked: null == isChecked
          ? _value.isChecked
          : isChecked // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistDataImpl implements _ChecklistData {
  const _$ChecklistDataImpl({required this.title, required this.isChecked});

  factory _$ChecklistDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistDataImplFromJson(json);

  @override
  final String title;
  @override
  final bool isChecked;

  @override
  String toString() {
    return 'ChecklistData(title: $title, isChecked: $isChecked)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistDataImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isChecked, isChecked) ||
                other.isChecked == isChecked));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, title, isChecked);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistDataImplCopyWith<_$ChecklistDataImpl> get copyWith =>
      __$$ChecklistDataImplCopyWithImpl<_$ChecklistDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistDataImplToJson(
      this,
    );
  }
}

abstract class _ChecklistData implements ChecklistData {
  const factory _ChecklistData(
      {required final String title,
      required final bool isChecked}) = _$ChecklistDataImpl;

  factory _ChecklistData.fromJson(Map<String, dynamic> json) =
      _$ChecklistDataImpl.fromJson;

  @override
  String get title;
  @override
  bool get isChecked;
  @override
  @JsonKey(ignore: true)
  _$$ChecklistDataImplCopyWith<_$ChecklistDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
