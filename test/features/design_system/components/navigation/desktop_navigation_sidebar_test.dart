import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(width: 400, height: 900, child: child),
        ),
      ),
    );
  }

  List<DesktopSidebarDestination> buildDestinations() {
    return [
      DesktopSidebarDestination(
        label: 'Journal',
        iconBuilder: ({required bool active}) =>
            Icon(active ? Icons.book : Icons.book_outlined),
      ),
      DesktopSidebarDestination(
        label: 'Tasks',
        iconBuilder: ({required bool active}) =>
            Icon(active ? Icons.task_alt : Icons.task_alt_outlined),
      ),
      DesktopSidebarDestination(
        label: 'Habits',
        iconBuilder: ({required bool active}) =>
            Icon(active ? Icons.repeat : Icons.repeat_outlined),
      ),
    ];
  }

  DesktopSidebarDestination buildSettingsDestination() {
    return DesktopSidebarDestination(
      label: 'Settings',
      iconBuilder: ({required bool active}) =>
          Icon(active ? Icons.settings : Icons.settings_outlined),
    );
  }

  group('DesktopNavigationSidebar', () {
    testWidgets('renders navigation item labels', (tester) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
    });

    testWidgets('renders Settings at the bottom when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            settingsDestination: buildSettingsDestination(),
            onSettingsSelected: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);

      // Settings label should appear below the last destination label
      final settingsOffset = tester.getCenter(find.text('Settings'));
      final habitsOffset = tester.getCenter(find.text('Habits'));
      expect(
        settingsOffset.dy,
        greaterThan(habitsOffset.dy),
        reason: 'Settings should be positioned below the last destination',
      );
    });

    testWidgets(
      'tapping a destination calls onDestinationSelected with correct index',
      (tester) async {
        final selected = <int>[];

        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 0,
              onDestinationSelected: selected.add,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Tasks'));
        await tester.pump();
        expect(selected, [1]);

        await tester.tap(find.text('Habits'));
        await tester.pump();
        expect(selected, [1, 2]);

        await tester.tap(find.text('Journal'));
        await tester.pump();
        expect(selected, [1, 2, 0]);
      },
    );

    testWidgets('tapping Settings calls onSettingsSelected', (tester) async {
      var settingsTapped = false;

      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            settingsDestination: buildSettingsDestination(),
            onSettingsSelected: () => settingsTapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Settings'));
      await tester.pump();

      expect(settingsTapped, isTrue);
    });

    testWidgets('active destination has active surface color', (tester) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 1,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      const tokens = dsTokensDark;

      // Find the Ink widgets that represent nav items.
      // The active one (index 1 = Tasks) should use the active surface color.
      final inkWidgets = tester.widgetList<Ink>(find.byType(Ink)).toList();

      final activeInks = inkWidgets.where((ink) {
        final decoration = ink.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == tokens.colors.surface.active;
        }
        return false;
      });

      expect(
        activeInks.length,
        1,
        reason: 'Exactly one nav item should have the active surface color',
      );

      // Verify the inactive items use transparent background
      final inactiveInks = inkWidgets.where((ink) {
        final decoration = ink.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == Colors.transparent;
        }
        return false;
      });

      expect(
        inactiveInks.length,
        greaterThanOrEqualTo(2),
        reason: 'Non-active destinations should have transparent background',
      );
    });

    testWidgets('renders the brand logo', (tester) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DesignSystemBrandLogo), findsOneWidget);
    });

    testWidgets('sidebar has default width of 320', (tester) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      // The sidebar renders a Container with the configured width.
      // Find the Container that is a direct child of DesktopNavigationSidebar.
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DesktopNavigationSidebar),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(
        container.constraints?.maxWidth,
        320,
        reason: 'Default sidebar width should be 320',
      );
    });

    testWidgets('tapping New button calls onNewPressed', (tester) async {
      var newPressed = false;

      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            onNewPressed: () => newPressed = true,
          ),
        ),
      );
      await tester.pump();

      // The New button displays the localized "New" label text.
      // Find it via the DesignSystemButton containing that text.
      await tester.tap(find.text('New'));
      await tester.pump();

      expect(newPressed, isTrue);
    });
  });
}
