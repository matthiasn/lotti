import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';

/// Mobile bottom-navigation container: hosts the five-slot bar
/// ([DesignSystemFiveSlotNavBar]) docked flush against the screen's bottom
/// edge. The time/audio recording indicators that ride above the bar are
/// owned by the mobile shell (`lib/beamer/beamer_app.dart`), not by this
/// container, so they stay visible when the shell slides the bar away.
class DesignSystemBottomNavigationBar extends StatelessWidget {
  const DesignSystemBottomNavigationBar({
    required this.items,
    super.key,
  });

  /// The bar's slots (at most five — overflow destinations live in the
  /// More sheet, represented here by their More slot item).
  final List<DesignSystemFiveSlotNavBarItem> items;

  /// Vertical screen estate the docked bottom stack occupies: the bar
  /// (including the bottom safe-area inset it absorbs into its surface)
  /// plus the rendered height of the shell-owned indicator row riding
  /// above it, published via
  /// [DesignSystemBottomNavigationOverlayHeight]. Content scrolling
  /// behind the bar pads by this amount (see
  /// [DesignSystemBottomNavigationFabPadding]).
  static double occupiedHeight(BuildContext context) {
    // In desktop layout the bottom navigation bar is not shown;
    // the sidebar replaces it, so no bottom inset is needed.
    if (isDesktopLayout(context)) return 0;

    // A slid-away bar occupies nothing; the indicator row above it stays,
    // so its height still counts.
    final barHeight =
        DesignSystemBottomNavigationOverlayHeight.barDockedOf(context)
        ? DesignSystemFiveSlotNavBar.barHeight(context)
        : 0.0;
    return barHeight + DesignSystemBottomNavigationOverlayHeight.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return DesignSystemFiveSlotNavBar(items: items);
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
