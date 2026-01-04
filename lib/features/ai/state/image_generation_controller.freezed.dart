// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image_generation_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ImageGenerationState implements DiagnosticableTreeMixin {
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties..add(DiagnosticsProperty('type', 'ImageGenerationState'));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is ImageGenerationState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ImageGenerationState()';
  }
}

/// @nodoc
class $ImageGenerationStateCopyWith<$Res> {
  $ImageGenerationStateCopyWith(
      ImageGenerationState _, $Res Function(ImageGenerationState) __);
}

/// Adds pattern-matching-related methods to [ImageGenerationState].
extension ImageGenerationStatePatterns on ImageGenerationState {
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
    TResult Function(ImageGenerationInitial value)? initial,
    TResult Function(ImageGenerationGenerating value)? generating,
    TResult Function(ImageGenerationSuccess value)? success,
    TResult Function(ImageGenerationError value)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case ImageGenerationInitial() when initial != null:
        return initial(_that);
      case ImageGenerationGenerating() when generating != null:
        return generating(_that);
      case ImageGenerationSuccess() when success != null:
        return success(_that);
      case ImageGenerationError() when error != null:
        return error(_that);
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
    required TResult Function(ImageGenerationInitial value) initial,
    required TResult Function(ImageGenerationGenerating value) generating,
    required TResult Function(ImageGenerationSuccess value) success,
    required TResult Function(ImageGenerationError value) error,
  }) {
    final _that = this;
    switch (_that) {
      case ImageGenerationInitial():
        return initial(_that);
      case ImageGenerationGenerating():
        return generating(_that);
      case ImageGenerationSuccess():
        return success(_that);
      case ImageGenerationError():
        return error(_that);
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
    TResult? Function(ImageGenerationInitial value)? initial,
    TResult? Function(ImageGenerationGenerating value)? generating,
    TResult? Function(ImageGenerationSuccess value)? success,
    TResult? Function(ImageGenerationError value)? error,
  }) {
    final _that = this;
    switch (_that) {
      case ImageGenerationInitial() when initial != null:
        return initial(_that);
      case ImageGenerationGenerating() when generating != null:
        return generating(_that);
      case ImageGenerationSuccess() when success != null:
        return success(_that);
      case ImageGenerationError() when error != null:
        return error(_that);
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
    TResult Function()? initial,
    TResult Function(String prompt)? generating,
    TResult Function(String prompt, Uint8List imageBytes, String mimeType)?
        success,
    TResult Function(String prompt, String errorMessage)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case ImageGenerationInitial() when initial != null:
        return initial();
      case ImageGenerationGenerating() when generating != null:
        return generating(_that.prompt);
      case ImageGenerationSuccess() when success != null:
        return success(_that.prompt, _that.imageBytes, _that.mimeType);
      case ImageGenerationError() when error != null:
        return error(_that.prompt, _that.errorMessage);
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
    required TResult Function() initial,
    required TResult Function(String prompt) generating,
    required TResult Function(
            String prompt, Uint8List imageBytes, String mimeType)
        success,
    required TResult Function(String prompt, String errorMessage) error,
  }) {
    final _that = this;
    switch (_that) {
      case ImageGenerationInitial():
        return initial();
      case ImageGenerationGenerating():
        return generating(_that.prompt);
      case ImageGenerationSuccess():
        return success(_that.prompt, _that.imageBytes, _that.mimeType);
      case ImageGenerationError():
        return error(_that.prompt, _that.errorMessage);
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
    TResult? Function()? initial,
    TResult? Function(String prompt)? generating,
    TResult? Function(String prompt, Uint8List imageBytes, String mimeType)?
        success,
    TResult? Function(String prompt, String errorMessage)? error,
  }) {
    final _that = this;
    switch (_that) {
      case ImageGenerationInitial() when initial != null:
        return initial();
      case ImageGenerationGenerating() when generating != null:
        return generating(_that.prompt);
      case ImageGenerationSuccess() when success != null:
        return success(_that.prompt, _that.imageBytes, _that.mimeType);
      case ImageGenerationError() when error != null:
        return error(_that.prompt, _that.errorMessage);
      case _:
        return null;
    }
  }
}

/// @nodoc

class ImageGenerationInitial
    with DiagnosticableTreeMixin
    implements ImageGenerationState {
  const ImageGenerationInitial();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'ImageGenerationState.initial'));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is ImageGenerationInitial);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ImageGenerationState.initial()';
  }
}

/// @nodoc

class ImageGenerationGenerating
    with DiagnosticableTreeMixin
    implements ImageGenerationState {
  const ImageGenerationGenerating({required this.prompt});

  final String prompt;

  /// Create a copy of ImageGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImageGenerationGeneratingCopyWith<ImageGenerationGenerating> get copyWith =>
      _$ImageGenerationGeneratingCopyWithImpl<ImageGenerationGenerating>(
          this, _$identity);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'ImageGenerationState.generating'))
      ..add(DiagnosticsProperty('prompt', prompt));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImageGenerationGenerating &&
            (identical(other.prompt, prompt) || other.prompt == prompt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, prompt);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ImageGenerationState.generating(prompt: $prompt)';
  }
}

