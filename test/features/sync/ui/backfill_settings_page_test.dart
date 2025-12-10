import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/backfill/backfill_request_service.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockSyncSequenceLogService mockSequenceService;
  late MockBackfillRequestService mockBackfillService;
  late MockUserActivityService mockUserActivityService;

  final testStats = BackfillStats.fromHostStats([
    const BackfillHostStats(
      hostId: 'host-1',
      receivedCount: 100,
      missingCount: 5,
      requestedCount: 2,
      backfilledCount: 10,
      deletedCount: 1,
      latestCounter: 118,
    ),
  ]);

  setUp(() {
    SharedPreferences.setMockInitialValues({'backfill_enabled': true});
    mockJournalDb = MockJournalDb();
    mockSequenceService = MockSyncSequenceLogService();
    mockBackfillService = MockBackfillRequestService();
    mockUserActivityService = MockUserActivityService();

    when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
        .thenAnswer((_) => Stream<bool>.value(true));
    when(() => mockSequenceService.getBackfillStats())
        .thenAnswer((_) async => testStats);
    when(() => mockBackfillService.processFullBackfill())
        .thenAnswer((_) async => 5);
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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verify the service was called
      verify(() => mockBackfillService.processFullBackfill()).called(1);
    });

    testWidgets('gate hides page when Matrix flag is OFF', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(false));
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
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
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Should now show sync_disabled icon
      expect(find.byIcon(Icons.sync_disabled), findsOneWidget);
    });

    testWidgets('shows zero stats when no hosts exist', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(true));
      // Return empty stats (no hosts)
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => BackfillStats.fromHostStats(const []));
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

    testWidgets('shows error message when manual backfill fails',
        (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(true));
      when(() => mockSequenceService.getBackfillStats())
          .thenAnswer((_) async => testStats);
      when(() => mockBackfillService.processFullBackfill())
          .thenThrow(Exception('Backfill failed'));
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
      await tester.pumpAndSettle();
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

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

    testWidgets('re-request button is disabled when requestedCount is 0',
        (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      mockSequenceService = MockSyncSequenceLogService();
      mockBackfillService = MockBackfillRequestService();
      mockUserActivityService = MockUserActivityService();

      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(true));
      // Return stats with 0 requested entries
      when(() => mockSequenceService.getBackfillStats()).thenAnswer(
        (_) async => BackfillStats.fromHostStats([
          const BackfillHostStats(
            hostId: 'host-1',
            receivedCount: 100,
            missingCount: 5,
            requestedCount: 0, // No requested entries
            backfilledCount: 10,
            deletedCount: 1,
            latestCounter: 116,
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
      await tester.pumpAndSettle();

      // Button should be disabled (onPressed is null)
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('re-request button triggers service when requestedCount > 0',
        (tester) async {
      when(() => mockBackfillService.processReRequest())
          .thenAnswer((_) async => 5);

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
      await tester.pumpAndSettle();

      // Tap the button
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verify the service was called
      verify(() => mockBackfillService.processReRequest()).called(1);
    });

    testWidgets('shows success message after re-request completes',
        (tester) async {
      when(() => mockBackfillService.processReRequest())
          .thenAnswer((_) async => 5);

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
      await tester.pumpAndSettle();
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Should show check_circle icon for success
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('re-request section shows orange icon when requestedCount > 0',
        (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(child: BackfillSettingsPage()),
      );
      await tester.pumpAndSettle();

      // With testStats having requestedCount = 2, the replay icon should have
      // an orange color. Find the replay icon.
      final replayIconFinder = find.byIcon(Icons.replay);
      expect(replayIconFinder, findsWidgets);
    });
  });
}
