import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/project_proposal_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart';
import '../test_utils.dart';

void main() {
  const projectId = 'project-1';
  late MockChangeSetConfirmationService confirmation;
  late MockProjectRepository repository;
  late MockDomainLogger logger;
  late List<String> removed;
  late bool removerSucceeds;
  late ProjectProposalService service;

  final open = ProjectStatus.open(
    id: 'status-open',
    createdAt: DateTime(2026, 9),
    utcOffset: 0,
  );
  final monitoring = ProjectStatus.monitoring(
    id: 'status-monitoring',
    createdAt: DateTime(2026, 9, 5),
    utcOffset: 0,
  );

  ChangeSetEntity setWith(ChangeItem item) => makeTestChangeSet(
    id: 'set-1',
    agentId: 'agent-1',
    taskId: projectId,
    items: [item],
  );
  const createTask = ChangeItem(
    toolName: 'create_task',
    args: {'title': 'Pack fish'},
    humanSummary: 'Create task',
  );
  const setStatus = ChangeItem(
    toolName: 'update_project_status',
    args: {'status': 'monitoring'},
    humanSummary: 'Set status',
  );
  ChangeSetEntity decided(ChangeItem item, ChangeItemStatus status) =>
      setWith(item.copyWith(status: status));

  setUpAll(registerAllFallbackValues);
  setUp(() {
    confirmation = MockChangeSetConfirmationService();
    repository = MockProjectRepository();
    logger = MockDomainLogger();
    removed = [];
    removerSucceeds = true;
    service = ProjectProposalService(
      confirmation: confirmation,
      projectRepository: repository,
      taskRemover: (taskId) async {
        removed.add(taskId);
        return removerSucceeds;
      },
      domainLogger: logger,
    );
    // The real reopen runs the revert once the record is pending again and
    // reports its outcome; the mock does the same so the tests exercise the
    // revert through the same seam.
    when(
      () => confirmation.reopenItem(
        any(),
        any(),
        revert: any(named: 'revert'),
      ),
    ).thenAnswer((invocation) async {
      final revert =
          invocation.namedArguments[#revert] as Future<bool> Function()?;
      return revert == null || await revert();
    });
    when(() => repository.updateProject(any())).thenAnswer((_) async => true);
  });

  test('reject delegates to the confirmation service', () async {
    when(
      () => confirmation.rejectItem(any(), any()),
    ).thenAnswer((_) async => true);
    final set = setWith(createTask);

    expect(await service.reject(set, 0), isTrue);
    verify(() => confirmation.rejectItem(set, 0)).called(1);
  });

  test(
    'a rejection is always undoable; a confirmation only once remembered',
    () async {
      expect(
        service.canUndo(decided(createTask, ChangeItemStatus.rejected), 0),
        isTrue,
      );
      expect(
        service.canUndo(decided(createTask, ChangeItemStatus.confirmed), 0),
        isFalse,
        reason: 'nothing remembered: the effect cannot be put back',
      );
      expect(service.canUndo(setWith(createTask), 0), isFalse);
      expect(
        service.canUndo(decided(createTask, ChangeItemStatus.retracted), 0),
        isFalse,
      );

      when(() => confirmation.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: '',
          mutatedEntityId: 'task-9',
        ),
      );
      final set = setWith(createTask);
      expect((await service.confirm(set, 0)).success, isTrue);
      expect(
        service.canUndo(decided(createTask, ChangeItemStatus.confirmed), 0),
        isTrue,
      );
    },
  );

  test('a failed confirmation remembers nothing', () async {
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(success: false, output: 'no'),
    );
    expect((await service.confirm(setWith(createTask), 0)).success, isFalse);
    expect(
      service.canUndo(decided(createTask, ChangeItemStatus.confirmed), 0),
      isFalse,
    );
  });

  test('undoing a created task removes it, then reopens the item', () async {
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: 'task-9',
      ),
    );
    final set = setWith(createTask);
    await service.confirm(set, 0);
    final applied = decided(createTask, ChangeItemStatus.confirmed);

    expect(await service.undo(applied, 0), isTrue);
    expect(removed, ['task-9']);
    verify(
      () => confirmation.reopenItem(
        applied,
        0,
        revert: any(named: 'revert', that: isNotNull),
      ),
    ).called(1);
    verifyNever(() => repository.getProjectById(any()));
    expect(
      service.canUndo(applied, 0),
      isFalse,
      reason: 'the memo is spent',
    );
  });

  test('undoing a status change restores the status and its history', () async {
    final before = makeTestProject(id: projectId, status: open);
    when(
      () => repository.getProjectById(projectId),
    ).thenAnswer((_) async => before);
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: projectId,
      ),
    );
    final set = setWith(setStatus);
    await service.confirm(set, 0);

    // The tool moved the project on and appended the old status to history.
    final after = before.copyWith(
      data: before.data.copyWith(
        status: monitoring,
        statusHistory: [open],
      ),
    );
    when(
      () => repository.getProjectById(projectId),
    ).thenAnswer((_) async => after);

    expect(
      await service.undo(decided(setStatus, ChangeItemStatus.confirmed), 0),
      isTrue,
    );
    final restored =
        verify(() => repository.updateProject(captureAny())).captured.single
            as ProjectEntry;
    expect(restored.data.status, open);
    expect(restored.data.statusHistory, isEmpty);
    expect(removed, isEmpty);
  });

  test('undoing a rejection only reopens the item', () async {
    final rejected = decided(setStatus, ChangeItemStatus.rejected);

    expect(await service.undo(rejected, 0), isTrue);
    verify(
      () => confirmation.reopenItem(
        rejected,
        0,
        revert: any(named: 'revert', that: isNull),
      ),
    ).called(1);
    verifyNever(() => repository.updateProject(any()));
    expect(removed, isEmpty);
  });

  test(
    'a task that will not go, or a project that will not save, stops the undo',
    () async {
      when(() => confirmation.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: '',
          mutatedEntityId: 'task-9',
        ),
      );
      await service.confirm(setWith(createTask), 0);
      removerSucceeds = false;
      final applied = decided(createTask, ChangeItemStatus.confirmed);
      expect(await service.undo(applied, 0), isFalse);
      expect(service.canUndo(applied, 0), isTrue, reason: 'still undoable');
      verify(
        () => logger.log(
          LogDomain.agentWorkflow,
          any<String>(that: contains('task-9')),
          subDomain: 'ProjectProposal',
          level: any<InsightLevel>(named: 'level'),
        ),
      ).called(1);

      final before = makeTestProject(id: projectId, status: open);
      when(
        () => repository.getProjectById(projectId),
      ).thenAnswer((_) async => before);
      await service.confirm(setWith(setStatus), 0);
      final moved = before.copyWith(
        data: before.data.copyWith(status: monitoring, statusHistory: [open]),
      );
      when(
        () => repository.getProjectById(projectId),
      ).thenAnswer((_) async => moved);
      when(
        () => repository.updateProject(any()),
      ).thenAnswer((_) async => false);
      final status = decided(setStatus, ChangeItemStatus.confirmed);
      expect(await service.undo(status, 0), isFalse);
      verify(
        () => logger.log(
          LogDomain.agentWorkflow,
          any<String>(that: contains('status')),
          subDomain: 'ProjectProposal',
          level: any<InsightLevel>(named: 'level'),
        ),
      ).called(1);

      when(
        () => repository.getProjectById(projectId),
      ).thenAnswer((_) async => null);
      expect(await service.undo(status, 0), isFalse, reason: 'project gone');
    },
  );

  test('a status that moved on since the confirmation is left alone', () async {
    final before = makeTestProject(id: projectId, status: open);
    when(
      () => repository.getProjectById(projectId),
    ).thenAnswer((_) async => before);
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: projectId,
      ),
    );
    await service.confirm(setWith(setStatus), 0);
    final applied = decided(setStatus, ChangeItemStatus.confirmed);
    final active = ProjectStatus.active(
      id: 'status-active',
      createdAt: DateTime(2026, 9, 6),
      utcOffset: 0,
    );

    // Another editor moved the project on after the tool set Monitoring.
    when(() => repository.getProjectById(projectId)).thenAnswer(
      (_) async => before.copyWith(
        data: before.data.copyWith(
          status: active,
          statusHistory: [open, monitoring],
        ),
      ),
    );
    expect(await service.undo(applied, 0), isFalse);
    verifyNever(() => repository.updateProject(any()));

    // The tool's own write raced a sync: the status is right but the
    // history does not end in what this session remembers replacing.
    when(() => repository.getProjectById(projectId)).thenAnswer(
      (_) async => before.copyWith(
        data: before.data.copyWith(
          status: monitoring,
          statusHistory: [active],
        ),
      ),
    );
    expect(await service.undo(applied, 0), isFalse);
    verifyNever(() => repository.updateProject(any()));
    expect(service.canUndo(applied, 0), isTrue);
  });

  test('a status the tool did not need to change is not restored', () async {
    final already = makeTestProject(id: projectId, status: monitoring);
    when(
      () => repository.getProjectById(projectId),
    ).thenAnswer((_) async => already);
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(success: true, output: ''),
    );
    await service.confirm(setWith(setStatus), 0);

    expect(
      await service.undo(decided(setStatus, ChangeItemStatus.confirmed), 0),
      isTrue,
    );
    verifyNever(() => repository.updateProject(any()));
  });

  test('a proposal without a parsable target status is not restored', () async {
    final before = makeTestProject(id: projectId, status: open);
    when(
      () => repository.getProjectById(projectId),
    ).thenAnswer((_) async => before);
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(success: true, output: ''),
    );
    const odd = ChangeItem(
      toolName: 'update_project_status',
      args: {'status': 42},
      humanSummary: 'Set status',
    );
    await service.confirm(setWith(odd), 0);
    when(() => repository.getProjectById(projectId)).thenAnswer(
      (_) async => before.copyWith(
        data: before.data.copyWith(status: monitoring, statusHistory: [open]),
      ),
    );

    expect(
      await service.undo(decided(odd, ChangeItemStatus.confirmed), 0),
      isFalse,
    );
    verifyNever(() => repository.updateProject(any()));
  });

  test('a refused reopen keeps the memo for another try', () async {
    when(
      () => confirmation.reopenItem(
        any(),
        any(),
        revert: any(named: 'revert'),
      ),
    ).thenAnswer((_) async => false);
    when(() => confirmation.confirmItem(any(), any())).thenAnswer(
      (_) async => const ToolExecutionResult(
        success: true,
        output: '',
        mutatedEntityId: 'task-9',
      ),
    );
    await service.confirm(setWith(createTask), 0);
    final applied = decided(createTask, ChangeItemStatus.confirmed);

    expect(await service.undo(applied, 0), isFalse);
    expect(service.canUndo(applied, 0), isTrue);
  });
}
