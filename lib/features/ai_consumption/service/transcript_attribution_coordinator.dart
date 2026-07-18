import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:uuid/uuid.dart';

/// Attribution result that direct transcript writers persist and then finalize.
class PreparedTranscriptAttribution {
  const PreparedTranscriptAttribution({
    required this.transcriptId,
    required this.envelope,
  });

  final String transcriptId;
  final AiTerminalAttributionEnvelope envelope;
}

/// Bridges transcript producers that predate the skill inference saga.
///
/// The provider call has already completed when these funnels receive text,
/// but the interaction evidence still crosses the publication barrier before
/// the transcript artifact is allowed into the journal database.
class TranscriptAttributionCoordinator {
  const TranscriptAttributionCoordinator(
    this._attributionService,
    this._identityResolver,
  );

  final AiAttributionService _attributionService;
  final AiAttributionIdentityResolver _identityResolver;

  Future<PreparedTranscriptAttribution> prepare({
    required String audioEntryId,
    required String transcript,
    required String providerName,
    required String modelId,
    required InferenceProviderType providerType,
    required AiInteractionKind interactionKind,
    String? taskId,
    String? categoryId,
  }) async {
    final transcriptId = const Uuid().v4();
    final eventId = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final output = AiArtifactReference(
      type: AiArtifactType.journalAudio,
      id: audioEntryId,
      subId: transcriptId,
    );
    final pending = await _attributionService.begin(
      AiAttributionStart(
        workType: AiWorkType.audioTranscription,
        initiator: await _identityResolver.humanInitiator(),
        trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
        executor: await _identityResolver.executor(),
        privacyClassification: AiPrivacyClassification.standard,
        intendedOutputs: [output],
        sources: [
          AiArtifactReference(
            type: AiArtifactType.journalAudio,
            id: audioEntryId,
          ),
        ],
        taskId: taskId,
        categoryId: categoryId,
      ),
    );
    final evidence = await _attributionService.recordInteraction(
      attributionId: pending.id,
      event: AiConsumptionEvent(
        id: eventId,
        createdAt: now,
        providerType: providerType,
        responseType: AiConsumptionResponseType.audioTranscription,
        vectorClock: null,
        interactionKind: interactionKind,
        completedAt: now,
        entryId: audioEntryId,
        taskId: taskId,
        categoryId: categoryId,
        providerModelId: modelId,
        payload: AiInteractionPayload(
          id: 'payload-$eventId',
          interactionId: eventId,
          request: const [],
          response: const [],
          parameters: {'providerName': providerName},
          requestDigest: 'journal-audio:$audioEntryId',
          responseDigest: sha256.convert(utf8.encode(transcript)).toString(),
          capturePolicy: AiPayloadCapturePolicy.referenceOnly,
          privacyClassification: AiPrivacyClassification.standard,
          createdAt: now,
        ),
        cost: AiInteractionCost(
          id: 'cost-$eventId',
          interactionId: eventId,
          source: AiCostSource.unknown,
          assessedAt: now,
          providerType: providerType.name,
        ),
      ),
    );
    if (!evidence.published) {
      throw const AiAttributionPublicationException(
        'transcript evidence did not cross the publication barrier',
      );
    }
    final envelope = await _attributionService.prepareCompletion(
      attributionId: pending.id,
      outputs: [output],
    );
    return PreparedTranscriptAttribution(
      transcriptId: transcriptId,
      envelope: envelope,
    );
  }

  Future<void> finalize(PreparedTranscriptAttribution attribution) =>
      _attributionService.finalize(attribution.envelope);
}
