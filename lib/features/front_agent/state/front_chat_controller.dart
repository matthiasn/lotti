import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_filing_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';

@immutable
class FrontChatComposerState {
  const FrontChatComposerState({
    this.draft = '',
    this.isSending = false,
    this.failedMessage,
    this.failedMessageId,
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
  }) => FrontChatComposerState(
    draft: draft,
    failedMessage: failedMessage,
    failedMessageId: failedMessageId,
    busyDoorIds: busyDoorIds,
    failedDoorIds: failedDoorIds,
  );
}

/// Keep-alive: a draft survives closing and reopening the sheet (the goal
/// and person chat controllers' shape). There is one front agent, so there
/// is one composer.
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
    state = state.copyWith(isSending: true);
    try {
      // The identity is created on first use, with the narrow default
      // allow-list (decision 4).
      await ref.read(frontAgentServiceProvider).getOrCreate();
      await ref.read(frontChatServiceProvider).sendMessage(text: message);
      ref.invalidate(frontChatThreadProvider);
      state = state.settled();
    } on FrontChatTurnException catch (error) {
      ref.invalidate(frontChatThreadProvider);
      state = state.settled(
        draft: state.draft,
        failedMessage: message,
        failedMessageId: error.messageId,
      );
    } catch (_) {
      state = state.settled(draft: state.draft, failedMessage: message);
    }
  }

  Future<void> retry() async {
    final failed = state.failedMessage;
    final messageId = state.failedMessageId;
    if (failed == null || state.isSending) return;
    state = state.copyWith(isSending: true);
    try {
      final service = ref.read(frontChatServiceProvider);
      if (messageId == null) {
        await ref.read(frontAgentServiceProvider).getOrCreate();
        await service.sendMessage(text: failed);
      } else {
        await service.retryMessage(messageId: messageId);
      }
      ref.invalidate(frontChatThreadProvider);
      state = state.settled();
    } on FrontChatTurnException catch (error) {
      ref.invalidate(frontChatThreadProvider);
      state = state.settled(
        draft: failed,
        failedMessage: failed,
        failedMessageId: error.messageId ?? messageId,
      );
    } catch (_) {
      state = state.settled(
        draft: failed,
        failedMessage: failed,
        failedMessageId: messageId,
      );
    }
  }

  /// Files the proposal under its task — the user's one tap (decision 1).
  Future<void> fileUnderTask(String doorId) =>
      _doorAction(doorId, (filing) => filing.fileUnderTask(doorId));

  /// Does not file the proposal.
  Future<void> declineFiling(String doorId) =>
      _doorAction(doorId, (filing) => filing.decline(doorId));

  /// Takes a filed entry back out.
  Future<void> unfile(String doorId) =>
      _doorAction(doorId, (filing) => filing.unfile(doorId));

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
      ref.invalidate(frontChatThreadProvider);
      state = state.copyWith(
        busyDoorIds: {...state.busyDoorIds}..remove(doorId),
      );
    }
  }
}
