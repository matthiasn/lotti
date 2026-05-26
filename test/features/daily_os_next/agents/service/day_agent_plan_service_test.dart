import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../features/agents/test_data/entity_factories.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

const _agentId = 'day-agent-001';
const _dayId = 'dayplan-2026-05-25';
const _threadId = 'thread-001';
const _runKey = 'run-key-001';
final _now = DateTime(2026, 5, 25, 9);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late MockDomainLogger domainLogger;
  late Map<String, AgentDomainEntity> agentEntities;
  late List<AgentDomainEntity> upsertedEntities;
  late List<AgentLink> upsertedLinks;
  late List<String> notifications;

  DayAgentPlanService createService() {
    return DayAgentPlanService(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      domainLogger: domainLogger,
      onPersistedStateChanged: notifications.add,
    );
  }

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
    domainLogger = MockDomainLogger();
    agentEntities = {
      _agentId: makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
        kind: AgentKinds.dayAgent,
        allowedCategoryIds: {'work', 'life'},
      ),
      'capture-001': AgentDomainEntity.capture(
        id: 'capture-001',
        agentId: _agentId,
        transcript: 'prep demo',
        capturedAt: _now,
        createdAt: _now,
        vectorClock: null,
      ),
    };
    upsertedEntities = <AgentDomainEntity>[];
    upsertedLinks = <AgentLink>[];
    notifications = <String>[];

    when(() => agentRepository.getEntity(any())).thenAnswer((invocation) async {
      return agentEntities[invocation.positionalArguments.single as String];
    });
    when(
      () => agentRepository.getEntitiesByAgentId(
        any(),
        type: any(named: 'type'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((invocation) async {
      final agentId = invocation.positionalArguments.single as String;
      final type = invocation.namedArguments[#type] as String?;
      return [
        for (final entity in agentEntities.values)
          if (entity.agentId == agentId &&
              (type == null || AgentEntityTypes.dayPlan == type) &&
              entity is DayPlanEntity)
            entity,
      ];
    });
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      upsertedEntities.add(entity);
      agentEntities[entity.id] = entity;
    });
    when(() => syncService.upsertLink(any())).thenAnswer((invocation) async {
      upsertedLinks.add(invocation.positionalArguments.single as AgentLink);
    });
  });

  group('DayAgentPlanService', () {
    test(
      'persistDraftPlan writes plan entity, pinned tasks, and capture link',
      () async {
        final service = createService();

        final plan = await withClock(Clock.fixed(_now), () {
          return service.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: DateTime(2026, 5, 25),
            captureId: 'capture-001',
            decidedTaskIds: const ['task-1'],
            capacityMinutes: 360,
            rawBlocks: [
              {
                'id': 'block-1',
                'title': 'Prep demo',
                'taskId': 'task-1',
                'categoryId': 'work',
                'start': DateTime(2026, 5, 25, 9).toIso8601String(),
                'end': DateTime(2026, 5, 25, 10).toIso8601String(),
                'type': 'ai',
                'reason': 'High-energy focus window.',
              },
              {
                'id': 'block-2',
                'title': 'Transition',
                'categoryId': 'life',
                'start': DateTime(2026, 5, 25, 10).toIso8601String(),
                'end': DateTime(2026, 5, 25, 10, 15).toIso8601String(),
                'type': 'buffer',
              },
            ],
            rawEnergyBands: [
              {
                'start': DateTime(2026, 5, 25, 9).toIso8601String(),
                'end': DateTime(2026, 5, 25, 12).toIso8601String(),
                'level': 'high',
                'label': 'HIGH ENERGY',
              },
            ],
          );
        });

        expect(plan.id, 'day_agent_plan:$_dayId');
        expect(plan.capacityMinutes, 360);
        expect(plan.scheduledMinutes, 75);
        expect(plan.data.plannedBlocks, hasLength(2));
        expect(plan.data.pinnedTasks.single.taskId, 'task-1');
        expect(
          plan.data.plannedBlocks.first.reason,
          'High-energy focus window.',
        );
        expect(plan.data.plannedBlocks.last.type, PlannedBlockType.buffer);
        expect(plan.energyBands.single.level, DayAgentEnergyLevel.high);
        expect(upsertedEntities.single, isA<DayPlanEntity>());
        expect(upsertedLinks.single, isA<CaptureToPlanLink>());
        expect(notifications, containsAll([_agentId, _dayId, plan.id]));
      },
    );

    test('persistDraftPlan rejects AI blocks without reasons', () async {
      await expectLater(
        createService().persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: DateTime(2026, 5, 25),
          rawBlocks: [
            {
              'title': 'Prep demo',
              'categoryId': 'work',
              'start': DateTime(2026, 5, 25, 9).toIso8601String(),
              'end': DateTime(2026, 5, 25, 10).toIso8601String(),
              'type': 'ai',
            },
          ],
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('persistDraftPlan rejects task IDs outside decidedTaskIds', () async {
      await expectLater(
        createService().persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: DateTime(2026, 5, 25),
          decidedTaskIds: const ['task-1'],
          rawBlocks: [
            {
              'title': 'Prep demo',
              'taskId': 'task-2',
              'categoryId': 'work',
              'start': DateTime(2026, 5, 25, 9).toIso8601String(),
              'end': DateTime(2026, 5, 25, 10).toIso8601String(),
              'type': 'ai',
              'reason': 'Requested focus work.',
            },
          ],
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('persistDraftPlan rejects categories outside agent scope', () async {
      await expectLater(
        createService().persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: DateTime(2026, 5, 25),
          rawBlocks: [_aiBlock(categoryId: 'blocked-category')],
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('persistDraftPlan allows non-AI blocks without reasons', () async {
      final plan = await withClock(Clock.fixed(_now), () {
        return createService().persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: DateTime(2026, 5, 25),
          decidedTaskIds: const ['task-1'],
          rawBlocks: [
            _aiBlock(taskId: 'task-1'),
            _aiBlock(
              id: 'block-2',
              taskId: 'task-1',
              start: DateTime(2026, 5, 25, 10),
              end: DateTime(2026, 5, 25, 10, 30),
              type: 'manual',
              reason: null,
            ),
          ],
        );
      });

      expect(plan.data.plannedBlocks.last.type, PlannedBlockType.manual);
      expect(plan.data.plannedBlocks.last.reason, isNull);
      expect(plan.data.pinnedTasks, hasLength(1));
      expect(plan.data.pinnedTasks.single.taskId, 'task-1');
    });

    test(
      'persistDraftPlan rejects energy bands outside the plan day',
      () async {
        await expectLater(
          createService().persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: DateTime(2026, 5, 25),
            rawBlocks: [_aiBlock()],
            rawEnergyBands: [
              {
                'start': DateTime(2026, 5, 24, 23).toIso8601String(),
                'end': DateTime(2026, 5, 25).toIso8601String(),
                'level': 'high',
                'label': 'LATE',
              },
            ],
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      },
    );

    test('executeTool returns JSON for draft_day_plan', () async {
      final result = await withClock(Clock.fixed(_now), () {
        return createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': _dayId,
            'dayDate': DateTime(2026, 5, 25).toIso8601String(),
            'blocks': [
              {
                'title': 'Prep demo',
                'categoryId': 'work',
                'start': DateTime(2026, 5, 25, 9).toIso8601String(),
                'end': DateTime(2026, 5, 25, 10).toIso8601String(),
                'type': 'ai',
                'reason': 'High-energy focus window.',
              },
            ],
          },
        );
      });

      expect(result.success, isTrue);
      final data = jsonDecode(result.output) as Map<String, dynamic>;
      expect(data['planId'], 'day_agent_plan:$_dayId');
      expect(data['scheduledMinutes'], 60);
      expect(data['blocks'], isA<List<dynamic>>());
    });

    test('executeTool reports validation failures without throwing', () async {
      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: {
          'dayId': _dayId,
          'decidedTaskIds': 'task-1',
          'blocks': [_aiBlock()],
        },
      );

      expect(result.success, isFalse);
      expect(result.output, contains('decidedTaskIds must be an array'));
    });

    test(
      'summarizeRecentPatterns returns capacity-aware transient cards',
      () async {
        final yesterday = AgentDomainEntity.dayPlan(
          id: 'day_agent_plan:dayplan-2026-05-24',
          agentId: _agentId,
          dayId: 'dayplan-2026-05-24',
          planDate: DateTime(2026, 5, 24),
          data: DayPlanData(
            planDate: DateTime(2026, 5, 24),
            status: const DayPlanStatus.draft(),
            plannedBlocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 24, 9),
                endTime: DateTime(2026, 5, 24, 13),
                title: 'Heavy work',
                reason: 'Deadline pressure.',
              ),
            ],
          ),
          capacityMinutes: 120,
          scheduledMinutes: 240,
          createdAt: DateTime(2026, 5, 24, 8),
          updatedAt: DateTime(2026, 5, 24, 8),
          vectorClock: null,
        );
        agentEntities[yesterday.id] = yesterday;

        final cards = await createService().summarizeRecentPatterns(
          agentId: _agentId,
          asOf: DateTime(2026, 5, 25),
        );

        expect(cards, hasLength(3));
        expect(cards.first.id, 'yesterday');
        expect(cards.first.summary, contains('1 planned block'));
        expect(cards.last.kind, 'nudge');
        expect(cards.last.summary, contains('over capacity'));
      },
    );

    test(
      'summarizeRecentPatterns emits a neutral nudge when no plans exist',
      () async {
        final cards = await createService().summarizeRecentPatterns(
          agentId: _agentId,
          asOf: DateTime(2026, 5, 25),
        );

        expect(cards, hasLength(3));
        expect(cards.last.id, 'gentle_nudge');
        expect(cards.last.summary, contains('No recent drafts'));
        expect(cards.last.bullets.single.tone, DayAgentLearningBulletTone.info);
      },
    );

    test('executeTool rejects fractional integer arguments', () async {
      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.summarizeRecentPatterns,
        args: {'lookbackDays': 7.5},
      );

      expect(result.success, isFalse);
      expect(result.output, contains('value must be an integer'));
    });

    test(
      'executeTool accepts integral doubles for integer arguments',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.summarizeRecentPatterns,
            args: {'lookbackDays': 3.0},
          );
        });

        expect(result.success, isTrue);
      },
    );

    test(
      'summarizeRecentPatterns rejects non-positive lookback windows',
      () async {
        await expectLater(
          createService().summarizeRecentPatterns(
            agentId: _agentId,
            asOf: DateTime(2026, 5, 25),
            lookbackDays: 0,
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      },
    );

    test('executeTool surfaces unknown tool names as failures', () async {
      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: 'not_a_tool',
        args: const {},
      );

      expect(result.success, isFalse);
      expect(result.output, contains('unknown tool'));
    });

    test('executeTool logs and reports unexpected errors', () async {
      when(() => agentRepository.getEntity(any())).thenThrow(
        StateError('boom'),
      );
      when(
        () => domainLogger.error(
          any(),
          any(),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: {
          'dayId': _dayId,
          'blocks': [_aiBlock()],
        },
      );

      expect(result.success, isFalse);
      expect(result.output, contains('boom'));
      verify(
        () => domainLogger.error(
          LogDomains.agentWorkflow,
          'day-agent plan tool failed',
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('persistDraftPlan rejects mismatched dayId / planDate', () async {
      await expectLater(
        createService().persistDraftPlan(
          agentId: _agentId,
          dayId: 'dayplan-2026-05-26',
          planDate: DateTime(2026, 5, 25),
          rawBlocks: [_aiBlock()],
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (e) => e.message,
            'message',
            contains('dayId must match planDate'),
          ),
        ),
      );
    });

    test(
      'persistDraftPlan rejects captures owned by a different agent',
      () async {
        agentEntities['capture-other'] = AgentDomainEntity.capture(
          id: 'capture-other',
          agentId: 'other-agent',
          transcript: 'foreign',
          capturedAt: _now,
          createdAt: _now,
          vectorClock: null,
        );
        await expectLater(
          createService().persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: DateTime(2026, 5, 25),
            captureId: 'capture-other',
            rawBlocks: [_aiBlock()],
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      },
    );

    test('persistDraftPlan rejects unknown agents', () async {
      await expectLater(
        createService().persistDraftPlan(
          agentId: 'nope',
          dayId: _dayId,
          planDate: DateTime(2026, 5, 25),
          rawBlocks: [_aiBlock()],
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (e) => e.message,
            'message',
            contains('agent nope not found'),
          ),
        ),
      );
    });

    test(
      'persistDraftPlan sorts equal-start blocks by id and reuses '
      'existing createdAt',
      () async {
        final service = createService();
        final firstPlan = await withClock(Clock.fixed(_now), () {
          return service.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: DateTime(2026, 5, 25),
            rawBlocks: [_aiBlock()],
          );
        });

        final later = _now.add(const Duration(hours: 1));
        final secondPlan = await withClock(Clock.fixed(later), () {
          return service.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: DateTime(2026, 5, 25),
            rawBlocks: [
              _aiBlock(id: 'block-b'),
              _aiBlock(id: 'block-a'),
            ],
          );
        });

        expect(
          secondPlan.data.plannedBlocks.map((b) => b.id),
          ['block-a', 'block-b'],
        );
        expect(secondPlan.createdAt, firstPlan.createdAt);
        expect(secondPlan.updatedAt, later);
      },
    );

    test(
      'executeTool runs decidedTaskIds + integer capacity paths end-to-end',
      () async {
        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.draftDayPlan,
            args: {
              'dayId': _dayId,
              'dayDate': DateTime(2026, 5, 25).toIso8601String(),
              'capacityMinutes': 300,
              'decidedTaskIds': const ['task-1'],
              'blocks': [_aiBlock(taskId: 'task-1')],
            },
          );
        });

        expect(result.success, isTrue);
        expect(upsertedEntities.single, isA<DayPlanEntity>());
      },
    );

    test('executeTool rejects blank decidedTaskIds entries', () async {
      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: {
          'dayId': _dayId,
          'decidedTaskIds': const ['task-1', '   '],
          'blocks': [_aiBlock()],
        },
      );

      expect(result.success, isFalse);
      expect(result.output, contains('non-empty strings'));
    });

    test('executeTool rejects non-list blocks payloads', () async {
      final result = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: const {
          'dayId': _dayId,
          'blocks': 'not-an-array',
        },
      );

      expect(result.success, isFalse);
      expect(result.output, contains('blocks must be an array'));
    });

    test('executeTool rejects blocks missing required fields', () async {
      final missingStart = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: {
          'dayId': _dayId,
          'blocks': [
            {
              'title': 'No start',
              'categoryId': 'work',
              'end': DateTime(2026, 5, 25, 10).toIso8601String(),
              'type': 'ai',
              'reason': 'reason',
            },
          ],
        },
      );
      expect(missingStart.success, isFalse);
      expect(missingStart.output, contains('start must be a valid ISO-8601'));

      final missingTitle = await createService().executeTool(
        agentId: _agentId,
        threadId: _threadId,
        runKey: _runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: {
          'dayId': _dayId,
          'blocks': [
            {
              'categoryId': 'work',
              'start': DateTime(2026, 5, 25, 9).toIso8601String(),
              'end': DateTime(2026, 5, 25, 10).toIso8601String(),
              'type': 'ai',
              'reason': 'reason',
            },
          ],
        },
      );
      expect(missingTitle.success, isFalse);
      expect(missingTitle.output, contains('title must not be empty'));
    });

    test('executeTool returns JSON for summarize_recent_patterns', () async {
      final result = await withClock(Clock.fixed(_now), () {
        return createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.summarizeRecentPatterns,
          args: {
            'asOf': DateTime(2026, 5, 25, 12).toIso8601String(),
            'lookbackDays': 3,
          },
        );
      });

      expect(result.success, isTrue);
      final data = jsonDecode(result.output) as Map<String, dynamic>;
      final cards = data['cards'] as List<dynamic>;
      expect(cards, hasLength(3));
      expect(cards.first, containsPair('id', 'yesterday'));
    });

    group('hydrateDecidedTasks', () {
      test('returns empty list and skips JournalDb when no inputs', () async {
        final result = await createService().hydrateDecidedTasks(
          agentId: _agentId,
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
          when(
            () => journalDb.journalEntityMapForIds(any()),
          ).thenAnswer(
            (_) async => {
              'task-1': task1,
              'task-2': task2,
              'task-3': task3,
            },
          );

          final result = await createService().hydrateDecidedTasks(
            agentId: _agentId,
            allowedCategoryIds: const {'work', 'life'},
            explicitTaskIds: const ['task-1', 'task-3'],
            parsedItems: [
              _parsedItem(matchedTaskId: 'task-3'),
              _parsedItem(id: 'parsed-2', matchedTaskId: 'task-2'),
            ],
          );

          expect(result.map((t) => t.id).toList(), [
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

      test(
        'skips parsed items without matchedTaskId or soft-deleted',
        () async {
          final task1 = _task(id: 'task-1', title: 'Prep demo');
          when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
            (_) async => {'task-1': task1},
          );

          final result = await createService().hydrateDecidedTasks(
            agentId: _agentId,
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

          expect(result.map((t) => t.id).toList(), ['task-1']);
        },
      );

      test('filters out tasks outside the agent allowed categories', () async {
        final task1 = _task(id: 'task-1', title: 'Prep demo');
        final task2 = _task(
          id: 'task-2',
          title: 'Personal errand',
          categoryId: 'blocked',
        );
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {'task-1': task1, 'task-2': task2},
        );

        final result = await createService().hydrateDecidedTasks(
          agentId: _agentId,
          allowedCategoryIds: const {'work', 'life'},
          explicitTaskIds: const ['task-1', 'task-2'],
        );

        expect(result.map((t) => t.id).toList(), ['task-1']);
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

        final result = await createService().hydrateDecidedTasks(
          agentId: _agentId,
          allowedCategoryIds: const {'work', 'life'},
          explicitTaskIds: const ['task-1', 'task-2', 'task-missing'],
        );

        expect(result.map((t) => t.id).toList(), ['task-1']);
      });

      test('allows any category when allowedCategoryIds is empty', () async {
        final task1 = _task(
          id: 'task-1',
          title: 'Anywhere',
          categoryId: 'unscoped',
        );
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {'task-1': task1},
        );

        final result = await createService().hydrateDecidedTasks(
          agentId: _agentId,
          allowedCategoryIds: const <String>{},
          explicitTaskIds: const ['task-1'],
        );

        expect(result.single.id, 'task-1');
        expect(result.single.categoryId, 'unscoped');
      });

      test('trims whitespace from explicit ids before lookup', () async {
        final task1 = _task(id: 'task-1', title: 'Prep demo');
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {'task-1': task1},
        );

        final result = await createService().hydrateDecidedTasks(
          agentId: _agentId,
          allowedCategoryIds: const {'work', 'life'},
          explicitTaskIds: const ['  task-1  ', '', '   '],
        );

        expect(result.map((t) => t.id).toList(), ['task-1']);
        final captured =
            verify(
                  () => journalDb.journalEntityMapForIds(captureAny()),
                ).captured.single
                as List<String>;
        expect(captured, ['task-1']);
      });
    });
  });
}

Task _task({
  required String id,
  required String title,
  String? categoryId = 'work',
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
          status: TaskStatus.open(
            id: 'status-open',
            createdAt: DateTime(2026, 5, 20),
            utcOffset: 120,
          ),
          statusHistory: const [],
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          title: title,
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

Map<String, Object?> _aiBlock({
  String id = 'block-1',
  String categoryId = 'work',
  String? taskId,
  DateTime? start,
  DateTime? end,
  String title = 'Prep demo',
  String type = 'ai',
  String? reason = 'High-energy focus window.',
}) {
  final block = {
    'id': id,
    'title': title,
    'categoryId': categoryId,
    'start': (start ?? DateTime(2026, 5, 25, 9)).toIso8601String(),
    'end': (end ?? DateTime(2026, 5, 25, 10)).toIso8601String(),
    'type': type,
  };
  if (taskId != null) {
    block['taskId'] = taskId;
  }
  if (reason != null) {
    block['reason'] = reason;
  }
  return block;
}
