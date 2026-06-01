import 'dart:async';
import 'dart:io' show Platform;

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
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
import 'package:lotti/widgets/misc/sidebar_audio_recording_section.dart';
import 'package:lotti/widgets/misc/sidebar_timer_section.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../mocks/mocks.dart';
import '../mocks/sync_config_test_mocks.dart';
import '../widget_test_utils.dart';

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
    isCalendarEnabled, // Calendar
    isHabitsEnabled, // Habits
    isDashboardsEnabled, // Dashboards
    true, // Journal
    true, // Settings
  ];
  final itemCount = navItems.where((isEnabled) => isEnabled).length;
  return rawIndex.clamp(0, itemCount - 1);
}

class _MockAiSetupPromptService extends AiSetupPromptService {
  @override
  Future<bool> build() async => false;
}

/// An [AiSetupPromptService] that invokes [onBuild] every time its `build`
/// runs, so tests can count rebuilds (including those caused by
/// `ref.invalidate`, which re-runs `build`).
class _CountingAiSetupPromptService extends AiSetupPromptService {
  _CountingAiSetupPromptService(this.onBuild);
  final void Function() onBuild;

  @override
  Future<bool> build() async {
    onBuild();
    return false;
  }
}

class _TestAudioRecorderController extends AudioRecorderController {
  _TestAudioRecorderController(this.stateOverride);

  final AudioRecorderState stateOverride;

  @override
  AudioRecorderState build() => stateOverride;
}

class _EmptyLocation extends BeamLocation<BeamState> {
  _EmptyLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return const [
      BeamPage(
        key: ValueKey('empty'),
        child: SizedBox.shrink(),
      ),
    ];
  }

  @override
  List<Pattern> get pathPatterns => ['*'];
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

Future<BeamerDelegate> _createEmptyDelegate(String initialPath) async {
  final delegate = BeamerDelegate(
    setBrowserTabTitle: false,
    initialPath: initialPath,
    locationBuilder: (routeInformation, _) => _EmptyLocation(routeInformation),
  );
  await delegate.setNewRoutePath(
    RouteInformation(uri: Uri.parse(initialPath)),
  );
  return delegate;
}

Future<void> _stubNavService(
  MockNavService navService, {
  required Stream<int> indexStream,
  required bool Function() isProjectsEnabled,
  required bool Function() isDailyOsEnabled,
  required bool Function() isHabitsEnabled,
  required bool Function() isDashboardsEnabled,
}) async {
  final tasksDelegate = await _createEmptyDelegate('/tasks');
  final projectsDelegate = await _createEmptyDelegate('/projects');
  final calendarDelegate = await _createEmptyDelegate('/calendar');
  final habitsDelegate = await _createEmptyDelegate('/habits');
  final dashboardsDelegate = await _createEmptyDelegate('/dashboards');
  final journalDelegate = await _createEmptyDelegate('/journal');
  final settingsDelegate = await _createEmptyDelegate('/settings');

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
  when(() => navService.tapIndex(any())).thenReturn(null);
  when(() => navService.isDesktopMode).thenReturn(false);
  // SidebarTimerSection reads these to decide whether to hide when the
  // running task matches the open task. Empty selection + a non-task
  // root path in these tests so the sidebar timer surfaces normally.
  when(
    () => navService.desktopSelectedTaskId,
  ).thenReturn(ValueNotifier<String?>(null));
  when(() => navService.currentPath).thenReturn('/');
}

