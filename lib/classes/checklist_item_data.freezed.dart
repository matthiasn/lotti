// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_item_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChecklistItemData {
  String get title;
  bool get isChecked;
  List<String> get linkedChecklists;
  String? get id;

  /// Create a copy of ChecklistItemData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ChecklistItemDataCopyWith<ChecklistItemData> get copyWith =>
      _$ChecklistItemDataCopyWithImpl<ChecklistItemData>(
          this as ChecklistItemData, _$identity);

  /// Serializes this ChecklistItemData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ChecklistItemData &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isChecked, isChecked) ||
                other.isChecked == isChecked) &&
            const DeepCollectionEquality()
                .equals(other.linkedChecklists, linkedChecklists) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, isChecked,
      const DeepCollectionEquality().hash(linkedChecklists), id);

  @override
  String toString() {
    return 'ChecklistItemData(title: $title, isChecked: $isChecked, linkedChecklists: $linkedChecklists, id: $id)';
  }
}

/// @nodoc
abstract mixin class $ChecklistItemDataCopyWith<$Res> {
  factory $ChecklistItemDataCopyWith(
          ChecklistItemData value, $Res Function(ChecklistItemData) _then) =
      _$ChecklistItemDataCopyWithImpl;
  @useResult
  $Res call(
      {String title,
      bool isChecked,
      List<String> linkedChecklists,
      String? id});
}

/// @nodoc
class _$ChecklistItemDataCopyWithImpl<$Res>
    implements $ChecklistItemDataCopyWith<$Res> {
  _$ChecklistItemDataCopyWithImpl(this._self, this._then);

  final ChecklistItemData _self;
  final $Res Function(ChecklistItemData) _then;

  /// Create a copy of ChecklistItemData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? isChecked = null,
    Object? linkedChecklists = null,
    Object? id = freezed,
  }) {
    return _then(_self.copyWith(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      isChecked: null == isChecked
          ? _self.isChecked
          : isChecked // ignore: cast_nullable_to_non_nullable
              as bool,
      linkedChecklists: null == linkedChecklists
          ? _self.linkedChecklists
          : linkedChecklists // ignore: cast_nullable_to_non_nullable
              as List<String>,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ChecklistItemData].
extension ChecklistItemDataPatterns on ChecklistItemData {
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
    TResult Function(_ChecklistItemData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistItemData() when $default != null:
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
    TResult Function(_ChecklistItemData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistItemData():
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
    TResult? Function(_ChecklistItemData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistItemData() when $default != null:
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
    TResult Function(String title, bool isChecked,
            List<String> linkedChecklists, String? id)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ChecklistItemData() when $default != null:
        return $default(
            _that.title, _that.isChecked, _that.linkedChecklists, _that.id);
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
    TResult Function(String title, bool isChecked,
            List<String> linkedChecklists, String? id)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistItemData():
        return $default(
            _that.title, _that.isChecked, _that.linkedChecklists, _that.id);
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
    TResult? Function(String title, bool isChecked,
            List<String> linkedChecklists, String? id)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ChecklistItemData() when $default != null:
        return $default(
            _that.title, _that.isChecked, _that.linkedChecklists, _that.id);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ChecklistItemData implements ChecklistItemData {
  const _ChecklistItemData(
      {required this.title,
      required this.isChecked,
      required final List<String> linkedChecklists,
      this.id})
      : _linkedChecklists = linkedChecklists;
  factory _ChecklistItemData.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDataFromJson(json);

  @override
  final String title;
  @override
  final bool isChecked;
  final List<String> _linkedChecklists;
  @override
  List<String> get linkedChecklists {
    if (_linkedChecklists is EqualUnmodifiableListView)
      return _linkedChecklists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_linkedChecklists);
  }

  @override
  final String? id;

  /// Create a copy of ChecklistItemData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ChecklistItemDataCopyWith<_ChecklistItemData> get copyWith =>
      __$ChecklistItemDataCopyWithImpl<_ChecklistItemData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ChecklistItemDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ChecklistItemData &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.isChecked, isChecked) ||
                other.isChecked == isChecked) &&
            const DeepCollectionEquality()
                .equals(other._linkedChecklists, _linkedChecklists) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, title, isChecked,
      const DeepCollectionEquality().hash(_linkedChecklists), id);

  @override
  String toString() {
    return 'ChecklistItemData(title: $title, isChecked: $isChecked, linkedChecklists: $linkedChecklists, id: $id)';
  }
}

/// @nodoc
abstract mixin class _$ChecklistItemDataCopyWith<$Res>
    implements $ChecklistItemDataCopyWith<$Res> {
  factory _$ChecklistItemDataCopyWith(
          _ChecklistItemData value, $Res Function(_ChecklistItemData) _then) =
      __$ChecklistItemDataCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String title,
      bool isChecked,
      List<String> linkedChecklists,
      String? id});
}

/// @nodoc
class __$ChecklistItemDataCopyWithImpl<$Res>
    implements _$ChecklistItemDataCopyWith<$Res> {
  __$ChecklistItemDataCopyWithImpl(this._self, this._then);

  final _ChecklistItemData _self;
  final $Res Function(_ChecklistItemData) _then;

  /// Create a copy of ChecklistItemData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? title = null,
    Object? isChecked = null,
    Object? linkedChecklists = null,
    Object? id = freezed,
  }) {
    return _then(_ChecklistItemData(
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      isChecked: null == isChecked
          ? _self.isChecked
          : isChecked // ignore: cast_nullable_to_non_nullable
              as bool,
      linkedChecklists: null == linkedChecklists
          ? _self._linkedChecklists
          : linkedChecklists // ignore: cast_nullable_to_non_nullable
              as List<String>,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
