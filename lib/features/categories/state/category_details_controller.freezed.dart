// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_details_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CategoryDetailsState {
  CategoryDefinition? get category;
  bool get isLoading;
  bool get isSaving;
  bool get hasChanges;
  String? get errorMessage;

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CategoryDetailsStateCopyWith<CategoryDetailsState> get copyWith =>
      _$CategoryDetailsStateCopyWithImpl<CategoryDetailsState>(
          this as CategoryDetailsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CategoryDetailsState &&
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

  @override
  String toString() {
    return 'CategoryDetailsState(category: $category, isLoading: $isLoading, isSaving: $isSaving, hasChanges: $hasChanges, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class $CategoryDetailsStateCopyWith<$Res> {
  factory $CategoryDetailsStateCopyWith(CategoryDetailsState value,
          $Res Function(CategoryDetailsState) _then) =
      _$CategoryDetailsStateCopyWithImpl;
  @useResult
  $Res call(
      {CategoryDefinition? category,
      bool isLoading,
      bool isSaving,
      bool hasChanges,
      String? errorMessage});
}

/// @nodoc
class _$CategoryDetailsStateCopyWithImpl<$Res>
    implements $CategoryDetailsStateCopyWith<$Res> {
  _$CategoryDetailsStateCopyWithImpl(this._self, this._then);

  final CategoryDetailsState _self;
  final $Res Function(CategoryDetailsState) _then;

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
    return _then(_self.copyWith(
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryDefinition?,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isSaving: null == isSaving
          ? _self.isSaving
          : isSaving // ignore: cast_nullable_to_non_nullable
              as bool,
      hasChanges: null == hasChanges
          ? _self.hasChanges
          : hasChanges // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CategoryDetailsState].
extension CategoryDetailsStatePatterns on CategoryDetailsState {
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
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_CategoryDetailsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CategoryDetailsState() when $default != null:
        return $default(_that);
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
  TResult map<TResult extends Object?>(
    TResult Function(_CategoryDetailsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryDetailsState():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_CategoryDetailsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryDetailsState() when $default != null:
        return $default(_that);
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
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(CategoryDefinition? category, bool isLoading,
            bool isSaving, bool hasChanges, String? errorMessage)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CategoryDetailsState() when $default != null:
        return $default(_that.category, _that.isLoading, _that.isSaving,
            _that.hasChanges, _that.errorMessage);
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
  TResult when<TResult extends Object?>(
    TResult Function(CategoryDefinition? category, bool isLoading,
            bool isSaving, bool hasChanges, String? errorMessage)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryDetailsState():
        return $default(_that.category, _that.isLoading, _that.isSaving,
            _that.hasChanges, _that.errorMessage);
      case _:
        throw StateError('Unexpected subclass');
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
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(CategoryDefinition? category, bool isLoading,
            bool isSaving, bool hasChanges, String? errorMessage)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryDetailsState() when $default != null:
        return $default(_that.category, _that.isLoading, _that.isSaving,
            _that.hasChanges, _that.errorMessage);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CategoryDetailsState implements CategoryDetailsState {
  const _CategoryDetailsState(
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

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CategoryDetailsStateCopyWith<_CategoryDetailsState> get copyWith =>
      __$CategoryDetailsStateCopyWithImpl<_CategoryDetailsState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CategoryDetailsState &&
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

  @override
  String toString() {
    return 'CategoryDetailsState(category: $category, isLoading: $isLoading, isSaving: $isSaving, hasChanges: $hasChanges, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class _$CategoryDetailsStateCopyWith<$Res>
    implements $CategoryDetailsStateCopyWith<$Res> {
  factory _$CategoryDetailsStateCopyWith(_CategoryDetailsState value,
          $Res Function(_CategoryDetailsState) _then) =
      __$CategoryDetailsStateCopyWithImpl;
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
class __$CategoryDetailsStateCopyWithImpl<$Res>
    implements _$CategoryDetailsStateCopyWith<$Res> {
  __$CategoryDetailsStateCopyWithImpl(this._self, this._then);

  final _CategoryDetailsState _self;
  final $Res Function(_CategoryDetailsState) _then;

  /// Create a copy of CategoryDetailsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? category = freezed,
    Object? isLoading = null,
    Object? isSaving = null,
    Object? hasChanges = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_CategoryDetailsState(
      category: freezed == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryDefinition?,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isSaving: null == isSaving
          ? _self.isSaving
          : isSaving // ignore: cast_nullable_to_non_nullable
              as bool,
      hasChanges: null == hasChanges
          ? _self.hasChanges
          : hasChanges // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
