import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input_mentions.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_voice_waveform.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

export 'design_system_chat_input_mentions.dart'
    show DesignSystemChatInputMention;

/// What the chat input is doing.
enum DesignSystemChatInputPhase {
  /// Taking words: typed, or dictated and landed to be read before sending.
  compose,

  /// Listening: the microphone is live.
  recording,

  /// What was said is being turned into words.
  transcribing,
}

/// Stable keys for the chat input's parts.
@visibleForTesting
abstract final class DesignSystemChatInputKeys {
  static const Key card = Key('ds-chat-input');
  static const Key field = Key('ds-chat-input-field');
  static const Key helper = Key('ds-chat-input-helper');
  static const Key mic = Key('ds-chat-input-mic');
  static const Key send = Key('ds-chat-input-send');
  static const Key cancel = Key('ds-chat-input-cancel');
  static const Key elapsed = Key('ds-chat-input-elapsed');
  static const Key waveform = Key('ds-chat-input-waveform');
  static const Key done = Key('ds-chat-input-done');
  static const Key transcribing = Key('ds-chat-input-transcribing');
  static const Key error = Key('ds-chat-input-error');
  static const Key retry = Key('ds-chat-input-retry');
}

/// The one input every conversation in the app is asked through — typed or
/// said — as a single card that keeps its place, width and height in every
/// state.
///
/// The words take the card's whole width on top and grow a line at a time,
/// up to [maxLines], then scroll inside: a long dictation is never one
/// clipped line under a button. Under them, one row: the host's
/// [helperText] (plus, where there is a keyboard, how Enter and Shift+Enter
/// work) and the controls. The mic is always there — the teal control while
/// the field is empty, a quiet one beside the teal send once there are words
/// — so the input never stops offering voice.
///
/// Recording changes only that row: cancel, the live dot and the time, the
/// voice as bars across all the width there is ([DesignSystemVoiceWaveform]),
/// and Done. Done ends the take; the host puts what was said in the field
/// (through [controller]) to be read, corrected and sent like typed words —
/// nothing is sent until Send. While [phase] is transcribing, a spinner holds
/// the controls and [partialTranscript], when the host has one, shows where
/// the words will land. Escape cancels a take.
///
/// Typing `@` offers [mentionOptions] above the card, filtered as the word
/// goes on; arrows and Enter, or a tap, put `@Label` in the text, Escape
/// closes the list. A host with no options offers none, and says nothing
/// about `@` in its helper.
///
/// [busyText], while set, says what the conversation is doing (her answer on
/// its way) in the field's place, and nothing can be sent or said until it
/// clears. [errorText] stands on its own line above the card, with Try again
/// when [onRetry] is given; the words stay in the field.
class DesignSystemChatInput extends StatefulWidget {
  const DesignSystemChatInput({
    required this.controller,
    required this.hintText,
    required this.onSend,
    required this.onStartRecording,
    this.phase = DesignSystemChatInputPhase.compose,
    this.levels = const [],
    this.sampleInterval = DesignSystemVoiceWaveform.defaultSampleInterval,
    this.elapsed = Duration.zero,
    this.onCancelRecording,
    this.onFinishRecording,
    this.partialTranscript,
    this.helperText,
    this.showKeyboardHint,
    this.busyText,
    this.errorText,
    this.onRetry,
    this.mentionOptions = const [],
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 6,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;

  /// Sends the words in [controller]; null while nothing may be sent.
  final VoidCallback? onSend;

  /// Opens the microphone; null while it may not.
  final VoidCallback? onStartRecording;

  final DesignSystemChatInputPhase phase;

  /// The take's loudness, `0..1`, oldest first, one per [sampleInterval].
  final List<double> levels;
  final Duration sampleInterval;
  final Duration elapsed;
  final VoidCallback? onCancelRecording;

  /// Ends the take, for its words to land in the field.
  final VoidCallback? onFinishRecording;

  /// The words as they arrive while transcribing.
  final String? partialTranscript;

  /// What the host wants said under the field — only what it supports.
  final String? helperText;

  /// Whether to add how Enter and Shift+Enter work; by default only on a
  /// desktop platform, where there is a keyboard to press them on.
  final bool? showKeyboardHint;

  /// What the conversation is doing while nothing can be sent.
  final String? busyText;
  final String? errorText;
  final VoidCallback? onRetry;

  /// What `@` offers; none, no `@`.
  final List<DesignSystemChatInputMention> mentionOptions;

  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final int maxLines;

  @override
  State<DesignSystemChatInput> createState() => _DesignSystemChatInputState();
}

class _DesignSystemChatInputState extends State<DesignSystemChatInput> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  final _mentions = DesignSystemChatInputMentionController();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _focus.addListener(_onFocus);
    // Words handed in with an `@` before the caret open its list as the
    // input appears, once the list's anchor is there to show it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onText();
    });
  }

  @override
  void didUpdateWidget(covariant DesignSystemChatInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    _onText();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _mentions.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  void _onText() {
    _mentions.update(
      widget.controller.value,
      options: _composing ? widget.mentionOptions : const [],
    );
    if (mounted) setState(() {});
  }

  bool get _composing =>
      widget.phase == DesignSystemChatInputPhase.compose &&
      widget.busyText == null &&
      widget.enabled;

  bool get _hasWords => widget.controller.text.trim().isNotEmpty;

  bool get _canSend => _composing && _hasWords && widget.onSend != null;

  bool get _canRecord => _composing && widget.onStartRecording != null;

  void _send() {
    if (!_canSend) return;
    widget.onSend!();
  }

  void _pick(DesignSystemChatInputMention option) {
    widget.controller.value = _mentions.insert(widget.controller.value, option);
    _focus.requestFocus();
  }

  /// Enter sends and Shift+Enter breaks a line; while `@` is offering, the
  /// arrows move through it, Enter or Tab picks and Escape closes it.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_mentions.isOpen) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _mentions.move(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _mentions.move(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _mentions.dismiss();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.tab)) {
        final option = _mentions.highlighted;
        if (option != null) _pick(option);
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _keyboardHint =>
      widget.showKeyboardHint ??
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final recording = widget.phase == DesignSystemChatInputPhase.recording;
    final transcribing =
        widget.phase == DesignSystemChatInputPhase.transcribing;
    final live = recording || transcribing;
    final error = widget.errorText;

    final card = DesignSystemChatInputMentionAnchor(
      controller: _mentions,
      onPick: _pick,
      child: AnimatedContainer(
        key: DesignSystemChatInputKeys.card,
        duration: MotionDurations.short3,
        curve: MotionCurves.standard,
        decoration: BoxDecoration(
          color: tokens.colors.surface.enabled,
          borderRadius: BorderRadius.circular(tokens.radii.l),
          border: Border.all(
            color: designSystemFieldBorderColor(
              tokens,
              focused: _focused || live,
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step4,
          tokens.spacing.step3,
          tokens.spacing.step3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tokens.spacing.step3,
          children: [
            _words(context, transcribing: transcribing, recording: recording),
            AnimatedSwitcher(
              duration: MotionDurations.short4,
              switchInCurve: MotionCurves.standard,
              switchOutCurve: MotionCurves.standard,
              child: recording
                  ? _RecordingRow(
                      key: const ValueKey('recording'),
                      levels: widget.levels,
                      sampleInterval: widget.sampleInterval,
                      elapsed: widget.elapsed,
                      onCancel: widget.onCancelRecording,
                      onDone: widget.onFinishRecording,
                    )
                  : _ControlsRow(
                      key: const ValueKey('controls'),
                      helper: transcribing
                          ? messages.timelineTranscribing
                          : [
                              ?widget.helperText,
                              if (_keyboardHint) messages.chatInputKeyboardHint,
                            ].join(' · '),
                      transcribing: transcribing,
                      hasWords: _hasWords,
                      onCancel: widget.onCancelRecording,
                      onRecord: _canRecord ? widget.onStartRecording : null,
                      onSend: _canSend ? _send : null,
                    ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tokens.spacing.step3,
      children: [
        if (error != null)
          Semantics(
            liveRegion: true,
            container: true,
            child: Row(
              key: DesignSystemChatInputKeys.error,
              spacing: tokens.spacing.step3,
              children: [
                Icon(
                  LottiIcons.error,
                  size: IconSizes.s,
                  color: tokens.colors.alert.error.ink,
                ),
                Expanded(
                  child: Text(
                    error,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.alert.error.ink,
                    ),
                  ),
                ),
                if (widget.onRetry != null)
                  DesignSystemButton(
                    key: DesignSystemChatInputKeys.retry,
                    label: messages.aiInferenceErrorRetryButton,
                    variant: DesignSystemButtonVariant.tertiary,
                    size: DesignSystemButtonSize.dense,
                    onPressed: widget.onRetry,
                  ),
              ],
            ),
          ),
        // Escape cancels a take wherever focus is inside the input.
        CallbackShortcuts(
          bindings: {
            if (live && widget.onCancelRecording != null)
              const SingleActivator(LogicalKeyboardKey.escape):
                  widget.onCancelRecording!,
          },
          child: card,
        ),
      ],
    );
  }

  /// The words: the field while composing; while transcribing, what has
  /// arrived so far, quieter, where it will land.
  Widget _words(
    BuildContext context, {
    required bool transcribing,
    required bool recording,
  }) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.body.bodyMedium;
    if (transcribing) {
      final partial = widget.partialTranscript?.trim() ?? '';
      final draft = widget.controller.text.trim();
      final shown = [draft, partial].where((s) => s.isNotEmpty).join(' ');
      return Text(
        shown.isEmpty ? context.messages.timelineTranscribing : shown,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: style.copyWith(color: tokens.colors.text.mediumEmphasis),
      );
    }
    final busy = widget.busyText;
    return TextFieldTapRegion(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: TextField(
          key: DesignSystemChatInputKeys.field,
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          enabled: widget.enabled && busy == null,
          readOnly: recording,
          minLines: 1,
          maxLines: widget.maxLines,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: tokens.colors.interactive.enabled,
          style: style.copyWith(color: tokens.colors.text.highEmphasis),
          decoration: InputDecoration.collapsed(
            hintText:
                busy ??
                (recording
                    ? context.messages.chatInputListening
                    : widget.hintText),
            hintStyle: style.copyWith(color: tokens.colors.text.lowEmphasis),
          ),
        ),
      ),
    );
  }
}

/// The row under the words while composing or transcribing: the helper,
/// then the mic (always) and send (once there are words) — or, while
/// transcribing, cancel and a spinner in their place.
class _ControlsRow extends StatelessWidget {
  const _ControlsRow({
    required this.helper,
    required this.transcribing,
    required this.hasWords,
    required this.onCancel,
    required this.onRecord,
    required this.onSend,
    super.key,
  });

  final String helper;
  final bool transcribing;
  final bool hasWords;
  final VoidCallback? onCancel;
  final VoidCallback? onRecord;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      spacing: tokens.spacing.step2,
      children: [
        Expanded(
          child: Text(
            helper,
            key: DesignSystemChatInputKeys.helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
        if (transcribing) ...[
          DesignSystemChatInputDisc(
            key: DesignSystemChatInputKeys.cancel,
            icon: LottiIcons.close,
            tooltip: messages.chatInputCancelRecording,
            onPressed: onCancel,
          ),
          SizedBox.square(
            key: DesignSystemChatInputKeys.transcribing,
            dimension: tokens.spacing.step8,
            child: Center(
              child: DesignSystemSpinner(
                style: DesignSystemSpinnerStyle.plain,
                size: IconSizes.m,
                semanticsLabel: messages.timelineTranscribing,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ] else ...[
          DesignSystemChatInputDisc(
            key: DesignSystemChatInputKeys.mic,
            icon: LottiIcons.mic,
            tooltip: messages.chatInputRecordVoice,
            // Teal while it is the way in; quiet once send leads.
            primary: !hasWords,
            onPressed: onRecord,
          ),
          if (hasWords)
            DesignSystemChatInputDisc(
              key: DesignSystemChatInputKeys.send,
              icon: LottiIcons.arrowUp,
              tooltip: messages.chatInputSendTooltip,
              primary: true,
              onPressed: onSend,
            ),
        ],
      ],
    );
  }
}

/// The row under the words while listening: cancel, the live dot and the
/// time, the voice across all the width left, and Done.
class _RecordingRow extends StatelessWidget {
  const _RecordingRow({
    required this.levels,
    required this.sampleInterval,
    required this.elapsed,
    required this.onCancel,
    required this.onDone,
    super.key,
  });

  final List<double> levels;
  final Duration sampleInterval;
  final Duration elapsed;
  final VoidCallback? onCancel;
  final VoidCallback? onDone;

  static String formatElapsed(Duration elapsed) =>
      '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Semantics(
      container: true,
      liveRegion: true,
      label: messages.chatInputListening,
      child: Row(
        spacing: tokens.spacing.step3,
        children: [
          DesignSystemChatInputDisc(
            key: DesignSystemChatInputKeys.cancel,
            icon: LottiIcons.close,
            tooltip: messages.chatInputCancelRecording,
            onPressed: onCancel,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.alert.error.defaultColor,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: tokens.spacing.step3),
          ),
          Text(
            formatElapsed(elapsed),
            key: DesignSystemChatInputKeys.elapsed,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Expanded(
            child: DesignSystemVoiceWaveform(
              key: DesignSystemChatInputKeys.waveform,
              levels: levels,
              sampleInterval: sampleInterval,
            ),
          ),
          DesignSystemChatInputDisc(
            key: DesignSystemChatInputKeys.done,
            icon: LottiIcons.confirm,
            tooltip: messages.chatInputFinishRecording,
            primary: true,
            onPressed: onDone,
          ),
        ],
      ),
    );
  }
}

/// A round control of the chat input: teal with dark ink when [primary],
/// else the field's quiet overlay. A 40 disc inside a 44 target.
@visibleForTesting
class DesignSystemChatInputDisc extends StatelessWidget {
  const DesignSystemChatInputDisc({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final disc = tokens.spacing.step8;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: primary
            ? tokens.colors.interactive.enabled
            : tokens.colors.surface.enabled,
        foregroundColor: primary
            ? tokens.colors.text.onInteractiveAlert
            : tokens.colors.text.mediumEmphasis,
        disabledBackgroundColor: tokens.colors.surface.enabled,
        disabledForegroundColor: tokens.colors.text.lowEmphasis,
        fixedSize: Size.square(disc),
        minimumSize: Size.square(disc),
        tapTargetSize: MaterialTapTargetSize.padded,
        animationDuration: MotionDurations.short3,
      ),
      icon: Icon(icon, size: IconSizes.m),
    );
  }
}
