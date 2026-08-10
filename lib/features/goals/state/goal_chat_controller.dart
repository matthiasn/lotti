import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';

@immutable
class GoalChatComposerState {
  const GoalChatComposerState({
    this.draft = '',
    this.isSending = false,
    this.failedMessage,
  });

  final String draft;
  final bool isSending;
  final String? failedMessage;

  GoalChatComposerState copyWith({
    String? draft,
    bool? isSending,
    String? failedMessage,
    bool clearFailure = false,
  }) => GoalChatComposerState(
    draft: draft ?? this.draft,
    isSending: isSending ?? this.isSending,
    failedMessage: clearFailure ? null : failedMessage ?? this.failedMessage,
  );
}

/// Keep-alive family: a draft survives leaving and reopening one agent's chat.
final NotifierProviderFamily<GoalChatController, GoalChatComposerState, String>
goalChatControllerProvider =
    NotifierProvider.family<GoalChatController, GoalChatComposerState, String>(
      GoalChatController.new,
      name: 'goalChatControllerProvider',
    );

class GoalChatController extends Notifier<GoalChatComposerState> {
  GoalChatController(this._agentId);

  final String _agentId;

  @override
  GoalChatComposerState build() => const GoalChatComposerState();

  void updateDraft(String value) {
    state = state.copyWith(draft: value, clearFailure: true);
  }

  Future<void> send() async {
    if (state.isSending || state.draft.trim().isEmpty) return;
    final message = state.draft.trim();
    state = state.copyWith(isSending: true, clearFailure: true);
    try {
      await ref
          .read(goalChatServiceProvider)
          .sendMessage(agentId: _agentId, text: message);
      state = const GoalChatComposerState();
    } catch (_) {
      state = GoalChatComposerState(
        draft: state.draft,
        failedMessage: message,
      );
    }
  }

  Future<void> retry() async {
    final failed = state.failedMessage;
    if (failed == null || state.isSending) return;
    state = state.copyWith(draft: failed, clearFailure: true);
    await send();
  }
}
