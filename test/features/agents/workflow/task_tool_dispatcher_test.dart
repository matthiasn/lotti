import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

enum _GeneratedDispatchGuardTool {
  setTaskTitle,
  updateTaskDueDate,
  updateTaskPriority,
  assignTaskLabels,
  addMultipleChecklistItems,
  updateChecklistItems,
  setTaskLanguage,
  setTaskStatus,
}

enum _GeneratedInvalidArgShape {
  missing,
  nullValue,
  number,
  boolean,
  map,
  emptyString,
  plainString,
  emptyList,
}

class _GeneratedDispatchGuardScenario {
  const _GeneratedDispatchGuardScenario({
    required this.tool,
    required this.shapeSeed,
  });

  final _GeneratedDispatchGuardTool tool;
  final int shapeSeed;

  String get toolName => switch (tool) {
    _GeneratedDispatchGuardTool.setTaskTitle => TaskAgentToolNames.setTaskTitle,
    _GeneratedDispatchGuardTool.updateTaskDueDate =>
      TaskAgentToolNames.updateTaskDueDate,
    _GeneratedDispatchGuardTool.updateTaskPriority =>
      TaskAgentToolNames.updateTaskPriority,
    _GeneratedDispatchGuardTool.assignTaskLabels =>
      TaskAgentToolNames.assignTaskLabels,
    _GeneratedDispatchGuardTool.addMultipleChecklistItems =>
      TaskAgentToolNames.addMultipleChecklistItems,
    _GeneratedDispatchGuardTool.updateChecklistItems =>
      TaskAgentToolNames.updateChecklistItems,
    _GeneratedDispatchGuardTool.setTaskLanguage =>
      TaskAgentToolNames.setTaskLanguage,
    _GeneratedDispatchGuardTool.setTaskStatus =>
      TaskAgentToolNames.setTaskStatus,
  };

  String get argKey => switch (tool) {
    _GeneratedDispatchGuardTool.setTaskTitle => 'title',
    _GeneratedDispatchGuardTool.updateTaskDueDate => 'dueDate',
    _GeneratedDispatchGuardTool.updateTaskPriority => 'priority',
    _GeneratedDispatchGuardTool.assignTaskLabels => 'labels',
    _GeneratedDispatchGuardTool.addMultipleChecklistItems => 'items',
    _GeneratedDispatchGuardTool.updateChecklistItems => 'items',
    _GeneratedDispatchGuardTool.setTaskLanguage => 'languageCode',
    _GeneratedDispatchGuardTool.setTaskStatus => 'status',
  };

  String get expectedErrorFragment => 'Type validation failed';

  _GeneratedInvalidArgShape get invalidShape {
    final shapes = switch (tool) {
      _GeneratedDispatchGuardTool.updateTaskDueDate ||
      _GeneratedDispatchGuardTool.updateTaskPriority => const [
        _GeneratedInvalidArgShape.missing,
        _GeneratedInvalidArgShape.nullValue,
        _GeneratedInvalidArgShape.number,
        _GeneratedInvalidArgShape.boolean,
        _GeneratedInvalidArgShape.map,
        _GeneratedInvalidArgShape.emptyString,
      ],
      _GeneratedDispatchGuardTool.assignTaskLabels ||
      _GeneratedDispatchGuardTool.addMultipleChecklistItems ||
      _GeneratedDispatchGuardTool.updateChecklistItems => const [
        _GeneratedInvalidArgShape.missing,
        _GeneratedInvalidArgShape.nullValue,
        _GeneratedInvalidArgShape.number,
        _GeneratedInvalidArgShape.boolean,
        _GeneratedInvalidArgShape.map,
        _GeneratedInvalidArgShape.plainString,
        _GeneratedInvalidArgShape.emptyList,
      ],
      _ => const [
        _GeneratedInvalidArgShape.missing,
        _GeneratedInvalidArgShape.nullValue,
        _GeneratedInvalidArgShape.number,
        _GeneratedInvalidArgShape.boolean,
        _GeneratedInvalidArgShape.map,
        _GeneratedInvalidArgShape.emptyList,
      ],
    };
    return shapes[shapeSeed % shapes.length];
  }

  Map<String, dynamic> get args {
    if (invalidShape == _GeneratedInvalidArgShape.missing) {
      return const {};
    }
    return {argKey: invalidValue};
  }

