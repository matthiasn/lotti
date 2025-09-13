// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_functions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetTaskLanguageResult {
  String get languageCode;
  LanguageDetectionConfidence get confidence;
  String get reason;

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SetTaskLanguageResultCopyWith<SetTaskLanguageResult> get copyWith =>
      _$SetTaskLanguageResultCopyWithImpl<SetTaskLanguageResult>(
          this as SetTaskLanguageResult, _$identity);

  /// Serializes this SetTaskLanguageResult to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SetTaskLanguageResult &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, languageCode, confidence, reason);

  @override
  String toString() {
    return 'SetTaskLanguageResult(languageCode: $languageCode, confidence: $confidence, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class $SetTaskLanguageResultCopyWith<$Res> {
  factory $SetTaskLanguageResultCopyWith(SetTaskLanguageResult value,
          $Res Function(SetTaskLanguageResult) _then) =
      _$SetTaskLanguageResultCopyWithImpl;
  @useResult
  $Res call(
      {String languageCode,
      LanguageDetectionConfidence confidence,
      String reason});
}

/// @nodoc
class _$SetTaskLanguageResultCopyWithImpl<$Res>
    implements $SetTaskLanguageResultCopyWith<$Res> {
  _$SetTaskLanguageResultCopyWithImpl(this._self, this._then);

  final SetTaskLanguageResult _self;
  final $Res Function(SetTaskLanguageResult) _then;

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? languageCode = null,
    Object? confidence = null,
    Object? reason = null,
  }) {
    return _then(_self.copyWith(
      languageCode: null == languageCode
          ? _self.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as LanguageDetectionConfidence,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [SetTaskLanguageResult].
extension SetTaskLanguageResultPatterns on SetTaskLanguageResult {
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
    TResult Function(_SetTaskLanguageResult value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetTaskLanguageResult() when $default != null:
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
    TResult Function(_SetTaskLanguageResult value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetTaskLanguageResult():
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
    TResult? Function(_SetTaskLanguageResult value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetTaskLanguageResult() when $default != null:
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
    TResult Function(String languageCode,
            LanguageDetectionConfidence confidence, String reason)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetTaskLanguageResult() when $default != null:
        return $default(_that.languageCode, _that.confidence, _that.reason);
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
    TResult Function(String languageCode,
            LanguageDetectionConfidence confidence, String reason)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetTaskLanguageResult():
        return $default(_that.languageCode, _that.confidence, _that.reason);
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
    TResult? Function(String languageCode,
            LanguageDetectionConfidence confidence, String reason)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetTaskLanguageResult() when $default != null:
        return $default(_that.languageCode, _that.confidence, _that.reason);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SetTaskLanguageResult implements SetTaskLanguageResult {
  const _SetTaskLanguageResult(
      {required this.languageCode,
      required this.confidence,
      required this.reason});
  factory _SetTaskLanguageResult.fromJson(Map<String, dynamic> json) =>
      _$SetTaskLanguageResultFromJson(json);

  @override
  final String languageCode;
  @override
  final LanguageDetectionConfidence confidence;
  @override
  final String reason;

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SetTaskLanguageResultCopyWith<_SetTaskLanguageResult> get copyWith =>
      __$SetTaskLanguageResultCopyWithImpl<_SetTaskLanguageResult>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SetTaskLanguageResultToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SetTaskLanguageResult &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, languageCode, confidence, reason);

  @override
  String toString() {
    return 'SetTaskLanguageResult(languageCode: $languageCode, confidence: $confidence, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class _$SetTaskLanguageResultCopyWith<$Res>
    implements $SetTaskLanguageResultCopyWith<$Res> {
  factory _$SetTaskLanguageResultCopyWith(_SetTaskLanguageResult value,
          $Res Function(_SetTaskLanguageResult) _then) =
      __$SetTaskLanguageResultCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String languageCode,
      LanguageDetectionConfidence confidence,
      String reason});
}

/// @nodoc
class __$SetTaskLanguageResultCopyWithImpl<$Res>
    implements _$SetTaskLanguageResultCopyWith<$Res> {
  __$SetTaskLanguageResultCopyWithImpl(this._self, this._then);

  final _SetTaskLanguageResult _self;
  final $Res Function(_SetTaskLanguageResult) _then;

  /// Create a copy of SetTaskLanguageResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? languageCode = null,
    Object? confidence = null,
    Object? reason = null,
  }) {
    return _then(_SetTaskLanguageResult(
      languageCode: null == languageCode
          ? _self.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as LanguageDetectionConfidence,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
