import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
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
    this.categoryRatings = const {},
    this.lastSurfacedProposalKey,
  });

  final String? sessionId;
  final List<EvolutionChatMessage> messages;
  final bool isWaiting;
  final String? currentDirectives;

  /// The GenUI message processor, available after session start.
  /// Used by [GenUiSurface] widgets to render dynamic content.
  final A2uiMessageProcessor? processor;
  final Map<String, int> categoryRatings;
  final String? lastSurfacedProposalKey;

  EvolutionChatData copyWith({
    String? Function()? sessionId,
    List<EvolutionChatMessage>? messages,
    bool? isWaiting,
    String? Function()? currentDirectives,
    A2uiMessageProcessor? Function()? processor,
    Map<String, int>? categoryRatings,
    String? Function()? lastSurfacedProposalKey,
  }) {
    return EvolutionChatData(
      sessionId: sessionId != null ? sessionId() : this.sessionId,
      messages: messages ?? this.messages,
      isWaiting: isWaiting ?? this.isWaiting,
      currentDirectives: currentDirectives != null
          ? currentDirectives()
          : this.currentDirectives,
      processor: processor != null ? processor() : this.processor,
      categoryRatings: categoryRatings ?? this.categoryRatings,
      lastSurfacedProposalKey: lastSurfacedProposalKey != null
          ? lastSurfacedProposalKey()
          : this.lastSurfacedProposalKey,
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
    final versionData = await ref.read(
      activeTemplateVersionProvider(templateId).future,
    );
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

    final hasOpeningProposal =
        workflow.getCurrentProposal(sessionId: session.sessionId) != null;
    final openingProposal = workflow.getCurrentProposal(
      sessionId: session.sessionId,
    );
    final suppressOpeningAssistantBubble =
        hasOpeningProposal && openingSurfaces.isNotEmpty;

    if (!suppressOpeningAssistantBubble && _hasNonEmptyText(openingResponse)) {
      messages.add(
        EvolutionChatMessage.assistant(
          text: openingResponse,
          timestamp: clock.now(),
        ),
      );
    }
    messages.addAll(openingSurfaces);

    final processor = session.processor;

    // Wire up GenUI event handler to route proposal actions to chat state.
    session.eventHandler?.onProposalAction = (surfaceId, action) {
      if (action == 'proposal_approved') {
        approveProposal();
      } else if (action == 'proposal_rejected') {
        rejectProposal();
      }
    };

    // Wire up category ratings handler.
    session.eventHandler?.onRatingsSubmitted = (surfaceId, ratings) {
      _handleRatingsSubmitted(ratings);
    };
    session.eventHandler?.onBinaryChoiceSubmitted = (surfaceId, value) {
      sendMessage(value);
    };

    ref.onDispose(() {
      // Remove GenUI event handler callbacks to avoid calling disposed notifier.
      session.eventHandler?.onProposalAction = null;
      session.eventHandler?.onRatingsSubmitted = null;
      session.eventHandler?.onBinaryChoiceSubmitted = null;
      // Abandon session on dispose if still active.
      if (workflow.getActiveSessionForTemplate(templateId) != null) {
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
      currentDirectives: currentDirectives,
      processor: processor,
      lastSurfacedProposalKey:
          openingProposal != null && openingSurfaces.isNotEmpty
          ? _proposalKey(openingProposal)
          : null,
    );
  }

  /// Handles the user submitting category ratings from the CategoryRatings
  /// widget. Formats the ratings as a user message and sends it to the LLM
  /// so it can proceed to Phase 2 (proposal).
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
  /// If a proposal is already pending, brief acknowledgements such as `ok`
  /// are treated as approval instead of triggering another model turn.
  Future<void> sendMessage(String text) async {
    final data = state.value;
    if (data == null || data.sessionId == null || data.isWaiting) return;

    final workflow = ref.read(templateEvolutionWorkflowProvider);
    final sessionId = data.sessionId!;
    final hasPendingProposal =
        workflow.getCurrentProposal(sessionId: sessionId) != null;

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

    if (hasPendingProposal && _isImplicitApprovalMessage(text)) {
      final approved = await approveProposal();
      if (!approved) {
        final current = state.value;
        if (current != null) {
          state = AsyncData(
            current.copyWith(
              messages: [
                ...current.messages,
                EvolutionChatMessage.system(
                  text: 'approval_failed',
                  timestamp: clock.now(),
                ),
              ],
            ),
          );
        }
      }
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

      final session = workflow.getSession(sessionId);
      final bridge = session?.strategy.genUiBridge ?? session?.genUiBridge;
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

      final pendingProposal = workflow.getCurrentProposal(sessionId: sessionId);
      final proposalKey = pendingProposal != null
          ? _proposalKey(pendingProposal)
          : null;

      // Render the proposal surface as a fallback when the LLM didn't already
      // emit surfaces (which typically include the proposal via a tool call).
      // When `surfaceMessages` is non-empty the LLM already produced the
      // proposal surface, so we skip to avoid duplicates.
      var proposalRenderedThisTurn = false;
      if (pendingProposal != null &&
          proposalKey != current.lastSurfacedProposalKey) {
        if (surfaceMessages.isEmpty) {
          final proposalSurfaces = _renderProposalSurface(
            session: session,
            proposal: pendingProposal,
          );
          if (proposalSurfaces.isNotEmpty) {
            surfaceMessages.addAll(proposalSurfaces);
            proposalRenderedThisTurn = true;
          }
        } else {
          // Surfaces were emitted by the LLM while a new proposal is pending
          // — treat the proposal as already rendered.
          proposalRenderedThisTurn = true;
        }
      }

      // Suppress the plain-text assistant bubble when a proposal surface was
      // shown this turn — either via _renderProposalSurface or via a GenUI
      // tool call that the LLM emitted directly.
      final shouldSuppressAssistantBubble =
          pendingProposal != null && surfaceMessages.isNotEmpty;

      final responseText = response?.trim();
      if ((responseText?.isNotEmpty ?? false) &&
          !shouldSuppressAssistantBubble) {
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
          lastSurfacedProposalKey: () => proposalRenderedThisTurn
              ? proposalKey
              : current.lastSurfacedProposalKey,
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

  static final _implicitApprovalPattern = RegExp(
    r'^[\s\p{P}\p{S}]*(ok|okay|yes|yep|approve|approved|lgtm|sounds good|looks good|ship it)[\s\p{P}\p{S}]*$',
    caseSensitive: false,
    unicode: true,
  );

  static bool _isImplicitApprovalMessage(String text) =>
      _implicitApprovalPattern.hasMatch(text.trim());

  static bool _hasNonEmptyText(String? text) =>
      text?.trim().isNotEmpty ?? false;

  static String _proposalKey(PendingProposal proposal) {
    return [
      proposal.generalDirective.trim(),
      proposal.reportDirective.trim(),
      proposal.rationale.trim(),
    ].join('\n---\n');
  }

  List<EvolutionChatMessage> _renderProposalSurface({
    required ActiveEvolutionSession? session,
    required PendingProposal proposal,
  }) {
    final bridge = session?.strategy.genUiBridge ?? session?.genUiBridge;
    final strategy = session?.strategy;
    if (bridge == null || strategy == null) {
      return const [];
    }

    bridge.handleToolCall({
      'surfaceId': 'proposal-${clock.now().microsecondsSinceEpoch}',
      'rootType': 'EvolutionProposal',
      'data': {
        'generalDirective': proposal.generalDirective,
        'reportDirective': proposal.reportDirective,
        'rationale': proposal.rationale,
        'currentGeneralDirective': strategy.currentGeneralDirective,
        'currentReportDirective': strategy.currentReportDirective,
      },
    });

    return bridge
        .drainPendingSurfaceIds()
        .map(
          (surfaceId) => EvolutionChatMessage.surface(
            surfaceId: surfaceId,
            timestamp: clock.now(),
          ),
        )
        .toList(growable: false);
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
      final pendingRecap = workflow.getCurrentRecap(sessionId: sessionId);
      final recapSummary = pendingRecap?.tldr.trim().isNotEmpty ?? false
          ? pendingRecap!.tldr.trim()
          : pendingRecap?.content.trim();
      final newVersion = await workflow.approveProposal(
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
        ..invalidate(templatePerformanceMetricsProvider(templateId))
        ..invalidate(ritualSummaryMetricsProvider(templateId))
        ..invalidate(ritualSessionHistoryProvider(templateId));

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