/// @nodoc
abstract mixin class $ImageGenerationGeneratingCopyWith<$Res>
    implements $ImageGenerationStateCopyWith<$Res> {
  factory $ImageGenerationGeneratingCopyWith(ImageGenerationGenerating value,
          $Res Function(ImageGenerationGenerating) _then) =
      _$ImageGenerationGeneratingCopyWithImpl;
  @useResult
  $Res call({String prompt});
}

/// @nodoc
class _$ImageGenerationGeneratingCopyWithImpl<$Res>
    implements $ImageGenerationGeneratingCopyWith<$Res> {
  _$ImageGenerationGeneratingCopyWithImpl(this._self, this._then);

  final ImageGenerationGenerating _self;
  final $Res Function(ImageGenerationGenerating) _then;

  /// Create a copy of ImageGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? prompt = null,
  }) {
    return _then(ImageGenerationGenerating(
      prompt: null == prompt
          ? _self.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class ImageGenerationSuccess
    with DiagnosticableTreeMixin
    implements ImageGenerationState {
  const ImageGenerationSuccess(
      {required this.prompt, required this.imageBytes, required this.mimeType});

  final String prompt;
  final Uint8List imageBytes;
  final String mimeType;

  /// Create a copy of ImageGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImageGenerationSuccessCopyWith<ImageGenerationSuccess> get copyWith =>
      _$ImageGenerationSuccessCopyWithImpl<ImageGenerationSuccess>(
          this, _$identity);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'ImageGenerationState.success'))
      ..add(DiagnosticsProperty('prompt', prompt))
      ..add(DiagnosticsProperty('imageBytes', imageBytes))
      ..add(DiagnosticsProperty('mimeType', mimeType));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImageGenerationSuccess &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            const DeepCollectionEquality()
                .equals(other.imageBytes, imageBytes) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType));
  }

  @override
  int get hashCode => Object.hash(runtimeType, prompt,
      const DeepCollectionEquality().hash(imageBytes), mimeType);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ImageGenerationState.success(prompt: $prompt, imageBytes: $imageBytes, mimeType: $mimeType)';
  }
}

/// @nodoc
abstract mixin class $ImageGenerationSuccessCopyWith<$Res>
    implements $ImageGenerationStateCopyWith<$Res> {
  factory $ImageGenerationSuccessCopyWith(ImageGenerationSuccess value,
          $Res Function(ImageGenerationSuccess) _then) =
      _$ImageGenerationSuccessCopyWithImpl;
  @useResult
  $Res call({String prompt, Uint8List imageBytes, String mimeType});
}

/// @nodoc
class _$ImageGenerationSuccessCopyWithImpl<$Res>
    implements $ImageGenerationSuccessCopyWith<$Res> {
  _$ImageGenerationSuccessCopyWithImpl(this._self, this._then);

  final ImageGenerationSuccess _self;
  final $Res Function(ImageGenerationSuccess) _then;

  /// Create a copy of ImageGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? prompt = null,
    Object? imageBytes = null,
    Object? mimeType = null,
  }) {
    return _then(ImageGenerationSuccess(
      prompt: null == prompt
          ? _self.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      imageBytes: null == imageBytes
          ? _self.imageBytes
          : imageBytes // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      mimeType: null == mimeType
          ? _self.mimeType
          : mimeType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class ImageGenerationError
    with DiagnosticableTreeMixin
    implements ImageGenerationState {
  const ImageGenerationError(
      {required this.prompt, required this.errorMessage});

  final String prompt;
  final String errorMessage;

  /// Create a copy of ImageGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImageGenerationErrorCopyWith<ImageGenerationError> get copyWith =>
      _$ImageGenerationErrorCopyWithImpl<ImageGenerationError>(
          this, _$identity);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
      ..add(DiagnosticsProperty('type', 'ImageGenerationState.error'))
      ..add(DiagnosticsProperty('prompt', prompt))
      ..add(DiagnosticsProperty('errorMessage', errorMessage));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImageGenerationError &&
            (identical(other.prompt, prompt) || other.prompt == prompt) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(runtimeType, prompt, errorMessage);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ImageGenerationState.error(prompt: $prompt, errorMessage: $errorMessage)';
  }
}

/// @nodoc
abstract mixin class $ImageGenerationErrorCopyWith<$Res>
    implements $ImageGenerationStateCopyWith<$Res> {
  factory $ImageGenerationErrorCopyWith(ImageGenerationError value,
          $Res Function(ImageGenerationError) _then) =
      _$ImageGenerationErrorCopyWithImpl;
  @useResult
  $Res call({String prompt, String errorMessage});
}

/// @nodoc
class _$ImageGenerationErrorCopyWithImpl<$Res>
    implements $ImageGenerationErrorCopyWith<$Res> {
  _$ImageGenerationErrorCopyWithImpl(this._self, this._then);

  final ImageGenerationError _self;
  final $Res Function(ImageGenerationError) _then;

  /// Create a copy of ImageGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? prompt = null,
    Object? errorMessage = null,
  }) {
    return _then(ImageGenerationError(
      prompt: null == prompt
          ? _self.prompt
          : prompt // ignore: cast_nullable_to_non_nullable
              as String,
      errorMessage: null == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
