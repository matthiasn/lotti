// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_summary_tool.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TaskSummaryRequest _$TaskSummaryRequestFromJson(Map<String, dynamic> json) {
  return _TaskSummaryRequest.fromJson(json);
}

/// @nodoc
mixin _$TaskSummaryRequest {
  @JsonKey(name: 'start_date')
  DateTime get startDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_date')
  DateTime get endDate => throw _privateConstructorUsedError;
  int get limit => throw _privateConstructorUsedError;

  /// Serializes this TaskSummaryRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskSummaryRequestCopyWith<TaskSummaryRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskSummaryRequestCopyWith<$Res> {
  factory $TaskSummaryRequestCopyWith(
          TaskSummaryRequest value, $Res Function(TaskSummaryRequest) then) =
      _$TaskSummaryRequestCopyWithImpl<$Res, TaskSummaryRequest>;
  @useResult
  $Res call(
      {@JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'end_date') DateTime endDate,
      int limit});
}

/// @nodoc
class _$TaskSummaryRequestCopyWithImpl<$Res, $Val extends TaskSummaryRequest>
    implements $TaskSummaryRequestCopyWith<$Res> {
  _$TaskSummaryRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? limit = null,
  }) {
    return _then(_value.copyWith(
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskSummaryRequestImplCopyWith<$Res>
    implements $TaskSummaryRequestCopyWith<$Res> {
  factory _$$TaskSummaryRequestImplCopyWith(_$TaskSummaryRequestImpl value,
          $Res Function(_$TaskSummaryRequestImpl) then) =
      __$$TaskSummaryRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'start_date') DateTime startDate,
      @JsonKey(name: 'end_date') DateTime endDate,
      int limit});
}

/// @nodoc
class __$$TaskSummaryRequestImplCopyWithImpl<$Res>
    extends _$TaskSummaryRequestCopyWithImpl<$Res, _$TaskSummaryRequestImpl>
    implements _$$TaskSummaryRequestImplCopyWith<$Res> {
  __$$TaskSummaryRequestImplCopyWithImpl(_$TaskSummaryRequestImpl _value,
      $Res Function(_$TaskSummaryRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? limit = null,
  }) {
    return _then(_$TaskSummaryRequestImpl(
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskSummaryRequestImpl implements _TaskSummaryRequest {
  const _$TaskSummaryRequestImpl(
      {@JsonKey(name: 'start_date') required this.startDate,
      @JsonKey(name: 'end_date') required this.endDate,
      this.limit = 100});

  factory _$TaskSummaryRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskSummaryRequestImplFromJson(json);

  @override
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @override
  @JsonKey(name: 'end_date')
  final DateTime endDate;
  @override
  @JsonKey()
  final int limit;

  @override
  String toString() {
    return 'TaskSummaryRequest(startDate: $startDate, endDate: $endDate, limit: $limit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskSummaryRequestImpl &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.limit, limit) || other.limit == limit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, startDate, endDate, limit);

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskSummaryRequestImplCopyWith<_$TaskSummaryRequestImpl> get copyWith =>
      __$$TaskSummaryRequestImplCopyWithImpl<_$TaskSummaryRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskSummaryRequestImplToJson(
      this,
    );
  }
}

abstract class _TaskSummaryRequest implements TaskSummaryRequest {
  const factory _TaskSummaryRequest(
      {@JsonKey(name: 'start_date') required final DateTime startDate,
      @JsonKey(name: 'end_date') required final DateTime endDate,
      final int limit}) = _$TaskSummaryRequestImpl;

  factory _TaskSummaryRequest.fromJson(Map<String, dynamic> json) =
      _$TaskSummaryRequestImpl.fromJson;

  @override
  @JsonKey(name: 'start_date')
  DateTime get startDate;
  @override
  @JsonKey(name: 'end_date')
  DateTime get endDate;
  @override
  int get limit;

  /// Create a copy of TaskSummaryRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskSummaryRequestImplCopyWith<_$TaskSummaryRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TaskSummaryResult _$TaskSummaryResultFromJson(Map<String, dynamic> json) {
  return _TaskSummaryResult.fromJson(json);
}

/// @nodoc
mixin _$TaskSummaryResult {
  String get taskId => throw _privateConstructorUsedError;
  String get taskTitle => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  DateTime get taskDate => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

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
      {String taskId,
      String taskTitle,
      String summary,
      DateTime taskDate,
      String status,
      Map<String, dynamic>? metadata});
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
    Object? taskId = null,
    Object? taskTitle = null,
    Object? summary = null,
    Object? taskDate = null,
    Object? status = null,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      taskTitle: null == taskTitle
          ? _value.taskTitle
          : taskTitle // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      taskDate: null == taskDate
          ? _value.taskDate
          : taskDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
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
      {String taskId,
      String taskTitle,
      String summary,
      DateTime taskDate,
      String status,
      Map<String, dynamic>? metadata});
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
    Object? taskId = null,
    Object? taskTitle = null,
    Object? summary = null,
    Object? taskDate = null,
    Object? status = null,
    Object? metadata = freezed,
  }) {
    return _then(_$TaskSummaryResultImpl(
      taskId: null == taskId
          ? _value.taskId
          : taskId // ignore: cast_nullable_to_non_nullable
              as String,
      taskTitle: null == taskTitle
          ? _value.taskTitle
          : taskTitle // ignore: cast_nullable_to_non_nullable
              as String,
      summary: null == summary
          ? _value.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as String,
      taskDate: null == taskDate
          ? _value.taskDate
          : taskDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskSummaryResultImpl implements _TaskSummaryResult {
  const _$TaskSummaryResultImpl(
      {required this.taskId,
      required this.taskTitle,
      required this.summary,
      required this.taskDate,
      required this.status,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$TaskSummaryResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskSummaryResultImplFromJson(json);

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

  @override
  String toString() {
    return 'TaskSummaryResult(taskId: $taskId, taskTitle: $taskTitle, summary: $summary, taskDate: $taskDate, status: $status, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskSummaryResultImpl &&
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
      {required final String taskId,
      required final String taskTitle,
      required final String summary,
      required final DateTime taskDate,
      required final String status,
      final Map<String, dynamic>? metadata}) = _$TaskSummaryResultImpl;

  factory _TaskSummaryResult.fromJson(Map<String, dynamic> json) =
      _$TaskSummaryResultImpl.fromJson;

  @override
  String get taskId;
  @override
  String get taskTitle;
  @override
  String get summary;
  @override
  DateTime get taskDate;
  @override
  String get status;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of TaskSummaryResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskSummaryResultImplCopyWith<_$TaskSummaryResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
