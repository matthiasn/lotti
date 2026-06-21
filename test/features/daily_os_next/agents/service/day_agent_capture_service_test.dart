import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_data/entity_factories.dart';

const _agentId = 'day-agent-001';
const _threadId = 'thread-001';
const _runKey = 'run-key-001';
final _now = DateTime(2026, 5, 25, 9);

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

TaskStatus _inProgressStatus() => TaskStatus.inProgress(
  id: 'status-progress',
  createdAt: DateTime(2026, 5, 20),
  utcOffset: 120,
);

TaskStatus _doneStatus() => TaskStatus.done(
  id: 'status-done',
  createdAt: DateTime(2026, 5, 20),
  utcOffset: 120,
);

/// Shape of a single `taskFactory` invocation captured by the test bench.
typedef _CreatedTaskRequest = ({
  String title,
  String categoryId,
  int? estimateMinutes,
  DateTime? due,
  String? profileId,
});

/// Builds a [DayAgentTaskFactory] that records each invocation into
/// [requests] and stores the synthesized task into [journalEntities] so the
/// rest of the service can read it back. Defined once instead of inline in
/// `createService` so the construction logic lives in one place.
DayAgentTaskFactory _makeTaskFactory(
  Map<String, JournalEntity> journalEntities,
  List<_CreatedTaskRequest> requests,
) {
  return ({
    required String title,
    required String categoryId,
    required DateTime now,
    int? estimateMinutes,
    DateTime? due,
    String? profileId,
  }) async {
    requests.add((
      title: title,
      categoryId: categoryId,
      estimateMinutes: estimateMinutes,
      due: due,
      profileId: profileId,
    ));
    final baseTask = _task(
      id: 'created-task-${requests.length}',
      title: title,
      status: _openStatus(),
      categoryId: categoryId,
    );
    final task = baseTask.copyWith(
      data: baseTask.data.copyWith(
        estimate: Duration(minutes: estimateMinutes ?? 0),
        due: due,
        profileId: profileId,
      ),
    );
    journalEntities[task.id] = task;
    return task;
  };
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late MockJournalRepository journalRepository;
  late MockFts5Db fts5Db;
  late MockWakeOrchestrator orchestrator;
  late MockDomainLogger domainLogger;
  late Map<String, AgentDomainEntity> agentEntities;
  late Map<String, JournalEntity> journalEntities;
  late Map<String, List<AgentLink>> linksByFromAndType;
  late List<AgentDomainEntity> upsertedEntities;
  late List<AgentLink> upsertedLinks;
  late List<String> notifications;
  late List<_CreatedTaskRequest> createdTaskRequests;

  DayAgentCaptureService createService() {
    return DayAgentCaptureService(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      journalRepository: journalRepository,
      fts5Db: fts5Db,
      orchestrator: orchestrator,
      domainLogger: domainLogger,
      taskFactory: _makeTaskFactory(journalEntities, createdTaskRequests),
      onPersistedStateChanged: notifications.add,
    );
  }

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
    journalRepository = MockJournalRepository();
    fts5Db = MockFts5Db();
    orchestrator = MockWakeOrchestrator();
    domainLogger = MockDomainLogger();
    agentEntities = {
      _agentId: makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
        kind: AgentKinds.dayAgent,
        allowedCategoryIds: {'work'},
      ),
    };
    journalEntities = <String, JournalEntity>{};
    linksByFromAndType = <String, List<AgentLink>>{};
    upsertedEntities = <AgentDomainEntity>[];
    upsertedLinks = <AgentLink>[];
    notifications = <String>[];
    createdTaskRequests = [];

    when(() => agentRepository.getEntity(any())).thenAnswer((invocation) async {
      return agentEntities[invocation.positionalArguments.single as String];
    });
    when(() => agentRepository.getEntitiesByIds(any())).thenAnswer((
      invocation,
    ) async {
      final ids = invocation.positionalArguments.single as Iterable<String>;
      return {
        for (final id in ids)
          if (agentEntities[id] != null) id: agentEntities[id]!,
      };
    });
    when(
      () => agentRepository.getLinksFrom(any(), type: any(named: 'type')),
    ).thenAnswer((invocation) async {
      final fromId = invocation.positionalArguments.single as String;
      final type = invocation.namedArguments[#type] as String?;
      return linksByFromAndType['$fromId:$type'] ?? const <AgentLink>[];
    });
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      upsertedEntities.add(entity);
      agentEntities[entity.id] = entity;
    });
    when(() => syncService.upsertLink(any())).thenAnswer((invocation) async {
      upsertedLinks.add(invocation.positionalArguments.single as AgentLink);
    });
    when(() => journalDb.journalEntityById(any())).thenAnswer((
      invocation,
    ) async {
      return journalEntities[invocation.positionalArguments.single as String];
    });
    when(() => journalDb.getCategoryById(any())).thenAnswer((_) async => null);
    when(
      () => journalDb.getOpenTasksForDayAgentCorpus(
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <Task>[]);
    when(() => journalDb.getTasksDueOn(any())).thenAnswer(
      (_) async => <Task>[],
    );
    when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
      (_) async => <Task>[],
    );
    when(
      () => journalDb.getInProgressTasks(
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async => <Task>[]);
    when(
      () => journalDb.getMissedRecurringTasks(
        asOf: any(named: 'asOf'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async => <Task>[]);
    when(
      () => journalDb.getJournalEntitiesForIdsUnordered(any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.single as Set<String>;
      return [
        for (final id in ids)
          if (journalEntities[id] != null) journalEntities[id]!,
      ];
    });
    when(() => journalRepository.updateJournalEntity(any())).thenAnswer(
      (_) async => true,
    );
    when(() => fts5Db.watchFullTextMatches(any())).thenAnswer(
      (_) => Stream.value(const <String>[]),
    );
  });

  group('DayAgentCaptureService', () {
    test('submitCapture writes a capture and enqueues a parse wake', () async {
      final service = createService();

      await withClock(Clock.fixed(_now), () async {
        final capture = await service.submitCapture(
          agentId: _agentId,
          transcript: '  buy milk and prep demo  ',
          capturedAt: DateTime(2026, 5, 25, 8, 45),
        );

        expect(capture.id, startsWith('capture_'));
        expect(capture.transcript, 'buy milk and prep demo');
        // The capture is stamped with its day workspace (ADR 0022), derived
        // from capturedAt.
        expect(capture.dayId, 'dayplan-2026-05-25');
        expect(upsertedEntities.single, isA<CaptureEntity>());
        expect(notifications, containsAll([_agentId, capture.id]));
        final captured =
            verify(
                  () => orchestrator.enqueueManualWake(
                    agentId: _agentId,
                    reason: 'capture_submitted',
                    workspaceKey: 'day:dayplan-2026-05-25',
                    triggerTokens: captureAny(named: 'triggerTokens'),
                    // Captures accumulate rather than supersede, so a second
                    // same-day capture can't drop this one's still-queued parse.
                    supersede: false,
                  ),
                ).captured.single
                as Set<String>;
        expect(captured, {dayAgentCaptureSubmittedToken(capture.id)});
      });
    });

    test('submitCapture rejects empty transcripts', () async {
      await expectLater(
        createService().submitCapture(
          agentId: _agentId,
          transcript: '   ',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      expect(upsertedEntities, isEmpty);
    });

    test(
      'parsedItemsForCapture returns linked items in created order',
      () async {
        final parsedLater =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-later',
                  agentId: _agentId,
                  captureId: 'capture-1',
                  kind: ParsedItemKind.newTask,
                  title: 'Later',
                  categoryId: 'work',
                  confidence: ParsedItemConfidence.low,
                  confidenceScore: 0.1,
                  createdAt: DateTime(2026, 5, 25, 9, 2),
                  vectorClock: null,
                )
                as ParsedItemEntity;
        final parsedEarlier = parsedLater.copyWith(
          id: 'parsed-earlier',
          title: 'Earlier',
          createdAt: DateTime(2026, 5, 25, 9, 1),
        );
        agentEntities
          ..[parsedLater.id] = parsedLater
          ..[parsedEarlier.id] = parsedEarlier;
        linksByFromAndType['capture-1:${AgentLinkTypes.captureToParsedItem}'] =
            [
              AgentLink.captureToParsedItem(
                id: 'link-later',
                fromId: 'capture-1',
                toId: parsedLater.id,
                createdAt: _now,
                updatedAt: _now,
                vectorClock: null,
              ),
              AgentLink.captureToParsedItem(
                id: 'link-earlier',
                fromId: 'capture-1',
                toId: parsedEarlier.id,
                createdAt: _now,
                updatedAt: _now,
                vectorClock: null,
              ),
            ];

        final items = await createService().parsedItemsForCapture('capture-1');

        expect(items.map((item) => item.id), [
          'parsed-earlier',
          'parsed-later',
        ]);
      },
    );

    test(
      'buildTaskCorpusSnapshot scopes, dedupes, and projects tasks',
      () async {
        final due = _task(
          id: 'task-1',
          title: 'Due work',
          status: _openStatus(),
          due: DateTime(2026, 5, 25, 12),
        );
        final duplicateOpen = due.copyWith(
          data: due.data.copyWith(title: 'Duplicate should not win'),
        );
        final open = _task(
          id: 'task-2',
          title: 'Open work',
          status: _openStatus(),
        );
        final hiddenCategory = _task(
          id: 'task-3',
          title: 'Home',
          status: _openStatus(),
          categoryId: 'home',
        );
        when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
          (_) async => [hiddenCategory, due],
        );
        when(
          () => journalDb.getOpenTasksForDayAgentCorpus(
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [duplicateOpen, open, hiddenCategory]);

        final snapshot = await createService().buildTaskCorpusSnapshot(
          allowedCategoryIds: {'work'},
          day: DateTime(2026, 5, 25, 8),
        );

        expect(snapshot.map((item) => item['taskId']), ['task-1', 'task-2']);
        expect(snapshot.first['title'], 'Due work');
        expect(
          snapshot.first['due'],
          DateTime(2026, 5, 25, 12).toIso8601String(),
        );
      },
    );

    test(
      'persistParsedItems stores thresholded items and task links',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'demo prep, milk, inbox',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        agentEntities[capture.id] = capture;
        journalEntities['task-1'] = _task(
          id: 'task-1',
          title: 'Prep demo',
          status: _openStatus(),
        );

        final service = createService();
        final items = await service.persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              'kind': 'matched',
              'title': 'Prep demo',
              'categoryId': 'work',
              'confidenceScore': 0.9,
              'matchedTaskId': 'task-1',
            },
            {
              'kind': 'matched',
              'title': 'Review inbox',
              'categoryId': 'work',
              'confidenceScore': 0.6,
              'matchedTaskId': 'task-1',
            },
            {
              'kind': 'matched',
              'title': 'Buy milk',
              'categoryId': 'work',
              'confidenceScore': 0.4,
              'matchedTaskId': 'task-1',
            },
          ],
        );

        expect(items, hasLength(3));
        expect(items[0].confidence, ParsedItemConfidence.high);
        expect(items[0].lowConfidence, isFalse);
        expect(items[0].matchedTaskId, 'task-1');
        expect(items[1].confidence, ParsedItemConfidence.medium);
        expect(items[1].lowConfidence, isTrue);
        expect(items[2].kind, ParsedItemKind.newTask);
        expect(items[2].matchedTaskId, isNull);

        final parsedItemLinks = upsertedLinks
            .whereType<CaptureToParsedItemLink>()
            .toList();
        final taskLinks = upsertedLinks
            .whereType<ParsedItemToTaskLink>()
            .toList();
        expect(parsedItemLinks, hasLength(3));
        expect(taskLinks, hasLength(2));
      },
    );

    test(
      'persistParsedItems replaces previous parsed items and task links',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'demo prep',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        final oldItem =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-old',
                  agentId: _agentId,
                  captureId: capture.id,
                  kind: ParsedItemKind.matched,
                  title: 'Old',
                  categoryId: 'work',
                  confidence: ParsedItemConfidence.high,
                  confidenceScore: 0.9,
                  createdAt: _now,
                  vectorClock: null,
                  matchedTaskId: 'task-old',
                )
                as ParsedItemEntity;
        agentEntities
          ..[capture.id] = capture
          ..[oldItem.id] = oldItem;
        linksByFromAndType['capture-1:${AgentLinkTypes.captureToParsedItem}'] =
            [
              AgentLink.captureToParsedItem(
                id: 'old-capture-link',
                fromId: capture.id,
                toId: oldItem.id,
                createdAt: _now,
                updatedAt: _now,
                vectorClock: null,
              ),
            ];
        linksByFromAndType['parsed-old:${AgentLinkTypes.parsedItemToTask}'] = [
          AgentLink.parsedItemToTask(
            id: 'old-task-link',
            fromId: oldItem.id,
            toId: 'task-old',
            createdAt: _now,
            updatedAt: _now,
            vectorClock: null,
          ),
        ];

        final items = await createService().persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              'kind': 'newTask',
              'title': 'New',
              'categoryId': 'work',
              'confidenceScore': 0.1,
            },
          ],
        );

        expect(items, hasLength(1));
        expect(
          upsertedLinks.where((link) => link.deletedAt != null).map((link) {
            return link.id;
          }),
          containsAll(['old-capture-link', 'old-task-link']),
        );
        final deletedOld = upsertedEntities
            .whereType<ParsedItemEntity>()
            .singleWhere(
              (item) => item.id == oldItem.id,
            );
        expect(deletedOld.deletedAt, isNotNull);
      },
    );

    test('linkCapturePhraseToTask replaces existing task links', () async {
      final parsedItem =
          AgentDomainEntity.parsedItem(
                id: 'parsed-1',
                agentId: _agentId,
                captureId: 'capture-1',
                kind: ParsedItemKind.newTask,
                title: 'Prep demo',
                categoryId: 'work',
                confidence: ParsedItemConfidence.low,
                confidenceScore: 0.2,
                createdAt: _now,
                vectorClock: null,
              )
              as ParsedItemEntity;
      agentEntities[parsedItem.id] = parsedItem;
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );
      linksByFromAndType['parsed-1:${AgentLinkTypes.parsedItemToTask}'] = [
        AgentLink.parsedItemToTask(
          id: 'old-link',
          fromId: 'parsed-1',
          toId: 'old-task',
          createdAt: DateTime(2026, 5, 24),
          updatedAt: DateTime(2026, 5, 24),
          vectorClock: null,
        ),
      ];

      final service = createService();
      final updated = await service.linkCapturePhraseToTask(
        captureItemId: 'parsed-1',
        taskId: 'task-1',
      );

      expect(updated.matchedTaskId, 'task-1');
      expect(updated.kind, ParsedItemKind.matched);
      expect(updated.confidence, ParsedItemConfidence.high);
      expect(updated.lowConfidence, isFalse);
      expect(upsertedLinks.first.deletedAt, isNotNull);
      expect(upsertedLinks.last, isA<ParsedItemToTaskLink>());
    });

    test('breakCaptureLink removes links and resets item to new', () async {
      final parsedItem =
          AgentDomainEntity.parsedItem(
                id: 'parsed-1',
                agentId: _agentId,
                captureId: 'capture-1',
                kind: ParsedItemKind.matched,
                title: 'Prep demo',
                categoryId: 'work',
                confidence: ParsedItemConfidence.high,
                confidenceScore: 0.9,
                createdAt: _now,
                vectorClock: null,
                matchedTaskId: 'task-1',
              )
              as ParsedItemEntity;
      agentEntities[parsedItem.id] = parsedItem;
      linksByFromAndType['parsed-1:${AgentLinkTypes.parsedItemToTask}'] = [
        AgentLink.parsedItemToTask(
          id: 'link-1',
          fromId: 'parsed-1',
          toId: 'task-1',
          createdAt: _now,
          updatedAt: _now,
          vectorClock: null,
        ),
      ];

      final service = createService();
      final updated = await service.breakCaptureLink('parsed-1');

      expect(updated.matchedTaskId, isNull);
      expect(updated.kind, ParsedItemKind.newTask);
      expect(updated.confidence, ParsedItemConfidence.low);
      expect(upsertedLinks.single.deletedAt, isNotNull);
    });

    test('surfacePendingDecisions filters by allowed categories', () async {
      final overdue = _task(
        id: 'task-overdue',
        title: 'Overdue',
        status: _openStatus(),
        due: DateTime(2026, 5, 24),
      );
      final dueTodayWrongCategory = _task(
        id: 'task-home',
        title: 'Home',
        status: _openStatus(),
        categoryId: 'home',
        due: DateTime(2026, 5, 25),
      );
      final inProgress = _task(
        id: 'task-progress',
        title: 'Progress',
        status: _inProgressStatus(),
      );
      when(() => journalDb.getTasksDueOn(any())).thenAnswer(
        (_) async => [dueTodayWrongCategory],
      );
      when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
        (_) async => [overdue, dueTodayWrongCategory],
      );
      when(
        () => journalDb.getInProgressTasks(
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) async => [inProgress]);

      final items = await createService().surfacePendingDecisions(
        agentId: _agentId,
        dayId: 'dayplan-2026-05-25',
      );

      expect(items.map((item) => item.taskId), [
        'task-overdue',
        'task-progress',
      ]);
    });

    test('surfacePendingDecisions skips stale overdue tasks', () async {
      final recentOverdue = _task(
        id: 'task-recent-overdue',
        title: 'Recent overdue',
        status: _openStatus(),
        due: DateTime(2026, 5, 20),
      );
      final staleOverdue = _task(
        id: 'task-stale-overdue',
        title: 'Stale overdue',
        status: _openStatus(),
        due: DateTime(2026, 5, 10),
      );
      when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
        (_) async => [staleOverdue, recentOverdue],
      );

      final items = await createService().surfacePendingDecisions(
        agentId: _agentId,
        dayId: 'dayplan-2026-05-25',
      );

      expect(items.map((item) => item.taskId), ['task-recent-overdue']);
    });

    test('applyTriage done writes a completed task', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      Task? updatedTask;
      when(() => journalRepository.updateJournalEntity(any())).thenAnswer((
        invocation,
      ) async {
        updatedTask = invocation.positionalArguments.single as Task;
        return true;
      });

      final task = await withClock(Clock.fixed(_now), () {
        return createService().applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'done',
        );
      });

      expect(task.data.status, isA<TaskDone>());
      expect(updatedTask?.data.status, isA<TaskDone>());
      expect(updatedTask?.data.statusHistory.last, isA<TaskDone>());
    });

    test('applyTriage requires deferTo for defer actions', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      await expectLater(
        createService().applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'defer',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('applyTriage reports failed task writes', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );
      when(() => journalRepository.updateJournalEntity(any())).thenAnswer(
        (_) async => false,
      );

      await expectLater(
        createService().applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'today',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('matchToCorpus returns open FTS matches in result order', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );
      journalEntities['task-2'] = _task(
        id: 'task-2',
        title: 'Done demo',
        status: _doneStatus(),
      );
      journalEntities['task-3'] = _task(
        id: 'task-3',
        title: 'Home demo',
        status: _openStatus(),
        categoryId: 'home',
      );
      when(() => fts5Db.watchFullTextMatches('demo')).thenAnswer(
        (_) => Stream.value(['task-2', 'task-1', 'task-3']),
      );

      final matches = await createService().matchToCorpus(
        agentId: _agentId,
        phrase: 'demo',
      );

      expect(matches.map((match) => match.taskId), ['task-1']);
      expect(matches.single.score, 0.5);
    });

    test(
      'matchToCorpus skips FTS when category hint is outside scope',
      () async {
        final matches = await createService().matchToCorpus(
          agentId: _agentId,
          phrase: 'demo',
          categoryHint: 'home',
        );

        expect(matches, isEmpty);
        verifyNever(() => fts5Db.watchFullTextMatches(any()));
      },
    );

    test('executeTool returns JSON for parse_capture_to_items', () async {
      final capture =
          AgentDomainEntity.capture(
                id: 'capture-1',
                agentId: _agentId,
                transcript: 'prep demo',
                capturedAt: _now,
                createdAt: _now,
                vectorClock: null,
              )
              as CaptureEntity;
      agentEntities[capture.id] = capture;

      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.parseCaptureToItems,
        args: const {
          'captureId': 'capture-1',
          'items': [
            {
              'kind': 'newTask',
              'title': 'Prep demo',
              'categoryId': 'work',
              'confidenceScore': 0.1,
            },
          ],
        },
      );

      expect(result.success, isTrue);
      final decoded = jsonDecode(result.output) as Map<String, dynamic>;
      expect(decoded['captureId'], 'capture-1');
      expect(decoded['items'], isA<List<dynamic>>());
    });

    test(
      'executeTool creates a task and links the parsed capture item',
      () async {
        final parsed =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-1',
                  agentId: _agentId,
                  captureId: 'capture-1',
                  kind: ParsedItemKind.newTask,
                  title: 'Buy milk',
                  categoryId: 'work',
                  confidence: ParsedItemConfidence.low,
                  confidenceScore: 0.1,
                  createdAt: _now,
                  vectorClock: null,
                )
                as ParsedItemEntity;
        agentEntities[parsed.id] = parsed;

        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {
              'phrase': 'Buy milk',
              'category': 'work',
              'estimate': 15,
              'dueAnchor': 'today',
              'captureItemId': 'parsed-1',
            },
          );
        });

        expect(result.success, isTrue);
        final decoded = jsonDecode(result.output) as Map<String, dynamic>;
        expect(decoded['taskId'], 'created-task-1');
        expect(decoded['estimateMinutes'], 15);
        expect(
          DateTime.parse(decoded['due'] as String),
          DateTime(2026, 5, 25, 23, 59, 59, 999),
        );
        expect(createdTaskRequests.single.title, 'Buy milk');
        expect(createdTaskRequests.single.categoryId, 'work');

        final updatedParsed = upsertedEntities
            .whereType<ParsedItemEntity>()
            .single;
        expect(updatedParsed.id, 'parsed-1');
        expect(updatedParsed.kind, ParsedItemKind.matched);
        expect(updatedParsed.matchedTaskId, 'created-task-1');
        expect(upsertedLinks.whereType<ParsedItemToTaskLink>(), hasLength(1));
        expect(
          notifications,
          containsAll([_agentId, 'created-task-1', 'parsed-1']),
        );
      },
    );

    test('executeTool returns validation errors as tool responses', () async {
      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.submitCapture,
        args: const {'transcript': '   ', 'capturedAt': '2026-05-25T09:00'},
      );

      expect(result.success, isFalse);
      expect(result.output, contains('transcript must not be empty'));
    });

    test('executeTool reports an error for unknown tool names', () async {
      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: 'no_such_tool',
        args: const {},
      );

      expect(result.success, isFalse);
      expect(result.output, contains('unknown tool "no_such_tool"'));
    });

    test(
      'executeTool wraps unexpected exceptions and logs to DomainLogger',
      () async {
        when(() => agentRepository.getEntity(_agentId)).thenThrow(
          StateError('boom'),
        );

        final result = await createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.surfacePendingDecisions,
          args: const {'dayId': 'dayplan-2026-05-25'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('boom'));
        verify(
          () => domainLogger.error(
            LogDomain.agentWorkflow,
            any(),
            message: 'day-agent capture tool failed',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test('executeTool dispatches matchToCorpus', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );
      when(() => fts5Db.watchFullTextMatches('prep')).thenAnswer(
        (_) => Stream.value(['task-1']),
      );

      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.matchToCorpus,
        args: const {'phrase': 'prep'},
      );

      expect(result.success, isTrue);
      final decoded = jsonDecode(result.output) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>;
      expect(candidates, hasLength(1));
      expect(decoded['best'], isNotNull);
    });

    ParsedItemEntity seedNewTaskParsedItem({String? matchedTaskId}) {
      final parsedItem =
          AgentDomainEntity.parsedItem(
                id: 'parsed-1',
                agentId: _agentId,
                captureId: 'capture-1',
                kind: matchedTaskId == null
                    ? ParsedItemKind.newTask
                    : ParsedItemKind.matched,
                title: 'Prep demo',
                categoryId: 'work',
                confidence: matchedTaskId == null
                    ? ParsedItemConfidence.low
                    : ParsedItemConfidence.high,
                confidenceScore: 0.2,
                createdAt: _now,
                vectorClock: null,
                matchedTaskId: matchedTaskId,
              )
              as ParsedItemEntity;
      agentEntities[parsedItem.id] = parsedItem;
      return parsedItem;
    }

    test('executeTool dispatches link_capture_phrase_to_task', () async {
      seedNewTaskParsedItem();
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      final linkResult = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.linkCapturePhraseToTask,
        args: const {'captureItemId': 'parsed-1', 'taskId': 'task-1'},
      );

      expect(linkResult.success, isTrue);
      final item =
          (jsonDecode(linkResult.output) as Map<String, dynamic>)['item']
              as Map<String, dynamic>;
      // Linking flips the parsed item to a matched, high-confidence row.
      expect(item['matchedTaskId'], 'task-1');
      expect(item['kind'], ParsedItemKind.matched.name);
    });

    test('executeTool dispatches break_capture_link', () async {
      seedNewTaskParsedItem(matchedTaskId: 'task-1');
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      final breakResult = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.breakCaptureLink,
        args: const {'captureItemId': 'parsed-1'},
      );

      expect(breakResult.success, isTrue);
      final item =
          (jsonDecode(breakResult.output) as Map<String, dynamic>)['item']
              as Map<String, dynamic>;
      // Breaking clears the match and demotes the row back to a new task.
      expect(item['matchedTaskId'], isNull);
      expect(item['kind'], ParsedItemKind.newTask.name);
    });

    test('executeTool dispatches surface_pending_decisions', () async {
      final overdue = _task(
        id: 'task-overdue',
        title: 'Overdue',
        status: _openStatus(),
        due: DateTime(2026, 5, 24),
      );
      when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
        (_) async => [overdue],
      );

      final surfaceResult = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.surfacePendingDecisions,
        args: const {'dayId': 'dayplan-2026-05-25'},
      );

      expect(surfaceResult.success, isTrue);
      final items =
          (jsonDecode(surfaceResult.output) as Map<String, dynamic>)['items']
              as List<dynamic>;
      expect(
        items.map((item) => (item as Map<String, dynamic>)['taskId']),
        contains('task-overdue'),
      );
    });

    test('executeTool dispatches apply_triage', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      final triageResult = await withClock(Clock.fixed(_now), () {
        return createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.applyTriage,
          args: const {'taskId': 'task-1', 'action': 'today'},
        );
      });

      expect(triageResult.success, isTrue);
      final triageJson =
          jsonDecode(triageResult.output) as Map<String, dynamic>;
      expect(triageJson['taskId'], 'task-1');
      expect(triageJson['due'], isNotNull);
    });

    test('getCapture returns null for non-capture entities', () async {
      final identity = makeTestIdentity(
        id: 'other-agent',
        agentId: 'other-agent',
        kind: AgentKinds.dayAgent,
      );
      agentEntities[identity.id] = identity;

      final result = await createService().getCapture('other-agent');

      expect(result, isNull);
    });

    test('parsedItemsForCapture returns empty when no links exist', () async {
      final items = await createService().parsedItemsForCapture('capture-x');

      expect(items, isEmpty);
    });

    test('persistParsedItems rejects when the capture is missing', () async {
      await expectLater(
        createService().persistParsedItems(
          agentId: _agentId,
          captureId: 'capture-missing',
          rawItems: const [
            {
              'title': 'X',
              'categoryId': 'work',
              'confidenceScore': 0.1,
            },
          ],
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('persistParsedItems rejects when the agent is missing', () async {
      await expectLater(
        createService().persistParsedItems(
          agentId: 'agent-missing',
          captureId: 'capture-1',
          rawItems: const [],
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test(
      'persistParsedItems demotes invalid matched task to a new item',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'prep',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        agentEntities[capture.id] = capture;

        final items = await createService().persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              'kind': 'matched',
              'title': 'Phantom',
              'categoryId': 'work',
              'confidenceScore': 0.9,
              'matchedTaskId': 'task-does-not-exist',
            },
          ],
        );

        expect(items, hasLength(1));
        expect(items.single.kind, ParsedItemKind.newTask);
        expect(items.single.matchedTaskId, isNull);
        expect(items.single.confidence, ParsedItemConfidence.low);
        expect(items.single.lowConfidence, isTrue);
      },
    );

    test('persistParsedItems skips items with a disallowed category', () async {
      final capture =
          AgentDomainEntity.capture(
                id: 'capture-1',
                agentId: _agentId,
                transcript: 'prep',
                capturedAt: _now,
                createdAt: _now,
                vectorClock: null,
              )
              as CaptureEntity;
      agentEntities[capture.id] = capture;

      final items = await createService().persistParsedItems(
        agentId: _agentId,
        captureId: capture.id,
        rawItems: const [
          {
            'kind': 'newTask',
            'title': 'Home item',
            'categoryId': 'home',
            'confidenceScore': 0.9,
          },
          {
            'kind': 'newTask',
            'title': 'Work item',
            'categoryId': 'work',
            'confidenceScore': 0.1,
          },
          'not-a-map',
        ],
      );

      expect(items.map((item) => item.title), ['Work item']);
    });

    test('persistParsedItems rejects an unknown kind value', () async {
      final capture =
          AgentDomainEntity.capture(
                id: 'capture-1',
                agentId: _agentId,
                transcript: 'prep',
                capturedAt: _now,
                createdAt: _now,
                vectorClock: null,
              )
              as CaptureEntity;
      agentEntities[capture.id] = capture;

      await expectLater(
        createService().persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              'kind': 'bogus',
              'title': 'X',
              'categoryId': 'work',
              'confidenceScore': 0.1,
            },
          ],
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('persistParsedItems rejects items with an invalid score', () async {
      final capture =
          AgentDomainEntity.capture(
                id: 'capture-1',
                agentId: _agentId,
                transcript: 'prep',
                capturedAt: _now,
                createdAt: _now,
                vectorClock: null,
              )
              as CaptureEntity;
      agentEntities[capture.id] = capture;

      await expectLater(
        createService().persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              'title': 'X',
              'categoryId': 'work',
              'confidenceScore': 1.5,
            },
          ],
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test(
      'linkCapturePhraseToTask rejects when the parsed item is missing',
      () async {
        await expectLater(
          createService().linkCapturePhraseToTask(
            captureItemId: 'parsed-missing',
            taskId: 'task-1',
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      },
    );

    test('linkCapturePhraseToTask rejects when the task is missing', () async {
      final parsedItem =
          AgentDomainEntity.parsedItem(
                id: 'parsed-1',
                agentId: _agentId,
                captureId: 'capture-1',
                kind: ParsedItemKind.newTask,
                title: 'Prep demo',
                categoryId: 'work',
                confidence: ParsedItemConfidence.low,
                confidenceScore: 0.2,
                createdAt: _now,
                vectorClock: null,
              )
              as ParsedItemEntity;
      agentEntities[parsedItem.id] = parsedItem;

      await expectLater(
        createService().linkCapturePhraseToTask(
          captureItemId: 'parsed-1',
          taskId: 'task-missing',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('breakCaptureLink rejects when the parsed item is missing', () async {
      await expectLater(
        createService().breakCaptureLink('parsed-missing'),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('matchToCorpus rejects empty phrases', () async {
      await expectLater(
        createService().matchToCorpus(agentId: _agentId, phrase: '   '),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('matchToCorpus returns empty when FTS has no results', () async {
      when(() => fts5Db.watchFullTextMatches('demo')).thenAnswer(
        (_) => Stream.value(const <String>[]),
      );

      final matches = await createService().matchToCorpus(
        agentId: _agentId,
        phrase: 'demo',
      );

      expect(matches, isEmpty);
    });

    test('surfacePendingDecisions rejects invalid dayIds', () async {
      await expectLater(
        createService().surfacePendingDecisions(
          agentId: _agentId,
          dayId: 'not-a-day',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('applyTriage rejects unknown actions', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      await expectLater(
        createService().applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'mystery',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('applyTriage throws when the task is missing', () async {
      await expectLater(
        createService().applyTriage(
          agentId: _agentId,
          taskId: 'task-missing',
          action: 'today',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('applyTriage today sets due to end of day', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      final task = await withClock(Clock.fixed(_now), () {
        return createService().applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'today',
        );
      });

      final due = task.data.due!;
      expect(due.year, _now.year);
      expect(due.month, _now.month);
      expect(due.day, _now.day);
      expect(due.hour, 23);
      expect(due.minute, 59);
    });

    test('applyTriage today reopens blocked and on-hold tasks', () async {
      final statuses = <String, TaskStatus>{
        'task-blocked': TaskStatus.blocked(
          id: 'status-blocked',
          createdAt: DateTime(2026, 5, 24),
          utcOffset: 120,
          reason: 'waiting',
        ),
        'task-on-hold': TaskStatus.onHold(
          id: 'status-on-hold',
          createdAt: DateTime(2026, 5, 24),
          utcOffset: 120,
          reason: 'parked',
        ),
      };

      for (final entry in statuses.entries) {
        journalEntities[entry.key] =
            JournalEntity.task(
                  meta: Metadata(
                    id: entry.key,
                    createdAt: DateTime(2026, 5, 24),
                    updatedAt: DateTime(2026, 5, 24),
                    dateFrom: DateTime(2026, 5, 24),
                    dateTo: DateTime(2026, 5, 24, 1),
                    categoryId: 'work',
                  ),
                  data: TaskData(
                    status: entry.value,
                    statusHistory: [entry.value],
                    dateFrom: DateTime(2026, 5, 24),
                    dateTo: DateTime(2026, 5, 24, 1),
                    title: 'Blocked',
                  ),
                )
                as Task;

        final task = await withClock(Clock.fixed(_now), () {
          return createService().applyTriage(
            agentId: _agentId,
            taskId: entry.key,
            action: 'today',
          );
        });

        expect(task.data.status, isA<TaskOpen>());
        expect(task.data.statusHistory, hasLength(2));
      }
    });

    test('applyTriage doNow and drop drive status transitions', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      final service = createService();

      final inProgress = await withClock(Clock.fixed(_now), () {
        return service.applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'do_now',
        );
      });
      expect(inProgress.data.status, isA<TaskInProgress>());

      final dropped = await withClock(Clock.fixed(_now), () {
        return service.applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'drop',
        );
      });
      expect(dropped.data.status, isA<TaskRejected>());
    });

    test('applyTriage defer sets due to end of deferTo day', () async {
      journalEntities['task-1'] = _task(
        id: 'task-1',
        title: 'Prep demo',
        status: _openStatus(),
      );

      final task = await withClock(Clock.fixed(_now), () {
        return createService().applyTriage(
          agentId: _agentId,
          taskId: 'task-1',
          action: 'defer',
          deferTo: DateTime(2026, 6, 1, 10),
        );
      });

      expect(task.data.due, DateTime(2026, 6, 1, 23, 59, 59, 999));
    });

    test(
      'applyTriage rejects a task outside the allowed categories without '
      'writing',
      () async {
        // The default identity allows {'work'} only; triage mutates task
        // status / due dates, so a planner must not reach tasks outside
        // its configured scope.
        journalEntities['task-home'] = _task(
          id: 'task-home',
          title: 'Tidy kitchen',
          status: _openStatus(),
          categoryId: 'home',
        );

        await expectLater(
          createService().applyTriage(
            agentId: _agentId,
            taskId: 'task-home',
            action: 'done',
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('outside the allowed categories'),
            ),
          ),
        );
        verifyNever(() => journalRepository.updateJournalEntity(any()));
      },
    );

    test(
      'applyTriage allows any category when the identity allow-list is empty',
      () async {
        // Empty allowedCategoryIds means "allow all" — same semantics as the
        // capture-side _categoryAllowed gate.
        agentEntities[_agentId] = makeTestIdentity(
          id: _agentId,
          agentId: _agentId,
          kind: AgentKinds.dayAgent,
        );
        journalEntities['task-home'] = _task(
          id: 'task-home',
          title: 'Tidy kitchen',
          status: _openStatus(),
          categoryId: 'home',
        );

        final task = await withClock(Clock.fixed(_now), () {
          return createService().applyTriage(
            agentId: _agentId,
            taskId: 'task-home',
            action: 'done',
          );
        });

        expect(task.data.status, isA<TaskDone>());
        verify(() => journalRepository.updateJournalEntity(any())).called(1);
      },
    );

    test('buildTaskCorpusSnapshot excludes closed tasks', () async {
      final open = _task(
        id: 'task-open',
        title: 'Open',
        status: _openStatus(),
        due: DateTime(2026, 5, 25, 12),
      );
      final done = _task(
        id: 'task-done',
        title: 'Already done',
        status: _doneStatus(),
        due: DateTime(2026, 5, 24, 12),
      );
      when(() => journalDb.getTasksDueOnOrBefore(any())).thenAnswer(
        (_) async => [done, open],
      );

      final snapshot = await createService().buildTaskCorpusSnapshot(
        allowedCategoryIds: {'work'},
        day: DateTime(2026, 5, 25, 8),
      );

      expect(snapshot.map((item) => item['taskId']), ['task-open']);
    });

    test('buildTaskCorpusSnapshot includes in-progress tasks', () async {
      final inProgress = _task(
        id: 'task-progress',
        title: 'Active work',
        status: _inProgressStatus(),
      );
      when(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [inProgress]);

      final snapshot = await createService().buildTaskCorpusSnapshot(
        allowedCategoryIds: {'work'},
        day: DateTime(2026, 5, 25, 8),
      );

      // In-progress tasks are not "closed" so they survive into the corpus
      // and carry their live status string through to the snapshot.
      expect(snapshot.map((item) => item['taskId']), ['task-progress']);
      expect(snapshot.single['status'], 'IN PROGRESS');
    });

    test(
      'executeTool rejects malformed capturedAt with a tool-response error',
      () async {
        final result = await createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.submitCapture,
          args: const {
            'transcript': 'prep demo',
            'capturedAt': 'not-a-date',
          },
        );

        expect(result.success, isFalse);
        expect(
          result.output,
          contains('capturedAt must be a valid ISO-8601 date-time'),
        );
      },
    );

    test(
      'parsed estimateMinutes ignores fractional numbers from the model',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'prep',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        agentEntities[capture.id] = capture;

        final items = await createService().persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              'title': 'Fractional minutes',
              'categoryId': 'work',
              'confidenceScore': 0.1,
              'estimateMinutes': 15.9,
            },
            {
              'title': 'Integer minutes',
              'categoryId': 'work',
              'confidenceScore': 0.1,
              'estimateMinutes': 20,
            },
            {
              'title': 'Whole double',
              'categoryId': 'work',
              'confidenceScore': 0.1,
              'estimateMinutes': 30.0,
            },
          ],
        );

        expect(items, hasLength(3));
        expect(items[0].estimateMinutes, isNull);
        expect(items[1].estimateMinutes, 20);
        expect(items[2].estimateMinutes, 30);
      },
    );

    // ── id-based tiebreaker when createdAt is equal (line 196) ───────────────

    test(
      'parsedItemsForCapture breaks createdAt ties by id (alphabetical)',
      () async {
        final sharedTime = DateTime(2026, 5, 25, 9);
        final itemB =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-b',
                  agentId: _agentId,
                  captureId: 'capture-tiebreak',
                  kind: ParsedItemKind.newTask,
                  title: 'Item B',
                  categoryId: 'work',
                  confidence: ParsedItemConfidence.low,
                  confidenceScore: 0.1,
                  createdAt: sharedTime,
                  vectorClock: null,
                )
                as ParsedItemEntity;
        final itemA = itemB.copyWith(id: 'parsed-a', title: 'Item A');
        agentEntities
          ..[itemB.id] = itemB
          ..[itemA.id] = itemA;
        linksByFromAndType['capture-tiebreak:${AgentLinkTypes.captureToParsedItem}'] =
            [
              AgentLink.captureToParsedItem(
                id: 'link-b',
                fromId: 'capture-tiebreak',
                toId: itemB.id,
                createdAt: sharedTime,
                updatedAt: sharedTime,
                vectorClock: null,
              ),
              AgentLink.captureToParsedItem(
                id: 'link-a',
                fromId: 'capture-tiebreak',
                toId: itemA.id,
                createdAt: sharedTime,
                updatedAt: sharedTime,
                vectorClock: null,
              ),
            ];

        final items = await createService().parsedItemsForCapture(
          'capture-tiebreak',
        );

        // 'parsed-a' < 'parsed-b' alphabetically → itemA comes first
        expect(items.map((i) => i.id), ['parsed-a', 'parsed-b']);
      },
    );

    // ── surfacePendingDecisions: missedRecurring + dueToday (lines 334-335, 338)

    test(
      'surfacePendingDecisions includes missed recurring and due-today tasks',
      () async {
        final missed = _task(
          id: 'task-missed',
          title: 'Missed recurring',
          status: _openStatus(),
        );
        final dueToday = _task(
          id: 'task-due-today',
          title: 'Due today',
          status: _openStatus(),
          due: DateTime(2026, 5, 25),
        );
        when(() => journalDb.getTasksDueOn(any())).thenAnswer(
          (_) async => [dueToday],
        );
        when(
          () => journalDb.getMissedRecurringTasks(
            asOf: any(named: 'asOf'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async => [missed]);

        final items = await createService().surfacePendingDecisions(
          agentId: _agentId,
          dayId: 'dayplan-2026-05-25',
        );

        final kinds = {
          for (final item in items) item.taskId: item.kind,
        };
        expect(kinds['task-missed'], DayAgentPendingKind.missedRecurring);
        expect(kinds['task-due-today'], DayAgentPendingKind.dueToday);
      },
    );

    // ── linkCapturePhraseToTask preserves non-newTask kind (line 415) ─────────

    test(
      'linkCapturePhraseToTask preserves kind when item is already matched',
      () async {
        final parsedItem =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-matched',
                  agentId: _agentId,
                  captureId: 'capture-1',
                  kind: ParsedItemKind.matched,
                  title: 'Prep demo',
                  categoryId: 'work',
                  confidence: ParsedItemConfidence.medium,
                  confidenceScore: 0.6,
                  createdAt: _now,
                  vectorClock: null,
                  matchedTaskId: 'task-old',
                )
                as ParsedItemEntity;
        agentEntities[parsedItem.id] = parsedItem;
        journalEntities['task-new'] = _task(
          id: 'task-new',
          title: 'New task',
          status: _openStatus(),
        );

        final updated = await createService().linkCapturePhraseToTask(
          captureItemId: 'parsed-matched',
          taskId: 'task-new',
        );

        // kind was already 'matched', should remain 'matched' (not re-promoted)
        expect(updated.kind, ParsedItemKind.matched);
        expect(updated.matchedTaskId, 'task-new');
        expect(updated.confidence, ParsedItemConfidence.high);
      },
    );

    // ── _submitCaptureTool: no capturedAt (line 519/522-523/525) ─────────────

    test(
      'executeTool submit_capture uses clock.now() when capturedAt is absent',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.submitCapture,
            args: const {'transcript': 'hello world'},
          );
        });

        expect(result.success, isTrue);
        final decoded = jsonDecode(result.output) as Map<String, dynamic>;
        expect(decoded['captureId'], isA<String>());
        // The persisted capture should have capturedAt == _now
        final capture = upsertedEntities.whereType<CaptureEntity>().single;
        expect(capture.capturedAt, _now);
        expect(capture.transcript, 'hello world');
      },
    );

    test(
      'executeTool submit_capture stores non-empty audioRef',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.submitCapture,
            args: const {
              'transcript': 'audio capture',
              'audioRef': 'audio-ref-123',
            },
          );
        });

        expect(result.success, isTrue);
        final capture = upsertedEntities.whereType<CaptureEntity>().single;
        expect(capture.audioRef, 'audio-ref-123');
      },
    );

    // ── createTaskFromPhrase: disallowed category (line 612) ─────────────────

    test(
      'createTaskFromPhrase rejects a category not in allowedCategoryIds',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {'phrase': 'Fix leak', 'category': 'home'},
          );
        });

        expect(result.success, isFalse);
        expect(result.output, contains('home'));
        expect(createdTaskRequests, isEmpty);
      },
    );

    // ── createTaskFromPhrase: dueAnchor 'tomorrow' (lines 622, 907-908) ──────

    test(
      'createTaskFromPhrase with dueAnchor tomorrow sets due to end of tomorrow',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {
              'phrase': 'Buy groceries',
              'category': 'work',
              'dueAnchor': 'tomorrow',
            },
          );
        });

        expect(result.success, isTrue);
        final decoded = jsonDecode(result.output) as Map<String, dynamic>;
        final due = DateTime.parse(decoded['due'] as String);
        // tomorrow = 2026-05-26 23:59:59.999
        expect(due, DateTime(2026, 5, 26, 23, 59, 59, 999));
        expect(createdTaskRequests.single.title, 'Buy groceries');
      },
    );

    // ── createTaskFromPhrase: invalid dueAnchor throws (line 914) ────────────

    test(
      'createTaskFromPhrase with malformed dueAnchor returns a tool error',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {
              'phrase': 'Buy groceries',
              'category': 'work',
              'dueAnchor': 'next-week',
            },
          );
        });

        expect(result.success, isFalse);
        expect(result.output, contains('dueAnchor'));
        expect(result.output, contains('next-week'));
        expect(createdTaskRequests, isEmpty);
      },
    );

    // ── createTaskFromPhrase: profileId from category (line 622) ─────────────

    test(
      'createTaskFromPhrase passes defaultProfileId from category to factory',
      () async {
        final category =
            EntityDefinition.categoryDefinition(
                  id: 'work',
                  createdAt: _now,
                  updatedAt: _now,
                  name: 'Work',
                  vectorClock: null,
                  private: false,
                  active: true,
                  defaultProfileId: 'profile-work',
                )
                as CategoryDefinition;
        when(() => journalDb.getCategoryById('work')).thenAnswer(
          (_) async => category,
        );

        await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {'phrase': 'Run tests', 'category': 'work'},
          );
        });

        expect(createdTaskRequests.single.profileId, 'profile-work');
      },
    );

    // ── _categoryFilterForHint returns {hint} when hint is allowed (line 939) ─

    test(
      'matchToCorpus restricts to allowed category hint',
      () async {
        // Agent has allowedCategoryIds: {'work'}; hint is also 'work'
        // → _categoryFilterForHint returns {'work'}, FTS runs.
        journalEntities['task-1'] = _task(
          id: 'task-1',
          title: 'Write report',
          status: _openStatus(),
        );
        when(() => fts5Db.watchFullTextMatches('report')).thenAnswer(
          (_) => Stream.value(['task-1']),
        );

        final matches = await createService().matchToCorpus(
          agentId: _agentId,
          phrase: 'report',
          categoryHint: 'work',
        );

        expect(matches.map((m) => m.taskId), ['task-1']);
        verify(() => fts5Db.watchFullTextMatches('report')).called(1);
      },
    );

    // ── _categoryFilterForHint: empty allowedCategoryIds → null (line 933) ───

    test(
      'matchToCorpus with no allowed categories and no hint allows all tasks',
      () async {
        // Agent with empty allowedCategoryIds
        agentEntities[_agentId] = makeTestIdentity(
          id: _agentId,
          agentId: _agentId,
          kind: AgentKinds.dayAgent,
          // ignore: avoid_redundant_argument_values
          allowedCategoryIds: const {},
        );
        journalEntities['task-any'] = _task(
          id: 'task-any',
          title: 'Anything',
          status: _openStatus(),
          categoryId: 'other',
        );
        when(() => fts5Db.watchFullTextMatches('any')).thenAnswer(
          (_) => Stream.value(['task-any']),
        );

        final matches = await createService().matchToCorpus(
          agentId: _agentId,
          phrase: 'any',
        );

        expect(matches.map((m) => m.taskId), ['task-any']);
      },
    );

    // ── _endOfDay UTC branch (line 957) ──────────────────────────────────────

    test(
      'applyTriage defer with a UTC deferTo date produces a UTC end-of-day',
      () async {
        journalEntities['task-1'] = _task(
          id: 'task-1',
          title: 'Prep demo',
          status: _openStatus(),
        );

        final task = await withClock(Clock.fixed(_now), () {
          return createService().applyTriage(
            agentId: _agentId,
            taskId: 'task-1',
            action: 'defer',
            deferTo: DateTime.utc(2026, 6, 10, 8),
          );
        });

        final due = task.data.due!;
        expect(due.isUtc, isTrue);
        expect(due.year, 2026);
        expect(due.month, 6);
        expect(due.day, 10);
        expect(due.hour, 23);
        expect(due.minute, 59);
        expect(due.second, 59);
      },
    );

    // ── createTaskFromPhrase: factory returns null (line 624-626) ────────────

    test(
      'createTaskFromPhrase returns a tool error when factory returns null',
      () async {
        final service = DayAgentCaptureService(
          agentRepository: agentRepository,
          syncService: syncService,
          journalDb: journalDb,
          journalRepository: journalRepository,
          fts5Db: fts5Db,
          orchestrator: orchestrator,
          domainLogger: domainLogger,
          taskFactory:
              ({
                required String title,
                required String categoryId,
                required DateTime now,
                int? estimateMinutes,
                DateTime? due,
                String? profileId,
              }) async => null,
          onPersistedStateChanged: notifications.add,
        );

        final result = await withClock(Clock.fixed(_now), () {
          return service.executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {'phrase': 'Will fail', 'category': 'work'},
          );
        });

        expect(result.success, isFalse);
        expect(result.output, contains('failed to create task'));
      },
    );

    // ── _defaultTaskFactory delegates to PersistenceLogic (lines 961-987) ─────

    test(
      'default task factory delegates to PersistenceLogic.createTaskEntry',
      () async {
        // Construct the service WITHOUT a taskFactory override so the
        // production _defaultTaskFactory (getIt<PersistenceLogic>()) is used.
        final persistenceLogic = MockPersistenceLogic();
        if (getIt.isRegistered<PersistenceLogic>()) {
          getIt.unregister<PersistenceLogic>();
        }
        getIt.registerSingleton<PersistenceLogic>(persistenceLogic);
        addTearDown(() => getIt.unregister<PersistenceLogic>());

        final category =
            EntityDefinition.categoryDefinition(
                  id: 'work',
                  createdAt: _now,
                  updatedAt: _now,
                  name: 'Work',
                  vectorClock: null,
                  private: false,
                  active: true,
                  defaultProfileId: 'profile-work',
                )
                as CategoryDefinition;
        when(() => journalDb.getCategoryById('work')).thenAnswer(
          (_) async => category,
        );

        final createdTask = _task(
          id: 'persisted-task-1',
          title: 'Run integration tests',
          status: _openStatus(),
        );
        when(
          () => persistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdTask);

        final service = DayAgentCaptureService(
          agentRepository: agentRepository,
          syncService: syncService,
          journalDb: journalDb,
          journalRepository: journalRepository,
          fts5Db: fts5Db,
          orchestrator: orchestrator,
          domainLogger: domainLogger,
          onPersistedStateChanged: notifications.add,
        );

        final result = await withClock(Clock.fixed(_now), () {
          return service.executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {
              'phrase': 'Run integration tests',
              'category': 'work',
              'estimate': 45,
              'dueAnchor': 'tomorrow',
            },
          );
        });

        // The persisted task flows back through the tool result.
        expect(result.success, isTrue);
        final decoded = jsonDecode(result.output) as Map<String, dynamic>;
        expect(decoded['title'], 'Run integration tests');

        // Capture and assert the arguments the default factory forwarded to
        // PersistenceLogic.createTaskEntry.
        final captured = verify(
          () => persistenceLogic.createTaskEntry(
            data: captureAny(named: 'data'),
            entryText: captureAny(named: 'entryText'),
            categoryId: captureAny(named: 'categoryId'),
          ),
        ).captured;
        final data = captured[0] as TaskData;
        final entryText = captured[1] as EntryText;
        final categoryId = captured[2] as String?;

        expect(categoryId, 'work');
        expect(data.title, 'Run integration tests');
        expect(data.estimate, const Duration(minutes: 45));
        // profileId is taken from the resolved category's defaultProfileId.
        expect(data.profileId, 'profile-work');
        // due is the end of tomorrow (dueAnchor: 'tomorrow' relative to _now).
        expect(data.due, isNotNull);
        expect(data.due!.day, _now.add(const Duration(days: 1)).day);
        // dateFrom/dateTo are pinned to clock.now().
        expect(data.dateFrom, _now);
        expect(data.dateTo, _now);
        // Fresh tasks start in the open state with a generated status id.
        expect(data.status.toDbString, 'OPEN');
        expect(data.status.id, isNotEmpty);
        expect(data.status.createdAt, _now);
        expect(
          data.status.utcOffset,
          _now.timeZoneOffset.inMinutes,
        );
        // entryText mirrors the phrase as both plain text and markdown.
        expect(entryText.plainText, 'Run integration tests');
        expect(entryText.markdown, 'Run integration tests');
      },
    );

    // ── _parseCaptureTool: empty/non-list items (line 534-536) ───────────────

    test(
      'executeTool parse_capture_to_items rejects a non-list items value',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'test',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        agentEntities[capture.id] = capture;

        final result = await createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.parseCaptureToItems,
          args: const {'captureId': 'capture-1', 'items': 'not-a-list'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('items must be a non-empty array'));
      },
    );

    test(
      'executeTool parse_capture_to_items rejects an empty items list',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'test',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        agentEntities[capture.id] = capture;

        final result = await createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.parseCaptureToItems,
          args: const {'captureId': 'capture-1', 'items': <dynamic>[]},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('items must be a non-empty array'));
      },
    );

    // ── createTaskFromPhrase without captureItemId (no entity update) ─────────

    test(
      'createTaskFromPhrase without captureItemId skips entity upsert',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.createTaskFromPhrase,
            args: const {'phrase': 'Solo task', 'category': 'work'},
          );
        });

        expect(result.success, isTrue);
        final decoded = jsonDecode(result.output) as Map<String, dynamic>;
        expect(decoded['title'], 'Solo task');
        // no parsed item should have been upserted
        expect(upsertedEntities.whereType<ParsedItemEntity>(), isEmpty);
        // notifications: agentId and taskId, but no captureItemId
        expect(notifications, containsAll([_agentId, 'created-task-1']));
        expect(notifications, hasLength(2));
      },
    );

    // ── buildTaskCorpusSnapshot: limit enforcement ────────────────────────────

    test(
      'buildTaskCorpusSnapshot respects the limit parameter',
      () async {
        final tasks = List.generate(
          5,
          (i) => _task(
            id: 'task-$i',
            title: 'Task $i',
            status: _openStatus(),
          ),
        );
        when(
          () => journalDb.getOpenTasksForDayAgentCorpus(
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => tasks);

        final snapshot = await createService().buildTaskCorpusSnapshot(
          allowedCategoryIds: {'work'},
          day: DateTime(2026, 5, 25),
          limit: 3,
        );

        expect(snapshot, hasLength(3));
      },
    );

    // ── persistParsedItems: closed matched task is demoted (line 718-724) ────

    test(
      'persistParsedItems demotes a matched-but-closed task to newTask',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'prep',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        agentEntities[capture.id] = capture;
        journalEntities['task-done'] = _task(
          id: 'task-done',
          title: 'Already done',
          status: _doneStatus(),
        );

        final items = await createService().persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              'kind': 'matched',
              'title': 'Done task',
              'categoryId': 'work',
              'confidenceScore': 0.9,
              'matchedTaskId': 'task-done',
            },
          ],
        );

        expect(items.single.kind, ParsedItemKind.newTask);
        expect(items.single.matchedTaskId, isNull);
        expect(items.single.lowConfidence, isTrue);
      },
    );

    // ── persistParsedItems: matched task promotes newTask kind (line 725-727)

    test(
      'persistParsedItems promotes kind to matched when auto-link succeeds '
      'and model omits kind',
      () async {
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: _agentId,
                  transcript: 'prep',
                  capturedAt: _now,
                  createdAt: _now,
                  vectorClock: null,
                )
                as CaptureEntity;
        agentEntities[capture.id] = capture;
        journalEntities['task-1'] = _task(
          id: 'task-1',
          title: 'Prep demo',
          status: _openStatus(),
        );

        final items = await createService().persistParsedItems(
          agentId: _agentId,
          captureId: capture.id,
          rawItems: const [
            {
              // No 'kind' field — defaults to newTask, but auto-link has high
              // score → should be promoted to matched.
              'title': 'Prep demo',
              'categoryId': 'work',
              'confidenceScore': 0.9,
              'matchedTaskId': 'task-1',
            },
          ],
        );

        expect(items.single.kind, ParsedItemKind.matched);
        expect(items.single.matchedTaskId, 'task-1');
      },
    );
  });
}
