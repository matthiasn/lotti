// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
EntryLink _$EntryLinkFromJson(Map<String, dynamic> json) {
  return BasicLink.fromJson(json);
}

/// @nodoc
mixin _$EntryLink {
  String get id;
  String get fromId;
  String get toId;
  DateTime get createdAt;
  DateTime get updatedAt;
  VectorClock? get vectorClock;
  bool? get hidden;
  DateTime? get deletedAt;

  /// Create a copy of EntryLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EntryLinkCopyWith<EntryLink> get copyWith =>
      _$EntryLinkCopyWithImpl<EntryLink>(this as EntryLink, _$identity);

  /// Serializes this EntryLink to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EntryLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.hidden, hidden) || other.hidden == hidden) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, hidden, deletedAt);

  @override
  String toString() {
    return 'EntryLink(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, hidden: $hidden, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $EntryLinkCopyWith<$Res> {
  factory $EntryLinkCopyWith(EntryLink value, $Res Function(EntryLink) _then) =
      _$EntryLinkCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      bool? hidden,
      DateTime? deletedAt});
}

/// @nodoc
class _$EntryLinkCopyWithImpl<$Res> implements $EntryLinkCopyWith<$Res> {
  _$EntryLinkCopyWithImpl(this._self, this._then);

  final EntryLink _self;
  final $Res Function(EntryLink) _then;

  /// Create a copy of EntryLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fromId = null,
    Object? toId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? hidden = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fromId: null == fromId
          ? _self.fromId
          : fromId // ignore: cast_nullable_to_non_nullable
              as String,
      toId: null == toId
          ? _self.toId
          : toId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      hidden: freezed == hidden
          ? _self.hidden
          : hidden // ignore: cast_nullable_to_non_nullable
              as bool?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [EntryLink].
extension EntryLinkPatterns on EntryLink {
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
    TResult Function(BasicLink value)? basic,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BasicLink() when basic != null:
        return basic(_that);
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
    required TResult Function(BasicLink value) basic,
  }) {
    final _that = this;
    switch (_that) {
      case BasicLink():
        return basic(_that);
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
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicLink value)? basic,
  }) {
    final _that = this;
    switch (_that) {
      case BasicLink() when basic != null:
        return basic(_that);
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
    TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            bool? hidden,
            DateTime? deletedAt)?
        basic,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BasicLink() when basic != null:
        return basic(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.hidden, _that.deletedAt);
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
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            bool? hidden,
            DateTime? deletedAt)
        basic,
  }) {
    final _that = this;
    switch (_that) {
      case BasicLink():
        return basic(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.hidden, _that.deletedAt);
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
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            bool? hidden,
            DateTime? deletedAt)?
        basic,
  }) {
    final _that = this;
    switch (_that) {
      case BasicLink() when basic != null:
        return basic(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.hidden, _that.deletedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class BasicLink implements EntryLink {
  const BasicLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.hidden,
      this.deletedAt});
  factory BasicLink.fromJson(Map<String, dynamic> json) =>
      _$BasicLinkFromJson(json);

  @override
  final String id;
  @override
  final String fromId;
  @override
  final String toId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final VectorClock? vectorClock;
  @override
  final bool? hidden;
  @override
  final DateTime? deletedAt;

  /// Create a copy of EntryLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BasicLinkCopyWith<BasicLink> get copyWith =>
      _$BasicLinkCopyWithImpl<BasicLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BasicLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BasicLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.hidden, hidden) || other.hidden == hidden) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, hidden, deletedAt);

  @override
  String toString() {
    return 'EntryLink.basic(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, hidden: $hidden, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $BasicLinkCopyWith<$Res>
    implements $EntryLinkCopyWith<$Res> {
  factory $BasicLinkCopyWith(BasicLink value, $Res Function(BasicLink) _then) =
      _$BasicLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      bool? hidden,
      DateTime? deletedAt});
}

/// @nodoc
class _$BasicLinkCopyWithImpl<$Res> implements $BasicLinkCopyWith<$Res> {
  _$BasicLinkCopyWithImpl(this._self, this._then);

  final BasicLink _self;
  final $Res Function(BasicLink) _then;

  /// Create a copy of EntryLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? fromId = null,
    Object? toId = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? hidden = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(BasicLink(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fromId: null == fromId
          ? _self.fromId
          : fromId // ignore: cast_nullable_to_non_nullable
              as String,
      toId: null == toId
          ? _self.toId
          : toId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      hidden: freezed == hidden
          ? _self.hidden
          : hidden // ignore: cast_nullable_to_non_nullable
              as bool?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
