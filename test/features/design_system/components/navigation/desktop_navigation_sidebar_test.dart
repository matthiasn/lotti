import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

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
            Icon(active ? LottiIconsFilled.bookmark : LottiIcons.book),
      ),
      DesktopSidebarDestination(
        label: 'Tasks',
        iconBuilder: ({required bool active}) => Icon(
          active ? LottiIconsFilled.circle : LottiIcons.confirmCircled,
        ),
      ),
      DesktopSidebarDestination(
        label: 'Habits',
        iconBuilder: ({required bool active}) =>
            Icon(active ? LottiIconsFilled.heart : LottiIcons.repeat),
      ),
    ];
  }

  DesktopSidebarDestination buildSettingsDestination() {
    return DesktopSidebarDestination(
      label: 'Settings',
      iconBuilder: ({required bool active}) =>
          Icon(active ? LottiIconsFilled.star : LottiIcons.settings),
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

    testWidgets('announces a destination without a callback as unavailable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            settingsDestination: buildSettingsDestination(),
          ),
        ),
      );

      final settings = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Settings',
      );
      expect(
        tester.getSemantics(settings),
        matchesSemantics(
          label: 'Settings',
          isButton: true,
          hasEnabledState: true,
          hasSelectedState: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets(
      'utility link stays above Settings and remains available when collapsed',
      (tester) async {
        var utilityTaps = 0;
        final semanticsHandle = tester.ensureSemantics();
        final utility = DesktopSidebarDestination(
          label: 'Manual',
          iconBuilder: ({required bool active}) => const Icon(LottiIcons.help),
          trailingBuilder: ({required bool active}) =>
              const Icon(LottiIcons.openExternal),
          isLink: true,
          semanticsHint: 'Opens in your browser',
        );

        Future<void> pumpSidebar({required bool collapsed}) async {
          await tester.pumpWidget(
            wrap(
              DesktopNavigationSidebar(
                destinations: buildDestinations(),
                activeIndex: 0,
                onDestinationSelected: (_) {},
                settingsDestination: buildSettingsDestination(),
                onSettingsSelected: () {},
                utilityDestination: utility,
                onUtilitySelected: () => utilityTaps++,
                collapsed: collapsed,
              ),
            ),
          );
          await tester.pump();
        }

        await pumpSidebar(collapsed: false);

        expect(find.byIcon(LottiIcons.openExternal), findsOneWidget);
        expect(
          tester.getCenter(find.text('Manual')).dy,
          lessThan(tester.getCenter(find.text('Settings')).dy),
        );
        final semantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Manual')),
        );
        expect(semantics.hint, 'Opens in your browser');
        expect(semantics.flagsCollection.isLink, isTrue);
        expect(semantics.flagsCollection.isButton, isFalse);

        await tester.tap(find.text('Manual'));
        await tester.pump();
        expect(utilityTaps, 1);

        await pumpSidebar(collapsed: true);

        expect(find.text('Manual'), findsNothing);
        expect(find.byIcon(LottiIcons.help), findsOneWidget);
        await tester.tap(find.byIcon(LottiIcons.help));
        await tester.pump();
        expect(utilityTaps, 2);
        semanticsHandle.dispose();
      },
    );

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
        expect(find.byIcon(LottiIconsFilled.circle), findsOneWidget);
        expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
        expect(find.byIcon(LottiIcons.book), findsOneWidget);
        expect(find.byIcon(LottiIcons.repeat), findsOneWidget);
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

        expect(find.byIcon(LottiIconsFilled.star), findsOneWidget);
        expect(find.byIcon(LottiIcons.settings), findsNothing);
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

      // Placement: the logo sits at the top of the sidebar, above every
      // navigation destination tile.
      expect(
        tester.getTopLeft(find.byType(DesignSystemBrandLogo)).dx,
        greaterThan(0),
        reason: 'the brand logo must not be flush with the screen edge',
      );
      final logoBottom = tester
          .getBottomLeft(find.byType(DesignSystemBrandLogo))
          .dy;
      for (final label in ['Journal', 'Tasks', 'Habits']) {
        expect(
          tester.getTopLeft(find.text(label)).dy,
          greaterThan(logoBottom),
          reason: 'nav item $label must render below the brand logo',
        );
      }
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
                      const Icon(LottiIcons.list),
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

    testWidgets('label text is pinned to a single ellipsized line', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: [
              DesktopSidebarDestination(
                label: 'Insights',
                iconBuilder: ({required bool active}) =>
                    const Icon(LottiIcons.chart),
              ),
            ],
            activeIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      // The rail is user-resizable down to 200 px, so a wrapping label
      // degrades into a column of single letters rather than a shorter row.
      final text = tester.widget<Text>(find.text('Insights'));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    // The conditions the design review actually complained about: a rail
    // dragged to its 200 px minimum, a trailing count beside the label, and an
    // enlarged platform text scale. Property assertions above say the label is
    // configured to truncate; these say the row survives.
    group('under a squeezed row', () {
      Widget narrowSidebar({
        required double width,
        double textScale = 1,
        Widget? trailing,
        String label = 'Settings',
      }) {
        return makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SizedBox(
                  width: width,
                  height: 900,
                  child: DesktopNavigationSidebar(
                    destinations: [
                      DesktopSidebarDestination(
                        label: label,
                        iconBuilder: ({required bool active}) =>
                            const Icon(LottiIcons.settings),
                        trailingBuilder: trailing == null
                            ? null
                            : ({required bool active}) => trailing,
                      ),
                    ],
                    activeIndex: 0,
                    onDestinationSelected: (_) {},
                    width: width,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('the label stays one line tall at the 200 px minimum', (
        tester,
      ) async {
        await tester.pumpWidget(narrowSidebar(width: 320));
        await tester.pump();
        final roomyHeight = tester.getSize(find.text('Settings')).height;

        await tester.pumpWidget(
          narrowSidebar(
            width: 200,
            trailing: const SizedBox(width: 90, height: 20),
          ),
        );
        await tester.pump();
        final squeezedHeight = tester.getSize(find.text('Settings')).height;

        // Before this change the same label rendered as `S/e/tt/in/g/s` — six
        // lines and roughly six times this height.
        expect(
          squeezedHeight,
          roomyHeight,
          reason: 'A squeezed label must ellipsize, never wrap',
        );
      });

      testWidgets('the label yields its width, not the trailing count', (
        tester,
      ) async {
        const trailing = SizedBox(width: 90, height: 20, key: Key('count'));

        await tester.pumpWidget(
          narrowSidebar(width: 200, trailing: trailing),
        );
        await tester.pump();

        // A count clipped to `↓ 1…` would be wrong rather than merely short,
        // so the trailing group keeps every pixel it asked for and the label
        // absorbs the shortfall.
        expect(tester.getSize(find.byKey(const Key('count'))).width, 90);
        expect(
          tester.getSize(find.text('Settings')).width,
          lessThan(tester.getSize(find.byKey(const Key('count'))).width),
        );
      });

      testWidgets(
        'a trailing group wider than the row is clamped, not overflowed',
        (tester) async {
          // 200 px rail − 2×16 gutter − 2×16 row padding − 32 icon − 8 gap
          // leaves 96 px. A trailing slot that asks for more than the row has
          // is where the label has already given up everything it had, so the
          // only remaining choice is to clamp it or to overflow.
          await tester.pumpWidget(
            narrowSidebar(
              width: 200,
              trailing: const SizedBox(
                width: 200,
                height: 20,
                key: Key('count'),
              ),
            ),
          );
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason: 'An over-wide trailing group must not overflow the rail',
          );
          expect(tester.getSize(find.byKey(const Key('count'))).width, 96);
        },
      );

      testWidgets('a trailing group within budget keeps its natural width', (
        tester,
      ) async {
        await tester.pumpWidget(
          narrowSidebar(
            width: 200,
            trailing: const SizedBox(width: 96, height: 20, key: Key('count')),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(const Key('count'))).width, 96);
      });

      testWidgets('icon and label share a vertical centre at 1.0 scale', (
        tester,
      ) async {
        await tester.pumpWidget(narrowSidebar(width: 320));
        await tester.pump();

        final iconCentre = tester
            .getCenter(find.byIcon(LottiIcons.settings))
            .dy;
        final labelCentre = tester.getCenter(find.text('Settings')).dy;
        expect((iconCentre - labelCentre).abs(), lessThan(1));
      });

      testWidgets('icon and label stay centred when the text scale doubles', (
        tester,
      ) async {
        await tester.pumpWidget(narrowSidebar(width: 320, textScale: 2));
        await tester.pump();

        final iconCentre = tester
            .getCenter(find.byIcon(LottiIcons.settings))
            .dy;
        final labelCentre = tester.getCenter(find.text('Settings')).dy;

        // The glyph stays 20 px while the label grows, so start-alignment
        // strands the icon near the top of a much taller label.
        expect((iconCentre - labelCentre).abs(), lessThan(1));
      });

      testWidgets('the icon does not grow with the text scale', (tester) async {
        await tester.pumpWidget(narrowSidebar(width: 320));
        await tester.pump();
        final baseIcon = tester.getSize(find.byIcon(LottiIcons.settings));

        await tester.pumpWidget(narrowSidebar(width: 320, textScale: 2));
        await tester.pump();

        // Deliberate: a glyph that scaled with the text would take the width
        // the label needs more.
        expect(tester.getSize(find.byIcon(LottiIcons.settings)), baseIcon);
      });
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
                              const Icon(LottiIcons.folder),
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
      expect(find.byIcon(LottiIcons.add), findsNothing);
    });

    testWidgets(
      'expandedChildBuilder renders below the active destination row',
      (tester) async {
        const childKey = Key('expanded-subtree');
        final destinations = [
          DesktopSidebarDestination(
            label: 'Journal',
            iconBuilder: ({required bool active}) =>
                const Icon(LottiIcons.book),
          ),
          DesktopSidebarDestination(
            label: 'Tasks',
            iconBuilder: ({required bool active}) =>
                const Icon(LottiIcons.confirmCircled),
            expandedChildBuilder: () => const Padding(
              key: childKey,
              padding: EdgeInsets.all(4),
              child: Text('saved-filters'),
            ),
          ),
        ];

        // Inactive destination — subtree must not render.
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: destinations,
              activeIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(childKey), findsNothing);

        // Active destination — subtree renders.
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: destinations,
              activeIndex: 1,
              onDestinationSelected: (_) {},
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(childKey), findsOneWidget);

        // Collapsed mode — subtree stays hidden even when active.
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: destinations,
              activeIndex: 1,
              onDestinationSelected: (_) {},
              collapsed: true,
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(childKey), findsNothing);
      },
    );

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

    testWidgets(
      'aboveSettings slot renders BETWEEN the last nav item and the '
      'Settings row in expanded mode and stays hidden in collapsed mode',
      (tester) async {
        const slotKey = Key('above-settings-slot');
        const slot = SizedBox(
          key: slotKey,
          height: 24,
          child: Text('sync activity'),
        );
        final settings = DesktopSidebarDestination(
          label: 'Settings',
          iconBuilder: ({required bool active}) =>
              const Icon(LottiIcons.settings),
        );

        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 0,
              onDestinationSelected: (_) {},
              settingsDestination: settings,
              aboveSettings: slot,
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(slotKey), findsOneWidget);

        // Verify vertical placement: the slot must sit between the
        // last nav row ("Habits") and the Settings row. A regression
        // that hoisted the slot into the nav list or pushed it below
        // Settings would still satisfy `findsOneWidget`, so these
        // placement asserts are the load-bearing check.
        final habitsY = tester.getCenter(find.text('Habits')).dy;
        final slotY = tester.getCenter(find.byKey(slotKey)).dy;
        final settingsY = tester.getCenter(find.text('Settings')).dy;
        expect(slotY, greaterThan(habitsY));
        expect(slotY, lessThan(settingsY));

        // Collapsed mode — slot is suppressed because the strip is too
        // narrow to display readable monospace counters.
        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 0,
              onDestinationSelected: (_) {},
              settingsDestination: settings,
              aboveSettings: slot,
              collapsed: true,
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(slotKey), findsNothing);
      },
    );

    testWidgets(
      'footerBand spans the rail edge to edge while every other slot keeps '
      'the gutters',
      (tester) async {
        const bandKey = Key('footer-band');
        final settings = DesktopSidebarDestination(
          label: 'Settings',
          iconBuilder: ({required bool active}) =>
              const Icon(LottiIcons.settings),
        );

        await tester.pumpWidget(
          wrap(
            DesktopNavigationSidebar(
              destinations: buildDestinations(),
              activeIndex: 0,
              onDestinationSelected: (_) {},
              settingsDestination: settings,
              width: 256,
              footerBand: const SizedBox(key: bandKey, height: 20),
            ),
          ),
        );
        await tester.pump();

        final sidebar = tester.getRect(find.byType(DesktopNavigationSidebar));
        final band = tester.getRect(find.byKey(bandKey));
        final settingsRow = tester.getRect(find.text('Settings'));

        // The whole point of the slot: the footer's divider can define the
        // rail edge while the action group owns its own compact inset.
        expect(band.left, sidebar.left);
        expect(band.right, sidebar.right);
        expect(band.width, sidebar.width);

        expect(settingsRow.left, greaterThan(sidebar.left));

        // Order: Settings, then the footer band as the stable bottom edge.
        expect(band.top, greaterThanOrEqualTo(settingsRow.bottom));
      },
    );

    testWidgets('footerBand is suppressed in collapsed mode', (tester) async {
      const bandKey = Key('footer-band');

      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            footerBand: const SizedBox(key: bandKey, height: 20),
            collapsed: true,
          ),
        ),
      );
      await tester.pump();

      // The icon-only rail is 72 px — narrower than the four glyphs the band
      // carries.
      expect(find.byKey(bandKey), findsNothing);
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
      expect(find.byIcon(LottiIconsFilled.bookmark), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
      expect(find.byIcon(LottiIcons.repeat), findsOneWidget);
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
        expect(find.byIcon(LottiIconsFilled.circle), findsOneWidget);
        expect(find.byIcon(LottiIcons.book), findsOneWidget);
        expect(find.byIcon(LottiIcons.repeat), findsOneWidget);
        expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
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

      await tester.tap(find.byIcon(LottiIcons.confirmCircled));
      await tester.pump();
      await tester.tap(find.byIcon(LottiIcons.repeat));
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
        expect(find.byIcon(LottiIcons.settings), findsOneWidget);

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

        await tester.tap(find.byIcon(LottiIcons.settings));
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

  group('DesktopNavigationSidebar logo menu', () {
    testWidgets('without menu items the logo is inert', (tester) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      );

      expect(find.byKey(desktopSidebarLogoMenuTriggerKey), findsNothing);
      await tester.tap(find.byType(DesignSystemBrandLogo));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemContextMenu), findsNothing);
    });

    testWidgets('tapping the logo opens the supplied menu with its header, '
        'and a row tap fires and closes it', (tester) async {
      var picked = 0;
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            logoMenuHeader: 'Lock to a category',
            logoMenuSemanticsLabel: 'Lockdown menu',
            logoMenuItems: [
              DesignSystemContextMenuItem(
                label: 'Work',
                onTap: () => picked++,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Work'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Lockdown menu')),
        matchesSemantics(
          label: 'Lockdown menu',
          isButton: true,
          isImage: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      await tester.tap(find.byKey(desktopSidebarLogoMenuTriggerKey));
      await tester.pumpAndSettle();
      expect(find.text('Lock to a category'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);

      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(picked, 1);
      expect(find.byType(DesignSystemContextMenu), findsNothing);
    });

    testWidgets('the collapsed rail has no logo and therefore no trigger', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          DesktopNavigationSidebar(
            destinations: buildDestinations(),
            activeIndex: 0,
            onDestinationSelected: (_) {},
            collapsed: true,
            logoMenuItems: const [DesignSystemContextMenuItem(label: 'Work')],
          ),
        ),
      );

      expect(find.byKey(desktopSidebarLogoMenuTriggerKey), findsNothing);
      expect(find.byType(DesignSystemBrandLogo), findsNothing);
    });
  });
}
