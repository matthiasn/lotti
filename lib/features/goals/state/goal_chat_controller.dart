import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/logic/goal_banner_snooze.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';

@immutable
class GoalChatComposerState {
  const GoalChatComposerState({
    this.draft = '',
    this.isSending = false,
    this.failedMessage,
    this.failedMessageId,
  });

  final String draft;
  final bool isSending;
  final String? failedMessage;
  final String? failedMessageId;

  GoalChatComposerState copyWith({
    String? draft,
    bool? isSending,
    String? failedMessage,
    String? failedMessageId,
    bool clearFailure = false,
  }) => GoalChatComposerState(
    draft: draft ?? this.draft,
    isSending: isSending ?? this.isSending,
    failedMessage: clearFailure ? null : failedMessage ?? this.failedMessage,
    failedMessageId: clearFailure
        ? null
        : failedMessageId ?? this.failedMessageId,
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
      await _suppressCommittedSnoozes();
      // Goal-agent workflow writes travel through the sync service rather than
      // the interaction notifier. Refresh the goal-owned banner projections
      // as soon as the awaited wake commits so the colored card appears in
      // this still-mounted split view without a route round-trip.
      ref
        ..invalidate(activeGoalNudgesProvider)
        ..invalidate(goalNudgeHistoryProvider(_agentId));
      state = const GoalChatComposerState();
    } on GoalChatTurnException catch (error) {
      state = GoalChatComposerState(
        draft: state.draft,
        failedMessage: message,
        failedMessageId: error.messageId,
      );
    } catch (_) {
      state = GoalChatComposerState(
        draft: state.draft,
        failedMessage: message,
      );
    }
  }

  Future<void> retry() async {
    final failed = state.failedMessage;
    final messageId = state.failedMessageId;
    if (failed == null || messageId == null || state.isSending) return;
    state = state.copyWith(isSending: true, clearFailure: true);
    try {
      await ref
          .read(goalChatServiceProvider)
          .retryMessage(agentId: _agentId, messageId: messageId);
      await _suppressCommittedSnoozes();
      ref
        ..invalidate(activeGoalNudgesProvider)
        ..invalidate(goalNudgeHistoryProvider(_agentId));
      state = const GoalChatComposerState();
    } on GoalChatTurnException catch (error) {
      state = GoalChatComposerState(
        draft: failed,
        failedMessage: failed,
        failedMessageId: error.messageId ?? messageId,
      );
    } catch (_) {
      state = GoalChatComposerState(
        draft: failed,
        failedMessage: failed,
        failedMessageId: messageId,
      );
    }
  }

  /// Reads the just-committed goal rows directly before invalidating the async
  /// projection. This is a render-time safety net only; durable snooze state
  /// remains authoritative and the normal provider reload still follows.
  Future<void> _suppressCommittedSnoozes() async {
    try {
      final rows = await ref
          .read(agentRepositoryProvider)
          .getEntitiesByAgentId(
            _agentId,
            type: AgentEntityTypes.goalNudge,
          );
      final now = clock.now();
      final local = ref.read(
        locallySnoozedNudgeDeadlinesProvider.notifier,
      );
      for (final nudge in rows.whereType<GoalNudgeEntity>()) {
        final until = goalBannerSnoozedUntil(nudge);
        if (nudge.status == GoalNudgeStatus.active &&
            until != null &&
            until.isAfter(now)) {
          local.add(nudge.id, until);
        }
      }
    } on Object {
      // Best effort: a failed direct read must not turn a committed chat wake
      // into a failed user turn. The invalidated durable projection remains
      // the authoritative fallback.
    }
  }
}
