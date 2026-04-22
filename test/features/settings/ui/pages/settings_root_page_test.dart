import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_stack.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _TestWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

/// Desktop viewport wide enough for the root menu + empty detail slot.
const _desktopMediaQuery = MediaQueryData(size: Size(1600, 900));

const _mobileMediaQuery = MediaQueryData(size: Size(800, 600));

/// Builds [count] stub columns with keys like `stub-0`. Used by the
/// layout component tests so we can exercise overflow, auto-scroll
/// and sizing without pulling in every real settings page's provider
/// graph.
List<SettingsColumn> _stubColumns(int count) {
  return [
    for (var i = 0; i < count; i++)
      SettingsColumn(
        key: ValueKey('stub-$i'),
        child: ColoredBox(
          color: Colors.grey.shade900,
          child: Center(child: Text('stub-$i')),
        ),
      ),
  ];
}

Finder _horizontalScrollView() => find.descendant(
  of: find.byType(SettingsColumnStackView),
  matching: find.byWidgetPredicate(
    (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockSettingsDb mockSettingsDb;
  late NavService navService;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockSettingsDb = MockSettingsDb();

    when(mockJournalDb.watchConfigFlags).thenAnswer(
      (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
    );
    when(mockJournalDb.getJournalCount).thenAnswer((_) async => 0);
    when(
      () => mockJournalDb.watchConfigFlag(any()),
    ).thenAnswer((_) => Stream.value(false));
    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(
      () => mockSettingsDb.itemsByKeys(any()),
    ).thenAnswer((_) async => <String, String?>{});
    when(
      () => mockSettingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);

    navService = NavService(
      journalDb: mockJournalDb,
      settingsDb: mockSettingsDb,
    );

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<NavService>(navService)
      ..registerSingleton<UserActivityService>(UserActivityService());

    ensureThemingServicesRegistered();
  });

  tearDown(() async {
    await navService.dispose();
    await getIt.reset();
  });

  List<Override> buildOverrides() => [
    journalDbProvider.overrideWithValue(mockJournalDb),
    whatsNewControllerProvider.overrideWith(_TestWhatsNewController.new),
    paneWidthControllerProvider.overrideWith(PaneWidthController.new),
  ];

  Future<void> pumpRoot(
    WidgetTester tester, {
    MediaQueryData mediaQuery = _desktopMediaQuery,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SettingsRootPage(),
        mediaQueryData: mediaQuery,
        overrides: buildOverrides(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ── Root page behaviour ────────────────────────────────────────────────

  group('SettingsRootPage mobile layout', () {
    testWidgets(
      'falls back to the single-pane SettingsPage on narrow viewports',
      (tester) async {
        await pumpRoot(tester, mediaQuery: _mobileMediaQuery);

        expect(find.byType(SettingsPage), findsOneWidget);
        expect(
          find.byType(SettingsColumnStackView),
          findsNothing,
          reason:
              'The multi-column stack is desktop-only; mobile must stay '
              'on the single SettingsPage push-navigation flow.',
        );
      },
    );
  });

  group('SettingsRootPage desktop layout', () {
    testWidgets(
      '/settings root route renders the column stack with only the root '
      'SettingsPage column',
      (tester) async {
        navService.isDesktopMode = true;
        navService.desktopSelectedSettingsRoute.value = (
          path: '/settings',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );

        await pumpRoot(tester);

        expect(find.byType(SettingsColumnStackView), findsOneWidget);
        expect(find.byType(SettingsPage), findsOneWidget);
      },
    );

    testWidgets(
      'passes the listPaneWidth token into the stack view as its '
      'column width so existing pane widths are honoured',
      (tester) async {
        navService.isDesktopMode = true;
        navService.desktopSelectedSettingsRoute.value = (
          path: '/settings',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );

        await pumpRoot(tester);

        final stack = tester.widget<SettingsColumnStackView>(
          find.byType(SettingsColumnStackView),
        );
        expect(stack.columnWidth, defaultListPaneWidth);
      },
    );
  });

  // ── Layout component behaviour (stub columns) ─────────────────────────

  group('SettingsColumnStackView layout', () {
    Future<void> pumpStack(
      WidgetTester tester, {
      required int columnCount,
      required double columnWidth,
      required double viewportWidth,
    }) async {
      // The Flutter test surface defaults to 800×600 regardless of what
      // MediaQuery reports, so physically resize the view to match the
      // viewport we want to test against.
      tester.view.physicalSize = Size(viewportWidth, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: SettingsColumnStackView(
              columns: _stubColumns(columnCount),
              columnWidth: columnWidth,
            ),
          ),
          mediaQueryData: MediaQueryData(size: Size(viewportWidth, 900)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'stack that fits the viewport lays out with the last column Expanded '
      'and no horizontal scroll view',
      (tester) async {
        await pumpStack(
          tester,
          columnCount: 2,
          columnWidth: 540,
          viewportWidth: 1600,
        );

        // Expanded lives inside the stack view only for the fits branch;
        // the scroll branch wraps everything in fixed-width SizedBoxes.
        expect(
          find.descendant(
            of: find.byType(SettingsColumnStackView),
            matching: find.byType(Expanded),
          ),
          findsOneWidget,
        );
        expect(_horizontalScrollView(), findsNothing);
        expect(find.text('stub-0'), findsOneWidget);
        expect(find.text('stub-1'), findsOneWidget);
      },
    );

    testWidgets(
      'first mount on an already-deep overflowing stack jumps to '
      'maxScrollExtent so the trailing column is visible on arrival',
      (tester) async {
        // 3 × 540 + 2 dividers = 1622 — does not fit in 1000.
        await pumpStack(
          tester,
          columnCount: 3,
          columnWidth: 540,
          viewportWidth: 1000,
        );

        final scrollable = tester.widget<SingleChildScrollView>(
          _horizontalScrollView(),
        );
        final position = scrollable.controller!.position;
        expect(
          position.pixels,
          closeTo(position.maxScrollExtent, 0.5),
          reason:
              'Initial mount on a deep stack (e.g. window-restore into '
              '/settings/sync/backfill) should jump to maxScrollExtent so '
              'the selected leaf is on-screen.',
        );
      },
    );

    testWidgets(
      'stack that overflows the viewport wraps the row in a horizontal '
      'SingleChildScrollView',
      (tester) async {
        await pumpStack(
          tester,
          columnCount: 3,
          columnWidth: 540,
          // 3 × 540 + 2 dividers = 1622 — does not fit in 1200.
          viewportWidth: 1200,
        );

        expect(_horizontalScrollView(), findsOneWidget);
        expect(find.text('stub-0'), findsOneWidget);
        expect(find.text('stub-1'), findsOneWidget);
        expect(find.text('stub-2'), findsOneWidget);
      },
    );

    testWidgets(
      'drilling deeper while the stack overflows auto-scrolls to the '
      'newly-appended column',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var columnCount = 1;
        late StateSetter outerSetState;

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SettingsColumnStackView(
                    columns: _stubColumns(columnCount),
                    columnWidth: 540,
                  );
                },
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1000, 900)),
          ),
        );
        await tester.pumpAndSettle();

        // 1 column @ 540 fits → no scroll yet.
        expect(_horizontalScrollView(), findsNothing);

        // Drill deeper: 3 columns = 1622, overflows 1000.
        outerSetState(() => columnCount = 3);
        await tester.pump(); // commit widget swap
        await tester.pump(); // post-frame scroll schedule
        await tester.pump(const Duration(milliseconds: 250)); // settle anim

        final scrollable = tester.widget<SingleChildScrollView>(
          _horizontalScrollView(),
        );
        final position = scrollable.controller!.position;
        expect(
          position.pixels,
          closeTo(position.maxScrollExtent, 0.5),
          reason:
              'Auto-scroll should have moved the horizontal scroll offset '
              'all the way to maxScrollExtent so the newly-added column '
              'is fully visible.',
        );
      },
    );

    testWidgets(
      'lateral swap at the same depth with a different last-column key '
      'auto-scrolls to the trailing column',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var lastKey = 'a';
        late StateSetter outerSetState;

        List<SettingsColumn> columnsFor(String keyName) => [
          for (var i = 0; i < 2; i++)
            SettingsColumn(
              key: ValueKey('stub-$i'),
              child: ColoredBox(
                color: Colors.grey.shade900,
                child: Center(child: Text('stub-$i')),
              ),
            ),
          SettingsColumn(
            key: ValueKey('leaf-$keyName'),
            child: ColoredBox(
              color: Colors.grey.shade700,
              child: Center(child: Text('leaf-$keyName')),
            ),
          ),
        ];

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SettingsColumnStackView(
                    columns: columnsFor(lastKey),
                    columnWidth: 540,
                  );
                },
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1000, 900)),
          ),
        );
        await tester.pumpAndSettle();

        final scrollableBefore = tester.widget<SingleChildScrollView>(
          _horizontalScrollView(),
        );
        // Reset scroll to left edge so we can detect that the swap triggered
        // a right-edge auto-scroll and not just carry-over from the initial
        // mount.
        scrollableBefore.controller!.jumpTo(0);
        await tester.pump();

        outerSetState(() => lastKey = 'b');
        await tester.pump(); // widget swap
        await tester.pump(); // post-frame schedule
        await tester.pump(const Duration(milliseconds: 250));

        final scrollable = tester.widget<SingleChildScrollView>(
          _horizontalScrollView(),
        );
        final position = scrollable.controller!.position;
        expect(
          position.pixels,
          closeTo(position.maxScrollExtent, 0.5),
          reason:
              'Swapping the trailing column for a different key at the same '
              'depth counts as drilling and should auto-scroll to maxScrollExtent.',
        );
        expect(find.text('leaf-b'), findsOneWidget);
      },
    );

    testWidgets(
      'collapsing the stack (user navigates up) does not try to '
      'auto-scroll',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var columnCount = 3;
        late StateSetter outerSetState;

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SettingsColumnStackView(
                    columns: _stubColumns(columnCount),
                    columnWidth: 540,
                  );
                },
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1000, 900)),
          ),
        );
        await tester.pumpAndSettle();

        outerSetState(() => columnCount = 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(_horizontalScrollView(), findsNothing);
      },
    );

    testWidgets(
      'columns are separated by a 1 px vertical divider (N-1 dividers for '
      'N columns)',
      (tester) async {
        await pumpStack(
          tester,
          columnCount: 4,
          columnWidth: 200,
          viewportWidth: 1600,
        );

        // The dividers live inside the stack view as Container(width: 1.0).
        final dividers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(SettingsColumnStackView),
                matching: find.byType(Container),
              ),
            )
            .where((c) => c.constraints?.maxWidth == 1.0)
            .toList();
        expect(dividers.length, 3);
      },
    );

    testWidgets(
      'single-column stack renders no dividers',
      (tester) async {
        await pumpStack(
          tester,
          columnCount: 1,
          columnWidth: 400,
          viewportWidth: 1600,
        );

        final dividers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(SettingsColumnStackView),
                matching: find.byType(Container),
              ),
            )
            .where((c) => c.constraints?.maxWidth == 1.0)
            .toList();
        expect(dividers, isEmpty);
      },
    );
  });
}
