// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tag_type_definitions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

TagEntity _$TagEntityFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'genericTag':
      return GenericTag.fromJson(json);
    case 'personTag':
      return PersonTag.fromJson(json);
    case 'storyTag':
      return StoryTag.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'TagEntity',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$TagEntity {
  String get id => throw _privateConstructorUsedError;
  String get tag => throw _privateConstructorUsedError;
  bool get private => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  VectorClock? get vectorClock => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;
  bool? get inactive => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)
        genericTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)
        personTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)
        storyTag,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GenericTag value) genericTag,
    required TResult Function(PersonTag value) personTag,
    required TResult Function(StoryTag value) storyTag,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GenericTag value)? genericTag,
    TResult? Function(PersonTag value)? personTag,
    TResult? Function(StoryTag value)? storyTag,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GenericTag value)? genericTag,
    TResult Function(PersonTag value)? personTag,
    TResult Function(StoryTag value)? storyTag,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $TagEntityCopyWith<TagEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TagEntityCopyWith<$Res> {
  factory $TagEntityCopyWith(TagEntity value, $Res Function(TagEntity) then) =
      _$TagEntityCopyWithImpl<$Res, TagEntity>;
  @useResult
  $Res call(
      {String id,
      String tag,
      bool private,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      bool? inactive});
}

/// @nodoc
class _$TagEntityCopyWithImpl<$Res, $Val extends TagEntity>
    implements $TagEntityCopyWith<$Res> {
  _$TagEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tag = null,
    Object? private = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? inactive = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _value.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GenericTagCopyWith<$Res> implements $TagEntityCopyWith<$Res> {
  factory _$$GenericTagCopyWith(
          _$GenericTag value, $Res Function(_$GenericTag) then) =
      __$$GenericTagCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tag,
      bool private,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      bool? inactive});
}

/// @nodoc
class __$$GenericTagCopyWithImpl<$Res>
    extends _$TagEntityCopyWithImpl<$Res, _$GenericTag>
    implements _$$GenericTagCopyWith<$Res> {
  __$$GenericTagCopyWithImpl(
      _$GenericTag _value, $Res Function(_$GenericTag) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tag = null,
    Object? private = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? inactive = freezed,
  }) {
    return _then(_$GenericTag(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _value.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$GenericTag implements GenericTag {
  _$GenericTag(
      {required this.id,
      required this.tag,
      required this.private,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      this.inactive,
      final String? $type})
      : $type = $type ?? 'genericTag';

  factory _$GenericTag.fromJson(Map<String, dynamic> json) =>
      _$$GenericTagFromJson(json);

  @override
  final String id;
  @override
  final String tag;
  @override
  final bool private;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final VectorClock? vectorClock;
  @override
  final DateTime? deletedAt;
  @override
  final bool? inactive;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TagEntity.genericTag(id: $id, tag: $tag, private: $private, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt, inactive: $inactive)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GenericTag &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tag, tag) || other.tag == tag) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.inactive, inactive) ||
                other.inactive == inactive));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, tag, private, createdAt,
      updatedAt, vectorClock, deletedAt, inactive);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$GenericTagCopyWith<_$GenericTag> get copyWith =>
      __$$GenericTagCopyWithImpl<_$GenericTag>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)
        genericTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)
        personTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)
        storyTag,
  }) {
    return genericTag(id, tag, private, createdAt, updatedAt, vectorClock,
        deletedAt, inactive);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
  }) {
    return genericTag?.call(id, tag, private, createdAt, updatedAt, vectorClock,
        deletedAt, inactive);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
    required TResult orElse(),
  }) {
    if (genericTag != null) {
      return genericTag(id, tag, private, createdAt, updatedAt, vectorClock,
          deletedAt, inactive);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GenericTag value) genericTag,
    required TResult Function(PersonTag value) personTag,
    required TResult Function(StoryTag value) storyTag,
  }) {
    return genericTag(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GenericTag value)? genericTag,
    TResult? Function(PersonTag value)? personTag,
    TResult? Function(StoryTag value)? storyTag,
  }) {
    return genericTag?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GenericTag value)? genericTag,
    TResult Function(PersonTag value)? personTag,
    TResult Function(StoryTag value)? storyTag,
    required TResult orElse(),
  }) {
    if (genericTag != null) {
      return genericTag(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$GenericTagToJson(
      this,
    );
  }
}

abstract class GenericTag implements TagEntity {
  factory GenericTag(
      {required final String id,
      required final String tag,
      required final bool private,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final VectorClock? vectorClock,
      final DateTime? deletedAt,
      final bool? inactive}) = _$GenericTag;

  factory GenericTag.fromJson(Map<String, dynamic> json) =
      _$GenericTag.fromJson;

  @override
  String get id;
  @override
  String get tag;
  @override
  bool get private;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  VectorClock? get vectorClock;
  @override
  DateTime? get deletedAt;
  @override
  bool? get inactive;
  @override
  @JsonKey(ignore: true)
  _$$GenericTagCopyWith<_$GenericTag> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PersonTagCopyWith<$Res> implements $TagEntityCopyWith<$Res> {
  factory _$$PersonTagCopyWith(
          _$PersonTag value, $Res Function(_$PersonTag) then) =
      __$$PersonTagCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tag,
      bool private,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      String? firstName,
      String? lastName,
      DateTime? deletedAt,
      bool? inactive});
}

