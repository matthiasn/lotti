import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/service/front_chat_thread_builder.dart';
import 'package:lotti/providers/agent_repository_providers.dart';

/// The projection of the front thread.
final frontChatThreadBuilderProvider = Provider<FrontChatThreadBuilder>(
  (ref) => FrontChatThreadBuilder(
    repository: ref.watch(agentRepositoryProvider),
  ),
  name: 'frontChatThreadBuilderProvider',
);

/// The front thread as the chat surface shows it.
///
/// Reloads on the front agent's own update pings; on a goal or person agent
/// a door handed a turn to finishing a wake here — its reply lands in its
/// own thread through the sync service, which pings nobody; and on that
/// agent's update pings, which is how a reply written on another device
/// arrives through sync. The chat service's own turn is awaited by the
/// composer, which invalidates this provider when it completes.
final FutureProvider<FrontChatThread> frontChatThreadProvider =
    FutureProvider.autoDispose<FrontChatThread>(
      (ref) async {
        ref.watch(agentUpdateStreamProvider(frontAgentId));
        final thread = await ref.watch(frontChatThreadBuilderProvider).build();
        for (final specialistId in thread.specialistAgentIds) {
          ref.watch(agentUpdateStreamProvider(specialistId));
        }
        final completions = ref
            .read(wakeOrchestratorProvider)
            .runCompletions
            .listen((completion) {
              if (thread.specialistAgentIds.contains(completion.agentId)) {
                ref.invalidateSelf();
              }
            });
        ref.onDispose(completions.cancel);
        return thread;
      },
      name: 'frontChatThreadProvider',
    );
