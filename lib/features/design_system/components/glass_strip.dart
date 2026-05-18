import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Edge-to-edge "glass" strip used by sticky bottom bars (e.g. the task
/// details action bar). Renders three layers:
///
/// 1. a hairline divider on top (decorative/01 @ 12% alpha),
/// 2. a [BackdropFilter] that blurs whatever the page paints behind the
///    strip (host parents must keep that content visible — usually via
///    `Scaffold.extendBody: true`), and
/// 3. a top→bottom white gradient overlay.
///
/// Glass overlay colors and the blur sigma currently live on
/// [DesignSystemFilterPalette] — until the design-system token export
/// surfaces dedicated `glass.*` tokens, this widget is the single
/// consumer for new sticky bars and keeps the values out of caller
/// widgets.
class DesignSystemGlassStrip extends StatelessWidget {
  const DesignSystemGlassStrip({
    required this.child,
    super.key,
  });

  final Widget child;

  /// Backdrop blur strength. Sits at the top of the codebase's existing
  /// glass-surface range (10–20) since this surface is wider and farther
  /// from the content than card-sized blurs.
  static const double blurSigma = 20;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 1,
          color: tokens.colors.decorative.level01.withValues(alpha: 0.12),
        ),
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.glassFooterOverlayStart,
                    palette.glassFooterOverlayEnd,
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sticky bottom action bar built on [DesignSystemGlassStrip].
///
/// Wraps [child] (typically a single button) in symmetric token-driven
/// padding and stretches it to fill the available width. Use this whenever
/// a modal needs a single primary action to float above a scrolling list
/// behind blurred glass.
///
/// Callers that overlay this footer on top of a scrolling region must
/// reserve [reservedHeight] of bottom inset (or matching bottom padding
/// inside the scrollable) so the last row of content remains tappable
/// after scrolling under the glass.
class DesignSystemGlassActionFooter extends StatelessWidget {
  const DesignSystemGlassActionFooter({
    required this.child,
    super.key,
  });

  final Widget child;

  /// Reserved bottom inset that lets scrolling content pass behind the
  /// glass footer without hiding the final rows. Sized for a single
  /// primary button with `spacing.step4` (~16px) vertical padding on
  /// both sides plus the 1px divider on top.
  ///
  /// Must be kept in sync with the layout produced by [build] — if you
  /// add a second row inside the footer, update this constant and audit
  /// every caller that uses it as a bottom inset.
  static const double reservedHeight = 88;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.step5,
          vertical: spacing.step4,
        ),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }
}
