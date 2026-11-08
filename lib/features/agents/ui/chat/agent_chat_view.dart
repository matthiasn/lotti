import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_typing_indicator.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_error_message.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:material_ui/material_ui.dart';

part 'agent_chat_view_collapsible_markdown_part.dart';
part 'agent_chat_view_transcription_progress_state_part.dart';
part 'agent_chat_view_voice_first_part.dart';

class _AgentChatViewState extends ConsumerState<AgentChatView> {
  late final TextEditingController _controller;
  final _scrollController = ScrollController();
  late final ProviderSubscription<ChatRecorderState> _recorderSubscription;
  String? _lastMessageId;
  bool _wasSending = false;

  /// Whether the draft came from what was said: sent, it goes out as a
  /// spoken turn ([AgentChatView.onSendSpoken]). Cleared once the field is
  /// emptied or the draft is sent.
  bool _draftSpoken = false;

  /// The field's words to the host, as they change — typed, dictated or
  /// completed by `@`.
  void _onTyped() {
    final text = _controller.text;
    if (text.isEmpty) _draftSpoken = false;
    if (text != widget.draft) widget.onDraftChanged(text);
  }

  /// Sends the draft: as a spoken turn when it came from what was said —
  /// here, or by the host's record ([AgentChatView.draftSpoken]).
  void _send() {
    final spoken = widget.draftSpoken ?? _draftSpoken;
    _draftSpoken = false;
    final sendSpoken = widget.onSendSpoken;
    if (spoken && sendSpoken != null) {
      sendSpoken();
    } else {
      widget.onSend();
    }
  }

