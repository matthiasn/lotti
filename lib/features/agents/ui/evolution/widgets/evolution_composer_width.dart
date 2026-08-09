import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Holds the composer to the same reading measure as the transcript above it.
///
/// Deliberately *not* [DetailContentWidth]: that centres on both axes, and a
/// both-axes centre in a `bottomNavigationBar` slot expands to the full screen
/// height — the bar then swallows the page, leaving the conversation zero
/// height and the input floating in the middle of it. A [Row] constrains the
/// width and takes its height from the child, which is what a bottom bar
/// needs.
class EvolutionComposerWidth extends StatelessWidget {
  const EvolutionComposerWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint
        ? kDetailContentMaxWidth
        : double.infinity;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            // Stretch to the cap: `Flexible` alone leaves the constraints
            // loose, so a child with no intrinsic width collapses to nothing.
            // `Expanded` is not the fix — it would hand down a tight width
            // and the cap could not shrink it.
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.designTokens.spacing.step5,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
