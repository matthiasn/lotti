// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CategorySettingsState {
  CategoryDefinition get categoryDefinition =>
      throw _privateConstructorUsedError;
  bool get dirty => throw _privateConstructorUsedError;
  bool get valid => throw _privateConstructorUsedError;
  GlobalKey<FormBuilderState> get formKey => throw _privateConstructorUsedError;

  /// Create a copy of CategorySettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategorySettingsStateCopyWith<CategorySettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategorySettingsStateCopyWith<$Res> {
  factory $CategorySettingsStateCopyWith(CategorySettingsState value,
          $Res Function(CategorySettingsState) then) =
      _$CategorySettingsStateCopyWithImpl<$Res, CategorySettingsState>;
  @useResult
  $Res call(
      {CategoryDefinition categoryDefinition,
      bool dirty,
      bool valid,
      GlobalKey<FormBuilderState> formKey});
}

/// @nodoc
class _$CategorySettingsStateCopyWithImpl<$Res,
        $Val extends CategorySettingsState>
    implements $CategorySettingsStateCopyWith<$Res> {
  _$CategorySettingsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategorySettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryDefinition = freezed,
    Object? dirty = null,
    Object? valid = null,
    Object? formKey = null,
  }) {
    return _then(_value.copyWith(
      categoryDefinition: freezed == categoryDefinition
          ? _value.categoryDefinition
          : categoryDefinition // ignore: cast_nullable_to_non_nullable
              as CategoryDefinition,
      dirty: null == dirty
          ? _value.dirty
          : dirty // ignore: cast_nullable_to_non_nullable
              as bool,
      valid: null == valid
          ? _value.valid
          : valid // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: null == formKey
          ? _value.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CategorySettingsStateImplCopyWith<$Res>
    implements $CategorySettingsStateCopyWith<$Res> {
  factory _$$CategorySettingsStateImplCopyWith(
          _$CategorySettingsStateImpl value,
          $Res Function(_$CategorySettingsStateImpl) then) =
      __$$CategorySettingsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {CategoryDefinition categoryDefinition,
      bool dirty,
      bool valid,
      GlobalKey<FormBuilderState> formKey});
}

/// @nodoc
class __$$CategorySettingsStateImplCopyWithImpl<$Res>
    extends _$CategorySettingsStateCopyWithImpl<$Res,
        _$CategorySettingsStateImpl>
    implements _$$CategorySettingsStateImplCopyWith<$Res> {
  __$$CategorySettingsStateImplCopyWithImpl(_$CategorySettingsStateImpl _value,
      $Res Function(_$CategorySettingsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of CategorySettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryDefinition = freezed,
    Object? dirty = null,
    Object? valid = null,
    Object? formKey = null,
  }) {
    return _then(_$CategorySettingsStateImpl(
      categoryDefinition: freezed == categoryDefinition
          ? _value.categoryDefinition
          : categoryDefinition // ignore: cast_nullable_to_non_nullable
              as CategoryDefinition,
      dirty: null == dirty
          ? _value.dirty
          : dirty // ignore: cast_nullable_to_non_nullable
              as bool,
      valid: null == valid
          ? _value.valid
          : valid // ignore: cast_nullable_to_non_nullable
              as bool,
      formKey: null == formKey
          ? _value.formKey
          : formKey // ignore: cast_nullable_to_non_nullable
              as GlobalKey<FormBuilderState>,
    ));
  }
}

/// @nodoc

class _$CategorySettingsStateImpl implements _CategorySettingsState {
  _$CategorySettingsStateImpl(
      {required this.categoryDefinition,
      required this.dirty,
      required this.valid,
      required this.formKey});

  @override
  final CategoryDefinition categoryDefinition;
  @override
  final bool dirty;
  @override
  final bool valid;
  @override
  final GlobalKey<FormBuilderState> formKey;

  @override
  String toString() {
    return 'CategorySettingsState(categoryDefinition: $categoryDefinition, dirty: $dirty, valid: $valid, formKey: $formKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategorySettingsStateImpl &&
            const DeepCollectionEquality()
                .equals(other.categoryDefinition, categoryDefinition) &&
            (identical(other.dirty, dirty) || other.dirty == dirty) &&
            (identical(other.valid, valid) || other.valid == valid) &&
            (identical(other.formKey, formKey) || other.formKey == formKey));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(categoryDefinition),
      dirty,
      valid,
      formKey);

  /// Create a copy of CategorySettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategorySettingsStateImplCopyWith<_$CategorySettingsStateImpl>
      get copyWith => __$$CategorySettingsStateImplCopyWithImpl<
          _$CategorySettingsStateImpl>(this, _$identity);
}

abstract class _CategorySettingsState implements CategorySettingsState {
  factory _CategorySettingsState(
          {required final CategoryDefinition categoryDefinition,
          required final bool dirty,
          required final bool valid,
          required final GlobalKey<FormBuilderState> formKey}) =
      _$CategorySettingsStateImpl;

  @override
  CategoryDefinition get categoryDefinition;
  @override
  bool get dirty;
  @override
  bool get valid;
  @override
  GlobalKey<FormBuilderState> get formKey;

  /// Create a copy of CategorySettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategorySettingsStateImplCopyWith<_$CategorySettingsStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
