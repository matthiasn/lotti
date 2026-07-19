import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'ai_attribution.freezed.dart';
part 'ai_attribution.g.dart';

/// Versioned key used when a terminal envelope is embedded in an extensible
/// provenance map, such as an agent report's `provenance` field.
const aiAttributionProvenanceKey = 'aiAttributionV1';

/// The user-visible kind of AI work that was produced.
///
/// Persisted by enum name. Names are wire-format values and must not be
/// renamed without a migration.
enum AiWorkType {
  codingPrompt,
  textGeneration,
  imageGeneration,
  imageAnalysis,
  audioTranscription,
  agentReport,
  embeddingIndexing,
  internalInference,
}

/// Terminal outcome of one logical AI work operation.
enum AiWorkStatus { succeeded, failed, cancelled, abandoned, partial }

/// The kind of actor that initiated an AI work operation.
enum AiActorType { human, agent, automation, system }

/// Why an AI work operation started.
enum AiTriggerType {
  manual,
  automatic,
  scheduled,
  synced,
  agentTool,
  migration,
}

/// The backend operation performed by one interaction.
enum AiInteractionKind {
  chatCompletion,
  textGeneration,
  audioTranscription,
  realtimeTranscription,
  imageAnalysis,
  imageGeneration,
  embedding,
}

/// Terminal outcome of one backend interaction.
enum AiInteractionStatus { succeeded, failed, cancelled, partial }

/// How much request/response content was retained for an interaction.
enum AiPayloadCapturePolicy {
  fullText,
  referenceOnly,
  redacted,
  metadataOnly,
}

/// Strongest privacy classification inherited from interaction sources.
enum AiPrivacyClassification { standard, private, mixed, unknown }

/// Local publication-saga phase. Pending sessions are never synchronized.
enum AiAttributionPendingPhase {
  prepared,
  calling,
  evidenceDurable,
  evidencePublished,
  outputPersisted,
}

/// The normalized kind of one request/response content part.
enum AiContentPartType {
  text,
  toolCall,
  toolResult,
  attachmentReference,
  omitted,
}

/// How an attribution relates to an external artifact.
enum AiAttributionLinkRole { output, source, context }

/// Typed cross-database target of an attribution link.
enum AiArtifactType {
  journalEntry,
  journalAiResponse,
  journalImage,
  journalAudio,
  agentReport,
  agentMessage,
  embeddingVector,
}

/// Origin of one immutable cost assessment.
enum AiCostSource {
  externallyReconciled,
  providerReported,
  legacyReported,
  locallyEstimated,
  localCompute,
  unknown,
}

/// Immutable actor identity snapshot retained with the attribution.
@freezed
abstract class AiActorSnapshot with _$AiActorSnapshot {
  const factory AiActorSnapshot({
    required AiActorType type,
    required String id,
    required String displayName,
    String? humanPrincipalId,
  }) = _AiActorSnapshot;

  factory AiActorSnapshot.fromJson(Map<String, dynamic> json) =>
      _$AiActorSnapshotFromJson(json);
}

/// Immutable snapshot of why an AI operation started.
@freezed
abstract class AiTriggerSnapshot with _$AiTriggerSnapshot {
  const factory AiTriggerSnapshot({
    required AiTriggerType type,
    String? skillId,
    String? promptId,
    String? profileId,
    String? agentId,
    String? wakeRunKey,
    String? automationRuleId,
  }) = _AiTriggerSnapshot;

  factory AiTriggerSnapshot.fromJson(Map<String, dynamic> json) =>
      _$AiTriggerSnapshotFromJson(json);
}

/// Device/node identity snapshot for the host that executed the operation.
@freezed
abstract class AiExecutorSnapshot with _$AiExecutorSnapshot {
  const factory AiExecutorSnapshot({
    required String hostId,
    required String displayName,
    String? appVersion,
  }) = _AiExecutorSnapshot;

  factory AiExecutorSnapshot.fromJson(Map<String, dynamic> json) =>
      _$AiExecutorSnapshotFromJson(json);
}

/// Stable typed reference to an artifact outside the consumption database.
@freezed
abstract class AiArtifactReference with _$AiArtifactReference {
  const factory AiArtifactReference({
    required AiArtifactType type,
    required String id,
    String? subId,
  }) = _AiArtifactReference;

  factory AiArtifactReference.fromJson(Map<String, dynamic> json) =>
      _$AiArtifactReferenceFromJson(json);
}

/// One output/source/context relationship owned by an attribution.
@freezed
abstract class AiAttributionLink with _$AiAttributionLink {
  const factory AiAttributionLink({
    required String id,
    required String attributionId,
    required AiAttributionLinkRole role,
    required AiArtifactReference artifact,
    String? contentDigest,
  }) = _AiAttributionLink;

  factory AiAttributionLink.fromJson(Map<String, dynamic> json) =>
      _$AiAttributionLinkFromJson(json);
}

/// One normalized content part in a captured request or response envelope.
@freezed
abstract class AiContentPart with _$AiContentPart {
  const factory AiContentPart({
    required AiContentPartType type,
    String? text,
    String? name,
    Map<String, dynamic>? arguments,
    AiArtifactReference? attachment,
    String? mediaType,
    String? sha256,
    int? byteLength,
  }) = _AiContentPart;

  factory AiContentPart.fromJson(Map<String, dynamic> json) =>
      _$AiContentPartFromJson(json);
}

