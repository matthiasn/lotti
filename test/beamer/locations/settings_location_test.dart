import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/ui/agent_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_settings_page.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/agents/ui/agent_template_detail_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_review_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_review_page.dart';
import 'package:lotti/features/ai/ui/inference_profile_form.dart';
import 'package:lotti/features/ai/ui/inference_profile_page.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';
import 'package:lotti/features/ai/ui/settings/inference_model_edit_page.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_page.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/daily_os_settings_page.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/features/keyboard/ui/keyboard_shortcuts_page.dart';
import 'package:lotti/features/labels/ui/pages/label_details_page.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/onboarding/ui/onboarding_metrics_page.dart';
import 'package:lotti/features/onboarding/ui/onboarding_settings_panel.dart';
import 'package:lotti/features/projects/ui/pages/project_detail_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/about_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/maintenance_page.dart';
import 'package:lotti/features/settings/ui/pages/advanced/manual_language_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/create_dashboard_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboard_definition_page.dart';
import 'package:lotti/features/settings/ui/pages/dashboards/dashboards_page.dart';
import 'package:lotti/features/settings/ui/pages/flags_page.dart';
import 'package:lotti/features/settings/ui/pages/habits/habits_page.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_create_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/features/settings/ui/pages/recording_style_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_root_page.dart';
import 'package:lotti/features/settings/ui/pages/theming_page.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_branch_page.dart';
import 'package:lotti/features/settings_v2/ui/mobile/settings_mobile_root_page.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/sync/ui/matrix_sync_maintenance_page.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_route.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflicts_page.dart';
import 'package:lotti/features/sync/ui/pages/outbox/outbox_monitor_page.dart';
import 'package:lotti/features/sync/ui/pages/sync_node_profile_page.dart';
import 'package:lotti/features/sync/ui/provisioned_sync_page.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/features/tts/ui/speech_settings_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

