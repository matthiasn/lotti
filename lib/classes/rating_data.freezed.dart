// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rating_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RatingData {
  /// The rated entity's ID. For session ratings this is the time entry ID.
  /// For day ratings it will be the DayPlanEntry ID, for task ratings
  /// the Task ID. JSON key remains 'timeEntryId' for wire compatibility.
  @JsonKey(name: 'timeEntryId')
  String get targetId;

  /// Individual dimension ratings, each normalized to 0.0-1.0.
  List<RatingDimension> get dimensions;

  /// Identifies which question catalog was used to produce this rating.
  /// Enables multiple distinct ratings per target entity (e.g. a task
  /// rated at start vs completion, or a day rated morning vs evening).
  /// The invariant is: at most one rating per (targetId, catalogId).
  String get catalogId;

  /// Schema version for the rating dimensions.
  /// Increment when adding/removing/reordering questions.
  int get schemaVersion;

  /// Optional free-text note about the session.
  String? get note;

  /// Create a copy of RatingData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RatingDataCopyWith<RatingData> get copyWith =>
      _$RatingDataCopyWithImpl<RatingData>(this as RatingData, _$identity);

  /// Serializes this RatingData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RatingData &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId) &&
            const DeepCollectionEquality()
                .equals(other.dimensions, dimensions) &&
            (identical(other.catalogId, catalogId) ||
                other.catalogId == catalogId) &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      targetId,
      const DeepCollectionEquality().hash(dimensions),
      catalogId,
      schemaVersion,
      note);

  @override
  String toString() {
    return 'RatingData(targetId: $targetId, dimensions: $dimensions, catalogId: $catalogId, schemaVersion: $schemaVersion, note: $note)';
  }
}

/// @nodoc
abstract mixin class $RatingDataCopyWith<$Res> {
  factory $RatingDataCopyWith(
          RatingData value, $Res Function(RatingData) _then) =
      _$RatingDataCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'timeEntryId') String targetId,
      List<RatingDimension> dimensions,
      String catalogId,
      int schemaVersion,
      String? note});
}

/// @nodoc
class _$RatingDataCopyWithImpl<$Res> implements $RatingDataCopyWith<$Res> {
  _$RatingDataCopyWithImpl(this._self, this._then);

  final RatingData _self;
  final $Res Function(RatingData) _then;

