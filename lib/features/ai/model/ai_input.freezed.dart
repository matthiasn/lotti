// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AiInputTaskObject _$AiInputTaskObjectFromJson(Map<String, dynamic> json) {
  return _AiInputTaskObject.fromJson(json);
}

/// @nodoc
mixin _$AiInputTaskObject {
  String get title => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  Duration get estimatedDuration => throw _privateConstructorUsedError;
  Duration get timeSpent => throw _privateConstructorUsedError;
  DateTime get creationDate => throw _privateConstructorUsedError;
  List<AiInputActionItemObject> get actionItems =>
      throw _privateConstructorUsedError;
  List<AiInputLogEntryObject> get logEntries =>
      throw _privateConstructorUsedError;

  /// Serializes this AiInputTaskObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiInputTaskObjectCopyWith<AiInputTaskObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiInputTaskObjectCopyWith<$Res> {
  factory $AiInputTaskObjectCopyWith(
          AiInputTaskObject value, $Res Function(AiInputTaskObject) then) =
      _$AiInputTaskObjectCopyWithImpl<$Res, AiInputTaskObject>;
  @useResult
  $Res call(
      {String title,
      String status,
      Duration estimatedDuration,
      Duration timeSpent,
      DateTime creationDate,
      List<AiInputActionItemObject> actionItems,
      List<AiInputLogEntryObject> logEntries});
}

/// @nodoc
class _$AiInputTaskObjectCopyWithImpl<$Res, $Val extends AiInputTaskObject>
    implements $AiInputTaskObjectCopyWith<$Res> {
  _$AiInputTaskObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? status = null,
    Object? estimatedDuration = null,
    Object? timeSpent = null,
    Object? creationDate = null,
    Object? actionItems = null,
    Object? logEntries = null,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedDuration: null == estimatedDuration
          ? _value.estimatedDuration
          : estimatedDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      timeSpent: null == timeSpent
          ? _value.timeSpent
          : timeSpent // ignore: cast_nullable_to_non_nullable
              as Duration,
      creationDate: null == creationDate
          ? _value.creationDate
          : creationDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      actionItems: null == actionItems
          ? _value.actionItems
          : actionItems // ignore: cast_nullable_to_non_nullable
              as List<AiInputActionItemObject>,
      logEntries: null == logEntries
          ? _value.logEntries
          : logEntries // ignore: cast_nullable_to_non_nullable
              as List<AiInputLogEntryObject>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiInputTaskObjectImplCopyWith<$Res>
    implements $AiInputTaskObjectCopyWith<$Res> {
  factory _$$AiInputTaskObjectImplCopyWith(_$AiInputTaskObjectImpl value,
          $Res Function(_$AiInputTaskObjectImpl) then) =
      __$$AiInputTaskObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String title,
      String status,
      Duration estimatedDuration,
      Duration timeSpent,
      DateTime creationDate,
      List<AiInputActionItemObject> actionItems,
      List<AiInputLogEntryObject> logEntries});
}

