// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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
    case 'themingSelection':
      return SyncThemingSelection.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'SyncMessage',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$SyncMessage {
  /// Serializes this SyncMessage to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is SyncMessage);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SyncMessage()';
  }
}

/// @nodoc
class $SyncMessageCopyWith<$Res> {
  $SyncMessageCopyWith(SyncMessage _, $Res Function(SyncMessage) __);
}

/// Adds pattern-matching-related methods to [SyncMessage].
extension SyncMessagePatterns on SyncMessage {
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
    TResult Function(SyncJournalEntity value)? journalEntity,
    TResult Function(SyncEntityDefinition value)? entityDefinition,
    TResult Function(SyncTagEntity value)? tagEntity,
    TResult Function(SyncEntryLink value)? entryLink,
    TResult Function(SyncAiConfig value)? aiConfig,
    TResult Function(SyncAiConfigDelete value)? aiConfigDelete,
    TResult Function(SyncThemingSelection value)? themingSelection,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SyncJournalEntity() when journalEntity != null:
        return journalEntity(_that);
      case SyncEntityDefinition() when entityDefinition != null:
        return entityDefinition(_that);
      case SyncTagEntity() when tagEntity != null:
        return tagEntity(_that);
      case SyncEntryLink() when entryLink != null:
        return entryLink(_that);
      case SyncAiConfig() when aiConfig != null:
        return aiConfig(_that);
      case SyncAiConfigDelete() when aiConfigDelete != null:
        return aiConfigDelete(_that);
      case SyncThemingSelection() when themingSelection != null:
        return themingSelection(_that);
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
    required TResult Function(SyncJournalEntity value) journalEntity,
    required TResult Function(SyncEntityDefinition value) entityDefinition,
    required TResult Function(SyncTagEntity value) tagEntity,
    required TResult Function(SyncEntryLink value) entryLink,
    required TResult Function(SyncAiConfig value) aiConfig,
    required TResult Function(SyncAiConfigDelete value) aiConfigDelete,
    required TResult Function(SyncThemingSelection value) themingSelection,
  }) {
    final _that = this;
    switch (_that) {
      case SyncJournalEntity():
        return journalEntity(_that);
      case SyncEntityDefinition():
        return entityDefinition(_that);
      case SyncTagEntity():
        return tagEntity(_that);
      case SyncEntryLink():
        return entryLink(_that);
      case SyncAiConfig():
        return aiConfig(_that);
      case SyncAiConfigDelete():
        return aiConfigDelete(_that);
      case SyncThemingSelection():
        return themingSelection(_that);
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
    TResult? Function(SyncJournalEntity value)? journalEntity,
    TResult? Function(SyncEntityDefinition value)? entityDefinition,
    TResult? Function(SyncTagEntity value)? tagEntity,
    TResult? Function(SyncEntryLink value)? entryLink,
    TResult? Function(SyncAiConfig value)? aiConfig,
    TResult? Function(SyncAiConfigDelete value)? aiConfigDelete,
    TResult? Function(SyncThemingSelection value)? themingSelection,
  }) {
    final _that = this;
    switch (_that) {
      case SyncJournalEntity() when journalEntity != null:
        return journalEntity(_that);
      case SyncEntityDefinition() when entityDefinition != null:
        return entityDefinition(_that);
      case SyncTagEntity() when tagEntity != null:
        return tagEntity(_that);
      case SyncEntryLink() when entryLink != null:
        return entryLink(_that);
      case SyncAiConfig() when aiConfig != null:
        return aiConfig(_that);
      case SyncAiConfigDelete() when aiConfigDelete != null:
        return aiConfigDelete(_that);
      case SyncThemingSelection() when themingSelection != null:
        return themingSelection(_that);
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
    TResult Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status, List<EntryLink>? entryLinks)?
        journalEntity,
    TResult Function(EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult Function(String id)? aiConfigDelete,
    TResult Function(String lightThemeName, String darkThemeName,
            String themeMode, int updatedAt, SyncEntryStatus status)?
        themingSelection,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SyncJournalEntity() when journalEntity != null:
        return journalEntity(_that.id, _that.jsonPath, _that.vectorClock,
            _that.status, _that.entryLinks);
      case SyncEntityDefinition() when entityDefinition != null:
        return entityDefinition(_that.entityDefinition, _that.status);
      case SyncTagEntity() when tagEntity != null:
        return tagEntity(_that.tagEntity, _that.status);
      case SyncEntryLink() when entryLink != null:
        return entryLink(_that.entryLink, _that.status);
      case SyncAiConfig() when aiConfig != null:
        return aiConfig(_that.aiConfig, _that.status);
      case SyncAiConfigDelete() when aiConfigDelete != null:
        return aiConfigDelete(_that.id);
      case SyncThemingSelection() when themingSelection != null:
        return themingSelection(_that.lightThemeName, _that.darkThemeName,
            _that.themeMode, _that.updatedAt, _that.status);
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
            String jsonPath,
            VectorClock? vectorClock,
            SyncEntryStatus status,
            List<EntryLink>? entryLinks)
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
    required TResult Function(String lightThemeName, String darkThemeName,
            String themeMode, int updatedAt, SyncEntryStatus status)
        themingSelection,
  }) {
    final _that = this;
    switch (_that) {
      case SyncJournalEntity():
        return journalEntity(_that.id, _that.jsonPath, _that.vectorClock,
            _that.status, _that.entryLinks);
      case SyncEntityDefinition():
        return entityDefinition(_that.entityDefinition, _that.status);
      case SyncTagEntity():
        return tagEntity(_that.tagEntity, _that.status);
      case SyncEntryLink():
        return entryLink(_that.entryLink, _that.status);
      case SyncAiConfig():
        return aiConfig(_that.aiConfig, _that.status);
      case SyncAiConfigDelete():
        return aiConfigDelete(_that.id);
      case SyncThemingSelection():
        return themingSelection(_that.lightThemeName, _that.darkThemeName,
            _that.themeMode, _that.updatedAt, _that.status);
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
    TResult? Function(String id, String jsonPath, VectorClock? vectorClock,
            SyncEntryStatus status, List<EntryLink>? entryLinks)?
        journalEntity,
    TResult? Function(
            EntityDefinition entityDefinition, SyncEntryStatus status)?
        entityDefinition,
    TResult? Function(TagEntity tagEntity, SyncEntryStatus status)? tagEntity,
    TResult? Function(EntryLink entryLink, SyncEntryStatus status)? entryLink,
    TResult? Function(AiConfig aiConfig, SyncEntryStatus status)? aiConfig,
    TResult? Function(String id)? aiConfigDelete,
    TResult? Function(String lightThemeName, String darkThemeName,
            String themeMode, int updatedAt, SyncEntryStatus status)?
        themingSelection,
  }) {
    final _that = this;
    switch (_that) {
      case SyncJournalEntity() when journalEntity != null:
        return journalEntity(_that.id, _that.jsonPath, _that.vectorClock,
            _that.status, _that.entryLinks);
      case SyncEntityDefinition() when entityDefinition != null:
        return entityDefinition(_that.entityDefinition, _that.status);
      case SyncTagEntity() when tagEntity != null:
        return tagEntity(_that.tagEntity, _that.status);
      case SyncEntryLink() when entryLink != null:
        return entryLink(_that.entryLink, _that.status);
      case SyncAiConfig() when aiConfig != null:
        return aiConfig(_that.aiConfig, _that.status);
      case SyncAiConfigDelete() when aiConfigDelete != null:
        return aiConfigDelete(_that.id);
      case SyncThemingSelection() when themingSelection != null:
        return themingSelection(_that.lightThemeName, _that.darkThemeName,
            _that.themeMode, _that.updatedAt, _that.status);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class SyncJournalEntity implements SyncMessage {
  const SyncJournalEntity(
      {required this.id,
      required this.jsonPath,
      required this.vectorClock,
      required this.status,
      final List<EntryLink>? entryLinks,
      final String? $type})
      : _entryLinks = entryLinks,
        $type = $type ?? 'journalEntity';
  factory SyncJournalEntity.fromJson(Map<String, dynamic> json) =>
      _$SyncJournalEntityFromJson(json);

  final String id;
  final String jsonPath;
  final VectorClock? vectorClock;
  final SyncEntryStatus status;
  final List<EntryLink>? _entryLinks;
  List<EntryLink>? get entryLinks {
    final value = _entryLinks;
    if (value == null) return null;
    if (_entryLinks is EqualUnmodifiableListView) return _entryLinks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncJournalEntityCopyWith<SyncJournalEntity> get copyWith =>
      _$SyncJournalEntityCopyWithImpl<SyncJournalEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncJournalEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncJournalEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.jsonPath, jsonPath) ||
                other.jsonPath == jsonPath) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality()
                .equals(other._entryLinks, _entryLinks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, jsonPath, vectorClock,
      status, const DeepCollectionEquality().hash(_entryLinks));

  @override
  String toString() {
    return 'SyncMessage.journalEntity(id: $id, jsonPath: $jsonPath, vectorClock: $vectorClock, status: $status, entryLinks: $entryLinks)';
  }
}

/// @nodoc
abstract mixin class $SyncJournalEntityCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory $SyncJournalEntityCopyWith(
          SyncJournalEntity value, $Res Function(SyncJournalEntity) _then) =
      _$SyncJournalEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String jsonPath,
      VectorClock? vectorClock,
      SyncEntryStatus status,
      List<EntryLink>? entryLinks});
}

