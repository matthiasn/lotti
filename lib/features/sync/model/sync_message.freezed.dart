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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

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
    case 'aiConfig':
      return SyncAiConfig.fromJson(json);
    case 'aiConfigDelete':
      return SyncAiConfigDelete.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'SyncMessage',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$SyncMessage {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String jsonPath,
            VectorClock? vectorClock, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
    required TResult Function(AiConfig aiConfig, SyncEntryStatus status)
        aiConfig,
    required TResult Function(String id) aiConfigDelete,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SyncJournalEntity value) journalEntity,
    required TResult Function(SyncEntityDefinition value) entityDefinition,
    required TResult Function(SyncTagEntity value) tagEntity,
    required TResult Function(SyncEntryLink value) entryLink,
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this SyncMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncMessageCopyWith<$Res> {
  factory $SyncMessageCopyWith(
          SyncMessage value, $Res Function(SyncMessage) then) =
      _$SyncMessageCopyWithImpl<$Res, SyncMessage>;
}

/// @nodoc
class _$SyncMessageCopyWithImpl<$Res, $Val extends SyncMessage>
    implements $SyncMessageCopyWith<$Res> {
  _$SyncMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$SyncJournalEntityImplCopyWith<$Res> {
  factory _$$SyncJournalEntityImplCopyWith(_$SyncJournalEntityImpl value,
          $Res Function(_$SyncJournalEntityImpl) then) =
      __$$SyncJournalEntityImplCopyWithImpl<$Res>;
  @useResult
  $Res call(
      {String id,
      String jsonPath,
      VectorClock? vectorClock,
      SyncEntryStatus status});
}

/// @nodoc
class __$$SyncJournalEntityImplCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncJournalEntityImpl>
    implements _$$SyncJournalEntityImplCopyWith<$Res> {
  __$$SyncJournalEntityImplCopyWithImpl(_$SyncJournalEntityImpl _value,
      $Res Function(_$SyncJournalEntityImpl) _then)
      : super(_value, _then);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? jsonPath = null,
    Object? vectorClock = freezed,
    Object? status = null,
  }) {
    return _then(_$SyncJournalEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      jsonPath: null == jsonPath
          ? _value.jsonPath
          : jsonPath // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _value.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncJournalEntityImpl implements SyncJournalEntity {
  const _$SyncJournalEntityImpl(
      {required this.id,
      required this.jsonPath,
      required this.vectorClock,
      required this.status,
      final String? $type})
      : $type = $type ?? 'journalEntity';

  factory _$SyncJournalEntityImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncJournalEntityImplFromJson(json);

  @override
  final String id;
  @override
  final String jsonPath;
  @override
  final VectorClock? vectorClock;
  @override
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SyncMessage.journalEntity(id: $id, jsonPath: $jsonPath, vectorClock: $vectorClock, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncJournalEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.jsonPath, jsonPath) ||
                other.jsonPath == jsonPath) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, jsonPath, vectorClock, status);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncJournalEntityImplCopyWith<_$SyncJournalEntityImpl> get copyWith =>
      __$$SyncJournalEntityImplCopyWithImpl<_$SyncJournalEntityImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String jsonPath,
            VectorClock? vectorClock, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
    required TResult Function(AiConfig aiConfig, SyncEntryStatus status)
        aiConfig,
    required TResult Function(String id) aiConfigDelete,
  }) {
    return journalEntity(id, jsonPath, vectorClock, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
  }) {
    return journalEntity?.call(id, jsonPath, vectorClock, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (journalEntity != null) {
      return journalEntity(id, jsonPath, vectorClock, status);
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
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
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
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
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
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (journalEntity != null) {
      return journalEntity(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncJournalEntityImplToJson(
      this,
    );
  }
}

abstract class SyncJournalEntity implements SyncMessage {
  const factory SyncJournalEntity(
      {required final String id,
      required final String jsonPath,
      required final VectorClock? vectorClock,
      required final SyncEntryStatus status}) = _$SyncJournalEntityImpl;

  factory SyncJournalEntity.fromJson(Map<String, dynamic> json) =
      _$SyncJournalEntityImpl.fromJson;

  String get id;
  String get jsonPath;
  VectorClock? get vectorClock;
  SyncEntryStatus get status;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncJournalEntityImplCopyWith<_$SyncJournalEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncEntityDefinitionImplCopyWith<$Res> {
  factory _$$SyncEntityDefinitionImplCopyWith(_$SyncEntityDefinitionImpl value,
          $Res Function(_$SyncEntityDefinitionImpl) then) =
      __$$SyncEntityDefinitionImplCopyWithImpl<$Res>;
  @useResult
  $Res call({EntityDefinition entityDefinition, SyncEntryStatus status});

  $EntityDefinitionCopyWith<$Res> get entityDefinition;
}

/// @nodoc
class __$$SyncEntityDefinitionImplCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncEntityDefinitionImpl>
    implements _$$SyncEntityDefinitionImplCopyWith<$Res> {
  __$$SyncEntityDefinitionImplCopyWithImpl(_$SyncEntityDefinitionImpl _value,
      $Res Function(_$SyncEntityDefinitionImpl) _then)
      : super(_value, _then);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entityDefinition = null,
    Object? status = null,
  }) {
    return _then(_$SyncEntityDefinitionImpl(
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

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
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
class _$SyncEntityDefinitionImpl implements SyncEntityDefinition {
  const _$SyncEntityDefinitionImpl(
      {required this.entityDefinition,
      required this.status,
      final String? $type})
      : $type = $type ?? 'entityDefinition';

  factory _$SyncEntityDefinitionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncEntityDefinitionImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncEntityDefinitionImpl &&
            (identical(other.entityDefinition, entityDefinition) ||
                other.entityDefinition == entityDefinition) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, entityDefinition, status);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncEntityDefinitionImplCopyWith<_$SyncEntityDefinitionImpl>
      get copyWith =>
          __$$SyncEntityDefinitionImplCopyWithImpl<_$SyncEntityDefinitionImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String jsonPath,
            VectorClock? vectorClock, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
    required TResult Function(AiConfig aiConfig, SyncEntryStatus status)
        aiConfig,
    required TResult Function(String id) aiConfigDelete,
  }) {
    return entityDefinition(this.entityDefinition, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
  }) {
    return entityDefinition?.call(this.entityDefinition, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
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
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
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
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
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
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (entityDefinition != null) {
      return entityDefinition(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncEntityDefinitionImplToJson(
      this,
    );
  }
}

abstract class SyncEntityDefinition implements SyncMessage {
  const factory SyncEntityDefinition(
      {required final EntityDefinition entityDefinition,
      required final SyncEntryStatus status}) = _$SyncEntityDefinitionImpl;

  factory SyncEntityDefinition.fromJson(Map<String, dynamic> json) =
      _$SyncEntityDefinitionImpl.fromJson;

  EntityDefinition get entityDefinition;
  SyncEntryStatus get status;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncEntityDefinitionImplCopyWith<_$SyncEntityDefinitionImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncTagEntityImplCopyWith<$Res> {
  factory _$$SyncTagEntityImplCopyWith(
          _$SyncTagEntityImpl value, $Res Function(_$SyncTagEntityImpl) then) =
      __$$SyncTagEntityImplCopyWithImpl<$Res>;
  @useResult
  $Res call({TagEntity tagEntity, SyncEntryStatus status});

  $TagEntityCopyWith<$Res> get tagEntity;
}

/// @nodoc
class __$$SyncTagEntityImplCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncTagEntityImpl>
    implements _$$SyncTagEntityImplCopyWith<$Res> {
  __$$SyncTagEntityImplCopyWithImpl(
      _$SyncTagEntityImpl _value, $Res Function(_$SyncTagEntityImpl) _then)
      : super(_value, _then);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagEntity = null,
    Object? status = null,
  }) {
    return _then(_$SyncTagEntityImpl(
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

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
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
class _$SyncTagEntityImpl implements SyncTagEntity {
  const _$SyncTagEntityImpl(
      {required this.tagEntity, required this.status, final String? $type})
      : $type = $type ?? 'tagEntity';

  factory _$SyncTagEntityImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncTagEntityImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncTagEntityImpl &&
            (identical(other.tagEntity, tagEntity) ||
                other.tagEntity == tagEntity) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tagEntity, status);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncTagEntityImplCopyWith<_$SyncTagEntityImpl> get copyWith =>
      __$$SyncTagEntityImplCopyWithImpl<_$SyncTagEntityImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String jsonPath,
            VectorClock? vectorClock, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
    required TResult Function(AiConfig aiConfig, SyncEntryStatus status)
        aiConfig,
    required TResult Function(String id) aiConfigDelete,
  }) {
    return tagEntity(this.tagEntity, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
  }) {
    return tagEntity?.call(this.tagEntity, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
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
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
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
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
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
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (tagEntity != null) {
      return tagEntity(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncTagEntityImplToJson(
      this,
    );
  }
}

abstract class SyncTagEntity implements SyncMessage {
  const factory SyncTagEntity(
      {required final TagEntity tagEntity,
      required final SyncEntryStatus status}) = _$SyncTagEntityImpl;

  factory SyncTagEntity.fromJson(Map<String, dynamic> json) =
      _$SyncTagEntityImpl.fromJson;

  TagEntity get tagEntity;
  SyncEntryStatus get status;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncTagEntityImplCopyWith<_$SyncTagEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncEntryLinkImplCopyWith<$Res> {
  factory _$$SyncEntryLinkImplCopyWith(
          _$SyncEntryLinkImpl value, $Res Function(_$SyncEntryLinkImpl) then) =
      __$$SyncEntryLinkImplCopyWithImpl<$Res>;
  @useResult
  $Res call({EntryLink entryLink, SyncEntryStatus status});

  $EntryLinkCopyWith<$Res> get entryLink;
}

/// @nodoc
class __$$SyncEntryLinkImplCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncEntryLinkImpl>
    implements _$$SyncEntryLinkImplCopyWith<$Res> {
  __$$SyncEntryLinkImplCopyWithImpl(
      _$SyncEntryLinkImpl _value, $Res Function(_$SyncEntryLinkImpl) _then)
      : super(_value, _then);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryLink = null,
    Object? status = null,
  }) {
    return _then(_$SyncEntryLinkImpl(
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

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
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
class _$SyncEntryLinkImpl implements SyncEntryLink {
  const _$SyncEntryLinkImpl(
      {required this.entryLink, required this.status, final String? $type})
      : $type = $type ?? 'entryLink';

  factory _$SyncEntryLinkImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncEntryLinkImplFromJson(json);

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
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncEntryLinkImpl &&
            (identical(other.entryLink, entryLink) ||
                other.entryLink == entryLink) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, entryLink, status);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncEntryLinkImplCopyWith<_$SyncEntryLinkImpl> get copyWith =>
      __$$SyncEntryLinkImplCopyWithImpl<_$SyncEntryLinkImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String jsonPath,
            VectorClock? vectorClock, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
    required TResult Function(AiConfig aiConfig, SyncEntryStatus status)
        aiConfig,
    required TResult Function(String id) aiConfigDelete,
  }) {
    return entryLink(this.entryLink, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
  }) {
    return entryLink?.call(this.entryLink, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
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
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
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
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
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
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (entryLink != null) {
      return entryLink(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncEntryLinkImplToJson(
      this,
    );
  }
}

abstract class SyncEntryLink implements SyncMessage {
  const factory SyncEntryLink(
      {required final EntryLink entryLink,
      required final SyncEntryStatus status}) = _$SyncEntryLinkImpl;

  factory SyncEntryLink.fromJson(Map<String, dynamic> json) =
      _$SyncEntryLinkImpl.fromJson;

  EntryLink get entryLink;
  SyncEntryStatus get status;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncEntryLinkImplCopyWith<_$SyncEntryLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncAiConfigImplCopyWith<$Res> {
  factory _$$SyncAiConfigImplCopyWith(
          _$SyncAiConfigImpl value, $Res Function(_$SyncAiConfigImpl) then) =
      __$$SyncAiConfigImplCopyWithImpl<$Res>;
  @useResult
  $Res call({AiConfig aiConfig, SyncEntryStatus status});

  $AiConfigCopyWith<$Res> get aiConfig;
}

/// @nodoc
class __$$SyncAiConfigImplCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncAiConfigImpl>
    implements _$$SyncAiConfigImplCopyWith<$Res> {
  __$$SyncAiConfigImplCopyWithImpl(
      _$SyncAiConfigImpl _value, $Res Function(_$SyncAiConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? aiConfig = null,
    Object? status = null,
  }) {
    return _then(_$SyncAiConfigImpl(
      aiConfig: null == aiConfig
          ? _value.aiConfig
          : aiConfig // ignore: cast_nullable_to_non_nullable
              as AiConfig,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AiConfigCopyWith<$Res> get aiConfig {
    return $AiConfigCopyWith<$Res>(_value.aiConfig, (value) {
      return _then(_value.copyWith(aiConfig: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncAiConfigImpl implements SyncAiConfig {
  const _$SyncAiConfigImpl(
      {required this.aiConfig, required this.status, final String? $type})
      : $type = $type ?? 'aiConfig';

  factory _$SyncAiConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncAiConfigImplFromJson(json);

  @override
  final AiConfig aiConfig;
  @override
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SyncMessage.aiConfig(aiConfig: $aiConfig, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncAiConfigImpl &&
            (identical(other.aiConfig, aiConfig) ||
                other.aiConfig == aiConfig) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, aiConfig, status);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncAiConfigImplCopyWith<_$SyncAiConfigImpl> get copyWith =>
      __$$SyncAiConfigImplCopyWithImpl<_$SyncAiConfigImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String jsonPath,
            VectorClock? vectorClock, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
    required TResult Function(AiConfig aiConfig, SyncEntryStatus status)
        aiConfig,
    required TResult Function(String id) aiConfigDelete,
  }) {
    return aiConfig(this.aiConfig, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
  }) {
    return aiConfig?.call(this.aiConfig, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (aiConfig != null) {
      return aiConfig(this.aiConfig, status);
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
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
  }) {
    return aiConfig(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
  }) {
    return aiConfig?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (aiConfig != null) {
      return aiConfig(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncAiConfigImplToJson(
      this,
    );
  }
}

abstract class SyncAiConfig implements SyncMessage {
  const factory SyncAiConfig(
      {required final AiConfig aiConfig,
      required final SyncEntryStatus status}) = _$SyncAiConfigImpl;

  factory SyncAiConfig.fromJson(Map<String, dynamic> json) =
      _$SyncAiConfigImpl.fromJson;

  AiConfig get aiConfig;
  SyncEntryStatus get status;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncAiConfigImplCopyWith<_$SyncAiConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SyncAiConfigDeleteImplCopyWith<$Res> {
  factory _$$SyncAiConfigDeleteImplCopyWith(_$SyncAiConfigDeleteImpl value,
          $Res Function(_$SyncAiConfigDeleteImpl) then) =
      __$$SyncAiConfigDeleteImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String id});
}

/// @nodoc
class __$$SyncAiConfigDeleteImplCopyWithImpl<$Res>
    extends _$SyncMessageCopyWithImpl<$Res, _$SyncAiConfigDeleteImpl>
    implements _$$SyncAiConfigDeleteImplCopyWith<$Res> {
  __$$SyncAiConfigDeleteImplCopyWithImpl(_$SyncAiConfigDeleteImpl _value,
      $Res Function(_$SyncAiConfigDeleteImpl) _then)
      : super(_value, _then);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
  }) {
    return _then(_$SyncAiConfigDeleteImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SyncAiConfigDeleteImpl implements SyncAiConfigDelete {
  const _$SyncAiConfigDeleteImpl({required this.id, final String? $type})
      : $type = $type ?? 'aiConfigDelete';

  factory _$SyncAiConfigDeleteImpl.fromJson(Map<String, dynamic> json) =>
      _$$SyncAiConfigDeleteImplFromJson(json);

  @override
  final String id;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SyncMessage.aiConfigDelete(id: $id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncAiConfigDeleteImpl &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id);

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncAiConfigDeleteImplCopyWith<_$SyncAiConfigDeleteImpl> get copyWith =>
      __$$SyncAiConfigDeleteImplCopyWithImpl<_$SyncAiConfigDeleteImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String jsonPath,
            VectorClock? vectorClock, SyncEntryStatus status)
        journalEntity,
    required TResult Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)
        entityDefinition,
    required TResult Function(TagEntity tagEntity, SyncEntryStatus status)
        tagEntity,
    required TResult Function(EntryLink entryLink, SyncEntryStatus status)
        entryLink,
    required TResult Function(AiConfig aiConfig, SyncEntryStatus status)
        aiConfig,
    required TResult Function(String id) aiConfigDelete,
  }) {
    return aiConfigDelete(id);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
  }) {
    return aiConfigDelete?.call(id);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (aiConfigDelete != null) {
      return aiConfigDelete(id);
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
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
  }) {
    return aiConfigDelete(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
  }) {
    return aiConfigDelete?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    required TResult orElse(),
  }) {
    if (aiConfigDelete != null) {
      return aiConfigDelete(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SyncAiConfigDeleteImplToJson(
      this,
    );
  }
}

abstract class SyncAiConfigDelete implements SyncMessage {
  const factory SyncAiConfigDelete({required final String id}) =
      _$SyncAiConfigDeleteImpl;

  factory SyncAiConfigDelete.fromJson(Map<String, dynamic> json) =
      _$SyncAiConfigDeleteImpl.fromJson;

  String get id;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncAiConfigDeleteImplCopyWith<_$SyncAiConfigDeleteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
