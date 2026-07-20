import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:uuid/uuid.dart';

/// Provider usage values observed on a streamed response chunk.
class AiCapturedUsage {
  const AiCapturedUsage({
    this.inputTokens,
    this.outputTokens,
    this.cachedInputTokens,
    this.thoughtsTokens,
    this.totalTokens,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? cachedInputTokens;
  final int? thoughtsTokens;
  final int? totalTokens;
}

/// Ownership and causal fields stamped on each child interaction.
class AiCapturedContext {
  const AiCapturedContext({
    this.parentId,
    this.entryId,
    this.agentId,
    this.wakeRunKey,
    this.threadId,
    this.turnIndex,
    this.promptId,
    this.skillId,
    this.providerConfigId,
    this.modelConfigId,
  });

  final String? parentId;
  final String? entryId;
  final String? agentId;
  final String? wakeRunKey;
  final String? threadId;
  final int? turnIndex;
  final String? promptId;
  final String? skillId;
  final String? providerConfigId;
  final String? modelConfigId;
}

/// Central pre-call capture boundary for product inference funnels.
///
/// Carrier and carrier-less funnels use this boundary so every backend
/// invocation has a consumption event linked to its logical attribution.
class AiInteractionCapture {
  const AiInteractionCapture(
    this._attributionService,
    this._identityResolver, [
    this._uuid = const Uuid(),
  ]);

  final AiAttributionService _attributionService;
  final AiAttributionIdentityResolver _identityResolver;
  final Uuid _uuid;

  Stream<T> captureStream<T>({
    required AiWorkType workType,
    required AiInteractionKind interactionKind,
    required AiConsumptionResponseType responseType,
    required InferenceProviderType providerType,
    required String modelId,
    required String requestText,
    required Stream<T> Function() invoke,
    required String Function(T chunk) responseText,
    AiCapturedUsage? Function(T chunk)? usageForChunk,
    MeliousCallImpact? Function()? impact,
    AiCapturedContext? interactionContext,
    AiAttributionSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiTriggerType triggerType = AiTriggerType.manual,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    List<AiArtifactReference> intendedOutputs = const [],
    String? taskId,
    String? categoryId,
  }) async* {
    final startedAt = clock.now().toUtc();
    final pending =
        existingSession ??
        await beginSession(
          workType: workType,
          trigger: AiTriggerSnapshot(type: triggerType),
          initiator: initiator,
          automationId: automationId,
          automationDisplayName: automationDisplayName,
          attributionId: attributionId,
          intendedOutputs: intendedOutputs,
          taskId: taskId,
          categoryId: categoryId,
        );
    final response = StringBuffer();
    AiCapturedUsage? usage;
    var streamCompleted = false;
    var interactionRecorded = false;
    try {
      await for (final chunk in invoke()) {
        response.write(responseText(chunk));
        usage = usageForChunk?.call(chunk) ?? usage;
        yield chunk;
      }
      streamCompleted = true;
    } on Object catch (error) {
      interactionRecorded = true;
      try {
        await _finish(
          pending: pending,
          interactionKind: interactionKind,
          responseType: responseType,
          providerType: providerType,
          modelId: modelId,
          requestText: requestText,
          responseText: response.toString(),
          startedAt: startedAt,
          interactionStatus: AiInteractionStatus.failed,
          workStatus: AiWorkStatus.failed,
          taskId: taskId,
          categoryId: categoryId,
          errorCode: error.runtimeType.toString(),
          usage: usage,
          impact: impact?.call(),
          interactionContext: interactionContext,
          terminalize: terminalizeFailure,
        );
      } on Object {
        rethrow;
      }
      rethrow;
    } finally {
      if (!streamCompleted && !interactionRecorded) {
        await _finish(
          pending: pending,
          interactionKind: interactionKind,
          responseType: responseType,
          providerType: providerType,
          modelId: modelId,
          requestText: requestText,
          responseText: response.toString(),
          startedAt: startedAt,
          interactionStatus: AiInteractionStatus.cancelled,
          workStatus: AiWorkStatus.cancelled,
          taskId: taskId,
          categoryId: categoryId,
          errorCode: 'cancelled',
          usage: usage,
          impact: impact?.call(),
          interactionContext: interactionContext,
          terminalize: terminalizeFailure,
        );
      }
    }
    await _finish(
      pending: pending,
      interactionKind: interactionKind,
      responseType: responseType,
      providerType: providerType,
      modelId: modelId,
      requestText: requestText,
      responseText: response.toString(),
      startedAt: startedAt,
      interactionStatus: AiInteractionStatus.succeeded,
      workStatus: AiWorkStatus.partial,
      taskId: taskId,
      categoryId: categoryId,
      errorCode: 'output_carrier_unavailable',
      usage: usage,
      impact: impact?.call(),
      interactionContext: interactionContext,
      terminalize: terminalizeSuccess,
    );
  }

  Future<T> captureUnary<T>({
    required AiWorkType workType,
    required AiInteractionKind interactionKind,
    required AiConsumptionResponseType responseType,
    required InferenceProviderType providerType,
    required String modelId,
    required String requestText,
    required Future<T> Function() invoke,
    required String Function(T result) responseText,
    AiCapturedUsage? Function(T result)? usageForResult,
    MeliousCallImpact? Function()? impact,
    AiCapturedContext? interactionContext,
    AiAttributionSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiTriggerType triggerType = AiTriggerType.manual,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    List<AiArtifactReference> intendedOutputs = const [],
    String? taskId,
    String? categoryId,
  }) async {
    late T result;
    await for (final value in captureStream<T>(
      workType: workType,
      interactionKind: interactionKind,
      responseType: responseType,
      providerType: providerType,
      modelId: modelId,
      requestText: requestText,
      invoke: () async* {
        result = await invoke();
        yield result;
      },
      responseText: responseText,
      usageForChunk: usageForResult,
      impact: impact,
      interactionContext: interactionContext,
      existingSession: existingSession,
      terminalizeSuccess: terminalizeSuccess,
      terminalizeFailure: terminalizeFailure,
      triggerType: triggerType,
      initiator: initiator,
      automationId: automationId,
      automationDisplayName: automationDisplayName,
      attributionId: attributionId,
      intendedOutputs: intendedOutputs,
      taskId: taskId,
      categoryId: categoryId,
    )) {
      result = value;
    }
    return result;
  }

  Stream<T> captureRealtime<T>({
    required AiWorkType workType,
    required AiConsumptionResponseType responseType,
    required InferenceProviderType providerType,
    required String modelId,
    required String requestText,
    required Stream<T> Function() invoke,
    required String Function(T chunk) responseText,
    AiCapturedUsage? Function(T chunk)? usageForChunk,
    AiCapturedContext? interactionContext,
    AiAttributionSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiTriggerType triggerType = AiTriggerType.manual,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    String? taskId,
    String? categoryId,
  }) => captureStream(
    workType: workType,
    interactionKind: AiInteractionKind.realtimeTranscription,
    responseType: responseType,
    providerType: providerType,
    modelId: modelId,
    requestText: requestText,
    invoke: invoke,
    responseText: responseText,
    usageForChunk: usageForChunk,
    interactionContext: interactionContext,
    existingSession: existingSession,
    terminalizeSuccess: terminalizeSuccess,
    terminalizeFailure: terminalizeFailure,
    triggerType: triggerType,
    initiator: initiator,
    automationId: automationId,
    automationDisplayName: automationDisplayName,
    attributionId: attributionId,
    taskId: taskId,
    categoryId: categoryId,
  );

  /// Creates one logical-work owner before provider inference starts.
  Future<AiAttributionSession> beginSession({
    required AiWorkType workType,
    required AiTriggerSnapshot trigger,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    List<AiArtifactReference> intendedOutputs = const [],
    String? parentAttributionId,
    String? taskId,
    String? categoryId,
  }) async {
    final resolvedInitiator =
        initiator ??
        (trigger.type == AiTriggerType.automatic ||
                trigger.type == AiTriggerType.scheduled ||
                trigger.type == AiTriggerType.synced
            ? await _identityResolver.automationInitiator(
                id: automationId ?? 'automation:${workType.name}',
                displayName: automationDisplayName ?? workType.name,
              )
            : await _identityResolver.humanInitiator());
    return _attributionService.begin(
      AiAttributionStart(
        workType: workType,
        initiator: resolvedInitiator,
        trigger: trigger,
        intendedOutputs: intendedOutputs,
        parentAttributionId: parentAttributionId,
        taskId: taskId,
        categoryId: categoryId,
        attributionId: attributionId,
      ),
    );
  }

  /// Finalizes logical work after its durable output has been handled by the
  /// caller, or as terminal carrier-less work when [outputs] is empty.
  Future<AiWorkAttribution> completeSession({
    required AiAttributionSession session,
    required List<AiArtifactReference> outputs,
    AiWorkStatus status = AiWorkStatus.succeeded,
    String? errorCode,
    String? errorSummary,
  }) async {
    final attribution = await _attributionService.prepareCompletion(
      attributionId: session.id,
      outputs: outputs,
      status: status,
      errorCode: errorCode,
      errorSummary: errorSummary,
    );
    await _attributionService.finalize(attribution);
    return attribution;
  }

  Future<void> _finish({
    required AiAttributionSession pending,
    required AiInteractionKind interactionKind,
    required AiConsumptionResponseType responseType,
    required InferenceProviderType providerType,
    required String modelId,
    required String requestText,
    required String responseText,
    required DateTime startedAt,
    required AiInteractionStatus interactionStatus,
    required AiWorkStatus workStatus,
    required String? taskId,
    required String? categoryId,
    required String errorCode,
    required AiCapturedUsage? usage,
    required MeliousCallImpact? impact,
    required AiCapturedContext? interactionContext,
    required bool terminalize,
  }) async {
    final completedAt = clock.now().toUtc();
    final interactionId = _uuid.v4();
    String digest(String value) =>
        sha256.convert(utf8.encode(value)).toString();
    try {
      await _attributionService.recordInteraction(
        attributionId: pending.id,
        event: AiConsumptionEvent(
          id: interactionId,
          createdAt: startedAt,
          providerType: providerType,
          responseType: responseType,
          vectorClock: null,
          interactionKind: interactionKind,
          interactionStatus: interactionStatus,
          completedAt: completedAt,
          errorCode: interactionStatus == AiInteractionStatus.succeeded
              ? null
              : errorCode,
          parentId: interactionContext?.parentId,
          entryId: interactionContext?.entryId,
          agentId: interactionContext?.agentId,
          taskId: taskId,
          categoryId: categoryId,
          wakeRunKey: interactionContext?.wakeRunKey,
          threadId: interactionContext?.threadId,
          turnIndex: interactionContext?.turnIndex,
          promptId: interactionContext?.promptId,
          skillId: interactionContext?.skillId,
          configId: interactionContext?.providerConfigId,
          modelId: interactionContext?.modelConfigId,
          providerModelId: modelId,
          durationMs: completedAt.difference(startedAt).inMilliseconds,
          inputTokens: usage?.inputTokens,
          outputTokens: usage?.outputTokens,
          cachedInputTokens: usage?.cachedInputTokens,
          thoughtsTokens: usage?.thoughtsTokens,
          totalTokens: usage?.totalTokens,
          credits: impact?.costCredits,
          costCreditsDecimal: impact?.costCreditsDecimal,
          energyKwh: impact?.energyKwh,
          carbonGCo2: impact?.carbonGCo2,
          waterLiters: impact?.waterLiters,
          renewablePercent: impact?.renewablePercent,
          pue: impact?.pue,
          dataCenter: impact?.dataCenter,
          upstreamProviderId: impact?.providerId,
          requestDigest: digest(requestText),
          responseDigest: digest(responseText),
          interactionParameters: {
            'model': modelId,
            'providerType': providerType.name,
          },
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to record AI interaction',
        name: 'AiInteractionCapture',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!terminalize) return;
    final attribution = await _attributionService.prepareCompletion(
      attributionId: pending.id,
      outputs: const [],
      status: workStatus,
      errorCode: errorCode,
    );
    await _attributionService.finalize(attribution);
  }
}
