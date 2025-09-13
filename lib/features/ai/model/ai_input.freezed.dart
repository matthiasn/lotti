// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AiInputTaskObject {
  String get title;
  String get status;
  String get estimatedDuration;
  String get timeSpent;
  DateTime get creationDate;
  List<AiActionItem> get actionItems;
  List<AiInputLogEntryObject> get logEntries;
  String? get languageCode;

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiInputTaskObjectCopyWith<AiInputTaskObject> get copyWith =>
      _$AiInputTaskObjectCopyWithImpl<AiInputTaskObject>(
          this as AiInputTaskObject, _$identity);

  /// Serializes this AiInputTaskObject to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiInputTaskObject &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.estimatedDuration, estimatedDuration) ||
                other.estimatedDuration == estimatedDuration) &&
            (identical(other.timeSpent, timeSpent) ||
                other.timeSpent == timeSpent) &&
            (identical(other.creationDate, creationDate) ||
                other.creationDate == creationDate) &&
            const DeepCollectionEquality()
                .equals(other.actionItems, actionItems) &&
            const DeepCollectionEquality()
                .equals(other.logEntries, logEntries) &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode));
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
      const DeepCollectionEquality().hash(actionItems),
      const DeepCollectionEquality().hash(logEntries),
      languageCode);

  @override
  String toString() {
    return 'AiInputTaskObject(title: $title, status: $status, estimatedDuration: $estimatedDuration, timeSpent: $timeSpent, creationDate: $creationDate, actionItems: $actionItems, logEntries: $logEntries, languageCode: $languageCode)';
  }
}

/// @nodoc
abstract mixin class $AiInputTaskObjectCopyWith<$Res> {
  factory $AiInputTaskObjectCopyWith(
          AiInputTaskObject value, $Res Function(AiInputTaskObject) _then) =
      _$AiInputTaskObjectCopyWithImpl;
  @useResult
  $Res call(
      {String title,
      String status,
      String estimatedDuration,
      String timeSpent,
      DateTime creationDate,
      List<AiActionItem> actionItems,
      List<AiInputLogEntryObject> logEntries,
      String? languageCode});
}

