import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_filing_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';

@immutable
class FrontChatComposerState {
  const FrontChatComposerState({
    this.draft = '',
    this.isSending = false,
    this.failedMessage,
    this.failedMessageId,
    this.failedConversationId,
    this.busyDoorIds = const {},
    this.failedDoorIds = const {},
  });

  final String draft;
  final bool isSending;

  /// Doors whose action — filing, declining, a chip — is in flight.
  final Set<String> busyDoorIds;

  /// Doors whose last action did not go through; cleared by the next one.
  final Set<String> failedDoorIds;

  /// The text of the turn that did not send, offered for a retry.
  final String? failedMessage;

  /// The durable id of that turn when it was persisted before failing, so a
  /// retry re-wakes the same turn instead of writing a duplicate.
  final String? failedMessageId;

  /// The conversation the failed turn was typed in, so a retry lands there
  /// even after the user opened another one.
  final String? failedConversationId;

  /// A copy never carries the send failure: an edit to the draft and the
  /// start of a send both clear it, and a failure is only ever set whole.
  /// The doors' state rides along untouched.
  FrontChatComposerState copyWith({
    String? draft,
    bool? isSending,
    Set<String>? busyDoorIds,
    Set<String>? failedDoorIds,
  }) => FrontChatComposerState(
    draft: draft ?? this.draft,
    isSending: isSending ?? this.isSending,
    busyDoorIds: busyDoorIds ?? this.busyDoorIds,
    failedDoorIds: failedDoorIds ?? this.failedDoorIds,
  );

  /// The state after a send settled, with the doors' state kept.
  FrontChatComposerState settled({
    String draft = '',
    String? failedMessage,
    String? failedMessageId,
    String? failedConversationId,
  }) => FrontChatComposerState(
    draft: draft,
    failedMessage: failedMessage,
    failedMessageId: failedMessageId,
    failedConversationId: failedConversationId,
    busyDoorIds: busyDoorIds,
    failedDoorIds: failedDoorIds,
  );
}

/// Keep-alive: a draft survives closing and reopening the sheet (the goal
/// and person chat controllers' shape). There is one front agent, so there
/// is one composer, whichever conversation is open.
final frontChatControllerProvider =
    NotifierProvider<FrontChatController, FrontChatComposerState>(
      FrontChatController.new,
      name: 'frontChatControllerProvider',
    );

class FrontChatController extends Notifier<FrontChatComposerState> {
  @override
  FrontChatComposerState build() => const FrontChatComposerState();

  void updateDraft(String value) {
    state = state.copyWith(draft: value);
  }

  /// Sends the draft.
  Future<void> send() => sendText(state.draft);

  /// Sends [text] as the user's next turn — the draft, or the label of a
  /// chip the user tapped under a clarifying question.
  Future<void> sendText(String text) async {
    final message = text.trim();
    if (state.isSending || message.isEmpty) return;
    // A send is a new turn, and its conversation is where it lands.
    ref.read(frontInboxFilterProvider.notifier).clear();
    state = state.copyWith(isSending: true);
    String? conversationId;
    try {
      final landing = conversationId = await _landingConversation();
      // The identity is created on first use, with the narrow default
      // allow-list (decision 4).
      await ref.read(frontAgentServiceProvider).getOrCreate();
      await ref
          .read(frontChatServiceProvider)
          .sendMessage(text: message, conversationId: landing);
      await _unarchive(landing);
      _reproject();
      state = state.settled();
    } on FrontChatTurnException catch (error) {
      _reproject();
      state = state.settled(
        draft: state.draft,
        failedMessage: message,
        failedMessageId: error.messageId,
        failedConversationId: conversationId,
      );
    } catch (_) {
      state = state.settled(
        draft: state.draft,
        failedMessage: message,
        failedConversationId: conversationId,
      );
    }
  }

  /// Talking in an archived conversation brings it back: it is in use. Best
  /// effort — the turn is sent, so a failure here must not offer a retry
  /// that would write it twice.
  Future<void> _unarchive(String conversationId) async {
    final sentIn = ref
        .read(frontConversationsProvider)
        .value
        ?.byId(conversationId);
    if (!(sentIn?.archived ?? false)) return;
    try {
      await ref
          .read(frontConversationServiceProvider)
          .archive(conversationId, archived: false);
    } catch (_) {
      // Still archived; the next send tries again.
    }
  }

  Future<void> retry() async {
    final failed = state.failedMessage;
    final messageId = state.failedMessageId;
    final typedIn = state.failedConversationId;
    if (failed == null || state.isSending) return;
    state = state.copyWith(isSending: true);
    try {
      final service = ref.read(frontChatServiceProvider);
      if (messageId == null) {
        final conversationId = typedIn ?? await _landingConversation();
        await ref.read(frontAgentServiceProvider).getOrCreate();
        await service.sendMessage(
          text: failed,
          conversationId: conversationId,
        );
      } else {
        await service.retryMessage(messageId: messageId);
      }
      _reproject();
      state = state.settled();
    } on FrontChatTurnException catch (error) {
      _reproject();
      state = state.settled(
        draft: failed,
        failedMessage: failed,
        failedMessageId: error.messageId ?? messageId,
        failedConversationId: typedIn,
      );
    } catch (_) {
      state = state.settled(
        draft: failed,
        failedMessage: failed,
        failedMessageId: messageId,
        failedConversationId: typedIn,
      );
    }
  }

  /// The conversation a send lands in: the active one, pinned, so a newer
  /// conversation arriving from another device does not take the surface
  /// out from under the reply.
  Future<String> _landingConversation() async {
    final id = await ref.read(frontActiveConversationProvider.future);
    ref.read(frontPickedConversationProvider.notifier).picked = id;
    return id;
  }

