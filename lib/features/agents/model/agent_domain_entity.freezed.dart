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
AgentDomainEntity _$AgentDomainEntityFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'agent':
          return AgentIdentityEntity.fromJson(
            json
          );
                case 'agentState':
          return AgentStateEntity.fromJson(
            json
          );
                case 'agentMessage':
          return AgentMessageEntity.fromJson(
            json
          );
                case 'agentMessagePayload':
          return AgentMessagePayloadEntity.fromJson(
            json
          );
                case 'agentReport':
          return AgentReportEntity.fromJson(
            json
          );
                case 'agentReportHead':
          return AgentReportHeadEntity.fromJson(
            json
          );
                case 'scheduledWake':
          return ScheduledWakeEntity.fromJson(
            json
          );
                case 'capture':
          return CaptureEntity.fromJson(
            json
          );
                case 'parsedItem':
          return ParsedItemEntity.fromJson(
            json
          );
                case 'dayPlan':
          return DayPlanEntity.fromJson(
            json
          );
                case 'attentionRequest':
          return AttentionRequestEntity.fromJson(
            json
          );
                case 'attentionClaimDisposition':
          return AttentionClaimDispositionEntity.fromJson(
            json
          );
                case 'attentionAward':
          return AttentionAwardEntity.fromJson(
            json
          );
                case 'standingAgreement':
          return StandingAgreementEntity.fromJson(
            json
          );
                case 'agentTemplate':
          return AgentTemplateEntity.fromJson(
            json
          );
                case 'agentTemplateVersion':
          return AgentTemplateVersionEntity.fromJson(
            json
          );
                case 'agentTemplateHead':
          return AgentTemplateHeadEntity.fromJson(
            json
          );
                case 'evolutionSession':
          return EvolutionSessionEntity.fromJson(
            json
          );
                case 'evolutionSessionRecap':
          return EvolutionSessionRecapEntity.fromJson(
            json
          );
                case 'evolutionNote':
          return EvolutionNoteEntity.fromJson(
            json
          );
                case 'changeSet':
          return ChangeSetEntity.fromJson(
            json
          );
                case 'changeDecision':
          return ChangeDecisionEntity.fromJson(
            json
          );
                case 'projectRecommendation':
          return ProjectRecommendationEntity.fromJson(
            json
          );
                case 'wakeTokenUsage':
          return WakeTokenUsageEntity.fromJson(
            json
          );
                case 'soulDocument':
          return SoulDocumentEntity.fromJson(
            json
          );
                case 'soulDocumentVersion':
          return SoulDocumentVersionEntity.fromJson(
            json
          );
                case 'soulDocumentHead':
          return SoulDocumentHeadEntity.fromJson(
            json
          );
        
          default:
            return AgentUnknownEntity.fromJson(
  json
);
        }
      
}