  /// Create a copy of RatingData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? targetId = null,
    Object? dimensions = null,
    Object? catalogId = null,
    Object? schemaVersion = null,
    Object? note = freezed,
  }) {
    return _then(_self.copyWith(
      targetId: null == targetId
          ? _self.targetId
          : targetId // ignore: cast_nullable_to_non_nullable
              as String,
      dimensions: null == dimensions
          ? _self.dimensions
          : dimensions // ignore: cast_nullable_to_non_nullable
              as List<RatingDimension>,
      catalogId: null == catalogId
          ? _self.catalogId
          : catalogId // ignore: cast_nullable_to_non_nullable
              as String,
      schemaVersion: null == schemaVersion
          ? _self.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [RatingData].
extension RatingDataPatterns on RatingData {
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
    TResult Function(_RatingData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingData() when $default != null:
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
    TResult Function(_RatingData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingData():
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
    TResult? Function(_RatingData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingData() when $default != null:
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
            @JsonKey(name: 'timeEntryId') String targetId,
            List<RatingDimension> dimensions,
            String catalogId,
            int schemaVersion,
            String? note)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingData() when $default != null:
        return $default(_that.targetId, _that.dimensions, _that.catalogId,
            _that.schemaVersion, _that.note);
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
            @JsonKey(name: 'timeEntryId') String targetId,
            List<RatingDimension> dimensions,
            String catalogId,
            int schemaVersion,
            String? note)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingData():
        return $default(_that.targetId, _that.dimensions, _that.catalogId,
            _that.schemaVersion, _that.note);
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
            @JsonKey(name: 'timeEntryId') String targetId,
            List<RatingDimension> dimensions,
            String catalogId,
            int schemaVersion,
            String? note)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingData() when $default != null:
        return $default(_that.targetId, _that.dimensions, _that.catalogId,
            _that.schemaVersion, _that.note);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RatingData extends RatingData {
  const _RatingData(
      {@JsonKey(name: 'timeEntryId') required this.targetId,
      required final List<RatingDimension> dimensions,
      this.catalogId = 'session',
      this.schemaVersion = 1,
      this.note})
      : _dimensions = dimensions,
        super._();
  factory _RatingData.fromJson(Map<String, dynamic> json) =>
      _$RatingDataFromJson(json);

  /// The rated entity's ID. For session ratings this is the time entry ID.
  /// For day ratings it will be the DayPlanEntry ID, for task ratings
  /// the Task ID. JSON key remains 'timeEntryId' for wire compatibility.
  @override
  @JsonKey(name: 'timeEntryId')
  final String targetId;

  /// Individual dimension ratings, each normalized to 0.0-1.0.
  final List<RatingDimension> _dimensions;

  /// Individual dimension ratings, each normalized to 0.0-1.0.
  @override
  List<RatingDimension> get dimensions {
    if (_dimensions is EqualUnmodifiableListView) return _dimensions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dimensions);
  }

  /// Identifies which question catalog was used to produce this rating.
  /// Enables multiple distinct ratings per target entity (e.g. a task
  /// rated at start vs completion, or a day rated morning vs evening).
  /// The invariant is: at most one rating per (targetId, catalogId).
  @override
  @JsonKey()
  final String catalogId;

  /// Schema version for the rating dimensions.
  /// Increment when adding/removing/reordering questions.
  @override
  @JsonKey()
  final int schemaVersion;

  /// Optional free-text note about the session.
  @override
  final String? note;

  /// Create a copy of RatingData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RatingDataCopyWith<_RatingData> get copyWith =>
      __$RatingDataCopyWithImpl<_RatingData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RatingDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RatingData &&
            (identical(other.targetId, targetId) ||
                other.targetId == targetId) &&
            const DeepCollectionEquality()
                .equals(other._dimensions, _dimensions) &&
            (identical(other.catalogId, catalogId) ||
                other.catalogId == catalogId) &&
            (identical(other.schemaVersion, schemaVersion) ||
                other.schemaVersion == schemaVersion) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      targetId,
      const DeepCollectionEquality().hash(_dimensions),
      catalogId,
      schemaVersion,
      note);

  @override
  String toString() {
    return 'RatingData(targetId: $targetId, dimensions: $dimensions, catalogId: $catalogId, schemaVersion: $schemaVersion, note: $note)';
  }
}

/// @nodoc
abstract mixin class _$RatingDataCopyWith<$Res>
    implements $RatingDataCopyWith<$Res> {
  factory _$RatingDataCopyWith(
          _RatingData value, $Res Function(_RatingData) _then) =
      __$RatingDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'timeEntryId') String targetId,
      List<RatingDimension> dimensions,
      String catalogId,
      int schemaVersion,
      String? note});
}

/// @nodoc
class __$RatingDataCopyWithImpl<$Res> implements _$RatingDataCopyWith<$Res> {
  __$RatingDataCopyWithImpl(this._self, this._then);

  final _RatingData _self;
  final $Res Function(_RatingData) _then;

