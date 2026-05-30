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
import 'package:lotti/features/agents/model/change_set.dart';
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
    when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
      (_) async => const <String, JournalEntity>{},
    );
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
              {
                'id': 'block-3',
                'title': 'Dropped errand',
                'categoryId': 'life',
                'start': DateTime(2026, 5, 25, 10, 15).toIso8601String(),
                'end': DateTime(2026, 5, 25, 10, 45).toIso8601String(),
                'type': 'manual',
                'state': 'dropped',
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
        expect(plan.data.plannedBlocks, hasLength(3));
        expect(plan.data.pinnedTasks.single.taskId, 'task-1');
        expect(
          plan.data.plannedBlocks.first.reason,
          'High-energy focus window.',
        );
        expect(plan.data.plannedBlocks[1].type, PlannedBlockType.buffer);
        expect(plan.data.plannedBlocks.last.state, PlannedBlockState.dropped);
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

    test(
      'persistDraftPlan allows task IDs created during the drafting wake',
      () async {
        when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
          (_) async => {'task-2': _task(id: 'task-2', title: 'Buy milk')},
        );

        final plan = await withClock(Clock.fixed(_now), () {
          return createService().persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: DateTime(2026, 5, 25),
            decidedTaskIds: const ['task-1'],
            rawBlocks: [
              {
                ..._aiBlock(taskId: 'task-2'),
                'title': 'Buy milk',
              },
            ],
          );
        });

        expect(plan.data.plannedBlocks.single.taskId, 'task-2');
      },
    );

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
      'persistDraftPlan rejects new drafted blocks that start earlier today',
      () async {
        await expectLater(
          withClock(Clock.fixed(DateTime(2026, 5, 25, 10)), () {
            return createService().persistDraftPlan(
              agentId: _agentId,
              dayId: _dayId,
              planDate: DateTime(2026, 5, 25),
              rawBlocks: [
                _aiBlock(
                  start: DateTime(2026, 5, 25, 9),
                  end: DateTime(2026, 5, 25, 10),
                ),
              ],
            );
          }),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('must not start before current time'),
            ),
          ),
        );
      },
    );

    test(
      'persistDraftPlan allows already-started in-progress history',
      () async {
        final plan = await withClock(
          Clock.fixed(DateTime(2026, 5, 25, 10)),
          () {
            return createService().persistDraftPlan(
              agentId: _agentId,
              dayId: _dayId,
              planDate: DateTime(2026, 5, 25),
              rawBlocks: [
                {
                  ..._aiBlock(
                    start: DateTime(2026, 5, 25, 9),
                    end: DateTime(2026, 5, 25, 11),
                  ),
                  'state': 'inProgress',
                },
              ],
            );
          },
        );

        expect(
          plan.data.plannedBlocks.single.state,
          PlannedBlockState.inProgress,
        );
      },
    );

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
          message: any(named: 'message'),
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
          LogDomain.agentWorkflow,
          any(),
          message: 'day-agent plan tool failed',
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
              _aiBlock(
                id: 'block-b',
                start: DateTime(2026, 5, 25, 11),
                end: DateTime(2026, 5, 25, 12),
              ),
              _aiBlock(
                id: 'block-a',
                start: DateTime(2026, 5, 25, 11),
                end: DateTime(2026, 5, 25, 12),
              ),
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

    group('proposePlanDiff', () {
      DayPlanEntity seedPlan({
        List<PlannedBlock>? blocks,
        DayPlanStatus? status,
      }) {
        final plan =
            AgentDomainEntity.dayPlan(
                  id: 'day_agent_plan:$_dayId',
                  agentId: _agentId,
                  dayId: _dayId,
                  planDate: DateTime(2026, 5, 25),
                  data: DayPlanData(
                    planDate: DateTime(2026, 5, 25),
                    status: status ?? const DayPlanStatus.draft(),
                    plannedBlocks:
                        blocks ??
                        [
                          PlannedBlock(
                            id: 'block-1',
                            categoryId: 'work',
                            startTime: DateTime(2026, 5, 25, 9),
                            endTime: DateTime(2026, 5, 25, 10),
                            title: 'Prep demo',
                            reason: 'Morning focus.',
                          ),
                        ],
                  ),
                  capacityMinutes: 360,
                  scheduledMinutes: 60,
                  createdAt: _now,
                  updatedAt: _now,
                  vectorClock: null,
                )
                as DayPlanEntity;
        agentEntities[plan.id] = plan;
        return plan;
      }

      Map<String, Object?> movedChange({
        String blockId = 'block-1',
        DateTime? fromStart,
        DateTime? fromEnd,
        DateTime? toStart,
        DateTime? toEnd,
        String reason = 'Push to high-energy window.',
      }) {
        return {
          'action': 'moved',
          'blockId': blockId,
          'reason': reason,
          'from': {
            'start': (fromStart ?? DateTime(2026, 5, 25, 9)).toIso8601String(),
            'end': (fromEnd ?? DateTime(2026, 5, 25, 10)).toIso8601String(),
            'title': 'Prep demo',
          },
          'to': {
            'start': (toStart ?? DateTime(2026, 5, 25, 11)).toIso8601String(),
            'end': (toEnd ?? DateTime(2026, 5, 25, 12)).toIso8601String(),
          },
        };
      }

      Map<String, Object?> addedChange({
        DateTime? start,
        DateTime? end,
        String title = 'Walk',
        String categoryId = 'life',
      }) {
        return {
          'action': 'added',
          'reason': 'Recovery between sprints.',
          'to': {
            'start': (start ?? DateTime(2026, 5, 25, 14)).toIso8601String(),
            'end': (end ?? DateTime(2026, 5, 25, 14, 30)).toIso8601String(),
            'title': title,
            'categoryId': categoryId,
            'type': 'manual',
          },
        };
      }

      Map<String, Object?> droppedChange({String blockId = 'block-1'}) {
        return {
          'action': 'dropped',
          'blockId': blockId,
          'reason': 'No longer needed.',
          'from': {
            'start': DateTime(2026, 5, 25, 9).toIso8601String(),
            'end': DateTime(2026, 5, 25, 10).toIso8601String(),
            'title': 'Prep demo',
          },
        };
      }

      test('persists a ChangeSetEntity and returns item summaries', () async {
        seedPlan();

        final changeSet = await withClock(Clock.fixed(_now), () {
          return createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [movedChange(), addedChange()],
            captureId: 'capture-001',
          );
        });

        expect(changeSet.id, startsWith('plan_diff:'));
        expect(changeSet.agentId, _agentId);
        expect(changeSet.taskId, 'day_agent_plan:$_dayId');
        expect(changeSet.threadId, _threadId);
        expect(changeSet.runKey, _runKey);
        expect(changeSet.status, ChangeSetStatus.pending);
        expect(changeSet.items, hasLength(2));
        expect(changeSet.items.first.toolName, 'move_block');
        expect(
          changeSet.items.first.humanSummary,
          contains('Move "Prep demo"'),
        );
        expect(changeSet.items.last.toolName, 'add_block');
        expect(changeSet.items.last.humanSummary, contains('Add "Walk"'));
        expect(changeSet.items.first.args['captureId'], 'capture-001');
        expect(changeSet.items.last.args.containsKey('captureId'), isFalse);
        expect(
          upsertedEntities.whereType<ChangeSetEntity>().single,
          changeSet,
        );
        expect(notifications, containsAll([_agentId, changeSet.id]));
      });

      test('rejects when no plan exists for the day', () async {
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [movedChange()],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('no plan'),
            ),
          ),
        );
      });

      test('persists a ChangeSetEntity against approved plans', () async {
        final statuses = <DayPlanStatus>[
          DayPlanStatus.committed(committedAt: DateTime(2026, 5, 25, 11)),
          DayPlanStatus.agreed(agreedAt: DateTime(2026, 5, 25, 10)),
        ];

        for (final status in statuses) {
          seedPlan(status: status);

          final changeSet = await createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [movedChange()],
          );

          expect(changeSet.status, ChangeSetStatus.pending);
          expect(changeSet.items.single.toolName, 'move_block');
          expect(
            upsertedEntities.whereType<ChangeSetEntity>().last,
            changeSet,
          );
          expect(notifications, containsAll([_agentId, changeSet.id]));
        }
      });

      test('rejects when baselinePlanId is stale', () async {
        final plan = seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [movedChange()],
            baselinePlanId: '${plan.id}-stale',
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('does not match live plan'),
            ),
          ),
        );
      });

      test('rejects when captureId is unknown', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [movedChange()],
            captureId: 'capture-missing',
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      });

      test('rejects an empty changes list', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: const [],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('at least one change'),
            ),
          ),
        );
      });

      test('rejects moved without blockId / unknown blockId', () async {
        seedPlan();
        final service = createService();
        await expectLater(
          service.proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              {
                ...movedChange(),
              }..remove('blockId'),
            ],
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
        await expectLater(
          service.proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [movedChange(blockId: 'block-ghost')],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('unknown blockId'),
            ),
          ),
        );
      });

      test('rejects added missing required to fields', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              {
                'action': 'added',
                'reason': 'No title.',
                'to': {
                  'start': DateTime(2026, 5, 25, 14).toIso8601String(),
                  'end': DateTime(2026, 5, 25, 15).toIso8601String(),
                  'categoryId': 'work',
                },
              },
            ],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('to.title'),
            ),
          ),
        );
      });

      test('rejects timestamps outside the plan day', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              movedChange(
                toStart: DateTime(2026, 5, 26, 9),
                toEnd: DateTime(2026, 5, 26, 10),
              ),
            ],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('inside the plan day'),
            ),
          ),
        );
      });

      test('rejects dropped without from snapshot', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              {
                ...droppedChange(),
              }..remove('from'),
            ],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('dropped change requires `from`'),
            ),
          ),
        );
      });

      test('rejects an unknown action name', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              {
                ...movedChange(),
                'action': 'reshuffled',
              },
            ],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('moved, added, or dropped'),
            ),
          ),
        );
      });

      test('rejects dropped with an unknown blockId', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [droppedChange(blockId: 'ghost-block')],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('dropped change references unknown blockId'),
            ),
          ),
        );
      });

      test('rejects a snapshot whose end is not after its start', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              movedChange(
                toStart: DateTime(2026, 5, 25, 12),
                toEnd: DateTime(2026, 5, 25, 11),
              ),
            ],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('must be after'),
            ),
          ),
        );
      });

      test('rejects a snapshot with an invalid block type', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              {
                ...movedChange(),
                'to': {
                  'start': DateTime(2026, 5, 25, 11).toIso8601String(),
                  'end': DateTime(2026, 5, 25, 12).toIso8601String(),
                  'type': 'lunch',
                },
              },
            ],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('must be ai, cal, buffer, or manual'),
            ),
          ),
        );
      });

      test('rejects a non-object snapshot', () async {
        seedPlan();
        await expectLater(
          createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              {
                ...movedChange(),
                'to': 'not-an-object',
              },
            ],
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('`to` must be an object'),
            ),
          ),
        );
      });

      test('formats a drop summary using the live block fallback', () async {
        seedPlan();
        final changeSet = await withClock(Clock.fixed(_now), () {
          return createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [droppedChange()],
          );
        });
        expect(
          changeSet.items.single.humanSummary,
          startsWith('Drop "Prep demo"'),
        );
      });

      test(
        'encodes from-snapshot categoryId into ChangeItem args when supplied',
        () async {
          seedPlan();
          final changeSet = await createService().proposePlanDiff(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            dayId: _dayId,
            rawChanges: [
              {
                'action': 'dropped',
                'blockId': 'block-1',
                'reason': 'capture category snapshot',
                'from': {
                  'start': DateTime(2026, 5, 25, 9).toIso8601String(),
                  'end': DateTime(2026, 5, 25, 10).toIso8601String(),
                  'title': 'Prep demo',
                  'categoryId': 'work',
                },
              },
            ],
          );
          expect(
            changeSet.items.single.args['fromCategoryId'],
            'work',
          );
        },
      );
    });

    group('acceptPlanDiff / revertPlanDiff', () {
      const planEntityId = 'day_agent_plan:$_dayId';

      DayPlanEntity seedPlan(
        List<PlannedBlock> blocks, {
        DayPlanStatus status = const DayPlanStatus.draft(),
      }) {
        final scheduled = blocks.fold<int>(
          0,
          (sum, b) => sum + b.duration.inMinutes,
        );
        final plan =
            AgentDomainEntity.dayPlan(
                  id: planEntityId,
                  agentId: _agentId,
                  dayId: _dayId,
                  planDate: DateTime(2026, 5, 25),
                  data: DayPlanData(
                    planDate: DateTime(2026, 5, 25),
                    status: status,
                    plannedBlocks: blocks,
                  ),
                  capacityMinutes: 360,
                  scheduledMinutes: scheduled,
                  createdAt: _now,
                  updatedAt: _now,
                  vectorClock: null,
                )
                as DayPlanEntity;
        agentEntities[plan.id] = plan;
        return plan;
      }

      ChangeSetEntity seedChangeSet({
        required List<ChangeItem> items,
      }) {
        final changeSet =
            AgentDomainEntity.changeSet(
                  id: 'plan_diff:test-1',
                  agentId: _agentId,
                  taskId: planEntityId,
                  threadId: _threadId,
                  runKey: _runKey,
                  status: ChangeSetStatus.pending,
                  items: items,
                  createdAt: _now,
                  vectorClock: null,
                )
                as ChangeSetEntity;
        agentEntities[changeSet.id] = changeSet;
        return changeSet;
      }

      ChangeItem moveBlockItem({
        String blockId = 'block-1',
        DateTime? toStart,
        DateTime? toEnd,
        String? title,
      }) {
        return ChangeItem(
          toolName: 'move_block',
          humanSummary: 'Move "Prep demo"',
          args: <String, dynamic>{
            'action': 'moved',
            'reason': 'New time.',
            'blockId': blockId,
            'toStart': (toStart ?? DateTime(2026, 5, 25, 11)).toIso8601String(),
            'toEnd': (toEnd ?? DateTime(2026, 5, 25, 12)).toIso8601String(),
            'title': ?title,
          },
        );
      }

      ChangeItem addBlockItem() {
        return ChangeItem(
          toolName: 'add_block',
          humanSummary: 'Add "Walk"',
          args: <String, dynamic>{
            'action': 'added',
            'reason': 'Recovery break.',
            'toStart': DateTime(2026, 5, 25, 13).toIso8601String(),
            'toEnd': DateTime(2026, 5, 25, 13, 30).toIso8601String(),
            'title': 'Walk',
            'categoryId': 'life',
            'type': 'manual',
          },
        );
      }

      ChangeItem dropBlockItem({String blockId = 'block-1'}) {
        return ChangeItem(
          toolName: 'drop_block',
          humanSummary: 'Drop "Prep demo"',
          args: <String, dynamic>{
            'action': 'dropped',
            'reason': 'Not today.',
            'blockId': blockId,
          },
        );
      }

      test(
        'acceptPlanDiff applies all changes, rebuilds plan, writes decisions',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              taskId: 'task-1',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [moveBlockItem(), addBlockItem()],
          );

          final later = _now.add(const Duration(hours: 2));
          final updated = await withClock(Clock.fixed(later), () {
            return createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            );
          });

          expect(updated.status, ChangeSetStatus.resolved);
          expect(updated.resolvedAt, later);
          expect(
            updated.items.map((i) => i.status),
            everyElement(ChangeItemStatus.confirmed),
          );

          final updatedPlan = upsertedEntities
              .whereType<DayPlanEntity>()
              .single;
          expect(updatedPlan.data.plannedBlocks, hasLength(2));
          expect(
            updatedPlan.data.plannedBlocks.first.startTime,
            DateTime(2026, 5, 25, 11),
          );
          expect(
            updatedPlan.data.plannedBlocks.last.title,
            'Walk',
          );
          expect(updatedPlan.scheduledMinutes, 90);
          expect(updatedPlan.updatedAt, later);

          final decisions = upsertedEntities
              .whereType<ChangeDecisionEntity>()
              .toList();
          expect(decisions, hasLength(2));
          expect(
            decisions.map((d) => d.verdict),
            everyElement(ChangeDecisionVerdict.confirmed),
          );
          expect(
            decisions.map((d) => d.actor),
            everyElement(DecisionActor.user),
          );
          expect(decisions.map((d) => d.itemIndex).toSet(), {0, 1});
          expect(
            notifications,
            containsAll([_agentId, changeSet.id, _dayId, planEntityId]),
          );
        },
      );

      test(
        'acceptPlanDiff amends a committed plan as a tracked change',
        () async {
          seedPlan(
            [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10),
                title: 'Prep demo',
                reason: 'Morning focus.',
                state: PlannedBlockState.committed,
              ),
            ],
            status: DayPlanStatus.committed(
              committedAt: DateTime(2026, 5, 25, 11),
            ),
          );
          final changeSet = seedChangeSet(items: [addBlockItem()]);

          final updated = await withClock(Clock.fixed(_now), () {
            return createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            );
          });

          expect(updated.status, ChangeSetStatus.resolved);
          expect(updated.items.single.status, ChangeItemStatus.confirmed);
          final updatedPlan = upsertedEntities
              .whereType<DayPlanEntity>()
              .single;
          expect(updatedPlan.data.status, isA<DayPlanStatusCommitted>());
          final addedBlock = updatedPlan.data.plannedBlocks.singleWhere(
            (block) => block.title == 'Walk',
          );
          expect(addedBlock.state, PlannedBlockState.committed);
          expect(
            upsertedEntities.whereType<ChangeDecisionEntity>().single.verdict,
            ChangeDecisionVerdict.confirmed,
          );
        },
      );

      test('acceptPlanDiff with itemIndices only resolves selected', () async {
        seedPlan([
          PlannedBlock(
            id: 'block-1',
            categoryId: 'work',
            startTime: DateTime(2026, 5, 25, 9),
            endTime: DateTime(2026, 5, 25, 10),
            title: 'Prep demo',
            reason: 'Morning focus.',
          ),
        ]);
        final changeSet = seedChangeSet(
          items: [moveBlockItem(), addBlockItem()],
        );

        final updated = await withClock(Clock.fixed(_now), () {
          return createService().acceptPlanDiff(
            agentId: _agentId,
            changeSetId: changeSet.id,
            itemIndices: const [1],
          );
        });

        expect(updated.status, ChangeSetStatus.partiallyResolved);
        expect(updated.items[0].status, ChangeItemStatus.pending);
        expect(updated.items[1].status, ChangeItemStatus.confirmed);
        final updatedPlan = upsertedEntities.whereType<DayPlanEntity>().single;
        expect(updatedPlan.data.plannedBlocks, hasLength(2));
        expect(
          updatedPlan.data.plannedBlocks.first.startTime,
          DateTime(2026, 5, 25, 9),
        );
      });

      test('acceptPlanDiff rejects when changeSet is missing', () async {
        await expectLater(
          createService().acceptPlanDiff(
            agentId: _agentId,
            changeSetId: 'plan_diff:ghost',
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('change set'),
            ),
          ),
        );
      });

      test(
        'acceptPlanDiff rolls back when a selected item references a missing block',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              addBlockItem(),
              moveBlockItem(blockId: 'block-ghost'),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(isA<DayAgentCaptureException>()),
          );
          expect(
            upsertedEntities.whereType<DayPlanEntity>(),
            isEmpty,
          );
          expect(
            upsertedEntities.whereType<ChangeSetEntity>(),
            isEmpty,
          );
        },
      );

      test(
        'acceptPlanDiff skips items already resolved on a re-issued accept',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final preResolvedItem = moveBlockItem().copyWith(
            status: ChangeItemStatus.confirmed,
          );
          final changeSet = seedChangeSet(
            items: [preResolvedItem, addBlockItem()],
          );

          final updated = await createService().acceptPlanDiff(
            agentId: _agentId,
            changeSetId: changeSet.id,
          );

          expect(updated.status, ChangeSetStatus.resolved);
          expect(updated.items[0].status, ChangeItemStatus.confirmed);
          expect(updated.items[1].status, ChangeItemStatus.confirmed);
          // Only the still-pending item produced a decision row.
          expect(
            upsertedEntities.whereType<ChangeDecisionEntity>().single.itemIndex,
            1,
          );
        },
      );

      test(
        'revertPlanDiff flips pending items to rejected without mutating the plan',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [moveBlockItem(), addBlockItem()],
          );

          final updated = await createService().revertPlanDiff(
            agentId: _agentId,
            changeSetId: changeSet.id,
          );

          expect(updated.status, ChangeSetStatus.resolved);
          expect(
            updated.items.map((i) => i.status),
            everyElement(ChangeItemStatus.rejected),
          );
          expect(upsertedEntities.whereType<DayPlanEntity>(), isEmpty);
          final decisions = upsertedEntities
              .whereType<ChangeDecisionEntity>()
              .toList();
          expect(decisions, hasLength(2));
          expect(
            decisions.map((d) => d.verdict),
            everyElement(ChangeDecisionVerdict.rejected),
          );
          expect(
            decisions.map((d) => d.actor),
            everyElement(DecisionActor.user),
          );
        },
      );

      test('revertPlanDiff with itemIndices only retracts selected', () async {
        seedPlan([
          PlannedBlock(
            id: 'block-1',
            categoryId: 'work',
            startTime: DateTime(2026, 5, 25, 9),
            endTime: DateTime(2026, 5, 25, 10),
            title: 'Prep demo',
            reason: 'Morning focus.',
          ),
        ]);
        final changeSet = seedChangeSet(
          items: [moveBlockItem(), addBlockItem()],
        );

        final updated = await createService().revertPlanDiff(
          agentId: _agentId,
          changeSetId: changeSet.id,
          itemIndices: const [0],
        );

        expect(updated.status, ChangeSetStatus.partiallyResolved);
        expect(updated.items[0].status, ChangeItemStatus.rejected);
        expect(updated.items[1].status, ChangeItemStatus.pending);
      });

      test('acceptPlanDiff also drops blocks', () async {
        seedPlan([
          PlannedBlock(
            id: 'block-1',
            categoryId: 'work',
            startTime: DateTime(2026, 5, 25, 9),
            endTime: DateTime(2026, 5, 25, 10),
            title: 'Prep demo',
            reason: 'Morning focus.',
          ),
        ]);
        final changeSet = seedChangeSet(items: [dropBlockItem()]);

        await createService().acceptPlanDiff(
          agentId: _agentId,
          changeSetId: changeSet.id,
        );

        final updatedPlan = upsertedEntities.whereType<DayPlanEntity>().single;
        expect(updatedPlan.data.plannedBlocks, isEmpty);
        expect(updatedPlan.scheduledMinutes, 0);
      });

      test(
        'acceptPlanDiff rejects a move that targets a block dropped earlier '
        'in the same batch',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [dropBlockItem(), moveBlockItem()],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('possibly dropped earlier'),
              ),
            ),
          );
          expect(upsertedEntities.whereType<DayPlanEntity>(), isEmpty);
          expect(upsertedEntities.whereType<ChangeSetEntity>(), isEmpty);
        },
      );

      test(
        'acceptPlanDiff rejects add_block items with malformed args',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              const ChangeItem(
                toolName: 'add_block',
                humanSummary: 'Add malformed',
                args: <String, dynamic>{
                  'action': 'added',
                  'reason': 'Bad data.',
                  // categoryId missing entirely
                  'toStart': '2026-05-25T13:00:00.000',
                  'toEnd': '2026-05-25T13:30:00.000',
                },
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('categoryId must be a non-empty string'),
              ),
            ),
          );
          expect(upsertedEntities.whereType<DayPlanEntity>(), isEmpty);
        },
      );

      test(
        'acceptPlanDiff rejects add_block whose categoryId is not allowed',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              ChangeItem(
                toolName: 'add_block',
                humanSummary: 'Add foreign-category block',
                args: <String, dynamic>{
                  'action': 'added',
                  'reason': 'Test.',
                  'categoryId': 'forbidden',
                  'toStart': DateTime(
                    2026,
                    5,
                    25,
                    13,
                  ).toIso8601String(),
                  'toEnd': DateTime(2026, 5, 25, 14).toIso8601String(),
                  'title': 'Test',
                },
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('not allowed for this agent'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects move_block whose effective times invert',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              ChangeItem(
                toolName: 'move_block',
                humanSummary: 'Move "Prep demo"',
                args: <String, dynamic>{
                  'action': 'moved',
                  'reason': 'Bad times.',
                  'blockId': 'block-1',
                  // Only toStart provided; live block's end is 10:00. New
                  // start at 11:00 would put end before start.
                  'toStart': DateTime(2026, 5, 25, 11).toIso8601String(),
                },
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('effective end must be after effective start'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects move_block whose toStart is outside the day',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              ChangeItem(
                toolName: 'move_block',
                humanSummary: 'Move "Prep demo"',
                args: <String, dynamic>{
                  'action': 'moved',
                  'reason': 'Out-of-day.',
                  'blockId': 'block-1',
                  'toStart': DateTime(2026, 5, 26, 9).toIso8601String(),
                  'toEnd': DateTime(2026, 5, 26, 10).toIso8601String(),
                },
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('outside the plan day'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects move_block whose categoryId override is foreign',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              ChangeItem(
                toolName: 'move_block',
                humanSummary: 'Move with foreign category',
                args: <String, dynamic>{
                  'action': 'moved',
                  'reason': 'Cross-device sync attack.',
                  'blockId': 'block-1',
                  'categoryId': 'forbidden',
                  'toStart': DateTime(
                    2026,
                    5,
                    25,
                    11,
                  ).toIso8601String(),
                  'toEnd': DateTime(2026, 5, 25, 12).toIso8601String(),
                },
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('not allowed for this agent'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects unknown tool names on persisted items',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              const ChangeItem(
                toolName: 'mystery_block_op',
                humanSummary: 'Unknown',
                args: <String, dynamic>{'action': 'whatever'},
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('unknown change tool'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects when the plan vanished between propose and '
        'accept',
        () async {
          final changeSet =
              AgentDomainEntity.changeSet(
                    id: 'plan_diff:vanished',
                    agentId: _agentId,
                    taskId: planEntityId,
                    threadId: _threadId,
                    runKey: _runKey,
                    status: ChangeSetStatus.pending,
                    items: [
                      const ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'orphaned',
                        args: <String, dynamic>{
                          'action': 'added',
                          'reason': "doesn't matter",
                          'categoryId': 'work',
                          'title': 'Test',
                          'toStart': '2026-05-25T13:00:00.000',
                          'toEnd': '2026-05-25T14:00:00.000',
                        },
                      ),
                    ],
                    createdAt: _now,
                    vectorClock: null,
                  )
                  as ChangeSetEntity;
          agentEntities[changeSet.id] = changeSet;
          // Note: no plan seeded for the day.

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('no longer exists'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects out-of-range itemIndices',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(items: [moveBlockItem()]);

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
              itemIndices: const [5],
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('out of range'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects move_block with a non-string toStart',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              const ChangeItem(
                toolName: 'move_block',
                humanSummary: 'bad type',
                args: <String, dynamic>{
                  'action': 'moved',
                  'reason': 'r',
                  'blockId': 'block-1',
                  'toStart': 123,
                },
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('toStart must be a string'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects move_block with an unparseable toStart',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              const ChangeItem(
                toolName: 'move_block',
                humanSummary: 'unparseable',
                args: <String, dynamic>{
                  'action': 'moved',
                  'reason': 'r',
                  'blockId': 'block-1',
                  'toStart': 'not-a-date',
                },
              ),
            ],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('toStart is not a valid ISO-8601'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff applies move_block that only changes the end time',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              taskId: 'task-1',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              ChangeItem(
                toolName: 'move_block',
                humanSummary: 'extend',
                args: <String, dynamic>{
                  'action': 'moved',
                  'reason': 'Extend.',
                  'blockId': 'block-1',
                  'toEnd': DateTime(
                    2026,
                    5,
                    25,
                    11,
                  ).toIso8601String(),
                },
              ),
            ],
          );

          await createService().acceptPlanDiff(
            agentId: _agentId,
            changeSetId: changeSet.id,
          );

          final updatedPlan = upsertedEntities
              .whereType<DayPlanEntity>()
              .single;
          expect(
            updatedPlan.data.plannedBlocks.single.endTime,
            DateTime(2026, 5, 25, 11),
          );
        },
      );

      test(
        'acceptPlanDiff rejects move targeting a block not in the plan',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [moveBlockItem(blockId: 'block-ghost')],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('not in plan'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff rejects add_block missing toStart / toEnd / inverted',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);

          Future<void> expectFailure({
            required Map<String, dynamic> args,
            required String messageFragment,
          }) async {
            final changeSet = seedChangeSet(
              items: [
                ChangeItem(
                  toolName: 'add_block',
                  humanSummary: 'malformed',
                  args: args,
                ),
              ],
            );
            await expectLater(
              createService().acceptPlanDiff(
                agentId: _agentId,
                changeSetId: changeSet.id,
              ),
              throwsA(
                isA<DayAgentCaptureException>().having(
                  (e) => e.message,
                  'message',
                  contains(messageFragment),
                ),
              ),
            );
            // Re-seed for the next iteration so each sub-case sees a fresh
            // pending change set.
            upsertedEntities.clear();
          }

          await expectFailure(
            args: const <String, dynamic>{
              'action': 'added',
              'reason': 'r',
              'categoryId': 'life',
              'title': 'A',
              'toEnd': '2026-05-25T14:00:00.000',
            },
            messageFragment: 'toStart is required',
          );
          await expectFailure(
            args: const <String, dynamic>{
              'action': 'added',
              'reason': 'r',
              'categoryId': 'life',
              'title': 'A',
              'toStart': '2026-05-25T14:00:00.000',
            },
            messageFragment: 'toEnd is required',
          );
          await expectFailure(
            args: const <String, dynamic>{
              'action': 'added',
              'reason': 'r',
              'categoryId': 'life',
              'title': 'A',
              'toStart': '2026-05-25T15:00:00.000',
              'toEnd': '2026-05-25T14:00:00.000',
            },
            messageFragment: 'toEnd must be after toStart',
          );
        },
      );

      test(
        'acceptPlanDiff applies move_block clearing taskId and overriding '
        'the per-block reason via blockReason (separate from change reason)',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              taskId: 'task-1',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              const ChangeItem(
                toolName: 'move_block',
                humanSummary: 'clear meta',
                args: <String, dynamic>{
                  'action': 'moved',
                  // change-level rationale; must NOT clobber block.reason
                  'reason': 'No longer tied.',
                  'blockId': 'block-1',
                  'taskId': null,
                  // explicit per-block reason override (separate key)
                  'blockReason': 'Shift to demo prep.',
                  // categoryId not supplied — should retain 'work'
                },
              ),
            ],
          );

          await createService().acceptPlanDiff(
            agentId: _agentId,
            changeSetId: changeSet.id,
          );

          final updated = upsertedEntities
              .whereType<DayPlanEntity>()
              .single
              .data
              .plannedBlocks
              .single;
          expect(updated.taskId, isNull);
          expect(updated.reason, 'Shift to demo prep.');
          // categoryId retained from live block
          expect(updated.categoryId, 'work');
        },
      );

      test(
        'acceptPlanDiff rejects a drop targeting a block already dropped '
        'earlier in the same batch',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [dropBlockItem(), dropBlockItem()],
          );

          await expectLater(
            createService().acceptPlanDiff(
              agentId: _agentId,
              changeSetId: changeSet.id,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('drop_block at index 1'),
              ),
            ),
          );
        },
      );

      test(
        'acceptPlanDiff sorts blocks deterministically when an added block '
        'shares a start time with an existing one',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          // Use a deterministic id prefix; add_block always generates
          // `block_<uuid>`, so the new block sorts AFTER 'block-1' by id
          // when start times tie.
          final changeSet = seedChangeSet(
            items: [
              ChangeItem(
                toolName: 'add_block',
                humanSummary: 'Add overlap',
                args: <String, dynamic>{
                  'action': 'added',
                  'reason': 'Test tiebreaker.',
                  'categoryId': 'work',
                  'title': 'Other',
                  'toStart': DateTime(
                    2026,
                    5,
                    25,
                    9,
                  ).toIso8601String(),
                  'toEnd': DateTime(
                    2026,
                    5,
                    25,
                    9,
                    30,
                  ).toIso8601String(),
                },
              ),
            ],
          );

          await createService().acceptPlanDiff(
            agentId: _agentId,
            changeSetId: changeSet.id,
          );

          final blocks = upsertedEntities
              .whereType<DayPlanEntity>()
              .single
              .data
              .plannedBlocks;
          expect(blocks, hasLength(2));
          expect(blocks.first.startTime, DateTime(2026, 5, 25, 9));
          expect(blocks.last.startTime, DateTime(2026, 5, 25, 9));
          // block-1 sorts first when ids are compared lexicographically
          // against `block_<uuid>`, so the live block stays at index 0.
          expect(blocks.first.id, 'block-1');
        },
      );

      test(
        'revertPlanDiff with mixed pending and resolved items emits a '
        'pendingCount that excludes already-resolved entries',
        () async {
          seedPlan([
            PlannedBlock(
              id: 'block-1',
              categoryId: 'work',
              startTime: DateTime(2026, 5, 25, 9),
              endTime: DateTime(2026, 5, 25, 10),
              title: 'Prep demo',
              reason: 'Morning focus.',
            ),
          ]);
          final changeSet = seedChangeSet(
            items: [
              moveBlockItem().copyWith(status: ChangeItemStatus.deferred),
              addBlockItem(),
            ],
          );

          final updated = await createService().revertPlanDiff(
            agentId: _agentId,
            changeSetId: changeSet.id,
            itemIndices: const [1],
          );

          // The deferred item stays deferred; the add_block flips to rejected.
          expect(updated.items[0].status, ChangeItemStatus.deferred);
          expect(updated.items[1].status, ChangeItemStatus.rejected);
        },
      );
    });

    group('commitDay', () {
      const planEntityId = 'day_agent_plan:$_dayId';

      DayPlanEntity seedPlan({
        DayPlanStatus status = const DayPlanStatus.draft(),
        List<PlannedBlock>? blocks,
      }) {
        final plan =
            AgentDomainEntity.dayPlan(
                  id: planEntityId,
                  agentId: _agentId,
                  dayId: _dayId,
                  planDate: DateTime(2026, 5, 25),
                  data: DayPlanData(
                    planDate: DateTime(2026, 5, 25),
                    status: status,
                    plannedBlocks:
                        blocks ??
                        [
                          PlannedBlock(
                            id: 'block-1',
                            categoryId: 'work',
                            startTime: DateTime(2026, 5, 25, 9),
                            endTime: DateTime(2026, 5, 25, 10),
                            title: 'Prep demo',
                            reason: 'Morning focus.',
                          ),
                          PlannedBlock(
                            id: 'block-2',
                            categoryId: 'life',
                            startTime: DateTime(2026, 5, 25, 12),
                            endTime: DateTime(2026, 5, 25, 13),
                            title: 'Lunch',
                          ),
                        ],
                  ),
                  capacityMinutes: 360,
                  scheduledMinutes: 120,
                  createdAt: _now,
                  updatedAt: _now,
                  vectorClock: null,
                )
                as DayPlanEntity;
        agentEntities[plan.id] = plan;
        return plan;
      }

      test(
        'commitDay flips status + every drafted block, persists, notifies',
        () async {
          seedPlan();

          final later = _now.add(const Duration(hours: 2));
          final committed = await withClock(Clock.fixed(later), () {
            return createService().commitDay(
              agentId: _agentId,
              dayId: _dayId,
            );
          });

          expect(committed.data.status, isA<DayPlanStatusCommitted>());
          expect(
            (committed.data.status as DayPlanStatusCommitted).committedAt,
            later,
          );
          expect(
            committed.data.plannedBlocks.map((b) => b.state),
            everyElement(PlannedBlockState.committed),
          );
          expect(committed.updatedAt, later);
          expect(upsertedEntities.single, committed);
          expect(
            notifications,
            containsAll([_agentId, _dayId, committed.id]),
          );
        },
      );

      test(
        'commitDay leaves non-drafted block states alone',
        () async {
          seedPlan(
            blocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10),
                title: 'In progress',
                reason: 'Morning focus.',
                state: PlannedBlockState.inProgress,
              ),
              PlannedBlock(
                id: 'block-2',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 11),
                endTime: DateTime(2026, 5, 25, 12),
                title: 'Drafted',
                reason: 'Focus.',
              ),
              PlannedBlock(
                id: 'block-3',
                categoryId: 'life',
                startTime: DateTime(2026, 5, 25, 13),
                endTime: DateTime(2026, 5, 25, 14),
                title: 'Completed',
                state: PlannedBlockState.completed,
              ),
              PlannedBlock(
                id: 'block-4',
                categoryId: 'life',
                startTime: DateTime(2026, 5, 25, 15),
                endTime: DateTime(2026, 5, 25, 16),
                title: 'Dropped',
                state: PlannedBlockState.dropped,
              ),
            ],
          );

          final committed = await createService().commitDay(
            agentId: _agentId,
            dayId: _dayId,
          );

          final byId = {
            for (final b in committed.data.plannedBlocks) b.id: b,
          };
          expect(byId['block-1']!.state, PlannedBlockState.inProgress);
          expect(byId['block-2']!.state, PlannedBlockState.committed);
          expect(byId['block-3']!.state, PlannedBlockState.completed);
          expect(byId['block-4']!.state, PlannedBlockState.dropped);
        },
      );

      test(
        'commitDay is idempotent — re-commit returns the live plan without a write',
        () async {
          seedPlan(
            status: DayPlanStatus.committed(
              committedAt: DateTime(2026, 5, 25, 11),
            ),
            blocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10),
                title: 'Prep demo',
                reason: 'Morning focus.',
                state: PlannedBlockState.committed,
              ),
            ],
          );

          final returned = await createService().commitDay(
            agentId: _agentId,
            dayId: _dayId,
          );

          expect(returned.data.status, isA<DayPlanStatusCommitted>());
          expect(upsertedEntities, isEmpty);
          expect(notifications, isEmpty);
        },
      );

      test('commitDay rejects when no plan exists', () async {
        await expectLater(
          createService().commitDay(agentId: _agentId, dayId: _dayId),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('no draft plan'),
            ),
          ),
        );
      });

      test(
        'commitDay rejects plans in legacy non-draft / non-committed states',
        () async {
          seedPlan(
            status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 5, 25)),
          );

          await expectLater(
            createService().commitDay(agentId: _agentId, dayId: _dayId),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('not in draft state'),
              ),
            ),
          );
          expect(upsertedEntities, isEmpty);
        },
      );

      test(
        'commitDay rejects when the plan belongs to a different agent',
        () async {
          final plan =
              AgentDomainEntity.dayPlan(
                    id: planEntityId,
                    agentId: 'other-agent',
                    dayId: _dayId,
                    planDate: DateTime(2026, 5, 25),
                    data: DayPlanData(
                      planDate: DateTime(2026, 5, 25),
                      status: const DayPlanStatus.draft(),
                    ),
                    createdAt: _now,
                    updatedAt: _now,
                    vectorClock: null,
                  )
                  as DayPlanEntity;
          agentEntities[plan.id] = plan;

          await expectLater(
            createService().commitDay(agentId: _agentId, dayId: _dayId),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('no draft plan'),
              ),
            ),
          );
        },
      );

      test('executeTool returns JSON for commit_day', () async {
        seedPlan();
        final later = _now.add(const Duration(hours: 1));
        final result = await withClock(Clock.fixed(later), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.commitDay,
            args: {'dayId': _dayId},
          );
        });

        expect(result.success, isTrue);
        final data = jsonDecode(result.output) as Map<String, dynamic>;
        expect(data['planId'], 'day_agent_plan:$_dayId');
        expect(data['dayId'], _dayId);
        expect(data['status'], 'committed');
        expect(data['blockCount'], 2);
        expect(data['committedAt'], later.toIso8601String());
      });

      test('executeTool surfaces commit failures as tool errors', () async {
        // No plan seeded; commit_day should fail.
        final result = await createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.commitDay,
          args: {'dayId': _dayId},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('no draft plan'));
      });
    });

    group('uncommitDay', () {
      const planEntityId = 'day_agent_plan:$_dayId';

      DayPlanEntity seedPlan({
        DayPlanStatus status = const DayPlanStatus.draft(),
        List<PlannedBlock>? blocks,
      }) {
        final plan =
            AgentDomainEntity.dayPlan(
                  id: planEntityId,
                  agentId: _agentId,
                  dayId: _dayId,
                  planDate: DateTime(2026, 5, 25),
                  data: DayPlanData(
                    planDate: DateTime(2026, 5, 25),
                    status: status,
                    plannedBlocks:
                        blocks ??
                        [
                          PlannedBlock(
                            id: 'block-1',
                            categoryId: 'work',
                            startTime: DateTime(2026, 5, 25, 9),
                            endTime: DateTime(2026, 5, 25, 10),
                            title: 'Prep demo',
                            reason: 'Morning focus.',
                            state: PlannedBlockState.committed,
                          ),
                        ],
                  ),
                  createdAt: _now,
                  updatedAt: _now,
                  vectorClock: null,
                )
                as DayPlanEntity;
        agentEntities[plan.id] = plan;
        return plan;
      }

      test(
        'uncommitDay flips status back to draft and walks committed blocks '
        'back to drafted',
        () async {
          seedPlan(
            status: DayPlanStatus.committed(
              committedAt: DateTime(2026, 5, 25, 11),
            ),
          );

          final later = _now.add(const Duration(hours: 2));
          final plan = await withClock(Clock.fixed(later), () {
            return createService().uncommitDay(
              agentId: _agentId,
              dayId: _dayId,
            );
          });

          expect(plan.data.status, isA<DayPlanStatusDraft>());
          expect(
            plan.data.plannedBlocks.map((b) => b.state),
            everyElement(PlannedBlockState.drafted),
          );
          expect(plan.updatedAt, later);
          expect(upsertedEntities.single, plan);
          expect(notifications, containsAll([_agentId, _dayId, plan.id]));
        },
      );

      test(
        'uncommitDay preserves inProgress / completed / dropped blocks',
        () async {
          seedPlan(
            status: DayPlanStatus.committed(
              committedAt: DateTime(2026, 5, 25, 11),
            ),
            blocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10),
                title: 'Still committed',
                reason: 'r',
                state: PlannedBlockState.committed,
              ),
              PlannedBlock(
                id: 'block-2',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 11),
                endTime: DateTime(2026, 5, 25, 12),
                title: 'In progress',
                state: PlannedBlockState.inProgress,
              ),
              PlannedBlock(
                id: 'block-3',
                categoryId: 'life',
                startTime: DateTime(2026, 5, 25, 13),
                endTime: DateTime(2026, 5, 25, 14),
                title: 'Completed',
                state: PlannedBlockState.completed,
              ),
              PlannedBlock(
                id: 'block-4',
                categoryId: 'life',
                startTime: DateTime(2026, 5, 25, 15),
                endTime: DateTime(2026, 5, 25, 16),
                title: 'Dropped',
                state: PlannedBlockState.dropped,
              ),
            ],
          );

          final plan = await createService().uncommitDay(
            agentId: _agentId,
            dayId: _dayId,
          );

          final byId = {
            for (final b in plan.data.plannedBlocks) b.id: b,
          };
          expect(byId['block-1']!.state, PlannedBlockState.drafted);
          expect(byId['block-2']!.state, PlannedBlockState.inProgress);
          expect(byId['block-3']!.state, PlannedBlockState.completed);
          expect(byId['block-4']!.state, PlannedBlockState.dropped);
        },
      );

      test(
        'uncommitDay is idempotent on draft plans (no write, no notification)',
        () async {
          seedPlan(
            blocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10),
                title: 'Already draft',
                reason: 'r',
              ),
            ],
          );

          final returned = await createService().uncommitDay(
            agentId: _agentId,
            dayId: _dayId,
          );

          expect(returned.data.status, isA<DayPlanStatusDraft>());
          expect(upsertedEntities, isEmpty);
          expect(notifications, isEmpty);
        },
      );

      test('uncommitDay rejects when no plan exists', () async {
        await expectLater(
          createService().uncommitDay(agentId: _agentId, dayId: _dayId),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('no plan'),
            ),
          ),
        );
      });

      test(
        'uncommitDay rejects legacy non-draft / non-committed states',
        () async {
          seedPlan(
            status: DayPlanStatus.agreed(agreedAt: DateTime(2026, 5, 25)),
          );

          await expectLater(
            createService().uncommitDay(agentId: _agentId, dayId: _dayId),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('not in committed state'),
              ),
            ),
          );
          expect(upsertedEntities, isEmpty);
        },
      );

      test('executeTool returns JSON for uncommit_day', () async {
        seedPlan(
          status: DayPlanStatus.committed(
            committedAt: DateTime(2026, 5, 25, 11),
          ),
        );

        final result = await createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.uncommitDay,
          args: {'dayId': _dayId},
        );

        expect(result.success, isTrue);
        final data = jsonDecode(result.output) as Map<String, dynamic>;
        expect(data['planId'], 'day_agent_plan:$_dayId');
        expect(data['status'], 'draft');
        expect(data['blockCount'], 1);
      });
    });

    group('executeTool dispatch for refine', () {
      DayPlanEntity seedPlan() {
        final plan =
            AgentDomainEntity.dayPlan(
                  id: 'day_agent_plan:$_dayId',
                  agentId: _agentId,
                  dayId: _dayId,
                  planDate: DateTime(2026, 5, 25),
                  data: DayPlanData(
                    planDate: DateTime(2026, 5, 25),
                    status: const DayPlanStatus.draft(),
                    plannedBlocks: [
                      PlannedBlock(
                        id: 'block-1',
                        categoryId: 'work',
                        startTime: DateTime(2026, 5, 25, 9),
                        endTime: DateTime(2026, 5, 25, 10),
                        title: 'Prep demo',
                        reason: 'Morning focus.',
                      ),
                    ],
                  ),
                  capacityMinutes: 360,
                  scheduledMinutes: 60,
                  createdAt: _now,
                  updatedAt: _now,
                  vectorClock: null,
                )
                as DayPlanEntity;
        agentEntities[plan.id] = plan;
        return plan;
      }

      test('executeTool returns JSON for propose_plan_diff', () async {
        seedPlan();

        final result = await withClock(Clock.fixed(_now), () {
          return createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.proposePlanDiff,
            args: {
              'dayId': _dayId,
              'changes': [
                {
                  'action': 'added',
                  'reason': 'Slot lunch.',
                  'to': {
                    'start': DateTime(2026, 5, 25, 12).toIso8601String(),
                    'end': DateTime(2026, 5, 25, 13).toIso8601String(),
                    'title': 'Lunch',
                    'categoryId': 'life',
                    'type': 'manual',
                  },
                },
              ],
            },
          );
        });

        expect(result.success, isTrue);
        final data = jsonDecode(result.output) as Map<String, dynamic>;
        expect(data['changeSetId'], isA<String>());
        final items = data['items'] as List<dynamic>;
        expect(items.single, containsPair('toolName', 'add_block'));
      });

      test(
        'executeTool returns JSON for accept_diff and revert_diff',
        () async {
          final plan = seedPlan();
          final changeSet =
              AgentDomainEntity.changeSet(
                    id: 'plan_diff:dispatch-1',
                    agentId: _agentId,
                    taskId: plan.id,
                    threadId: _threadId,
                    runKey: _runKey,
                    status: ChangeSetStatus.pending,
                    items: [
                      ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'Add "Walk"',
                        args: <String, dynamic>{
                          'toStart': DateTime(
                            2026,
                            5,
                            25,
                            14,
                          ).toIso8601String(),
                          'toEnd': DateTime(
                            2026,
                            5,
                            25,
                            14,
                            30,
                          ).toIso8601String(),
                          'title': 'Walk',
                          'categoryId': 'life',
                        },
                      ),
                    ],
                    createdAt: _now,
                    vectorClock: null,
                  )
                  as ChangeSetEntity;
          agentEntities[changeSet.id] = changeSet;

          final acceptResult = await createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.acceptDiff,
            args: {'changeSetId': changeSet.id},
          );
          expect(acceptResult.success, isTrue);
          final acceptData =
              jsonDecode(acceptResult.output) as Map<String, dynamic>;
          expect(acceptData['status'], 'resolved');
          expect(acceptData['confirmedCount'], 1);

          // Seed a fresh pending change set to exercise revert.
          final revertSet =
              AgentDomainEntity.changeSet(
                    id: 'plan_diff:dispatch-2',
                    agentId: _agentId,
                    taskId: plan.id,
                    threadId: _threadId,
                    runKey: _runKey,
                    status: ChangeSetStatus.pending,
                    items: [
                      ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'Add "Stretch"',
                        args: <String, dynamic>{
                          'toStart': DateTime(
                            2026,
                            5,
                            25,
                            15,
                          ).toIso8601String(),
                          'toEnd': DateTime(
                            2026,
                            5,
                            25,
                            15,
                            15,
                          ).toIso8601String(),
                          'title': 'Stretch',
                          'categoryId': 'life',
                        },
                      ),
                    ],
                    createdAt: _now,
                    vectorClock: null,
                  )
                  as ChangeSetEntity;
          agentEntities[revertSet.id] = revertSet;
          final revertResult = await createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.revertDiff,
            args: {'changeSetId': revertSet.id},
          );
          expect(revertResult.success, isTrue);
          final revertData =
              jsonDecode(revertResult.output) as Map<String, dynamic>;
          expect(revertData['status'], 'resolved');
          expect(revertData['rejectedCount'], 1);
        },
      );

      test(
        'executeTool parses itemIndices including integral doubles',
        () async {
          final plan = seedPlan();
          final changeSet =
              AgentDomainEntity.changeSet(
                    id: 'plan_diff:indices-1',
                    agentId: _agentId,
                    taskId: plan.id,
                    threadId: _threadId,
                    runKey: _runKey,
                    status: ChangeSetStatus.pending,
                    items: [
                      const ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'a',
                        args: <String, dynamic>{
                          'action': 'added',
                          'reason': 'r',
                          'categoryId': 'life',
                          'title': 'A',
                          'toStart': '2026-05-25T14:00:00.000',
                          'toEnd': '2026-05-25T14:30:00.000',
                        },
                      ),
                      const ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'b',
                        args: <String, dynamic>{
                          'action': 'added',
                          'reason': 'r',
                          'categoryId': 'life',
                          'title': 'B',
                          'toStart': '2026-05-25T15:00:00.000',
                          'toEnd': '2026-05-25T15:30:00.000',
                        },
                      ),
                    ],
                    createdAt: _now,
                    vectorClock: null,
                  )
                  as ChangeSetEntity;
          agentEntities[changeSet.id] = changeSet;

          final result = await createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.acceptDiff,
            args: {
              'changeSetId': changeSet.id,
              // Integral double mixed with int — both should parse as ints.
              'itemIndices': const [0, 1.0],
            },
          );
          expect(result.success, isTrue);
          final data = jsonDecode(result.output) as Map<String, dynamic>;
          expect(data['confirmedCount'], 2);
        },
      );

      test('executeTool rejects non-list itemIndices', () async {
        final plan = seedPlan();
        final changeSet =
            AgentDomainEntity.changeSet(
                  id: 'plan_diff:indices-2',
                  agentId: _agentId,
                  taskId: plan.id,
                  threadId: _threadId,
                  runKey: _runKey,
                  status: ChangeSetStatus.pending,
                  items: const [
                    ChangeItem(
                      toolName: 'add_block',
                      humanSummary: 'a',
                      args: <String, dynamic>{
                        'action': 'added',
                        'reason': 'r',
                        'categoryId': 'life',
                        'title': 'A',
                        'toStart': '2026-05-25T14:00:00.000',
                        'toEnd': '2026-05-25T14:30:00.000',
                      },
                    ),
                  ],
                  createdAt: _now,
                  vectorClock: null,
                )
                as ChangeSetEntity;
        agentEntities[changeSet.id] = changeSet;

        final result = await createService().executeTool(
          agentId: _agentId,
          threadId: _threadId,
          runKey: _runKey,
          toolName: DayAgentToolNames.acceptDiff,
          args: {
            'changeSetId': changeSet.id,
            'itemIndices': 'not-a-list',
          },
        );
        expect(result.success, isFalse);
        expect(result.output, contains('itemIndices must be an array'));
      });

      test(
        'executeTool resolution summary counts deferred + retained pending',
        () async {
          final plan = seedPlan();
          // Seed a change set that includes a pending item, a deferred
          // item, and a retracted item. Accepting only index 0 leaves
          // the rest in their original (non-pending) states; the
          // _resolutionSummary walks all statuses.
          final changeSet =
              AgentDomainEntity.changeSet(
                    id: 'plan_diff:summary-1',
                    agentId: _agentId,
                    taskId: plan.id,
                    threadId: _threadId,
                    runKey: _runKey,
                    status: ChangeSetStatus.partiallyResolved,
                    items: const [
                      ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'pending one',
                        args: <String, dynamic>{
                          'action': 'added',
                          'reason': 'r',
                          'categoryId': 'work',
                          'title': 'P',
                          'toStart': '2026-05-25T14:00:00.000',
                          'toEnd': '2026-05-25T14:30:00.000',
                        },
                      ),
                      ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'deferred',
                        args: <String, dynamic>{'reason': 'r'},
                        status: ChangeItemStatus.deferred,
                      ),
                      ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'retracted',
                        args: <String, dynamic>{'reason': 'r'},
                        status: ChangeItemStatus.retracted,
                      ),
                    ],
                    createdAt: _now,
                    vectorClock: null,
                  )
                  as ChangeSetEntity;
          agentEntities[changeSet.id] = changeSet;

          // Accept nothing (itemIndices: []) so the pending one stays
          // pending; deferred/retracted are untouched by design.
          final result = await createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.acceptDiff,
            args: {
              'changeSetId': changeSet.id,
              'itemIndices': const <int>[],
            },
          );
          expect(result.success, isTrue);
          final data = jsonDecode(result.output) as Map<String, dynamic>;
          expect(data['pendingCount'], 1);
          expect(data['confirmedCount'], 0);
          expect(data['rejectedCount'], 0);
          expect(data['status'], 'partiallyResolved');
        },
      );

      test(
        'executeTool rejects fractional itemIndices entries',
        () async {
          final plan = seedPlan();
          final changeSet =
              AgentDomainEntity.changeSet(
                    id: 'plan_diff:indices-3',
                    agentId: _agentId,
                    taskId: plan.id,
                    threadId: _threadId,
                    runKey: _runKey,
                    status: ChangeSetStatus.pending,
                    items: const [
                      ChangeItem(
                        toolName: 'add_block',
                        humanSummary: 'a',
                        args: <String, dynamic>{
                          'action': 'added',
                          'reason': 'r',
                          'categoryId': 'life',
                          'title': 'A',
                          'toStart': '2026-05-25T14:00:00.000',
                          'toEnd': '2026-05-25T14:30:00.000',
                        },
                      ),
                    ],
                    createdAt: _now,
                    vectorClock: null,
                  )
                  as ChangeSetEntity;
          agentEntities[changeSet.id] = changeSet;

          final result = await createService().executeTool(
            agentId: _agentId,
            threadId: _threadId,
            runKey: _runKey,
            toolName: DayAgentToolNames.acceptDiff,
            args: {
              'changeSetId': changeSet.id,
              'itemIndices': const [0.5],
            },
          );
          expect(result.success, isFalse);
          expect(
            result.output,
            contains('itemIndices entries must be integers'),
          );
        },
      );
    });

    group('deletePlanForDay', () {
      const planEntityId = 'day_agent_plan:$_dayId';

      DayPlanEntity seedPlan({DateTime? deletedAt}) {
        final plan =
            AgentDomainEntity.dayPlan(
                  id: planEntityId,
                  agentId: _agentId,
                  dayId: _dayId,
                  planDate: DateTime(2026, 5, 25),
                  data: DayPlanData(
                    planDate: DateTime(2026, 5, 25),
                    status: const DayPlanStatus.draft(),
                  ),
                  createdAt: _now,
                  updatedAt: _now,
                  vectorClock: null,
                  deletedAt: deletedAt,
                )
                as DayPlanEntity;
        agentEntities[plan.id] = plan;
        return plan;
      }

      AgentLink captureLink({String captureId = 'capture-001'}) {
        return AgentLink.captureToPlan(
          id: 'capture_to_plan:$captureId:$planEntityId',
          fromId: captureId,
          toId: planEntityId,
          createdAt: _now,
          updatedAt: _now,
          vectorClock: null,
        );
      }

      test('returns false when no plan exists for this day', () async {
        when(
          () => agentRepository.getLinksTo(
            any(),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => const <AgentLink>[]);

        final removed = await createService().deletePlanForDay(
          agentId: _agentId,
          dayId: _dayId,
        );

        expect(removed, isFalse);
        expect(upsertedEntities, isEmpty);
        expect(notifications, isEmpty);
      });

      test(
        'returns false when the plan belongs to a different agent',
        () async {
          seedPlan();
          agentEntities[planEntityId] =
              (agentEntities[planEntityId]! as DayPlanEntity).copyWith(
                agentId: 'other-agent',
              );
          when(
            () => agentRepository.getLinksTo(
              any(),
              type: any(named: 'type'),
            ),
          ).thenAnswer((_) async => const <AgentLink>[]);

          final removed = await createService().deletePlanForDay(
            agentId: _agentId,
            dayId: _dayId,
          );

          expect(removed, isFalse);
          expect(upsertedEntities, isEmpty);
        },
      );

      test(
        'soft-deletes the plan + inbound capture links and fires notifications',
        () async {
          final plan = seedPlan();
          final link = captureLink(captureId: 'capture-live-001');
          when(
            () => agentRepository.getLinksTo(
              any(),
              type: any(named: 'type'),
            ),
          ).thenAnswer((_) async => [link]);

          final removed = await withClock(Clock.fixed(_now), () {
            return createService().deletePlanForDay(
              agentId: _agentId,
              dayId: _dayId,
            );
          });

          expect(removed, isTrue);
          expect(upsertedEntities, hasLength(1));
          final upserted = upsertedEntities.single as DayPlanEntity;
          expect(upserted.id, plan.id);
          expect(upserted.deletedAt, _now);
          expect(upsertedLinks, hasLength(1));
          expect(upsertedLinks.single.deletedAt, _now);
          expect(notifications, containsAll([_agentId, _dayId, plan.id]));
        },
      );

      test('is idempotent when called on an already-deleted plan', () async {
        seedPlan(deletedAt: _now);
        when(
          () => agentRepository.getLinksTo(
            any(),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => const <AgentLink>[]);

        final removed = await createService().deletePlanForDay(
          agentId: _agentId,
          dayId: _dayId,
        );

        expect(removed, isFalse);
        expect(upsertedEntities, isEmpty);
      });

      test('skips inbound links that are already soft-deleted', () async {
        seedPlan();
        final liveLink = captureLink(captureId: 'capture-live');
        final deletedLink = captureLink(
          captureId: 'capture-dead',
        ).copyWith(deletedAt: _now);
        when(
          () => agentRepository.getLinksTo(
            any(),
            type: any(named: 'type'),
          ),
        ).thenAnswer((_) async => [liveLink, deletedLink]);

        final removed = await withClock(Clock.fixed(_now), () {
          return createService().deletePlanForDay(
            agentId: _agentId,
            dayId: _dayId,
          );
        });

        expect(removed, isTrue);
        expect(upsertedLinks, hasLength(1));
        expect(upsertedLinks.single.fromId, 'capture-live');
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