/// @nodoc
mixin _$AgentDomainEntity {

 String get id; String get agentId; VectorClock? get vectorClock; DateTime? get deletedAt;
/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentDomainEntityCopyWith<AgentDomainEntity> get copyWith => _$AgentDomainEntityCopyWithImpl<AgentDomainEntity>(this as AgentDomainEntity, _$identity);

  /// Serializes this AgentDomainEntity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentDomainEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,vectorClock,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity(id: $id, agentId: $agentId, vectorClock: $vectorClock, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentDomainEntityCopyWith<$Res>  {
  factory $AgentDomainEntityCopyWith(AgentDomainEntity value, $Res Function(AgentDomainEntity) _then) = _$AgentDomainEntityCopyWithImpl;
@useResult
$Res call({
 String id, String agentId, VectorClock? vectorClock, DateTime? deletedAt
});




}
/// @nodoc
class _$AgentDomainEntityCopyWithImpl<$Res>
    implements $AgentDomainEntityCopyWith<$Res> {
  _$AgentDomainEntityCopyWithImpl(this._self, this._then);

  final AgentDomainEntity _self;
  final $Res Function(AgentDomainEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? agentId = null,Object? vectorClock = freezed,Object? deletedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AgentIdentityEntity value)?  agent,TResult Function( AgentStateEntity value)?  agentState,TResult Function( AgentMessageEntity value)?  agentMessage,TResult Function( AgentMessagePayloadEntity value)?  agentMessagePayload,TResult Function( AgentReportEntity value)?  agentReport,TResult Function( AgentReportHeadEntity value)?  agentReportHead,TResult Function( ScheduledWakeEntity value)?  scheduledWake,TResult Function( CaptureEntity value)?  capture,TResult Function( ParsedItemEntity value)?  parsedItem,TResult Function( DayPlanEntity value)?  dayPlan,TResult Function( AttentionRequestEntity value)?  attentionRequest,TResult Function( AttentionClaimDispositionEntity value)?  attentionClaimDisposition,TResult Function( AttentionAwardEntity value)?  attentionAward,TResult Function( StandingAgreementEntity value)?  standingAgreement,TResult Function( AgentTemplateEntity value)?  agentTemplate,TResult Function( AgentTemplateVersionEntity value)?  agentTemplateVersion,TResult Function( AgentTemplateHeadEntity value)?  agentTemplateHead,TResult Function( EvolutionSessionEntity value)?  evolutionSession,TResult Function( EvolutionSessionRecapEntity value)?  evolutionSessionRecap,TResult Function( EvolutionNoteEntity value)?  evolutionNote,TResult Function( ChangeSetEntity value)?  changeSet,TResult Function( ChangeDecisionEntity value)?  changeDecision,TResult Function( ProjectRecommendationEntity value)?  projectRecommendation,TResult Function( WakeTokenUsageEntity value)?  wakeTokenUsage,TResult Function( SoulDocumentEntity value)?  soulDocument,TResult Function( SoulDocumentVersionEntity value)?  soulDocumentVersion,TResult Function( SoulDocumentHeadEntity value)?  soulDocumentHead,TResult Function( AgentUnknownEntity value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AgentIdentityEntity() when agent != null:
return agent(_that);case AgentStateEntity() when agentState != null:
return agentState(_that);case AgentMessageEntity() when agentMessage != null:
return agentMessage(_that);case AgentMessagePayloadEntity() when agentMessagePayload != null:
return agentMessagePayload(_that);case AgentReportEntity() when agentReport != null:
return agentReport(_that);case AgentReportHeadEntity() when agentReportHead != null:
return agentReportHead(_that);case ScheduledWakeEntity() when scheduledWake != null:
return scheduledWake(_that);case CaptureEntity() when capture != null:
return capture(_that);case ParsedItemEntity() when parsedItem != null:
return parsedItem(_that);case DayPlanEntity() when dayPlan != null:
return dayPlan(_that);case AttentionRequestEntity() when attentionRequest != null:
return attentionRequest(_that);case AttentionClaimDispositionEntity() when attentionClaimDisposition != null:
return attentionClaimDisposition(_that);case AttentionAwardEntity() when attentionAward != null:
return attentionAward(_that);case StandingAgreementEntity() when standingAgreement != null:
return standingAgreement(_that);case AgentTemplateEntity() when agentTemplate != null:
return agentTemplate(_that);case AgentTemplateVersionEntity() when agentTemplateVersion != null:
return agentTemplateVersion(_that);case AgentTemplateHeadEntity() when agentTemplateHead != null:
return agentTemplateHead(_that);case EvolutionSessionEntity() when evolutionSession != null:
return evolutionSession(_that);case EvolutionSessionRecapEntity() when evolutionSessionRecap != null:
return evolutionSessionRecap(_that);case EvolutionNoteEntity() when evolutionNote != null:
return evolutionNote(_that);case ChangeSetEntity() when changeSet != null:
return changeSet(_that);case ChangeDecisionEntity() when changeDecision != null:
return changeDecision(_that);case ProjectRecommendationEntity() when projectRecommendation != null:
return projectRecommendation(_that);case WakeTokenUsageEntity() when wakeTokenUsage != null:
return wakeTokenUsage(_that);case SoulDocumentEntity() when soulDocument != null:
return soulDocument(_that);case SoulDocumentVersionEntity() when soulDocumentVersion != null:
return soulDocumentVersion(_that);case SoulDocumentHeadEntity() when soulDocumentHead != null:
return soulDocumentHead(_that);case AgentUnknownEntity() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AgentIdentityEntity value)  agent,required TResult Function( AgentStateEntity value)  agentState,required TResult Function( AgentMessageEntity value)  agentMessage,required TResult Function( AgentMessagePayloadEntity value)  agentMessagePayload,required TResult Function( AgentReportEntity value)  agentReport,required TResult Function( AgentReportHeadEntity value)  agentReportHead,required TResult Function( ScheduledWakeEntity value)  scheduledWake,required TResult Function( CaptureEntity value)  capture,required TResult Function( ParsedItemEntity value)  parsedItem,required TResult Function( DayPlanEntity value)  dayPlan,required TResult Function( AttentionRequestEntity value)  attentionRequest,required TResult Function( AttentionClaimDispositionEntity value)  attentionClaimDisposition,required TResult Function( AttentionAwardEntity value)  attentionAward,required TResult Function( StandingAgreementEntity value)  standingAgreement,required TResult Function( AgentTemplateEntity value)  agentTemplate,required TResult Function( AgentTemplateVersionEntity value)  agentTemplateVersion,required TResult Function( AgentTemplateHeadEntity value)  agentTemplateHead,required TResult Function( EvolutionSessionEntity value)  evolutionSession,required TResult Function( EvolutionSessionRecapEntity value)  evolutionSessionRecap,required TResult Function( EvolutionNoteEntity value)  evolutionNote,required TResult Function( ChangeSetEntity value)  changeSet,required TResult Function( ChangeDecisionEntity value)  changeDecision,required TResult Function( ProjectRecommendationEntity value)  projectRecommendation,required TResult Function( WakeTokenUsageEntity value)  wakeTokenUsage,required TResult Function( SoulDocumentEntity value)  soulDocument,required TResult Function( SoulDocumentVersionEntity value)  soulDocumentVersion,required TResult Function( SoulDocumentHeadEntity value)  soulDocumentHead,required TResult Function( AgentUnknownEntity value)  unknown,}){
final _that = this;
switch (_that) {
case AgentIdentityEntity():
return agent(_that);case AgentStateEntity():
return agentState(_that);case AgentMessageEntity():
return agentMessage(_that);case AgentMessagePayloadEntity():
return agentMessagePayload(_that);case AgentReportEntity():
return agentReport(_that);case AgentReportHeadEntity():
return agentReportHead(_that);case ScheduledWakeEntity():
return scheduledWake(_that);case CaptureEntity():
return capture(_that);case ParsedItemEntity():
return parsedItem(_that);case DayPlanEntity():
return dayPlan(_that);case AttentionRequestEntity():
return attentionRequest(_that);case AttentionClaimDispositionEntity():
return attentionClaimDisposition(_that);case AttentionAwardEntity():
return attentionAward(_that);case StandingAgreementEntity():
return standingAgreement(_that);case AgentTemplateEntity():
return agentTemplate(_that);case AgentTemplateVersionEntity():
return agentTemplateVersion(_that);case AgentTemplateHeadEntity():
return agentTemplateHead(_that);case EvolutionSessionEntity():
return evolutionSession(_that);case EvolutionSessionRecapEntity():
return evolutionSessionRecap(_that);case EvolutionNoteEntity():
return evolutionNote(_that);case ChangeSetEntity():
return changeSet(_that);case ChangeDecisionEntity():
return changeDecision(_that);case ProjectRecommendationEntity():
return projectRecommendation(_that);case WakeTokenUsageEntity():
return wakeTokenUsage(_that);case SoulDocumentEntity():
return soulDocument(_that);case SoulDocumentVersionEntity():
return soulDocumentVersion(_that);case SoulDocumentHeadEntity():
return soulDocumentHead(_that);case AgentUnknownEntity():
return unknown(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AgentIdentityEntity value)?  agent,TResult? Function( AgentStateEntity value)?  agentState,TResult? Function( AgentMessageEntity value)?  agentMessage,TResult? Function( AgentMessagePayloadEntity value)?  agentMessagePayload,TResult? Function( AgentReportEntity value)?  agentReport,TResult? Function( AgentReportHeadEntity value)?  agentReportHead,TResult? Function( ScheduledWakeEntity value)?  scheduledWake,TResult? Function( CaptureEntity value)?  capture,TResult? Function( ParsedItemEntity value)?  parsedItem,TResult? Function( DayPlanEntity value)?  dayPlan,TResult? Function( AttentionRequestEntity value)?  attentionRequest,TResult? Function( AttentionClaimDispositionEntity value)?  attentionClaimDisposition,TResult? Function( AttentionAwardEntity value)?  attentionAward,TResult? Function( StandingAgreementEntity value)?  standingAgreement,TResult? Function( AgentTemplateEntity value)?  agentTemplate,TResult? Function( AgentTemplateVersionEntity value)?  agentTemplateVersion,TResult? Function( AgentTemplateHeadEntity value)?  agentTemplateHead,TResult? Function( EvolutionSessionEntity value)?  evolutionSession,TResult? Function( EvolutionSessionRecapEntity value)?  evolutionSessionRecap,TResult? Function( EvolutionNoteEntity value)?  evolutionNote,TResult? Function( ChangeSetEntity value)?  changeSet,TResult? Function( ChangeDecisionEntity value)?  changeDecision,TResult? Function( ProjectRecommendationEntity value)?  projectRecommendation,TResult? Function( WakeTokenUsageEntity value)?  wakeTokenUsage,TResult? Function( SoulDocumentEntity value)?  soulDocument,TResult? Function( SoulDocumentVersionEntity value)?  soulDocumentVersion,TResult? Function( SoulDocumentHeadEntity value)?  soulDocumentHead,TResult? Function( AgentUnknownEntity value)?  unknown,}){
final _that = this;
switch (_that) {
case AgentIdentityEntity() when agent != null:
return agent(_that);case AgentStateEntity() when agentState != null:
return agentState(_that);case AgentMessageEntity() when agentMessage != null:
return agentMessage(_that);case AgentMessagePayloadEntity() when agentMessagePayload != null:
return agentMessagePayload(_that);case AgentReportEntity() when agentReport != null:
return agentReport(_that);case AgentReportHeadEntity() when agentReportHead != null:
return agentReportHead(_that);case ScheduledWakeEntity() when scheduledWake != null:
return scheduledWake(_that);case CaptureEntity() when capture != null:
return capture(_that);case ParsedItemEntity() when parsedItem != null:
return parsedItem(_that);case DayPlanEntity() when dayPlan != null:
return dayPlan(_that);case AttentionRequestEntity() when attentionRequest != null:
return attentionRequest(_that);case AttentionClaimDispositionEntity() when attentionClaimDisposition != null:
return attentionClaimDisposition(_that);case AttentionAwardEntity() when attentionAward != null:
return attentionAward(_that);case StandingAgreementEntity() when standingAgreement != null:
return standingAgreement(_that);case AgentTemplateEntity() when agentTemplate != null:
return agentTemplate(_that);case AgentTemplateVersionEntity() when agentTemplateVersion != null:
return agentTemplateVersion(_that);case AgentTemplateHeadEntity() when agentTemplateHead != null:
return agentTemplateHead(_that);case EvolutionSessionEntity() when evolutionSession != null:
return evolutionSession(_that);case EvolutionSessionRecapEntity() when evolutionSessionRecap != null:
return evolutionSessionRecap(_that);case EvolutionNoteEntity() when evolutionNote != null:
return evolutionNote(_that);case ChangeSetEntity() when changeSet != null:
return changeSet(_that);case ChangeDecisionEntity() when changeDecision != null:
return changeDecision(_that);case ProjectRecommendationEntity() when projectRecommendation != null:
return projectRecommendation(_that);case WakeTokenUsageEntity() when wakeTokenUsage != null:
return wakeTokenUsage(_that);case SoulDocumentEntity() when soulDocument != null:
return soulDocument(_that);case SoulDocumentVersionEntity() when soulDocumentVersion != null:
return soulDocumentVersion(_that);case SoulDocumentHeadEntity() when soulDocumentHead != null:
return soulDocumentHead(_that);case AgentUnknownEntity() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String id,  String agentId,  String kind,  String displayName,  AgentLifecycle lifecycle,  AgentInteractionMode mode,  Set<String> allowedCategoryIds,  String currentStateId,  AgentConfig config,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt,  DateTime? destroyedAt)?  agent,TResult Function( String id,  String agentId,  AgentSlots slots,  DateTime updatedAt,  VectorClock? vectorClock,  int revision,  DateTime? lastWakeAt,  DateTime? nextWakeAt,  DateTime? sleepUntil,  DateTime? scheduledWakeAt,  String? recentHeadMessageId,  String? latestSummaryMessageId,  int consecutiveFailureCount, @JsonKey(name: 'wakeCounterByHost')  GCounter wakeCounter,  Map<String, int> processedCounterByHost,  Map<String, int> toolCounterByKey,  bool awaitingContent,  DateTime? deletedAt)?  agentState,TResult Function( String id,  String agentId,  String threadId,  AgentMessageKind kind,  DateTime createdAt,  VectorClock? vectorClock,  AgentMessageMetadata metadata,  String? prevMessageId,  String? contentEntryId,  String? triggerSourceId,  String? summaryStartMessageId,  String? summaryEndMessageId,  int summaryDepth,  int tokensApprox,  DateTime? deletedAt)?  agentMessage,TResult Function( String id,  String agentId,  DateTime createdAt,  VectorClock? vectorClock,  Map<String, Object?> content,  String contentType,  DateTime? deletedAt)?  agentMessagePayload,TResult Function( String id,  String agentId,  String scope,  DateTime createdAt,  VectorClock? vectorClock,  String content,  String? tldr,  String? oneLiner,  double? confidence,  Map<String, Object?> provenance,  DateTime? deletedAt,  String? threadId)?  agentReport,TResult Function( String id,  String agentId,  String scope,  String reportId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  agentReportHead,TResult Function( String id,  String agentId,  DateTime scheduledAt,  ScheduledWakeStatus status,  String reason,  DateTime updatedAt,  VectorClock? vectorClock,  List<String> triggerTokens,  String? workspaceKey,  DateTime? consumedAt,  DateTime? deletedAt)?  scheduledWake,TResult Function( String id,  String agentId,  String transcript,  DateTime capturedAt,  DateTime createdAt,  VectorClock? vectorClock,  String? audioRef,  DateTime? deletedAt)?  capture,TResult Function( String id,  String agentId,  String captureId,  ParsedItemKind kind,  String title,  String categoryId,  ParsedItemConfidence confidence,  double confidenceScore,  DateTime createdAt,  VectorClock? vectorClock,  bool lowConfidence,  String? spokenPhrase,  String? matchedTaskId,  int? estimateMinutes,  String? timeAnchor,  String? proposedUpdate,  DateTime? deletedAt)?  parsedItem,TResult Function( String id,  String agentId,  String dayId,  DateTime planDate,  DayPlanData data,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? captureId,  List<DayAgentEnergyBand> energyBands,  int capacityMinutes,  int scheduledMinutes,  DateTime? deletedAt)?  dayPlan,TResult Function( String id,  String agentId,  AttentionRequestKind kind,  String title,  String categoryId,  int requestedMinutes,  int impact,  int urgency,  AttentionEnergyFit energyFit,  List<AttentionEvidenceRef> evidenceRefs,  DateTime createdAt,  VectorClock? vectorClock,  AttentionClaimScopeKind scopeKind,  AttentionRequestStatus status,  DateTime? rangeStart,  DateTime? rangeEnd,  DateTime? earliestStart,  DateTime? latestEnd,  DateTime? deadline,  DateTime? nextReviewAt,  String? targetId,  String? targetKind,  String? cadence,  String? rationale,  DateTime? deletedAt)?  attentionRequest,TResult Function( String id,  String agentId,  String requestId,  AttentionClaimStatus status,  DateTime createdAt,  VectorClock? vectorClock,  String? awardId,  String? planId,  String? changeSetId,  String? reason,  DateTime? nextReviewAt,  DateTime? deletedAt)?  attentionClaimDisposition,TResult Function( String id,  String agentId,  String requestId,  String dayId,  String planId,  String blockId,  String categoryId,  String title,  DateTime startTime,  DateTime endTime,  int rank,  int utilityScore,  DateTime createdAt,  VectorClock? vectorClock,  AttentionAwardStatus status,  String? taskId,  String? rationale,  DateTime? deletedAt)?  attentionAward,TResult Function( String id,  String agentId,  String title,  StandingAgreementScope scope,  StandingAgreementCadence cadence,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  StandingAgreementStatus status,  StandingAgreementEnforcement enforcement,  StandingAgreementApprovalMode approvalMode,  String? categoryId,  String? targetId,  String? targetKind,  String? customScope,  String? customCadence,  int? minCount,  int? maxCount,  int? minMinutes,  int? maxMinutes,  int? preferredSessionMinutes,  bool canPreempt,  int priority,  List<String> preemptibleCategoryIds,  List<String> protectedCategoryIds,  List<AttentionEvidenceRef> evidenceRefs,  DateTime? activeFrom,  DateTime? activeUntil,  String? rationale,  DateTime? deletedAt)?  standingAgreement,TResult Function( String id,  String agentId,  String displayName,  AgentTemplateKind kind,  String modelId,  Set<String> categoryIds,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? profileId,  DateTime? deletedAt)?  agentTemplate,TResult Function( String id,  String agentId,  int version,  AgentTemplateVersionStatus status,  String directives,  String authoredBy,  DateTime createdAt,  VectorClock? vectorClock,  String generalDirective,  String reportDirective,  String? modelId,  String? profileId,  DateTime? deletedAt)?  agentTemplateVersion,TResult Function( String id,  String agentId,  String versionId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  agentTemplateHead,TResult Function( String id,  String agentId,  String templateId,  int sessionNumber,  EvolutionSessionStatus status,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? proposedVersionId,  String? proposedSoulVersionId,  String? feedbackSummary,  double? userRating,  DateTime? completedAt,  DateTime? deletedAt)?  evolutionSession,TResult Function( String id,  String agentId,  String sessionId,  DateTime createdAt,  VectorClock? vectorClock,  String tldr,  String recapMarkdown,  Map<String, int> categoryRatings,  List<Map<String, String>> transcript,  String? approvedChangeSummary,  DateTime? deletedAt)?  evolutionSessionRecap,TResult Function( String id,  String agentId,  String sessionId,  EvolutionNoteKind kind,  DateTime createdAt,  VectorClock? vectorClock,  String content,  DateTime? deletedAt)?  evolutionNote,TResult Function( String id,  String agentId,  String taskId,  String threadId,  String runKey,  ChangeSetStatus status,  List<ChangeItem> items,  DateTime createdAt,  VectorClock? vectorClock,  DateTime? resolvedAt,  DateTime? deletedAt)?  changeSet,TResult Function( String id,  String agentId,  String changeSetId,  int itemIndex,  String toolName,  ChangeDecisionVerdict verdict,  DateTime createdAt,  VectorClock? vectorClock,  DecisionActor actor,  String? taskId,  String? rejectionReason,  String? retractionReason,  String? humanSummary,  Map<String, dynamic>? args,  DateTime? deletedAt)?  changeDecision,TResult Function( String id,  String agentId,  String projectId,  String title,  int position,  ProjectRecommendationStatus status,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? sourceChangeSetId,  String? sourceDecisionId,  String? rationale,  String? priority,  DateTime? resolvedAt,  DateTime? dismissedAt,  DateTime? supersededAt,  DateTime? deletedAt)?  projectRecommendation,TResult Function( String id,  String agentId,  String runKey,  String threadId,  String modelId,  DateTime createdAt,  VectorClock? vectorClock,  String? templateId,  String? templateVersionId,  String? soulDocumentId,  String? soulDocumentVersionId,  int? inputTokens,  int? outputTokens,  int? thoughtsTokens,  int? cachedInputTokens,  DateTime? deletedAt)?  wakeTokenUsage,TResult Function( String id,  String agentId,  String displayName,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  soulDocument,TResult Function( String id,  String agentId,  int version,  SoulDocumentVersionStatus status,  String authoredBy,  DateTime createdAt,  VectorClock? vectorClock,  String voiceDirective,  String toneBounds,  String coachingStyle,  String antiSycophancyPolicy,  String? sourceSessionId,  String? diffFromVersionId,  DateTime? deletedAt)?  soulDocumentVersion,TResult Function( String id,  String agentId,  String versionId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  soulDocumentHead,TResult Function( String id,  String agentId,  DateTime createdAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AgentIdentityEntity() when agent != null:
return agent(_that.id,_that.agentId,_that.kind,_that.displayName,_that.lifecycle,_that.mode,_that.allowedCategoryIds,_that.currentStateId,_that.config,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.deletedAt,_that.destroyedAt);case AgentStateEntity() when agentState != null:
return agentState(_that.id,_that.agentId,_that.slots,_that.updatedAt,_that.vectorClock,_that.revision,_that.lastWakeAt,_that.nextWakeAt,_that.sleepUntil,_that.scheduledWakeAt,_that.recentHeadMessageId,_that.latestSummaryMessageId,_that.consecutiveFailureCount,_that.wakeCounter,_that.processedCounterByHost,_that.toolCounterByKey,_that.awaitingContent,_that.deletedAt);case AgentMessageEntity() when agentMessage != null:
return agentMessage(_that.id,_that.agentId,_that.threadId,_that.kind,_that.createdAt,_that.vectorClock,_that.metadata,_that.prevMessageId,_that.contentEntryId,_that.triggerSourceId,_that.summaryStartMessageId,_that.summaryEndMessageId,_that.summaryDepth,_that.tokensApprox,_that.deletedAt);case AgentMessagePayloadEntity() when agentMessagePayload != null:
return agentMessagePayload(_that.id,_that.agentId,_that.createdAt,_that.vectorClock,_that.content,_that.contentType,_that.deletedAt);case AgentReportEntity() when agentReport != null:
return agentReport(_that.id,_that.agentId,_that.scope,_that.createdAt,_that.vectorClock,_that.content,_that.tldr,_that.oneLiner,_that.confidence,_that.provenance,_that.deletedAt,_that.threadId);case AgentReportHeadEntity() when agentReportHead != null:
return agentReportHead(_that.id,_that.agentId,_that.scope,_that.reportId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case ScheduledWakeEntity() when scheduledWake != null:
return scheduledWake(_that.id,_that.agentId,_that.scheduledAt,_that.status,_that.reason,_that.updatedAt,_that.vectorClock,_that.triggerTokens,_that.workspaceKey,_that.consumedAt,_that.deletedAt);case CaptureEntity() when capture != null:
return capture(_that.id,_that.agentId,_that.transcript,_that.capturedAt,_that.createdAt,_that.vectorClock,_that.audioRef,_that.deletedAt);case ParsedItemEntity() when parsedItem != null:
return parsedItem(_that.id,_that.agentId,_that.captureId,_that.kind,_that.title,_that.categoryId,_that.confidence,_that.confidenceScore,_that.createdAt,_that.vectorClock,_that.lowConfidence,_that.spokenPhrase,_that.matchedTaskId,_that.estimateMinutes,_that.timeAnchor,_that.proposedUpdate,_that.deletedAt);case DayPlanEntity() when dayPlan != null:
return dayPlan(_that.id,_that.agentId,_that.dayId,_that.planDate,_that.data,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.captureId,_that.energyBands,_that.capacityMinutes,_that.scheduledMinutes,_that.deletedAt);case AttentionRequestEntity() when attentionRequest != null:
return attentionRequest(_that.id,_that.agentId,_that.kind,_that.title,_that.categoryId,_that.requestedMinutes,_that.impact,_that.urgency,_that.energyFit,_that.evidenceRefs,_that.createdAt,_that.vectorClock,_that.scopeKind,_that.status,_that.rangeStart,_that.rangeEnd,_that.earliestStart,_that.latestEnd,_that.deadline,_that.nextReviewAt,_that.targetId,_that.targetKind,_that.cadence,_that.rationale,_that.deletedAt);case AttentionClaimDispositionEntity() when attentionClaimDisposition != null:
return attentionClaimDisposition(_that.id,_that.agentId,_that.requestId,_that.status,_that.createdAt,_that.vectorClock,_that.awardId,_that.planId,_that.changeSetId,_that.reason,_that.nextReviewAt,_that.deletedAt);case AttentionAwardEntity() when attentionAward != null:
return attentionAward(_that.id,_that.agentId,_that.requestId,_that.dayId,_that.planId,_that.blockId,_that.categoryId,_that.title,_that.startTime,_that.endTime,_that.rank,_that.utilityScore,_that.createdAt,_that.vectorClock,_that.status,_that.taskId,_that.rationale,_that.deletedAt);case StandingAgreementEntity() when standingAgreement != null:
return standingAgreement(_that.id,_that.agentId,_that.title,_that.scope,_that.cadence,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.status,_that.enforcement,_that.approvalMode,_that.categoryId,_that.targetId,_that.targetKind,_that.customScope,_that.customCadence,_that.minCount,_that.maxCount,_that.minMinutes,_that.maxMinutes,_that.preferredSessionMinutes,_that.canPreempt,_that.priority,_that.preemptibleCategoryIds,_that.protectedCategoryIds,_that.evidenceRefs,_that.activeFrom,_that.activeUntil,_that.rationale,_that.deletedAt);case AgentTemplateEntity() when agentTemplate != null:
return agentTemplate(_that.id,_that.agentId,_that.displayName,_that.kind,_that.modelId,_that.categoryIds,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.profileId,_that.deletedAt);case AgentTemplateVersionEntity() when agentTemplateVersion != null:
return agentTemplateVersion(_that.id,_that.agentId,_that.version,_that.status,_that.directives,_that.authoredBy,_that.createdAt,_that.vectorClock,_that.generalDirective,_that.reportDirective,_that.modelId,_that.profileId,_that.deletedAt);case AgentTemplateHeadEntity() when agentTemplateHead != null:
return agentTemplateHead(_that.id,_that.agentId,_that.versionId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case EvolutionSessionEntity() when evolutionSession != null:
return evolutionSession(_that.id,_that.agentId,_that.templateId,_that.sessionNumber,_that.status,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.proposedVersionId,_that.proposedSoulVersionId,_that.feedbackSummary,_that.userRating,_that.completedAt,_that.deletedAt);case EvolutionSessionRecapEntity() when evolutionSessionRecap != null:
return evolutionSessionRecap(_that.id,_that.agentId,_that.sessionId,_that.createdAt,_that.vectorClock,_that.tldr,_that.recapMarkdown,_that.categoryRatings,_that.transcript,_that.approvedChangeSummary,_that.deletedAt);case EvolutionNoteEntity() when evolutionNote != null:
return evolutionNote(_that.id,_that.agentId,_that.sessionId,_that.kind,_that.createdAt,_that.vectorClock,_that.content,_that.deletedAt);case ChangeSetEntity() when changeSet != null:
return changeSet(_that.id,_that.agentId,_that.taskId,_that.threadId,_that.runKey,_that.status,_that.items,_that.createdAt,_that.vectorClock,_that.resolvedAt,_that.deletedAt);case ChangeDecisionEntity() when changeDecision != null:
return changeDecision(_that.id,_that.agentId,_that.changeSetId,_that.itemIndex,_that.toolName,_that.verdict,_that.createdAt,_that.vectorClock,_that.actor,_that.taskId,_that.rejectionReason,_that.retractionReason,_that.humanSummary,_that.args,_that.deletedAt);case ProjectRecommendationEntity() when projectRecommendation != null:
return projectRecommendation(_that.id,_that.agentId,_that.projectId,_that.title,_that.position,_that.status,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.sourceChangeSetId,_that.sourceDecisionId,_that.rationale,_that.priority,_that.resolvedAt,_that.dismissedAt,_that.supersededAt,_that.deletedAt);case WakeTokenUsageEntity() when wakeTokenUsage != null:
return wakeTokenUsage(_that.id,_that.agentId,_that.runKey,_that.threadId,_that.modelId,_that.createdAt,_that.vectorClock,_that.templateId,_that.templateVersionId,_that.soulDocumentId,_that.soulDocumentVersionId,_that.inputTokens,_that.outputTokens,_that.thoughtsTokens,_that.cachedInputTokens,_that.deletedAt);case SoulDocumentEntity() when soulDocument != null:
return soulDocument(_that.id,_that.agentId,_that.displayName,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.deletedAt);case SoulDocumentVersionEntity() when soulDocumentVersion != null:
return soulDocumentVersion(_that.id,_that.agentId,_that.version,_that.status,_that.authoredBy,_that.createdAt,_that.vectorClock,_that.voiceDirective,_that.toneBounds,_that.coachingStyle,_that.antiSycophancyPolicy,_that.sourceSessionId,_that.diffFromVersionId,_that.deletedAt);case SoulDocumentHeadEntity() when soulDocumentHead != null:
return soulDocumentHead(_that.id,_that.agentId,_that.versionId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case AgentUnknownEntity() when unknown != null:
return unknown(_that.id,_that.agentId,_that.createdAt,_that.vectorClock,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String id,  String agentId,  String kind,  String displayName,  AgentLifecycle lifecycle,  AgentInteractionMode mode,  Set<String> allowedCategoryIds,  String currentStateId,  AgentConfig config,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt,  DateTime? destroyedAt)  agent,required TResult Function( String id,  String agentId,  AgentSlots slots,  DateTime updatedAt,  VectorClock? vectorClock,  int revision,  DateTime? lastWakeAt,  DateTime? nextWakeAt,  DateTime? sleepUntil,  DateTime? scheduledWakeAt,  String? recentHeadMessageId,  String? latestSummaryMessageId,  int consecutiveFailureCount, @JsonKey(name: 'wakeCounterByHost')  GCounter wakeCounter,  Map<String, int> processedCounterByHost,  Map<String, int> toolCounterByKey,  bool awaitingContent,  DateTime? deletedAt)  agentState,required TResult Function( String id,  String agentId,  String threadId,  AgentMessageKind kind,  DateTime createdAt,  VectorClock? vectorClock,  AgentMessageMetadata metadata,  String? prevMessageId,  String? contentEntryId,  String? triggerSourceId,  String? summaryStartMessageId,  String? summaryEndMessageId,  int summaryDepth,  int tokensApprox,  DateTime? deletedAt)  agentMessage,required TResult Function( String id,  String agentId,  DateTime createdAt,  VectorClock? vectorClock,  Map<String, Object?> content,  String contentType,  DateTime? deletedAt)  agentMessagePayload,required TResult Function( String id,  String agentId,  String scope,  DateTime createdAt,  VectorClock? vectorClock,  String content,  String? tldr,  String? oneLiner,  double? confidence,  Map<String, Object?> provenance,  DateTime? deletedAt,  String? threadId)  agentReport,required TResult Function( String id,  String agentId,  String scope,  String reportId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)  agentReportHead,required TResult Function( String id,  String agentId,  DateTime scheduledAt,  ScheduledWakeStatus status,  String reason,  DateTime updatedAt,  VectorClock? vectorClock,  List<String> triggerTokens,  String? workspaceKey,  DateTime? consumedAt,  DateTime? deletedAt)  scheduledWake,required TResult Function( String id,  String agentId,  String transcript,  DateTime capturedAt,  DateTime createdAt,  VectorClock? vectorClock,  String? audioRef,  DateTime? deletedAt)  capture,required TResult Function( String id,  String agentId,  String captureId,  ParsedItemKind kind,  String title,  String categoryId,  ParsedItemConfidence confidence,  double confidenceScore,  DateTime createdAt,  VectorClock? vectorClock,  bool lowConfidence,  String? spokenPhrase,  String? matchedTaskId,  int? estimateMinutes,  String? timeAnchor,  String? proposedUpdate,  DateTime? deletedAt)  parsedItem,required TResult Function( String id,  String agentId,  String dayId,  DateTime planDate,  DayPlanData data,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? captureId,  List<DayAgentEnergyBand> energyBands,  int capacityMinutes,  int scheduledMinutes,  DateTime? deletedAt)  dayPlan,required TResult Function( String id,  String agentId,  AttentionRequestKind kind,  String title,  String categoryId,  int requestedMinutes,  int impact,  int urgency,  AttentionEnergyFit energyFit,  List<AttentionEvidenceRef> evidenceRefs,  DateTime createdAt,  VectorClock? vectorClock,  AttentionClaimScopeKind scopeKind,  AttentionRequestStatus status,  DateTime? rangeStart,  DateTime? rangeEnd,  DateTime? earliestStart,  DateTime? latestEnd,  DateTime? deadline,  DateTime? nextReviewAt,  String? targetId,  String? targetKind,  String? cadence,  String? rationale,  DateTime? deletedAt)  attentionRequest,required TResult Function( String id,  String agentId,  String requestId,  AttentionClaimStatus status,  DateTime createdAt,  VectorClock? vectorClock,  String? awardId,  String? planId,  String? changeSetId,  String? reason,  DateTime? nextReviewAt,  DateTime? deletedAt)  attentionClaimDisposition,required TResult Function( String id,  String agentId,  String requestId,  String dayId,  String planId,  String blockId,  String categoryId,  String title,  DateTime startTime,  DateTime endTime,  int rank,  int utilityScore,  DateTime createdAt,  VectorClock? vectorClock,  AttentionAwardStatus status,  String? taskId,  String? rationale,  DateTime? deletedAt)  attentionAward,required TResult Function( String id,  String agentId,  String title,  StandingAgreementScope scope,  StandingAgreementCadence cadence,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  StandingAgreementStatus status,  StandingAgreementEnforcement enforcement,  StandingAgreementApprovalMode approvalMode,  String? categoryId,  String? targetId,  String? targetKind,  String? customScope,  String? customCadence,  int? minCount,  int? maxCount,  int? minMinutes,  int? maxMinutes,  int? preferredSessionMinutes,  bool canPreempt,  int priority,  List<String> preemptibleCategoryIds,  List<String> protectedCategoryIds,  List<AttentionEvidenceRef> evidenceRefs,  DateTime? activeFrom,  DateTime? activeUntil,  String? rationale,  DateTime? deletedAt)  standingAgreement,required TResult Function( String id,  String agentId,  String displayName,  AgentTemplateKind kind,  String modelId,  Set<String> categoryIds,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? profileId,  DateTime? deletedAt)  agentTemplate,required TResult Function( String id,  String agentId,  int version,  AgentTemplateVersionStatus status,  String directives,  String authoredBy,  DateTime createdAt,  VectorClock? vectorClock,  String generalDirective,  String reportDirective,  String? modelId,  String? profileId,  DateTime? deletedAt)  agentTemplateVersion,required TResult Function( String id,  String agentId,  String versionId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)  agentTemplateHead,required TResult Function( String id,  String agentId,  String templateId,  int sessionNumber,  EvolutionSessionStatus status,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? proposedVersionId,  String? proposedSoulVersionId,  String? feedbackSummary,  double? userRating,  DateTime? completedAt,  DateTime? deletedAt)  evolutionSession,required TResult Function( String id,  String agentId,  String sessionId,  DateTime createdAt,  VectorClock? vectorClock,  String tldr,  String recapMarkdown,  Map<String, int> categoryRatings,  List<Map<String, String>> transcript,  String? approvedChangeSummary,  DateTime? deletedAt)  evolutionSessionRecap,required TResult Function( String id,  String agentId,  String sessionId,  EvolutionNoteKind kind,  DateTime createdAt,  VectorClock? vectorClock,  String content,  DateTime? deletedAt)  evolutionNote,required TResult Function( String id,  String agentId,  String taskId,  String threadId,  String runKey,  ChangeSetStatus status,  List<ChangeItem> items,  DateTime createdAt,  VectorClock? vectorClock,  DateTime? resolvedAt,  DateTime? deletedAt)  changeSet,required TResult Function( String id,  String agentId,  String changeSetId,  int itemIndex,  String toolName,  ChangeDecisionVerdict verdict,  DateTime createdAt,  VectorClock? vectorClock,  DecisionActor actor,  String? taskId,  String? rejectionReason,  String? retractionReason,  String? humanSummary,  Map<String, dynamic>? args,  DateTime? deletedAt)  changeDecision,required TResult Function( String id,  String agentId,  String projectId,  String title,  int position,  ProjectRecommendationStatus status,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? sourceChangeSetId,  String? sourceDecisionId,  String? rationale,  String? priority,  DateTime? resolvedAt,  DateTime? dismissedAt,  DateTime? supersededAt,  DateTime? deletedAt)  projectRecommendation,required TResult Function( String id,  String agentId,  String runKey,  String threadId,  String modelId,  DateTime createdAt,  VectorClock? vectorClock,  String? templateId,  String? templateVersionId,  String? soulDocumentId,  String? soulDocumentVersionId,  int? inputTokens,  int? outputTokens,  int? thoughtsTokens,  int? cachedInputTokens,  DateTime? deletedAt)  wakeTokenUsage,required TResult Function( String id,  String agentId,  String displayName,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)  soulDocument,required TResult Function( String id,  String agentId,  int version,  SoulDocumentVersionStatus status,  String authoredBy,  DateTime createdAt,  VectorClock? vectorClock,  String voiceDirective,  String toneBounds,  String coachingStyle,  String antiSycophancyPolicy,  String? sourceSessionId,  String? diffFromVersionId,  DateTime? deletedAt)  soulDocumentVersion,required TResult Function( String id,  String agentId,  String versionId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)  soulDocumentHead,required TResult Function( String id,  String agentId,  DateTime createdAt,  VectorClock? vectorClock,  DateTime? deletedAt)  unknown,}) {final _that = this;
switch (_that) {
case AgentIdentityEntity():
return agent(_that.id,_that.agentId,_that.kind,_that.displayName,_that.lifecycle,_that.mode,_that.allowedCategoryIds,_that.currentStateId,_that.config,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.deletedAt,_that.destroyedAt);case AgentStateEntity():
return agentState(_that.id,_that.agentId,_that.slots,_that.updatedAt,_that.vectorClock,_that.revision,_that.lastWakeAt,_that.nextWakeAt,_that.sleepUntil,_that.scheduledWakeAt,_that.recentHeadMessageId,_that.latestSummaryMessageId,_that.consecutiveFailureCount,_that.wakeCounter,_that.processedCounterByHost,_that.toolCounterByKey,_that.awaitingContent,_that.deletedAt);case AgentMessageEntity():
return agentMessage(_that.id,_that.agentId,_that.threadId,_that.kind,_that.createdAt,_that.vectorClock,_that.metadata,_that.prevMessageId,_that.contentEntryId,_that.triggerSourceId,_that.summaryStartMessageId,_that.summaryEndMessageId,_that.summaryDepth,_that.tokensApprox,_that.deletedAt);case AgentMessagePayloadEntity():
return agentMessagePayload(_that.id,_that.agentId,_that.createdAt,_that.vectorClock,_that.content,_that.contentType,_that.deletedAt);case AgentReportEntity():
return agentReport(_that.id,_that.agentId,_that.scope,_that.createdAt,_that.vectorClock,_that.content,_that.tldr,_that.oneLiner,_that.confidence,_that.provenance,_that.deletedAt,_that.threadId);case AgentReportHeadEntity():
return agentReportHead(_that.id,_that.agentId,_that.scope,_that.reportId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case ScheduledWakeEntity():
return scheduledWake(_that.id,_that.agentId,_that.scheduledAt,_that.status,_that.reason,_that.updatedAt,_that.vectorClock,_that.triggerTokens,_that.workspaceKey,_that.consumedAt,_that.deletedAt);case CaptureEntity():
return capture(_that.id,_that.agentId,_that.transcript,_that.capturedAt,_that.createdAt,_that.vectorClock,_that.audioRef,_that.deletedAt);case ParsedItemEntity():
return parsedItem(_that.id,_that.agentId,_that.captureId,_that.kind,_that.title,_that.categoryId,_that.confidence,_that.confidenceScore,_that.createdAt,_that.vectorClock,_that.lowConfidence,_that.spokenPhrase,_that.matchedTaskId,_that.estimateMinutes,_that.timeAnchor,_that.proposedUpdate,_that.deletedAt);case DayPlanEntity():
return dayPlan(_that.id,_that.agentId,_that.dayId,_that.planDate,_that.data,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.captureId,_that.energyBands,_that.capacityMinutes,_that.scheduledMinutes,_that.deletedAt);case AttentionRequestEntity():
return attentionRequest(_that.id,_that.agentId,_that.kind,_that.title,_that.categoryId,_that.requestedMinutes,_that.impact,_that.urgency,_that.energyFit,_that.evidenceRefs,_that.createdAt,_that.vectorClock,_that.scopeKind,_that.status,_that.rangeStart,_that.rangeEnd,_that.earliestStart,_that.latestEnd,_that.deadline,_that.nextReviewAt,_that.targetId,_that.targetKind,_that.cadence,_that.rationale,_that.deletedAt);case AttentionClaimDispositionEntity():
return attentionClaimDisposition(_that.id,_that.agentId,_that.requestId,_that.status,_that.createdAt,_that.vectorClock,_that.awardId,_that.planId,_that.changeSetId,_that.reason,_that.nextReviewAt,_that.deletedAt);case AttentionAwardEntity():
return attentionAward(_that.id,_that.agentId,_that.requestId,_that.dayId,_that.planId,_that.blockId,_that.categoryId,_that.title,_that.startTime,_that.endTime,_that.rank,_that.utilityScore,_that.createdAt,_that.vectorClock,_that.status,_that.taskId,_that.rationale,_that.deletedAt);case StandingAgreementEntity():
return standingAgreement(_that.id,_that.agentId,_that.title,_that.scope,_that.cadence,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.status,_that.enforcement,_that.approvalMode,_that.categoryId,_that.targetId,_that.targetKind,_that.customScope,_that.customCadence,_that.minCount,_that.maxCount,_that.minMinutes,_that.maxMinutes,_that.preferredSessionMinutes,_that.canPreempt,_that.priority,_that.preemptibleCategoryIds,_that.protectedCategoryIds,_that.evidenceRefs,_that.activeFrom,_that.activeUntil,_that.rationale,_that.deletedAt);case AgentTemplateEntity():
return agentTemplate(_that.id,_that.agentId,_that.displayName,_that.kind,_that.modelId,_that.categoryIds,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.profileId,_that.deletedAt);case AgentTemplateVersionEntity():
return agentTemplateVersion(_that.id,_that.agentId,_that.version,_that.status,_that.directives,_that.authoredBy,_that.createdAt,_that.vectorClock,_that.generalDirective,_that.reportDirective,_that.modelId,_that.profileId,_that.deletedAt);case AgentTemplateHeadEntity():
return agentTemplateHead(_that.id,_that.agentId,_that.versionId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case EvolutionSessionEntity():
return evolutionSession(_that.id,_that.agentId,_that.templateId,_that.sessionNumber,_that.status,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.proposedVersionId,_that.proposedSoulVersionId,_that.feedbackSummary,_that.userRating,_that.completedAt,_that.deletedAt);case EvolutionSessionRecapEntity():
return evolutionSessionRecap(_that.id,_that.agentId,_that.sessionId,_that.createdAt,_that.vectorClock,_that.tldr,_that.recapMarkdown,_that.categoryRatings,_that.transcript,_that.approvedChangeSummary,_that.deletedAt);case EvolutionNoteEntity():
return evolutionNote(_that.id,_that.agentId,_that.sessionId,_that.kind,_that.createdAt,_that.vectorClock,_that.content,_that.deletedAt);case ChangeSetEntity():
return changeSet(_that.id,_that.agentId,_that.taskId,_that.threadId,_that.runKey,_that.status,_that.items,_that.createdAt,_that.vectorClock,_that.resolvedAt,_that.deletedAt);case ChangeDecisionEntity():
return changeDecision(_that.id,_that.agentId,_that.changeSetId,_that.itemIndex,_that.toolName,_that.verdict,_that.createdAt,_that.vectorClock,_that.actor,_that.taskId,_that.rejectionReason,_that.retractionReason,_that.humanSummary,_that.args,_that.deletedAt);case ProjectRecommendationEntity():
return projectRecommendation(_that.id,_that.agentId,_that.projectId,_that.title,_that.position,_that.status,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.sourceChangeSetId,_that.sourceDecisionId,_that.rationale,_that.priority,_that.resolvedAt,_that.dismissedAt,_that.supersededAt,_that.deletedAt);case WakeTokenUsageEntity():
return wakeTokenUsage(_that.id,_that.agentId,_that.runKey,_that.threadId,_that.modelId,_that.createdAt,_that.vectorClock,_that.templateId,_that.templateVersionId,_that.soulDocumentId,_that.soulDocumentVersionId,_that.inputTokens,_that.outputTokens,_that.thoughtsTokens,_that.cachedInputTokens,_that.deletedAt);case SoulDocumentEntity():
return soulDocument(_that.id,_that.agentId,_that.displayName,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.deletedAt);case SoulDocumentVersionEntity():
return soulDocumentVersion(_that.id,_that.agentId,_that.version,_that.status,_that.authoredBy,_that.createdAt,_that.vectorClock,_that.voiceDirective,_that.toneBounds,_that.coachingStyle,_that.antiSycophancyPolicy,_that.sourceSessionId,_that.diffFromVersionId,_that.deletedAt);case SoulDocumentHeadEntity():
return soulDocumentHead(_that.id,_that.agentId,_that.versionId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case AgentUnknownEntity():
return unknown(_that.id,_that.agentId,_that.createdAt,_that.vectorClock,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String id,  String agentId,  String kind,  String displayName,  AgentLifecycle lifecycle,  AgentInteractionMode mode,  Set<String> allowedCategoryIds,  String currentStateId,  AgentConfig config,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt,  DateTime? destroyedAt)?  agent,TResult? Function( String id,  String agentId,  AgentSlots slots,  DateTime updatedAt,  VectorClock? vectorClock,  int revision,  DateTime? lastWakeAt,  DateTime? nextWakeAt,  DateTime? sleepUntil,  DateTime? scheduledWakeAt,  String? recentHeadMessageId,  String? latestSummaryMessageId,  int consecutiveFailureCount, @JsonKey(name: 'wakeCounterByHost')  GCounter wakeCounter,  Map<String, int> processedCounterByHost,  Map<String, int> toolCounterByKey,  bool awaitingContent,  DateTime? deletedAt)?  agentState,TResult? Function( String id,  String agentId,  String threadId,  AgentMessageKind kind,  DateTime createdAt,  VectorClock? vectorClock,  AgentMessageMetadata metadata,  String? prevMessageId,  String? contentEntryId,  String? triggerSourceId,  String? summaryStartMessageId,  String? summaryEndMessageId,  int summaryDepth,  int tokensApprox,  DateTime? deletedAt)?  agentMessage,TResult? Function( String id,  String agentId,  DateTime createdAt,  VectorClock? vectorClock,  Map<String, Object?> content,  String contentType,  DateTime? deletedAt)?  agentMessagePayload,TResult? Function( String id,  String agentId,  String scope,  DateTime createdAt,  VectorClock? vectorClock,  String content,  String? tldr,  String? oneLiner,  double? confidence,  Map<String, Object?> provenance,  DateTime? deletedAt,  String? threadId)?  agentReport,TResult? Function( String id,  String agentId,  String scope,  String reportId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  agentReportHead,TResult? Function( String id,  String agentId,  DateTime scheduledAt,  ScheduledWakeStatus status,  String reason,  DateTime updatedAt,  VectorClock? vectorClock,  List<String> triggerTokens,  String? workspaceKey,  DateTime? consumedAt,  DateTime? deletedAt)?  scheduledWake,TResult? Function( String id,  String agentId,  String transcript,  DateTime capturedAt,  DateTime createdAt,  VectorClock? vectorClock,  String? audioRef,  DateTime? deletedAt)?  capture,TResult? Function( String id,  String agentId,  String captureId,  ParsedItemKind kind,  String title,  String categoryId,  ParsedItemConfidence confidence,  double confidenceScore,  DateTime createdAt,  VectorClock? vectorClock,  bool lowConfidence,  String? spokenPhrase,  String? matchedTaskId,  int? estimateMinutes,  String? timeAnchor,  String? proposedUpdate,  DateTime? deletedAt)?  parsedItem,TResult? Function( String id,  String agentId,  String dayId,  DateTime planDate,  DayPlanData data,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? captureId,  List<DayAgentEnergyBand> energyBands,  int capacityMinutes,  int scheduledMinutes,  DateTime? deletedAt)?  dayPlan,TResult? Function( String id,  String agentId,  AttentionRequestKind kind,  String title,  String categoryId,  int requestedMinutes,  int impact,  int urgency,  AttentionEnergyFit energyFit,  List<AttentionEvidenceRef> evidenceRefs,  DateTime createdAt,  VectorClock? vectorClock,  AttentionClaimScopeKind scopeKind,  AttentionRequestStatus status,  DateTime? rangeStart,  DateTime? rangeEnd,  DateTime? earliestStart,  DateTime? latestEnd,  DateTime? deadline,  DateTime? nextReviewAt,  String? targetId,  String? targetKind,  String? cadence,  String? rationale,  DateTime? deletedAt)?  attentionRequest,TResult? Function( String id,  String agentId,  String requestId,  AttentionClaimStatus status,  DateTime createdAt,  VectorClock? vectorClock,  String? awardId,  String? planId,  String? changeSetId,  String? reason,  DateTime? nextReviewAt,  DateTime? deletedAt)?  attentionClaimDisposition,TResult? Function( String id,  String agentId,  String requestId,  String dayId,  String planId,  String blockId,  String categoryId,  String title,  DateTime startTime,  DateTime endTime,  int rank,  int utilityScore,  DateTime createdAt,  VectorClock? vectorClock,  AttentionAwardStatus status,  String? taskId,  String? rationale,  DateTime? deletedAt)?  attentionAward,TResult? Function( String id,  String agentId,  String title,  StandingAgreementScope scope,  StandingAgreementCadence cadence,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  StandingAgreementStatus status,  StandingAgreementEnforcement enforcement,  StandingAgreementApprovalMode approvalMode,  String? categoryId,  String? targetId,  String? targetKind,  String? customScope,  String? customCadence,  int? minCount,  int? maxCount,  int? minMinutes,  int? maxMinutes,  int? preferredSessionMinutes,  bool canPreempt,  int priority,  List<String> preemptibleCategoryIds,  List<String> protectedCategoryIds,  List<AttentionEvidenceRef> evidenceRefs,  DateTime? activeFrom,  DateTime? activeUntil,  String? rationale,  DateTime? deletedAt)?  standingAgreement,TResult? Function( String id,  String agentId,  String displayName,  AgentTemplateKind kind,  String modelId,  Set<String> categoryIds,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? profileId,  DateTime? deletedAt)?  agentTemplate,TResult? Function( String id,  String agentId,  int version,  AgentTemplateVersionStatus status,  String directives,  String authoredBy,  DateTime createdAt,  VectorClock? vectorClock,  String generalDirective,  String reportDirective,  String? modelId,  String? profileId,  DateTime? deletedAt)?  agentTemplateVersion,TResult? Function( String id,  String agentId,  String versionId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  agentTemplateHead,TResult? Function( String id,  String agentId,  String templateId,  int sessionNumber,  EvolutionSessionStatus status,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? proposedVersionId,  String? proposedSoulVersionId,  String? feedbackSummary,  double? userRating,  DateTime? completedAt,  DateTime? deletedAt)?  evolutionSession,TResult? Function( String id,  String agentId,  String sessionId,  DateTime createdAt,  VectorClock? vectorClock,  String tldr,  String recapMarkdown,  Map<String, int> categoryRatings,  List<Map<String, String>> transcript,  String? approvedChangeSummary,  DateTime? deletedAt)?  evolutionSessionRecap,TResult? Function( String id,  String agentId,  String sessionId,  EvolutionNoteKind kind,  DateTime createdAt,  VectorClock? vectorClock,  String content,  DateTime? deletedAt)?  evolutionNote,TResult? Function( String id,  String agentId,  String taskId,  String threadId,  String runKey,  ChangeSetStatus status,  List<ChangeItem> items,  DateTime createdAt,  VectorClock? vectorClock,  DateTime? resolvedAt,  DateTime? deletedAt)?  changeSet,TResult? Function( String id,  String agentId,  String changeSetId,  int itemIndex,  String toolName,  ChangeDecisionVerdict verdict,  DateTime createdAt,  VectorClock? vectorClock,  DecisionActor actor,  String? taskId,  String? rejectionReason,  String? retractionReason,  String? humanSummary,  Map<String, dynamic>? args,  DateTime? deletedAt)?  changeDecision,TResult? Function( String id,  String agentId,  String projectId,  String title,  int position,  ProjectRecommendationStatus status,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  String? sourceChangeSetId,  String? sourceDecisionId,  String? rationale,  String? priority,  DateTime? resolvedAt,  DateTime? dismissedAt,  DateTime? supersededAt,  DateTime? deletedAt)?  projectRecommendation,TResult? Function( String id,  String agentId,  String runKey,  String threadId,  String modelId,  DateTime createdAt,  VectorClock? vectorClock,  String? templateId,  String? templateVersionId,  String? soulDocumentId,  String? soulDocumentVersionId,  int? inputTokens,  int? outputTokens,  int? thoughtsTokens,  int? cachedInputTokens,  DateTime? deletedAt)?  wakeTokenUsage,TResult? Function( String id,  String agentId,  String displayName,  DateTime createdAt,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  soulDocument,TResult? Function( String id,  String agentId,  int version,  SoulDocumentVersionStatus status,  String authoredBy,  DateTime createdAt,  VectorClock? vectorClock,  String voiceDirective,  String toneBounds,  String coachingStyle,  String antiSycophancyPolicy,  String? sourceSessionId,  String? diffFromVersionId,  DateTime? deletedAt)?  soulDocumentVersion,TResult? Function( String id,  String agentId,  String versionId,  DateTime updatedAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  soulDocumentHead,TResult? Function( String id,  String agentId,  DateTime createdAt,  VectorClock? vectorClock,  DateTime? deletedAt)?  unknown,}) {final _that = this;
switch (_that) {
case AgentIdentityEntity() when agent != null:
return agent(_that.id,_that.agentId,_that.kind,_that.displayName,_that.lifecycle,_that.mode,_that.allowedCategoryIds,_that.currentStateId,_that.config,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.deletedAt,_that.destroyedAt);case AgentStateEntity() when agentState != null:
return agentState(_that.id,_that.agentId,_that.slots,_that.updatedAt,_that.vectorClock,_that.revision,_that.lastWakeAt,_that.nextWakeAt,_that.sleepUntil,_that.scheduledWakeAt,_that.recentHeadMessageId,_that.latestSummaryMessageId,_that.consecutiveFailureCount,_that.wakeCounter,_that.processedCounterByHost,_that.toolCounterByKey,_that.awaitingContent,_that.deletedAt);case AgentMessageEntity() when agentMessage != null:
return agentMessage(_that.id,_that.agentId,_that.threadId,_that.kind,_that.createdAt,_that.vectorClock,_that.metadata,_that.prevMessageId,_that.contentEntryId,_that.triggerSourceId,_that.summaryStartMessageId,_that.summaryEndMessageId,_that.summaryDepth,_that.tokensApprox,_that.deletedAt);case AgentMessagePayloadEntity() when agentMessagePayload != null:
return agentMessagePayload(_that.id,_that.agentId,_that.createdAt,_that.vectorClock,_that.content,_that.contentType,_that.deletedAt);case AgentReportEntity() when agentReport != null:
return agentReport(_that.id,_that.agentId,_that.scope,_that.createdAt,_that.vectorClock,_that.content,_that.tldr,_that.oneLiner,_that.confidence,_that.provenance,_that.deletedAt,_that.threadId);case AgentReportHeadEntity() when agentReportHead != null:
return agentReportHead(_that.id,_that.agentId,_that.scope,_that.reportId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case ScheduledWakeEntity() when scheduledWake != null:
return scheduledWake(_that.id,_that.agentId,_that.scheduledAt,_that.status,_that.reason,_that.updatedAt,_that.vectorClock,_that.triggerTokens,_that.workspaceKey,_that.consumedAt,_that.deletedAt);case CaptureEntity() when capture != null:
return capture(_that.id,_that.agentId,_that.transcript,_that.capturedAt,_that.createdAt,_that.vectorClock,_that.audioRef,_that.deletedAt);case ParsedItemEntity() when parsedItem != null:
return parsedItem(_that.id,_that.agentId,_that.captureId,_that.kind,_that.title,_that.categoryId,_that.confidence,_that.confidenceScore,_that.createdAt,_that.vectorClock,_that.lowConfidence,_that.spokenPhrase,_that.matchedTaskId,_that.estimateMinutes,_that.timeAnchor,_that.proposedUpdate,_that.deletedAt);case DayPlanEntity() when dayPlan != null:
return dayPlan(_that.id,_that.agentId,_that.dayId,_that.planDate,_that.data,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.captureId,_that.energyBands,_that.capacityMinutes,_that.scheduledMinutes,_that.deletedAt);case AttentionRequestEntity() when attentionRequest != null:
return attentionRequest(_that.id,_that.agentId,_that.kind,_that.title,_that.categoryId,_that.requestedMinutes,_that.impact,_that.urgency,_that.energyFit,_that.evidenceRefs,_that.createdAt,_that.vectorClock,_that.scopeKind,_that.status,_that.rangeStart,_that.rangeEnd,_that.earliestStart,_that.latestEnd,_that.deadline,_that.nextReviewAt,_that.targetId,_that.targetKind,_that.cadence,_that.rationale,_that.deletedAt);case AttentionClaimDispositionEntity() when attentionClaimDisposition != null:
return attentionClaimDisposition(_that.id,_that.agentId,_that.requestId,_that.status,_that.createdAt,_that.vectorClock,_that.awardId,_that.planId,_that.changeSetId,_that.reason,_that.nextReviewAt,_that.deletedAt);case AttentionAwardEntity() when attentionAward != null:
return attentionAward(_that.id,_that.agentId,_that.requestId,_that.dayId,_that.planId,_that.blockId,_that.categoryId,_that.title,_that.startTime,_that.endTime,_that.rank,_that.utilityScore,_that.createdAt,_that.vectorClock,_that.status,_that.taskId,_that.rationale,_that.deletedAt);case StandingAgreementEntity() when standingAgreement != null:
return standingAgreement(_that.id,_that.agentId,_that.title,_that.scope,_that.cadence,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.status,_that.enforcement,_that.approvalMode,_that.categoryId,_that.targetId,_that.targetKind,_that.customScope,_that.customCadence,_that.minCount,_that.maxCount,_that.minMinutes,_that.maxMinutes,_that.preferredSessionMinutes,_that.canPreempt,_that.priority,_that.preemptibleCategoryIds,_that.protectedCategoryIds,_that.evidenceRefs,_that.activeFrom,_that.activeUntil,_that.rationale,_that.deletedAt);case AgentTemplateEntity() when agentTemplate != null:
return agentTemplate(_that.id,_that.agentId,_that.displayName,_that.kind,_that.modelId,_that.categoryIds,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.profileId,_that.deletedAt);case AgentTemplateVersionEntity() when agentTemplateVersion != null:
return agentTemplateVersion(_that.id,_that.agentId,_that.version,_that.status,_that.directives,_that.authoredBy,_that.createdAt,_that.vectorClock,_that.generalDirective,_that.reportDirective,_that.modelId,_that.profileId,_that.deletedAt);case AgentTemplateHeadEntity() when agentTemplateHead != null:
return agentTemplateHead(_that.id,_that.agentId,_that.versionId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case EvolutionSessionEntity() when evolutionSession != null:
return evolutionSession(_that.id,_that.agentId,_that.templateId,_that.sessionNumber,_that.status,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.proposedVersionId,_that.proposedSoulVersionId,_that.feedbackSummary,_that.userRating,_that.completedAt,_that.deletedAt);case EvolutionSessionRecapEntity() when evolutionSessionRecap != null:
return evolutionSessionRecap(_that.id,_that.agentId,_that.sessionId,_that.createdAt,_that.vectorClock,_that.tldr,_that.recapMarkdown,_that.categoryRatings,_that.transcript,_that.approvedChangeSummary,_that.deletedAt);case EvolutionNoteEntity() when evolutionNote != null:
return evolutionNote(_that.id,_that.agentId,_that.sessionId,_that.kind,_that.createdAt,_that.vectorClock,_that.content,_that.deletedAt);case ChangeSetEntity() when changeSet != null:
return changeSet(_that.id,_that.agentId,_that.taskId,_that.threadId,_that.runKey,_that.status,_that.items,_that.createdAt,_that.vectorClock,_that.resolvedAt,_that.deletedAt);case ChangeDecisionEntity() when changeDecision != null:
return changeDecision(_that.id,_that.agentId,_that.changeSetId,_that.itemIndex,_that.toolName,_that.verdict,_that.createdAt,_that.vectorClock,_that.actor,_that.taskId,_that.rejectionReason,_that.retractionReason,_that.humanSummary,_that.args,_that.deletedAt);case ProjectRecommendationEntity() when projectRecommendation != null:
return projectRecommendation(_that.id,_that.agentId,_that.projectId,_that.title,_that.position,_that.status,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.sourceChangeSetId,_that.sourceDecisionId,_that.rationale,_that.priority,_that.resolvedAt,_that.dismissedAt,_that.supersededAt,_that.deletedAt);case WakeTokenUsageEntity() when wakeTokenUsage != null:
return wakeTokenUsage(_that.id,_that.agentId,_that.runKey,_that.threadId,_that.modelId,_that.createdAt,_that.vectorClock,_that.templateId,_that.templateVersionId,_that.soulDocumentId,_that.soulDocumentVersionId,_that.inputTokens,_that.outputTokens,_that.thoughtsTokens,_that.cachedInputTokens,_that.deletedAt);case SoulDocumentEntity() when soulDocument != null:
return soulDocument(_that.id,_that.agentId,_that.displayName,_that.createdAt,_that.updatedAt,_that.vectorClock,_that.deletedAt);case SoulDocumentVersionEntity() when soulDocumentVersion != null:
return soulDocumentVersion(_that.id,_that.agentId,_that.version,_that.status,_that.authoredBy,_that.createdAt,_that.vectorClock,_that.voiceDirective,_that.toneBounds,_that.coachingStyle,_that.antiSycophancyPolicy,_that.sourceSessionId,_that.diffFromVersionId,_that.deletedAt);case SoulDocumentHeadEntity() when soulDocumentHead != null:
return soulDocumentHead(_that.id,_that.agentId,_that.versionId,_that.updatedAt,_that.vectorClock,_that.deletedAt);case AgentUnknownEntity() when unknown != null:
return unknown(_that.id,_that.agentId,_that.createdAt,_that.vectorClock,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class AgentIdentityEntity implements AgentDomainEntity {
  const AgentIdentityEntity({required this.id, required this.agentId, required this.kind, required this.displayName, required this.lifecycle, required this.mode, required final  Set<String> allowedCategoryIds, required this.currentStateId, required this.config, required this.createdAt, required this.updatedAt, required this.vectorClock, this.deletedAt, this.destroyedAt, final  String? $type}): _allowedCategoryIds = allowedCategoryIds,$type = $type ?? 'agent';
  factory AgentIdentityEntity.fromJson(Map<String, dynamic> json) => _$AgentIdentityEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String kind;
 final  String displayName;
 final  AgentLifecycle lifecycle;
 final  AgentInteractionMode mode;
 final  Set<String> _allowedCategoryIds;
 Set<String> get allowedCategoryIds {
  if (_allowedCategoryIds is EqualUnmodifiableSetView) return _allowedCategoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_allowedCategoryIds);
}

 final  String currentStateId;
 final  AgentConfig config;
 final  DateTime createdAt;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
@override final  DateTime? deletedAt;
 final  DateTime? destroyedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentIdentityEntityCopyWith<AgentIdentityEntity> get copyWith => _$AgentIdentityEntityCopyWithImpl<AgentIdentityEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentIdentityEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentIdentityEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.lifecycle, lifecycle) || other.lifecycle == lifecycle)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other._allowedCategoryIds, _allowedCategoryIds)&&(identical(other.currentStateId, currentStateId) || other.currentStateId == currentStateId)&&(identical(other.config, config) || other.config == config)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.destroyedAt, destroyedAt) || other.destroyedAt == destroyedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,kind,displayName,lifecycle,mode,const DeepCollectionEquality().hash(_allowedCategoryIds),currentStateId,config,createdAt,updatedAt,vectorClock,deletedAt,destroyedAt);

@override
String toString() {
  return 'AgentDomainEntity.agent(id: $id, agentId: $agentId, kind: $kind, displayName: $displayName, lifecycle: $lifecycle, mode: $mode, allowedCategoryIds: $allowedCategoryIds, currentStateId: $currentStateId, config: $config, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt, destroyedAt: $destroyedAt)';
}


}

/// @nodoc
abstract mixin class $AgentIdentityEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentIdentityEntityCopyWith(AgentIdentityEntity value, $Res Function(AgentIdentityEntity) _then) = _$AgentIdentityEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String kind, String displayName, AgentLifecycle lifecycle, AgentInteractionMode mode, Set<String> allowedCategoryIds, String currentStateId, AgentConfig config, DateTime createdAt, DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt, DateTime? destroyedAt
});


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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? kind = null,Object? displayName = null,Object? lifecycle = null,Object? mode = null,Object? allowedCategoryIds = null,Object? currentStateId = null,Object? config = null,Object? createdAt = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? deletedAt = freezed,Object? destroyedAt = freezed,}) {
  return _then(AgentIdentityEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,lifecycle: null == lifecycle ? _self.lifecycle : lifecycle // ignore: cast_nullable_to_non_nullable
as AgentLifecycle,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as AgentInteractionMode,allowedCategoryIds: null == allowedCategoryIds ? _self._allowedCategoryIds : allowedCategoryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,currentStateId: null == currentStateId ? _self.currentStateId : currentStateId // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as AgentConfig,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,destroyedAt: freezed == destroyedAt ? _self.destroyedAt : destroyedAt // ignore: cast_nullable_to_non_nullable
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
  const AgentStateEntity({required this.id, required this.agentId, required this.slots, required this.updatedAt, required this.vectorClock, this.revision = 0, this.lastWakeAt, this.nextWakeAt, this.sleepUntil, this.scheduledWakeAt, this.recentHeadMessageId, this.latestSummaryMessageId, this.consecutiveFailureCount = 0, @JsonKey(name: 'wakeCounterByHost') this.wakeCounter = const GCounter.empty(), final  Map<String, int> processedCounterByHost = const {}, final  Map<String, int> toolCounterByKey = const {}, this.awaitingContent = false, this.deletedAt, final  String? $type}): _processedCounterByHost = processedCounterByHost,_toolCounterByKey = toolCounterByKey,$type = $type ?? 'agentState';
  factory AgentStateEntity.fromJson(Map<String, dynamic> json) => _$AgentStateEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  AgentSlots slots;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
/// **Retired** (PR 4 B4). Was a display-only per-row counter; never read for
/// logic — concurrent resolution uses `updatedAt` + the vector clock, not
/// this. No longer incremented or shown. Kept as a defaulted (rather than
/// removed) field purely so a peer still on an older build can deserialize
/// state this build emits; drop it in a later breaking-change window.
@JsonKey() final  int revision;
 final  DateTime? lastWakeAt;
 final  DateTime? nextWakeAt;
 final  DateTime? sleepUntil;
 final  DateTime? scheduledWakeAt;
 final  String? recentHeadMessageId;
 final  String? latestSummaryMessageId;
@JsonKey() final  int consecutiveFailureCount;
@JsonKey(name: 'wakeCounterByHost') final  GCounter wakeCounter;
 final  Map<String, int> _processedCounterByHost;
@JsonKey() Map<String, int> get processedCounterByHost {
  if (_processedCounterByHost is EqualUnmodifiableMapView) return _processedCounterByHost;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_processedCounterByHost);
}

 final  Map<String, int> _toolCounterByKey;
@JsonKey() Map<String, int> get toolCounterByKey {
  if (_toolCounterByKey is EqualUnmodifiableMapView) return _toolCounterByKey;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_toolCounterByKey);
}

/// When true, the agent was auto-created from a category default and is
/// waiting for the task to contain meaningful content before its first run.
@JsonKey() final  bool awaitingContent;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentStateEntityCopyWith<AgentStateEntity> get copyWith => _$AgentStateEntityCopyWithImpl<AgentStateEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentStateEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentStateEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.slots, slots) || other.slots == slots)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.lastWakeAt, lastWakeAt) || other.lastWakeAt == lastWakeAt)&&(identical(other.nextWakeAt, nextWakeAt) || other.nextWakeAt == nextWakeAt)&&(identical(other.sleepUntil, sleepUntil) || other.sleepUntil == sleepUntil)&&(identical(other.scheduledWakeAt, scheduledWakeAt) || other.scheduledWakeAt == scheduledWakeAt)&&(identical(other.recentHeadMessageId, recentHeadMessageId) || other.recentHeadMessageId == recentHeadMessageId)&&(identical(other.latestSummaryMessageId, latestSummaryMessageId) || other.latestSummaryMessageId == latestSummaryMessageId)&&(identical(other.consecutiveFailureCount, consecutiveFailureCount) || other.consecutiveFailureCount == consecutiveFailureCount)&&(identical(other.wakeCounter, wakeCounter) || other.wakeCounter == wakeCounter)&&const DeepCollectionEquality().equals(other._processedCounterByHost, _processedCounterByHost)&&const DeepCollectionEquality().equals(other._toolCounterByKey, _toolCounterByKey)&&(identical(other.awaitingContent, awaitingContent) || other.awaitingContent == awaitingContent)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,slots,updatedAt,vectorClock,revision,lastWakeAt,nextWakeAt,sleepUntil,scheduledWakeAt,recentHeadMessageId,latestSummaryMessageId,consecutiveFailureCount,wakeCounter,const DeepCollectionEquality().hash(_processedCounterByHost),const DeepCollectionEquality().hash(_toolCounterByKey),awaitingContent,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.agentState(id: $id, agentId: $agentId, slots: $slots, updatedAt: $updatedAt, vectorClock: $vectorClock, revision: $revision, lastWakeAt: $lastWakeAt, nextWakeAt: $nextWakeAt, sleepUntil: $sleepUntil, scheduledWakeAt: $scheduledWakeAt, recentHeadMessageId: $recentHeadMessageId, latestSummaryMessageId: $latestSummaryMessageId, consecutiveFailureCount: $consecutiveFailureCount, wakeCounter: $wakeCounter, processedCounterByHost: $processedCounterByHost, toolCounterByKey: $toolCounterByKey, awaitingContent: $awaitingContent, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentStateEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentStateEntityCopyWith(AgentStateEntity value, $Res Function(AgentStateEntity) _then) = _$AgentStateEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, AgentSlots slots, DateTime updatedAt, VectorClock? vectorClock, int revision, DateTime? lastWakeAt, DateTime? nextWakeAt, DateTime? sleepUntil, DateTime? scheduledWakeAt, String? recentHeadMessageId, String? latestSummaryMessageId, int consecutiveFailureCount,@JsonKey(name: 'wakeCounterByHost') GCounter wakeCounter, Map<String, int> processedCounterByHost, Map<String, int> toolCounterByKey, bool awaitingContent, DateTime? deletedAt
});


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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? slots = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? revision = null,Object? lastWakeAt = freezed,Object? nextWakeAt = freezed,Object? sleepUntil = freezed,Object? scheduledWakeAt = freezed,Object? recentHeadMessageId = freezed,Object? latestSummaryMessageId = freezed,Object? consecutiveFailureCount = null,Object? wakeCounter = null,Object? processedCounterByHost = null,Object? toolCounterByKey = null,Object? awaitingContent = null,Object? deletedAt = freezed,}) {
  return _then(AgentStateEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,slots: null == slots ? _self.slots : slots // ignore: cast_nullable_to_non_nullable
as AgentSlots,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,lastWakeAt: freezed == lastWakeAt ? _self.lastWakeAt : lastWakeAt // ignore: cast_nullable_to_non_nullable
as DateTime?,nextWakeAt: freezed == nextWakeAt ? _self.nextWakeAt : nextWakeAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sleepUntil: freezed == sleepUntil ? _self.sleepUntil : sleepUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,scheduledWakeAt: freezed == scheduledWakeAt ? _self.scheduledWakeAt : scheduledWakeAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recentHeadMessageId: freezed == recentHeadMessageId ? _self.recentHeadMessageId : recentHeadMessageId // ignore: cast_nullable_to_non_nullable
as String?,latestSummaryMessageId: freezed == latestSummaryMessageId ? _self.latestSummaryMessageId : latestSummaryMessageId // ignore: cast_nullable_to_non_nullable
as String?,consecutiveFailureCount: null == consecutiveFailureCount ? _self.consecutiveFailureCount : consecutiveFailureCount // ignore: cast_nullable_to_non_nullable
as int,wakeCounter: null == wakeCounter ? _self.wakeCounter : wakeCounter // ignore: cast_nullable_to_non_nullable
as GCounter,processedCounterByHost: null == processedCounterByHost ? _self._processedCounterByHost : processedCounterByHost // ignore: cast_nullable_to_non_nullable
as Map<String, int>,toolCounterByKey: null == toolCounterByKey ? _self._toolCounterByKey : toolCounterByKey // ignore: cast_nullable_to_non_nullable
as Map<String, int>,awaitingContent: null == awaitingContent ? _self.awaitingContent : awaitingContent // ignore: cast_nullable_to_non_nullable
as bool,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
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
  const AgentMessageEntity({required this.id, required this.agentId, required this.threadId, required this.kind, required this.createdAt, required this.vectorClock, required this.metadata, this.prevMessageId, this.contentEntryId, this.triggerSourceId, this.summaryStartMessageId, this.summaryEndMessageId, this.summaryDepth = 0, this.tokensApprox = 0, this.deletedAt, final  String? $type}): $type = $type ?? 'agentMessage';
  factory AgentMessageEntity.fromJson(Map<String, dynamic> json) => _$AgentMessageEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String threadId;
 final  AgentMessageKind kind;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  AgentMessageMetadata metadata;
 final  String? prevMessageId;
 final  String? contentEntryId;
 final  String? triggerSourceId;
 final  String? summaryStartMessageId;
 final  String? summaryEndMessageId;
@JsonKey() final  int summaryDepth;
@JsonKey() final  int tokensApprox;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentMessageEntityCopyWith<AgentMessageEntity> get copyWith => _$AgentMessageEntityCopyWithImpl<AgentMessageEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentMessageEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentMessageEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.prevMessageId, prevMessageId) || other.prevMessageId == prevMessageId)&&(identical(other.contentEntryId, contentEntryId) || other.contentEntryId == contentEntryId)&&(identical(other.triggerSourceId, triggerSourceId) || other.triggerSourceId == triggerSourceId)&&(identical(other.summaryStartMessageId, summaryStartMessageId) || other.summaryStartMessageId == summaryStartMessageId)&&(identical(other.summaryEndMessageId, summaryEndMessageId) || other.summaryEndMessageId == summaryEndMessageId)&&(identical(other.summaryDepth, summaryDepth) || other.summaryDepth == summaryDepth)&&(identical(other.tokensApprox, tokensApprox) || other.tokensApprox == tokensApprox)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,threadId,kind,createdAt,vectorClock,metadata,prevMessageId,contentEntryId,triggerSourceId,summaryStartMessageId,summaryEndMessageId,summaryDepth,tokensApprox,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.agentMessage(id: $id, agentId: $agentId, threadId: $threadId, kind: $kind, createdAt: $createdAt, vectorClock: $vectorClock, metadata: $metadata, prevMessageId: $prevMessageId, contentEntryId: $contentEntryId, triggerSourceId: $triggerSourceId, summaryStartMessageId: $summaryStartMessageId, summaryEndMessageId: $summaryEndMessageId, summaryDepth: $summaryDepth, tokensApprox: $tokensApprox, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentMessageEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentMessageEntityCopyWith(AgentMessageEntity value, $Res Function(AgentMessageEntity) _then) = _$AgentMessageEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String threadId, AgentMessageKind kind, DateTime createdAt, VectorClock? vectorClock, AgentMessageMetadata metadata, String? prevMessageId, String? contentEntryId, String? triggerSourceId, String? summaryStartMessageId, String? summaryEndMessageId, int summaryDepth, int tokensApprox, DateTime? deletedAt
});


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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? threadId = null,Object? kind = null,Object? createdAt = null,Object? vectorClock = freezed,Object? metadata = null,Object? prevMessageId = freezed,Object? contentEntryId = freezed,Object? triggerSourceId = freezed,Object? summaryStartMessageId = freezed,Object? summaryEndMessageId = freezed,Object? summaryDepth = null,Object? tokensApprox = null,Object? deletedAt = freezed,}) {
  return _then(AgentMessageEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AgentMessageKind,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as AgentMessageMetadata,prevMessageId: freezed == prevMessageId ? _self.prevMessageId : prevMessageId // ignore: cast_nullable_to_non_nullable
as String?,contentEntryId: freezed == contentEntryId ? _self.contentEntryId : contentEntryId // ignore: cast_nullable_to_non_nullable
as String?,triggerSourceId: freezed == triggerSourceId ? _self.triggerSourceId : triggerSourceId // ignore: cast_nullable_to_non_nullable
as String?,summaryStartMessageId: freezed == summaryStartMessageId ? _self.summaryStartMessageId : summaryStartMessageId // ignore: cast_nullable_to_non_nullable
as String?,summaryEndMessageId: freezed == summaryEndMessageId ? _self.summaryEndMessageId : summaryEndMessageId // ignore: cast_nullable_to_non_nullable
as String?,summaryDepth: null == summaryDepth ? _self.summaryDepth : summaryDepth // ignore: cast_nullable_to_non_nullable
as int,tokensApprox: null == tokensApprox ? _self.tokensApprox : tokensApprox // ignore: cast_nullable_to_non_nullable
as int,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
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
  const AgentMessagePayloadEntity({required this.id, required this.agentId, required this.createdAt, required this.vectorClock, required final  Map<String, Object?> content, this.contentType = 'application/json', this.deletedAt, final  String? $type}): _content = content,$type = $type ?? 'agentMessagePayload';
  factory AgentMessagePayloadEntity.fromJson(Map<String, dynamic> json) => _$AgentMessagePayloadEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  Map<String, Object?> _content;
 Map<String, Object?> get content {
  if (_content is EqualUnmodifiableMapView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_content);
}

@JsonKey() final  String contentType;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentMessagePayloadEntityCopyWith<AgentMessagePayloadEntity> get copyWith => _$AgentMessagePayloadEntityCopyWithImpl<AgentMessagePayloadEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentMessagePayloadEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentMessagePayloadEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,createdAt,vectorClock,const DeepCollectionEquality().hash(_content),contentType,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.agentMessagePayload(id: $id, agentId: $agentId, createdAt: $createdAt, vectorClock: $vectorClock, content: $content, contentType: $contentType, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentMessagePayloadEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentMessagePayloadEntityCopyWith(AgentMessagePayloadEntity value, $Res Function(AgentMessagePayloadEntity) _then) = _$AgentMessagePayloadEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, DateTime createdAt, VectorClock? vectorClock, Map<String, Object?> content, String contentType, DateTime? deletedAt
});




}
/// @nodoc
class _$AgentMessagePayloadEntityCopyWithImpl<$Res>
    implements $AgentMessagePayloadEntityCopyWith<$Res> {
  _$AgentMessagePayloadEntityCopyWithImpl(this._self, this._then);

  final AgentMessagePayloadEntity _self;
  final $Res Function(AgentMessagePayloadEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? createdAt = null,Object? vectorClock = freezed,Object? content = null,Object? contentType = null,Object? deletedAt = freezed,}) {
  return _then(AgentMessagePayloadEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AgentReportEntity implements AgentDomainEntity {
  const AgentReportEntity({required this.id, required this.agentId, required this.scope, required this.createdAt, required this.vectorClock, this.content = '', this.tldr, this.oneLiner, this.confidence, final  Map<String, Object?> provenance = const {}, this.deletedAt, this.threadId, final  String? $type}): _provenance = provenance,$type = $type ?? 'agentReport';
  factory AgentReportEntity.fromJson(Map<String, dynamic> json) => _$AgentReportEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String scope;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
@JsonKey() final  String content;
/// Short summary, populated by `update_report(tldr:, content:)`.
/// Null for reports created before this field was added.
 final  String? tldr;
/// Compact task tagline, populated by
/// `update_report(oneLiner:, tldr:, content:)`.
/// Null for reports created before this field was added.
 final  String? oneLiner;
 final  double? confidence;
 final  Map<String, Object?> _provenance;
@JsonKey() Map<String, Object?> get provenance {
  if (_provenance is EqualUnmodifiableMapView) return _provenance;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_provenance);
}

@override final  DateTime? deletedAt;
 final  String? threadId;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentReportEntityCopyWith<AgentReportEntity> get copyWith => _$AgentReportEntityCopyWithImpl<AgentReportEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentReportEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentReportEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.content, content) || other.content == content)&&(identical(other.tldr, tldr) || other.tldr == tldr)&&(identical(other.oneLiner, oneLiner) || other.oneLiner == oneLiner)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&const DeepCollectionEquality().equals(other._provenance, _provenance)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt)&&(identical(other.threadId, threadId) || other.threadId == threadId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,scope,createdAt,vectorClock,content,tldr,oneLiner,confidence,const DeepCollectionEquality().hash(_provenance),deletedAt,threadId);

