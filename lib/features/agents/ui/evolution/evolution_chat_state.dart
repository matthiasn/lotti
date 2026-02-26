import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'evolution_chat_state.g.dart';

/// Holds the full state for an active evolution chat session.
class EvolutionChatData {
  const EvolutionChatData({
    required this.messages,
    this.sessionId,
    this.isWaiting = false,
    this.currentDirectives,
    this.processor,
  });

  final String? sessionId;
  final List<EvolutionChatMessage> messages;
  final bool isWaiting;
  final String? currentDirectives;

  /// The GenUI message processor, available after session start.
  /// Used by [GenUiSurface] widgets to render dynamic content.
  final A2uiMessageProcessor? processor;

  EvolutionChatData copyWith({
    String? Function()? sessionId,
    List<EvolutionChatMessage>? messages,
    bool? isWaiting,
    String? Function()? currentDirectives,
    A2uiMessageProcessor? Function()? processor,
  }) {
    return EvolutionChatData(
      sessionId: sessionId != null ? sessionId() : this.sessionId,
      messages: messages ?? this.messages,
      isWaiting: isWaiting ?? this.isWaiting,
      currentDirectives: currentDirectives != null
          ? currentDirectives()
          : this.currentDirectives,
      processor: processor != null ? processor() : this.processor,
    );
  }
}

/// Manages the lifecycle of an evolution chat session for a specific template.
///
/// On [build], starts a new multi-turn session via
/// [TemplateEvolutionWorkflow.startSession]. The user can then send messages,
/// approve/reject proposals, and end the session.
@riverpod
class EvolutionChatState extends _$EvolutionChatState {
  static const _logTag = 'EvolutionChatState';

  @override
  Future<EvolutionChatData> build(String templateId) async {
    final workflow = ref.read(templateEvolutionWorkflowProvider);

    // Load current directives for display in proposal cards.
    final versionData =
        await ref.read(activeTemplateVersionProvider(templateId).future);
    final currentDirectives = versionData is AgentTemplateVersionEntity
        ? versionData.directives
        : null;

    final now = clock.now();
    final messages = <EvolutionChatMessage>[
      EvolutionChatMessage.system(
        text: 'starting_session',
        timestamp: now,
      ),
    ];

    // Start the session asynchronously.
    final openingResponse = await workflow.startSession(templateId: templateId);

    final session = workflow.getActiveSessionForTemplate(templateId);
    if (session == null || openingResponse == null) {
      // Abandon any partially-created session to avoid blocking future starts.
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
        currentDirectives: currentDirectives,
      );
    }

    messages.add(
      EvolutionChatMessage.assistant(
        text: openingResponse,
        timestamp: clock.now(),
      ),
    );

    // Drain any GenUI surfaces created during the opening turn.
    final bridge = session.strategy.genUiBridge;
    if (bridge != null) {
      for (final surfaceId in bridge.drainPendingSurfaceIds()) {
        messages.add(
          EvolutionChatMessage.surface(
            surfaceId: surfaceId,
            timestamp: clock.now(),
          ),
        );
      }
    }

    final processor = session.processor;

    // Wire up GenUI event handler to route proposal actions to chat state.
    session.eventHandler?.onProposalAction = (surfaceId, action) {
      if (action == 'proposal_approved') {
        approveProposal();
      } else if (action == 'proposal_rejected') {
        rejectProposal();
      }
    };

    ref.onDispose(() {
      // Remove GenUI event handler callback to avoid calling disposed notifier.
      session.eventHandler?.onProposalAction = null;
      // Abandon session on dispose if still active.
      if (workflow.getActiveSessionForTemplate(templateId) != null) {
        workflow.abandonSession(sessionId: session.sessionId);
      }
    });

    return EvolutionChatData(
      sessionId: session.sessionId,
      messages: messages,
      currentDirectives: currentDirectives,
      processor: processor,
    );
  }

  /// Send a user message and receive the assistant's response.
  Future<void> sendMessage(String text) async {
    final data = state.value;
    if (data == null || data.sessionId == null || data.isWaiting) return;

    final workflow = ref.read(templateEvolutionWorkflowProvider);
    final sessionId = data.sessionId!;

    // Add user message and set waiting state.
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

    try {
      final response = await workflow.sendMessage(
        sessionId: sessionId,
        userMessage: text,
      );

      final current = state.value;
      if (current == null) return;

      final updatedMessages = [...current.messages];

      if (response != null) {
        updatedMessages.add(
          EvolutionChatMessage.assistant(
            text: response,
            timestamp: clock.now(),
          ),
        );
      }

      // Drain any GenUI surfaces created during this turn.
      final session = workflow.getSession(sessionId);
      final bridge = session?.strategy.genUiBridge;
      if (bridge != null) {
        for (final surfaceId in bridge.drainPendingSurfaceIds()) {
          updatedMessages.add(
            EvolutionChatMessage.surface(
              surfaceId: surfaceId,
              timestamp: clock.now(),
            ),
          );
        }
      }

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

  /// Approve the current proposal.
  Future<bool> approveProposal() async {
    final data = state.value;
    if (data == null || data.sessionId == null) return false;

    final workflow = ref.read(templateEvolutionWorkflowProvider);
    final sessionId = data.sessionId!;

    // Check the workflow for a pending proposal (managed by EvolutionStrategy).
    final hasProposal =
        workflow.getCurrentProposal(sessionId: sessionId) != null;
    if (!hasProposal) return false;

    state = AsyncData(data.copyWith(isWaiting: true));

    try {
      final newVersion = await workflow.approveProposal(
        sessionId: sessionId,
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
            EvolutionChatMessage.system(
              text: 'session_completed:${newVersion.version}',
              timestamp: clock.now(),
            ),
          ],
          isWaiting: false,
        ),
      );

      // Invalidate related providers so the detail page shows updated data.
      ref
        ..invalidate(agentTemplatesProvider)
        ..invalidate(activeTemplateVersionProvider(templateId))
        ..invalidate(templateVersionHistoryProvider(templateId))
        ..invalidate(templatePerformanceMetricsProvider(templateId));

      return true;
    } catch (e, s) {
      developer.log(
        'approveProposal failed',
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

  /// Reject the current proposal and continue the conversation.
  void rejectProposal() {
    final data = state.value;
    if (data == null || data.sessionId == null) return;

    ref
        .read(templateEvolutionWorkflowProvider)
        .rejectProposal(sessionId: data.sessionId!);

    state = AsyncData(
      data.copyWith(
        messages: [
          ...data.messages,
          EvolutionChatMessage.system(
            text: 'proposal_rejected',
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
    await workflow.abandonSession(sessionId: data.sessionId!);

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
}
