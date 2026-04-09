import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/misc/time_recording_indicator.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/nav_bar/nav_bar.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../mocks/sync_config_test_mocks.dart';
import '../widget_test_utils.dart';

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
        child: AppScreen(enableBottomNavSelectionAnimation: false),
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

  when(() => navService.getIndexStream()).thenAnswer((_) => indexStream);
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
}

Future<void> _pumpAppScreen(
  WidgetTester tester, {
  required MockNavService navService,
  MockJournalDb? journalDb,
}) async {
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

      await _pumpAppScreen(tester, navService: mockNavService);

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

      await _pumpAppScreen(tester, navService: mockNavService);
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
    testWidgets('uses design-system nav on redesigned tasks tab', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      final mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.watchConfigFlag(enableTasksRedesignFlag),
      ).thenAnswer((_) => Stream.value(true));

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
        journalDb: mockJournalDb,
      );

      expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
      expect(find.byType(DesignSystemNavigationTabBar), findsOneWidget);
      expect(find.byType(SpotifyStyleBottomNavigationBar), findsNothing);
    });

    testWidgets('uses design-system nav on projects tab', (tester) async {
      final mockNavService = MockNavService();
      final mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.watchConfigFlag(enableTasksRedesignFlag),
      ).thenAnswer((_) => Stream.value(false));

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
        journalDb: mockJournalDb,
      );

      expect(find.byType(DesignSystemBottomNavigationBar), findsOneWidget);
      expect(find.byType(SpotifyStyleBottomNavigationBar), findsNothing);
    });

    testWidgets('lifts recording indicators above the design-system nav', (
      tester,
    ) async {
      final mockNavService = MockNavService();
      final mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.watchConfigFlag(enableTasksRedesignFlag),
      ).thenAnswer((_) => Stream.value(false));

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
        journalDb: mockJournalDb,
      );

      final context = tester.element(find.byType(AppScreen));
      final expectedBottom =
          AppScreenConstants.navigationTimeIndicatorBottom +
          DesignSystemBottomNavigationBar.occupiedHeight(context);
      final timeIndicatorPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(TimeRecordingIndicator),
          matching: find.byType(Positioned),
        ),
      );
      final audioIndicatorPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(AudioRecordingIndicator),
          matching: find.byType(Positioned),
        ),
      );

      expect(timeIndicatorPositioned.bottom, expectedBottom);
      expect(audioIndicatorPositioned.bottom, expectedBottom);
    });

    testWidgets('keeps legacy nav on non-migrated tabs', (tester) async {
      final mockNavService = MockNavService();
      final mockJournalDb = MockJournalDb();
      when(
        () => mockJournalDb.watchConfigFlag(enableTasksRedesignFlag),
      ).thenAnswer((_) => Stream.value(true));

      await _stubNavService(
        mockNavService,
        indexStream: Stream.value(5),
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
        journalDb: mockJournalDb,
      );

      expect(find.byType(SpotifyStyleBottomNavigationBar), findsOneWidget);
      expect(find.byType(DesignSystemBottomNavigationBar), findsNothing);
    });
  });
}
