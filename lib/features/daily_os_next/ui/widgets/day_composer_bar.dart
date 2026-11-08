import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
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
/// Sized to the Day surface's reading column on wide screens, full width on a
/// phone, on the same glass strip as the other Day footers.
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
    this.trailing,
    this.enabled = true,
    super.key,
  });

  /// Shown above the field, inside the bar's reading column — quick
  /// refinements on a planned day. Hidden while a take runs, so nothing
  /// opens a flow over a take that is still recording.
  final Widget? header;

  /// Beside the field, in thumb reach, while the field is empty and nothing
  /// records — the day's next step. Typing or speaking a change gives the
  /// field the whole width.
  final Widget? trailing;

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

  /// The next step beside the field follows the draft, so text a host sets
  /// (a transcript) gives the field the width just as typing does.
  void _onText() => setState(() {});

  bool get _composing => widget.phase == DesignSystemChatInputPhase.compose;

  void _send() {
    final words = _controller.text.trim();
    if (words.isEmpty) return;
    widget.onSubmitText(words);
  }

  Widget _withTrailing(BuildContext context, Widget field) {
    final trailing = widget.trailing;
    if (trailing == null) return field;
    final show = _composing && _controller.text.trim().isEmpty;
    // Same widget at the same index either way, so the field keeps its
    // state and focus while the next step comes and goes.
    return _FieldWithTrailing(
      gap: show ? context.designTokens.spacing.step3 : 0,
      children: [field, if (show) trailing else const SizedBox.shrink()],
    );
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DayComposerBar.maxWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header case final header? when _composing) ...[
                  header,
                  SizedBox(height: tokens.spacing.step3),
                ],
                _withTrailing(
                  context,
                  DesignSystemChatInput(
                    controller: _controller,
                    hintText: widget.hintText,
                    enabled: widget.enabled,
                    errorText: widget.errorText,
                    phase: widget.phase,
                    levels: widget.levels,
                    sampleInterval: widget.sampleInterval,
                    elapsed: widget.elapsed,
                    onSend: _send,
                    onStartRecording: widget.onStartVoice,
                    onCancelRecording: widget.onCancelRecording,
                    onFinishRecording: widget.onFinishRecording,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The field with the day's next step beside it while the field keeps at
/// least half the bar, and the step under it, full width, once it needs
/// more — large text on a narrow phone. Either way it stays at the bottom,
/// in thumb reach.
class _FieldWithTrailing extends MultiChildRenderObjectWidget {
  const _FieldWithTrailing({required this.gap, required super.children});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFieldWithTrailing(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFieldWithTrailing renderObject,
  ) {
    renderObject.gap = gap;
  }
}

class _FieldWithTrailingParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFieldWithTrailing extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FieldWithTrailingParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _FieldWithTrailingParentData
        > {
  _RenderFieldWithTrailing(this._gap);

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FieldWithTrailingParentData) {
      child.parentData = _FieldWithTrailingParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final field = firstChild!;
    final trailing = childAfter(field)!
      ..layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final fieldData = field.parentData! as _FieldWithTrailingParentData;
    final trailingData = trailing.parentData! as _FieldWithTrailingParentData;
    final beside = trailing.size.width <= (width - _gap) / 2;
    if (beside) {
      field.layout(
        BoxConstraints.tightFor(width: width - _gap - trailing.size.width),
        parentUsesSize: true,
      );
      final height = math.max(field.size.height, trailing.size.height);
      fieldData.offset = Offset(0, (height - field.size.height) / 2);
      trailingData.offset = Offset(
        width - trailing.size.width,
        (height - trailing.size.height) / 2,
      );
      size = constraints.constrain(Size(width, height));
      return;
    }
    field.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    trailing.layout(
      BoxConstraints.tightFor(width: width),
      parentUsesSize: true,
    );
    fieldData.offset = Offset.zero;
    trailingData.offset = Offset(0, field.size.height + _gap);
    size = constraints.constrain(
      Size(width, field.size.height + _gap + trailing.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
