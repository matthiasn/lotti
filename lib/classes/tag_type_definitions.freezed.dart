// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tag_type_definitions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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
  String get id;
  String get tag;
  bool get private;
  DateTime get createdAt;
  DateTime get updatedAt;
  VectorClock? get vectorClock;
  DateTime? get deletedAt;
  bool? get inactive;

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TagEntityCopyWith<TagEntity> get copyWith =>
      _$TagEntityCopyWithImpl<TagEntity>(this as TagEntity, _$identity);

  /// Serializes this TagEntity to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TagEntity &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, tag, private, createdAt,
      updatedAt, vectorClock, deletedAt, inactive);

  @override
  String toString() {
    return 'TagEntity(id: $id, tag: $tag, private: $private, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt, inactive: $inactive)';
  }
}

/// @nodoc
abstract mixin class $TagEntityCopyWith<$Res> {
  factory $TagEntityCopyWith(TagEntity value, $Res Function(TagEntity) _then) =
      _$TagEntityCopyWithImpl;
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
class _$TagEntityCopyWithImpl<$Res> implements $TagEntityCopyWith<$Res> {
  _$TagEntityCopyWithImpl(this._self, this._then);

  final TagEntity _self;
  final $Res Function(TagEntity) _then;

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _self.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _self.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [TagEntity].
extension TagEntityPatterns on TagEntity {
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
    TResult Function(GenericTag value)? genericTag,
    TResult Function(PersonTag value)? personTag,
    TResult Function(StoryTag value)? storyTag,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case GenericTag() when genericTag != null:
        return genericTag(_that);
      case PersonTag() when personTag != null:
        return personTag(_that);
      case StoryTag() when storyTag != null:
        return storyTag(_that);
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
    required TResult Function(GenericTag value) genericTag,
    required TResult Function(PersonTag value) personTag,
    required TResult Function(StoryTag value) storyTag,
  }) {
    final _that = this;
    switch (_that) {
      case GenericTag():
        return genericTag(_that);
      case PersonTag():
        return personTag(_that);
      case StoryTag():
        return storyTag(_that);
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
    TResult? Function(GenericTag value)? genericTag,
    TResult? Function(PersonTag value)? personTag,
    TResult? Function(StoryTag value)? storyTag,
  }) {
    final _that = this;
    switch (_that) {
      case GenericTag() when genericTag != null:
        return genericTag(_that);
      case PersonTag() when personTag != null:
        return personTag(_that);
      case StoryTag() when storyTag != null:
        return storyTag(_that);
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
    final _that = this;
    switch (_that) {
      case GenericTag() when genericTag != null:
        return genericTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt,
            _that.inactive);
      case PersonTag() when personTag != null:
        return personTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.firstName,
            _that.lastName,
            _that.deletedAt,
            _that.inactive);
      case StoryTag() when storyTag != null:
        return storyTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.description,
            _that.longTitle,
            _that.deletedAt,
            _that.inactive);
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
    final _that = this;
    switch (_that) {
      case GenericTag():
        return genericTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt,
            _that.inactive);
      case PersonTag():
        return personTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.firstName,
            _that.lastName,
            _that.deletedAt,
            _that.inactive);
      case StoryTag():
        return storyTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.description,
            _that.longTitle,
            _that.deletedAt,
            _that.inactive);
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
    final _that = this;
    switch (_that) {
      case GenericTag() when genericTag != null:
        return genericTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt,
            _that.inactive);
      case PersonTag() when personTag != null:
        return personTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.firstName,
            _that.lastName,
            _that.deletedAt,
            _that.inactive);
      case StoryTag() when storyTag != null:
        return storyTag(
            _that.id,
            _that.tag,
            _that.private,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.description,
            _that.longTitle,
            _that.deletedAt,
            _that.inactive);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class GenericTag implements TagEntity {
  const GenericTag(
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
  factory GenericTag.fromJson(Map<String, dynamic> json) =>
      _$GenericTagFromJson(json);

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

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GenericTagCopyWith<GenericTag> get copyWith =>
      _$GenericTagCopyWithImpl<GenericTag>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GenericTagToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GenericTag &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, tag, private, createdAt,
      updatedAt, vectorClock, deletedAt, inactive);

  @override
  String toString() {
    return 'TagEntity.genericTag(id: $id, tag: $tag, private: $private, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt, inactive: $inactive)';
  }
}

