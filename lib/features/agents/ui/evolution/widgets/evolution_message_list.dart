import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_typing_indicator.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Turns a persisted system token (`starting_session`, `session_error`, …)
/// into localized text. The template and soul rituals emit overlapping but
/// non-identical token sets, which is the only thing that differs between
/// their two conversations.
typedef EvolutionSystemTextResolver =
    String Function(BuildContext context, String token);

/// The scrolling transcript of an evolution conversation.
///
/// Shared by the template and soul chats, which previously carried
/// byte-identical copies of this widget — including its scroll-anchoring
/// logic — and so drifted apart every time only one of them was touched.
class EvolutionMessageList extends StatefulWidget {
  const EvolutionMessageList({
    required this.messages,
    required this.isWaiting,
    required this.resolveSystemText,
    this.processor,
    super.key,
  });

  final List<EvolutionChatMessage> messages;
  final bool isWaiting;
  final EvolutionSystemTextResolver resolveSystemText;
  final SurfaceController? processor;

  @override
  State<EvolutionMessageList> createState() => _EvolutionMessageListState();
}

class _EvolutionMessageListState extends State<EvolutionMessageList> {
  late final ScrollController _scrollController;

  /// While true, new messages / the typing indicator follow to the bottom. Set
  /// from the user's position *before* new content lays out, so someone who
  /// scrolled up to read earlier messages is never yanked back down. Starts
  /// true so the chat opens pinned to the latest message.
  bool _stickToBottom = true;

  /// Distance from the bottom (logical px) within which the view still counts
  /// as "following" — slack so a partially-scrolled tail still sticks.
  static const double _stickToBottomThreshold = 120;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scheduleScrollToBottom();
  }

  @override
  void didUpdateWidget(covariant EvolutionMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length ||
        widget.isWaiting != oldWidget.isWaiting) {
      // Decide here, before the new content lays out: the controller still
      // reflects the old extent, so this measures where the user actually was.
      _stickToBottom = _isNearBottom();
      _scheduleScrollToBottom(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <=
        _stickToBottomThreshold;
  }

  void _scheduleScrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || !_stickToBottom) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final items = <Widget>[
      for (final message in widget.messages) _buildMessage(context, message),
      if (widget.isWaiting) const EvolutionTypingIndicator(),
    ];

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
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
        text: widget.resolveSystemText(context, text),
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
}

/// System tokens emitted by a *template* evolution session.
String resolveTemplateSystemText(BuildContext context, String token) {
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
    'approval_failed' => messages.agentEvolutionProposalApprovalFailed,
    _ => token,
  };
}

/// System tokens emitted by a *soul* evolution session. The completion token
/// carries a `v`-prefixed version rather than a bare number.
String resolveSoulSystemText(BuildContext context, String token) {
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
