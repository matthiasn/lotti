import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/ai_consumption/service/attribution_carrier_projector.dart';
import 'package:uuid/uuid.dart';

/// Result of one idempotent legacy-attribution projection pass.
class AiAttributionBackfillResult {
  const AiAttributionBackfillResult({
    required this.projectedCarriers,
    required this.createdLegacyAttributions,
    required this.migratedConsumptionEvents,
  });

  final int projectedCarriers;
  final int createdLegacyAttributions;
  final int migratedConsumptionEvents;
}

/// Conservatively projects attribution for data created before carriers existed.
///
/// The service never guesses a human creator or maps a source artifact to a
/// separate generated output. Historical rows are explicitly partial and use
/// deterministic ids, making repeated and cross-device runs idempotent.
class AiAttributionBackfillService {
  const AiAttributionBackfillService(this._repository);

  final ConsumptionRepository _repository;

  Future<AiAttributionBackfillResult> backfill({
    Iterable<JournalEntity> journalEntities = const [],
    Iterable<AgentDomainEntity> agentEntities = const [],
    Iterable<AiConsumptionEvent> consumptionEvents = const [],
  }) async {
    var projectedCarriers = 0;
    var createdLegacyAttributions = 0;
    var migratedConsumptionEvents = 0;

    for (final entity in journalEntities) {
      if (entity is JournalAudio) {
        final transcripts =
            entity.data.transcripts ?? const <AudioTranscript>[];
        for (var index = 0; index < transcripts.length; index++) {
          final transcript = transcripts[index];
          final carrier = transcript.aiAttribution;
          if (carrier != null) {
            await _repository.projectTerminalEnvelope(carrier);
            projectedCarriers++;
          } else {
            await _repository.upsertAttribution(
              _legacyAudioTranscriptAttribution(entity, transcript, index),
            );
            createdLegacyAttributions++;
          }
        }
        continue;
      }
      final carriers = terminalEnvelopesFromJournalEntity(entity).toList();
      for (final carrier in carriers) {
        await _repository.projectTerminalEnvelope(carrier);
        projectedCarriers++;
      }
      if (carriers.isNotEmpty) continue;
      for (final attribution in _legacyJournalAttributions(entity)) {
        await _repository.upsertAttribution(attribution);
        createdLegacyAttributions++;
      }
    }

    for (final entity in agentEntities) {
      final carrier = terminalEnvelopeFromAgentEntity(entity);
      if (carrier != null) {
        await _repository.projectTerminalEnvelope(carrier);
        projectedCarriers++;
      } else if (entity is AgentReportEntity) {
        await _repository.upsertAttribution(_legacyAgentReport(entity));
        createdLegacyAttributions++;
      }
    }

    for (final event in consumptionEvents) {
      if (event.attributionId != null) continue;
      final attributionId = _id('event', event.id);
      final migrated = event.copyWith(
        attributionId: attributionId,
        interactionKind:
            event.interactionKind ?? _interactionKind(event.responseType),
        completedAt: event.completedAt ?? event.createdAt,
        payload: event.payload ?? _legacyPayload(event),
        cost: event.cost ?? _legacyCost(event),
      );
      await _repository.upsertAttribution(_legacyEventAttribution(migrated));
      await _repository.upsertEvent(migrated);
      migratedConsumptionEvents++;
    }

    return AiAttributionBackfillResult(
      projectedCarriers: projectedCarriers,
      createdLegacyAttributions: createdLegacyAttributions,
      migratedConsumptionEvents: migratedConsumptionEvents,
    );
  }

  Iterable<AiWorkAttribution> _legacyJournalAttributions(
    JournalEntity entity,
  ) sync* {
    if (entity is AiResponseEntry) {
      yield _legacyAttribution(
        id: _id('journal-ai-response', entity.id),
        workType: _responseWorkType(entity.data.type),
        createdAt: entity.meta.createdAt,
        output: AiArtifactReference(
          type: AiArtifactType.journalAiResponse,
          id: entity.id,
        ),
        categoryId: entity.meta.categoryId,
      );
    }
  }

  AiWorkAttribution _legacyAudioTranscriptAttribution(
    JournalAudio entity,
    AudioTranscript transcript,
    int index,
  ) {
    final transcriptSourceId =
        transcript.id ??
        '${transcript.created.toUtc().toIso8601String()}|$index';
    return _legacyAttribution(
      id: _id(
        'journal-audio-transcript',
        '${entity.id}|$transcriptSourceId',
      ),
      workType: AiWorkType.audioTranscription,
      createdAt: transcript.created,
      output: AiArtifactReference(
        type: AiArtifactType.journalAudio,
        id: entity.id,
        subId: transcript.id,
      ),
      categoryId: entity.meta.categoryId,
    );
  }

