import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/logic/create/task_agent_assignment.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/agents/test_utils.dart';
import '../../features/categories/test_utils.dart';
import '../../mocks/mocks.dart';

void main() {
  late MockTaskAgentService mockService;

  setUp(() {
    mockService = MockTaskAgentService();
  });

  Task makeTask({String? categoryId}) {
    return Task(
      meta: Metadata(
        id: 'task-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        categoryId: categoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 0,
        ),
        title: 'Task',
        statusHistory: const [],
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        estimate: Duration.zero,
      ),
    );
  }

  void stubCreate() {
    when(
      () => mockService.createTaskAgent(
        taskId: any(named: 'taskId'),
        templateId: any(named: 'templateId'),
        profileId: any(named: 'profileId'),
        setupOrigin: any(named: 'setupOrigin'),
        setupOriginEntityId: any(named: 'setupOriginEntityId'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        awaitContent: any(named: 'awaitContent'),
        automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
      ),
    ).thenAnswer((_) async => makeTestIdentity(id: 'agent-1'));
  }

  /// The `automaticUpdatesEnabled` value the helper forwarded.
  bool capturedSeed() {
    return verify(
          () => mockService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            setupOrigin: any(named: 'setupOrigin'),
            setupOriginEntityId: any(named: 'setupOriginEntityId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
            automaticUpdatesEnabled: captureAny(
              named: 'automaticUpdatesEnabled',
            ),
          ),
        ).captured.single
        as bool;
  }

  group('assignCategoryDefaultTaskAgent', () {
    // The category's wake preference is a creation-time seed: it decides what
    // the new agent starts with, and the per-task switch owns it afterwards.
    test('forwards the category opt-in as the agent seed', () async {
      stubCreate();

      final result = await assignCategoryDefaultTaskAgent(
        service: mockService,
        task: makeTask(categoryId: 'cat-1'),
        category: CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          defaultTemplateId: 'template-1',
          automaticAgentWakesEnabled: true,
        ),
      );

      expect(result.assigned, isTrue);
      expect(capturedSeed(), isTrue);
    });

    test('seeds off when the category opted out', () async {
      stubCreate();

      await assignCategoryDefaultTaskAgent(
        service: mockService,
        task: makeTask(categoryId: 'cat-1'),
        category: CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          defaultTemplateId: 'template-1',
          automaticAgentWakesEnabled: false,
        ),
      );

      expect(capturedSeed(), isFalse);
    });

    // Absent means off, which is what `createTaskAgent` hardcoded before the
    // category could express a preference — so upgrading changes nothing.
    test('seeds off when the category never expressed a preference', () async {
      stubCreate();

      await assignCategoryDefaultTaskAgent(
        service: mockService,
        task: makeTask(categoryId: 'cat-1'),
        category: CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          defaultTemplateId: 'template-1',
        ),
      );

      expect(capturedSeed(), isFalse);
    });

    test(
      'carries the category profile and origin alongside the seed',
      () async {
        stubCreate();

        await assignCategoryDefaultTaskAgent(
          service: mockService,
          task: makeTask(categoryId: 'cat-1'),
          category: CategoryTestUtils.createTestCategory(
            id: 'cat-1',
            defaultTemplateId: 'template-1',
            defaultProfileId: 'profile-1',
            automaticAgentWakesEnabled: true,
          ),
        );

        verify(
          () => mockService.createTaskAgent(
            taskId: 'task-1',
            templateId: 'template-1',
            profileId: 'profile-1',
            setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
            setupOriginEntityId: 'cat-1',
            allowedCategoryIds: {'cat-1'},
            awaitContent: true,
            automaticUpdatesEnabled: true,
          ),
        ).called(1);
      },
    );

    test('skips without a default template', () async {
      final result = await assignCategoryDefaultTaskAgent(
        service: mockService,
        task: makeTask(categoryId: 'cat-1'),
        category: CategoryTestUtils.createTestCategory(id: 'cat-1'),
      );

      expect(result.status, TaskAgentAssignmentStatus.skipped);
      verifyNever(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
    });

    test('skips when the task has no category', () async {
      final result = await assignCategoryDefaultTaskAgent(
        service: mockService,
        task: makeTask(),
        category: CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          defaultTemplateId: 'template-1',
        ),
      );

      expect(result.status, TaskAgentAssignmentStatus.skipped);
    });

    test('reports a creation failure instead of throwing', () async {
      when(
        () => mockService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          profileId: any(named: 'profileId'),
          setupOrigin: any(named: 'setupOrigin'),
          setupOriginEntityId: any(named: 'setupOriginEntityId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          awaitContent: any(named: 'awaitContent'),
          automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
        ),
      ).thenThrow(StateError('already exists'));

      final result = await assignCategoryDefaultTaskAgent(
        service: mockService,
        task: makeTask(categoryId: 'cat-1'),
        category: CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          defaultTemplateId: 'template-1',
        ),
      );

      expect(result.status, TaskAgentAssignmentStatus.failed);
      expect(result.error, isStateError);
      expect(result.assigned, isFalse);
    });
  });
}
