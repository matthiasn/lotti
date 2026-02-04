// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reference_image_selection_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReferenceImageSelectionState {
  List<JournalImage> get availableImages;
  Set<String> get selectedImageIds;
  bool get isLoading;
  bool get isProcessing;
  String? get errorMessage;

  /// Create a copy of ReferenceImageSelectionState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReferenceImageSelectionStateCopyWith<ReferenceImageSelectionState>
      get copyWith => _$ReferenceImageSelectionStateCopyWithImpl<
              ReferenceImageSelectionState>(
          this as ReferenceImageSelectionState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReferenceImageSelectionState &&
            const DeepCollectionEquality()
                .equals(other.availableImages, availableImages) &&
            const DeepCollectionEquality()
                .equals(other.selectedImageIds, selectedImageIds) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isProcessing, isProcessing) ||
                other.isProcessing == isProcessing) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(availableImages),
      const DeepCollectionEquality().hash(selectedImageIds),
      isLoading,
      isProcessing,
      errorMessage);

  @override
  String toString() {
    return 'ReferenceImageSelectionState(availableImages: $availableImages, selectedImageIds: $selectedImageIds, isLoading: $isLoading, isProcessing: $isProcessing, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class $ReferenceImageSelectionStateCopyWith<$Res> {
  factory $ReferenceImageSelectionStateCopyWith(
          ReferenceImageSelectionState value,
          $Res Function(ReferenceImageSelectionState) _then) =
      _$ReferenceImageSelectionStateCopyWithImpl;
  @useResult
  $Res call(
      {List<JournalImage> availableImages,
      Set<String> selectedImageIds,
      bool isLoading,
      bool isProcessing,
      String? errorMessage});
}

/// @nodoc
class _$ReferenceImageSelectionStateCopyWithImpl<$Res>
    implements $ReferenceImageSelectionStateCopyWith<$Res> {
  _$ReferenceImageSelectionStateCopyWithImpl(this._self, this._then);

  final ReferenceImageSelectionState _self;
  final $Res Function(ReferenceImageSelectionState) _then;

  /// Create a copy of ReferenceImageSelectionState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? availableImages = null,
    Object? selectedImageIds = null,
    Object? isLoading = null,
    Object? isProcessing = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_self.copyWith(
      availableImages: null == availableImages
          ? _self.availableImages
          : availableImages // ignore: cast_nullable_to_non_nullable
              as List<JournalImage>,
      selectedImageIds: null == selectedImageIds
          ? _self.selectedImageIds
          : selectedImageIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isProcessing: null == isProcessing
          ? _self.isProcessing
          : isProcessing // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ReferenceImageSelectionState].
extension ReferenceImageSelectionStatePatterns on ReferenceImageSelectionState {
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
    TResult Function(_ReferenceImageSelectionState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReferenceImageSelectionState() when $default != null:
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
    TResult Function(_ReferenceImageSelectionState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReferenceImageSelectionState():
        return $default(_that);
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
    TResult? Function(_ReferenceImageSelectionState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReferenceImageSelectionState() when $default != null:
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
    TResult Function(
            List<JournalImage> availableImages,
            Set<String> selectedImageIds,
            bool isLoading,
            bool isProcessing,
            String? errorMessage)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReferenceImageSelectionState() when $default != null:
        return $default(_that.availableImages, _that.selectedImageIds,
            _that.isLoading, _that.isProcessing, _that.errorMessage);
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
    TResult Function(
            List<JournalImage> availableImages,
            Set<String> selectedImageIds,
            bool isLoading,
            bool isProcessing,
            String? errorMessage)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReferenceImageSelectionState():
        return $default(_that.availableImages, _that.selectedImageIds,
            _that.isLoading, _that.isProcessing, _that.errorMessage);
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
    TResult? Function(
            List<JournalImage> availableImages,
            Set<String> selectedImageIds,
            bool isLoading,
            bool isProcessing,
            String? errorMessage)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReferenceImageSelectionState() when $default != null:
        return $default(_that.availableImages, _that.selectedImageIds,
            _that.isLoading, _that.isProcessing, _that.errorMessage);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ReferenceImageSelectionState implements ReferenceImageSelectionState {
  const _ReferenceImageSelectionState(
      {final List<JournalImage> availableImages = const [],
      final Set<String> selectedImageIds = const {},
      this.isLoading = false,
      this.isProcessing = false,
      this.errorMessage})
      : _availableImages = availableImages,
        _selectedImageIds = selectedImageIds;

  final List<JournalImage> _availableImages;
  @override
  @JsonKey()
  List<JournalImage> get availableImages {
    if (_availableImages is EqualUnmodifiableListView) return _availableImages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableImages);
  }

  final Set<String> _selectedImageIds;
  @override
  @JsonKey()
  Set<String> get selectedImageIds {
    if (_selectedImageIds is EqualUnmodifiableSetView) return _selectedImageIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedImageIds);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isProcessing;
  @override
  final String? errorMessage;

  /// Create a copy of ReferenceImageSelectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReferenceImageSelectionStateCopyWith<_ReferenceImageSelectionState>
      get copyWith => __$ReferenceImageSelectionStateCopyWithImpl<
          _ReferenceImageSelectionState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReferenceImageSelectionState &&
            const DeepCollectionEquality()
                .equals(other._availableImages, _availableImages) &&
            const DeepCollectionEquality()
                .equals(other._selectedImageIds, _selectedImageIds) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isProcessing, isProcessing) ||
                other.isProcessing == isProcessing) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_availableImages),
      const DeepCollectionEquality().hash(_selectedImageIds),
      isLoading,
      isProcessing,
      errorMessage);

  @override
  String toString() {
    return 'ReferenceImageSelectionState(availableImages: $availableImages, selectedImageIds: $selectedImageIds, isLoading: $isLoading, isProcessing: $isProcessing, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class _$ReferenceImageSelectionStateCopyWith<$Res>
    implements $ReferenceImageSelectionStateCopyWith<$Res> {
  factory _$ReferenceImageSelectionStateCopyWith(
          _ReferenceImageSelectionState value,
          $Res Function(_ReferenceImageSelectionState) _then) =
      __$ReferenceImageSelectionStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<JournalImage> availableImages,
      Set<String> selectedImageIds,
      bool isLoading,
      bool isProcessing,
      String? errorMessage});
}

/// @nodoc
class __$ReferenceImageSelectionStateCopyWithImpl<$Res>
    implements _$ReferenceImageSelectionStateCopyWith<$Res> {
  __$ReferenceImageSelectionStateCopyWithImpl(this._self, this._then);

  final _ReferenceImageSelectionState _self;
  final $Res Function(_ReferenceImageSelectionState) _then;

  /// Create a copy of ReferenceImageSelectionState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? availableImages = null,
    Object? selectedImageIds = null,
    Object? isLoading = null,
    Object? isProcessing = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_ReferenceImageSelectionState(
      availableImages: null == availableImages
          ? _self._availableImages
          : availableImages // ignore: cast_nullable_to_non_nullable
              as List<JournalImage>,
      selectedImageIds: null == selectedImageIds
          ? _self._selectedImageIds
          : selectedImageIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isProcessing: null == isProcessing
          ? _self.isProcessing
          : isProcessing // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
