import 'dart:convert';

import 'package:clock/clock.dart';
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
    required this.attribution,
  });

  final String transcriptId;
  final AiWorkAttribution attribution;
}

/// In-memory transcript capture created before provider/native inference starts.
class TranscriptAttributionSession {
  const TranscriptAttributionSession({
    required this.transcriptId,
    required this.pending,
    required this.providerName,
    required this.modelId,
    required this.providerType,
    required this.interactionKind,
    required this.startedAt,
  });

  final String transcriptId;
  final AiAttributionSession pending;
  final String providerName;
  final String modelId;
  final InferenceProviderType providerType;
  final AiInteractionKind interactionKind;
  final DateTime startedAt;
}

/// Coordinates pre-call transcript capture and carrier publication.
class TranscriptAttributionCoordinator {
  const TranscriptAttributionCoordinator(
    this._attributionService,
    this._identityResolver,
  );

  final AiAttributionService _attributionService;
  final AiAttributionIdentityResolver _identityResolver;

  Future<TranscriptAttributionSession> begin({
    required String providerName,
    required String modelId,
    required InferenceProviderType providerType,
    required AiInteractionKind interactionKind,
    String? taskId,
    String? categoryId,
  }) async {
    final transcriptId = const Uuid().v4();
    final startedAt = clock.now().toUtc();
    final pending = await _attributionService.begin(
      AiAttributionStart(
        workType: AiWorkType.audioTranscription,
        initiator: await _identityResolver.humanInitiator(),
        trigger: const AiTriggerSnapshot(type: AiTriggerType.manual),
        taskId: taskId,
        categoryId: categoryId,
      ),
    );
    return TranscriptAttributionSession(
      transcriptId: transcriptId,
      pending: pending,
      providerName: providerName,
      modelId: modelId,
      providerType: providerType,
      interactionKind: interactionKind,
      startedAt: startedAt,
    );
  }

  /// Prepares the output attribution after the provider interaction was already
  /// recorded through the shared interaction capture boundary under this
  /// session's attribution.
  Future<PreparedTranscriptAttribution> prepareOutput({
    required TranscriptAttributionSession session,
    required String audioEntryId,
  }) async {
    final attribution = await _attributionService.prepareCompletion(
      attributionId: session.pending.id,
      outputs: [
        AiArtifactReference(
          type: AiArtifactType.journalAudio,
          id: audioEntryId,
          subId: session.transcriptId,
        ),
      ],
    );
    return PreparedTranscriptAttribution(
      transcriptId: session.transcriptId,
      attribution: attribution,
    );
  }

  /// Publishes a sanitized failed interaction and terminalizes work that never
  /// produced a transcript carrier.
  Future<void> fail({
    required TranscriptAttributionSession session,
    required Object error,
  }) => _terminalizeWithoutCarrier(
    session: session,
    interactionStatus: AiInteractionStatus.failed,
    workStatus: AiWorkStatus.failed,
    errorCode: error.runtimeType.toString(),
  );

  /// Terminalizes a session whose provider interaction is already recorded
  /// but whose durable transcript carrier could not be created.
  Future<void> failOutput({
    required TranscriptAttributionSession session,
    required String errorCode,
  }) async {
    final attribution = await _attributionService.prepareCompletion(
      attributionId: session.pending.id,
      outputs: const [],
      status: AiWorkStatus.failed,
      errorCode: errorCode,
    );
    await _attributionService.finalize(attribution);
  }

  Future<void> _terminalizeWithoutCarrier({
    required TranscriptAttributionSession session,
    required AiInteractionStatus interactionStatus,
    required AiWorkStatus workStatus,
    required String errorCode,
  }) async {
    final eventId = const Uuid().v4();
    final completedAt = clock.now().toUtc();
    await _attributionService.recordInteraction(
      attributionId: session.pending.id,
      event: AiConsumptionEvent(
        id: eventId,
        createdAt: session.startedAt,
        providerType: session.providerType,
        responseType: AiConsumptionResponseType.audioTranscription,
        vectorClock: null,
        interactionKind: session.interactionKind,
        interactionStatus: interactionStatus,
        completedAt: completedAt,
        errorCode: errorCode,
        taskId: session.pending.taskId,
        categoryId: session.pending.categoryId,
        providerModelId: session.modelId,
        durationMs: completedAt.difference(session.startedAt).inMilliseconds,
        requestDigest: sha256
            .convert(utf8.encode(session.pending.id))
            .toString(),
        responseDigest: sha256.convert(const []).toString(),
        interactionParameters: {'providerName': session.providerName},
      ),
    );
    final attribution = await _attributionService.prepareCompletion(
      attributionId: session.pending.id,
      outputs: const [],
      status: workStatus,
      errorCode: errorCode,
    );
    await _attributionService.finalize(attribution);
  }

  Future<void> finalize(PreparedTranscriptAttribution attribution) =>
      _attributionService.finalize(attribution.attribution);
}
