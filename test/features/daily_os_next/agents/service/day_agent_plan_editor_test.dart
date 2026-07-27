import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_editor.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_writer.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

const _agentId = 'day-agent-001';
final _now = DateTime(2026, 5, 25, 9);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;

  DayAgentPlanEditor createEditor() {
    final reads = DayAgentPlanReads(agentRepository: agentRepository);
    return DayAgentPlanEditor(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      reads: reads,
      writer: DayAgentPlanWriter(
        agentRepository: agentRepository,
        syncService: syncService,
        journalDb: journalDb,
        reads: reads,
      ),
    );
  }

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
  });

  group('hydrateDecidedTasks', () {
    test('returns empty list and skips JournalDb when no inputs', () async {
      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const {'work', 'life'},
      );

      expect(result, isEmpty);
      verifyNever(() => journalDb.journalEntityMapForIds(any()));
    });

    test(
      'merges explicit + parsed-item ids, explicit first, deduped',
      () async {
        final task1 = _task(id: 'task-1', title: 'Prep demo');
        final task2 = _task(id: 'task-2', title: 'Buy milk');
        final task3 = _task(id: 'task-3', title: 'Send invoice');
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {
            'task-1': task1,
            'task-2': task2,
            'task-3': task3,
          },
        );

        final result = await createEditor().hydrateDecidedTasks(
          allowedCategoryIds: const {'work', 'life'},
          explicitTaskIds: const ['task-1', 'task-3'],
          parsedItems: [
            _parsedItem(matchedTaskId: 'task-3'),
            _parsedItem(id: 'parsed-2', matchedTaskId: 'task-2'),
          ],
        );

        expect(result.map((task) => task.id).toList(), [
          'task-1',
          'task-3',
          'task-2',
        ]);
        final captured =
            verify(
                  () => journalDb.journalEntityMapForIds(captureAny()),
                ).captured.single
                as List<String>;
        expect(captured, ['task-1', 'task-3', 'task-2']);
      },
    );

    test('skips parsed items without matchedTaskId or soft-deleted', () async {
      final task1 = _task(id: 'task-1', title: 'Prep demo');
      when(
        () => journalDb.journalEntityMapForIds(any()),
      ).thenAnswer((_) async => {'task-1': task1});

      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const {'work', 'life'},
        parsedItems: [
          _parsedItem(matchedTaskId: 'task-1'),
          _parsedItem(id: 'parsed-2'),
          _parsedItem(
            id: 'parsed-3',
            matchedTaskId: 'task-2',
            deletedAt: DateTime(2026, 5, 25, 8),
          ),
        ],
      );

      expect(result.map((task) => task.id).toList(), ['task-1']);
    });

    test('filters out tasks outside the agent allowed categories', () async {
      final task1 = _task(id: 'task-1', title: 'Prep demo');
      final task2 = _task(
        id: 'task-2',
        title: 'Personal errand',
        categoryId: 'blocked',
      );
      when(
        () => journalDb.journalEntityMapForIds(any()),
      ).thenAnswer((_) async => {'task-1': task1, 'task-2': task2});

      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const {'work', 'life'},
        explicitTaskIds: const ['task-1', 'task-2'],
      );

      expect(result.map((task) => task.id).toList(), ['task-1']);
    });

    test('skips ids that resolve to missing or deleted tasks', () async {
      final task1 = _task(id: 'task-1', title: 'Prep demo');
      final task2 = _task(id: 'task-2', title: 'Deleted task');
      when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
        (_) async => {
          'task-1': task1,
          'task-2': task2.copyWith(
            meta: task2.meta.copyWith(deletedAt: DateTime(2026, 5, 24)),
          ),
        },
      );

      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const {'work', 'life'},
        explicitTaskIds: const ['task-1', 'task-2', 'task-missing'],
      );

      expect(result.map((task) => task.id).toList(), ['task-1']);
    });

    test('allows any category when allowedCategoryIds is empty', () async {
      final task1 = _task(
        id: 'task-1',
        title: 'Anywhere',
        categoryId: 'unscoped',
      );
      when(
        () => journalDb.journalEntityMapForIds(any()),
      ).thenAnswer((_) async => {'task-1': task1});

      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const <String>{},
        explicitTaskIds: const ['task-1'],
      );

      expect(result.single.id, 'task-1');
      expect(result.single.categoryId, 'unscoped');
    });

    test('trims whitespace from explicit ids before lookup', () async {
      final task1 = _task(id: 'task-1', title: 'Prep demo');
      when(
        () => journalDb.journalEntityMapForIds(any()),
      ).thenAnswer((_) async => {'task-1': task1});

      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const {'work', 'life'},
        explicitTaskIds: const ['  task-1  ', '', '   '],
      );

      expect(result.map((task) => task.id).toList(), ['task-1']);
      final captured =
          verify(
                () => journalDb.journalEntityMapForIds(captureAny()),
              ).captured.single
              as List<String>;
      expect(captured, ['task-1']);
    });

    test('carries the positive task estimate without a resolver', () async {
      when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
        (_) async => {
          'task-1': _task(
            id: 'task-1',
            title: 'Rewrite the ingestion pipeline',
            estimate: const Duration(minutes: 240),
          ),
        },
      );

      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const {'work', 'life'},
        explicitTaskIds: const ['task-1'],
      );

      expect(result.single.estimateMinutes, 240);
    });

    test(
      'omits a zero-duration estimate instead of treating work as free',
      () async {
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {
            'task-1': _task(
              id: 'task-1',
              title: 'Unsized work',
              estimate: Duration.zero,
            ),
          },
        );

        final result = await createEditor().hydrateDecidedTasks(
          allowedCategoryIds: const {'work', 'life'},
          explicitTaskIds: const ['task-1'],
        );

        expect(result.single.estimateMinutes, isNull);
        expect(result.single.toJson().containsKey('estimateMinutes'), isFalse);
      },
    );

    test('omits status entirely without a dependency resolver', () async {
      when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
        (_) async => {'task-1': _task(id: 'task-1', title: 'Prep demo')},
      );

      final result = await createEditor().hydrateDecidedTasks(
        allowedCategoryIds: const {'work', 'life'},
        explicitTaskIds: const ['task-1'],
      );

      expect(result.single.status, isNull);
      expect(result.single.blockedBy, isEmpty);
      expect(result.single.toJson().containsKey('status'), isFalse);
      expect(result.single.toJson().containsKey('blockedBy'), isFalse);
    });

    test(
      'resolves blockers in one batch and still carries estimates',
      () async {
        final resolver = MockTaskDependencyResolver();
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {
            'task-c-leaf': _task(
              id: 'task-c-leaf',
              title: 'Ship the integration',
              estimate: const Duration(minutes: 90),
            ),
            'task-1': _task(id: 'task-1', title: 'Prep demo'),
          },
        );
        when(
          () => resolver.resolveBlockedStatus(
            any(),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer(
          (_) async => {
            'task-c-leaf': const [
              ResolvedBlocker(
                taskId: 'task-b-middle',
                title: 'Get vendor credentials',
                status: 'OPEN',
              ),
            ],
          },
        );

        final result = await createEditor().hydrateDecidedTasks(
          allowedCategoryIds: const {'work', 'life'},
          explicitTaskIds: const ['task-c-leaf', 'task-1'],
          dependencyResolver: resolver,
        );

        expect(result.map((task) => task.id).toList(), [
          'task-c-leaf',
          'task-1',
        ]);
        expect(result.first.blockedBy.single.taskId, 'task-b-middle');
        expect(result.first.estimateMinutes, 90);
        expect(result.last.blockedBy, isEmpty);
        final asked = verify(
          () => resolver.resolveBlockedStatus(
            captureAny(),
            allowedCategoryIds: captureAny(named: 'allowedCategoryIds'),
          ),
        ).captured;
        expect(asked[0], {'task-c-leaf', 'task-1'});
        expect(asked[1], {'work', 'life'});
      },
    );

    test(
      'does not consult the resolver when nothing survives filtering',
      () async {
        final resolver = MockTaskDependencyResolver();
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {
            'task-2': _task(
              id: 'task-2',
              title: 'Personal errand',
              categoryId: 'blocked',
            ),
          },
        );

        final result = await createEditor().hydrateDecidedTasks(
          allowedCategoryIds: const {'work', 'life'},
          explicitTaskIds: const ['task-2'],
          dependencyResolver: resolver,
        );

        expect(result, isEmpty);
        verifyNever(
          () => resolver.resolveBlockedStatus(
            any(),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );
  });
}

Task _task({
  required String id,
  required String title,
  String? categoryId = 'work',
  TaskStatus? status,
  Duration? estimate,
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
          status:
              status ??
              TaskStatus.open(
                id: 'status-open',
                createdAt: DateTime(2026, 5, 20),
                utcOffset: 120,
              ),
          statusHistory: const [],
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          title: title,
          estimate: estimate,
        ),
      )
      as Task;
}

ParsedItemEntity _parsedItem({
  String id = 'parsed-1',
  String? matchedTaskId,
  DateTime? deletedAt,
}) {
  return AgentDomainEntity.parsedItem(
        id: id,
        agentId: _agentId,
        captureId: 'capture-001',
        kind: ParsedItemKind.matched,
        title: 'Prep demo',
        categoryId: 'work',
        confidence: ParsedItemConfidence.high,
        confidenceScore: 0.9,
        createdAt: _now,
        vectorClock: null,
        matchedTaskId: matchedTaskId,
        deletedAt: deletedAt,
      )
      as ParsedItemEntity;
}
