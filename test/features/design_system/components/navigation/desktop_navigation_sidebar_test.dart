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

    testWidgets(
      'renders the active-variant icon for the active destination',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 1, // Tasks
              onDestinationSelected: (_) {},
            ),
          ),
        );
        await tester.pump();

        // Tasks is active -> filled icon; Journal/Habits stay outlined.
        expect(find.byIcon(Icons.task_alt), findsOneWidget);
        expect(find.byIcon(Icons.task_alt_outlined), findsNothing);
        expect(find.byIcon(Icons.book_outlined), findsOneWidget);
        expect(find.byIcon(Icons.repeat_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Settings destination renders the active-variant icon when active',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 0,
              onDestinationSelected: (_) {},
              settingsDestination: buildSettingsDestination(),
              onSettingsSelected: () {},
              isSettingsActive: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
      },
    );

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

    testWidgets(
      'sidebar paints background.level02 so it reads as a lighter surface '
      'than the task-list pane (level01) — matches the Figma reference',
      (tester) async {
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

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(DesktopNavigationSidebar),
                matching: find.byType(Container),
              )
              .first,
        );

        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, dsTokensDark.colors.background.level02);
      },
    );

    testWidgets(
      'renders trailingBuilder widget on the right side of the row, '
      'to the right of the label',
      (tester) async {
        const trailingKey = Key('trailing-badge');

        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: [
                DesktopSidebarDestination(
                  label: 'Tasks',
                  iconBuilder: ({required bool active}) =>
                      const Icon(Icons.list_outlined),
                  trailingBuilder: ({required bool active}) => const SizedBox(
                    key: trailingKey,
                    width: 32,
                    height: 24,
                  ),
                ),
              ],
              activeIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        );
        await tester.pump();

        final trailingFinder = find.byKey(trailingKey);
        expect(trailingFinder, findsOneWidget);

        // Trailing sits to the right of the label.
        final trailingLeft = tester.getTopLeft(trailingFinder).dx;
        final labelRight = tester.getTopRight(find.text('Tasks')).dx;
        expect(
          trailingLeft,
          greaterThanOrEqualTo(labelRight),
          reason: 'Trailing badge should be to the right of the label',
        );
      },
    );

    testWidgets('label text is rendered without forced single-line clipping', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: [
              DesktopSidebarDestination(
                label: 'Insights',
                iconBuilder: ({required bool active}) =>
                    const Icon(Icons.insert_chart_outlined),
              ),
            ],
            activeIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      // The label uses the Text defaults so the row can grow with the
      // text scaler instead of getting clipped to a fixed 48 px item.
      final text = tester.widget<Text>(find.text('Insights'));
      expect(text.overflow, isNull);
      expect(text.softWrap, isNull);
      expect(text.maxLines, isNull);
    });

    testWidgets(
      'item grows vertically to fit the label when the text scaler is large',
      (tester) async {
        Widget buildSidebar(double scale) {
          return makeTestableWidget2(
            Theme(
              data: DesignSystemTheme.dark(),
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 900,
                    child: DesktopNavigationSidebar(
                      destinations: [
                        DesktopSidebarDestination(
                          label: 'Projects',
                          iconBuilder: ({required bool active}) =>
                              const Icon(Icons.folder_outlined),
                        ),
                      ],
                      activeIndex: 0,
                      onDestinationSelected: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildSidebar(1));
        await tester.pump();
        final baseHeight = tester.getSize(find.text('Projects')).height;
        final baseRow = tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Projects'),
                    matching: find.byType(Row),
                  )
                  .first,
            )
            .height;

        await tester.pumpWidget(buildSidebar(2));
        await tester.pump();
        final largeHeight = tester.getSize(find.text('Projects')).height;
        final largeRow = tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Projects'),
                    matching: find.byType(Row),
                  )
                  .first,
            )
            .height;

        expect(
          largeHeight,
          greaterThan(baseHeight),
          reason: 'Scaled-up label should take more vertical space',
        );
        expect(
          largeRow,
          greaterThanOrEqualTo(largeHeight),
          reason: 'Row must grow to fit the scaled label, not clip it',
        );
        expect(
          largeRow,
          greaterThan(baseRow),
          reason: 'The row should grow with the label',
        );
      },
    );

    testWidgets('sidebar does not render a "+ New" quick action', (
      tester,
    ) async {
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

      expect(find.text('New'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    testWidgets('toggle icon is tappable and fires onToggleCollapsed', (
      tester,
    ) async {
      var toggleCount = 0;
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            onToggleCollapsed: () => toggleCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(desktopSidebarToggleKey));
      await tester.pump();

      expect(toggleCount, 1);
    });
  });

  group('DesktopNavigationSidebar collapsed', () {
    testWidgets('renders at collapsedWidth and hides destination labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            collapsed: true,
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DesktopNavigationSidebar),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.constraints?.maxWidth, 72);

      // Labels are hidden; icons still render. Journal is active (index 0)
      // so it renders the filled variant; the others render outlined.
      expect(find.text('Journal'), findsNothing);
      expect(find.text('Tasks'), findsNothing);
      expect(find.text('Habits'), findsNothing);
      expect(find.byIcon(Icons.book), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.repeat_outlined), findsOneWidget);
    });

    testWidgets(
      'collapsed mode renders the active-variant icon for the active '
      'destination',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 1, // Tasks
              onDestinationSelected: (_) {},
              collapsed: true,
            ),
          ),
        );
        await tester.pump();

        // Tasks is active -> filled icon; Journal/Habits stay outlined.
        expect(find.byIcon(Icons.task_alt), findsOneWidget);
        expect(find.byIcon(Icons.book_outlined), findsOneWidget);
        expect(find.byIcon(Icons.repeat_outlined), findsOneWidget);
        expect(find.byIcon(Icons.task_alt_outlined), findsNothing);
      },
    );

    testWidgets(
      'hides the brand logo when collapsed so only the toggle icon remains',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 0,
              onDestinationSelected: (_) {},
              collapsed: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DesignSystemBrandLogo), findsNothing);
        expect(find.byKey(desktopSidebarToggleKey), findsOneWidget);
      },
    );

    testWidgets('collapsed destinations remain tappable by icon', (
      tester,
    ) async {
      final selected = <int>[];

      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: selected.add,
            collapsed: true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.task_alt_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.repeat_outlined));
      await tester.pump();

      expect(selected, [1, 2]);
    });

    testWidgets(
      'collapsed Settings entry renders as an icon-only tile with tooltip',
      (tester) async {
        var settingsTapped = false;
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 0,
              onDestinationSelected: (_) {},
              settingsDestination: buildSettingsDestination(),
              onSettingsSelected: () => settingsTapped = true,
              collapsed: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Settings'), findsNothing);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

        // Each collapsed destination wraps its content in a Tooltip keyed to
        // the label so the user can discover the name on hover.
        final tooltipMessages = tester
            .widgetList<Tooltip>(
              find.descendant(
                of: find.byType(DesktopNavigationSidebar),
                matching: find.byType(Tooltip),
              ),
            )
            .map((t) => t.message ?? t.richMessage?.toPlainText() ?? '')
            .toSet();
        expect(tooltipMessages, contains('Settings'));
        expect(tooltipMessages, contains('Journal'));

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pump();
        expect(settingsTapped, isTrue);
      },
    );

    testWidgets('toggle icon fires onToggleCollapsed when collapsed', (
      tester,
    ) async {
      var toggleCount = 0;
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            collapsed: true,
            onToggleCollapsed: () => toggleCount++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(desktopSidebarToggleKey));
      await tester.pump();

      expect(toggleCount, 1);
    });

    testWidgets(
      'active destination still has surface.active fill in collapsed mode',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 1,
              onDestinationSelected: (_) {},
              collapsed: true,
            ),
          ),
        );
        await tester.pump();

        const tokens = dsTokensDark;
        final inkWidgets = tester.widgetList<Ink>(find.byType(Ink)).toList();
        final activeInks = inkWidgets.where((ink) {
          final decoration = ink.decoration;
          return decoration is BoxDecoration &&
              decoration.color == tokens.colors.surface.active;
        });
        expect(activeInks.length, 1);
      },
    );
  });
}
