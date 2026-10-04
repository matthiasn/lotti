import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A small coloured tag displaying a category icon and label.
class CategoryTag extends StatelessWidget {
  const CategoryTag({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // User-defined category colors span the full hue/luminance space —
    // a fixed palette text colour collapses to illegible on near-black
    // or near-white backgrounds. Flip to black/white based on the
    // estimated background brightness, mirroring the same pattern used
    // by the category icon tiles in `categories_list_page.dart`.
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final child = MetaTag(
      label: label,
      icon: icon,
      backgroundColor: color,
      foregroundColor: foreground,
    );

    if (onTap == null) {
      return child;
    }

    return InteractiveTagSurface(
      borderRadius: tokens.radii.xs,
      onTap: onTap!,
      child: child,
    );
  }
}

/// A compact filled pill with an icon and a single-line label, the shape
/// every meta tag shares. Pass either [icon] or a custom [iconWidget].
class MetaTag extends StatelessWidget {
  const MetaTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.iconWidget,
    this.borderColor,
    super.key,
  }) : assert(
         icon != null || iconWidget != null,
         'Either icon or iconWidget must be provided.',
       );

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      constraints: BoxConstraints(
        minHeight: tokens.spacing.step5 + tokens.spacing.step1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ??
              Icon(
                icon,
                size: tokens.typography.size.caption,
                color: foregroundColor,
              ),
          SizedBox(width: tokens.spacing.step1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.others.caption.copyWith(
                color: foregroundColor,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Makes a tag tappable: an ink-splash surface clipped to [borderRadius],
/// announced as a button, with at least the minimum tap-target height.
class InteractiveTagSurface extends StatelessWidget {
  const InteractiveTagSurface({
    required this.borderRadius,
    required this.onTap,
    required this.child,
    super.key,
  });

  final double borderRadius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TapTargets.minimum),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
