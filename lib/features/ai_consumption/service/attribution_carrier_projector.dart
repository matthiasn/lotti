import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';

/// Rebuilds the local attribution read model from existing sync carriers.
class AttributionCarrierProjector {
  const AttributionCarrierProjector(this._repository);

  final ConsumptionRepository _repository;

  Future<void> projectJournalEntity(JournalEntity entity) async {
    for (final attribution in attributionsFromJournalEntity(entity)) {
      await _repository.upsertAttribution(attribution);
    }
  }

  Future<void> projectAgentEntity(AgentDomainEntity entity) async {
    final attribution = attributionFromAgentEntity(entity);
    if (attribution != null) {
      await _repository.upsertAttribution(attribution);
    }
  }
}

Iterable<AiWorkAttribution> attributionsFromJournalEntity(
  JournalEntity entity,
) sync* {
  switch (entity) {
    case final AiResponseEntry response:
      final attribution = response.data.aiAttribution;
      if (attribution != null) yield attribution;
    case final JournalImage image:
      final attribution = image.data.aiAttribution;
      if (attribution != null) yield attribution;
    case final JournalAudio audio:
      for (final transcript
          in audio.data.transcripts ?? const <AudioTranscript>[]) {
        final attribution = transcript.aiAttribution;
        if (attribution != null) yield attribution;
      }
    default:
      return;
  }
}

AiWorkAttribution? attributionFromAgentEntity(
  AgentDomainEntity entity,
) {
  if (entity is! AgentReportEntity) return null;
  final raw = entity.provenance[aiAttributionProvenanceKey];
  if (raw is! Map) return null;
  try {
    return AiWorkAttribution.fromJson(
      Map<String, dynamic>.from(raw),
    );
  } on Object {
    return null;
  }
}
