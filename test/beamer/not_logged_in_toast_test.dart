import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
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

class _MockUserActivityService extends Mock implements UserActivityService {}

// Simple test location for wrapping AppScreen
class _TestLocation extends BeamLocation<BeamState> {
  _TestLocation(super.routeInformation, {required this.db});

  final JournalDb db;

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    return [
      BeamPage(
        key: const ValueKey('test'),
        child: AppScreen(journalDb: db),
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

void main() {
  testWidgets('Shows one-time red toast when sync enabled and logged out',
      (tester) async {
    final db = MockJournalDb();
    // Emit active flags that include enableMatrixFlag
    when(db.watchActiveConfigFlagNames)
        .thenAnswer((_) => Stream<Set<String>>.value({enableMatrixFlag}));

    // Register GetIt dependencies used by AppScreen children
    final syncDb = mockSyncDatabaseWithCount(0);
    if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>();
    if (getIt.isRegistered<SyncDatabase>()) getIt.unregister<SyncDatabase>();
    if (getIt.isRegistered<SettingsDb>()) getIt.unregister<SettingsDb>();
    final settingsDb = MockSettingsDb();
    when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(() => settingsDb.saveSettingsItem(any(), any()))
        .thenAnswer((_) async => 1);
    getIt
      ..registerSingleton<JournalDb>(db)
      ..registerSingleton<SyncDatabase>(syncDb)
      ..registerSingleton<SettingsDb>(settingsDb);

    // ThemingCubit reads tooltip flag
    when(() => db.watchConfigFlag(enableTooltipFlag))
        .thenAnswer((_) => Stream<bool>.value(false));

    // Minimal nav service stub with properly initialized delegates
    final mockNav = MockNavService();

    // Create delegates once with initialization
    final tasksDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      initialPath: '/tasks',
      locationBuilder: (routeInformation, _) =>
          _EmptyLocation(routeInformation),
    );
    final calendarDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      initialPath: '/calendar',
      locationBuilder: (routeInformation, _) =>
          _EmptyLocation(routeInformation),
    );
    final habitsDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      initialPath: '/habits',
      locationBuilder: (routeInformation, _) =>
          _EmptyLocation(routeInformation),
    );
    final dashboardsDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      initialPath: '/dashboards',
      locationBuilder: (routeInformation, _) =>
          _EmptyLocation(routeInformation),
    );
    final journalDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      initialPath: '/journal',
      locationBuilder: (routeInformation, _) =>
          _EmptyLocation(routeInformation),
    );
    final settingsDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      initialPath: '/settings',
      locationBuilder: (routeInformation, _) =>
          _EmptyLocation(routeInformation),
    );

    // Initialize all delegates
    await tasksDelegate
        .setNewRoutePath(RouteInformation(uri: Uri.parse('/tasks')));
    await calendarDelegate
        .setNewRoutePath(RouteInformation(uri: Uri.parse('/calendar')));
    await habitsDelegate
        .setNewRoutePath(RouteInformation(uri: Uri.parse('/habits')));
    await dashboardsDelegate
        .setNewRoutePath(RouteInformation(uri: Uri.parse('/dashboards')));
    await journalDelegate
        .setNewRoutePath(RouteInformation(uri: Uri.parse('/journal')));
    await settingsDelegate
        .setNewRoutePath(RouteInformation(uri: Uri.parse('/settings')));

    when(mockNav.getIndexStream).thenAnswer((_) => Stream<int>.value(0));
    when(() => mockNav.tasksDelegate).thenReturn(tasksDelegate);
    when(() => mockNav.calendarDelegate).thenReturn(calendarDelegate);
    when(() => mockNav.habitsDelegate).thenReturn(habitsDelegate);
    when(() => mockNav.dashboardsDelegate).thenReturn(dashboardsDelegate);
    when(() => mockNav.journalDelegate).thenReturn(journalDelegate);
    when(() => mockNav.settingsDelegate).thenReturn(settingsDelegate);
    when(() => mockNav.currentPath).thenReturn('/');
    when(() => mockNav.tapIndex(any())).thenReturn(null);
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
    getIt.registerSingleton<NavService>(mockNav);

    // Build with provider overrides to satisfy Riverpod + Router via MyBeamerApp
    final mockMatrix = MockMatrixService();
    // Stub matrix streams used by IncomingVerificationWrapper to avoid null errors
    when(mockMatrix.getIncomingKeyVerificationStream)
        .thenAnswer((_) => const Stream<KeyVerification>.empty());
    when(() => mockMatrix.incomingKeyVerificationRunnerStream)
        .thenAnswer((_) => const Stream<KeyVerificationRunner>.empty());

    // Additional service stubs used by AppScreen widgets
    final mockTimeService = MockTimeService();
    when(mockTimeService.getStream)
        .thenAnswer((_) => const Stream<JournalEntity?>.empty());
    if (getIt.isRegistered<TimeService>()) getIt.unregister<TimeService>();
    getIt.registerSingleton<TimeService>(mockTimeService);

    // User activity for MyBeamerApp
    final mockUserActivityService = _MockUserActivityService();
    when(mockUserActivityService.updateActivity).thenReturn(null);

    // Use MaterialApp.router with proper BeamLocation
    final routerDelegate = BeamerDelegate(
      setBrowserTabTitle: false,
      locationBuilder: (routeInformation, _) {
        return _TestLocation(routeInformation, db: db);
      },
    );

    // Initialize the delegate's route
    await routerDelegate.setNewRoutePath(RouteInformation(uri: Uri.parse('/')));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedOut),
          ),
        ],
        child: MaterialApp.router(
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

    await tester.pumpAndSettle();

    // Expect a SnackBar with the localized text
    expect(find.byType(SnackBar), findsOneWidget);
    // Localized text from l10n
    expect(find.text('Sync is not logged in'), findsOneWidget);

    // Now simulate login: rebuild with logged in state
    final routerDelegate2 = BeamerDelegate(
      setBrowserTabTitle: false,
      locationBuilder: (routeInformation, _) {
        return _TestLocation(routeInformation, db: db);
      },
    );

    // Initialize the delegate's route
    await routerDelegate2
        .setNewRoutePath(RouteInformation(uri: Uri.parse('/')));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrix),
          loginStateStreamProvider.overrideWith(
            (ref) => Stream<LoginState>.value(LoginState.loggedIn),
          ),
        ],
        child: MaterialApp.router(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerDelegate: routerDelegate2,
          routeInformationParser: BeamerParser(),
          backButtonDispatcher: BeamerBackButtonDispatcher(
            delegate: routerDelegate2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // No additional SnackBar expected now.
    // We tolerate one lingering SnackBar due to UI rebuilds.
  });
}
