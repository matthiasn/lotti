// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_domain_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
AgentDomainEntity _$AgentDomainEntityFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'agent':
      return AgentIdentityEntity.fromJson(json);
    case 'agentState':
      return AgentStateEntity.fromJson(json);
    case 'agentMessage':
      return AgentMessageEntity.fromJson(json);
    case 'agentMessagePayload':
      return AgentMessagePayloadEntity.fromJson(json);
    case 'agentReport':
      return AgentReportEntity.fromJson(json);
    case 'agentReportHead':
      return AgentReportHeadEntity.fromJson(json);

    default:
      return AgentUnknownEntity.fromJson(json);
  }
}

/// @nodoc
mixin _$AgentDomainEntity {
  String get id;
  String get agentId;
  VectorClock? get vectorClock;
  DateTime? get deletedAt;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentDomainEntityCopyWith<AgentDomainEntity> get copyWith =>
      _$AgentDomainEntityCopyWithImpl<AgentDomainEntity>(
          this as AgentDomainEntity, _$identity);

  /// Serializes this AgentDomainEntity to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentDomainEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, agentId, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentDomainEntity(id: $id, agentId: $agentId, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentDomainEntityCopyWith<$Res> {
  factory $AgentDomainEntityCopyWith(
          AgentDomainEntity value, $Res Function(AgentDomainEntity) _then) =
      _$AgentDomainEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String agentId,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentDomainEntityCopyWithImpl<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  _$AgentDomainEntityCopyWithImpl(this._self, this._then);

  final AgentDomainEntity _self;
  final $Res Function(AgentDomainEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AgentDomainEntity].
extension AgentDomainEntityPatterns on AgentDomainEntity {
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
    TResult Function(AgentIdentityEntity value)? agent,
    TResult Function(AgentStateEntity value)? agentState,
    TResult Function(AgentMessageEntity value)? agentMessage,
    TResult Function(AgentMessagePayloadEntity value)? agentMessagePayload,
    TResult Function(AgentReportEntity value)? agentReport,
    TResult Function(AgentReportHeadEntity value)? agentReportHead,
    TResult Function(AgentUnknownEntity value)? unknown,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AgentIdentityEntity() when agent != null:
        return agent(_that);
      case AgentStateEntity() when agentState != null:
        return agentState(_that);
      case AgentMessageEntity() when agentMessage != null:
        return agentMessage(_that);
      case AgentMessagePayloadEntity() when agentMessagePayload != null:
        return agentMessagePayload(_that);
      case AgentReportEntity() when agentReport != null:
        return agentReport(_that);
      case AgentReportHeadEntity() when agentReportHead != null:
        return agentReportHead(_that);
      case AgentUnknownEntity() when unknown != null:
        return unknown(_that);
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
    required TResult Function(AgentIdentityEntity value) agent,
    required TResult Function(AgentStateEntity value) agentState,
    required TResult Function(AgentMessageEntity value) agentMessage,
    required TResult Function(AgentMessagePayloadEntity value)
        agentMessagePayload,
    required TResult Function(AgentReportEntity value) agentReport,
    required TResult Function(AgentReportHeadEntity value) agentReportHead,
    required TResult Function(AgentUnknownEntity value) unknown,
  }) {
    final _that = this;
    switch (_that) {
      case AgentIdentityEntity():
        return agent(_that);
      case AgentStateEntity():
        return agentState(_that);
      case AgentMessageEntity():
        return agentMessage(_that);
      case AgentMessagePayloadEntity():
        return agentMessagePayload(_that);
      case AgentReportEntity():
        return agentReport(_that);
      case AgentReportHeadEntity():
        return agentReportHead(_that);
      case AgentUnknownEntity():
        return unknown(_that);
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
    TResult? Function(AgentIdentityEntity value)? agent,
    TResult? Function(AgentStateEntity value)? agentState,
    TResult? Function(AgentMessageEntity value)? agentMessage,
    TResult? Function(AgentMessagePayloadEntity value)? agentMessagePayload,
    TResult? Function(AgentReportEntity value)? agentReport,
    TResult? Function(AgentReportHeadEntity value)? agentReportHead,
    TResult? Function(AgentUnknownEntity value)? unknown,
  }) {
    final _that = this;
    switch (_that) {
      case AgentIdentityEntity() when agent != null:
        return agent(_that);
      case AgentStateEntity() when agentState != null:
        return agentState(_that);
      case AgentMessageEntity() when agentMessage != null:
        return agentMessage(_that);
      case AgentMessagePayloadEntity() when agentMessagePayload != null:
        return agentMessagePayload(_that);
      case AgentReportEntity() when agentReport != null:
        return agentReport(_that);
      case AgentReportHeadEntity() when agentReportHead != null:
        return agentReportHead(_that);
      case AgentUnknownEntity() when unknown != null:
        return unknown(_that);
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
            String agentId,
            String kind,
            String displayName,
            AgentLifecycle lifecycle,
            AgentInteractionMode mode,
            Set<String> allowedCategoryIds,
            String currentStateId,
            AgentConfig config,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            DateTime? destroyedAt)?
        agent,
    TResult Function(
            String id,
            String agentId,
            int revision,
            AgentSlots slots,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? lastWakeAt,
            DateTime? nextWakeAt,
            DateTime? sleepUntil,
            String? recentHeadMessageId,
            String? latestSummaryMessageId,
            int consecutiveFailureCount,
            int wakeCounter,
            Map<String, int> processedCounterByHost,
            DateTime? deletedAt)?
        agentState,
    TResult Function(
            String id,
            String agentId,
            String threadId,
            AgentMessageKind kind,
            DateTime createdAt,
            VectorClock? vectorClock,
            AgentMessageMetadata metadata,
            String? prevMessageId,
            String? contentEntryId,
            String? triggerSourceId,
            String? summaryStartMessageId,
            String? summaryEndMessageId,
            int summaryDepth,
            int tokensApprox,
            DateTime? deletedAt)?
        agentMessage,
    TResult Function(
            String id,
            String agentId,
            DateTime createdAt,
            VectorClock? vectorClock,
            Map<String, Object?> content,
            String contentType,
            DateTime? deletedAt)?
        agentMessagePayload,
    TResult Function(
            String id,
            String agentId,
            String scope,
            DateTime createdAt,
            VectorClock? vectorClock,
            String content,
            double? confidence,
            Map<String, Object?> provenance,
            DateTime? deletedAt)?
        agentReport,
    TResult Function(String id, String agentId, String scope, String reportId,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        agentReportHead,
    TResult Function(String id, String agentId, DateTime createdAt,
            VectorClock? vectorClock, DateTime? deletedAt)?
        unknown,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case AgentIdentityEntity() when agent != null:
        return agent(
            _that.id,
            _that.agentId,
            _that.kind,
            _that.displayName,
            _that.lifecycle,
            _that.mode,
            _that.allowedCategoryIds,
            _that.currentStateId,
            _that.config,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt,
            _that.destroyedAt);
      case AgentStateEntity() when agentState != null:
        return agentState(
            _that.id,
            _that.agentId,
            _that.revision,
            _that.slots,
            _that.updatedAt,
            _that.vectorClock,
            _that.lastWakeAt,
            _that.nextWakeAt,
            _that.sleepUntil,
            _that.recentHeadMessageId,
            _that.latestSummaryMessageId,
            _that.consecutiveFailureCount,
            _that.wakeCounter,
            _that.processedCounterByHost,
            _that.deletedAt);
      case AgentMessageEntity() when agentMessage != null:
        return agentMessage(
            _that.id,
            _that.agentId,
            _that.threadId,
            _that.kind,
            _that.createdAt,
            _that.vectorClock,
            _that.metadata,
            _that.prevMessageId,
            _that.contentEntryId,
            _that.triggerSourceId,
            _that.summaryStartMessageId,
            _that.summaryEndMessageId,
            _that.summaryDepth,
            _that.tokensApprox,
            _that.deletedAt);
      case AgentMessagePayloadEntity() when agentMessagePayload != null:
        return agentMessagePayload(
            _that.id,
            _that.agentId,
            _that.createdAt,
            _that.vectorClock,
            _that.content,
            _that.contentType,
            _that.deletedAt);
      case AgentReportEntity() when agentReport != null:
        return agentReport(
            _that.id,
            _that.agentId,
            _that.scope,
            _that.createdAt,
            _that.vectorClock,
            _that.content,
            _that.confidence,
            _that.provenance,
            _that.deletedAt);
      case AgentReportHeadEntity() when agentReportHead != null:
        return agentReportHead(
            _that.id,
            _that.agentId,
            _that.scope,
            _that.reportId,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case AgentUnknownEntity() when unknown != null:
        return unknown(_that.id, _that.agentId, _that.createdAt,
            _that.vectorClock, _that.deletedAt);
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
            String agentId,
            String kind,
            String displayName,
            AgentLifecycle lifecycle,
            AgentInteractionMode mode,
            Set<String> allowedCategoryIds,
            String currentStateId,
            AgentConfig config,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            DateTime? destroyedAt)
        agent,
    required TResult Function(
            String id,
            String agentId,
            int revision,
            AgentSlots slots,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? lastWakeAt,
            DateTime? nextWakeAt,
            DateTime? sleepUntil,
            String? recentHeadMessageId,
            String? latestSummaryMessageId,
            int consecutiveFailureCount,
            int wakeCounter,
            Map<String, int> processedCounterByHost,
            DateTime? deletedAt)
        agentState,
    required TResult Function(
            String id,
            String agentId,
            String threadId,
            AgentMessageKind kind,
            DateTime createdAt,
            VectorClock? vectorClock,
            AgentMessageMetadata metadata,
            String? prevMessageId,
            String? contentEntryId,
            String? triggerSourceId,
            String? summaryStartMessageId,
            String? summaryEndMessageId,
            int summaryDepth,
            int tokensApprox,
            DateTime? deletedAt)
        agentMessage,
    required TResult Function(
            String id,
            String agentId,
            DateTime createdAt,
            VectorClock? vectorClock,
            Map<String, Object?> content,
            String contentType,
            DateTime? deletedAt)
        agentMessagePayload,
    required TResult Function(
            String id,
            String agentId,
            String scope,
            DateTime createdAt,
            VectorClock? vectorClock,
            String content,
            double? confidence,
            Map<String, Object?> provenance,
            DateTime? deletedAt)
        agentReport,
    required TResult Function(
            String id,
            String agentId,
            String scope,
            String reportId,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        agentReportHead,
    required TResult Function(String id, String agentId, DateTime createdAt,
            VectorClock? vectorClock, DateTime? deletedAt)
        unknown,
  }) {
    final _that = this;
    switch (_that) {
      case AgentIdentityEntity():
        return agent(
            _that.id,
            _that.agentId,
            _that.kind,
            _that.displayName,
            _that.lifecycle,
            _that.mode,
            _that.allowedCategoryIds,
            _that.currentStateId,
            _that.config,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt,
            _that.destroyedAt);
      case AgentStateEntity():
        return agentState(
            _that.id,
            _that.agentId,
            _that.revision,
            _that.slots,
            _that.updatedAt,
            _that.vectorClock,
            _that.lastWakeAt,
            _that.nextWakeAt,
            _that.sleepUntil,
            _that.recentHeadMessageId,
            _that.latestSummaryMessageId,
            _that.consecutiveFailureCount,
            _that.wakeCounter,
            _that.processedCounterByHost,
            _that.deletedAt);
      case AgentMessageEntity():
        return agentMessage(
            _that.id,
            _that.agentId,
            _that.threadId,
            _that.kind,
            _that.createdAt,
            _that.vectorClock,
            _that.metadata,
            _that.prevMessageId,
            _that.contentEntryId,
            _that.triggerSourceId,
            _that.summaryStartMessageId,
            _that.summaryEndMessageId,
            _that.summaryDepth,
            _that.tokensApprox,
            _that.deletedAt);
      case AgentMessagePayloadEntity():
        return agentMessagePayload(
            _that.id,
            _that.agentId,
            _that.createdAt,
            _that.vectorClock,
            _that.content,
            _that.contentType,
            _that.deletedAt);
      case AgentReportEntity():
        return agentReport(
            _that.id,
            _that.agentId,
            _that.scope,
            _that.createdAt,
            _that.vectorClock,
            _that.content,
            _that.confidence,
            _that.provenance,
            _that.deletedAt);
      case AgentReportHeadEntity():
        return agentReportHead(
            _that.id,
            _that.agentId,
            _that.scope,
            _that.reportId,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case AgentUnknownEntity():
        return unknown(_that.id, _that.agentId, _that.createdAt,
            _that.vectorClock, _that.deletedAt);
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
            String agentId,
            String kind,
            String displayName,
            AgentLifecycle lifecycle,
            AgentInteractionMode mode,
            Set<String> allowedCategoryIds,
            String currentStateId,
            AgentConfig config,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt,
            DateTime? destroyedAt)?
        agent,
    TResult? Function(
            String id,
            String agentId,
            int revision,
            AgentSlots slots,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? lastWakeAt,
            DateTime? nextWakeAt,
            DateTime? sleepUntil,
            String? recentHeadMessageId,
            String? latestSummaryMessageId,
            int consecutiveFailureCount,
            int wakeCounter,
            Map<String, int> processedCounterByHost,
            DateTime? deletedAt)?
        agentState,
    TResult? Function(
            String id,
            String agentId,
            String threadId,
            AgentMessageKind kind,
            DateTime createdAt,
            VectorClock? vectorClock,
            AgentMessageMetadata metadata,
            String? prevMessageId,
            String? contentEntryId,
            String? triggerSourceId,
            String? summaryStartMessageId,
            String? summaryEndMessageId,
            int summaryDepth,
            int tokensApprox,
            DateTime? deletedAt)?
        agentMessage,
    TResult? Function(
            String id,
            String agentId,
            DateTime createdAt,
            VectorClock? vectorClock,
            Map<String, Object?> content,
            String contentType,
            DateTime? deletedAt)?
        agentMessagePayload,
    TResult? Function(
            String id,
            String agentId,
            String scope,
            DateTime createdAt,
            VectorClock? vectorClock,
            String content,
            double? confidence,
            Map<String, Object?> provenance,
            DateTime? deletedAt)?
        agentReport,
    TResult? Function(String id, String agentId, String scope, String reportId,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        agentReportHead,
    TResult? Function(String id, String agentId, DateTime createdAt,
            VectorClock? vectorClock, DateTime? deletedAt)?
        unknown,
  }) {
    final _that = this;
    switch (_that) {
      case AgentIdentityEntity() when agent != null:
        return agent(
            _that.id,
            _that.agentId,
            _that.kind,
            _that.displayName,
            _that.lifecycle,
            _that.mode,
            _that.allowedCategoryIds,
            _that.currentStateId,
            _that.config,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt,
            _that.destroyedAt);
      case AgentStateEntity() when agentState != null:
        return agentState(
            _that.id,
            _that.agentId,
            _that.revision,
            _that.slots,
            _that.updatedAt,
            _that.vectorClock,
            _that.lastWakeAt,
            _that.nextWakeAt,
            _that.sleepUntil,
            _that.recentHeadMessageId,
            _that.latestSummaryMessageId,
            _that.consecutiveFailureCount,
            _that.wakeCounter,
            _that.processedCounterByHost,
            _that.deletedAt);
      case AgentMessageEntity() when agentMessage != null:
        return agentMessage(
            _that.id,
            _that.agentId,
            _that.threadId,
            _that.kind,
            _that.createdAt,
            _that.vectorClock,
            _that.metadata,
            _that.prevMessageId,
            _that.contentEntryId,
            _that.triggerSourceId,
            _that.summaryStartMessageId,
            _that.summaryEndMessageId,
            _that.summaryDepth,
            _that.tokensApprox,
            _that.deletedAt);
      case AgentMessagePayloadEntity() when agentMessagePayload != null:
        return agentMessagePayload(
            _that.id,
            _that.agentId,
            _that.createdAt,
            _that.vectorClock,
            _that.content,
            _that.contentType,
            _that.deletedAt);
      case AgentReportEntity() when agentReport != null:
        return agentReport(
            _that.id,
            _that.agentId,
            _that.scope,
            _that.createdAt,
            _that.vectorClock,
            _that.content,
            _that.confidence,
            _that.provenance,
            _that.deletedAt);
      case AgentReportHeadEntity() when agentReportHead != null:
        return agentReportHead(
            _that.id,
            _that.agentId,
            _that.scope,
            _that.reportId,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case AgentUnknownEntity() when unknown != null:
        return unknown(_that.id, _that.agentId, _that.createdAt,
            _that.vectorClock, _that.deletedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class AgentIdentityEntity implements AgentDomainEntity {
  const AgentIdentityEntity(
      {required this.id,
      required this.agentId,
      required this.kind,
      required this.displayName,
      required this.lifecycle,
      required this.mode,
      required final Set<String> allowedCategoryIds,
      required this.currentStateId,
      required this.config,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      this.destroyedAt,
      final String? $type})
      : _allowedCategoryIds = allowedCategoryIds,
        $type = $type ?? 'agent';
  factory AgentIdentityEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentIdentityEntityFromJson(json);

  @override
  final String id;
  @override
  final String agentId;
  final String kind;
  final String displayName;
  final AgentLifecycle lifecycle;
  final AgentInteractionMode mode;
  final Set<String> _allowedCategoryIds;
  Set<String> get allowedCategoryIds {
    if (_allowedCategoryIds is EqualUnmodifiableSetView)
      return _allowedCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_allowedCategoryIds);
  }

  final String currentStateId;
  final AgentConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;
  @override
  final VectorClock? vectorClock;
  @override
  final DateTime? deletedAt;
  final DateTime? destroyedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentIdentityEntityCopyWith<AgentIdentityEntity> get copyWith =>
      _$AgentIdentityEntityCopyWithImpl<AgentIdentityEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentIdentityEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentIdentityEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.lifecycle, lifecycle) ||
                other.lifecycle == lifecycle) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            const DeepCollectionEquality()
                .equals(other._allowedCategoryIds, _allowedCategoryIds) &&
            (identical(other.currentStateId, currentStateId) ||
                other.currentStateId == currentStateId) &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt) &&
            (identical(other.destroyedAt, destroyedAt) ||
                other.destroyedAt == destroyedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      agentId,
      kind,
      displayName,
      lifecycle,
      mode,
      const DeepCollectionEquality().hash(_allowedCategoryIds),
      currentStateId,
      config,
      createdAt,
      updatedAt,
      vectorClock,
      deletedAt,
      destroyedAt);

  @override
  String toString() {
    return 'AgentDomainEntity.agent(id: $id, agentId: $agentId, kind: $kind, displayName: $displayName, lifecycle: $lifecycle, mode: $mode, allowedCategoryIds: $allowedCategoryIds, currentStateId: $currentStateId, config: $config, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt, destroyedAt: $destroyedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentIdentityEntityCopyWith<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentIdentityEntityCopyWith(
          AgentIdentityEntity value, $Res Function(AgentIdentityEntity) _then) =
      _$AgentIdentityEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String agentId,
      String kind,
      String displayName,
      AgentLifecycle lifecycle,
      AgentInteractionMode mode,
      Set<String> allowedCategoryIds,
      String currentStateId,
      AgentConfig config,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt,
      DateTime? destroyedAt});

  $AgentConfigCopyWith<$Res> get config;
}

