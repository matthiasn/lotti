import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
import 'package:material_ui/material_ui.dart';

/// The clearance contract of the mobile bottom navigation.
///
/// The mobile shell (`lib/beamer/beamer_app.dart`) floats the
/// [MobileNavigationLauncher] over each tab's page stack as an app-level
/// overlay — not a `Scaffold.bottomNavigationBar` — and the activity island
/// (running timer / recording) above it. Pages therefore reserve room for
/// that bottom stack themselves, through [occupiedHeight] directly or via
/// [DesignSystemBottomNavigationFabPadding].
abstract final class DesignSystemBottomNavigationBar {
  /// Vertical screen estate the docked bottom stack occupies: the launcher
  /// (including the bottom safe-area inset it absorbs into its padding) plus
  /// the estate the shell-owned activity island claims above it, published
  /// via [DesignSystemBottomNavigationOverlayHeight]. Content scrolling
  /// behind the launcher pads by this amount.
  static double occupiedHeight(BuildContext context) {
    // In desktop layout there is no bottom navigation; the sidebar replaces
    // it, so no bottom inset is needed.
    if (isDesktopLayout(context)) return 0;

    // A slid-away launcher occupies nothing; the activity island above it
    // stays, so its height still counts.
    final barHeight =
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(context)
        ? MobileNavigationLauncher.barHeight(context)
        : 0.0;
    return barHeight + DesignSystemBottomNavigationOverlayHeight.of(context);
  }
}

/// Publishes the estate the shell-owned activity island (running timer /
/// recording) claims above the launcher to the page stack. The app shell
/// wraps the pages with this scope and updates [height] as the island
/// appears and disappears, so
/// [DesignSystemBottomNavigationBar.occupiedHeight] — and everything padding
/// by it — matches the full rendered bottom stack, not just the launcher.
class DesignSystemBottomNavigationOverlayHeight extends InheritedWidget {
  const DesignSystemBottomNavigationOverlayHeight({
    required this.height,
    required super.child,
    this.barDocked = true,
    super.key,
  });

  /// Estate the island claims above the launcher; 0 while it is not visible.
  final double height;

  /// Whether the launcher itself is docked at the bottom edge.
  ///
  /// False on routes that slide it away (goal agent pages, project and
  /// settings details): the launcher occupies no screen estate there, so a
  /// page padding by [DesignSystemBottomNavigationBar.occupiedHeight] must
  /// not leave a launcher-sized gutter its own pinned surface then cannot
  /// fill.
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

  /// Whether the launcher is docked; true when no scope exists, so pages
  /// rendered outside the shell keep reserving room for it as they always
  /// have.
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

/// Lifts a screen-level floating action above the mobile bottom stack by
/// padding it with [DesignSystemBottomNavigationBar.occupiedHeight].
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