@override
String toString() {
  return 'AgentDomainEntity.agentReport(id: $id, agentId: $agentId, scope: $scope, createdAt: $createdAt, vectorClock: $vectorClock, content: $content, tldr: $tldr, oneLiner: $oneLiner, confidence: $confidence, provenance: $provenance, deletedAt: $deletedAt, threadId: $threadId)';
}


}

/// @nodoc
abstract mixin class $AgentReportEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentReportEntityCopyWith(AgentReportEntity value, $Res Function(AgentReportEntity) _then) = _$AgentReportEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String scope, DateTime createdAt, VectorClock? vectorClock, String content, String? tldr, String? oneLiner, double? confidence, Map<String, Object?> provenance, DateTime? deletedAt, String? threadId
});




}
/// @nodoc
class _$AgentReportEntityCopyWithImpl<$Res>
    implements $AgentReportEntityCopyWith<$Res> {
  _$AgentReportEntityCopyWithImpl(this._self, this._then);

  final AgentReportEntity _self;
  final $Res Function(AgentReportEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? scope = null,Object? createdAt = null,Object? vectorClock = freezed,Object? content = null,Object? tldr = freezed,Object? oneLiner = freezed,Object? confidence = freezed,Object? provenance = null,Object? deletedAt = freezed,Object? threadId = freezed,}) {
  return _then(AgentReportEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,tldr: freezed == tldr ? _self.tldr : tldr // ignore: cast_nullable_to_non_nullable
as String?,oneLiner: freezed == oneLiner ? _self.oneLiner : oneLiner // ignore: cast_nullable_to_non_nullable
as String?,confidence: freezed == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double?,provenance: null == provenance ? _self._provenance : provenance // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,threadId: freezed == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AgentReportHeadEntity implements AgentDomainEntity {
  const AgentReportHeadEntity({required this.id, required this.agentId, required this.scope, required this.reportId, required this.updatedAt, required this.vectorClock, this.deletedAt, final  String? $type}): $type = $type ?? 'agentReportHead';
  factory AgentReportHeadEntity.fromJson(Map<String, dynamic> json) => _$AgentReportHeadEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String scope;
 final  String reportId;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentReportHeadEntityCopyWith<AgentReportHeadEntity> get copyWith => _$AgentReportHeadEntityCopyWithImpl<AgentReportHeadEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentReportHeadEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentReportHeadEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.reportId, reportId) || other.reportId == reportId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,scope,reportId,updatedAt,vectorClock,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.agentReportHead(id: $id, agentId: $agentId, scope: $scope, reportId: $reportId, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentReportHeadEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentReportHeadEntityCopyWith(AgentReportHeadEntity value, $Res Function(AgentReportHeadEntity) _then) = _$AgentReportHeadEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String scope, String reportId, DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt
});




}
/// @nodoc
class _$AgentReportHeadEntityCopyWithImpl<$Res>
    implements $AgentReportHeadEntityCopyWith<$Res> {
  _$AgentReportHeadEntityCopyWithImpl(this._self, this._then);

  final AgentReportHeadEntity _self;
  final $Res Function(AgentReportHeadEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? scope = null,Object? reportId = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? deletedAt = freezed,}) {
  return _then(AgentReportHeadEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as String,reportId: null == reportId ? _self.reportId : reportId // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ScheduledWakeEntity implements AgentDomainEntity {
  const ScheduledWakeEntity({required this.id, required this.agentId, required this.scheduledAt, required this.status, required this.reason, required this.updatedAt, required this.vectorClock, final  List<String> triggerTokens = const <String>[], this.workspaceKey, this.consumedAt, this.deletedAt, final  String? $type}): _triggerTokens = triggerTokens,$type = $type ?? 'scheduledWake';
  factory ScheduledWakeEntity.fromJson(Map<String, dynamic> json) => _$ScheduledWakeEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  DateTime scheduledAt;
 final  ScheduledWakeStatus status;
 final  String reason;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
 final  List<String> _triggerTokens;
@JsonKey() List<String> get triggerTokens {
  if (_triggerTokens is EqualUnmodifiableListView) return _triggerTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_triggerTokens);
}

 final  String? workspaceKey;
 final  DateTime? consumedAt;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduledWakeEntityCopyWith<ScheduledWakeEntity> get copyWith => _$ScheduledWakeEntityCopyWithImpl<ScheduledWakeEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduledWakeEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduledWakeEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.scheduledAt, scheduledAt) || other.scheduledAt == scheduledAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&const DeepCollectionEquality().equals(other._triggerTokens, _triggerTokens)&&(identical(other.workspaceKey, workspaceKey) || other.workspaceKey == workspaceKey)&&(identical(other.consumedAt, consumedAt) || other.consumedAt == consumedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,scheduledAt,status,reason,updatedAt,vectorClock,const DeepCollectionEquality().hash(_triggerTokens),workspaceKey,consumedAt,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.scheduledWake(id: $id, agentId: $agentId, scheduledAt: $scheduledAt, status: $status, reason: $reason, updatedAt: $updatedAt, vectorClock: $vectorClock, triggerTokens: $triggerTokens, workspaceKey: $workspaceKey, consumedAt: $consumedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $ScheduledWakeEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $ScheduledWakeEntityCopyWith(ScheduledWakeEntity value, $Res Function(ScheduledWakeEntity) _then) = _$ScheduledWakeEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, DateTime scheduledAt, ScheduledWakeStatus status, String reason, DateTime updatedAt, VectorClock? vectorClock, List<String> triggerTokens, String? workspaceKey, DateTime? consumedAt, DateTime? deletedAt
});




}
/// @nodoc
class _$ScheduledWakeEntityCopyWithImpl<$Res>
    implements $ScheduledWakeEntityCopyWith<$Res> {
  _$ScheduledWakeEntityCopyWithImpl(this._self, this._then);

  final ScheduledWakeEntity _self;
  final $Res Function(ScheduledWakeEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? scheduledAt = null,Object? status = null,Object? reason = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? triggerTokens = null,Object? workspaceKey = freezed,Object? consumedAt = freezed,Object? deletedAt = freezed,}) {
  return _then(ScheduledWakeEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,scheduledAt: null == scheduledAt ? _self.scheduledAt : scheduledAt // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ScheduledWakeStatus,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,triggerTokens: null == triggerTokens ? _self._triggerTokens : triggerTokens // ignore: cast_nullable_to_non_nullable
as List<String>,workspaceKey: freezed == workspaceKey ? _self.workspaceKey : workspaceKey // ignore: cast_nullable_to_non_nullable
as String?,consumedAt: freezed == consumedAt ? _self.consumedAt : consumedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class CaptureEntity implements AgentDomainEntity {
  const CaptureEntity({required this.id, required this.agentId, required this.transcript, required this.capturedAt, required this.createdAt, required this.vectorClock, this.audioRef, this.deletedAt, final  String? $type}): $type = $type ?? 'capture';
  factory CaptureEntity.fromJson(Map<String, dynamic> json) => _$CaptureEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String transcript;
 final  DateTime capturedAt;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  String? audioRef;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CaptureEntityCopyWith<CaptureEntity> get copyWith => _$CaptureEntityCopyWithImpl<CaptureEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CaptureEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CaptureEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.transcript, transcript) || other.transcript == transcript)&&(identical(other.capturedAt, capturedAt) || other.capturedAt == capturedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.audioRef, audioRef) || other.audioRef == audioRef)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,transcript,capturedAt,createdAt,vectorClock,audioRef,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.capture(id: $id, agentId: $agentId, transcript: $transcript, capturedAt: $capturedAt, createdAt: $createdAt, vectorClock: $vectorClock, audioRef: $audioRef, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $CaptureEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $CaptureEntityCopyWith(CaptureEntity value, $Res Function(CaptureEntity) _then) = _$CaptureEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String transcript, DateTime capturedAt, DateTime createdAt, VectorClock? vectorClock, String? audioRef, DateTime? deletedAt
});




}
/// @nodoc
class _$CaptureEntityCopyWithImpl<$Res>
    implements $CaptureEntityCopyWith<$Res> {
  _$CaptureEntityCopyWithImpl(this._self, this._then);

  final CaptureEntity _self;
  final $Res Function(CaptureEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? transcript = null,Object? capturedAt = null,Object? createdAt = null,Object? vectorClock = freezed,Object? audioRef = freezed,Object? deletedAt = freezed,}) {
  return _then(CaptureEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,transcript: null == transcript ? _self.transcript : transcript // ignore: cast_nullable_to_non_nullable
as String,capturedAt: null == capturedAt ? _self.capturedAt : capturedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,audioRef: freezed == audioRef ? _self.audioRef : audioRef // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ParsedItemEntity implements AgentDomainEntity {
  const ParsedItemEntity({required this.id, required this.agentId, required this.captureId, required this.kind, required this.title, required this.categoryId, required this.confidence, required this.confidenceScore, required this.createdAt, required this.vectorClock, this.lowConfidence = false, this.spokenPhrase, this.matchedTaskId, this.estimateMinutes, this.timeAnchor, this.proposedUpdate, this.deletedAt, final  String? $type}): $type = $type ?? 'parsedItem';
  factory ParsedItemEntity.fromJson(Map<String, dynamic> json) => _$ParsedItemEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String captureId;
 final  ParsedItemKind kind;
 final  String title;
 final  String categoryId;
 final  ParsedItemConfidence confidence;
 final  double confidenceScore;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
@JsonKey() final  bool lowConfidence;
 final  String? spokenPhrase;
 final  String? matchedTaskId;
 final  int? estimateMinutes;
 final  String? timeAnchor;
 final  String? proposedUpdate;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParsedItemEntityCopyWith<ParsedItemEntity> get copyWith => _$ParsedItemEntityCopyWithImpl<ParsedItemEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ParsedItemEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParsedItemEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.captureId, captureId) || other.captureId == captureId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.confidenceScore, confidenceScore) || other.confidenceScore == confidenceScore)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.lowConfidence, lowConfidence) || other.lowConfidence == lowConfidence)&&(identical(other.spokenPhrase, spokenPhrase) || other.spokenPhrase == spokenPhrase)&&(identical(other.matchedTaskId, matchedTaskId) || other.matchedTaskId == matchedTaskId)&&(identical(other.estimateMinutes, estimateMinutes) || other.estimateMinutes == estimateMinutes)&&(identical(other.timeAnchor, timeAnchor) || other.timeAnchor == timeAnchor)&&(identical(other.proposedUpdate, proposedUpdate) || other.proposedUpdate == proposedUpdate)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,captureId,kind,title,categoryId,confidence,confidenceScore,createdAt,vectorClock,lowConfidence,spokenPhrase,matchedTaskId,estimateMinutes,timeAnchor,proposedUpdate,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.parsedItem(id: $id, agentId: $agentId, captureId: $captureId, kind: $kind, title: $title, categoryId: $categoryId, confidence: $confidence, confidenceScore: $confidenceScore, createdAt: $createdAt, vectorClock: $vectorClock, lowConfidence: $lowConfidence, spokenPhrase: $spokenPhrase, matchedTaskId: $matchedTaskId, estimateMinutes: $estimateMinutes, timeAnchor: $timeAnchor, proposedUpdate: $proposedUpdate, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $ParsedItemEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $ParsedItemEntityCopyWith(ParsedItemEntity value, $Res Function(ParsedItemEntity) _then) = _$ParsedItemEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String captureId, ParsedItemKind kind, String title, String categoryId, ParsedItemConfidence confidence, double confidenceScore, DateTime createdAt, VectorClock? vectorClock, bool lowConfidence, String? spokenPhrase, String? matchedTaskId, int? estimateMinutes, String? timeAnchor, String? proposedUpdate, DateTime? deletedAt
});




}
/// @nodoc
class _$ParsedItemEntityCopyWithImpl<$Res>
    implements $ParsedItemEntityCopyWith<$Res> {
  _$ParsedItemEntityCopyWithImpl(this._self, this._then);

  final ParsedItemEntity _self;
  final $Res Function(ParsedItemEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? captureId = null,Object? kind = null,Object? title = null,Object? categoryId = null,Object? confidence = null,Object? confidenceScore = null,Object? createdAt = null,Object? vectorClock = freezed,Object? lowConfidence = null,Object? spokenPhrase = freezed,Object? matchedTaskId = freezed,Object? estimateMinutes = freezed,Object? timeAnchor = freezed,Object? proposedUpdate = freezed,Object? deletedAt = freezed,}) {
  return _then(ParsedItemEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,captureId: null == captureId ? _self.captureId : captureId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ParsedItemKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as ParsedItemConfidence,confidenceScore: null == confidenceScore ? _self.confidenceScore : confidenceScore // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,lowConfidence: null == lowConfidence ? _self.lowConfidence : lowConfidence // ignore: cast_nullable_to_non_nullable
as bool,spokenPhrase: freezed == spokenPhrase ? _self.spokenPhrase : spokenPhrase // ignore: cast_nullable_to_non_nullable
as String?,matchedTaskId: freezed == matchedTaskId ? _self.matchedTaskId : matchedTaskId // ignore: cast_nullable_to_non_nullable
as String?,estimateMinutes: freezed == estimateMinutes ? _self.estimateMinutes : estimateMinutes // ignore: cast_nullable_to_non_nullable
as int?,timeAnchor: freezed == timeAnchor ? _self.timeAnchor : timeAnchor // ignore: cast_nullable_to_non_nullable
as String?,proposedUpdate: freezed == proposedUpdate ? _self.proposedUpdate : proposedUpdate // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class DayPlanEntity implements AgentDomainEntity {
  const DayPlanEntity({required this.id, required this.agentId, required this.dayId, required this.planDate, required this.data, required this.createdAt, required this.updatedAt, required this.vectorClock, this.captureId, final  List<DayAgentEnergyBand> energyBands = const [], this.capacityMinutes = 480, this.scheduledMinutes = 0, this.deletedAt, final  String? $type}): _energyBands = energyBands,$type = $type ?? 'dayPlan';
  factory DayPlanEntity.fromJson(Map<String, dynamic> json) => _$DayPlanEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String dayId;
 final  DateTime planDate;
 final  DayPlanData data;
 final  DateTime createdAt;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
 final  String? captureId;
 final  List<DayAgentEnergyBand> _energyBands;
@JsonKey() List<DayAgentEnergyBand> get energyBands {
  if (_energyBands is EqualUnmodifiableListView) return _energyBands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_energyBands);
}

@JsonKey() final  int capacityMinutes;
@JsonKey() final  int scheduledMinutes;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayPlanEntityCopyWith<DayPlanEntity> get copyWith => _$DayPlanEntityCopyWithImpl<DayPlanEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DayPlanEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DayPlanEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.planDate, planDate) || other.planDate == planDate)&&(identical(other.data, data) || other.data == data)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.captureId, captureId) || other.captureId == captureId)&&const DeepCollectionEquality().equals(other._energyBands, _energyBands)&&(identical(other.capacityMinutes, capacityMinutes) || other.capacityMinutes == capacityMinutes)&&(identical(other.scheduledMinutes, scheduledMinutes) || other.scheduledMinutes == scheduledMinutes)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,dayId,planDate,data,createdAt,updatedAt,vectorClock,captureId,const DeepCollectionEquality().hash(_energyBands),capacityMinutes,scheduledMinutes,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.dayPlan(id: $id, agentId: $agentId, dayId: $dayId, planDate: $planDate, data: $data, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, captureId: $captureId, energyBands: $energyBands, capacityMinutes: $capacityMinutes, scheduledMinutes: $scheduledMinutes, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $DayPlanEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $DayPlanEntityCopyWith(DayPlanEntity value, $Res Function(DayPlanEntity) _then) = _$DayPlanEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String dayId, DateTime planDate, DayPlanData data, DateTime createdAt, DateTime updatedAt, VectorClock? vectorClock, String? captureId, List<DayAgentEnergyBand> energyBands, int capacityMinutes, int scheduledMinutes, DateTime? deletedAt
});


