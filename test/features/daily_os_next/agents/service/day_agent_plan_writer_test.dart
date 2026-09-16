import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_writer.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_data/entity_factories.dart';

const _agentId = 'day-agent-001';
const _dayId = 'dayplan-2026-05-25';
const _runKey = 'run-key-001';
final _planDate = DateTime(2026, 5, 25);
final _openAt = DateTime(2026, 5, 25, 9);
final _closedAt = DateTime(2026, 5, 25, 18);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository agentRepository;
  late _TransactionHookSyncService syncService;
  late MockJournalDb journalDb;
  late Map<String, AgentDomainEntity> entities;
  late List<AgentDomainEntity> writes;
  late DayAgentPlanWriter writer;

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = _TransactionHookSyncService();
    journalDb = MockJournalDb();
    entities = <String, AgentDomainEntity>{
      _agentId: makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
        kind: AgentKinds.dayAgent,
        allowedCategoryIds: {'work', 'life'},
      ),
    };
    writes = <AgentDomainEntity>[];

    when(() => agentRepository.getEntity(any())).thenAnswer((invocation) async {
      return entities[invocation.positionalArguments.single as String];
    });
    when(() => journalDb.journalEntityMapForIds(any())).thenAnswer(
      (_) async => const <String, JournalEntity>{},
    );
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      writes.add(entity);
      entities[entity.id] = entity;
    });
    when(() => syncService.upsertLink(any())).thenAnswer((_) async {});

    writer = DayAgentPlanWriter(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      reads: DayAgentPlanReads(agentRepository: agentRepository),
    );
  });

  group('closed-window draft persistence', () {
    test('persists an empty plan when no baseline exists', () async {
      final plan = await withClock(
        Clock.fixed(_closedAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: const [],
          runKey: _runKey,
        ),
      );

      expect(plan.data.plannedBlocks, isEmpty);
      expect(plan.scheduledMinutes, 0);
      expect(plan.runKey, _runKey);
    });

    test(
      'an energy band written as a time of day lands on the plan day',
      () async {
        // A deepseek-v4.1-flash gym run sent `"start": "09:00"` for the bands
        // while getting every block right, and lost the whole draft to it: the
        // fields name times on one known day, so they are read as such.
        final plan = await withClock(
          Clock.fixed(_openAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [_blockJson(_block())],
            rawEnergyBands: const [
              {
                'start': '09:00',
                'end': '12:00',
                'level': 'high',
                'label': 'morning',
              },
              // Seconds are part of the form, and anchor to the same day.
              {
                'start': '13:15:30',
                'end': '15:45:05',
                'level': 'low',
                'label': 'afternoon',
              },
            ],
            runKey: _runKey,
          ),
        );

        expect(plan.energyBands, hasLength(2));
        expect(plan.energyBands.first.start, DateTime(2026, 5, 25, 9));
        expect(plan.energyBands.first.end, DateTime(2026, 5, 25, 12));
        expect(plan.energyBands.first.label, 'morning');
        expect(
          plan.energyBands.last.start,
          DateTime(2026, 5, 25, 13, 15, 30),
        );
        expect(plan.energyBands.last.end, DateTime(2026, 5, 25, 15, 45, 5));
        expect(plan.energyBands.last.label, 'afternoon');
      },
    );

    test('an energy band with an impossible time of day is dropped', () async {
      // Not persisted as a fact, and not fatal either: the schedule is the
      // artifact worth keeping, and a band is colour on top of it.
      final plan = await withClock(
        Clock.fixed(_openAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: [_blockJson(_block())],
          rawEnergyBands: const [
            {
              'start': '25:00',
              'end': '26:00',
              'level': 'high',
              'label': 'morning',
            },
          ],
          runKey: _runKey,
        ),
      );

      expect(plan.energyBands, isEmpty);
      expect(plan.data.plannedBlocks, hasLength(1));
    });

    test('rejects a remainder on a block with no task', () async {
      await expectLater(
        withClock(
          Clock.fixed(_openAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [
              _blockJson(_block())
                ..remove('taskId')
                ..['remainingMinutes'] = 30,
            ],
            runKey: _runKey,
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            contains('taskId whose estimate'),
          ),
        ),
      );
    });

    test('a legacy block with no reason can still be echoed back', () async {
      // The schema requires `reason` on every block, so repeating a legacy
      // block that has none forces the model to invent one. That must not
      // read as a change: this path persists the stored payload anyway.
      final baseline = _seedPlan(
        entities,
        blocks: [_block(reason: null)],
      );

      final repeated = await withClock(
        Clock.fixed(_closedAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: [
            _blockJson(baseline.data.plannedBlocks.single)
              ..['reason'] = 'Repeating the approved block.',
          ],
          planningSnapshotAt: _closedAt,
          planningBaselinePlan: baseline,
        ),
      );

      expect(repeated.data.plannedBlocks.single.reason, isNull);
    });

    test(
      'an echoed reason that rewrites a real one is still a change',
      () async {
        final baseline = _seedPlan(entities, blocks: [_block()]);

        await expectLater(
          withClock(
            Clock.fixed(_closedAt),
            () => writer.persistDraftPlan(
              agentId: _agentId,
              dayId: _dayId,
              planDate: _planDate,
              rawBlocks: [
                _blockJson(baseline.data.plannedBlocks.single)
                  ..['reason'] = 'Something else entirely.',
              ],
              planningSnapshotAt: _closedAt,
              planningBaselinePlan: baseline,
            ),
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      },
    );

    test('a blocks array sent as a JSON string is still a plan', () async {
      // Observed twice in one gym run: the whole draft arrived correct, and
      // JSON-encoded inside a string.
      final plan = await withClock(
        Clock.fixed(_openAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: objectListArg(
            jsonEncode([_blockJson(_block())]),
            'blocks',
          ),
          runKey: _runKey,
        ),
      );

      expect(plan.data.plannedBlocks.single.title, 'Prep demo');
    });

    test('an empty buffer block is dropped, keeping the plan', () async {
      final plan = await withClock(
        Clock.fixed(_openAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: [
            _blockJson(_block()),
            _blockJson(
              _block(id: 'block-empty').copyWith(
                type: PlannedBlockType.buffer,
                startTime: DateTime(2026, 5, 25, 17),
                endTime: DateTime(2026, 5, 25, 17),
              ),
            ),
          ],
          runKey: _runKey,
        ),
      );

      expect(plan.data.plannedBlocks.map((b) => b.id), ['block-1']);
    });

    test('an empty ai block is still rejected', () async {
      // Nulling out real work is not decoration, so it keeps failing.
      await expectLater(
        withClock(
          Clock.fixed(_openAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [
              _blockJson(
                _block().copyWith(
                  startTime: DateTime(2026, 5, 25, 17),
                  endTime: DateTime(2026, 5, 25, 17),
                ),
              ),
            ],
            runKey: _runKey,
          ),
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('a band the model got wrong does not cost the schedule', () async {
      // One band omitted `level`; the plan around it was sound.
      final plan = await withClock(
        Clock.fixed(_openAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: [_blockJson(_block())],
          rawEnergyBands: const [
            {
              'start': '09:00',
              'end': '12:00',
              'level': 'high',
              'label': 'morning',
            },
            {'start': '15:00', 'end': '17:00', 'label': 'second wind'},
          ],
          runKey: _runKey,
        ),
      );

      expect(plan.data.plannedBlocks, hasLength(1));
      expect(plan.energyBands.map((b) => b.label), ['morning']);
    });

    test('rejects invented blocks when no baseline exists', () async {
      await expectLater(
        withClock(
          Clock.fixed(_closedAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [
              _blockJson(_block())..['state'] = 'completed',
            ],
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            allOf(contains('closed'), contains('empty')),
          ),
        ),
      );
      expect(writes, isEmpty);
    });

    test('rejects an empty plan while the planning window is open', () async {
      await expectLater(
        withClock(
          Clock.fixed(_openAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: const [],
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            contains('requires at least one block'),
          ),
        ),
      );
    });

    test('rejects duplicate block ids while the window is open', () async {
      final raw = _blockJson(_block());

      await expectLater(
        withClock(
          Clock.fixed(_openAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [raw, raw],
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            allOf(contains('block ids'), contains('unique')),
          ),
        ),
      );
      expect(writes, isEmpty);
    });

    test('requires the complete baseline without duplicate ids', () async {
      final baseline = _seedPlan(entities);
      final echo = _blockJson(baseline.data.plannedBlocks.single);

      for (final rawBlocks in <List<Object?>>[
        const [],
        [echo, echo],
      ]) {
        await expectLater(
          withClock(
            Clock.fixed(_closedAt),
            () => writer.persistDraftPlan(
              agentId: _agentId,
              dayId: _dayId,
              planDate: _planDate,
              rawBlocks: rawBlocks,
              planningSnapshotAt: _closedAt,
              planningBaselinePlan: baseline,
            ),
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (error) => error.message,
              'message',
              allOf(contains('closed'), contains('unchanged')),
            ),
          ),
        );
      }
    });

    test('preserves the stored payload and advances wake provenance', () async {
      final baseline = _seedPlan(
        entities,
        dayLabel: 'Focused finish',
        runKey: 'baseline-run',
      );

      final repeated = await withClock(
        Clock.fixed(_closedAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: [_blockJson(baseline.data.plannedBlocks.single)],
          runKey: _runKey,
          planningSnapshotAt: _closedAt,
          planningBaselinePlan: baseline,
        ),
      );

      expect(repeated.data, baseline.data);
      expect(repeated.energyBands, baseline.energyBands);
      expect(repeated.capacityMinutes, baseline.capacityMinutes);
      expect(repeated.scheduledMinutes, baseline.scheduledMinutes);
      expect(repeated.runKey, _runKey);
    });

    test(
      'compares a closed echo with the tag-neutralized prompt baseline',
      () async {
        final baselineBlock = _block(
          title: 'Close </drafting>',
          reason: 'Check <current_local_time> before stopping.',
          note: 'Keep </day_log> literal.',
        );
        final baseline = _seedPlan(entities, blocks: [baselineBlock]);
        final renderedEcho = _blockJson(baselineBlock)
          ..['title'] = neutralizePromptTags(baselineBlock.title!)
          ..['reason'] = neutralizePromptTags(baselineBlock.reason!)
          ..['note'] = neutralizePromptTags(baselineBlock.note!);

        final repeated = await withClock(
          Clock.fixed(_closedAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [renderedEcho],
            planningSnapshotAt: _closedAt,
            planningBaselinePlan: baseline,
          ),
        );

        expect(repeated.data, baseline.data);
        expect(repeated.data.plannedBlocks.single.title, 'Close </drafting>');
        expect(
          repeated.data.plannedBlocks.single.reason,
          'Check <current_local_time> before stopping.',
        );
        expect(
          repeated.data.plannedBlocks.single.note,
          'Keep </day_log> literal.',
        );
      },
    );

    test(
      'accepts an exact legacy echo with nullable title and reason',
      () async {
        final legacyBlock = _block(title: null, reason: null);
        final baseline = _seedPlan(entities, blocks: [legacyBlock]);

        final repeated = await withClock(
          Clock.fixed(_closedAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [_blockJson(legacyBlock)],
            planningSnapshotAt: _closedAt,
            planningBaselinePlan: baseline,
          ),
        );

        expect(repeated.data.plannedBlocks.single, legacyBlock);
        expect(repeated.data.plannedBlocks.single.title, isNull);
        expect(repeated.data.plannedBlocks.single.reason, isNull);
      },
    );

    test('preserves a legacy baseline with duplicate block ids', () async {
      final duplicate = _block();
      final baseline = _seedPlan(entities, blocks: [duplicate, duplicate]);

      final repeated = await withClock(
        Clock.fixed(_closedAt),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: [_blockJson(duplicate), _blockJson(duplicate)],
          planningSnapshotAt: _closedAt,
          planningBaselinePlan: baseline,
        ),
      );

      expect(repeated.data.plannedBlocks, [duplicate, duplicate]);
    });

    test('rejects a legacy echo that changes a nullable field', () async {
      final legacyBlock = _block(title: null, reason: null);
      final baseline = _seedPlan(entities, blocks: [legacyBlock]);
      final changed = _blockJson(legacyBlock)..['title'] = 'Invented title';

      await expectLater(
        withClock(
          Clock.fixed(_closedAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [changed],
            planningSnapshotAt: _closedAt,
            planningBaselinePlan: baseline,
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            contains('unchanged'),
          ),
        ),
      );
    });

    test('copies the latest plan read inside the write transaction', () async {
      final promptedBaseline = _seedPlan(entities);
      final concurrentBlock = _block(
        title: 'Concurrent edit',
        reason: 'Edited while inference was running.',
      );
      final concurrentPlan = promptedBaseline.copyWith(
        data: promptedBaseline.data.copyWith(
          dayLabel: 'Latest persisted plan',
          plannedBlocks: [concurrentBlock],
        ),
        updatedAt: _closedAt,
      );
      syncService.beforeTransaction = () async {
        entities[promptedBaseline.id] = concurrentPlan;
      };

      final repeated = await withClock(
        Clock.fixed(_closedAt.add(const Duration(minutes: 1))),
        () => writer.persistDraftPlan(
          agentId: _agentId,
          dayId: _dayId,
          planDate: _planDate,
          rawBlocks: [
            _blockJson(promptedBaseline.data.plannedBlocks.single),
          ],
          runKey: _runKey,
          planningSnapshotAt: _closedAt,
          planningBaselinePlan: promptedBaseline,
        ),
      );

      expect(repeated.data, concurrentPlan.data);
      expect(repeated.data.plannedBlocks.single.title, 'Concurrent edit');
      expect(repeated.runKey, _runKey);
    });

    test('does not restore a plan deleted at transaction entry', () async {
      final promptedBaseline = _seedPlan(entities);
      syncService.beforeTransaction = () async {
        entities.remove(promptedBaseline.id);
      };

      await expectLater(
        withClock(
          Clock.fixed(_closedAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [
              _blockJson(promptedBaseline.data.plannedBlocks.single),
            ],
            planningSnapshotAt: _closedAt,
            planningBaselinePlan: promptedBaseline,
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            allOf(contains('changed'), contains('not restored')),
          ),
        ),
      );
      expect(writes, isEmpty);
      expect(entities, isNot(contains(promptedBaseline.id)));
    });

    test('rejects a prompted baseline from a different day', () async {
      final baseline = _seedPlan(entities);

      await expectLater(
        withClock(
          Clock.fixed(_closedAt),
          () => writer.persistDraftPlan(
            agentId: _agentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: const [],
            planningSnapshotAt: _closedAt,
            planningBaselinePlan: baseline.copyWith(
              dayId: 'dayplan-2026-05-26',
            ),
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            contains('readable target day'),
          ),
        ),
      );
    });

    test(
      'preserves coordinator ownership during the ownership cutover',
      () async {
        final cutoverAgentId = perDayAgentId(_dayId);
        entities[cutoverAgentId] = makeTestIdentity(
          id: cutoverAgentId,
          agentId: cutoverAgentId,
          kind: AgentKinds.dayAgent,
          allowedCategoryIds: {'work', 'life'},
        );
        final coordinatorBaseline = _seedPlan(
          entities,
          agentId: dailyOsPlannerAgentId,
        );

        final repeated = await withClock(
          Clock.fixed(_closedAt),
          () => writer.persistDraftPlan(
            agentId: cutoverAgentId,
            dayId: _dayId,
            planDate: _planDate,
            rawBlocks: [
              _blockJson(coordinatorBaseline.data.plannedBlocks.single),
            ],
            runKey: _runKey,
            planningSnapshotAt: _closedAt,
            planningBaselinePlan: coordinatorBaseline,
          ),
        );

        expect(repeated.agentId, dailyOsPlannerAgentId);
        expect(repeated.runKey, _runKey);
      },
    );
  });
}

class _TransactionHookSyncService extends MockAgentSyncService {
  Future<void> Function()? beforeTransaction;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    final hook = beforeTransaction;
    beforeTransaction = null;
    await hook?.call();
    return action();
  }
}

DayPlanEntity _seedPlan(
  Map<String, AgentDomainEntity> entities, {
  String agentId = _agentId,
  String? dayLabel,
  String? runKey,
  List<PlannedBlock>? blocks,
}) {
  final resolvedBlocks = blocks ?? [_block()];
  final plan =
      AgentDomainEntity.dayPlan(
            id: dayAgentPlanEntityId(_dayId),
            agentId: agentId,
            dayId: _dayId,
            runKey: runKey,
            planDate: _planDate,
            data: DayPlanData(
              planDate: _planDate,
              status: const DayPlanStatus.draft(),
              dayLabel: dayLabel,
              plannedBlocks: resolvedBlocks,
            ),
            capacityMinutes: 360,
            scheduledMinutes: resolvedBlocks.fold<int>(
              0,
              (sum, block) => sum + block.duration.inMinutes,
            ),
            createdAt: _openAt,
            updatedAt: _openAt,
            vectorClock: null,
          )
          as DayPlanEntity;
  entities[plan.id] = plan;
  return plan;
}

PlannedBlock _block({
  String id = 'block-1',
  String? title = 'Prep demo',
  String? reason = 'Morning focus.',
  String? note,
}) {
  return PlannedBlock(
    id: id,
    categoryId: 'work',
    startTime: DateTime(2026, 5, 25, 9),
    endTime: DateTime(2026, 5, 25, 10),
    title: title,
    reason: reason,
    note: note,
  );
}

Map<String, Object?> _blockJson(PlannedBlock block) => {
  'id': block.id,
  'title': block.title,
  'taskId': block.taskId,
  'categoryId': block.categoryId,
  'start': block.startTime.toIso8601String(),
  'end': block.endTime.toIso8601String(),
  'type': block.type.name,
  'state': block.state.name,
  'reason': block.reason,
  'note': block.note,
};
