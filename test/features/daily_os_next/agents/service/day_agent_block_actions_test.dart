import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_block_actions.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_reads.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../agents/test_data/entity_factories.dart';
import '../../../categories/test_utils.dart';

const _agentId = 'day-agent-001';
const _dayId = 'dayplan-2026-05-25';
final _now = DateTime(2026, 5, 25, 9);

PlannedBlock _standalone() => PlannedBlock(
  id: 'block-plain',
  categoryId: 'work',
  startTime: DateTime(2026, 5, 25, 9),
  endTime: DateTime(2026, 5, 25, 10, 30),
  title: 'Draft the launch memo',
);

PlannedBlock _linked() => PlannedBlock(
  id: 'block-linked',
  categoryId: 'work',
  startTime: DateTime(2026, 5, 25, 11),
  endTime: DateTime(2026, 5, 25, 12),
  title: 'Penguin roll call',
  taskId: 'task-roll-call',
);

PlannedBlock _buffer() => PlannedBlock(
  id: 'block-buffer',
  categoryId: 'work',
  startTime: DateTime(2026, 5, 25, 10, 30),
  endTime: DateTime(2026, 5, 25, 11),
  title: 'Buffer',
  type: PlannedBlockType.buffer,
);

PlannedBlock _calendar() => PlannedBlock(
  id: 'block-cal',
  categoryId: 'work',
  startTime: DateTime(2026, 5, 25, 14),
  endTime: DateTime(2026, 5, 25, 15),
  title: 'Board meeting',
  type: PlannedBlockType.cal,
);

