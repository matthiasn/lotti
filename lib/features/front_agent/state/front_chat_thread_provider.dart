import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/providers/agent_repository_providers.dart';

/// The projection of the front thread.
final frontChatThreadBuilderProvider = Provider<FrontChatThreadBuilder>(
  (ref) => FrontChatThreadBuilder(
    repository: ref.watch(agentRepositoryProvider),
  ),
  name: 'frontChatThreadBuilderProvider',
);

/// The thread the chat surface shows: the active conversation, or — while
/// the inbox filter is on — every conversation, since what waits on the
/// user is gathered from all of them.
///
/// The chat service's own turn is awaited by the composer, which
/// invalidates this provider when it completes.
final FutureProvider<FrontChatThread> frontChatThreadProvider =
    FutureProvider.autoDispose<FrontChatThread>((ref) async {
      if (ref.watch(frontInboxFilterProvider)) {
        return ref.watch(frontAllChatsThreadProvider.future);
      }
      final conversationId = await ref.watch(
        frontActiveConversationProvider.future,
      );
      return _projected(ref, conversationId: conversationId);
    }, name: 'frontChatThreadProvider');

/// Every conversation not deleted, as one thread: where the inbox count and
/// the inbox view come from.
final FutureProvider<FrontChatThread> frontAllChatsThreadProvider =
    FutureProvider.autoDispose<FrontChatThread>((ref) async {
      final index = await ref.watch(frontConversationsProvider.future);
      return _projected(ref, excluded: index.deletedIds);
    }, name: 'frontAllChatsThreadProvider');

/// Projects one conversation, or all but [excluded].
///
/// Reloads on the front agent's own update pings; on a goal or person agent
/// a door handed a turn to finishing a wake here — its reply lands in its
/// own thread through the sync service, which pings nobody; and on that
/// agent's update pings, which is how a reply written on another device
/// arrives through sync.
Future<FrontChatThread> _projected(
  Ref ref, {
  String? conversationId,
  Set<String> excluded = const {},
}) async {
  ref.watch(agentUpdateStreamProvider(frontAgentId));
  // Subscribed before the projection reads, not after: a specialist can
  // finish while the thread is being read, and a completion that fired in
  // that window would otherwise be lost — the reply arrives through the
  // sync service, which pings nobody.
  FrontChatThread? thread;
  final completedWhileReading = <String?>{};
  final completions = ref.read(wakeOrchestratorProvider).runCompletions.listen((
    completion,
  ) {
    final known = thread;
    if (known == null) {
      completedWhileReading.add(completion.agentId);
    } else if (known.specialistAgentIds.contains(completion.agentId)) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(completions.cancel);
  final built = await ref
      .watch(frontChatThreadBuilderProvider)
      .build(conversationId: conversationId, excluded: excluded);
  thread = built;
  for (final specialistId in built.specialistAgentIds) {
    ref.watch(agentUpdateStreamProvider(specialistId));
  }
  if (completedWhileReading.any(built.specialistAgentIds.contains)) {
    ref.invalidateSelf();
  }
  return built;
}
