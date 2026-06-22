import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('kSettingsPanels — registered ids', () {
    /// Every panel id the registry is expected to carry. Each must
    /// resolve to a non-null spec AND the dispatcher must be able
    /// to find it via [panelSpecFor]. Keeping the expected set
    /// declared here locks the registry contents against accidental
    /// removal and surfaces additions that weren't deliberately
    /// signed off. Grouped by the plan step that introduced each id.
    const expectedIds = <String>{
      // Branches that carry their own landing page. Sync has no
      // landing panel — its provisioned-sync entry is a leaf below.
      'ai',
      'agents',
      // Step 7 — simple leaves.
      'flags',
      'theming',
      'speech',
      'advanced-about',
      'advanced-maintenance',
      'advanced-logging',
      'advanced-animations',
      'advanced-onboarding-metrics',
      'sync-provisioned',
      'sync-node-profile',
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
      // Step 9 — AI + agents. The AI tab leaves were promoted to
      // their own sidebar entries in v4 so the right pane never
      // has to render a duplicate in-pane TabBar on desktop.
      'ai-providers',
      'ai-models',
      'ai-profiles',
      'agents-stats',
      'agents-templates',
      'agents-instances',
      'agents-souls',
      'agents-pending-wakes',
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

    test('scrollable = true wraps flat-column bodies like ThemingPage', () {
      // ThemingPage is a plain Column body; without the outer
      // SingleChildScrollView it would overflow the detail pane.
      expect(panelSpecFor('theming')!.scrollable, isTrue);
    });

    test(
      'flags panel keeps scrollable: false because FlagsBody owns its scroll',
      () {
        // FlagsBody is `Column[fixed search, Expanded(scrollable list)]`.
        // The Expanded would receive unbounded height inside an outer
        // SingleChildScrollView and crash at paint time, so the registry
        // must NOT wrap it.
        expect(panelSpecFor('flags')!.scrollable, isFalse);
      },
    );
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
            // The sync-backfill builder reads design tokens eagerly to
            // compute its desktop inset, so the host theme must carry the
            // DsTokens extension.
            theme: resolveTestTheme(),
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
        // Backfill is wrapped in a desktop-only horizontal inset so its
        // content doesn't run edge-to-edge (matching the Stats card margin).
        final backfill = build('sync-backfill');
        expect(backfill, isA<Padding>());
        expect((backfill as Padding).child, isA<BackfillSettingsBody>());
        expect(build('sync-stats'), isA<SyncStatsBody>());
        expect(build('sync-outbox'), isA<OutboxMonitorBody>());
        expect(
          build('sync-matrix-maintenance'),
          isA<MatrixSyncMaintenanceBody>(),
        );

        // Step 8 — dynamic lists. All five definition types are
        // wrapped in `DetailIdDispatch` because the same panel slot
        // also hosts their detail and create surfaces; the dispatch
        // logic itself is exercised in the dedicated group below.
        expect(build('categories'), isA<DetailIdDispatch>());
        expect(build('labels'), isA<DetailIdDispatch>());
        expect(build('habits'), isA<DetailIdDispatch>());
        expect(build('dashboards'), isA<DetailIdDispatch>());
        expect(build('measurables'), isA<DetailIdDispatch>());
        // sync-conflicts moved from `advanced-conflicts` so it could
        // sit next to the other Sync surfaces in the tree, and is now
        // wrapped in `DetailIdDispatch` so a row tap can swap the
        // panel from list to detail (the per-closure wiring is
        // exercised in the dedicated group below).
        expect(build('sync-conflicts'), isA<DetailIdDispatch>());

        // Step 9 — AI + agents. The AI panel is wrapped in the
        // multi-kind `AiPanelDispatch` (v4) so the right pane swaps
        // between the list and per-kind detail pages (provider /
        // model / profile) on desktop instead of pushing fullscreen
        // routes over the master/detail shell — the dispatch
        // behavior itself is asserted in the dedicated group below.
        // The agents tab variants follow the same broad pattern via
        // `DetailIdDispatch`.
        expect(build('ai'), isA<AiPanelDispatch>());
        // Each AI sidebar leaf renders an `AiSettingsBody` pinned to
        // one tab with `hideTabBar: true` so the in-pane TabBar
        // doesn't duplicate the sidebar selection. The legacy
        // `InferenceProfilesBody` is no longer wired into the v2
        // panel registry — the v3 Profiles tab body took its slot.
        for (final entry in {
          'ai-providers': AiSettingsTab.providers,
          'ai-models': AiSettingsTab.models,
          'ai-profiles': AiSettingsTab.profiles,
        }.entries) {
          final body = build(entry.key);
          expect(body, isA<AiSettingsBody>());
          final pinned = body as AiSettingsBody;
          expect(
            pinned.initialTab,
            entry.value,
            reason:
                '${entry.key} must pin AiSettingsBody to '
                '${entry.value} so the matching tab body renders',
          );
          expect(
            pinned.hideTabBar,
            isTrue,
            reason:
                '${entry.key} must hide the in-pane TabBar — the '
                'sidebar leaf is the source of truth for which view '
                'is active on desktop',
          );
          expect(
            pinned.hideHeader,
            isTrue,
            reason:
                '${entry.key} must hide the in-pane SettingsPageHeader '
                '— the master/detail breadcrumb already names the '
                'panel, so the duplicate AI Settings title would just '
                'crowd the search bar',
          );
        }

        final agentsRoot = build('agents');
        expect(agentsRoot, isA<AgentSettingsBody>());
        expect((agentsRoot as AgentSettingsBody).initialTab, isNull);

        // Stats and Pending Wakes are read-only views: no detail/
        // create flow, so they reuse `AgentSettingsBody` directly
        // with the matching `initialTab` as the mobile/test fallback.
        // On desktop the URL drives the tab regardless.
        final stats = build('agents-stats');
        expect(stats, isA<AgentSettingsBody>());
        expect(
          (stats as AgentSettingsBody).initialTab,
          AgentSettingsTab.stats,
        );

        final pendingWakes = build('agents-pending-wakes');
        expect(pendingWakes, isA<AgentSettingsBody>());
        expect(
          (pendingWakes as AgentSettingsBody).initialTab,
          AgentSettingsTab.pendingWakes,
        );

        expect(build('agents-templates'), isA<DetailIdDispatch>());
        expect(build('agents-souls'), isA<DetailIdDispatch>());
        expect(build('agents-instances'), isA<DetailIdDispatch>());

        // The remaining two registered builders: the node-profile page and
        // the provisioned-sync consumer wrapper.
        expect(build('sync-node-profile'), isA<SyncNodeProfilePage>());
        expect(build('sync-provisioned'), isA<Consumer>());
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

    setUp(() async {
      // EditDashboardPage / CreateDashboardPage read these singletons
      // during their constructor, so the closures can't even build a
      // widget without them registered. setUpTestGetIt owns the reset and
      // base registrations (incl. JournalDb/UpdateNotifications mocks), so
      // no conditional reuse of leftover singletons is possible.
      await setUpTestGetIt();
    });

    tearDown(tearDownTestGetIt);

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

    testWidgets(
      'agents-templates panel: list closure pins the templates tab so '
      'tapping the leaf in the tree still lands on the right tab',
      (tester) async {
        final r = await dispatchFor('agents-templates', tester);
        expect(r.dispatch.idParamKey, 'templateId');
        final body = r.dispatch.list(r.context);
        expect(body, isA<AgentSettingsBody>());
        expect(
          (body as AgentSettingsBody).initialTab,
          AgentSettingsTab.templates,
        );
      },
    );

    testWidgets(
      'agents-templates panel: create closure returns blank '
      "AgentTemplateDetailPage — this is the path the templates tab's "
      '"+" button hits on desktop',
      (tester) async {
        final r = await dispatchFor('agents-templates', tester);
        final created = r.dispatch.create(r.context, null);
        expect(created, isA<AgentTemplateDetailPage>());
        expect((created as AgentTemplateDetailPage).templateId, isNull);
      },
    );

    testWidgets(
      'agents-templates panel: detail closure returns '
      'AgentTemplateDetailPage(templateId)',
      (tester) async {
        final r = await dispatchFor('agents-templates', tester);
        final detail = r.dispatch.detail(r.context, 'tpl-1');
        expect(detail, isA<AgentTemplateDetailPage>());
        expect((detail as AgentTemplateDetailPage).templateId, 'tpl-1');
        expect(
          detail.key,
          const ValueKey('settings-v2-agent-template-tpl-1'),
        );
      },
    );

    testWidgets('agents-souls panel: list pins the souls tab', (tester) async {
      final r = await dispatchFor('agents-souls', tester);
      expect(r.dispatch.idParamKey, 'soulId');
      final body = r.dispatch.list(r.context);
      expect(body, isA<AgentSettingsBody>());
      expect((body as AgentSettingsBody).initialTab, AgentSettingsTab.souls);
    });

    testWidgets(
      'agents-souls panel: create closure returns blank AgentSoulDetailPage',
      (tester) async {
        final r = await dispatchFor('agents-souls', tester);
        final created = r.dispatch.create(r.context, null);
        expect(created, isA<AgentSoulDetailPage>());
        expect((created as AgentSoulDetailPage).soulId, isNull);
      },
    );

    testWidgets(
      'agents-souls panel: detail closure returns AgentSoulDetailPage(soulId)',
      (tester) async {
        final r = await dispatchFor('agents-souls', tester);
        final detail = r.dispatch.detail(r.context, 'soul-7');
        expect(detail, isA<AgentSoulDetailPage>());
        expect((detail as AgentSoulDetailPage).soulId, 'soul-7');
        expect(detail.key, const ValueKey('settings-v2-agent-soul-soul-7'));
      },
    );

    testWidgets(
      'agents-instances panel: list pins the instances tab',
      (tester) async {
        final r = await dispatchFor('agents-instances', tester);
        expect(r.dispatch.idParamKey, 'agentId');
        final body = r.dispatch.list(r.context);
        expect(body, isA<AgentSettingsBody>());
        expect(
          (body as AgentSettingsBody).initialTab,
          AgentSettingsTab.instances,
        );
      },
    );

    testWidgets(
      'agents-instances panel: detail closure returns AgentDetailPage(agentId)',
      (tester) async {
        final r = await dispatchFor('agents-instances', tester);
        final detail = r.dispatch.detail(r.context, 'agent-3');
        expect(detail, isA<AgentDetailPage>());
        expect((detail as AgentDetailPage).agentId, 'agent-3');
        expect(
          detail.key,
          const ValueKey('settings-v2-agent-instance-agent-3'),
        );
      },
    );

    testWidgets(
      'agents-instances panel: create closure falls back to the list '
      '(beamer has no `/settings/agents/instances/create` route, so '
      'the closure is structurally unreachable but defensive)',
      (tester) async {
        final r = await dispatchFor('agents-instances', tester);
        final created = r.dispatch.create(r.context, null);
        expect(created, isA<AgentSettingsBody>());
        expect(
          (created as AgentSettingsBody).initialTab,
          AgentSettingsTab.instances,
        );
      },
    );

    testWidgets('sync-conflicts panel: list closure returns ConflictsBody', (
      tester,
    ) async {
      final r = await dispatchFor('sync-conflicts', tester);
      expect(r.dispatch.idParamKey, 'conflictId');
      expect(r.dispatch.list(r.context), isA<ConflictsBody>());
    });

    testWidgets(
      'sync-conflicts panel: create closure falls back to the list — '
      'there is no create flow for conflicts, the closure exists only '
      'because `DetailIdDispatch` requires one',
      (tester) async {
        final r = await dispatchFor('sync-conflicts', tester);
        final created = r.dispatch.create(r.context, null);
        expect(created, isA<ConflictsBody>());
      },
    );

    testWidgets(
      'sync-conflicts panel: detail closure returns '
      'ConflictDetailRoute(conflictId) with a stable per-id key',
      (tester) async {
        final r = await dispatchFor('sync-conflicts', tester);
        final detail = r.dispatch.detail(r.context, 'conflict-12');
        expect(detail, isA<ConflictDetailRoute>());
        expect((detail as ConflictDetailRoute).conflictId, 'conflict-12');
        expect(detail.key, const ValueKey('settings-v2-conflict-conflict-12'));
      },
    );

    // The AI panel uses a custom `AiPanelDispatch` widget (not the
    // generic `DetailIdDispatch`) because three orthogonal detail
    // kinds — provider, model, profile — live behind one panel slot
    // and each is keyed off a different `pathParameters` key. The
    // route → page mapping is extracted into the pure
    // `aiPanelSelectionFor` helper so the tests below can verify
    // every dispatch branch by widget TYPE without having to pump
    // the destination pages (each carries its own Riverpod /
    // repository setup that would dominate every test here).
  });

  group('aiPanelSelectionFor — AI panel route dispatch (v4)', () {
    test(
      'null route resolves to AiSettingsBody with hideTabBar: true — '
      'the AI Settings parent landing on desktop renders the Providers '
      'content (the page-level default tab) without an in-pane TabBar, '
      'so it looks identical to the Providers leaf',
      () {
        final selection = aiPanelSelectionFor(null);
        expect(selection.child, isA<AiSettingsBody>());
        final body = selection.child as AiSettingsBody;
        expect(body.hideTabBar, isTrue);
        expect(body.hideHeader, isTrue);
        expect(body.initialTab, isNull);
        expect(selection.modeKey, 'list');
      },
    );

    test(
      'bare /settings/ai URL with no path parameters resolves to the same '
      'hide-tabs list as the null-route case — a route without any of '
      'the three id keys must never be misread as a detail dispatch',
      () {
        final selection = aiPanelSelectionFor(const (
          path: '/settings/ai',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        ));
        expect(selection.child, isA<AiSettingsBody>());
        final body = selection.child as AiSettingsBody;
        expect(body.hideTabBar, isTrue);
        expect(body.hideHeader, isTrue);
        expect(selection.modeKey, 'list');
      },
    );

    test(
      'providerId in pathParameters resolves to AiProviderDetailPage with '
      'focusApiKey: false by default and a stable per-id ValueKey',
      () {
        final selection = aiPanelSelectionFor(const (
          path: '/settings/ai/provider/gemini-xyz',
          pathParameters: <String, String>{'providerId': 'gemini-xyz'},
          queryParameters: <String, String>{},
        ));
        expect(selection.child, isA<AiProviderDetailPage>());
        final page = selection.child as AiProviderDetailPage;
        expect(page.providerId, 'gemini-xyz');
        expect(page.focusApiKey, isFalse);
        expect(page.key, const ValueKey('settings-v2-ai-provider-gemini-xyz'));
        expect(selection.modeKey, 'provider:gemini-xyz:view');
      },
    );

    test(
      'route with ?focusApiKey=true flips AiProviderDetailPage.focusApiKey '
      'to true AND distinguishes the modeKey from the no-focus variant — '
      'the AnimatedSwitcher needs a different key so the Fix-flow rebuild '
      'actually fires a transition',
      () {
        final selection = aiPanelSelectionFor(const (
          path: '/settings/ai/provider/gemini-xyz',
          pathParameters: <String, String>{'providerId': 'gemini-xyz'},
          queryParameters: <String, String>{'focusApiKey': 'true'},
        ));
        expect(selection.child, isA<AiProviderDetailPage>());
        expect((selection.child as AiProviderDetailPage).focusApiKey, isTrue);
        expect(selection.modeKey, 'provider:gemini-xyz:fix');
      },
    );

    test(
      'modelId in pathParameters resolves to InferenceModelEditPage with '
      'the right configId and a stable per-id ValueKey',
      () {
        final selection = aiPanelSelectionFor(const (
          path: '/settings/ai/model/abc-123',
          pathParameters: <String, String>{'modelId': 'abc-123'},
          queryParameters: <String, String>{},
        ));
        expect(selection.child, isA<InferenceModelEditPage>());
        final page = selection.child as InferenceModelEditPage;
        expect(page.configId, 'abc-123');
        expect(page.key, const ValueKey('settings-v2-ai-model-abc-123'));
        expect(selection.modeKey, 'model:abc-123');
      },
    );

    test(
      'profileId in pathParameters resolves to InferenceProfileDetailPage — '
      'the URL only carries the id so the route goes through the lookup '
      'wrapper rather than InferenceProfileForm directly (which takes the '
      'already-resolved AiConfigInferenceProfile)',
      () {
        final selection = aiPanelSelectionFor(const (
          path: '/settings/ai/profile/prof-9',
          pathParameters: <String, String>{'profileId': 'prof-9'},
          queryParameters: <String, String>{},
        ));
        expect(selection.child, isA<InferenceProfileDetailPage>());
        final page = selection.child as InferenceProfileDetailPage;
        expect(page.profileId, 'prof-9');
        expect(page.key, const ValueKey('settings-v2-ai-profile-prof-9'));
        expect(selection.modeKey, 'profile:prof-9');
      },
    );

    test(
      'providerId takes priority when multiple id keys are accidentally '
      'present (defensive: Beamer should only bind one of the three at a '
      'time, but the dispatcher must pick deterministically if it ever '
      'sees more than one)',
      () {
        final selection = aiPanelSelectionFor(const (
          path: '/settings/ai/provider/p',
          pathParameters: <String, String>{
            'providerId': 'p',
            'modelId': 'm',
            'profileId': 'pr',
          },
          queryParameters: <String, String>{},
        ));
        expect(selection.child, isA<AiProviderDetailPage>());
        expect((selection.child as AiProviderDetailPage).providerId, 'p');
      },
    );

    test(
      'modelId takes priority over profileId when both are present (same '
      'defensive priority order as the if-else chain in the resolver)',
      () {
        final selection = aiPanelSelectionFor(const (
          path: '/settings/ai/model/m',
          pathParameters: <String, String>{
            'modelId': 'm',
            'profileId': 'pr',
          },
          queryParameters: <String, String>{},
        ));
        expect(selection.child, isA<InferenceModelEditPage>());
        expect((selection.child as InferenceModelEditPage).configId, 'm');
      },
    );

    test(
      'empty-string ids fall through to the list — Beamer should never '
      'hand an empty string back here, but if it did the dispatcher must '
      'resolve to a valid panel rather than render an empty detail page',
      () {
        for (final key in ['providerId', 'modelId', 'profileId']) {
          final selection = aiPanelSelectionFor((
            path: '/settings/ai',
            pathParameters: {key: ''},
            queryParameters: const <String, String>{},
          ));
          expect(
            selection.child,
            isA<AiSettingsBody>(),
            reason:
                '$key="" must not be treated as a detail dispatch — the '
                'list is the safe fallback',
          );
          expect(selection.modeKey, 'list');
        }
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

  /// AiPanelDispatch widget-body coverage. The pure resolver
  /// `aiPanelSelectionFor` is already covered above; these tests mount
  /// the actual `AiPanelDispatch` so the ValueListenableBuilder + the
  /// AnimatedSwitcher (layoutBuilder + transitionBuilder) execute.
  group('AiPanelDispatch widget body', () {
    testWidgets(
      'AnimatedSwitcher layoutBuilder stacks children with StackFit.expand',
      (tester) async {
        final notifier = ValueNotifier<DesktopSettingsRoute?>(null);
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AiPanelDispatch(listenable: notifier),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // A StackFit.loose regression silently collapses Scaffold-based
        // children, so the layout policy itself is pinned here.
        final switcher = tester.widget<AnimatedSwitcher>(
          find.byType(AnimatedSwitcher).first,
        );
        final layout = switcher.layoutBuilder(
          const SizedBox(key: ValueKey('current')),
          const <Widget>[SizedBox(key: ValueKey('previous'))],
        );
        expect(layout, isA<Stack>());
        expect((layout as Stack).fit, StackFit.expand);
      },
    );

    testWidgets(
      'mounts the resolver-selected child for the seeded route — the '
      'list arm renders when no detail id is bound',
      (tester) async {
        final notifier = ValueNotifier<DesktopSettingsRoute?>(null);
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AiPanelDispatch(listenable: notifier),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The list arm uses `AiSettingsBody(hideTabBar: true)`; it
        // pumps a Riverpod-backed page that ultimately renders an
        // empty state — searching by widget type is the cheapest way
        // to assert the list arm landed without spinning up the full
        // bench. The widget is private to the AI feature, so we
        // assert by `KeyedSubtree` carrying the `'list'` mode key.
        final keyedSubtree = tester
            .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
            .firstWhere((k) => k.key == const ValueKey('list'));
        expect(keyedSubtree, isNotNull);
      },
    );

    testWidgets(
      'rebuilds the dispatched child when the route notifier swaps from '
      'the list to a per-id detail mode — covers the live listener path '
      'plus the AnimatedSwitcher cross-fade transition builder',
      (tester) async {
        final notifier = ValueNotifier<DesktopSettingsRoute?>(null);
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AiPanelDispatch(listenable: notifier),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial mode is "list".
        expect(
          tester
              .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
              .where((k) => k.key == const ValueKey('list')),
          isNotEmpty,
        );

        // Swap the route to a per-provider detail URL — the dispatcher
        // must rebuild and pick up the matching mode key.
        notifier.value = const (
          path: '/settings/ai/provider/p-99',
          pathParameters: <String, String>{'providerId': 'p-99'},
          queryParameters: <String, String>{},
        );
        // Pump mid-transition to exercise the AnimatedSwitcher's
        // layoutBuilder + transitionBuilder branches.
        await tester.pump();
        await tester.pump(kSettingsPanelSwapDuration ~/ 2);
        await tester.pumpAndSettle();

        // The cross-fade swaps to the provider:view mode key.
        expect(
          tester
              .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
              .where((k) => k.key == const ValueKey('provider:p-99:view')),
          isNotEmpty,
        );
      },
    );

    testWidgets(
      'falls back to `getIt<NavService>().desktopSelectedSettingsRoute` '
      'when no `listenable` is supplied — the production wiring path',
      (tester) async {
        if (getIt.isRegistered<NavService>()) {
          getIt.unregister<NavService>();
        }
        final nav = _StubNavService();
        getIt.registerSingleton<NavService>(nav);
        addTearDown(() {
          if (getIt.isRegistered<NavService>()) {
            getIt.unregister<NavService>();
          }
          nav.desktopSelectedSettingsRoute.dispose();
        });

        nav.desktopSelectedSettingsRoute.value = const (
          path: '/settings/ai/model/m-7',
          pathParameters: <String, String>{'modelId': 'm-7'},
          queryParameters: <String, String>{},
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: const <ThemeExtension<dynamic>>[dsTokensLight],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AiPanelDispatch(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Resolved through the production NavService — the model arm
        // landed in the dispatcher.
        expect(
          tester
              .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
              .where((k) => k.key == const ValueKey('model:m-7')),
          isNotEmpty,
        );
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
