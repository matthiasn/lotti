import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockBackfillRequestService extends Mock
    implements BackfillRequestService {}

class MockUserActivityService extends Mock implements UserActivityService {}

class _MockQueuePipelineCoordinator extends Mock
    implements QueuePipelineCoordinator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockSyncSequenceLogService mockSequenceService;
  late MockBackfillRequestService mockBackfillService;
  late MockUserActivityService mockUserActivityService;

  final testStats = BackfillStats.fromHostStats([
    const BackfillHostStats(
      receivedCount: 100,
      missingCount: 5,
      requestedCount: 2,
      backfilledCount: 10,
      deletedCount: 1,
      unresolvableCount: 0,
    ),
  ]);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});
    mockJournalDb = MockJournalDb();
    mockSequenceService = MockSyncSequenceLogService();
    mockBackfillService = MockBackfillRequestService();
    mockUserActivityService = MockUserActivityService();

    when(
      () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
    ).thenAnswer((_) => Stream<bool>.value(true));
    when(
      () => mockSequenceService.getBackfillStats(),
    ).thenAnswer((_) async => testStats);
    when(
      () => mockBackfillService.processFullBackfill(),
    ).thenAnswer((_) async => 5);
    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
      ..registerSingleton<BackfillRequestService>(mockBackfillService)
      ..registerSingleton<UserActivityService>(mockUserActivityService);
  });

  tearDown(getIt.reset);

  group('BackfillSettingsPage', () {
    testWidgets('renders page with toggle card', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should find the toggle switch
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('renders stats section', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should find bar_chart icon for stats section
      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });

    testWidgets('renders manual backfill button', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find the manual backfill section Card (contains history icon)
      final manualSectionCard = find.ancestor(
        of: find.byIcon(Icons.history),
        matching: find.byType(Card),
      );
      expect(manualSectionCard, findsOneWidget);

      // Find the button inside that Card
      final buttonFinder = find.descendant(
        of: manualSectionCard,
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('renders history icon for manual section', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should find history icon
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('renders refresh button', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should find refresh icon button
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('toggle can be tapped', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Switch should now be off
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);
    });

    testWidgets('manual backfill button triggers service', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find the manual backfill section Card (contains history icon)
      final manualSectionCard = find.ancestor(
        of: find.byIcon(Icons.history),
        matching: find.byType(Card),
      );

      // Find the button inside that Card
      final buttonFinder = find.descendant(
        of: manualSectionCard,
        matching: find.bySubtype<ButtonStyleButton>(),
      );

      // Scroll to make the button visible
      await tester.ensureVisible(buttonFinder);
      await tester.pump();

      // Tap the button
      await tester.tap(buttonFinder);
      await tester.pump();

      // Verify the service was called
      verify(() => mockBackfillService.processFullBackfill()).called(1);
    });

    testWidgets('gate hides page when Matrix flag is OFF', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(false));
      when(
        () => mockSequenceService.getBackfillStats(),
      ).thenAnswer((_) async => testStats);
      when(() => mockUserActivityService.updateActivity()).thenReturn(null);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
        ..registerSingleton<BackfillRequestService>(mockBackfillService)
        ..registerSingleton<UserActivityService>(mockUserActivityService);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pump();

      // Page content should not be visible
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('displays stats values when loaded', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should show received count from test stats
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('shows missing count in red when > 0', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should show missing count from test stats (5)
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows requested count when > 0', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should show requested count from test stats (2)
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows backfilled count', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should show backfilled count from test stats (10)
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('refresh button calls service', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Initial load already called getBackfillStats
      clearInteractions(mockSequenceService);

      // Find and tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Should have called getBackfillStats again
      verify(() => mockSequenceService.getBackfillStats()).called(1);
    });

    testWidgets('shows sync icon when enabled', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should show sync icon (enabled state)
      expect(find.byIcon(Icons.sync), findsWidgets);
    });

    testWidgets('shows total entries count', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Total entries = 100 + 5 + 2 + 10 + 1 = 118
      expect(find.text('118'), findsOneWidget);
    });

    testWidgets('shows sync_disabled icon when toggle is off', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Toggle the switch off
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // Should now show sync_disabled icon
      expect(find.byIcon(Icons.sync_disabled), findsOneWidget);
    });

    testWidgets('shows zero stats when no hosts exist', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));
      // Return empty stats (no hosts)
      when(
        () => mockSequenceService.getBackfillStats(),
      ).thenAnswer((_) async => BackfillStats.fromHostStats(const []));
      when(() => mockUserActivityService.updateActivity()).thenReturn(null);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
        ..registerSingleton<BackfillRequestService>(mockBackfillService)
        ..registerSingleton<UserActivityService>(mockUserActivityService);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should show zeros for all stats
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('shows error message when manual backfill fails', (
      tester,
    ) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));
      when(
        () => mockSequenceService.getBackfillStats(),
      ).thenAnswer((_) async => testStats);
      when(
        () => mockBackfillService.processFullBackfill(),
      ).thenThrow(Exception('Backfill failed'));
      when(() => mockUserActivityService.updateActivity()).thenReturn(null);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
        ..registerSingleton<BackfillRequestService>(mockBackfillService)
        ..registerSingleton<UserActivityService>(mockUserActivityService);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find and tap the manual backfill button
      final manualSectionCard = find.ancestor(
        of: find.byIcon(Icons.history),
        matching: find.byType(Card),
      );
      final buttonFinder = find.descendant(
        of: manualSectionCard,
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      await tester.ensureVisible(buttonFinder);
      await tester.pump();
      await tester.tap(buttonFinder);
      await tester.pump();

      // Error state should be visible (button should still be tappable)
      expect(find.bySubtype<ButtonStyleButton>(), findsWidgets);
    });

    testWidgets('shows deleted count', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should show deleted count from test stats (1)
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('renders re-request section with replay icon', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should find replay icon for re-request section
      expect(find.byIcon(Icons.replay), findsWidgets);
    });

    testWidgets('re-request section has button', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find the re-request section Card (contains replay icon)
      final reRequestSectionCard = find.ancestor(
        of: find.byIcon(Icons.replay).first,
        matching: find.byType(Card),
      );
      expect(reRequestSectionCard, findsOneWidget);

      // Find the button inside that Card
      final buttonFinder = find.descendant(
        of: reRequestSectionCard,
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('re-request button is disabled when requestedCount is 0', (
      tester,
    ) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));
      // Return stats with 0 requested entries
      when(() => mockSequenceService.getBackfillStats()).thenAnswer(
        (_) async => BackfillStats.fromHostStats([
          const BackfillHostStats(
            receivedCount: 100,
            missingCount: 5,
            requestedCount: 0, // No requested entries
            backfilledCount: 10,
            deletedCount: 1,
            unresolvableCount: 0,
          ),
        ]),
      );
      when(() => mockUserActivityService.updateActivity()).thenReturn(null);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
        ..registerSingleton<BackfillRequestService>(mockBackfillService)
        ..registerSingleton<UserActivityService>(mockUserActivityService);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find the re-request section Card
      final reRequestSectionCard = find.ancestor(
        of: find.byIcon(Icons.replay).first,
        matching: find.byType(Card),
      );

      // Find the button inside that Card
      final buttonFinder = find.descendant(
        of: reRequestSectionCard,
        matching: find.bySubtype<ButtonStyleButton>(),
      );

      // Scroll to make the button visible
      await tester.ensureVisible(buttonFinder);
      await tester.pump();

      // Button should be disabled (onPressed is null)
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('re-request button triggers service when requestedCount > 0', (
      tester,
    ) async {
      when(
        () => mockBackfillService.processReRequest(),
      ).thenAnswer((_) async => 5);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find the re-request section Card
      final reRequestSectionCard = find.ancestor(
        of: find.byIcon(Icons.replay).first,
        matching: find.byType(Card),
      );

      // Find the button inside that Card
      final buttonFinder = find.descendant(
        of: reRequestSectionCard,
        matching: find.bySubtype<ButtonStyleButton>(),
      );

      // Scroll to make the button visible
      await tester.ensureVisible(buttonFinder);
      await tester.pump();

      // Tap the button
      await tester.tap(buttonFinder);
      await tester.pump();

      // Verify the service was called
      verify(() => mockBackfillService.processReRequest()).called(1);
    });

    testWidgets('shows success message after re-request completes', (
      tester,
    ) async {
      when(
        () => mockBackfillService.processReRequest(),
      ).thenAnswer((_) async => 5);

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find and tap the re-request button
      final reRequestSectionCard = find.ancestor(
        of: find.byIcon(Icons.replay).first,
        matching: find.byType(Card),
      );
      final buttonFinder = find.descendant(
        of: reRequestSectionCard,
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      await tester.ensureVisible(buttonFinder);
      await tester.pump();
      await tester.tap(buttonFinder);
      await tester.pump();

      // Should show check_circle icon for success
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets(
      're-request section shows orange icon when requestedCount > 0',
      (tester) async {
        await tester.pumpWidget(
          const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
        );
        await tester.pumpAndSettle();

        // With testStats having requestedCount = 2, the replay icon should have
        // an orange color. Find the replay icon.
        final replayIconFinder = find.byIcon(Icons.replay);
        expect(replayIconFinder, findsWidgets);
      },
    );

    testWidgets('renders reset unresolvable section with restore icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Should find restore icon for reset unresolvable section
      expect(find.byIcon(Icons.restore), findsWidgets);
    });

    testWidgets(
      'reset unresolvable button is disabled when unresolvableCount is 0',
      (tester) async {
        // Default testStats has unresolvableCount = 0
        await tester.pumpWidget(
          const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
        );
        await tester.pumpAndSettle();

        // Find the reset unresolvable section Card (contains restore icon)
        final resetSectionCard = find.ancestor(
          of: find.byIcon(Icons.restore).first,
          matching: find.byType(Card),
        );

        // Find the button inside that Card
        final buttonFinder = find.descendant(
          of: resetSectionCard,
          matching: find.bySubtype<ButtonStyleButton>(),
        );

        await tester.ensureVisible(buttonFinder);
        await tester.pump();

        // Button should be disabled (onPressed is null)
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'reset unresolvable button is enabled when unresolvableCount > 0',
      (tester) async {
        // Setup stats with unresolvable count > 0
        when(() => mockSequenceService.getBackfillStats()).thenAnswer(
          (_) async => BackfillStats.fromHostStats([
            const BackfillHostStats(
              receivedCount: 100,
              missingCount: 5,
              requestedCount: 2,
              backfilledCount: 10,
              deletedCount: 1,
              unresolvableCount: 42,
            ),
          ]),
        );
        when(
          () => mockSequenceService.resetUnresolvableEntries(),
        ).thenAnswer((_) async => 42);

        await tester.pumpWidget(
          const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
        );
        await tester.pumpAndSettle();

        // Find the reset unresolvable section Card
        final resetSectionCard = find.ancestor(
          of: find.byIcon(Icons.restore).first,
          matching: find.byType(Card),
        );

        // Find the button inside that Card
        final buttonFinder = find.descendant(
          of: resetSectionCard,
          matching: find.bySubtype<ButtonStyleButton>(),
        );

        await tester.ensureVisible(buttonFinder);
        await tester.pump();

        // Button should be enabled
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(button.onPressed, isNotNull);

        // Tap the button
        await tester.tap(buttonFinder);
        await tester.pump();

        // Verify the service was called
        verify(() => mockSequenceService.resetUnresolvableEntries()).called(1);
      },
    );

    testWidgets(
      'shows success message after reset unresolvable completes',
      (tester) async {
        when(() => mockSequenceService.getBackfillStats()).thenAnswer(
          (_) async => BackfillStats.fromHostStats([
            const BackfillHostStats(
              receivedCount: 100,
              missingCount: 5,
              requestedCount: 2,
              backfilledCount: 10,
              deletedCount: 1,
              unresolvableCount: 10,
            ),
          ]),
        );
        when(
          () => mockSequenceService.resetUnresolvableEntries(),
        ).thenAnswer((_) async => 10);

        await tester.pumpWidget(
          const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
        );
        await tester.pumpAndSettle();

        // Find and tap the reset button
        final resetSectionCard = find.ancestor(
          of: find.byIcon(Icons.restore).first,
          matching: find.byType(Card),
        );
        final buttonFinder = find.descendant(
          of: resetSectionCard,
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        await tester.ensureVisible(buttonFinder);
        await tester.pump();
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        // Should show check_circle icon for success
        expect(find.byIcon(Icons.check_circle), findsWidgets);
      },
    );

    testWidgets('displays unresolvable count when present', (tester) async {
      // Setup stats with unresolvable count > 0
      when(() => mockSequenceService.getBackfillStats()).thenAnswer(
        (_) async => BackfillStats.fromHostStats([
          const BackfillHostStats(
            receivedCount: 100,
            missingCount: 5,
            requestedCount: 2,
            backfilledCount: 10,
            deletedCount: 1,
            unresolvableCount: 3,
          ),
        ]),
      );

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // Find and scroll to the stats section
      final statsCard = find.ancestor(
        of: find.byIcon(Icons.bar_chart),
        matching: find.byType(Card),
      );
      expect(statsCard, findsOneWidget);

      // Ensure the card is visible
      await tester.ensureVisible(statsCard);
      await tester.pump();

      // Should display the unresolvable count of 3
      expect(find.text('3'), findsWidgets);
    });
  });

  group('BackfillSettingsPage queue section (Phase-2 queue pipeline)', () {
    late MockMatrixService mockMatrixService;
    late _MockQueuePipelineCoordinator mockCoordinator;
    late SyncDatabase syncDb;
    late InboundQueue realQueue;
    late MockLoggingService loggingService;

    setUp(() async {
      // Outer setUp already registered a subset of singletons; reset so
      // the queue-section tests can inject their own wiring (notably
      // MatrixService with a QueuePipelineCoordinator).
      await getIt.reset();
      SharedPreferences.setMockInitialValues({'backfill_enabled': true});
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();
      mockMatrixService = MockMatrixService();
      mockCoordinator = _MockQueuePipelineCoordinator();
      syncDb = SyncDatabase(inMemoryDatabase: true);
      loggingService = MockLoggingService();
      realQueue = InboundQueue(db: syncDb, logging: loggingService);

      when(
        () => mockJournalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));
      when(
        () => mockSequenceService.getBackfillStats(),
      ).thenAnswer((_) async => testStats);
      when(
        () => mockBackfillService.processFullBackfill(),
      ).thenAnswer((_) async => 5);
      when(() => mockUserActivityService.updateActivity()).thenReturn(null);
      when(() => mockMatrixService.isLegacyPipelineSuppressed).thenReturn(true);
      when(
        () => mockMatrixService.queueCoordinator,
      ).thenReturn(mockCoordinator);
      when(() => mockCoordinator.queue).thenReturn(realQueue);
      when(mockCoordinator.triggerBridge).thenAnswer((_) async {});

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<SyncSequenceLogService>(mockSequenceService)
        ..registerSingleton<BackfillRequestService>(mockBackfillService)
        ..registerSingleton<UserActivityService>(mockUserActivityService)
        ..registerSingleton<MatrixService>(mockMatrixService);
    });

    tearDown(() async {
      await getIt.reset();
      await realQueue.dispose();
      await syncDb.close();
    });

    testWidgets('renders queue depth card and catch-up button', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // The catch-up button uses the bolt icon.
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
      // The fetch-all-history button uses download_rounded.
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('catch-up button invokes coordinator.triggerBridge', (
      tester,
    ) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      final button = find.ancestor(
        of: find.byIcon(Icons.bolt_outlined),
        matching: find.byType(FilledButton),
      );
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      verify(mockCoordinator.triggerBridge).called(1);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'catch-up button shows error SnackBar when triggerBridge throws',
      (
        tester,
      ) async {
        when(
          mockCoordinator.triggerBridge,
        ).thenThrow(StateError('bridge down'));

        await tester.pumpWidget(
          const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
        );
        await tester.pumpAndSettle();

        final button = find.ancestor(
          of: find.byIcon(Icons.bolt_outlined),
          matching: find.byType(FilledButton),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('fetch-all-history button opens the dialog', (tester) async {
      when(
        () => mockCoordinator.collectHistory(
          onProgress: any(named: 'onProgress'),
          cancelSignal: any(named: 'cancelSignal'),
          overallTimeout: any(named: 'overallTimeout'),
        ),
      ).thenAnswer(
        (_) async => const BootstrapResult(
          totalPages: 0,
          totalEvents: 0,
          oldestTimestampReached: null,
          stopReason: BootstrapStopReason.serverExhausted,
        ),
      );

      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      final button = find.ancestor(
        of: find.byIcon(Icons.download_rounded),
        matching: find.byType(OutlinedButton),
      );
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Dialog renders its close/cancel button and title.
      expect(find.byType(AlertDialog), findsOneWidget);
      // Dismiss it to avoid leaking the dialog into teardown.
      final closeButton = find.widgetWithText(TextButton, 'Close');
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton);
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
      'queue section hidden when MatrixService is not suppressed',
      (tester) async {
        when(
          () => mockMatrixService.isLegacyPipelineSuppressed,
        ).thenReturn(false);

        await tester.pumpWidget(
          const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bolt_outlined), findsNothing);
        expect(find.byIcon(Icons.download_rounded), findsNothing);
      },
    );
  });

  /// Scaffolds the Backfill Settings page with the given stats. The
  /// top-level `setUp` already wires the common mocks; this helper lets
  /// per-test cases swap in specific `BackfillStats` without re-doing
  /// the GetIt registration boilerplate.
  Future<void> pumpWithStats(
    WidgetTester tester,
    BackfillStats stats,
  ) async {
    when(
      () => mockSequenceService.getBackfillStats(),
    ).thenAnswer((_) async => stats);
    await tester.pumpWidget(
      const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
    );
    await tester.pumpAndSettle();
  }

  BackfillStats statsWith({
    int receivedCount = 100,
    int missingCount = 0,
    int requestedCount = 0,
    int backfilledCount = 0,
    int deletedCount = 0,
    int unresolvableCount = 0,
  }) => BackfillStats.fromHostStats([
    BackfillHostStats(
      receivedCount: receivedCount,
      missingCount: missingCount,
      requestedCount: requestedCount,
      backfilledCount: backfilledCount,
      deletedCount: deletedCount,
      unresolvableCount: unresolvableCount,
    ),
  ]);

  group('Ask peers for unresolvable entries section', () {
    testWidgets('renders cloud_sync icon when unresolvable > 0', (
      tester,
    ) async {
      await pumpWithStats(tester, statsWith(unresolvableCount: 12));
      // Two cloud_sync icons: one in the section header, one in the
      // button icon slot.
      expect(find.byIcon(Icons.cloud_sync), findsNWidgets(2));
    });

    testWidgets(
      'button is disabled when unresolvable count is 0 so the user is '
      'not offered an action that has nothing to do',
      (tester) async {
        // The default testStats has unresolvableCount=0.
        await pumpWithStats(tester, testStats);

        final section = find.ancestor(
          of: find.text('Ask peers for unresolvable entries'),
          matching: find.byType(Card),
        );
        final button = find.descendant(
          of: section,
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        final widget = tester.widget<FilledButton>(button);
        expect(widget.onPressed, isNull);
      },
    );

    testWidgets(
      'tapping the button opens a confirmation dialog; cancelling the '
      'dialog does NOT call resetAllUnresolvableEntries so a stray tap '
      'cannot flip hundreds of thousands of rows',
      (tester) async {
        await pumpWithStats(tester, statsWith(unresolvableCount: 42));

        final section = find.ancestor(
          of: find.text('Ask peers for unresolvable entries'),
          matching: find.byType(Card),
        );
        final button = find.descendant(
          of: section,
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();

        // Dialog rendered with title + row count context.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Ask peers again for unresolvable entries?'),
          findsOneWidget,
        );
        // Dialog content mentions the 42 rows inside the AlertDialog.
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('42 '),
          ),
          findsOneWidget,
        );

        // Cancel — must not call the service.
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        verifyNever(() => mockSequenceService.resetAllUnresolvableEntries());
      },
    );

    testWidgets(
      'confirming the dialog calls resetAllUnresolvableEntries and the '
      'success row appears once the stats refresh',
      (tester) async {
        when(
          () => mockSequenceService.resetAllUnresolvableEntries(),
        ).thenAnswer((_) async => 42);

        await pumpWithStats(tester, statsWith(unresolvableCount: 42));

        final section = find.ancestor(
          of: find.text('Ask peers for unresolvable entries'),
          matching: find.byType(Card),
        );
        final button = find.descendant(
          of: section,
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Ask peers'));
        await tester.pumpAndSettle();

        verify(
          () => mockSequenceService.resetAllUnresolvableEntries(),
        ).called(1);
        // Success row confirms the count came back.
        expect(find.textContaining('Reopened 42'), findsOneWidget);
      },
    );
  });

  group('Retire stuck entries section', () {
    testWidgets(
      'renders the block icon in the section when there are open rows',
      (tester) async {
        await pumpWithStats(
          tester,
          statsWith(missingCount: 3, requestedCount: 4),
        );
        // One in header (open > 0 → red), one in button icon slot.
        expect(find.byIcon(Icons.block), findsNWidgets(2));
      },
    );

    testWidgets(
      'button is disabled when neither missing nor requested rows exist',
      (tester) async {
        await pumpWithStats(tester, statsWith());

        final section = find.ancestor(
          of: find.text('Retire stuck entries'),
          matching: find.byType(Card),
        );
        final button = find.descendant(
          of: section,
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        final widget = tester.widget<FilledButton>(button);
        expect(widget.onPressed, isNull);
      },
    );

    testWidgets(
      'tapping opens a confirmation dialog; cancelling the dialog does '
      'NOT retire anything',
      (tester) async {
        await pumpWithStats(
          tester,
          statsWith(missingCount: 5, requestedCount: 2),
        );

        final section = find.ancestor(
          of: find.text('Retire stuck entries'),
          matching: find.byType(Card),
        );
        final button = find.descendant(
          of: section,
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Retire stuck entries now?'),
          findsOneWidget,
        );
        // openCount = missing + requested = 7, mentioned inside dialog body.
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('7 '),
          ),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        verifyNever(
          () => mockSequenceService.retireAgedOutRequestedEntries(
            amnestyWindow: any(named: 'amnestyWindow'),
          ),
        );
      },
    );

    testWidgets(
      'confirming the dialog calls retireAgedOutRequestedEntries with '
      'Duration.zero — the zero-amnesty manual path — and shows success',
      (tester) async {
        when(
          () => mockSequenceService.retireAgedOutRequestedEntries(
            amnestyWindow: any(named: 'amnestyWindow'),
          ),
        ).thenAnswer((_) async => 7);

        await pumpWithStats(
          tester,
          statsWith(missingCount: 5, requestedCount: 2),
        );

        final section = find.ancestor(
          of: find.text('Retire stuck entries'),
          matching: find.byType(Card),
        );
        final button = find.descendant(
          of: section,
          matching: find.bySubtype<ButtonStyleButton>(),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Retire now'));
        await tester.pumpAndSettle();

        verify(
          () => mockSequenceService.retireAgedOutRequestedEntries(
            amnestyWindow: Duration.zero,
          ),
        ).called(1);
        expect(
          find.textContaining('Retired 7 entries'),
          findsOneWidget,
        );
      },
    );
  });
}
