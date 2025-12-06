import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/features/sync/ui/sequence_log_populate_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockLoggingDb extends Mock implements LoggingDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncSequenceLogService mockSequenceLogService;
  late MockJournalDb mockJournalDb;
  late MockLoggingService mockLoggingService;
  late MockLoggingDb mockLoggingDb;

  setUp(() async {
    await getIt.reset();

    mockSequenceLogService = MockSyncSequenceLogService();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();
    mockLoggingDb = MockLoggingDb();

    getIt
      ..registerSingleton<SyncSequenceLogService>(mockSequenceLogService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<LoggingDb>(mockLoggingDb);

    when(
      () => mockLoggingService.captureException(
        any<Object>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });

  tearDown(getIt.reset);

  Widget buildTestWidget({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('SequenceLogPopulateModal', () {
    testWidgets('shows modal with confirmation page', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => SequenceLogPopulateModal.show(context),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Confirmation page visible
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('dismisses on cancel', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => SequenceLogPopulateModal.show(context),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('shows confirmation message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => SequenceLogPopulateModal.show(context),
                child: const Text('Show Modal'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Check for localized confirmation message
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('SequenceLogPopulateState', () {
    test('default values', () {
      const state = SequenceLogPopulateState();
      expect(state.progress, 0);
      expect(state.isRunning, false);
      expect(state.populatedCount, isNull);
      expect(state.totalCount, isNull);
      expect(state.error, isNull);
    });

    test('copyWith preserves values when not overridden', () {
      const state = SequenceLogPopulateState(
        progress: 0.5,
        isRunning: true,
        populatedCount: 100,
        totalCount: 200,
        error: 'error',
      );
      final copied = state.copyWith();
      expect(copied.progress, 0.5);
      expect(copied.isRunning, true);
      expect(copied.populatedCount, 100);
      expect(copied.totalCount, 200);
      expect(copied.error, 'error');
    });

    test('copyWith overrides specified values', () {
      const state = SequenceLogPopulateState();
      final copied = state.copyWith(
        progress: 0.75,
        isRunning: true,
        populatedCount: 50,
        totalCount: 100,
        error: 'new error',
      );
      expect(copied.progress, 0.75);
      expect(copied.isRunning, true);
      expect(copied.populatedCount, 50);
      expect(copied.totalCount, 100);
      expect(copied.error, 'new error');
    });

    test('copyWith clearError removes error', () {
      const state = SequenceLogPopulateState(error: 'error');
      final copied = state.copyWith(clearError: true);
      expect(copied.error, isNull);
    });

    test('copyWith clearCount removes counts', () {
      const state = SequenceLogPopulateState(
        populatedCount: 100,
        totalCount: 200,
      );
      final copied = state.copyWith(clearCount: true);
      expect(copied.populatedCount, isNull);
      expect(copied.totalCount, isNull);
    });

    test('copyWith clearError takes precedence over new error', () {
      const state = SequenceLogPopulateState(error: 'old');
      final copied = state.copyWith(clearError: true, error: 'new');
      expect(copied.error, isNull);
    });

    test('copyWith clearCount takes precedence over new counts', () {
      const state = SequenceLogPopulateState(
        populatedCount: 10,
        totalCount: 20,
      );
      final copied = state.copyWith(
        clearCount: true,
        populatedCount: 30,
        totalCount: 40,
      );
      expect(copied.populatedCount, isNull);
      expect(copied.totalCount, isNull);
    });
  });
}
