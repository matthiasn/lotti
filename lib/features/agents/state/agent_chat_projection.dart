import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';

enum AgentChatRole { user, agent }

@immutable
class AgentChatMessage {
  const AgentChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final AgentChatRole role;
  final String text;
  final DateTime createdAt;
}

/// Bounded, durable conversation projection. Model context and private agent
/// messages are deliberately unrelated to this visible history.
final FutureProviderFamily<List<AgentChatMessage>, String>
agentChatProjectionProvider = FutureProvider.autoDispose
    .family<List<AgentChatMessage>, String>(
      agentChatProjection,
      name: 'agentChatProjectionProvider',
    );

Future<List<AgentChatMessage>> agentChatProjection(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);
  final entities = await repository.getEntitiesByAgentId(
    agentId,
    type: AgentEntityTypes.agentMessage,
  );
  final visible = entities.whereType<AgentMessageEntity>().where(
    (message) =>
        // Goal chat source turns have no runKey because they exist before the
        // wake. Older automatic goal wakes stored their internal FACTS blob as
        // a user row with a runKey; keep those legacy rows out of visible chat.
        (message.kind == AgentMessageKind.user &&
            message.metadata.runKey == null) ||
        (message.kind == AgentMessageKind.action &&
            message.metadata.toolName ==
                AgentConversationToolNames.replyToUser),
  );
  final projected = <AgentChatMessage>[];
  for (final message in visible) {
    final payloadId = message.contentEntryId;
    if (payloadId == null) continue;
    final payload = await repository.getEntity(payloadId);
    if (payload is! AgentMessagePayloadEntity) continue;
    final text = payload.content['text'];
    if (text is! String || text.trim().isEmpty) continue;
    projected.add(
      AgentChatMessage(
        id: message.id,
        role: message.kind == AgentMessageKind.user
            ? AgentChatRole.user
            : AgentChatRole.agent,
        text: text.trim(),
        createdAt: message.createdAt,
      ),
    );
  }
  projected.sort((a, b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return projected.length <= 50
      ? projected
      : projected.sublist(projected.length - 50);
}