  /// Re-reads what a write changed: the shown thread, the inbox it counts
  /// from, and the conversation list.
  void _reproject() => ref
    ..invalidate(frontChatThreadProvider)
    ..invalidate(frontAllChatsThreadProvider)
    ..invalidate(frontConversationsProvider);

  /// The conversation on the surface now: the one picked — read first,
  /// since the resolved one is async and lags a pick — else the one
  /// resolved for "where I left off".
  String? get _open {
    final picker = ref.read(frontPickedConversationProvider.notifier);
    final picked = picker.picked;
    // A pick from another day, or of a conversation since deleted, is not
    // what the surface shows any more.
    final deleted =
        ref.read(frontConversationsProvider).value?.deletedIds ?? const {};
    return picked != null &&
            picker.pickedOn(clock.now()) &&
            !deleted.contains(picked)
        ? picked
        : ref.read(frontActiveConversationProvider).value;
  }

  /// Drafts of the conversations the user switched away from, so a
  /// half-typed message stays with the conversation it was written for.
  final _drafts = <String, String>{};

  /// Opens [conversationId]; the inbox filter, which spans them all, is
  /// left.
  void openConversation(String conversationId) => _switch(
    () => ref.read(frontPickedConversationProvider.notifier).picked =
        conversationId,
  );

  /// Whether [conversationId] is the one on the surface.
  bool isOpen(String conversationId) => _open == conversationId;

  /// A new, empty conversation — unless the open one is already new and
  /// empty, whose draft would otherwise be orphaned under an id nothing
  /// lists.
  void startConversation() {
    final open = _open;
    final index = ref.read(frontConversationsProvider).value;
    if (open != null && index != null && index.byId(open) == null) {
      ref.read(frontInboxFilterProvider.notifier).clear();
      return;
    }
    _switch(ref.read(frontPickedConversationProvider.notifier).startNew);
  }

  /// Switches the surface with [pick], parking the draft of the conversation
  /// left and taking up the one of the conversation opened.
  void _switch(void Function() pick) {
    ref.read(frontInboxFilterProvider.notifier).clear();
    final from = _open;
    if (from != null && state.draft.isNotEmpty) _drafts[from] = state.draft;
    pick();
    final to = ref.read(frontPickedConversationProvider);
    if (to != from) {
      state = state.copyWith(draft: _drafts.remove(to) ?? '');
    }
  }

  Future<void> renameConversation(String conversationId, String title) async {
    await ref
        .read(frontConversationServiceProvider)
        .rename(
          conversationId,
          title,
        );
    _reproject();
  }

  Future<void> archiveConversation(
    String conversationId, {
    required bool archived,
  }) async {
    await ref
        .read(frontConversationServiceProvider)
        .archive(conversationId, archived: archived);
    // Archiving the open one puts it away, as deleting does.
    if (archived) _leave(conversationId);
    _reproject();
  }

  /// Deletes [conversationId]; when it was the open one, the surface goes
  /// back to where the user left off elsewhere.
  Future<void> deleteConversation(String conversationId) async {
    await ref.read(frontConversationServiceProvider).delete(conversationId);
    _leave(conversationId);
    _reproject();
  }

  /// When [conversationId] is the open one, the surface moves to a new,
  /// empty conversation: the next message must not land in some older one.
  void _leave(String conversationId) {
    if (_open == conversationId) {
      // Through the switch, so its draft is parked and an undo finds it.
      _switch(ref.read(frontPickedConversationProvider.notifier).startNew);
    }
  }

  /// Files the proposal under its task — the user's one tap (decision 1).
  Future<void> fileUnderTask(String doorId) =>
      _doorAction(doorId, (filing) => filing.fileUnderTask(doorId));

  /// Says no to what a waiting door offers: a proposal's words go to the
  /// inbox, an inbox item is left where it is.
  Future<void> decline(String doorId) =>
      _doorAction(doorId, (filing) => filing.decline(doorId));

  /// A left door waits again as what it was.
  Future<void> undoDecline(String doorId) =>
      _doorAction(doorId, (filing) => filing.undoDecline(doorId));

  /// Takes back what a door wrote: the entry, note or task.
  Future<void> takeBack(String doorId) =>
      _doorAction(doorId, (filing) => filing.takeBack(doorId));

  /// Makes a task of an inbox item.
  Future<void> makeTask(String doorId) =>
      _doorAction(doorId, (filing) => filing.makeTask(doorId));

  /// Saves an inbox item as a note.
  Future<void> saveAsNote(String doorId) =>
      _doorAction(doorId, (filing) => filing.saveAsNote(doorId));

  /// Runs one action on a door: the door is busy meanwhile, the thread is
  /// re-projected after, and a failure is kept on the door until its next
  /// action. A door already busy takes no second tap.
  Future<void> _doorAction(
    String doorId,
    Future<void> Function(FrontFilingService filing) action,
  ) async {
    if (state.busyDoorIds.contains(doorId)) return;
    state = state.copyWith(
      busyDoorIds: {...state.busyDoorIds, doorId},
      failedDoorIds: {...state.failedDoorIds}..remove(doorId),
    );
    try {
      await action(ref.read(frontFilingServiceProvider));
    } catch (_) {
      state = state.copyWith(failedDoorIds: {...state.failedDoorIds, doorId});
    } finally {
      _reproject();
      state = state.copyWith(
        busyDoorIds: {...state.busyDoorIds}..remove(doorId),
      );
    }
  }
}
