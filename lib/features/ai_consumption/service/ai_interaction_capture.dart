import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/logic/attribution_cost.dart';
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

/// Exact cost evidence supplied by a call site when it is not provider impact.
class AiCapturedCost {
  const AiCapturedCost({
    required this.source,
    this.originalAmountDecimal,
    this.originalUnit,
    this.reportingAmountMicros,
    this.reportingCurrency,
    this.billingSource,
    this.pricingSnapshot,
  });

  final AiCostSource source;
  final String? originalAmountDecimal;
  final String? originalUnit;
  final int? reportingAmountMicros;
  final String? reportingCurrency;
  final String? billingSource;
  final Map<String, dynamic>? pricingSnapshot;
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

/// Preserves both failures when a provider call and its required attribution
/// publication fail in the same capture boundary.
class AiInteractionCapturePublicationFailure implements Exception {
  const AiInteractionCapturePublicationFailure({
    required this.providerError,
    required this.providerStackTrace,
    required this.publicationError,
    required this.publicationStackTrace,
  });

  /// The provider failure that initiated the error path.
  final Object providerError;

  /// The original provider stack trace used when exposing this failure.
  final StackTrace providerStackTrace;

  /// The secondary failure raised while publishing attribution evidence.
  final Object publicationError;

  /// The stack trace for the attribution-publication failure.
  final StackTrace publicationStackTrace;

