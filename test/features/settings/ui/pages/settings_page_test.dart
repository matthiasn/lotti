import 'dart:ui';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_indicator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Test controller that returns empty state (no infinite animation).
class _TestWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const n = 111;

  final mockJournalDb = MockJournalDb();

  group('SettingsPage Widget Tests - ', () {
    setUp(() {
      when(mockJournalDb.getJournalCount).thenAnswer((_) async => n);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService());

      // Ensure ThemingController dependencies are registered
      ensureThemingServicesRegistered();
    });
    tearDown(getIt.reset);

    testWidgets('main page is displayed with gated cards enabled', (
      tester,
    ) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: true,
            ),
          },
        ]),
      );

      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Settings'), findsOneWidget);

      expect(find.text('AI Settings'), findsOneWidget);
      // Habits / Categories / Dashboards / Measurables / Flags moved
      // off the root list — they live behind Definitions / Advanced.
      expect(find.text('Habits'), findsNothing);
      expect(find.text('Categories'), findsNothing);
      expect(find.text('Dashboards'), findsNothing);
      expect(find.text('Measurable Types'), findsNothing);
      expect(find.text('Definitions'), findsOneWidget);
      expect(find.text('Theming'), findsOneWidget);
      expect(find.text('Config Flags'), findsNothing);
      expect(find.text('Advanced Settings'), findsOneWidget);
    });

    testWidgets('renders DesignSystemListItem components with dividers', (
      tester,
    ) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
      );

      await _pumpSettingsPage(tester, mockJournalDb);

      // Core items always visible: AI, Agents, Definitions, Theming, Advanced.
      expect(find.byType(DesignSystemListItem), findsNWidgets(5));
    });

    testWidgets('shows Sync tile when Matrix flag is ON', (tester) async {
      when(mockJournalDb.watchConfigFlags).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableHabitsPageFlag,
              description: 'Enable Habits Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableDashboardsPageFlag,
              description: 'Enable Dashboards Page?',
              status: true,
            ),
            const ConfigFlag(
              name: enableMatrixFlag,
              description: 'Enable Matrix?',
              status: true,
            ),
          },
        ]),
      );

      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Sync Settings'), findsOneWidget);
    });

    testWidgets(
      'root list always shows Definitions regardless of habits flag',
      (tester) async {
        // Habits / Dashboards toggles no longer affect the root list —
        // their gating moved into DefinitionsPage. The root entry for
        // Definitions is unconditional.
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableHabitsPageFlag,
                description: 'Enable Habits Page?',
                status: false,
              ),
              const ConfigFlag(
                name: enableDashboardsPageFlag,
                description: 'Enable Dashboards Page?',
                status: true,
              ),
            },
          ]),
        );

        await _pumpSettingsPage(tester, mockJournalDb);

        expect(find.text('Habits'), findsNothing);
        expect(find.text('Dashboards'), findsNothing);
        expect(find.text('Measurable Types'), findsNothing);
        expect(find.text('Definitions'), findsOneWidget);
      },
    );

    testWidgets('shows Agents card', (tester) async {
      await _pumpSettingsPage(tester, mockJournalDb);

      expect(find.text('Agents'), findsOneWidget);
      // Subtitle verifies the full card structure rendered, not just the title.
      expect(
        find.text('Templates, instances, and monitoring'),
        findsOneWidget,
      );
    });

    testWidgets(
      "shows What's New card and indicator when enableWhatsNewFlag is ON",
      (tester) async {
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableWhatsNewFlag,
                description: "Enable What's New feature?",
                status: true,
              ),
            },
          ]),
        );

        await _pumpSettingsPage(tester, mockJournalDb);

        // Settings card with title and subtitle
        expect(find.text("What's New"), findsOneWidget);
        expect(
          find.text('See the latest updates and features'),
          findsOneWidget,
        );
        // The WhatsNewIndicator is rendered in the app bar actions
        expect(find.byType(WhatsNewIndicator), findsOneWidget);
      },
    );

    testWidgets(
      "hides What's New card and indicator when enableWhatsNewFlag is OFF",
      (tester) async {
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
        );

        await _pumpSettingsPage(tester, mockJournalDb);

        expect(find.text("What's New"), findsNothing);
        expect(find.byType(WhatsNewIndicator), findsNothing);
      },
    );

    testWidgets(
      'tapping the Definitions row beams to /settings/definitions',
      (tester) async {
        // Wraps SettingsPage in a Beamer so the onTap closure
        // (`context.beamToNamed('/settings/definitions')`) executes
        // and we can read the resulting URL back from the delegate.
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
        );

        final delegate = BeamerDelegate(
          locationBuilder: RoutesLocationBuilder(
            routes: <String, Widget Function(BuildContext, BeamState, Object?)>{
              '/': (_, _, _) => const SettingsPage(),
              '/settings/definitions': (_, _, _) => const SizedBox.shrink(),
              '/settings/ai': (_, _, _) => const SizedBox.shrink(),
              '/settings/theming': (_, _, _) => const SizedBox.shrink(),
              '/settings/advanced': (_, _, _) => const SizedBox.shrink(),
            },
          ).call,
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BeamerProvider(
              routerDelegate: delegate,
              child: const SettingsPage(),
            ),
            theme: DesignSystemTheme.light(),
            overrides: [
              journalDbProvider.overrideWithValue(mockJournalDb),
              whatsNewControllerProvider.overrideWith(
                _TestWhatsNewController.new,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(SettingsPage));
        await tester.tap(
          find.text(context.messages.settingsDefinitionsTitle),
        );
        await tester.pumpAndSettle();

        expect(
          delegate.configuration.uri.toString(),
          '/settings/definitions',
        );
      },
    );

    testWidgets(
      'root list still shows Definitions when dashboards flag is OFF',
      (tester) async {
        // Dashboards gating moved into DefinitionsPage. Toggling the
        // dashboards flag does not affect what's at the root level —
        // Definitions stays put because Categories / Labels /
        // Measurables are unconditional.
        when(mockJournalDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([
            {
              const ConfigFlag(
                name: enableHabitsPageFlag,
                description: 'Enable Habits Page?',
                status: true,
              ),
              const ConfigFlag(
                name: enableDashboardsPageFlag,
                description: 'Enable Dashboards Page?',
                status: false,
              ),
            },
          ]),
        );

        await _pumpSettingsPage(tester, mockJournalDb);

        expect(find.text('Definitions'), findsOneWidget);
        expect(find.text('Habits'), findsNothing);
        expect(find.text('Dashboards'), findsNothing);
        expect(find.text('Measurable Types'), findsNothing);
      },
    );
  });

  group('SettingsPage divider coordination', () {
    late _DesktopSettingsBench bench;

    setUp(() async {
      bench = await _DesktopSettingsBench.create();
    });

    tearDown(() async {
      await bench.dispose();
    });

    List<DesignSystemListItem> readRows(WidgetTester tester) => tester
        .widgetList<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        )
        .toList();

    testWidgets(
      'with no route active and nothing hovered, the divider between two '
      'idle rows is drawn in the decorative colour (not suppressed)',
      (tester) async {
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        expect(rows.length, greaterThanOrEqualTo(2));

        // Layout is stable: every row except the last still reserves
        // `showDivider: true`. Colour is what toggles to hide the line
        // between interacting rows — when all rows are idle, no override
        // is applied so the divider uses its default colour.
        for (var i = 0; i < rows.length; i++) {
          final shouldShow = i < rows.length - 1;
          expect(
            rows[i].showDivider,
            shouldShow,
            reason: 'row $i showDivider should be $shouldShow',
          );
          expect(
            rows[i].dividerColor,
            isNull,
            reason: 'idle row $i should not override divider colour',
          );
        }
      },
    );

    testWidgets(
      'activating a row paints the dividers on both sides transparent so '
      'the row is not bisected by a partial-width line, without shifting '
      'layout',
      (tester) async {
        // Activate the AI route — that row should be flagged activated,
        // and its neighbours should mask their touching dividers.
        bench.navService.desktopSelectedSettingsRoute.value = (
          path: '/settings/ai',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        final activatedIndex = rows.indexWhere((r) => r.activated);
        expect(
          activatedIndex,
          greaterThanOrEqualTo(0),
          reason: 'Expected an activated row for /settings/ai',
        );

        // The activated row still reserves its divider space; the colour
        // is made transparent so the line visually disappears.
        expect(rows[activatedIndex].showDivider, isTrue);
        expect(rows[activatedIndex].dividerColor, Colors.transparent);

        // The row *above* the activated one also paints its divider
        // transparent — it sits between two rows where one is interacting.
        if (activatedIndex > 0) {
          expect(rows[activatedIndex - 1].showDivider, isTrue);
          expect(
            rows[activatedIndex - 1].dividerColor,
            Colors.transparent,
          );
        }
      },
    );

    testWidgets(
      'activated row also sets selected: true so screen readers announce '
      'the active settings route as the selected list item',
      (tester) async {
        bench.navService.desktopSelectedSettingsRoute.value = (
          path: '/settings/ai',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        final activated = rows.where((r) => r.activated).toList();
        expect(activated, hasLength(1));
        expect(activated.single.selected, isTrue);

        // Every other row must not claim to be selected.
        for (final row in rows.where((r) => !r.activated)) {
          expect(row.selected, isFalse);
        }
      },
    );

    testWidgets(
      'hovering a row paints the dividers on both sides transparent',
      (tester) async {
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        // Target a middle row so we can inspect both neighbours.
        final targetIndex = rows.length ~/ 2;
        final rowFinder = find.byType(DesignSystemListItem).at(targetIndex);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(rowFinder));
        await tester.pumpAndSettle();

        final hoveredRows = readRows(tester);

        // Row itself masks its own bottom divider (if there is one).
        if (targetIndex < hoveredRows.length - 1) {
          expect(
            hoveredRows[targetIndex].dividerColor,
            Colors.transparent,
          );
        }
        // Row above also masks its bottom divider because its next
        // neighbour (the hovered one) is interacting.
        if (targetIndex > 0) {
          expect(
            hoveredRows[targetIndex - 1].dividerColor,
            Colors.transparent,
          );
        }
      },
    );
  });

  group('SettingsPage desktop layout', () {
    late _DesktopSettingsBench bench;

    setUp(() async {
      bench = await _DesktopSettingsBench.create();
    });

    tearDown(() async {
      await bench.dispose();
    });

    testWidgets('uses ValueListenableBuilder on desktop layout', (
      tester,
    ) async {
      bench.navService.desktopSelectedSettingsRoute.value = (
        path: '/settings/ai',
        pathParameters: <String, String>{},
        queryParameters: <String, String>{},
      );
      await bench.pumpPage(tester);

      // The list items should render on desktop
      expect(find.byType(DesignSystemListItem), findsWidgets);
    });
  });
}

