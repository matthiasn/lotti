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
    TResult Function(_TaskOpen value)? open,
    TResult Function(_TaskInProgress value)? inProgress,
    TResult Function(_TaskGroomed value)? groomed,
    TResult Function(_TaskBlocked value)? blocked,
    TResult Function(_TaskOnHold value)? onHold,
    TResult Function(_TaskDone value)? done,
    TResult Function(_TaskRejected value)? rejected,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TaskOpen() when open != null:
        return open(_that);
      case _TaskInProgress() when inProgress != null:
        return inProgress(_that);
      case _TaskGroomed() when groomed != null:
        return groomed(_that);
      case _TaskBlocked() when blocked != null:
        return blocked(_that);
      case _TaskOnHold() when onHold != null:
        return onHold(_that);
      case _TaskDone() when done != null:
        return done(_that);
      case _TaskRejected() when rejected != null:
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
    required TResult Function(_TaskOpen value) open,
    required TResult Function(_TaskInProgress value) inProgress,
    required TResult Function(_TaskGroomed value) groomed,
    required TResult Function(_TaskBlocked value) blocked,
    required TResult Function(_TaskOnHold value) onHold,
    required TResult Function(_TaskDone value) done,
    required TResult Function(_TaskRejected value) rejected,
  }) {
    final _that = this;
    switch (_that) {
      case _TaskOpen():
        return open(_that);
      case _TaskInProgress():
        return inProgress(_that);
      case _TaskGroomed():
        return groomed(_that);
      case _TaskBlocked():
        return blocked(_that);
      case _TaskOnHold():
        return onHold(_that);
      case _TaskDone():
        return done(_that);
      case _TaskRejected():
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
    TResult? Function(_TaskOpen value)? open,
    TResult? Function(_TaskInProgress value)? inProgress,
    TResult? Function(_TaskGroomed value)? groomed,
    TResult? Function(_TaskBlocked value)? blocked,
    TResult? Function(_TaskOnHold value)? onHold,
    TResult? Function(_TaskDone value)? done,
    TResult? Function(_TaskRejected value)? rejected,
  }) {
    final _that = this;
    switch (_that) {
      case _TaskOpen() when open != null:
        return open(_that);
      case _TaskInProgress() when inProgress != null:
        return inProgress(_that);
      case _TaskGroomed() when groomed != null:
        return groomed(_that);
      case _TaskBlocked() when blocked != null:
        return blocked(_that);
      case _TaskOnHold() when onHold != null:
        return onHold(_that);
      case _TaskDone() when done != null:
        return done(_that);
      case _TaskRejected() when rejected != null:
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
      case _TaskOpen() when open != null:
        return open(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case _TaskInProgress() when inProgress != null:
        return inProgress(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _TaskGroomed() when groomed != null:
        return groomed(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _TaskBlocked() when blocked != null:
        return blocked(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case _TaskOnHold() when onHold != null:
        return onHold(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case _TaskDone() when done != null:
        return done(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case _TaskRejected() when rejected != null:
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
      case _TaskOpen():
        return open(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case _TaskInProgress():
        return inProgress(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _TaskGroomed():
        return groomed(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _TaskBlocked():
        return blocked(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case _TaskOnHold():
        return onHold(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case _TaskDone():
        return done(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case _TaskRejected():
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
      case _TaskOpen() when open != null:
        return open(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case _TaskInProgress() when inProgress != null:
        return inProgress(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _TaskGroomed() when groomed != null:
        return groomed(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _TaskBlocked() when blocked != null:
        return blocked(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case _TaskOnHold() when onHold != null:
        return onHold(_that.id, _that.createdAt, _that.utcOffset, _that.reason,
            _that.timezone, _that.geolocation);
      case _TaskDone() when done != null:
        return done(_that.id, _that.createdAt, _that.utcOffset, _that.timezone,
            _that.geolocation);
      case _TaskRejected() when rejected != null:
        return rejected(_that.id, _that.createdAt, _that.utcOffset,
            _that.timezone, _that.geolocation);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TaskOpen implements TaskStatus {
  const _TaskOpen(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'open';
  factory _TaskOpen.fromJson(Map<String, dynamic> json) =>
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
  _$TaskOpenCopyWith<_TaskOpen> get copyWith =>
      __$TaskOpenCopyWithImpl<_TaskOpen>(this, _$identity);

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
            other is _TaskOpen &&
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
abstract mixin class _$TaskOpenCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$TaskOpenCopyWith(_TaskOpen value, $Res Function(_TaskOpen) _then) =
      __$TaskOpenCopyWithImpl;
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
class __$TaskOpenCopyWithImpl<$Res> implements _$TaskOpenCopyWith<$Res> {
  __$TaskOpenCopyWithImpl(this._self, this._then);

  final _TaskOpen _self;
  final $Res Function(_TaskOpen) _then;

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
    return _then(_TaskOpen(
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
class _TaskInProgress implements TaskStatus {
  const _TaskInProgress(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'inProgress';
  factory _TaskInProgress.fromJson(Map<String, dynamic> json) =>
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
  _$TaskInProgressCopyWith<_TaskInProgress> get copyWith =>
      __$TaskInProgressCopyWithImpl<_TaskInProgress>(this, _$identity);

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
            other is _TaskInProgress &&
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
abstract mixin class _$TaskInProgressCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$TaskInProgressCopyWith(
          _TaskInProgress value, $Res Function(_TaskInProgress) _then) =
      __$TaskInProgressCopyWithImpl;
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
class __$TaskInProgressCopyWithImpl<$Res>
    implements _$TaskInProgressCopyWith<$Res> {
  __$TaskInProgressCopyWithImpl(this._self, this._then);

  final _TaskInProgress _self;
  final $Res Function(_TaskInProgress) _then;

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
    return _then(_TaskInProgress(
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
class _TaskGroomed implements TaskStatus {
  const _TaskGroomed(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'groomed';
  factory _TaskGroomed.fromJson(Map<String, dynamic> json) =>
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
  _$TaskGroomedCopyWith<_TaskGroomed> get copyWith =>
      __$TaskGroomedCopyWithImpl<_TaskGroomed>(this, _$identity);

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
            other is _TaskGroomed &&
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
abstract mixin class _$TaskGroomedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$TaskGroomedCopyWith(
          _TaskGroomed value, $Res Function(_TaskGroomed) _then) =
      __$TaskGroomedCopyWithImpl;
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
class __$TaskGroomedCopyWithImpl<$Res> implements _$TaskGroomedCopyWith<$Res> {
  __$TaskGroomedCopyWithImpl(this._self, this._then);

  final _TaskGroomed _self;
  final $Res Function(_TaskGroomed) _then;

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
    return _then(_TaskGroomed(
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
class _TaskBlocked implements TaskStatus {
  const _TaskBlocked(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'blocked';
  factory _TaskBlocked.fromJson(Map<String, dynamic> json) =>
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
  _$TaskBlockedCopyWith<_TaskBlocked> get copyWith =>
      __$TaskBlockedCopyWithImpl<_TaskBlocked>(this, _$identity);

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
            other is _TaskBlocked &&
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
abstract mixin class _$TaskBlockedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$TaskBlockedCopyWith(
          _TaskBlocked value, $Res Function(_TaskBlocked) _then) =
      __$TaskBlockedCopyWithImpl;
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
class __$TaskBlockedCopyWithImpl<$Res> implements _$TaskBlockedCopyWith<$Res> {
  __$TaskBlockedCopyWithImpl(this._self, this._then);

  final _TaskBlocked _self;
  final $Res Function(_TaskBlocked) _then;

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
    return _then(_TaskBlocked(
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
class _TaskOnHold implements TaskStatus {
  const _TaskOnHold(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      required this.reason,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'onHold';
  factory _TaskOnHold.fromJson(Map<String, dynamic> json) =>
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
  _$TaskOnHoldCopyWith<_TaskOnHold> get copyWith =>
      __$TaskOnHoldCopyWithImpl<_TaskOnHold>(this, _$identity);

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
            other is _TaskOnHold &&
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
abstract mixin class _$TaskOnHoldCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$TaskOnHoldCopyWith(
          _TaskOnHold value, $Res Function(_TaskOnHold) _then) =
      __$TaskOnHoldCopyWithImpl;
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
class __$TaskOnHoldCopyWithImpl<$Res> implements _$TaskOnHoldCopyWith<$Res> {
  __$TaskOnHoldCopyWithImpl(this._self, this._then);

  final _TaskOnHold _self;
  final $Res Function(_TaskOnHold) _then;

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
    return _then(_TaskOnHold(
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
class _TaskDone implements TaskStatus {
  const _TaskDone(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'done';
  factory _TaskDone.fromJson(Map<String, dynamic> json) =>
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
  _$TaskDoneCopyWith<_TaskDone> get copyWith =>
      __$TaskDoneCopyWithImpl<_TaskDone>(this, _$identity);

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
            other is _TaskDone &&
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
abstract mixin class _$TaskDoneCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$TaskDoneCopyWith(_TaskDone value, $Res Function(_TaskDone) _then) =
      __$TaskDoneCopyWithImpl;
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
class __$TaskDoneCopyWithImpl<$Res> implements _$TaskDoneCopyWith<$Res> {
  __$TaskDoneCopyWithImpl(this._self, this._then);

  final _TaskDone _self;
  final $Res Function(_TaskDone) _then;

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
    return _then(_TaskDone(
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
class _TaskRejected implements TaskStatus {
  const _TaskRejected(
      {required this.id,
      required this.createdAt,
      required this.utcOffset,
      this.timezone,
      this.geolocation,
      final String? $type})
      : $type = $type ?? 'rejected';
  factory _TaskRejected.fromJson(Map<String, dynamic> json) =>
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
  _$TaskRejectedCopyWith<_TaskRejected> get copyWith =>
      __$TaskRejectedCopyWithImpl<_TaskRejected>(this, _$identity);

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
            other is _TaskRejected &&
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
abstract mixin class _$TaskRejectedCopyWith<$Res>
    implements $TaskStatusCopyWith<$Res> {
  factory _$TaskRejectedCopyWith(
          _TaskRejected value, $Res Function(_TaskRejected) _then) =
      __$TaskRejectedCopyWithImpl;
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
class __$TaskRejectedCopyWithImpl<$Res>
    implements _$TaskRejectedCopyWith<$Res> {
  __$TaskRejectedCopyWithImpl(this._self, this._then);

  final _TaskRejected _self;
  final $Res Function(_TaskRejected) _then;

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
    return _then(_TaskRejected(
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