  @override
  String toString() => providerError.toString();
}

/// Central pre-call capture boundary for product inference funnels.
///
/// Callers with a durable output carrier may use their stricter publication
/// saga. Carrier-less funnels use this boundary so every backend invocation
/// still has a durable top-level attribution and terminal interaction record.
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
    AiCapturedCost? cost,
    AiCapturedContext? interactionContext,
    AiAttributionPendingSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiTriggerType triggerType = AiTriggerType.manual,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    AiPrivacyClassification privacyClassification =
        AiPrivacyClassification.standard,
    List<AiArtifactReference> intendedOutputs = const [],
    List<AiArtifactReference> sources = const [],
    List<AiArtifactReference> context = const [],
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
          privacyClassification: privacyClassification,
          intendedOutputs: intendedOutputs,
          sources: sources,
          context: context,
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
    } on Object catch (error, stackTrace) {
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
          capturedCost: cost,
          interactionContext: interactionContext,
          terminalize: terminalizeFailure,
        );
      } on Object catch (publicationError, publicationStackTrace) {
        Error.throwWithStackTrace(
          AiInteractionCapturePublicationFailure(
            providerError: error,
            providerStackTrace: stackTrace,
            publicationError: publicationError,
            publicationStackTrace: publicationStackTrace,
          ),
          stackTrace,
        );
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
          capturedCost: cost,
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
      capturedCost: cost,
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
    AiCapturedCost? cost,
    AiCapturedContext? interactionContext,
    AiAttributionPendingSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiTriggerType triggerType = AiTriggerType.manual,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    AiPrivacyClassification privacyClassification =
        AiPrivacyClassification.standard,
    List<AiArtifactReference> intendedOutputs = const [],
    List<AiArtifactReference> sources = const [],
    List<AiArtifactReference> context = const [],
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
      cost: cost,
      interactionContext: interactionContext,
      existingSession: existingSession,
      terminalizeSuccess: terminalizeSuccess,
      terminalizeFailure: terminalizeFailure,
      triggerType: triggerType,
      initiator: initiator,
      automationId: automationId,
      automationDisplayName: automationDisplayName,
      attributionId: attributionId,
      privacyClassification: privacyClassification,
      intendedOutputs: intendedOutputs,
      sources: sources,
      context: context,
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
    AiCapturedCost? cost,
    AiCapturedContext? interactionContext,
    AiAttributionPendingSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiTriggerType triggerType = AiTriggerType.manual,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    AiPrivacyClassification privacyClassification =
        AiPrivacyClassification.standard,
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
    cost: cost,
    interactionContext: interactionContext,
    existingSession: existingSession,
    terminalizeSuccess: terminalizeSuccess,
    terminalizeFailure: terminalizeFailure,
    triggerType: triggerType,
    initiator: initiator,
    automationId: automationId,
    automationDisplayName: automationDisplayName,
    attributionId: attributionId,
    privacyClassification: privacyClassification,
    taskId: taskId,
    categoryId: categoryId,
  );

  /// Creates one durable logical-work owner before any provider call starts.
  Future<AiAttributionPendingSession> beginSession({
    required AiWorkType workType,
    required AiTriggerSnapshot trigger,
    required AiPrivacyClassification privacyClassification,
    AiActorSnapshot? initiator,
    String? automationId,
    String? automationDisplayName,
    String? attributionId,
    List<AiArtifactReference> intendedOutputs = const [],
    List<AiArtifactReference> sources = const [],
    List<AiArtifactReference> context = const [],
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
        executor: await _identityResolver.executor(),
        privacyClassification: privacyClassification,
        intendedOutputs: intendedOutputs,
        sources: sources,
        context: context,
        parentAttributionId: parentAttributionId,
        taskId: taskId,
        categoryId: categoryId,
        attributionId: attributionId,
      ),
    );
  }

  /// Finalizes logical work after its durable output has been handled by the
  /// caller, or as terminal carrier-less work when [outputs] is empty.
  Future<AiTerminalAttributionEnvelope> completeSession({
    required AiAttributionPendingSession session,
    required List<AiArtifactReference> outputs,
    AiWorkStatus status = AiWorkStatus.succeeded,
    String? errorCode,
    String? errorSummary,
  }) async {
    final envelope = await _attributionService.prepareCompletion(
      attributionId: session.id,
      outputs: outputs,
      status: status,
      errorCode: errorCode,
      errorSummary: errorSummary,
    );
    await _attributionService.finalize(envelope);
    return envelope;
  }

  Future<void> _finish({
    required AiAttributionPendingSession pending,
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
    required AiCapturedCost? capturedCost,
    required AiCapturedContext? interactionContext,
    required bool terminalize,
  }) async {
    final completedAt = clock.now().toUtc();
    final interactionId = _uuid.v4();
    String digest(String value) =>
        sha256.convert(utf8.encode(value)).toString();
    final evidence = await _attributionService.recordInteraction(
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
        energyKwh: impact?.energyKwh,
        carbonGCo2: impact?.carbonGCo2,
        waterLiters: impact?.waterLiters,
        renewablePercent: impact?.renewablePercent,
        pue: impact?.pue,
        dataCenter: impact?.dataCenter,
        upstreamProviderId: impact?.providerId,
        payload: AiInteractionPayload(
          id: _uuid.v4(),
          interactionId: interactionId,
          request: const [],
          response: const [],
          parameters: {'model': modelId, 'providerType': providerType.name},
          requestDigest: digest(requestText),
          responseDigest: digest(responseText),
          capturePolicy: AiPayloadCapturePolicy.referenceOnly,
          privacyClassification: pending.privacyClassification,
          createdAt: completedAt,
        ),
        cost: _costForImpact(
          interactionId: interactionId,
          providerType: providerType,
          impact: impact,
          capturedCost: capturedCost,
          assessedAt: completedAt,
        ),
      ),
    );
    if (!evidence.published) {
      throw const AiAttributionPublicationException(
        'captured interaction did not cross the publication barrier',
      );
    }
    if (!terminalize) return;
    final envelope = await _attributionService.prepareCompletion(
      attributionId: pending.id,
      outputs: const [],
      status: workStatus,
      errorCode: errorCode,
    );
    await _attributionService.finalize(envelope);
  }

  AiInteractionCost _costForImpact({
    required String interactionId,
    required InferenceProviderType providerType,
    required MeliousCallImpact? impact,
    required AiCapturedCost? capturedCost,
    required DateTime assessedAt,
  }) {
    final exactCost = impact?.costCreditsDecimal;
    return AiInteractionCost(
      id: _uuid.v4(),
      interactionId: interactionId,
      source:
          capturedCost?.source ??
          (exactCost == null
              ? AiCostSource.unknown
              : AiCostSource.providerReported),
      assessedAt: assessedAt,
      originalAmountDecimal: capturedCost?.originalAmountDecimal ?? exactCost,
      originalUnit:
          capturedCost?.originalUnit ??
          (exactCost == null ? null : 'meliousCredit'),
      reportingAmountMicros:
          capturedCost?.reportingAmountMicros ??
          (exactCost == null ? null : decimalAmountToMicros(exactCost)),
      reportingCurrency:
          capturedCost?.reportingCurrency ?? (exactCost == null ? null : 'EUR'),
      providerType: providerType.name,
      billingSource: capturedCost?.billingSource,
      pricingSnapshot:
          capturedCost?.pricingSnapshot ??
          (exactCost == null
              ? null
              : const {
                  'version': 'melious-credit-eur-v1',
                  'formula': '1 meliousCredit ≈ 1 EUR',
                }),
    );
  }
}
