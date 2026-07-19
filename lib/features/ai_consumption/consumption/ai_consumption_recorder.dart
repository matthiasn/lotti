import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/sync/consumption_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Thin, safe facade that AI call sites use to record one consumption event.
///
/// Compatibility callers use [record], which logs failures without changing
/// their existing inference behavior.
class AiConsumptionRecorder {
  AiConsumptionRecorder({
    required this._syncService,
    required this._logger,
    this._attributionService,
    this._identityResolver,
  });

  final ConsumptionSyncService _syncService;
  final DomainLogger _logger;
  final AiAttributionService? _attributionService;
  final AiAttributionIdentityResolver? _identityResolver;

  Future<void> record(AiConsumptionEvent event) async {
    try {
      await recordRequired(event);
    } on Object catch (exception, stackTrace) {
      _logger.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'aiConsumptionRecorder.record',
      );
    }
  }

  Future<void> recordRequired(AiConsumptionEvent event) async {
    if (event.attributionId != null ||
        _attributionService == null ||
        _identityResolver == null) {
      await _syncService.recordEvent(event);
      return;
    }
    await _recordCompatibilityAttribution(event);
  }

  /// Adapts older completed-call funnels to the shared attribution record.
  ///
  /// These call sites cannot yet guarantee a terminal output carrier, so the
  /// work is intentionally marked partial instead of overstating provenance.
  Future<void> _recordCompatibilityAttribution(
    AiConsumptionEvent event,
  ) async {
    final identityResolver = _identityResolver!;
    final attributionService = _attributionService!;
    final agentId = event.agentId;
    final wakeRunKey = event.wakeRunKey;
    final actor =
        event.responseType == AiConsumptionResponseType.embeddingIndexing
        ? const AiActorSnapshot(
            type: AiActorType.system,
            id: 'system:embedding-indexer',
            displayName: 'Embedding indexer',
          )
        : agentId == null
        ? await identityResolver.humanInitiator()
        : AiActorSnapshot(
            type: AiActorType.agent,
            id: agentId,
            displayName: agentId,
            humanPrincipalId:
                (await identityResolver.humanInitiator()).humanPrincipalId,
          );
    final pending = await attributionService.begin(
      AiAttributionStart(
        workType: _workType(event.responseType),
        initiator: actor,
        trigger: AiTriggerSnapshot(
          type:
              event.responseType == AiConsumptionResponseType.embeddingIndexing
              ? AiTriggerType.automatic
              : agentId == null
              ? AiTriggerType.manual
              : AiTriggerType.agentTool,
          agentId: agentId,
          wakeRunKey: event.wakeRunKey,
          skillId: event.skillId,
          promptId: event.promptId,
        ),
        taskId: event.taskId,
        categoryId: event.categoryId,
        attributionId:
            event.responseType == AiConsumptionResponseType.agentTurn &&
                wakeRunKey != null
            ? agentWakeAttributionId(wakeRunKey)
            : null,
      ),
    );
    await attributionService.recordInteraction(
      attributionId: pending.id,
      event: event.copyWith(
        interactionKind:
            event.interactionKind ?? _interactionKind(event.responseType),
        completedAt: event.completedAt ?? DateTime.now(),
      ),
    );
    if (event.responseType == AiConsumptionResponseType.agentTurn &&
        wakeRunKey != null) {
      return;
    }
    final attribution = await attributionService.prepareCompletion(
      attributionId: pending.id,
      outputs: const [],
      status: AiWorkStatus.partial,
      errorCode: 'legacy_output_carrier_unavailable',
    );
    await attributionService.finalize(attribution);
  }

  AiWorkType _workType(AiConsumptionResponseType type) => switch (type) {
    AiConsumptionResponseType.agentTurn => AiWorkType.agentReport,
    AiConsumptionResponseType.textGeneration => AiWorkType.textGeneration,
    AiConsumptionResponseType.audioTranscription =>
      AiWorkType.audioTranscription,
    AiConsumptionResponseType.imageAnalysis => AiWorkType.imageAnalysis,
    AiConsumptionResponseType.imageGeneration => AiWorkType.imageGeneration,
    AiConsumptionResponseType.promptGeneration => AiWorkType.codingPrompt,
    AiConsumptionResponseType.embeddingIndexing => AiWorkType.embeddingIndexing,
  };

  AiInteractionKind _interactionKind(
    AiConsumptionResponseType type,
  ) => switch (type) {
    AiConsumptionResponseType.agentTurn => AiInteractionKind.chatCompletion,
    AiConsumptionResponseType.textGeneration =>
      AiInteractionKind.textGeneration,
    AiConsumptionResponseType.audioTranscription =>
      AiInteractionKind.audioTranscription,
    AiConsumptionResponseType.imageAnalysis => AiInteractionKind.imageAnalysis,
    AiConsumptionResponseType.imageGeneration =>
      AiInteractionKind.imageGeneration,
    AiConsumptionResponseType.promptGeneration =>
      AiInteractionKind.textGeneration,
    AiConsumptionResponseType.embeddingIndexing => AiInteractionKind.embedding,
  };
}
