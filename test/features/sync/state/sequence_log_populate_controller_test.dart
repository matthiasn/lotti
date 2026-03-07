import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockSyncSequenceLogService extends Mock
    implements SyncSequenceLogService {}

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
      expect(state.populatedLinksCount, isNull);
      expect(state.populatedAgentEntitiesCount, isNull);
      expect(state.populatedAgentLinksCount, isNull);
      expect(state.totalCount, isNull);
      expect(state.error, isNull);
    });

    test('copyWith preserves values when not overridden', () {
      const state = SequenceLogPopulateState(
        progress: 0.5,
        isRunning: true,
        populatedCount: 100,
        populatedLinksCount: 50,
        populatedAgentEntitiesCount: 30,
        populatedAgentLinksCount: 20,
        totalCount: 200,
        error: 'some error',
      );

      final copied = state.copyWith();

      expect(copied.progress, 0.5);
      expect(copied.isRunning, true);
      expect(copied.populatedCount, 100);
      expect(copied.populatedLinksCount, 50);
      expect(copied.populatedAgentEntitiesCount, 30);
      expect(copied.populatedAgentLinksCount, 20);
      expect(copied.totalCount, 200);
      expect(copied.error, 'some error');
    });

    test('copyWith overrides specified values', () {
      const state = SequenceLogPopulateState();

      final copied = state.copyWith(
        progress: 0.75,
        isRunning: true,
        populatedCount: 50,
        populatedLinksCount: 25,
        populatedAgentEntitiesCount: 15,
        populatedAgentLinksCount: 10,
        totalCount: 100,
        error: 'new error',
      );

      expect(copied.progress, 0.75);
      expect(copied.isRunning, true);
      expect(copied.populatedCount, 50);
      expect(copied.populatedLinksCount, 25);
      expect(copied.populatedAgentEntitiesCount, 15);
      expect(copied.populatedAgentLinksCount, 10);
      expect(copied.totalCount, 100);
      expect(copied.error, 'new error');
    });

    test('copyWith clearError removes error', () {
      const state = SequenceLogPopulateState(error: 'some error');

      final copied = state.copyWith(clearError: true);

      expect(copied.error, isNull);
    });

    test('copyWith clearCount removes all counts', () {
      const state = SequenceLogPopulateState(
        populatedCount: 100,
        populatedLinksCount: 50,
        populatedAgentEntitiesCount: 30,
        populatedAgentLinksCount: 20,
        totalCount: 200,
      );

      final copied = state.copyWith(clearCount: true);

      expect(copied.populatedCount, isNull);
      expect(copied.populatedLinksCount, isNull);
      expect(copied.populatedAgentEntitiesCount, isNull);
      expect(copied.populatedAgentLinksCount, isNull);
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
        populatedLinksCount: 50,
        populatedAgentEntitiesCount: 30,
        populatedAgentLinksCount: 20,
        totalCount: 200,
      );

      final copied = state.copyWith(
        clearCount: true,
        populatedCount: 300,
        populatedLinksCount: 150,
        populatedAgentEntitiesCount: 90,
        populatedAgentLinksCount: 60,
        totalCount: 400,
      );

      // clearCount should take precedence
      expect(copied.populatedCount, isNull);
      expect(copied.populatedLinksCount, isNull);
      expect(copied.populatedAgentEntitiesCount, isNull);
      expect(copied.populatedAgentLinksCount, isNull);
      expect(copied.totalCount, isNull);
    });
  });

  group('SequenceLogPopulateController', () {
    late MockSyncSequenceLogService mockSequenceLogService;
    late MockJournalDb mockJournalDb;
    late MockAgentDatabase mockAgentDb;
    late ProviderContainer container;

    setUp(() async {
      await getIt.reset();

      mockSequenceLogService = MockSyncSequenceLogService();
      mockJournalDb = MockJournalDb();
      mockAgentDb = MockAgentDatabase();

      getIt
        ..registerSingleton<SyncSequenceLogService>(mockSequenceLogService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<AgentDatabase>(mockAgentDb);
    });

    tearDown(() async {
      container.dispose();
      await getIt.reset();
    });

    void stubAllPopulateMethods({
      int journalCount = 0,
      int linksCount = 0,
      int agentEntitiesCount = 0,
      int agentLinksCount = 0,
    }) {
      when(() => mockJournalDb.streamEntriesWithVectorClock()).thenAnswer(
        (_) => Stream.fromIterable([]),
      );
      when(
        () => mockJournalDb.countAllJournalEntries(),
      ).thenAnswer((_) async => 0);
      when(() => mockJournalDb.streamEntryLinksWithVectorClock()).thenAnswer(
        (_) => Stream.fromIterable([]),
      );
      when(() => mockJournalDb.countAllEntryLinks()).thenAnswer((_) async => 0);
      when(() => mockAgentDb.streamAgentEntitiesWithVectorClock()).thenAnswer(
        (_) => Stream.fromIterable([]),
      );
      when(
        () => mockAgentDb.countAllAgentEntities(),
      ).thenAnswer((_) async => 0);
      when(() => mockAgentDb.streamAgentLinksWithVectorClock()).thenAnswer(
        (_) => Stream.fromIterable([]),
      );
      when(() => mockAgentDb.countAllAgentLinks()).thenAnswer((_) async => 0);

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
        return journalCount;
      });

      when(
        () => mockSequenceLogService.populateFromEntryLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(double)?;
        onProgress?.call(1);
        return linksCount;
      });

      when(
        () => mockSequenceLogService.populateFromAgentEntities(
          entityStream: any(named: 'entityStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(double)?;
        onProgress?.call(1);
        return agentEntitiesCount;
      });

      when(
        () => mockSequenceLogService.populateFromAgentLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(double)?;
        onProgress?.call(1);
        return agentLinksCount;
      });
    }

    test('initial state is not running with zero progress', () {
      container = ProviderContainer();

      final state = container.read(sequenceLogPopulateControllerProvider);

      expect(state.progress, 0);
      expect(state.isRunning, false);
      expect(state.populatedCount, isNull);
      expect(state.populatedAgentEntitiesCount, isNull);
      expect(state.populatedAgentLinksCount, isNull);
      expect(state.error, isNull);
    });

    test('populateSequenceLog completes all four phases', () async {
      container = ProviderContainer();

      stubAllPopulateMethods(
        journalCount: 10,
        linksCount: 5,
        agentEntitiesCount: 8,
        agentLinksCount: 3,
      );

      // Track phases seen during execution
      final phasesSeen = <SequenceLogPopulatePhase>[];
      container.listen(
        sequenceLogPopulateControllerProvider,
        (previous, next) {
          if (!phasesSeen.contains(next.phase)) {
            phasesSeen.add(next.phase);
          }
        },
      );

      final controller = container.read(
        sequenceLogPopulateControllerProvider.notifier,
      );
      await controller.populateSequenceLog();

      final finalState = container.read(sequenceLogPopulateControllerProvider);

      expect(finalState.isRunning, false);
      expect(finalState.progress, 1.0);
      expect(finalState.populatedCount, 10);
      expect(finalState.populatedLinksCount, 5);
      expect(finalState.populatedAgentEntitiesCount, 8);
      expect(finalState.populatedAgentLinksCount, 3);
      expect(finalState.error, isNull);
      expect(finalState.phase, SequenceLogPopulatePhase.done);

      expect(phasesSeen, contains(SequenceLogPopulatePhase.populatingJournal));
      expect(phasesSeen, contains(SequenceLogPopulatePhase.populatingLinks));
      expect(
        phasesSeen,
        contains(SequenceLogPopulatePhase.populatingAgentEntities),
      );
      expect(
        phasesSeen,
        contains(SequenceLogPopulatePhase.populatingAgentLinks),
      );
      expect(phasesSeen, contains(SequenceLogPopulatePhase.done));
    });

    test('populateSequenceLog calls all four service methods', () async {
      container = ProviderContainer();

      stubAllPopulateMethods();

      final controller = container.read(
        sequenceLogPopulateControllerProvider.notifier,
      );
      await controller.populateSequenceLog();

      verify(
        () => mockSequenceLogService.populateFromJournal(
          entryStream: any(named: 'entryStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);

      verify(
        () => mockSequenceLogService.populateFromEntryLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);

      verify(
        () => mockSequenceLogService.populateFromAgentEntities(
          entityStream: any(named: 'entityStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);

      verify(
        () => mockSequenceLogService.populateFromAgentLinks(
          linkStream: any(named: 'linkStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    });

    test('populateSequenceLog handles errors', () async {
      container = ProviderContainer();

      when(() => mockJournalDb.streamEntriesWithVectorClock()).thenAnswer(
        (_) => Stream.fromIterable([]),
      );
      when(
        () => mockJournalDb.countAllJournalEntries(),
      ).thenAnswer((_) async => 0);

      when(
        () => mockSequenceLogService.populateFromJournal(
          entryStream: any(named: 'entryStream'),
          getTotalCount: any(named: 'getTotalCount'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(Exception('Database error'));

      final controller = container.read(
        sequenceLogPopulateControllerProvider.notifier,
      );
      await controller.populateSequenceLog();

      final state = container.read(sequenceLogPopulateControllerProvider);
      expect(state.isRunning, false);
      expect(state.progress, 0);
      expect(state.error, contains('Database error'));
    });
  });
}
