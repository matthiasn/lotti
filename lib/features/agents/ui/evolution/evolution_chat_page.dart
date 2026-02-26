import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_dashboard_header.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_proposal_card.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_rating_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/theme.dart';

/// Chat-based evolution page for template evolution sessions.
///
/// Provides a multi-turn conversation with the evolution agent, an inline
/// proposal review flow, and a collapsible performance dashboard.
class EvolutionChatPage extends ConsumerStatefulWidget {
  const EvolutionChatPage({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  ConsumerState<EvolutionChatPage> createState() => _EvolutionChatPageState();
}

class _EvolutionChatPageState extends ConsumerState<EvolutionChatPage> {
  double _rating = 0.5;
  bool _showRating = false;

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(evolutionChatStateProvider(widget.templateId));
    final templateAsync = ref.watch(agentTemplateProvider(widget.templateId));
    final templateEntity = templateAsync.value;
    final templateName =
        templateEntity is AgentTemplateEntity ? templateEntity.displayName : '';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Session cleanup happens via ref.onDispose in the notifier.
        }
      },
      child: Scaffold(
        backgroundColor: GameyColors.surfaceDarkLow,
        appBar: AppBar(
          backgroundColor: GameyColors.surfaceDark,
          title: Text(
            templateName,
            style: appBarTextStyleNewLarge.copyWith(
              color: GameyColors.aiCyan,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: chatAsync.when(
          data: (data) => _buildChat(context, data),
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: GameyColors.aiCyan,
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.messages.agentEvolutionSessionError,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        bottomNavigationBar: chatAsync.whenOrNull(
          data: (data) => EvolutionMessageInput(
            onSend: _handleSend,
            isWaiting: data.isWaiting,
            enabled: data.sessionId != null,
          ),
        ),
      ),
    );
  }

  Widget _buildChat(BuildContext context, EvolutionChatData data) {
    return Column(
      children: [
        EvolutionDashboardHeader(templateId: widget.templateId),
        Expanded(
          child: _MessageList(
            messages: data.messages,
            currentDirectives: data.currentDirectives,
            isWaiting: data.isWaiting,
            showRating: _showRating,
            rating: _rating,
            onApprove: () => _handleApprove(data),
            onReject: _handleReject,
            onRatingChanged: (v) => setState(() => _rating = v),
            processor: data.processor,
          ),
        ),
      ],
    );
  }

  void _handleSend(String text) {
    ref
        .read(evolutionChatStateProvider(widget.templateId).notifier)
        .sendMessage(text);
  }

  void _handleApprove(EvolutionChatData data) {
    if (!_showRating) {
      // First tap: show rating slider
      setState(() => _showRating = true);
      return;
    }

    // Second tap: actually approve with rating
    ref
        .read(evolutionChatStateProvider(widget.templateId).notifier)
        .approveProposal(rating: _rating)
        .then((success) {
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.agentTemplateEvolveSuccess),
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }

  void _handleReject() {
    setState(() => _showRating = false);
    ref
        .read(evolutionChatStateProvider(widget.templateId).notifier)
        .rejectProposal();
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.isWaiting,
    required this.showRating,
    required this.rating,
    required this.onApprove,
    required this.onReject,
    required this.onRatingChanged,
    this.currentDirectives,
    this.processor,
  });

  final List<EvolutionChatMessage> messages;
  final String? currentDirectives;
  final bool isWaiting;
  final bool showRating;
  final double rating;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<double> onRatingChanged;
  final A2uiMessageProcessor? processor;

  @override
  Widget build(BuildContext context) {
    final messages = this.messages;

    // Build items list with optional trailing elements
    final items = <Widget>[];
    for (final message in messages) {
      items.add(_buildMessage(context, message));
    }

    if (isWaiting) {
      items.add(_buildLoadingIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  Widget _buildMessage(BuildContext context, EvolutionChatMessage message) {
    return switch (message) {
      EvolutionUserMessage(:final text) => EvolutionChatBubble(
          text: text,
          role: 'user',
        ),
      EvolutionAssistantMessage(:final text) => EvolutionChatBubble(
          text: text,
          role: 'assistant',
        ),
      EvolutionSystemMessage(:final text) => EvolutionChatBubble(
          text: _resolveSystemText(context, text),
          role: 'system',
        ),
      EvolutionProposalMessage(:final proposal) => Column(
          children: [
            if (showRating)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EvolutionRatingWidget(
                  onRatingChanged: onRatingChanged,
                  initialRating: rating,
                ),
              ),
            EvolutionProposalCard(
              proposal: proposal,
              currentDirectives: currentDirectives,
              onApprove: onApprove,
              onReject: onReject,
              isWaiting: isWaiting,
            ),
          ],
        ),
      EvolutionSurfaceMessage(:final surfaceId) => processor != null
          ? GenUiSurface(
              host: processor!,
              surfaceId: surfaceId,
            )
          : const SizedBox.shrink(),
    };
  }

  /// Resolves system message tokens to localized text.
  String _resolveSystemText(BuildContext context, String token) {
    final messages = context.messages;
    if (token.startsWith('session_completed:')) {
      final version = int.tryParse(token.split(':').last) ?? 0;
      return messages.agentEvolutionSessionCompleted(version);
    }
    return switch (token) {
      'starting_session' => messages.agentEvolutionSessionStarting,
      'session_error' => messages.agentEvolutionSessionError,
      'session_abandoned' => messages.agentEvolutionSessionAbandoned,
      'proposal_rejected' => messages.agentEvolutionProposalRejected,
      _ => token,
    };
  }

  Widget _buildLoadingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GameyColors.aiCyan.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
