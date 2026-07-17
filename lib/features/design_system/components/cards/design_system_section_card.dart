import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Flat card surface for content sections rendered on a page canvas.
///
/// Solid `background.level02`, `radii.l` corners, a `decorative.level01`
/// hairline border, no shadow and no gradient — the same treatment the task
/// and logbook list rows use, so a detail page built from these reads as the
/// same material as the list beside it.
///
/// Unlike `dsCardSurface` this does not swap levels by brightness: it is always
/// `level02`. That is deliberate — it preserves the established detail-page
/// appearance in both themes.
///
/// Lives in the design-system layer rather than in a feature so detail pages
/// can share one section surface without depending on another feature's
/// palette.
class DesignSystemSectionCard extends StatelessWidget {
  const DesignSystemSectionCard({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    final effectivePadding = padding ?? EdgeInsets.all(tokens.spacing.step5);

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: radius,
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: effectivePadding, child: child)
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Padding(padding: effectivePadding, child: child),
              ),
      ),
    );

    if (margin == null) return decorated;
    return Padding(padding: margin!, child: decorated);
  }
}
