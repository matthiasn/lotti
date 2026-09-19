import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/observation_record.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:uuid/uuid.dart';

/// The `record_observations` parameters every agent's tool schema declares:
/// a non-empty list of `{text, priority?, category?}` objects, the enums
/// taken from the model so the schema cannot drift, closed to properties it
/// does not name. [parseRecordObservations] still accepts bare strings,
/// which models send regardless.
Map<String, Object?> recordObservationsParameters({
  required String textDescription,
}) => {
  'type': 'object',
  'properties': {
    'observations': {
      'type': 'array',
      'minItems': 1,
      'items': {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': textDescription},
          'priority': {
            'type': 'string',
            'enum': [for (final p in ObservationPriority.values) p.name],
          },
          'category': {
            'type': 'string',
            'enum': [for (final c in ObservationCategory.values) c.name],
          },
        },
        'required': ['text'],
        'additionalProperties': false,
      },
    },
  },
  'required': ['observations'],
  'additionalProperties': false,
};

class _Parser with ObservationRecordParsing {
  const _Parser();
}

/// Parses `record_observations` arguments into records, or explains in an
/// error the model can act on why none were usable.
///
/// Accepts both shapes agents have produced: bare strings and structured
/// objects. Blank entries are skipped; unknown priorities and categories
/// fall back to their defaults rather than failing the whole call.
({List<ObservationRecord> records, String? error}) parseRecordObservations(
  Map<String, dynamic> args,
) {
  final raw = args['observations'];
  if (raw is! List || raw.isEmpty) {
    return (
      records: const [],
      error: 'Error: "observations" must be a non-empty array.',
    );
  }
  const parser = _Parser();
  final records = <ObservationRecord>[
    for (final item in raw)
      if (item is String && item.trim().isNotEmpty)
        ObservationRecord(text: item.trim())
      else if (item is Map &&
          item['text'] is String &&
          (item['text'] as String).trim().isNotEmpty)
        ObservationRecord(
          text: (item['text'] as String).trim(),
          priority: parser.parseObservationPriority(
            item['priority'] is String ? item['priority'] as String : null,
          ),
          category: parser.parseObservationCategory(
            item['category'] is String ? item['category'] as String : null,
          ),
        ),
  ];
  return records.isEmpty
      ? (
          records: const <ObservationRecord>[],
          error:
              'Error: no valid observations found. Provide non-empty '
              'observation text.',
        )
      : (records: records, error: null);
}

/// One earlier observation as an agent's next wake reads it: the message
/// `id` (a stable tie-break for notes written in the same instant), when it
/// was written, its text, and the priority and category it was filed under.
typedef RecalledObservation = ({
  String id,
  DateTime at,
  String text,
  ObservationPriority priority,
  ObservationCategory category,
});

/// The agent's [limit] newest observations, newest first.
///
/// An observation whose payload cannot be read is left out rather than
/// shown as a placeholder: a wake is better served by fewer notes than by
/// noise it has to reason around. For the same reason a failed payload
/// read recalls nothing instead of failing the wake — observations are
/// memory, not the evidence the wake exists to act on.
Future<List<RecalledObservation>> recallAgentObservations(
  AgentRepository repository,
  String agentId, {
  required int limit,
}) async {
  final messages = await repository.getMessagesByKind(
    agentId,
    AgentMessageKind.observation,
    limit: limit,
  );
  final payloadIds = {
    for (final message in messages) ?message.contentEntryId,
  };
  if (payloadIds.isEmpty) return const [];
  final Map<String, AgentDomainEntity> payloads;
  try {
    payloads = await repository.getEntitiesByIds(payloadIds);
  } on Object {
    return const [];
  }
  const parser = _Parser();
  final recalled = <RecalledObservation>[];
  for (final message in messages) {
    final payload = payloads[message.contentEntryId];
    if (payload is! AgentMessagePayloadEntity) continue;
    final text = payload.content['text'];
    if (text is String && text.trim().isNotEmpty) {
      final priority = payload.content['priority'];
      final category = payload.content['category'];
      recalled.add((
        id: message.id,
        at: message.createdAt,
        text: text.trim(),
        priority: parser.parseObservationPriority(
          priority is String ? priority : null,
        ),
        category: parser.parseObservationCategory(
          category is String ? category : null,
        ),
      ));
    }
  }
  return recalled;
}

/// Writes [observations] as observation messages of one wake.
///
/// Ids are derived from the agent, the run and the position, so a retried
/// transaction rewrites the same rows instead of recording each note twice.
Future<void> persistAgentObservations(
  AgentSyncService syncService, {
  required String agentId,
  required String threadId,
  required String runKey,
  required DateTime now,
  required List<ObservationRecord> observations,
}) async {
  const uuid = Uuid();
  for (final (index, observation) in observations.indexed) {
    final payloadId = uuid.v5(
      Namespace.nil.value,
      'agent-observation-payload:$agentId:$runKey:$index',
    );
    await syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{
          'text': observation.text,
          'priority': observation.priority.name,
          'category': observation.category.name,
        },
      ),
    );
    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: uuid.v5(
          Namespace.nil.value,
          'agent-observation:$agentId:$runKey:$index',
        ),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.observation,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(runKey: runKey),
      ),
    );
  }
}
