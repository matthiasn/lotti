// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_details_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CategoryDetailsState {
  CategoryDefinition? get category => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isSaving => throw _privateConstructorUsedError;
  bool get hasChanges => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategoryDetailsStateCopyWith<CategoryDetailsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategoryDetailsStateCopyWith<$Res> {
  factory $CategoryDetailsStateCopyWith(CategoryDetailsState value,
          $Res Function(CategoryDetailsState) then) =
      _$CategoryDetailsStateCopyWithImpl<$Res, CategoryDetailsState>;
  @useResult
  $Res call(
      {CategoryDefinition? category,
      bool isLoading,
      bool isSaving,
      bool hasChanges,
      String? errorMessage});
}

/// @nodoc
class _$CategoryDetailsStateCopyWithImpl<$Res,
        $Val extends CategoryDetailsState>
    implements $CategoryDetailsStateCopyWith<$Res> {
  _$CategoryDetailsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = freezed,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? hasChanges = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryDefinition?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isSaving: null == isSaving
          ? _value.isSaving
          : isSaving // ignore: cast_nullable_to_non_nullable
              as bool,
      hasChanges: null == hasChanges
          ? _value.hasChanges
          : hasChanges // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CategoryDetailsStateImplCopyWith<$Res>
    implements $CategoryDetailsStateCopyWith<$Res> {
  factory _$$CategoryDetailsStateImplCopyWith(_$CategoryDetailsStateImpl value,
          $Res Function(_$CategoryDetailsStateImpl) then) =
      __$$CategoryDetailsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {CategoryDefinition? category,
      bool isLoading,
      bool isSaving,
      bool hasChanges,
      String? errorMessage});
}

/// @nodoc
class __$$CategoryDetailsStateImplCopyWithImpl<$Res>
    extends _$CategoryDetailsStateCopyWithImpl<$Res, _$CategoryDetailsStateImpl>
    implements _$$CategoryDetailsStateImplCopyWith<$Res> {
  __$$CategoryDetailsStateImplCopyWithImpl(_$CategoryDetailsStateImpl _value,
      $Res Function(_$CategoryDetailsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = freezed,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? hasChanges = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$CategoryDetailsStateImpl(
      category: freezed == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryDefinition?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isSaving: null == isSaving
          ? _value.isSaving
          : isSaving // ignore: cast_nullable_to_non_nullable
              as bool,
      hasChanges: null == hasChanges
          ? _value.hasChanges
          : hasChanges // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$CategoryDetailsStateImpl implements _CategoryDetailsState {
  const _$CategoryDetailsStateImpl(
      {required this.category,
      required this.isLoading,
      required this.isSaving,
      required this.hasChanges,
      this.errorMessage});

  @override
  final CategoryDefinition? category;
  @override
  final bool isLoading;
  @override
  final bool isSaving;
  @override
  final bool hasChanges;
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'CategoryDetailsState(category: $category, isLoading: $isLoading, isSaving: $isSaving, hasChanges: $hasChanges, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryDetailsStateImpl &&
            const DeepCollectionEquality().equals(other.category, category) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isSaving, isSaving) ||
                other.isSaving == isSaving) &&
            (identical(other.hasChanges, hasChanges) ||
                other.hasChanges == hasChanges) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(category),
      isLoading,
      isSaving,
      hasChanges,
      errorMessage);

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryDetailsStateImplCopyWith<_$CategoryDetailsStateImpl>
      get copyWith =>
          __$$CategoryDetailsStateImplCopyWithImpl<_$CategoryDetailsStateImpl>(
              this, _$identity);
}

abstract class _CategoryDetailsState implements CategoryDetailsState {
  const factory _CategoryDetailsState(
      {required final CategoryDefinition? category,
      required final bool isLoading,
      required final bool isSaving,
      required final bool hasChanges,
      final String? errorMessage}) = _$CategoryDetailsStateImpl;

  @override
  CategoryDefinition? get category;
  @override
  bool get isLoading;
  @override
  bool get isSaving;
  @override
  bool get hasChanges;
  @override
  String? get errorMessage;

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryDetailsStateImplCopyWith<_$CategoryDetailsStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
