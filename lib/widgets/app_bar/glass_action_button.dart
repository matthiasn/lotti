import 'package:lotti/widgets/app_bar/glass_icon_container.dart';
import 'package:material_ui/material_ui.dart';

/// A glass-styled action button for use over images.
///
/// Combines [GlassIconContainer] with Material and InkWell for tap feedback.
/// Accepts any child widget (typically an Icon) and an onTap callback.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    required this.child,
    required this.onTap,
    this.size = defaultSize,
    this.semanticLabel,
    this.tooltip,
    this.fill,
    super.key,
  });

  /// The widget to display inside the glass container.
  final Widget child;

  /// Callback when button is tapped.
  final VoidCallback onTap;

  /// The default [size]: the touch target every glass action in an app bar
  /// shares, so a row of them lines up.
  static const double defaultSize = 40;

  /// Size of the glass container. Defaults to [defaultSize].
  final double size;

  /// Accessible label for icon-only glass actions.
  final String? semanticLabel;

  /// Optional hover tooltip. When omitted, [semanticLabel] is used.
  final String? tooltip;

  /// Forwarded to [GlassIconContainer.fill].
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? tooltip;
    final button = Semantics(
      container: true,
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.hardEdge,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          child: GlassIconContainer(
            size: size,
            fill: fill,
            child: child,
          ),
        ),
      ),
    );

    final tooltipMessage = tooltip ?? semanticLabel;
    if (tooltipMessage == null) return button;

    return Tooltip(
      message: tooltipMessage,
      excludeFromSemantics: true,
      child: button,
    );
  }
}
