import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// An [InkWell] with every Material overlay silenced — no hover fill, no
/// focus fill, no splash, no highlight — that instead reports its interaction
/// state to [builder] so the content shifts its *own* ink.
///
/// This is the tap wrapper for quiet targets: text links, disclosure rows,
/// header blocks and glyph buttons whose resting form does not look like a
/// button. On those, Material's default overlay paints a rectangle around
/// content that never advertised a boundary — a phantom button that appears
/// on hover and vanishes on exit. The design-system buttons and chips already
/// suppress the overlay and re-express state through their own fills
/// (`DesignSystemButton`, `DesignSystemChip`); this widget gives ad-hoc
/// targets the same contract without each one re-implementing the
/// state-tracking scaffold.
///
/// [builder] receives `highlighted`, true while the pointer hovers, the
/// target holds keyboard focus, or a press is in flight. Folding focus in is
/// deliberate: with `focusColor` transparent, the builder's ink shift is the
/// only visible cue keyboard users get. Folding the press in restores tap
/// feedback on touch, where the removed splash used to carry it.
///
/// A builder that deliberately shows nothing on hover — a whole-card doorway,
/// a data cell whose hover answer is a tooltip — must still be findable by
/// keyboard. [focusRing] is the cue for that class: an interactive-ink
/// outline drawn only while the target holds keyboard focus, never on hover
/// or press, so the pointer experience stays exactly as quiet as the builder
/// made it.
///
/// The widget adds no semantics of its own beyond [InkWell]'s tap action —
/// callers keep their existing [Semantics] wrappers. It supplies the click
/// cursor through [InkWell]'s built-in [MouseRegion].
class DsQuietInk extends StatefulWidget {
  const DsQuietInk({
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
    this.excludeFromSemantics = false,
    this.canRequestFocus = true,
    this.focusRing = false,
    super.key,
  });

  /// Builds the target's content. `highlighted` is true on hover, keyboard
  /// focus, or while pressed; the content answers with a token-level ink or
  /// border shift of its own rather than a painted overlay.
  ///
  /// Positional bool by design, matching the codebase's builder idiom
  /// (`StaleAsyncValue`): a builder signature reads best positionally.
  // ignore: avoid_positional_boolean_parameters
  final Widget Function(BuildContext context, bool highlighted) builder;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Clip/shape for the ink response that no longer paints; still forwarded
  /// so the focus traversal highlight and hit-testing keep the right shape.
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;

  /// Forwarded to [InkWell.excludeFromSemantics] for pointer-only enlarged
  /// targets whose accessible control lives elsewhere (e.g. a row wrapping a
  /// switch that already publishes the toggle).
  final bool excludeFromSemantics;

  /// Forwarded to [InkWell.canRequestFocus]; set false when the target must
  /// not add a second Tab stop beside the control it enlarges.
  final bool canRequestFocus;

  /// Draws an interactive-ink outline (shaped by [borderRadius]) while the
  /// target itself holds *primary* keyboard focus — and only then. Opt in on
  /// targets whose builder deliberately shows no hover state, so Tab still
  /// lands somewhere visible. A focusable control nested inside the target
  /// lights its own cue instead of keeping the doorway's ring lit.
  final bool focusRing;

  @override
  State<DsQuietInk> createState() => _DsQuietInkState();
}

class _DsQuietInkState extends State<DsQuietInk> {
  // Own node so focus can be read as PRIMARY focus. InkWell's onFocusChange
  // reports chain focus — with a focusable control nested inside the target
  // (the banner's Snooze button, a card's chips) the doorway would stay
  // "focused", ring lit, while the child owns the actual keystroke.
  final FocusNode _node = FocusNode(debugLabel: 'DsQuietInk');
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _highlighted => _hovered || _focused || _pressed;

  @override
  void initState() {
    super.initState();
    _node.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final focused = _node.hasPrimaryFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  void dispose() {
    _node
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.onLongPress != null;
    if (!interactive) {
      // Inert targets render at rest — no Material, no stale highlight.
      return widget.builder(context, false);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: widget.borderRadius,
        customBorder: widget.customBorder,
        excludeFromSemantics: widget.excludeFromSemantics,
        canRequestFocus: widget.canRequestFocus,
        focusNode: _node,
        // The full overlay silence, matching DesignSystemButton's InkWell.
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        onHover: (value) => setState(() => _hovered = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        child: widget.focusRing && _focused
            ? DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(
                    color: context.designTokens.colors.interactive.enabled,
                    width: BorderWidths.emphasis,
                  ),
                ),
                child: widget.builder(context, _highlighted),
              )
            : widget.builder(context, _highlighted),
      ),
    );
  }
}
