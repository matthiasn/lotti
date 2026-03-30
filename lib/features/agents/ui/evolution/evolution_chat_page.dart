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
import 'package:lotti/l10n/app_localizations_context.dart';

/// Chat-based evolution page for template evolution sessions.
///
/// Provides a multi-turn conversation with the evolution agent, an inline
/// proposal review flow, and a compact ritual summary header.
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
  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(evolutionChatStateProvider(widget.templateId));
    final templateAsync = ref.watch(agentTemplateProvider(widget.templateId));
    final templateEntity = templateAsync.value;
    final templateName = templateEntity is AgentTemplateEntity
        ? templateEntity.displayName
        : '';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Session cleanup happens via ref.onDispose in the notifier.
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            templateName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: chatAsync.when(
          data: (data) => _buildChat(context, data),
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.messages.agentEvolutionSessionError,
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
            isWaiting: data.isWaiting,
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
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.messages,
    required this.isWaiting,
    this.processor,
  });

  final List<EvolutionChatMessage> messages;
  final bool isWaiting;
  final A2uiMessageProcessor? processor;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scheduleScrollToBottom();
  }

  @override
  void didUpdateWidget(covariant _MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length ||
        widget.isWaiting != oldWidget.isWaiting) {
      _scheduleScrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;

    // Build items list with optional trailing elements
    final items = <Widget>[];
    for (final message in messages) {
      items.add(_buildMessage(context, message));
    }

    if (widget.isWaiting) {
      items.add(_buildLoadingIndicator(context));
    }

    return ListView.builder(
      controller: _scrollController,
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
      EvolutionSurfaceMessage(:final surfaceId) =>
        widget.processor != null
            ? GenUiSurface(
                host: widget.processor!,
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

  Widget _buildLoadingIndicator(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              '...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