$DayPlanDataCopyWith<$Res> get data;

}
/// @nodoc
class _$DayPlanEntityCopyWithImpl<$Res>
    implements $DayPlanEntityCopyWith<$Res> {
  _$DayPlanEntityCopyWithImpl(this._self, this._then);

  final DayPlanEntity _self;
  final $Res Function(DayPlanEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? dayId = null,Object? planDate = null,Object? data = null,Object? createdAt = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? captureId = freezed,Object? energyBands = null,Object? capacityMinutes = null,Object? scheduledMinutes = null,Object? deletedAt = freezed,}) {
  return _then(DayPlanEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,dayId: null == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String,planDate: null == planDate ? _self.planDate : planDate // ignore: cast_nullable_to_non_nullable
as DateTime,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DayPlanData,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,captureId: freezed == captureId ? _self.captureId : captureId // ignore: cast_nullable_to_non_nullable
as String?,energyBands: null == energyBands ? _self._energyBands : energyBands // ignore: cast_nullable_to_non_nullable
as List<DayAgentEnergyBand>,capacityMinutes: null == capacityMinutes ? _self.capacityMinutes : capacityMinutes // ignore: cast_nullable_to_non_nullable
as int,scheduledMinutes: null == scheduledMinutes ? _self.scheduledMinutes : scheduledMinutes // ignore: cast_nullable_to_non_nullable
as int,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DayPlanDataCopyWith<$Res> get data {
  
  return $DayPlanDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class AttentionRequestEntity implements AgentDomainEntity {
  const AttentionRequestEntity({required this.id, required this.agentId, required this.kind, required this.title, required this.categoryId, required this.requestedMinutes, required this.impact, required this.urgency, required this.energyFit, required final  List<AttentionEvidenceRef> evidenceRefs, required this.createdAt, required this.vectorClock, this.scopeKind = AttentionClaimScopeKind.day, this.status = AttentionRequestStatus.pending, this.rangeStart, this.rangeEnd, this.earliestStart, this.latestEnd, this.deadline, this.nextReviewAt, this.targetId, this.targetKind, this.cadence, this.rationale, this.deletedAt, final  String? $type}): _evidenceRefs = evidenceRefs,$type = $type ?? 'attentionRequest';
  factory AttentionRequestEntity.fromJson(Map<String, dynamic> json) => _$AttentionRequestEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  AttentionRequestKind kind;
 final  String title;
 final  String categoryId;
 final  int requestedMinutes;
 final  int impact;
 final  int urgency;
 final  AttentionEnergyFit energyFit;
 final  List<AttentionEvidenceRef> _evidenceRefs;
 List<AttentionEvidenceRef> get evidenceRefs {
  if (_evidenceRefs is EqualUnmodifiableListView) return _evidenceRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_evidenceRefs);
}

 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
@JsonKey() final  AttentionClaimScopeKind scopeKind;
@JsonKey() final  AttentionRequestStatus status;
 final  DateTime? rangeStart;
 final  DateTime? rangeEnd;
 final  DateTime? earliestStart;
 final  DateTime? latestEnd;
 final  DateTime? deadline;
 final  DateTime? nextReviewAt;
 final  String? targetId;
 final  String? targetKind;
 final  String? cadence;
 final  String? rationale;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttentionRequestEntityCopyWith<AttentionRequestEntity> get copyWith => _$AttentionRequestEntityCopyWithImpl<AttentionRequestEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttentionRequestEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttentionRequestEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.title, title) || other.title == title)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.requestedMinutes, requestedMinutes) || other.requestedMinutes == requestedMinutes)&&(identical(other.impact, impact) || other.impact == impact)&&(identical(other.urgency, urgency) || other.urgency == urgency)&&(identical(other.energyFit, energyFit) || other.energyFit == energyFit)&&const DeepCollectionEquality().equals(other._evidenceRefs, _evidenceRefs)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.scopeKind, scopeKind) || other.scopeKind == scopeKind)&&(identical(other.status, status) || other.status == status)&&(identical(other.rangeStart, rangeStart) || other.rangeStart == rangeStart)&&(identical(other.rangeEnd, rangeEnd) || other.rangeEnd == rangeEnd)&&(identical(other.earliestStart, earliestStart) || other.earliestStart == earliestStart)&&(identical(other.latestEnd, latestEnd) || other.latestEnd == latestEnd)&&(identical(other.deadline, deadline) || other.deadline == deadline)&&(identical(other.nextReviewAt, nextReviewAt) || other.nextReviewAt == nextReviewAt)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.targetKind, targetKind) || other.targetKind == targetKind)&&(identical(other.cadence, cadence) || other.cadence == cadence)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,agentId,kind,title,categoryId,requestedMinutes,impact,urgency,energyFit,const DeepCollectionEquality().hash(_evidenceRefs),createdAt,vectorClock,scopeKind,status,rangeStart,rangeEnd,earliestStart,latestEnd,deadline,nextReviewAt,targetId,targetKind,cadence,rationale,deletedAt]);

