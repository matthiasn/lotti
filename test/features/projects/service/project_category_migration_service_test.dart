import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/projects/service/project_category_migration_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockProjectRepository projectRepository;
  late MockJournalRepository journalRepository;
  late MockProjectAgentService projectAgentService;
  late ProjectCategoryMigrationService service;
  late ProjectAgentMutationCoordinator mutationCoordinator;
  late ProjectEntry original;
  late ProjectEntry requested;
  late Task task;
  late JournalImage attachment;
  late Map<String, JournalEntity> entries;
  late ProjectEntry persistedProject;

  setUp(() {
    projectRepository = MockProjectRepository();
    journalRepository = MockJournalRepository();
    projectAgentService = MockProjectAgentService();
    mutationCoordinator = ProjectAgentMutationCoordinator();
    service = ProjectCategoryMigrationService(
      projectRepository,
      journalRepository,
      projectAgentService,
      mutationCoordinator,
    );

    original = makeTestProject(
      id: 'project-1',
      categoryId: 'category-old',
    );
    requested = original.copyWith(
      meta: original.meta.copyWith(categoryId: 'category-new'),
    );
    task = makeTestTask(id: 'task-1').copyWith(
      meta: makeTestTask(id: 'task-1').meta.copyWith(
        categoryId: 'category-old',
      ),
    );
    attachment =
        JournalEntity.journalImage(
              meta: task.meta.copyWith(id: 'image-1'),
              data: ImageData(
                capturedAt: task.meta.createdAt,
                imageId: 'image-1',
                imageFile: 'image-1.jpg',
                imageDirectory: '/images/',
              ),
            )
            as JournalImage;
    entries = {task.id: task, attachment.id: attachment};
    persistedProject = original;

    when(
      () => projectRepository.getProjectById(original.id),
    ).thenAnswer((_) async => persistedProject);
    when(
      () => projectRepository.getTasksForProjectUnfiltered(original.id),
    ).thenAnswer((_) async => [task]);
    when(
      () => journalRepository.getLinkedEntities(linkedTo: task.id),
    ).thenAnswer((_) async => [attachment]);
    when(
      () => projectRepository.unlinkTaskFromProject(task.id),
    ).thenAnswer((_) async => true);
    when(
      () => projectRepository.linkTaskToProject(
        projectId: original.id,
        taskId: task.id,
      ),
    ).thenAnswer((_) async => true);
    when(
      () => projectAgentService.updateProjectAgentScopes(
        projectId: original.id,
        allowedCategoryIds: {'category-new'},
      ),
    ).thenAnswer(
      (_) async => {
        'agent-1': {'category-old'},
      },
    );
    when(
      () => projectAgentService.restoreProjectAgentScopes(
        projectId: original.id,
        scopesByAgentId: {
          'agent-1': {'category-old'},
        },
      ),
    ).thenAnswer((_) async {});
    when(() => projectRepository.updateProject(any())).thenAnswer((call) async {
      persistedProject = call.positionalArguments.single as ProjectEntry;
      return true;
    });
    when(
      () => journalRepository.updateCategoryId(
        any(),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((call) async {
      final id = call.positionalArguments.single as String;
      final categoryId = call.namedArguments[#categoryId] as String?;
      final current = entries[id];
      if (current == null) return false;
      entries[id] = current.copyWith(
        meta: current.meta.copyWith(categoryId: categoryId),
      );
      return true;
    });
    when(
      () => journalRepository.getJournalEntityById(any()),
    ).thenAnswer((call) async {
      return entries[call.positionalArguments.single as String];
    });
  });

  test('moves project work and agent scope together', () async {
    final saved = await service.save(requested);

    expect(saved, isTrue);
    expect(persistedProject.meta.categoryId, 'category-new');
    expect(entries[task.id]?.meta.categoryId, 'category-new');
    expect(entries[attachment.id]?.meta.categoryId, 'category-new');
    verify(
      () => projectAgentService.updateProjectAgentScopes(
        projectId: original.id,
        allowedCategoryIds: {'category-new'},
      ),
    ).called(1);
    verify(
      () => projectRepository.unlinkTaskFromProject(task.id),
    ).called(1);
    verify(
      () => projectRepository.linkTaskToProject(
        projectId: original.id,
        taskId: task.id,
      ),
    ).called(1);
  });

  test('waits for an in-flight project-agent mutation', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final provisioning = mutationCoordinator.run(original.id, () async {
      started.complete();
      await release.future;
    });
    await started.future;

    final save = service.save(requested);
    await Future<void>.value();
    verifyNever(() => projectRepository.getProjectById(original.id));

    release.complete();
    await provisioning;
    expect(await save, isTrue);
    verify(() => projectRepository.getProjectById(original.id)).called(1);
  });

  test('restores project work and agent scope when relinking fails', () async {
    var linkAttempts = 0;
    when(
      () => projectRepository.linkTaskToProject(
        projectId: original.id,
        taskId: task.id,
      ),
    ).thenAnswer((_) async => ++linkAttempts > 1);

    final saved = await service.save(requested);

    expect(saved, isFalse);
    expect(persistedProject.meta.categoryId, 'category-old');
    expect(entries[task.id]?.meta.categoryId, 'category-old');
    expect(entries[attachment.id]?.meta.categoryId, 'category-old');
    verify(
      () => projectAgentService.restoreProjectAgentScopes(
        projectId: original.id,
        scopesByAgentId: {
          'agent-1': {'category-old'},
        },
      ),
    ).called(1);
    expect(linkAttempts, 2);
  });
}