/// @nodoc
class __$$AiInputTaskObjectImplCopyWithImpl<$Res>
    extends _$AiInputTaskObjectCopyWithImpl<$Res, _$AiInputTaskObjectImpl>
    implements _$$AiInputTaskObjectImplCopyWith<$Res> {
  __$$AiInputTaskObjectImplCopyWithImpl(_$AiInputTaskObjectImpl _value,
      $Res Function(_$AiInputTaskObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? status = null,
    Object? estimatedDuration = null,
    Object? timeSpent = null,
    Object? creationDate = null,
    Object? actionItems = null,
    Object? logEntries = null,
  }) {
    return _then(_$AiInputTaskObjectImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedDuration: null == estimatedDuration
          ? _value.estimatedDuration
          : estimatedDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      timeSpent: null == timeSpent
          ? _value.timeSpent
          : timeSpent // ignore: cast_nullable_to_non_nullable
              as Duration,
      creationDate: null == creationDate
          ? _value.creationDate
          : creationDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      actionItems: null == actionItems
          ? _value._actionItems
          : actionItems // ignore: cast_nullable_to_non_nullable
              as List<AiInputActionItemObject>,
      logEntries: null == logEntries
          ? _value._logEntries
          : logEntries // ignore: cast_nullable_to_non_nullable
              as List<AiInputLogEntryObject>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiInputTaskObjectImpl implements _AiInputTaskObject {
  const _$AiInputTaskObjectImpl(
      {required this.title,
      required this.status,
      required this.estimatedDuration,
      required this.timeSpent,
      required this.creationDate,
      required final List<AiInputActionItemObject> actionItems,
      required final List<AiInputLogEntryObject> logEntries})
      : _actionItems = actionItems,
        _logEntries = logEntries;

  factory _$AiInputTaskObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiInputTaskObjectImplFromJson(json);

  @override
  final String title;
  @override
  final String status;
  @override
  final Duration estimatedDuration;
  @override
  final Duration timeSpent;
  @override
  final DateTime creationDate;
  final List<AiInputActionItemObject> _actionItems;
  @override
  List<AiInputActionItemObject> get actionItems {
    if (_actionItems is EqualUnmodifiableListView) return _actionItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_actionItems);
  }

  final List<AiInputLogEntryObject> _logEntries;
  @override
  List<AiInputLogEntryObject> get logEntries {
    if (_logEntries is EqualUnmodifiableListView) return _logEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_logEntries);
  }

  @override
  String toString() {
    return 'AiInputTaskObject(title: $title, status: $status, estimatedDuration: $estimatedDuration, timeSpent: $timeSpent, creationDate: $creationDate, actionItems: $actionItems, logEntries: $logEntries)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiInputTaskObjectImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.estimatedDuration, estimatedDuration) ||
                other.estimatedDuration == estimatedDuration) &&
            (identical(other.timeSpent, timeSpent) ||
                other.timeSpent == timeSpent) &&
            (identical(other.creationDate, creationDate) ||
                other.creationDate == creationDate) &&
            const DeepCollectionEquality()
                .equals(other._actionItems, _actionItems) &&
            const DeepCollectionEquality()
                .equals(other._logEntries, _logEntries));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      title,
      status,
      estimatedDuration,
      timeSpent,
      creationDate,
      const DeepCollectionEquality().hash(_actionItems),
      const DeepCollectionEquality().hash(_logEntries));

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiInputTaskObjectImplCopyWith<_$AiInputTaskObjectImpl> get copyWith =>
      __$$AiInputTaskObjectImplCopyWithImpl<_$AiInputTaskObjectImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AiInputTaskObjectImplToJson(
      this,
    );
  }
}

abstract class _AiInputTaskObject implements AiInputTaskObject {
  const factory _AiInputTaskObject(
          {required final String title,
          required final String status,
          required final Duration estimatedDuration,
          required final Duration timeSpent,
          required final DateTime creationDate,
          required final List<AiInputActionItemObject> actionItems,
          required final List<AiInputLogEntryObject> logEntries}) =
      _$AiInputTaskObjectImpl;

  factory _AiInputTaskObject.fromJson(Map<String, dynamic> json) =
      _$AiInputTaskObjectImpl.fromJson;