/// Normalized request/response evidence for a single backend interaction.
@freezed
abstract class AiInteractionPayload with _$AiInteractionPayload {
  const factory AiInteractionPayload({
    required String id,
    required String interactionId,
    required List<AiContentPart> request,
    required List<AiContentPart> response,
    required Map<String, dynamic> parameters,
    required String requestDigest,
    required String responseDigest,
    required AiPayloadCapturePolicy capturePolicy,
    required AiPrivacyClassification privacyClassification,
    required DateTime createdAt,
    Map<String, dynamic>? providerMetadata,
  }) = _AiInteractionPayload;

  factory AiInteractionPayload.fromJson(Map<String, dynamic> json) =>
      _$AiInteractionPayloadFromJson(json);
}

/// One immutable cost assessment for a backend interaction.
///
/// [originalAmountDecimal] preserves the provider unit while
/// [reportingAmountMicros] is the amount safe to aggregate in
/// [reportingCurrency]. A null amount with [AiCostSource.unknown] is distinct
/// from a known zero local-compute charge.
@freezed
abstract class AiInteractionCost with _$AiInteractionCost {
  const factory AiInteractionCost({
    required String id,
    required String interactionId,
    required AiCostSource source,
    required DateTime assessedAt,
    String? originalAmountDecimal,
    String? originalUnit,
    int? reportingAmountMicros,
    String? reportingCurrency,
    String? supersedesCostId,
    String? providerType,
    String? billingAccountKey,
    String? billingSource,
    String? externalRecordId,
    Map<String, dynamic>? pricingSnapshot,
  }) = _AiInteractionCost;

  factory AiInteractionCost.fromJson(Map<String, dynamic> json) =>
      _$AiInteractionCostFromJson(json);
}

/// Top-level audit record for one logical, user-visible piece of AI work.
///
/// The record is terminal and immutable. In-flight crash recovery uses a
/// separate local pending-session table; only terminal records are synced.
@freezed
abstract class AiWorkAttribution with _$AiWorkAttribution {
  const factory AiWorkAttribution({
    required String id,
    required AiWorkType workType,
    required AiWorkStatus status,
    required AiActorSnapshot initiator,
    required AiTriggerSnapshot trigger,
    required AiExecutorSnapshot executor,
    required AiPrivacyClassification privacyClassification,
    required DateTime startedAt,
    required DateTime completedAt,
    required VectorClock? vectorClock,
    required List<AiAttributionLink> links,
    String? parentAttributionId,
    String? taskId,
    String? categoryId,
    AiArtifactReference? primaryOutput,
    String? errorCode,
    String? errorSummary,
    @Default(1) int schemaVersion,
  }) = _AiWorkAttribution;

  factory AiWorkAttribution.fromJson(Map<String, dynamic> json) =>
      _$AiWorkAttributionFromJson(json);
}

/// Sanitized, sync-safe evidence persisted before an output is published.
///
/// It lets another device retain creator, trigger, intended-output, and
/// privacy facts when the executing device is permanently lost after provider
/// completion but before the journal/agent output is finalized.
@freezed
abstract class AiAttributionRecoveryCapsule
    with _$AiAttributionRecoveryCapsule {
  const factory AiAttributionRecoveryCapsule({
    required String id,
    required String attributionId,
    required AiWorkType workType,
    required AiActorSnapshot initiator,
    required AiTriggerSnapshot trigger,
    required AiExecutorSnapshot executor,
    required AiPrivacyClassification privacyClassification,
    required DateTime startedAt,
    required List<AiArtifactReference> intendedOutputs,
    @Default('sha256-v1') String digestAlgorithm,
    @Default(0) int omittedReferenceCount,
    String? parentAttributionId,
    String? taskId,
    String? categoryId,
    @Default(1) int schemaVersion,
  }) = _AiAttributionRecoveryCapsule;

  factory AiAttributionRecoveryCapsule.fromJson(Map<String, dynamic> json) =>
      _$AiAttributionRecoveryCapsuleFromJson(json);
}

/// Versioned terminal envelope stored on the generated output carrier.
@freezed
abstract class AiTerminalAttributionEnvelope
    with _$AiTerminalAttributionEnvelope {
  const factory AiTerminalAttributionEnvelope({
    required String id,
    required AiWorkAttribution attribution,
    @Default('sha256-v1') String digestAlgorithm,
    @Default(1) int schemaVersion,
  }) = _AiTerminalAttributionEnvelope;

  factory AiTerminalAttributionEnvelope.fromJson(Map<String, dynamic> json) =>
      _$AiTerminalAttributionEnvelopeFromJson(json);
}

/// Durable local state used to resume attribution publication after a crash.
@freezed
abstract class AiAttributionPendingSession with _$AiAttributionPendingSession {
  const factory AiAttributionPendingSession({
    required String id,
    required String attributionId,
    required AiWorkType workType,
    required AiActorSnapshot initiator,
    required AiTriggerSnapshot trigger,
    required AiExecutorSnapshot executor,
    required AiPrivacyClassification privacyClassification,
    required AiAttributionPendingPhase phase,
    required DateTime startedAt,
    required DateTime lastUpdatedAt,
    required List<AiArtifactReference> intendedOutputs,
    @Default(<AiArtifactReference>[]) List<AiArtifactReference> sourceArtifacts,
    @Default(<AiArtifactReference>[])
    List<AiArtifactReference> contextArtifacts,
    @Default(<String>[]) List<String> interactionIds,
    String? parentAttributionId,
    String? taskId,
    String? categoryId,
    String? terminalAttributionId,
    String? errorCode,
  }) = _AiAttributionPendingSession;

  factory AiAttributionPendingSession.fromJson(Map<String, dynamic> json) =>
      _$AiAttributionPendingSessionFromJson(json);
}