  /// Create a copy of RatingData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? targetId = null,
    Object? dimensions = null,
    Object? catalogId = null,
    Object? schemaVersion = null,
    Object? note = freezed,
  }) {
    return _then(_RatingData(
      targetId: null == targetId
          ? _self.targetId
          : targetId // ignore: cast_nullable_to_non_nullable
              as String,
      dimensions: null == dimensions
          ? _self._dimensions
          : dimensions // ignore: cast_nullable_to_non_nullable
              as List<RatingDimension>,
      catalogId: null == catalogId
          ? _self.catalogId
          : catalogId // ignore: cast_nullable_to_non_nullable
              as String,
      schemaVersion: null == schemaVersion
          ? _self.schemaVersion
          : schemaVersion // ignore: cast_nullable_to_non_nullable
              as int,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$RatingDimension {
  /// Stable key for this dimension (e.g., "productivity", "energy",
  /// "focus", "challenge_skill").
  String get key;

  /// Normalized value between 0.0 and 1.0.
  double get value;

  /// The localized question text shown to the user at time of rating.
  /// Captured in whatever language the user had active.
  String? get question;

  /// English semantic description of what this dimension measures and
  /// how to interpret the 0-1 scale. Intended for LLM consumption so
  /// it can determine "good" vs "bad" outcomes without a schema lookup.
  /// Example: "Measures subjective productivity. 0.0 = completely
  /// unproductive, 1.0 = peak productivity."
  String? get description;

  /// Input type used to collect this answer ('tapBar', 'segmented',
  /// 'boolean'). Allows the UI and LLMs to interpret the value.
  String? get inputType;

  /// Labels for segmented/categorical options (e.g. ["Too easy",
  /// "Just right", "Too challenging"]). Present only when
  /// [inputType] is 'segmented'.
  List<String>? get optionLabels;

  /// Create a copy of RatingDimension
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RatingDimensionCopyWith<RatingDimension> get copyWith =>
      _$RatingDimensionCopyWithImpl<RatingDimension>(
          this as RatingDimension, _$identity);

  /// Serializes this RatingDimension to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RatingDimension &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.inputType, inputType) ||
                other.inputType == inputType) &&
            const DeepCollectionEquality()
                .equals(other.optionLabels, optionLabels));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      key,
      value,
      question,
      description,
      inputType,
      const DeepCollectionEquality().hash(optionLabels));

  @override
  String toString() {
    return 'RatingDimension(key: $key, value: $value, question: $question, description: $description, inputType: $inputType, optionLabels: $optionLabels)';
  }
}

/// @nodoc
abstract mixin class $RatingDimensionCopyWith<$Res> {
  factory $RatingDimensionCopyWith(
          RatingDimension value, $Res Function(RatingDimension) _then) =
      _$RatingDimensionCopyWithImpl;
  @useResult
  $Res call(
      {String key,
      double value,
      String? question,
      String? description,
      String? inputType,
      List<String>? optionLabels});
}

