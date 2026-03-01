// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'classified_feedback.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClassifiedFeedbackItem {
  FeedbackSentiment get sentiment;
  FeedbackCategory get category;

  /// Source type: 'observation', 'decision', 'metric', or 'rating'.
  String get source;

  /// Human-readable detail about this feedback signal.
  String get detail;

  /// The agent instance this feedback relates to.
  String get agentId;

  /// ID of the source entity (e.g., change decision ID).
  String? get sourceEntityId;

  /// Classification confidence (0.0–1.0) for LLM-classified items.
  double? get confidence;

  /// Create a copy of ClassifiedFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ClassifiedFeedbackItemCopyWith<ClassifiedFeedbackItem> get copyWith =>
      _$ClassifiedFeedbackItemCopyWithImpl<ClassifiedFeedbackItem>(
          this as ClassifiedFeedbackItem, _$identity);

  /// Serializes this ClassifiedFeedbackItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ClassifiedFeedbackItem &&
            (identical(other.sentiment, sentiment) ||
                other.sentiment == sentiment) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.sourceEntityId, sourceEntityId) ||
                other.sourceEntityId == sourceEntityId) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sentiment, category, source,
      detail, agentId, sourceEntityId, confidence);

  @override
  String toString() {
    return 'ClassifiedFeedbackItem(sentiment: $sentiment, category: $category, source: $source, detail: $detail, agentId: $agentId, sourceEntityId: $sourceEntityId, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class $ClassifiedFeedbackItemCopyWith<$Res> {
  factory $ClassifiedFeedbackItemCopyWith(ClassifiedFeedbackItem value,
          $Res Function(ClassifiedFeedbackItem) _then) =
      _$ClassifiedFeedbackItemCopyWithImpl;
  @useResult
  $Res call(
      {FeedbackSentiment sentiment,
      FeedbackCategory category,
      String source,
      String detail,
      String agentId,
      String? sourceEntityId,
      double? confidence});
}