/// @nodoc
class __$$PersonTagCopyWithImpl<$Res>
    extends _$TagEntityCopyWithImpl<$Res, _$PersonTag>
    implements _$$PersonTagCopyWith<$Res> {
  __$$PersonTagCopyWithImpl(
      _$PersonTag _value, $Res Function(_$PersonTag) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tag = null,
    Object? private = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? firstName = freezed,
    Object? lastName = freezed,
    Object? deletedAt = freezed,
    Object? inactive = freezed,
  }) {
    return _then(_$PersonTag(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      firstName: freezed == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: freezed == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _value.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PersonTag implements PersonTag {
  _$PersonTag(
      {required this.id,
      required this.tag,
      required this.private,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.firstName,
      this.lastName,
      this.deletedAt,
      this.inactive,
      final String? $type})
      : $type = $type ?? 'personTag';

  factory _$PersonTag.fromJson(Map<String, dynamic> json) =>
      _$$PersonTagFromJson(json);

  @override
  final String id;
  @override
  final String tag;
  @override
  final bool private;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final VectorClock? vectorClock;
  @override
  final String? firstName;
  @override
  final String? lastName;
  @override
  final DateTime? deletedAt;
  @override
  final bool? inactive;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TagEntity.personTag(id: $id, tag: $tag, private: $private, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, firstName: $firstName, lastName: $lastName, deletedAt: $deletedAt, inactive: $inactive)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PersonTag &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tag, tag) || other.tag == tag) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.inactive, inactive) ||
                other.inactive == inactive));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, tag, private, createdAt,
      updatedAt, vectorClock, firstName, lastName, deletedAt, inactive);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PersonTagCopyWith<_$PersonTag> get copyWith =>
      __$$PersonTagCopyWithImpl<_$PersonTag>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)
        genericTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)
        personTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)
        storyTag,
  }) {
    return personTag(id, tag, private, createdAt, updatedAt, vectorClock,
        firstName, lastName, deletedAt, inactive);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
  }) {
    return personTag?.call(id, tag, private, createdAt, updatedAt, vectorClock,
        firstName, lastName, deletedAt, inactive);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
    required TResult orElse(),
  }) {
    if (personTag != null) {
      return personTag(id, tag, private, createdAt, updatedAt, vectorClock,
          firstName, lastName, deletedAt, inactive);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GenericTag value) genericTag,
    required TResult Function(PersonTag value) personTag,
    required TResult Function(StoryTag value) storyTag,
  }) {
    return personTag(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GenericTag value)? genericTag,
    TResult? Function(PersonTag value)? personTag,
    TResult? Function(StoryTag value)? storyTag,
  }) {
    return personTag?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GenericTag value)? genericTag,
    TResult Function(PersonTag value)? personTag,
    TResult Function(StoryTag value)? storyTag,
    required TResult orElse(),
  }) {
    if (personTag != null) {
      return personTag(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PersonTagToJson(
      this,
    );
  }
}

abstract class PersonTag implements TagEntity {
  factory PersonTag(
      {required final String id,
      required final String tag,
      required final bool private,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final VectorClock? vectorClock,
      final String? firstName,
      final String? lastName,
      final DateTime? deletedAt,
      final bool? inactive}) = _$PersonTag;

  factory PersonTag.fromJson(Map<String, dynamic> json) = _$PersonTag.fromJson;

  @override
  String get id;
  @override
  String get tag;
  @override
  bool get private;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  VectorClock? get vectorClock;
  String? get firstName;
  String? get lastName;
  @override
  DateTime? get deletedAt;
  @override
  bool? get inactive;
  @override
  @JsonKey(ignore: true)
  _$$PersonTagCopyWith<_$PersonTag> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$StoryTagCopyWith<$Res> implements $TagEntityCopyWith<$Res> {
  factory _$$StoryTagCopyWith(
          _$StoryTag value, $Res Function(_$StoryTag) then) =
      __$$StoryTagCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tag,
      bool private,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      String? description,
      String? longTitle,
      DateTime? deletedAt,
      bool? inactive});
}