/// Page keys of the three settings branch hubs. The production location
/// spells these inline; they are named here so the branch-navigation tables
/// below can pair a leaf with the hub page it must uncover.
const ValueKey<String> definitionsHubKey = ValueKey('settings-definitions');
const ValueKey<String> preferencesHubKey = ValueKey('settings-preferences');
const ValueKey<String> advancedHubKey = ValueKey('settings-advanced');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsLocation', () {
    late MockBuildContext mockBuildContext;
    late NavService navService;
    late MockJournalDb mockJournalDb;
    late MockSettingsDb mockSettingsDb;

    setUp(() {
      mockBuildContext = MockBuildContext();
      mockJournalDb = MockJournalDb();
      mockSettingsDb = MockSettingsDb();

      when(
        () => mockJournalDb.watchConfigFlag(any()),
      ).thenAnswer((_) => Stream.value(false));
      when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => mockSettingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);

      navService = NavService(
        journalDb: mockJournalDb,
        settingsDb: mockSettingsDb,
      );

      for (final unregister in [
        if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>,
        if (getIt.isRegistered<NavService>()) getIt.unregister<NavService>,
      ]) {
        unregister();
      }
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(navService);
    });

    tearDown(() async {
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    test('pathPatterns are correct', () {
      final location = SettingsLocation(
        RouteInformation(uri: Uri.parse('/settings')),
      );
      expect(location.pathPatterns, [
        '/settings',
        '/settings/onboarding',
        '/settings/ai',
        '/settings/ai/profiles',
        // AI Settings detail surfaces — added in v4 so per-kind detail
        // pages can be deep-linked / bookmarked / picked up by the
        // desktop master/detail panel dispatcher.
        '/settings/ai/provider/:providerId',
        '/settings/ai/model/:modelId',
        '/settings/ai/profile/:profileId',
        '/settings/sync',
        '/settings/sync/provisioned',
        '/settings/sync/matrix/maintenance',
        '/settings/sync/node-profile',
        '/settings/sync/backfill',
        '/settings/sync/stats',
        '/settings/sync/outbox',
        '/settings/categories',
        '/settings/categories/:categoryId',
        '/settings/categories/create',
        '/settings/projects/:projectId',
        '/settings/labels',
        '/settings/labels/create',
        '/settings/labels/:labelId',
        '/settings/dashboards',
        '/settings/dashboards/:dashboardId',
        '/settings/dashboards/create',
        '/settings/measurables',
        '/settings/measurables/:measurableId',
        '/settings/measurables/create',
        '/settings/habits',
        '/settings/habits/by_id/:habitId',
        '/settings/habits/create',
        '/settings/habits/search/:searchTerm',
        '/settings/agents',
        // Bare per-tab landings — Settings V2 tree leaves under
        // `agents` canonicalize to these and the in-page tab bar
        // beams here when the user switches tabs on desktop.
        '/settings/agents/templates',
        '/settings/agents/instances',
        '/settings/agents/souls',
        '/settings/agents/pending-wakes',
        '/settings/agents/templates/create',
        '/settings/agents/templates/:templateId',
        '/settings/agents/templates/:templateId/review',
        '/settings/agents/souls/create',
        '/settings/agents/souls/:soulId',
        '/settings/agents/souls/:soulId/review',
        '/settings/agents/instances/:agentId',
        '/settings/daily-os',
        '/settings/flags',
        '/settings/recording-style',
        '/settings/theming',
        '/settings/keyboard-shortcuts',
        '/settings/speech',
        '/settings/definitions',
        '/settings/preferences',
        '/settings/advanced',
        '/settings/advanced/animations',
        '/settings/advanced/manual-language',
        '/settings/advanced/logging_domains',
        '/settings/advanced/conflicts/:conflictId',
        '/settings/advanced/conflicts',
        '/settings/advanced/maintenance',
        '/settings/advanced/onboarding_metrics',
        '/settings/health_import',
        // Legacy alias kept so hand-edited bookmarks that hit the
        // pattern advertised on `main` still render the MaintenancePage.
        '/settings/maintenance',
      ]);
    });

    test(
      'legacy /settings/maintenance alias still renders MaintenancePage',
      () {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/maintenance'),
        );
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);
        // Settings root + MaintenancePage. The old URL never pushed an
        // Advanced intermediate page, so the stack is 2 pages deep.
        expect(pages.length, 2);
        expect(pages[0].child, isA<SettingsMobileRootPage>());
        expect(pages[1].child, isA<MaintenancePage>());
      },
    );

    test('buildPages builds SettingsMobileRootPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/settings'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<SettingsMobileRootPage>());
    });

    test('buildPages builds LabelsListPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/labels'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<LabelsListPage>());
    });

    test('buildPages builds LabelDetailsPage for create', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/labels/create'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<LabelsListPage>());
      expect(pages[3].child, isA<LabelDetailsPage>());
    });

    test('buildPages builds LabelDetailsPage with labelId', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/labels/test-id'),
      );
      var beamState = BeamState.fromRouteInformation(routeInformation);
      final location = SettingsLocation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'labelId': 'test-id'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<LabelsListPage>());
      expect(pages[3].child, isA<LabelDetailsPage>());
      final labelPage = pages[3].child as LabelDetailsPage;
      expect(labelPage.labelId, 'test-id');
    });

    test('buildPages builds AiSettingsPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/settings/ai'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AiSettingsPage>());
    });

    test('buildPages builds InferenceProfilePage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/ai/profiles'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      // The legacy profiles leaf keeps the AI Settings list beneath it on
      // the shared `settings-ai` key, so a back tap reveals the list that
      // is already mounted instead of swapping this page for a fresh one.
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AiSettingsPage>());
      expect(pages[1].key, const ValueKey('settings-ai'));
      expect(pages[2].child, isA<InferenceProfilePage>());
    });

    /// AI Settings v4 — per-kind detail BeamPages. Each test mounts the
    /// location through a real MaterialApp so `context.messages` (used
    /// for the localised page title) actually resolves; the rest of the
    /// suite uses a `MockBuildContext` for non-localised stacks.
    Future<List<BeamPage>> pumpAndBuildPages(
      WidgetTester tester,
      BeamState beamState,
      RouteInformation routeInformation,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final location = SettingsLocation(routeInformation);
      return location.buildPages(capturedContext, beamState);
    }

    testWidgets(
      'buildPages stacks AiProviderDetailPage on top of AiSettingsPage '
      'for /settings/ai/provider/:providerId — the detail page must sit '
      'above the list so the back gesture returns to the list, not all '
      'the way to the Settings root',
      (tester) async {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/ai/provider/gemini-1'),
        );
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'providerId': 'gemini-1'});

        final pages = await pumpAndBuildPages(
          tester,
          beamState,
          routeInformation,
        );

        expect(pages.length, 3);
        expect(pages[0].child, isA<SettingsMobileRootPage>());
        expect(pages[1].child, isA<AiSettingsPage>());
        expect(pages[2].child, isA<AiProviderDetailPage>());
        final detailPage = pages[2].child as AiProviderDetailPage;
        expect(detailPage.providerId, 'gemini-1');
        expect(detailPage.focusApiKey, isFalse);
      },
    );

    testWidgets(
      'buildPages threads ?focusApiKey=true into AiProviderDetailPage so '
      'the Fix-flow URL is bookmarkable',
      (tester) async {
        final routeInformation = RouteInformation(
          uri: Uri.parse(
            '/settings/ai/provider/gemini-1?focusApiKey=true',
          ),
        );
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'providerId': 'gemini-1'});

        final pages = await pumpAndBuildPages(
          tester,
          beamState,
          routeInformation,
        );

        final detailPage = pages.last.child as AiProviderDetailPage;
        expect(detailPage.focusApiKey, isTrue);
      },
    );

    testWidgets(
      'buildPages stacks InferenceModelEditPage for /settings/ai/model/:id '
      'and forwards the modelId into the page constructor',
      (tester) async {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/ai/model/m-1'),
        );
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'modelId': 'm-1'});

        final pages = await pumpAndBuildPages(
          tester,
          beamState,
          routeInformation,
        );

        expect(pages.length, 3);
        expect(pages[0].child, isA<SettingsMobileRootPage>());
        expect(pages[1].child, isA<AiSettingsPage>());
        expect(pages[2].child, isA<InferenceModelEditPage>());
        final modelPage = pages[2].child as InferenceModelEditPage;
        expect(modelPage.configId, 'm-1');
      },
    );

    testWidgets(
      'buildPages stacks InferenceProfileDetailPage for '
      '/settings/ai/profile/:id — the URL only carries the id so the '
      'wrapper page resolves the profile via Riverpod',
      (tester) async {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/ai/profile/p-1'),
        );
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'profileId': 'p-1'});

        final pages = await pumpAndBuildPages(
          tester,
          beamState,
          routeInformation,
        );

        expect(pages.length, 3);
        expect(pages[0].child, isA<SettingsMobileRootPage>());
        expect(pages[1].child, isA<AiSettingsPage>());
        expect(pages[2].child, isA<InferenceProfileDetailPage>());
        final profilePage = pages[2].child as InferenceProfileDetailPage;
        expect(profilePage.profileId, 'p-1');
      },
    );

    /// The AI Settings list — the destination every AI detail page returns
    /// to, and the URL its `popToNamed` must name.
    const aiListUrl = '/settings/ai';

    /// Every AI-settings detail surface, as
    /// `(label, url, path-parameter key, path-parameter value)`. Shared by
    /// the `buildPages`-level group and the real-navigator group below so
    /// a new detail kind is added in exactly one place and both levels
    /// provably cover the same set.
    const aiDetailRoutes = <(String, String, String, String)>[
      ('provider', '/settings/ai/provider/gemini-1', 'providerId', 'gemini-1'),
      ('model', '/settings/ai/model/m-1', 'modelId', 'm-1'),
      ('profile', '/settings/ai/profile/p-1', 'profileId', 'p-1'),
    ];

    /// Back navigation out of the AI-settings detail pages.
    ///
    /// Beamer's default pop (`BeamPage.pathSegmentPop`) strips exactly ONE
    /// URI segment. Every AI detail URL is two segments deep under the list
    /// (`/settings/ai/<kind>/<id>`), so without an explicit `popToNamed` the
    /// first back tap strands the route on `/settings/ai/<kind>` — a URL
    /// that carries no id and therefore rebuilds the AI Settings list. The
    /// next back tap pops that dead URI to `/settings/ai`, which builds the
    /// very same list page again: the user taps back, watches the list slide
    /// out and an identical list slide back in, and is still on the page
    /// they were trying to leave. `popToNamed` skips the dead intermediate
    /// URI so one back tap is one level, with a real pop transition.
    group('AI settings detail pages pop back to the list in one tap', () {
      Future<List<BeamPage>> buildFor(
        WidgetTester tester,
        String url, {
        Map<String, String> pathParameters = const {},
      }) {
        final routeInformation = RouteInformation(uri: Uri.parse(url));
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: pathParameters);
        return pumpAndBuildPages(tester, beamState, routeInformation);
      }

      for (final (label, url, paramKey, paramValue) in aiDetailRoutes) {
        testWidgets(
          'the $label detail page declares popToNamed $aiListUrl so its '
          'back tap skips the dead /settings/ai/$label URI',
          (tester) async {
            final pages = await buildFor(
              tester,
              url,
              pathParameters: {paramKey: paramValue},
            );

            expect(pages.last.popToNamed, aiListUrl);
          },
        );
      }

      testWidgets(
        'the Fix-flow URL (?focusApiKey=true) pops to the bare list URL, '
        'so re-entering the detail page does not silently re-focus the key',
        (tester) async {
          final pages = await buildFor(
            tester,
            '/settings/ai/provider/gemini-1?focusApiKey=true',
            pathParameters: {'providerId': 'gemini-1'},
          );

          expect(pages.last.popToNamed, aiListUrl);
        },
      );

      testWidgets(
        'the AI Settings list itself sets no popToNamed — it is one segment '
        'deep, so Beamer default single-segment pop already lands on '
        '/settings',
        (tester) async {
          final pages = await buildFor(tester, aiListUrl);

          expect(pages.last.child, isA<AiSettingsPage>());
          expect(pages.last.popToNamed, isNull);
        },
      );

      testWidgets(
        'the legacy /settings/ai/profiles leaf sets no popToNamed either — '
        'it is one segment deep, and it now keeps the list beneath it so '
        'the default pop reveals that page rather than swapping it',
        (tester) async {
          final pages = await buildFor(tester, '/settings/ai/profiles');

          expect(pages.last.child, isA<InferenceProfilePage>());
          expect(pages.last.popToNamed, isNull);
          expect(pages[1].key, const ValueKey('settings-ai'));
        },
      );
    });

    /// The same contract, but exercised end to end through a real
    /// [BeamerDelegate] and a real [Navigator] — the layer that actually
    /// consumes `popToNamed` (`BeamerDelegate._onPopPage`). Page *children*
    /// are swapped for placeholders by [_RoutingOnlySettingsLocation] so the
    /// stack mounts without standing up the whole AI settings dependency
    /// graph; every routing input Beamer reads — path patterns, page keys,
    /// `popToNamed` — still comes from the production location.
    group('AI settings back navigation through a real Beamer navigator', () {
      late BeamerDelegate delegate;
      late _RouteRecordingObserver observer;

      /// Mounts the settings page stack at `/settings`, then walks the same
      /// route sequence a user does: Settings → AI Settings → detail. Going
      /// through `beamToNamed` (rather than deep-linking straight to the
      /// detail URL) is what gives Beamer the real beaming history its pop
      /// machinery consults.
      Future<void> openDetail(WidgetTester tester, String detailUrl) async {
        observer = _RouteRecordingObserver();
        delegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/settings',
          navigatorObservers: [observer],
          locationBuilder: (routeInformation, _) =>
              _RoutingOnlySettingsLocation(routeInformation),
        );
        await delegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/settings')),
        );
        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routeInformationParser: BeamerParser(),
            routerDelegate: delegate,
          ),
        );
        await tester.pumpAndSettle();

        for (final url in ['/settings/ai', detailUrl]) {
          delegate.beamToNamed(url);
          await tester.pumpAndSettle();
        }
      }

      /// The system back gesture and the header chevron both end up here:
      /// `SettingsHeaderBar` pops the visible page stack, and Beamer turns
      /// that into a route update via `BeamerDelegate._onPopPage`.
      Future<void> tapBack(WidgetTester tester) async {
        delegate.navigator.pop();
        await tester.pumpAndSettle();
      }

      List<Object?> pageKeys() =>
          delegate.currentPages.map((page) => page.key).toList();

      tearDown(() => delegate.dispose());

      for (final (label, url, _, _) in aiDetailRoutes) {
        testWidgets(
          'one back tap from the $label detail page lands on the AI Settings '
          'list, not on the dead /settings/ai/$label URI',
          (tester) async {
            await openDetail(tester, url);
            expect(delegate.currentPages, hasLength(3));

            await tapBack(tester);

            expect(delegate.configuration.uri.path, aiListUrl);
            expect(pageKeys(), const [
              ValueKey('settings'),
              ValueKey('settings-ai'),
            ]);
          },
        );
      }

      testWidgets(
        'the legacy profiles leaf reveals the AI Settings list beneath it '
        'instead of swapping itself for a fresh copy of that list',
        (tester) async {
          await openDetail(tester, '/settings/ai/profiles');
          expect(delegate.currentPages, hasLength(3));

          observer.reset();
          await tapBack(tester);

          expect(delegate.configuration.uri.path, aiListUrl);
          expect(pageKeys(), const [
            ValueKey('settings'),
            ValueKey('settings-ai'),
          ]);
          // The list was already mounted underneath, so the pop uncovers
          // it. A pushed `settings-ai` here would mean the leaf had been
          // swapped for a new list — the wrong-transition symptom.
          expect(observer.pushedKeys, isEmpty);
          expect(observer.goneKeys, const [ValueKey('settings-ai-profiles')]);
        },
      );

      testWidgets(
        'two back taps from a detail page reach the Settings root — the '
        'user never lands on the AI Settings list twice',
        (tester) async {
          await openDetail(tester, '/settings/ai/provider/gemini-1');

          await tapBack(tester);
          await tapBack(tester);

          expect(delegate.configuration.uri.path, '/settings');
          expect(pageKeys(), const [ValueKey('settings')]);
        },
      );

      testWidgets(
        'backing out of the AI Settings list removes it instead of pushing '
        'a second copy on top of itself',
        (tester) async {
          await openDetail(tester, '/settings/ai/provider/gemini-1');
          await tapBack(tester);

          observer.reset();
          await tapBack(tester);

          // The wrong-transition symptom is Navigator swapping one AI
          // Settings page for an identical one, so the list slides out and
          // an identical list slides straight back in. Leaving the list
          // must only remove it.
          expect(observer.pushedKeys, isEmpty);
          expect(observer.goneKeys, const [ValueKey('settings-ai')]);
        },
      );

      testWidgets(
        'the Fix-flow URL pops back to the list with its query dropped, so '
        'the API-key field is not re-focused on the way out',
        (tester) async {
          await openDetail(
            tester,
            '/settings/ai/provider/gemini-1?focusApiKey=true',
          );

          await tapBack(tester);

          expect(delegate.configuration.uri.toString(), '/settings/ai');
        },
      );
    });

    /// Back navigation out of a settings *branch* leaf.
    ///
    /// A branch hub (Definitions / Preferences / Advanced) is a pure
    /// navigation page that `buildPages` keeps beneath its leaves so a back
    /// tap returns to the hub rather than to the Settings root. Whether it
    /// stays there is decided by the hub's own path predicate, evaluated
    /// against whatever URL the pop produces.
    ///
    /// Beamer's default pop strips one URI segment, and most branch leaves
    /// keep flat URLs that do not nest under their hub's — `/settings/
    /// categories` under a hub at `/settings/definitions`. Stripping a
    /// segment there lands on `/settings`, the hub predicate stops matching,
    /// and the hub is dropped from the stack along with the leaf: one back
    /// tap left the branch. The hub was still uncovered by the Navigator's
    /// pop animation and only replaced once the route rebuild landed, which
    /// is why it read as the Definitions page bouncing back to Settings by
    /// itself a moment later.
    ///
    /// Each `(leaf URL, hub URL, hub page key)`, **derived from the same
    /// lists the routing reads** — `definitionsLeafPaths`,
    /// `preferencesLeafPaths` and `advancedFlatLeafPaths`. A leaf added to one
    /// of those is added to every group below at once; a hand-written table
    /// here would let a new leaf ship with the bug and no red test.
    ///
    /// Shared by all three groups so a leaf is provably covered at the
    /// predicate, `buildPages` and real-navigator levels alike.
    final branchLeaves = <(String, String, ValueKey<String>)>[
      // Definitions — the reported bug.
      for (final leaf in definitionsLeafPaths)
        (leaf, definitionsHubUrl, definitionsHubKey),
      // Preferences — the same flat-URL shape, so the same bug. Animations is
      // in this list while its URL sits under `/settings/advanced/`, so its
      // default pop reached the *wrong branch's* hub, not merely the root.
      for (final leaf in preferencesLeafPaths)
        (leaf, preferencesHubUrl, preferencesHubKey),
      // Advanced's two flat leaves.
      for (final leaf in advancedFlatLeafPaths)
        (leaf, advancedHubUrl, advancedHubKey),
    ];

    test('every branch leaf is covered by the tables below', () {
      // Guards the derivation itself: if a list is emptied or a branch is
      // dropped, the loops below would silently generate no tests at all.
      expect(definitionsLeafPaths, isNotEmpty);
      expect(preferencesLeafPaths, isNotEmpty);
      expect(advancedFlatLeafPaths, isNotEmpty);
      expect(
        branchLeaves.length,
        definitionsLeafPaths.length +
            preferencesLeafPaths.length +
            advancedFlatLeafPaths.length,
      );
      // The hub URLs resolve out of the settings tree, so a branch renamed
      // there fails here rather than at runtime on a null assertion.
      expect(definitionsHubUrl, '/settings/definitions');
      expect(preferencesHubUrl, '/settings/preferences');
      expect(advancedHubUrl, '/settings/advanced');
    });

    group('settingsBranchHubOf names the hub a leaf returns to', () {
      for (final (leaf, hub, _) in branchLeaves) {
        test('$leaf -> $hub', () {
          expect(settingsBranchHubOf(leaf), hub);
        });
      }

      test(
        'animations resolves to Preferences, not the Advanced hub its URL '
        'sits under — the branch is a property of the leaf, not the path',
        () {
          expect(
            settingsBranchHubOf('/settings/advanced/animations'),
            preferencesHubUrl,
          );
          expect(
            settingsBranchHubOf('/settings/advanced/maintenance'),
            advancedHubUrl,
          );
        },
      );

      test(
        'a detail URL under a leaf still names the hub, for the list page '
        'sitting beneath it in the stack',
        () {
          expect(
            settingsBranchHubOf('/settings/categories/cat-1'),
            definitionsHubUrl,
          );
          expect(
            settingsBranchHubOf('/settings/habits/by_id/h-1'),
            definitionsHubUrl,
          );
        },
      );

      // A hub naming itself would make its own back tap a no-op, trapping
      // the user on the hub.
      for (final hub in [
        definitionsHubUrl,
        preferencesHubUrl,
        advancedHubUrl,
      ]) {
        test('the $hub hub itself names no destination', () {
          expect(settingsBranchHubOf(hub), isNull);
        });
      }

      for (final outside in const [
        '/settings',
        '/settings/ai',
        '/settings/ai/provider/gemini-1',
        '/settings/sync/backfill',
        '/settings/agents',
        '/settings/onboarding',
        '/settings/daily-os',
      ]) {
        test('$outside is not in a hub branch, so it names no destination', () {
          expect(settingsBranchHubOf(outside), isNull);
        });
      }
    });

    group('branch leaf pages declare their hub as popToNamed', () {
      List<BeamPage> buildFor(String uri) {
        final routeInformation = RouteInformation(uri: Uri.parse(uri));
        return SettingsLocation(routeInformation).buildPages(
          mockBuildContext,
          BeamState.fromRouteInformation(routeInformation),
        );
      }

      for (final (leaf, hub, _) in branchLeaves) {
        test('$leaf pops to $hub', () {
          expect(buildFor(leaf).last.popToNamed, hub);
        });
      }

      for (final hub in [
        definitionsHubUrl,
        preferencesHubUrl,
        advancedHubUrl,
      ]) {
        test('the $hub hub sets none — its default pop reaches /settings', () {
          expect(buildFor(hub).last.popToNamed, isNull);
        });
      }

      test(
        'a leaf detail page pops to its list, not past it to the hub — the '
        'list page beneath is the one carrying the hub destination',
        () {
          final routeInformation = RouteInformation(
            uri: Uri.parse('/settings/categories/cat-1'),
          );
          final pages = SettingsLocation(routeInformation).buildPages(
            mockBuildContext,
            BeamState.fromRouteInformation(
              routeInformation,
            ).copyWith(pathParameters: {'categoryId': 'cat-1'}),
          );

          expect(pages, hasLength(4));
          expect(pages[2].key, const ValueKey('settings-categories'));
          expect(pages[2].popToNamed, definitionsHubUrl);
          // No destination of its own: the default single-segment pop from
          // `/settings/categories/cat-1` already reaches the list.
          expect(pages[3].popToNamed, isNull);
        },
      );
    });

    /// The same contract end to end, through a real [BeamerDelegate] and
    /// [Navigator] — the layer that actually consumes `popToNamed`. Children
    /// are placeholders ([_RoutingOnlySettingsLocation]); every routing input
    /// Beamer reads still comes from the production location.
    group('branch back navigation through a real Beamer navigator', () {
      late BeamerDelegate delegate;
      late _RouteRecordingObserver observer;

      /// Walks the route sequence a user does — Settings, hub, leaf — rather
      /// than deep-linking to the leaf, so Beamer has the real beaming
      /// history its pop machinery consults.
      Future<void> openLeaf(
        WidgetTester tester,
        String hub,
        String leaf, {
        List<String> then = const [],
      }) async {
        observer = _RouteRecordingObserver();
        delegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/settings',
          navigatorObservers: [observer],
          locationBuilder: (routeInformation, _) =>
              _RoutingOnlySettingsLocation(routeInformation),
        );
        await delegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/settings')),
        );
        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routeInformationParser: BeamerParser(),
            routerDelegate: delegate,
          ),
        );
        await tester.pumpAndSettle();

        for (final url in [hub, leaf, ...then]) {
          delegate.beamToNamed(url);
          await tester.pumpAndSettle();
        }
      }

      Future<void> tapBack(WidgetTester tester) async {
        delegate.navigator.pop();
        await tester.pumpAndSettle();
      }

      List<Object?> pageKeys() =>
          delegate.currentPages.map((page) => page.key).toList();

      tearDown(() => delegate.dispose());

      for (final (leaf, hub, hubKey) in branchLeaves) {
        testWidgets('one back tap from $leaf lands on $hub, not /settings', (
          tester,
        ) async {
          await openLeaf(tester, hub, leaf);
          expect(delegate.currentPages, hasLength(3));

          await tapBack(tester);

          expect(delegate.configuration.uri.path, hub);
          expect(pageKeys(), [const ValueKey('settings'), hubKey]);
        });
      }

      testWidgets(
        'the hub is uncovered rather than swapped for a fresh copy, so the '
        'back tap plays a pop and not a push',
        (tester) async {
          await openLeaf(tester, definitionsHubUrl, '/settings/categories');

          observer.reset();
          await tapBack(tester);

          expect(observer.pushedKeys, isEmpty);
          expect(observer.goneKeys, const [ValueKey('settings-categories')]);
        },
      );

      testWidgets(
        'a second back tap then leaves the branch for the Settings root — '
        'the two levels the one tap used to collapse into one',
        (tester) async {
          await openLeaf(tester, definitionsHubUrl, '/settings/categories');

          await tapBack(tester);
          await tapBack(tester);

          expect(delegate.configuration.uri.path, '/settings');
          expect(pageKeys(), const [ValueKey('settings')]);
        },
      );

      testWidgets(
        'from a category detail the way out is detail, list, hub, root — one '
        'level per tap, no level skipped',
        (tester) async {
          await openLeaf(
            tester,
            definitionsHubUrl,
            '/settings/categories',
            then: ['/settings/categories/cat-1'],
          );
          expect(delegate.currentPages, hasLength(4));

          await tapBack(tester);
          expect(delegate.configuration.uri.path, '/settings/categories');

          await tapBack(tester);
          expect(delegate.configuration.uri.path, definitionsHubUrl);

          await tapBack(tester);
          expect(delegate.configuration.uri.path, '/settings');
        },
      );

      testWidgets(
        'backing out of Animations reaches Preferences, not the Advanced hub '
        'whose URL prefix it borrows',
        (tester) async {
          await openLeaf(
            tester,
            preferencesHubUrl,
            '/settings/advanced/animations',
          );

          await tapBack(tester);

          expect(delegate.configuration.uri.path, preferencesHubUrl);
          expect(pageKeys(), const [
            ValueKey('settings'),
            preferencesHubKey,
          ]);
        },
      );

      testWidgets(
        'a nested Advanced leaf was never broken and still pops to its hub',
        (tester) async {
          await openLeaf(
            tester,
            advancedHubUrl,
            '/settings/advanced/maintenance',
          );

          await tapBack(tester);

          expect(delegate.configuration.uri.path, advancedHubUrl);
          expect(pageKeys(), const [ValueKey('settings'), advancedHubKey]);
        },
      );
    });

    test('buildPages builds the sync branch hub from the shared tree', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/sync'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      final gate = pages[1].child;
      expect(gate, isA<SyncFeatureGate>());
      final hub = (gate as SyncFeatureGate).child;
      expect(hub, isA<SettingsMobileBranchPage>());
      expect((hub as SettingsMobileBranchPage).branchId, 'sync');
    });

    test('buildPages builds MatrixSyncMaintenancePage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/sync/matrix/maintenance'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      final gate = pages[1].child;
      expect(gate, isA<SyncFeatureGate>());
      final hub = (gate as SyncFeatureGate).child;
      expect(hub, isA<SettingsMobileBranchPage>());
      expect((hub as SettingsMobileBranchPage).branchId, 'sync');
      expect(pages[2].child, isA<MatrixSyncMaintenancePage>());
    });

    test('buildPages builds CategoriesListPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/categories'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<CategoriesListPage>());
    });

    test('buildPages builds CategoryDetailsPage for create', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/categories/create'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<CategoriesListPage>());
      expect(pages[3].child, isA<CategoryDetailsPage>());
    });

    test('buildPages builds CategoryDetailsPage with categoryId', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/categories/test-id'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'categoryId': 'test-id'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<CategoriesListPage>());
      expect(pages[3].child, isA<CategoryDetailsPage>());
      final categoryPage = pages[3].child as CategoryDetailsPage;
      expect(categoryPage.categoryId, 'test-id');
    });

    test('buildPages builds ProjectDetailPage with projectId', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/projects/proj-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'projectId': 'proj-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<ProjectDetailPage>());
      final detailPage = pages[1].child as ProjectDetailPage;
      expect(detailPage.projectId, 'proj-123');
    });

    test(
      'buildPages does NOT render ProjectDetailPage for the legacy '
      '/settings/projects/create slug — the `:projectId` pattern would '
      'greedily match `create`, but the create flow now lives under '
      'ProjectsLocation, so this branch must skip the reserved slug',
      () {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/projects/create'),
        );
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(
          routeInformation,
        ).copyWith(pathParameters: {'projectId': 'create'});

        final pages = location.buildPages(mockBuildContext, beamState);

        // Only the SettingsMobileRootPage shell — no ProjectDetailPage in
        // the stack, even though `pathContains('projects')` is true.
        expect(pages.length, 1);
        expect(pages[0].child, isA<SettingsMobileRootPage>());
        expect(
          pages.where((p) => p.child is ProjectDetailPage),
          isEmpty,
        );
      },
    );

    test('buildPages builds DashboardSettingsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/dashboards'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<DashboardSettingsPage>());
    });

    test('buildPages builds EditDashboardPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/dashboards/dash-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'dashboardId': 'dash-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<DashboardSettingsPage>());
      expect(pages[3].child, isA<EditDashboardPage>());
    });

    test('buildPages builds CreateDashboardPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/dashboards/create'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<DashboardSettingsPage>());
      expect(pages[3].child, isA<CreateDashboardPage>());
    });

    test('buildPages builds MeasurablesPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/measurables'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<MeasurablesPage>());
    });

    test('buildPages builds EditMeasurablePage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/measurables/meas-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'measurableId': 'meas-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<MeasurablesPage>());
      expect(pages[3].child, isA<EditMeasurablePage>());
    });

    test('buildPages builds CreateMeasurablePage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/measurables/create'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<MeasurablesPage>());
      expect(pages[3].child, isA<CreateMeasurablePage>());
    });

    test('buildPages builds HabitsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/habits'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<HabitsPage>());
    });

    test('buildPages builds HabitsPage with search term', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/habits/search/test'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'searchTerm': 'test'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<HabitsPage>());
      final habitsPage = pages[2].child as HabitsPage;
      expect(habitsPage.initialSearchTerm, 'test');
      // Beamer's default pop walks one URI segment at a time, which would
      // strand the route on the dead `/settings/habits/search` URI.
      expect(pages[2].popToNamed, '/settings/habits');
    });

    test('buildPages builds the habit editor for an existing habit', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/habits/by_id/habit-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'habitId': 'habit-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<HabitsPage>());
      final editor = pages[3].child as HabitEditorPage;
      expect(editor.habitId, 'habit-123');
      expect(editor.isCreate, isFalse);
      // Opened from settings, the editor returns to the settings list.
      expect(editor.returnPath, '/settings/habits');
      // Beamer's default pop walks one URI segment at a time, which would
      // strand the route on the dead `/settings/habits/by_id` URI — the
      // list page would render with the bottom nav still hidden, costing
      // an extra back tap. Popping the editor must land on the list URI.
      expect(pages[3].popToNamed, '/settings/habits');
    });

    test('buildPages builds the habit editor in create mode', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/habits/create'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(pages[2].child, isA<HabitsPage>());
      final editor = pages[3].child as HabitEditorPage;
      expect(editor.isCreate, isTrue);
      expect(editor.returnPath, '/settings/habits');
    });

    test('buildPages builds AgentSettingsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
    });

    test('buildPages builds DailyOsSettingsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/daily-os'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<DailyOsSettingsPage>());
    });

    test('buildPages builds AgentTemplateDetailPage for create', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents/templates/create'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
      expect(pages[2].child, isA<AgentTemplateDetailPage>());
    });

    test('buildPages builds AgentTemplateDetailPage with templateId', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents/templates/tmpl-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'templateId': 'tmpl-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
      expect(pages[2].child, isA<AgentTemplateDetailPage>());
      final detailPage = pages[2].child as AgentTemplateDetailPage;
      expect(detailPage.templateId, 'tmpl-123');
    });

    test('buildPages builds AgentDetailPage with agentId', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents/instances/agent-456'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'agentId': 'agent-456'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
      expect(pages[2].child, isA<AgentDetailPage>());
      final detailPage = pages[2].child as AgentDetailPage;
      expect(detailPage.agentId, 'agent-456');
    });

    test('buildPages builds AgentSoulDetailPage for create', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents/souls/create'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
      expect(pages[2].child, isA<AgentSoulDetailPage>());
    });

    test('buildPages builds AgentSoulDetailPage with soulId', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents/souls/soul-789'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'soulId': 'soul-789'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
      expect(pages[2].child, isA<AgentSoulDetailPage>());
      final detailPage = pages[2].child as AgentSoulDetailPage;
      expect(detailPage.soulId, 'soul-789');
    });

    test('buildPages builds FlagsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/flags'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<FlagsPage>());
    });

    /// Asserts the mobile stack for a preference leaf: root, the
    /// Preferences hub, then the page itself. The hub in the middle is
    /// what makes a back tap return to Preferences instead of dropping
    /// the user at the top of Settings.
    void expectPreferenceLeafStack(String url, Matcher pageMatcher) {
      final routeInformation = RouteInformation(uri: Uri.parse(url));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);

      expect(pages.length, 3, reason: url);
      expect(pages[0].child, isA<SettingsMobileRootPage>(), reason: url);
      expect(pages[1].child, isA<SettingsMobileBranchPage>(), reason: url);
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'preferences',
        reason: url,
      );
      expect(pages[2].child, pageMatcher, reason: url);
    }

    test('buildPages builds RecordingStyleSettingsPage under the hub', () {
      expectPreferenceLeafStack(
        '/settings/recording-style',
        isA<RecordingStyleSettingsPage>(),
      );
    });

    test('buildPages builds ThemingPage under the hub', () {
      expectPreferenceLeafStack('/settings/theming', isA<ThemingPage>());
    });

    test('buildPages builds KeyboardShortcutsPage under the hub', () {
      expectPreferenceLeafStack(
        '/settings/keyboard-shortcuts',
        isA<KeyboardShortcutsPage>(),
      );
    });

    test('buildPages builds SpeechSettingsPage under the hub', () {
      expectPreferenceLeafStack('/settings/speech', isA<SpeechSettingsPage>());
    });

    test(
      'buildPages builds CelebrationSettingsPage under the Preferences hub',
      () {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/advanced/animations'),
        );
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);
        // The URL still says `advanced`, but the node moved to the
        // Preferences branch — so the hub beneath it is Preferences, and
        // a back tap returns there rather than to Advanced.
        expect(pages.length, 3);
        expect(pages[0].child, isA<SettingsMobileRootPage>());
        expect(pages[1].child, isA<SettingsMobileBranchPage>());
        expect(
          (pages[1].child as SettingsMobileBranchPage).branchId,
          'preferences',
        );
        expect(pages[2].child, isA<CelebrationSettingsPage>());
      },
    );

    test('buildPages builds OnboardingSettingsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/onboarding'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<OnboardingSettingsPage>());
    });

    test(
      'buildPages does NOT render OnboardingSettingsPage for the '
      'onboarding-metrics URL — the exact-path guard must not let '
      '`/settings/advanced/onboarding_metrics` fall through to it',
      () {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/advanced/onboarding_metrics'),
        );
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);
        expect(
          pages.any((p) => p.child is OnboardingSettingsPage),
          isFalse,
        );
        expect(pages.any((p) => p.child is OnboardingMetricsPage), isTrue);
      },
    );

    test('buildPages builds HealthImportPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/health_import'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      // Health import's tree node lives under Advanced, so the hub stays
      // in the stack beneath it (drill-down back returns to Advanced).
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect((pages[1].child as SettingsMobileBranchPage).branchId, 'advanced');
      expect(pages[2].child, isA<HealthImportPage>());
    });

    test('buildPages builds the advanced branch hub', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
    });

    test('buildPages builds the preferences branch hub', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/preferences'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'preferences',
      );
    });

    test(
      'the preferences hub does not leak into unrelated settings stacks',
      () {
        // `_inPreferencesBranch` matches on explicit leaf URLs, so a
        // route that merely *contains* one of those words — or that
        // shares the `/settings/advanced/` prefix animations kept — must
        // not push the hub.
        for (final url in const [
          '/settings/advanced',
          '/settings/advanced/maintenance',
          '/settings/categories',
          '/settings/daily-os',
          '/settings/flags',
        ]) {
          final routeInformation = RouteInformation(uri: Uri.parse(url));
          final location = SettingsLocation(routeInformation);
          final beamState = BeamState.fromRouteInformation(routeInformation);
          final branchIds = location
              .buildPages(mockBuildContext, beamState)
              .map((page) => page.child)
              .whereType<SettingsMobileBranchPage>()
              .map((page) => page.branchId);
          expect(branchIds, isNot(contains('preferences')), reason: url);
        }
      },
    );

    test(
      'a preference URL with a trailing segment still stacks under the hub',
      () {
        // `_inPreferencesBranch` matches `path.startsWith('<leaf>/')` as
        // well as an exact hit, so a deep link that carries a
        // panel-local suffix keeps the hub beneath it rather than
        // dropping the user back at the Settings root on the way out.
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/theming/anything'),
        );
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);
        expect(pages[1].child, isA<SettingsMobileBranchPage>());
        expect(
          (pages[1].child as SettingsMobileBranchPage).branchId,
          'preferences',
        );
      },
    );

    test('buildPages builds the definitions branch hub', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/definitions'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
    });

    test('buildPages builds OutboxMonitorPage under /settings/sync/outbox', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/sync/outbox'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      final gate = pages[1].child;
      expect(gate, isA<SyncFeatureGate>());
      final hub = (gate as SyncFeatureGate).child;
      expect(hub, isA<SettingsMobileBranchPage>());
      expect((hub as SettingsMobileBranchPage).branchId, 'sync');
      // The leaf page carries no gate of its own, so the route wraps it —
      // a stale deep link in a guest/demo world must not build a sync
      // surface whose stack is structurally absent.
      final leafGate = pages[2].child;
      expect(leafGate, isA<SyncFeatureGate>());
      expect((leafGate as SyncFeatureGate).child, isA<OutboxMonitorPage>());
    });

    test(
      'buildPages gates SyncNodeProfilePage under /settings/sync/node-profile',
      () {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/sync/node-profile'),
        );
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(
          mockBuildContext,
          beamState,
        );
        expect(pages.length, 3);
        final leafGate = pages[2].child;
        expect(leafGate, isA<SyncFeatureGate>());
        expect(
          (leafGate as SyncFeatureGate).child,
          isA<SyncNodeProfilePage>(),
        );
      },
    );

    test('buildPages builds SyncStatsPage under /settings/sync/stats', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/sync/stats'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      final gate = pages[1].child;
      expect(gate, isA<SyncFeatureGate>());
      final hub = (gate as SyncFeatureGate).child;
      expect(hub, isA<SettingsMobileBranchPage>());
      expect((hub as SettingsMobileBranchPage).branchId, 'sync');
      expect(pages[2].child, isA<SyncStatsPage>());
    });

    test(
      'buildPages stacks the provisioned-sync leaf under the sync hub',
      () {
        final routeInformation = RouteInformation(
          uri: Uri.parse('/settings/sync/provisioned'),
        );
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final pages = location.buildPages(mockBuildContext, beamState);
        expect(pages.length, 3);
        expect(pages[0].child, isA<SettingsMobileRootPage>());
        // The hub base sits beneath the leaf so back returns to the list.
        final hubGate = pages[1].child;
        expect(hubGate, isA<SyncFeatureGate>());
        expect(
          ((hubGate as SyncFeatureGate).child as SettingsMobileBranchPage)
              .branchId,
          'sync',
        );
        // The leaf renders the provisioned-sync wrapper page.
        expect(pages[2].child, isA<ProvisionedSyncPage>());
      },
    );

    test('buildPages builds LoggingSettingsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/logging_domains'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<LoggingSettingsPage>());
    });

    test('buildPages builds ManualLanguageSettingsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/manual-language'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<ManualLanguageSettingsPage>());
    });

    test('buildPages builds AboutPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/about'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<AboutPage>());
    });

    test('buildPages builds ConflictsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/conflicts'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<ConflictsPage>());
    });

    test('buildPages builds ConflictDetailRoute', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/conflicts/conflict-123'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'conflictId': 'conflict-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<ConflictsPage>());
      expect(pages[3].child, isA<ConflictDetailRoute>());
    });

    test('buildPages builds MaintenancePage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/maintenance'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<MaintenancePage>());
    });

    test('buildPages builds OnboardingMetricsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/advanced/onboarding_metrics'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(mockBuildContext, beamState);
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (pages[1].child as SettingsMobileBranchPage).branchId,
        'advanced',
      );
      expect(pages[2].child, isA<OnboardingMetricsPage>());
    });

    test('buildPages builds SoulEvolutionReviewPage for soul review', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents/souls/soul-789/review'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'soulId': 'soul-789'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
      expect(pages[2].child, isA<SoulEvolutionReviewPage>());
      final reviewPage = pages[2].child as SoulEvolutionReviewPage;
      expect(reviewPage.soulId, 'soul-789');
    });

    test('buildPages builds EvolutionReviewPage for template review', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/agents/templates/tmpl-123/review'),
      );
      final location = SettingsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      beamState = beamState.copyWith(
        pathParameters: {'templateId': 'tmpl-123'},
      );
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      // Settings + Agents + Template detail + Review
      expect(pages.length, 4);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      expect(pages[1].child, isA<AgentSettingsPage>());
      expect(pages[2].child, isA<AgentTemplateDetailPage>());
      expect(pages[3].child, isA<EvolutionReviewPage>());
      final reviewPage = pages[3].child as EvolutionReviewPage;
      expect(reviewPage.templateId, 'tmpl-123');
    });

    test('buildPages builds BackfillSettingsPage', () {
      final routeInformation = RouteInformation(
        uri: Uri.parse('/settings/sync/backfill'),
      );
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 3);
      expect(pages[0].child, isA<SettingsMobileRootPage>());
      final gate = pages[1].child;
      expect(gate, isA<SyncFeatureGate>());
      final hub = (gate as SyncFeatureGate).child;
      expect(hub, isA<SettingsMobileBranchPage>());
      expect((hub as SettingsMobileBranchPage).branchId, 'sync');
      expect(pages[2].child, isA<BackfillSettingsPage>());
    });

    group('sync hub keeps a stable page key across the drill-down', () {
      // The Sync Settings hub must carry the SAME ValueKey for the bare
      // `/settings/sync` URL and every `/settings/sync/*` leaf. A stable key
      // is what lets a back tap from a leaf (e.g. Backfill) pop cleanly to
      // reveal the existing hub beneath it. A key that flipped between the
      // base and leaf states (the old `settings-sync-base`) made Navigator
      // swap the underlying page instead of revealing it, playing the wrong
      // pop animation — the bug this guards against. Definitions/Advanced/AI
      // already follow this one-stable-key rule.
      const expectedHubKey = ValueKey('settings-sync');

      List<BeamPage> buildFor(String uri) {
        final routeInformation = RouteInformation(uri: Uri.parse(uri));
        final location = SettingsLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        return location.buildPages(mockBuildContext, beamState);
      }

      BeamPage hubPage(List<BeamPage> pages) =>
          pages.firstWhere((p) => p.child is SyncFeatureGate);

      test('bare /settings/sync uses the settings-sync key', () {
        expect(hubPage(buildFor('/settings/sync')).key, expectedHubKey);
      });

      for (final leaf in const [
        '/settings/sync/provisioned',
        '/settings/sync/matrix/maintenance',
        '/settings/sync/node-profile',
        '/settings/sync/backfill',
        '/settings/sync/stats',
        '/settings/sync/outbox',
      ]) {
        test('$leaf keeps the hub on the settings-sync key', () {
          expect(hubPage(buildFor(leaf)).key, expectedHubKey);
        });
      }

      test(
        'hub key is identical between the bare URL and a leaf so back pops '
        'cleanly instead of swapping the page',
        () {
          final baseKey = hubPage(buildFor('/settings/sync')).key;
          final leafKey = hubPage(buildFor('/settings/sync/backfill')).key;
          expect(baseKey, leafKey);
          expect(baseKey, expectedHubKey);
        },
      );
    });

    test('categories navigation stack has list page', () {
      final categoriesRoute = RouteInformation(
        uri: Uri.parse('/settings/categories/cat-id'),
      );
      final categoriesLocation = SettingsLocation(categoriesRoute);
      var categoriesState = BeamState.fromRouteInformation(categoriesRoute);
      categoriesState = categoriesState.copyWith(
        pathParameters: {'categoryId': 'cat-id'},
      );
      final categoriesPages = categoriesLocation.buildPages(
        mockBuildContext,
        categoriesState,
      );

      // Should have the list page in the stack
      // (4 pages: Root -> Definitions hub -> List -> Details).
      expect(categoriesPages.length, 4);
      expect(categoriesPages[1].child, isA<SettingsMobileBranchPage>());
      expect(
        (categoriesPages[1].child as SettingsMobileBranchPage).branchId,
        'definitions',
      );
      expect(categoriesPages[2].child, isA<CategoriesListPage>());
    });

    group('desktop mode', () {
      setUp(() {
        navService.isDesktopMode = true;
      });

      test('returns only SettingsRootPage for /settings', () {
        final routeInfo = RouteInformation(uri: Uri.parse('/settings'));
        final location = SettingsLocation(routeInfo);
        final beamState = BeamState.fromRouteInformation(routeInfo);
        final pages = location.buildPages(mockBuildContext, beamState);

        expect(pages.length, 1);
        expect(pages[0].child, isA<SettingsRootPage>());
      });

      test('sets desktopSelectedSettingsRoute to null for /settings', () {
        final routeInfo = RouteInformation(uri: Uri.parse('/settings'));
        final location = SettingsLocation(routeInfo);
        final beamState = BeamState.fromRouteInformation(routeInfo);
        location.buildPages(mockBuildContext, beamState);

        expect(navService.desktopSelectedSettingsRoute.value, isNull);
      });

      test('returns only SettingsRootPage for sub-routes', () {
        final routeInfo = RouteInformation(
          uri: Uri.parse('/settings/ai'),
        );
        final location = SettingsLocation(routeInfo);
        final beamState = BeamState.fromRouteInformation(routeInfo);
        final pages = location.buildPages(mockBuildContext, beamState);

        expect(pages.length, 1);
        expect(pages[0].child, isA<SettingsRootPage>());
      });

      test('sets route path for /settings/ai', () {
        final routeInfo = RouteInformation(
          uri: Uri.parse('/settings/ai'),
        );
        final location = SettingsLocation(routeInfo);
        final beamState = BeamState.fromRouteInformation(routeInfo);
        location.buildPages(mockBuildContext, beamState);

        final route = navService.desktopSelectedSettingsRoute.value;
        expect(route, isNotNull);
        expect(route!.path, '/settings/ai');
        expect(route.pathParameters, isEmpty);
      });

      test('sets route with path parameters for deep routes', () {
        final routeInfo = RouteInformation(
          uri: Uri.parse('/settings/categories/cat-42'),
        );
        final location = SettingsLocation(routeInfo);
        var beamState = BeamState.fromRouteInformation(routeInfo);
        beamState = beamState.copyWith(
          pathParameters: {'categoryId': 'cat-42'},
        );
        location.buildPages(mockBuildContext, beamState);

        final route = navService.desktopSelectedSettingsRoute.value;
        expect(route, isNotNull);
        expect(route!.path, '/settings/categories/cat-42');
        expect(route.pathParameters['categoryId'], 'cat-42');
      });

      test('sets route with query parameters', () {
        final routeInfo = RouteInformation(
          uri: Uri.parse('/settings/labels/create?name=test'),
        );
        final location = SettingsLocation(routeInfo);
        final beamState = BeamState.fromRouteInformation(routeInfo);
        location.buildPages(mockBuildContext, beamState);

        final route = navService.desktopSelectedSettingsRoute.value;
        expect(route, isNotNull);
        expect(route!.path, '/settings/labels/create');
        expect(route.queryParameters['name'], 'test');
      });

      test(
        'AI detail routes set the notifier with their path parameter and '
        'still push only the root page',
        () {
          const cases = <(String path, String paramKey, String paramValue)>[
            ('/settings/ai/provider/prov-1', 'providerId', 'prov-1'),
            ('/settings/ai/model/model-2', 'modelId', 'model-2'),
            ('/settings/ai/profile/profile-3', 'profileId', 'profile-3'),
          ];
          for (final (path, paramKey, paramValue) in cases) {
            final routeInfo = RouteInformation(uri: Uri.parse(path));
            final location = SettingsLocation(routeInfo);
            var beamState = BeamState.fromRouteInformation(routeInfo);
            beamState = beamState.copyWith(
              pathParameters: {paramKey: paramValue},
            );
            final pages = location.buildPages(mockBuildContext, beamState);

            // Desktop divergence: single root page + notifier update,
            // versus the 3-page stack the mobile branch builds.
            expect(pages, hasLength(1), reason: path);
            expect(pages[0].child, isA<SettingsRootPage>(), reason: path);

            final route = navService.desktopSelectedSettingsRoute.value;
            expect(route, isNotNull, reason: path);
            expect(route!.path, path, reason: path);
            expect(route.pathParameters[paramKey], paramValue, reason: path);
          }
        },
      );

      test('does not push sub-pages on desktop', () {
        for (final path in [
          '/settings/flags',
          '/settings/theming',
          '/settings/advanced',
          '/settings/advanced/logging_domains',
        ]) {
          final routeInfo = RouteInformation(uri: Uri.parse(path));
          final location = SettingsLocation(routeInfo);
          final beamState = BeamState.fromRouteInformation(routeInfo);
          final pages = location.buildPages(mockBuildContext, beamState);

          expect(
            pages.length,
            1,
            reason: '$path should only produce 1 page on desktop',
          );
          expect(pages[0].child, isA<SettingsRootPage>());
        }
      });
    });
  });
}

