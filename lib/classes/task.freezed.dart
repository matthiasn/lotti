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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

TaskStatus _$TaskStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'open':
      return _TaskOpen.fromJson(json);
    case 'started':
      return _TaskStarted.fromJson(json);
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
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
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
abstract class _$$_TaskOpenCopyWith<$Res> implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskOpenCopyWith(
          _$_TaskOpen value, $Res Function(_$_TaskOpen) then) =
      __$$_TaskOpenCopyWithImpl<$Res>;
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
class __$$_TaskOpenCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskOpen>
    implements _$$_TaskOpenCopyWith<$Res> {
  __$$_TaskOpenCopyWithImpl(
      _$_TaskOpen _value, $Res Function(_$_TaskOpen) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$_TaskOpen(
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
class _$_TaskOpen implements _TaskOpen {
  _$_TaskOpen(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'open';

  factory _$_TaskOpen.fromJson(Map<String, dynamic> json) =>
      _$$_TaskOpenFromJson(json);

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskOpen &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskOpenCopyWith<_$_TaskOpen> get copyWith =>
      __$$_TaskOpenCopyWithImpl<_$_TaskOpen>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
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
    return _$$_TaskOpenToJson(
      this,
    );
  }
}

abstract class _TaskOpen implements TaskStatus {
  factory _TaskOpen(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskOpen;

  factory _TaskOpen.fromJson(Map<String, dynamic> json) = _$_TaskOpen.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskOpenCopyWith<_$_TaskOpen> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_TaskStartedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskStartedCopyWith(
          _$_TaskStarted value, $Res Function(_$_TaskStarted) then) =
      __$$_TaskStartedCopyWithImpl<$Res>;
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
class __$$_TaskStartedCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskStarted>
    implements _$$_TaskStartedCopyWith<$Res> {
  __$$_TaskStartedCopyWithImpl(
      _$_TaskStarted _value, $Res Function(_$_TaskStarted) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$_TaskStarted(
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
class _$_TaskStarted implements _TaskStarted {
  _$_TaskStarted(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'started';

  factory _$_TaskStarted.fromJson(Map<String, dynamic> json) =>
      _$$_TaskStartedFromJson(json);

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
    return 'TaskStatus.started(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskStarted &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskStartedCopyWith<_$_TaskStarted> get copyWith =>
      __$$_TaskStartedCopyWithImpl<_$_TaskStarted>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
    return started(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult? Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        started,
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
    return started?.call(id, createdAt, utcOffset, timezone, geolocation);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        open,
    TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)?
        started,
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
    if (started != null) {
      return started(id, createdAt, utcOffset, timezone, geolocation);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskStarted value) started,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    return started(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskStarted value)? started,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    return started?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskStarted value)? started,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    if (started != null) {
      return started(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$_TaskStartedToJson(
      this,
    );
  }
}

abstract class _TaskStarted implements TaskStatus {
  factory _TaskStarted(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskStarted;

  factory _TaskStarted.fromJson(Map<String, dynamic> json) =
      _$_TaskStarted.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskStartedCopyWith<_$_TaskStarted> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_TaskInProgressCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskInProgressCopyWith(
          _$_TaskInProgress value, $Res Function(_$_TaskInProgress) then) =
      __$$_TaskInProgressCopyWithImpl<$Res>;
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
class __$$_TaskInProgressCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskInProgress>
    implements _$$_TaskInProgressCopyWith<$Res> {
  __$$_TaskInProgressCopyWithImpl(
      _$_TaskInProgress _value, $Res Function(_$_TaskInProgress) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$_TaskInProgress(
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
class _$_TaskInProgress implements _TaskInProgress {
  _$_TaskInProgress(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'inProgress';

  factory _$_TaskInProgress.fromJson(Map<String, dynamic> json) =>
      _$$_TaskInProgressFromJson(json);

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskInProgress &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskInProgressCopyWith<_$_TaskInProgress> get copyWith =>
      __$$_TaskInProgressCopyWithImpl<_$_TaskInProgress>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
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
    return _$$_TaskInProgressToJson(
      this,
    );
  }
}

abstract class _TaskInProgress implements TaskStatus {
  factory _TaskInProgress(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskInProgress;

  factory _TaskInProgress.fromJson(Map<String, dynamic> json) =
      _$_TaskInProgress.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskInProgressCopyWith<_$_TaskInProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_TaskGroomedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskGroomedCopyWith(
          _$_TaskGroomed value, $Res Function(_$_TaskGroomed) then) =
      __$$_TaskGroomedCopyWithImpl<$Res>;
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
class __$$_TaskGroomedCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskGroomed>
    implements _$$_TaskGroomedCopyWith<$Res> {
  __$$_TaskGroomedCopyWithImpl(
      _$_TaskGroomed _value, $Res Function(_$_TaskGroomed) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$_TaskGroomed(
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
class _$_TaskGroomed implements _TaskGroomed {
  _$_TaskGroomed(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'groomed';

  factory _$_TaskGroomed.fromJson(Map<String, dynamic> json) =>
      _$$_TaskGroomedFromJson(json);

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskGroomed &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskGroomedCopyWith<_$_TaskGroomed> get copyWith =>
      __$$_TaskGroomedCopyWithImpl<_$_TaskGroomed>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
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
    return _$$_TaskGroomedToJson(
      this,
    );
  }
}

abstract class _TaskGroomed implements TaskStatus {
  factory _TaskGroomed(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskGroomed;

  factory _TaskGroomed.fromJson(Map<String, dynamic> json) =
      _$_TaskGroomed.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskGroomedCopyWith<_$_TaskGroomed> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_TaskBlockedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskBlockedCopyWith(
          _$_TaskBlocked value, $Res Function(_$_TaskBlocked) then) =
      __$$_TaskBlockedCopyWithImpl<$Res>;
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
class __$$_TaskBlockedCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskBlocked>
    implements _$$_TaskBlockedCopyWith<$Res> {
  __$$_TaskBlockedCopyWithImpl(
      _$_TaskBlocked _value, $Res Function(_$_TaskBlocked) _then)
      : super(_value, _then);

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
    return _then(_$_TaskBlocked(
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
class _$_TaskBlocked implements _TaskBlocked {
  _$_TaskBlocked(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'blocked';

  factory _$_TaskBlocked.fromJson(Map<String, dynamic> json) =>
      _$$_TaskBlockedFromJson(json);

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskBlocked &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, createdAt, utcOffset, reason, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskBlockedCopyWith<_$_TaskBlocked> get copyWith =>
      __$$_TaskBlockedCopyWithImpl<_$_TaskBlocked>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
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
    return _$$_TaskBlockedToJson(
      this,
    );
  }
}

abstract class _TaskBlocked implements TaskStatus {
  factory _TaskBlocked(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      required final String reason,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskBlocked;

  factory _TaskBlocked.fromJson(Map<String, dynamic> json) =
      _$_TaskBlocked.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskBlockedCopyWith<_$_TaskBlocked> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_TaskOnHoldCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskOnHoldCopyWith(
          _$_TaskOnHold value, $Res Function(_$_TaskOnHold) then) =
      __$$_TaskOnHoldCopyWithImpl<$Res>;
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
class __$$_TaskOnHoldCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskOnHold>
    implements _$$_TaskOnHoldCopyWith<$Res> {
  __$$_TaskOnHoldCopyWithImpl(
      _$_TaskOnHold _value, $Res Function(_$_TaskOnHold) _then)
      : super(_value, _then);

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
    return _then(_$_TaskOnHold(
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
class _$_TaskOnHold implements _TaskOnHold {
  _$_TaskOnHold(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'onHold';

  factory _$_TaskOnHold.fromJson(Map<String, dynamic> json) =>
      _$$_TaskOnHoldFromJson(json);

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskOnHold &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, createdAt, utcOffset, reason, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskOnHoldCopyWith<_$_TaskOnHold> get copyWith =>
      __$$_TaskOnHoldCopyWithImpl<_$_TaskOnHold>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
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
    return _$$_TaskOnHoldToJson(
      this,
    );
  }
}

abstract class _TaskOnHold implements TaskStatus {
  factory _TaskOnHold(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      required final String reason,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskOnHold;

  factory _TaskOnHold.fromJson(Map<String, dynamic> json) =
      _$_TaskOnHold.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskOnHoldCopyWith<_$_TaskOnHold> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_TaskDoneCopyWith<$Res> implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskDoneCopyWith(
          _$_TaskDone value, $Res Function(_$_TaskDone) then) =
      __$$_TaskDoneCopyWithImpl<$Res>;
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
class __$$_TaskDoneCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskDone>
    implements _$$_TaskDoneCopyWith<$Res> {
  __$$_TaskDoneCopyWithImpl(
      _$_TaskDone _value, $Res Function(_$_TaskDone) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$_TaskDone(
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
class _$_TaskDone implements _TaskDone {
  _$_TaskDone(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'done';

  factory _$_TaskDone.fromJson(Map<String, dynamic> json) =>
      _$$_TaskDoneFromJson(json);

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskDone &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskDoneCopyWith<_$_TaskDone> get copyWith =>
      __$$_TaskDoneCopyWithImpl<_$_TaskDone>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
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
    return _$$_TaskDoneToJson(
      this,
    );
  }
}

abstract class _TaskDone implements TaskStatus {
  factory _TaskDone(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskDone;

  factory _TaskDone.fromJson(Map<String, dynamic> json) = _$_TaskDone.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskDoneCopyWith<_$_TaskDone> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$_TaskRejectedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$$_TaskRejectedCopyWith(
          _$_TaskRejected value, $Res Function(_$_TaskRejected) then) =
      __$$_TaskRejectedCopyWithImpl<$Res>;
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
class __$$_TaskRejectedCopyWithImpl<$Res>
    extends _$TaskStatusCopyWithImpl<$Res, _$_TaskRejected>
    implements _$$_TaskRejectedCopyWith<$Res> {
  __$$_TaskRejectedCopyWithImpl(
      _$_TaskRejected _value, $Res Function(_$_TaskRejected) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(_$_TaskRejected(
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
class _$_TaskRejected implements _TaskRejected {
  _$_TaskRejected(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'rejected';

  factory _$_TaskRejected.fromJson(Map<String, dynamic> json) =>
      _$$_TaskRejectedFromJson(json);

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
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskRejected &&
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

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, utcOffset, timezone, geolocation);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskRejectedCopyWith<_$_TaskRejected> get copyWith =>
      __$$_TaskRejectedCopyWithImpl<_$_TaskRejected>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        open,
    required TResult Function(String id, DateTime createdAt, int utcOffset,
            String? timezone, Geolocation? geolocation)
        started,
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
        started,
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
        started,
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
    required TResult Function(_TaskStarted value) started,
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
    TResult? Function(_TaskStarted value)? started,
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
    TResult Function(_TaskStarted value)? started,
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
    return _$$_TaskRejectedToJson(
      this,
    );
  }
}

abstract class _TaskRejected implements TaskStatus {
  factory _TaskRejected(
      {required final String id,
      required final DateTime createdAt,
      required final int utcOffset,
      final String? timezone,
      final Geolocation? geolocation}) = _$_TaskRejected;

  factory _TaskRejected.fromJson(Map<String, dynamic> json) =
      _$_TaskRejected.fromJson;

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
  @override
  @JsonKey(ignore: true)
  _$$_TaskRejectedCopyWith<_$_TaskRejected> get copyWith =>
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
  List<CheckListItem>? get checklist => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
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
      List<CheckListItem>? checklist});

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
    Object? checklist = freezed,
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
      checklist: freezed == checklist
          ? _value.checklist
          : checklist // ignore: cast_nullable_to_non_nullable
              as List<CheckListItem>?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $TaskStatusCopyWith<$Res> get status {
    return $TaskStatusCopyWith<$Res>(_value.status, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_TaskDataCopyWith<$Res> implements $TaskDataCopyWith<$Res> {
  factory _$$_TaskDataCopyWith(
          _$_TaskData value, $Res Function(_$_TaskData) then) =
      __$$_TaskDataCopyWithImpl<$Res>;
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
      List<CheckListItem>? checklist});

  @override
  $TaskStatusCopyWith<$Res> get status;
}

/// @nodoc
class __$$_TaskDataCopyWithImpl<$Res>
    extends _$TaskDataCopyWithImpl<$Res, _$_TaskData>
    implements _$$_TaskDataCopyWith<$Res> {
  __$$_TaskDataCopyWithImpl(
      _$_TaskData _value, $Res Function(_$_TaskData) _then)
      : super(_value, _then);

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
    Object? checklist = freezed,
  }) {
    return _then(_$_TaskData(
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
      checklist: freezed == checklist
          ? _value._checklist
          : checklist // ignore: cast_nullable_to_non_nullable
              as List<CheckListItem>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_TaskData implements _TaskData {
  _$_TaskData(
      {required this.status,
      required this.dateFrom,
      required this.dateTo,
      required final List<TaskStatus> statusHistory,
      required this.title,
      this.due,
      this.estimate,
      final List<CheckListItem>? checklist})
      : _statusHistory = statusHistory,
        _checklist = checklist;

  factory _$_TaskData.fromJson(Map<String, dynamic> json) =>
      _$$_TaskDataFromJson(json);

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
  final List<CheckListItem>? _checklist;
  @override
  List<CheckListItem>? get checklist {
    final value = _checklist;
    if (value == null) return null;
    if (_checklist is EqualUnmodifiableListView) return _checklist;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'TaskData(status: $status, dateFrom: $dateFrom, dateTo: $dateTo, statusHistory: $statusHistory, title: $title, due: $due, estimate: $estimate, checklist: $checklist)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_TaskData &&
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
                .equals(other._checklist, _checklist));
  }

  @JsonKey(ignore: true)
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
      const DeepCollectionEquality().hash(_checklist));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_TaskDataCopyWith<_$_TaskData> get copyWith =>
      __$$_TaskDataCopyWithImpl<_$_TaskData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_TaskDataToJson(
      this,
    );
  }
}

abstract class _TaskData implements TaskData {
  factory _TaskData(
      {required final TaskStatus status,
      required final DateTime dateFrom,
      required final DateTime dateTo,
      required final List<TaskStatus> statusHistory,
      required final String title,
      final DateTime? due,
      final Duration? estimate,
      final List<CheckListItem>? checklist}) = _$_TaskData;

  factory _TaskData.fromJson(Map<String, dynamic> json) = _$_TaskData.fromJson;

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
  List<CheckListItem>? get checklist;
  @override
  @JsonKey(ignore: true)
  _$$_TaskDataCopyWith<_$_TaskData> get copyWith =>
      throw _privateConstructorUsedError;
}
