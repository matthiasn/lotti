import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/stub_audio_recorder_controller.dart';
import '../mocks/mocks.dart';
import '../mocks/sync_config_test_mocks.dart';
import '../widget_test_utils.dart';

class _MockUserActivityService extends Mock implements UserActivityService {}

/// Mock AI setup prompt service that always returns false (don't show prompt)
class _MockAiSetupPromptService extends AiSetupPromptService {
  @override
  Future<bool> build() async => false;
}

// Simple test location for wrapping AppScreen
class _TestLocation extends BeamLocation<BeamState> {
  _TestLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      const BeamPage(
        key: ValueKey('test'),
        child: AppScreen(),
      ),
    ];
  }

  @override
  List<Pattern> get pathPatterns => ['/'];
}

// Empty location for nav delegates
class _EmptyLocation extends BeamLocation<BeamState> {
  _EmptyLocation(super.routeInformation);

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      const BeamPage(
        key: ValueKey('empty'),
        child: SizedBox.shrink(),
      ),
    ];
  }

  @override
  List<Pattern> get pathPatterns => ['*'];
}

Future<BeamerDelegate> _createEmptyDelegate(String initialPath) async {
  final delegate = BeamerDelegate(
    setBrowserTabTitle: false,
    initialPath: initialPath,
    locationBuilder: (routeInformation, _) => _EmptyLocation(routeInformation),
  );
  addTearDown(delegate.dispose);
  await delegate.setNewRoutePath(
    RouteInformation(uri: Uri.parse(initialPath)),
  );
  return delegate;
}

Future<MockNavService> _stubNavService() async {
  final mockNav = MockNavService();
  final indexStream = Stream<int>.value(0).asBroadcastStream();
  when(mockNav.getIndexStream).thenAnswer((_) => indexStream);
  when(() => mockNav.isProjectsPageEnabled).thenReturn(false);
  when(() => mockNav.isDailyOsPageEnabled).thenReturn(true);
  when(() => mockNav.isHabitsPageEnabled).thenReturn(true);
  when(() => mockNav.isDashboardsPageEnabled).thenReturn(true);
  when(() => mockNav.isEventsPageEnabled).thenReturn(false);
  when(() => mockNav.tasksDelegate).thenReturn(
    await _createEmptyDelegate('/tasks'),
  );
  when(() => mockNav.calendarDelegate).thenReturn(
    await _createEmptyDelegate('/calendar'),
  );
  when(() => mockNav.habitsDelegate).thenReturn(
    await _createEmptyDelegate('/habits'),
  );
  when(() => mockNav.dashboardsDelegate).thenReturn(
    await _createEmptyDelegate('/dashboards'),
  );
  when(() => mockNav.journalDelegate).thenReturn(
    await _createEmptyDelegate('/journal'),
  );
  when(() => mockNav.settingsDelegate).thenReturn(
    await _createEmptyDelegate('/settings'),
  );
  when(() => mockNav.currentPath).thenReturn('/');
  when(() => mockNav.isDesktopMode).thenReturn(false);
  when(
    () => mockNav.desktopSelectedTaskId,
  ).thenReturn(ValueNotifier<String?>(null));
  when(() => mockNav.tapIndex(any())).thenReturn(null);
  return mockNav;
}

/// Registers everything AppScreen needs in GetIt through the centralized
/// helper: the test-specific [db], a zero-count sync DB, the stubbed
/// NavService, and an idle TimeService.
Future<void> _setUpToastGetIt(MockJournalDb db) async {
  final mockNav = await _stubNavService();
  final mockTimeService = MockTimeService();
  when(
    mockTimeService.getStream,
  ).thenAnswer((_) => const Stream<JournalEntity?>.empty());
  when(mockTimeService.getCurrent).thenReturn(null);

  await setUpTestGetIt(
    additionalSetup: () {
      getIt
        ..unregister<JournalDb>()
        ..registerSingleton<JournalDb>(db)
        ..registerSingleton<SyncDatabase>(mockSyncDatabaseWithCount(0))
        ..registerSingleton<NavService>(mockNav)
        ..registerSingleton<TimeService>(mockTimeService);
    },
  );
  ensureThemingServicesRegistered();
}