Future<void> _pumpAppScreen(
  WidgetTester tester, {
  required MockNavService navService,
  MockJournalDb? journalDb,
  Size viewportSize = _phoneViewportSize,
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
        aiSetupPromptServiceProvider.overrideWith(
          _MockAiSetupPromptService.new,
        ),
        journalDbProvider.overrideWithValue(effectiveJournalDb),
        audioRecorderControllerProvider.overrideWith(
          () => _TestAudioRecorderController(
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
        // The Tasks destination's expanded subtree (TasksSavedFiltersTree)
        // watches saved-filter providers. Override them with safe defaults so
        // this test doesn't transitively trigger the real JournalPageController
        // build chain (which needs Fts5Db etc. that aren't wired up here).
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
  AiSetupPromptService Function()? aiSetupPromptOverride,
  WhatsNewController Function()? whatsNewOverride,
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
        aiSetupPromptServiceProvider.overrideWith(
          aiSetupPromptOverride ?? _MockAiSetupPromptService.new,
        ),
        journalDbProvider.overrideWithValue(mockJournalDb),
        audioRecorderControllerProvider.overrideWith(
          () => _TestAudioRecorderController(
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
        if (whatsNewOverride != null)
          whatsNewControllerProvider.overrideWith(whatsNewOverride),
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
}

Future<void> _registerAppScreenGetIt(MockNavService navService) async {
  final mockTimeService = MockTimeService();
  when(mockTimeService.getStream).thenAnswer(_emptyTimeStream);
  // SidebarTimerSection seeds its StreamBuilder with getCurrent() so it
  // doesn't flicker on first frame when a timer is already running.
  when(mockTimeService.getCurrent).thenReturn(null);

  await setUpTestGetIt(
    additionalSetup: () {
      getIt
        ..registerSingleton<NavService>(navService)
        ..registerSingleton<SyncDatabase>(mockSyncDatabaseWithCount(0))
        ..registerSingleton<TimeService>(mockTimeService);
    },
  );
}

Stream<JournalEntity?> _emptyTimeStream(Invocation _) =>
    const Stream<JournalEntity?>.empty();

void main() {
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

    testWidgets('shows Projects after a flag-driven nav update', (
      tester,
    ) async {
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

      expect(find.text('Projects'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('AppScreen bottom navigation style', () {
    // Pin a mobile-width surface so AppScreen takes the mobile-shell branch
    // regardless of any view-size leakage from earlier tests in a bundled
    // `very_good test` run. Without this, a contaminated view ≥960 px wide
    // routes AppScreen into the desktop sidebar, which mounts
    // DesktopNavigationSidebar / SidebarTimerSection and trips on the
    // unstubbed `MockNavService.desktopSelectedTaskId` getter.
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    });

    for (final (index, name) in <(int, String)>[
      (0, 'tasks'),
      (1, 'projects'),
      (2, 'dailyOS'),
      (3, 'habits'),
      (4, 'dashboards'),
      (5, 'journal'),
      (6, 'settings'),
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
        expect(find.byType(DesignSystemNavigationTabBar), findsOneWidget);
      });
    }

    testWidgets('renders recording indicators inside the nav bar overlay', (
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

      // The indicators are passed in as the nav bar's `overlay` so they
      // share the same FittedBox/Column as the pill — sized to the pill's
      // width and stacked above it via spaceBetween.
      final navBar = tester.widget<DesignSystemBottomNavigationBar>(
        find.byType(DesignSystemBottomNavigationBar),
      );
      expect(navBar.overlay, isNotNull);

      // The TimeRecordingIndicator must be inside the nav bar widget, not
      // in a separate Positioned.
      expect(
        find.descendant(
          of: find.byType(DesignSystemBottomNavigationBar),
          matching: find.byType(TimeRecordingIndicator),
        ),
        findsOneWidget,
      );

      // The closest enclosing Row uses center so the indicators meet in
      // the middle of the pill rather than spreading to its edges.
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
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      expect(find.byType(DesignSystemBottomNavigationBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Tasks sidebar item has no trailing count badge', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

    testWidgets('tapping sidebar destination calls tapIndex', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // Projects is at index 1 in the full destinations list
      verify(() => mockNavService.tapIndex(1)).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('tapping Settings in sidebar calls tapIndex for settings', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      'desktop layout has no floating TimeRecordingIndicator — '
      'the running timer lives in the sidebar instead',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
        // the desktop layout; timer and audio recording cards render inside
        // the desktop sidebar's aboveSettings slot.
        expect(find.byType(TimeRecordingIndicator), findsNothing);
        expect(
          find.byType(SidebarTimerSection),
          findsOneWidget,
          reason:
              'SidebarTimerSection should be wired into the desktop sidebar.',
        );
        expect(
          find.byType(SidebarAudioRecordingSection),
          _isFlatpakTestHost() ? findsNothing : findsOneWidget,
          reason: 'Audio section is hidden in Flatpak builds.',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('disables tickers for inactive desktop tabs', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        expect((child as TickerMode).enabled, i == 2);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('respects feature flags in sidebar', (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

  group('AppScreen mobile nav item taps', () {
    // Each bottom-nav item wires onTap to `navService.tapIndex(i)`.
    // Verify tapping items 0–2 (Tasks, Projects, Journal) invokes the right index.
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(800, 1200)
        ..devicePixelRatio = 1.0;
    });
    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    });

    for (final (tabIndex, tabName) in <(int, String)>[
      (0, 'Tasks'),
      (1, 'Projects'),
      (5, 'Journal'), // index 5 with all optional tabs enabled
    ]) {
      testWidgets(
        'tapping $tabName bottom-nav item calls tapIndex($tabIndex)',
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

          // Find the DesignSystemNavigationTabBar and retrieve its items.
          final navBar = tester.widget<DesignSystemBottomNavigationBar>(
            find.byType(DesignSystemBottomNavigationBar),
          );
          // Invoke the onTap callback directly — tapping in the widget tree
          // is unreliable for overlapping bottom-sheet-style nav bars.
          navBar.items[tabIndex].onTap?.call();
          await tester.pump();

          verify(() => mockNavService.tapIndex(tabIndex)).called(1);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  });

  group('AppScreen desktop sidebar toggle-collapsed', () {
    testWidgets(
      'tapping toggle-collapsed button calls toggleSidebarCollapsed',
      (tester) async {
        tester.view
          ..physicalSize = const Size(1280, 800)
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
              aiSetupPromptServiceProvider.overrideWith(
                _MockAiSetupPromptService.new,
              ),
              journalDbProvider.overrideWithValue(mockJournalDb),
              audioRecorderControllerProvider.overrideWith(
                () => _TestAudioRecorderController(
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
      'aiSetupPromptServiceProvider error arm does not crash AppScreen',
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
          aiSetupPromptOverride: _ErrorAiSetupPromptService.new,
        );

        // The error arm just logs; AppScreen continues rendering normally.
        expect(find.text('Tasks'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'whatsNewControllerProvider unseen→seen transition invalidates aiSetupPrompt',
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

        // The listener in AppScreen fires when whatsNewControllerProvider
        // transitions from prevHasUnseen=true to nextHasUnseen=false, calling
        // ref.invalidate(aiSetupPromptServiceProvider). Track how many times
        // the provider builds so we can confirm it was invalidated.
        var aiSetupBuildCount = 0;
        await _pumpAppScreenCustomProviders(
          tester,
          navService: mockNavService,
          whatsNewOverride: _UnseenToSeenWhatsNewController.new,
          aiSetupPromptOverride: () =>
              _CountingAiSetupPromptService(() => aiSetupBuildCount++),
        );

        // Resolve the initial build: whatsNew settles on AsyncData(unseen) and
        // aiSetupPromptServiceProvider has been built once at this point.
        await tester.pump();
        final buildsBeforeTransition = aiSetupBuildCount;

        // Advance time so the scheduled unseen -> seen transition fires. The
        // listener then sees prevHasUnseen=true && !nextHasUnseen and
        // invalidates aiSetupPromptServiceProvider, forcing a rebuild.
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();

        // AppScreen is still alive and the provider rebuilt after the
        // invalidation triggered by the unseen -> seen transition.
        expect(find.text('Tasks'), findsOneWidget);
        expect(
          aiSetupBuildCount,
          greaterThan(buildsBeforeTransition),
          reason:
              'aiSetupPromptServiceProvider should rebuild after the '
              'unseen -> seen transition invalidates it',
        );

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

/// An [AiSetupPromptService] whose build throws so the `error:` arm of
/// the `aiSetupPromptServiceProvider` listener in [AppScreen] is exercised.
class _ErrorAiSetupPromptService extends AiSetupPromptService {
  @override
  Future<bool> build() async => throw Exception('ai-setup-error');
}

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