  Object? get invalidValue => switch (invalidShape) {
    _GeneratedInvalidArgShape.missing => null,
    _GeneratedInvalidArgShape.nullValue => null,
    _GeneratedInvalidArgShape.number => 42,
    _GeneratedInvalidArgShape.boolean => true,
    _GeneratedInvalidArgShape.map => const {'unexpected': 'value'},
    _GeneratedInvalidArgShape.emptyString => '',
    _GeneratedInvalidArgShape.plainString => 'not-a-list',
    _GeneratedInvalidArgShape.emptyList => const <dynamic>[],
  };

  @override
  String toString() {
    return '_GeneratedDispatchGuardScenario('
        'toolName: $toolName, args: $args)';
  }
}

extension _AnyGeneratedDispatchGuardScenario on glados.Any {
  glados.Generator<_GeneratedDispatchGuardTool> get dispatchGuardTool =>
      glados.AnyUtils(this).choose(_GeneratedDispatchGuardTool.values);

  glados.Generator<_GeneratedDispatchGuardScenario> get dispatchGuardScenario =>
      glados.CombinableAny(this).combine2(
        dispatchGuardTool,
        glados.IntAnys(this).intInRange(0, 1000),
        (
          _GeneratedDispatchGuardTool tool,
          int shapeSeed,
        ) => _GeneratedDispatchGuardScenario(
          tool: tool,
          shapeSeed: shapeSeed,
        ),
      );
}

enum _GeneratedValidDispatchTool {
  setTaskTitle,
  updateTaskEstimate,
  updateTaskDueDate,
  updateTaskPriority,
  setTaskLanguage,
  setTaskStatus,
}

class _GeneratedValidDispatchScenario {
  const _GeneratedValidDispatchScenario({
    required this.tool,
    required this.seed,
    required this.useStringNumber,
    required this.padString,
  });

  final _GeneratedValidDispatchTool tool;
  final int seed;
  final bool useStringNumber;
  final bool padString;

  String get toolName => switch (tool) {
    _GeneratedValidDispatchTool.setTaskTitle => TaskAgentToolNames.setTaskTitle,
    _GeneratedValidDispatchTool.updateTaskEstimate =>
      TaskAgentToolNames.updateTaskEstimate,
    _GeneratedValidDispatchTool.updateTaskDueDate =>
      TaskAgentToolNames.updateTaskDueDate,
    _GeneratedValidDispatchTool.updateTaskPriority =>
      TaskAgentToolNames.updateTaskPriority,
    _GeneratedValidDispatchTool.setTaskLanguage =>
      TaskAgentToolNames.setTaskLanguage,
    _GeneratedValidDispatchTool.setTaskStatus =>
      TaskAgentToolNames.setTaskStatus,
  };

  int get expectedMinutes => seed % 1439 + 1;

  String get expectedDueDate {
    final day = (seed % 28 + 1).toString().padLeft(2, '0');
    return '2026-08-$day';
  }

  TaskPriority get expectedPriority => switch (seed % 3) {
    0 => TaskPriority.p0Urgent,
    1 => TaskPriority.p1High,
    _ => TaskPriority.p3Low,
  };

  String get expectedLanguage => switch (seed % 5) {
    0 => 'en',
    1 => 'de',
    2 => 'fr',
    3 => 'es',
    _ => 'ro',
  };

  String get expectedStatus => switch (seed % 4) {
    0 => 'IN PROGRESS',
    1 => 'GROOMED',
    2 => 'BLOCKED',
    _ => 'ON HOLD',
  };

  String get statusReason => 'Generated status reason $seed';

  String _maybePadded(String value) => padString ? '  $value  ' : value;

  Map<String, dynamic> get args => switch (tool) {
    _GeneratedValidDispatchTool.setTaskTitle => {
      'title': _maybePadded('Generated title $seed'),
    },
    _GeneratedValidDispatchTool.updateTaskEstimate => {
      'minutes': useStringNumber ? '$expectedMinutes' : expectedMinutes,
    },
    _GeneratedValidDispatchTool.updateTaskDueDate => {
      'dueDate': expectedDueDate,
    },
    _GeneratedValidDispatchTool.updateTaskPriority => {
      'priority': _maybePadded(expectedPriority.short.toLowerCase()),
    },
    _GeneratedValidDispatchTool.setTaskLanguage => {
      'languageCode': _maybePadded(expectedLanguage.toUpperCase()),
    },
    _GeneratedValidDispatchTool.setTaskStatus => {
      'status': _maybePadded(expectedStatus.toLowerCase()),
      if (expectedStatus == 'BLOCKED' || expectedStatus == 'ON HOLD')
        'reason': _maybePadded(statusReason),
    },
  };

