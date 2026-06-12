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

    return DesignSystemFiveSlotNavBar.barHeight(context) +
        DesignSystemBottomNavigationOverlayHeight.of(context);
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
    super.key,
  });

  /// Rendered height of the overlay row; 0 while no indicator is visible.
  final double height;

  /// Overlay height published by the nearest enclosing scope, or 0 when
  /// none exists (previews and tests that render pages without the shell).
  static double of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<
          DesignSystemBottomNavigationOverlayHeight
        >();
    return scope?.height ?? 0;
  }

  @override
  bool updateShouldNotify(
    DesignSystemBottomNavigationOverlayHeight oldWidget,
  ) => height != oldWidget.height;
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
