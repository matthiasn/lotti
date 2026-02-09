// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rating_question.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RatingQuestion {
  /// Stable identifier for this question (e.g., "productivity").
  String get key;

  /// Localized question text shown to the user.
  String get question;

  /// English semantic description of what this dimension measures and
  /// how to interpret the 0-1 scale. Used by LLMs to determine
  /// "good" vs "bad" outcomes without external schema knowledge.
  String get description;

  /// Input type for the UI and value interpretation.
  /// - 'tapBar': continuous 0.0-1.0 tap bar (tap anywhere to set value)
  /// - 'segmented': categorical buttons with fixed values
  /// - 'boolean': yes/no (0.0 or 1.0)
  String get inputType;

  /// Available options for 'segmented' input type.
  /// Each option has a display label and a normalized value.
  List<RatingQuestionOption>? get options;

  /// Create a copy of RatingQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RatingQuestionCopyWith<RatingQuestion> get copyWith =>
      _$RatingQuestionCopyWithImpl<RatingQuestion>(
          this as RatingQuestion, _$identity);

  /// Serializes this RatingQuestion to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RatingQuestion &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.inputType, inputType) ||
                other.inputType == inputType) &&
            const DeepCollectionEquality().equals(other.options, options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, key, question, description,
      inputType, const DeepCollectionEquality().hash(options));

  @override
  String toString() {
    return 'RatingQuestion(key: $key, question: $question, description: $description, inputType: $inputType, options: $options)';
  }
}

/// @nodoc
abstract mixin class $RatingQuestionCopyWith<$Res> {
  factory $RatingQuestionCopyWith(
          RatingQuestion value, $Res Function(RatingQuestion) _then) =
      _$RatingQuestionCopyWithImpl;
  @useResult
  $Res call(
      {String key,
      String question,
      String description,
      String inputType,
      List<RatingQuestionOption>? options});
}

/// @nodoc
class _$RatingQuestionCopyWithImpl<$Res>
    implements $RatingQuestionCopyWith<$Res> {
  _$RatingQuestionCopyWithImpl(this._self, this._then);

  final RatingQuestion _self;
  final $Res Function(RatingQuestion) _then;

  /// Create a copy of RatingQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? question = null,
    Object? description = null,
    Object? inputType = null,
    Object? options = freezed,
  }) {
    return _then(_self.copyWith(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      question: null == question
          ? _self.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      inputType: null == inputType
          ? _self.inputType
          : inputType // ignore: cast_nullable_to_non_nullable
              as String,
      options: freezed == options
          ? _self.options
          : options // ignore: cast_nullable_to_non_nullable
              as List<RatingQuestionOption>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [RatingQuestion].
extension RatingQuestionPatterns on RatingQuestion {
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
    TResult Function(_RatingQuestion value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingQuestion() when $default != null:
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
    TResult Function(_RatingQuestion value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestion():
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
    TResult? Function(_RatingQuestion value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestion() when $default != null:
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
    TResult Function(String key, String question, String description,
            String inputType, List<RatingQuestionOption>? options)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingQuestion() when $default != null:
        return $default(_that.key, _that.question, _that.description,
            _that.inputType, _that.options);
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
    TResult Function(String key, String question, String description,
            String inputType, List<RatingQuestionOption>? options)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestion():
        return $default(_that.key, _that.question, _that.description,
            _that.inputType, _that.options);
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
    TResult? Function(String key, String question, String description,
            String inputType, List<RatingQuestionOption>? options)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestion() when $default != null:
        return $default(_that.key, _that.question, _that.description,
            _that.inputType, _that.options);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RatingQuestion implements RatingQuestion {
  const _RatingQuestion(
      {required this.key,
      required this.question,
      required this.description,
      this.inputType = 'tapBar',
      final List<RatingQuestionOption>? options})
      : _options = options;
  factory _RatingQuestion.fromJson(Map<String, dynamic> json) =>
      _$RatingQuestionFromJson(json);

  /// Stable identifier for this question (e.g., "productivity").
  @override
  final String key;

  /// Localized question text shown to the user.
  @override
  final String question;

  /// English semantic description of what this dimension measures and
  /// how to interpret the 0-1 scale. Used by LLMs to determine
  /// "good" vs "bad" outcomes without external schema knowledge.
  @override
  final String description;

  /// Input type for the UI and value interpretation.
  /// - 'tapBar': continuous 0.0-1.0 tap bar (tap anywhere to set value)
  /// - 'segmented': categorical buttons with fixed values
  /// - 'boolean': yes/no (0.0 or 1.0)
  @override
  @JsonKey()
  final String inputType;

  /// Available options for 'segmented' input type.
  /// Each option has a display label and a normalized value.
  final List<RatingQuestionOption>? _options;

  /// Available options for 'segmented' input type.
  /// Each option has a display label and a normalized value.
  @override
  List<RatingQuestionOption>? get options {
    final value = _options;
    if (value == null) return null;
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of RatingQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RatingQuestionCopyWith<_RatingQuestion> get copyWith =>
      __$RatingQuestionCopyWithImpl<_RatingQuestion>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RatingQuestionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RatingQuestion &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.question, question) ||
                other.question == question) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.inputType, inputType) ||
                other.inputType == inputType) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, key, question, description,
      inputType, const DeepCollectionEquality().hash(_options));

  @override
  String toString() {
    return 'RatingQuestion(key: $key, question: $question, description: $description, inputType: $inputType, options: $options)';
  }
}

/// @nodoc
abstract mixin class _$RatingQuestionCopyWith<$Res>
    implements $RatingQuestionCopyWith<$Res> {
  factory _$RatingQuestionCopyWith(
          _RatingQuestion value, $Res Function(_RatingQuestion) _then) =
      __$RatingQuestionCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String key,
      String question,
      String description,
      String inputType,
      List<RatingQuestionOption>? options});
}

/// @nodoc
class __$RatingQuestionCopyWithImpl<$Res>
    implements _$RatingQuestionCopyWith<$Res> {
  __$RatingQuestionCopyWithImpl(this._self, this._then);

  final _RatingQuestion _self;
  final $Res Function(_RatingQuestion) _then;

  /// Create a copy of RatingQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? key = null,
    Object? question = null,
    Object? description = null,
    Object? inputType = null,
    Object? options = freezed,
  }) {
    return _then(_RatingQuestion(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      question: null == question
          ? _self.question
          : question // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      inputType: null == inputType
          ? _self.inputType
          : inputType // ignore: cast_nullable_to_non_nullable
              as String,
      options: freezed == options
          ? _self._options
          : options // ignore: cast_nullable_to_non_nullable
              as List<RatingQuestionOption>?,
    ));
  }
}