/// @nodoc
abstract mixin class $GenericTagCopyWith<$Res>
    implements $TagEntityCopyWith<$Res> {
  factory $GenericTagCopyWith(
          GenericTag value, $Res Function(GenericTag) _then) =
      _$GenericTagCopyWithImpl;
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
class _$GenericTagCopyWithImpl<$Res> implements $GenericTagCopyWith<$Res> {
  _$GenericTagCopyWithImpl(this._self, this._then);

  final GenericTag _self;
  final $Res Function(GenericTag) _then;

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(GenericTag(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _self.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _self.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class PersonTag implements TagEntity {
  const PersonTag(
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
  factory PersonTag.fromJson(Map<String, dynamic> json) =>
      _$PersonTagFromJson(json);

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
  final String? firstName;
  final String? lastName;
  @override
  final DateTime? deletedAt;
  @override
  final bool? inactive;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PersonTagCopyWith<PersonTag> get copyWith =>
      _$PersonTagCopyWithImpl<PersonTag>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PersonTagToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PersonTag &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, tag, private, createdAt,
      updatedAt, vectorClock, firstName, lastName, deletedAt, inactive);

  @override
  String toString() {
    return 'TagEntity.personTag(id: $id, tag: $tag, private: $private, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, firstName: $firstName, lastName: $lastName, deletedAt: $deletedAt, inactive: $inactive)';
  }
}

/// @nodoc
abstract mixin class $PersonTagCopyWith<$Res>
    implements $TagEntityCopyWith<$Res> {
  factory $PersonTagCopyWith(PersonTag value, $Res Function(PersonTag) _then) =
      _$PersonTagCopyWithImpl;
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
class _$PersonTagCopyWithImpl<$Res> implements $PersonTagCopyWith<$Res> {
  _$PersonTagCopyWithImpl(this._self, this._then);

  final PersonTag _self;
  final $Res Function(PersonTag) _then;

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(PersonTag(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _self.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      firstName: freezed == firstName
          ? _self.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String?,
      lastName: freezed == lastName
          ? _self.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _self.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class StoryTag implements TagEntity {
  const StoryTag(
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
  factory StoryTag.fromJson(Map<String, dynamic> json) =>
      _$StoryTagFromJson(json);

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
  final String? description;
  final String? longTitle;
  @override
  final DateTime? deletedAt;
  @override
  final bool? inactive;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StoryTagCopyWith<StoryTag> get copyWith =>
      _$StoryTagCopyWithImpl<StoryTag>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$StoryTagToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StoryTag &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, tag, private, createdAt,
      updatedAt, vectorClock, description, longTitle, deletedAt, inactive);

  @override
  String toString() {
    return 'TagEntity.storyTag(id: $id, tag: $tag, private: $private, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, description: $description, longTitle: $longTitle, deletedAt: $deletedAt, inactive: $inactive)';
  }
}

/// @nodoc
abstract mixin class $StoryTagCopyWith<$Res>
    implements $TagEntityCopyWith<$Res> {
  factory $StoryTagCopyWith(StoryTag value, $Res Function(StoryTag) _then) =
      _$StoryTagCopyWithImpl;
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
class _$StoryTagCopyWithImpl<$Res> implements $StoryTagCopyWith<$Res> {
  _$StoryTagCopyWithImpl(this._self, this._then);

  final StoryTag _self;
  final $Res Function(StoryTag) _then;

  /// Create a copy of TagEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(StoryTag(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tag: null == tag
          ? _self.tag
          : tag // ignore: cast_nullable_to_non_nullable
              as String,
      private: null == private
          ? _self.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
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
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      longTitle: freezed == longTitle
          ? _self.longTitle
          : longTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      inactive: freezed == inactive
          ? _self.inactive
          : inactive // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

// dart format on
