// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
AgentLink _$AgentLinkFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'agentState':
      return AgentStateLink.fromJson(json);
    case 'messagePrev':
      return MessagePrevLink.fromJson(json);
    case 'messagePayload':
      return MessagePayloadLink.fromJson(json);
    case 'toolEffect':
      return ToolEffectLink.fromJson(json);
    case 'agentTask':
      return AgentTaskLink.fromJson(json);
    case 'templateAssignment':
      return TemplateAssignmentLink.fromJson(json);
    case 'improverTarget':
      return ImproverTargetLink.fromJson(json);

    default:
      return BasicAgentLink.fromJson(json);
  }
}

/// @nodoc
mixin _$AgentLink {
  String get id;
  String get fromId;
  String get toId;
  DateTime get createdAt;
  DateTime get updatedAt;
  VectorClock? get vectorClock;
  DateTime? get deletedAt;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentLinkCopyWith<AgentLink> get copyWith =>
      _$AgentLinkCopyWithImpl<AgentLink>(this as AgentLink, _$identity);

  /// Serializes this AgentLink to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentLinkCopyWith<$Res> {
  factory $AgentLinkCopyWith(AgentLink value, $Res Function(AgentLink) _then) =
      _$AgentLinkCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentLinkCopyWithImpl<$Res> implements $AgentLinkCopyWith<$Res> {
  _$AgentLinkCopyWithImpl(this._self, this._then);

  final AgentLink _self;
  final $Res Function(AgentLink) _then;

  /// Create a copy of AgentLink
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AgentLink].
extension AgentLinkPatterns on AgentLink {
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
    TResult Function(BasicAgentLink value)? basic,
    TResult Function(AgentStateLink value)? agentState,
    TResult Function(MessagePrevLink value)? messagePrev,
    TResult Function(MessagePayloadLink value)? messagePayload,
    TResult Function(ToolEffectLink value)? toolEffect,
    TResult Function(AgentTaskLink value)? agentTask,
    TResult Function(TemplateAssignmentLink value)? templateAssignment,
    TResult Function(ImproverTargetLink value)? improverTarget,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BasicAgentLink() when basic != null:
        return basic(_that);
      case AgentStateLink() when agentState != null:
        return agentState(_that);
      case MessagePrevLink() when messagePrev != null:
        return messagePrev(_that);
      case MessagePayloadLink() when messagePayload != null:
        return messagePayload(_that);
      case ToolEffectLink() when toolEffect != null:
        return toolEffect(_that);
      case AgentTaskLink() when agentTask != null:
        return agentTask(_that);
      case TemplateAssignmentLink() when templateAssignment != null:
        return templateAssignment(_that);
      case ImproverTargetLink() when improverTarget != null:
        return improverTarget(_that);
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
    required TResult Function(BasicAgentLink value) basic,
    required TResult Function(AgentStateLink value) agentState,
    required TResult Function(MessagePrevLink value) messagePrev,
    required TResult Function(MessagePayloadLink value) messagePayload,
    required TResult Function(ToolEffectLink value) toolEffect,
    required TResult Function(AgentTaskLink value) agentTask,
    required TResult Function(TemplateAssignmentLink value) templateAssignment,
    required TResult Function(ImproverTargetLink value) improverTarget,
  }) {
    final _that = this;
    switch (_that) {
      case BasicAgentLink():
        return basic(_that);
      case AgentStateLink():
        return agentState(_that);
      case MessagePrevLink():
        return messagePrev(_that);
      case MessagePayloadLink():
        return messagePayload(_that);
      case ToolEffectLink():
        return toolEffect(_that);
      case AgentTaskLink():
        return agentTask(_that);
      case TemplateAssignmentLink():
        return templateAssignment(_that);
      case ImproverTargetLink():
        return improverTarget(_that);
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
    TResult? Function(BasicAgentLink value)? basic,
    TResult? Function(AgentStateLink value)? agentState,
    TResult? Function(MessagePrevLink value)? messagePrev,
    TResult? Function(MessagePayloadLink value)? messagePayload,
    TResult? Function(ToolEffectLink value)? toolEffect,
    TResult? Function(AgentTaskLink value)? agentTask,
    TResult? Function(TemplateAssignmentLink value)? templateAssignment,
    TResult? Function(ImproverTargetLink value)? improverTarget,
  }) {
    final _that = this;
    switch (_that) {
      case BasicAgentLink() when basic != null:
        return basic(_that);
      case AgentStateLink() when agentState != null:
        return agentState(_that);
      case MessagePrevLink() when messagePrev != null:
        return messagePrev(_that);
      case MessagePayloadLink() when messagePayload != null:
        return messagePayload(_that);
      case ToolEffectLink() when toolEffect != null:
        return toolEffect(_that);
      case AgentTaskLink() when agentTask != null:
        return agentTask(_that);
      case TemplateAssignmentLink() when templateAssignment != null:
        return templateAssignment(_that);
      case ImproverTargetLink() when improverTarget != null:
        return improverTarget(_that);
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
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        basic,
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        agentState,
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        messagePrev,
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        messagePayload,
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        toolEffect,
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        agentTask,
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        templateAssignment,
    TResult Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        improverTarget,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BasicAgentLink() when basic != null:
        return basic(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case AgentStateLink() when agentState != null:
        return agentState(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case MessagePrevLink() when messagePrev != null:
        return messagePrev(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case MessagePayloadLink() when messagePayload != null:
        return messagePayload(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case ToolEffectLink() when toolEffect != null:
        return toolEffect(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case AgentTaskLink() when agentTask != null:
        return agentTask(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case TemplateAssignmentLink() when templateAssignment != null:
        return templateAssignment(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case ImproverTargetLink() when improverTarget != null:
        return improverTarget(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
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
            DateTime? deletedAt)
        basic,
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        agentState,
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        messagePrev,
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        messagePayload,
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        toolEffect,
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        agentTask,
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        templateAssignment,
    required TResult Function(
            String id,
            String fromId,
            String toId,
            DateTime createdAt,
            DateTime updatedAt,
            VectorClock? vectorClock,
            DateTime? deletedAt)
        improverTarget,
  }) {
    final _that = this;
    switch (_that) {
      case BasicAgentLink():
        return basic(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case AgentStateLink():
        return agentState(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case MessagePrevLink():
        return messagePrev(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case MessagePayloadLink():
        return messagePayload(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case ToolEffectLink():
        return toolEffect(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case AgentTaskLink():
        return agentTask(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case TemplateAssignmentLink():
        return templateAssignment(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case ImproverTargetLink():
        return improverTarget(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
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
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        basic,
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        agentState,
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        messagePrev,
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        messagePayload,
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        toolEffect,
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        agentTask,
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        templateAssignment,
    TResult? Function(String id, String fromId, String toId, DateTime createdAt,
            DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt)?
        improverTarget,
  }) {
    final _that = this;
    switch (_that) {
      case BasicAgentLink() when basic != null:
        return basic(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case AgentStateLink() when agentState != null:
        return agentState(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case MessagePrevLink() when messagePrev != null:
        return messagePrev(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case MessagePayloadLink() when messagePayload != null:
        return messagePayload(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case ToolEffectLink() when toolEffect != null:
        return toolEffect(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case AgentTaskLink() when agentTask != null:
        return agentTask(_that.id, _that.fromId, _that.toId, _that.createdAt,
            _that.updatedAt, _that.vectorClock, _that.deletedAt);
      case TemplateAssignmentLink() when templateAssignment != null:
        return templateAssignment(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case ImproverTargetLink() when improverTarget != null:
        return improverTarget(
            _that.id,
            _that.fromId,
            _that.toId,
            _that.createdAt,
            _that.updatedAt,
            _that.vectorClock,
            _that.deletedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class BasicAgentLink implements AgentLink {
  const BasicAgentLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'basic';
  factory BasicAgentLink.fromJson(Map<String, dynamic> json) =>
      _$BasicAgentLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BasicAgentLinkCopyWith<BasicAgentLink> get copyWith =>
      _$BasicAgentLinkCopyWithImpl<BasicAgentLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BasicAgentLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BasicAgentLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.basic(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $BasicAgentLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $BasicAgentLinkCopyWith(
          BasicAgentLink value, $Res Function(BasicAgentLink) _then) =
      _$BasicAgentLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$BasicAgentLinkCopyWithImpl<$Res>
    implements $BasicAgentLinkCopyWith<$Res> {
  _$BasicAgentLinkCopyWithImpl(this._self, this._then);

  final BasicAgentLink _self;
  final $Res Function(BasicAgentLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(BasicAgentLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AgentStateLink implements AgentLink {
  const AgentStateLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'agentState';
  factory AgentStateLink.fromJson(Map<String, dynamic> json) =>
      _$AgentStateLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentStateLinkCopyWith<AgentStateLink> get copyWith =>
      _$AgentStateLinkCopyWithImpl<AgentStateLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentStateLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentStateLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.agentState(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentStateLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $AgentStateLinkCopyWith(
          AgentStateLink value, $Res Function(AgentStateLink) _then) =
      _$AgentStateLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentStateLinkCopyWithImpl<$Res>
    implements $AgentStateLinkCopyWith<$Res> {
  _$AgentStateLinkCopyWithImpl(this._self, this._then);

  final AgentStateLink _self;
  final $Res Function(AgentStateLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(AgentStateLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class MessagePrevLink implements AgentLink {
  const MessagePrevLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'messagePrev';
  factory MessagePrevLink.fromJson(Map<String, dynamic> json) =>
      _$MessagePrevLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessagePrevLinkCopyWith<MessagePrevLink> get copyWith =>
      _$MessagePrevLinkCopyWithImpl<MessagePrevLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MessagePrevLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessagePrevLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.messagePrev(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $MessagePrevLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $MessagePrevLinkCopyWith(
          MessagePrevLink value, $Res Function(MessagePrevLink) _then) =
      _$MessagePrevLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$MessagePrevLinkCopyWithImpl<$Res>
    implements $MessagePrevLinkCopyWith<$Res> {
  _$MessagePrevLinkCopyWithImpl(this._self, this._then);

  final MessagePrevLink _self;
  final $Res Function(MessagePrevLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(MessagePrevLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class MessagePayloadLink implements AgentLink {
  const MessagePayloadLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'messagePayload';
  factory MessagePayloadLink.fromJson(Map<String, dynamic> json) =>
      _$MessagePayloadLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MessagePayloadLinkCopyWith<MessagePayloadLink> get copyWith =>
      _$MessagePayloadLinkCopyWithImpl<MessagePayloadLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MessagePayloadLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MessagePayloadLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.messagePayload(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $MessagePayloadLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $MessagePayloadLinkCopyWith(
          MessagePayloadLink value, $Res Function(MessagePayloadLink) _then) =
      _$MessagePayloadLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$MessagePayloadLinkCopyWithImpl<$Res>
    implements $MessagePayloadLinkCopyWith<$Res> {
  _$MessagePayloadLinkCopyWithImpl(this._self, this._then);

  final MessagePayloadLink _self;
  final $Res Function(MessagePayloadLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(MessagePayloadLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class ToolEffectLink implements AgentLink {
  const ToolEffectLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'toolEffect';
  factory ToolEffectLink.fromJson(Map<String, dynamic> json) =>
      _$ToolEffectLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ToolEffectLinkCopyWith<ToolEffectLink> get copyWith =>
      _$ToolEffectLinkCopyWithImpl<ToolEffectLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ToolEffectLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ToolEffectLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.toolEffect(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $ToolEffectLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $ToolEffectLinkCopyWith(
          ToolEffectLink value, $Res Function(ToolEffectLink) _then) =
      _$ToolEffectLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$ToolEffectLinkCopyWithImpl<$Res>
    implements $ToolEffectLinkCopyWith<$Res> {
  _$ToolEffectLinkCopyWithImpl(this._self, this._then);

  final ToolEffectLink _self;
  final $Res Function(ToolEffectLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(ToolEffectLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class AgentTaskLink implements AgentLink {
  const AgentTaskLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'agentTask';
  factory AgentTaskLink.fromJson(Map<String, dynamic> json) =>
      _$AgentTaskLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AgentTaskLinkCopyWith<AgentTaskLink> get copyWith =>
      _$AgentTaskLinkCopyWithImpl<AgentTaskLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AgentTaskLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AgentTaskLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.agentTask(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $AgentTaskLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $AgentTaskLinkCopyWith(
          AgentTaskLink value, $Res Function(AgentTaskLink) _then) =
      _$AgentTaskLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$AgentTaskLinkCopyWithImpl<$Res>
    implements $AgentTaskLinkCopyWith<$Res> {
  _$AgentTaskLinkCopyWithImpl(this._self, this._then);

  final AgentTaskLink _self;
  final $Res Function(AgentTaskLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(AgentTaskLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class TemplateAssignmentLink implements AgentLink {
  const TemplateAssignmentLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'templateAssignment';
  factory TemplateAssignmentLink.fromJson(Map<String, dynamic> json) =>
      _$TemplateAssignmentLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TemplateAssignmentLinkCopyWith<TemplateAssignmentLink> get copyWith =>
      _$TemplateAssignmentLinkCopyWithImpl<TemplateAssignmentLink>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TemplateAssignmentLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TemplateAssignmentLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.templateAssignment(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $TemplateAssignmentLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $TemplateAssignmentLinkCopyWith(TemplateAssignmentLink value,
          $Res Function(TemplateAssignmentLink) _then) =
      _$TemplateAssignmentLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$TemplateAssignmentLinkCopyWithImpl<$Res>
    implements $TemplateAssignmentLinkCopyWith<$Res> {
  _$TemplateAssignmentLinkCopyWithImpl(this._self, this._then);

  final TemplateAssignmentLink _self;
  final $Res Function(TemplateAssignmentLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(TemplateAssignmentLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class ImproverTargetLink implements AgentLink {
  const ImproverTargetLink(
      {required this.id,
      required this.fromId,
      required this.toId,
      required this.createdAt,
      required this.updatedAt,
      required this.vectorClock,
      this.deletedAt,
      final String? $type})
      : $type = $type ?? 'improverTarget';
  factory ImproverTargetLink.fromJson(Map<String, dynamic> json) =>
      _$ImproverTargetLinkFromJson(json);

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
  final DateTime? deletedAt;

  @JsonKey(name: 'runtimeType')
  final String $type;

  /// Create a copy of AgentLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ImproverTargetLinkCopyWith<ImproverTargetLink> get copyWith =>
      _$ImproverTargetLinkCopyWithImpl<ImproverTargetLink>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ImproverTargetLinkToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ImproverTargetLink &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromId, fromId) || other.fromId == fromId) &&
            (identical(other.toId, toId) || other.toId == toId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.vectorClock, vectorClock) ||
                other.vectorClock == vectorClock) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, fromId, toId, createdAt,
      updatedAt, vectorClock, deletedAt);

  @override
  String toString() {
    return 'AgentLink.improverTarget(id: $id, fromId: $fromId, toId: $toId, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
  }
}

/// @nodoc
abstract mixin class $ImproverTargetLinkCopyWith<$Res>
    implements $AgentLinkCopyWith<$Res> {
  factory $ImproverTargetLinkCopyWith(
          ImproverTargetLink value, $Res Function(ImproverTargetLink) _then) =
      _$ImproverTargetLinkCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String fromId,
      String toId,
      DateTime createdAt,
      DateTime updatedAt,
      VectorClock? vectorClock,
      DateTime? deletedAt});
}

/// @nodoc
class _$ImproverTargetLinkCopyWithImpl<$Res>
    implements $ImproverTargetLinkCopyWith<$Res> {
  _$ImproverTargetLinkCopyWithImpl(this._self, this._then);

  final ImproverTargetLink _self;
  final $Res Function(ImproverTargetLink) _then;

  /// Create a copy of AgentLink
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
    Object? deletedAt = freezed,
  }) {
    return _then(ImproverTargetLink(
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
      deletedAt: freezed == deletedAt
          ? _self.deletedAt
          : deletedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

// dart format on
