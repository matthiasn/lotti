import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_error_message.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:material_ui/material_ui.dart';

part 'agent_chat_view_transcription_progress_state_part.dart';
part 'agent_chat_view_voice_first_part.dart';

class _AgentChatViewState extends ConsumerState<AgentChatView> {
  late final TextEditingController _controller;
  final _scrollController = ScrollController();
  late final ProviderSubscription<ChatRecorderState> _recorderSubscription;
  String? _lastMessageId;
  bool _wasSending = false;

  /// Laid-out reply heights, keyed by message id, owned by the LIST rather
  /// than by the item.
  ///
  /// `ListView.builder` disposes an item's State once it scrolls past the
  /// cache extent. A collapsible reply that lost its measurement renders at
  /// FULL height for the frame before the measurement lands, so every
  /// re-entry of a long reply grew the content above the viewport and the
  /// scroll machinery yanked the offset to compensate — the flashing and
  /// bouncing seen while scrolling a chat that contains a long reply.
  /// Surviving the item, the measurement lets a rebuilt reply lay out
  /// collapsed on its first frame.
  final _measuredHeights = <String, double>{};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft);
    _wasSending = widget.isSending;
    if (widget.conversationId != null) {
      _lastMessageId = widget.history?.value?.lastOrNull?.id;
    }
    _recorderSubscription = ref.listenManual<ChatRecorderState>(
      chatRecorderControllerProvider,
      (previous, next) {
        final error = next.error?.trim();
        if (error != null &&
            error.isNotEmpty &&
            error != previous?.error &&
            mounted) {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.commonError,
            description: chatRecorderErrorMessage(context, next.errorKind),
            duration: const Duration(seconds: 8),
            replaceCurrent: true,
          );
          Future.microtask(() {
            if (mounted) {
              ref.read(chatRecorderControllerProvider.notifier).clearResult();
            }
          });
          return;
        }
        if (next.transcript != null &&
            next.transcript != previous?.transcript) {
          if (!mounted) return;
          final transcript = next.transcript!.trim();
          if (transcript.isNotEmpty) {
            _controller.text = transcript;
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
            widget.onDraftChanged(transcript);
            // Tap to talk, tap to send: what was said goes out as is.
            if (widget.voiceFirst) widget.onSend();
          }
          ref.read(chatRecorderControllerProvider.notifier).clearResult();
        }
      },
    );
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
    _recorderSubscription.close();
    super.dispose();
  }

  /// Tells [AgentChatView.onThreadScrolled] where the thread is: on a
  /// scroll, and on a layout — a thread restored where it was left moves
  /// without one. The thread's own list only (depth 0 here), never a scroll
  /// nested inside a message or the composer.
  Widget _followThread(Widget list) {
    final follow = widget.onThreadScrolled;
    if (follow == null) return list;
    return NotificationListener<Notification>(
      onNotification: (notification) {
        final metrics = switch (notification) {
          ScrollUpdateNotification(depth: 0, :final metrics) => metrics,
          ScrollMetricsNotification(depth: 0, :final metrics) => metrics,
          _ => null,
        };
        if (metrics != null) follow(metrics);
        return false;
      },
      child: list,
    );
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
    final historyAsync =
        widget.history ??
        ref.watch<AsyncValue<List<AgentChatMessage>>>(
          agentChatProjectionProvider(widget.agentId),
        );
    final messages = historyAsync.value;
    final latestMessageId = messages?.lastOrNull?.id;
    final shouldScroll =
        messages != null &&
        ((_lastMessageId != latestMessageId &&
                (widget.scrollOnReplies ||
                    messages.lastOrNull?.role == AgentChatRole.user)) ||
            (!_wasSending && widget.isSending));
    _lastMessageId = latestMessageId;
    _wasSending = widget.isSending;
    if (shouldScroll) _scrollToLatest();
    // What scrolls in above the first message, with the thread.
    final lead = widget.leading == null ? 0 : 1;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
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
                    ? widget.emptyState ??
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(tokens.spacing.step5),
                              child: Text(
                                widget.emptyMessage ??
                                    context.messages.goalChatEmpty(
                                      widget.agentName,
                                    ),
                                textAlign: TextAlign.center,
                                style: tokens.typography.styles.body.bodyMedium
                                    .copyWith(
                                      color: tokens.colors.text.mediumEmphasis,
                                    ),
                              ),
                            ),
                          )
                    : _followThread(
                        ListView.builder(
                          key: widget.conversationId == null
                              ? null
                              : PageStorageKey(widget.conversationId),
                          controller: _scrollController,
                          padding: EdgeInsets.all(tokens.spacing.step5),
                          itemCount:
                              lead +
                              history.length +
                              (widget.isSending ? 1 : 0),
                          itemBuilder: (context, at) {
                            if (at < lead) return widget.leading!;
                            final index = at - lead;
                            if (index == history.length) {
                              return widget.activity ??
                                  _ThinkingBubble(
                                    conversational: widget.conversational,
                                    label:
                                        widget.sendingLabel ??
                                        context.messages.goalChatResponding(
                                          widget.agentName,
                                        ),
                                  );
                            }
                            final message = history[index];
                            final groupAttachment =
                                widget.groupAttachmentsWithReply &&
                                message.role == AgentChatRole.agent;
                            final attachment = widget.attachmentBuilder?.call(
                              context,
                              message,
                            );
                            final divider = widget.dividerBuilder?.call(
                              context,
                              message,
                              index == 0 ? null : history[index - 1],
                            );
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: tokens.spacing.cardItemSpacing,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (divider != null) ...[
                                    KeyedSubtree(
                                      key: ValueKey(
                                        'goal-chat-divider-${message.id}',
                                      ),
                                      child: divider,
                                    ),
                                    SizedBox(height: tokens.spacing.step2),
                                  ],
                                  _MessageBubble(
                                    key: ValueKey(
                                      'goal-chat-message-${message.id}',
                                    ),
                                    message: message,
                                    agentName: widget.agentName,
                                    measuredHeights: _measuredHeights,
                                    conversational: widget.conversational,
                                    replyTextStyle: widget.replyTextStyle,
                                    onLinkTap: widget.onLinkTap == null
                                        ? null
                                        : (url, title) => widget.onLinkTap!(
                                            message,
                                            url,
                                            title,
                                          ),
                                    attachment: groupAttachment
                                        ? attachment
                                        : null,
                                    footerTrailing: widget.footerTrailingBuilder
                                        ?.call(context, message),
                                  ),
                                  if (attachment != null &&
                                      !groupAttachment) ...[
                                    SizedBox(height: tokens.spacing.step2),
                                    KeyedSubtree(
                                      key: ValueKey(
                                        'goal-chat-attachment-${message.id}',
                                      ),
                                      child: attachment,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
            },
          ),
          if (widget.isSending && widget.pinnedActivity != null)
            widget.pinnedActivity!,
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
          ?widget.footer,
          if (widget.composerEnabled)
            _ChatComposer(
              availableHeight: constraints.maxHeight,
              controller: _controller,
              hintText:
                  widget.composerHint ??
                  context.messages.goalChatPlaceholder(widget.agentName),
              isSending: widget.isSending,
              allowDraftWhileSending: widget.allowDraftWhileSending,
              showVoiceDetails: widget.showVoiceDetails,
              sendingLabel:
                  widget.sendingLabel ??
                  context.messages.goalChatResponding(widget.agentName),
              draft: widget.draft,
              onDraftChanged: widget.onDraftChanged,
              onSend: widget.onSend,
              shape: widget.composerShape,
              voiceFirst: widget.voiceFirst,
              resolveTranscriptionTarget: widget.resolveTranscriptionTarget,
            ),
        ],
      ),
    );
  }
}