  void expectMutation(Task updatedTask) {
    switch (tool) {
      case _GeneratedValidDispatchTool.setTaskTitle:
        expect(updatedTask.data.title, 'Generated title $seed');
      case _GeneratedValidDispatchTool.updateTaskEstimate:
        expect(updatedTask.data.estimate, Duration(minutes: expectedMinutes));
      case _GeneratedValidDispatchTool.updateTaskDueDate:
        expect(updatedTask.data.due, DateTime.parse(expectedDueDate));
      case _GeneratedValidDispatchTool.updateTaskPriority:
        expect(updatedTask.data.priority, expectedPriority);
      case _GeneratedValidDispatchTool.setTaskLanguage:
        expect(updatedTask.data.languageCode, expectedLanguage);
        expect(updatedTask.data.languageSource, ChangeSource.agent);
      case _GeneratedValidDispatchTool.setTaskStatus:
        expect(updatedTask.data.status.toDbString, expectedStatus);
        expect(updatedTask.data.statusHistory, hasLength(1));
        if (expectedStatus == 'BLOCKED') {
          expect((updatedTask.data.status as TaskBlocked).reason, statusReason);
        }
        if (expectedStatus == 'ON HOLD') {
          expect((updatedTask.data.status as TaskOnHold).reason, statusReason);
        }
    }
  }

  @override
  String toString() {
    return '_GeneratedValidDispatchScenario('
        'toolName: $toolName, args: $args)';
  }
}

extension _AnyGeneratedValidDispatchScenario on glados.Any {
  glados.Generator<_GeneratedValidDispatchTool> get validDispatchTool =>
      glados.AnyUtils(this).choose(_GeneratedValidDispatchTool.values);

  glados.Generator<_GeneratedValidDispatchScenario> get validDispatchScenario =>
      glados.CombinableAny(this).combine4(
        validDispatchTool,
        glados.IntAnys(this).intInRange(0, 10000),
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        (
          _GeneratedValidDispatchTool tool,
          int seed,
          bool useStringNumber,
          bool padString,
        ) => _GeneratedValidDispatchScenario(
          tool: tool,
          seed: seed,
          useStringNumber: useStringNumber,
          padString: padString,
        ),
      );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb mockJournalDb;
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
  late MockLabelsRepository mockLabelsRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockTimeService mockTimeService;
  late TaskToolDispatcher dispatcher;

  const taskId = 'task-001';

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockJournalRepository = MockJournalRepository();
    mockChecklistRepository = MockChecklistRepository();
    mockLabelsRepository = MockLabelsRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockTimeService = MockTimeService();

