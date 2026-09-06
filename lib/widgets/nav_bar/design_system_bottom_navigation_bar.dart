import 'dart:math' as math;

import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A single mobile navigation launcher. The transparent surrounding area leaves
/// the page visible; the shell owns the recording indicators above the button.
class DesignSystemBottomNavigationBar extends StatelessWidget {
  const DesignSystemBottomNavigationBar({required this.onNavigate, super.key});

  final VoidCallback onNavigate;

  /// Height of the large, padded design-system button plus safe-area spacing.
  /// Shared with the shell so recordings and page actions clear the launcher.
  static double barHeight(BuildContext context) {
    final tokens = context.designTokens;
    final labelPainter = TextPainter(
      text: TextSpan(
        text: context.messages.navTabTitleNavigate,
        style: tokens.typography.styles.subtitle.subtitle1,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final labelHeight = math.max(
      labelPainter.height,
      tokens.typography.lineHeight.subtitle1,
    );
    labelPainter.dispose();
    return math.max(
          TapTargets.minimum,
          labelHeight + tokens.spacing.step4 * 2,
        ) +
        tokens.spacing.step2 +
        _bottomPadding(context);
  }

  static double _bottomPadding(BuildContext context) => math.max(
    MediaQuery.paddingOf(context).bottom,
    context.designTokens.spacing.step6,
  );

  /// Page clearance for the visible launcher and shell-owned recording row.
  static double occupiedHeight(BuildContext context) {
    if (isDesktopLayout(context)) return 0;
    final launcherHeight =
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(context)
        ? barHeight(context)
        : 0.0;
    return launcherHeight +
        DesignSystemBottomNavigationOverlayHeight.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.paddingOf(context).left + tokens.spacing.step3,
        tokens.spacing.step2,
        MediaQuery.paddingOf(context).right + tokens.spacing.step3,
        _bottomPadding(context),
      ),
      child: Center(
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.xl),
            boxShadow: DsShadows.floatingSurface,
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.xl),
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            child: DesignSystemButton(
              label: context.messages.navTabTitleNavigate,
              onPressed: onNavigate,
              leadingIcon: LottiIcons.menu,
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
      ),
    );
  }
}

/// Publishes the rendered height of the shell-owned indicator row (the
/// time/audio recording indicators) riding above the nav bar to the page
/// stack. The app shell wraps the pages with this scope and updates
/// [height] as indicators appear and disappear, so
/// [DesignSystemBottomNavigationBar.occupiedHeight] — and everything padding
/// by it — matches the full rendered bottom stack, not just the bar.
class DesignSystemBottomNavigationOverlayHeight extends InheritedWidget {
  const DesignSystemBottomNavigationOverlayHeight({
    required this.height,
    required super.child,
    this.barDocked = true,
    super.key,
  });

  /// Rendered height of the overlay row; 0 while no indicator is visible.
  final double height;

  /// Whether the nav bar itself is docked at the bottom edge.
  ///
  /// False on routes that slide it away (goal agent pages, project and
  /// settings details): the bar occupies no screen estate there, so a page
  /// padding by [DesignSystemBottomNavigationBar.occupiedHeight] must not
  /// leave a bar-sized gutter its own pinned surface then cannot fill.
  final bool barDocked;

  /// Overlay height published by the nearest enclosing scope, or 0 when
  /// none exists (previews and tests that render pages without the shell).
  static double of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
          DesignSystemBottomNavigationOverlayHeight
        >();
    return scope?.height ?? 0;
  }

  /// Whether the bar is docked; true when no scope exists, so pages rendered
  /// outside the shell keep reserving room for it as they always have.
  static bool barDockedOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
          DesignSystemBottomNavigationOverlayHeight
        >();
    return scope?.barDocked ?? true;
  }

  @override
  bool updateShouldNotify(
    DesignSystemBottomNavigationOverlayHeight oldWidget,
  ) => height != oldWidget.height || barDocked != oldWidget.barDocked;
}

class DesignSystemBottomNavigationFabPadding extends StatelessWidget {
  const DesignSystemBottomNavigationFabPadding({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: DesignSystemBottomNavigationBar.occupiedHeight(context),
      ),
      child: child,
    );
  }
}
