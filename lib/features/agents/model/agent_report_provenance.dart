import 'package:collection/collection.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:meta/meta.dart';

/// Versioned key used inside a task-agent report's provenance map.
const taskAgentInferenceProvenanceKey = 'taskAgentInferenceV1';

/// The route that produced content, denormalized at wake start.
///
/// Display names are intentionally copied so historical attribution survives
/// later model/provider renames or deletion. Credentials and endpoint URLs are
/// never included.
@immutable
class InferenceRouteSnapshot {
  const InferenceRouteSnapshot({
    required this.providerModelId,
    required this.modelName,
    required this.servingProviderType,
    required this.servingProviderName,
    required this.runtimeSettings,
    this.modelConfigId,
    this.publisherName,
    this.servingProviderConfigId,
  });

  factory InferenceRouteSnapshot.fromResolvedProfile(
    ResolvedProfile profile,
  ) {
    final model = profile.thinkingModel;
    final provider = profile.thinkingProvider;
    return InferenceRouteSnapshot(
      modelConfigId: model?.id,
      providerModelId: profile.thinkingModelId,
      modelName: model?.name ?? profile.thinkingModelId,
      publisherName: model?.publisher,
      servingProviderConfigId: provider.id,
      servingProviderType: provider.inferenceProviderType,
      servingProviderName: provider.name,
      runtimeSettings: <String, Object?>{
        if (model != null) 'geminiThinkingMode': model.geminiThinkingMode.name,
      },
    );
  }

  factory InferenceRouteSnapshot.fromJson(Map<String, Object?> json) {
    return InferenceRouteSnapshot(
      modelConfigId: json['modelConfigId'] as String?,
      providerModelId: json['providerModelId']! as String,
      modelName: json['modelName']! as String,
      publisherName: json['publisherName'] as String?,
      servingProviderConfigId: json['servingProviderConfigId'] as String?,
      servingProviderType: InferenceProviderType.values.byName(
        json['servingProviderType']! as String,
      ),
      servingProviderName: json['servingProviderName']! as String,
      runtimeSettings: Map<String, Object?>.from(
        json['runtimeSettings']! as Map,
      ),
    );
  }

  final String? modelConfigId;
  final String providerModelId;
  final String modelName;
  final String? publisherName;
  final String? servingProviderConfigId;
  final InferenceProviderType servingProviderType;
  final String servingProviderName;
  final Map<String, Object?> runtimeSettings;

  InferenceRouteFingerprint get fingerprint => InferenceRouteFingerprint(
    modelConfigId: modelConfigId,
    providerModelId: providerModelId,
    providerConfigId: servingProviderConfigId,
    providerType: servingProviderType,
    runtimeSettings: runtimeSettings,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    if (modelConfigId != null) 'modelConfigId': modelConfigId,
    'providerModelId': providerModelId,
    'modelName': modelName,
    if (publisherName != null) 'publisherName': publisherName,
    if (servingProviderConfigId != null)
      'servingProviderConfigId': servingProviderConfigId,
    'servingProviderType': servingProviderType.name,
    'servingProviderName': servingProviderName,
    'runtimeSettings': runtimeSettings,
  };

  static const _mapEquality = MapEquality<String, Object?>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InferenceRouteSnapshot &&
          modelConfigId == other.modelConfigId &&
          providerModelId == other.providerModelId &&
          modelName == other.modelName &&
          publisherName == other.publisherName &&
          servingProviderConfigId == other.servingProviderConfigId &&
          servingProviderType == other.servingProviderType &&
          servingProviderName == other.servingProviderName &&
          _mapEquality.equals(runtimeSettings, other.runtimeSettings);

  @override
  int get hashCode => Object.hash(
    modelConfigId,
    providerModelId,
    modelName,
    publisherName,
    servingProviderConfigId,
    servingProviderType,
    servingProviderName,
    _mapEquality.hash(runtimeSettings),
  );
}

enum ReportFinalizerOutcome { accepted, rejected, failed }

enum ReportContentAuthor { executor, finalizer }