/// Shared test fixture for `SettingsPage` tests that need the desktop
/// layout: a journal-db mock, a settings-db mock, a desktop-mode
/// `NavService`, a `UserActivityService`, themed theming services, and
/// a pump helper that wires the standard Riverpod overrides. The two
/// desktop-mode groups in this file used to duplicate this setup line
/// for line — they share it now instead.
class _DesktopSettingsBench {
  _DesktopSettingsBench._({
    required this.mockDb,
    required this.mockSettingsDb,
    required this.navService,
  });

  static Future<_DesktopSettingsBench> create() async {
    await getIt.reset();

    final mockDb = MockJournalDb();
    final mockSettingsDb = MockSettingsDb();

    when(mockDb.getJournalCount).thenAnswer((_) async => 0);
    when(mockDb.watchConfigFlags).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
    );
    when(
      () => mockDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(false));
    when(
      () => mockSettingsDb.itemByKey(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.itemsByKeys(any()),
    ).thenAnswer((_) async => <String, String?>{});
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    final navService = NavService(
      journalDb: mockDb,
      settingsDb: mockSettingsDb,
    )..isDesktopMode = true;

    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<NavService>(navService)
      ..registerSingleton<UserActivityService>(UserActivityService());

    ensureThemingServicesRegistered();

    return _DesktopSettingsBench._(
      mockDb: mockDb,
      mockSettingsDb: mockSettingsDb,
      navService: navService,
    );
  }

  final MockJournalDb mockDb;
  final MockSettingsDb mockSettingsDb;
  final NavService navService;

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SettingsPage(),
        theme: DesignSystemTheme.light(),
        mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
        overrides: [
          journalDbProvider.overrideWithValue(mockDb),
          whatsNewControllerProvider.overrideWith(
            _TestWhatsNewController.new,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    await getIt.reset();
  }
}

Future<void> _pumpSettingsPage(
  WidgetTester tester,
  MockJournalDb mockJournalDb,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const SettingsPage(),
      theme: DesignSystemTheme.light(),
      overrides: [
        journalDbProvider.overrideWithValue(mockJournalDb),
        whatsNewControllerProvider.overrideWith(
          _TestWhatsNewController.new,
        ),
      ],
    ),
  );

  await tester.pumpAndSettle();
}
