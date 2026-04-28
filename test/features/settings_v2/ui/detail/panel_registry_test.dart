import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../mocks/mocks.dart';

void main() {
  group('kSettingsPanels — registered ids', () {
    /// Every panel id the registry is expected to carry. Each must
    /// resolve to a non-null spec AND the dispatcher must be able
    /// to find it via [panelSpecFor]. Keeping the expected set
    /// declared here locks the registry contents against accidental
    /// removal and surfaces additions that weren't deliberately
    /// signed off. Grouped by the plan step that introduced each id.
    const expectedIds = <String>{
      // Branches that carry their own landing page.
      'ai',
      'agents',
      // Step 7 — simple leaves.
      'flags',
      'theming',
      'advanced-about',
      'advanced-maintenance',
      'advanced-logging',
      'sync-backfill',
      'sync-stats',
      'sync-outbox',
      'sync-conflicts',
      'sync-matrix-maintenance',
      // Step 8 — dynamic lists.
      'categories',
      'labels',
      'habits',
      'dashboards',
      'measurables',
      // Step 9 — AI + agents.
      'ai-profiles',
      'agents-templates',
      'agents-souls',
      'agents-instances',
    };

    test('registers every expected panel id', () {
      expect(kSettingsPanels.keys.toSet(), containsAll(expectedIds));
    });

    test('every registered spec carries a non-null builder', () {
      for (final entry in kSettingsPanels.entries) {
        expect(
          entry.value.build,
          isNotNull,
          reason: 'spec for "${entry.key}" should carry a builder',
        );
      }
    });

    test('registry does not carry unexpected ids', () {
      // Additions should be deliberately added to [expectedIds]
      // rather than silently growing the registry.
      expect(kSettingsPanels.keys.toSet(), equals(expectedIds));
    });
  });

  group('panelSpecFor', () {
    test('returns null when given a null id', () {
      expect(panelSpecFor(null), isNull);
    });

    test('returns null for an id not in the registry', () {
      expect(panelSpecFor('no-such-panel'), isNull);
    });

    test('returns the same spec reference that kSettingsPanels holds', () {
      // Every step-7 id should round-trip through the dispatcher
      // helper exactly as it does through a direct map lookup.
      for (final id in kSettingsPanels.keys) {
        expect(
          identical(panelSpecFor(id), kSettingsPanels[id]),
          isTrue,
          reason: 'panelSpecFor("$id") should return the map entry',
        );
      }
    });
  });

  group('SettingsPanelSpec — scrollable flag', () {
    test(
      'defaults to false so bodies that own their scrolling opt-in '
      'rather than opt-out',
      () {
        // `ai-profiles` renders the full AiInferenceProfilesPage with
        // its own CustomScrollView — the scrollable flag must stay
        // false so the host does not wrap it in a
        // SingleChildScrollView.
        expect(panelSpecFor('ai-profiles')!.scrollable, isFalse);
      },
    );

    test('scrollable = true wraps flat-column bodies like FlagsBody', () {
      // FlagsBody is a plain Column; without the outer
      // SingleChildScrollView it would overflow the detail pane.
      expect(panelSpecFor('flags')!.scrollable, isTrue);
    });
  });

  group('SettingsPanelSpec — builders', () {
    // Invoking each registered builder is what proves every panel id
    // is wired to the right Body type — without this, the registry
    // can silently lose a wiring (e.g. `agents-souls` pointing at the
    // `templates` tab) and the structural tests above would still
    // pass. Building under a real BuildContext also exercises every
    // builder line directly, which is what `panel_registry.dart`
    // needs for coverage.
    //
    // We don't pump the returned widgets — most depend on `getIt` /
    // Riverpod setup we'd need to mock. The wiring assertion (right
    // Body class, right `initialTab` argument for the agent variants)
    // is what we actually care about here.
    testWidgets(
      'every registered builder returns the expected Body widget',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        Widget build(String id) => kSettingsPanels[id]!.build(capturedContext);

        // Step 7 — simple leaves.
        expect(build('flags'), isA<FlagsBody>());
        expect(build('theming'), isA<ThemingBody>());
        expect(build('advanced-about'), isA<AboutBody>());
        expect(build('advanced-maintenance'), isA<MaintenanceBody>());
        expect(build('advanced-logging'), isA<LoggingSettingsBody>());
        expect(build('sync-backfill'), isA<BackfillSettingsBody>());
        expect(build('sync-stats'), isA<SyncStatsBody>());
        expect(build('sync-outbox'), isA<OutboxMonitorBody>());
        expect(
          build('sync-matrix-maintenance'),
          isA<MatrixSyncMaintenanceBody>(),
        );

        // Step 8 — dynamic lists. Categories / labels / dashboards /
        // measurables are wrapped in `DetailIdDispatch` because the
        // same panel slot also hosts their detail and create surfaces;
        // the dispatch logic itself is exercised in the dedicated
        // group below. Habits is the lone exception — it has its own
        // internal navigation and doesn't need the dispatcher.
        expect(build('categories'), isA<DetailIdDispatch>());
        expect(build('labels'), isA<DetailIdDispatch>());
        expect(build('habits'), isA<HabitsBody>());
        expect(build('dashboards'), isA<DetailIdDispatch>());
        expect(build('measurables'), isA<DetailIdDispatch>());
        // sync-conflicts moved from `advanced-conflicts` so it could
        // sit next to the other Sync surfaces in the tree. The
        // builder still resolves to ConflictsBody.
        expect(build('sync-conflicts'), isA<ConflictsBody>());

        // Step 9 — AI + agents. The agent variants must each carry
        // the correct `initialTab` so the registry doesn't silently
        // collapse all three tabs onto the same default.
        expect(build('ai'), isA<AiSettingsBody>());
        expect(build('ai-profiles'), isA<InferenceProfilesBody>());

        final agentsRoot = build('agents');
        expect(agentsRoot, isA<AgentSettingsBody>());
        expect((agentsRoot as AgentSettingsBody).initialTab, isNull);

        final templates = build('agents-templates');
        expect(templates, isA<AgentSettingsBody>());
        expect(
          (templates as AgentSettingsBody).initialTab,
          AgentSettingsTab.templates,
        );

        final souls = build('agents-souls');
        expect(souls, isA<AgentSettingsBody>());
        expect(
          (souls as AgentSettingsBody).initialTab,
          AgentSettingsTab.souls,
        );

        final instances = build('agents-instances');
        expect(instances, isA<AgentSettingsBody>());
        expect(
          (instances as AgentSettingsBody).initialTab,
          AgentSettingsTab.instances,
        );
      },
    );
  });

  group('DetailIdDispatch — list/detail/create dispatch', () {
    /// Pumps the dispatcher with a test-owned `ValueNotifier` standing
    /// in for `NavService.desktopSelectedSettingsRoute`. The list /
    /// create / detail builders return dedicated marker widgets so
    /// assertions can pick out exactly which branch fired without
    /// depending on the real list-detail page widgets (which carry
    /// their own DB / Riverpod setup).
    ///
    /// The same notifier is returned so individual tests can mutate it
    /// after the initial pump — proves the dispatcher reacts to live
    /// route changes the way it has to in production.
    Future<ValueNotifier<DesktopSettingsRoute?>> pumpDispatch(
      WidgetTester tester, {
      required DesktopSettingsRoute? route,
    }) async {
      final source = ValueNotifier<DesktopSettingsRoute?>(route);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DetailIdDispatch(
            idParamKey: 'categoryId',
            listenable: source,
            list: (_) => const Text('marker:list'),
            create: (_, route) => Text(
              'marker:create:${route?.queryParameters['name'] ?? ''}',
            ),
            detail: (_, id) => Text('marker:detail:$id'),
          ),
        ),
      );
      await tester.pump();
      return source;
    }

    testWidgets('null route falls back to the list builder', (tester) async {
      await pumpDispatch(tester, route: null);
      expect(find.text('marker:list'), findsOneWidget);
    });

    testWidgets(
      'bare branch URL with no path parameters renders the list builder',
      (tester) async {
        await pumpDispatch(
          tester,
          route: const (
            path: '/settings/categories',
            pathParameters: <String, String>{},
            queryParameters: <String, String>{},
          ),
        );
        expect(find.text('marker:list'), findsOneWidget);
      },
    );

    testWidgets(
      'path ending in /create dispatches to the create builder regardless '
      'of whether categoryId was also bound by Beamer',
      (tester) async {
        // `/settings/categories/create` matches the `:categoryId` route in
        // settings_location.dart, so Beamer hands `categoryId='create'`
        // back as a path parameter. The dispatcher must still pick the
        // create branch — the trailing-`/create` check wins.
        await pumpDispatch(
          tester,
          route: const (
            path: '/settings/categories/create',
            pathParameters: <String, String>{'categoryId': 'create'},
            queryParameters: <String, String>{},
          ),
        );
        expect(find.text('marker:create:'), findsOneWidget);
        expect(find.text('marker:list'), findsNothing);
        expect(find.text('marker:detail:create'), findsNothing);
      },
    );

    testWidgets(
      'create builder receives the active route so it can read query params',
      (tester) async {
        // Labels' create flow prefills the new label name from the
        // `?name=` query parameter; the dispatcher hands the full
        // route through so the builder can see it.
        await pumpDispatch(
          tester,
          route: const (
            path: '/settings/categories/create',
            pathParameters: <String, String>{},
            queryParameters: <String, String>{'name': 'urgent'},
          ),
        );
        expect(find.text('marker:create:urgent'), findsOneWidget);
      },
    );

    testWidgets(
      'pathParameter id present (and not "create") dispatches to the '
      'detail builder with the id',
      (tester) async {
        await pumpDispatch(
          tester,
          route: const (
            path: '/settings/categories/abc-123',
            pathParameters: <String, String>{'categoryId': 'abc-123'},
            queryParameters: <String, String>{},
          ),
        );
        expect(find.text('marker:detail:abc-123'), findsOneWidget);
        expect(find.text('marker:list'), findsNothing);
      },
    );

    testWidgets(
      'empty-string id is treated as no id (falls back to list)',
      (tester) async {
        // Defensive: Beamer should never hand an empty string back
        // here, but if it did the dispatcher must still resolve to a
        // valid panel rather than an empty detail page.
        await pumpDispatch(
          tester,
          route: const (
            path: '/settings/categories/',
            pathParameters: <String, String>{'categoryId': ''},
            queryParameters: <String, String>{},
          ),
        );
        expect(find.text('marker:list'), findsOneWidget);
      },
    );

    testWidgets(
      'route with the "wrong" id parameter (different idParamKey) '
      'falls back to the list',
      (tester) async {
        // The dispatcher only inspects its configured `idParamKey`. A
        // route whose pathParameters carry a `labelId` must not trip
        // a `categoryId`-keyed dispatcher into detail mode.
        await pumpDispatch(
          tester,
          route: const (
            path: '/settings/labels/xyz-789',
            pathParameters: <String, String>{'labelId': 'xyz-789'},
            queryParameters: <String, String>{},
          ),
        );
        expect(find.text('marker:list'), findsOneWidget);
        expect(find.text('marker:detail:xyz-789'), findsNothing);
      },
    );

    testWidgets(
      'mode swap cross-fades — both old and new children co-exist in '
      'the tree mid-transition, then the old one is unmounted',
      (tester) async {
        // This is the user-visible "smooth transition" check: tapping a
        // row should fade the list out as the detail fades in, not
        // swap with a hard cut. The upstream `SettingsDetailPane`
        // already cross-fades between empty / branch / leaf states; this
        // test pins the same motion grammar inside the leaf panel.
        final source = await pumpDispatch(
          tester,
          route: const (
            path: '/settings/categories',
            pathParameters: <String, String>{},
            queryParameters: <String, String>{},
          ),
        );
        expect(find.text('marker:list'), findsOneWidget);

        source.value = const (
          path: '/settings/categories/abc-123',
          pathParameters: <String, String>{'categoryId': 'abc-123'},
          queryParameters: <String, String>{},
        );
        // Mid-transition: both children should be present, wrapped in
        // FadeTransitions whose opacities are partway between 0 and 1.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        expect(find.text('marker:list'), findsOneWidget);
        expect(find.text('marker:detail:abc-123'), findsOneWidget);
        // The dispatcher uses a FadeTransition cross-fade — confirm
        // the wrapping is in place (the smooth-transition contract).
        expect(find.byType(FadeTransition), findsAtLeastNWidgets(2));

        // After the 180 ms cross-fade settles, only the new child is
        // mounted.
        await tester.pumpAndSettle();
        expect(find.text('marker:detail:abc-123'), findsOneWidget);
        expect(find.text('marker:list'), findsNothing);
      },
    );

    testWidgets(
      'live route change rebuilds the dispatcher so list → detail '
      'happens without re-mounting (the production flow when a row '
      'is tapped while the panel is already on-screen)',
      (tester) async {
        // Start on the bare branch URL — list mode.
        final source = await pumpDispatch(
          tester,
          route: const (
            path: '/settings/categories',
            pathParameters: <String, String>{},
            queryParameters: <String, String>{},
          ),
        );
        expect(find.text('marker:list'), findsOneWidget);

        // Beamer publishes the new URL after a tap; the dispatcher
        // must observe it without the user re-navigating in the tree.
        source.value = const (
          path: '/settings/categories/abc-123',
          pathParameters: <String, String>{'categoryId': 'abc-123'},
          queryParameters: <String, String>{},
        );
        await tester.pumpAndSettle();
        // The outgoing list child stays mounted briefly while
        // AnimatedSwitcher cross-fades; we only assert the incoming
        // child appears. The transition itself is exercised by the
        // smooth-cross-fade test below.
        expect(find.text('marker:detail:abc-123'), findsOneWidget);

        // And back again — closing the detail beams to the list URL.
        source.value = const (
          path: '/settings/categories',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );
        await tester.pumpAndSettle();
        expect(find.text('marker:list'), findsOneWidget);
      },
    );
  });

  group('panel registry — list/create/detail closures', () {
    // The categories / labels / dashboards builders construct their
    // `DetailIdDispatch` with three closures (list / create / detail).
    // The wiring is exercised here by invoking each closure directly
    // with synthetic inputs and verifying the resulting widget — this
    // is the only place every closure body is on the line-coverage
    // hook for the registry's list-detail panels.

    setUp(() {
      // EditDashboardPage / CreateDashboardPage read these singletons
      // during their constructor, so the closures can't even build a
      // widget without them registered.
      if (!getIt.isRegistered<JournalDb>()) {
        getIt.registerSingleton<JournalDb>(MockJournalDb());
      }
      if (!getIt.isRegistered<UpdateNotifications>()) {
        getIt.registerSingleton<UpdateNotifications>(MockUpdateNotifications());
      }
    });

    tearDown(() async {
      await getIt.reset();
    });

    Future<({DetailIdDispatch dispatch, BuildContext context})> dispatchFor(
      String panelId,
      WidgetTester tester,
    ) async {
      late BuildContext capturedContext;
      // pumpWidget the builder under a real Element so the returned
      // DetailIdDispatch can be cast (the cast itself is the assertion).
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final widget = kSettingsPanels[panelId]!.build(capturedContext);
      return (dispatch: widget as DetailIdDispatch, context: capturedContext);
    }

    testWidgets('categories panel: list closure returns CategoriesListBody', (
      tester,
    ) async {
      final r = await dispatchFor('categories', tester);
      expect(r.dispatch.idParamKey, 'categoryId');
      expect(r.dispatch.list(r.context), isA<CategoriesListBody>());
    });

    testWidgets(
      'categories panel: create closure returns blank CategoryDetailsPage',
      (tester) async {
        final r = await dispatchFor('categories', tester);
        final created = r.dispatch.create(r.context, null);
        expect(created, isA<CategoryDetailsPage>());
        // No-arg create — the page falls into "create mode" because
        // `categoryId` is null.
        expect((created as CategoryDetailsPage).categoryId, isNull);
      },
    );

    testWidgets(
      'categories panel: detail closure returns CategoryDetailsPage(categoryId: id) '
      'with a stable per-id key so successive detail rows tear down cleanly',
      (tester) async {
        final r = await dispatchFor('categories', tester);
        final detail = r.dispatch.detail(r.context, 'cat-42');
        expect(detail, isA<CategoryDetailsPage>());
        expect((detail as CategoryDetailsPage).categoryId, 'cat-42');
        expect(detail.key, const ValueKey('settings-v2-category-cat-42'));
      },
    );

    testWidgets('labels panel: list closure returns LabelsListBody', (
      tester,
    ) async {
      final r = await dispatchFor('labels', tester);
      expect(r.dispatch.idParamKey, 'labelId');
      expect(r.dispatch.list(r.context), isA<LabelsListBody>());
    });

    testWidgets(
      "labels panel: create closure forwards the route's ?name= query "
      'parameter into LabelDetailsPage.initialName',
      (tester) async {
        final r = await dispatchFor('labels', tester);
        // No route → no prefill.
        final blank = r.dispatch.create(r.context, null);
        expect(blank, isA<LabelDetailsPage>());
        expect((blank as LabelDetailsPage).initialName, isNull);

        // With ?name=urgent → prefill flows through.
        final prefilled = r.dispatch.create(
          r.context,
          const (
            path: '/settings/labels/create',
            pathParameters: <String, String>{},
            queryParameters: <String, String>{'name': 'urgent'},
          ),
        );
        expect((prefilled as LabelDetailsPage).initialName, 'urgent');
      },
    );

    testWidgets(
      'labels panel: detail closure returns LabelDetailsPage(labelId)',
      (tester) async {
        final r = await dispatchFor('labels', tester);
        final detail = r.dispatch.detail(r.context, 'lab-7');
        expect(detail, isA<LabelDetailsPage>());
        expect((detail as LabelDetailsPage).labelId, 'lab-7');
        expect(detail.key, const ValueKey('settings-v2-label-lab-7'));
      },
    );

    testWidgets('dashboards panel: list closure returns DashboardsBody', (
      tester,
    ) async {
      final r = await dispatchFor('dashboards', tester);
      expect(r.dispatch.idParamKey, 'dashboardId');
      expect(r.dispatch.list(r.context), isA<DashboardsBody>());
    });

    testWidgets(
      'dashboards panel: create closure returns CreateDashboardPage',
      (tester) async {
        final r = await dispatchFor('dashboards', tester);
        final created = r.dispatch.create(r.context, null);
        expect(created, isA<CreateDashboardPage>());
      },
    );

    testWidgets(
      'dashboards panel: detail closure returns EditDashboardPage(dashboardId)',
      (tester) async {
        final r = await dispatchFor('dashboards', tester);
        final detail = r.dispatch.detail(r.context, 'dash-3');
        expect(detail, isA<EditDashboardPage>());
        expect((detail as EditDashboardPage).dashboardId, 'dash-3');
        expect(detail.key, const ValueKey('settings-v2-dashboard-dash-3'));
      },
    );

    testWidgets('measurables panel: list closure returns MeasurablesBody', (
      tester,
    ) async {
      final r = await dispatchFor('measurables', tester);
      expect(r.dispatch.idParamKey, 'measurableId');
      expect(r.dispatch.list(r.context), isA<MeasurablesBody>());
    });

    testWidgets(
      'measurables panel: create closure returns CreateMeasurablePage — '
      'this is the path the floating "+" button hits on desktop',
      (tester) async {
        final r = await dispatchFor('measurables', tester);
        final created = r.dispatch.create(r.context, null);
        expect(created, isA<CreateMeasurablePage>());
      },
    );

    testWidgets(
      'measurables panel: detail closure returns EditMeasurablePage(id)',
      (tester) async {
        final r = await dispatchFor('measurables', tester);
        final detail = r.dispatch.detail(r.context, 'meas-9');
        expect(detail, isA<EditMeasurablePage>());
        expect((detail as EditMeasurablePage).measurableId, 'meas-9');
        expect(detail.key, const ValueKey('settings-v2-measurable-meas-9'));
      },
    );
  });

  group('DetailIdDispatch — production NavService fallback', () {
    /// Stand-in NavService that exposes only the route notifier — the
    /// dispatcher reads no other field, so an `UnimplementedError`
    /// from anywhere else would surface a regression that started
    /// touching unrelated NavService surface area.
    Future<void> withStubNavService(
      Future<void> Function(_StubNavService nav) body,
    ) async {
      final nav = _StubNavService();
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(nav);
      try {
        await body(nav);
      } finally {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
        nav.desktopSelectedSettingsRoute.dispose();
      }
    }

    testWidgets(
      'when no `listenable` is supplied, the dispatcher subscribes to '
      '`getIt<NavService>().desktopSelectedSettingsRoute` (production path)',
      (tester) async {
        await withStubNavService((nav) async {
          // Seed the notifier before mount; the initial build should
          // pick up the seeded value via the getIt fallback.
          nav.desktopSelectedSettingsRoute.value = const (
            path: '/settings/categories/seeded-id',
            pathParameters: <String, String>{'categoryId': 'seeded-id'},
            queryParameters: <String, String>{},
          );

          await tester.pumpWidget(
            MaterialApp(
              home: DetailIdDispatch(
                idParamKey: 'categoryId',
                list: (_) => const Text('marker:list'),
                create: (_, _) => const Text('marker:create'),
                detail: (_, id) => Text('marker:detail:$id'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('marker:detail:seeded-id'), findsOneWidget);

          // Pushing a new route on the same notifier rebuilds the
          // dispatcher — proves the listener is live, not just read
          // once on mount.
          nav.desktopSelectedSettingsRoute.value = const (
            path: '/settings/categories',
            pathParameters: <String, String>{},
            queryParameters: <String, String>{},
          );
          await tester.pumpAndSettle();
          expect(find.text('marker:list'), findsOneWidget);
        });
      },
    );
  });
}

class _StubNavService implements NavService {
  @override
  final ValueNotifier<DesktopSettingsRoute?> desktopSelectedSettingsRoute =
      ValueNotifier<DesktopSettingsRoute?>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected NavService call: ${invocation.memberName}',
  );
}
