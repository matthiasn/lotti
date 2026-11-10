import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Talks to the day's agent from the bottom of the Day surface, in the one
/// input every Lotti conversation uses ([DesignSystemChatInput]): the mic
/// and, once there are words, send beside it; while a take records, the
/// voice across the whole row, then Done.
///
/// The bar owns only the layout and, unless the host passes a [controller],
/// the draft. What a spoken or a typed message *does* is the host's call:
/// [onStartVoice] when the mic is tapped, [onSubmitText] with the trimmed
/// words when they are sent. The draft is deliberately not cleared on send —
/// the host opens a flow over the day, and words a user typed should still
/// be here if they back out of it.
///
/// While a take runs the host passes its [phase] and levels; Done
/// ([onFinishRecording]) ends it and the host puts the words in the field
/// to be read before sending. [errorText] reads above the field.
///
/// On the Day surface's reading column — the page's shared measure from the
/// left rail — on wide screens, full width on a phone, on the same glass
/// strip as the other Day footers.
class DayComposerBar extends StatefulWidget {
  const DayComposerBar({
    required this.hintText,
    required this.onStartVoice,
    required this.onSubmitText,
    this.controller,
    this.phase = DesignSystemChatInputPhase.compose,
    this.levels = const [],
    this.sampleInterval = DesignSystemVoiceWaveform.defaultSampleInterval,
    this.elapsed = Duration.zero,
    this.onCancelRecording,
    this.onFinishRecording,
    this.errorText,
    this.header,
    this.nextStep,
    this.enabled = true,
    super.key,
  });

  /// Shown above the field, inside the bar's reading column — quick
  /// refinements on a planned day — while the field has focus: at rest the
  /// footer is just the field, so the day keeps the room. Hidden while a take
  /// runs, so nothing opens a flow over a take that is still recording.
  final Widget? header;

  /// The day's next step, in the input's bottom row beside the mic while the
  /// field is empty and nothing records; typed or dictated words take its
  /// place.
  final Widget? nextStep;

  /// False while the host cannot yet tell whether a check-in can go
  /// anywhere: the field shows but takes no words, so nothing typed can be
  /// lost when the footer turns out to need setup instead.
  final bool enabled;

  final String hintText;
  final VoidCallback onStartVoice;
  final ValueChanged<String> onSubmitText;

  /// The field's text, when the host needs to fill it — a finished
  /// transcript lands here for review. The bar owns one otherwise.
  final TextEditingController? controller;

  /// What the take is doing; composing between takes.
  final DesignSystemChatInputPhase phase;

  /// The take's loudness, `0..1`, one per [sampleInterval].
  final List<double> levels;
  final Duration sampleInterval;
  final Duration elapsed;
  final VoidCallback? onCancelRecording;
  final VoidCallback? onFinishRecording;

  final String? errorText;

  @override
  State<DayComposerBar> createState() => _DayComposerBarState();
}

class _DayComposerBarState extends State<DayComposerBar> {
  TextEditingController? _ownController;

  /// Whether the field has focus, which is when the [DayComposerBar.header]
  /// shows.
  final FocusNode _focus = FocusNode(debugLabel: 'DayComposerBar');

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focus.addListener(_onText);
  }

  @override
  void didUpdateWidget(DayComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focus
      ..removeListener(_onText)
      ..dispose();
    _ownController?.dispose();
    super.dispose();
  }

  /// The next step follows the draft, so text a host sets (a transcript)
  /// hides it just as typing does; the header follows the field's focus.
  void _onText() => setState(() {});

  bool get _composing => widget.phase == DesignSystemChatInputPhase.compose;

  void _send() {
    final words = _controller.text.trim();
    if (words.isEmpty) return;
    widget.onSubmitText(words);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemGlassStrip(
      child: Padding(
        // step5: the page's content rail, shared with the header and the
        // timeline toolbar.
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step4,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            // The page column, less this strip's own rail on each side, so
            // the field's edges meet the briefing's and the agenda's.
            constraints: BoxConstraints(
              maxWidth: kDetailContentMaxWidth - tokens.spacing.step5 * 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header case final header?
                    when _composing && _focus.hasFocus) ...[
                  // Part of the field for tap-outside purposes, so tapping a
                  // chip does not unfocus the field and take the chip away
                  // before the tap lands.
                  TextFieldTapRegion(child: header),
                  SizedBox(height: tokens.spacing.step3),
                ],
                DesignSystemChatInput(
                  controller: _controller,
                  focusNode: _focus,
                  hintText: widget.hintText,
                  enabled: widget.enabled,
                  errorText: widget.errorText,
                  phase: widget.phase,
                  levels: widget.levels,
                  sampleInterval: widget.sampleInterval,
                  elapsed: widget.elapsed,
                  // The input's own row holds the next step, so the field
                  // keeps the width, state and focus as it comes and goes.
                  leading: _controller.text.trim().isEmpty
                      ? widget.nextStep
                      : null,
                  onSend: _send,
                  onStartRecording: widget.onStartVoice,
                  onCancelRecording: widget.onCancelRecording,
                  onFinishRecording: widget.onFinishRecording,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
