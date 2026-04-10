import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Chat-based evolution page for standalone soul evolution sessions.
///
/// Provides a multi-turn conversation with the personality evolution agent,
/// inline soul proposal review, and message input.
class SoulEvolutionChatPage extends ConsumerStatefulWidget {
  const SoulEvolutionChatPage({
    required this.soulId,
    super.key,
  });

  final String soulId;

  @override
  ConsumerState<SoulEvolutionChatPage> createState() =>
      _SoulEvolutionChatPageState();
}

class _SoulEvolutionChatPageState extends ConsumerState<SoulEvolutionChatPage> {
  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(
      soulEvolutionChatStateProvider(widget.soulId),
    );
    final soulAsync = ref.watch(soulDocumentProvider(widget.soulId));
    final soulName = soulAsync.value is SoulDocumentEntity
        ? (soulAsync.value! as SoulDocumentEntity).displayName
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
            soulName,
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
    return _MessageList(
      messages: data.messages,
      isWaiting: data.isWaiting,
      processor: data.processor,
    );
  }

  void _handleSend(String text) {
    ref
        .read(soulEvolutionChatStateProvider(widget.soulId).notifier)
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
  final SurfaceController? processor;

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
    final items = <Widget>[];
    for (final message in widget.messages) {
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
            ? Surface(
                surfaceContext: widget.processor!.contextFor(surfaceId),
              )
            : const SizedBox.shrink(),
    };
  }

  String _resolveSystemText(BuildContext context, String token) {
    final messages = context.messages;
    if (token.startsWith('soul_version_created:')) {
      final version = token.split(':').last;
      return messages.agentEvolutionSessionCompleted(
        int.tryParse(version.replaceFirst('v', '')) ?? 0,
      );
    }
    return switch (token) {
      'starting_session' => messages.agentEvolutionSessionStarting,
      'session_error' => messages.agentEvolutionSessionError,
      'session_abandoned' => messages.agentEvolutionSessionAbandoned,
      'soul_proposal_rejected' => messages.agentEvolutionProposalRejected,
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
