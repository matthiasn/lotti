import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
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
  });
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