  /// Whether the thread keeps to its latest message as it grows: set by
  /// every scroll to the latest, cleared once the user scrolls away from
  /// the bottom, set again when they come back. A reply's cards, a door's
  /// answer and a lazily built list's real height all arrive after the
  /// reply's own frame; following the growth keeps the newest in view
  /// where a single jump landed short of it.
  bool _followLatest = true;

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
    _controller = TextEditingController(text: widget.draft)
      ..addListener(_onTyped);
    _wasSending = widget.isSending;
    if (widget.conversationId != null) {
      _lastMessageId = widget.history?.value?.lastOrNull?.id;
      // A conversation restored where it was left keeps its place until
      // something new arrives or the user returns to the bottom.
      _followLatest = false;
    }
    _recorderSubscription = ref.listenManual<ChatRecorderState>(
      chatRecorderControllerProvider,
      (previous, next) {
        // Under a route that covers it (the companion's stage over her
        // chat, a task opened from it) the result is left pending: the view
        // in front takes it, or this one does once it is in front again
        // ([didChangeDependencies]) — never both, which would land the
        // words twice.
        if (!mounted || !_inFront) return;
        _takeRecorderResult(previous, next);
      },
    );
  }

  /// Whether this view is where anything is said: it has a composer, and
  /// no route covers it.
  bool get _inFront =>
      widget.composerEnabled && (ModalRoute.isCurrentOf(context) ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Back in front: a recording that finished while a route covered this
    // view lands now. After the frame — taking it writes the field and the
    // recorder, which a build must not.
    if (!_inFront) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inFront) {
        _takeRecorderResult(null, ref.read(chatRecorderControllerProvider));
      }
    });
  }

  /// Acts on the shared recorder's finished result: an error as a toast, a
  /// transcript into the field. Either is then cleared, so it is taken once.
  void _takeRecorderResult(
    ChatRecorderState? previous,
    ChatRecorderState next,
  ) {
    final error = next.error?.trim();
    if (error != null && error.isNotEmpty && error != previous?.error) {
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
    if (next.transcript != null && next.transcript != previous?.transcript) {
      final transcript = next.transcript!.trim();
      if (transcript.isNotEmpty) {
        // What was said lands in the field, after anything already
        // there, to be read and corrected before Send — nothing goes
        // out by itself.
        final before = _controller.text.trimRight();
        final text = before.isEmpty ? transcript : '$before $transcript';
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _draftSpoken = true;
        widget.onDraftSpoken?.call();
      }
      ref.read(chatRecorderControllerProvider.notifier).clearResult();
    }
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

  /// Keeps the thread at its latest message while [_followLatest] holds,
  /// whenever the content grows. The thread's own list only (depth 0
  /// here), never a scroll nested inside a message or the composer.
  Widget _followThread(Widget list, {required double nearBottom}) {
    return NotificationListener<Notification>(
      onNotification: (notification) {
        switch (notification) {
          // The reader turning back up lets go at once: a slow drag still
          // within [nearBottom] of the end would otherwise be pulled back
          // by every metrics change under it — each row laid out above
          // corrects the list's extent — and never get away.
          case UserScrollNotification(
            depth: 0,
            direction: ScrollDirection.forward,
          ):
            _followLatest = false;
          // Where a scroll leaves the reader decides whether to follow
          // again: every scroll — a drag, a wheel, a fling, a jump to the
          // latest — where it ends. Content growing is no scroll.
          case ScrollEndNotification(depth: 0, :final metrics):
            _followLatest = metrics.extentAfter <= nearBottom;
          // A host that keeps replies where they start (query chat, whose
          // reader reads an answer and its evidence from the top) is not
          // followed as they grow.
          case ScrollMetricsNotification(depth: 0, :final metrics)
              when widget.scrollOnReplies &&
                  _followLatest &&
                  metrics.extentAfter > 0:
            _scrollToLatest();
        }
        return false;
      },
      child: list,
    );
  }

  void _scrollToLatest() {
    _followLatest = true;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // In a reading column the side gutter grows with the window, so the
        // messages keep to the composer's width while the whole pane
        // scrolls; never under the usual gutter on a narrow one.
        final maxWidth = widget.contentMaxWidth;
        final gutter = maxWidth == null
            ? tokens.spacing.step5
            : math.max(
                tokens.spacing.step5,
                (constraints.maxWidth - maxWidth) / 2,
              );
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
                                  style: tokens
                                      .typography
                                      .styles
                                      .body
                                      .bodyMedium
                                      .copyWith(
                                        color:
                                            tokens.colors.text.mediumEmphasis,
                                      ),
                                ),
                              ),
                            )
                      : _followThread(
                          nearBottom: tokens.spacing.step9,
                          ListView.builder(
                            key: widget.conversationId == null
                                ? null
                                : PageStorageKey(widget.conversationId),
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: gutter,
                              vertical: tokens.spacing.step5,
                            ),
                            itemCount:
                                history.length + (widget.isSending ? 1 : 0),
                            itemBuilder: (context, index) {
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (divider != null) ...[
                                      KeyedSubtree(
                                        key: ValueKey(
                                          'goal-chat-divider-${message.id}',
                                        ),
                                        child: divider,
                                      ),
                                      SizedBox(height: tokens.spacing.step3),
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
                                      replyBodyBuilder: widget.replyBodyBuilder,
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
                                      footerTrailing: widget
                                          .footerTrailingBuilder
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
                contentMaxWidth: maxWidth,
                controller: _controller,
                helperText: widget.composerHelper,
                mentionOptions: widget.mentionOptions,
                hintText:
                    widget.composerHint ??
                    context.messages.goalChatPlaceholder(widget.agentName),
                isSending: widget.isSending,
                allowDraftWhileSending: widget.allowDraftWhileSending,
                sendingLabel:
                    widget.sendingLabel ??
                    context.messages.goalChatResponding(widget.agentName),
                onSend: _send,
                voiceFirst: widget.voiceFirst,
                resolveTranscriptionTarget: widget.resolveTranscriptionTarget,
                correctTranscript: widget.correctTranscript,
                resolveDictionaryCategory: widget.resolveDictionaryCategory,
              ),
          ],
        );
      },
    );
  }
}
