import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/state/agent_workflow_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'soul_evolution_chat_state.g.dart';

/// Manages the lifecycle of a standalone soul evolution chat session.
///
/// Parameterized by [soulId]. On [build], starts a new multi-turn session
/// via [TemplateEvolutionWorkflow.startSoulSession]. The user can then send
/// messages, approve/reject soul proposals, and end the session.
@riverpod
class SoulEvolutionChatState extends _$SoulEvolutionChatState {
  static const _logTag = 'SoulEvolutionChatState';

  @override
  Future<EvolutionChatData> build(String soulId) async {
    final workflow = ref.read(templateEvolutionWorkflowProvider);

    final messages = <EvolutionChatMessage>[
      EvolutionChatMessage.system(
        text: 'starting_session',
        timestamp: clock.now(),
      ),
    ];

    final openingResponse = await workflow.startSoulSession(soulId: soulId);
    final session = workflow.getActiveSessionForSoul(soulId);

    if (session == null || openingResponse == null) {
      if (session != null) {
        await workflow.abandonSession(sessionId: session.sessionId);
      }
      return EvolutionChatData(
        messages: [
          ...messages,
          EvolutionChatMessage.system(
            text: 'session_error',
            timestamp: clock.now(),
          ),
        ],
      );
    }

    // Drain any opening surfaces (e.g., if the LLM calls tools immediately).
    final openingSurfaces = <EvolutionChatMessage>[];
    final bridge = session.strategy.genUiBridge;
    if (bridge != null) {
      for (final surfaceId in bridge.drainPendingSurfaceIds()) {
        openingSurfaces.add(
          EvolutionChatMessage.surface(
            surfaceId: surfaceId,
            timestamp: clock.now(),
          ),
        );
      }
    }

    // Never suppress the opening text in soul sessions — the greeting and
    // example phrasings are essential context for BinaryChoicePrompt widgets.
    if (_hasNonEmptyText(openingResponse)) {
      messages.add(
        EvolutionChatMessage.assistant(
          text: openingResponse,
          timestamp: clock.now(),
        ),
      );
    }
    messages.addAll(openingSurfaces);

    // Wire up GenUI event handlers for soul proposals.
    session.eventHandler?.onSoulProposalAction = (surfaceId, action) {
      if (action == 'soul_proposal_approved') {
        approveSoulProposal();
      } else if (action == 'soul_proposal_rejected') {
        rejectSoulProposal();
      }
    };

    session.eventHandler?.onRatingsSubmitted = (surfaceId, ratings) {
      _handleRatingsSubmitted(ratings);
    };
    session.eventHandler?.onBinaryChoiceSubmitted = (surfaceId, value) {
      sendMessage(value, skipApprovalCheck: true);
    };
    session.eventHandler?.onABComparisonSubmitted = (surfaceId, value) {
      sendMessage(value, skipApprovalCheck: true);
    };

    // Abandon session on dispose if still active.
    ref.onDispose(() {
      session.eventHandler?.onSoulProposalAction = null;
      session.eventHandler?.onRatingsSubmitted = null;
      session.eventHandler?.onBinaryChoiceSubmitted = null;
      session.eventHandler?.onABComparisonSubmitted = null;
      if (workflow.getActiveSessionForSoul(soulId) != null) {
        unawaited(
          workflow.abandonSession(sessionId: session.sessionId).catchError((
            Object e,
            StackTrace s,
          ) {
            developer.log(
              'abandonSession on dispose failed',
              name: _logTag,
              error: e,
              stackTrace: s,
            );
          }),
        );
      }
    });

    return EvolutionChatData(
      sessionId: session.sessionId,
      messages: messages,
      processor: session.processor,
    );
  }