/// @nodoc
class _$ClassifiedFeedbackItemCopyWithImpl<$Res>
    implements $ClassifiedFeedbackItemCopyWith<$Res> {
  _$ClassifiedFeedbackItemCopyWithImpl(this._self, this._then);

  final ClassifiedFeedbackItem _self;
  final $Res Function(ClassifiedFeedbackItem) _then;

  /// Create a copy of ClassifiedFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sentiment = null,
    Object? category = null,
    Object? source = null,
    Object? detail = null,
    Object? agentId = null,
    Object? sourceEntityId = freezed,
    Object? confidence = freezed,
  }) {
    return _then(_self.copyWith(
      sentiment: null == sentiment
          ? _self.sentiment
          : sentiment // ignore: cast_nullable_to_non_nullable
              as FeedbackSentiment,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as FeedbackCategory,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      sourceEntityId: freezed == sourceEntityId
          ? _self.sourceEntityId
          : sourceEntityId // ignore: cast_nullable_to_non_nullable
              as String?,
      confidence: freezed == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ClassifiedFeedbackItem].
extension ClassifiedFeedbackItemPatterns on ClassifiedFeedbackItem {
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
    TResult Function(_ClassifiedFeedbackItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedbackItem() when $default != null:
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
    TResult Function(_ClassifiedFeedbackItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedbackItem():
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
    TResult? Function(_ClassifiedFeedbackItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedbackItem() when $default != null:
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
            FeedbackSentiment sentiment,
            FeedbackCategory category,
            String source,
            String detail,
            String agentId,
            String? sourceEntityId,
            double? confidence)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedbackItem() when $default != null:
        return $default(
            _that.sentiment,
            _that.category,
            _that.source,
            _that.detail,
            _that.agentId,
            _that.sourceEntityId,
            _that.confidence);
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
            FeedbackSentiment sentiment,
            FeedbackCategory category,
            String source,
            String detail,
            String agentId,
            String? sourceEntityId,
            double? confidence)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedbackItem():
        return $default(
            _that.sentiment,
            _that.category,
            _that.source,
            _that.detail,
            _that.agentId,
            _that.sourceEntityId,
            _that.confidence);
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
            FeedbackSentiment sentiment,
            FeedbackCategory category,
            String source,
            String detail,
            String agentId,
            String? sourceEntityId,
            double? confidence)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedbackItem() when $default != null:
        return $default(
            _that.sentiment,
            _that.category,
            _that.source,
            _that.detail,
            _that.agentId,
            _that.sourceEntityId,
            _that.confidence);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ClassifiedFeedbackItem implements ClassifiedFeedbackItem {
  const _ClassifiedFeedbackItem(
      {required this.sentiment,
      required this.category,
      required this.source,
      required this.detail,
      required this.agentId,
      this.sourceEntityId,
      this.confidence});
  factory _ClassifiedFeedbackItem.fromJson(Map<String, dynamic> json) =>
      _$ClassifiedFeedbackItemFromJson(json);

  @override
  final FeedbackSentiment sentiment;
  @override
  final FeedbackCategory category;

  /// Source type: 'observation', 'decision', 'metric', or 'rating'.
  @override
  final String source;

  /// Human-readable detail about this feedback signal.
  @override
  final String detail;

  /// The agent instance this feedback relates to.
  @override
  final String agentId;

  /// ID of the source entity (e.g., change decision ID).
  @override
  final String? sourceEntityId;

  /// Classification confidence (0.0–1.0) for LLM-classified items.
  @override
  final double? confidence;

  /// Create a copy of ClassifiedFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ClassifiedFeedbackItemCopyWith<_ClassifiedFeedbackItem> get copyWith =>
      __$ClassifiedFeedbackItemCopyWithImpl<_ClassifiedFeedbackItem>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ClassifiedFeedbackItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ClassifiedFeedbackItem &&
            (identical(other.sentiment, sentiment) ||
                other.sentiment == sentiment) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.sourceEntityId, sourceEntityId) ||
                other.sourceEntityId == sourceEntityId) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sentiment, category, source,
      detail, agentId, sourceEntityId, confidence);

  @override
  String toString() {
    return 'ClassifiedFeedbackItem(sentiment: $sentiment, category: $category, source: $source, detail: $detail, agentId: $agentId, sourceEntityId: $sourceEntityId, confidence: $confidence)';
  }
}

/// @nodoc
abstract mixin class _$ClassifiedFeedbackItemCopyWith<$Res>
    implements $ClassifiedFeedbackItemCopyWith<$Res> {
  factory _$ClassifiedFeedbackItemCopyWith(_ClassifiedFeedbackItem value,
          $Res Function(_ClassifiedFeedbackItem) _then) =
      __$ClassifiedFeedbackItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {FeedbackSentiment sentiment,
      FeedbackCategory category,
      String source,
      String detail,
      String agentId,
      String? sourceEntityId,
      double? confidence});
}

