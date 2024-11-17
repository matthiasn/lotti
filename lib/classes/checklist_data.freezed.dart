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
  List<String> get linkedChecklistItems => throw _privateConstructorUsedError;

  /// Serializes this ChecklistData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistDataCopyWith<ChecklistData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistDataCopyWith<$Res> {
  factory $ChecklistDataCopyWith(
          ChecklistData value, $Res Function(ChecklistData) then) =
      _$ChecklistDataCopyWithImpl<$Res, ChecklistData>;
  @useResult
  $Res call({String title, List<String> linkedChecklistItems});
}

/// @nodoc
class _$ChecklistDataCopyWithImpl<$Res, $Val extends ChecklistData>
    implements $ChecklistDataCopyWith<$Res> {
  _$ChecklistDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? linkedChecklistItems = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      linkedChecklistItems: null == linkedChecklistItems
          ? _value.linkedChecklistItems
          : linkedChecklistItems // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
  $Res call({String title, List<String> linkedChecklistItems});
}

/// @nodoc
class __$$ChecklistDataImplCopyWithImpl<$Res>
    extends _$ChecklistDataCopyWithImpl<$Res, _$ChecklistDataImpl>
    implements _$$ChecklistDataImplCopyWith<$Res> {
  __$$ChecklistDataImplCopyWithImpl(
      _$ChecklistDataImpl _value, $Res Function(_$ChecklistDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? linkedChecklistItems = null,
  }) {
    return _then(_$ChecklistDataImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      linkedChecklistItems: null == linkedChecklistItems
          ? _value._linkedChecklistItems
          : linkedChecklistItems // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistDataImpl implements _ChecklistData {
  const _$ChecklistDataImpl(
      {required this.title, required final List<String> linkedChecklistItems})
      : _linkedChecklistItems = linkedChecklistItems;

  factory _$ChecklistDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistDataImplFromJson(json);

  @override
  final String title;
  final List<String> _linkedChecklistItems;
  @override
  List<String> get linkedChecklistItems {
    if (_linkedChecklistItems is EqualUnmodifiableListView)
      return _linkedChecklistItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_linkedChecklistItems);
  }

  @override
  String toString() {
    return 'ChecklistData(title: $title, linkedChecklistItems: $linkedChecklistItems)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistDataImpl &&
            (identical(other.title, title) || other.title == title) &&
            const DeepCollectionEquality()
                .equals(other._linkedChecklistItems, _linkedChecklistItems));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title,
      const DeepCollectionEquality().hash(_linkedChecklistItems));

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      required final List<String> linkedChecklistItems}) = _$ChecklistDataImpl;

  factory _ChecklistData.fromJson(Map<String, dynamic> json) =
      _$ChecklistDataImpl.fromJson;

  @override
  String get title;
  @override
  List<String> get linkedChecklistItems;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistDataImplCopyWith<_$ChecklistDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
