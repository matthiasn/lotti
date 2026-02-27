// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'change_set.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChangeItem {
  /// The tool name for this mutation (e.g., `add_checklist_item`).
  String get toolName;

  /// The arguments to pass to the tool handler.
  Map<String, dynamic> get args;

  /// A user-facing plain-text description of what this change does.
  String get humanSummary;

  /// Current status of this item within the change set.
  ChangeItemStatus get status;

  /// Create a copy of ChangeItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChangeItemCopyWith<ChangeItem> get copyWith =>
      _$ChangeItemCopyWithImpl<ChangeItem>(this as ChangeItem, _$identity);

  /// Serializes this ChangeItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChangeItem &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other.args, args) &&
            (identical(other.humanSummary, humanSummary) ||
                other.humanSummary == humanSummary) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, toolName,
      const DeepCollectionEquality().hash(args), humanSummary, status);

  @override
  String toString() {
    return 'ChangeItem(toolName: $toolName, args: $args, humanSummary: $humanSummary, status: $status)';
  }
}

/// @nodoc
abstract mixin class $ChangeItemCopyWith<$Res> {
  factory $ChangeItemCopyWith(
          ChangeItem value, $Res Function(ChangeItem) _then) =
      _$ChangeItemCopyWithImpl;
  @useResult
  $Res call(
      {String toolName,
      Map<String, dynamic> args,
      String humanSummary,
      ChangeItemStatus status});
}

/// @nodoc
class _$ChangeItemCopyWithImpl<$Res> implements $ChangeItemCopyWith<$Res> {
  _$ChangeItemCopyWithImpl(this._self, this._then);

  final ChangeItem _self;
  final $Res Function(ChangeItem) _then;

  /// Create a copy of ChangeItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toolName = null,
    Object? args = null,
    Object? humanSummary = null,
    Object? status = null,
  }) {
    return _then(_self.copyWith(
      toolName: null == toolName
          ? _self.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String,
      args: null == args
          ? _self.args
          : args // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      humanSummary: null == humanSummary
          ? _self.humanSummary
          : humanSummary // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as ChangeItemStatus,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChangeItem].
extension ChangeItemPatterns on ChangeItem {
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
    TResult Function(_ChangeItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChangeItem() when $default != null:
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
    TResult Function(_ChangeItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeItem():
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
    TResult? Function(_ChangeItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeItem() when $default != null:
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
    TResult Function(String toolName, Map<String, dynamic> args,
            String humanSummary, ChangeItemStatus status)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChangeItem() when $default != null:
        return $default(
            _that.toolName, _that.args, _that.humanSummary, _that.status);
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
    TResult Function(String toolName, Map<String, dynamic> args,
            String humanSummary, ChangeItemStatus status)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeItem():
        return $default(
            _that.toolName, _that.args, _that.humanSummary, _that.status);
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
    TResult? Function(String toolName, Map<String, dynamic> args,
            String humanSummary, ChangeItemStatus status)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChangeItem() when $default != null:
        return $default(
            _that.toolName, _that.args, _that.humanSummary, _that.status);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ChangeItem implements ChangeItem {
  const _ChangeItem(
      {required this.toolName,
      required final Map<String, dynamic> args,
      required this.humanSummary,
      this.status = ChangeItemStatus.pending})
      : _args = args;
  factory _ChangeItem.fromJson(Map<String, dynamic> json) =>
      _$ChangeItemFromJson(json);

  /// The tool name for this mutation (e.g., `add_checklist_item`).
  @override
  final String toolName;

  /// The arguments to pass to the tool handler.
  final Map<String, dynamic> _args;

  /// The arguments to pass to the tool handler.
  @override
  Map<String, dynamic> get args {
    if (_args is EqualUnmodifiableMapView) return _args;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_args);
  }

  /// A user-facing plain-text description of what this change does.
  @override
  final String humanSummary;

  /// Current status of this item within the change set.
  @override
  @JsonKey()
  final ChangeItemStatus status;

  /// Create a copy of ChangeItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChangeItemCopyWith<_ChangeItem> get copyWith =>
      __$ChangeItemCopyWithImpl<_ChangeItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChangeItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChangeItem &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other._args, _args) &&
            (identical(other.humanSummary, humanSummary) ||
                other.humanSummary == humanSummary) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, toolName,
      const DeepCollectionEquality().hash(_args), humanSummary, status);

  @override
  String toString() {
    return 'ChangeItem(toolName: $toolName, args: $args, humanSummary: $humanSummary, status: $status)';
  }
}

/// @nodoc
abstract mixin class _$ChangeItemCopyWith<$Res>
    implements $ChangeItemCopyWith<$Res> {
  factory _$ChangeItemCopyWith(
          _ChangeItem value, $Res Function(_ChangeItem) _then) =
      __$ChangeItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String toolName,
      Map<String, dynamic> args,
      String humanSummary,
      ChangeItemStatus status});
}

/// @nodoc
class __$ChangeItemCopyWithImpl<$Res> implements _$ChangeItemCopyWith<$Res> {
  __$ChangeItemCopyWithImpl(this._self, this._then);

  final _ChangeItem _self;
  final $Res Function(_ChangeItem) _then;

  /// Create a copy of ChangeItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? toolName = null,
    Object? args = null,
    Object? humanSummary = null,
    Object? status = null,
  }) {
    return _then(_ChangeItem(
      toolName: null == toolName
          ? _self.toolName
          : toolName // ignore: cast_nullable_to_non_nullable
              as String,
      args: null == args
          ? _self._args
          : args // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      humanSummary: null == humanSummary
          ? _self.humanSummary
          : humanSummary // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as ChangeItemStatus,
    ));
  }
}

// dart format on