/// @nodoc
class __$ClassifiedFeedbackItemCopyWithImpl<$Res>
    implements _$ClassifiedFeedbackItemCopyWith<$Res> {
  __$ClassifiedFeedbackItemCopyWithImpl(this._self, this._then);

  final _ClassifiedFeedbackItem _self;
  final $Res Function(_ClassifiedFeedbackItem) _then;

  /// Create a copy of ClassifiedFeedbackItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? sentiment = null,
    Object? category = null,
    Object? source = null,
    Object? detail = null,
    Object? agentId = null,
    Object? sourceEntityId = freezed,
    Object? confidence = freezed,
  }) {
    return _then(_ClassifiedFeedbackItem(
      sentiment: null == sentiment
          ? _self.sentiment
          : sentiment // ignore: cast_nullable_to_non_nullable
              as FeedbackSentiment,
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as FeedbackCategory,
      source: null == source
          ? _self.source
          : source // ignore: cast_nullable_to_non_nullable
              as String,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      sourceEntityId: freezed == sourceEntityId
          ? _self.sourceEntityId
          : sourceEntityId // ignore: cast_nullable_to_non_nullable
              as String?,
      confidence: freezed == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
mixin _$ClassifiedFeedback {
  List<ClassifiedFeedbackItem> get items;
  DateTime get windowStart;
  DateTime get windowEnd;
  int get totalObservationsScanned;
  int get totalDecisionsScanned;

  /// Create a copy of ClassifiedFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ClassifiedFeedbackCopyWith<ClassifiedFeedback> get copyWith =>
      _$ClassifiedFeedbackCopyWithImpl<ClassifiedFeedback>(
          this as ClassifiedFeedback, _$identity);

  /// Serializes this ClassifiedFeedback to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ClassifiedFeedback &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.windowStart, windowStart) ||
                other.windowStart == windowStart) &&
            (identical(other.windowEnd, windowEnd) ||
                other.windowEnd == windowEnd) &&
            (identical(
                    other.totalObservationsScanned, totalObservationsScanned) ||
                other.totalObservationsScanned == totalObservationsScanned) &&
            (identical(other.totalDecisionsScanned, totalDecisionsScanned) ||
                other.totalDecisionsScanned == totalDecisionsScanned));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(items),
      windowStart,
      windowEnd,
      totalObservationsScanned,
      totalDecisionsScanned);

  @override
  String toString() {
    return 'ClassifiedFeedback(items: $items, windowStart: $windowStart, windowEnd: $windowEnd, totalObservationsScanned: $totalObservationsScanned, totalDecisionsScanned: $totalDecisionsScanned)';
  }
}

/// @nodoc
abstract mixin class $ClassifiedFeedbackCopyWith<$Res> {
  factory $ClassifiedFeedbackCopyWith(
          ClassifiedFeedback value, $Res Function(ClassifiedFeedback) _then) =
      _$ClassifiedFeedbackCopyWithImpl;
  @useResult
  $Res call(
      {List<ClassifiedFeedbackItem> items,
      DateTime windowStart,
      DateTime windowEnd,
      int totalObservationsScanned,
      int totalDecisionsScanned});
}

