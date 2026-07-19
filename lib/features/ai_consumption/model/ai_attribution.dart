import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'ai_attribution.freezed.dart';
part 'ai_attribution.g.dart';

/// Versioned key used when attribution is embedded in an agent report.
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
enum AiWorkStatus { succeeded, failed, cancelled, partial }

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

/// Typed target of an attribution.
enum AiArtifactType {
  journalEntry,
  journalAiResponse,
  journalImage,
  journalAudio,
  agentReport,
  agentMessage,
  embeddingVector,
}

/// Immutable creator identity snapshot retained with the attribution.
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

/// Stable typed reference to the output that carries an attribution.
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

/// Top-level audit record for one logical, user-visible piece of AI work.
///
/// Provider calls are stored separately as consumption events linked
/// by [id]. The generated output embeds this record and is authoritative; the
/// consumption database keeps a queryable projection.
@freezed
abstract class AiWorkAttribution with _$AiWorkAttribution {
  const factory AiWorkAttribution({
    required String id,
    required AiWorkType workType,
    required AiWorkStatus status,
    required AiActorSnapshot initiator,
    required AiTriggerSnapshot trigger,
    required DateTime startedAt,
    required DateTime completedAt,
    required VectorClock? vectorClock,
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

/// Lightweight in-memory state held while one logical operation is running.
///
/// This is deliberately not persisted. A provider call and its output each
/// remain independently durable, so no recovery state machine is required.
@freezed
abstract class AiAttributionSession with _$AiAttributionSession {
  const factory AiAttributionSession({
    required String id,
    required AiWorkType workType,
    required AiActorSnapshot initiator,
    required AiTriggerSnapshot trigger,
    required DateTime startedAt,
    @Default(<AiArtifactReference>[]) List<AiArtifactReference> intendedOutputs,
    String? parentAttributionId,
    String? taskId,
    String? categoryId,
  }) = _AiAttributionSession;

  factory AiAttributionSession.fromJson(Map<String, dynamic> json) =>
      _$AiAttributionSessionFromJson(json);
}