/// @nodoc
class _$AiInputTaskObjectCopyWithImpl<$Res>
    implements $AiInputTaskObjectCopyWith<$Res> {
  _$AiInputTaskObjectCopyWithImpl(this._self, this._then);

  final AiInputTaskObject _self;
  final $Res Function(AiInputTaskObject) _then;

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
    Object? languageCode = freezed,
  }) {
    return _then(_self.copyWith(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedDuration: null == estimatedDuration
          ? _self.estimatedDuration
          : estimatedDuration // ignore: cast_nullable_to_non_nullable
              as String,
      timeSpent: null == timeSpent
          ? _self.timeSpent
          : timeSpent // ignore: cast_nullable_to_non_nullable
              as String,
      creationDate: null == creationDate
          ? _self.creationDate
          : creationDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      actionItems: null == actionItems
          ? _self.actionItems
          : actionItems // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>,
      logEntries: null == logEntries
          ? _self.logEntries
          : logEntries // ignore: cast_nullable_to_non_nullable
              as List<AiInputLogEntryObject>,
      languageCode: freezed == languageCode
          ? _self.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiInputTaskObject].
extension AiInputTaskObjectPatterns on AiInputTaskObject {
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
    TResult Function(_AiInputTaskObject value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiInputTaskObject() when $default != null:
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
    TResult Function(_AiInputTaskObject value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputTaskObject():
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
    TResult? Function(_AiInputTaskObject value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputTaskObject() when $default != null:
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
            String title,
            String status,
            String estimatedDuration,
            String timeSpent,
            DateTime creationDate,
            List<AiActionItem> actionItems,
            List<AiInputLogEntryObject> logEntries,
            String? languageCode)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiInputTaskObject() when $default != null:
        return $default(
            _that.title,
            _that.status,
            _that.estimatedDuration,
            _that.timeSpent,
            _that.creationDate,
            _that.actionItems,
            _that.logEntries,
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
            String title,
            String status,
            String estimatedDuration,
            String timeSpent,
            DateTime creationDate,
            List<AiActionItem> actionItems,
            List<AiInputLogEntryObject> logEntries,
            String? languageCode)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputTaskObject():
        return $default(
            _that.title,
            _that.status,
            _that.estimatedDuration,
            _that.timeSpent,
            _that.creationDate,
            _that.actionItems,
            _that.logEntries,
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
            String title,
            String status,
            String estimatedDuration,
            String timeSpent,
            DateTime creationDate,
            List<AiActionItem> actionItems,
            List<AiInputLogEntryObject> logEntries,
            String? languageCode)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputTaskObject() when $default != null:
        return $default(
            _that.title,
            _that.status,
            _that.estimatedDuration,
            _that.timeSpent,
            _that.creationDate,
            _that.actionItems,
            _that.logEntries,
            _that.languageCode);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiInputTaskObject implements AiInputTaskObject {
  const _AiInputTaskObject(
      {required this.title,
      required this.status,
      required this.estimatedDuration,
      required this.timeSpent,
      required this.creationDate,
      required final List<AiActionItem> actionItems,
      required final List<AiInputLogEntryObject> logEntries,
      this.languageCode})
      : _actionItems = actionItems,
        _logEntries = logEntries;
  factory _AiInputTaskObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputTaskObjectFromJson(json);

  @override
  final String title;
  @override
  final String status;
  @override
  final String estimatedDuration;
  @override
  final String timeSpent;
  @override
  final DateTime creationDate;
  final List<AiActionItem> _actionItems;
  @override
  List<AiActionItem> get actionItems {
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
  final String? languageCode;

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiInputTaskObjectCopyWith<_AiInputTaskObject> get copyWith =>
      __$AiInputTaskObjectCopyWithImpl<_AiInputTaskObject>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiInputTaskObjectToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiInputTaskObject &&
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
                .equals(other._logEntries, _logEntries) &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode));
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
      const DeepCollectionEquality().hash(_logEntries),
      languageCode);

  @override
  String toString() {
    return 'AiInputTaskObject(title: $title, status: $status, estimatedDuration: $estimatedDuration, timeSpent: $timeSpent, creationDate: $creationDate, actionItems: $actionItems, logEntries: $logEntries, languageCode: $languageCode)';
  }
}

/// @nodoc
abstract mixin class _$AiInputTaskObjectCopyWith<$Res>
    implements $AiInputTaskObjectCopyWith<$Res> {
  factory _$AiInputTaskObjectCopyWith(
          _AiInputTaskObject value, $Res Function(_AiInputTaskObject) _then) =
      __$AiInputTaskObjectCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String title,
      String status,
      String estimatedDuration,
      String timeSpent,
      DateTime creationDate,
      List<AiActionItem> actionItems,
      List<AiInputLogEntryObject> logEntries,
      String? languageCode});
}

/// @nodoc
class __$AiInputTaskObjectCopyWithImpl<$Res>
    implements _$AiInputTaskObjectCopyWith<$Res> {
  __$AiInputTaskObjectCopyWithImpl(this._self, this._then);

  final _AiInputTaskObject _self;
  final $Res Function(_AiInputTaskObject) _then;

  /// Create a copy of AiInputTaskObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? title = null,
    Object? status = null,
    Object? estimatedDuration = null,
    Object? timeSpent = null,
    Object? creationDate = null,
    Object? actionItems = null,
    Object? logEntries = null,
    Object? languageCode = freezed,
  }) {
    return _then(_AiInputTaskObject(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedDuration: null == estimatedDuration
          ? _self.estimatedDuration
          : estimatedDuration // ignore: cast_nullable_to_non_nullable
              as String,
      timeSpent: null == timeSpent
          ? _self.timeSpent
          : timeSpent // ignore: cast_nullable_to_non_nullable
              as String,
      creationDate: null == creationDate
          ? _self.creationDate
          : creationDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      actionItems: null == actionItems
          ? _self._actionItems
          : actionItems // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>,
      logEntries: null == logEntries
          ? _self._logEntries
          : logEntries // ignore: cast_nullable_to_non_nullable
              as List<AiInputLogEntryObject>,
      languageCode: freezed == languageCode
          ? _self.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$AiActionItem {
  String get title;
  bool get completed;
  String? get id;
  DateTime? get deadline;
  DateTime? get completionDate;

  /// Create a copy of AiActionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiActionItemCopyWith<AiActionItem> get copyWith =>
      _$AiActionItemCopyWithImpl<AiActionItem>(
          this as AiActionItem, _$identity);

  /// Serializes this AiActionItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiActionItem &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.completionDate, completionDate) ||
                other.completionDate == completionDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, title, completed, id, deadline, completionDate);

  @override
  String toString() {
    return 'AiActionItem(title: $title, completed: $completed, id: $id, deadline: $deadline, completionDate: $completionDate)';
  }
}

/// @nodoc
abstract mixin class $AiActionItemCopyWith<$Res> {
  factory $AiActionItemCopyWith(
          AiActionItem value, $Res Function(AiActionItem) _then) =
      _$AiActionItemCopyWithImpl;
  @useResult
  $Res call(
      {String title,
      bool completed,
      String? id,
      DateTime? deadline,
      DateTime? completionDate});
}

/// @nodoc
class _$AiActionItemCopyWithImpl<$Res> implements $AiActionItemCopyWith<$Res> {
  _$AiActionItemCopyWithImpl(this._self, this._then);

  final AiActionItem _self;
  final $Res Function(AiActionItem) _then;

  /// Create a copy of AiActionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? completed = null,
    Object? id = freezed,
    Object? deadline = freezed,
    Object? completionDate = freezed,
  }) {
    return _then(_self.copyWith(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      completed: null == completed
          ? _self.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      deadline: freezed == deadline
          ? _self.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionDate: freezed == completionDate
          ? _self.completionDate
          : completionDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiActionItem].
extension AiActionItemPatterns on AiActionItem {
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
    TResult Function(_AiActionItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiActionItem() when $default != null:
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
    TResult Function(_AiActionItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiActionItem():
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
    TResult? Function(_AiActionItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiActionItem() when $default != null:
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
    TResult Function(String title, bool completed, String? id,
            DateTime? deadline, DateTime? completionDate)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiActionItem() when $default != null:
        return $default(_that.title, _that.completed, _that.id, _that.deadline,
            _that.completionDate);
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
    TResult Function(String title, bool completed, String? id,
            DateTime? deadline, DateTime? completionDate)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiActionItem():
        return $default(_that.title, _that.completed, _that.id, _that.deadline,
            _that.completionDate);
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
    TResult? Function(String title, bool completed, String? id,
            DateTime? deadline, DateTime? completionDate)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiActionItem() when $default != null:
        return $default(_that.title, _that.completed, _that.id, _that.deadline,
            _that.completionDate);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiActionItem implements AiActionItem {
  const _AiActionItem(
      {required this.title,
      required this.completed,
      this.id,
      this.deadline,
      this.completionDate});
  factory _AiActionItem.fromJson(Map<String, dynamic> json) =>
      _$AiActionItemFromJson(json);

  @override
  final String title;
  @override
  final bool completed;
  @override
  final String? id;
  @override
  final DateTime? deadline;
  @override
  final DateTime? completionDate;

  /// Create a copy of AiActionItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiActionItemCopyWith<_AiActionItem> get copyWith =>
      __$AiActionItemCopyWithImpl<_AiActionItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiActionItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiActionItem &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.deadline, deadline) ||
                other.deadline == deadline) &&
            (identical(other.completionDate, completionDate) ||
                other.completionDate == completionDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, title, completed, id, deadline, completionDate);

  @override
  String toString() {
    return 'AiActionItem(title: $title, completed: $completed, id: $id, deadline: $deadline, completionDate: $completionDate)';
  }
}

/// @nodoc
abstract mixin class _$AiActionItemCopyWith<$Res>
    implements $AiActionItemCopyWith<$Res> {
  factory _$AiActionItemCopyWith(
          _AiActionItem value, $Res Function(_AiActionItem) _then) =
      __$AiActionItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String title,
      bool completed,
      String? id,
      DateTime? deadline,
      DateTime? completionDate});
}

/// @nodoc
class __$AiActionItemCopyWithImpl<$Res>
    implements _$AiActionItemCopyWith<$Res> {
  __$AiActionItemCopyWithImpl(this._self, this._then);

  final _AiActionItem _self;
  final $Res Function(_AiActionItem) _then;

  /// Create a copy of AiActionItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? title = null,
    Object? completed = null,
    Object? id = freezed,
    Object? deadline = freezed,
    Object? completionDate = freezed,
  }) {
    return _then(_AiActionItem(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      completed: null == completed
          ? _self.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      deadline: freezed == deadline
          ? _self.deadline
          : deadline // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completionDate: freezed == completionDate
          ? _self.completionDate
          : completionDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
mixin _$AiInputLogEntryObject {
  DateTime get creationTimestamp;
  String get loggedDuration;
  String get text;
  String? get audioTranscript;
  String? get transcriptLanguage;
  String? get entryType;

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiInputLogEntryObjectCopyWith<AiInputLogEntryObject> get copyWith =>
      _$AiInputLogEntryObjectCopyWithImpl<AiInputLogEntryObject>(
          this as AiInputLogEntryObject, _$identity);

  /// Serializes this AiInputLogEntryObject to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiInputLogEntryObject &&
            (identical(other.creationTimestamp, creationTimestamp) ||
                other.creationTimestamp == creationTimestamp) &&
            (identical(other.loggedDuration, loggedDuration) ||
                other.loggedDuration == loggedDuration) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.audioTranscript, audioTranscript) ||
                other.audioTranscript == audioTranscript) &&
            (identical(other.transcriptLanguage, transcriptLanguage) ||
                other.transcriptLanguage == transcriptLanguage) &&
            (identical(other.entryType, entryType) ||
                other.entryType == entryType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, creationTimestamp,
      loggedDuration, text, audioTranscript, transcriptLanguage, entryType);

  @override
  String toString() {
    return 'AiInputLogEntryObject(creationTimestamp: $creationTimestamp, loggedDuration: $loggedDuration, text: $text, audioTranscript: $audioTranscript, transcriptLanguage: $transcriptLanguage, entryType: $entryType)';
  }
}

/// @nodoc
abstract mixin class $AiInputLogEntryObjectCopyWith<$Res> {
  factory $AiInputLogEntryObjectCopyWith(AiInputLogEntryObject value,
          $Res Function(AiInputLogEntryObject) _then) =
      _$AiInputLogEntryObjectCopyWithImpl;
  @useResult
  $Res call(
      {DateTime creationTimestamp,
      String loggedDuration,
      String text,
      String? audioTranscript,
      String? transcriptLanguage,
      String? entryType});
}

/// @nodoc
class _$AiInputLogEntryObjectCopyWithImpl<$Res>
    implements $AiInputLogEntryObjectCopyWith<$Res> {
  _$AiInputLogEntryObjectCopyWithImpl(this._self, this._then);

  final AiInputLogEntryObject _self;
  final $Res Function(AiInputLogEntryObject) _then;

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? creationTimestamp = null,
    Object? loggedDuration = null,
    Object? text = null,
    Object? audioTranscript = freezed,
    Object? transcriptLanguage = freezed,
    Object? entryType = freezed,
  }) {
    return _then(_self.copyWith(
      creationTimestamp: null == creationTimestamp
          ? _self.creationTimestamp
          : creationTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      loggedDuration: null == loggedDuration
          ? _self.loggedDuration
          : loggedDuration // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      audioTranscript: freezed == audioTranscript
          ? _self.audioTranscript
          : audioTranscript // ignore: cast_nullable_to_non_nullable
              as String?,
      transcriptLanguage: freezed == transcriptLanguage
          ? _self.transcriptLanguage
          : transcriptLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      entryType: freezed == entryType
          ? _self.entryType
          : entryType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiInputLogEntryObject].
extension AiInputLogEntryObjectPatterns on AiInputLogEntryObject {
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
    TResult Function(_AiInputLogEntryObject value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiInputLogEntryObject() when $default != null:
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
    TResult Function(_AiInputLogEntryObject value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputLogEntryObject():
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
    TResult? Function(_AiInputLogEntryObject value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputLogEntryObject() when $default != null:
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
            DateTime creationTimestamp,
            String loggedDuration,
            String text,
            String? audioTranscript,
            String? transcriptLanguage,
            String? entryType)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiInputLogEntryObject() when $default != null:
        return $default(
            _that.creationTimestamp,
            _that.loggedDuration,
            _that.text,
            _that.audioTranscript,
            _that.transcriptLanguage,
            _that.entryType);
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
            DateTime creationTimestamp,
            String loggedDuration,
            String text,
            String? audioTranscript,
            String? transcriptLanguage,
            String? entryType)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputLogEntryObject():
        return $default(
            _that.creationTimestamp,
            _that.loggedDuration,
            _that.text,
            _that.audioTranscript,
            _that.transcriptLanguage,
            _that.entryType);
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
            DateTime creationTimestamp,
            String loggedDuration,
            String text,
            String? audioTranscript,
            String? transcriptLanguage,
            String? entryType)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputLogEntryObject() when $default != null:
        return $default(
            _that.creationTimestamp,
            _that.loggedDuration,
            _that.text,
            _that.audioTranscript,
            _that.transcriptLanguage,
            _that.entryType);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiInputLogEntryObject implements AiInputLogEntryObject {
  const _AiInputLogEntryObject(
      {required this.creationTimestamp,
      required this.loggedDuration,
      required this.text,
      this.audioTranscript,
      this.transcriptLanguage,
      this.entryType});
  factory _AiInputLogEntryObject.fromJson(Map<String, dynamic> json) =>
      _$AiInputLogEntryObjectFromJson(json);

  @override
  final DateTime creationTimestamp;
  @override
  final String loggedDuration;
  @override
  final String text;
  @override
  final String? audioTranscript;
  @override
  final String? transcriptLanguage;
  @override
  final String? entryType;

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiInputLogEntryObjectCopyWith<_AiInputLogEntryObject> get copyWith =>
      __$AiInputLogEntryObjectCopyWithImpl<_AiInputLogEntryObject>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiInputLogEntryObjectToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiInputLogEntryObject &&
            (identical(other.creationTimestamp, creationTimestamp) ||
                other.creationTimestamp == creationTimestamp) &&
            (identical(other.loggedDuration, loggedDuration) ||
                other.loggedDuration == loggedDuration) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.audioTranscript, audioTranscript) ||
                other.audioTranscript == audioTranscript) &&
            (identical(other.transcriptLanguage, transcriptLanguage) ||
                other.transcriptLanguage == transcriptLanguage) &&
            (identical(other.entryType, entryType) ||
                other.entryType == entryType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, creationTimestamp,
      loggedDuration, text, audioTranscript, transcriptLanguage, entryType);

  @override
  String toString() {
    return 'AiInputLogEntryObject(creationTimestamp: $creationTimestamp, loggedDuration: $loggedDuration, text: $text, audioTranscript: $audioTranscript, transcriptLanguage: $transcriptLanguage, entryType: $entryType)';
  }
}

/// @nodoc
abstract mixin class _$AiInputLogEntryObjectCopyWith<$Res>
    implements $AiInputLogEntryObjectCopyWith<$Res> {
  factory _$AiInputLogEntryObjectCopyWith(_AiInputLogEntryObject value,
          $Res Function(_AiInputLogEntryObject) _then) =
      __$AiInputLogEntryObjectCopyWithImpl;
  @override
  @useResult
  $Res call(
      {DateTime creationTimestamp,
      String loggedDuration,
      String text,
      String? audioTranscript,
      String? transcriptLanguage,
      String? entryType});
}

/// @nodoc
class __$AiInputLogEntryObjectCopyWithImpl<$Res>
    implements _$AiInputLogEntryObjectCopyWith<$Res> {
  __$AiInputLogEntryObjectCopyWithImpl(this._self, this._then);

  final _AiInputLogEntryObject _self;
  final $Res Function(_AiInputLogEntryObject) _then;

  /// Create a copy of AiInputLogEntryObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? creationTimestamp = null,
    Object? loggedDuration = null,
    Object? text = null,
    Object? audioTranscript = freezed,
    Object? transcriptLanguage = freezed,
    Object? entryType = freezed,
  }) {
    return _then(_AiInputLogEntryObject(
      creationTimestamp: null == creationTimestamp
          ? _self.creationTimestamp
          : creationTimestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      loggedDuration: null == loggedDuration
          ? _self.loggedDuration
          : loggedDuration // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _self.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      audioTranscript: freezed == audioTranscript
          ? _self.audioTranscript
          : audioTranscript // ignore: cast_nullable_to_non_nullable
              as String?,
      transcriptLanguage: freezed == transcriptLanguage
          ? _self.transcriptLanguage
          : transcriptLanguage // ignore: cast_nullable_to_non_nullable
              as String?,
      entryType: freezed == entryType
          ? _self.entryType
          : entryType // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$AiInputActionItemsList {
  List<AiActionItem> get items;

  /// Create a copy of AiInputActionItemsList
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AiInputActionItemsListCopyWith<AiInputActionItemsList> get copyWith =>
      _$AiInputActionItemsListCopyWithImpl<AiInputActionItemsList>(
          this as AiInputActionItemsList, _$identity);

  /// Serializes this AiInputActionItemsList to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AiInputActionItemsList &&
            const DeepCollectionEquality().equals(other.items, items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(items));

  @override
  String toString() {
    return 'AiInputActionItemsList(items: $items)';
  }
}

/// @nodoc
abstract mixin class $AiInputActionItemsListCopyWith<$Res> {
  factory $AiInputActionItemsListCopyWith(AiInputActionItemsList value,
          $Res Function(AiInputActionItemsList) _then) =
      _$AiInputActionItemsListCopyWithImpl;
  @useResult
  $Res call({List<AiActionItem> items});
}

/// @nodoc
class _$AiInputActionItemsListCopyWithImpl<$Res>
    implements $AiInputActionItemsListCopyWith<$Res> {
  _$AiInputActionItemsListCopyWithImpl(this._self, this._then);

  final AiInputActionItemsList _self;
  final $Res Function(AiInputActionItemsList) _then;

  /// Create a copy of AiInputActionItemsList
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>,
    ));
  }
}

/// Adds pattern-matching-related methods to [AiInputActionItemsList].
extension AiInputActionItemsListPatterns on AiInputActionItemsList {
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
    TResult Function(_AiInputActionItemsList value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiInputActionItemsList() when $default != null:
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
    TResult Function(_AiInputActionItemsList value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputActionItemsList():
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
    TResult? Function(_AiInputActionItemsList value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputActionItemsList() when $default != null:
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
    TResult Function(List<AiActionItem> items)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AiInputActionItemsList() when $default != null:
        return $default(_that.items);
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
    TResult Function(List<AiActionItem> items) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputActionItemsList():
        return $default(_that.items);
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
    TResult? Function(List<AiActionItem> items)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AiInputActionItemsList() when $default != null:
        return $default(_that.items);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _AiInputActionItemsList implements AiInputActionItemsList {
  const _AiInputActionItemsList({required final List<AiActionItem> items})
      : _items = items;
  factory _AiInputActionItemsList.fromJson(Map<String, dynamic> json) =>
      _$AiInputActionItemsListFromJson(json);

  final List<AiActionItem> _items;
  @override
  List<AiActionItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Create a copy of AiInputActionItemsList
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AiInputActionItemsListCopyWith<_AiInputActionItemsList> get copyWith =>
      __$AiInputActionItemsListCopyWithImpl<_AiInputActionItemsList>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AiInputActionItemsListToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AiInputActionItemsList &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_items));

  @override
  String toString() {
    return 'AiInputActionItemsList(items: $items)';
  }
}

/// @nodoc
abstract mixin class _$AiInputActionItemsListCopyWith<$Res>
    implements $AiInputActionItemsListCopyWith<$Res> {
  factory _$AiInputActionItemsListCopyWith(_AiInputActionItemsList value,
          $Res Function(_AiInputActionItemsList) _then) =
      __$AiInputActionItemsListCopyWithImpl;
  @override
  @useResult
  $Res call({List<AiActionItem> items});
}

/// @nodoc
class __$AiInputActionItemsListCopyWithImpl<$Res>
    implements _$AiInputActionItemsListCopyWith<$Res> {
  __$AiInputActionItemsListCopyWithImpl(this._self, this._then);

  final _AiInputActionItemsList _self;
  final $Res Function(_AiInputActionItemsList) _then;

  /// Create a copy of AiInputActionItemsList
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
  }) {
    return _then(_AiInputActionItemsList(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<AiActionItem>,
    ));
  }
}

// dart format on
