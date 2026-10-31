import 'package:clock/clock.dart';
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

  /// When the pick was made: one from another day is not resumed.
  DateTime? _pickedAt;

  @override
  String? build() => null;

  /// The picked conversation, or null for "where I left off".
  String? get picked => state;
  set picked(String? conversationId) => _pick(conversationId);

  /// Whether the pick was made on [now]'s day.
  bool pickedOn(DateTime now) {
    final at = _pickedAt;
    return at != null &&
        at.year == now.year &&
        at.month == now.month &&
        at.day == now.day;
  }

  /// A new, empty conversation: it exists once its first turn is sent.
  void startNew() => _pick(_uuid.v4());

  /// Back to "where I left off".
  void reset() => _pick(null);

  void _pick(String? conversationId) {
    _pickedAt = conversationId == null ? null : clock.now();
    state = conversationId;
  }
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
/// once per session, so the empty surface and the first send agree on it,
/// and minted again once a conversation that took it is deleted.
final frontFreshConversationIdProvider =
    NotifierProvider<FrontFreshConversationId, String>(
      FrontFreshConversationId.new,
      name: 'frontFreshConversationIdProvider',
    );

class FrontFreshConversationId extends Notifier<String> {
  static const _uuid = Uuid();

  @override
  String build() => _uuid.v4();

  /// The fresh id, minted anew when [deletedIds] holds it: a send must
  /// never land in a deleted conversation, which no list shows again.
  String liveAgainst(Set<String> deletedIds) {
    if (deletedIds.contains(state)) state = _uuid.v4();
    return state;
  }
}

/// The conversation the surface shows and a send lands in: the one the
/// user picked, else the newest one not archived while it moved today —
/// picking up where they left off — else a fresh one, so opening the sheet
/// and talking starts a new subject rather than continuing a stale one. A
/// conversation deleted — here or on another device — is never active.
final FutureProvider<String> frontActiveConversationProvider =
    FutureProvider.autoDispose<String>((ref) async {
      final picked = ref.watch(frontPickedConversationProvider);
      final index = await ref.watch(frontConversationsProvider.future);
      // A pick holds for the day it was made: a sheet left open overnight
      // does not carry the next morning's first words into yesterday's
      // subject.
      if (picked != null &&
          !index.deletedIds.contains(picked) &&
          ref
              .read(frontPickedConversationProvider.notifier)
              .pickedOn(clock.now())) {
        return picked;
      }
      final latest = index.latest;
      final now = clock.now();
      final today =
          latest != null &&
          latest.lastActivity.year == now.year &&
          latest.lastActivity.month == now.month &&
          latest.lastActivity.day == now.day;
      if (today) return latest.id;
      ref.watch(frontFreshConversationIdProvider);
      return ref
          .read(frontFreshConversationIdProvider.notifier)
          .liveAgainst(index.deletedIds);
    }, name: 'frontActiveConversationProvider');