@override
String toString() {
  return 'AgentDomainEntity.attentionRequest(id: $id, agentId: $agentId, kind: $kind, title: $title, categoryId: $categoryId, requestedMinutes: $requestedMinutes, impact: $impact, urgency: $urgency, energyFit: $energyFit, evidenceRefs: $evidenceRefs, createdAt: $createdAt, vectorClock: $vectorClock, scopeKind: $scopeKind, status: $status, rangeStart: $rangeStart, rangeEnd: $rangeEnd, earliestStart: $earliestStart, latestEnd: $latestEnd, deadline: $deadline, nextReviewAt: $nextReviewAt, targetId: $targetId, targetKind: $targetKind, cadence: $cadence, rationale: $rationale, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AttentionRequestEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AttentionRequestEntityCopyWith(AttentionRequestEntity value, $Res Function(AttentionRequestEntity) _then) = _$AttentionRequestEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, AttentionRequestKind kind, String title, String categoryId, int requestedMinutes, int impact, int urgency, AttentionEnergyFit energyFit, List<AttentionEvidenceRef> evidenceRefs, DateTime createdAt, VectorClock? vectorClock, AttentionClaimScopeKind scopeKind, AttentionRequestStatus status, DateTime? rangeStart, DateTime? rangeEnd, DateTime? earliestStart, DateTime? latestEnd, DateTime? deadline, DateTime? nextReviewAt, String? targetId, String? targetKind, String? cadence, String? rationale, DateTime? deletedAt
});




}
/// @nodoc
class _$AttentionRequestEntityCopyWithImpl<$Res>
    implements $AttentionRequestEntityCopyWith<$Res> {
  _$AttentionRequestEntityCopyWithImpl(this._self, this._then);

  final AttentionRequestEntity _self;
  final $Res Function(AttentionRequestEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? kind = null,Object? title = null,Object? categoryId = null,Object? requestedMinutes = null,Object? impact = null,Object? urgency = null,Object? energyFit = null,Object? evidenceRefs = null,Object? createdAt = null,Object? vectorClock = freezed,Object? scopeKind = null,Object? status = null,Object? rangeStart = freezed,Object? rangeEnd = freezed,Object? earliestStart = freezed,Object? latestEnd = freezed,Object? deadline = freezed,Object? nextReviewAt = freezed,Object? targetId = freezed,Object? targetKind = freezed,Object? cadence = freezed,Object? rationale = freezed,Object? deletedAt = freezed,}) {
  return _then(AttentionRequestEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AttentionRequestKind,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,requestedMinutes: null == requestedMinutes ? _self.requestedMinutes : requestedMinutes // ignore: cast_nullable_to_non_nullable
as int,impact: null == impact ? _self.impact : impact // ignore: cast_nullable_to_non_nullable
as int,urgency: null == urgency ? _self.urgency : urgency // ignore: cast_nullable_to_non_nullable
as int,energyFit: null == energyFit ? _self.energyFit : energyFit // ignore: cast_nullable_to_non_nullable
as AttentionEnergyFit,evidenceRefs: null == evidenceRefs ? _self._evidenceRefs : evidenceRefs // ignore: cast_nullable_to_non_nullable
as List<AttentionEvidenceRef>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,scopeKind: null == scopeKind ? _self.scopeKind : scopeKind // ignore: cast_nullable_to_non_nullable
as AttentionClaimScopeKind,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AttentionRequestStatus,rangeStart: freezed == rangeStart ? _self.rangeStart : rangeStart // ignore: cast_nullable_to_non_nullable
as DateTime?,rangeEnd: freezed == rangeEnd ? _self.rangeEnd : rangeEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,earliestStart: freezed == earliestStart ? _self.earliestStart : earliestStart // ignore: cast_nullable_to_non_nullable
as DateTime?,latestEnd: freezed == latestEnd ? _self.latestEnd : latestEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,deadline: freezed == deadline ? _self.deadline : deadline // ignore: cast_nullable_to_non_nullable
as DateTime?,nextReviewAt: freezed == nextReviewAt ? _self.nextReviewAt : nextReviewAt // ignore: cast_nullable_to_non_nullable
as DateTime?,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,targetKind: freezed == targetKind ? _self.targetKind : targetKind // ignore: cast_nullable_to_non_nullable
as String?,cadence: freezed == cadence ? _self.cadence : cadence // ignore: cast_nullable_to_non_nullable
as String?,rationale: freezed == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AttentionClaimDispositionEntity implements AgentDomainEntity {
  const AttentionClaimDispositionEntity({required this.id, required this.agentId, required this.requestId, required this.status, required this.createdAt, required this.vectorClock, this.awardId, this.planId, this.changeSetId, this.reason, this.nextReviewAt, this.deletedAt, final  String? $type}): $type = $type ?? 'attentionClaimDisposition';
  factory AttentionClaimDispositionEntity.fromJson(Map<String, dynamic> json) => _$AttentionClaimDispositionEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String requestId;
 final  AttentionClaimStatus status;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  String? awardId;
 final  String? planId;
 final  String? changeSetId;
 final  String? reason;
 final  DateTime? nextReviewAt;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttentionClaimDispositionEntityCopyWith<AttentionClaimDispositionEntity> get copyWith => _$AttentionClaimDispositionEntityCopyWithImpl<AttentionClaimDispositionEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttentionClaimDispositionEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttentionClaimDispositionEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.awardId, awardId) || other.awardId == awardId)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.changeSetId, changeSetId) || other.changeSetId == changeSetId)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.nextReviewAt, nextReviewAt) || other.nextReviewAt == nextReviewAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,requestId,status,createdAt,vectorClock,awardId,planId,changeSetId,reason,nextReviewAt,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.attentionClaimDisposition(id: $id, agentId: $agentId, requestId: $requestId, status: $status, createdAt: $createdAt, vectorClock: $vectorClock, awardId: $awardId, planId: $planId, changeSetId: $changeSetId, reason: $reason, nextReviewAt: $nextReviewAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AttentionClaimDispositionEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AttentionClaimDispositionEntityCopyWith(AttentionClaimDispositionEntity value, $Res Function(AttentionClaimDispositionEntity) _then) = _$AttentionClaimDispositionEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String requestId, AttentionClaimStatus status, DateTime createdAt, VectorClock? vectorClock, String? awardId, String? planId, String? changeSetId, String? reason, DateTime? nextReviewAt, DateTime? deletedAt
});




}
/// @nodoc
class _$AttentionClaimDispositionEntityCopyWithImpl<$Res>
    implements $AttentionClaimDispositionEntityCopyWith<$Res> {
  _$AttentionClaimDispositionEntityCopyWithImpl(this._self, this._then);

  final AttentionClaimDispositionEntity _self;
  final $Res Function(AttentionClaimDispositionEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? requestId = null,Object? status = null,Object? createdAt = null,Object? vectorClock = freezed,Object? awardId = freezed,Object? planId = freezed,Object? changeSetId = freezed,Object? reason = freezed,Object? nextReviewAt = freezed,Object? deletedAt = freezed,}) {
  return _then(AttentionClaimDispositionEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AttentionClaimStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,awardId: freezed == awardId ? _self.awardId : awardId // ignore: cast_nullable_to_non_nullable
as String?,planId: freezed == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String?,changeSetId: freezed == changeSetId ? _self.changeSetId : changeSetId // ignore: cast_nullable_to_non_nullable
as String?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,nextReviewAt: freezed == nextReviewAt ? _self.nextReviewAt : nextReviewAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AttentionAwardEntity implements AgentDomainEntity {
  const AttentionAwardEntity({required this.id, required this.agentId, required this.requestId, required this.dayId, required this.planId, required this.blockId, required this.categoryId, required this.title, required this.startTime, required this.endTime, required this.rank, required this.utilityScore, required this.createdAt, required this.vectorClock, this.status = AttentionAwardStatus.proposed, this.taskId, this.rationale, this.deletedAt, final  String? $type}): $type = $type ?? 'attentionAward';
  factory AttentionAwardEntity.fromJson(Map<String, dynamic> json) => _$AttentionAwardEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String requestId;
 final  String dayId;
 final  String planId;
 final  String blockId;
 final  String categoryId;
 final  String title;
 final  DateTime startTime;
 final  DateTime endTime;
 final  int rank;
 final  int utilityScore;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
@JsonKey() final  AttentionAwardStatus status;
 final  String? taskId;
 final  String? rationale;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttentionAwardEntityCopyWith<AttentionAwardEntity> get copyWith => _$AttentionAwardEntityCopyWithImpl<AttentionAwardEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttentionAwardEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttentionAwardEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.blockId, blockId) || other.blockId == blockId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.title, title) || other.title == title)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.utilityScore, utilityScore) || other.utilityScore == utilityScore)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.status, status) || other.status == status)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,requestId,dayId,planId,blockId,categoryId,title,startTime,endTime,rank,utilityScore,createdAt,vectorClock,status,taskId,rationale,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.attentionAward(id: $id, agentId: $agentId, requestId: $requestId, dayId: $dayId, planId: $planId, blockId: $blockId, categoryId: $categoryId, title: $title, startTime: $startTime, endTime: $endTime, rank: $rank, utilityScore: $utilityScore, createdAt: $createdAt, vectorClock: $vectorClock, status: $status, taskId: $taskId, rationale: $rationale, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AttentionAwardEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AttentionAwardEntityCopyWith(AttentionAwardEntity value, $Res Function(AttentionAwardEntity) _then) = _$AttentionAwardEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String requestId, String dayId, String planId, String blockId, String categoryId, String title, DateTime startTime, DateTime endTime, int rank, int utilityScore, DateTime createdAt, VectorClock? vectorClock, AttentionAwardStatus status, String? taskId, String? rationale, DateTime? deletedAt
});




}
/// @nodoc
class _$AttentionAwardEntityCopyWithImpl<$Res>
    implements $AttentionAwardEntityCopyWith<$Res> {
  _$AttentionAwardEntityCopyWithImpl(this._self, this._then);

  final AttentionAwardEntity _self;
  final $Res Function(AttentionAwardEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? requestId = null,Object? dayId = null,Object? planId = null,Object? blockId = null,Object? categoryId = null,Object? title = null,Object? startTime = null,Object? endTime = null,Object? rank = null,Object? utilityScore = null,Object? createdAt = null,Object? vectorClock = freezed,Object? status = null,Object? taskId = freezed,Object? rationale = freezed,Object? deletedAt = freezed,}) {
  return _then(AttentionAwardEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,dayId: null == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,blockId: null == blockId ? _self.blockId : blockId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,utilityScore: null == utilityScore ? _self.utilityScore : utilityScore // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AttentionAwardStatus,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,rationale: freezed == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class StandingAgreementEntity implements AgentDomainEntity {
  const StandingAgreementEntity({required this.id, required this.agentId, required this.title, required this.scope, required this.cadence, required this.createdAt, required this.updatedAt, required this.vectorClock, this.status = StandingAgreementStatus.active, this.enforcement = StandingAgreementEnforcement.target, this.approvalMode = StandingAgreementApprovalMode.ask, this.categoryId, this.targetId, this.targetKind, this.customScope, this.customCadence, this.minCount, this.maxCount, this.minMinutes, this.maxMinutes, this.preferredSessionMinutes, this.canPreempt = false, this.priority = 0, final  List<String> preemptibleCategoryIds = const [], final  List<String> protectedCategoryIds = const [], final  List<AttentionEvidenceRef> evidenceRefs = const [], this.activeFrom, this.activeUntil, this.rationale, this.deletedAt, final  String? $type}): _preemptibleCategoryIds = preemptibleCategoryIds,_protectedCategoryIds = protectedCategoryIds,_evidenceRefs = evidenceRefs,$type = $type ?? 'standingAgreement';
  factory StandingAgreementEntity.fromJson(Map<String, dynamic> json) => _$StandingAgreementEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String title;
 final  StandingAgreementScope scope;
 final  StandingAgreementCadence cadence;
 final  DateTime createdAt;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
@JsonKey() final  StandingAgreementStatus status;
@JsonKey() final  StandingAgreementEnforcement enforcement;
@JsonKey() final  StandingAgreementApprovalMode approvalMode;
 final  String? categoryId;
 final  String? targetId;
 final  String? targetKind;
 final  String? customScope;
 final  String? customCadence;
 final  int? minCount;
 final  int? maxCount;
 final  int? minMinutes;
 final  int? maxMinutes;
 final  int? preferredSessionMinutes;
@JsonKey() final  bool canPreempt;
@JsonKey() final  int priority;
 final  List<String> _preemptibleCategoryIds;
@JsonKey() List<String> get preemptibleCategoryIds {
  if (_preemptibleCategoryIds is EqualUnmodifiableListView) return _preemptibleCategoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_preemptibleCategoryIds);
}

 final  List<String> _protectedCategoryIds;
@JsonKey() List<String> get protectedCategoryIds {
  if (_protectedCategoryIds is EqualUnmodifiableListView) return _protectedCategoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_protectedCategoryIds);
}

 final  List<AttentionEvidenceRef> _evidenceRefs;
