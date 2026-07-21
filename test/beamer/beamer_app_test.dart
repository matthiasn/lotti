import 'dart:async';
import 'dart:io' show Platform;

import 'package:beamer/beamer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/sidebar_wake_queue.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_sidebar_entry.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/sidebar_calendar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/settings/state/zoom_controller.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_badge.dart';
import 'package:lotti/features/settings/ui/pages/outbox/outbox_trailing_badge.dart';
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
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:lotti/widgets/misc/sidebar_activity_summary.dart';
import 'package:lotti/widgets/misc/sidebar_audio_recording_section.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/misc/zoom_wrapper.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
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
  BeamerDelegate? settingsDelegate,
}) async {
  final tasksDelegate = await _createEmptyDelegate('/tasks');
  final projectsDelegate = await _createEmptyDelegate('/projects');
  final calendarDelegate = await _createEmptyDelegate('/calendar');
  final habitsDelegate = await _createEmptyDelegate('/habits');
  final dashboardsDelegate = await _createEmptyDelegate('/dashboards');
  final journalDelegate = await _createEmptyDelegate('/journal');
  final eventsDelegate = await _createEmptyDelegate('/events');
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

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);

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
        expect(find.byType(OutboxTrailingBadge), findsOneWidget);
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
      expect((icon as Icon).icon, Icons.list_outlined);
      expect(activeIcon, isA<Icon>());
      expect((activeIcon! as Icon).icon, Icons.list_rounded);

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
      expect((icon as Icon).icon, Icons.list_outlined);
      expect(activeIcon, isA<Icon>());
      expect((activeIcon as Icon).icon, Icons.list_rounded);

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

      final divider = find.byType(ResizableDivider);
      expect(divider, findsOneWidget);

      // Perform a horizontal drag on the divider.
      await tester.drag(divider, const Offset(30, 0));
      await tester.pump();

      // At least one delta was reported to updateSidebarWidth.
      expect(deltas, isNotEmpty);

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
      var projectsEnabled = false;
      var habitsEnabled = false;
      var dashboardsEnabled = false;
      var eventsEnabled = false;
      await _stubNavService(
        mockNavService,
        indexStream: const Stream<int>.empty(),
        isProjectsEnabled: () => projectsEnabled,
        isDailyOsEnabled: () => true,
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
        AppCommandId.navigateProjects,
        AppCommandId.navigateHabits,
        AppCommandId.navigateDashboards,
        AppCommandId.navigateEvents,
      ]) {
        expect(commandController.isAvailable(commandContext, id), isFalse);
      }
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
    required DailyOsOnboardingOrigin origin,
    required DateTime targetDate,
    String? sessionId,
  }) {
    startCount++;
    return super.start(
      origin: origin,
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