/// @nodoc
class _$SyncJournalEntityCopyWithImpl<$Res>
    implements $SyncJournalEntityCopyWith<$Res> {
  _$SyncJournalEntityCopyWithImpl(this._self, this._then);

  final SyncJournalEntity _self;
  final $Res Function(SyncJournalEntity) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? jsonPath = null,
    Object? vectorClock = freezed,
    Object? status = null,
    Object? entryLinks = freezed,
  }) {
    return _then(SyncJournalEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      jsonPath: null == jsonPath
          ? _self.jsonPath
          : jsonPath // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
      entryLinks: freezed == entryLinks
          ? _self._entryLinks
          : entryLinks // ignore: cast_nullable_to_non_nullable
              as List<EntryLink>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class SyncEntityDefinition implements SyncMessage {
  const SyncEntityDefinition(
      {required this.entityDefinition,
      required this.status,
      final String? $type})
      : $type = $type ?? 'entityDefinition';
  factory SyncEntityDefinition.fromJson(Map<String, dynamic> json) =>
      _$SyncEntityDefinitionFromJson(json);

  final EntityDefinition entityDefinition;
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncEntityDefinitionCopyWith<SyncEntityDefinition> get copyWith =>
      _$SyncEntityDefinitionCopyWithImpl<SyncEntityDefinition>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncEntityDefinitionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncEntityDefinition &&
            (identical(other.entityDefinition, entityDefinition) ||
                other.entityDefinition == entityDefinition) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, entityDefinition, status);

  @override
  String toString() {
    return 'SyncMessage.entityDefinition(entityDefinition: $entityDefinition, status: $status)';
  }
}

/// @nodoc
abstract mixin class $SyncEntityDefinitionCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory $SyncEntityDefinitionCopyWith(SyncEntityDefinition value,
          $Res Function(SyncEntityDefinition) _then) =
      _$SyncEntityDefinitionCopyWithImpl;
  @useResult
  $Res call({EntityDefinition entityDefinition, SyncEntryStatus status});

  $EntityDefinitionCopyWith<$Res> get entityDefinition;
}

