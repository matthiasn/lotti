import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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