  @override
  String get title;
  @override
  String get status;
  @override
  Duration get estimatedDuration;
  @override
  Duration get timeSpent;
  @override
  DateTime get creationDate;
  @override
  List<AiInputActionItemObject> get actionItems;
  @override
  List<AiInputLogEntryObject> get logEntries;

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiInputTaskObjectImplCopyWith<_$AiInputTaskObjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AiInputActionItemObject _$AiInputActionItemObjectFromJson(
    Map<String, dynamic> json) {
  return _AiInputActionItemObject.fromJson(json);
}

/// @nodoc
mixin _$AiInputActionItemObject {
  String get title => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;
  DateTime? get deadline => throw _privateConstructorUsedError;
  DateTime? get completionDate => throw _privateConstructorUsedError;

  /// Serializes this AiInputActionItemObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiInputActionItemObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiInputActionItemObjectCopyWith<AiInputActionItemObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiInputActionItemObjectCopyWith<$Res> {
  factory $AiInputActionItemObjectCopyWith(AiInputActionItemObject value,
          $Res Function(AiInputActionItemObject) then) =
      _$AiInputActionItemObjectCopyWithImpl<$Res, AiInputActionItemObject>;
  @useResult
  $Res call(
      {String title,
      bool completed,
      DateTime? deadline,
      DateTime? completionDate});
}

/// @nodoc
class _$AiInputActionItemObjectCopyWithImpl<$Res,
        $Val extends AiInputActionItemObject>
    implements $AiInputActionItemObjectCopyWith<$Res> {
  _$AiInputActionItemObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiInputActionItemObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? completed = null,
    Object? deadline = freezed,
    Object? completionDate = freezed,
  }) {
    return _then(_value.copyWith(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      deadline: freezed == deadline
          ? _value.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionDate: freezed == completionDate
          ? _value.completionDate
          : completionDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiInputActionItemObjectImplCopyWith<$Res>
    implements $AiInputActionItemObjectCopyWith<$Res> {
  factory _$$AiInputActionItemObjectImplCopyWith(
          _$AiInputActionItemObjectImpl value,
          $Res Function(_$AiInputActionItemObjectImpl) then) =
      __$$AiInputActionItemObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String title,
      bool completed,
      DateTime? deadline,
      DateTime? completionDate});
}

/// @nodoc
class __$$AiInputActionItemObjectImplCopyWithImpl<$Res>
    extends _$AiInputActionItemObjectCopyWithImpl<$Res,
        _$AiInputActionItemObjectImpl>
    implements _$$AiInputActionItemObjectImplCopyWith<$Res> {
  __$$AiInputActionItemObjectImplCopyWithImpl(
      _$AiInputActionItemObjectImpl _value,
      $Res Function(_$AiInputActionItemObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiInputActionItemObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? completed = null,
    Object? deadline = freezed,
    Object? completionDate = freezed,
  }) {
    return _then(_$AiInputActionItemObjectImpl(
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      deadline: freezed == deadline
          ? _value.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionDate: freezed == completionDate
          ? _value.completionDate
          : completionDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiInputActionItemObjectImpl implements _AiInputActionItemObject {
  const _$AiInputActionItemObjectImpl(
      {required this.title,
      required this.completed,
      this.deadline,
      this.completionDate});

  factory _$AiInputActionItemObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiInputActionItemObjectImplFromJson(json);

  @override
  final String title;
  @override
  final bool completed;
  @override
  final DateTime? deadline;
  @override
  final DateTime? completionDate;

  @override
  String toString() {
    return 'AiInputActionItemObject(title: $title, completed: $completed, deadline: $deadline, completionDate: $completionDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiInputActionItemObjectImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.completionDate, completionDate) ||
                other.completionDate == completionDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, title, completed, deadline, completionDate);

  /// Create a copy of AiInputActionItemObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiInputActionItemObjectImplCopyWith<_$AiInputActionItemObjectImpl>
      get copyWith => __$$AiInputActionItemObjectImplCopyWithImpl<
          _$AiInputActionItemObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AiInputActionItemObjectImplToJson(
      this,
    );
  }
}

abstract class _AiInputActionItemObject implements AiInputActionItemObject {
  const factory _AiInputActionItemObject(
      {required final String title,
      required final bool completed,
      final DateTime? deadline,
      final DateTime? completionDate}) = _$AiInputActionItemObjectImpl;

  factory _AiInputActionItemObject.fromJson(Map<String, dynamic> json) =
      _$AiInputActionItemObjectImpl.fromJson;

  @override
  String get title;
  @override
  bool get completed;
  @override
  DateTime? get deadline;
  @override
  DateTime? get completionDate;

  /// Create a copy of AiInputActionItemObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiInputActionItemObjectImplCopyWith<_$AiInputActionItemObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

AiInputLogEntryObject _$AiInputLogEntryObjectFromJson(
    Map<String, dynamic> json) {
  return _AiInputLogEntryObject.fromJson(json);
}

/// @nodoc
mixin _$AiInputLogEntryObject {
  DateTime get creationTimestamp => throw _privateConstructorUsedError;
  Duration get loggedDuration => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;

  /// Serializes this AiInputLogEntryObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiInputLogEntryObjectCopyWith<AiInputLogEntryObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiInputLogEntryObjectCopyWith<$Res> {
  factory $AiInputLogEntryObjectCopyWith(AiInputLogEntryObject value,
          $Res Function(AiInputLogEntryObject) then) =
      _$AiInputLogEntryObjectCopyWithImpl<$Res, AiInputLogEntryObject>;
  @useResult
  $Res call({DateTime creationTimestamp, Duration loggedDuration, String text});
}

/// @nodoc
class _$AiInputLogEntryObjectCopyWithImpl<$Res,
        $Val extends AiInputLogEntryObject>
    implements $AiInputLogEntryObjectCopyWith<$Res> {
  _$AiInputLogEntryObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? creationTimestamp = null,
    Object? loggedDuration = null,
    Object? text = null,
  }) {
    return _then(_value.copyWith(
      creationTimestamp: null == creationTimestamp
          ? _value.creationTimestamp
          : creationTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      loggedDuration: null == loggedDuration
          ? _value.loggedDuration
          : loggedDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AiInputLogEntryObjectImplCopyWith<$Res>
    implements $AiInputLogEntryObjectCopyWith<$Res> {
  factory _$$AiInputLogEntryObjectImplCopyWith(
          _$AiInputLogEntryObjectImpl value,
          $Res Function(_$AiInputLogEntryObjectImpl) then) =
      __$$AiInputLogEntryObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({DateTime creationTimestamp, Duration loggedDuration, String text});
}

/// @nodoc
class __$$AiInputLogEntryObjectImplCopyWithImpl<$Res>
    extends _$AiInputLogEntryObjectCopyWithImpl<$Res,
        _$AiInputLogEntryObjectImpl>
    implements _$$AiInputLogEntryObjectImplCopyWith<$Res> {
  __$$AiInputLogEntryObjectImplCopyWithImpl(_$AiInputLogEntryObjectImpl _value,
      $Res Function(_$AiInputLogEntryObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? creationTimestamp = null,
    Object? loggedDuration = null,
    Object? text = null,
  }) {
    return _then(_$AiInputLogEntryObjectImpl(
      creationTimestamp: null == creationTimestamp
          ? _value.creationTimestamp
          : creationTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      loggedDuration: null == loggedDuration
          ? _value.loggedDuration
          : loggedDuration // ignore: cast_nullable_to_non_nullable
              as Duration,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AiInputLogEntryObjectImpl implements _AiInputLogEntryObject {
  const _$AiInputLogEntryObjectImpl(
      {required this.creationTimestamp,
      required this.loggedDuration,
      required this.text});

  factory _$AiInputLogEntryObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiInputLogEntryObjectImplFromJson(json);

  @override
  final DateTime creationTimestamp;
  @override
  final Duration loggedDuration;
  @override
  final String text;

  @override
  String toString() {
    return 'AiInputLogEntryObject(creationTimestamp: $creationTimestamp, loggedDuration: $loggedDuration, text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiInputLogEntryObjectImpl &&
            (identical(other.creationTimestamp, creationTimestamp) ||
                other.creationTimestamp == creationTimestamp) &&
            (identical(other.loggedDuration, loggedDuration) ||
                other.loggedDuration == loggedDuration) &&
            (identical(other.text, text) || other.text == text));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, creationTimestamp, loggedDuration, text);

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiInputLogEntryObjectImplCopyWith<_$AiInputLogEntryObjectImpl>
      get copyWith => __$$AiInputLogEntryObjectImplCopyWithImpl<
          _$AiInputLogEntryObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AiInputLogEntryObjectImplToJson(
      this,
    );
  }
}

abstract class _AiInputLogEntryObject implements AiInputLogEntryObject {
  const factory _AiInputLogEntryObject(
      {required final DateTime creationTimestamp,
      required final Duration loggedDuration,
      required final String text}) = _$AiInputLogEntryObjectImpl;

  factory _AiInputLogEntryObject.fromJson(Map<String, dynamic> json) =
      _$AiInputLogEntryObjectImpl.fromJson;

  @override
  DateTime get creationTimestamp;
  @override
  Duration get loggedDuration;
  @override
  String get text;

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiInputLogEntryObjectImplCopyWith<_$AiInputLogEntryObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}