/// @nodoc
class _$AgentIdentityEntityCopyWithImpl<$Res>
    implements $AgentIdentityEntityCopyWith<$Res> {
  _$AgentIdentityEntityCopyWithImpl(this._self, this._then);

  final AgentIdentityEntity _self;
  final $Res Function(AgentIdentityEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? kind = null,
    Object? displayName = null,
    Object? lifecycle = null,
    Object? mode = null,
    Object? allowedCategoryIds = null,
    Object? currentStateId = null,
    Object? config = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
    Object? destroyedAt = freezed,
  }) {
    return _then(AgentIdentityEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _self.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      lifecycle: null == lifecycle
          ? _self.lifecycle
          : lifecycle // ignore: cast_nullable_to_non_nullable
              as AgentLifecycle,
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as AgentInteractionMode,
      allowedCategoryIds: null == allowedCategoryIds
          ? _self._allowedCategoryIds
          : allowedCategoryIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      currentStateId: null == currentStateId
          ? _self.currentStateId
          : currentStateId // ignore: cast_nullable_to_non_nullable
              as String,
      config: null == config
          ? _self.config
          : config // ignore: cast_nullable_to_non_nullable
              as AgentConfig,
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
      destroyedAt: freezed == destroyedAt
          ? _self.destroyedAt
          : destroyedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AgentConfigCopyWith<$Res> get config {
    return $AgentConfigCopyWith<$Res>(_self.config, (value) {
      return _then(_self.copyWith(config: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class AgentStateEntity implements AgentDomainEntity {
  const AgentStateEntity(
      {required this.id,
      required this.agentId,
      required this.revision,
      required this.slots,
      required this.updatedAt,
      required this.vectorClock,
      this.lastWakeAt,
      this.nextWakeAt,
      this.sleepUntil,
      this.recentHeadMessageId,
      this.latestSummaryMessageId,
      this.consecutiveFailureCount = 0,
      this.wakeCounter = 0,
      final Map<String, int> processedCounterByHost = const {},
      this.deletedAt,
      final String? $type})
      : _processedCounterByHost = processedCounterByHost,
        $type = $type ?? 'agentState';
  factory AgentStateEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentStateEntityFromJson(json);

  @override
  final String id;
  @override
  final String agentId;
  final int revision;
  final AgentSlots slots;
  final DateTime updatedAt;
  @override
  final VectorClock? vectorClock;
  final DateTime? lastWakeAt;
  final DateTime? nextWakeAt;
  final DateTime? sleepUntil;
  final String? recentHeadMessageId;
  final String? latestSummaryMessageId;
  @JsonKey()
  final int consecutiveFailureCount;
  @JsonKey()
  final int wakeCounter;
  final Map<String, int> _processedCounterByHost;
  @JsonKey()
  Map<String, int> get processedCounterByHost {
    if (_processedCounterByHost is EqualUnmodifiableMapView)
      return _processedCounterByHost;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_processedCounterByHost);
  }

  @override
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentStateEntityCopyWith<AgentStateEntity> get copyWith =>
      _$AgentStateEntityCopyWithImpl<AgentStateEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentStateEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentStateEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.revision, revision) ||
                other.revision == revision) &&
            (identical(other.slots, slots) || other.slots == slots) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.lastWakeAt, lastWakeAt) ||
                other.lastWakeAt == lastWakeAt) &&
            (identical(other.nextWakeAt, nextWakeAt) ||
                other.nextWakeAt == nextWakeAt) &&
            (identical(other.sleepUntil, sleepUntil) ||
                other.sleepUntil == sleepUntil) &&
            (identical(other.recentHeadMessageId, recentHeadMessageId) ||
                other.recentHeadMessageId == recentHeadMessageId) &&
            (identical(other.latestSummaryMessageId, latestSummaryMessageId) ||
                other.latestSummaryMessageId == latestSummaryMessageId) &&
            (identical(
                    other.consecutiveFailureCount, consecutiveFailureCount) ||
                other.consecutiveFailureCount == consecutiveFailureCount) &&
            (identical(other.wakeCounter, wakeCounter) ||
                other.wakeCounter == wakeCounter) &&
            const DeepCollectionEquality().equals(
                other._processedCounterByHost, _processedCounterByHost) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      agentId,
      revision,
      slots,
      updatedAt,
      vectorClock,
      lastWakeAt,
      nextWakeAt,
      sleepUntil,
      recentHeadMessageId,
      latestSummaryMessageId,
      consecutiveFailureCount,
      wakeCounter,
      const DeepCollectionEquality().hash(_processedCounterByHost),
      deletedAt);

  @override
  String toString() {
    return 'AgentDomainEntity.agentState(id: $id, agentId: $agentId, revision: $revision, slots: $slots, updatedAt: $updatedAt, vectorClock: $vectorClock, lastWakeAt: $lastWakeAt, nextWakeAt: $nextWakeAt, sleepUntil: $sleepUntil, recentHeadMessageId: $recentHeadMessageId, latestSummaryMessageId: $latestSummaryMessageId, consecutiveFailureCount: $consecutiveFailureCount, wakeCounter: $wakeCounter, processedCounterByHost: $processedCounterByHost, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentStateEntityCopyWith<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentStateEntityCopyWith(
          AgentStateEntity value, $Res Function(AgentStateEntity) _then) =
      _$AgentStateEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String agentId,
      int revision,
      AgentSlots slots,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? lastWakeAt,
      DateTime? nextWakeAt,
      DateTime? sleepUntil,
      String? recentHeadMessageId,
      String? latestSummaryMessageId,
      int consecutiveFailureCount,
      int wakeCounter,
      Map<String, int> processedCounterByHost,
      DateTime? deletedAt});

  $AgentSlotsCopyWith<$Res> get slots;
}