/// Immutable inference context captured once for a wake.
@immutable
class InferenceRunSnapshot {
  const InferenceRunSnapshot({
    required this.runKey,
    required this.threadId,
    required this.executor,
    this.setupSource,
    this.setupOrigin,
    this.profileId,
  });

  final String runKey;
  final String threadId;
  final AgentSetupResolutionSource? setupSource;
  final AgentInferenceSetupOrigin? setupOrigin;
  final String? profileId;
  final InferenceRouteSnapshot executor;
}

/// Typed v1 carrier stored under [taskAgentInferenceProvenanceKey].
@immutable
class ReportInferenceProvenance {
  const ReportInferenceProvenance({
    required this.runKey,
    required this.threadId,
    required this.executor,
    required this.finalContentAuthor,
    this.setupSource,
    this.setupOrigin,
    this.profileId,
    this.finalizer,
    this.finalizerOutcome,
  });

  factory ReportInferenceProvenance.executorOnly(
    InferenceRunSnapshot snapshot,
  ) {
    return ReportInferenceProvenance(
      runKey: snapshot.runKey,
      threadId: snapshot.threadId,
      setupSource: snapshot.setupSource,
      setupOrigin: snapshot.setupOrigin,
      profileId: snapshot.profileId,
      executor: snapshot.executor,
      finalContentAuthor: ReportContentAuthor.executor,
    );
  }

  factory ReportInferenceProvenance.fromJson(Map<String, Object?> json) {
    final finalizerJson = json['finalizer'];
    return ReportInferenceProvenance(
      runKey: json['runKey']! as String,
      threadId: json['threadId']! as String,
      setupSource: _enumByNameOrNull(
        AgentSetupResolutionSource.values,
        json['setupSource'],
      ),
      setupOrigin: _enumByNameOrNull(
        AgentInferenceSetupOrigin.values,
        json['setupOrigin'],
      ),
      profileId: json['profileId'] as String?,
      executor: InferenceRouteSnapshot.fromJson(
        Map<String, Object?>.from(json['executor']! as Map),
      ),
      finalizer: finalizerJson is Map
          ? InferenceRouteSnapshot.fromJson(
              Map<String, Object?>.from(finalizerJson),
            )
          : null,
      finalizerOutcome: _enumByNameOrNull(
        ReportFinalizerOutcome.values,
        json['finalizerOutcome'],
      ),
      finalContentAuthor:
          _enumByNameOrNull(
            ReportContentAuthor.values,
            json['finalContentAuthor'],
          ) ??
          ReportContentAuthor.executor,
    );
  }

  final String runKey;
  final String threadId;
  final AgentSetupResolutionSource? setupSource;
  final AgentInferenceSetupOrigin? setupOrigin;
  final String? profileId;
  final InferenceRouteSnapshot executor;
  final InferenceRouteSnapshot? finalizer;
  final ReportFinalizerOutcome? finalizerOutcome;
  final ReportContentAuthor finalContentAuthor;

  InferenceRouteSnapshot get finalAuthorRoute =>
      finalContentAuthor == ReportContentAuthor.finalizer && finalizer != null
      ? finalizer!
      : executor;

  Map<String, Object?> toJson() => <String, Object?>{
    'runKey': runKey,
    'threadId': threadId,
    if (setupSource != null) 'setupSource': setupSource!.name,
    if (setupOrigin != null) 'setupOrigin': setupOrigin!.name,
    if (profileId != null) 'profileId': profileId,
    'executor': executor.toJson(),
    if (finalizer != null) 'finalizer': finalizer!.toJson(),
    if (finalizerOutcome != null) 'finalizerOutcome': finalizerOutcome!.name,
    'finalContentAuthor': finalContentAuthor.name,
  };

  Map<String, Object?> toReportMap() => <String, Object?>{
    taskAgentInferenceProvenanceKey: toJson(),
  };

  static ReportInferenceProvenance? tryRead(Map<String, Object?> provenance) {
    final raw = provenance[taskAgentInferenceProvenanceKey];
    if (raw is! Map) return null;
    try {
      return ReportInferenceProvenance.fromJson(
        Map<String, Object?>.from(raw),
      );
    } on Object {
      return null;
    }
  }
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
