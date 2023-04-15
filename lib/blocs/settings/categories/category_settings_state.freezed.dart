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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$CategorySettingsState {
  CategoryDefinition get categoryDefinition =>
      throw _privateConstructorUsedError;
  bool get dirty => throw _privateConstructorUsedError;
  bool get valid => throw _privateConstructorUsedError;
  GlobalKey<FormBuilderState> get formKey => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
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

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryDefinition = null,
    Object? dirty = null,
    Object? valid = null,
    Object? formKey = null,
  }) {
    return _then(_value.copyWith(
      categoryDefinition: null == categoryDefinition
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
abstract class _$$_CategorySettingsStateCopyWith<$Res>
    implements $CategorySettingsStateCopyWith<$Res> {
  factory _$$_CategorySettingsStateCopyWith(_$_CategorySettingsState value,
          $Res Function(_$_CategorySettingsState) then) =
      __$$_CategorySettingsStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {CategoryDefinition categoryDefinition,
      bool dirty,
      bool valid,
      GlobalKey<FormBuilderState> formKey});
}

/// @nodoc
class __$$_CategorySettingsStateCopyWithImpl<$Res>
    extends _$CategorySettingsStateCopyWithImpl<$Res, _$_CategorySettingsState>
    implements _$$_CategorySettingsStateCopyWith<$Res> {
  __$$_CategorySettingsStateCopyWithImpl(_$_CategorySettingsState _value,
      $Res Function(_$_CategorySettingsState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categoryDefinition = null,
    Object? dirty = null,
    Object? valid = null,
    Object? formKey = null,
  }) {
    return _then(_$_CategorySettingsState(
      categoryDefinition: null == categoryDefinition
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

class _$_CategorySettingsState implements _CategorySettingsState {
  _$_CategorySettingsState(
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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_CategorySettingsState &&
            (identical(other.categoryDefinition, categoryDefinition) ||
                other.categoryDefinition == categoryDefinition) &&
            (identical(other.dirty, dirty) || other.dirty == dirty) &&
            (identical(other.valid, valid) || other.valid == valid) &&
            (identical(other.formKey, formKey) || other.formKey == formKey));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, categoryDefinition, dirty, valid, formKey);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_CategorySettingsStateCopyWith<_$_CategorySettingsState> get copyWith =>
      __$$_CategorySettingsStateCopyWithImpl<_$_CategorySettingsState>(
          this, _$identity);
}

abstract class _CategorySettingsState implements CategorySettingsState {
  factory _CategorySettingsState(
          {required final CategoryDefinition categoryDefinition,
          required final bool dirty,
          required final bool valid,
          required final GlobalKey<FormBuilderState> formKey}) =
      _$_CategorySettingsState;

  @override
  CategoryDefinition get categoryDefinition;
  @override
  bool get dirty;
  @override
  bool get valid;
  @override
  GlobalKey<FormBuilderState> get formKey;
  @override
  @JsonKey(ignore: true)
  _$$_CategorySettingsStateCopyWith<_$_CategorySettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}
