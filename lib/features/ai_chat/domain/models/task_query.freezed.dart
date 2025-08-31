// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_query.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TaskQuery _$TaskQueryFromJson(Map<String, dynamic> json) {
  return _TaskQuery.fromJson(json);
}

/// @nodoc
mixin _$TaskQuery {
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  List<String>? get categoryIds => throw _privateConstructorUsedError;
  List<String>? get tagIds => throw _privateConstructorUsedError;
  int? get limit => throw _privateConstructorUsedError;
  TaskQueryType? get queryType => throw _privateConstructorUsedError;
  Map<String, dynamic>? get filters => throw _privateConstructorUsedError;

  /// Serializes this TaskQuery to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskQuery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskQueryCopyWith<TaskQuery> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskQueryCopyWith<$Res> {
  factory $TaskQueryCopyWith(TaskQuery value, $Res Function(TaskQuery) then) =
      _$TaskQueryCopyWithImpl<$Res, TaskQuery>;
  @useResult
  $Res call(
      {DateTime startDate,
      DateTime endDate,
      List<String>? categoryIds,
      List<String>? tagIds,
      int? limit,
      TaskQueryType? queryType,
      Map<String, dynamic>? filters});
}

/// @nodoc
class _$TaskQueryCopyWithImpl<$Res, $Val extends TaskQuery>
    implements $TaskQueryCopyWith<$Res> {
  _$TaskQueryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskQuery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? categoryIds = freezed,
    Object? tagIds = freezed,
    Object? limit = freezed,
    Object? queryType = freezed,
    Object? filters = freezed,
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
      categoryIds: freezed == categoryIds
          ? _value.categoryIds
          : categoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagIds: freezed == tagIds
          ? _value.tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      limit: freezed == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int?,
      queryType: freezed == queryType
          ? _value.queryType
          : queryType // ignore: cast_nullable_to_non_nullable
              as TaskQueryType?,
      filters: freezed == filters
          ? _value.filters
          : filters // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TaskQueryImplCopyWith<$Res>
    implements $TaskQueryCopyWith<$Res> {
  factory _$$TaskQueryImplCopyWith(
          _$TaskQueryImpl value, $Res Function(_$TaskQueryImpl) then) =
      __$$TaskQueryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {DateTime startDate,
      DateTime endDate,
      List<String>? categoryIds,
      List<String>? tagIds,
      int? limit,
      TaskQueryType? queryType,
      Map<String, dynamic>? filters});
}

/// @nodoc
class __$$TaskQueryImplCopyWithImpl<$Res>
    extends _$TaskQueryCopyWithImpl<$Res, _$TaskQueryImpl>
    implements _$$TaskQueryImplCopyWith<$Res> {
  __$$TaskQueryImplCopyWithImpl(
      _$TaskQueryImpl _value, $Res Function(_$TaskQueryImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskQuery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? startDate = null,
    Object? endDate = null,
    Object? categoryIds = freezed,
    Object? tagIds = freezed,
    Object? limit = freezed,
    Object? queryType = freezed,
    Object? filters = freezed,
  }) {
    return _then(_$TaskQueryImpl(
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      categoryIds: freezed == categoryIds
          ? _value._categoryIds
          : categoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tagIds: freezed == tagIds
          ? _value._tagIds
          : tagIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      limit: freezed == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int?,
      queryType: freezed == queryType
          ? _value.queryType
          : queryType // ignore: cast_nullable_to_non_nullable
              as TaskQueryType?,
      filters: freezed == filters
          ? _value._filters
          : filters // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskQueryImpl implements _TaskQuery {
  const _$TaskQueryImpl(
      {required this.startDate,
      required this.endDate,
      final List<String>? categoryIds,
      final List<String>? tagIds,
      this.limit,
      this.queryType,
      final Map<String, dynamic>? filters})
      : _categoryIds = categoryIds,
        _tagIds = tagIds,
        _filters = filters;

  factory _$TaskQueryImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskQueryImplFromJson(json);

  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  final List<String>? _categoryIds;
  @override
  List<String>? get categoryIds {
    final value = _categoryIds;
    if (value == null) return null;
    if (_categoryIds is EqualUnmodifiableListView) return _categoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _tagIds;
  @override
  List<String>? get tagIds {
    final value = _tagIds;
    if (value == null) return null;
    if (_tagIds is EqualUnmodifiableListView) return _tagIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final int? limit;
  @override
  final TaskQueryType? queryType;
  final Map<String, dynamic>? _filters;
  @override
  Map<String, dynamic>? get filters {
    final value = _filters;
    if (value == null) return null;
    if (_filters is EqualUnmodifiableMapView) return _filters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'TaskQuery(startDate: $startDate, endDate: $endDate, categoryIds: $categoryIds, tagIds: $tagIds, limit: $limit, queryType: $queryType, filters: $filters)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskQueryImpl &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            const DeepCollectionEquality()
                .equals(other._categoryIds, _categoryIds) &&
            const DeepCollectionEquality().equals(other._tagIds, _tagIds) &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.queryType, queryType) ||
                other.queryType == queryType) &&
            const DeepCollectionEquality().equals(other._filters, _filters));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      startDate,
      endDate,
      const DeepCollectionEquality().hash(_categoryIds),
      const DeepCollectionEquality().hash(_tagIds),
      limit,
      queryType,
      const DeepCollectionEquality().hash(_filters));

  /// Create a copy of TaskQuery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskQueryImplCopyWith<_$TaskQueryImpl> get copyWith =>
      __$$TaskQueryImplCopyWithImpl<_$TaskQueryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskQueryImplToJson(
      this,
    );
  }
}

abstract class _TaskQuery implements TaskQuery {
  const factory _TaskQuery(
      {required final DateTime startDate,
      required final DateTime endDate,
      final List<String>? categoryIds,
      final List<String>? tagIds,
      final int? limit,
      final TaskQueryType? queryType,
      final Map<String, dynamic>? filters}) = _$TaskQueryImpl;

  factory _TaskQuery.fromJson(Map<String, dynamic> json) =
      _$TaskQueryImpl.fromJson;

  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  List<String>? get categoryIds;
  @override
  List<String>? get tagIds;
  @override
  int? get limit;
  @override
  TaskQueryType? get queryType;
  @override
  Map<String, dynamic>? get filters;

  /// Create a copy of TaskQuery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskQueryImplCopyWith<_$TaskQueryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
