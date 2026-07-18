import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';

/// Rebuilds the local attribution read model from existing sync carriers.
class AttributionCarrierProjector {
  const AttributionCarrierProjector(this._repository);

  final ConsumptionRepository _repository;

  Future<void> projectJournalEntity(JournalEntity entity) async {
    for (final envelope in terminalEnvelopesFromJournalEntity(entity)) {
      await _repository.projectTerminalEnvelope(envelope);
    }
  }

  Future<void> projectAgentEntity(AgentDomainEntity entity) async {
    final envelope = terminalEnvelopeFromAgentEntity(entity);
    if (envelope != null) {
      await _repository.projectTerminalEnvelope(envelope);
    }
  }
}

Iterable<AiTerminalAttributionEnvelope> terminalEnvelopesFromJournalEntity(
  JournalEntity entity,
) sync* {
  switch (entity) {
    case final AiResponseEntry response:
      final envelope = response.data.aiAttribution;
      if (envelope != null) yield envelope;
    case final JournalImage image:
      final envelope = image.data.aiAttribution;
      if (envelope != null) yield envelope;
    case final JournalAudio audio:
      for (final transcript
          in audio.data.transcripts ?? const <AudioTranscript>[]) {
        final envelope = transcript.aiAttribution;
        if (envelope != null) yield envelope;
      }
    default:
      return;
  }
}

AiTerminalAttributionEnvelope? terminalEnvelopeFromAgentEntity(
  AgentDomainEntity entity,
) {
  if (entity is! AgentReportEntity) return null;
  final raw = entity.provenance[aiAttributionProvenanceKey];
  if (raw is! Map) return null;
  try {
    return AiTerminalAttributionEnvelope.fromJson(
      Map<String, dynamic>.from(raw),
    );
  } on Object {
    return null;
  }
}
