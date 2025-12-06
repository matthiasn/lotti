import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

class MockJournalDb extends Mock implements JournalDb {}

// Fake types for mocktail fallback
class FakeEntryStream extends Fake
    implements Stream<List<({String id, Map<String, int>? vectorClock})>> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeEntryStream());
  });

  group('SequenceLogPopulateState', () {
    test('default constructor has expected values', () {
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
        error: 'some error',
      );

      final copied = state.copyWith();

      expect(copied.progress, 0.5);
      expect(copied.isRunning, true);
      expect(copied.populatedCount, 100);
      expect(copied.totalCount, 200);
      expect(copied.error, 'some error');
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
      const state = SequenceLogPopulateState(error: 'some error');

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
      const state = SequenceLogPopulateState(error: 'old error');

      final copied = state.copyWith(clearError: true, error: 'new error');

      // clearError should take precedence
      expect(copied.error, isNull);
    });

    test('copyWith clearCount takes precedence over new counts', () {
      const state = SequenceLogPopulateState(
        populatedCount: 100,
        totalCount: 200,
      );

      final copied = state.copyWith(
        clearCount: true,
        populatedCount: 300,
        totalCount: 400,
      );

      // clearCount should take precedence
      expect(copied.populatedCount, isNull);
      expect(copied.totalCount, isNull);
    });
  });

  group('SequenceLogPopulateController', () {
    late MockSyncSequenceLogService mockSequenceLogService;
    late MockJournalDb mockJournalDb;
    late ProviderContainer container;

    setUp(() async {
      await getIt.reset();

      mockSequenceLogService = MockSyncSequenceLogService();
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<SyncSequenceLogService>(mockSequenceLogService)
        ..registerSingleton<JournalDb>(mockJournalDb);
    });

    tearDown(() async {
      container.dispose();
      await getIt.reset();
    });

    test('initial state is not running with zero progress', () {
      container = ProviderContainer();

      final state = container.read(sequenceLogPopulateControllerProvider);

      expect(state.progress, 0);
      expect(state.isRunning, false);
      expect(state.populatedCount, isNull);
      expect(state.error, isNull);
    });

    test('populateSequenceLog completes successfully', () async {
      container = ProviderContainer();

      when(() => mockJournalDb.streamEntriesWithVectorClock()).thenAnswer(
        (_) => Stream.fromIterable([
          [
            (id: 'entry-1', vectorClock: {'host-1': 1}),
          ],
        ]),
      );
      when(() => mockJournalDb.countAllJournalEntries())
          .thenAnswer((_) async => 1);

      when(
        () => mockSequenceLogService.populateFromJournal(
          entryStream: any(named: 'entryStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(double)?;
        onProgress?.call(1);
        return 10;
      });

      // Listen for completion
      final completer = Completer<SequenceLogPopulateState>();
      container.listen(
        sequenceLogPopulateControllerProvider,
        (previous, next) {
          if (!next.isRunning &&
              next.progress == 1.0 &&
              !completer.isCompleted) {
            completer.complete(next);
          }
        },
      );

      final controller =
          container.read(sequenceLogPopulateControllerProvider.notifier);
      await controller.populateSequenceLog();

      final finalState = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => container.read(sequenceLogPopulateControllerProvider),
      );

      expect(finalState.isRunning, false);
      expect(finalState.progress, 1.0);
      expect(finalState.populatedCount, 10);
      expect(finalState.error, isNull);
    });

    test('populateSequenceLog handles errors', () async {
      container = ProviderContainer();

      when(() => mockJournalDb.streamEntriesWithVectorClock()).thenAnswer(
        (_) => Stream.fromIterable([]),
      );
      when(() => mockJournalDb.countAllJournalEntries())
          .thenAnswer((_) async => 0);

      when(
        () => mockSequenceLogService.populateFromJournal(
          entryStream: any(named: 'entryStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(Exception('Database error'));

      final controller =
          container.read(sequenceLogPopulateControllerProvider.notifier);
      await controller.populateSequenceLog();

      final state = container.read(sequenceLogPopulateControllerProvider);
      expect(state.isRunning, false);
      expect(state.progress, 0);
      expect(state.error, contains('Database error'));
    });
  });
}