    dispatcher = TaskToolDispatcher(
      journalDb: mockJournalDb,
      journalRepository: mockJournalRepository,
      checklistRepository: mockChecklistRepository,
      labelsRepository: mockLabelsRepository,
      persistenceLogic: mockPersistenceLogic,
      timeService: mockTimeService,
    );
  });

  group('TaskToolDispatcher', () {
    group('dispatch — task lookup', () {
      test('returns failure when task entity is not found', () async {
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);

        final result = await dispatcher.dispatch(
          'set_task_title',
          {'title': 'New Title'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('not found'));
        expect(result.errorMessage, 'Task lookup failed');
      });

      test('returns failure for unknown tool name', () async {
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => _makeTestTask(taskId));

        final result = await dispatcher.dispatch(
          'nonexistent_tool',
          <String, dynamic>{},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('Unknown tool: nonexistent_tool'));
        expect(result.errorMessage, contains('not registered'));
      });
    });

    group('dispatch — type validation guards', () {
      setUp(() {
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => _makeTestTask(taskId));
      });

      test('set_task_title rejects non-string title', () async {
        final result = await dispatcher.dispatch(
          'set_task_title',
          {'title': 42},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a string'));
        expect(result.errorMessage, contains('Type validation failed'));
      });

      test('update_task_due_date rejects non-string dueDate', () async {
        final result = await dispatcher.dispatch(
          'update_task_due_date',
          {'dueDate': 123},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"dueDate" must be a non-empty'));
        expect(result.errorMessage, contains('Type validation failed'));
      });

      test('update_task_due_date rejects empty dueDate', () async {
        final result = await dispatcher.dispatch(
          'update_task_due_date',
          {'dueDate': ''},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"dueDate" must be a non-empty'));
      });

      test('update_task_priority rejects non-string priority', () async {
        final result = await dispatcher.dispatch(
          'update_task_priority',
          {'priority': true},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"priority" must be a non-empty'));
      });

      test('update_task_estimate rejects null minutes', () async {
        final result = await dispatcher.dispatch(
          'update_task_estimate',
          <String, dynamic>{},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"minutes" is required'));
        expect(result.errorMessage, 'Missing minutes parameter');
      });

      test('assign_task_labels rejects non-list labels', () async {
        final result = await dispatcher.dispatch(
          'assign_task_labels',
          {'labels': 'not-a-list'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"labels" must be an array'));
      });

      test('set_task_language rejects non-string languageCode', () async {
        final result = await dispatcher.dispatch(
          'set_task_language',
          {'languageCode': 42},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"languageCode" must be a string'));
      });

      test('set_task_status rejects non-string status', () async {
        final result = await dispatcher.dispatch(
          'set_task_status',
          {'status': 123},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"status" must be a string'));
      });

      test('add_multiple_checklist_items rejects non-list items', () async {
        final result = await dispatcher.dispatch(
          'add_multiple_checklist_items',
          {'items': 'not-a-list'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });

      test('add_multiple_checklist_items rejects empty list', () async {
        final result = await dispatcher.dispatch(
          'add_multiple_checklist_items',
          {'items': <dynamic>[]},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });

      test('update_checklist_items rejects non-list items', () async {
        final result = await dispatcher.dispatch(
          'update_checklist_items',
          {'items': 'not-a-list'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });

      test('update_checklist_items rejects empty list', () async {
        final result = await dispatcher.dispatch(
          'update_checklist_items',
          {'items': <dynamic>[]},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });

      glados.Glados(
        glados.any.dispatchGuardScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'rejects generated invalid top-level argument shapes before delegation',
        (scenario) async {
          final localJournalDb = MockJournalDb();
          final localDispatcher = TaskToolDispatcher(
            journalDb: localJournalDb,
            journalRepository: MockJournalRepository(),
            checklistRepository: MockChecklistRepository(),
            labelsRepository: MockLabelsRepository(),
            persistenceLogic: MockPersistenceLogic(),
            timeService: MockTimeService(),
          );

          when(
            () => localJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => _makeTestTask(taskId));

          final result = await localDispatcher.dispatch(
            scenario.toolName,
            scenario.args,
            taskId,
          );

          expect(result.success, isFalse, reason: '$scenario');
          expect(result.output, contains('"${scenario.argKey}"'));
          expect(
            result.errorMessage,
            contains(scenario.expectedErrorFragment),
            reason: '$scenario',
          );
          expect(result.mutatedEntityId, isNull, reason: '$scenario');
        },
        tags: 'glados',
      );
    });

    group('dispatch — handler delegation', () {
      setUp(() {
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => _makeTestTask(taskId));
      });

      test('set_task_title delegates to TaskTitleHandler', () async {
        // The dispatcher is the single write path for both auto-applied
        // initial titles and user-confirmed renames — it does NOT gate
        // on current title. The "never overwrite a populated title"
        // invariant lives in TaskAgentStrategy._shouldAutoApplyInitialTitle
        // for the auto-apply path; user-confirmed renames are explicit
        // user intent and must write regardless.
        when(
          () => mockJournalRepository.updateJournalEntityDate(
            any(),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalRepository.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'set_task_title',
          {'title': 'Updated Title'},
          taskId,
        );

        expect(result.success, isTrue);
        expect(result.output, isNotEmpty);
        verify(
          () => mockJournalRepository.updateJournalEntity(any()),
        ).called(1);
      });

      test('set_task_status delegates to TaskStatusHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'set_task_status',
          {'status': 'IN PROGRESS'},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('set_task_language delegates to TaskLanguageHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'set_task_language',
          {'languageCode': 'en'},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('update_task_estimate delegates to TaskEstimateHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'update_task_estimate',
          {'minutes': 60},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('update_task_due_date delegates to TaskDueDateHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'update_task_due_date',
          {'dueDate': '2024-12-31'},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('update_task_priority delegates to TaskPriorityHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'update_task_priority',
          {'priority': 'P1'},
          taskId,
        );

        expect(result.success, isTrue);
      });

      glados.Glados(
        glados.any.validDispatchScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test(
        'applies generated valid scalar task mutations',
        (scenario) async {
          final localJournalDb = MockJournalDb();
          final localJournalRepository = MockJournalRepository();
          final localDispatcher = TaskToolDispatcher(
            journalDb: localJournalDb,
            journalRepository: localJournalRepository,
            checklistRepository: MockChecklistRepository(),
            labelsRepository: MockLabelsRepository(),
            persistenceLogic: MockPersistenceLogic(),
            timeService: MockTimeService(),
          );

          when(
            () => localJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => _makeTestTask(taskId));
          when(
            () => localJournalRepository.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final result = await localDispatcher.dispatch(
            scenario.toolName,
            scenario.args,
            taskId,
          );

          expect(result.success, isTrue, reason: '$scenario');
          expect(result.mutatedEntityId, taskId, reason: '$scenario');

          final captured =
              verify(
                    () => localJournalRepository.updateJournalEntity(
                      captureAny(),
                    ),
                  ).captured.single
                  as Task;
          expect(captured.id, taskId, reason: '$scenario');
          scenario.expectMutation(captured);
        },
        tags: 'glados',
      );

      group('request_attention', () {
        const requesterAgentId = 'task-agent-001';
        final now = DateTime(2026, 5, 26, 8);
        final args = {
          'title': 'Finish tax packet',
          'requestedMinutes': 90,
          'impact': 5,
          'urgency': 4,
          'energyFit': 'high',
          'earliestStart': '2026-05-27T09:00:00.000',
          'latestEnd': '2026-05-28T17:00:00.000',
          'deadline': '2026-05-29T12:00:00.000',
          'rationale': 'Due soon and still needs a focused block.',
        };

        late MockJournalDb localJournalDb;
        late MockAgentRepository localAgentRepository;
        late MockAgentSyncService localSyncService;
        late TaskToolDispatcher localDispatcher;

        setUp(() {
          localJournalDb = MockJournalDb();
          localAgentRepository = MockAgentRepository();
          localSyncService = MockAgentSyncService();
          localDispatcher = TaskToolDispatcher(
            journalDb: localJournalDb,
            journalRepository: MockJournalRepository(),
            checklistRepository: MockChecklistRepository(),
            labelsRepository: MockLabelsRepository(),
            persistenceLogic: MockPersistenceLogic(),
            timeService: MockTimeService(),
            agentRepository: localAgentRepository,
            syncService: localSyncService,
            requestingAgentId: requesterAgentId,
          );

          when(
            () => localJournalDb.journalEntityById(taskId),
          ).thenAnswer(
            (_) async => _makeTestTask(taskId, categoryId: 'work'),
          );
          when(
            () => localAgentRepository.getAttentionClaimsForTarget(
              targetKind: 'task',
              targetId: taskId,
            ),
          ).thenAnswer((_) async => const []);
          when(
            () => localSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});
        });

        test('creates a synced task attention request', () async {
          final result = await withClock(Clock.fixed(now), () {
            return localDispatcher.dispatch(
              TaskAgentToolNames.requestAttention,
              args,
              taskId,
            );
          });

          expect(result.success, isTrue);
          expect(result.output, contains('Attention request created'));
          expect(result.mutatedEntityId, isNull);

          final captured =
              verify(
                    () => localSyncService.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentDomainEntity;
          expect(captured, isA<AttentionRequestEntity>());
          final request = captured as AttentionRequestEntity;
          expect(request.agentId, requesterAgentId);
          expect(request.kind, AttentionRequestKind.task);
          expect(request.title, 'Finish tax packet');
          expect(request.categoryId, 'work');
          expect(request.requestedMinutes, 90);
          expect(request.impact, 5);
          expect(request.urgency, 4);
          expect(request.energyFit, AttentionEnergyFit.high);
          expect(request.scopeKind, AttentionClaimScopeKind.dateRange);
          expect(request.earliestStart, DateTime(2026, 5, 27, 9));
          expect(request.latestEnd, DateTime(2026, 5, 28, 17));
          expect(request.deadline, DateTime(2026, 5, 29, 12));
          expect(request.targetId, taskId);
          expect(request.targetKind, 'task');
          expect(
            request.rationale,
            'Due soon and still needs a focused block.',
          );
          expect(request.createdAt, now);
          expect(request.evidenceRefs.single.id, taskId);
        });

        test('does not duplicate an equivalent active request', () async {
          when(
            () => localAgentRepository.getAttentionClaimsForTarget(
              targetKind: 'task',
              targetId: taskId,
            ),
          ).thenAnswer(
            (_) async => [
              _makeAttentionRequest(
                id: 'attention-existing',
                agentId: requesterAgentId,
                taskId: taskId,
                categoryId: 'work',
              ),
            ],
          );

          final result = await withClock(Clock.fixed(now), () {
            return localDispatcher.dispatch(
              TaskAgentToolNames.requestAttention,
              args,
              taskId,
            );
          });

          expect(result.success, isTrue);
          expect(result.output, contains('already active'));
          verifyNever(() => localSyncService.upsertEntity(any()));
        });

        test(
          'supersedes stale active requests before writing the new one',
          () async {
            when(
              () => localAgentRepository.getAttentionClaimsForTarget(
                targetKind: 'task',
                targetId: taskId,
              ),
            ).thenAnswer(
              (_) async => [
                _makeAttentionRequest(
                  id: 'attention-stale',
                  agentId: requesterAgentId,
                  taskId: taskId,
                  categoryId: 'work',
                  requestedMinutes: 30,
                ),
              ],
            );

            final result = await withClock(Clock.fixed(now), () {
              return localDispatcher.dispatch(
                TaskAgentToolNames.requestAttention,
                args,
                taskId,
              );
            });

            expect(result.success, isTrue);

            final captured = verify(
              () => localSyncService.upsertEntity(captureAny()),
            ).captured.cast<AgentDomainEntity>().toList();
            expect(captured, hasLength(2));
            final disposition =
                captured.first as AttentionClaimDispositionEntity;
            expect(disposition.requestId, 'attention-stale');
            expect(disposition.status, AttentionClaimStatus.superseded);
            expect(disposition.createdAt, now);
            expect(captured.last, isA<AttentionRequestEntity>());
          },
        );
      });
    });

    group('dispatch — handlers requiring getIt', () {
      late MockDomainLogger mockLoggingService;

      setUp(() {
        mockLoggingService = MockDomainLogger();

        // Register getIt dependencies needed by internal handlers.
        getIt
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<DomainLogger>(mockLoggingService);

        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => _makeTestTask(taskId));

        // Common stubs for logging service.
        when(
          () => mockLoggingService.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);
        when(
          () => mockLoggingService.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
      });

      tearDown(() async {
        await getIt.reset();
      });

      test(
        'assign_task_labels delegates to TaskLabelHandler '
        '(no-op when all labels low confidence)',
        () async {
          // Provide labels with low confidence — the parser drops them,
          // resulting in an early no-op success in TaskLabelHandler.handle.
          // This covers the dispatcher's processor/handler creation and
          // result conversion code path.
          final result = await dispatcher.dispatch(
            'assign_task_labels',
            {
              'labels': [
                {'id': 'label-a', 'confidence': 'low'},
              ],
            },
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, contains('No valid labels'));
        },
      );

      test(
        'assign_task_labels delegates to TaskLabelHandler '
        '(valid labels assigned)',
        () async {
          // Stub label validation: return label as valid.
          when(
            () => mockJournalDb.getLabelDefinitionById('label-a'),
          ).thenAnswer((_) async => _makeLabelDef('label-a'));
          when(
            () => mockJournalDb.getAllLabelDefinitions(),
          ).thenAnswer((_) async => [_makeLabelDef('label-a')]);
          when(
            () => mockLabelsRepository.addLabels(
              journalEntityId: any(named: 'journalEntityId'),
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          ).thenAnswer((_) async => true);

          final result = await dispatcher.dispatch(
            'assign_task_labels',
            {
              'labels': [
                {'id': 'label-a', 'confidence': 'very_high'},
              ],
            },
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, contains('assign_task_labels'));
        },
      );

      test(
        'add_multiple_checklist_items delegates to '
        'LottiBatchChecklistHandler',
        () async {
          // The task has no checklists, so the handler creates a new one
          // via AutoChecklistService.autoCreateChecklist.
          // autoCreateChecklist calls checklistRepository.createChecklist.
          when(
            () => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
              items: any(named: 'items'),
              title: any(named: 'title'),
            ),
          ).thenAnswer(
            (_) async => (
              checklist: null,
              createdItems: <({String id, String title, bool isChecked})>[],
            ),
          );

          final result = await dispatcher.dispatch(
            'add_multiple_checklist_items',
            {
              'items': [
                {'title': 'Buy milk'},
                {'title': 'Walk the dog'},
              ],
            },
            taskId,
          );

          // Parsing succeeded — the handler returns success even if
          // checklist creation yielded no items (no-op).
          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'update_checklist_items delegates to '
        'LottiChecklistUpdateHandler',
        () async {
          // Task has no checklists → handler skips all items.
          final result = await dispatcher.dispatch(
            'update_checklist_items',
            {
              'items': [
                {'id': 'item-001', 'isChecked': true},
              ],
            },
            taskId,
          );

          // Parsing succeeded — the handler returns success=true even
          // when all items are skipped (no-op).
          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'add_multiple_checklist_items surfaces handler parse error for '
        'array-of-strings items',
        () async {
          // The dispatcher's own guard accepts a non-empty list, so the
          // call reaches LottiBatchChecklistHandler.processFunctionCall,
          // which rejects string entries (it expects objects with a title).
          // This exercises the dispatcher's parse-failure branch where the
          // non-null handler error is surfaced verbatim in both output and
          // errorMessage, and no entity is mutated.
          final result = await dispatcher.dispatch(
            'add_multiple_checklist_items',
            {
              'items': ['just a string'],
            },
            taskId,
          );

          expect(result.success, isFalse);
          expect(result.output, contains('must be an object with a title'));
          expect(result.errorMessage, result.output);
          expect(result.mutatedEntityId, isNull);
        },
      );

      test(
        'update_checklist_items surfaces handler parse error for '
        'non-object items',
        () async {
          // The dispatcher guard accepts a non-empty list, so the call
          // reaches LottiChecklistUpdateHandler.processFunctionCall, which
          // rejects a non-object entry. This exercises the dispatcher's
          // parse-failure branch, surfacing the non-null handler error
          // verbatim in both output and errorMessage with no mutation.
          final result = await dispatcher.dispatch(
            'update_checklist_items',
            {
              'items': ['not-an-object'],
            },
            taskId,
          );

          expect(result.success, isFalse);
          expect(
            result.output,
            contains('Item at index 0 is not an object'),
          );
          expect(result.errorMessage, result.output);
          expect(result.mutatedEntityId, isNull);
        },
      );

      test(
        'add_checklist_item wraps as single-element batch',
        () async {
          when(
            () => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
              items: any(named: 'items'),
              title: any(named: 'title'),
            ),
          ).thenAnswer(
            (_) async => (
              checklist: null,
              createdItems: <({String id, String title, bool isChecked})>[],
            ),
          );

          final result = await dispatcher.dispatch(
            'add_checklist_item',
            {'title': 'Single item'},
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'update_checklist_item wraps as single-element batch',
        () async {
          final result = await dispatcher.dispatch(
            'update_checklist_item',
            {'id': 'item-001', 'isChecked': true},
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'assign_task_label wraps as single-element labels array',
        () async {
          final labelDef = _makeLabelDef('label-bug');
          when(
            () => mockJournalDb.getLabelDefinitionById('label-bug'),
          ).thenAnswer((_) async => labelDef);

          when(
            () => mockLabelsRepository.addLabels(
              journalEntityId: any(named: 'journalEntityId'),
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          ).thenAnswer((_) async => true);

          final result = await dispatcher.dispatch(
            'assign_task_label',
            {'id': 'label-bug', 'confidence': 'high'},
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'create_follow_up_task delegates to FollowUpTaskHandler',
        () async {
          final newTask = _makeTestTask('new-task-001');

          // FollowUpTaskHandler needs a source task to inherit category.
          when(
            () => mockPersistenceLogic.createTaskEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => newTask);

          // Stub verify-lookup after task creation.
          when(
            () => mockJournalDb.journalEntityById('new-task-001'),
          ).thenAnswer((_) async => newTask);

          when(
            () => mockPersistenceLogic.createLink(
              fromId: any(named: 'fromId'),
              toId: any(named: 'toId'),
            ),
          ).thenAnswer((_) async => true);

          final result = await dispatcher.dispatch(
            'create_follow_up_task',
            {'title': 'Follow-Up Task'},
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, contains('Follow-Up Task'));
        },
      );

      test(
        'create_time_entry delegates to TimeEntryHandler',
        () async {
          // Dispatcher does a top-level task lookup before routing.
          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => _makeTestTask(taskId));

          // Missing summary causes TimeEntryHandler to return early,
          // proving the dispatch route reaches the handler.
          final result = await dispatcher.dispatch(
            'create_time_entry',
            {'startTime': '2026-03-17T14:00:00'},
            taskId,
          );

          expect(result.success, isFalse);
          expect(result.errorMessage, 'Missing, empty, or too-long summary');
        },
      );

      test(
        'update_running_timer delegates to RunningTimerUpdateHandler',
        () async {
          // Dispatcher does a top-level task lookup before routing.
          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => _makeTestTask(taskId));
          // No timer running — handler returns early with "No active timer",
          // which proves the dispatch route reaches RunningTimerUpdateHandler
          // (and that no other handler intercepted the call).
          when(() => mockTimeService.getCurrent()).thenReturn(null);

          final result = await dispatcher.dispatch(
            'update_running_timer',
            {'timerId': 'timer-xyz', 'summary': 'Refined description'},
            taskId,
          );

          expect(result.success, isFalse);
          expect(result.errorMessage, 'No active timer');
        },
      );

      test(
        'update_time_entry delegates to TimeEntryUpdateHandler',
        () async {
          const entryId = 'entry-xyz';
          final entry = _makeJournalEntry(entryId);
          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => _makeTestTask(taskId));
          when(
            () => mockJournalDb.journalEntityById(entryId),
          ).thenAnswer((_) async => entry);
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => [entry]);
          when(() => mockTimeService.getCurrent()).thenReturn(null);
          when(
            () => mockPersistenceLogic.updateJournalEntry(
              journalEntityId: any(named: 'journalEntityId'),
              entryText: any(named: 'entryText'),
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
            ),
          ).thenAnswer((_) async => true);

          final result = await dispatcher.dispatch(
            'update_time_entry',
            {'entryId': entryId, 'summary': 'Updated notes'},
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.mutatedEntityId, entryId);
        },
      );

      test(
        'migrate_checklist_item delegates to ChecklistMigrationHandler',
        () async {
          // The handler needs the checklist item, source task, and target task.
          // Since the task has no checklists and item won't be found, it
          // will fail at the item lookup step — but this proves dispatch
          // routing works.
          when(
            () => mockJournalDb.journalEntityById('item-x'),
          ).thenAnswer((_) async => null);

          final result = await dispatcher.dispatch(
            'migrate_checklist_item',
            {
              'id': 'item-x',
              'title': 'Migrate me',
              'targetTaskId': 'target-001',
            },
            taskId,
          );

          // Handler returns failure because item is not found.
          expect(result.success, isFalse);
          expect(result.output, contains('checklist item item-x not found'));
        },
      );
    });
  });
}

JournalEntry _makeJournalEntry(String id) {
  return JournalEntry(
    meta: Metadata(
      id: id,
      dateFrom: DateTime(2024, 3, 15, 10),
      dateTo: DateTime(2024, 3, 15, 11),
      createdAt: DateTime(2024, 3, 15, 10),
      updatedAt: DateTime(2024, 3, 15, 10),
    ),
  );
}

/// Creates a minimal [LabelDefinition] for testing.
LabelDefinition _makeLabelDef(String id) {
  return LabelDefinition(
    id: id,
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    name: 'Label $id',
    color: '#FF0000',
    vectorClock: null,
  );
}

/// Creates a minimal [Task] entity for testing dispatch.
Task _makeTestTask(
  String id, {
  String title = 'Test Task',
  String? categoryId,
}) {
  return Task(
    meta: Metadata(
      id: id,
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      categoryId: categoryId,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: id,
        createdAt: DateTime(2024, 3, 15),
        utcOffset: 0,
      ),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      statusHistory: [],
      title: title,
    ),
  );
}

AttentionRequestEntity _makeAttentionRequest({
  required String id,
  required String agentId,
  required String taskId,
  required String categoryId,
  int requestedMinutes = 90,
}) {
  return AgentDomainEntity.attentionRequest(
        id: id,
        agentId: agentId,
        kind: AttentionRequestKind.task,
        title: 'Finish tax packet',
        categoryId: categoryId,
        requestedMinutes: requestedMinutes,
        impact: 5,
        urgency: 4,
        energyFit: AttentionEnergyFit.high,
        evidenceRefs: [
          AttentionEvidenceRef(
            kind: AttentionEvidenceKind.task,
            id: taskId,
            label: 'Test Task',
          ),
        ],
        scopeKind: AttentionClaimScopeKind.dateRange,
        earliestStart: DateTime(2026, 5, 27, 9),
        latestEnd: DateTime(2026, 5, 28, 17),
        deadline: DateTime(2026, 5, 29, 12),
        targetId: taskId,
        targetKind: 'task',
        rationale: 'Due soon and still needs a focused block.',
        createdAt: DateTime(2026, 5, 26, 8),
        vectorClock: null,
      )
      as AttentionRequestEntity;
}
