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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: detailContentInsets(
        context,
        availableWidth: constraints.maxWidth,
      ),
      child: child,
    ),
  );
}

/// The horizontal insets [DetailContentWidth] applies: the standard content
/// gutter plus, on a desktop-breakpoint screen, the centring that caps the
/// content at [kDetailContentMaxWidth] within [availableWidth] — the width
/// the caller actually has, which inside a list/detail split is the detail
/// pane and not the window. Exposed for slivers and bars that have to share
/// the column but cannot be children of that widget.
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
