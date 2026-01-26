// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'day_plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
DayPlanStatus _$DayPlanStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'draft':
      return DayPlanStatusDraft.fromJson(json);
    case 'agreed':
      return DayPlanStatusAgreed.fromJson(json);
    case 'needsReview':
      return DayPlanStatusNeedsReview.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'DayPlanStatus',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$DayPlanStatus {
  /// Serializes this DayPlanStatus to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is DayPlanStatus);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DayPlanStatus()';
  }
}

/// @nodoc
class $DayPlanStatusCopyWith<$Res> {
  $DayPlanStatusCopyWith(DayPlanStatus _, $Res Function(DayPlanStatus) __);
}

/// Adds pattern-matching-related methods to [DayPlanStatus].
extension DayPlanStatusPatterns on DayPlanStatus {
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
    TResult Function(DayPlanStatusDraft value)? draft,
    TResult Function(DayPlanStatusAgreed value)? agreed,
    TResult Function(DayPlanStatusNeedsReview value)? needsReview,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanStatusDraft() when draft != null:
        return draft(_that);
      case DayPlanStatusAgreed() when agreed != null:
        return agreed(_that);
      case DayPlanStatusNeedsReview() when needsReview != null:
        return needsReview(_that);
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
    required TResult Function(DayPlanStatusDraft value) draft,
    required TResult Function(DayPlanStatusAgreed value) agreed,
    required TResult Function(DayPlanStatusNeedsReview value) needsReview,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanStatusDraft():
        return draft(_that);
      case DayPlanStatusAgreed():
        return agreed(_that);
      case DayPlanStatusNeedsReview():
        return needsReview(_that);
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
    TResult? Function(DayPlanStatusDraft value)? draft,
    TResult? Function(DayPlanStatusAgreed value)? agreed,
    TResult? Function(DayPlanStatusNeedsReview value)? needsReview,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanStatusDraft() when draft != null:
        return draft(_that);
      case DayPlanStatusAgreed() when agreed != null:
        return agreed(_that);
      case DayPlanStatusNeedsReview() when needsReview != null:
        return needsReview(_that);
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
    TResult Function()? draft,
    TResult Function(DateTime agreedAt)? agreed,
    TResult Function(DateTime triggeredAt, DayPlanReviewReason reason,
            DateTime? previouslyAgreedAt)?
        needsReview,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanStatusDraft() when draft != null:
        return draft();
      case DayPlanStatusAgreed() when agreed != null:
        return agreed(_that.agreedAt);
      case DayPlanStatusNeedsReview() when needsReview != null:
        return needsReview(
            _that.triggeredAt, _that.reason, _that.previouslyAgreedAt);
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
    required TResult Function() draft,
    required TResult Function(DateTime agreedAt) agreed,
    required TResult Function(DateTime triggeredAt, DayPlanReviewReason reason,
            DateTime? previouslyAgreedAt)
        needsReview,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanStatusDraft():
        return draft();
      case DayPlanStatusAgreed():
        return agreed(_that.agreedAt);
      case DayPlanStatusNeedsReview():
        return needsReview(
            _that.triggeredAt, _that.reason, _that.previouslyAgreedAt);
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
    TResult? Function()? draft,
    TResult? Function(DateTime agreedAt)? agreed,
    TResult? Function(DateTime triggeredAt, DayPlanReviewReason reason,
            DateTime? previouslyAgreedAt)?
        needsReview,
  }) {
    final _that = this;
    switch (_that) {
      case DayPlanStatusDraft() when draft != null:
        return draft();
      case DayPlanStatusAgreed() when agreed != null:
        return agreed(_that.agreedAt);
      case DayPlanStatusNeedsReview() when needsReview != null:
        return needsReview(
            _that.triggeredAt, _that.reason, _that.previouslyAgreedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class DayPlanStatusDraft implements DayPlanStatus {
  const DayPlanStatusDraft({final String? $type}) : $type = $type ?? 'draft';
  factory DayPlanStatusDraft.fromJson(Map<String, dynamic> json) =>
      _$DayPlanStatusDraftFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  Map<String, dynamic> toJson() {
    return _$DayPlanStatusDraftToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is DayPlanStatusDraft);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DayPlanStatus.draft()';
  }
}

/// @nodoc
@JsonSerializable()
class DayPlanStatusAgreed implements DayPlanStatus {
  const DayPlanStatusAgreed({required this.agreedAt, final String? $type})
      : $type = $type ?? 'agreed';
  factory DayPlanStatusAgreed.fromJson(Map<String, dynamic> json) =>
      _$DayPlanStatusAgreedFromJson(json);

  final DateTime agreedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DayPlanStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DayPlanStatusAgreedCopyWith<DayPlanStatusAgreed> get copyWith =>
      _$DayPlanStatusAgreedCopyWithImpl<DayPlanStatusAgreed>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DayPlanStatusAgreedToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DayPlanStatusAgreed &&
            (identical(other.agreedAt, agreedAt) ||
                other.agreedAt == agreedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, agreedAt);

  @override
  String toString() {
    return 'DayPlanStatus.agreed(agreedAt: $agreedAt)';
  }
}

/// @nodoc
abstract mixin class $DayPlanStatusAgreedCopyWith<$Res>
    implements $DayPlanStatusCopyWith<$Res> {
  factory $DayPlanStatusAgreedCopyWith(
          DayPlanStatusAgreed value, $Res Function(DayPlanStatusAgreed) _then) =
      _$DayPlanStatusAgreedCopyWithImpl;
  @useResult
  $Res call({DateTime agreedAt});
}

/// @nodoc
class _$DayPlanStatusAgreedCopyWithImpl<$Res>
    implements $DayPlanStatusAgreedCopyWith<$Res> {
  _$DayPlanStatusAgreedCopyWithImpl(this._self, this._then);

  final DayPlanStatusAgreed _self;
  final $Res Function(DayPlanStatusAgreed) _then;

  /// Create a copy of DayPlanStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? agreedAt = null,
  }) {
    return _then(DayPlanStatusAgreed(
      agreedAt: null == agreedAt
          ? _self.agreedAt
          : agreedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class DayPlanStatusNeedsReview implements DayPlanStatus {
  const DayPlanStatusNeedsReview(
      {required this.triggeredAt,
      required this.reason,
      this.previouslyAgreedAt,
      final String? $type})
      : $type = $type ?? 'needsReview';
  factory DayPlanStatusNeedsReview.fromJson(Map<String, dynamic> json) =>
      _$DayPlanStatusNeedsReviewFromJson(json);

  final DateTime triggeredAt;
  final DayPlanReviewReason reason;

  /// When the plan was last agreed (before this review trigger)
  final DateTime? previouslyAgreedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of DayPlanStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DayPlanStatusNeedsReviewCopyWith<DayPlanStatusNeedsReview> get copyWith =>
      _$DayPlanStatusNeedsReviewCopyWithImpl<DayPlanStatusNeedsReview>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DayPlanStatusNeedsReviewToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DayPlanStatusNeedsReview &&
            (identical(other.triggeredAt, triggeredAt) ||
                other.triggeredAt == triggeredAt) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.previouslyAgreedAt, previouslyAgreedAt) ||
                other.previouslyAgreedAt == previouslyAgreedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, triggeredAt, reason, previouslyAgreedAt);

  @override
  String toString() {
    return 'DayPlanStatus.needsReview(triggeredAt: $triggeredAt, reason: $reason, previouslyAgreedAt: $previouslyAgreedAt)';
  }
}

/// @nodoc
abstract mixin class $DayPlanStatusNeedsReviewCopyWith<$Res>
    implements $DayPlanStatusCopyWith<$Res> {
  factory $DayPlanStatusNeedsReviewCopyWith(DayPlanStatusNeedsReview value,
          $Res Function(DayPlanStatusNeedsReview) _then) =
      _$DayPlanStatusNeedsReviewCopyWithImpl;
  @useResult
  $Res call(
      {DateTime triggeredAt,
      DayPlanReviewReason reason,
      DateTime? previouslyAgreedAt});
}

/// @nodoc
class _$DayPlanStatusNeedsReviewCopyWithImpl<$Res>
    implements $DayPlanStatusNeedsReviewCopyWith<$Res> {
  _$DayPlanStatusNeedsReviewCopyWithImpl(this._self, this._then);

  final DayPlanStatusNeedsReview _self;
  final $Res Function(DayPlanStatusNeedsReview) _then;

  /// Create a copy of DayPlanStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? triggeredAt = null,
    Object? reason = null,
    Object? previouslyAgreedAt = freezed,
  }) {
    return _then(DayPlanStatusNeedsReview(
      triggeredAt: null == triggeredAt
          ? _self.triggeredAt
          : triggeredAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as DayPlanReviewReason,
      previouslyAgreedAt: freezed == previouslyAgreedAt
          ? _self.previouslyAgreedAt
          : previouslyAgreedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
mixin _$PlannedBlock {
  /// UUID for internal reference within the plan
  String get id;

  /// Which category this block is for
  String get categoryId;

  /// When block starts
  DateTime get startTime;

  /// When block ends
  DateTime get endTime;

  /// Optional note on the block
  String? get note;

  /// Create a copy of PlannedBlock
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlannedBlockCopyWith<PlannedBlock> get copyWith =>
      _$PlannedBlockCopyWithImpl<PlannedBlock>(
          this as PlannedBlock, _$identity);

  /// Serializes this PlannedBlock to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlannedBlock &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, categoryId, startTime, endTime, note);

  @override
  String toString() {
    return 'PlannedBlock(id: $id, categoryId: $categoryId, startTime: $startTime, endTime: $endTime, note: $note)';
  }
}

/// @nodoc
abstract mixin class $PlannedBlockCopyWith<$Res> {
  factory $PlannedBlockCopyWith(
          PlannedBlock value, $Res Function(PlannedBlock) _then) =
      _$PlannedBlockCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String categoryId,
      DateTime startTime,
      DateTime endTime,
      String? note});
}

/// @nodoc
class _$PlannedBlockCopyWithImpl<$Res> implements $PlannedBlockCopyWith<$Res> {
  _$PlannedBlockCopyWithImpl(this._self, this._then);

  final PlannedBlock _self;
  final $Res Function(PlannedBlock) _then;

  /// Create a copy of PlannedBlock
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? categoryId = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? note = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _self.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _self.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PlannedBlock].
extension PlannedBlockPatterns on PlannedBlock {
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
    TResult Function(_PlannedBlock value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlannedBlock() when $default != null:
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
    TResult Function(_PlannedBlock value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedBlock():
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
    TResult? Function(_PlannedBlock value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedBlock() when $default != null:
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
    TResult Function(String id, String categoryId, DateTime startTime,
            DateTime endTime, String? note)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PlannedBlock() when $default != null:
        return $default(_that.id, _that.categoryId, _that.startTime,
            _that.endTime, _that.note);
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
    TResult Function(String id, String categoryId, DateTime startTime,
            DateTime endTime, String? note)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedBlock():
        return $default(_that.id, _that.categoryId, _that.startTime,
            _that.endTime, _that.note);
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
    TResult? Function(String id, String categoryId, DateTime startTime,
            DateTime endTime, String? note)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PlannedBlock() when $default != null:
        return $default(_that.id, _that.categoryId, _that.startTime,
            _that.endTime, _that.note);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PlannedBlock implements PlannedBlock {
  const _PlannedBlock(
      {required this.id,
      required this.categoryId,
      required this.startTime,
      required this.endTime,
      this.note});
  factory _PlannedBlock.fromJson(Map<String, dynamic> json) =>
      _$PlannedBlockFromJson(json);

  /// UUID for internal reference within the plan
  @override
  final String id;

  /// Which category this block is for
  @override
  final String categoryId;

  /// When block starts
  @override
  final DateTime startTime;

  /// When block ends
  @override
  final DateTime endTime;

  /// Optional note on the block
  @override
  final String? note;

  /// Create a copy of PlannedBlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PlannedBlockCopyWith<_PlannedBlock> get copyWith =>
      __$PlannedBlockCopyWithImpl<_PlannedBlock>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PlannedBlockToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PlannedBlock &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, categoryId, startTime, endTime, note);

  @override
  String toString() {
    return 'PlannedBlock(id: $id, categoryId: $categoryId, startTime: $startTime, endTime: $endTime, note: $note)';
  }
}

/// @nodoc
abstract mixin class _$PlannedBlockCopyWith<$Res>
    implements $PlannedBlockCopyWith<$Res> {
  factory _$PlannedBlockCopyWith(
          _PlannedBlock value, $Res Function(_PlannedBlock) _then) =
      __$PlannedBlockCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String categoryId,
      DateTime startTime,
      DateTime endTime,
      String? note});
}

/// @nodoc
class __$PlannedBlockCopyWithImpl<$Res>
    implements _$PlannedBlockCopyWith<$Res> {
  __$PlannedBlockCopyWithImpl(this._self, this._then);

  final _PlannedBlock _self;
  final $Res Function(_PlannedBlock) _then;

  /// Create a copy of PlannedBlock
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? categoryId = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? note = freezed,
  }) {
    return _then(_PlannedBlock(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _self.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _self.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$PinnedTaskRef {
  /// References Task entity by ID
  String get taskId;

  /// Which category this task is pinned to
  String get categoryId;

  /// Display order within the category's task list
  int get sortOrder;

  /// Create a copy of PinnedTaskRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PinnedTaskRefCopyWith<PinnedTaskRef> get copyWith =>
      _$PinnedTaskRefCopyWithImpl<PinnedTaskRef>(
          this as PinnedTaskRef, _$identity);

  /// Serializes this PinnedTaskRef to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PinnedTaskRef &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, taskId, categoryId, sortOrder);

  @override
  String toString() {
    return 'PinnedTaskRef(taskId: $taskId, categoryId: $categoryId, sortOrder: $sortOrder)';
  }
}

/// @nodoc
abstract mixin class $PinnedTaskRefCopyWith<$Res> {
  factory $PinnedTaskRefCopyWith(
          PinnedTaskRef value, $Res Function(PinnedTaskRef) _then) =
      _$PinnedTaskRefCopyWithImpl;
  @useResult
  $Res call({String taskId, String categoryId, int sortOrder});
}

/// @nodoc
class _$PinnedTaskRefCopyWithImpl<$Res>
    implements $PinnedTaskRefCopyWith<$Res> {
  _$PinnedTaskRefCopyWithImpl(this._self, this._then);

  final PinnedTaskRef _self;
  final $Res Function(PinnedTaskRef) _then;

  /// Create a copy of PinnedTaskRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? categoryId = null,
    Object? sortOrder = null,
  }) {
    return _then(_self.copyWith(
      taskId: null == taskId
          ? _self.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _self.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [PinnedTaskRef].
extension PinnedTaskRefPatterns on PinnedTaskRef {
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
    TResult Function(_PinnedTaskRef value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PinnedTaskRef() when $default != null:
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
    TResult Function(_PinnedTaskRef value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PinnedTaskRef():
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
    TResult? Function(_PinnedTaskRef value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PinnedTaskRef() when $default != null:
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
    TResult Function(String taskId, String categoryId, int sortOrder)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PinnedTaskRef() when $default != null:
        return $default(_that.taskId, _that.categoryId, _that.sortOrder);
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
    TResult Function(String taskId, String categoryId, int sortOrder) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PinnedTaskRef():
        return $default(_that.taskId, _that.categoryId, _that.sortOrder);
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
    TResult? Function(String taskId, String categoryId, int sortOrder)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PinnedTaskRef() when $default != null:
        return $default(_that.taskId, _that.categoryId, _that.sortOrder);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PinnedTaskRef implements PinnedTaskRef {
  const _PinnedTaskRef(
      {required this.taskId, required this.categoryId, this.sortOrder = 0});
  factory _PinnedTaskRef.fromJson(Map<String, dynamic> json) =>
      _$PinnedTaskRefFromJson(json);

  /// References Task entity by ID
  @override
  final String taskId;

  /// Which category this task is pinned to
  @override
  final String categoryId;

  /// Display order within the category's task list
  @override
  @JsonKey()
  final int sortOrder;

  /// Create a copy of PinnedTaskRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PinnedTaskRefCopyWith<_PinnedTaskRef> get copyWith =>
      __$PinnedTaskRefCopyWithImpl<_PinnedTaskRef>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PinnedTaskRefToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PinnedTaskRef &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, taskId, categoryId, sortOrder);

  @override
  String toString() {
    return 'PinnedTaskRef(taskId: $taskId, categoryId: $categoryId, sortOrder: $sortOrder)';
  }
}

/// @nodoc
abstract mixin class _$PinnedTaskRefCopyWith<$Res>
    implements $PinnedTaskRefCopyWith<$Res> {
  factory _$PinnedTaskRefCopyWith(
          _PinnedTaskRef value, $Res Function(_PinnedTaskRef) _then) =
      __$PinnedTaskRefCopyWithImpl;
  @override
  @useResult
  $Res call({String taskId, String categoryId, int sortOrder});
}

/// @nodoc
class __$PinnedTaskRefCopyWithImpl<$Res>
    implements _$PinnedTaskRefCopyWith<$Res> {
  __$PinnedTaskRefCopyWithImpl(this._self, this._then);

  final _PinnedTaskRef _self;
  final $Res Function(_PinnedTaskRef) _then;

  /// Create a copy of PinnedTaskRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? taskId = null,
    Object? categoryId = null,
    Object? sortOrder = null,
  }) {
    return _then(_PinnedTaskRef(
      taskId: null == taskId
          ? _self.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      categoryId: null == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _self.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$DayPlanData {
  /// The day this plan is for (at midnight local time)
  DateTime get planDate;

  /// Current status of the plan (draft/agreed/needsReview)
  DayPlanStatus get status;

  /// Optional label for the day (e.g., "Focused Workday", "Recovery Day")
  String? get dayLabel;

  /// When the plan was last agreed (convenience field, also in status)
  DateTime? get agreedAt;

  /// When the day was marked complete
  DateTime? get completedAt;

  /// Planned time blocks on the timeline
  List<PlannedBlock> get plannedBlocks;

  /// References to tasks pinned to categories
  List<PinnedTaskRef> get pinnedTasks;

  /// Create a copy of DayPlanData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DayPlanDataCopyWith<DayPlanData> get copyWith =>
      _$DayPlanDataCopyWithImpl<DayPlanData>(this as DayPlanData, _$identity);

  /// Serializes this DayPlanData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DayPlanData &&
            (identical(other.planDate, planDate) ||
                other.planDate == planDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.dayLabel, dayLabel) ||
                other.dayLabel == dayLabel) &&
            (identical(other.agreedAt, agreedAt) ||
                other.agreedAt == agreedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            const DeepCollectionEquality()
                .equals(other.plannedBlocks, plannedBlocks) &&
            const DeepCollectionEquality()
                .equals(other.pinnedTasks, pinnedTasks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      planDate,
      status,
      dayLabel,
      agreedAt,
      completedAt,
      const DeepCollectionEquality().hash(plannedBlocks),
      const DeepCollectionEquality().hash(pinnedTasks));

  @override
  String toString() {
    return 'DayPlanData(planDate: $planDate, status: $status, dayLabel: $dayLabel, agreedAt: $agreedAt, completedAt: $completedAt, plannedBlocks: $plannedBlocks, pinnedTasks: $pinnedTasks)';
  }
}

/// @nodoc
abstract mixin class $DayPlanDataCopyWith<$Res> {
  factory $DayPlanDataCopyWith(
          DayPlanData value, $Res Function(DayPlanData) _then) =
      _$DayPlanDataCopyWithImpl;
  @useResult
  $Res call(
      {DateTime planDate,
      DayPlanStatus status,
      String? dayLabel,
      DateTime? agreedAt,
      DateTime? completedAt,
      List<PlannedBlock> plannedBlocks,
      List<PinnedTaskRef> pinnedTasks});

  $DayPlanStatusCopyWith<$Res> get status;
}

/// @nodoc
class _$DayPlanDataCopyWithImpl<$Res> implements $DayPlanDataCopyWith<$Res> {
  _$DayPlanDataCopyWithImpl(this._self, this._then);

  final DayPlanData _self;
  final $Res Function(DayPlanData) _then;

  /// Create a copy of DayPlanData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? planDate = null,
    Object? status = null,
    Object? dayLabel = freezed,
    Object? agreedAt = freezed,
    Object? completedAt = freezed,
    Object? plannedBlocks = null,
    Object? pinnedTasks = null,
  }) {
    return _then(_self.copyWith(
      planDate: null == planDate
          ? _self.planDate
          : planDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as DayPlanStatus,
      dayLabel: freezed == dayLabel
          ? _self.dayLabel
          : dayLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      agreedAt: freezed == agreedAt
          ? _self.agreedAt
          : agreedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      plannedBlocks: null == plannedBlocks
          ? _self.plannedBlocks
          : plannedBlocks // ignore: cast_nullable_to_non_nullable
              as List<PlannedBlock>,
      pinnedTasks: null == pinnedTasks
          ? _self.pinnedTasks
          : pinnedTasks // ignore: cast_nullable_to_non_nullable
              as List<PinnedTaskRef>,
    ));
  }

  /// Create a copy of DayPlanData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DayPlanStatusCopyWith<$Res> get status {
    return $DayPlanStatusCopyWith<$Res>(_self.status, (value) {
      return _then(_self.copyWith(status: value));
    });
  }
}

/// Adds pattern-matching-related methods to [DayPlanData].
extension DayPlanDataPatterns on DayPlanData {
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
    TResult Function(_DayPlanData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DayPlanData() when $default != null:
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
    TResult Function(_DayPlanData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayPlanData():
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
    TResult? Function(_DayPlanData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayPlanData() when $default != null:
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
            DateTime planDate,
            DayPlanStatus status,
            String? dayLabel,
            DateTime? agreedAt,
            DateTime? completedAt,
            List<PlannedBlock> plannedBlocks,
            List<PinnedTaskRef> pinnedTasks)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DayPlanData() when $default != null:
        return $default(
            _that.planDate,
            _that.status,
            _that.dayLabel,
            _that.agreedAt,
            _that.completedAt,
            _that.plannedBlocks,
            _that.pinnedTasks);
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
            DateTime planDate,
            DayPlanStatus status,
            String? dayLabel,
            DateTime? agreedAt,
            DateTime? completedAt,
            List<PlannedBlock> plannedBlocks,
            List<PinnedTaskRef> pinnedTasks)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayPlanData():
        return $default(
            _that.planDate,
            _that.status,
            _that.dayLabel,
            _that.agreedAt,
            _that.completedAt,
            _that.plannedBlocks,
            _that.pinnedTasks);
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
            DateTime planDate,
            DayPlanStatus status,
            String? dayLabel,
            DateTime? agreedAt,
            DateTime? completedAt,
            List<PlannedBlock> plannedBlocks,
            List<PinnedTaskRef> pinnedTasks)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DayPlanData() when $default != null:
        return $default(
            _that.planDate,
            _that.status,
            _that.dayLabel,
            _that.agreedAt,
            _that.completedAt,
            _that.plannedBlocks,
            _that.pinnedTasks);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DayPlanData implements DayPlanData {
  const _DayPlanData(
      {required this.planDate,
      required this.status,
      this.dayLabel,
      this.agreedAt,
      this.completedAt,
      final List<PlannedBlock> plannedBlocks = const [],
      final List<PinnedTaskRef> pinnedTasks = const []})
      : _plannedBlocks = plannedBlocks,
        _pinnedTasks = pinnedTasks;
  factory _DayPlanData.fromJson(Map<String, dynamic> json) =>
      _$DayPlanDataFromJson(json);

  /// The day this plan is for (at midnight local time)
  @override
  final DateTime planDate;

  /// Current status of the plan (draft/agreed/needsReview)
  @override
  final DayPlanStatus status;

  /// Optional label for the day (e.g., "Focused Workday", "Recovery Day")
  @override
  final String? dayLabel;

  /// When the plan was last agreed (convenience field, also in status)
  @override
  final DateTime? agreedAt;

  /// When the day was marked complete
  @override
  final DateTime? completedAt;

  /// Planned time blocks on the timeline
  final List<PlannedBlock> _plannedBlocks;

  /// Planned time blocks on the timeline
  @override
  @JsonKey()
  List<PlannedBlock> get plannedBlocks {
    if (_plannedBlocks is EqualUnmodifiableListView) return _plannedBlocks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_plannedBlocks);
  }

  /// References to tasks pinned to categories
  final List<PinnedTaskRef> _pinnedTasks;

  /// References to tasks pinned to categories
  @override
  @JsonKey()
  List<PinnedTaskRef> get pinnedTasks {
    if (_pinnedTasks is EqualUnmodifiableListView) return _pinnedTasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pinnedTasks);
  }

  /// Create a copy of DayPlanData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DayPlanDataCopyWith<_DayPlanData> get copyWith =>
      __$DayPlanDataCopyWithImpl<_DayPlanData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DayPlanDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DayPlanData &&
            (identical(other.planDate, planDate) ||
                other.planDate == planDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.dayLabel, dayLabel) ||
                other.dayLabel == dayLabel) &&
            (identical(other.agreedAt, agreedAt) ||
                other.agreedAt == agreedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            const DeepCollectionEquality()
                .equals(other._plannedBlocks, _plannedBlocks) &&
            const DeepCollectionEquality()
                .equals(other._pinnedTasks, _pinnedTasks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      planDate,
      status,
      dayLabel,
      agreedAt,
      completedAt,
      const DeepCollectionEquality().hash(_plannedBlocks),
      const DeepCollectionEquality().hash(_pinnedTasks));

  @override
  String toString() {
    return 'DayPlanData(planDate: $planDate, status: $status, dayLabel: $dayLabel, agreedAt: $agreedAt, completedAt: $completedAt, plannedBlocks: $plannedBlocks, pinnedTasks: $pinnedTasks)';
  }
}

/// @nodoc
abstract mixin class _$DayPlanDataCopyWith<$Res>
    implements $DayPlanDataCopyWith<$Res> {
  factory _$DayPlanDataCopyWith(
          _DayPlanData value, $Res Function(_DayPlanData) _then) =
      __$DayPlanDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime planDate,
      DayPlanStatus status,
      String? dayLabel,
      DateTime? agreedAt,
      DateTime? completedAt,
      List<PlannedBlock> plannedBlocks,
      List<PinnedTaskRef> pinnedTasks});

  @override
  $DayPlanStatusCopyWith<$Res> get status;
}

/// @nodoc
class __$DayPlanDataCopyWithImpl<$Res> implements _$DayPlanDataCopyWith<$Res> {
  __$DayPlanDataCopyWithImpl(this._self, this._then);

  final _DayPlanData _self;
  final $Res Function(_DayPlanData) _then;

  /// Create a copy of DayPlanData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? planDate = null,
    Object? status = null,
    Object? dayLabel = freezed,
    Object? agreedAt = freezed,
    Object? completedAt = freezed,
    Object? plannedBlocks = null,
    Object? pinnedTasks = null,
  }) {
    return _then(_DayPlanData(
      planDate: null == planDate
          ? _self.planDate
          : planDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as DayPlanStatus,
      dayLabel: freezed == dayLabel
          ? _self.dayLabel
          : dayLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      agreedAt: freezed == agreedAt
          ? _self.agreedAt
          : agreedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _self.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      plannedBlocks: null == plannedBlocks
          ? _self._plannedBlocks
          : plannedBlocks // ignore: cast_nullable_to_non_nullable
              as List<PlannedBlock>,
      pinnedTasks: null == pinnedTasks
          ? _self._pinnedTasks
          : pinnedTasks // ignore: cast_nullable_to_non_nullable
              as List<PinnedTaskRef>,
    ));
  }

  /// Create a copy of DayPlanData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DayPlanStatusCopyWith<$Res> get status {
    return $DayPlanStatusCopyWith<$Res>(_self.status, (value) {
      return _then(_self.copyWith(status: value));
    });
  }
}

// dart format on
