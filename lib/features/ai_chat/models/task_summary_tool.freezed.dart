// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_summary_tool.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskSummaryRequest {
  @JsonKey(name: 'start_date')
  String get startDate;
  @JsonKey(name: 'end_date')
  String get endDate;
  int get limit;

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskSummaryRequestCopyWith<TaskSummaryRequest> get copyWith =>
      _$TaskSummaryRequestCopyWithImpl<TaskSummaryRequest>(
          this as TaskSummaryRequest, _$identity);

  /// Serializes this TaskSummaryRequest to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskSummaryRequest &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.limit, limit) || other.limit == limit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, startDate, endDate, limit);

  @override
  String toString() {
    return 'TaskSummaryRequest(startDate: $startDate, endDate: $endDate, limit: $limit)';
  }
}

/// @nodoc
abstract mixin class $TaskSummaryRequestCopyWith<$Res> {
  factory $TaskSummaryRequestCopyWith(
          TaskSummaryRequest value, $Res Function(TaskSummaryRequest) _then) =
      _$TaskSummaryRequestCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'start_date') String startDate,
      @JsonKey(name: 'end_date') String endDate,
      int limit});
}

/// @nodoc
class _$TaskSummaryRequestCopyWithImpl<$Res>
    implements $TaskSummaryRequestCopyWith<$Res> {
  _$TaskSummaryRequestCopyWithImpl(this._self, this._then);

  final TaskSummaryRequest _self;
  final $Res Function(TaskSummaryRequest) _then;

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? limit = null,
  }) {
    return _then(_self.copyWith(
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as String,
      endDate: null == endDate
          ? _self.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as String,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [TaskSummaryRequest].
extension TaskSummaryRequestPatterns on TaskSummaryRequest {
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
    TResult Function(_TaskSummaryRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryRequest() when $default != null:
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
    TResult Function(_TaskSummaryRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryRequest():
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
    TResult? Function(_TaskSummaryRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryRequest() when $default != null:
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
    TResult Function(@JsonKey(name: 'start_date') String startDate,
            @JsonKey(name: 'end_date') String endDate, int limit)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryRequest() when $default != null:
        return $default(_that.startDate, _that.endDate, _that.limit);
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
    TResult Function(@JsonKey(name: 'start_date') String startDate,
            @JsonKey(name: 'end_date') String endDate, int limit)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryRequest():
        return $default(_that.startDate, _that.endDate, _that.limit);
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
    TResult? Function(@JsonKey(name: 'start_date') String startDate,
            @JsonKey(name: 'end_date') String endDate, int limit)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryRequest() when $default != null:
        return $default(_that.startDate, _that.endDate, _that.limit);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TaskSummaryRequest implements TaskSummaryRequest {
  const _TaskSummaryRequest(
      {@JsonKey(name: 'start_date') required this.startDate,
      @JsonKey(name: 'end_date') required this.endDate,
      this.limit = 100});
  factory _TaskSummaryRequest.fromJson(Map<String, dynamic> json) =>
      _$TaskSummaryRequestFromJson(json);

  @override
  @JsonKey(name: 'start_date')
  final String startDate;
  @override
  @JsonKey(name: 'end_date')
  final String endDate;
  @override
  @JsonKey()
  final int limit;

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskSummaryRequestCopyWith<_TaskSummaryRequest> get copyWith =>
      __$TaskSummaryRequestCopyWithImpl<_TaskSummaryRequest>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskSummaryRequestToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TaskSummaryRequest &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.limit, limit) || other.limit == limit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, startDate, endDate, limit);

  @override
  String toString() {
    return 'TaskSummaryRequest(startDate: $startDate, endDate: $endDate, limit: $limit)';
  }
}

/// @nodoc
abstract mixin class _$TaskSummaryRequestCopyWith<$Res>
    implements $TaskSummaryRequestCopyWith<$Res> {
  factory _$TaskSummaryRequestCopyWith(
          _TaskSummaryRequest value, $Res Function(_TaskSummaryRequest) _then) =
      __$TaskSummaryRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'start_date') String startDate,
      @JsonKey(name: 'end_date') String endDate,
      int limit});
}

/// @nodoc
class __$TaskSummaryRequestCopyWithImpl<$Res>
    implements _$TaskSummaryRequestCopyWith<$Res> {
  __$TaskSummaryRequestCopyWithImpl(this._self, this._then);

  final _TaskSummaryRequest _self;
  final $Res Function(_TaskSummaryRequest) _then;

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? limit = null,
  }) {
    return _then(_TaskSummaryRequest(
      startDate: null == startDate
          ? _self.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as String,
      endDate: null == endDate
          ? _self.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as String,
      limit: null == limit
          ? _self.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$TaskSummaryResult {
  String get taskId;
  String get taskTitle;
  String get summary;
  DateTime get taskDate;
  String get status;
  Map<String, dynamic>? get metadata;

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskSummaryResultCopyWith<TaskSummaryResult> get copyWith =>
      _$TaskSummaryResultCopyWithImpl<TaskSummaryResult>(
          this as TaskSummaryResult, _$identity);

  /// Serializes this TaskSummaryResult to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskSummaryResult &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.taskTitle, taskTitle) ||
                other.taskTitle == taskTitle) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.taskDate, taskDate) ||
                other.taskDate == taskDate) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.metadata, metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, taskId, taskTitle, summary,
      taskDate, status, const DeepCollectionEquality().hash(metadata));

  @override
  String toString() {
    return 'TaskSummaryResult(taskId: $taskId, taskTitle: $taskTitle, summary: $summary, taskDate: $taskDate, status: $status, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class $TaskSummaryResultCopyWith<$Res> {
  factory $TaskSummaryResultCopyWith(
          TaskSummaryResult value, $Res Function(TaskSummaryResult) _then) =
      _$TaskSummaryResultCopyWithImpl;
  @useResult
  $Res call(
      {String taskId,
      String taskTitle,
      String summary,
      DateTime taskDate,
      String status,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$TaskSummaryResultCopyWithImpl<$Res>
    implements $TaskSummaryResultCopyWith<$Res> {
  _$TaskSummaryResultCopyWithImpl(this._self, this._then);

  final TaskSummaryResult _self;
  final $Res Function(TaskSummaryResult) _then;

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? taskTitle = null,
    Object? summary = null,
    Object? taskDate = null,
    Object? status = null,
    Object? metadata = freezed,
  }) {
    return _then(_self.copyWith(
      taskId: null == taskId
          ? _self.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      taskTitle: null == taskTitle
          ? _self.taskTitle
          : taskTitle // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      taskDate: null == taskDate
          ? _self.taskDate
          : taskDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: freezed == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [TaskSummaryResult].
extension TaskSummaryResultPatterns on TaskSummaryResult {
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
    TResult Function(_TaskSummaryResult value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryResult() when $default != null:
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
    TResult Function(_TaskSummaryResult value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryResult():
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
    TResult? Function(_TaskSummaryResult value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryResult() when $default != null:
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
    TResult Function(String taskId, String taskTitle, String summary,
            DateTime taskDate, String status, Map<String, dynamic>? metadata)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryResult() when $default != null:
        return $default(_that.taskId, _that.taskTitle, _that.summary,
            _that.taskDate, _that.status, _that.metadata);
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
    TResult Function(String taskId, String taskTitle, String summary,
            DateTime taskDate, String status, Map<String, dynamic>? metadata)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryResult():
        return $default(_that.taskId, _that.taskTitle, _that.summary,
            _that.taskDate, _that.status, _that.metadata);
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
    TResult? Function(String taskId, String taskTitle, String summary,
            DateTime taskDate, String status, Map<String, dynamic>? metadata)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskSummaryResult() when $default != null:
        return $default(_that.taskId, _that.taskTitle, _that.summary,
            _that.taskDate, _that.status, _that.metadata);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TaskSummaryResult implements TaskSummaryResult {
  const _TaskSummaryResult(
      {required this.taskId,
      required this.taskTitle,
      required this.summary,
      required this.taskDate,
      required this.status,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;
  factory _TaskSummaryResult.fromJson(Map<String, dynamic> json) =>
      _$TaskSummaryResultFromJson(json);

  @override
  final String taskId;
  @override
  final String taskTitle;
  @override
  final String summary;
  @override
  final DateTime taskDate;
  @override
  final String status;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskSummaryResultCopyWith<_TaskSummaryResult> get copyWith =>
      __$TaskSummaryResultCopyWithImpl<_TaskSummaryResult>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskSummaryResultToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TaskSummaryResult &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.taskTitle, taskTitle) ||
                other.taskTitle == taskTitle) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.taskDate, taskDate) ||
                other.taskDate == taskDate) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, taskId, taskTitle, summary,
      taskDate, status, const DeepCollectionEquality().hash(_metadata));

  @override
  String toString() {
    return 'TaskSummaryResult(taskId: $taskId, taskTitle: $taskTitle, summary: $summary, taskDate: $taskDate, status: $status, metadata: $metadata)';
  }
}

/// @nodoc
abstract mixin class _$TaskSummaryResultCopyWith<$Res>
    implements $TaskSummaryResultCopyWith<$Res> {
  factory _$TaskSummaryResultCopyWith(
          _TaskSummaryResult value, $Res Function(_TaskSummaryResult) _then) =
      __$TaskSummaryResultCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String taskId,
      String taskTitle,
      String summary,
      DateTime taskDate,
      String status,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$TaskSummaryResultCopyWithImpl<$Res>
    implements _$TaskSummaryResultCopyWith<$Res> {
  __$TaskSummaryResultCopyWithImpl(this._self, this._then);

  final _TaskSummaryResult _self;
  final $Res Function(_TaskSummaryResult) _then;

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? taskId = null,
    Object? taskTitle = null,
    Object? summary = null,
    Object? taskDate = null,
    Object? status = null,
    Object? metadata = freezed,
  }) {
    return _then(_TaskSummaryResult(
      taskId: null == taskId
          ? _self.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      taskTitle: null == taskTitle
          ? _self.taskTitle
          : taskTitle // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      taskDate: null == taskDate
          ? _self.taskDate
          : taskDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: freezed == metadata
          ? _self._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

// dart format on
