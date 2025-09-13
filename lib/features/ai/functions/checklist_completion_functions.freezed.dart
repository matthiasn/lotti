// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_completion_functions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChecklistCompletionSuggestion {
  String get checklistItemId;
  String get reason;
  ChecklistCompletionConfidence get confidence;

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChecklistCompletionSuggestionCopyWith<ChecklistCompletionSuggestion>
      get copyWith => _$ChecklistCompletionSuggestionCopyWithImpl<
              ChecklistCompletionSuggestion>(
          this as ChecklistCompletionSuggestion, _$identity);

  /// Serializes this ChecklistCompletionSuggestion to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChecklistCompletionSuggestion &&
            (identical(other.checklistItemId, checklistItemId) ||
                other.checklistItemId == checklistItemId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, checklistItemId, reason, confidence);

  @override
  String toString() {
    return 'ChecklistCompletionSuggestion(checklistItemId: $checklistItemId, reason: $reason, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class $ChecklistCompletionSuggestionCopyWith<$Res> {
  factory $ChecklistCompletionSuggestionCopyWith(
          ChecklistCompletionSuggestion value,
          $Res Function(ChecklistCompletionSuggestion) _then) =
      _$ChecklistCompletionSuggestionCopyWithImpl;
  @useResult
  $Res call(
      {String checklistItemId,
      String reason,
      ChecklistCompletionConfidence confidence});
}