/// @nodoc
class _$RatingDimensionCopyWithImpl<$Res>
    implements $RatingDimensionCopyWith<$Res> {
  _$RatingDimensionCopyWithImpl(this._self, this._then);

  final RatingDimension _self;
  final $Res Function(RatingDimension) _then;

  /// Create a copy of RatingDimension
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? value = null,
    Object? question = freezed,
    Object? description = freezed,
    Object? inputType = freezed,
    Object? optionLabels = freezed,
  }) {
    return _then(_self.copyWith(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      question: freezed == question
          ? _self.question
          : question // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      inputType: freezed == inputType
          ? _self.inputType
          : inputType // ignore: cast_nullable_to_non_nullable
              as String?,
      optionLabels: freezed == optionLabels
          ? _self.optionLabels
          : optionLabels // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [RatingDimension].
extension RatingDimensionPatterns on RatingDimension {
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
    TResult Function(_RatingDimension value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingDimension() when $default != null:
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
    TResult Function(_RatingDimension value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingDimension():
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
    TResult? Function(_RatingDimension value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingDimension() when $default != null:
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
    TResult Function(String key, double value, String? question,
            String? description, String? inputType, List<String>? optionLabels)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingDimension() when $default != null:
        return $default(_that.key, _that.value, _that.question,
            _that.description, _that.inputType, _that.optionLabels);
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
    TResult Function(String key, double value, String? question,
            String? description, String? inputType, List<String>? optionLabels)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingDimension():
        return $default(_that.key, _that.value, _that.question,
            _that.description, _that.inputType, _that.optionLabels);
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
    TResult? Function(String key, double value, String? question,
            String? description, String? inputType, List<String>? optionLabels)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingDimension() when $default != null:
        return $default(_that.key, _that.value, _that.question,
            _that.description, _that.inputType, _that.optionLabels);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RatingDimension implements RatingDimension {
  const _RatingDimension(
      {required this.key,
      required this.value,
      this.question,
      this.description,
      this.inputType,
      final List<String>? optionLabels})
      : _optionLabels = optionLabels;
  factory _RatingDimension.fromJson(Map<String, dynamic> json) =>
      _$RatingDimensionFromJson(json);

  /// Stable key for this dimension (e.g., "productivity", "energy",
  /// "focus", "challenge_skill").
  @override
  final String key;

  /// Normalized value between 0.0 and 1.0.
  @override
  final double value;

  /// The localized question text shown to the user at time of rating.
  /// Captured in whatever language the user had active.
  @override
  final String? question;

  /// English semantic description of what this dimension measures and
  /// how to interpret the 0-1 scale. Intended for LLM consumption so
  /// it can determine "good" vs "bad" outcomes without a schema lookup.
  /// Example: "Measures subjective productivity. 0.0 = completely
  /// unproductive, 1.0 = peak productivity."
  @override
  final String? description;

  /// Input type used to collect this answer ('tapBar', 'segmented',
  /// 'boolean'). Allows the UI and LLMs to interpret the value.
  @override
  final String? inputType;

  /// Labels for segmented/categorical options (e.g. ["Too easy",
  /// "Just right", "Too challenging"]). Present only when
  /// [inputType] is 'segmented'.
  final List<String>? _optionLabels;

  /// Labels for segmented/categorical options (e.g. ["Too easy",
  /// "Just right", "Too challenging"]). Present only when
  /// [inputType] is 'segmented'.
  @override
  List<String>? get optionLabels {
    final value = _optionLabels;
    if (value == null) return null;
    if (_optionLabels is EqualUnmodifiableListView) return _optionLabels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of RatingDimension
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RatingDimensionCopyWith<_RatingDimension> get copyWith =>
      __$RatingDimensionCopyWithImpl<_RatingDimension>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RatingDimensionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RatingDimension &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.inputType, inputType) ||
                other.inputType == inputType) &&
            const DeepCollectionEquality()
                .equals(other._optionLabels, _optionLabels));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      key,
      value,
      question,
      description,
      inputType,
      const DeepCollectionEquality().hash(_optionLabels));

  @override
  String toString() {
    return 'RatingDimension(key: $key, value: $value, question: $question, description: $description, inputType: $inputType, optionLabels: $optionLabels)';
  }
}

/// @nodoc
abstract mixin class _$RatingDimensionCopyWith<$Res>
    implements $RatingDimensionCopyWith<$Res> {
  factory _$RatingDimensionCopyWith(
          _RatingDimension value, $Res Function(_RatingDimension) _then) =
      __$RatingDimensionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String key,
      double value,
      String? question,
      String? description,
      String? inputType,
      List<String>? optionLabels});
}

/// @nodoc
class __$RatingDimensionCopyWithImpl<$Res>
    implements _$RatingDimensionCopyWith<$Res> {
  __$RatingDimensionCopyWithImpl(this._self, this._then);

  final _RatingDimension _self;
  final $Res Function(_RatingDimension) _then;

  /// Create a copy of RatingDimension
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? key = null,
    Object? value = null,
    Object? question = freezed,
    Object? description = freezed,
    Object? inputType = freezed,
    Object? optionLabels = freezed,
  }) {
    return _then(_RatingDimension(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
      question: freezed == question
          ? _self.question
          : question // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      inputType: freezed == inputType
          ? _self.inputType
          : inputType // ignore: cast_nullable_to_non_nullable
              as String?,
      optionLabels: freezed == optionLabels
          ? _self._optionLabels
          : optionLabels // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

// dart format on
