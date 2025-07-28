// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TaskStatus _$TaskStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'open':
      return _TaskOpen.fromJson(json);
    case 'inProgress':
      return _TaskInProgress.fromJson(json);
    case 'groomed':
      return _TaskGroomed.fromJson(json);
    case 'blocked':
      return _TaskBlocked.fromJson(json);
    case 'onHold':
      return _TaskOnHold.fromJson(json);
    case 'done':
      return _TaskDone.fromJson(json);
    case 'rejected':
      return _TaskRejected.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'TaskStatus',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$TaskStatus {
  String get id => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  int get utcOffset => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError;
  Geolocation? get geolocation => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this TaskStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskStatusCopyWith<TaskStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskStatusCopyWith<$Res> {
  factory $TaskStatusCopyWith(
          TaskStatus value, $Res Function(TaskStatus) then) =
      _$TaskStatusCopyWithImpl<$Res, TaskStatus>;
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String? timezone,
      Geolocation? geolocation});

  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class _$TaskStatusCopyWithImpl<$Res, $Val extends TaskStatus>
    implements $TaskStatusCopyWith<$Res> {
  _$TaskStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ) as $Val);
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_value.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_value.geolocation!, (value) {
      return _then(_value.copyWith(geolocation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TaskOpenImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskOpenImplCopyWith(
          _$TaskOpenImpl value, $Res Function(_$TaskOpenImpl) then) =
      __$$TaskOpenImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String? timezone,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskOpenImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskOpenImpl>
    implements _$$TaskOpenImplCopyWith<$Res> {
  __$$TaskOpenImplCopyWithImpl(
      _$TaskOpenImpl _value, $Res Function(_$TaskOpenImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskOpenImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskOpenImpl implements _TaskOpen {
  const _$TaskOpenImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'open';

  factory _$TaskOpenImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskOpenImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TaskStatus.open(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskOpenImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskOpenImplCopyWith<_$TaskOpenImpl> get copyWith =>
      __$$TaskOpenImplCopyWithImpl<_$TaskOpenImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) {
    return open(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) {
    return open?.call(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) {
    if (open != null) {
      return open(id, createdAt, utcOffset, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return open(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return open?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (open != null) {
      return open(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskOpenImplToJson(
      this,
    );
  }
}

abstract class _TaskOpen implements TaskStatus {
  const factory _TaskOpen(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$TaskOpenImpl;

  factory _TaskOpen.fromJson(Map<String, dynamic> json) =
      _$TaskOpenImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskOpenImplCopyWith<_$TaskOpenImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskInProgressImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskInProgressImplCopyWith(_$TaskInProgressImpl value,
          $Res Function(_$TaskInProgressImpl) then) =
      __$$TaskInProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String? timezone,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskInProgressImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskInProgressImpl>
    implements _$$TaskInProgressImplCopyWith<$Res> {
  __$$TaskInProgressImplCopyWithImpl(
      _$TaskInProgressImpl _value, $Res Function(_$TaskInProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskInProgressImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskInProgressImpl implements _TaskInProgress {
  const _$TaskInProgressImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'inProgress';

  factory _$TaskInProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskInProgressImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TaskStatus.inProgress(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskInProgressImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskInProgressImplCopyWith<_$TaskInProgressImpl> get copyWith =>
      __$$TaskInProgressImplCopyWithImpl<_$TaskInProgressImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) {
    return inProgress(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) {
    return inProgress?.call(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) {
    if (inProgress != null) {
      return inProgress(id, createdAt, utcOffset, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return inProgress(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return inProgress?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (inProgress != null) {
      return inProgress(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskInProgressImplToJson(
      this,
    );
  }
}

abstract class _TaskInProgress implements TaskStatus {
  const factory _TaskInProgress(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$TaskInProgressImpl;

  factory _TaskInProgress.fromJson(Map<String, dynamic> json) =
      _$TaskInProgressImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskInProgressImplCopyWith<_$TaskInProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskGroomedImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskGroomedImplCopyWith(
          _$TaskGroomedImpl value, $Res Function(_$TaskGroomedImpl) then) =
      __$$TaskGroomedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String? timezone,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskGroomedImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskGroomedImpl>
    implements _$$TaskGroomedImplCopyWith<$Res> {
  __$$TaskGroomedImplCopyWithImpl(
      _$TaskGroomedImpl _value, $Res Function(_$TaskGroomedImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskGroomedImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskGroomedImpl implements _TaskGroomed {
  const _$TaskGroomedImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'groomed';

  factory _$TaskGroomedImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskGroomedImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TaskStatus.groomed(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskGroomedImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskGroomedImplCopyWith<_$TaskGroomedImpl> get copyWith =>
      __$$TaskGroomedImplCopyWithImpl<_$TaskGroomedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) {
    return groomed(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) {
    return groomed?.call(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) {
    if (groomed != null) {
      return groomed(id, createdAt, utcOffset, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return groomed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return groomed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (groomed != null) {
      return groomed(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskGroomedImplToJson(
      this,
    );
  }
}

abstract class _TaskGroomed implements TaskStatus {
  const factory _TaskGroomed(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$TaskGroomedImpl;

  factory _TaskGroomed.fromJson(Map<String, dynamic> json) =
      _$TaskGroomedImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskGroomedImplCopyWith<_$TaskGroomedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskBlockedImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskBlockedImplCopyWith(
          _$TaskBlockedImpl value, $Res Function(_$TaskBlockedImpl) then) =
      __$$TaskBlockedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String reason,
      String? timezone,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskBlockedImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskBlockedImpl>
    implements _$$TaskBlockedImplCopyWith<$Res> {
  __$$TaskBlockedImplCopyWithImpl(
      _$TaskBlockedImpl _value, $Res Function(_$TaskBlockedImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? reason = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskBlockedImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskBlockedImpl implements _TaskBlocked {
  const _$TaskBlockedImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'blocked';

  factory _$TaskBlockedImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskBlockedImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String reason;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TaskStatus.blocked(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, reason: $reason, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskBlockedImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, createdAt, utcOffset, reason, timezone, geolocation);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskBlockedImplCopyWith<_$TaskBlockedImpl> get copyWith =>
      __$$TaskBlockedImplCopyWithImpl<_$TaskBlockedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) {
    return blocked(id, createdAt, utcOffset, reason, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) {
    return blocked?.call(
        id, createdAt, utcOffset, reason, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) {
    if (blocked != null) {
      return blocked(id, createdAt, utcOffset, reason, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return blocked(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return blocked?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (blocked != null) {
      return blocked(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskBlockedImplToJson(
      this,
    );
  }
}

abstract class _TaskBlocked implements TaskStatus {
  const factory _TaskBlocked(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      required final String reason,
      final String? timezone,
      final Geolocation? geolocation}) = _$TaskBlockedImpl;

  factory _TaskBlocked.fromJson(Map<String, dynamic> json) =
      _$TaskBlockedImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  String get reason;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskBlockedImplCopyWith<_$TaskBlockedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskOnHoldImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskOnHoldImplCopyWith(
          _$TaskOnHoldImpl value, $Res Function(_$TaskOnHoldImpl) then) =
      __$$TaskOnHoldImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String reason,
      String? timezone,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskOnHoldImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskOnHoldImpl>
    implements _$$TaskOnHoldImplCopyWith<$Res> {
  __$$TaskOnHoldImplCopyWithImpl(
      _$TaskOnHoldImpl _value, $Res Function(_$TaskOnHoldImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? reason = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskOnHoldImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskOnHoldImpl implements _TaskOnHold {
  const _$TaskOnHoldImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'onHold';

  factory _$TaskOnHoldImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskOnHoldImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String reason;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TaskStatus.onHold(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, reason: $reason, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskOnHoldImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, createdAt, utcOffset, reason, timezone, geolocation);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskOnHoldImplCopyWith<_$TaskOnHoldImpl> get copyWith =>
      __$$TaskOnHoldImplCopyWithImpl<_$TaskOnHoldImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) {
    return onHold(id, createdAt, utcOffset, reason, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) {
    return onHold?.call(
        id, createdAt, utcOffset, reason, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) {
    if (onHold != null) {
      return onHold(id, createdAt, utcOffset, reason, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return onHold(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return onHold?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (onHold != null) {
      return onHold(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskOnHoldImplToJson(
      this,
    );
  }
}

abstract class _TaskOnHold implements TaskStatus {
  const factory _TaskOnHold(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      required final String reason,
      final String? timezone,
      final Geolocation? geolocation}) = _$TaskOnHoldImpl;

  factory _TaskOnHold.fromJson(Map<String, dynamic> json) =
      _$TaskOnHoldImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  String get reason;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskOnHoldImplCopyWith<_$TaskOnHoldImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskDoneImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskDoneImplCopyWith(
          _$TaskDoneImpl value, $Res Function(_$TaskDoneImpl) then) =
      __$$TaskDoneImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String? timezone,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskDoneImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskDoneImpl>
    implements _$$TaskDoneImplCopyWith<$Res> {
  __$$TaskDoneImplCopyWithImpl(
      _$TaskDoneImpl _value, $Res Function(_$TaskDoneImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskDoneImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskDoneImpl implements _TaskDone {
  const _$TaskDoneImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'done';

  factory _$TaskDoneImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskDoneImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TaskStatus.done(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskDoneImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskDoneImplCopyWith<_$TaskDoneImpl> get copyWith =>
      __$$TaskDoneImplCopyWithImpl<_$TaskDoneImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) {
    return done(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) {
    return done?.call(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) {
    if (done != null) {
      return done(id, createdAt, utcOffset, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return done(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return done?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (done != null) {
      return done(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskDoneImplToJson(
      this,
    );
  }
}

abstract class _TaskDone implements TaskStatus {
  const factory _TaskDone(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$TaskDoneImpl;

  factory _TaskDone.fromJson(Map<String, dynamic> json) =
      _$TaskDoneImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskDoneImplCopyWith<_$TaskDoneImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$TaskRejectedImplCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$TaskRejectedImplCopyWith(
          _$TaskRejectedImpl value, $Res Function(_$TaskRejectedImpl) then) =
      __$$TaskRejectedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime createdAt,
      int utcOffset,
      String? timezone,
      Geolocation? geolocation});

  @override
  $GeolocationCopyWith<$Res>? get geolocation;
}

/// @nodoc
class __$$TaskRejectedImplCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$TaskRejectedImpl>
    implements _$$TaskRejectedImplCopyWith<$Res> {
  __$$TaskRejectedImplCopyWithImpl(
      _$TaskRejectedImpl _value, $Res Function(_$TaskRejectedImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$TaskRejectedImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _value.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _value.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskRejectedImpl implements _TaskRejected {
  const _$TaskRejectedImpl(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'rejected';

  factory _$TaskRejectedImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskRejectedImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TaskStatus.rejected(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskRejectedImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.utcOffset, utcOffset) ||
                other.utcOffset == utcOffset) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.geolocation, geolocation) ||
                other.geolocation == geolocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskRejectedImplCopyWith<_$TaskRejectedImpl> get copyWith =>
      __$$TaskRejectedImplCopyWithImpl<_$TaskRejectedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        inProgress,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        groomed,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        blocked,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)
        onHold,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        done,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        rejected,
  }) {
    return rejected(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
  }) {
    return rejected?.call(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        inProgress,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        groomed,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        blocked,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String reason, String? timezone, Geolocation? geolocation)?
        onHold,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        done,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        rejected,
    required TResult orElse(),
  }) {
    if (rejected != null) {
      return rejected(id, createdAt, utcOffset, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return rejected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return rejected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (rejected != null) {
      return rejected(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskRejectedImplToJson(
      this,
    );
  }
}

abstract class _TaskRejected implements TaskStatus {
  const factory _TaskRejected(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$TaskRejectedImpl;

  factory _TaskRejected.fromJson(Map<String, dynamic> json) =
      _$TaskRejectedImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get utcOffset;
  @override
  String? get timezone;
  @override
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskRejectedImplCopyWith<_$TaskRejectedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TaskData _$TaskDataFromJson(Map<String, dynamic> json) {
  return _TaskData.fromJson(json);
}

/// @nodoc
mixin _$TaskData {
  TaskStatus get status => throw _privateConstructorUsedError;
  DateTime get dateFrom => throw _privateConstructorUsedError;
  DateTime get dateTo => throw _privateConstructorUsedError;
  List<TaskStatus> get statusHistory => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  DateTime? get due => throw _privateConstructorUsedError;
  Duration? get estimate => throw _privateConstructorUsedError;
  List<String>? get checklistIds => throw _privateConstructorUsedError;
  String? get languageCode => throw _privateConstructorUsedError;

  /// Serializes this TaskData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskDataCopyWith<TaskData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskDataCopyWith<$Res> {
  factory $TaskDataCopyWith(TaskData value, $Res Function(TaskData) then) =
      _$TaskDataCopyWithImpl<$Res, TaskData>;
  @useResult
  $Res call(
      {TaskStatus status,
      DateTime dateFrom,
      DateTime dateTo,
      List<TaskStatus> statusHistory,
      String title,
      DateTime? due,
      Duration? estimate,
      List<String>? checklistIds,
      String? languageCode});

  $TaskStatusCopyWith<$Res> get status;
}

/// @nodoc
class _$TaskDataCopyWithImpl<$Res, $Val extends TaskData>
    implements $TaskDataCopyWith<$Res> {
  _$TaskDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? statusHistory = null,
    Object? title = null,
    Object? due = freezed,
    Object? estimate = freezed,
    Object? checklistIds = freezed,
    Object? languageCode = freezed,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      statusHistory: null == statusHistory
          ? _value.statusHistory
          : statusHistory // ignore: cast_nullable_to_non_nullable
              as List<TaskStatus>,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      due: freezed == due
          ? _value.due
          : due // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimate: freezed == estimate
          ? _value.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration?,
      checklistIds: freezed == checklistIds
          ? _value.checklistIds
          : checklistIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      languageCode: freezed == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TaskStatusCopyWith<$Res> get status {
    return $TaskStatusCopyWith<$Res>(_value.status, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TaskDataImplCopyWith<$Res>
    implements $TaskDataCopyWith<$Res> {
  factory _$$TaskDataImplCopyWith(
          _$TaskDataImpl value, $Res Function(_$TaskDataImpl) then) =
      __$$TaskDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {TaskStatus status,
      DateTime dateFrom,
      DateTime dateTo,
      List<TaskStatus> statusHistory,
      String title,
      DateTime? due,
      Duration? estimate,
      List<String>? checklistIds,
      String? languageCode});

  @override
  $TaskStatusCopyWith<$Res> get status;
}

/// @nodoc
class __$$TaskDataImplCopyWithImpl<$Res>
    extends _$TaskDataCopyWithImpl<$Res, _$TaskDataImpl>
    implements _$$TaskDataImplCopyWith<$Res> {
  __$$TaskDataImplCopyWithImpl(
      _$TaskDataImpl _value, $Res Function(_$TaskDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? dateFrom = null,
    Object? dateTo = null,
    Object? statusHistory = null,
    Object? title = null,
    Object? due = freezed,
    Object? estimate = freezed,
    Object? checklistIds = freezed,
    Object? languageCode = freezed,
  }) {
    return _then(_$TaskDataImpl(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      dateFrom: null == dateFrom
          ? _value.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _value.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      statusHistory: null == statusHistory
          ? _value._statusHistory
          : statusHistory // ignore: cast_nullable_to_non_nullable
              as List<TaskStatus>,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      due: freezed == due
          ? _value.due
          : due // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimate: freezed == estimate
          ? _value.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration?,
      checklistIds: freezed == checklistIds
          ? _value._checklistIds
          : checklistIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      languageCode: freezed == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskDataImpl implements _TaskData {
  const _$TaskDataImpl(
      {required this.status,
      required this.dateFrom,
      required this.dateTo,
      required final List<TaskStatus> statusHistory,
      required this.title,
      this.due,
      this.estimate,
      final List<String>? checklistIds,
      this.languageCode})
      : _statusHistory = statusHistory,
        _checklistIds = checklistIds;

  factory _$TaskDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskDataImplFromJson(json);

  @override
  final TaskStatus status;
  @override
  final DateTime dateFrom;
  @override
  final DateTime dateTo;
  final List<TaskStatus> _statusHistory;
  @override
  List<TaskStatus> get statusHistory {
    if (_statusHistory is EqualUnmodifiableListView) return _statusHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_statusHistory);
  }

  @override
  final String title;
  @override
  final DateTime? due;
  @override
  final Duration? estimate;
  final List<String>? _checklistIds;
  @override
  List<String>? get checklistIds {
    final value = _checklistIds;
    if (value == null) return null;
    if (_checklistIds is EqualUnmodifiableListView) return _checklistIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? languageCode;

  @override
  String toString() {
    return 'TaskData(status: $status, dateFrom: $dateFrom, dateTo: $dateTo, statusHistory: $statusHistory, title: $title, due: $due, estimate: $estimate, checklistIds: $checklistIds, languageCode: $languageCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskDataImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            const DeepCollectionEquality()
                .equals(other._statusHistory, _statusHistory) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.due, due) || other.due == due) &&
            (identical(other.estimate, estimate) ||
                other.estimate == estimate) &&
            const DeepCollectionEquality()
                .equals(other._checklistIds, _checklistIds) &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      dateFrom,
      dateTo,
      const DeepCollectionEquality().hash(_statusHistory),
      title,
      due,
      estimate,
      const DeepCollectionEquality().hash(_checklistIds),
      languageCode);

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskDataImplCopyWith<_$TaskDataImpl> get copyWith =>
      __$$TaskDataImplCopyWithImpl<_$TaskDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskDataImplToJson(
      this,
    );
  }
}

abstract class _TaskData implements TaskData {
  const factory _TaskData(
      {required final TaskStatus status,
      required final DateTime dateFrom,
      required final DateTime dateTo,
      required final List<TaskStatus> statusHistory,
      required final String title,
      final DateTime? due,
      final Duration? estimate,
      final List<String>? checklistIds,
      final String? languageCode}) = _$TaskDataImpl;

  factory _TaskData.fromJson(Map<String, dynamic> json) =
      _$TaskDataImpl.fromJson;

  @override
  TaskStatus get status;
  @override
  DateTime get dateFrom;
  @override
  DateTime get dateTo;
  @override
  List<TaskStatus> get statusHistory;
  @override
  String get title;
  @override
  DateTime? get due;
  @override
  Duration? get estimate;
  @override
  List<String>? get checklistIds;
  @override
  String? get languageCode;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskDataImplCopyWith<_$TaskDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
