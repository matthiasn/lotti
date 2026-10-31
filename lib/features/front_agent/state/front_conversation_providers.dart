import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_conversation_service.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:uuid/uuid.dart';

/// Lists, renames, archives and deletes the user's conversations with her.
final frontConversationServiceProvider = Provider<FrontConversationService>(
  (ref) => FrontConversationService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  ),
  name: 'frontConversationServiceProvider',
);

/// Every conversation, reloaded on the front agent's update pings — a turn
/// or a lifecycle event, written here or arriving through sync.
final FutureProvider<FrontConversationIndex> frontConversationsProvider =
    FutureProvider.autoDispose<FrontConversationIndex>((ref) {
      ref.watch(agentUpdateStreamProvider(frontAgentId));
      return ref.watch(frontConversationServiceProvider).load();
    }, name: 'frontConversationsProvider');

/// The conversation the user picked, or null for "where I left off".
/// Keep-alive, like the composer: closing and reopening the sheet returns
/// to the same conversation.
final frontPickedConversationProvider =
    NotifierProvider<FrontConversationPicker, String?>(
      FrontConversationPicker.new,
      name: 'frontPickedConversationProvider',
    );

class FrontConversationPicker extends Notifier<String?> {
  static const _uuid = Uuid();

  @override
  String? build() => null;

  /// The picked conversation, or null for "where I left off".
  String? get picked => state;
  set picked(String? conversationId) => state = conversationId;

  /// A new, empty conversation: it exists once its first turn is sent.
  void startNew() => state = _uuid.v4();

  /// Back to "where I left off" — after the picked one was deleted.
  void reset() => state = null;
}

/// Whether the sheet shows the list of conversations instead of one. Off
/// every time the sheet opens.
final NotifierProvider<FrontConversationListOpen, bool>
frontConversationListOpenProvider =
    NotifierProvider.autoDispose<FrontConversationListOpen, bool>(
      FrontConversationListOpen.new,
      name: 'frontConversationListOpenProvider',
    );

class FrontConversationListOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void close() => state = false;
}

/// The id a first conversation takes when nothing was ever said: minted
/// once per session, so the empty surface and the first send agree on it.
final frontFreshConversationIdProvider = Provider<String>(
  (ref) => const Uuid().v4(),
  name: 'frontFreshConversationIdProvider',
);

/// The conversation the surface shows and a send lands in: the one the
/// user picked, else the newest one not archived, else a fresh one.
final FutureProvider<String> frontActiveConversationProvider =
    FutureProvider.autoDispose<String>((ref) async {
      final picked = ref.watch(frontPickedConversationProvider);
      if (picked != null) return picked;
      final index = await ref.watch(frontConversationsProvider.future);
      return index.latest?.id ?? ref.watch(frontFreshConversationIdProvider);
    }, name: 'frontActiveConversationProvider');
