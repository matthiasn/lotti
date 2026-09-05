import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The design-system's floating action button — a circular icon button sized
/// from typography/spacing tokens, or an extended pill when given a [label].
///
/// Shows [icon] (defaults to a rounded plus) and tracks hover/pressed state,
/// resolving its background from the interactive token set. A `null`
/// [onPressed] is the disabled state. [semanticLabel] is required because the
/// circular form is icon-only.
class DesignSystemFloatingActionButton extends StatefulWidget {
  const DesignSystemFloatingActionButton({
    required this.semanticLabel,
    this.onPressed,
    this.icon = LottiIcons.add,
    this.label,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final IconData icon;

  /// Words the button beside its glyph, turning it into an extended pill.
  ///
  /// A bare `+` names its action only in a tooltip, so on a screen that can
  /// create more than one kind of thing the user has to press it to find out
  /// what it makes. Null keeps the circular icon-only form for the surfaces
  /// where the list itself already says what gets added.
  final String? label;

  @override
  State<DesignSystemFloatingActionButton> createState() =>
      _DesignSystemFloatingActionButtonState();
}

class _DesignSystemFloatingActionButtonState
    extends State<DesignSystemFloatingActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  void didUpdateWidget(covariant DesignSystemFloatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = widget.onPressed != null;
    final label = widget.label;
    // The circular form keeps the 56 the FAB convention expects; the extended
    // pill drops to the standard tap target so it reads as a peer of the
    // labelled controls it sits beside (the task bar's Track time pill) rather
    // than towering over them.
    final dimension = label == null
        ? tokens.typography.lineHeight.subtitle1 + (tokens.spacing.step5 * 2)
        : TapTargets.minimum;
    final backgroundColor = switch ((_pressed, _hovered)) {
      (_, _) when !enabled => tokens.colors.interactive.enabled,
      (true, _) => tokens.colors.interactive.pressed,
      (_, true) => tokens.colors.interactive.hover,
      _ => tokens.colors.interactive.enabled,
    };

    final content = label == null
        ? Center(
            child: Icon(
              widget.icon,
              size: tokens.typography.lineHeight.subtitle1,
              color: tokens.colors.text.onInteractiveAlert,
            ),
          )
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: tokens.typography.lineHeight.subtitle1,
                  color: tokens.colors.text.onInteractiveAlert,
                ),
                SizedBox(width: tokens.spacing.step2),
                // The outer Semantics already speaks for the whole button;
                // without this the label would also be announced as its own
                // node, reading the action name twice.
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.onInteractiveAlert,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled
            ? (_) => setState(() {
                _hovered = false;
                _pressed = false;
              })
            : null,
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            // An extended pill sizes to its label; only the circular form
            // pins both axes to the same dimension.
            width: label == null ? dimension : null,
            height: dimension,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.xl),
              color: backgroundColor,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(tokens.radii.xl),
              onTap: widget.onPressed,
              onHighlightChanged: enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: content,
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      return button;
    }

    return Opacity(
      opacity: tokens.colors.text.lowEmphasis.a,
      child: button,
    );
  }
}