/// @nodoc
class _$SyncEntityDefinitionCopyWithImpl<$Res>
    implements $SyncEntityDefinitionCopyWith<$Res> {
  _$SyncEntityDefinitionCopyWithImpl(this._self, this._then);

  final SyncEntityDefinition _self;
  final $Res Function(SyncEntityDefinition) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? entityDefinition = null,
    Object? status = null,
  }) {
    return _then(SyncEntityDefinition(
      entityDefinition: null == entityDefinition
          ? _self.entityDefinition
          : entityDefinition // ignore: cast_nullable_to_non_nullable
              as EntityDefinition,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntityDefinitionCopyWith<$Res> get entityDefinition {
    return $EntityDefinitionCopyWith<$Res>(_self.entityDefinition, (value) {
      return _then(_self.copyWith(entityDefinition: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class SyncTagEntity implements SyncMessage {
  const SyncTagEntity(
      {required this.tagEntity, required this.status, final String? $type})
      : $type = $type ?? 'tagEntity';
  factory SyncTagEntity.fromJson(Map<String, dynamic> json) =>
      _$SyncTagEntityFromJson(json);

  final TagEntity tagEntity;
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncTagEntityCopyWith<SyncTagEntity> get copyWith =>
      _$SyncTagEntityCopyWithImpl<SyncTagEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncTagEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncTagEntity &&
            (identical(other.tagEntity, tagEntity) ||
                other.tagEntity == tagEntity) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tagEntity, status);

  @override
  String toString() {
    return 'SyncMessage.tagEntity(tagEntity: $tagEntity, status: $status)';
  }
}

/// @nodoc
abstract mixin class $SyncTagEntityCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory $SyncTagEntityCopyWith(
          SyncTagEntity value, $Res Function(SyncTagEntity) _then) =
      _$SyncTagEntityCopyWithImpl;
  @useResult
  $Res call({TagEntity tagEntity, SyncEntryStatus status});

  $TagEntityCopyWith<$Res> get tagEntity;
}

/// @nodoc
class _$SyncTagEntityCopyWithImpl<$Res>
    implements $SyncTagEntityCopyWith<$Res> {
  _$SyncTagEntityCopyWithImpl(this._self, this._then);

  final SyncTagEntity _self;
  final $Res Function(SyncTagEntity) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? tagEntity = null,
    Object? status = null,
  }) {
    return _then(SyncTagEntity(
      tagEntity: null == tagEntity
          ? _self.tagEntity
          : tagEntity // ignore: cast_nullable_to_non_nullable
              as TagEntity,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TagEntityCopyWith<$Res> get tagEntity {
    return $TagEntityCopyWith<$Res>(_self.tagEntity, (value) {
      return _then(_self.copyWith(tagEntity: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class SyncEntryLink implements SyncMessage {
  const SyncEntryLink(
      {required this.entryLink, required this.status, final String? $type})
      : $type = $type ?? 'entryLink';
  factory SyncEntryLink.fromJson(Map<String, dynamic> json) =>
      _$SyncEntryLinkFromJson(json);

  final EntryLink entryLink;
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncEntryLinkCopyWith<SyncEntryLink> get copyWith =>
      _$SyncEntryLinkCopyWithImpl<SyncEntryLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncEntryLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncEntryLink &&
            (identical(other.entryLink, entryLink) ||
                other.entryLink == entryLink) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, entryLink, status);

  @override
  String toString() {
    return 'SyncMessage.entryLink(entryLink: $entryLink, status: $status)';
  }
}

/// @nodoc
abstract mixin class $SyncEntryLinkCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory $SyncEntryLinkCopyWith(
          SyncEntryLink value, $Res Function(SyncEntryLink) _then) =
      _$SyncEntryLinkCopyWithImpl;
  @useResult
  $Res call({EntryLink entryLink, SyncEntryStatus status});

  $EntryLinkCopyWith<$Res> get entryLink;
}

/// @nodoc
class _$SyncEntryLinkCopyWithImpl<$Res>
    implements $SyncEntryLinkCopyWith<$Res> {
  _$SyncEntryLinkCopyWithImpl(this._self, this._then);

  final SyncEntryLink _self;
  final $Res Function(SyncEntryLink) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? entryLink = null,
    Object? status = null,
  }) {
    return _then(SyncEntryLink(
      entryLink: null == entryLink
          ? _self.entryLink
          : entryLink // ignore: cast_nullable_to_non_nullable
              as EntryLink,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EntryLinkCopyWith<$Res> get entryLink {
    return $EntryLinkCopyWith<$Res>(_self.entryLink, (value) {
      return _then(_self.copyWith(entryLink: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class SyncAiConfig implements SyncMessage {
  const SyncAiConfig(
      {required this.aiConfig, required this.status, final String? $type})
      : $type = $type ?? 'aiConfig';
  factory SyncAiConfig.fromJson(Map<String, dynamic> json) =>
      _$SyncAiConfigFromJson(json);

  final AiConfig aiConfig;
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncAiConfigCopyWith<SyncAiConfig> get copyWith =>
      _$SyncAiConfigCopyWithImpl<SyncAiConfig>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncAiConfigToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncAiConfig &&
            (identical(other.aiConfig, aiConfig) ||
                other.aiConfig == aiConfig) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, aiConfig, status);

  @override
  String toString() {
    return 'SyncMessage.aiConfig(aiConfig: $aiConfig, status: $status)';
  }
}

/// @nodoc
abstract mixin class $SyncAiConfigCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory $SyncAiConfigCopyWith(
          SyncAiConfig value, $Res Function(SyncAiConfig) _then) =
      _$SyncAiConfigCopyWithImpl;
  @useResult
  $Res call({AiConfig aiConfig, SyncEntryStatus status});

  $AiConfigCopyWith<$Res> get aiConfig;
}

/// @nodoc
class _$SyncAiConfigCopyWithImpl<$Res> implements $SyncAiConfigCopyWith<$Res> {
  _$SyncAiConfigCopyWithImpl(this._self, this._then);

  final SyncAiConfig _self;
  final $Res Function(SyncAiConfig) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? aiConfig = null,
    Object? status = null,
  }) {
    return _then(SyncAiConfig(
      aiConfig: null == aiConfig
          ? _self.aiConfig
          : aiConfig // ignore: cast_nullable_to_non_nullable
              as AiConfig,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AiConfigCopyWith<$Res> get aiConfig {
    return $AiConfigCopyWith<$Res>(_self.aiConfig, (value) {
      return _then(_self.copyWith(aiConfig: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class SyncAiConfigDelete implements SyncMessage {
  const SyncAiConfigDelete({required this.id, final String? $type})
      : $type = $type ?? 'aiConfigDelete';
  factory SyncAiConfigDelete.fromJson(Map<String, dynamic> json) =>
      _$SyncAiConfigDeleteFromJson(json);

  final String id;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncAiConfigDeleteCopyWith<SyncAiConfigDelete> get copyWith =>
      _$SyncAiConfigDeleteCopyWithImpl<SyncAiConfigDelete>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncAiConfigDeleteToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncAiConfigDelete &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() {
    return 'SyncMessage.aiConfigDelete(id: $id)';
  }
}

/// @nodoc
abstract mixin class $SyncAiConfigDeleteCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory $SyncAiConfigDeleteCopyWith(
          SyncAiConfigDelete value, $Res Function(SyncAiConfigDelete) _then) =
      _$SyncAiConfigDeleteCopyWithImpl;
  @useResult
  $Res call({String id});
}

/// @nodoc
class _$SyncAiConfigDeleteCopyWithImpl<$Res>
    implements $SyncAiConfigDeleteCopyWith<$Res> {
  _$SyncAiConfigDeleteCopyWithImpl(this._self, this._then);

  final SyncAiConfigDelete _self;
  final $Res Function(SyncAiConfigDelete) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
  }) {
    return _then(SyncAiConfigDelete(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class SyncThemingSelection implements SyncMessage {
  const SyncThemingSelection(
      {required this.lightThemeName,
      required this.darkThemeName,
      required this.themeMode,
      required this.updatedAt,
      required this.status,
      final String? $type})
      : $type = $type ?? 'themingSelection';
  factory SyncThemingSelection.fromJson(Map<String, dynamic> json) =>
      _$SyncThemingSelectionFromJson(json);

  final String lightThemeName;
  final String darkThemeName;
  final String themeMode;
  final int updatedAt;
  final SyncEntryStatus status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SyncThemingSelectionCopyWith<SyncThemingSelection> get copyWith =>
      _$SyncThemingSelectionCopyWithImpl<SyncThemingSelection>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SyncThemingSelectionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SyncThemingSelection &&
            (identical(other.lightThemeName, lightThemeName) ||
                other.lightThemeName == lightThemeName) &&
            (identical(other.darkThemeName, darkThemeName) ||
                other.darkThemeName == darkThemeName) &&
            (identical(other.themeMode, themeMode) ||
                other.themeMode == themeMode) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, lightThemeName, darkThemeName, themeMode, updatedAt, status);

  @override
  String toString() {
    return 'SyncMessage.themingSelection(lightThemeName: $lightThemeName, darkThemeName: $darkThemeName, themeMode: $themeMode, updatedAt: $updatedAt, status: $status)';
  }
}

/// @nodoc
abstract mixin class $SyncThemingSelectionCopyWith<$Res>
    implements $SyncMessageCopyWith<$Res> {
  factory $SyncThemingSelectionCopyWith(SyncThemingSelection value,
          $Res Function(SyncThemingSelection) _then) =
      _$SyncThemingSelectionCopyWithImpl;
  @useResult
  $Res call(
      {String lightThemeName,
      String darkThemeName,
      String themeMode,
      int updatedAt,
      SyncEntryStatus status});
}

/// @nodoc
class _$SyncThemingSelectionCopyWithImpl<$Res>
    implements $SyncThemingSelectionCopyWith<$Res> {
  _$SyncThemingSelectionCopyWithImpl(this._self, this._then);

  final SyncThemingSelection _self;
  final $Res Function(SyncThemingSelection) _then;

  /// Create a copy of SyncMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? lightThemeName = null,
    Object? darkThemeName = null,
    Object? themeMode = null,
    Object? updatedAt = null,
    Object? status = null,
  }) {
    return _then(SyncThemingSelection(
      lightThemeName: null == lightThemeName
          ? _self.lightThemeName
          : lightThemeName // ignore: cast_nullable_to_non_nullable
              as String,
      darkThemeName: null == darkThemeName
          ? _self.darkThemeName
          : darkThemeName // ignore: cast_nullable_to_non_nullable
              as String,
      themeMode: null == themeMode
          ? _self.themeMode
          : themeMode // ignore: cast_nullable_to_non_nullable
              as String,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as SyncEntryStatus,
    ));
  }
}

// dart format on
