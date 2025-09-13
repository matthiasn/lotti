// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChecklistData {
  String get title;
  List<String> get linkedChecklistItems;
  List<String> get linkedTasks;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChecklistDataCopyWith<ChecklistData> get copyWith =>
      _$ChecklistDataCopyWithImpl<ChecklistData>(
          this as ChecklistData, _$identity);

  /// Serializes this ChecklistData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChecklistData &&
            (identical(other.title, title) || other.title == title) &&
            const DeepCollectionEquality()
                .equals(other.linkedChecklistItems, linkedChecklistItems) &&
            const DeepCollectionEquality()
                .equals(other.linkedTasks, linkedTasks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      title,
      const DeepCollectionEquality().hash(linkedChecklistItems),
      const DeepCollectionEquality().hash(linkedTasks));

  @override
  String toString() {
    return 'ChecklistData(title: $title, linkedChecklistItems: $linkedChecklistItems, linkedTasks: $linkedTasks)';
  }
}

/// @nodoc
abstract mixin class $ChecklistDataCopyWith<$Res> {
  factory $ChecklistDataCopyWith(
          ChecklistData value, $Res Function(ChecklistData) _then) =
      _$ChecklistDataCopyWithImpl;
  @useResult
  $Res call(
      {String title,
      List<String> linkedChecklistItems,
      List<String> linkedTasks});
}

/// @nodoc
class _$ChecklistDataCopyWithImpl<$Res>
    implements $ChecklistDataCopyWith<$Res> {
  _$ChecklistDataCopyWithImpl(this._self, this._then);

  final ChecklistData _self;
  final $Res Function(ChecklistData) _then;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? linkedChecklistItems = null,
    Object? linkedTasks = null,
  }) {
    return _then(_self.copyWith(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      linkedChecklistItems: null == linkedChecklistItems
          ? _self.linkedChecklistItems
          : linkedChecklistItems // ignore: cast_nullable_to_non_nullable
              as List<String>,
      linkedTasks: null == linkedTasks
          ? _self.linkedTasks
          : linkedTasks // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChecklistData].
extension ChecklistDataPatterns on ChecklistData {
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
    TResult Function(_ChecklistData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistData() when $default != null:
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
    TResult Function(_ChecklistData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistData():
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
    TResult? Function(_ChecklistData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistData() when $default != null:
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
    TResult Function(String title, List<String> linkedChecklistItems,
            List<String> linkedTasks)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistData() when $default != null:
        return $default(
            _that.title, _that.linkedChecklistItems, _that.linkedTasks);
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
    TResult Function(String title, List<String> linkedChecklistItems,
            List<String> linkedTasks)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistData():
        return $default(
            _that.title, _that.linkedChecklistItems, _that.linkedTasks);
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
    TResult? Function(String title, List<String> linkedChecklistItems,
            List<String> linkedTasks)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistData() when $default != null:
        return $default(
            _that.title, _that.linkedChecklistItems, _that.linkedTasks);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ChecklistData implements ChecklistData {
  const _ChecklistData(
      {required this.title,
      required final List<String> linkedChecklistItems,
      required final List<String> linkedTasks})
      : _linkedChecklistItems = linkedChecklistItems,
        _linkedTasks = linkedTasks;
  factory _ChecklistData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistDataFromJson(json);

  @override
  final String title;
  final List<String> _linkedChecklistItems;
  @override
  List<String> get linkedChecklistItems {
    if (_linkedChecklistItems is EqualUnmodifiableListView)
      return _linkedChecklistItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_linkedChecklistItems);
  }

  final List<String> _linkedTasks;
  @override
  List<String> get linkedTasks {
    if (_linkedTasks is EqualUnmodifiableListView) return _linkedTasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_linkedTasks);
  }

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChecklistDataCopyWith<_ChecklistData> get copyWith =>
      __$ChecklistDataCopyWithImpl<_ChecklistData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChecklistDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChecklistData &&
            (identical(other.title, title) || other.title == title) &&
            const DeepCollectionEquality()
                .equals(other._linkedChecklistItems, _linkedChecklistItems) &&
            const DeepCollectionEquality()
                .equals(other._linkedTasks, _linkedTasks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      title,
      const DeepCollectionEquality().hash(_linkedChecklistItems),
      const DeepCollectionEquality().hash(_linkedTasks));

  @override
  String toString() {
    return 'ChecklistData(title: $title, linkedChecklistItems: $linkedChecklistItems, linkedTasks: $linkedTasks)';
  }
}

/// @nodoc
abstract mixin class _$ChecklistDataCopyWith<$Res>
    implements $ChecklistDataCopyWith<$Res> {
  factory _$ChecklistDataCopyWith(
          _ChecklistData value, $Res Function(_ChecklistData) _then) =
      __$ChecklistDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String title,
      List<String> linkedChecklistItems,
      List<String> linkedTasks});
}

/// @nodoc
class __$ChecklistDataCopyWithImpl<$Res>
    implements _$ChecklistDataCopyWith<$Res> {
  __$ChecklistDataCopyWithImpl(this._self, this._then);

  final _ChecklistData _self;
  final $Res Function(_ChecklistData) _then;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? title = null,
    Object? linkedChecklistItems = null,
    Object? linkedTasks = null,
  }) {
    return _then(_ChecklistData(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      linkedChecklistItems: null == linkedChecklistItems
          ? _self._linkedChecklistItems
          : linkedChecklistItems // ignore: cast_nullable_to_non_nullable
              as List<String>,
      linkedTasks: null == linkedTasks
          ? _self._linkedTasks
          : linkedTasks // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