MockMatrixService _stubMatrixService() {
  final mockMatrix = MockMatrixService();
  // Stub matrix streams used by IncomingVerificationWrapper to avoid
  // null errors.
  when(
    mockMatrix.getIncomingKeyVerificationStream,
  ).thenAnswer((_) => const Stream<KeyVerification>.empty());
  when(
    () => mockMatrix.incomingKeyVerificationRunnerStream,
  ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());
  return mockMatrix;
}

Future<BeamerDelegate> _createAppDelegate() async {
  final delegate = BeamerDelegate(
    setBrowserTabTitle: false,
    locationBuilder: (routeInformation, _) => _TestLocation(routeInformation),
  );
  await delegate.setNewRoutePath(RouteInformation(uri: Uri.parse('/')));
  return delegate;
}

Widget _buildTestRouterApp({
  required BeamerDelegate routerDelegate,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: [
      audioRecorderControllerProvider.overrideWith(
        StubAudioRecorderController.new,
      ),
      ...overrides,
    ],
    child: MaterialApp.router(
      theme: resolveTestTheme(ThemeData.dark(useMaterial3: true)),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerDelegate: routerDelegate,
      routeInformationParser: BeamerParser(),
      backButtonDispatcher: BeamerBackButtonDispatcher(
        delegate: routerDelegate,
      ),
    ),
  );
}