@JsonKey() List<AttentionEvidenceRef> get evidenceRefs {
  if (_evidenceRefs is EqualUnmodifiableListView) return _evidenceRefs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_evidenceRefs);
}

 final  DateTime? activeFrom;
 final  DateTime? activeUntil;
 final  String? rationale;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StandingAgreementEntityCopyWith<StandingAgreementEntity> get copyWith => _$StandingAgreementEntityCopyWithImpl<StandingAgreementEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StandingAgreementEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StandingAgreementEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.title, title) || other.title == title)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.cadence, cadence) || other.cadence == cadence)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.status, status) || other.status == status)&&(identical(other.enforcement, enforcement) || other.enforcement == enforcement)&&(identical(other.approvalMode, approvalMode) || other.approvalMode == approvalMode)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.targetKind, targetKind) || other.targetKind == targetKind)&&(identical(other.customScope, customScope) || other.customScope == customScope)&&(identical(other.customCadence, customCadence) || other.customCadence == customCadence)&&(identical(other.minCount, minCount) || other.minCount == minCount)&&(identical(other.maxCount, maxCount) || other.maxCount == maxCount)&&(identical(other.minMinutes, minMinutes) || other.minMinutes == minMinutes)&&(identical(other.maxMinutes, maxMinutes) || other.maxMinutes == maxMinutes)&&(identical(other.preferredSessionMinutes, preferredSessionMinutes) || other.preferredSessionMinutes == preferredSessionMinutes)&&(identical(other.canPreempt, canPreempt) || other.canPreempt == canPreempt)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other._preemptibleCategoryIds, _preemptibleCategoryIds)&&const DeepCollectionEquality().equals(other._protectedCategoryIds, _protectedCategoryIds)&&const DeepCollectionEquality().equals(other._evidenceRefs, _evidenceRefs)&&(identical(other.activeFrom, activeFrom) || other.activeFrom == activeFrom)&&(identical(other.activeUntil, activeUntil) || other.activeUntil == activeUntil)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,agentId,title,scope,cadence,createdAt,updatedAt,vectorClock,status,enforcement,approvalMode,categoryId,targetId,targetKind,customScope,customCadence,minCount,maxCount,minMinutes,maxMinutes,preferredSessionMinutes,canPreempt,priority,const DeepCollectionEquality().hash(_preemptibleCategoryIds),const DeepCollectionEquality().hash(_protectedCategoryIds),const DeepCollectionEquality().hash(_evidenceRefs),activeFrom,activeUntil,rationale,deletedAt]);

