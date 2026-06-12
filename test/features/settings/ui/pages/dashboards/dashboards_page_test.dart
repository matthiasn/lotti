import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        // _DashboardListItem renders CategoryIconChip.fromId, which
        // resolves the dashboard's category through the cache; the
        // unstubbed mock returns null and triggers the neutral fallback
        // chip, which is fine for most tests here.
        getIt.registerSingleton<EntitiesCacheService>(
          MockEntitiesCacheService(),
        );
      },
    );
    beamToNamedOverride = (_) {};
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpDashboardsPage(
    WidgetTester tester, {
    List<DashboardDefinition> dashboards = const [],
    Object? error,
    bool loading = false,
    Widget child = const DashboardSettingsPage(),
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        child,
        overrides: [
          allDashboardsStreamProvider.overrideWith(
            (ref) => loading
                ? const Stream<List<DashboardDefinition>>.empty()
                : error != null
                ? Stream<List<DashboardDefinition>>.error(error)
                : Stream.value(dashboards),
          ),
        ],
      ),
    );
    // A plain pump() does not advance the test clock; the header's
    // flutter_animate entrance schedules a zero-duration timer that must
    // fire before the test ends, so advance the clock explicitly.
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('DashboardSettingsPage', () {
    group('data rendering', () {
      testWidgets('displays dashboard names sorted alphabetically', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [emptyTestDashboardConfig, testDashboardConfig],
        );

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(2));
        expect(
          [
            tester.widget<DesignSystemListItem>(items.at(0)).title,
            tester.widget<DesignSystemListItem>(items.at(1)).title,
          ],
          [testDashboardConfig.name, emptyTestDashboardConfig.name],
        );
      });

      testWidgets('displays description as subtitle when non-empty', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        expect(find.text(testDashboardConfig.description), findsOneWidget);
      });

      testWidgets('omits subtitle when description is empty', (tester) async {
        final noDescription = testDashboardConfig.copyWith(description: '');
        await pumpDashboardsPage(tester, dashboards: [noDescription]);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.subtitle, isNull);
      });

      testWidgets('displays chevron trailing icon', (tester) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });
    });

    group('leading category chip', () {
      testWidgets(
        'unresolved category renders the neutral chip with the dashboard '
        'initial — never the more_horiz glyph',
        (tester) async {
          // The unstubbed cache resolves the dashboard's categoryId to
          // null, so the chip falls back to the neutral treatment.
          await pumpDashboardsPage(tester, dashboards: [testDashboardConfig]);

          final chipFinder = find.byType(CategoryIconChip);
          expect(chipFinder, findsOneWidget);
          // 'S' for 'Some test dashboard'.
          expect(
            find.descendant(of: chipFinder, matching: find.text('S')),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.more_horiz), findsNothing);
          expect(find.byIcon(Icons.category_outlined), findsNothing);
        },
      );

      testWidgets(
        'resolved category renders the DASHBOARD first letter on the '
        'category color — never the category initial or icon',
        (tester) async {
          final cache =
              getIt<EntitiesCacheService>() as MockEntitiesCacheService;
          when(
            () => cache.getCategoryById(categoryMindfulness.id),
          ).thenReturn(categoryMindfulness);

          await pumpDashboardsPage(tester, dashboards: [testDashboardConfig]);

          final chipFinder = find.byType(CategoryIconChip);
          expect(chipFinder, findsOneWidget);
          expect(find.byIcon(Icons.more_horiz), findsNothing);
          // The dashboard's own initial ('S' for 'Some test dashboard'),
          // not the category's ('M' for Mindfulness)...
          expect(
            find.descendant(of: chipFinder, matching: find.text('S')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: chipFinder, matching: find.text('M')),
            findsNothing,
          );
          // ...while the chip background carries the category color.
          final inner = tester.widget<DefinitionIconChip>(
            find.descendant(
              of: chipFinder,
              matching: find.byType(DefinitionIconChip),
            ),
          );
          expect(inner.background, colorFromCssHex(categoryMindfulness.color));
        },
      );
    });

    group('private indicator', () {
      testWidgets('shows lock icon when private', (tester) async {
        final privateDashboard = testDashboardConfig.copyWith(private: true);
        await pumpDashboardsPage(tester, dashboards: [privateDashboard]);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('hides lock icon when not private', (tester) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        expect(find.byIcon(Icons.lock_outline), findsNothing);
      });
    });

    group('dividers', () {
      testWidgets('shows dividers between items but not after last', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [
            testDashboardConfig,
            emptyTestDashboardConfig,
            testDashboardConfig.copyWith(
              name: 'Zeta Dashboard',
              id: 'zeta-id',
            ),
          ],
        );

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));

        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.showDivider, isTrue);
        expect(second.showDivider, isTrue);
        expect(third.showDivider, isFalse);
      });

      testWidgets('single item has no divider', (tester) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
        );

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.showDivider, isFalse);
      });
    });

    group('empty, error, and loading states', () {
      testWidgets('shows localized empty state when no dashboards exist', (
        tester,
      ) async {
        await pumpDashboardsPage(tester);

        expect(find.byIcon(Icons.dashboard_customize_outlined), findsOneWidget);
        expect(find.text('No dashboards yet'), findsOneWidget);
        expect(
          find.text('Tap the + button to create your first dashboard.'),
          findsOneWidget,
        );
      });

      testWidgets('shows localized error state when the stream errors', (
        tester,
      ) async {
        await pumpDashboardsPage(tester, error: Exception('boards broke'));
        // Riverpod 3 retries failed providers with backoff; the spinner
        // keeps scheduling frames, so settling pumps virtual time through
        // the retries until the terminal AsyncError renders.
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Error loading dashboards'), findsOneWidget);
        expect(find.textContaining('boards broke'), findsOneWidget);
      });

      testWidgets('shows progress indicator while loading', (tester) async {
        await pumpDashboardsPage(tester, loading: true);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DesignSystemSearch), findsNothing);
      });
    });

    group('search', () {
      testWidgets('filters dashboards by name case-insensitively', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [
            testDashboardConfig.copyWith(id: 'dash-a', name: 'Alpha Board'),
            testDashboardConfig.copyWith(id: 'dash-b', name: 'Beta Board'),
          ],
        );

        await tester.enterText(find.byType(TextField), 'ALPHA');
        await tester.pump();

        expect(find.text('Alpha Board'), findsOneWidget);
        expect(find.text('Beta Board'), findsNothing);
      });

      testWidgets('search also matches the dashboard description', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [
            testDashboardConfig.copyWith(
              id: 'dash-a',
              name: 'Alpha Board',
              description: 'Tracks sleep',
            ),
            testDashboardConfig.copyWith(
              id: 'dash-b',
              name: 'Beta Board',
              description: 'Tracks running',
            ),
          ],
        );

        await tester.enterText(find.byType(TextField), 'sleep');
        await tester.pump();

        expect(find.text('Alpha Board'), findsOneWidget);
        expect(find.text('Beta Board'), findsNothing);
      });

      testWidgets('shows localized no-match message for unmatched query', (
        tester,
      ) async {
        await pumpDashboardsPage(tester, dashboards: [testDashboardConfig]);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pump();

        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
        expect(find.text('No dashboards match "zzz"'), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets(
        'FAB carries create-dashboard semantics and beams to create',
        (tester) async {
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          await pumpDashboardsPage(tester, dashboards: [testDashboardConfig]);

          final fab = find.byType(DesignSystemFloatingActionButton);
          expect(
            tester.widget<DesignSystemFloatingActionButton>(fab).semanticLabel,
            'Create dashboard',
          );

          await tester.tap(fab);
          await tester.pump();

          expect(beamedTo, '/settings/dashboards/create');
        },
      );

      testWidgets('tapping a dashboard row beams to its detail route', (
        tester,
      ) async {
        String? beamedTo;
        beamToNamedOverride = (path) => beamedTo = path;

        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig.copyWith(id: 'dash-42')],
        );

        await tester.tap(find.byType(DesignSystemListItem));
        await tester.pump();

        expect(beamedTo, '/settings/dashboards/dash-42');
      });
    });

    group('DashboardsBody embedded alias', () {
      testWidgets('renders a DashboardSettingsPage with its content', (
        tester,
      ) async {
        await pumpDashboardsPage(
          tester,
          dashboards: [testDashboardConfig],
          child: const DashboardsBody(),
        );

        expect(find.byType(DashboardSettingsPage), findsOneWidget);
        expect(find.text(testDashboardConfig.name), findsOneWidget);
      });
    });
  });
}