  void _handleRatingsSubmitted(Map<String, int> ratings) {
    final formatted = ratings.entries
        .map((e) => '${e.key}: ${e.value}/5')
        .join(', ');
    final message = 'My category ratings: $formatted';
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(categoryRatings: ratings));
    }
    sendMessage(message);
  }

  /// Send a user message and receive the assistant's response.
  ///
  /// If a soul proposal is pending, brief acknowledgements are treated as
  /// approval.
  Future<void> sendMessage(
    String text, {
    bool skipApprovalCheck = false,
  }) async {
    final data = state.value;
    if (data == null || data.sessionId == null || data.isWaiting) return;

    final workflow = ref.read(templateEvolutionWorkflowProvider);
    final sessionId = data.sessionId!;

    // Check for pending soul proposal (the only proposal type in soul sessions).
    final session = workflow.getSession(sessionId);
    final hasPendingSoulProposal = session?.strategy.latestSoulProposal != null;

    final userMsg = EvolutionChatMessage.user(
      text: text,
      timestamp: clock.now(),
    );
    state = AsyncData(
      data.copyWith(
        messages: [...data.messages, userMsg],
        isWaiting: true,
      ),
    );

    if (!skipApprovalCheck &&
        hasPendingSoulProposal &&
        _isImplicitApprovalMessage(text)) {
      await approveSoulProposal();
      return;
    }

    try {
      final response = await workflow.sendMessage(
        sessionId: sessionId,
        userMessage: text,
      );

      final current = state.value;
      if (current == null) return;

      final updatedMessages = [...current.messages];
      final surfaceMessages = <EvolutionChatMessage>[];

      final activeSession = workflow.getSession(sessionId);
      final bridge =
          activeSession?.strategy.genUiBridge ?? activeSession?.genUiBridge;
      if (bridge != null) {
        for (final surfaceId in bridge.drainPendingSurfaceIds()) {
          surfaceMessages.add(
            EvolutionChatMessage.surface(
              surfaceId: surfaceId,
              timestamp: clock.now(),
            ),
          );
        }
      }

      // Soul sessions always show text alongside surfaces — the text provides
      // context for A/B choices and proposals. Only suppress when a soul
      // proposal surface fully replaces the text.
      final responseText = response?.trim();
      if (responseText?.isNotEmpty ?? false) {
        updatedMessages.add(
          EvolutionChatMessage.assistant(
            text: responseText!,
            timestamp: clock.now(),
          ),
        );
      }

      updatedMessages.addAll(surfaceMessages);

      state = AsyncData(
        current.copyWith(
          messages: updatedMessages,
          isWaiting: false,
        ),
      );
    } catch (e, s) {
      developer.log(
        'sendMessage failed',
        name: _logTag,
        error: e,
        stackTrace: s,
      );
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(isWaiting: false));
      }
    }
  }

  /// Approve the soul proposal and complete the session.
  Future<bool> approveSoulProposal() async {
    final data = state.value;
    if (data == null || data.sessionId == null) return false;

    final workflow = ref.read(templateEvolutionWorkflowProvider);
    final sessionId = data.sessionId!;

    state = AsyncData(data.copyWith(isWaiting: true));

    try {
      final pendingRecap = workflow.getCurrentRecap(sessionId: sessionId);
      final recapSummary = pendingRecap?.tldr.trim().isNotEmpty ?? false
          ? pendingRecap!.tldr.trim()
          : pendingRecap?.content.trim();

      final newVersion = await workflow.completeSoulSession(
        sessionId: sessionId,
        categoryRatings: data.categoryRatings,
      );

      if (newVersion == null) {
        state = AsyncData(data.copyWith(isWaiting: false));
        return false;
      }

      final current = state.value;
      if (current == null) return false;

      state = AsyncData(
        current.copyWith(
          sessionId: () => null,
          processor: () => null,
          messages: [
            ...current.messages,
            if (_hasNonEmptyText(recapSummary))
              EvolutionChatMessage.assistant(
                text: recapSummary!,
                timestamp: clock.now(),
              ),
            EvolutionChatMessage.system(
              text: 'soul_version_created:v${newVersion.version}',
              timestamp: clock.now(),
            ),
          ],
          isWaiting: false,
        ),
      );

      // Invalidate soul-related providers.
      ref
        ..invalidate(allSoulDocumentsProvider)
        ..invalidate(activeSoulVersionProvider(soulId))
        ..invalidate(soulVersionHistoryProvider(soulId))
        ..invalidate(templatesUsingSoulProvider(soulId))
        ..invalidate(soulEvolutionSessionsProvider(soulId))
        ..invalidate(soulEvolutionSessionHistoryProvider(soulId));

      return true;
    } catch (e, s) {
      developer.log(
        'approveSoulProposal failed',
        name: _logTag,
        error: e,
        stackTrace: s,
      );
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(isWaiting: false));
      }
      return false;
    }
  }

  /// Reject the soul proposal and continue the conversation.
  void rejectSoulProposal() {
    final data = state.value;
    if (data == null || data.sessionId == null) return;

    ref
        .read(templateEvolutionWorkflowProvider)
        .rejectSoulProposal(sessionId: data.sessionId!);

    state = AsyncData(
      data.copyWith(
        messages: [
          ...data.messages,
          EvolutionChatMessage.system(
            text: 'soul_proposal_rejected',
            timestamp: clock.now(),
          ),
        ],
      ),
    );
  }

  /// End the session without approving changes.
  Future<void> endSession() async {
    final data = state.value;
    if (data == null || data.sessionId == null) return;

    final workflow = ref.read(templateEvolutionWorkflowProvider);
    try {
      await workflow.abandonSession(sessionId: data.sessionId!);
    } catch (e, s) {
      developer.log(
        'abandonSession failed',
        name: _logTag,
        error: e,
        stackTrace: s,
      );
    }

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          sessionId: () => null,
          processor: () => null,
          messages: [
            ...current.messages,
            EvolutionChatMessage.system(
              text: 'session_abandoned',
              timestamp: clock.now(),
            ),
          ],
          isWaiting: false,
        ),
      );
    }
  }

  static final _implicitApprovalPattern = RegExp(
    r'^[\s\p{P}\p{S}]*(ok|okay|yes|yep|approve|approved|lgtm|sounds good|looks good|ship it)[\s\p{P}\p{S}]*$',
    caseSensitive: false,
    unicode: true,
  );

  static bool _isImplicitApprovalMessage(String text) =>
      _implicitApprovalPattern.hasMatch(text.trim());

  static bool _hasNonEmptyText(String? text) =>
      text?.trim().isNotEmpty ?? false;
}