/// @nodoc
mixin _$RatingQuestionOption {
  /// Display label for this option (localized).
  String get label;

  /// Normalized value (0.0-1.0) assigned when this option is selected.
  double get value;

  /// Create a copy of RatingQuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RatingQuestionOptionCopyWith<RatingQuestionOption> get copyWith =>
      _$RatingQuestionOptionCopyWithImpl<RatingQuestionOption>(
          this as RatingQuestionOption, _$identity);

  /// Serializes this RatingQuestionOption to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RatingQuestionOption &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, label, value);

  @override
  String toString() {
    return 'RatingQuestionOption(label: $label, value: $value)';
  }
}

/// @nodoc
abstract mixin class $RatingQuestionOptionCopyWith<$Res> {
  factory $RatingQuestionOptionCopyWith(RatingQuestionOption value,
          $Res Function(RatingQuestionOption) _then) =
      _$RatingQuestionOptionCopyWithImpl;
  @useResult
  $Res call({String label, double value});
}

/// @nodoc
class _$RatingQuestionOptionCopyWithImpl<$Res>
    implements $RatingQuestionOptionCopyWith<$Res> {
  _$RatingQuestionOptionCopyWithImpl(this._self, this._then);

  final RatingQuestionOption _self;
  final $Res Function(RatingQuestionOption) _then;

  /// Create a copy of RatingQuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? value = null,
  }) {
    return _then(_self.copyWith(
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [RatingQuestionOption].
extension RatingQuestionOptionPatterns on RatingQuestionOption {
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
    TResult Function(_RatingQuestionOption value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingQuestionOption() when $default != null:
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
    TResult Function(_RatingQuestionOption value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestionOption():
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
    TResult? Function(_RatingQuestionOption value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestionOption() when $default != null:
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
    TResult Function(String label, double value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RatingQuestionOption() when $default != null:
        return $default(_that.label, _that.value);
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
    TResult Function(String label, double value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestionOption():
        return $default(_that.label, _that.value);
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
    TResult? Function(String label, double value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RatingQuestionOption() when $default != null:
        return $default(_that.label, _that.value);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _RatingQuestionOption implements RatingQuestionOption {
  const _RatingQuestionOption({required this.label, required this.value});
  factory _RatingQuestionOption.fromJson(Map<String, dynamic> json) =>
      _$RatingQuestionOptionFromJson(json);

  /// Display label for this option (localized).
  @override
  final String label;

  /// Normalized value (0.0-1.0) assigned when this option is selected.
  @override
  final double value;

  /// Create a copy of RatingQuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RatingQuestionOptionCopyWith<_RatingQuestionOption> get copyWith =>
      __$RatingQuestionOptionCopyWithImpl<_RatingQuestionOption>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$RatingQuestionOptionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RatingQuestionOption &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, label, value);

  @override
  String toString() {
    return 'RatingQuestionOption(label: $label, value: $value)';
  }
}

/// @nodoc
abstract mixin class _$RatingQuestionOptionCopyWith<$Res>
    implements $RatingQuestionOptionCopyWith<$Res> {
  factory _$RatingQuestionOptionCopyWith(_RatingQuestionOption value,
          $Res Function(_RatingQuestionOption) _then) =
      __$RatingQuestionOptionCopyWithImpl;
  @override
  @useResult
  $Res call({String label, double value});
}

/// @nodoc
class __$RatingQuestionOptionCopyWithImpl<$Res>
    implements _$RatingQuestionOptionCopyWith<$Res> {
  __$RatingQuestionOptionCopyWithImpl(this._self, this._then);

  final _RatingQuestionOption _self;
  final $Res Function(_RatingQuestionOption) _then;

  /// Create a copy of RatingQuestionOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? label = null,
    Object? value = null,
  }) {
    return _then(_RatingQuestionOption(
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      value: null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
