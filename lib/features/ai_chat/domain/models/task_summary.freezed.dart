// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TaskSummary _$TaskSummaryFromJson(Map<String, dynamic> json) {
  return _TaskSummary.fromJson(json);
}

/// @nodoc
mixin _$TaskSummary {
  String get taskId => throw _privateConstructorUsedError;
  String get taskName => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  String? get categoryId => throw _privateConstructorUsedError;
  String? get categoryName => throw _privateConstructorUsedError;
  List<String>? get tags => throw _privateConstructorUsedError;
  String? get aiSummary => throw _privateConstructorUsedError;
  Duration? get timeLogged => throw _privateConstructorUsedError;
  TaskStatus? get status => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this TaskSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskSummaryCopyWith<TaskSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskSummaryCopyWith<$Res> {
  factory $TaskSummaryCopyWith(
          TaskSummary value, $Res Function(TaskSummary) then) =
      _$TaskSummaryCopyWithImpl<$Res, TaskSummary>;
  @useResult
  $Res call(
      {String taskId,
      String taskName,
      DateTime createdAt,
      DateTime? completedAt,
      String? categoryId,
      String? categoryName,
      List<String>? tags,
      String? aiSummary,
      Duration? timeLogged,
      TaskStatus? status,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$TaskSummaryCopyWithImpl<$Res, $Val extends TaskSummary>
    implements $TaskSummaryCopyWith<$Res> {
  _$TaskSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? taskName = null,
    Object? createdAt = null,
    Object? completedAt = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? tags = freezed,
    Object? aiSummary = freezed,
    Object? timeLogged = freezed,
    Object? status = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      taskName: null == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      aiSummary: freezed == aiSummary
          ? _value.aiSummary
          : aiSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      timeLogged: freezed == timeLogged
          ? _value.timeLogged
          : timeLogged // ignore: cast_nullable_to_non_nullable
              as Duration?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskSummaryImplCopyWith<$Res>
    implements $TaskSummaryCopyWith<$Res> {
  factory _$$TaskSummaryImplCopyWith(
          _$TaskSummaryImpl value, $Res Function(_$TaskSummaryImpl) then) =
      __$$TaskSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String taskId,
      String taskName,
      DateTime createdAt,
      DateTime? completedAt,
      String? categoryId,
      String? categoryName,
      List<String>? tags,
      String? aiSummary,
      Duration? timeLogged,
      TaskStatus? status,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$TaskSummaryImplCopyWithImpl<$Res>
    extends _$TaskSummaryCopyWithImpl<$Res, _$TaskSummaryImpl>
    implements _$$TaskSummaryImplCopyWith<$Res> {
  __$$TaskSummaryImplCopyWithImpl(
      _$TaskSummaryImpl _value, $Res Function(_$TaskSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? taskName = null,
    Object? createdAt = null,
    Object? completedAt = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? tags = freezed,
    Object? aiSummary = freezed,
    Object? timeLogged = freezed,
    Object? status = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$TaskSummaryImpl(
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      taskName: null == taskName
          ? _value.taskName
          : taskName // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryName: freezed == categoryName
          ? _value.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: freezed == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      aiSummary: freezed == aiSummary
          ? _value.aiSummary
          : aiSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      timeLogged: freezed == timeLogged
          ? _value.timeLogged
          : timeLogged // ignore: cast_nullable_to_non_nullable
              as Duration?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskSummaryImpl implements _TaskSummary {
  const _$TaskSummaryImpl(
      {required this.taskId,
      required this.taskName,
      required this.createdAt,
      this.completedAt,
      this.categoryId,
      this.categoryName,
      final List<String>? tags,
      this.aiSummary,
      this.timeLogged,
      this.status,
      final Map<String, dynamic>? metadata})
      : _tags = tags,
        _metadata = metadata;

  factory _$TaskSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskSummaryImplFromJson(json);

  @override
  final String taskId;
  @override
  final String taskName;
  @override
  final DateTime createdAt;
  @override
  final DateTime? completedAt;
  @override
  final String? categoryId;
  @override
  final String? categoryName;
  final List<String>? _tags;
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? aiSummary;
  @override
  final Duration? timeLogged;
  @override
  final TaskStatus? status;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'TaskSummary(taskId: $taskId, taskName: $taskName, createdAt: $createdAt, completedAt: $completedAt, categoryId: $categoryId, categoryName: $categoryName, tags: $tags, aiSummary: $aiSummary, timeLogged: $timeLogged, status: $status, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskSummaryImpl &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.aiSummary, aiSummary) ||
                other.aiSummary == aiSummary) &&
            (identical(other.timeLogged, timeLogged) ||
                other.timeLogged == timeLogged) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      taskId,
      taskName,
      createdAt,
      completedAt,
      categoryId,
      categoryName,
      const DeepCollectionEquality().hash(_tags),
      aiSummary,
      timeLogged,
      status,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of TaskSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskSummaryImplCopyWith<_$TaskSummaryImpl> get copyWith =>
      __$$TaskSummaryImplCopyWithImpl<_$TaskSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskSummaryImplToJson(
      this,
    );
  }
}

abstract class _TaskSummary implements TaskSummary {
  const factory _TaskSummary(
      {required final String taskId,
      required final String taskName,
      required final DateTime createdAt,
      final DateTime? completedAt,
      final String? categoryId,
      final String? categoryName,
      final List<String>? tags,
      final String? aiSummary,
      final Duration? timeLogged,
      final TaskStatus? status,
      final Map<String, dynamic>? metadata}) = _$TaskSummaryImpl;

  factory _TaskSummary.fromJson(Map<String, dynamic> json) =
      _$TaskSummaryImpl.fromJson;

  @override
  String get taskId;
  @override
  String get taskName;
  @override
  DateTime get createdAt;
  @override
  DateTime? get completedAt;
  @override
  String? get categoryId;
  @override
  String? get categoryName;
  @override
  List<String>? get tags;
  @override
  String? get aiSummary;
  @override
  Duration? get timeLogged;
  @override
  TaskStatus? get status;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of TaskSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskSummaryImplCopyWith<_$TaskSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TaskSummaryResult _$TaskSummaryResultFromJson(Map<String, dynamic> json) {
  return _TaskSummaryResult.fromJson(json);
}

/// @nodoc
mixin _$TaskSummaryResult {
  List<TaskSummary> get tasks => throw _privateConstructorUsedError;
  DateTime get queryStartDate => throw _privateConstructorUsedError;
  DateTime get queryEndDate => throw _privateConstructorUsedError;
  int get totalCount => throw _privateConstructorUsedError;
  int? get limitApplied => throw _privateConstructorUsedError;
  List<String>? get categoriesQueried => throw _privateConstructorUsedError;
  List<String>? get tagsQueried => throw _privateConstructorUsedError;

  /// Serializes this TaskSummaryResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskSummaryResultCopyWith<TaskSummaryResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskSummaryResultCopyWith<$Res> {
  factory $TaskSummaryResultCopyWith(
          TaskSummaryResult value, $Res Function(TaskSummaryResult) then) =
      _$TaskSummaryResultCopyWithImpl<$Res, TaskSummaryResult>;
  @useResult
  $Res call(
      {List<TaskSummary> tasks,
      DateTime queryStartDate,
      DateTime queryEndDate,
      int totalCount,
      int? limitApplied,
      List<String>? categoriesQueried,
      List<String>? tagsQueried});
}

/// @nodoc
class _$TaskSummaryResultCopyWithImpl<$Res, $Val extends TaskSummaryResult>
    implements $TaskSummaryResultCopyWith<$Res> {
  _$TaskSummaryResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tasks = null,
    Object? queryStartDate = null,
    Object? queryEndDate = null,
    Object? totalCount = null,
    Object? limitApplied = freezed,
    Object? categoriesQueried = freezed,
    Object? tagsQueried = freezed,
  }) {
    return _then(_value.copyWith(
      tasks: null == tasks
          ? _value.tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<TaskSummary>,
      queryStartDate: null == queryStartDate
          ? _value.queryStartDate
          : queryStartDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      queryEndDate: null == queryEndDate
          ? _value.queryEndDate
          : queryEndDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
      limitApplied: freezed == limitApplied
          ? _value.limitApplied
          : limitApplied // ignore: cast_nullable_to_non_nullable
              as int?,
      categoriesQueried: freezed == categoriesQueried
          ? _value.categoriesQueried
          : categoriesQueried // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagsQueried: freezed == tagsQueried
          ? _value.tagsQueried
          : tagsQueried // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskSummaryResultImplCopyWith<$Res>
    implements $TaskSummaryResultCopyWith<$Res> {
  factory _$$TaskSummaryResultImplCopyWith(_$TaskSummaryResultImpl value,
          $Res Function(_$TaskSummaryResultImpl) then) =
      __$$TaskSummaryResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<TaskSummary> tasks,
      DateTime queryStartDate,
      DateTime queryEndDate,
      int totalCount,
      int? limitApplied,
      List<String>? categoriesQueried,
      List<String>? tagsQueried});
}

/// @nodoc
class __$$TaskSummaryResultImplCopyWithImpl<$Res>
    extends _$TaskSummaryResultCopyWithImpl<$Res, _$TaskSummaryResultImpl>
    implements _$$TaskSummaryResultImplCopyWith<$Res> {
  __$$TaskSummaryResultImplCopyWithImpl(_$TaskSummaryResultImpl _value,
      $Res Function(_$TaskSummaryResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tasks = null,
    Object? queryStartDate = null,
    Object? queryEndDate = null,
    Object? totalCount = null,
    Object? limitApplied = freezed,
    Object? categoriesQueried = freezed,
    Object? tagsQueried = freezed,
  }) {
    return _then(_$TaskSummaryResultImpl(
      tasks: null == tasks
          ? _value._tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<TaskSummary>,
      queryStartDate: null == queryStartDate
          ? _value.queryStartDate
          : queryStartDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      queryEndDate: null == queryEndDate
          ? _value.queryEndDate
          : queryEndDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      totalCount: null == totalCount
          ? _value.totalCount
          : totalCount // ignore: cast_nullable_to_non_nullable
              as int,
      limitApplied: freezed == limitApplied
          ? _value.limitApplied
          : limitApplied // ignore: cast_nullable_to_non_nullable
              as int?,
      categoriesQueried: freezed == categoriesQueried
          ? _value._categoriesQueried
          : categoriesQueried // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagsQueried: freezed == tagsQueried
          ? _value._tagsQueried
          : tagsQueried // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskSummaryResultImpl implements _TaskSummaryResult {
  const _$TaskSummaryResultImpl(
      {required final List<TaskSummary> tasks,
      required this.queryStartDate,
      required this.queryEndDate,
      required this.totalCount,
      this.limitApplied,
      final List<String>? categoriesQueried,
      final List<String>? tagsQueried})
      : _tasks = tasks,
        _categoriesQueried = categoriesQueried,
        _tagsQueried = tagsQueried;

  factory _$TaskSummaryResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskSummaryResultImplFromJson(json);

  final List<TaskSummary> _tasks;
  @override
  List<TaskSummary> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  @override
  final DateTime queryStartDate;
  @override
  final DateTime queryEndDate;
  @override
  final int totalCount;
  @override
  final int? limitApplied;
  final List<String>? _categoriesQueried;
  @override
  List<String>? get categoriesQueried {
    final value = _categoriesQueried;
    if (value == null) return null;
    if (_categoriesQueried is EqualUnmodifiableListView)
      return _categoriesQueried;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _tagsQueried;
  @override
  List<String>? get tagsQueried {
    final value = _tagsQueried;
    if (value == null) return null;
    if (_tagsQueried is EqualUnmodifiableListView) return _tagsQueried;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'TaskSummaryResult(tasks: $tasks, queryStartDate: $queryStartDate, queryEndDate: $queryEndDate, totalCount: $totalCount, limitApplied: $limitApplied, categoriesQueried: $categoriesQueried, tagsQueried: $tagsQueried)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskSummaryResultImpl &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.queryStartDate, queryStartDate) ||
                other.queryStartDate == queryStartDate) &&
            (identical(other.queryEndDate, queryEndDate) ||
                other.queryEndDate == queryEndDate) &&
            (identical(other.totalCount, totalCount) ||
                other.totalCount == totalCount) &&
            (identical(other.limitApplied, limitApplied) ||
                other.limitApplied == limitApplied) &&
            const DeepCollectionEquality()
                .equals(other._categoriesQueried, _categoriesQueried) &&
            const DeepCollectionEquality()
                .equals(other._tagsQueried, _tagsQueried));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_tasks),
      queryStartDate,
      queryEndDate,
      totalCount,
      limitApplied,
      const DeepCollectionEquality().hash(_categoriesQueried),
      const DeepCollectionEquality().hash(_tagsQueried));

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskSummaryResultImplCopyWith<_$TaskSummaryResultImpl> get copyWith =>
      __$$TaskSummaryResultImplCopyWithImpl<_$TaskSummaryResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskSummaryResultImplToJson(
      this,
    );
  }
}

abstract class _TaskSummaryResult implements TaskSummaryResult {
  const factory _TaskSummaryResult(
      {required final List<TaskSummary> tasks,
      required final DateTime queryStartDate,
      required final DateTime queryEndDate,
      required final int totalCount,
      final int? limitApplied,
      final List<String>? categoriesQueried,
      final List<String>? tagsQueried}) = _$TaskSummaryResultImpl;

  factory _TaskSummaryResult.fromJson(Map<String, dynamic> json) =
      _$TaskSummaryResultImpl.fromJson;

  @override
  List<TaskSummary> get tasks;
  @override
  DateTime get queryStartDate;
  @override
  DateTime get queryEndDate;
  @override
  int get totalCount;
  @override
  int? get limitApplied;
  @override
  List<String>? get categoriesQueried;
  @override
  List<String>? get tagsQueried;

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskSummaryResultImplCopyWith<_$TaskSummaryResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
