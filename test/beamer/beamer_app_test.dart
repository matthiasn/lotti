import 'dart:async';
import 'dart:io' show Platform;

import 'package:beamer/beamer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/beamer/locations/goals_location.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/beamer/locations/projects_location.dart';
import 'package:lotti/beamer/locations/relationships_location.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/sidebar_wake_queue.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_sidebar_entry.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_view_side_panel.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/sidebar_calendar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/lockdown/state/lockdown_category_options.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_dock.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/profiles/service/profile_switch_chrome.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/outbox/sync_queue_counts.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/desktop/sidebar_saved_task_filters.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/contact_support_row.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/sidebar_activity_summary.dart';
import 'package:lotti/widgets/misc/sidebar_audio_recording_section.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/misc/zoom_wrapper.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart' hide Profile;
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../helpers/stub_audio_recorder_controller.dart';
import '../mocks/mocks.dart';
import '../mocks/sync_config_test_mocks.dart';
import '../widget_test_utils.dart';
import '_beamer_test_utils.dart';

bool _isFlatpakTestHost() {
  return Platform.isLinux &&
      ((Platform.environment['FLATPAK_ID']?.isNotEmpty ?? false) ||
          Platform.environment.containsKey('FLATPAK_SANDBOX') ||
          (Platform.environment['XDG_RUNTIME_DIR']?.contains('flatpak') ??
              false));
}

const _phoneViewportSize = Size(390, 844);
const _desktopViewportSize = Size(1280, 800);

void _useViewport(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Maps the flag combination to the destinations count and delegates to the
/// PRODUCTION clamp (`clampNavigationIndex`) — previously this was a local
/// re-implementation that tested itself.
int calculateClampedIndex({
  required int rawIndex,
  required bool isProjectsEnabled,
  required bool isCalendarEnabled,
  required bool isHabitsEnabled,
  required bool isDashboardsEnabled,
}) {
  final navItems = [
    true, // Tasks
    isProjectsEnabled, // Projects
    isCalendarEnabled, // Daily OS
    isHabitsEnabled, // Habits
    isDashboardsEnabled, // Dashboards
    true, // Journal
    true, // Settings
  ];
  final itemCount = navItems.where((isEnabled) => isEnabled).length;
  return clampNavigationIndex(rawIndex: rawIndex, itemCount: itemCount);
}

class _LoadingThemingController extends ThemingController {
  @override
  ThemingState build() => const ThemingState();
}

class _AppScreenLocation extends BeamLocation<BeamState> {
  _AppScreenLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return const [
      BeamPage(
        key: ValueKey('app-screen'),
        child: AppScreen(),
      ),
    ];
  }

  @override
  List<Pattern> get pathPatterns => ['/'];
}

/// A [SettingsLocation] whose pages are inert stubs: route matching (and
/// therefore [settingsRouteHidesBottomNav]) behaves exactly like
/// production, but no real settings page — with its getIt dependency
/// fan-out — is ever built.
class _TestSettingsLocation extends SettingsLocation {
  _TestSettingsLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      BeamPage(
        key: ValueKey('test-settings-${state.uri.path}'),
        child: const SizedBox.shrink(),
      ),
    ];
  }
}

/// A [ProjectsLocation] whose pages are inert stubs: route matching (and
/// therefore [projectsRouteHidesBottomNav]) behaves exactly like production,
/// but neither the real list page nor the detail page — with their provider
/// and getIt dependency fan-out — is ever built.
class _TestProjectsLocation extends ProjectsLocation {
  _TestProjectsLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      BeamPage(
        key: ValueKey('test-projects-${state.uri.path}'),
        child: const SizedBox.shrink(),
      ),
    ];
  }
}

/// A [RelationshipsLocation] whose pages are inert stubs: route matching (and
/// therefore [peopleRouteHidesBottomNav]) behaves exactly like production,
/// but none of the People pages — with their provider and getIt dependency
/// fan-out — is ever built.
class _TestRelationshipsLocation extends RelationshipsLocation {
  _TestRelationshipsLocation(super.routeInformation);

  /// Mirrors production's *stack* — list, then detail, then chat — with inert
  /// children. The shape matters: the back arrow pops a page rather than
  /// beaming, so a single-page stub could not exercise that path at all.
  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final relationshipId = state.pathParameters['relationshipId'];
    return [
      const BeamPage(
        key: ValueKey('test-people'),
        child: SizedBox.shrink(),
      ),
      if (relationshipId != null)
        BeamPage(
          key: ValueKey('test-people-details-$relationshipId'),
          child: const SizedBox.shrink(),
        ),
      if (relationshipId != null &&
          state.uri.pathSegments.length == 3 &&
          state.uri.pathSegments[2] == 'chat')
        BeamPage(
          key: ValueKey('test-people-chat-$relationshipId'),
          child: const SizedBox.shrink(),
        ),
    ];
  }
}

/// A [GoalsLocation] whose pages are inert stubs: route matching (and
/// therefore [goalsRouteHidesBottomNav]) behaves exactly like production,
/// but none of the goal pages — with their provider and getIt dependency
/// fan-out — is ever built.
class _TestGoalsLocation extends GoalsLocation {
  _TestGoalsLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      BeamPage(
        key: ValueKey('test-goals-${state.uri.path}'),
        child: const SizedBox.shrink(),
      ),
    ];
  }
}

/// A [HabitsLocation] whose pages are inert stubs: route matching (and
/// therefore [habitsRouteHidesBottomNav]) behaves exactly like production,
/// without building the habits dashboard or editor dependency trees.
class _TestHabitsLocation extends HabitsLocation {
  _TestHabitsLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      BeamPage(
        key: ValueKey('test-habits-${state.uri.path}'),
        child: const SizedBox.shrink(),
      ),
    ];
  }
}

Future<BeamerDelegate> _createEmptyDelegate(String initialPath) async {
  final delegate = BeamerDelegate(
    setBrowserTabTitle: false,
    initialPath: initialPath,
    locationBuilder: (routeInformation, _) =>
        EmptyTestLocation(routeInformation),
  );
  await delegate.setNewRoutePath(
    RouteInformation(uri: Uri.parse(initialPath)),
  );
  return delegate;
}

bool _eventsDisabledByDefault() => false;

Future<void> _stubNavService(
  MockNavService navService, {
  required Stream<int> indexStream,
  required bool Function() isProjectsEnabled,
  required bool Function() isDailyOsEnabled,
  required bool Function() isHabitsEnabled,
  required bool Function() isDashboardsEnabled,
  bool Function() isEventsEnabled = _eventsDisabledByDefault,
  bool? isUnifiedGoalsEnabled,
  BeamerDelegate? settingsDelegate,
  BeamerDelegate? projectsDelegate,
  BeamerDelegate? goalsDelegate,
  BeamerDelegate? habitsDelegate,
  BeamerDelegate? relationshipsDelegate,
}) async {
  final tasksDelegate = await _createEmptyDelegate('/tasks');
  projectsDelegate ??= await _createEmptyDelegate('/projects');
  relationshipsDelegate ??= await _createEmptyDelegate('/people');
  final calendarDelegate = await _createEmptyDelegate('/calendar');
  habitsDelegate ??= await _createEmptyDelegate('/habits');
  final dashboardsDelegate = await _createEmptyDelegate('/dashboards');
  final journalDelegate = await _createEmptyDelegate('/journal');
  final eventsDelegate = await _createEmptyDelegate('/events');
  // AppScreen listens to the goals delegate too, so the bottom bar can
  // slide away on the unified Goals tab's hosted goal pages.
  goalsDelegate ??= await _createEmptyDelegate('/goals');
  settingsDelegate ??= await _createEmptyDelegate('/settings');

  // Real NavService.getIndexStream returns a broadcast stream (multiple
  // listeners — e.g. AppScreen + SidebarTimerSection — subscribe). Wrap
  // the test-supplied stream so single-subscription inputs like
  // Stream.value still satisfy multi-listener consumers.
  final broadcastIndex = indexStream.isBroadcast
      ? indexStream
      : indexStream.asBroadcastStream();
  when(() => navService.getIndexStream()).thenAnswer((_) => broadcastIndex);
  when(() => navService.tasksDelegate).thenReturn(tasksDelegate);
  when(() => navService.projectsDelegate).thenReturn(projectsDelegate);
  when(() => navService.calendarDelegate).thenReturn(calendarDelegate);
  when(() => navService.habitsDelegate).thenReturn(habitsDelegate);
  when(() => navService.dashboardsDelegate).thenReturn(dashboardsDelegate);
  when(() => navService.journalDelegate).thenReturn(journalDelegate);
  when(() => navService.settingsDelegate).thenReturn(settingsDelegate);
  when(() => navService.goalsDelegate).thenReturn(goalsDelegate);
  when(
    () => navService.relationshipsDelegate,
  ).thenReturn(relationshipsDelegate);
  // `isUnifiedGoalsPageEnabled` is a concrete member on MockNavService, so it
  // is flipped through the field rather than stubbed with `when()`. Left
  // alone unless the caller asks, so a test that set it before stubbing
  // keeps it.
  if (isUnifiedGoalsEnabled != null) {
    navService.unifiedGoalsPageEnabled = isUnifiedGoalsEnabled;
  }
  when(() => navService.isProjectsPageEnabled).thenAnswer(
    (_) => isProjectsEnabled(),
  );
  when(() => navService.isDailyOsPageEnabled).thenAnswer(
    (_) => isDailyOsEnabled(),
  );
  when(() => navService.isHabitsPageEnabled).thenAnswer(
    (_) => isHabitsEnabled(),
  );
  when(() => navService.isDashboardsPageEnabled).thenAnswer(
    (_) => isDashboardsEnabled(),
  );
  when(() => navService.eventsDelegate).thenReturn(eventsDelegate);
  when(
    () => navService.isEventsPageEnabled,
  ).thenAnswer((_) => isEventsEnabled());
  when(() => navService.tapIndex(any())).thenReturn(null);
  // Daily OS lives at the calendar index; the onboarding arm reads both to
  // decide whether to switch tabs. Same value → already on the tab, no tap.
  when(() => navService.calendarIndex).thenReturn(1);
  when(() => navService.index).thenReturn(1);
  when(() => navService.isDesktopMode).thenReturn(false);
  // The desktop tasks pane (`tasks_tab_page.dart`) reads
  // `desktopSelectedTaskId` for its detail selection; stub it with an
  // empty selection so the pane builds. (The sidebar running-timer card
  // no longer reads it — it stays visible whenever a timer runs.)
  when(
    () => navService.desktopSelectedTaskId,
  ).thenReturn(ValueNotifier<String?>(null));
  // The Time Analysis and AI Impact sidebar sub-entries read these for their
  // active-route highlights.
  when(
    () => navService.desktopShowTimeAnalysis,
  ).thenReturn(ValueNotifier<bool>(false));
  when(
    () => navService.desktopShowAiImpact,
  ).thenReturn(ValueNotifier<bool>(false));
  when(() => navService.currentPath).thenReturn('/');
}