/// The production [SettingsLocation] with every page's *child* replaced by a
/// cheap placeholder.
///
/// Beamer's pop machinery only reads a page's routing metadata — the key and
/// `popToNamed` — so keeping those verbatim from the real location is enough
/// to exercise back navigation faithfully, while dropping the children lets
/// the stack mount without the AI settings dependency graph (Riverpod
/// controllers, `SettingsDb`, design tokens) behind it.
class _RoutingOnlySettingsLocation extends SettingsLocation {
  _RoutingOnlySettingsLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return super.buildPages(context, state).map((page) {
      return BeamPage(
        key: page.key,
        title: page.title,
        popToNamed: page.popToNamed,
        child: const SizedBox.shrink(),
      );
    }).toList();
  }
}

/// Records which page keys the [Navigator] pushed and which it got rid of.
///
/// Distinguishing "the list was removed" from "the list was removed and an
/// identical one pushed in its place" is the whole point: the second is the
/// wrong-transition bug, and it is invisible to a URL assertion because both
/// end up on `/settings/ai`.
class _RouteRecordingObserver extends NavigatorObserver {
  final List<Object?> pushedKeys = [];

  /// Keys of routes that left the stack, whether they animated out (`didPop`)
  /// or were dropped outright (`didRemove`) — which of the two the transition
  /// delegate picks is not what these tests are pinning down.
  final List<Object?> goneKeys = [];

  void reset() {
    pushedKeys.clear();
    goneKeys.clear();
  }

  Object? _keyOf(Route<dynamic> route) {
    final settings = route.settings;
    return settings is Page ? settings.key : null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedKeys.add(_keyOf(route));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    goneKeys.add(_keyOf(route));
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    goneKeys.add(_keyOf(route));
  }
}