@override
String toString() {
  return 'AgentDomainEntity.standingAgreement(id: $id, agentId: $agentId, title: $title, scope: $scope, cadence: $cadence, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, status: $status, enforcement: $enforcement, approvalMode: $approvalMode, categoryId: $categoryId, targetId: $targetId, targetKind: $targetKind, customScope: $customScope, customCadence: $customCadence, minCount: $minCount, maxCount: $maxCount, minMinutes: $minMinutes, maxMinutes: $maxMinutes, preferredSessionMinutes: $preferredSessionMinutes, canPreempt: $canPreempt, priority: $priority, preemptibleCategoryIds: $preemptibleCategoryIds, protectedCategoryIds: $protectedCategoryIds, evidenceRefs: $evidenceRefs, activeFrom: $activeFrom, activeUntil: $activeUntil, rationale: $rationale, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $StandingAgreementEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $StandingAgreementEntityCopyWith(StandingAgreementEntity value, $Res Function(StandingAgreementEntity) _then) = _$StandingAgreementEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String title, StandingAgreementScope scope, StandingAgreementCadence cadence, DateTime createdAt, DateTime updatedAt, VectorClock? vectorClock, StandingAgreementStatus status, StandingAgreementEnforcement enforcement, StandingAgreementApprovalMode approvalMode, String? categoryId, String? targetId, String? targetKind, String? customScope, String? customCadence, int? minCount, int? maxCount, int? minMinutes, int? maxMinutes, int? preferredSessionMinutes, bool canPreempt, int priority, List<String> preemptibleCategoryIds, List<String> protectedCategoryIds, List<AttentionEvidenceRef> evidenceRefs, DateTime? activeFrom, DateTime? activeUntil, String? rationale, DateTime? deletedAt
});




}
/// @nodoc
class _$StandingAgreementEntityCopyWithImpl<$Res>
    implements $StandingAgreementEntityCopyWith<$Res> {
  _$StandingAgreementEntityCopyWithImpl(this._self, this._then);

  final StandingAgreementEntity _self;
  final $Res Function(StandingAgreementEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? title = null,Object? scope = null,Object? cadence = null,Object? createdAt = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? status = null,Object? enforcement = null,Object? approvalMode = null,Object? categoryId = freezed,Object? targetId = freezed,Object? targetKind = freezed,Object? customScope = freezed,Object? customCadence = freezed,Object? minCount = freezed,Object? maxCount = freezed,Object? minMinutes = freezed,Object? maxMinutes = freezed,Object? preferredSessionMinutes = freezed,Object? canPreempt = null,Object? priority = null,Object? preemptibleCategoryIds = null,Object? protectedCategoryIds = null,Object? evidenceRefs = null,Object? activeFrom = freezed,Object? activeUntil = freezed,Object? rationale = freezed,Object? deletedAt = freezed,}) {
  return _then(StandingAgreementEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as StandingAgreementScope,cadence: null == cadence ? _self.cadence : cadence // ignore: cast_nullable_to_non_nullable
as StandingAgreementCadence,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as StandingAgreementStatus,enforcement: null == enforcement ? _self.enforcement : enforcement // ignore: cast_nullable_to_non_nullable
as StandingAgreementEnforcement,approvalMode: null == approvalMode ? _self.approvalMode : approvalMode // ignore: cast_nullable_to_non_nullable
as StandingAgreementApprovalMode,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,targetId: freezed == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String?,targetKind: freezed == targetKind ? _self.targetKind : targetKind // ignore: cast_nullable_to_non_nullable
as String?,customScope: freezed == customScope ? _self.customScope : customScope // ignore: cast_nullable_to_non_nullable
as String?,customCadence: freezed == customCadence ? _self.customCadence : customCadence // ignore: cast_nullable_to_non_nullable
as String?,minCount: freezed == minCount ? _self.minCount : minCount // ignore: cast_nullable_to_non_nullable
as int?,maxCount: freezed == maxCount ? _self.maxCount : maxCount // ignore: cast_nullable_to_non_nullable
as int?,minMinutes: freezed == minMinutes ? _self.minMinutes : minMinutes // ignore: cast_nullable_to_non_nullable
as int?,maxMinutes: freezed == maxMinutes ? _self.maxMinutes : maxMinutes // ignore: cast_nullable_to_non_nullable
as int?,preferredSessionMinutes: freezed == preferredSessionMinutes ? _self.preferredSessionMinutes : preferredSessionMinutes // ignore: cast_nullable_to_non_nullable
as int?,canPreempt: null == canPreempt ? _self.canPreempt : canPreempt // ignore: cast_nullable_to_non_nullable
as bool,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,preemptibleCategoryIds: null == preemptibleCategoryIds ? _self._preemptibleCategoryIds : preemptibleCategoryIds // ignore: cast_nullable_to_non_nullable
as List<String>,protectedCategoryIds: null == protectedCategoryIds ? _self._protectedCategoryIds : protectedCategoryIds // ignore: cast_nullable_to_non_nullable
as List<String>,evidenceRefs: null == evidenceRefs ? _self._evidenceRefs : evidenceRefs // ignore: cast_nullable_to_non_nullable
as List<AttentionEvidenceRef>,activeFrom: freezed == activeFrom ? _self.activeFrom : activeFrom // ignore: cast_nullable_to_non_nullable
as DateTime?,activeUntil: freezed == activeUntil ? _self.activeUntil : activeUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,rationale: freezed == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AgentTemplateEntity implements AgentDomainEntity {
  const AgentTemplateEntity({required this.id, required this.agentId, required this.displayName, required this.kind, required this.modelId, required final  Set<String> categoryIds, required this.createdAt, required this.updatedAt, required this.vectorClock, this.profileId, this.deletedAt, final  String? $type}): _categoryIds = categoryIds,$type = $type ?? 'agentTemplate';
  factory AgentTemplateEntity.fromJson(Map<String, dynamic> json) => _$AgentTemplateEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String displayName;
 final  AgentTemplateKind kind;
 final  String modelId;
 final  Set<String> _categoryIds;
 Set<String> get categoryIds {
  if (_categoryIds is EqualUnmodifiableSetView) return _categoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_categoryIds);
}

 final  DateTime createdAt;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
 final  String? profileId;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentTemplateEntityCopyWith<AgentTemplateEntity> get copyWith => _$AgentTemplateEntityCopyWithImpl<AgentTemplateEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentTemplateEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentTemplateEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&const DeepCollectionEquality().equals(other._categoryIds, _categoryIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,displayName,kind,modelId,const DeepCollectionEquality().hash(_categoryIds),createdAt,updatedAt,vectorClock,profileId,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.agentTemplate(id: $id, agentId: $agentId, displayName: $displayName, kind: $kind, modelId: $modelId, categoryIds: $categoryIds, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, profileId: $profileId, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentTemplateEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentTemplateEntityCopyWith(AgentTemplateEntity value, $Res Function(AgentTemplateEntity) _then) = _$AgentTemplateEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String displayName, AgentTemplateKind kind, String modelId, Set<String> categoryIds, DateTime createdAt, DateTime updatedAt, VectorClock? vectorClock, String? profileId, DateTime? deletedAt
});




}
/// @nodoc
class _$AgentTemplateEntityCopyWithImpl<$Res>
    implements $AgentTemplateEntityCopyWith<$Res> {
  _$AgentTemplateEntityCopyWithImpl(this._self, this._then);

  final AgentTemplateEntity _self;
  final $Res Function(AgentTemplateEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? displayName = null,Object? kind = null,Object? modelId = null,Object? categoryIds = null,Object? createdAt = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? profileId = freezed,Object? deletedAt = freezed,}) {
  return _then(AgentTemplateEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AgentTemplateKind,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,categoryIds: null == categoryIds ? _self._categoryIds : categoryIds // ignore: cast_nullable_to_non_nullable
as Set<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AgentTemplateVersionEntity implements AgentDomainEntity {
  const AgentTemplateVersionEntity({required this.id, required this.agentId, required this.version, required this.status, required this.directives, required this.authoredBy, required this.createdAt, required this.vectorClock, this.generalDirective = '', this.reportDirective = '', this.modelId, this.profileId, this.deletedAt, final  String? $type}): $type = $type ?? 'agentTemplateVersion';
  factory AgentTemplateVersionEntity.fromJson(Map<String, dynamic> json) => _$AgentTemplateVersionEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  int version;
 final  AgentTemplateVersionStatus status;
 final  String directives;
 final  String authoredBy;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
/// The agent's mission: persona, available tools, and overall objective.
@JsonKey() final  String generalDirective;
/// How the agent should structure its output report.
@JsonKey() final  String reportDirective;
/// The model ID configured on the template when this version was created.
 final  String? modelId;
/// The profile ID configured on the template when this version was created.
 final  String? profileId;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentTemplateVersionEntityCopyWith<AgentTemplateVersionEntity> get copyWith => _$AgentTemplateVersionEntityCopyWithImpl<AgentTemplateVersionEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentTemplateVersionEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentTemplateVersionEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.version, version) || other.version == version)&&(identical(other.status, status) || other.status == status)&&(identical(other.directives, directives) || other.directives == directives)&&(identical(other.authoredBy, authoredBy) || other.authoredBy == authoredBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.generalDirective, generalDirective) || other.generalDirective == generalDirective)&&(identical(other.reportDirective, reportDirective) || other.reportDirective == reportDirective)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,version,status,directives,authoredBy,createdAt,vectorClock,generalDirective,reportDirective,modelId,profileId,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.agentTemplateVersion(id: $id, agentId: $agentId, version: $version, status: $status, directives: $directives, authoredBy: $authoredBy, createdAt: $createdAt, vectorClock: $vectorClock, generalDirective: $generalDirective, reportDirective: $reportDirective, modelId: $modelId, profileId: $profileId, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentTemplateVersionEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentTemplateVersionEntityCopyWith(AgentTemplateVersionEntity value, $Res Function(AgentTemplateVersionEntity) _then) = _$AgentTemplateVersionEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, int version, AgentTemplateVersionStatus status, String directives, String authoredBy, DateTime createdAt, VectorClock? vectorClock, String generalDirective, String reportDirective, String? modelId, String? profileId, DateTime? deletedAt
});




}
/// @nodoc
class _$AgentTemplateVersionEntityCopyWithImpl<$Res>
    implements $AgentTemplateVersionEntityCopyWith<$Res> {
  _$AgentTemplateVersionEntityCopyWithImpl(this._self, this._then);

  final AgentTemplateVersionEntity _self;
  final $Res Function(AgentTemplateVersionEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? version = null,Object? status = null,Object? directives = null,Object? authoredBy = null,Object? createdAt = null,Object? vectorClock = freezed,Object? generalDirective = null,Object? reportDirective = null,Object? modelId = freezed,Object? profileId = freezed,Object? deletedAt = freezed,}) {
  return _then(AgentTemplateVersionEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AgentTemplateVersionStatus,directives: null == directives ? _self.directives : directives // ignore: cast_nullable_to_non_nullable
as String,authoredBy: null == authoredBy ? _self.authoredBy : authoredBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,generalDirective: null == generalDirective ? _self.generalDirective : generalDirective // ignore: cast_nullable_to_non_nullable
as String,reportDirective: null == reportDirective ? _self.reportDirective : reportDirective // ignore: cast_nullable_to_non_nullable
as String,modelId: freezed == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String?,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AgentTemplateHeadEntity implements AgentDomainEntity {
  const AgentTemplateHeadEntity({required this.id, required this.agentId, required this.versionId, required this.updatedAt, required this.vectorClock, this.deletedAt, final  String? $type}): $type = $type ?? 'agentTemplateHead';
  factory AgentTemplateHeadEntity.fromJson(Map<String, dynamic> json) => _$AgentTemplateHeadEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String versionId;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentTemplateHeadEntityCopyWith<AgentTemplateHeadEntity> get copyWith => _$AgentTemplateHeadEntityCopyWithImpl<AgentTemplateHeadEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentTemplateHeadEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentTemplateHeadEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,versionId,updatedAt,vectorClock,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.agentTemplateHead(id: $id, agentId: $agentId, versionId: $versionId, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentTemplateHeadEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentTemplateHeadEntityCopyWith(AgentTemplateHeadEntity value, $Res Function(AgentTemplateHeadEntity) _then) = _$AgentTemplateHeadEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String versionId, DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt
});




}
/// @nodoc
class _$AgentTemplateHeadEntityCopyWithImpl<$Res>
    implements $AgentTemplateHeadEntityCopyWith<$Res> {
  _$AgentTemplateHeadEntityCopyWithImpl(this._self, this._then);

  final AgentTemplateHeadEntity _self;
  final $Res Function(AgentTemplateHeadEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? versionId = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? deletedAt = freezed,}) {
  return _then(AgentTemplateHeadEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class EvolutionSessionEntity implements AgentDomainEntity {
  const EvolutionSessionEntity({required this.id, required this.agentId, required this.templateId, required this.sessionNumber, required this.status, required this.createdAt, required this.updatedAt, required this.vectorClock, this.proposedVersionId, this.proposedSoulVersionId, this.feedbackSummary, this.userRating, this.completedAt, this.deletedAt, final  String? $type}): $type = $type ?? 'evolutionSession';
  factory EvolutionSessionEntity.fromJson(Map<String, dynamic> json) => _$EvolutionSessionEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String templateId;
 final  int sessionNumber;
 final  EvolutionSessionStatus status;
 final  DateTime createdAt;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
 final  String? proposedVersionId;
 final  String? proposedSoulVersionId;
 final  String? feedbackSummary;
 final  double? userRating;
 final  DateTime? completedAt;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EvolutionSessionEntityCopyWith<EvolutionSessionEntity> get copyWith => _$EvolutionSessionEntityCopyWithImpl<EvolutionSessionEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EvolutionSessionEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EvolutionSessionEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.sessionNumber, sessionNumber) || other.sessionNumber == sessionNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.proposedVersionId, proposedVersionId) || other.proposedVersionId == proposedVersionId)&&(identical(other.proposedSoulVersionId, proposedSoulVersionId) || other.proposedSoulVersionId == proposedSoulVersionId)&&(identical(other.feedbackSummary, feedbackSummary) || other.feedbackSummary == feedbackSummary)&&(identical(other.userRating, userRating) || other.userRating == userRating)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,templateId,sessionNumber,status,createdAt,updatedAt,vectorClock,proposedVersionId,proposedSoulVersionId,feedbackSummary,userRating,completedAt,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.evolutionSession(id: $id, agentId: $agentId, templateId: $templateId, sessionNumber: $sessionNumber, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, proposedVersionId: $proposedVersionId, proposedSoulVersionId: $proposedSoulVersionId, feedbackSummary: $feedbackSummary, userRating: $userRating, completedAt: $completedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $EvolutionSessionEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $EvolutionSessionEntityCopyWith(EvolutionSessionEntity value, $Res Function(EvolutionSessionEntity) _then) = _$EvolutionSessionEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String templateId, int sessionNumber, EvolutionSessionStatus status, DateTime createdAt, DateTime updatedAt, VectorClock? vectorClock, String? proposedVersionId, String? proposedSoulVersionId, String? feedbackSummary, double? userRating, DateTime? completedAt, DateTime? deletedAt
});




}
/// @nodoc
class _$EvolutionSessionEntityCopyWithImpl<$Res>
    implements $EvolutionSessionEntityCopyWith<$Res> {
  _$EvolutionSessionEntityCopyWithImpl(this._self, this._then);

  final EvolutionSessionEntity _self;
  final $Res Function(EvolutionSessionEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? templateId = null,Object? sessionNumber = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? proposedVersionId = freezed,Object? proposedSoulVersionId = freezed,Object? feedbackSummary = freezed,Object? userRating = freezed,Object? completedAt = freezed,Object? deletedAt = freezed,}) {
  return _then(EvolutionSessionEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,sessionNumber: null == sessionNumber ? _self.sessionNumber : sessionNumber // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EvolutionSessionStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,proposedVersionId: freezed == proposedVersionId ? _self.proposedVersionId : proposedVersionId // ignore: cast_nullable_to_non_nullable
as String?,proposedSoulVersionId: freezed == proposedSoulVersionId ? _self.proposedSoulVersionId : proposedSoulVersionId // ignore: cast_nullable_to_non_nullable
as String?,feedbackSummary: freezed == feedbackSummary ? _self.feedbackSummary : feedbackSummary // ignore: cast_nullable_to_non_nullable
as String?,userRating: freezed == userRating ? _self.userRating : userRating // ignore: cast_nullable_to_non_nullable
as double?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class EvolutionSessionRecapEntity implements AgentDomainEntity {
  const EvolutionSessionRecapEntity({required this.id, required this.agentId, required this.sessionId, required this.createdAt, required this.vectorClock, required this.tldr, required this.recapMarkdown, final  Map<String, int> categoryRatings = const {}, final  List<Map<String, String>> transcript = const <Map<String, String>>[], this.approvedChangeSummary, this.deletedAt, final  String? $type}): _categoryRatings = categoryRatings,_transcript = transcript,$type = $type ?? 'evolutionSessionRecap';
  factory EvolutionSessionRecapEntity.fromJson(Map<String, dynamic> json) => _$EvolutionSessionRecapEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String sessionId;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  String tldr;
 final  String recapMarkdown;
 final  Map<String, int> _categoryRatings;
@JsonKey() Map<String, int> get categoryRatings {
  if (_categoryRatings is EqualUnmodifiableMapView) return _categoryRatings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_categoryRatings);
}

 final  List<Map<String, String>> _transcript;
@JsonKey() List<Map<String, String>> get transcript {
  if (_transcript is EqualUnmodifiableListView) return _transcript;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transcript);
}

 final  String? approvedChangeSummary;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EvolutionSessionRecapEntityCopyWith<EvolutionSessionRecapEntity> get copyWith => _$EvolutionSessionRecapEntityCopyWithImpl<EvolutionSessionRecapEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EvolutionSessionRecapEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EvolutionSessionRecapEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.tldr, tldr) || other.tldr == tldr)&&(identical(other.recapMarkdown, recapMarkdown) || other.recapMarkdown == recapMarkdown)&&const DeepCollectionEquality().equals(other._categoryRatings, _categoryRatings)&&const DeepCollectionEquality().equals(other._transcript, _transcript)&&(identical(other.approvedChangeSummary, approvedChangeSummary) || other.approvedChangeSummary == approvedChangeSummary)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,sessionId,createdAt,vectorClock,tldr,recapMarkdown,const DeepCollectionEquality().hash(_categoryRatings),const DeepCollectionEquality().hash(_transcript),approvedChangeSummary,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.evolutionSessionRecap(id: $id, agentId: $agentId, sessionId: $sessionId, createdAt: $createdAt, vectorClock: $vectorClock, tldr: $tldr, recapMarkdown: $recapMarkdown, categoryRatings: $categoryRatings, transcript: $transcript, approvedChangeSummary: $approvedChangeSummary, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $EvolutionSessionRecapEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $EvolutionSessionRecapEntityCopyWith(EvolutionSessionRecapEntity value, $Res Function(EvolutionSessionRecapEntity) _then) = _$EvolutionSessionRecapEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String sessionId, DateTime createdAt, VectorClock? vectorClock, String tldr, String recapMarkdown, Map<String, int> categoryRatings, List<Map<String, String>> transcript, String? approvedChangeSummary, DateTime? deletedAt
});




}
/// @nodoc
class _$EvolutionSessionRecapEntityCopyWithImpl<$Res>
    implements $EvolutionSessionRecapEntityCopyWith<$Res> {
  _$EvolutionSessionRecapEntityCopyWithImpl(this._self, this._then);

  final EvolutionSessionRecapEntity _self;
  final $Res Function(EvolutionSessionRecapEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? sessionId = null,Object? createdAt = null,Object? vectorClock = freezed,Object? tldr = null,Object? recapMarkdown = null,Object? categoryRatings = null,Object? transcript = null,Object? approvedChangeSummary = freezed,Object? deletedAt = freezed,}) {
  return _then(EvolutionSessionRecapEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,tldr: null == tldr ? _self.tldr : tldr // ignore: cast_nullable_to_non_nullable
as String,recapMarkdown: null == recapMarkdown ? _self.recapMarkdown : recapMarkdown // ignore: cast_nullable_to_non_nullable
as String,categoryRatings: null == categoryRatings ? _self._categoryRatings : categoryRatings // ignore: cast_nullable_to_non_nullable
as Map<String, int>,transcript: null == transcript ? _self._transcript : transcript // ignore: cast_nullable_to_non_nullable
as List<Map<String, String>>,approvedChangeSummary: freezed == approvedChangeSummary ? _self.approvedChangeSummary : approvedChangeSummary // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class EvolutionNoteEntity implements AgentDomainEntity {
  const EvolutionNoteEntity({required this.id, required this.agentId, required this.sessionId, required this.kind, required this.createdAt, required this.vectorClock, required this.content, this.deletedAt, final  String? $type}): $type = $type ?? 'evolutionNote';
  factory EvolutionNoteEntity.fromJson(Map<String, dynamic> json) => _$EvolutionNoteEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String sessionId;
 final  EvolutionNoteKind kind;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  String content;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EvolutionNoteEntityCopyWith<EvolutionNoteEntity> get copyWith => _$EvolutionNoteEntityCopyWithImpl<EvolutionNoteEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EvolutionNoteEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EvolutionNoteEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.content, content) || other.content == content)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,sessionId,kind,createdAt,vectorClock,content,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.evolutionNote(id: $id, agentId: $agentId, sessionId: $sessionId, kind: $kind, createdAt: $createdAt, vectorClock: $vectorClock, content: $content, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $EvolutionNoteEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $EvolutionNoteEntityCopyWith(EvolutionNoteEntity value, $Res Function(EvolutionNoteEntity) _then) = _$EvolutionNoteEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String sessionId, EvolutionNoteKind kind, DateTime createdAt, VectorClock? vectorClock, String content, DateTime? deletedAt
});




}
/// @nodoc
class _$EvolutionNoteEntityCopyWithImpl<$Res>
    implements $EvolutionNoteEntityCopyWith<$Res> {
  _$EvolutionNoteEntityCopyWithImpl(this._self, this._then);

  final EvolutionNoteEntity _self;
  final $Res Function(EvolutionNoteEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? sessionId = null,Object? kind = null,Object? createdAt = null,Object? vectorClock = freezed,Object? content = null,Object? deletedAt = freezed,}) {
  return _then(EvolutionNoteEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as EvolutionNoteKind,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ChangeSetEntity implements AgentDomainEntity {
  const ChangeSetEntity({required this.id, required this.agentId, required this.taskId, required this.threadId, required this.runKey, required this.status, required final  List<ChangeItem> items, required this.createdAt, required this.vectorClock, this.resolvedAt, this.deletedAt, final  String? $type}): _items = items,$type = $type ?? 'changeSet';
  factory ChangeSetEntity.fromJson(Map<String, dynamic> json) => _$ChangeSetEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String taskId;
 final  String threadId;
 final  String runKey;
 final  ChangeSetStatus status;
 final  List<ChangeItem> _items;
 List<ChangeItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  DateTime? resolvedAt;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeSetEntityCopyWith<ChangeSetEntity> get copyWith => _$ChangeSetEntityCopyWithImpl<ChangeSetEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChangeSetEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeSetEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.runKey, runKey) || other.runKey == runKey)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,taskId,threadId,runKey,status,const DeepCollectionEquality().hash(_items),createdAt,vectorClock,resolvedAt,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.changeSet(id: $id, agentId: $agentId, taskId: $taskId, threadId: $threadId, runKey: $runKey, status: $status, items: $items, createdAt: $createdAt, vectorClock: $vectorClock, resolvedAt: $resolvedAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $ChangeSetEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $ChangeSetEntityCopyWith(ChangeSetEntity value, $Res Function(ChangeSetEntity) _then) = _$ChangeSetEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String taskId, String threadId, String runKey, ChangeSetStatus status, List<ChangeItem> items, DateTime createdAt, VectorClock? vectorClock, DateTime? resolvedAt, DateTime? deletedAt
});




}
/// @nodoc
class _$ChangeSetEntityCopyWithImpl<$Res>
    implements $ChangeSetEntityCopyWith<$Res> {
  _$ChangeSetEntityCopyWithImpl(this._self, this._then);

  final ChangeSetEntity _self;
  final $Res Function(ChangeSetEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? taskId = null,Object? threadId = null,Object? runKey = null,Object? status = null,Object? items = null,Object? createdAt = null,Object? vectorClock = freezed,Object? resolvedAt = freezed,Object? deletedAt = freezed,}) {
  return _then(ChangeSetEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,taskId: null == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String,threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,runKey: null == runKey ? _self.runKey : runKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChangeSetStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ChangeItem>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ChangeDecisionEntity implements AgentDomainEntity {
  const ChangeDecisionEntity({required this.id, required this.agentId, required this.changeSetId, required this.itemIndex, required this.toolName, required this.verdict, required this.createdAt, required this.vectorClock, this.actor = DecisionActor.user, this.taskId, this.rejectionReason, this.retractionReason, this.humanSummary, final  Map<String, dynamic>? args, this.deletedAt, final  String? $type}): _args = args,$type = $type ?? 'changeDecision';
  factory ChangeDecisionEntity.fromJson(Map<String, dynamic> json) => _$ChangeDecisionEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String changeSetId;
 final  int itemIndex;
 final  String toolName;
 final  ChangeDecisionVerdict verdict;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
/// Who recorded this decision. Defaults to [DecisionActor.user] so
/// pre-existing rows (which did not store this field) deserialize as
/// user decisions — which is what they all were before the agent
/// gained the ability to retract its own proposals.
@JsonKey() final  DecisionActor actor;
 final  String? taskId;
/// Free-text reason a *user* supplied when rejecting a proposal.
/// Only populated when `verdict` is `ChangeDecisionVerdict.rejected`
/// and `actor` is `DecisionActor.user`. Kept separate from
/// `retractionReason` so feedback-extraction heuristics that treat
/// this text as a user signal are not polluted by agent self-talk.
 final  String? rejectionReason;
/// Free-text reason the *agent* supplied when retracting its own
/// proposal. Only populated when `verdict` is
/// `ChangeDecisionVerdict.retracted` and `actor` is
/// `DecisionActor.agent`.
 final  String? retractionReason;
/// Human-readable summary of the change item (e.g., 'Check off: "Buy
/// milk"'). Stored at decision time so the agent can see *what* was
/// confirmed or rejected, not just the tool name.
 final  String? humanSummary;
/// The original tool-call arguments, stored so that rejection fingerprints
/// can be reconstructed even after the parent change set is resolved.
 final  Map<String, dynamic>? _args;
/// The original tool-call arguments, stored so that rejection fingerprints
/// can be reconstructed even after the parent change set is resolved.
 Map<String, dynamic>? get args {
  final value = _args;
  if (value == null) return null;
  if (_args is EqualUnmodifiableMapView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChangeDecisionEntityCopyWith<ChangeDecisionEntity> get copyWith => _$ChangeDecisionEntityCopyWithImpl<ChangeDecisionEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChangeDecisionEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChangeDecisionEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.changeSetId, changeSetId) || other.changeSetId == changeSetId)&&(identical(other.itemIndex, itemIndex) || other.itemIndex == itemIndex)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.verdict, verdict) || other.verdict == verdict)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.actor, actor) || other.actor == actor)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.rejectionReason, rejectionReason) || other.rejectionReason == rejectionReason)&&(identical(other.retractionReason, retractionReason) || other.retractionReason == retractionReason)&&(identical(other.humanSummary, humanSummary) || other.humanSummary == humanSummary)&&const DeepCollectionEquality().equals(other._args, _args)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,changeSetId,itemIndex,toolName,verdict,createdAt,vectorClock,actor,taskId,rejectionReason,retractionReason,humanSummary,const DeepCollectionEquality().hash(_args),deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.changeDecision(id: $id, agentId: $agentId, changeSetId: $changeSetId, itemIndex: $itemIndex, toolName: $toolName, verdict: $verdict, createdAt: $createdAt, vectorClock: $vectorClock, actor: $actor, taskId: $taskId, rejectionReason: $rejectionReason, retractionReason: $retractionReason, humanSummary: $humanSummary, args: $args, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $ChangeDecisionEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $ChangeDecisionEntityCopyWith(ChangeDecisionEntity value, $Res Function(ChangeDecisionEntity) _then) = _$ChangeDecisionEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String changeSetId, int itemIndex, String toolName, ChangeDecisionVerdict verdict, DateTime createdAt, VectorClock? vectorClock, DecisionActor actor, String? taskId, String? rejectionReason, String? retractionReason, String? humanSummary, Map<String, dynamic>? args, DateTime? deletedAt
});




}
/// @nodoc
class _$ChangeDecisionEntityCopyWithImpl<$Res>
    implements $ChangeDecisionEntityCopyWith<$Res> {
  _$ChangeDecisionEntityCopyWithImpl(this._self, this._then);

  final ChangeDecisionEntity _self;
  final $Res Function(ChangeDecisionEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? changeSetId = null,Object? itemIndex = null,Object? toolName = null,Object? verdict = null,Object? createdAt = null,Object? vectorClock = freezed,Object? actor = null,Object? taskId = freezed,Object? rejectionReason = freezed,Object? retractionReason = freezed,Object? humanSummary = freezed,Object? args = freezed,Object? deletedAt = freezed,}) {
  return _then(ChangeDecisionEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,changeSetId: null == changeSetId ? _self.changeSetId : changeSetId // ignore: cast_nullable_to_non_nullable
as String,itemIndex: null == itemIndex ? _self.itemIndex : itemIndex // ignore: cast_nullable_to_non_nullable
as int,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,verdict: null == verdict ? _self.verdict : verdict // ignore: cast_nullable_to_non_nullable
as ChangeDecisionVerdict,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,actor: null == actor ? _self.actor : actor // ignore: cast_nullable_to_non_nullable
as DecisionActor,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,rejectionReason: freezed == rejectionReason ? _self.rejectionReason : rejectionReason // ignore: cast_nullable_to_non_nullable
as String?,retractionReason: freezed == retractionReason ? _self.retractionReason : retractionReason // ignore: cast_nullable_to_non_nullable
as String?,humanSummary: freezed == humanSummary ? _self.humanSummary : humanSummary // ignore: cast_nullable_to_non_nullable
as String?,args: freezed == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ProjectRecommendationEntity implements AgentDomainEntity {
  const ProjectRecommendationEntity({required this.id, required this.agentId, required this.projectId, required this.title, required this.position, required this.status, required this.createdAt, required this.updatedAt, required this.vectorClock, this.sourceChangeSetId, this.sourceDecisionId, this.rationale, this.priority, this.resolvedAt, this.dismissedAt, this.supersededAt, this.deletedAt, final  String? $type}): $type = $type ?? 'projectRecommendation';
  factory ProjectRecommendationEntity.fromJson(Map<String, dynamic> json) => _$ProjectRecommendationEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String projectId;
 final  String title;
 final  int position;
 final  ProjectRecommendationStatus status;
 final  DateTime createdAt;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
 final  String? sourceChangeSetId;
 final  String? sourceDecisionId;
 final  String? rationale;
 final  String? priority;
 final  DateTime? resolvedAt;
 final  DateTime? dismissedAt;
 final  DateTime? supersededAt;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectRecommendationEntityCopyWith<ProjectRecommendationEntity> get copyWith => _$ProjectRecommendationEntityCopyWithImpl<ProjectRecommendationEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectRecommendationEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectRecommendationEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.title, title) || other.title == title)&&(identical(other.position, position) || other.position == position)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.sourceChangeSetId, sourceChangeSetId) || other.sourceChangeSetId == sourceChangeSetId)&&(identical(other.sourceDecisionId, sourceDecisionId) || other.sourceDecisionId == sourceDecisionId)&&(identical(other.rationale, rationale) || other.rationale == rationale)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.dismissedAt, dismissedAt) || other.dismissedAt == dismissedAt)&&(identical(other.supersededAt, supersededAt) || other.supersededAt == supersededAt)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,projectId,title,position,status,createdAt,updatedAt,vectorClock,sourceChangeSetId,sourceDecisionId,rationale,priority,resolvedAt,dismissedAt,supersededAt,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.projectRecommendation(id: $id, agentId: $agentId, projectId: $projectId, title: $title, position: $position, status: $status, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, sourceChangeSetId: $sourceChangeSetId, sourceDecisionId: $sourceDecisionId, rationale: $rationale, priority: $priority, resolvedAt: $resolvedAt, dismissedAt: $dismissedAt, supersededAt: $supersededAt, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $ProjectRecommendationEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $ProjectRecommendationEntityCopyWith(ProjectRecommendationEntity value, $Res Function(ProjectRecommendationEntity) _then) = _$ProjectRecommendationEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String projectId, String title, int position, ProjectRecommendationStatus status, DateTime createdAt, DateTime updatedAt, VectorClock? vectorClock, String? sourceChangeSetId, String? sourceDecisionId, String? rationale, String? priority, DateTime? resolvedAt, DateTime? dismissedAt, DateTime? supersededAt, DateTime? deletedAt
});




}
/// @nodoc
class _$ProjectRecommendationEntityCopyWithImpl<$Res>
    implements $ProjectRecommendationEntityCopyWith<$Res> {
  _$ProjectRecommendationEntityCopyWithImpl(this._self, this._then);

  final ProjectRecommendationEntity _self;
  final $Res Function(ProjectRecommendationEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? projectId = null,Object? title = null,Object? position = null,Object? status = null,Object? createdAt = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? sourceChangeSetId = freezed,Object? sourceDecisionId = freezed,Object? rationale = freezed,Object? priority = freezed,Object? resolvedAt = freezed,Object? dismissedAt = freezed,Object? supersededAt = freezed,Object? deletedAt = freezed,}) {
  return _then(ProjectRecommendationEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProjectRecommendationStatus,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,sourceChangeSetId: freezed == sourceChangeSetId ? _self.sourceChangeSetId : sourceChangeSetId // ignore: cast_nullable_to_non_nullable
as String?,sourceDecisionId: freezed == sourceDecisionId ? _self.sourceDecisionId : sourceDecisionId // ignore: cast_nullable_to_non_nullable
as String?,rationale: freezed == rationale ? _self.rationale : rationale // ignore: cast_nullable_to_non_nullable
as String?,priority: freezed == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String?,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dismissedAt: freezed == dismissedAt ? _self.dismissedAt : dismissedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,supersededAt: freezed == supersededAt ? _self.supersededAt : supersededAt // ignore: cast_nullable_to_non_nullable
as DateTime?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class WakeTokenUsageEntity implements AgentDomainEntity {
  const WakeTokenUsageEntity({required this.id, required this.agentId, required this.runKey, required this.threadId, required this.modelId, required this.createdAt, required this.vectorClock, this.templateId, this.templateVersionId, this.soulDocumentId, this.soulDocumentVersionId, this.inputTokens, this.outputTokens, this.thoughtsTokens, this.cachedInputTokens, this.deletedAt, final  String? $type}): $type = $type ?? 'wakeTokenUsage';
  factory WakeTokenUsageEntity.fromJson(Map<String, dynamic> json) => _$WakeTokenUsageEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String runKey;
 final  String threadId;
 final  String modelId;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
 final  String? templateId;
 final  String? templateVersionId;
 final  String? soulDocumentId;
 final  String? soulDocumentVersionId;
 final  int? inputTokens;
 final  int? outputTokens;
 final  int? thoughtsTokens;
 final  int? cachedInputTokens;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WakeTokenUsageEntityCopyWith<WakeTokenUsageEntity> get copyWith => _$WakeTokenUsageEntityCopyWithImpl<WakeTokenUsageEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WakeTokenUsageEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WakeTokenUsageEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.runKey, runKey) || other.runKey == runKey)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.templateId, templateId) || other.templateId == templateId)&&(identical(other.templateVersionId, templateVersionId) || other.templateVersionId == templateVersionId)&&(identical(other.soulDocumentId, soulDocumentId) || other.soulDocumentId == soulDocumentId)&&(identical(other.soulDocumentVersionId, soulDocumentVersionId) || other.soulDocumentVersionId == soulDocumentVersionId)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.thoughtsTokens, thoughtsTokens) || other.thoughtsTokens == thoughtsTokens)&&(identical(other.cachedInputTokens, cachedInputTokens) || other.cachedInputTokens == cachedInputTokens)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,runKey,threadId,modelId,createdAt,vectorClock,templateId,templateVersionId,soulDocumentId,soulDocumentVersionId,inputTokens,outputTokens,thoughtsTokens,cachedInputTokens,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.wakeTokenUsage(id: $id, agentId: $agentId, runKey: $runKey, threadId: $threadId, modelId: $modelId, createdAt: $createdAt, vectorClock: $vectorClock, templateId: $templateId, templateVersionId: $templateVersionId, soulDocumentId: $soulDocumentId, soulDocumentVersionId: $soulDocumentVersionId, inputTokens: $inputTokens, outputTokens: $outputTokens, thoughtsTokens: $thoughtsTokens, cachedInputTokens: $cachedInputTokens, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $WakeTokenUsageEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $WakeTokenUsageEntityCopyWith(WakeTokenUsageEntity value, $Res Function(WakeTokenUsageEntity) _then) = _$WakeTokenUsageEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String runKey, String threadId, String modelId, DateTime createdAt, VectorClock? vectorClock, String? templateId, String? templateVersionId, String? soulDocumentId, String? soulDocumentVersionId, int? inputTokens, int? outputTokens, int? thoughtsTokens, int? cachedInputTokens, DateTime? deletedAt
});




}
/// @nodoc
class _$WakeTokenUsageEntityCopyWithImpl<$Res>
    implements $WakeTokenUsageEntityCopyWith<$Res> {
  _$WakeTokenUsageEntityCopyWithImpl(this._self, this._then);

  final WakeTokenUsageEntity _self;
  final $Res Function(WakeTokenUsageEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? runKey = null,Object? threadId = null,Object? modelId = null,Object? createdAt = null,Object? vectorClock = freezed,Object? templateId = freezed,Object? templateVersionId = freezed,Object? soulDocumentId = freezed,Object? soulDocumentVersionId = freezed,Object? inputTokens = freezed,Object? outputTokens = freezed,Object? thoughtsTokens = freezed,Object? cachedInputTokens = freezed,Object? deletedAt = freezed,}) {
  return _then(WakeTokenUsageEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,runKey: null == runKey ? _self.runKey : runKey // ignore: cast_nullable_to_non_nullable
as String,threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,templateId: freezed == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String?,templateVersionId: freezed == templateVersionId ? _self.templateVersionId : templateVersionId // ignore: cast_nullable_to_non_nullable
as String?,soulDocumentId: freezed == soulDocumentId ? _self.soulDocumentId : soulDocumentId // ignore: cast_nullable_to_non_nullable
as String?,soulDocumentVersionId: freezed == soulDocumentVersionId ? _self.soulDocumentVersionId : soulDocumentVersionId // ignore: cast_nullable_to_non_nullable
as String?,inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int?,thoughtsTokens: freezed == thoughtsTokens ? _self.thoughtsTokens : thoughtsTokens // ignore: cast_nullable_to_non_nullable
as int?,cachedInputTokens: freezed == cachedInputTokens ? _self.cachedInputTokens : cachedInputTokens // ignore: cast_nullable_to_non_nullable
as int?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SoulDocumentEntity implements AgentDomainEntity {
  const SoulDocumentEntity({required this.id, required this.agentId, required this.displayName, required this.createdAt, required this.updatedAt, required this.vectorClock, this.deletedAt, final  String? $type}): $type = $type ?? 'soulDocument';
  factory SoulDocumentEntity.fromJson(Map<String, dynamic> json) => _$SoulDocumentEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String displayName;
 final  DateTime createdAt;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoulDocumentEntityCopyWith<SoulDocumentEntity> get copyWith => _$SoulDocumentEntityCopyWithImpl<SoulDocumentEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SoulDocumentEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoulDocumentEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,displayName,createdAt,updatedAt,vectorClock,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.soulDocument(id: $id, agentId: $agentId, displayName: $displayName, createdAt: $createdAt, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $SoulDocumentEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $SoulDocumentEntityCopyWith(SoulDocumentEntity value, $Res Function(SoulDocumentEntity) _then) = _$SoulDocumentEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String displayName, DateTime createdAt, DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt
});




}
/// @nodoc
class _$SoulDocumentEntityCopyWithImpl<$Res>
    implements $SoulDocumentEntityCopyWith<$Res> {
  _$SoulDocumentEntityCopyWithImpl(this._self, this._then);

  final SoulDocumentEntity _self;
  final $Res Function(SoulDocumentEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? displayName = null,Object? createdAt = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? deletedAt = freezed,}) {
  return _then(SoulDocumentEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SoulDocumentVersionEntity implements AgentDomainEntity {
  const SoulDocumentVersionEntity({required this.id, required this.agentId, required this.version, required this.status, required this.authoredBy, required this.createdAt, required this.vectorClock, required this.voiceDirective, this.toneBounds = '', this.coachingStyle = '', this.antiSycophancyPolicy = '', this.sourceSessionId, this.diffFromVersionId, this.deletedAt, final  String? $type}): $type = $type ?? 'soulDocumentVersion';
  factory SoulDocumentVersionEntity.fromJson(Map<String, dynamic> json) => _$SoulDocumentVersionEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  int version;
 final  SoulDocumentVersionStatus status;
 final  String authoredBy;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
/// Core personality: tone, warmth, humor, style, communication patterns.
 final  String voiceDirective;
/// Guardrails on voice — what the personality must never do.
@JsonKey() final  String toneBounds;
/// How the personality coaches, mentors, and motivates the user.
@JsonKey() final  String coachingStyle;
/// Directness contract — when to push back vs. comply.
@JsonKey() final  String antiSycophancyPolicy;
/// Evolution session that produced this version, if any.
 final  String? sourceSessionId;
/// Parent version for diff tracking.
 final  String? diffFromVersionId;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoulDocumentVersionEntityCopyWith<SoulDocumentVersionEntity> get copyWith => _$SoulDocumentVersionEntityCopyWithImpl<SoulDocumentVersionEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SoulDocumentVersionEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoulDocumentVersionEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.version, version) || other.version == version)&&(identical(other.status, status) || other.status == status)&&(identical(other.authoredBy, authoredBy) || other.authoredBy == authoredBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.voiceDirective, voiceDirective) || other.voiceDirective == voiceDirective)&&(identical(other.toneBounds, toneBounds) || other.toneBounds == toneBounds)&&(identical(other.coachingStyle, coachingStyle) || other.coachingStyle == coachingStyle)&&(identical(other.antiSycophancyPolicy, antiSycophancyPolicy) || other.antiSycophancyPolicy == antiSycophancyPolicy)&&(identical(other.sourceSessionId, sourceSessionId) || other.sourceSessionId == sourceSessionId)&&(identical(other.diffFromVersionId, diffFromVersionId) || other.diffFromVersionId == diffFromVersionId)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,version,status,authoredBy,createdAt,vectorClock,voiceDirective,toneBounds,coachingStyle,antiSycophancyPolicy,sourceSessionId,diffFromVersionId,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.soulDocumentVersion(id: $id, agentId: $agentId, version: $version, status: $status, authoredBy: $authoredBy, createdAt: $createdAt, vectorClock: $vectorClock, voiceDirective: $voiceDirective, toneBounds: $toneBounds, coachingStyle: $coachingStyle, antiSycophancyPolicy: $antiSycophancyPolicy, sourceSessionId: $sourceSessionId, diffFromVersionId: $diffFromVersionId, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $SoulDocumentVersionEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $SoulDocumentVersionEntityCopyWith(SoulDocumentVersionEntity value, $Res Function(SoulDocumentVersionEntity) _then) = _$SoulDocumentVersionEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, int version, SoulDocumentVersionStatus status, String authoredBy, DateTime createdAt, VectorClock? vectorClock, String voiceDirective, String toneBounds, String coachingStyle, String antiSycophancyPolicy, String? sourceSessionId, String? diffFromVersionId, DateTime? deletedAt
});




}
/// @nodoc
class _$SoulDocumentVersionEntityCopyWithImpl<$Res>
    implements $SoulDocumentVersionEntityCopyWith<$Res> {
  _$SoulDocumentVersionEntityCopyWithImpl(this._self, this._then);

  final SoulDocumentVersionEntity _self;
  final $Res Function(SoulDocumentVersionEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? version = null,Object? status = null,Object? authoredBy = null,Object? createdAt = null,Object? vectorClock = freezed,Object? voiceDirective = null,Object? toneBounds = null,Object? coachingStyle = null,Object? antiSycophancyPolicy = null,Object? sourceSessionId = freezed,Object? diffFromVersionId = freezed,Object? deletedAt = freezed,}) {
  return _then(SoulDocumentVersionEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SoulDocumentVersionStatus,authoredBy: null == authoredBy ? _self.authoredBy : authoredBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,voiceDirective: null == voiceDirective ? _self.voiceDirective : voiceDirective // ignore: cast_nullable_to_non_nullable
as String,toneBounds: null == toneBounds ? _self.toneBounds : toneBounds // ignore: cast_nullable_to_non_nullable
as String,coachingStyle: null == coachingStyle ? _self.coachingStyle : coachingStyle // ignore: cast_nullable_to_non_nullable
as String,antiSycophancyPolicy: null == antiSycophancyPolicy ? _self.antiSycophancyPolicy : antiSycophancyPolicy // ignore: cast_nullable_to_non_nullable
as String,sourceSessionId: freezed == sourceSessionId ? _self.sourceSessionId : sourceSessionId // ignore: cast_nullable_to_non_nullable
as String?,diffFromVersionId: freezed == diffFromVersionId ? _self.diffFromVersionId : diffFromVersionId // ignore: cast_nullable_to_non_nullable
as String?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class SoulDocumentHeadEntity implements AgentDomainEntity {
  const SoulDocumentHeadEntity({required this.id, required this.agentId, required this.versionId, required this.updatedAt, required this.vectorClock, this.deletedAt, final  String? $type}): $type = $type ?? 'soulDocumentHead';
  factory SoulDocumentHeadEntity.fromJson(Map<String, dynamic> json) => _$SoulDocumentHeadEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  String versionId;
 final  DateTime updatedAt;
@override final  VectorClock? vectorClock;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SoulDocumentHeadEntityCopyWith<SoulDocumentHeadEntity> get copyWith => _$SoulDocumentHeadEntityCopyWithImpl<SoulDocumentHeadEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SoulDocumentHeadEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SoulDocumentHeadEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.versionId, versionId) || other.versionId == versionId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,versionId,updatedAt,vectorClock,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.soulDocumentHead(id: $id, agentId: $agentId, versionId: $versionId, updatedAt: $updatedAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $SoulDocumentHeadEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $SoulDocumentHeadEntityCopyWith(SoulDocumentHeadEntity value, $Res Function(SoulDocumentHeadEntity) _then) = _$SoulDocumentHeadEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, String versionId, DateTime updatedAt, VectorClock? vectorClock, DateTime? deletedAt
});




}
/// @nodoc
class _$SoulDocumentHeadEntityCopyWithImpl<$Res>
    implements $SoulDocumentHeadEntityCopyWith<$Res> {
  _$SoulDocumentHeadEntityCopyWithImpl(this._self, this._then);

  final SoulDocumentHeadEntity _self;
  final $Res Function(SoulDocumentHeadEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? versionId = null,Object? updatedAt = null,Object? vectorClock = freezed,Object? deletedAt = freezed,}) {
  return _then(SoulDocumentHeadEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,versionId: null == versionId ? _self.versionId : versionId // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
@JsonSerializable()

class AgentUnknownEntity implements AgentDomainEntity {
  const AgentUnknownEntity({required this.id, required this.agentId, required this.createdAt, this.vectorClock, this.deletedAt, final  String? $type}): $type = $type ?? 'unknown';
  factory AgentUnknownEntity.fromJson(Map<String, dynamic> json) => _$AgentUnknownEntityFromJson(json);

@override final  String id;
@override final  String agentId;
 final  DateTime createdAt;
@override final  VectorClock? vectorClock;
@override final  DateTime? deletedAt;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentUnknownEntityCopyWith<AgentUnknownEntity> get copyWith => _$AgentUnknownEntityCopyWithImpl<AgentUnknownEntity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentUnknownEntityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentUnknownEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.agentId, agentId) || other.agentId == agentId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.vectorClock, vectorClock) || other.vectorClock == vectorClock)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,agentId,createdAt,vectorClock,deletedAt);

@override
String toString() {
  return 'AgentDomainEntity.unknown(id: $id, agentId: $agentId, createdAt: $createdAt, vectorClock: $vectorClock, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class $AgentUnknownEntityCopyWith<$Res> implements $AgentDomainEntityCopyWith<$Res> {
  factory $AgentUnknownEntityCopyWith(AgentUnknownEntity value, $Res Function(AgentUnknownEntity) _then) = _$AgentUnknownEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String agentId, DateTime createdAt, VectorClock? vectorClock, DateTime? deletedAt
});




}
/// @nodoc
class _$AgentUnknownEntityCopyWithImpl<$Res>
    implements $AgentUnknownEntityCopyWith<$Res> {
  _$AgentUnknownEntityCopyWithImpl(this._self, this._then);

  final AgentUnknownEntity _self;
  final $Res Function(AgentUnknownEntity) _then;

/// Create a copy of AgentDomainEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? agentId = null,Object? createdAt = null,Object? vectorClock = freezed,Object? deletedAt = freezed,}) {
  return _then(AgentUnknownEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentId: null == agentId ? _self.agentId : agentId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,vectorClock: freezed == vectorClock ? _self.vectorClock : vectorClock // ignore: cast_nullable_to_non_nullable
as VectorClock?,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