Future<void> _pumpAppScreen(
  WidgetTester tester, {
  required MockNavService navService,
  MockJournalDb? journalDb,
  Size viewportSize = _phoneViewportSize,
  AudioRecorderState? audioRecorderState,
  List<Override> extraOverrides = const [],
}) async {
  _useViewport(tester, viewportSize);

  final effectiveJournalDb = journalDb ?? MockJournalDb();
  final mockMatrix = MockMatrixService();
  when(
    mockMatrix.getIncomingKeyVerificationStream,
  ).thenAnswer((_) => const Stream<KeyVerification>.empty());
  when(
    () => mockMatrix.incomingKeyVerificationRunnerStream,
  ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

  final mockOutboxService = MockOutboxService();
  when(
    () => mockOutboxService.notLoggedInGateStream,
  ).thenAnswer((_) => const Stream<void>.empty());

  final routerDelegate = BeamerDelegate(
    setBrowserTabTitle: false,
    locationBuilder: (routeInformation, _) =>
        _AppScreenLocation(routeInformation),
  );
  addTearDown(routerDelegate.dispose);
  await routerDelegate.setNewRoutePath(
    RouteInformation(uri: Uri.parse('/')),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrix),
        loginStateStreamProvider.overrideWith(
          (ref) => Stream<LoginState>.value(LoginState.loggedIn),
        ),
        outboxServiceProvider.overrideWithValue(mockOutboxService),
        journalDbProvider.overrideWithValue(effectiveJournalDb),
        audioRecorderControllerProvider.overrideWith(
          () => StubAudioRecorderController(
            audioRecorderState ??
                AudioRecorderState(
                  status: AudioRecorderStatus.stopped,
                  progress: Duration.zero,
                  vu: -20,
                  dBFS: -160,
                  showIndicator: false,
                  modalVisible: false,
                ),
          ),
        ),
        shouldAutoShowWhatsNewProvider.overrideWith((ref) async => false),
        // FTUE welcome gate is off (matches the flag stub above), but pin it
        // explicitly rather than relying on the flag short-circuit alone.
        shouldAutoShowOnboardingProvider.overrideWith((ref) async => false),
        // Daily OS onboarding gate off too, pinned so its real provider (which
        // reads unstubbed config flags) never fires in the default harness.
        shouldAutoShowDailyOsOnboardingProvider.overrideWith(
          (ref) async => false,
        ),
        // Saved-filter surfaces watch these providers.
        // Override them with safe defaults so this test doesn't transitively
        // trigger the real JournalPageController build chain.
        savedTaskFiltersControllerProvider.overrideWith(
          () => _StubSavedTaskFiltersController(const []),
        ),
        currentSavedTaskFilterIdProvider.overrideWith((ref) => null),
        tasksFilterHasUnsavedClausesProvider.overrideWith((ref) => false),
        ...extraOverrides,
      ],
      child: MaterialApp.router(
        theme: withOverrides(ThemeData.dark(useMaterial3: true)),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerDelegate: routerDelegate,
        routeInformationParser: BeamerParser(),
        backButtonDispatcher: BeamerBackButtonDispatcher(
          delegate: routerDelegate,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Variant of [_pumpAppScreen] that allows the caller to supply custom
/// implementations for providers that [_pumpAppScreen] always overrides.
/// This avoids the "override twice within the same container" Riverpod error.
Future<void> _pumpAppScreenCustomProviders(
  WidgetTester tester, {
  required MockNavService navService,
  Size viewportSize = _phoneViewportSize,
  Future<bool> Function(Ref)? shouldAutoShowWhatsNew,
  Future<bool> Function(Ref)? shouldAutoShowOnboarding,
  Future<bool> Function(Ref)? shouldAutoShowDailyOsOnboarding,
  OnboardingWelcomeCadence Function()? onboardingWelcomeCadenceOverride,
  DailyOsOnboardingCadence Function()? dailyOsOnboardingCadenceOverride,
  WhatsNewController Function()? whatsNewOverride,
  List<Override> extraOverrides = const [],
}) async {
  _useViewport(tester, viewportSize);

  final mockMatrix = MockMatrixService();
  when(
    mockMatrix.getIncomingKeyVerificationStream,
  ).thenAnswer((_) => const Stream<KeyVerification>.empty());
  when(
    () => mockMatrix.incomingKeyVerificationRunnerStream,
  ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

  final mockOutboxService = MockOutboxService();
  when(
    () => mockOutboxService.notLoggedInGateStream,
  ).thenAnswer((_) => const Stream<void>.empty());

  final routerDelegate = BeamerDelegate(
    setBrowserTabTitle: false,
    locationBuilder: (routeInformation, _) =>
        _AppScreenLocation(routeInformation),
  );
  addTearDown(routerDelegate.dispose);
  await routerDelegate.setNewRoutePath(
    RouteInformation(uri: Uri.parse('/')),
  );

  final mockJournalDb = MockJournalDb();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrix),
        loginStateStreamProvider.overrideWith(
          (ref) => Stream<LoginState>.value(LoginState.loggedIn),
        ),
        outboxServiceProvider.overrideWithValue(mockOutboxService),
        journalDbProvider.overrideWithValue(mockJournalDb),
        audioRecorderControllerProvider.overrideWith(
          () => StubAudioRecorderController(
            AudioRecorderState(
              status: AudioRecorderStatus.stopped,
              progress: Duration.zero,
              vu: -20,
              dBFS: -160,
              showIndicator: false,
              modalVisible: false,
            ),
          ),
        ),
        shouldAutoShowWhatsNewProvider.overrideWith(
          shouldAutoShowWhatsNew ?? (ref) async => false,
        ),
        shouldAutoShowOnboardingProvider.overrideWith(
          shouldAutoShowOnboarding ?? (ref) async => false,
        ),
        shouldAutoShowDailyOsOnboardingProvider.overrideWith(
          shouldAutoShowDailyOsOnboarding ?? (ref) async => false,
        ),
        if (onboardingWelcomeCadenceOverride != null)
          onboardingWelcomeCadenceProvider.overrideWith(
            onboardingWelcomeCadenceOverride,
          ),
        if (dailyOsOnboardingCadenceOverride != null)
          dailyOsOnboardingCadenceProvider.overrideWith(
            dailyOsOnboardingCadenceOverride,
          ),
        if (whatsNewOverride != null)
          whatsNewControllerProvider.overrideWith(whatsNewOverride),
        savedTaskFiltersControllerProvider.overrideWith(
          () => _StubSavedTaskFiltersController(const []),
        ),
        currentSavedTaskFilterIdProvider.overrideWith((ref) => null),
        tasksFilterHasUnsavedClausesProvider.overrideWith((ref) => false),
        ...extraOverrides,
      ],
      child: MaterialApp.router(
        theme: withOverrides(ThemeData.dark(useMaterial3: true)),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerDelegate: routerDelegate,
        routeInformationParser: BeamerParser(),
        backButtonDispatcher: BeamerBackButtonDispatcher(
          delegate: routerDelegate,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _registerAppScreenGetIt(
  MockNavService navService, {
  JournalEntity? runningTimer,
  NavService? registeredNavService,
}) async {
  final mockTimeService = MockTimeService();
  if (runningTimer != null) {
    when(
      mockTimeService.getStream,
    ).thenAnswer((_) => Stream<JournalEntity?>.value(runningTimer));
    when(mockTimeService.getCurrent).thenReturn(runningTimer);
  } else {
    when(mockTimeService.getStream).thenAnswer(_emptyTimeStream);
    // SidebarTimerSection seeds its StreamBuilder with getCurrent() so it
    // doesn't flicker on first frame when a timer is already running.
    when(mockTimeService.getCurrent).thenReturn(null);
  }

  await setUpTestGetIt(
    additionalSetup: () {
      getIt
        ..registerSingleton<NavService>(registeredNavService ?? navService)
        ..registerSingleton<SyncDatabase>(mockSyncDatabaseWithCount(0))
        ..registerSingleton<TimeService>(mockTimeService);
    },
  );
}

Future<void> _pumpReadyMyBeamerApp(
  WidgetTester tester, {
  required MyBeamerApp app,
}) async {
  final mockMatrix = MockMatrixService();
  when(
    mockMatrix.getIncomingKeyVerificationStream,
  ).thenAnswer((_) => const Stream<KeyVerification>.empty());
  when(
    () => mockMatrix.incomingKeyVerificationRunnerStream,
  ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

  final mockOutboxService = MockOutboxService();
  when(
    () => mockOutboxService.notLoggedInGateStream,
  ).thenAnswer((_) => const Stream<void>.empty());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themingControllerProvider.overrideWith(ReadyThemingController.new),
        manualLanguageControllerProvider.overrideWith(
          _FollowSystemManualLanguageController.new,
        ),
        enableTooltipsProvider.overrideWith((ref) => Stream.value(true)),
        zoomControllerProvider.overrideWith(TestZoomController.new),
        agentInitializationProvider.overrideWith((ref) async {}),
        dayProcessingRuntimeProvider.overrideWithValue(
          MockDayProcessingRuntime(),
        ),
        matrixServiceProvider.overrideWithValue(mockMatrix),
        loginStateStreamProvider.overrideWith(
          (ref) => Stream.value(LoginState.loggedIn),
        ),
        outboxServiceProvider.overrideWithValue(mockOutboxService),
        audioRecorderControllerProvider.overrideWith(
          () => StubAudioRecorderController(
            AudioRecorderState(
              status: AudioRecorderStatus.stopped,
              progress: Duration.zero,
              vu: -20,
              dBFS: -160,
              showIndicator: false,
              modalVisible: false,
            ),
          ),
        ),
        shouldAutoShowWhatsNewProvider.overrideWith((ref) async => false),
        shouldAutoShowOnboardingProvider.overrideWith((ref) async => false),
        savedTaskFiltersControllerProvider.overrideWith(
          () => _StubSavedTaskFiltersController(const []),
        ),
        currentSavedTaskFilterIdProvider.overrideWith((ref) => null),
        tasksFilterHasUnsavedClausesProvider.overrideWith((ref) => false),
      ],
      child: app,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Stream<JournalEntity?> _emptyTimeStream(Invocation _) =>
    const Stream<JournalEntity?>.empty();

void main() {
  setUpAll(() {
    // The AI provider FTUE path stubs AiConfigRepository.getConfigsByType,
    // whose argument is an AiConfigType — mocktail needs a fallback for `any()`.
    registerFallbackValue(AiConfigType.inferenceProvider);
    registerFallbackValue(FakeLaunchOptions());
    // The lockdown guard is set and reset by delegate.
    registerFallbackValue(<BeamerDelegate>{});
    registerFallbackValue(
      BeamerDelegate(locationBuilder: (_, _) => NotFound()),
    );
  });

  group('Navigation Index Clamping Logic Tests', () {
    test('clamps index when optional tabs are disabled and index is high', () {
      final clampedIndex = calculateClampedIndex(
        rawIndex: 6,
        isProjectsEnabled: false,
        isCalendarEnabled: false,
        isHabitsEnabled: false,
        isDashboardsEnabled: false,
      );

      expect(clampedIndex, 2);
    });

    test('does not clamp index when within bounds', () {
      final clampedIndex = calculateClampedIndex(
        rawIndex: 4,
        isProjectsEnabled: true,
        isCalendarEnabled: true,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );

      expect(clampedIndex, 4);
    });

    test('clamps index when projects and calendar are toggled off', () {
      final clampedIndex = calculateClampedIndex(
        rawIndex: 6,
        isProjectsEnabled: false,
        isCalendarEnabled: false,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );

      expect(clampedIndex, 4);
    });

    test('handles zero index correctly', () {
      final clampedIndex = calculateClampedIndex(
        rawIndex: 0,
        isProjectsEnabled: false,
        isCalendarEnabled: false,
        isHabitsEnabled: false,
        isDashboardsEnabled: false,
      );

      expect(clampedIndex, 0);
    });

    test('clamp invariants hold over the full rawIndex x itemCount space', () {
      for (var itemCount = 1; itemCount <= 7; itemCount++) {
        for (var rawIndex = -3; rawIndex <= 10; rawIndex++) {
          final result = clampNavigationIndex(
            rawIndex: rawIndex,
            itemCount: itemCount,
          );
          final reason = 'rawIndex=$rawIndex itemCount=$itemCount';
          expect(result, greaterThanOrEqualTo(0), reason: reason);
          expect(result, lessThanOrEqualTo(itemCount - 1), reason: reason);
          if (rawIndex >= 0 && rawIndex <= itemCount - 1) {
            expect(result, rawIndex, reason: '$reason (identity in range)');
          }
        }
      }
    });

    test('clamps negative index to zero', () {
      final clampedIndex = calculateClampedIndex(
        rawIndex: -1,
        isProjectsEnabled: true,
        isCalendarEnabled: true,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );

      expect(clampedIndex, 0);
    });
  });

  group('MyBeamerApp loading shell', () {
    testWidgets('renders loading shell while themes are unresolved', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      when(() => mockNavService.currentPath).thenReturn('/');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themingControllerProvider.overrideWith(
              _LoadingThemingController.new,
            ),
            enableTooltipsProvider.overrideWith(
              (ref) => Stream<bool>.value(true),
            ),
            dayProcessingRuntimeProvider.overrideWithValue(
              MockDayProcessingRuntime(),
            ),
            agentInitializationProvider.overrideWith((ref) async {}),
          ],
          child: MyBeamerApp(navService: mockNavService),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The loading shell holds the colour carried across the profile
      // switch and mounts NO MaterialApp/Scaffold — either would fall back
      // to Flutter's default light theme and strobe the switch white.
      expect(find.byType(MaterialApp), findsNothing);
      expect(find.byType(Scaffold), findsNothing);
      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
        ProfileSwitchChrome.instance.background,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('AppScreen projects gating', () {
    testWidgets('hides Projects on the first frame when disabled', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => false,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
      );

      expect(find.text('Projects'), findsNothing);
      expect(find.text('Tasks'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('the flag-gated unified Goals destination appears in the '
        'desktop sidebar when enabled', (tester) async {
      final mockNavService = MockNavService()..unifiedGoalsPageEnabled = true;
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => false,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      final goalsDelegate = await _createEmptyDelegate('/goals');
      when(() => mockNavService.goalsDelegate).thenReturn(goalsDelegate);
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == LottiIcons.focus || w.icon == LottiIcons.focus),
        ),
        findsWidgets,
      );
      // The goals tab is mounted but not active, so its Beamer child sits
      // offstage in the shell's IndexedStack.
      expect(
        find.byWidgetPredicate(
          (w) => w is Beamer && w.routerDelegate == goalsDelegate,
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('the flag-gated People destination appears in the desktop '
        'sidebar when enabled, and not otherwise', (tester) async {
      final mockNavService = MockNavService()..relationshipsPageEnabled = true;
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => false,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      final relationshipsDelegate = await _createEmptyDelegate('/people');
      when(
        () => mockNavService.relationshipsDelegate,
      ).thenReturn(relationshipsDelegate);
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      final peopleGlyph = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == LottiIcons.people || w.icon == LottiIcons.people),
      );
      expect(peopleGlyph, findsWidgets);
      // Mounted but not active, so its Beamer child sits offstage in the
      // shell's IndexedStack.
      expect(
        find.byWidgetPredicate(
          (w) => w is Beamer && w.routerDelegate == relationshipsDelegate,
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      // Turning the flag off removes both the destination and its Beamer.
      mockNavService.relationshipsPageEnabled = false;
      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      expect(peopleGlyph, findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Beamer && w.routerDelegate == relationshipsDelegate,
          skipOffstage: false,
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'routes Projects into the More sheet after a flag-driven nav update',
      (tester) async {
        final mockNavService = MockNavService();
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        var isProjectsEnabled = false;
        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          isProjectsEnabled: () => isProjectsEnabled,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
        );
        expect(find.text('Projects'), findsNothing);

        isProjectsEnabled = true;
        indexController.add(0);
        await tester.pump();
        await tester.pump();

        // Projects never claims a bar slot — it appears in the More sheet.
        expect(find.text('Projects'), findsNothing);
        final navBar = tester.widget<DesignSystemBottomNavigationBar>(
          find.byType(DesignSystemBottomNavigationBar),
        );
        expect(navBar.items.last.label, 'More');
        navBar.items.last.onTap?.call();
        await tester.pumpAndSettle();

        expect(find.text('Projects'), findsOneWidget);

        // Sheet rows use the desktop-style trailing slot for the Settings
        // outbox count instead of cramming the badge over the gear icon.
        expect(find.byType(SyncQueueCounts), findsOneWidget);
        expect(find.byType(OutboxBadgeIcon), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'More sheet row tapped after its flag was disabled closes the sheet '
      'without routing',
      (tester) async {
        final mockNavService = MockNavService();
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        var isProjectsEnabled = true;
        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          // All flags on: seven destinations cannot fit the phone-width
          // viewport, so the bar keeps the More overflow this test needs.
          isProjectsEnabled: () => isProjectsEnabled,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        // Open the More sheet while Projects is still enabled.
        final navBar = tester.widget<DesignSystemBottomNavigationBar>(
          find.byType(DesignSystemBottomNavigationBar),
        );
        navBar.items.last.onTap?.call();
        await tester.pumpAndSettle();
        expect(find.text('Projects'), findsOneWidget);

        // The flag flips (e.g. synced from another device) while the sheet
        // is open. The row is still visible, but its tap-time index
        // resolution now returns null: the sheet closes and the tap is
        // dropped instead of routing through a stale index.
        isProjectsEnabled = false;
        await tester.tap(find.text('Projects'));
        await tester.pumpAndSettle();

        expect(find.text('Projects'), findsNothing);
        verifyNever(() => mockNavService.tapIndex(any()));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen relationships gating', () {
    testWidgets('surfaces the People tab when the flag is enabled', (
      tester,
    ) async {
      final mockNavService = MockNavService()..relationshipsPageEnabled = true;
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => false,
        isDailyOsEnabled: () => false,
        isHabitsEnabled: () => false,
        isDashboardsEnabled: () => false,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(tester, navService: mockNavService);

      expect(find.text('People'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('AppScreen events gating', () {
    testWidgets('surfaces Events in the More sheet when the flag is enabled', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        // All optional tabs on so the phone bar keeps the More overflow that
        // holds the non-primary Events destination.
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
        isEventsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(tester, navService: mockNavService);

      // Events never claims a primary bar slot — it appears in the More sheet.
      expect(find.text('Events'), findsNothing);
      final navBar = tester.widget<DesignSystemBottomNavigationBar>(
        find.byType(DesignSystemBottomNavigationBar),
      );
      expect(navBar.items.last.label, 'More');
      navBar.items.last.onTap?.call();
      await tester.pumpAndSettle();

      expect(find.text('Events'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('keeps Events hidden when the flag is disabled', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(tester, navService: mockNavService);

      final navBar = tester.widget<DesignSystemBottomNavigationBar>(
        find.byType(DesignSystemBottomNavigationBar),
      );
      navBar.items.last.onTap?.call();
      await tester.pumpAndSettle();

      expect(find.text('Events'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('Flatpak audio indicator gating', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
      debugIsRunningInFlatpakOverride = null;
    });

    Future<void> pumpMobileShell(WidgetTester tester) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => false,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);
      await _pumpAppScreen(tester, navService: mockNavService);
    }

    testWidgets(
      'omits the AudioRecordingIndicator from the mobile overlay when '
      'running inside the Flatpak sandbox',
      (tester) async {
        debugIsRunningInFlatpakOverride = true;
        await pumpMobileShell(tester);

        expect(find.byType(AudioRecordingIndicator), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'mounts the AudioRecordingIndicator outside the Flatpak sandbox',
      (tester) async {
        debugIsRunningInFlatpakOverride = false;
        await pumpMobileShell(tester);

        expect(find.byType(AudioRecordingIndicator), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen bottom navigation style', () {
    // Pin a mobile-width surface so AppScreen takes the mobile-shell branch
    // regardless of any view-size leakage from earlier tests in a bundled
    // `very_good test` run. Without this, a contaminated view ≥960 px wide
    // routes AppScreen into the desktop layout, which mounts the desktop
    // tasks pane (`tasks_tab_page.dart`) and trips on the unstubbed
    // `MockNavService.desktopSelectedTaskId` getter.
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    });

    // With every flag enabled the full index space is 0 Tasks, 1 DailyOS,
    // 2 Projects, 3 Habits, 4 Dashboards, 5 Journal, 6 Settings. Tasks,
    // DailyOS, and Journal hold the bar slots; Projects, Habits,
    // Dashboards, and Settings live behind the More slot, which takes
    // their name and the active tint while one of them is on screen.
    for (final (index, name, moreLabel) in <(int, String, String)>[
      (0, 'tasks', 'More'),
      (1, 'dailyOS', 'More'),
      (2, 'projects', 'Projects'),
      (3, 'habits', 'Habits'),
      (4, 'dashboards', 'Insights'),
      (5, 'journal', 'More'),
      (6, 'settings', 'Settings'),
    ]) {
      testWidgets('uses design-system nav on the $name tab', (tester) async {
        final mockNavService = MockNavService();

        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(index),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
        );

        expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
        expect(find.byType(DesignSystemFiveSlotNavBar), findsOneWidget);

        // The bar is capped at the three primary destinations plus More
        // on the right — regardless of how many flag-gated destinations
        // are enabled.
        final navBar = tester.widget<DesignSystemBottomNavigationBar>(
          find.byType(DesignSystemBottomNavigationBar),
        );
        expect(navBar.items, hasLength(4));
        expect(
          navBar.items.map((item) => item.label),
          ['Tasks', 'DailyOS', 'Logbook', moreLabel],
        );
        // The More slot lights up exactly while an overflow destination is
        // the active route. Its accessible name keeps the More affordance
        // alongside the destination name — activating the slot opens the
        // sheet, not the destination, and that must stay discoverable.
        final isOverflowActive = (index >= 2 && index <= 4) || index == 6;
        expect(navBar.items.last.active, isOverflowActive);
        expect(
          navBar.items.last.semanticsLabel,
          isOverflowActive
              ? '$moreLabel — More, 4 additional destinations'
              : 'More, 4 additional destinations',
        );

        // Docked with zero gap: the bar's surface is flush with the
        // screen's bottom edge and spans the full width.
        final barRect = tester.getRect(
          find.byType(DesignSystemFiveSlotNavBar),
        );
        final screenSize =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(barRect.bottom, screenSize.height);
        expect(barRect.left, 0);
        expect(barRect.right, screenSize.width);
      });
    }

    testWidgets(
      'gives every destination its own slot on wide windows — no More slot',
      (tester) async {
        final mockNavService = MockNavService();

        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(6),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          // Wide mobile window: at/above kNavBarAllDestinationsBreakpoint
          // but below the desktop breakpoint, so the bottom bar (not the
          // sidebar) renders — with one slot per destination.
          viewportSize: const Size(800, 1200),
        );

        final navBar = tester.widget<DesignSystemBottomNavigationBar>(
          find.byType(DesignSystemBottomNavigationBar),
        );
        expect(
          navBar.items.map((item) => item.label),
          [
            'Tasks',
            'DailyOS',
            'Projects',
            'Habits',
            'Insights',
            'Logbook',
            'Settings',
          ],
        );

        // Settings — overflow-only on compact windows — owns a regular
        // slot here: active tint on its own slot, no More semantics.
        expect(navBar.items.last.active, isTrue);
        expect(navBar.items.last.semanticsLabel, isNull);

        // Taps route directly through the destination's full index
        // instead of opening a sheet.
        navBar.items[2].onTap?.call();
        verify(() => mockNavService.tapIndex(2)).called(1);
      },
    );

    testWidgets(
      'promotes overflow destinations one by one as window width allows',
      (tester) async {
        final mockNavService = MockNavService();

        await _stubNavService(
          mockNavService,
          // Projects is the active route AND the promoted destination —
          // its own slot must light up while More stays plain.
          indexStream: Stream.value(2),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          // Intermediate band: wider than the phone base line-up, too
          // narrow for all seven destinations. Exactly one overflow
          // destination (Projects, first in nav order) fits alongside
          // the base slots and More.
          viewportSize: const Size(520, 1200),
        );

        final navBar = tester.widget<DesignSystemBottomNavigationBar>(
          find.byType(DesignSystemBottomNavigationBar),
        );
        // Promoted into its canonical position — between DailyOS and
        // Logbook — with More pinned last.
        expect(
          navBar.items.map((item) => item.label),
          ['Tasks', 'DailyOS', 'Projects', 'Logbook', 'More'],
        );

        // The promoted destination owns its highlight; the More slot must
        // not take its name (it only ever represents what it still hides:
        // Habits, Insights, and Settings).
        expect(navBar.items[2].active, isTrue);
        expect(navBar.items.last.active, isFalse);
        expect(navBar.items.last.label, 'More');
        expect(
          navBar.items.last.semanticsLabel,
          'More, 3 additional destinations',
        );

        // The promoted slot taps straight through to the destination.
        navBar.items[2].onTap?.call();
        verify(() => mockNavService.tapIndex(2)).called(1);
      },
    );

    testWidgets(
      'keeps the More overflow on a wide window when a large text scale '
      'widens the labels past the available space',
      (tester) async {
        // The fit decision is text-scale-aware: the same 800px window that
        // fits all seven destinations at scale 1.0 cannot fit their labels
        // at 3.0, so the bar falls back to the compact More line-up
        // instead of ellipsizing every caption.
        tester.platformDispatcher.textScaleFactorTestValue = 3.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final mockNavService = MockNavService();

        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: const Size(800, 1200),
        );

        final navBar = tester.widget<DesignSystemBottomNavigationBar>(
          find.byType(DesignSystemBottomNavigationBar),
        );
        expect(
          navBar.items.map((item) => item.label),
          ['Tasks', 'DailyOS', 'Logbook', 'More'],
        );
      },
    );

    testWidgets('renders recording indicators directly above the nav bar', (
      tester,
    ) async {
      final mockNavService = MockNavService();

      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(1),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
      );

      // The indicators are shell-owned and live OUTSIDE the bar widget, so
      // they stay visible when the bar slides away in settings definition
      // surfaces.
      expect(
        find.descendant(
          of: find.byType(DesignSystemBottomNavigationBar),
          matching: find.byType(TimeRecordingIndicator),
        ),
        findsNothing,
      );
      expect(find.byType(TimeRecordingIndicator), findsOneWidget);

      // They sit in an AnimatedPositioned pinned to the bar's top edge —
      // the same height contract the bar itself renders with.
      final positioned = tester.widget<AnimatedPositioned>(
        find
            .ancestor(
              of: find.byType(TimeRecordingIndicator),
              matching: find.byType(AnimatedPositioned),
            )
            .first,
      );
      final barContext = tester.element(
        find.byType(DesignSystemFiveSlotNavBar),
      );
      expect(
        positioned.bottom,
        DesignSystemFiveSlotNavBar.barHeight(barContext),
      );

      // The closest enclosing Row uses center so the indicators meet in
      // the middle of the bar rather than spreading to its edges.
      final overlayRow = tester.widget<Row>(
        find
            .ancestor(
              of: find.byType(TimeRecordingIndicator),
              matching: find.byType(Row),
            )
            .first,
      );
      expect(overlayRow.mainAxisAlignment, MainAxisAlignment.center);
    });

    testWidgets(
      'occupiedHeight inside the page stack grows by the indicator height '
      'while a timer runs',
      (tester) async {
        final mockNavService = MockNavService();

        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(
          mockNavService,
          runningTimer: _runningTimerEntry,
        );
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        // Pages padding by occupiedHeight reserve room for the time
        // recording indicator riding above the bar, so it never covers
        // scroll content or floating actions.
        final pageContext = tester.element(find.byType(IndexedStack));
        expect(
          DesignSystemBottomNavigationBar.occupiedHeight(pageContext),
          DesignSystemFiveSlotNavBar.barHeight(pageContext) +
              AudioRecordingIndicatorConstants.indicatorHeight,
        );
      },
    );

    testWidgets(
      'occupiedHeight inside the page stack matches the bar while no '
      'indicator is visible',
      (tester) async {
        final mockNavService = MockNavService();

        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        final pageContext = tester.element(find.byType(IndexedStack));
        expect(
          DesignSystemBottomNavigationBar.occupiedHeight(pageContext),
          DesignSystemFiveSlotNavBar.barHeight(pageContext),
        );
      },
    );

    testWidgets(
      'the goal banner tops the shell, displacing content and leaving the '
      'bottom bar reserve untouched',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);
        final nudge = NudgeEntityView.of(
          AgentDomainEntity.goalNudge(
            id: 'goal-banner',
            agentId: 'goal-walk',
            status: NudgeStatus.active,
            brief: const NudgeBrief(
              headline: 'One more walk keeps the week moving.',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: 'goal-banner',
            createdAt: DateTime.utc(2026, 8, 11),
            updatedAt: DateTime.utc(2026, 8, 11),
            vectorClock: null,
          ),
        )!;
        final entry = (
          nudge: nudge,
          subjectTitle: 'Walk',
          kind: NudgeBannerKind.goal,
          tapRoute: '/goals/details/goal-walk',
        );

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          extraOverrides: [
            // The shell's dock reads the merged provider; register the goal
            // source exactly as app_bootstrap does.
            nudgeBannerSourcesProvider.overrideWithValue([
              activeGoalNudgesProvider,
            ]),
            activeGoalNudgesProvider.overrideWith((ref) async => [entry]),
            nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          ],
        );

        expect(find.text(nudge.brief.headline), findsOneWidget);
        final pageContext = tester.element(find.byType(IndexedStack));

        // The dock no longer rides in the bottom overlay, so the bar's
        // reserve is the bar alone — page content and FABs must not be
        // pushed up by a banner that is nowhere near the bottom edge.
        expect(
          DesignSystemBottomNavigationBar.occupiedHeight(pageContext),
          DesignSystemFiveSlotNavBar.barHeight(pageContext),
          reason: 'the top-anchored dock reserves no bottom lane',
        );

        // The dock is mounted from the first frame and animates its arrival
        // in, so let that finish before measuring — otherwise every geometry
        // assertion below reads a mid-transition zero and passes vacuously.
        await tester.pump(const Duration(milliseconds: 400));

        // Anchored to the very top, and DISPLACING the content rather than
        // covering it: the content stack starts below the banner's bottom
        // edge, which is what keeps scrolling content from passing under it.
        final dockRect = tester.getRect(find.byType(NudgeBannerDock));
        final contentTop = tester.getRect(find.byType(IndexedStack)).top;
        expect(dockRect.top, 0);
        expect(dockRect.height, greaterThan(0));
        expect(
          contentTop,
          greaterThanOrEqualTo(dockRect.bottom),
          reason: 'content must start below the banner, never under it',
        );

        final container = ProviderScope.containerOf(pageContext, listen: false);
        container
            .read(locallySnoozedNudgeDeadlinesProvider.notifier)
            .add(nudge.id, nudge.activationCount, DateTime.utc(2099));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Collapsing gracefully: the lane gives every pixel back to the
        // content, which returns to the top of the shell.
        expect(find.text(nudge.brief.headline), findsNothing);
        expect(tester.getRect(find.byType(NudgeBannerDock)).height, 0);
        expect(
          tester.getRect(find.byType(IndexedStack)).top,
          lessThan(contentTop),
          reason: 'a hidden banner must not leave a blank lane behind',
        );
        expect(
          DesignSystemBottomNavigationBar.occupiedHeight(pageContext),
          DesignSystemFiveSlotNavBar.barHeight(pageContext),
        );
      },
    );

    testWidgets(
      'a banner appearing or leaving never remounts the shell or the dock',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        final nudge = NudgeEntityView.of(
          AgentDomainEntity.goalNudge(
            id: 'goal-banner',
            agentId: 'goal-walk',
            status: NudgeStatus.active,
            brief: const NudgeBrief(
              headline: 'One more walk keeps the week moving.',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: 'goal-banner',
            createdAt: DateTime.utc(2026, 8, 11),
            updatedAt: DateTime.utc(2026, 8, 11),
            vectorClock: null,
          ),
        )!;
        final entry = (
          nudge: nudge,
          subjectTitle: 'Walk',
          kind: NudgeBannerKind.goal,
          tapRoute: '/goals/details/goal-walk',
        );

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          extraOverrides: [
            nudgeBannerSourcesProvider.overrideWithValue([
              activeGoalNudgesProvider,
            ]),
            activeGoalNudgesProvider.overrideWith((ref) async => [entry]),
            nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          ],
        );

        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(nudge.brief.headline), findsOneWidget);

        // Element identity IS mount identity: if the lane swaps the wrapper
        // hierarchy above the shell when a banner arrives or leaves, Flutter
        // inflates a fresh subtree and every Beamer, scroll offset and
        // half-typed field below is silently reset.
        final shellBefore = tester.element(find.byType(IndexedStack));
        final dockBefore = tester.element(find.byType(NudgeBannerDock));

        final container = ProviderScope.containerOf(
          shellBefore,
          listen: false,
        );
        container
            .read(locallySnoozedNudgeDeadlinesProvider.notifier)
            .add(nudge.id, nudge.activationCount, DateTime.utc(2099));
        await tester.pump();

        expect(
          tester.element(find.byType(IndexedStack)),
          same(shellBefore),
          reason: 'a sync-driven banner change must not remount the shell',
        );
        expect(
          tester.element(find.byType(NudgeBannerDock)),
          same(dockBefore),
          reason: 'remounting the dock discards its rotation and tenure state',
        );

        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.getRect(find.byType(NudgeBannerDock)).height, 0);
      },
    );

    testWidgets('Tasks bottom-nav item uses plain list icons', (tester) async {
      final mockNavService = MockNavService();

      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
      );

      final navBar = tester.widget<DesignSystemBottomNavigationBar>(
        find.byType(DesignSystemBottomNavigationBar),
      );
      final tasksItem = navBar.items.first;
      final icon = tasksItem.icon;
      final activeIcon = tasksItem.activeIcon;

      expect(tasksItem.label, 'Tasks');
      expect(icon, isA<Icon>());
      expect((icon as Icon).icon, LottiIcons.list);
      expect(activeIcon, isA<Icon>());
      expect((activeIcon! as Icon).icon, LottiIcons.list);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('disables tickers for inactive mobile tabs', (tester) async {
      final mockNavService = MockNavService();

      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(3),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
      );

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 3);
      for (var i = 0; i < stack.children.length; i++) {
        final child = stack.children[i];
        expect(child, isA<TickerMode>());
        expect((child as TickerMode).enabled, i == 3);
      }
    });
  });

  group('AppScreen restored tab', () {
    testWidgets(
      'renders the restored tab on the FIRST frame, with no emission to '
      'wait for',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          // Nav state is restored before `runApp`, so the emission that
          // selected the tab is long gone by the time the shell subscribes.
          // An empty stream is exactly that cold-start situation.
          indexStream: const Stream<int>.empty(),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        when(() => mockNavService.index).thenReturn(4);
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
        );

        // Seeded from the service rather than defaulting to 0 — otherwise the
        // app opens on Tasks and the whole restore is invisible to the user.
        expect(
          tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          4,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen breakpoint crossing', () {
    testWidgets(
      'keeps the tab content mounted and the delegates attached across a '
      'resize',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
        );

        expect(find.byType(DesktopNavigationSidebar), findsOneWidget);
        final stackFinder = find.byType(IndexedStack);
        final elementBefore = tester.element(stackFinder);
        // A nested delegate reaches the root router through `parent`. It is
        // the first thing `BeamerState.dispose` tears down, so it is the
        // sharpest witness that the subtree survived rather than being
        // re-inflated.
        expect(mockNavService.tasksDelegate.parent, isNotNull);
        expect(mockNavService.journalDelegate.parent, isNotNull);

        tester.view.physicalSize = _phoneViewportSize;
        await tester.pump();
        await tester.pump();

        expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
        expect(find.byType(DesktopNavigationSidebar), findsNothing);
        // Same Element, not merely a same-shaped widget: everything the tabs
        // hold — page stacks, scroll offsets, in-flight state — is still the
        // state the user built up before the resize.
        expect(tester.element(stackFinder), same(elementBefore));
        expect(mockNavService.tasksDelegate.parent, isNotNull);
        expect(mockNavService.journalDelegate.parent, isNotNull);

        // ...and back up again.
        tester.view.physicalSize = _desktopViewportSize;
        await tester.pump();
        await tester.pump();

        expect(find.byType(DesktopNavigationSidebar), findsOneWidget);
        expect(tester.element(stackFinder), same(elementBefore));
        expect(mockNavService.tasksDelegate.parent, isNotNull);
        expect(mockNavService.journalDelegate.parent, isNotNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen desktop layout', () {
    testWidgets('shows sidebar and hides bottom nav at desktop width', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      expect(find.byType(DesktopNavigationSidebar), findsOneWidget);
      expect(find.byType(SidebarSavedTaskFilters), findsOneWidget);
      expect(find.byType(DesignSystemBottomNavigationBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('pins the Contact Us footer beneath Settings in the sidebar', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      expect(find.byType(ContactSupportRow), findsOneWidget);
      // Below Settings, not among the destinations: nothing in the footer
      // switches tabs, so it must not read as one more place to navigate to.
      expect(
        tester.getRect(find.byType(ContactSupportRow)).top,
        greaterThan(tester.getRect(find.text('Settings')).bottom),
      );
      // And inside the rail, not floating over the content pane.
      final sidebarFinder = find.byType(DesktopNavigationSidebar);
      final sidebar = tester.getRect(sidebarFinder);
      final contact = tester.getRect(find.byType(ContactSupportRow));
      expect(
        contact.right,
        lessThanOrEqualTo(sidebar.right),
      );
      expect(
        sidebar.bottom - contact.bottom,
        closeTo(
          tester.element(sidebarFinder).designTokens.spacing.step3,
          0.5,
        ),
        reason: 'the inactive sync slot must not leave a footer gap',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('drops the Contact Us footer while the sidebar is collapsed', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      await tester.tap(find.byKey(desktopSidebarToggleKey));
      await tester.pump();

      // The icon-only rail is 72 px wide — narrower than the four glyphs.
      // The footer disappears rather than overflowing, the same as the
      // activity summary above Settings.
      expect(find.byType(ContactSupportRow), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'Daily OS month calendar renders under its sidebar row only while '
      'the Daily OS tab is active',
      (tester) async {
        Future<void> pumpWithActiveIndex(int index) async {
          final mockNavService = MockNavService();
          await _stubNavService(
            mockNavService,
            indexStream: Stream.value(index),
            isProjectsEnabled: () => true,
            isDailyOsEnabled: () => true,
            isHabitsEnabled: () => true,
            isDashboardsEnabled: () => true,
          );
          await _registerAppScreenGetIt(mockNavService);
          addTearDown(tearDownTestGetIt);

          await _pumpAppScreen(
            tester,
            navService: mockNavService,
            viewportSize: _desktopViewportSize,
          );
        }

        // Tasks active (index 0): no calendar in the sidebar.
        await pumpWithActiveIndex(0);
        expect(find.byType(DailyOsSidebarCalendar), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tearDownTestGetIt();

        // Daily OS active (index 1, right after Tasks): the calendar
        // renders as the destination's expanded subtree.
        await pumpWithActiveIndex(1);
        expect(find.byType(DailyOsSidebarCalendar), findsOneWidget);
        // It sits under the Daily OS row, above Habits.
        final calendarY = tester
            .getTopLeft(find.byType(DailyOsSidebarCalendar))
            .dy;
        final sidebar = find.byType(DesktopNavigationSidebar);
        final dailyOsRowY = tester
            .getCenter(
              find.descendant(of: sidebar, matching: find.text('DailyOS')),
            )
            .dy;
        final habitsRowY = tester
            .getCenter(
              find.descendant(of: sidebar, matching: find.text('Habits')),
            )
            .dy;
        expect(calendarY, greaterThan(dailyOsRowY));
        expect(calendarY, lessThan(habitsRowY));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'AI Impact sidebar entry renders under Insights, not Daily OS',
      (tester) async {
        Future<void> pumpWithActiveIndex(int index) async {
          final mockNavService = MockNavService();
          await _stubNavService(
            mockNavService,
            indexStream: Stream.value(index),
            isProjectsEnabled: () => true,
            isDailyOsEnabled: () => true,
            isHabitsEnabled: () => true,
            isDashboardsEnabled: () => true,
          );
          await _registerAppScreenGetIt(mockNavService);
          addTearDown(tearDownTestGetIt);

          await _pumpAppScreen(
            tester,
            navService: mockNavService,
            viewportSize: _desktopViewportSize,
          );
        }

        await pumpWithActiveIndex(1);
        expect(find.byType(DailyOsSidebarCalendar), findsOneWidget);
        expect(find.byType(ImpactSidebarEntry), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tearDownTestGetIt();

        await pumpWithActiveIndex(4);
        expect(find.byType(DailyOsSidebarCalendar), findsNothing);
        expect(find.byType(ImpactSidebarEntry), findsOneWidget);

        final sidebar = find.byType(DesktopNavigationSidebar);
        final impactY = tester.getTopLeft(find.byType(ImpactSidebarEntry)).dy;
        final insightsRowY = tester
            .getCenter(
              find.descendant(of: sidebar, matching: find.text('Insights')),
            )
            .dy;
        final journalRowY = tester
            .getCenter(
              find.descendant(of: sidebar, matching: find.text('Logbook')),
            )
            .dy;

        expect(impactY, greaterThan(insightsRowY));
        expect(impactY, lessThan(journalRowY));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('Tasks sidebar item has no trailing count badge', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      final sidebar = tester.widget<DesktopNavigationSidebar>(
        find.byType(DesktopNavigationSidebar),
      );
      final tasksDestination = sidebar.destinations.first;
      final icon = tasksDestination.iconBuilder(active: false);
      final activeIcon = tasksDestination.iconBuilder(active: true);

      expect(tasksDestination.label, 'Tasks');
      expect(tasksDestination.trailingBuilder, isNull);
      expect(icon, isA<Icon>());
      expect((icon as Icon).icon, LottiIcons.list);
      expect(activeIcon, isA<Icon>());
      expect((activeIcon as Icon).icon, LottiIcons.list);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('sidebar shows Settings at the bottom', (tester) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'desktop sidebar keeps Settings navigation without a Manual utility link',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
        );

        final settings = find.text('Settings');
        expect(settings, findsOneWidget);
        expect(find.text('Manual'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('tapping sidebar destination calls tapIndex', (tester) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      // Tap Projects in the sidebar
      await tester.tap(find.text('Projects'));
      await tester.pump();

      // Projects is at index 2 in the full destinations list, after
      // Tasks and DailyOS.
      verify(() => mockNavService.tapIndex(2)).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('tapping Settings in sidebar calls tapIndex for settings', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      await tester.tap(find.text('Settings'));
      await tester.pump();

      // Settings is at index 6 (last) in the full destinations list
      verify(() => mockNavService.tapIndex(6)).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'desktop layout has no floating TimeRecordingIndicator and wires the '
      'compact activity summary into the sidebar',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
        );

        // The legacy bottom-anchored TimeRecordingIndicator must not appear in
        // the desktop layout. Transient systems share the compact summary.
        expect(find.byType(TimeRecordingIndicator), findsNothing);
        expect(
          find.byType(SidebarActivitySummary),
          findsOneWidget,
          reason:
              'SidebarActivitySummary should be wired into the desktop sidebar.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('disables tickers for inactive desktop tabs', (tester) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(2),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 2);
      for (var i = 0; i < stack.children.length; i++) {
        final child = stack.children[i];
        expect(child, isA<TickerMode>());
        final tickerMode = child as TickerMode;
        expect(tickerMode.enabled, i == 2);
        expect(tickerMode.child, isA<ExcludeFocus>());
        expect((tickerMode.child as ExcludeFocus).excluding, i != 2);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('excludes inactive mobile tabs from keyboard focus', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(2),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
      );

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, 2);
      for (var i = 0; i < stack.children.length; i++) {
        final tickerMode = stack.children[i] as TickerMode;
        expect(tickerMode.child, isA<ExcludeFocus>());
        expect((tickerMode.child as ExcludeFocus).excluding, i != 2);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('respects feature flags in sidebar', (tester) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => false,
        isDailyOsEnabled: () => false,
        isHabitsEnabled: () => false,
        isDashboardsEnabled: () => false,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      // Only Tasks, Journal, Settings should be visible
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Projects'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('isTaskDetailRoute', () {
    // Single source of truth for the drives the predicate: this is the
    // exact same callsite shape used by the mobile shell in beamer_app.dart
    // for bottom-nav suppression.

    test('returns false when the active tab is not the tasks tab', () {
      // Even with a task-detail location, any non-tasks tab keeps the
      // bottom navigation visible — the TaskActionBar only renders inside
      // the tasks-tab pane.
      final location = TasksLocation(
        RouteInformation(uri: Uri.parse('/tasks/${const Uuid().v4()}')),
      );
      expect(isTaskDetailRoute(location, 1), isFalse);
      expect(isTaskDetailRoute(location, 5), isFalse);
    });

    test('returns false when the location is not a TasksLocation', () {
      final location = _ArbitraryLocation(
        RouteInformation(uri: Uri.parse('/tasks/abc')),
      );
      expect(isTaskDetailRoute(location, 0), isFalse);
    });

    test('returns false when the location is null', () {
      expect(isTaskDetailRoute(null, 0), isFalse);
    });

    test('returns false on the tasks list route (no taskId in path)', () {
      final location = TasksLocation(
        RouteInformation(uri: Uri.parse('/tasks')),
      );
      expect(isTaskDetailRoute(location, 0), isFalse);
    });

    test('returns false when the trailing path segment is not a uuid', () {
      // A non-uuid segment (legacy/typo path) must not falsely flag the
      // route as a task detail and hide the indicator.
      final location = TasksLocation(
        RouteInformation(uri: Uri.parse('/tasks/not-a-uuid')),
      );
      expect(isTaskDetailRoute(location, 0), isFalse);
    });

    test('returns true on /tasks/<uuid> with the tasks tab active', () {
      final taskId = const Uuid().v4();
      final location = TasksLocation(
        RouteInformation(uri: Uri.parse('/tasks/$taskId')),
      );
      expect(isTaskDetailRoute(location, 0), isTrue);
    });
  });

  group('dayViewColumnAllowance', () {
    test('hides below the minimum window width', () {
      final allowance = dayViewColumnAllowance(
        taskDetailOpen: false,
        windowWidth: kDayViewPanelMinWindowWidth - 1,
        sidebarWidth: defaultSidebarWidth,
      );
      expect(allowance.show, isFalse);
    });

    test('allows the full width range with no open task detail', () {
      final allowance = dayViewColumnAllowance(
        taskDetailOpen: false,
        windowWidth: 1280,
        sidebarWidth: defaultSidebarWidth,
      );
      expect(allowance.show, isTrue);
      expect(allowance.maxWidth, maxDayViewPanelWidth);
    });

    test(
      'clamps the column while a task detail is open on a wide window, '
      'preserving a desktop-wide split region',
      () {
        final allowance = dayViewColumnAllowance(
          taskDetailOpen: true,
          windowWidth: 1800,
          sidebarWidth: defaultSidebarWidth,
        );
        expect(allowance.show, isTrue);
        // 1800 - 256 sidebar - 960 split floor = 584.
        expect(allowance.maxWidth, 1800 - defaultSidebarWidth - 960);
        expect(allowance.maxWidth, lessThan(maxDayViewPanelWidth));
      },
    );

    test(
      'yields entirely while a detail is open when even the minimum column '
      'would starve the split',
      () {
        // 1440 - 256 - 960 = 224 < minDayViewPanelWidth (300).
        final allowance = dayViewColumnAllowance(
          taskDetailOpen: true,
          windowWidth: 1440,
          sidebarWidth: defaultSidebarWidth,
        );
        expect(allowance.show, isFalse);
      },
    );

    test('a collapsed sidebar frees room for the column beside a detail', () {
      // 1440 - 72 - 960 = 408 >= 300 — the same window that yields with an
      // expanded sidebar hosts the column at a clamped width.
      final allowance = dayViewColumnAllowance(
        taskDetailOpen: true,
        windowWidth: 1440,
        sidebarWidth: kCollapsedSidebarWidth,
      );
      expect(allowance.show, isTrue);
      expect(allowance.maxWidth, 1440 - kCollapsedSidebarWidth - 960);
    });
  });

  group('settingsRouteHidesBottomNav', () {
    SettingsLocation settingsLocationFor(String path) =>
        SettingsLocation(RouteInformation(uri: Uri.parse(path)));

    /// Asserts every path in [paths] resolves to [hides], with the path as
    /// the failure reason so a regression names the offending route.
    void expectHides(Iterable<String> paths, {required bool hides}) {
      for (final path in paths) {
        expect(
          settingsRouteHidesBottomNav(settingsLocationFor(path)),
          hides,
          reason: path,
        );
      }
    }

    group('guards', () {
      test('a null location keeps the bar', () {
        expect(settingsRouteHidesBottomNav(null), isFalse);
      });

      test('a non-settings location keeps the bar even at a settings-like '
          'path', () {
        expect(
          settingsRouteHidesBottomNav(
            _ArbitraryLocation(
              RouteInformation(uri: Uri.parse('/settings/categories/abc')),
            ),
          ),
          isFalse,
        );
      });

      test('the bare /settings root menu keeps the bar', () {
        expectHides(['/settings'], hides: false);
      });

      test('a SettingsLocation whose path is not under /settings keeps the '
          'bar', () {
        // Exercises the `segments.first != 'settings'` guard: a
        // SettingsLocation can be constructed for any URI.
        expectHides(['/elsewhere/deep/path'], hides: false);
      });
    });

    group('menu hubs keep the bar', () {
      test('the branch hubs with no page of their own', () {
        expectHides([
          '/settings/advanced',
          '/settings/sync',
          '/settings/definitions',
          '/settings/preferences',
        ], hides: false);
      });
    });

    group('AI and Agents sections hide the bar entirely', () {
      test('AI landing, per-tab lists, and editors all hide', () {
        expectHides([
          '/settings/ai',
          '/settings/ai/profiles',
          '/settings/ai/provider/some-provider-id',
          '/settings/ai/model/some-model-id',
          '/settings/ai/profile/some-profile-id',
        ], hides: true);
      });

      test('Agents landing, per-tab lists, editors, and review history all '
          'hide', () {
        expectHides([
          '/settings/agents',
          '/settings/agents/templates',
          '/settings/agents/instances',
          '/settings/agents/souls',
          '/settings/agents/pending-wakes',
          '/settings/agents/templates/some-template-id',
          '/settings/agents/templates/create',
          '/settings/agents/souls/some-soul-id',
          '/settings/agents/souls/create',
          '/settings/agents/instances/some-agent-id',
          '/settings/agents/templates/some-template-id/review',
          '/settings/agents/souls/some-soul-id/review',
        ], hides: true);
      });
    });

    group('Sync leaves hide, the hub keeps', () {
      test('every sync detail leaf hides the bar', () {
        expectHides([
          '/settings/sync/provisioned',
          '/settings/sync/node-profile',
          '/settings/sync/backfill',
          '/settings/sync/stats',
          '/settings/sync/outbox',
          '/settings/sync/matrix/maintenance',
        ], hides: true);
      });

      test('the sync hub keeps the bar', () {
        expectHides(['/settings/sync'], hides: false);
      });
    });

    group('Advanced leaves', () {
      test('non-conflict advanced leaves hide the bar', () {
        expectHides([
          '/settings/advanced/animations',
          '/settings/advanced/manual-language',
          '/settings/advanced/logging_domains',
          '/settings/advanced/maintenance',
          '/settings/advanced/onboarding_metrics',
          '/settings/advanced/about',
        ], hides: true);
      });

      test('the conflicts list keeps the bar but conflict detail hides it', () {
        expectHides(['/settings/advanced/conflicts'], hides: false);
        expectHides([
          '/settings/advanced/conflicts/some-conflict-id',
        ], hides: true);
      });
    });

    group('top-level leaf pages hide the bar', () {
      test(
        'terminal single-segment leaves and the legacy maintenance alias',
        () {
          expectHides([
            '/settings/flags',
            '/settings/theming',
            '/settings/recording-style',
            '/settings/daily-os',
            '/settings/speech',
            '/settings/onboarding',
            '/settings/health_import',
            '/settings/keyboard-shortcuts',
            '/settings/maintenance',
          ], hides: true);
        },
      );
    });

    group('entity definitions: lists keep, editors hide', () {
      test('list pages keep the bar', () {
        expectHides([
          '/settings/categories',
          '/settings/labels',
          '/settings/dashboards',
          '/settings/measurables',
          '/settings/habits',
        ], hides: false);
      });

      test('detail and create editors hide the bar', () {
        expectHides([
          '/settings/categories/some-category-id',
          '/settings/categories/create',
          '/settings/labels/some-label-id',
          '/settings/labels/create',
          '/settings/dashboards/some-dashboard-id',
          '/settings/dashboards/create',
          '/settings/measurables/some-measurable-id',
          '/settings/measurables/create',
        ], hides: true);
      });
    });

    group('habits list variants keep, editors hide', () {
      test('create and a real by_id/<id> editor hide the bar', () {
        expectHides([
          '/settings/habits/create',
          '/settings/habits/by_id/some-habit-id',
        ], hides: true);
      });

      test('the filtered search list and a bare by_id keep the bar', () {
        expectHides([
          // Search is the list page with a filter applied.
          '/settings/habits/search/morning',
          // Bare `by_id` without an id renders the list page.
          '/settings/habits/by_id',
        ], hides: false);
      });
    });

    group('projects: editors hide, the reserved create slug keeps', () {
      test('a project editor hides the bar', () {
        expectHides(['/settings/projects/some-project-id'], hides: true);
      });

      test('the unrouted create slug keeps the bar over the settings root', () {
        // Creation lives at /projects/create (a modal), so a stale deep link
        // must not hide the bar.
        expectHides(['/settings/projects/create'], hides: false);
      });
    });
  });

  group('projectsRouteHidesBottomNav', () {
    ProjectsLocation projectsLocationFor(String path) =>
        ProjectsLocation(RouteInformation(uri: Uri.parse(path)));

    test('a null location keeps the bar', () {
      expect(projectsRouteHidesBottomNav(null), isFalse);
    });

    test('a non-projects location keeps the bar even at a projects-like '
        'path', () {
      expect(
        projectsRouteHidesBottomNav(
          _ArbitraryLocation(
            RouteInformation(uri: Uri.parse('/projects/some-project-id')),
          ),
        ),
        isFalse,
      );
    });

    test('the /projects list root keeps the bar', () {
      expect(
        projectsRouteHidesBottomNav(projectsLocationFor('/projects')),
        isFalse,
      );
    });

    test('a ProjectsLocation whose path is not under /projects keeps the '
        'bar', () {
      // Exercises the `segments.first != 'projects'` guard: a
      // ProjectsLocation can be constructed for any URI.
      expect(
        projectsRouteHidesBottomNav(projectsLocationFor('/elsewhere/deep')),
        isFalse,
      );
    });

    test('a project detail hides the bar', () {
      expect(
        projectsRouteHidesBottomNav(
          projectsLocationFor('/projects/some-project-id'),
        ),
        isTrue,
      );
    });

    test('the reserved create slug keeps the bar', () {
      // `/projects/create` is a stale deep link from the retired full-screen
      // create route; ProjectsLocation renders the list for it, so the bar
      // must stay.
      expect(
        projectsRouteHidesBottomNav(projectsLocationFor('/projects/create')),
        isFalse,
      );
    });
  });

  group('peopleRouteHidesBottomNav', () {
    RelationshipsLocation peopleLocationFor(String path) =>
        RelationshipsLocation(RouteInformation(uri: Uri.parse(path)));

    test('a null location keeps the bar', () {
      expect(peopleRouteHidesBottomNav(null), isFalse);
    });

    test('a non-people location keeps the bar even at a people-like path', () {
      expect(
        peopleRouteHidesBottomNav(
          GoalsLocation(RouteInformation(uri: Uri.parse('/people/anna'))),
        ),
        isFalse,
      );
    });

    // The list root is the only way back to the other tabs from here.
    test('the /people list root keeps the bar', () {
      expect(peopleRouteHidesBottomNav(peopleLocationFor('/people')), isFalse);
    });

    test('a RelationshipsLocation outside /people keeps the bar', () {
      expect(
        peopleRouteHidesBottomNav(peopleLocationFor('/elsewhere/deep')),
        isFalse,
      );
    });

    test("a person's detail page hides the bar", () {
      expect(
        peopleRouteHidesBottomNav(peopleLocationFor('/people/anna')),
        isTrue,
      );
    });

    // The pointed case: the chat composer owns the bottom edge.
    test("a person's chat hides the bar", () {
      expect(
        peopleRouteHidesBottomNav(peopleLocationFor('/people/anna/chat')),
        isTrue,
      );
    });

    // Malformed shapes render the list, and the list must keep its tab bar.
    test('unknown sub-routes and deeper paths keep the bar', () {
      expect(
        peopleRouteHidesBottomNav(peopleLocationFor('/people/anna/edit')),
        isFalse,
      );
      expect(
        peopleRouteHidesBottomNav(peopleLocationFor('/people/anna/chat/deep')),
        isFalse,
      );
    });

    test('an empty person id keeps the bar', () {
      expect(
        peopleRouteHidesBottomNav(peopleLocationFor('/people//chat')),
        isFalse,
      );
    });
  });

  group('goalsRouteHidesBottomNav', () {
    GoalsLocation goalsLocationFor(String path) =>
        GoalsLocation(RouteInformation(uri: Uri.parse(path)));

    test('a null location keeps the bar', () {
      expect(goalsRouteHidesBottomNav(null), isFalse);
    });

    test('a non-goals location keeps the bar even at a goals-like path', () {
      expect(
        goalsRouteHidesBottomNav(
          ProjectsLocation(
            RouteInformation(uri: Uri.parse('/goals/details/goal-1')),
          ),
        ),
        isFalse,
      );
    });

    test('the /goals list root keeps the bar', () {
      expect(goalsRouteHidesBottomNav(goalsLocationFor('/goals')), isFalse);
    });

    test('a GoalsLocation whose path is not under /goals keeps the bar', () {
      expect(
        goalsRouteHidesBottomNav(goalsLocationFor('/elsewhere/deep')),
        isFalse,
      );
    });

    test('detail, chat, edit and create hide the bar; unknown sub-routes '
        'keep it', () {
      expect(
        goalsRouteHidesBottomNav(goalsLocationFor('/goals/details/goal-1')),
        isTrue,
      );
      expect(
        goalsRouteHidesBottomNav(
          goalsLocationFor('/goals/details/goal-1/chat'),
        ),
        isTrue,
      );
      expect(
        goalsRouteHidesBottomNav(
          goalsLocationFor('/goals/details/goal-1/edit'),
        ),
        isTrue,
      );
      expect(
        goalsRouteHidesBottomNav(goalsLocationFor('/goals/create')),
        isTrue,
      );
      expect(
        goalsRouteHidesBottomNav(goalsLocationFor('/goals/settings')),
        isFalse,
      );
    });
  });

  group('habitsRouteHidesBottomNav', () {
    HabitsLocation habitsLocationFor(String path) =>
        HabitsLocation(RouteInformation(uri: Uri.parse(path)));

    test('only valid create and edit routes hide the bar', () {
      expect(habitsRouteHidesBottomNav(null), isFalse);
      expect(
        habitsRouteHidesBottomNav(
          GoalsLocation(RouteInformation(uri: Uri.parse('/habits/create'))),
        ),
        isFalse,
      );
      expect(habitsRouteHidesBottomNav(habitsLocationFor('/habits')), isFalse);
      expect(
        habitsRouteHidesBottomNav(habitsLocationFor('/habits/create')),
        isTrue,
      );
      expect(
        habitsRouteHidesBottomNav(habitsLocationFor('/habits/edit/habit-1')),
        isTrue,
      );
      expect(
        habitsRouteHidesBottomNav(habitsLocationFor('/habits/edit')),
        isFalse,
      );
      expect(
        habitsRouteHidesBottomNav(
          habitsLocationFor('/habits/edit/habit-1/deep'),
        ),
        isFalse,
      );
    });
  });

  group('AppScreen settings entity-definition nav hiding', () {
    testWidgets(
      'slides the bar away inside an entity editor and back on the list',
      (tester) async {
        final mockNavService = MockNavService();
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        final settingsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/settings',
          locationBuilder: (routeInformation, _) =>
              _TestSettingsLocation(routeInformation),
        );
        addTearDown(settingsDelegate.dispose);
        await settingsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/settings')),
        );

        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
          settingsDelegate: settingsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        // Activate the Settings tab (destinations: Tasks, Journal,
        // Settings).
        indexController.add(2);
        await tester.pump();

        AnimatedSlide slide() => tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );
        IgnorePointer ignorePointer() => tester.widget<IgnorePointer>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(IgnorePointer),
              )
              .first,
        );

        AnimatedPositioned indicators() => tester.widget<AnimatedPositioned>(
          find
              .ancestor(
                of: find.byType(TimeRecordingIndicator),
                matching: find.byType(AnimatedPositioned),
              )
              .first,
        );

        // On the settings root the bar sits in place and accepts taps.
        expect(slide().offset, Offset.zero);
        expect(ignorePointer().ignoring, isFalse);

        // The categories list page is a browse surface — the bar stays in
        // place there.
        settingsDelegate.beamToNamed('/settings/categories');
        await tester.pump();
        expect(slide().offset, Offset.zero);
        expect(ignorePointer().ignoring, isFalse);

        // Entering a category editor keeps the bar mounted (so the move
        // can animate) but slides it down by its own height and makes it
        // inert. The recording indicators stay mounted outside the
        // sliding subtree and drop to the bottom safe-area edge.
        settingsDelegate.beamToNamed('/settings/categories/some-category-id');
        await tester.pump();
        expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
        expect(slide().offset, const Offset(0, 1));
        expect(ignorePointer().ignoring, isTrue);
        expect(find.byType(TimeRecordingIndicator), findsOneWidget);
        final barContext = tester.element(
          find.byType(DesignSystemFiveSlotNavBar),
        );
        expect(
          indicators().bottom,
          MediaQuery.paddingOf(barContext).bottom,
        );
        await tester.pump(const Duration(milliseconds: 450));

        // Popping back to the list slides the bar into place and lifts
        // the indicators back above it.
        settingsDelegate.beamToNamed('/settings/categories');
        await tester.pump();
        expect(slide().offset, Offset.zero);
        expect(ignorePointer().ignoring, isFalse);
        expect(
          indicators().bottom,
          DesignSystemFiveSlotNavBar.barHeight(barContext),
        );
        await tester.pump(const Duration(milliseconds: 450));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'slides the bar away inside a project detail and back on the list',
      (tester) async {
        final mockNavService = MockNavService();
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        final projectsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/projects',
          locationBuilder: (routeInformation, _) =>
              _TestProjectsLocation(routeInformation),
        );
        addTearDown(projectsDelegate.dispose);
        await projectsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/projects')),
        );

        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
          projectsDelegate: projectsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        // Activate the Projects tab (destinations: Tasks, Projects,
        // Journal, Settings).
        indexController.add(1);
        await tester.pump();

        AnimatedSlide slide() => tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );
        IgnorePointer ignorePointer() => tester.widget<IgnorePointer>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(IgnorePointer),
              )
              .first,
        );

        // On the projects list the bar sits in place and accepts taps.
        expect(slide().offset, Offset.zero);
        expect(ignorePointer().ignoring, isFalse);

        // Entering a project detail keeps the bar mounted (so the move can
        // animate) but slides it down by its own height and makes it inert —
        // the same motion as the settings detail surfaces.
        projectsDelegate.beamToNamed('/projects/some-project-id');
        await tester.pump();
        expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
        expect(slide().offset, const Offset(0, 1));
        expect(ignorePointer().ignoring, isTrue);
        await tester.pump(const Duration(milliseconds: 450));

        // Popping back to the list slides the bar into place.
        projectsDelegate.beamToNamed('/projects');
        await tester.pump();
        expect(slide().offset, Offset.zero);
        expect(ignorePointer().ignoring, isFalse);
        await tester.pump(const Duration(milliseconds: 450));

        // The reserved create slug renders the list, so the bar stays put.
        projectsDelegate.beamToNamed('/projects/create');
        await tester.pump();
        expect(slide().offset, Offset.zero);
        expect(ignorePointer().ignoring, isFalse);
        await tester.pump(const Duration(milliseconds: 450));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    // The back arrow pops the BeamPage rather than beaming to the list.
    // Nothing else in this suite covers that path, and it is the one users
    // actually take out of a person's page.
    testWidgets(
      'brings the bar back when the back arrow pops off a person',
      (tester) async {
        final mockNavService = MockNavService()
          ..relationshipsPageEnabled = true;
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        final relationshipsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/people',
          locationBuilder: (routeInformation, _) =>
              _TestRelationshipsLocation(routeInformation),
        );
        addTearDown(relationshipsDelegate.dispose);
        await relationshipsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/people')),
        );

        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
          relationshipsDelegate: relationshipsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        indexController.add(1);
        await tester.pump();

        AnimatedSlide slide() => tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );

        relationshipsDelegate.beamToNamed('/people/anna');
        await tester.pump();
        expect(slide().offset, const Offset(0, 1));
        await tester.pump(const Duration(milliseconds: 450));

        // What the back arrow actually does: pop the BeamPage, not beam.
        relationshipsDelegate.navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump();

        expect(
          slide().offset,
          Offset.zero,
          reason: 'popping back to the list must restore the bar',
        );
        await tester.pump(const Duration(milliseconds: 450));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      "slides the bar away on a person's pages and back on the People list",
      (tester) async {
        final mockNavService = MockNavService()
          ..relationshipsPageEnabled = true;
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        final relationshipsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/people',
          locationBuilder: (routeInformation, _) =>
              _TestRelationshipsLocation(routeInformation),
        );
        addTearDown(relationshipsDelegate.dispose);
        await relationshipsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/people')),
        );

        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
          relationshipsDelegate: relationshipsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        // Destinations: Tasks, People, Journal, Settings.
        indexController.add(1);
        await tester.pump();

        AnimatedSlide slide() => tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );

        // A person's own page owns its bottom edge. The bar stays mounted
        // but slides down, exactly like a goal's pages.
        relationshipsDelegate.beamToNamed('/people/anna');
        await tester.pump();
        expect(slide().offset, const Offset(0, 1));
        await tester.pump(const Duration(milliseconds: 450));

        // The chat is the pointed case: its composer owns the bottom edge.
        relationshipsDelegate.beamToNamed('/people/anna/chat');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        // Popping back to the list slides the bar into place.
        relationshipsDelegate.beamToNamed('/people');
        await tester.pump();
        expect(slide().offset, Offset.zero);
        await tester.pump(const Duration(milliseconds: 450));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'slides the bar away inside a Goals-hosted goal page and back on the '
      'unified list',
      (tester) async {
        final mockNavService = MockNavService();
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        final goalsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/goals',
          locationBuilder: (routeInformation, _) =>
              _TestGoalsLocation(routeInformation),
        );
        addTearDown(goalsDelegate.dispose);
        await goalsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/goals')),
        );

        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
          isUnifiedGoalsEnabled: true,
          goalsDelegate: goalsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        // Activate the Goals tab (destinations: Tasks, Goals, Journal,
        // Settings).
        indexController.add(1);
        await tester.pump();

        AnimatedSlide slide() => tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );

        // The /goals list is a tab you navigate from, so it keeps the bar.
        expect(slide().offset, Offset.zero);

        // A Goals-hosted goal page owns its bottom edge, exactly like its
        // The bar stays mounted but slides down.
        goalsDelegate.beamToNamed('/goals/details/goal-1');
        await tester.pump();
        expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
        expect(slide().offset, const Offset(0, 1));
        await tester.pump(const Duration(milliseconds: 450));

        // Popping back to the unified list slides the bar into place.
        goalsDelegate.beamToNamed('/goals');
        await tester.pump();
        expect(slide().offset, Offset.zero);
        await tester.pump(const Duration(milliseconds: 450));
      },
    );

    testWidgets(
      'slides the bar away inside a Habits editor and back on the list',
      (tester) async {
        final mockNavService = MockNavService();
        final indexController = StreamController<int>.broadcast();
        addTearDown(indexController.close);

        final habitsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/habits',
          locationBuilder: (routeInformation, _) =>
              _TestHabitsLocation(routeInformation),
        );
        addTearDown(habitsDelegate.dispose);
        await habitsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/habits')),
        );

        await _stubNavService(
          mockNavService,
          indexStream: indexController.stream,
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => false,
          habitsDelegate: habitsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        // Destinations: Tasks, Habits, Journal, Settings.
        indexController.add(1);
        await tester.pump();

        AnimatedSlide slide() => tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );

        expect(slide().offset, Offset.zero);

        habitsDelegate.beamToNamed('/habits/edit/habit-1');
        await tester.pump();
        expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
        expect(slide().offset, const Offset(0, 1));
        await tester.pump(const Duration(milliseconds: 450));

        habitsDelegate.beamToNamed('/habits');
        await tester.pump();
        expect(slide().offset, Offset.zero);
        await tester.pump(const Duration(milliseconds: 450));
      },
    );

    testWidgets(
      'keeps the bar in place inside editors when another tab is active',
      (tester) async {
        final mockNavService = MockNavService();

        final settingsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/settings/habits/create',
          locationBuilder: (routeInformation, _) =>
              _TestSettingsLocation(routeInformation),
        );
        addTearDown(settingsDelegate.dispose);
        await settingsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/settings/habits/create')),
        );

        await _stubNavService(
          mockNavService,
          // Tasks tab active; the settings delegate's editor route is
          // background state and must not hide the bar.
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
          settingsDelegate: settingsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        final slide = tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );
        expect(slide.offset, Offset.zero);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'keeps the bar in place over a background project detail when '
      'another tab is active',
      (tester) async {
        final mockNavService = MockNavService();

        final projectsDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          initialPath: '/projects/some-project-id',
          locationBuilder: (routeInformation, _) =>
              _TestProjectsLocation(routeInformation),
        );
        addTearDown(projectsDelegate.dispose);
        await projectsDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/projects/some-project-id')),
        );

        await _stubNavService(
          mockNavService,
          // Tasks tab active; the projects delegate's detail route is
          // background state and must not hide the bar.
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
          projectsDelegate: projectsDelegate,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);

        final slide = tester.widget<AnimatedSlide>(
          find
              .ancestor(
                of: find.byType(DesignSystemBottomNavigationBar),
                matching: find.byType(AnimatedSlide),
              )
              .first,
        );
        expect(slide.offset, Offset.zero);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen mobile nav item taps', () {
    // Each bottom-nav slot wires onTap to `navService.tapIndex(i)` with the
    // destination's full index, even though the bar shows only the primary
    // slots (Tasks · DailyOS · Logbook · More).
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    });

    Future<DesignSystemBottomNavigationBar> pumpNavBar(
      WidgetTester tester,
      MockNavService mockNavService,
    ) async {
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(tester, navService: mockNavService);

      return tester.widget<DesignSystemBottomNavigationBar>(
        find.byType(DesignSystemBottomNavigationBar),
      );
    }

    // Bar slot → expected full destination index with all flags enabled.
    for (final (slot, tabIndex, tabName) in <(int, int, String)>[
      (0, 0, 'Tasks'),
      (1, 1, 'DailyOS'),
      (2, 5, 'Journal'),
    ]) {
      testWidgets(
        'tapping the $tabName slot calls tapIndex($tabIndex)',
        (tester) async {
          final mockNavService = MockNavService();
          final navBar = await pumpNavBar(tester, mockNavService);

          // Invoke the onTap callback directly — tapping in the widget tree
          // is unreliable for overlapping bottom-sheet-style nav bars.
          navBar.items[slot].onTap?.call();
          await tester.pump();

          verify(() => mockNavService.tapIndex(tabIndex)).called(1);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }

    testWidgets(
      'selecting Projects in the More sheet dismisses it and calls '
      'tapIndex(2)',
      (tester) async {
        final mockNavService = MockNavService();
        final navBar = await pumpNavBar(tester, mockNavService);

        // The More slot opens the overflow sheet instead of navigating.
        navBar.items.last.onTap?.call();
        await tester.pumpAndSettle();
        verifyNever(() => mockNavService.tapIndex(any()));

        await tester.tap(find.text('Projects'));
        await tester.pumpAndSettle();

        verify(() => mockNavService.tapIndex(2)).called(1);
        expect(find.text('Projects'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'More-sheet taps resolve indices against the flags at tap time, not '
      'at sheet-open time',
      (tester) async {
        final mockNavService = MockNavService();
        var projectsEnabled = true;
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => projectsEnabled,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(tester, navService: mockNavService);
        final navBar = tester.widget<DesignSystemBottomNavigationBar>(
          find.byType(DesignSystemBottomNavigationBar),
        );

        navBar.items.last.onTap?.call();
        await tester.pumpAndSettle();

        // Projects gets disabled (e.g. a synced settings change) while the
        // sheet is open: every destination after it shifts down one index.
        projectsEnabled = false;

        await tester.tap(find.text('Habits'));
        await tester.pumpAndSettle();

        // Habits resolved to its new index 2 (after Tasks and DailyOS),
        // not the index 3 it had when the sheet captured its rows.
        verify(() => mockNavService.tapIndex(2)).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen desktop banner lane', () {
    testWidgets(
      'the goal banner spans the full width above the sidebar and pushes it '
      'down',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        final nudge = NudgeEntityView.of(
          AgentDomainEntity.goalNudge(
            id: 'goal-banner',
            agentId: 'goal-walk',
            status: NudgeStatus.active,
            brief: const NudgeBrief(
              headline: 'One more walk keeps the week moving.',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: 'goal-banner',
            createdAt: DateTime.utc(2026, 8, 11),
            updatedAt: DateTime.utc(2026, 8, 11),
            vectorClock: null,
          ),
        )!;
        final entry = (
          nudge: nudge,
          subjectTitle: 'Walk',
          kind: NudgeBannerKind.goal,
          tapRoute: '/goals/details/goal-walk',
        );

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
          extraOverrides: [
            nudgeBannerSourcesProvider.overrideWithValue([
              activeGoalNudgesProvider,
            ]),
            activeGoalNudgesProvider.overrideWith((ref) async => [entry]),
            nudgeExposureFlushProvider.overrideWithValue((_, _) {}),
          ],
        );

        expect(find.text(nudge.brief.headline), findsOneWidget);

        // Settle the dock's enter animation first; a mid-transition dock has
        // zero height, which would satisfy the displacement check below
        // without proving anything.
        await tester.pump(const Duration(milliseconds: 400));

        final dockRect = tester.getRect(find.byType(NudgeBannerDock));
        final sidebarRect = tester.getRect(
          find.byType(DesktopNavigationSidebar),
        );

        // Full width, at the very top: the banner is above the sidebar,
        // not beside it inside the content region.
        expect(dockRect.top, 0);
        expect(dockRect.left, 0);
        expect(dockRect.height, greaterThan(0));
        expect(dockRect.width, _desktopViewportSize.width);

        // And it DISPLACES the sidebar rather than overlaying it.
        expect(
          sidebarRect.top,
          greaterThanOrEqualTo(dockRect.bottom),
          reason: 'the sidebar must start below the banner',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen desktop sidebar toggle-collapsed', () {
    testWidgets(
      'tapping toggle-collapsed button calls toggleSidebarCollapsed',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        var toggleCount = 0;
        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
          extraOverrides: [
            paneWidthControllerProvider.overrideWith(
              () => _SpyPaneWidthController(onToggle: () => toggleCount++),
            ),
          ],
        );

        // The sidebar toggle tile has the key `desktopSidebarToggleKey`.
        final toggleFinder = find.byKey(desktopSidebarToggleKey);
        expect(toggleFinder, findsOneWidget);
        await tester.tap(toggleFinder);
        await tester.pump();

        expect(toggleCount, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen desktop sidebar ResizableDivider drag', () {
    testWidgets('dragging the divider calls updateSidebarWidth', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);

      final deltas = <double>[];
      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
        extraOverrides: [
          paneWidthControllerProvider.overrideWith(
            () => _SpyPaneWidthController(onDrag: deltas.add),
          ),
        ],
      );

      // Two dividers on a wide desktop shell: the sidebar's and the docked
      // day-view column's. The sidebar's renders first in the Row.
      final divider = find.byType(ResizableDivider).first;
      expect(find.byType(ResizableDivider), findsNWidgets(2));

      // Perform a horizontal drag on the divider.
      await tester.drag(divider, const Offset(30, 0));
      await tester.pump();

      // At least one delta was reported to updateSidebarWidth.
      expect(deltas, isNotEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('AppScreen docked day-view column', () {
    Future<MockNavService> stubbedNavService({
      bool dailyOsEnabled = true,
      int activeIndex = 0,
    }) async {
      final mockNavService = MockNavService();
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(activeIndex),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => dailyOsEnabled,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      await _registerAppScreenGetIt(mockNavService);
      addTearDown(tearDownTestGetIt);
      return mockNavService;
    }

    testWidgets(
      'is visible by default on a wide desktop window on the Tasks tab',
      (tester) async {
        final mockNavService = await stubbedNavService();
        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
        );

        expect(find.byType(DayViewSidePanel), findsOneWidget);
        expect(find.byType(DayViewSidePanelRail), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('is absent on tabs other than Tasks', (tester) async {
      // Index 1 is the Daily OS (calendar) tab with the flag enabled — the
      // column belongs beside the tasks list only, and would be redundant
      // next to the Daily OS surface itself.
      final mockNavService = await stubbedNavService(activeIndex: 1);
      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      expect(find.byType(DayViewSidePanel), findsNothing);
      expect(find.byType(DayViewSidePanelRail), findsNothing);
      expect(find.byType(ResizableDivider), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'the calendar toggle collapses it to the rail and brings it back',
      (tester) async {
        final mockNavService = await stubbedNavService();
        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
        );

        await tester.tap(
          find.byKey(const Key('day_view_panel_hide_button')),
        );
        await tester.pump();

        expect(find.byType(DayViewSidePanel), findsNothing);
        expect(find.byType(DayViewSidePanelRail), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('day_view_panel_show_button')),
        );
        await tester.pump();

        expect(find.byType(DayViewSidePanel), findsOneWidget);
        expect(find.byType(DayViewSidePanelRail), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('is absent when the Daily OS feature flag is off', (
      tester,
    ) async {
      final mockNavService = await stubbedNavService(dailyOsEnabled: false);
      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      expect(find.byType(DayViewSidePanel), findsNothing);
      expect(find.byType(DayViewSidePanelRail), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'is absent on a desktop window too narrow to host a third column',
      (tester) async {
        final mockNavService = await stubbedNavService();
        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          // Desktop layout (>= 960) but below kDayViewPanelMinWindowWidth.
          viewportSize: const Size(1100, 800),
        );

        expect(find.byType(DayViewSidePanel), findsNothing);
        expect(find.byType(DayViewSidePanelRail), findsNothing);
        // The sidebar's divider is still the only one.
        expect(find.byType(ResizableDivider), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('dragging its divider resizes the day-view column', (
      tester,
    ) async {
      final mockNavService = await stubbedNavService();
      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
      );

      final panelFinder = find.byType(DayViewSidePanel);
      final widthBefore = tester.getSize(panelFinder).width;

      // The panel's divider is the second one in the Row; dragging it left
      // grows the panel (the divider sits on the panel's leading edge).
      await tester.drag(
        find.byType(ResizableDivider).last,
        const Offset(-40, 0),
      );
      await tester.pump();

      final widthAfter = tester.getSize(panelFinder).width;
      expect(widthAfter, greaterThan(widthBefore));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('AppScreen provider listener error branches', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    });

    testWidgets(
      'outboxLoginGateStreamProvider error arm logs via DomainLogger',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        // Emit a Stream.error so the `error:` arm of the outboxLoginGate listener fires.
        final outboxController = StreamController<void>.broadcast();
        addTearDown(outboxController.close);

        final mockOutboxService = MockOutboxService();
        when(
          () => mockOutboxService.notLoggedInGateStream,
        ).thenAnswer((_) => outboxController.stream);

        final routerDelegate = BeamerDelegate(
          setBrowserTabTitle: false,
          locationBuilder: (routeInformation, _) =>
              _AppScreenLocation(routeInformation),
        );
        addTearDown(routerDelegate.dispose);
        await routerDelegate.setNewRoutePath(
          RouteInformation(uri: Uri.parse('/')),
        );

        _useViewport(tester, _phoneViewportSize);

        final mockMatrix = MockMatrixService();
        when(
          mockMatrix.getIncomingKeyVerificationStream,
        ).thenAnswer((_) => const Stream<KeyVerification>.empty());
        when(
          () => mockMatrix.incomingKeyVerificationRunnerStream,
        ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

        final mockJournalDb = MockJournalDb();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              matrixServiceProvider.overrideWithValue(mockMatrix),
              loginStateStreamProvider.overrideWith(
                (ref) => Stream<LoginState>.value(LoginState.loggedIn),
              ),
              outboxServiceProvider.overrideWithValue(mockOutboxService),
              // Override outboxLoginGateStreamProvider directly to emit an error.
              outboxLoginGateStreamProvider.overrideWith(
                (ref) => Stream<void>.error(
                  Exception('test-outbox-error'),
                  StackTrace.empty,
                ),
              ),
              journalDbProvider.overrideWithValue(mockJournalDb),
              audioRecorderControllerProvider.overrideWith(
                () => StubAudioRecorderController(
                  AudioRecorderState(
                    status: AudioRecorderStatus.stopped,
                    progress: Duration.zero,
                    vu: -20,
                    dBFS: -160,
                    showIndicator: false,
                    modalVisible: false,
                  ),
                ),
              ),
              shouldAutoShowWhatsNewProvider.overrideWith(
                (ref) async => false,
              ),
              shouldAutoShowOnboardingProvider.overrideWith(
                (ref) async => false,
              ),
              savedTaskFiltersControllerProvider.overrideWith(
                () => _StubSavedTaskFiltersController(const []),
              ),
              currentSavedTaskFilterIdProvider.overrideWith((ref) => null),
              tasksFilterHasUnsavedClausesProvider.overrideWith((ref) => false),
            ],
            child: MaterialApp.router(
              theme: withOverrides(ThemeData.dark(useMaterial3: true)),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              routerDelegate: routerDelegate,
              routeInformationParser: BeamerParser(),
              backButtonDispatcher: BeamerBackButtonDispatcher(
                delegate: routerDelegate,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // AppScreen should still render with Tasks in the nav despite the error.
        expect(find.text('Tasks'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'shouldAutoShowWhatsNewProvider error arm does not crash AppScreen',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        // Build the widget directly so we can set shouldAutoShowWhatsNewProvider
        // to throw — _pumpAppScreen already overrides this provider and Riverpod
        // disallows double-overrides in the same container.
        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          shouldAutoShowWhatsNew: (ref) async =>
              throw Exception('whats-new-error'),
        );

        // The error arm just logs; AppScreen continues rendering normally.
        expect(find.text('Tasks'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'shouldAutoShowOnboardingProvider error arm does not crash AppScreen',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          shouldAutoShowOnboarding: (ref) async =>
              throw Exception('onboarding-trigger-error'),
        );

        // The error arm just logs; AppScreen continues rendering normally.
        expect(find.text('Tasks'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'whatsNewControllerProvider unseen→seen transition invalidates '
      'shouldAutoShowOnboardingProvider',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        // Same transition as above, but tracking
        // `shouldAutoShowOnboardingProvider` rebuilds instead -- the two
        // invalidations fire from the same whatsNew listener branch.
        var onboardingBuildCount = 0;
        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          whatsNewOverride: _UnseenToSeenWhatsNewController.new,
          shouldAutoShowOnboarding: (ref) async {
            onboardingBuildCount++;
            return false;
          },
        );

        await tester.pump();
        final buildsBeforeTransition = onboardingBuildCount;

        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();

        expect(find.text('Tasks'), findsOneWidget);
        expect(
          onboardingBuildCount,
          greaterThan(buildsBeforeTransition),
          reason:
              'shouldAutoShowOnboardingProvider should rebuild after the '
              'unseen -> seen transition invalidates it',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen listener happy-path side effects', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    });

    testWidgets(
      "shouldAutoShowWhatsNew data(true) shows the What's New modal",
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        // shouldAutoShowWhatsNew resolves to true → the post-frame callback in
        // AppScreen invokes WhatsNewModal.show. whatsNewController reports no
        // unseen content, so WhatsNewModal.show takes its empty-modal branch
        // ("You're all caught up!"), which is enough to prove the listener's
        // data(true) arm ran and opened the modal.
        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          shouldAutoShowWhatsNew: (ref) async => true,
          whatsNewOverride: _EmptyWhatsNewController.new,
        );

        // Let the post-frame callback fire and the modal route animate in.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text("You're all caught up!"), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'shouldAutoShowOnboarding data(true) shows the FTUE welcome and '
      'records the show via recordShown',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        var recordShownCount = 0;
        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          whatsNewOverride: _StableUnseenWhatsNewController.new,
          shouldAutoShowOnboarding: (ref) async => true,
          onboardingWelcomeCadenceOverride: () =>
              _CountingOnboardingWelcomeCadence(
                onRecordShown: () => recordShownCount++,
              ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.text('Choose your AI brain'), findsOneWidget);
        expect(
          recordShownCount,
          1,
          reason:
              '_showOnboardingWelcome must record the show before opening '
              'the welcome',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'shouldAutoShowDailyOsOnboarding data(true) arms the walkthrough and '
      'defers the show count until the spotlight is visible',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          // The selected destination is already the Daily OS tab, so this
          // isolates session arming from navigation behavior.
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        var recordShownCount = 0;
        final sessionController = _CountingDailyOsOnboardingSessionController();
        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          whatsNewOverride: _StableUnseenWhatsNewController.new,
          shouldAutoShowDailyOsOnboarding: (ref) async => true,
          dailyOsOnboardingCadenceOverride: () =>
              _CountingDailyOsOnboardingCadence(
                onRecordShown: () => recordShownCount++,
              ),
          extraOverrides: [
            dailyOsOnboardingSessionControllerProvider.overrideWith(
              () => sessionController,
            ),
          ],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 800));

        expect(sessionController.startCount, 1);
        expect(
          recordShownCount,
          0,
          reason:
              'arming alone must not count a walkthrough the user never saw',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'FTUE welcome skip closes the welcome without marking it completed '
      '(so the shown-count/window grace period is preserved)',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        var markCompletedCount = 0;
        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          whatsNewOverride: _StableUnseenWhatsNewController.new,
          shouldAutoShowOnboarding: (ref) async => true,
          onboardingWelcomeCadenceOverride: () =>
              _CountingOnboardingWelcomeCadence(
                onMarkCompleted: () => markCompletedCount++,
              ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text('Choose your AI brain'), findsOneWidget);

        // Skip out of the welcome without connecting — the modal's own
        // "Look around first" link (the `onDismiss` path).
        await tester.ensureVisible(find.text('Look around first'));
        await tester.tap(find.text('Look around first'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        // The welcome is gone...
        expect(find.text('Choose your AI brain'), findsNothing);
        // ...but skipping must NOT retire it: only connecting a provider marks
        // it completed, so a plain skip keeps the grace period open.
        expect(markCompletedCount, 0);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('AppScreen desktop sidebar activity summary', () {
    testWidgets(
      'consolidates timer, recording, and agents into one persistent surface',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(
          mockNavService,
          runningTimer: _runningTimerEntry,
        );
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
          extraOverrides: [
            ongoingWakeRecordsProvider.overrideWith(
              (ref) async => [
                OngoingWakeRecord(
                  agentId: 'agent-1',
                  title: 'Running wake',
                  startedAt: DateTime(2024, 3, 15, 10),
                ),
              ],
            ),
            pendingWakeRecordsProvider.overrideWith((ref) async => const []),
          ],
          audioRecorderState: AudioRecorderState(
            status: AudioRecorderStatus.recording,
            progress: const Duration(seconds: 8),
            vu: -20,
            dBFS: -40,
            showIndicator: true,
            modalVisible: false,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(SidebarActivitySummaryKeys.root),
          findsOneWidget,
        );
        expect(
          find.byKey(SidebarActivitySummaryKeys.timer),
          findsOneWidget,
        );
        expect(
          find.byKey(SidebarActivitySummaryKeys.agents),
          findsOneWidget,
        );
        expect(
          find.byKey(SidebarActivitySummaryKeys.audio),
          _isFlatpakTestHost() ? findsNothing : findsOneWidget,
        );
        expect(find.byType(SidebarTimerSection), findsNothing);
        expect(find.byType(SidebarWakeQueue), findsNothing);
        expect(find.byType(SidebarAudioRecordingSection), findsNothing);

        await tester.tap(find.byKey(SidebarActivitySummaryKeys.root));
        await tester.pump(SidebarTimerSection.animationDuration);
        expect(find.byKey(SidebarActivitySummaryKeys.details), findsOneWidget);
        expect(find.byType(SidebarTimerSection), findsOneWidget);
        expect(find.byType(SidebarWakeQueue), findsOneWidget);
        expect(
          find.byType(SidebarAudioRecordingSection),
          _isFlatpakTestHost() ? findsNothing : findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'always shows the agent metric when agents are the sole activity',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
          extraOverrides: [
            ongoingWakeRecordsProvider.overrideWith(
              (ref) async => [
                OngoingWakeRecord(
                  agentId: 'agent-1',
                  title: 'Running wake',
                  startedAt: DateTime(2024, 3, 15, 10),
                ),
              ],
            ),
            pendingWakeRecordsProvider.overrideWith((ref) async => const []),
          ],
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(SidebarActivitySummaryKeys.root),
          findsOneWidget,
        );
        expect(
          find.byKey(SidebarActivitySummaryKeys.agents),
          findsOneWidget,
        );
        expect(find.byKey(SidebarActivitySummaryKeys.timer), findsNothing);
        expect(find.byKey(SidebarActivitySummaryKeys.audio), findsNothing);

        await tester.tap(find.byKey(SidebarActivitySummaryKeys.root));
        await tester.pump(SidebarTimerSection.animationDuration);
        expect(find.byType(SidebarWakeQueue), findsOneWidget);
        expect(find.text('Running wake'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'collapses the activity surface when every system is idle',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: Stream.value(0),
          isProjectsEnabled: () => true,
          isDailyOsEnabled: () => true,
          isHabitsEnabled: () => true,
          isDashboardsEnabled: () => true,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        await _pumpAppScreen(
          tester,
          navService: mockNavService,
          viewportSize: _desktopViewportSize,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SidebarActivitySummary), findsOneWidget);
        expect(find.byKey(SidebarActivitySummaryKeys.root), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('MyBeamerApp activity tracking and focus', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    });

    testWidgets(
      'pointer events call updateActivity and a tap unfocuses primary focus',
      (tester) async {
        final mockNavService = MockNavService();
        await _stubNavService(
          mockNavService,
          indexStream: const Stream<int>.empty(),
          isProjectsEnabled: () => false,
          isDailyOsEnabled: () => false,
          isHabitsEnabled: () => false,
          isDashboardsEnabled: () => false,
        );
        await _registerAppScreenGetIt(mockNavService);
        addTearDown(tearDownTestGetIt);

        final spyActivity = _SpyUserActivityService();
        addTearDown(spyActivity.dispose);

        await _pumpReadyMyBeamerApp(
          tester,
          app: MyBeamerApp(
            navService: mockNavService,
            userActivityService: spyActivity,
          ),
        );

        // The full app tree is up (not the loading shell).
        expect(find.byType(ZoomWrapper), findsOneWidget);
        expect(find.byType(DesktopMenuWrapper), findsOneWidget);

        // A pointer-down on the app surface drives the Listener callbacks.
        final gesture = await tester.startGesture(const Offset(20, 20));
        final afterDown = spyActivity.updateCount;
        expect(afterDown, greaterThan(0));
        await gesture.moveBy(const Offset(5, 5));
        await gesture.up();
        await tester.pump();
        expect(spyActivity.updateCount, greaterThan(afterDown));

        // A scroll wheel signal drives onPointerSignal → updateActivity.
        final beforeSignal = spyActivity.updateCount;
        final pointer = TestPointer(2, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          pointer.hover(const Offset(30, 30)),
        );
        await tester.sendEventToBinding(
          pointer.scroll(const Offset(0, 20)),
        );
        await tester.pump();
        expect(spyActivity.updateCount, greaterThan(beforeSignal));

        // Trackpad pan/zoom gestures drive the panZoom* listeners.
        final beforePanZoom = spyActivity.updateCount;
        final trackpad = TestPointer(3, PointerDeviceKind.trackpad);
        await tester.sendEventToBinding(
          trackpad.panZoomStart(const Offset(40, 40)),
        );
        await tester.sendEventToBinding(
          trackpad.panZoomUpdate(const Offset(40, 40), pan: const Offset(5, 5)),
        );
        await tester.sendEventToBinding(trackpad.panZoomEnd());
        await tester.pump();
        expect(spyActivity.updateCount, greaterThan(beforePanZoom + 1));

        // Focus a node inside the app, then tap empty space: the outer
        // GestureDetector.onTap clears the primary focus.
        final node = FocusNode();
        addTearDown(node.dispose);
        final context = tester.element(find.byType(ZoomWrapper));
        FocusScope.of(context).requestFocus(node);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, node);

        await tester.tapAt(const Offset(20, 20));
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNot(node));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('global commands dispatch creation, navigation, and zoom', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      final registeredNavService = MockNavService();
      var dailyOsEnabled = false;
      var projectsEnabled = false;
      var habitsEnabled = false;
      var dashboardsEnabled = false;
      var eventsEnabled = false;
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => projectsEnabled,
        isDailyOsEnabled: () => dailyOsEnabled,
        isHabitsEnabled: () => habitsEnabled,
        isDashboardsEnabled: () => dashboardsEnabled,
        isEventsEnabled: () => eventsEnabled,
      );
      await _stubNavService(
        registeredNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
        isEventsEnabled: () => true,
      );
      const navIndexes = <AppCommandId, int>{
        AppCommandId.navigateTasks: 0,
        AppCommandId.navigateDailyOs: 1,
        AppCommandId.navigateProjects: 2,
        AppCommandId.navigateHabits: 3,
        AppCommandId.navigateDashboards: 4,
        AppCommandId.navigateJournal: 5,
        AppCommandId.navigateEvents: 6,
        AppCommandId.navigateSettings: 7,
      };
      when(() => mockNavService.tasksIndex).thenReturn(0);
      when(() => mockNavService.calendarIndex).thenReturn(1);
      when(() => mockNavService.projectsIndex).thenReturn(2);
      when(() => mockNavService.habitsIndex).thenReturn(3);
      when(() => mockNavService.dashboardsIndex).thenReturn(4);
      when(() => mockNavService.journalIndex).thenReturn(5);
      when(() => mockNavService.eventsIndex).thenReturn(6);
      when(() => mockNavService.settingsIndex).thenReturn(7);
      await _registerAppScreenGetIt(
        mockNavService,
        registeredNavService: registeredNavService,
      );
      addTearDown(tearDownTestGetIt);

      final resolvedLinkedIds = <String?>[];
      var shouldFailScreenshot = false;
      Future<Object?> recordCreation({String? linkedId}) async {
        resolvedLinkedIds.add(linkedId);
        return null;
      }

      Future<Object?> captureScreenshot({String? linkedId}) async {
        if (shouldFailScreenshot) throw StateError('capture failed');
        resolvedLinkedIds.add(linkedId);
        return null;
      }

      final userActivityService = _SpyUserActivityService();
      addTearDown(userActivityService.dispose);

      await _pumpReadyMyBeamerApp(
        tester,
        app: MyBeamerApp(
          navService: mockNavService,
          userActivityService: userActivityService,
          linkedIdResolver: () async => 'linked-entry',
          createTextEntryAction: recordCreation,
          createTaskAction: recordCreation,
          captureScreenshotAction: captureScreenshot,
        ),
      );

      final commandContext = tester.element(find.byType(ZoomWrapper));
      final commandController = AppCommandControllerProvider.of(
        commandContext,
      );
      final messages = AppLocalizations.of(commandContext)!;

      for (final id in const [
        AppCommandId.navigateDailyOs,
        AppCommandId.navigateProjects,
        AppCommandId.navigateHabits,
        AppCommandId.navigateDashboards,
        AppCommandId.navigateEvents,
      ]) {
        expect(commandController.isAvailable(commandContext, id), isFalse);
      }
      dailyOsEnabled = true;
      projectsEnabled = true;
      habitsEnabled = true;
      dashboardsEnabled = true;
      eventsEnabled = true;

      Future<void> openAndClose(AppCommandId id, String title) async {
        expect(commandController.isAvailable(commandContext, id), isTrue);
        final invocation = commandController.invoke(commandContext, id);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(title), findsWidgets);
        Navigator.of(tester.element(find.text(title).first)).pop();
        await tester.pump();
        expect(await invocation, isTrue);
      }

      await openAndClose(
        AppCommandId.openCommandPalette,
        messages.commandPaletteTitle,
      );
      await openAndClose(
        AppCommandId.openShortcutHelp,
        messages.keyboardShortcutsTitle,
      );

      for (final id in const [
        AppCommandId.createTextEntry,
        AppCommandId.createTask,
        AppCommandId.captureScreenshot,
      ]) {
        expect(await commandController.invoke(commandContext, id), isTrue);
      }
      expect(resolvedLinkedIds, const [
        'linked-entry',
        'linked-entry',
        'linked-entry',
      ]);

      for (final entry in navIndexes.entries) {
        expect(
          await commandController.invoke(commandContext, entry.key),
          isTrue,
        );
        verify(() => mockNavService.tapIndex(entry.value)).called(1);
      }
      verifyNever(() => registeredNavService.tapIndex(any()));

      final container = ProviderScope.containerOf(commandContext);
      expect(container.read(zoomControllerProvider), defaultZoomScale);
      expect(
        await commandController.invoke(commandContext, AppCommandId.zoomIn),
        isTrue,
      );
      expect(container.read(zoomControllerProvider), 1.1);
      expect(
        await commandController.invoke(commandContext, AppCommandId.zoomOut),
        isTrue,
      );
      expect(container.read(zoomControllerProvider), defaultZoomScale);
      container.read(zoomControllerProvider.notifier).zoomIn();
      expect(
        await commandController.invoke(commandContext, AppCommandId.resetZoom),
        isTrue,
      );
      expect(container.read(zoomControllerProvider), defaultZoomScale);

      shouldFailScreenshot = true;
      expect(
        await commandController.invoke(
          commandContext,
          AppCommandId.captureScreenshot,
        ),
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('AppScreen lockdown mode', () {
    CategoryDefinition category(String id, String name) => CategoryDefinition(
      id: id,
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      vectorClock: null,
      private: false,
      active: true,
    );

    /// Pumps the desktop shell on the Tasks tab with the lockdown options
    /// pinned to [categories]; returns the shell's provider container.
    Future<ProviderContainer> pumpLockdownShell(
      WidgetTester tester,
      MockNavService mockNavService, {
      required List<CategoryDefinition> categories,
    }) async {
      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(0),
        isProjectsEnabled: () => true,
        isDailyOsEnabled: () => true,
        isHabitsEnabled: () => true,
        isDashboardsEnabled: () => true,
      );
      when(() => mockNavService.index).thenReturn(0);
      when(() => mockNavService.journalIndex).thenReturn(5);
      when(() => mockNavService.isTabAllowed(any())).thenReturn(true);
      when(() => mockNavService.setIndex(any())).thenReturn(null);
      when(
        () => mockNavService.resetTabRootWithinTab(any()),
      ).thenReturn(null);
      await _registerAppScreenGetIt(mockNavService);
      getIt.registerSingleton<EntitiesCacheService>(
        MockEntitiesCacheService(),
      );
      addTearDown(tearDownTestGetIt);

      await _pumpAppScreen(
        tester,
        navService: mockNavService,
        viewportSize: _desktopViewportSize,
        extraOverrides: [
          lockdownCategoryOptionsProvider.overrideWith((ref) {
            final lockdown = ref.watch(lockdownControllerProvider);
            return categories.where((c) => lockdown.allows(c.id)).toList();
          }),
        ],
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(AppScreen)),
      );
    }

    testWidgets(
      'picking a category from the logo menu strips the rail down to Tasks '
      'and Logbook and resets both tabs; exiting restores everything',
      (tester) async {
        final mockNavService = MockNavService();
        final container = await pumpLockdownShell(
          tester,
          mockNavService,
          categories: [category('work', 'Work'), category('health', 'Health')],
        );

        // Full rail before lockdown.
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Habits'), findsOneWidget);
        expect(find.byType(ContactSupportRow), findsOneWidget);
        expect(find.text('Work'), findsNothing);

        await tester.tap(find.byKey(desktopSidebarLogoMenuTriggerKey));
        await tester.pumpAndSettle();
        expect(find.text('Lock to a category'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Health'), findsOneWidget);

        await tester.tap(find.byKey(const Key('lockdown-menu-category-work')));
        await tester.pumpAndSettle();

        expect(container.read(lockdownControllerProvider).categoryIds, {
          'work',
        });
        final sidebar = tester.widget<DesktopNavigationSidebar>(
          find.byType(DesktopNavigationSidebar),
        );
        expect(
          sidebar.destinations.map((d) => d.label).toList(),
          ['Tasks', 'Habits', 'Insights', 'Logbook'],
        );
        expect(sidebar.destinations.first.expandedChildBuilder, isNull);
        expect(sidebar.settingsDestination, isNull);
        expect(sidebar.aboveSettings, isNull);
        expect(sidebar.footerBand, isNull);
        expect(find.text('Settings'), findsNothing);
        expect(find.text('DailyOS'), findsNothing);
        expect(find.text('Projects'), findsNothing);
        expect(find.byType(ContactSupportRow), findsNothing);
        expect(find.byType(SidebarSavedTaskFilters), findsNothing);
        // The navigation guard covers shortcuts, the palette and path beams,
        // and is keyed by delegate so a flag flip cannot shift it.
        final allowed =
            verify(
                  () => mockNavService.allowedTabDelegates = captureAny(),
                ).captured.single
                as Set<BeamerDelegate>?;
        expect(allowed, {
          mockNavService.tasksDelegate,
          mockNavService.journalDelegate,
          mockNavService.habitsDelegate,
          mockNavService.dashboardsDelegate,
          mockNavService.goalsDelegate,
        });
        // Every surviving tab was reset to its root without being activated.
        for (final delegate in allowed!) {
          verify(
            () => mockNavService.resetTabRootWithinTab(delegate),
          ).called(1);
        }
        verifyNever(() => mockNavService.setTabRoot(any()));
        verifyNever(() => mockNavService.setIndex(any()));

        // A rail tap maps back to the full (content-stack) index.
        await tester.tap(find.text('Logbook'));
        await tester.pump();
        verify(() => mockNavService.tapIndex(5)).called(1);

        // The menu now offers only the locked category and the exit.
        await tester.tap(find.byKey(desktopSidebarLogoMenuTriggerKey));
        await tester.pumpAndSettle();
        expect(find.text('Locked down'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Health'), findsNothing);

        await tester.tap(find.byKey(const Key('lockdown-menu-clear')));
        await tester.pumpAndSettle();

        expect(container.read(lockdownControllerProvider).isActive, isFalse);
        verify(() => mockNavService.allowedTabDelegates = null).called(1);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('DailyOS'), findsOneWidget);
        expect(find.byType(ContactSupportRow), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'entering lockdown from a hidden tab switches to Tasks first',
      (tester) async {
        final mockNavService = MockNavService();
        final container = await pumpLockdownShell(
          tester,
          mockNavService,
          categories: [category('work', 'Work')],
        );
        // Projects is active: the guard reports it as not allowed.
        when(() => mockNavService.index).thenReturn(2);
        when(() => mockNavService.isTabAllowed(2)).thenReturn(false);

        container
            .read(lockdownControllerProvider.notifier)
            .lockToCategory(
              'work',
            );
        await tester.pumpAndSettle();

        verify(() => mockNavService.setIndex(0)).called(1);
        final reset = verify(
          () => mockNavService.resetTabRootWithinTab(captureAny()),
        ).captured;
        expect(reset, hasLength(5));
        expect(reset, contains(mockNavService.tasksDelegate));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}

class _ArbitraryLocation extends BeamLocation<BeamState> {
  _ArbitraryLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => const [
    BeamPage(key: ValueKey('arbitrary'), child: SizedBox.shrink()),
  ];

  @override
  List<Pattern> get pathPatterns => ['*'];
}

class _StubSavedTaskFiltersController extends SavedTaskFiltersController {
  _StubSavedTaskFiltersController(this._seed);
  final List<SavedTaskFilter> _seed;

  @override
  Future<List<SavedTaskFilter>> build() async => _seed;
}

/// A [PaneWidthController] that delegates [toggleSidebarCollapsed] and
/// [updateSidebarWidth] to spy callbacks so tests can verify the lambdas
/// wired in the desktop layout builder of [AppScreen].
class _SpyPaneWidthController extends PaneWidthController {
  _SpyPaneWidthController({
    this.onToggle,
    this.onDrag,
  });

  final VoidCallback? onToggle;
  final ValueChanged<double>? onDrag;

  @override
  PaneWidths build() => const PaneWidths();

  @override
  void toggleSidebarCollapsed() => onToggle?.call();

  @override
  void updateSidebarWidth(double delta) => onDrag?.call(delta);
}

/// Keeps ready-app tests focused on their feature rather than preference
/// hydration. A null value intentionally follows the platform locale.
class _FollowSystemManualLanguageController extends ManualLanguageController {
  @override
  ManualLanguage? build() => null;
}

/// An [OnboardingWelcomeCadence] that records [recordShown] / [markCompleted]
/// invocations instead of touching `SettingsDb`, so tests can assert
/// `_showOnboardingWelcome`'s wiring without needing a real `SettingsDb`.
class _CountingOnboardingWelcomeCadence extends OnboardingWelcomeCadence {
  _CountingOnboardingWelcomeCadence({this.onRecordShown, this.onMarkCompleted});

  final void Function()? onRecordShown;
  final void Function()? onMarkCompleted;

  @override
  Future<void> recordShown() async => onRecordShown?.call();

  @override
  Future<void> markCompleted() async => onMarkCompleted?.call();
}

/// Counts `recordShown` without touching SettingsDb — proves the Daily OS
/// onboarding auto-show arm ran.
class _CountingDailyOsOnboardingCadence extends DailyOsOnboardingCadence {
  _CountingDailyOsOnboardingCadence({this.onRecordShown});

  final void Function()? onRecordShown;

  @override
  Future<void> recordShown() async => onRecordShown?.call();
}

class _CountingDailyOsOnboardingSessionController
    extends DailyOsOnboardingSessionController {
  int startCount = 0;

  @override
  DailyOsOnboardingSession start({
    required DateTime targetDate,
    String? sessionId,
  }) {
    startCount++;
    return super.start(
      targetDate: targetDate,
      sessionId: sessionId,
    );
  }
}

/// A [WhatsNewController] with no unseen releases, used so the What's New modal
/// takes its empty ("You're all caught up!") branch — enough to prove the
/// `shouldAutoShowWhatsNew` data(true) arm opened the modal.
class _EmptyWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async => const WhatsNewState();
}

/// Counts [updateActivity] calls so the [MyBeamerApp] pointer listeners can be
/// asserted on.
class _SpyUserActivityService extends UserActivityService {
  int updateCount = 0;

  @override
  void updateActivity() {
    updateCount++;
    super.updateActivity();
  }
}

/// A running-timer journal entry so the desktop sidebar's TimeService stream
/// reports `hasTimer == true`.
final JournalEntity _runningTimerEntry = JournalEntity.journalEntry(
  meta: Metadata(
    id: 'running-timer',
    createdAt: DateTime(2024, 3, 15, 10),
    updatedAt: DateTime(2024, 3, 15, 10),
    dateFrom: DateTime(2024, 3, 15, 10),
    dateTo: DateTime(2024, 3, 15, 10, 5),
  ),
);

/// A single unseen release used to seed [_UnseenToSeenWhatsNewController] so
/// that its first state genuinely has `hasUnseenRelease == true`.
final _unseenWhatsNewContent = WhatsNewContent(
  release: WhatsNewRelease(
    version: '0.9.999',
    date: DateTime(2026, 1, 7),
    title: 'Test Release',
    folder: '0.9.999',
  ),
  headerMarkdown: '# Test Release',
  sections: const ['## Feature'],
);

/// A [WhatsNewController] that starts with an unseen release
/// (`hasUnseenRelease == true`) and then transitions to seen
/// (`hasUnseenRelease == false`), which drives the
/// `prevHasUnseen && !nextHasUnseen` branch of the listener in [AppScreen].
class _UnseenToSeenWhatsNewController extends WhatsNewController {
  var _firstBuild = true;

  @override
  Future<WhatsNewState> build() async {
    if (_firstBuild) {
      _firstBuild = false;
      // Schedule the unseen -> seen transition on a real (1ms) timer rather
      // than a microtask: a timer is guaranteed to fire *after* this build's
      // future resolves, so the listener reliably observes
      // AsyncData(unseen) -> AsyncData(seen) instead of a racy ordering.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1), () {
          if (ref.mounted) {
            state = const AsyncData(WhatsNewState());
          }
        }),
      );
      // First state has an unseen release so the later transition to the empty
      // (all-seen) state is a real prevHasUnseen=true -> nextHasUnseen=false.
      return WhatsNewState(unseenContent: [_unseenWhatsNewContent]);
    }
    return const WhatsNewState();
  }
}

/// A [WhatsNewController] that stably reports an unseen release and never
/// transitions to seen. The AppScreen listener invalidates the onboarding
/// gates only on a `prevHasUnseen && !nextHasUnseen` transition; by never
/// producing one, this keeps each onboarding side effect single-shot. Pinning
/// it makes these tests independent of What's New state leaked from earlier
/// files in a bundled `very_good test` run, where extra transitions would
/// otherwise re-invalidate the providers.
class _StableUnseenWhatsNewController extends WhatsNewController {
  @override
  Future<WhatsNewState> build() async =>
      WhatsNewState(unseenContent: [_unseenWhatsNewContent]);
}