  AiWorkAttribution _legacyAgentReport(AgentReportEntity report) =>
      _legacyAttribution(
        id: _id('agent-report', report.id),
        workType: AiWorkType.agentReport,
        createdAt: report.createdAt,
        output: AiArtifactReference(
          type: AiArtifactType.agentReport,
          id: report.id,
        ),
      );

  AiWorkAttribution _legacyEventAttribution(AiConsumptionEvent event) {
    final artifact = _eventArtifact(event);
    return _legacyAttribution(
      id: event.attributionId!,
      workType: _eventWorkType(event.responseType),
      createdAt: event.createdAt,
      output: artifact,
      categoryId: event.categoryId,
      taskId: event.taskId,
    );
  }

  AiWorkAttribution _legacyAttribution({
    required String id,
    required AiWorkType workType,
    required DateTime createdAt,
    required AiArtifactReference? output,
    String? taskId,
    String? categoryId,
  }) {
    final links = output == null
        ? const <AiAttributionLink>[]
        : [
            AiAttributionLink(
              id: _id(
                'link',
                '$id|${output.type.name}|${output.id}|${output.subId ?? ''}',
              ),
              attributionId: id,
              role: AiAttributionLinkRole.output,
              artifact: output,
            ),
          ];
    return AiWorkAttribution(
      id: id,
      workType: workType,
      status: AiWorkStatus.partial,
      initiator: const AiActorSnapshot(
        type: AiActorType.system,
        id: 'legacy:unknown',
        displayName: '',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.migration),
      executor: const AiExecutorSnapshot(
        hostId: 'legacy:unknown',
        displayName: '',
      ),
      privacyClassification: AiPrivacyClassification.standard,
      startedAt: createdAt.toUtc(),
      completedAt: createdAt.toUtc(),
      vectorClock: null,
      links: links,
      taskId: taskId,
      categoryId: categoryId,
      primaryOutput: output,
      errorCode: 'legacy_evidence_incomplete',
    );
  }

  AiInteractionPayload _legacyPayload(AiConsumptionEvent event) =>
      AiInteractionPayload(
        id: _id('payload', event.id),
        interactionId: event.id,
        request: const [],
        response: const [],
        parameters: const {'legacy': true},
        requestDigest: 'legacy-unavailable',
        responseDigest: 'legacy-unavailable',
        capturePolicy: AiPayloadCapturePolicy.metadataOnly,
        privacyClassification: AiPrivacyClassification.standard,
        createdAt: event.createdAt.toUtc(),
      );

  AiInteractionCost _legacyCost(AiConsumptionEvent event) {
    final credits = event.credits;
    return AiInteractionCost(
      id: _id('cost', event.id),
      interactionId: event.id,
      source: credits == null
          ? AiCostSource.unknown
          : AiCostSource.legacyReported,
      assessedAt: (event.completedAt ?? event.createdAt).toUtc(),
      originalAmountDecimal: credits?.toString(),
      originalUnit: credits == null ? null : 'meliousCredit',
      reportingAmountMicros: credits == null
          ? null
          : (credits * 1000000).round(),
      reportingCurrency: credits == null ? null : 'EUR',
      providerType: event.providerType.name,
      billingSource: credits == null ? null : 'legacy_consumption_event',
      pricingSnapshot: credits == null
          ? null
          : const {
              'version': 'legacy-melious-credit-eur-v1',
              'formula': '1 meliousCredit ≈ 1 EUR',
            },
    );
  }

  AiArtifactReference? _eventArtifact(AiConsumptionEvent event) {
    final entryId = event.entryId;
    if (entryId == null) return null;
    return switch (event.responseType) {
      AiConsumptionResponseType.audioTranscription => AiArtifactReference(
        type: AiArtifactType.journalAudio,
        id: entryId,
      ),
      AiConsumptionResponseType.imageAnalysis => AiArtifactReference(
        type: AiArtifactType.journalImage,
        id: entryId,
      ),
      _ => null,
    };
  }

  AiWorkType _responseWorkType(AiResponseType? type) => switch (type) {
    AiResponseType.promptGeneration => AiWorkType.codingPrompt,
    AiResponseType.imagePromptGeneration => AiWorkType.textGeneration,
    AiResponseType.imageGeneration => AiWorkType.imageGeneration,
    AiResponseType.imageAnalysis => AiWorkType.imageAnalysis,
    AiResponseType.audioTranscription => AiWorkType.audioTranscription,
    // ignore: deprecated_member_use_from_same_package
    AiResponseType.taskSummary ||
    // ignore: deprecated_member_use_from_same_package
    AiResponseType.checklistUpdates ||
    null => AiWorkType.textGeneration,
  };

  AiWorkType _eventWorkType(AiConsumptionResponseType type) => switch (type) {
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

  String _id(String kind, String sourceId) => const Uuid().v5(
    Namespace.nil.value,
    'ai-attribution-backfill-v1|$kind|$sourceId',
  );
}