/// @nodoc
class __$$StoryTagCopyWithImpl<$Res>
    extends _$TagEntityCopyWithImpl<$Res, _$StoryTag>
    implements _$$StoryTagCopyWith<$Res> {
  __$$StoryTagCopyWithImpl(_$StoryTag _value, $Res Function(_$StoryTag) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tag = null,
    Object? private = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? description = freezed,
    Object? longTitle = freezed,
    Object? deletedAt = freezed,
    Object? inactive = freezed,
  }) {
    return _then(_$StoryTag(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _value.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      longTitle: freezed == longTitle
          ? _value.longTitle
          : longTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedAt: freezed == deletedAt
          ? _value.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _value.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StoryTag implements StoryTag {
  _$StoryTag(
      {required this.id,
      required this.tag,
      required this.private,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.description,
      this.longTitle,
      this.deletedAt,
      this.inactive,
      final String? $type})
      : $type = $type ?? 'storyTag';

  factory _$StoryTag.fromJson(Map<String, dynamic> json) =>
      _$$StoryTagFromJson(json);

  @override
  final String id;
  @override
  final String tag;
  @override
  final bool private;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final VectorClock? vectorClock;
  @override
  final String? description;
  @override
  final String? longTitle;
  @override
  final DateTime? deletedAt;
  @override
  final bool? inactive;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'TagEntity.storyTag(id: $id, tag: $tag, private: $private, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, description: $description, longTitle: $longTitle, deletedAt: $deletedAt, inactive: $inactive)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StoryTag &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tag, tag) || other.tag == tag) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.longTitle, longTitle) ||
                other.longTitle == longTitle) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.inactive, inactive) ||
                other.inactive == inactive));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, tag, private, createdAt,
      updatedAt, vectorClock, description, longTitle, deletedAt, inactive);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$StoryTagCopyWith<_$StoryTag> get copyWith =>
      __$$StoryTagCopyWithImpl<_$StoryTag>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)
        genericTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)
        personTag,
    required TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)
        storyTag,
  }) {
    return storyTag(id, tag, private, createdAt, updatedAt, vectorClock,
        description, longTitle, deletedAt, inactive);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult? Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
  }) {
    return storyTag?.call(id, tag, private, createdAt, updatedAt, vectorClock,
        description, longTitle, deletedAt, inactive);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            bool? inactive)?
        genericTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? firstName,
            String? lastName,
            DateTime? deletedAt,
            bool? inactive)?
        personTag,
    TResult Function(
            String id,
            String tag,
            bool private,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            String? description,
            String? longTitle,
            DateTime? deletedAt,
            bool? inactive)?
        storyTag,
    required TResult orElse(),
  }) {
    if (storyTag != null) {
      return storyTag(id, tag, private, createdAt, updatedAt, vectorClock,
          description, longTitle, deletedAt, inactive);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GenericTag value) genericTag,
    required TResult Function(PersonTag value) personTag,
    required TResult Function(StoryTag value) storyTag,
  }) {
    return storyTag(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GenericTag value)? genericTag,
    TResult? Function(PersonTag value)? personTag,
    TResult? Function(StoryTag value)? storyTag,
  }) {
    return storyTag?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GenericTag value)? genericTag,
    TResult Function(PersonTag value)? personTag,
    TResult Function(StoryTag value)? storyTag,
    required TResult orElse(),
  }) {
    if (storyTag != null) {
      return storyTag(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$StoryTagToJson(
      this,
    );
  }
}

abstract class StoryTag implements TagEntity {
  factory StoryTag(
      {required final String id,
      required final String tag,
      required final bool private,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      required final VectorClock? vectorClock,
      final String? description,
      final String? longTitle,
      final DateTime? deletedAt,
      final bool? inactive}) = _$StoryTag;

  factory StoryTag.fromJson(Map<String, dynamic> json) = _$StoryTag.fromJson;

  @override
  String get id;
  @override
  String get tag;
  @override
  bool get private;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  VectorClock? get vectorClock;
  String? get description;
  String? get longTitle;
  @override
  DateTime? get deletedAt;
  @override
  bool? get inactive;
  @override
  @JsonKey(ignore: true)
  _$$StoryTagCopyWith<_$StoryTag> get copyWith =>
      throw _privateConstructorUsedError;
}
