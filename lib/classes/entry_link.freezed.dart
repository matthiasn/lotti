// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

EntryLink _$EntryLinkFromJson(Map<String, dynamic> json) {
  return BasicLink.fromJson(json);
}

/// @nodoc
mixin _$EntryLink {
  String get id => throw _privateConstructorUsedError;
  String get fromId => throw _privateConstructorUsedError;
  String get toId => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  VectorClock? get vectorClock => throw _privateConstructorUsedError;
  bool? get hidden => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
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
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BasicLink value) basic,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicLink value)? basic,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BasicLink value)? basic,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this EntryLink to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EntryLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EntryLinkCopyWith<EntryLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntryLinkCopyWith<$Res> {
  factory $EntryLinkCopyWith(EntryLink value, $Res Function(EntryLink) then) =
      _$EntryLinkCopyWithImpl<$Res, EntryLink>;
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
class _$EntryLinkCopyWithImpl<$Res, $Val extends EntryLink>
    implements $EntryLinkCopyWith<$Res> {
  _$EntryLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fromId: null == fromId
          ? _value.fromId
          : fromId // ignore: cast_nullable_to_non_nullable
              as String,
      toId: null == toId
          ? _value.toId
          : toId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      hidden: freezed == hidden
          ? _value.hidden
          : hidden // ignore: cast_nullable_to_non_nullable
              as bool?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BasicLinkImplCopyWith<$Res>
    implements $EntryLinkCopyWith<$Res> {
  factory _$$BasicLinkImplCopyWith(
          _$BasicLinkImpl value, $Res Function(_$BasicLinkImpl) then) =
      __$$BasicLinkImplCopyWithImpl<$Res>;
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
class __$$BasicLinkImplCopyWithImpl<$Res>
    extends _$EntryLinkCopyWithImpl<$Res, _$BasicLinkImpl>
    implements _$$BasicLinkImplCopyWith<$Res> {
  __$$BasicLinkImplCopyWithImpl(
      _$BasicLinkImpl _value, $Res Function(_$BasicLinkImpl) _then)
      : super(_value, _then);

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
    return _then(_$BasicLinkImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      fromId: null == fromId
          ? _value.fromId
          : fromId // ignore: cast_nullable_to_non_nullable
              as String,
      toId: null == toId
          ? _value.toId
          : toId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      hidden: freezed == hidden
          ? _value.hidden
          : hidden // ignore: cast_nullable_to_non_nullable
              as bool?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BasicLinkImpl implements BasicLink {
  const _$BasicLinkImpl(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.hidden,
      this.deletedAt});

  factory _$BasicLinkImpl.fromJson(Map<String, dynamic> json) =>
      _$$BasicLinkImplFromJson(json);

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

  @override
  String toString() {
    return 'EntryLink.basic(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, hidden: $hidden, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BasicLinkImpl &&
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

  /// Create a copy of EntryLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BasicLinkImplCopyWith<_$BasicLinkImpl> get copyWith =>
      __$$BasicLinkImplCopyWithImpl<_$BasicLinkImpl>(this, _$identity);

  @override
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
    return basic(
        id, fromId, toId, createdAt, updatedAt, vectorClock, hidden, deletedAt);
  }

  @override
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
    return basic?.call(
        id, fromId, toId, createdAt, updatedAt, vectorClock, hidden, deletedAt);
  }

  @override
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
    if (basic != null) {
      return basic(id, fromId, toId, createdAt, updatedAt, vectorClock, hidden,
          deletedAt);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BasicLink value) basic,
  }) {
    return basic(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BasicLink value)? basic,
  }) {
    return basic?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BasicLink value)? basic,
    required TResult orElse(),
  }) {
    if (basic != null) {
      return basic(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$BasicLinkImplToJson(
      this,
    );
  }
}

abstract class BasicLink implements EntryLink {
  const factory BasicLink(
      {required final String id,
      required final String fromId,
      required final String toId,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final VectorClock? vectorClock,
      final bool? hidden,
      final DateTime? deletedAt}) = _$BasicLinkImpl;

  factory BasicLink.fromJson(Map<String, dynamic> json) =
      _$BasicLinkImpl.fromJson;

  @override
  String get id;
  @override
  String get fromId;
  @override
  String get toId;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  VectorClock? get vectorClock;
  @override
  bool? get hidden;
  @override
  DateTime? get deletedAt;

  /// Create a copy of EntryLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BasicLinkImplCopyWith<_$BasicLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
