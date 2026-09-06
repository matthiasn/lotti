import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Centers [child] and caps its width at [kDetailContentMaxWidth] on wide
/// (desktop-breakpoint) screens so list and detail content stays at one shared
/// reading measure, while letting it span full width on narrow ones. Also
/// applies the standard horizontal content gutter.
///
/// Lives in the design-system layer so every list/detail surface — tasks,
/// projects, and the logbook — shares one width constraint without depending on
/// another feature for it.
class DetailContentWidth extends StatelessWidget {
  const DetailContentWidth({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth >= kDesktopBreakpoint
        ? kDetailContentMaxWidth
        : double.infinity;
    // Center + ConstrainedBox, not a LayoutBuilder: a `SliverFillRemaining`
    // asks its child for an intrinsic height, which a LayoutBuilder cannot
    // answer — and loose constraints let a shrink-wrapping child sit
    // centred in the column rather than being stretched across it.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.designTokens.spacing.step5,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The same geometry as [DetailContentWidth], as insets: the standard
/// content gutter plus, on a desktop-breakpoint screen, the centring that
/// caps the content at [kDetailContentMaxWidth] within [availableWidth] —
/// the width the caller actually has, which inside a list/detail split is
/// the detail pane and not the window. For slivers and bars that have to
/// share the column but cannot be children of that widget; they measure
/// the width themselves.
EdgeInsets detailContentInsets(
  BuildContext context, {
  required double availableWidth,
}) {
  final tokens = context.designTokens;
  final desktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
  final overflow = availableWidth - kDetailContentMaxWidth;
  final centring = desktop && overflow.isFinite && overflow > 0
      ? overflow / 2
      : 0.0;
  return EdgeInsets.symmetric(horizontal: tokens.spacing.step5 + centring);
}