/// Pumps the AppScreen router shell for [loginState] and flushes the first
/// frames with bounded pumps (the toast path is post-frame-callback driven,
/// so no open-ended settling is required).
Future<void> _pumpToastApp(
  WidgetTester tester, {
  required BeamerDelegate routerDelegate,
  required MockMatrixService matrix,
  required MockOutboxService outbox,
  required LoginState loginState,
}) async {
  await tester.pumpWidget(
    _buildTestRouterApp(
      routerDelegate: routerDelegate,
      overrides: [
        matrixServiceProvider.overrideWithValue(matrix),
        loginStateStreamProvider.overrideWith(
          (ref) => Stream<LoginState>.value(loginState),
        ),
        outboxServiceProvider.overrideWithValue(outbox),
        // Prevent Gemini setup prompt from triggering during tests
        aiSetupPromptServiceProvider.overrideWith(
          _MockAiSetupPromptService.new,
        ),
        // Prevent What's New from creating pending timers
        shouldAutoShowWhatsNewProvider.overrideWith(
          (ref) async => false,
        ),
      ],
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Flushes the post-frame callback that shows the toast plus the snack-bar
/// entrance frame after a login-gate event.
Future<void> _pumpGateEvent(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = phoneMediaQueryData.size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
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
  tearDown(() async {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
    await tearDownTestGetIt();
  });

  testWidgets(
    'Shows red toast only when outbox attempts send while logged out',
    (
      tester,
    ) async {
      _usePhoneViewport(tester);

      final db = MockJournalDb();
      when(() => db.watchConfigFlag(any())).thenAnswer((invocation) {
        final flagName = invocation.positionalArguments.first as String;
        const enabledFlags = {
          enableDailyOsPageFlag,
          enableDashboardsPageFlag,
          enableHabitsPageFlag,
          enableMatrixFlag,
        };
        if (flagName == enableTooltipFlag) {
          return Stream<bool>.value(false);
        }
        return Stream<bool>.value(enabledFlags.contains(flagName));
      });
      await _setUpToastGetIt(db);

      final mockMatrix = _stubMatrixService();

      // User activity for MyBeamerApp
      final mockUserActivityService = _MockUserActivityService();
      when(mockUserActivityService.updateActivity).thenReturn(null);

      // Mock OutboxService and provide a stream to emit login-gate events
      final mockOutboxService = MockOutboxService();
      final controller = StreamController<void>.broadcast();
      addTearDown(controller.close);
      when(
        () => mockOutboxService.notLoggedInGateStream,
      ).thenAnswer((_) => controller.stream);

      await _pumpToastApp(
        tester,
        routerDelegate: await _createAppDelegate(),
        matrix: mockMatrix,
        outbox: mockOutboxService,
        loginState: LoginState.loggedOut,
      );

      // On startup while logged out: no toast yet (only on outbox attempt)
      expect(find.byType(SnackBar), findsNothing);

      // Simulate an outbox send attempt getting gated by not-logged-in
      controller.add(null);
      await _pumpGateEvent(tester);

      // Expect a SnackBar with the localized text after the event
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Sync is not logged in'), findsOneWidget);

      // Now simulate login: rebuild with logged in state
      await _pumpToastApp(
        tester,
        routerDelegate: await _createAppDelegate(),
        matrix: mockMatrix,
        outbox: mockOutboxService,
        loginState: LoginState.loggedIn,
      );
      // No additional SnackBar expected now.
      // We tolerate one lingering SnackBar due to UI rebuilds.
    },
  );

  testWidgets('Duplicate login-gate events show only one toast per session', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    final db = MockJournalDb();
    when(() => db.getConfigFlag(any())).thenAnswer((_) async => false);
    when(
      db.watchActiveConfigFlagNames,
    ).thenAnswer((_) => Stream<Set<String>>.value({enableMatrixFlag}));
    await _setUpToastGetIt(db);

    final mockMatrix = _stubMatrixService();

    final mockOutboxService = MockOutboxService();
    final controller = StreamController<void>.broadcast();
    addTearDown(controller.close);
    when(
      () => mockOutboxService.notLoggedInGateStream,
    ).thenAnswer((_) => controller.stream);

    await _pumpToastApp(
      tester,
      routerDelegate: await _createAppDelegate(),
      matrix: mockMatrix,
      outbox: mockOutboxService,
      loginState: LoginState.loggedOut,
    );
    expect(find.byType(SnackBar), findsNothing);

    // Emit two events in the same session
    controller
      ..add(null)
      ..add(null);
    await _pumpGateEvent(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Sync is not logged in'), findsOneWidget);
  });

  testWidgets('Guard resets on login; event after login shows toast again', (
    tester,
  ) async {
    _usePhoneViewport(tester);

    final db = MockJournalDb();
    when(() => db.getConfigFlag(any())).thenAnswer((_) async => false);
    when(
      db.watchActiveConfigFlagNames,
    ).thenAnswer((_) => Stream<Set<String>>.value({enableMatrixFlag}));
    await _setUpToastGetIt(db);

    final mockMatrix = _stubMatrixService();

    final mockOutboxService = MockOutboxService();
    final controller = StreamController<void>.broadcast();
    addTearDown(controller.close);
    when(
      () => mockOutboxService.notLoggedInGateStream,
    ).thenAnswer((_) => controller.stream);

    final routerDelegate = await _createAppDelegate();

    // First build: logged out
    await _pumpToastApp(
      tester,
      routerDelegate: routerDelegate,
      matrix: mockMatrix,
      outbox: mockOutboxService,
      loginState: LoginState.loggedOut,
    );
    expect(find.byType(SnackBar), findsNothing);
    controller.add(null);
    await _pumpGateEvent(tester);
    expect(find.byType(SnackBar), findsOneWidget);

    // Second build: simulate login (resets guard)
    await _pumpToastApp(
      tester,
      routerDelegate: routerDelegate,
      matrix: mockMatrix,
      outbox: mockOutboxService,
      loginState: LoginState.loggedIn,
    );

    // Third build: back to logged out, a new event should show toast again
    await _pumpToastApp(
      tester,
      routerDelegate: routerDelegate,
      matrix: mockMatrix,
      outbox: mockOutboxService,
      loginState: LoginState.loggedOut,
    );
    controller.add(null);
    await _pumpGateEvent(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Sync is not logged in'), findsOneWidget);
  });
}
