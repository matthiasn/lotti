import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

/// Placeholder crumb used by the layout component tests. Those tests
/// exercise overflow, auto-scroll and sizing, not breadcrumb wiring —
/// so every stub column shares the same dummy crumb. Production
/// columns declare meaningful crumbs in `settings_column_stack.dart`.
const _stubCrumb = SettingsColumnCrumb(
  label: SettingsCrumbLabel.root,
  path: '/settings',
);

/// Builds [count] stub columns with keys like `stub-0`. Used by the
/// layout component tests so we can exercise overflow, auto-scroll
/// and sizing without pulling in every real settings page's provider
/// graph.
List<SettingsColumn> _stubColumns(int count) {
  return [
    for (var i = 0; i < count; i++)
      SettingsColumn(
        key: ValueKey('stub-$i'),
        childBuilder: () => ColoredBox(
          color: Colors.grey.shade900,
          child: Center(child: Text('stub-$i')),
        ),
        crumb: _stubCrumb,
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
      'renders a DesignSystemHeader top bar above the column stack with '
      'the settings cog as the leading icon',
      (tester) async {
        navService.isDesktopMode = true;
        navService.desktopSelectedSettingsRoute.value = (
          path: '/settings',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );

        await pumpRoot(tester);

        final header = tester.widget<DesignSystemHeader>(
          find.byType(DesignSystemHeader),
        );
        expect(header.leading, isA<Icon>());
        final icon = header.leading! as Icon;
        expect(icon.icon, Icons.settings_rounded);
        // At the root there's only one crumb so the breadcrumb slot is
        // suppressed (nothing to chain).
        expect(header.breadcrumbs, isNull);
        // And the title reads "Settings" — the root crumb label.
        expect(header.title, isNotEmpty);
      },
    );

    testWidgets(
      'drilling into a sub-route surfaces a breadcrumb trail in the top '
      'bar, marks the leaf as selected, and sets the header title to the '
      'leaf label',
      (tester) async {
        navService.isDesktopMode = true;
        // Use /settings/flags — both the root SettingsPage and the
        // leaf FlagsPage build without extra provider overrides, so we
        // exercise the top-bar rendering without pulling in deeper
        // pages that need their own Riverpod scaffolding.
        navService.desktopSelectedSettingsRoute.value = (
          path: '/settings/flags',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );

        await pumpRoot(tester);

        final header = tester.widget<DesignSystemHeader>(
          find.byType(DesignSystemHeader),
        );
        expect(
          header.breadcrumbs,
          isA<DesignSystemBreadcrumbs>(),
          reason: 'A non-root route should surface a multi-entry breadcrumb',
        );
        final breadcrumbs = header.breadcrumbs! as DesignSystemBreadcrumbs;
        expect(breadcrumbs.items.length, 2);
        // Last crumb is marked selected and has no chevron.
        expect(breadcrumbs.items.last.selected, isTrue);
        expect(breadcrumbs.items.last.showChevron, isFalse);
        // First crumb is a tappable root link with a chevron.
        expect(breadcrumbs.items.first.showChevron, isTrue);
        expect(breadcrumbs.items.first.onPressed, isNotNull);
        // Header title matches the leaf crumb label.
        expect(header.title, breadcrumbs.items.last.label);
      },
    );

    testWidgets(
      'paints the root with tokens.colors.background.level01 so the '
      'settings tab no longer reads darker than the rest of the app',
      (tester) async {
        navService.isDesktopMode = true;
        navService.desktopSelectedSettingsRoute.value = (
          path: '/settings',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );

        await pumpRoot(tester);

        final colored = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(SettingsRootPage),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(
          colored.color,
          dsTokensLight.colors.background.level01,
        );
      },
    );
  });

  // ── Layout component behaviour (stub columns) ─────────────────────────

  group('SettingsColumnStackView layout', () {
    Future<void> pumpStack(
      WidgetTester tester, {
      required int columnCount,
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
            ),
          ),
          mediaQueryData: MediaQueryData(size: Size(viewportWidth, 900)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'every column — including the last — is pinned at the fixed '
      'minimum width on a wide viewport (no last-column Expanded); the '
      'row left-aligns so a 4K display does not stretch the stack '
      'across the whole screen',
      (tester) async {
        await pumpStack(
          tester,
          columnCount: 2,
          viewportWidth: 1600,
        );

        // No Expanded anywhere inside the stack — every column lives
        // inside a fixed-width SizedBox.
        expect(
          find.descendant(
            of: find.byType(SettingsColumnStackView),
            matching: find.byType(Expanded),
          ),
          findsNothing,
        );
        // Both stub columns still render, each at the fixed min width.
        final columnSize0 = tester.getSize(
          find.byKey(const ValueKey('stub-0')),
        );
        final columnSize1 = tester.getSize(
          find.byKey(const ValueKey('stub-1')),
        );
        expect(columnSize0.width, settingsColumnMinWidth);
        expect(columnSize1.width, settingsColumnMinWidth);
      },
    );

    testWidgets(
      'fixed-width row is left-aligned on wide viewports so the columns '
      'hug the navigation sidebar instead of drifting toward the centre',
      (tester) async {
        await pumpStack(
          tester,
          columnCount: 2,
          viewportWidth: 1600,
        );

        // Row width = 2 × 360 + 1 divider = 721. With a 1600 px
        // viewport there's ~879 px of free space; a centred row would
        // sit at x ≈ 440, a left-aligned one sits at x = 0.
        final left = tester.getTopLeft(
          find.byKey(const ValueKey('stub-0')),
        );
        expect(
          left.dx,
          0,
          reason: 'First column must hug the left edge on wide viewports',
        );
      },
    );

    testWidgets(
      'first mount on an already-deep overflowing stack jumps to '
      'maxScrollExtent so the trailing column is visible on arrival',
      (tester) async {
        // 3 × 360 + 2 dividers = 1082 — does not fit in 1000.
        await pumpStack(
          tester,
          columnCount: 3,
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
          // 3 × 360 + 2 dividers = 1082 — does not fit in 1000.
          viewportWidth: 1000,
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
                  );
                },
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(1000, 900)),
          ),
        );
        await tester.pumpAndSettle();

        // 1 column @ 360 fits → no scroll yet.
        expect(_horizontalScrollView(), findsNothing);

        // Drill deeper: 3 columns @ 360 = 1082, overflows 1000.
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
              childBuilder: () => ColoredBox(
                color: Colors.grey.shade900,
                child: Center(child: Text('stub-$i')),
              ),
              crumb: _stubCrumb,
            ),
          SettingsColumn(
            key: ValueKey('leaf-$keyName'),
            childBuilder: () => ColoredBox(
              color: Colors.grey.shade700,
              child: Center(child: Text('leaf-$keyName')),
            ),
            crumb: _stubCrumb,
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