/// @nodoc
class _$ChecklistCompletionSuggestionCopyWithImpl<$Res>
    implements $ChecklistCompletionSuggestionCopyWith<$Res> {
  _$ChecklistCompletionSuggestionCopyWithImpl(this._self, this._then);

  final ChecklistCompletionSuggestion _self;
  final $Res Function(ChecklistCompletionSuggestion) _then;

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checklistItemId = null,
    Object? reason = null,
    Object? confidence = null,
  }) {
    return _then(_self.copyWith(
      checklistItemId: null == checklistItemId
          ? _self.checklistItemId
          : checklistItemId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as ChecklistCompletionConfidence,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChecklistCompletionSuggestion].
extension ChecklistCompletionSuggestionPatterns
    on ChecklistCompletionSuggestion {
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
    TResult Function(_ChecklistCompletionSuggestion value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistCompletionSuggestion() when $default != null:
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
    TResult Function(_ChecklistCompletionSuggestion value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistCompletionSuggestion():
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
    TResult? Function(_ChecklistCompletionSuggestion value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistCompletionSuggestion() when $default != null:
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
    TResult Function(String checklistItemId, String reason,
            ChecklistCompletionConfidence confidence)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistCompletionSuggestion() when $default != null:
        return $default(_that.checklistItemId, _that.reason, _that.confidence);
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
    TResult Function(String checklistItemId, String reason,
            ChecklistCompletionConfidence confidence)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistCompletionSuggestion():
        return $default(_that.checklistItemId, _that.reason, _that.confidence);
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
    TResult? Function(String checklistItemId, String reason,
            ChecklistCompletionConfidence confidence)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistCompletionSuggestion() when $default != null:
        return $default(_that.checklistItemId, _that.reason, _that.confidence);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ChecklistCompletionSuggestion implements ChecklistCompletionSuggestion {
  const _ChecklistCompletionSuggestion(
      {required this.checklistItemId,
      required this.reason,
      required this.confidence});
  factory _ChecklistCompletionSuggestion.fromJson(Map<String, dynamic> json) =>
      _$ChecklistCompletionSuggestionFromJson(json);

  @override
  final String checklistItemId;
  @override
  final String reason;
  @override
  final ChecklistCompletionConfidence confidence;

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChecklistCompletionSuggestionCopyWith<_ChecklistCompletionSuggestion>
      get copyWith => __$ChecklistCompletionSuggestionCopyWithImpl<
          _ChecklistCompletionSuggestion>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChecklistCompletionSuggestionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChecklistCompletionSuggestion &&
            (identical(other.checklistItemId, checklistItemId) ||
                other.checklistItemId == checklistItemId) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, checklistItemId, reason, confidence);

  @override
  String toString() {
    return 'ChecklistCompletionSuggestion(checklistItemId: $checklistItemId, reason: $reason, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class _$ChecklistCompletionSuggestionCopyWith<$Res>
    implements $ChecklistCompletionSuggestionCopyWith<$Res> {
  factory _$ChecklistCompletionSuggestionCopyWith(
          _ChecklistCompletionSuggestion value,
          $Res Function(_ChecklistCompletionSuggestion) _then) =
      __$ChecklistCompletionSuggestionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String checklistItemId,
      String reason,
      ChecklistCompletionConfidence confidence});
}

/// @nodoc
class __$ChecklistCompletionSuggestionCopyWithImpl<$Res>
    implements _$ChecklistCompletionSuggestionCopyWith<$Res> {
  __$ChecklistCompletionSuggestionCopyWithImpl(this._self, this._then);

  final _ChecklistCompletionSuggestion _self;
  final $Res Function(_ChecklistCompletionSuggestion) _then;

  /// Create a copy of ChecklistCompletionSuggestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? checklistItemId = null,
    Object? reason = null,
    Object? confidence = null,
  }) {
    return _then(_ChecklistCompletionSuggestion(
      checklistItemId: null == checklistItemId
          ? _self.checklistItemId
          : checklistItemId // ignore: cast_nullable_to_non_nullable
              as String,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: null == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as ChecklistCompletionConfidence,
    ));
  }
}

/// @nodoc
mixin _$AddChecklistItemResult {
  String get checklistId;
  String get checklistItemId;
  bool get checklistCreated;

  /// Create a copy of AddChecklistItemResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AddChecklistItemResultCopyWith<AddChecklistItemResult> get copyWith =>
      _$AddChecklistItemResultCopyWithImpl<AddChecklistItemResult>(
          this as AddChecklistItemResult, _$identity);

  /// Serializes this AddChecklistItemResult to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AddChecklistItemResult &&
            (identical(other.checklistId, checklistId) ||
                other.checklistId == checklistId) &&
            (identical(other.checklistItemId, checklistItemId) ||
                other.checklistItemId == checklistItemId) &&
            (identical(other.checklistCreated, checklistCreated) ||
                other.checklistCreated == checklistCreated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, checklistId, checklistItemId, checklistCreated);

  @override
  String toString() {
    return 'AddChecklistItemResult(checklistId: $checklistId, checklistItemId: $checklistItemId, checklistCreated: $checklistCreated)';
  }
}

/// @nodoc
abstract mixin class $AddChecklistItemResultCopyWith<$Res> {
  factory $AddChecklistItemResultCopyWith(AddChecklistItemResult value,
          $Res Function(AddChecklistItemResult) _then) =
      _$AddChecklistItemResultCopyWithImpl;
  @useResult
  $Res call(
      {String checklistId, String checklistItemId, bool checklistCreated});
}

/// @nodoc
class _$AddChecklistItemResultCopyWithImpl<$Res>
    implements $AddChecklistItemResultCopyWith<$Res> {
  _$AddChecklistItemResultCopyWithImpl(this._self, this._then);

  final AddChecklistItemResult _self;
  final $Res Function(AddChecklistItemResult) _then;

  /// Create a copy of AddChecklistItemResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checklistId = null,
    Object? checklistItemId = null,
    Object? checklistCreated = null,
  }) {
    return _then(_self.copyWith(
      checklistId: null == checklistId
          ? _self.checklistId
          : checklistId // ignore: cast_nullable_to_non_nullable
              as String,
      checklistItemId: null == checklistItemId
          ? _self.checklistItemId
          : checklistItemId // ignore: cast_nullable_to_non_nullable
              as String,
      checklistCreated: null == checklistCreated
          ? _self.checklistCreated
          : checklistCreated // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [AddChecklistItemResult].
extension AddChecklistItemResultPatterns on AddChecklistItemResult {
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
    TResult Function(_AddChecklistItemResult value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddChecklistItemResult() when $default != null:
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
    TResult Function(_AddChecklistItemResult value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddChecklistItemResult():
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
    TResult? Function(_AddChecklistItemResult value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddChecklistItemResult() when $default != null:
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
            String checklistId, String checklistItemId, bool checklistCreated)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddChecklistItemResult() when $default != null:
        return $default(
            _that.checklistId, _that.checklistItemId, _that.checklistCreated);
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
            String checklistId, String checklistItemId, bool checklistCreated)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddChecklistItemResult():
        return $default(
            _that.checklistId, _that.checklistItemId, _that.checklistCreated);
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
    TResult? Function(
            String checklistId, String checklistItemId, bool checklistCreated)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddChecklistItemResult() when $default != null:
        return $default(
            _that.checklistId, _that.checklistItemId, _that.checklistCreated);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AddChecklistItemResult implements AddChecklistItemResult {
  const _AddChecklistItemResult(
      {required this.checklistId,
      required this.checklistItemId,
      required this.checklistCreated});
  factory _AddChecklistItemResult.fromJson(Map<String, dynamic> json) =>
      _$AddChecklistItemResultFromJson(json);

  @override
  final String checklistId;
  @override
  final String checklistItemId;
  @override
  final bool checklistCreated;

  /// Create a copy of AddChecklistItemResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AddChecklistItemResultCopyWith<_AddChecklistItemResult> get copyWith =>
      __$AddChecklistItemResultCopyWithImpl<_AddChecklistItemResult>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AddChecklistItemResultToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AddChecklistItemResult &&
            (identical(other.checklistId, checklistId) ||
                other.checklistId == checklistId) &&
            (identical(other.checklistItemId, checklistItemId) ||
                other.checklistItemId == checklistItemId) &&
            (identical(other.checklistCreated, checklistCreated) ||
                other.checklistCreated == checklistCreated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, checklistId, checklistItemId, checklistCreated);

  @override
  String toString() {
    return 'AddChecklistItemResult(checklistId: $checklistId, checklistItemId: $checklistItemId, checklistCreated: $checklistCreated)';
  }
}

/// @nodoc
abstract mixin class _$AddChecklistItemResultCopyWith<$Res>
    implements $AddChecklistItemResultCopyWith<$Res> {
  factory _$AddChecklistItemResultCopyWith(_AddChecklistItemResult value,
          $Res Function(_AddChecklistItemResult) _then) =
      __$AddChecklistItemResultCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String checklistId, String checklistItemId, bool checklistCreated});
}

/// @nodoc
class __$AddChecklistItemResultCopyWithImpl<$Res>
    implements _$AddChecklistItemResultCopyWith<$Res> {
  __$AddChecklistItemResultCopyWithImpl(this._self, this._then);

  final _AddChecklistItemResult _self;
  final $Res Function(_AddChecklistItemResult) _then;

  /// Create a copy of AddChecklistItemResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? checklistId = null,
    Object? checklistItemId = null,
    Object? checklistCreated = null,
  }) {
    return _then(_AddChecklistItemResult(
      checklistId: null == checklistId
          ? _self.checklistId
          : checklistId // ignore: cast_nullable_to_non_nullable
              as String,
      checklistItemId: null == checklistItemId
          ? _self.checklistItemId
          : checklistItemId // ignore: cast_nullable_to_non_nullable
              as String,
      checklistCreated: null == checklistCreated
          ? _self.checklistCreated
          : checklistCreated // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
