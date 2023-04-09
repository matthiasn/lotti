// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

SyncMessage _$SyncMessageFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'journalEntity':
      return SyncJournalEntity.fromJson(json);
    case 'entityDefinition':
      return SyncEntityDefinition.fromJson(json);
    case 'tagEntity':
      return SyncTagEntity.fromJson(json);
    case 'entryLink':
      return SyncEntryLink.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'SyncMessage',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$SyncMessage {
  SyncEntryStatus get status => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            JournalEntity journalEntity, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SyncJournalEntity value) journalEntity,
    required TResult Function(SyncEntityDefinition value) entityDefinition,
    required TResult Function(SyncTagEntity value) tagEntity,
    required TResult Function(SyncEntryLink value) entryLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SyncMessageCopyWith<SyncMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncMessageCopyWith<$Res> {
  factory $SyncMessageCopyWith(
          SyncMessage value, $Res Function(SyncMessage) then) =
      _$SyncMessageCopyWithImpl<$Res, SyncMessage>;
  @useResult
  $Res call({SyncEntryStatus status});
}

/// @nodoc
class _$SyncMessageCopyWithImpl<$Res, $Val extends SyncMessage>
    implements $SyncMessageCopyWith<$Res> {
  _$SyncMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
  }) {
    return _then(_value.copyWith(
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SyncJournalEntityCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory _$$SyncJournalEntityCopyWith(
          _$SyncJournalEntity value, $Res Function(_$SyncJournalEntity) then) =
      __$$SyncJournalEntityCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({JournalEntity journalEntity, SyncEntryStatus status});

  $JournalEntityCopyWith<$Res> get journalEntity;
}

/// @nodoc
class __$$SyncJournalEntityCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncJournalEntity>
    implements _$$SyncJournalEntityCopyWith<$Res> {
  __$$SyncJournalEntityCopyWithImpl(
      _$SyncJournalEntity _value, $Res Function(_$SyncJournalEntity) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? journalEntity = null,
    Object? status = null,
  }) {
    return _then(_$SyncJournalEntity(
      journalEntity: null == journalEntity
          ? _value.journalEntity
          : journalEntity // ignore: cast_nullable_to_non_nullable
              as JournalEntity,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $JournalEntityCopyWith<$Res> get journalEntity {
    return $JournalEntityCopyWith<$Res>(_value.journalEntity, (value) {
      return _then(_value.copyWith(journalEntity: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncJournalEntity implements SyncJournalEntity {
  _$SyncJournalEntity(
      {required this.journalEntity, required this.status, final String? $type})
      : $type = $type ?? 'journalEntity';

  factory _$SyncJournalEntity.fromJson(Map<String, dynamic> json) =>
      _$$SyncJournalEntityFromJson(json);

  @override
  final JournalEntity journalEntity;
  @override
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SyncMessage.journalEntity(journalEntity: $journalEntity, status: $status)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncJournalEntity &&
            (identical(other.journalEntity, journalEntity) ||
                other.journalEntity == journalEntity) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, journalEntity, status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncJournalEntityCopyWith<_$SyncJournalEntity> get copyWith =>
      __$$SyncJournalEntityCopyWithImpl<_$SyncJournalEntity>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            JournalEntity journalEntity, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
  }) {
    return journalEntity(this.journalEntity, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
  }) {
    return journalEntity?.call(this.journalEntity, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    required TResult orElse(),
  }) {
    if (journalEntity != null) {
      return journalEntity(this.journalEntity, status);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SyncJournalEntity value) journalEntity,
    required TResult Function(SyncEntityDefinition value) entityDefinition,
    required TResult Function(SyncTagEntity value) tagEntity,
    required TResult Function(SyncEntryLink value) entryLink,
  }) {
    return journalEntity(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
  }) {
    return journalEntity?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    required TResult orElse(),
  }) {
    if (journalEntity != null) {
      return journalEntity(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncJournalEntityToJson(
      this,
    );
  }
}

abstract class SyncJournalEntity implements SyncMessage {
  factory SyncJournalEntity(
      {required final JournalEntity journalEntity,
      required final SyncEntryStatus status}) = _$SyncJournalEntity;

  factory SyncJournalEntity.fromJson(Map<String, dynamic> json) =
      _$SyncJournalEntity.fromJson;

  JournalEntity get journalEntity;
  @override
  SyncEntryStatus get status;
  @override
  @JsonKey(ignore: true)
  _$$SyncJournalEntityCopyWith<_$SyncJournalEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncEntityDefinitionCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory _$$SyncEntityDefinitionCopyWith(_$SyncEntityDefinition value,
          $Res Function(_$SyncEntityDefinition) then) =
      __$$SyncEntityDefinitionCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({EntityDefinition entityDefinition, SyncEntryStatus status});

  $EntityDefinitionCopyWith<$Res> get entityDefinition;
}

/// @nodoc
class __$$SyncEntityDefinitionCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncEntityDefinition>
    implements _$$SyncEntityDefinitionCopyWith<$Res> {
  __$$SyncEntityDefinitionCopyWithImpl(_$SyncEntityDefinition _value,
      $Res Function(_$SyncEntityDefinition) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entityDefinition = null,
    Object? status = null,
  }) {
    return _then(_$SyncEntityDefinition(
      entityDefinition: null == entityDefinition
          ? _value.entityDefinition
          : entityDefinition // ignore: cast_nullable_to_non_nullable
              as EntityDefinition,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $EntityDefinitionCopyWith<$Res> get entityDefinition {
    return $EntityDefinitionCopyWith<$Res>(_value.entityDefinition, (value) {
      return _then(_value.copyWith(entityDefinition: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncEntityDefinition implements SyncEntityDefinition {
  _$SyncEntityDefinition(
      {required this.entityDefinition,
      required this.status,
      final String? $type})
      : $type = $type ?? 'entityDefinition';

  factory _$SyncEntityDefinition.fromJson(Map<String, dynamic> json) =>
      _$$SyncEntityDefinitionFromJson(json);

  @override
  final EntityDefinition entityDefinition;
  @override
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SyncMessage.entityDefinition(entityDefinition: $entityDefinition, status: $status)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncEntityDefinition &&
            (identical(other.entityDefinition, entityDefinition) ||
                other.entityDefinition == entityDefinition) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, entityDefinition, status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncEntityDefinitionCopyWith<_$SyncEntityDefinition> get copyWith =>
      __$$SyncEntityDefinitionCopyWithImpl<_$SyncEntityDefinition>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            JournalEntity journalEntity, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
  }) {
    return entityDefinition(this.entityDefinition, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
  }) {
    return entityDefinition?.call(this.entityDefinition, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    required TResult orElse(),
  }) {
    if (entityDefinition != null) {
      return entityDefinition(this.entityDefinition, status);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SyncJournalEntity value) journalEntity,
    required TResult Function(SyncEntityDefinition value) entityDefinition,
    required TResult Function(SyncTagEntity value) tagEntity,
    required TResult Function(SyncEntryLink value) entryLink,
  }) {
    return entityDefinition(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
  }) {
    return entityDefinition?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    required TResult orElse(),
  }) {
    if (entityDefinition != null) {
      return entityDefinition(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncEntityDefinitionToJson(
      this,
    );
  }
}

abstract class SyncEntityDefinition implements SyncMessage {
  factory SyncEntityDefinition(
      {required final EntityDefinition entityDefinition,
      required final SyncEntryStatus status}) = _$SyncEntityDefinition;

  factory SyncEntityDefinition.fromJson(Map<String, dynamic> json) =
      _$SyncEntityDefinition.fromJson;

  EntityDefinition get entityDefinition;
  @override
  SyncEntryStatus get status;
  @override
  @JsonKey(ignore: true)
  _$$SyncEntityDefinitionCopyWith<_$SyncEntityDefinition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncTagEntityCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory _$$SyncTagEntityCopyWith(
          _$SyncTagEntity value, $Res Function(_$SyncTagEntity) then) =
      __$$SyncTagEntityCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({TagEntity tagEntity, SyncEntryStatus status});

  $TagEntityCopyWith<$Res> get tagEntity;
}

/// @nodoc
class __$$SyncTagEntityCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncTagEntity>
    implements _$$SyncTagEntityCopyWith<$Res> {
  __$$SyncTagEntityCopyWithImpl(
      _$SyncTagEntity _value, $Res Function(_$SyncTagEntity) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagEntity = null,
    Object? status = null,
  }) {
    return _then(_$SyncTagEntity(
      tagEntity: null == tagEntity
          ? _value.tagEntity
          : tagEntity // ignore: cast_nullable_to_non_nullable
              as TagEntity,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $TagEntityCopyWith<$Res> get tagEntity {
    return $TagEntityCopyWith<$Res>(_value.tagEntity, (value) {
      return _then(_value.copyWith(tagEntity: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncTagEntity implements SyncTagEntity {
  _$SyncTagEntity(
      {required this.tagEntity, required this.status, final String? $type})
      : $type = $type ?? 'tagEntity';

  factory _$SyncTagEntity.fromJson(Map<String, dynamic> json) =>
      _$$SyncTagEntityFromJson(json);

  @override
  final TagEntity tagEntity;
  @override
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SyncMessage.tagEntity(tagEntity: $tagEntity, status: $status)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncTagEntity &&
            (identical(other.tagEntity, tagEntity) ||
                other.tagEntity == tagEntity) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, tagEntity, status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncTagEntityCopyWith<_$SyncTagEntity> get copyWith =>
      __$$SyncTagEntityCopyWithImpl<_$SyncTagEntity>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            JournalEntity journalEntity, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
  }) {
    return tagEntity(this.tagEntity, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
  }) {
    return tagEntity?.call(this.tagEntity, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    required TResult orElse(),
  }) {
    if (tagEntity != null) {
      return tagEntity(this.tagEntity, status);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SyncJournalEntity value) journalEntity,
    required TResult Function(SyncEntityDefinition value) entityDefinition,
    required TResult Function(SyncTagEntity value) tagEntity,
    required TResult Function(SyncEntryLink value) entryLink,
  }) {
    return tagEntity(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
  }) {
    return tagEntity?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    required TResult orElse(),
  }) {
    if (tagEntity != null) {
      return tagEntity(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncTagEntityToJson(
      this,
    );
  }
}

abstract class SyncTagEntity implements SyncMessage {
  factory SyncTagEntity(
      {required final TagEntity tagEntity,
      required final SyncEntryStatus status}) = _$SyncTagEntity;

  factory SyncTagEntity.fromJson(Map<String, dynamic> json) =
      _$SyncTagEntity.fromJson;

  TagEntity get tagEntity;
  @override
  SyncEntryStatus get status;
  @override
  @JsonKey(ignore: true)
  _$$SyncTagEntityCopyWith<_$SyncTagEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncEntryLinkCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory _$$SyncEntryLinkCopyWith(
          _$SyncEntryLink value, $Res Function(_$SyncEntryLink) then) =
      __$$SyncEntryLinkCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({EntryLink entryLink, SyncEntryStatus status});

  $EntryLinkCopyWith<$Res> get entryLink;
}

/// @nodoc
class __$$SyncEntryLinkCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncEntryLink>
    implements _$$SyncEntryLinkCopyWith<$Res> {
  __$$SyncEntryLinkCopyWithImpl(
      _$SyncEntryLink _value, $Res Function(_$SyncEntryLink) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryLink = null,
    Object? status = null,
  }) {
    return _then(_$SyncEntryLink(
      entryLink: null == entryLink
          ? _value.entryLink
          : entryLink // ignore: cast_nullable_to_non_nullable
              as EntryLink,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $EntryLinkCopyWith<$Res> get entryLink {
    return $EntryLinkCopyWith<$Res>(_value.entryLink, (value) {
      return _then(_value.copyWith(entryLink: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncEntryLink implements SyncEntryLink {
  _$SyncEntryLink(
      {required this.entryLink, required this.status, final String? $type})
      : $type = $type ?? 'entryLink';

  factory _$SyncEntryLink.fromJson(Map<String, dynamic> json) =>
      _$$SyncEntryLinkFromJson(json);

  @override
  final EntryLink entryLink;
  @override
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SyncMessage.entryLink(entryLink: $entryLink, status: $status)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncEntryLink &&
            (identical(other.entryLink, entryLink) ||
                other.entryLink == entryLink) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, entryLink, status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncEntryLinkCopyWith<_$SyncEntryLink> get copyWith =>
      __$$SyncEntryLinkCopyWithImpl<_$SyncEntryLink>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            JournalEntity journalEntity, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
  }) {
    return entryLink(this.entryLink, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
  }) {
    return entryLink?.call(this.entryLink, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(JournalEntity journalEntity, SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    required TResult orElse(),
  }) {
    if (entryLink != null) {
      return entryLink(this.entryLink, status);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SyncJournalEntity value) journalEntity,
    required TResult Function(SyncEntityDefinition value) entityDefinition,
    required TResult Function(SyncTagEntity value) tagEntity,
    required TResult Function(SyncEntryLink value) entryLink,
  }) {
    return entryLink(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
  }) {
    return entryLink?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    required TResult orElse(),
  }) {
    if (entryLink != null) {
      return entryLink(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncEntryLinkToJson(
      this,
    );
  }
}

abstract class SyncEntryLink implements SyncMessage {
  factory SyncEntryLink(
      {required final EntryLink entryLink,
      required final SyncEntryStatus status}) = _$SyncEntryLink;

  factory SyncEntryLink.fromJson(Map<String, dynamic> json) =
      _$SyncEntryLink.fromJson;

  EntryLink get entryLink;
  @override
  SyncEntryStatus get status;
  @override
  @JsonKey(ignore: true)
  _$$SyncEntryLinkCopyWith<_$SyncEntryLink> get copyWith =>
      throw _privateConstructorUsedError;
}
