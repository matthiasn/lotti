import 'package:lotti/features/agents/ui/chat/chat_composer_field.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Talks to the day's agent from the bottom of the Day surface: one docked
/// field that is the mic while it is empty and the send arrow once there are
/// words — the same field every Lotti chat uses ([ChatComposerField]).
///
/// The bar owns only the layout and, unless the host passes a [controller],
/// the draft. What a spoken or a typed message *does* is the host's call:
/// [onStartVoice] when the mic is tapped, [onSubmitText] with the trimmed
/// words when they are sent. The draft is deliberately not cleared on send —
/// the host opens a flow over the day, and words a user typed should still
/// be here if they back out of it.
///
/// While a recording runs, the host passes [replacement] (the recording
/// pill) and the bar shows it in the field's place, so speaking and typing
/// happen in the same spot. [errorText] reads under the field.
///
/// Sized to the Day surface's reading column on wide screens, full width on a
/// phone, on the same glass strip as the other Day footers.
class DayComposerBar extends StatefulWidget {
  const DayComposerBar({
    required this.hintText,
    required this.onStartVoice,
    required this.onSubmitText,
    this.controller,
    this.replacement,
    this.errorText,
    this.enabled = true,
    super.key,
  });

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

  /// Shown in the field's place while non-null.
  final Widget? replacement;

  final String? errorText;

  /// The Day surface's reading width, shared with the review footer so the
  /// composer belongs to the content column rather than the page chrome.
  static const double maxWidth = 760;

  @override
  State<DayComposerBar> createState() => _DayComposerBarState();
}

class _DayComposerBarState extends State<DayComposerBar> {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
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
    _ownController?.dispose();
    super.dispose();
  }

  /// The draft follows the controller, so text a host sets (a transcript)
  /// turns the mic into send just as typing does.
  void _onText() => setState(() {});

  void _send() {
    final words = _controller.text.trim();
    if (words.isEmpty) return;
    widget.onSubmitText(words);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final errorText = widget.errorText;
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DayComposerBar.maxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.replacement ??
                    ChatComposerField(
                      controller: _controller,
                      hintText: widget.hintText,
                      draft: _controller.text,
                      // The controller listener tracks the draft.
                      onDraftChanged: (_) {},
                      onSend: _send,
                      onStartRecording: widget.onStartVoice,
                      enabled: widget.enabled,
                    ),
                if (errorText != null) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    errorText,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.alert.error.defaultColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