/// @nodoc
class _$ClassifiedFeedbackCopyWithImpl<$Res>
    implements $ClassifiedFeedbackCopyWith<$Res> {
  _$ClassifiedFeedbackCopyWithImpl(this._self, this._then);

  final ClassifiedFeedback _self;
  final $Res Function(ClassifiedFeedback) _then;

  /// Create a copy of ClassifiedFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? windowStart = null,
    Object? windowEnd = null,
    Object? totalObservationsScanned = null,
    Object? totalDecisionsScanned = null,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<ClassifiedFeedbackItem>,
      windowStart: null == windowStart
          ? _self.windowStart
          : windowStart // ignore: cast_nullable_to_non_nullable
              as DateTime,
      windowEnd: null == windowEnd
          ? _self.windowEnd
          : windowEnd // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalObservationsScanned: null == totalObservationsScanned
          ? _self.totalObservationsScanned
          : totalObservationsScanned // ignore: cast_nullable_to_non_nullable
              as int,
      totalDecisionsScanned: null == totalDecisionsScanned
          ? _self.totalDecisionsScanned
          : totalDecisionsScanned // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [ClassifiedFeedback].
extension ClassifiedFeedbackPatterns on ClassifiedFeedback {
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
    TResult Function(_ClassifiedFeedback value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedback() when $default != null:
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
    TResult Function(_ClassifiedFeedback value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedback():
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
    TResult? Function(_ClassifiedFeedback value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedback() when $default != null:
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
            List<ClassifiedFeedbackItem> items,
            DateTime windowStart,
            DateTime windowEnd,
            int totalObservationsScanned,
            int totalDecisionsScanned)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedback() when $default != null:
        return $default(_that.items, _that.windowStart, _that.windowEnd,
            _that.totalObservationsScanned, _that.totalDecisionsScanned);
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
            List<ClassifiedFeedbackItem> items,
            DateTime windowStart,
            DateTime windowEnd,
            int totalObservationsScanned,
            int totalDecisionsScanned)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedback():
        return $default(_that.items, _that.windowStart, _that.windowEnd,
            _that.totalObservationsScanned, _that.totalDecisionsScanned);
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
            List<ClassifiedFeedbackItem> items,
            DateTime windowStart,
            DateTime windowEnd,
            int totalObservationsScanned,
            int totalDecisionsScanned)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ClassifiedFeedback() when $default != null:
        return $default(_that.items, _that.windowStart, _that.windowEnd,
            _that.totalObservationsScanned, _that.totalDecisionsScanned);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ClassifiedFeedback implements ClassifiedFeedback {
  const _ClassifiedFeedback(
      {required final List<ClassifiedFeedbackItem> items,
      required this.windowStart,
      required this.windowEnd,
      required this.totalObservationsScanned,
      required this.totalDecisionsScanned})
      : _items = items;
  factory _ClassifiedFeedback.fromJson(Map<String, dynamic> json) =>
      _$ClassifiedFeedbackFromJson(json);

  final List<ClassifiedFeedbackItem> _items;
  @override
  List<ClassifiedFeedbackItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final DateTime windowStart;
  @override
  final DateTime windowEnd;
  @override
  final int totalObservationsScanned;
  @override
  final int totalDecisionsScanned;

  /// Create a copy of ClassifiedFeedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ClassifiedFeedbackCopyWith<_ClassifiedFeedback> get copyWith =>
      __$ClassifiedFeedbackCopyWithImpl<_ClassifiedFeedback>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ClassifiedFeedbackToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ClassifiedFeedback &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.windowStart, windowStart) ||
                other.windowStart == windowStart) &&
            (identical(other.windowEnd, windowEnd) ||
                other.windowEnd == windowEnd) &&
            (identical(
                    other.totalObservationsScanned, totalObservationsScanned) ||
                other.totalObservationsScanned == totalObservationsScanned) &&
            (identical(other.totalDecisionsScanned, totalDecisionsScanned) ||
                other.totalDecisionsScanned == totalDecisionsScanned));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_items),
      windowStart,
      windowEnd,
      totalObservationsScanned,
      totalDecisionsScanned);

  @override
  String toString() {
    return 'ClassifiedFeedback(items: $items, windowStart: $windowStart, windowEnd: $windowEnd, totalObservationsScanned: $totalObservationsScanned, totalDecisionsScanned: $totalDecisionsScanned)';
  }
}

/// @nodoc
abstract mixin class _$ClassifiedFeedbackCopyWith<$Res>
    implements $ClassifiedFeedbackCopyWith<$Res> {
  factory _$ClassifiedFeedbackCopyWith(
          _ClassifiedFeedback value, $Res Function(_ClassifiedFeedback) _then) =
      __$ClassifiedFeedbackCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<ClassifiedFeedbackItem> items,
      DateTime windowStart,
      DateTime windowEnd,
      int totalObservationsScanned,
      int totalDecisionsScanned});
}

/// @nodoc
class __$ClassifiedFeedbackCopyWithImpl<$Res>
    implements _$ClassifiedFeedbackCopyWith<$Res> {
  __$ClassifiedFeedbackCopyWithImpl(this._self, this._then);

  final _ClassifiedFeedback _self;
  final $Res Function(_ClassifiedFeedback) _then;

  /// Create a copy of ClassifiedFeedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
    Object? windowStart = null,
    Object? windowEnd = null,
    Object? totalObservationsScanned = null,
    Object? totalDecisionsScanned = null,
  }) {
    return _then(_ClassifiedFeedback(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<ClassifiedFeedbackItem>,
      windowStart: null == windowStart
          ? _self.windowStart
          : windowStart // ignore: cast_nullable_to_non_nullable
              as DateTime,
      windowEnd: null == windowEnd
          ? _self.windowEnd
          : windowEnd // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalObservationsScanned: null == totalObservationsScanned
          ? _self.totalObservationsScanned
          : totalObservationsScanned // ignore: cast_nullable_to_non_nullable
              as int,
      totalDecisionsScanned: null == totalDecisionsScanned
          ? _self.totalDecisionsScanned
          : totalDecisionsScanned // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
