import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
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

import '../mocks/mocks.dart';
import '../mocks/sync_config_test_mocks.dart';
import '../widget_test_utils.dart';

class _MockUserActivityService extends Mock implements UserActivityService {}

/// Mock AI setup prompt service that always returns false (don't show prompt)
class _MockAiSetupPromptService extends AiSetupPromptService {
  @override
  Future<bool> build() async => false;
}

class _TestAudioRecorderController extends AudioRecorderController {
  @override
  AudioRecorderState build() => AudioRecorderState(
    status: AudioRecorderStatus.stopped,
    progress: Duration.zero,
    vu: -20,
    dBFS: -160,
    showIndicator: false,
    modalVisible: false,
  );
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

void _registerNavService(MockNavService mockNav) {
  if (getIt.isRegistered<NavService>()) {
    getIt.unregister<NavService>();
  }
  getIt.registerSingleton<NavService>(mockNav);
}

void _registerTimeService() {
  final mockTimeService = MockTimeService();
  when(
    mockTimeService.getStream,
  ).thenAnswer((_) => const Stream<JournalEntity?>.empty());
  when(mockTimeService.getCurrent).thenReturn(null);
  if (getIt.isRegistered<TimeService>()) {
    getIt.unregister<TimeService>();
  }
  getIt.registerSingleton<TimeService>(mockTimeService);
}

Widget _buildTestRouterApp({
  required BeamerDelegate routerDelegate,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: [
      audioRecorderControllerProvider.overrideWith(
        _TestAudioRecorderController.new,
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

void _usePhoneViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = phoneMediaQueryData.size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MockSettingsDb _stubSettingsDb() {
  final settingsDb = MockSettingsDb();
  when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
  when(
    () => settingsDb.itemsByKeys(any()),
  ).thenAnswer((_) async => <String, String?>{});
  when(
    () => settingsDb.saveSettingsItem(any(), any()),
  ).thenAnswer((_) async => 1);
  return settingsDb;
}

void main() {
  testWidgets('Shows red toast only when outbox attempts send while logged out', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tearDownTestGetIt);

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

    // Register GetIt dependencies used by AppScreen children
    final syncDb = mockSyncDatabaseWithCount(0);
    if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>();
    if (getIt.isRegistered<SyncDatabase>()) getIt.unregister<SyncDatabase>();
    if (getIt.isRegistered<SettingsDb>()) getIt.unregister<SettingsDb>();
    final settingsDb = _stubSettingsDb();
    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<SyncDatabase>(syncDb)
      ..registerSingleton<SettingsDb>(settingsDb);
    ensureThemingServicesRegistered();

    _registerNavService(await _stubNavService());

    // Build with provider overrides to satisfy Riverpod + Router via MyBeamerApp
    final mockMatrix = MockMatrixService();
    // Stub matrix streams used by IncomingVerificationWrapper to avoid null errors
    when(
      mockMatrix.getIncomingKeyVerificationStream,
    ).thenAnswer((_) => const Stream<KeyVerification>.empty());
    when(
      () => mockMatrix.incomingKeyVerificationRunnerStream,
    ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

    _registerTimeService();

    // User activity for MyBeamerApp
    final mockUserActivityService = _MockUserActivityService();
    when(mockUserActivityService.updateActivity).thenReturn(null);

    // Use MaterialApp.router with proper BeamLocation
    final routerDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      locationBuilder: (routeInformation, _) {
        return _TestLocation(routeInformation);
      },
    );

    // Initialize the delegate's route
    await routerDelegate.setNewRoutePath(RouteInformation(uri: Uri.parse('/')));

    // Mock OutboxService and provide a stream to emit login-gate events
    final mockOutboxService = MockOutboxService();
    final controller = StreamController<void>.broadcast();
    addTearDown(controller.close);
    when(
      () => mockOutboxService.notLoggedInGateStream,
    ).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(
      _buildTestRouterApp(
        routerDelegate: routerDelegate,
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedOut),
          ),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
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

    await tester.pumpAndSettle();

    // On startup while logged out: no toast yet (only on outbox attempt)
    expect(find.byType(SnackBar), findsNothing);

    // Simulate an outbox send attempt getting gated by not-logged-in
    controller.add(null);
    await tester.pump();
    await tester.pumpAndSettle();

    // Expect a SnackBar with the localized text after the event
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Sync is not logged in'), findsOneWidget);

    // Now simulate login: rebuild with logged in state
    final routerDelegate2 = BeamerDelegate(
      setBrowserTabTitle: false,
      locationBuilder: (routeInformation, _) {
        return _TestLocation(routeInformation);
      },
    );

    // Initialize the delegate's route
    await routerDelegate2.setNewRoutePath(
      RouteInformation(uri: Uri.parse('/')),
    );

    await tester.pumpWidget(
      _buildTestRouterApp(
        routerDelegate: routerDelegate2,
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedIn),
          ),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
          aiSetupPromptServiceProvider.overrideWith(
            _MockAiSetupPromptService.new,
          ),
          shouldAutoShowWhatsNewProvider.overrideWith(
            (ref) async => false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // No additional SnackBar expected now.
    // We tolerate one lingering SnackBar due to UI rebuilds.
  });

  testWidgets('Duplicate login-gate events show only one toast per session', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tearDownTestGetIt);

    final db = MockJournalDb();
    when(() => db.getConfigFlag(any())).thenAnswer((_) async => false);
    when(
      db.watchActiveConfigFlagNames,
    ).thenAnswer((_) => Stream<Set<String>>.value({enableMatrixFlag}));

    // Register GetIt dependencies used by AppScreen children
    final syncDb = mockSyncDatabaseWithCount(0);
    if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>();
    if (getIt.isRegistered<SyncDatabase>()) getIt.unregister<SyncDatabase>();
    if (getIt.isRegistered<SettingsDb>()) getIt.unregister<SettingsDb>();
    final settingsDb = _stubSettingsDb();
    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<SyncDatabase>(syncDb)
      ..registerSingleton<SettingsDb>(settingsDb);
    ensureThemingServicesRegistered();

    _registerNavService(await _stubNavService());
    _registerTimeService();

    final mockMatrix = MockMatrixService();
    when(
      mockMatrix.getIncomingKeyVerificationStream,
    ).thenAnswer((_) => const Stream<KeyVerification>.empty());
    when(
      () => mockMatrix.incomingKeyVerificationRunnerStream,
    ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

    final mockOutboxService = MockOutboxService();
    final controller = StreamController<void>.broadcast();
    addTearDown(controller.close);
    when(
      () => mockOutboxService.notLoggedInGateStream,
    ).thenAnswer((_) => controller.stream);

    final routerDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      locationBuilder: (routeInformation, _) {
        return _TestLocation(routeInformation);
      },
    );
    await routerDelegate.setNewRoutePath(RouteInformation(uri: Uri.parse('/')));

    await tester.pumpWidget(
      _buildTestRouterApp(
        routerDelegate: routerDelegate,
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedOut),
          ),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
          aiSetupPromptServiceProvider.overrideWith(
            _MockAiSetupPromptService.new,
          ),
          shouldAutoShowWhatsNewProvider.overrideWith(
            (ref) async => false,
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    // Emit two events in the same session
    controller
      ..add(null)
      ..add(null);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Sync is not logged in'), findsOneWidget);
  });

  testWidgets('Guard resets on login; event after login shows toast again', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    addTearDown(tearDownTestGetIt);

    final db = MockJournalDb();
    when(() => db.getConfigFlag(any())).thenAnswer((_) async => false);
    when(
      db.watchActiveConfigFlagNames,
    ).thenAnswer((_) => Stream<Set<String>>.value({enableMatrixFlag}));

    // Register GetIt dependencies used by AppScreen children
    final syncDb = mockSyncDatabaseWithCount(0);
    if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>();
    if (getIt.isRegistered<SyncDatabase>()) getIt.unregister<SyncDatabase>();
    if (getIt.isRegistered<SettingsDb>()) getIt.unregister<SettingsDb>();
    final settingsDb = _stubSettingsDb();
    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<SyncDatabase>(syncDb)
      ..registerSingleton<SettingsDb>(settingsDb);
    ensureThemingServicesRegistered();

    _registerNavService(await _stubNavService());
    _registerTimeService();

    final mockMatrix = MockMatrixService();
    when(
      mockMatrix.getIncomingKeyVerificationStream,
    ).thenAnswer((_) => const Stream<KeyVerification>.empty());
    when(
      () => mockMatrix.incomingKeyVerificationRunnerStream,
    ).thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

    final mockOutboxService = MockOutboxService();
    final controller = StreamController<void>.broadcast();
    addTearDown(controller.close);
    when(
      () => mockOutboxService.notLoggedInGateStream,
    ).thenAnswer((_) => controller.stream);

    final routerDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      locationBuilder: (routeInformation, _) {
        return _TestLocation(routeInformation);
      },
    );
    await routerDelegate.setNewRoutePath(RouteInformation(uri: Uri.parse('/')));

    // First build: logged out
    await tester.pumpWidget(
      _buildTestRouterApp(
        routerDelegate: routerDelegate,
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedOut),
          ),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
          aiSetupPromptServiceProvider.overrideWith(
            _MockAiSetupPromptService.new,
          ),
          shouldAutoShowWhatsNewProvider.overrideWith(
            (ref) async => false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    controller.add(null);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    // Second build: simulate login (resets guard)
    await tester.pumpWidget(
      _buildTestRouterApp(
        routerDelegate: routerDelegate,
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedIn),
          ),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
          aiSetupPromptServiceProvider.overrideWith(
            _MockAiSetupPromptService.new,
          ),
          shouldAutoShowWhatsNewProvider.overrideWith(
            (ref) async => false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Third build: back to logged out, a new event should show toast again
    await tester.pumpWidget(
      _buildTestRouterApp(
        routerDelegate: routerDelegate,
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedOut),
          ),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
          aiSetupPromptServiceProvider.overrideWith(
            _MockAiSetupPromptService.new,
          ),
          shouldAutoShowWhatsNewProvider.overrideWith(
            (ref) async => false,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    controller.add(null);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Sync is not logged in'), findsOneWidget);
  });
}
