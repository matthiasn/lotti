import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_corpus_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../agents/test_data/entity_factories.dart';

const _agentId = 'day-agent-001';
final _day = DateTime(2026, 5, 25);

Task _task({
  required String id,
  required String title,
  required TaskStatus status,
  String? categoryId = 'work',
  DateTime? due,
}) {
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: DateTime(2026, 5, 20),
          updatedAt: DateTime(2026, 5, 20),
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          categoryId: categoryId,
        ),
        data: TaskData(
          status: status,
          statusHistory: [status],
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          title: title,
          due: due,
        ),
      )
      as Task;
}

TaskStatus _openStatus() => TaskStatus.open(
  id: 'status-open',
  createdAt: DateTime(2026, 5, 20),
  utcOffset: 120,
);

TaskStatus _doneStatus() => TaskStatus.done(
  id: 'status-done',
  createdAt: DateTime(2026, 5, 20),
  utcOffset: 120,
);

void main() {
  late MockJournalDb journalDb;
  late MockFts5Db fts5Db;
  late MockAgentRepository agentRepository;

  DayAgentCorpusService createService() => DayAgentCorpusService(
    journalDb: journalDb,
    fts5Db: fts5Db,
    reads: DayAgentCaptureReads(agentRepository: agentRepository),
  );

  setUp(() {
    journalDb = MockJournalDb();
    fts5Db = MockFts5Db();
    agentRepository = MockAgentRepository();
    when(() => agentRepository.getEntity(_agentId)).thenAnswer(
      (_) async => makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
        allowedCategoryIds: {'work'},
      ),
    );
  });

  group('buildTaskCorpusSnapshot', () {
    test('merges open + overdue tasks, drops closed and disallowed', () async {
      when(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          _task(id: 't-open', title: 'Open', status: _openStatus()),
          _task(
            id: 't-other',
            title: 'Other category',
            status: _openStatus(),
            categoryId: 'life',
          ),
        ],
      );
      when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
        (_) async => [
          _task(id: 't-done', title: 'Done', status: _doneStatus()),
          _task(id: 't-due', title: 'Due', status: _openStatus()),
        ],
      );

      final snapshot = await createService().buildTaskCorpusSnapshot(
        allowedCategoryIds: {'work'},
        day: _day,
      );

      final ids = snapshot.map((row) => row['taskId']).toSet();
      expect(ids, {'t-due', 't-open'});
    });

    test('honors the limit by capping the merged set', () async {
      when(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          _task(id: 't1', title: 'One', status: _openStatus()),
          _task(id: 't2', title: 'Two', status: _openStatus()),
        ],
      );
      when(
        () => journalDb.getTasksDueOnOrBefore(any()),
      ).thenAnswer((_) async => const <Task>[]);

      final snapshot = await createService().buildTaskCorpusSnapshot(
        allowedCategoryIds: {'work'},
        day: _day,
        limit: 1,
      );

      expect(snapshot, hasLength(1));
    });
  });

  group('matchToCorpus', () {
    test('throws when the phrase is empty', () async {
      expect(
        () => createService().matchToCorpus(agentId: _agentId, phrase: '  '),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test(
      'returns ranked matches in FTS order, dropping closed tasks',
      () async {
        when(
          () => fts5Db.watchFullTextMatches('demo'),
        ).thenAnswer((_) => Stream.value(['t-a', 't-closed', 't-b']));
        when(
          () => journalDb.getJournalEntitiesForIdsUnordered(any()),
        ).thenAnswer(
          (_) async => [
            _task(id: 't-b', title: 'B', status: _openStatus()),
            _task(id: 't-a', title: 'A', status: _openStatus()),
            _task(id: 't-closed', title: 'Closed', status: _doneStatus()),
          ],
        );

        final matches = await createService().matchToCorpus(
          agentId: _agentId,
          phrase: 'demo',
        );

        expect(matches.map((m) => m.taskId).toList(), ['t-a', 't-b']);
        // First hit (rank index 0) scores highest.
        expect(matches.first.score, greaterThan(matches.last.score));
      },
    );

    test('returns empty when the category hint is outside allowed', () async {
      final matches = await createService().matchToCorpus(
        agentId: _agentId,
        phrase: 'demo',
        categoryHint: 'life',
      );

      expect(matches, isEmpty);
      verifyNever(() => fts5Db.watchFullTextMatches(any()));
    });
  });
}
