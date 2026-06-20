import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

part 'sync_node_profile.freezed.dart';
part 'sync_node_profile.g.dart';

/// AI inference capabilities that a sync node advertises.
///
/// The mapping to [InferenceProviderType] is **explicit**, not by string
/// match — see [nodeCapabilityFromProviderType] and [NodeCapability.providerType].
/// `ollamaLlm` deliberately carries a semantic suffix because future Ollama
/// integrations (embeddings, image) may warrant separate capability tokens
/// without requiring a `NodeCapability.ollama` rename across stored snapshots.
/// `omlxLlm` follows the same pattern for the local OpenAI-compatible oMLX
/// runtime.
enum NodeCapability {
  mlxAudio,
  omlxLlm,
  ollamaLlm,
  voxtral,
  whisper;

  /// The inference-provider type this capability advertises support for.
  /// Used when filtering known nodes for a profile's pinning UI: a profile
  /// referencing `InferenceProviderType.ollama` is runnable on a node that
  /// advertises `NodeCapability.ollamaLlm`.
  InferenceProviderType get providerType {
    switch (this) {
      case NodeCapability.mlxAudio:
        return InferenceProviderType.mlxAudio;
      case NodeCapability.omlxLlm:
        return InferenceProviderType.omlx;
      case NodeCapability.ollamaLlm:
        return InferenceProviderType.ollama;
      case NodeCapability.voxtral:
        return InferenceProviderType.voxtral;
      case NodeCapability.whisper:
        return InferenceProviderType.whisper;
    }
  }
}

/// Resolves the [NodeCapability] that advertises support for [providerType],
/// or null when the provider is cloud-only (no node-capability token exists
/// for cloud providers — they don't need to be advertised).
NodeCapability? nodeCapabilityFromProviderType(
  InferenceProviderType providerType,
) {
  switch (providerType) {
    case InferenceProviderType.mlxAudio:
      return NodeCapability.mlxAudio;
    case InferenceProviderType.omlx:
      return NodeCapability.omlxLlm;
    case InferenceProviderType.ollama:
      return NodeCapability.ollamaLlm;
    case InferenceProviderType.voxtral:
      return NodeCapability.voxtral;
    case InferenceProviderType.whisper:
      return NodeCapability.whisper;
    case InferenceProviderType.alibaba:
    case InferenceProviderType.anthropic:
    case InferenceProviderType.gemini:
    case InferenceProviderType.genericOpenAi:
    case InferenceProviderType.mistral:
    case InferenceProviderType.nebiusAiStudio:
    case InferenceProviderType.openAi:
    case InferenceProviderType.openRouter:
      return null;
  }
}

/// A node's self-description published over Matrix.
///
/// Each device broadcasts its own profile on startup (and whenever the
/// detected capability set changes). Receivers store the latest snapshot per
/// `hostId` in a local directory, used by:
/// - the inference-profile pinning UI (to show "pin to which device?")
/// - the auto-trigger dispatcher (to decide whether the local node is the
///   pinned host for an incoming local-only audio entry).
///
/// `hostId` is the `VectorClockService` host UUID — the same identifier used
/// for `SyncMessage.originatingHostId` and `VectorClock` keys.
///
/// `updatedAt` is the broadcast timestamp; receivers compare it on upsert and
/// ignore older snapshots for the same `hostId`.
@freezed
abstract class SyncNodeProfile with _$SyncNodeProfile {
  const factory SyncNodeProfile({
    required String hostId,
    required String displayName,
    required String platform,
    required List<NodeCapability> capabilities,
    required DateTime updatedAt,
    String? osVersion,
    String? cpuModel,
    int? ramMb,
    String? gpuModel,
    String? appVersion,
  }) = _SyncNodeProfile;

  factory SyncNodeProfile.fromJson(Map<String, dynamic> json) =>
      _$SyncNodeProfileFromJson(json);
}