/// @nodoc
class _$AgentStateEntityCopyWithImpl<$Res>
    implements $AgentStateEntityCopyWith<$Res> {
  _$AgentStateEntityCopyWithImpl(this._self, this._then);

  final AgentStateEntity _self;
  final $Res Function(AgentStateEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? revision = null,
    Object? slots = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? lastWakeAt = freezed,
    Object? nextWakeAt = freezed,
    Object? sleepUntil = freezed,
    Object? recentHeadMessageId = freezed,
    Object? latestSummaryMessageId = freezed,
    Object? consecutiveFailureCount = null,
    Object? wakeCounter = null,
    Object? processedCounterByHost = null,
    Object? deletedAt = freezed,
  }) {
    return _then(AgentStateEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      revision: null == revision
          ? _self.revision
          : revision // ignore: cast_nullable_to_non_nullable
              as int,
      slots: null == slots
          ? _self.slots
          : slots // ignore: cast_nullable_to_non_nullable
              as AgentSlots,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      lastWakeAt: freezed == lastWakeAt
          ? _self.lastWakeAt
          : lastWakeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      nextWakeAt: freezed == nextWakeAt
          ? _self.nextWakeAt
          : nextWakeAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sleepUntil: freezed == sleepUntil
          ? _self.sleepUntil
          : sleepUntil // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      recentHeadMessageId: freezed == recentHeadMessageId
          ? _self.recentHeadMessageId
          : recentHeadMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      latestSummaryMessageId: freezed == latestSummaryMessageId
          ? _self.latestSummaryMessageId
          : latestSummaryMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      consecutiveFailureCount: null == consecutiveFailureCount
          ? _self.consecutiveFailureCount
          : consecutiveFailureCount // ignore: cast_nullable_to_non_nullable
              as int,
      wakeCounter: null == wakeCounter
          ? _self.wakeCounter
          : wakeCounter // ignore: cast_nullable_to_non_nullable
              as int,
      processedCounterByHost: null == processedCounterByHost
          ? _self._processedCounterByHost
          : processedCounterByHost // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AgentSlotsCopyWith<$Res> get slots {
    return $AgentSlotsCopyWith<$Res>(_self.slots, (value) {
      return _then(_self.copyWith(slots: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class AgentMessageEntity implements AgentDomainEntity {
  const AgentMessageEntity(
      {required this.id,
      required this.agentId,
      required this.threadId,
      required this.kind,
      required this.createdAt,
      required this.vectorClock,
      required this.metadata,
      this.prevMessageId,
      this.contentEntryId,
      this.triggerSourceId,
      this.summaryStartMessageId,
      this.summaryEndMessageId,
      this.summaryDepth = 0,
      this.tokensApprox = 0,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'agentMessage';
  factory AgentMessageEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentMessageEntityFromJson(json);

  @override
  final String id;
  @override
  final String agentId;
  final String threadId;
  final AgentMessageKind kind;
  final DateTime createdAt;
  @override
  final VectorClock? vectorClock;
  final AgentMessageMetadata metadata;
  final String? prevMessageId;
  final String? contentEntryId;
  final String? triggerSourceId;
  final String? summaryStartMessageId;
  final String? summaryEndMessageId;
  @JsonKey()
  final int summaryDepth;
  @JsonKey()
  final int tokensApprox;
  @override
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentMessageEntityCopyWith<AgentMessageEntity> get copyWith =>
      _$AgentMessageEntityCopyWithImpl<AgentMessageEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentMessageEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentMessageEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.threadId, threadId) ||
                other.threadId == threadId) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.prevMessageId, prevMessageId) ||
                other.prevMessageId == prevMessageId) &&
            (identical(other.contentEntryId, contentEntryId) ||
                other.contentEntryId == contentEntryId) &&
            (identical(other.triggerSourceId, triggerSourceId) ||
                other.triggerSourceId == triggerSourceId) &&
            (identical(other.summaryStartMessageId, summaryStartMessageId) ||
                other.summaryStartMessageId == summaryStartMessageId) &&
            (identical(other.summaryEndMessageId, summaryEndMessageId) ||
                other.summaryEndMessageId == summaryEndMessageId) &&
            (identical(other.summaryDepth, summaryDepth) ||
                other.summaryDepth == summaryDepth) &&
            (identical(other.tokensApprox, tokensApprox) ||
                other.tokensApprox == tokensApprox) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      agentId,
      threadId,
      kind,
      createdAt,
      vectorClock,
      metadata,
      prevMessageId,
      contentEntryId,
      triggerSourceId,
      summaryStartMessageId,
      summaryEndMessageId,
      summaryDepth,
      tokensApprox,
      deletedAt);

  @override
  String toString() {
    return 'AgentDomainEntity.agentMessage(id: $id, agentId: $agentId, threadId: $threadId, kind: $kind, createdAt: $createdAt, vectorClock: $vectorClock, metadata: $metadata, prevMessageId: $prevMessageId, contentEntryId: $contentEntryId, triggerSourceId: $triggerSourceId, summaryStartMessageId: $summaryStartMessageId, summaryEndMessageId: $summaryEndMessageId, summaryDepth: $summaryDepth, tokensApprox: $tokensApprox, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentMessageEntityCopyWith<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentMessageEntityCopyWith(
          AgentMessageEntity value, $Res Function(AgentMessageEntity) _then) =
      _$AgentMessageEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String agentId,
      String threadId,
      AgentMessageKind kind,
      DateTime createdAt,
      VectorClock? vectorClock,
      AgentMessageMetadata metadata,
      String? prevMessageId,
      String? contentEntryId,
      String? triggerSourceId,
      String? summaryStartMessageId,
      String? summaryEndMessageId,
      int summaryDepth,
      int tokensApprox,
      DateTime? deletedAt});

  $AgentMessageMetadataCopyWith<$Res> get metadata;
}

/// @nodoc
class _$AgentMessageEntityCopyWithImpl<$Res>
    implements $AgentMessageEntityCopyWith<$Res> {
  _$AgentMessageEntityCopyWithImpl(this._self, this._then);

  final AgentMessageEntity _self;
  final $Res Function(AgentMessageEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? threadId = null,
    Object? kind = null,
    Object? createdAt = null,
    Object? vectorClock = freezed,
    Object? metadata = null,
    Object? prevMessageId = freezed,
    Object? contentEntryId = freezed,
    Object? triggerSourceId = freezed,
    Object? summaryStartMessageId = freezed,
    Object? summaryEndMessageId = freezed,
    Object? summaryDepth = null,
    Object? tokensApprox = null,
    Object? deletedAt = freezed,
  }) {
    return _then(AgentMessageEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      threadId: null == threadId
          ? _self.threadId
          : threadId // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _self.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as AgentMessageKind,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      metadata: null == metadata
          ? _self.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as AgentMessageMetadata,
      prevMessageId: freezed == prevMessageId
          ? _self.prevMessageId
          : prevMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      contentEntryId: freezed == contentEntryId
          ? _self.contentEntryId
          : contentEntryId // ignore: cast_nullable_to_non_nullable
              as String?,
      triggerSourceId: freezed == triggerSourceId
          ? _self.triggerSourceId
          : triggerSourceId // ignore: cast_nullable_to_non_nullable
              as String?,
      summaryStartMessageId: freezed == summaryStartMessageId
          ? _self.summaryStartMessageId
          : summaryStartMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      summaryEndMessageId: freezed == summaryEndMessageId
          ? _self.summaryEndMessageId
          : summaryEndMessageId // ignore: cast_nullable_to_non_nullable
              as String?,
      summaryDepth: null == summaryDepth
          ? _self.summaryDepth
          : summaryDepth // ignore: cast_nullable_to_non_nullable
              as int,
      tokensApprox: null == tokensApprox
          ? _self.tokensApprox
          : tokensApprox // ignore: cast_nullable_to_non_nullable
              as int,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AgentMessageMetadataCopyWith<$Res> get metadata {
    return $AgentMessageMetadataCopyWith<$Res>(_self.metadata, (value) {
      return _then(_self.copyWith(metadata: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class AgentMessagePayloadEntity implements AgentDomainEntity {
  const AgentMessagePayloadEntity(
      {required this.id,
      required this.agentId,
      required this.createdAt,
      required this.vectorClock,
      required final Map<String, Object?> content,
      this.contentType = 'application/json',
      this.deletedAt,
      final String? $type})
      : _content = content,
        $type = $type ?? 'agentMessagePayload';
  factory AgentMessagePayloadEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentMessagePayloadEntityFromJson(json);

  @override
  final String id;
  @override
  final String agentId;
  final DateTime createdAt;
  @override
  final VectorClock? vectorClock;
  final Map<String, Object?> _content;
  Map<String, Object?> get content {
    if (_content is EqualUnmodifiableMapView) return _content;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_content);
  }

  @JsonKey()
  final String contentType;
  @override
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentMessagePayloadEntityCopyWith<AgentMessagePayloadEntity> get copyWith =>
      _$AgentMessagePayloadEntityCopyWithImpl<AgentMessagePayloadEntity>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentMessagePayloadEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentMessagePayloadEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            const DeepCollectionEquality().equals(other._content, _content) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      agentId,
      createdAt,
      vectorClock,
      const DeepCollectionEquality().hash(_content),
      contentType,
      deletedAt);

  @override
  String toString() {
    return 'AgentDomainEntity.agentMessagePayload(id: $id, agentId: $agentId, createdAt: $createdAt, vectorClock: $vectorClock, content: $content, contentType: $contentType, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentMessagePayloadEntityCopyWith<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentMessagePayloadEntityCopyWith(AgentMessagePayloadEntity value,
          $Res Function(AgentMessagePayloadEntity) _then) =
      _$AgentMessagePayloadEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String agentId,
      DateTime createdAt,
      VectorClock? vectorClock,
      Map<String, Object?> content,
      String contentType,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentMessagePayloadEntityCopyWithImpl<$Res>
    implements $AgentMessagePayloadEntityCopyWith<$Res> {
  _$AgentMessagePayloadEntityCopyWithImpl(this._self, this._then);

  final AgentMessagePayloadEntity _self;
  final $Res Function(AgentMessagePayloadEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? createdAt = null,
    Object? vectorClock = freezed,
    Object? content = null,
    Object? contentType = null,
    Object? deletedAt = freezed,
  }) {
    return _then(AgentMessagePayloadEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      content: null == content
          ? _self._content
          : content // ignore: cast_nullable_to_non_nullable
              as Map<String, Object?>,
      contentType: null == contentType
          ? _self.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AgentReportEntity implements AgentDomainEntity {
  const AgentReportEntity(
      {required this.id,
      required this.agentId,
      required this.scope,
      required this.createdAt,
      required this.vectorClock,
      this.content = '',
      this.confidence,
      final Map<String, Object?> provenance = const {},
      this.deletedAt,
      final String? $type})
      : _provenance = provenance,
        $type = $type ?? 'agentReport';
  factory AgentReportEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentReportEntityFromJson(json);

  @override
  final String id;
  @override
  final String agentId;
  final String scope;
  final DateTime createdAt;
  @override
  final VectorClock? vectorClock;
  @JsonKey()
  final String content;
  final double? confidence;
  final Map<String, Object?> _provenance;
  @JsonKey()
  Map<String, Object?> get provenance {
    if (_provenance is EqualUnmodifiableMapView) return _provenance;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_provenance);
  }

  @override
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentReportEntityCopyWith<AgentReportEntity> get copyWith =>
      _$AgentReportEntityCopyWithImpl<AgentReportEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentReportEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentReportEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.scope, scope) || other.scope == scope) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            const DeepCollectionEquality()
                .equals(other._provenance, _provenance) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      agentId,
      scope,
      createdAt,
      vectorClock,
      content,
      confidence,
      const DeepCollectionEquality().hash(_provenance),
      deletedAt);

  @override
  String toString() {
    return 'AgentDomainEntity.agentReport(id: $id, agentId: $agentId, scope: $scope, createdAt: $createdAt, vectorClock: $vectorClock, content: $content, confidence: $confidence, provenance: $provenance, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentReportEntityCopyWith<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentReportEntityCopyWith(
          AgentReportEntity value, $Res Function(AgentReportEntity) _then) =
      _$AgentReportEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String agentId,
      String scope,
      DateTime createdAt,
      VectorClock? vectorClock,
      String content,
      double? confidence,
      Map<String, Object?> provenance,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentReportEntityCopyWithImpl<$Res>
    implements $AgentReportEntityCopyWith<$Res> {
  _$AgentReportEntityCopyWithImpl(this._self, this._then);

  final AgentReportEntity _self;
  final $Res Function(AgentReportEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? scope = null,
    Object? createdAt = null,
    Object? vectorClock = freezed,
    Object? content = null,
    Object? confidence = freezed,
    Object? provenance = null,
    Object? deletedAt = freezed,
  }) {
    return _then(AgentReportEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      scope: null == scope
          ? _self.scope
          : scope // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      content: null == content
          ? _self.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      confidence: freezed == confidence
          ? _self.confidence
          : confidence // ignore: cast_nullable_to_non_nullable
              as double?,
      provenance: null == provenance
          ? _self._provenance
          : provenance // ignore: cast_nullable_to_non_nullable
              as Map<String, Object?>,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AgentReportHeadEntity implements AgentDomainEntity {
  const AgentReportHeadEntity(
      {required this.id,
      required this.agentId,
      required this.scope,
      required this.reportId,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'agentReportHead';
  factory AgentReportHeadEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentReportHeadEntityFromJson(json);

  @override
  final String id;
  @override
  final String agentId;
  final String scope;
  final String reportId;
  final DateTime updatedAt;
  @override
  final VectorClock? vectorClock;
  @override
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentReportHeadEntityCopyWith<AgentReportHeadEntity> get copyWith =>
      _$AgentReportHeadEntityCopyWithImpl<AgentReportHeadEntity>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentReportHeadEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentReportHeadEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.scope, scope) || other.scope == scope) &&
            (identical(other.reportId, reportId) ||
                other.reportId == reportId) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, agentId, scope, reportId,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentDomainEntity.agentReportHead(id: $id, agentId: $agentId, scope: $scope, reportId: $reportId, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentReportHeadEntityCopyWith<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentReportHeadEntityCopyWith(AgentReportHeadEntity value,
          $Res Function(AgentReportHeadEntity) _then) =
      _$AgentReportHeadEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String agentId,
      String scope,
      String reportId,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentReportHeadEntityCopyWithImpl<$Res>
    implements $AgentReportHeadEntityCopyWith<$Res> {
  _$AgentReportHeadEntityCopyWithImpl(this._self, this._then);

  final AgentReportHeadEntity _self;
  final $Res Function(AgentReportHeadEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? scope = null,
    Object? reportId = null,
    Object? updatedAt = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(AgentReportHeadEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      scope: null == scope
          ? _self.scope
          : scope // ignore: cast_nullable_to_non_nullable
              as String,
      reportId: null == reportId
          ? _self.reportId
          : reportId // ignore: cast_nullable_to_non_nullable
              as String,
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
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AgentUnknownEntity implements AgentDomainEntity {
  const AgentUnknownEntity(
      {required this.id,
      required this.agentId,
      required this.createdAt,
      this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'unknown';
  factory AgentUnknownEntity.fromJson(Map<String, dynamic> json) =>
      _$AgentUnknownEntityFromJson(json);

  @override
  final String id;
  @override
  final String agentId;
  final DateTime createdAt;
  @override
  final VectorClock? vectorClock;
  @override
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentUnknownEntityCopyWith<AgentUnknownEntity> get copyWith =>
      _$AgentUnknownEntityCopyWithImpl<AgentUnknownEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentUnknownEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentUnknownEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.agentId, agentId) || other.agentId == agentId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, agentId, createdAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentDomainEntity.unknown(id: $id, agentId: $agentId, createdAt: $createdAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentUnknownEntityCopyWith<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentUnknownEntityCopyWith(
          AgentUnknownEntity value, $Res Function(AgentUnknownEntity) _then) =
      _$AgentUnknownEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String agentId,
      DateTime createdAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentUnknownEntityCopyWithImpl<$Res>
    implements $AgentUnknownEntityCopyWith<$Res> {
  _$AgentUnknownEntityCopyWithImpl(this._self, this._then);

  final AgentUnknownEntity _self;
  final $Res Function(AgentUnknownEntity) _then;

  /// Create a copy of AgentDomainEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? agentId = null,
    Object? createdAt = null,
    Object? vectorClock = freezed,
    Object? deletedAt = freezed,
  }) {
    return _then(AgentUnknownEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      agentId: null == agentId
          ? _self.agentId
          : agentId // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vectorClock: freezed == vectorClock
          ? _self.vectorClock
          : vectorClock // ignore: cast_nullable_to_non_nullable
              as VectorClock?,
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
