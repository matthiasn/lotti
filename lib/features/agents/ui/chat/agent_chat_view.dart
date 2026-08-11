import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Reusable durable-agent conversation surface. Consumers own sending and
/// draft state; this component owns only projection, bubbles and composition.
class AgentChatView extends ConsumerStatefulWidget {
  const AgentChatView({
    required this.agentId,
    required this.agentName,
    required this.draft,
    required this.isSending,
    required this.onDraftChanged,
    required this.onSend,
    required this.onRetry,
    this.hasFailedTurn = false,
    super.key,
  });

  final String agentId;
  final String agentName;
  final String draft;
  final bool isSending;
  final bool hasFailedTurn;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final VoidCallback onRetry;

  @override
  ConsumerState<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends ConsumerState<AgentChatView> {
  late final TextEditingController _controller;
  final _scrollController = ScrollController();
  String? _lastMessageId;
  bool _wasSending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft);
    _wasSending = widget.isSending;
  }

  @override
  void didUpdateWidget(covariant AgentChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId) {
      _lastMessageId = null;
      _wasSending = widget.isSending;
    }
    if (_controller.text != widget.draft) {
      _controller
        ..text = widget.draft
        ..selection = TextSelection.collapsed(offset: widget.draft.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final historyAsync = ref.watch(
      agentChatProjectionProvider(widget.agentId),
    );
    final messages = historyAsync.value;
    final latestMessageId = messages?.lastOrNull?.id;
    final shouldScroll =
        messages != null &&
        (_lastMessageId != latestMessageId ||
            (!_wasSending && widget.isSending));
    _lastMessageId = latestMessageId;
    _wasSending = widget.isSending;
    if (shouldScroll) _scrollToLatest();

    return Column(
      children: [
        Expanded(
          child: switch (messages) {
            null when historyAsync.hasError => Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step5),
                child: Text(
                  context.messages.goalChatHistoryError,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
              ),
            ),
            null => const Center(child: CircularProgressIndicator()),
            final history =>
              history.isEmpty && !widget.isSending
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(tokens.spacing.step5),
                        child: Text(
                          context.messages.goalChatEmpty(widget.agentName),
                          textAlign: TextAlign.center,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(tokens.spacing.step5),
                      itemCount: history.length + (widget.isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == history.length) {
                          return _ThinkingBubble(agentName: widget.agentName);
                        }
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: tokens.spacing.cardItemSpacing,
                          ),
                          child: _MessageBubble(
                            key: ValueKey(
                              'goal-chat-message-${history[index].id}',
                            ),
                            message: history[index],
                            agentName: widget.agentName,
                          ),
                        );
                      },
                    ),
          },
        ),
        if (widget.hasFailedTurn)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step5,
              vertical: tokens.spacing.step2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.messages.goalChatFailed,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                DesignSystemButton(
                  label: context.messages.aiInferenceErrorRetryButton,
                  onPressed: widget.onRetry,
                  variant: DesignSystemButtonVariant.dangerTertiary,
                  size: DesignSystemButtonSize.dense,
                ),
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            border: Border(
              top: BorderSide(color: tokens.colors.decorative.level01),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: DesignSystemTextInput(
              controller: _controller,
              hintText: context.messages.goalChatPlaceholder(widget.agentName),
              helperText: widget.isSending
                  ? context.messages.goalChatResponding(widget.agentName)
                  : null,
              enabled: !widget.isSending,
              textCapitalization: TextCapitalization.sentences,
              trailingIcon: Icons.send_rounded,
              onTrailingIconTap: widget.draft.trim().isEmpty
                  ? null
                  : widget.onSend,
              trailingIconTooltip: context.messages.chatInputSendTooltip,
              onChanged: widget.onDraftChanged,
              onSubmitted: (_) {
                if (widget.draft.trim().isNotEmpty) widget.onSend();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.agentName,
    super.key,
  });

  final AgentChatMessage message;
  final String agentName;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const _collapsedMaxLines = 8;
  static const _longReplyCharacterThreshold = 360;
  static const _longReplyLineThreshold = 8;

  bool _expanded = false;

  bool get _canCollapse {
    final message = widget.message;
    if (message.role != AgentChatRole.agent) return false;
    final lineBreaks = '\n'.allMatches(message.text).length;
    return message.text.length > _longReplyCharacterThreshold ||
        lineBreaks >= _longReplyLineThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final message = widget.message;
    final isUser = message.role == AgentChatRole.user;
    final author = isUser ? context.messages.goalChatYou : widget.agentName;
    final time = DateFormat.jm(
      Localizations.localeOf(context).toString(),
    ).format(message.createdAt);
    final canCollapse = _canCollapse;
    return Semantics(
      container: true,
      label: context.messages.goalChatMessageSemantics(
        author,
        time,
        message.text,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kActionListContentMaxWidth,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser
                  ? tokens.colors.surface.selected
                  : tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.l),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message.text,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    )
                  else
                    AgentMarkdownView(
                      message.text,
                      maxLines: canCollapse && !_expanded
                          ? _collapsedMaxLines
                          : null,
                      overflow: canCollapse && !_expanded
                          ? TextOverflow.ellipsis
                          : null,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                  if (canCollapse) ...[
                    SizedBox(height: tokens.spacing.step1),
                    DesignSystemButton(
                      label: _expanded
                          ? context.messages.aiResponseShowLess
                          : context.messages.aiResponseShowMore,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      variant: DesignSystemButtonVariant.tertiary,
                      size: DesignSystemButtonSize.dense,
                      trailingIcon: _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      alignsLabelToLeadingEdge: true,
                    ),
                  ],
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    '$author · $time',
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.agentName});

  final String agentName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: context.messages.goalChatResponding(agentName),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.l),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: Text(
              '•••',
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
