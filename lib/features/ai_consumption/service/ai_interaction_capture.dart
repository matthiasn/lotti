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
    AiAttributionPendingSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiTriggerType triggerType = AiTriggerType.manual,
    AiPrivacyClassification privacyClassification =
        AiPrivacyClassification.standard,
    String? taskId,
    String? categoryId,
  }) async* {
    final startedAt = clock.now().toUtc();
    final pending =
        existingSession ??
        await _attributionService.begin(
          AiAttributionStart(
            workType: workType,
            initiator: await _identityResolver.humanInitiator(),
            trigger: AiTriggerSnapshot(type: triggerType),
            executor: await _identityResolver.executor(),
            privacyClassification: privacyClassification,
            taskId: taskId,
            categoryId: categoryId,
          ),
        );
    final response = StringBuffer();
    AiCapturedUsage? usage;
    try {
      await for (final chunk in invoke()) {
        response.write(responseText(chunk));
        usage = usageForChunk?.call(chunk) ?? usage;
        yield chunk;
      }
    } on Object catch (error) {
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
        terminalize: terminalizeFailure,
      );
      rethrow;
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
    AiAttributionPendingSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
    AiPrivacyClassification privacyClassification =
        AiPrivacyClassification.standard,
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
      existingSession: existingSession,
      terminalizeSuccess: terminalizeSuccess,
      terminalizeFailure: terminalizeFailure,
      privacyClassification: privacyClassification,
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
    AiAttributionPendingSession? existingSession,
    bool terminalizeSuccess = true,
    bool terminalizeFailure = true,
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
    existingSession: existingSession,
    terminalizeSuccess: terminalizeSuccess,
    terminalizeFailure: terminalizeFailure,
    privacyClassification: privacyClassification,
    taskId: taskId,
    categoryId: categoryId,
  );

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
        errorCode: interactionStatus == AiInteractionStatus.failed
            ? errorCode
            : null,
        taskId: taskId,
        categoryId: categoryId,
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
    required DateTime assessedAt,
  }) {
    final exactCost = impact?.costCreditsDecimal;
    return AiInteractionCost(
      id: _uuid.v4(),
      interactionId: interactionId,
      source: exactCost == null
          ? AiCostSource.unknown
          : AiCostSource.providerReported,
      assessedAt: assessedAt,
      originalAmountDecimal: exactCost,
      originalUnit: exactCost == null ? null : 'meliousCredit',
      reportingAmountMicros: exactCost == null
          ? null
          : decimalAmountToMicros(exactCost),
      reportingCurrency: exactCost == null ? null : 'EUR',
      providerType: providerType.name,
      pricingSnapshot: exactCost == null
          ? null
          : const {
              'version': 'melious-credit-eur-v1',
              'formula': '1 meliousCredit ≈ 1 EUR',
            },
    );
  }
}
