import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';

@immutable
class FrontChatComposerState {
  const FrontChatComposerState({
    this.draft = '',
    this.isSending = false,
    this.failedMessage,
    this.failedMessageId,
  });

  final String draft;
  final bool isSending;

  /// The text of the turn that did not send, offered for a retry.
  final String? failedMessage;

  /// The durable id of that turn when it was persisted before failing, so a
  /// retry re-wakes the same turn instead of writing a duplicate.
  final String? failedMessageId;

  /// A copy never carries the failure: an edit to the draft and the start
  /// of a send both clear it, and a failure is only ever set whole.
  FrontChatComposerState copyWith({String? draft, bool? isSending}) =>
      FrontChatComposerState(
        draft: draft ?? this.draft,
        isSending: isSending ?? this.isSending,
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
      state = const FrontChatComposerState();
    } on FrontChatTurnException catch (error) {
      ref.invalidate(frontChatThreadProvider);
      state = FrontChatComposerState(
        draft: state.draft,
        failedMessage: message,
        failedMessageId: error.messageId,
      );
    } catch (_) {
      state = FrontChatComposerState(
        draft: state.draft,
        failedMessage: message,
      );
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
      state = const FrontChatComposerState();
    } on FrontChatTurnException catch (error) {
      ref.invalidate(frontChatThreadProvider);
      state = FrontChatComposerState(
        draft: failed,
        failedMessage: failed,
        failedMessageId: error.messageId ?? messageId,
      );
    } catch (_) {
      state = FrontChatComposerState(
        draft: failed,
        failedMessage: failed,
        failedMessageId: messageId,
      );
    }
  }
}
