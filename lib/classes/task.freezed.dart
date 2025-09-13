// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
TaskStatus _$TaskStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'open':
      return TaskOpen.fromJson(json);
    case 'inProgress':
      return TaskInProgress.fromJson(json);
    case 'groomed':
      return TaskGroomed.fromJson(json);
    case 'blocked':
      return TaskBlocked.fromJson(json);
    case 'onHold':
      return TaskOnHold.fromJson(json);
    case 'done':
      return TaskDone.fromJson(json);
    case 'rejected':
      return TaskRejected.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'TaskStatus',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$TaskStatus {
  String get id;
  DateTime get createdAt;
  int get utcOffset;
  String? get timezone;
  Geolocation? get geolocation;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskStatusCopyWith<TaskStatus> get copyWith =>
      _$TaskStatusCopyWithImpl<TaskStatus>(this as TaskStatus, _$identity);

  /// Serializes this TaskStatus to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskStatus &&
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

  @override
  String toString() {
    return 'TaskStatus(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskStatusCopyWith<$Res> {
  factory $TaskStatusCopyWith(
          TaskStatus value, $Res Function(TaskStatus) _then) =
      _$TaskStatusCopyWithImpl;
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
class _$TaskStatusCopyWithImpl<$Res> implements $TaskStatusCopyWith<$Res> {
  _$TaskStatusCopyWithImpl(this._self, this._then);

  final TaskStatus _self;
  final $Res Function(TaskStatus) _then;

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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// Adds pattern-matching-related methods to [TaskStatus].
extension TaskStatusPatterns on TaskStatus {
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
    TResult Function(TaskOpen value)? open,
    TResult Function(TaskInProgress value)? inProgress,
    TResult Function(TaskGroomed value)? groomed,
    TResult Function(TaskBlocked value)? blocked,
    TResult Function(TaskOnHold value)? onHold,
    TResult Function(TaskDone value)? done,
    TResult Function(TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case TaskOpen() when open != null:
        return open(_that);
      case TaskInProgress() when inProgress != null:
        return inProgress(_that);
      case TaskGroomed() when groomed != null:
        return groomed(_that);
      case TaskBlocked() when blocked != null:
        return blocked(_that);
      case TaskOnHold() when onHold != null:
        return onHold(_that);
      case TaskDone() when done != null:
        return done(_that);
      case TaskRejected() when rejected != null:
        return rejected(_that);
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
    required TResult Function(TaskOpen value) open,
    required TResult Function(TaskInProgress value) inProgress,
    required TResult Function(TaskGroomed value) groomed,
    required TResult Function(TaskBlocked value) blocked,
    required TResult Function(TaskOnHold value) onHold,
    required TResult Function(TaskDone value) done,
    required TResult Function(TaskRejected value) rejected,
  }) {
    final _that = this;
    switch (_that) {
      case TaskOpen():
        return open(_that);
      case TaskInProgress():
        return inProgress(_that);
      case TaskGroomed():
        return groomed(_that);
      case TaskBlocked():
        return blocked(_that);
      case TaskOnHold():
        return onHold(_that);
      case TaskDone():
        return done(_that);
      case TaskRejected():
        return rejected(_that);
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
    TResult? Function(TaskOpen value)? open,
    TResult? Function(TaskInProgress value)? inProgress,
    TResult? Function(TaskGroomed value)? groomed,
    TResult? Function(TaskBlocked value)? blocked,
    TResult? Function(TaskOnHold value)? onHold,
    TResult? Function(TaskDone value)? done,
    TResult? Function(TaskRejected value)? rejected,
  }) {
    final _that = this;
    switch (_that) {
      case TaskOpen() when open != null:
        return open(_that);
      case TaskInProgress() when inProgress != null:
        return inProgress(_that);
      case TaskGroomed() when groomed != null:
        return groomed(_that);
      case TaskBlocked() when blocked != null:
        return blocked(_that);
      case TaskOnHold() when onHold != null:
        return onHold(_that);
      case TaskDone() when done != null:
        return done(_that);
      case TaskRejected() when rejected != null:
        return rejected(_that);
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
    final _that = this;
    switch (_that) {
      case TaskOpen() when open != null:
        return open(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case TaskInProgress() when inProgress != null:
        return inProgress(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case TaskGroomed() when groomed != null:
        return groomed(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case TaskBlocked() when blocked != null:
        return blocked(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case TaskOnHold() when onHold != null:
        return onHold(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case TaskDone() when done != null:
        return done(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case TaskRejected() when rejected != null:
        return rejected(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
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
    final _that = this;
    switch (_that) {
      case TaskOpen():
        return open(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case TaskInProgress():
        return inProgress(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case TaskGroomed():
        return groomed(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case TaskBlocked():
        return blocked(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case TaskOnHold():
        return onHold(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case TaskDone():
        return done(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case TaskRejected():
        return rejected(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
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
    final _that = this;
    switch (_that) {
      case TaskOpen() when open != null:
        return open(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case TaskInProgress() when inProgress != null:
        return inProgress(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case TaskGroomed() when groomed != null:
        return groomed(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case TaskBlocked() when blocked != null:
        return blocked(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case TaskOnHold() when onHold != null:
        return onHold(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case TaskDone() when done != null:
        return done(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case TaskRejected() when rejected != null:
        return rejected(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class TaskOpen implements TaskStatus {
  const TaskOpen(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'open';
  factory TaskOpen.fromJson(Map<String, dynamic> json) =>
      _$TaskOpenFromJson(json);

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

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskOpenCopyWith<TaskOpen> get copyWith =>
      _$TaskOpenCopyWithImpl<TaskOpen>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskOpenToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskOpen &&
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

  @override
  String toString() {
    return 'TaskStatus.open(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskOpenCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory $TaskOpenCopyWith(TaskOpen value, $Res Function(TaskOpen) _then) =
      _$TaskOpenCopyWithImpl;
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
class _$TaskOpenCopyWithImpl<$Res> implements $TaskOpenCopyWith<$Res> {
  _$TaskOpenCopyWithImpl(this._self, this._then);

  final TaskOpen _self;
  final $Res Function(TaskOpen) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(TaskOpen(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class TaskInProgress implements TaskStatus {
  const TaskInProgress(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'inProgress';
  factory TaskInProgress.fromJson(Map<String, dynamic> json) =>
      _$TaskInProgressFromJson(json);

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

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskInProgressCopyWith<TaskInProgress> get copyWith =>
      _$TaskInProgressCopyWithImpl<TaskInProgress>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskInProgressToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskInProgress &&
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

  @override
  String toString() {
    return 'TaskStatus.inProgress(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskInProgressCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory $TaskInProgressCopyWith(
          TaskInProgress value, $Res Function(TaskInProgress) _then) =
      _$TaskInProgressCopyWithImpl;
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
class _$TaskInProgressCopyWithImpl<$Res>
    implements $TaskInProgressCopyWith<$Res> {
  _$TaskInProgressCopyWithImpl(this._self, this._then);

  final TaskInProgress _self;
  final $Res Function(TaskInProgress) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(TaskInProgress(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class TaskGroomed implements TaskStatus {
  const TaskGroomed(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'groomed';
  factory TaskGroomed.fromJson(Map<String, dynamic> json) =>
      _$TaskGroomedFromJson(json);

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

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskGroomedCopyWith<TaskGroomed> get copyWith =>
      _$TaskGroomedCopyWithImpl<TaskGroomed>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskGroomedToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskGroomed &&
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

  @override
  String toString() {
    return 'TaskStatus.groomed(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskGroomedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory $TaskGroomedCopyWith(
          TaskGroomed value, $Res Function(TaskGroomed) _then) =
      _$TaskGroomedCopyWithImpl;
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
class _$TaskGroomedCopyWithImpl<$Res> implements $TaskGroomedCopyWith<$Res> {
  _$TaskGroomedCopyWithImpl(this._self, this._then);

  final TaskGroomed _self;
  final $Res Function(TaskGroomed) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(TaskGroomed(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class TaskBlocked implements TaskStatus {
  const TaskBlocked(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'blocked';
  factory TaskBlocked.fromJson(Map<String, dynamic> json) =>
      _$TaskBlockedFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  final String reason;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskBlockedCopyWith<TaskBlocked> get copyWith =>
      _$TaskBlockedCopyWithImpl<TaskBlocked>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskBlockedToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskBlocked &&
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

  @override
  String toString() {
    return 'TaskStatus.blocked(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, reason: $reason, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskBlockedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory $TaskBlockedCopyWith(
          TaskBlocked value, $Res Function(TaskBlocked) _then) =
      _$TaskBlockedCopyWithImpl;
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
class _$TaskBlockedCopyWithImpl<$Res> implements $TaskBlockedCopyWith<$Res> {
  _$TaskBlockedCopyWithImpl(this._self, this._then);

  final TaskBlocked _self;
  final $Res Function(TaskBlocked) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? reason = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(TaskBlocked(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class TaskOnHold implements TaskStatus {
  const TaskOnHold(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'onHold';
  factory TaskOnHold.fromJson(Map<String, dynamic> json) =>
      _$TaskOnHoldFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int utcOffset;
  final String reason;
  @override
  final String? timezone;
  @override
  final Geolocation? geolocation;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskOnHoldCopyWith<TaskOnHold> get copyWith =>
      _$TaskOnHoldCopyWithImpl<TaskOnHold>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskOnHoldToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskOnHold &&
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

  @override
  String toString() {
    return 'TaskStatus.onHold(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, reason: $reason, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskOnHoldCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory $TaskOnHoldCopyWith(
          TaskOnHold value, $Res Function(TaskOnHold) _then) =
      _$TaskOnHoldCopyWithImpl;
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
class _$TaskOnHoldCopyWithImpl<$Res> implements $TaskOnHoldCopyWith<$Res> {
  _$TaskOnHoldCopyWithImpl(this._self, this._then);

  final TaskOnHold _self;
  final $Res Function(TaskOnHold) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? reason = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(TaskOnHold(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class TaskDone implements TaskStatus {
  const TaskDone(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'done';
  factory TaskDone.fromJson(Map<String, dynamic> json) =>
      _$TaskDoneFromJson(json);

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

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskDoneCopyWith<TaskDone> get copyWith =>
      _$TaskDoneCopyWithImpl<TaskDone>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskDoneToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskDone &&
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

  @override
  String toString() {
    return 'TaskStatus.done(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskDoneCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory $TaskDoneCopyWith(TaskDone value, $Res Function(TaskDone) _then) =
      _$TaskDoneCopyWithImpl;
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
class _$TaskDoneCopyWithImpl<$Res> implements $TaskDoneCopyWith<$Res> {
  _$TaskDoneCopyWithImpl(this._self, this._then);

  final TaskDone _self;
  final $Res Function(TaskDone) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(TaskDone(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class TaskRejected implements TaskStatus {
  const TaskRejected(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'rejected';
  factory TaskRejected.fromJson(Map<String, dynamic> json) =>
      _$TaskRejectedFromJson(json);

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

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskRejectedCopyWith<TaskRejected> get copyWith =>
      _$TaskRejectedCopyWithImpl<TaskRejected>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskRejectedToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskRejected &&
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

  @override
  String toString() {
    return 'TaskStatus.rejected(id: $id, createdAt: $createdAt, utcOffset: $utcOffset, timezone: $timezone, geolocation: $geolocation)';
  }
}

/// @nodoc
abstract mixin class $TaskRejectedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory $TaskRejectedCopyWith(
          TaskRejected value, $Res Function(TaskRejected) _then) =
      _$TaskRejectedCopyWithImpl;
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
class _$TaskRejectedCopyWithImpl<$Res> implements $TaskRejectedCopyWith<$Res> {
  _$TaskRejectedCopyWithImpl(this._self, this._then);

  final TaskRejected _self;
  final $Res Function(TaskRejected) _then;

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? utcOffset = null,
    Object? timezone = freezed,
    Object? geolocation = freezed,
  }) {
    return _then(TaskRejected(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      utcOffset: null == utcOffset
          ? _self.utcOffset
          : utcOffset // ignore: cast_nullable_to_non_nullable
              as int,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      geolocation: freezed == geolocation
          ? _self.geolocation
          : geolocation // ignore: cast_nullable_to_non_nullable
              as Geolocation?,
    ));
  }

  /// Create a copy of TaskStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GeolocationCopyWith<$Res>? get geolocation {
    if (_self.geolocation == null) {
      return null;
    }

    return $GeolocationCopyWith<$Res>(_self.geolocation!, (value) {
      return _then(_self.copyWith(geolocation: value));
    });
  }
}

/// @nodoc
mixin _$TaskData {
  TaskStatus get status;
  DateTime get dateFrom;
  DateTime get dateTo;
  List<TaskStatus> get statusHistory;
  String get title;
  DateTime? get due;
  Duration? get estimate;
  List<String>? get checklistIds;
  String? get languageCode;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TaskDataCopyWith<TaskData> get copyWith =>
      _$TaskDataCopyWithImpl<TaskData>(this as TaskData, _$identity);

  /// Serializes this TaskData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TaskData &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.dateFrom, dateFrom) ||
                other.dateFrom == dateFrom) &&
            (identical(other.dateTo, dateTo) || other.dateTo == dateTo) &&
            const DeepCollectionEquality()
                .equals(other.statusHistory, statusHistory) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.due, due) || other.due == due) &&
            (identical(other.estimate, estimate) ||
                other.estimate == estimate) &&
            const DeepCollectionEquality()
                .equals(other.checklistIds, checklistIds) &&
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
      const DeepCollectionEquality().hash(statusHistory),
      title,
      due,
      estimate,
      const DeepCollectionEquality().hash(checklistIds),
      languageCode);

  @override
  String toString() {
    return 'TaskData(status: $status, dateFrom: $dateFrom, dateTo: $dateTo, statusHistory: $statusHistory, title: $title, due: $due, estimate: $estimate, checklistIds: $checklistIds, languageCode: $languageCode)';
  }
}

/// @nodoc
abstract mixin class $TaskDataCopyWith<$Res> {
  factory $TaskDataCopyWith(TaskData value, $Res Function(TaskData) _then) =
      _$TaskDataCopyWithImpl;
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
class _$TaskDataCopyWithImpl<$Res> implements $TaskDataCopyWith<$Res> {
  _$TaskDataCopyWithImpl(this._self, this._then);

  final TaskData _self;
  final $Res Function(TaskData) _then;

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
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      statusHistory: null == statusHistory
          ? _self.statusHistory
          : statusHistory // ignore: cast_nullable_to_non_nullable
              as List<TaskStatus>,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      due: freezed == due
          ? _self.due
          : due // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimate: freezed == estimate
          ? _self.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration?,
      checklistIds: freezed == checklistIds
          ? _self.checklistIds
          : checklistIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      languageCode: freezed == languageCode
          ? _self.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TaskStatusCopyWith<$Res> get status {
    return $TaskStatusCopyWith<$Res>(_self.status, (value) {
      return _then(_self.copyWith(status: value));
    });
  }
}

/// Adds pattern-matching-related methods to [TaskData].
extension TaskDataPatterns on TaskData {
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
    TResult Function(_TaskData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskData() when $default != null:
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
    TResult Function(_TaskData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskData():
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
    TResult? Function(_TaskData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskData() when $default != null:
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
            TaskStatus status,
            DateTime dateFrom,
            DateTime dateTo,
            List<TaskStatus> statusHistory,
            String title,
            DateTime? due,
            Duration? estimate,
            List<String>? checklistIds,
            String? languageCode)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskData() when $default != null:
        return $default(
            _that.status,
            _that.dateFrom,
            _that.dateTo,
            _that.statusHistory,
            _that.title,
            _that.due,
            _that.estimate,
            _that.checklistIds,
            _that.languageCode);
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
            TaskStatus status,
            DateTime dateFrom,
            DateTime dateTo,
            List<TaskStatus> statusHistory,
            String title,
            DateTime? due,
            Duration? estimate,
            List<String>? checklistIds,
            String? languageCode)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskData():
        return $default(
            _that.status,
            _that.dateFrom,
            _that.dateTo,
            _that.statusHistory,
            _that.title,
            _that.due,
            _that.estimate,
            _that.checklistIds,
            _that.languageCode);
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
            TaskStatus status,
            DateTime dateFrom,
            DateTime dateTo,
            List<TaskStatus> statusHistory,
            String title,
            DateTime? due,
            Duration? estimate,
            List<String>? checklistIds,
            String? languageCode)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TaskData() when $default != null:
        return $default(
            _that.status,
            _that.dateFrom,
            _that.dateTo,
            _that.statusHistory,
            _that.title,
            _that.due,
            _that.estimate,
            _that.checklistIds,
            _that.languageCode);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TaskData implements TaskData {
  const _TaskData(
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
  factory _TaskData.fromJson(Map<String, dynamic> json) =>
      _$TaskDataFromJson(json);

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

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TaskDataCopyWith<_TaskData> get copyWith =>
      __$TaskDataCopyWithImpl<_TaskData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TaskDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TaskData &&
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

  @override
  String toString() {
    return 'TaskData(status: $status, dateFrom: $dateFrom, dateTo: $dateTo, statusHistory: $statusHistory, title: $title, due: $due, estimate: $estimate, checklistIds: $checklistIds, languageCode: $languageCode)';
  }
}

/// @nodoc
abstract mixin class _$TaskDataCopyWith<$Res>
    implements $TaskDataCopyWith<$Res> {
  factory _$TaskDataCopyWith(_TaskData value, $Res Function(_TaskData) _then) =
      __$TaskDataCopyWithImpl;
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
class __$TaskDataCopyWithImpl<$Res> implements _$TaskDataCopyWith<$Res> {
  __$TaskDataCopyWithImpl(this._self, this._then);

  final _TaskData _self;
  final $Res Function(_TaskData) _then;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_TaskData(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as TaskStatus,
      dateFrom: null == dateFrom
          ? _self.dateFrom
          : dateFrom // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dateTo: null == dateTo
          ? _self.dateTo
          : dateTo // ignore: cast_nullable_to_non_nullable
              as DateTime,
      statusHistory: null == statusHistory
          ? _self._statusHistory
          : statusHistory // ignore: cast_nullable_to_non_nullable
              as List<TaskStatus>,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      due: freezed == due
          ? _self.due
          : due // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimate: freezed == estimate
          ? _self.estimate
          : estimate // ignore: cast_nullable_to_non_nullable
              as Duration?,
      checklistIds: freezed == checklistIds
          ? _self._checklistIds
          : checklistIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      languageCode: freezed == languageCode
          ? _self.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TaskStatusCopyWith<$Res> get status {
    return $TaskStatusCopyWith<$Res>(_self.status, (value) {
      return _then(_self.copyWith(status: value));
    });
  }
}

// dart format on