Task _task({
  String id = 'task-sardines',
  String title = 'Negotiate sardine futures',
  String? categoryId = 'life',
  DateTime? deletedAt,
}) => testTask.copyWith(
  meta: testTask.meta.copyWith(
    id: id,
    categoryId: categoryId,
    deletedAt: deletedAt,
  ),
  data: testTask.data.copyWith(title: title),
);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late Map<String, AgentDomainEntity> entities;
  late List<AgentDomainEntity> upserted;
  late List<String> notified;
  late List<({String title, String categoryId, int? estimateMinutes})>
  createdTasks;
  Task? Function()? factoryResult;

  DayAgentBlockActions actions() => DayAgentBlockActions(
    syncService: syncService,
    journalDb: journalDb,
    reads: DayAgentPlanReads(agentRepository: agentRepository),
    onPersistedStateChanged: notified.add,
    taskFactory:
        ({
          required title,
          required categoryId,
          required now,
          estimateMinutes,
          due,
          profileId,
        }) async {
          createdTasks.add((
            title: title,
            categoryId: categoryId,
            estimateMinutes: estimateMinutes,
          ));
          return factoryResult == null
              ? _task(id: 'task-new', title: title, categoryId: categoryId)
              : factoryResult!();
        },
  );

  DayPlanEntity seedPlan(List<PlannedBlock> blocks) {
    final plan =
        AgentDomainEntity.dayPlan(
              id: 'day_agent_plan:$_dayId',
              agentId: _agentId,
              dayId: _dayId,
              planDate: DateTime(2026, 5, 25),
              data: DayPlanData(
                planDate: DateTime(2026, 5, 25),
                status: const DayPlanStatus.draft(),
                plannedBlocks: blocks,
              ),
              createdAt: _now,
              updatedAt: _now,
              vectorClock: null,
            )
            as DayPlanEntity;
    entities[plan.id] = plan;
    return plan;
  }

  void plannable(String id, {bool available = true}) {
    when(() => journalDb.getCategoryById(id)).thenAnswer(
      (_) async => CategoryTestUtils.createTestCategory(
        id: id,
        isAvailableForDayPlan: available,
      ),
    );
  }

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
    entities = {
      _agentId: makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
        kind: AgentKinds.dayAgent,
        allowedCategoryIds: {'work', 'life'},
      ),
    };
    upserted = [];
    notified = [];
    createdTasks = [];
    factoryResult = null;
    when(() => agentRepository.getEntity(any())).thenAnswer(
      (invocation) async =>
          entities[invocation.positionalArguments.single as String],
    );
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      upserted.add(entity);
      entities[entity.id] = entity;
    });
    when(() => journalDb.getCategoryById(any())).thenAnswer((_) async => null);
    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
  });

  Matcher refusal(String fragment) => throwsA(
    isA<DayAgentCaptureException>().having(
      (e) => e.message,
      'message',
      contains(fragment),
    ),
  );

  PlannedBlock blockOf(DayPlanEntity plan, String id) =>
      plan.data.plannedBlocks.singleWhere((block) => block.id == id);

  group('removeBlock', () {
    test('takes the block off, recounts the day, and notifies', () async {
      seedPlan([_standalone(), _buffer(), _linked()]);
      final later = _now.add(const Duration(hours: 1));

      final result = await withClock(
        Clock.fixed(later),
        () => actions().removeBlock(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-plain',
        ),
      );

      expect(result.removed, _standalone());
      expect(
        result.plan.data.plannedBlocks.map((block) => block.id),
        ['block-buffer', 'block-linked'],
      );
      expect(result.plan.scheduledMinutes, 90);
      expect(result.plan.updatedAt, later);
      expect(upserted.single, result.plan);
      expect(notified, [_agentId, _dayId, result.plan.id]);
    });

    test('refuses calendar blocks, unknown blocks and missing plans', () async {
      seedPlan([_calendar()]);
      await expectLater(
        () => actions().removeBlock(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-cal',
        ),
        refusal('calendar-owned'),
      );
      await expectLater(
        () => actions().removeBlock(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'nope',
        ),
        refusal('no block nope'),
      );
      entities.remove('day_agent_plan:$_dayId');
      await expectLater(
        () => actions().removeBlock(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-cal',
        ),
        refusal('no plan for $_dayId'),
      );
      expect(upserted, isEmpty);
    });
  });

  group('restoreBlock', () {
    test('puts a removed block back where its times place it', () async {
      seedPlan([_buffer(), _linked()]);

      final restored = await actions().restoreBlock(
        agentId: _agentId,
        dayId: _dayId,
        block: _standalone(),
      );

      expect(
        restored.data.plannedBlocks.map((block) => block.id),
        ['block-plain', 'block-buffer', 'block-linked'],
      );
      expect(restored.scheduledMinutes, 180);
      expect(upserted.single, restored);
    });

    test('a block already on the plan leaves it untouched', () async {
      final plan = seedPlan([_standalone()]);

      final restored = await actions().restoreBlock(
        agentId: _agentId,
        dayId: _dayId,
        block: _standalone(),
      );

      expect(restored, plan);
      expect(upserted, isEmpty);
    });
  });

  group('linkTask', () {
    test("takes the task's title and its plannable category", () async {
      seedPlan([_standalone()]);
      plannable('life');
      when(
        () => journalDb.journalEntityById('task-sardines'),
      ).thenAnswer((_) async => _task());

      final linked = await actions().linkTask(
        agentId: _agentId,
        dayId: _dayId,
        blockId: 'block-plain',
        taskId: 'task-sardines',
      );

      final block = blockOf(linked, 'block-plain');
      expect(block.taskId, 'task-sardines');
      expect(block.title, 'Negotiate sardine futures');
      expect(block.categoryId, 'life');
      expect(upserted.single, linked);
    });

    test('keeps its own category when the task has none, or one that may '
        'not be planned with', () async {
      seedPlan([_standalone()]);
      plannable('closed', available: false);
      for (final categoryId in [null, 'closed', 'other-agent']) {
        when(() => journalDb.journalEntityById('task-sardines')).thenAnswer(
          (_) async => _task(categoryId: categoryId),
        );

        final linked = await actions().linkTask(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-plain',
          taskId: 'task-sardines',
        );

        expect(blockOf(linked, 'block-plain').categoryId, 'work');
      }
    });

    test('a block placed by hand can carry a task too', () async {
      seedPlan([_standalone().copyWith(type: PlannedBlockType.manual)]);
      when(
        () => journalDb.journalEntityById('task-sardines'),
      ).thenAnswer((_) async => _task());

      final linked = await actions().linkTask(
        agentId: _agentId,
        dayId: _dayId,
        blockId: 'block-plain',
        taskId: 'task-sardines',
      );

      expect(blockOf(linked, 'block-plain').taskId, 'task-sardines');
    });

    test('keeps the block title when the task has none', () async {
      seedPlan([_standalone()]);
      when(
        () => journalDb.journalEntityById('task-blank'),
      ).thenAnswer((_) async => _task(id: 'task-blank', title: '  '));

      final linked = await actions().linkTask(
        agentId: _agentId,
        dayId: _dayId,
        blockId: 'block-plain',
        taskId: 'task-blank',
      );

      expect(blockOf(linked, 'block-plain').title, 'Draft the launch memo');
    });

    test(
      'refuses a missing or deleted task, buffers and calendar blocks',
      () async {
        seedPlan([_standalone(), _buffer(), _calendar()]);
        when(() => journalDb.journalEntityById('task-gone')).thenAnswer(
          (_) async => _task(id: 'task-gone', deletedAt: _now),
        );

        await expectLater(
          () => actions().linkTask(
            agentId: _agentId,
            dayId: _dayId,
            blockId: 'block-plain',
            taskId: 'task-missing',
          ),
          refusal('no task task-missing'),
        );
        await expectLater(
          () => actions().linkTask(
            agentId: _agentId,
            dayId: _dayId,
            blockId: 'block-plain',
            taskId: 'task-gone',
          ),
          refusal('no task task-gone'),
        );
        await expectLater(
          () => actions().linkTask(
            agentId: _agentId,
            dayId: _dayId,
            blockId: 'block-buffer',
            taskId: 'task-gone',
          ),
          refusal('is a buffer'),
        );
        await expectLater(
          () => actions().linkTask(
            agentId: _agentId,
            dayId: _dayId,
            blockId: 'block-cal',
            taskId: 'task-gone',
          ),
          refusal('calendar-owned'),
        );
      },
    );
  });

  group('unlinkTask', () {
    test("drops the task and keeps its title as the block's own", () async {
      seedPlan([_linked()]);

      final unlinked = await actions().unlinkTask(
        agentId: _agentId,
        dayId: _dayId,
        blockId: 'block-linked',
      );

      final block = blockOf(unlinked, 'block-linked');
      expect(block.taskId, isNull);
      expect(block.title, 'Penguin roll call');
      expect(upserted.single, unlinked);
    });

    test('refuses a block without a task', () async {
      seedPlan([_standalone()]);
      await expectLater(
        () => actions().unlinkTask(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-plain',
        ),
        refusal('has no task'),
      );
    });
  });

  group('createTaskForBlock', () {
    test('makes a task named, filed and estimated after the block, and '
        'links it', () async {
      seedPlan([_standalone()]);
      plannable('work');

      final created = await actions().createTaskForBlock(
        agentId: _agentId,
        dayId: _dayId,
        blockId: 'block-plain',
      );

      expect(createdTasks, [
        (
          title: 'Draft the launch memo',
          categoryId: 'work',
          estimateMinutes: 90,
        ),
      ]);
      expect(created.task.meta.id, 'task-new');
      expect(blockOf(created.plan, 'block-plain').taskId, 'task-new');
      expect(upserted.single, created.plan);
    });

    test('refuses a block that already has a task, has no title, or could '
        'not get one', () async {
      seedPlan([
        _linked(),
        _standalone().copyWith(id: 'block-untitled', title: ' '),
        _standalone(),
      ]);
      await expectLater(
        () => actions().createTaskForBlock(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-linked',
        ),
        refusal('already has a task'),
      );
      await expectLater(
        () => actions().createTaskForBlock(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-untitled',
        ),
        refusal('no title'),
      );
      factoryResult = () => null;
      await expectLater(
        () => actions().createTaskForBlock(
          agentId: _agentId,
          dayId: _dayId,
          blockId: 'block-plain',
        ),
        refusal('could not create a task'),
      );
      expect(upserted, isEmpty);
    });

    test(
      'refuses buffers and calendar blocks before creating anything',
      () async {
        seedPlan([_buffer(), _calendar()]);
        await expectLater(
          () => actions().createTaskForBlock(
            agentId: _agentId,
            dayId: _dayId,
            blockId: 'block-buffer',
          ),
          refusal('is a buffer'),
        );
        expect(createdTasks, isEmpty);
      },
    );
  });

  test('refuses an unknown agent', () async {
    seedPlan([_standalone()]);
    entities.remove(_agentId);
    await expectLater(
      () => actions().removeBlock(
        agentId: _agentId,
        dayId: _dayId,
        blockId: 'block-plain',
      ),
      refusal('agent $_agentId not found'),
    );
  });
}
