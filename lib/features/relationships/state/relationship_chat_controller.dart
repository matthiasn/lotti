import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/relationships/service/relationship_chat_service.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationship_nudge_providers.dart';

@immutable
class RelationshipChatComposerState {
  const RelationshipChatComposerState({
    this.draft = '',
    this.isSending = false,
    this.failedMessage,
    this.failedMessageId,
  });

  final String draft;
  final bool isSending;
  final String? failedMessage;
  final String? failedMessageId;

  RelationshipChatComposerState copyWith({
    String? draft,
    bool? isSending,
    String? failedMessage,
    String? failedMessageId,
    bool clearFailure = false,
  }) => RelationshipChatComposerState(
    draft: draft ?? this.draft,
    isSending: isSending ?? this.isSending,
    failedMessage: clearFailure ? null : failedMessage ?? this.failedMessage,
    failedMessageId: clearFailure
        ? null
        : failedMessageId ?? this.failedMessageId,
  );
}

/// Keep-alive family: a draft survives leaving and reopening one agent's
/// chat (the `GoalChatController` shape).
final NotifierProviderFamily<
  RelationshipChatController,
  RelationshipChatComposerState,
  String
>
relationshipChatControllerProvider =
    NotifierProvider.family<
      RelationshipChatController,
      RelationshipChatComposerState,
      String
    >(
      RelationshipChatController.new,
      name: 'relationshipChatControllerProvider',
    );

class RelationshipChatController
    extends Notifier<RelationshipChatComposerState> {
  RelationshipChatController(this._agentId);

  final String _agentId;

  @override
  RelationshipChatComposerState build() =>
      const RelationshipChatComposerState();

  void updateDraft(String value) {
    state = state.copyWith(draft: value, clearFailure: true);
  }

  Future<void> send() async {
    if (state.isSending || state.draft.trim().isEmpty) return;
    final message = state.draft.trim();
    state = state.copyWith(isSending: true, clearFailure: true);
    try {
      await ref
          .read(relationshipChatServiceProvider)
          .sendMessage(agentId: _agentId, text: message);
      await _suppressCommittedSnoozes();
      _refreshProjections();
      state = const RelationshipChatComposerState();
    } on RelationshipChatTurnException catch (error) {
      state = RelationshipChatComposerState(
        draft: state.draft,
        failedMessage: message,
        failedMessageId: error.messageId,
      );
    } catch (_) {
      state = RelationshipChatComposerState(
        draft: state.draft,
        failedMessage: message,
      );
    }
  }

  Future<void> retry() async {
    final failed = state.failedMessage;
    final messageId = state.failedMessageId;
    if (failed == null || state.isSending) return;
    state = state.copyWith(isSending: true, clearFailure: true);
    try {
      final service = ref.read(relationshipChatServiceProvider);
      if (messageId == null) {
        await service.sendMessage(agentId: _agentId, text: failed);
      } else {
        await service.retryMessage(agentId: _agentId, messageId: messageId);
      }
      await _suppressCommittedSnoozes();
      _refreshProjections();
      state = const RelationshipChatComposerState();
    } on RelationshipChatTurnException catch (error) {
      state = RelationshipChatComposerState(
        draft: failed,
        failedMessage: failed,
        failedMessageId: error.messageId ?? messageId,
      );
    } catch (_) {
      state = RelationshipChatComposerState(
        draft: failed,
        failedMessage: failed,
        failedMessageId: messageId,
      );
    }
  }

  /// Workflow writes travel through the sync service (which deliberately
  /// does not notify), so the projections the awaited wake changed are
  /// refreshed explicitly (the goal-controller pattern).
  void _refreshProjections() {
    ref
      ..invalidate(agentChatProjectionProvider(_agentId))
      ..invalidate(activeRelationshipNudgesProvider);
  }

  /// Reads the just-committed relationship rows directly before the async
  /// projection reloads, feeding the shared dock's local suppression map so
  /// a background refresh serving retained data cannot flash a banner the
  /// chat wake just snoozed (the `GoalChatController` pattern). Render-time
  /// safety net only; durable snooze state stays authoritative.
  Future<void> _suppressCommittedSnoozes() async {
    try {
      final rows = await ref
          .read(agentRepositoryProvider)
          .getEntitiesByAgentId(
            _agentId,
            type: AgentEntityTypes.relationshipNudge,
          );
      final now = clock.now();
      final local = ref.read(
        locallySnoozedNudgeDeadlinesProvider.notifier,
      );
      for (final nudge in rows.whereType<RelationshipNudgeEntity>()) {
        final until = nudgeBannerSnoozedUntil(NudgeEntityView.of(nudge)!);
        if (nudge.status == NudgeStatus.active &&
            until != null &&
            until.isAfter(now)) {
          local.add(nudge.id, nudge.activationCount, until);
        }
      }
    } on Object {
      // Best effort: a failed direct read must not turn a committed chat
      // wake into a failed user turn. The invalidated durable projection
      // remains the authoritative fallback.
    }
  }
}
