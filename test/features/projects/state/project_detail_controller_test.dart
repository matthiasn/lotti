import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/service/project_category_migration_service.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockProjectRepository mockRepo;
  late MockProjectCategoryMigrationService mockCategoryMigrationService;
  late StreamController<Set<String>> updateStreamController;

  final projectId = uuid.v1();

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockProjectRepository();
    mockCategoryMigrationService = MockProjectCategoryMigrationService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(
      () => mockRepo.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    when(
      () => mockRepo.getProjectById(projectId),
    ).thenAnswer((_) async => makeTestProject(id: projectId));
    when(
      () => mockRepo.getTasksForProject(projectId),
    ).thenAnswer((_) async => []);
    when(
      () => mockCategoryMigrationService.save(any()),
    ).thenAnswer((invocation) {
      return mockRepo.updateProject(
        invocation.positionalArguments.single as ProjectEntry,
      );
    });
  });

  tearDown(() async {
    await updateStreamController.close();
  });

  /// Creates a container and waits for the controller to finish loading.
  Future<ProviderContainer> createLoadedContainer() async {
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
        projectCategoryMigrationServiceProvider.overrideWithValue(
          mockCategoryMigrationService,
        ),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<void>();
    final subscription = container.listen(
      projectDetailControllerProvider(projectId),
      (_, next) {
        if (!next.isLoading && next.project != null && !completer.isCompleted) {
          completer.complete();
        }
      },
    );

    container.read(projectDetailControllerProvider(projectId).notifier);
    await completer.future.timeout(const Duration(seconds: 1));
    subscription.close();

    return container;
  }

  group('ProjectDetailController', () {
    test('loads project on build', () async {
      final container = await createLoadedContainer();

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.project, isNotNull);
      expect(state.project!.data.title, 'Test Project');
      expect(state.isLoading, isFalse);
      expect(state.hasChanges, isFalse);
      expect(state.linkedTasks, isEmpty);
    });

    test('updateTitle marks hasChanges true', () async {
      final container = await createLoadedContainer();

      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateTitle('New Title');

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      final notifier = container.read(
        projectDetailControllerProvider(projectId).notifier,
      );
      expect(state.hasChanges, isTrue);
      expect(state.project!.data.title, 'New Title');
      expect(notifier.isTitleDirty, isTrue);
      expect(notifier.isDescriptionDirty, isFalse);
    });

    test('updateDescription marks hasChanges true', () async {
      final container = await createLoadedContainer();

      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateDescription('A clear project brief.');

      final state = container.read(projectDetailControllerProvider(projectId));
      final notifier = container.read(
        projectDetailControllerProvider(projectId).notifier,
      );
      expect(state.hasChanges, isTrue);
      expect(state.project?.entryText?.plainText, 'A clear project brief.');
      expect(notifier.isTitleDirty, isFalse);
      expect(notifier.isDescriptionDirty, isTrue);
    });

    test('updateDescription preserves ancillary entry text', () async {
      final geolocation = Geolocation(
        createdAt: DateTime(2026, 8, 16),
        latitude: 52.52,
        longitude: 13.405,
        geohashString: 'u33d',
      );
      final project = makeTestProject(id: projectId).copyWith(
        entryText: EntryText(
          plainText: 'Old description',
          markdown: '**Old description**',
          quill: '[{"insert":"Old description"}]',
          geolocation: geolocation,
        ),
      );
      when(
        () => mockRepo.getProjectById(projectId),
      ).thenAnswer((_) async => project);
      final container = await createLoadedContainer();

      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateDescription('Updated description');

      final entryText = container
          .read(projectDetailControllerProvider(projectId))
          .project
          ?.entryText;
      expect(entryText?.plainText, 'Updated description');
      expect(entryText?.markdown, '**Old description**');
      expect(entryText?.quill, '[{"insert":"Old description"}]');
      expect(entryText?.geolocation, geolocation);
    });

    test('updateTargetDate marks hasChanges true', () async {
      final container = await createLoadedContainer();

      final newDate = DateTime(2025, 6, 15);
      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateTargetDate(newDate);

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.hasChanges, isTrue);
      expect(state.project!.data.targetDate, newDate);
    });

    test('saveChanges persists updates and resets hasChanges', () async {
      when(() => mockRepo.updateProject(any())).thenAnswer((_) async => true);

      final container = await createLoadedContainer();

      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateTitle('Updated Title');

      await container
          .read(projectDetailControllerProvider(projectId).notifier)
          .saveChanges();

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.hasChanges, isFalse);
      expect(state.isSaving, isFalse);
      verify(() => mockRepo.updateProject(any())).called(1);
    });

    test('saveChanges with empty title shows error', () async {
      final container = await createLoadedContainer();

      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateTitle('');

      await container
          .read(projectDetailControllerProvider(projectId).notifier)
          .saveChanges();

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.error, ProjectDetailError.titleRequired);
      verifyNever(() => mockRepo.updateProject(any()));
    });

    test('updateTitle clears stale errors', () async {
      final container = await createLoadedContainer();
      final notifier = container.read(
        projectDetailControllerProvider(projectId).notifier,
      );

      // Trigger a titleRequired error then save to set error state.
      // ignore: cascade_invocations
      notifier.updateTitle('');
      await notifier.saveChanges();
      expect(
        container.read(projectDetailControllerProvider(projectId)).error,
        ProjectDetailError.titleRequired,
      );

      // Editing the title should clear the error
      notifier.updateTitle('Fixed');
      expect(
        container.read(projectDetailControllerProvider(projectId)).error,
        isNull,
      );
    });

    test('no changes when setting same title', () async {
      final container = await createLoadedContainer();

      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateTitle('Test Project');

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.hasChanges, isFalse);
    });

    test(
      'updateStatus marks hasChanges without appending history',
      () async {
        final container = await createLoadedContainer();
        final notifier = container.read(
          projectDetailControllerProvider(projectId).notifier,
        );

        final newStatus = ProjectStatus.active(
          id: uuid.v1(),
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 0,
        );
        notifier.updateStatus(newStatus);

        final state = container.read(
          projectDetailControllerProvider(projectId),
        );
        expect(state.hasChanges, isTrue);
        expect(state.project!.data.status, isA<ProjectActive>());
        // History is only appended at save time, not during picker changes.
        expect(state.project!.data.statusHistory, isEmpty);
      },
    );

    test(
      'saveChanges appends original status to history when status changed',
      () async {
        ProjectEntry? persisted;
        when(
          () => mockRepo.updateProject(any()),
        ).thenAnswer((invocation) async {
          persisted = invocation.positionalArguments.first as ProjectEntry;
          return true;
        });

        final container = await createLoadedContainer();
        final notifier = container.read(
          projectDetailControllerProvider(projectId).notifier,
        );

        final newStatus = ProjectStatus.active(
          id: uuid.v1(),
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 0,
        );
        notifier.updateStatus(newStatus);
        await notifier.saveChanges();

        final state = container.read(
          projectDetailControllerProvider(projectId),
        );
        expect(state.hasChanges, isFalse);
        expect(state.project!.data.status, isA<ProjectActive>());
        // The original open status should be in history after save.
        expect(state.project!.data.statusHistory, hasLength(1));
        expect(state.project!.data.statusHistory.first, isA<ProjectOpen>());

        // The entity handed to the repository carries the new status and the
        // appended history — not just the in-memory state.
        expect(persisted, isNotNull);
        expect(persisted!.data.status, isA<ProjectActive>());
        expect(persisted!.data.statusHistory, hasLength(1));
        expect(persisted!.data.statusHistory.first, isA<ProjectOpen>());
      },
    );

    test(
      'saveChanges persists the updated category to the repository',
      () async {
        ProjectEntry? persisted;
        when(
          () => mockRepo.updateProject(any()),
        ).thenAnswer((invocation) async {
          persisted = invocation.positionalArguments.first as ProjectEntry;
          return true;
        });

        final container = await createLoadedContainer();
        final notifier = container.read(
          projectDetailControllerProvider(projectId).notifier,
        )..updateCategoryId('new-category-id');
        await notifier.saveChanges();

        final state = container.read(
          projectDetailControllerProvider(projectId),
        );
        expect(state.hasChanges, isFalse);
        expect(state.project!.meta.categoryId, 'new-category-id');

        // Category changes go through the migration service so linked work and
        // agent scope move with the project.
        verify(() => mockCategoryMigrationService.save(any())).called(1);
        expect(persisted, isNotNull);
        expect(persisted!.meta.categoryId, 'new-category-id');
      },
    );

    test(
      'saveChanges sets updateFailed when repository returns false',
      () async {
        when(
          () => mockRepo.updateProject(any()),
        ).thenAnswer((_) async => false);

        final container = await createLoadedContainer();
        container
            .read(projectDetailControllerProvider(projectId).notifier)
            .updateTitle('Changed');
        await container
            .read(projectDetailControllerProvider(projectId).notifier)
            .saveChanges();

        final state = container.read(
          projectDetailControllerProvider(projectId),
        );
        expect(state.error, ProjectDetailError.updateFailed);
        expect(state.isSaving, isFalse);
      },
    );

    test(
      'discardChanges restores persisted state after a failed save',
      () async {
        when(
          () => mockRepo.updateProject(any()),
        ).thenAnswer((_) async => false);

        final container = await createLoadedContainer();
        final notifier = container.read(
          projectDetailControllerProvider(projectId).notifier,
        )..updateTitle('Unsaved optimistic title');
        await notifier.saveChanges();

        expect(
          container
              .read(projectDetailControllerProvider(projectId))
              .project!
              .data
              .title,
          'Unsaved optimistic title',
        );

        notifier.discardChanges();
        final restored = container.read(
          projectDetailControllerProvider(projectId),
        );
        expect(restored.project!.data.title, 'Test Project');
        expect(restored.hasChanges, isFalse);
        expect(restored.error, isNull);
      },
    );

    test(
      'failed save discards to a concurrently reloaded persisted baseline',
      () async {
        final updateResult = Completer<bool>();
        when(
          () => mockRepo.updateProject(any()),
        ).thenAnswer((_) => updateResult.future);
        final container = await createLoadedContainer();
        final notifier = container.read(
          projectDetailControllerProvider(projectId).notifier,
        );
        final saveFuture = (notifier..updateTitle('Unsaved optimistic title'))
            .saveChanges();
        expect(
          container.read(projectDetailControllerProvider(projectId)).isSaving,
          isTrue,
        );

        final syncedProject = makeTestProject(id: projectId).copyWith(
          data: makeTestProject(
            id: projectId,
          ).data.copyWith(title: 'Title received from sync'),
        );
        final syncedTask = makeTestTask(id: 'synced-task');
        when(
          () => mockRepo.getProjectById(projectId),
        ).thenAnswer((_) async => syncedProject);
        when(
          () => mockRepo.getTasksForProject(projectId),
        ).thenAnswer((_) async => [syncedTask]);
        final reloadObserved = Completer<void>();
        final subscription = container.listen(
          projectDetailControllerProvider(projectId),
          (_, next) {
            if (next.linkedTasks.any((task) => task.id == syncedTask.id) &&
                !reloadObserved.isCompleted) {
              reloadObserved.complete();
            }
          },
        );

        updateStreamController.add({projectId});
        await reloadObserved.future;
        subscription.close();
        expect(
          container
              .read(projectDetailControllerProvider(projectId))
              .project!
              .data
              .title,
          'Unsaved optimistic title',
        );

        updateResult.complete(false);
        await saveFuture;
        notifier.discardChanges();

        final restored = container.read(
          projectDetailControllerProvider(projectId),
        );
        expect(restored.project!.data.title, 'Title received from sync');
        expect(restored.hasChanges, isFalse);
        expect(restored.error, isNull);
      },
    );

    test('rebases pending fields onto a concurrently synced project', () async {
      ProjectEntry? persisted;
      when(() => mockRepo.updateProject(any())).thenAnswer((invocation) async {
        persisted = invocation.positionalArguments.single as ProjectEntry;
        return true;
      });
      final container = await createLoadedContainer();
      final notifier = container.read(
        projectDetailControllerProvider(projectId).notifier,
      );
      final localTargetDate = DateTime(2026, 9);
      notifier.updateTargetDate(localTargetDate);

      final syncedStatus = ProjectStatus.active(
        id: 'synced-status',
        createdAt: DateTime(2026, 8, 16),
        utcOffset: 0,
      );
      final syncedProject = makeTestProject(id: projectId).copyWith(
        data: makeTestProject(id: projectId).data.copyWith(
          title: 'Synced title',
          status: syncedStatus,
        ),
      );
      when(
        () => mockRepo.getProjectById(projectId),
      ).thenAnswer((_) async => syncedProject);
      final syncedTask = makeTestTask(id: 'rebased-sync-task');
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [syncedTask]);
      final reloadObserved = Completer<void>();
      final subscription = container.listen(
        projectDetailControllerProvider(projectId),
        (_, next) {
          if (next.linkedTasks.any((task) => task.id == syncedTask.id) &&
              !reloadObserved.isCompleted) {
            reloadObserved.complete();
          }
        },
      );

      updateStreamController.add({projectId});
      await reloadObserved.future;
      subscription.close();

      final rebased = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(rebased.project!.data.title, 'Synced title');
      expect(rebased.project!.data.status, syncedStatus);
      expect(rebased.project!.data.targetDate, localTargetDate);
      expect(rebased.hasChanges, isTrue);

      await notifier.saveChanges();

      expect(persisted!.data.title, 'Synced title');
      expect(persisted!.data.status, syncedStatus);
      expect(persisted!.data.targetDate, localTargetDate);

      final locallyEditedStatus = ProjectStatus.active(
        id: 'locally-edited-status',
        createdAt: DateTime(2026, 8, 17),
        utcOffset: 0,
      );
      notifier
        ..updateTitle('Locally edited title')
        ..updateDescription('Locally edited description')
        ..updateCategoryId('local-category')
        ..updateStatus(locallyEditedStatus);
      final secondSyncedAt = DateTime(2026, 8, 18);
      final syncedGeolocation = Geolocation(
        createdAt: secondSyncedAt,
        latitude: 59.3293,
        longitude: 18.0686,
        geohashString: 'u6sce',
      );
      final secondSyncedProject = persisted!.copyWith(
        meta: persisted!.meta.copyWith(updatedAt: secondSyncedAt),
        entryText: EntryText(
          plainText: 'Body received from sync',
          markdown: '**Synced body**',
          quill: '[{"insert":"Synced body"}]',
          geolocation: syncedGeolocation,
        ),
      );
      final secondSyncedTask = makeTestTask(id: 'second-rebased-sync-task');
      when(
        () => mockRepo.getProjectById(projectId),
      ).thenAnswer((_) async => secondSyncedProject);
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [secondSyncedTask]);
      final secondReloadObserved = Completer<void>();
      final secondSubscription = container.listen(
        projectDetailControllerProvider(projectId),
        (_, next) {
          if (next.linkedTasks.any(
                (task) => task.id == secondSyncedTask.id,
              ) &&
              !secondReloadObserved.isCompleted) {
            secondReloadObserved.complete();
          }
        },
      );

      updateStreamController.add({projectId});
      await secondReloadObserved.future;
      secondSubscription.close();

      final fullyRebased = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(fullyRebased.project!.data.title, 'Locally edited title');
      expect(fullyRebased.project!.meta.categoryId, 'local-category');
      expect(fullyRebased.project!.data.status, locallyEditedStatus);
      expect(fullyRebased.project!.data.targetDate, localTargetDate);
      expect(fullyRebased.project!.meta.updatedAt, secondSyncedAt);
      expect(
        fullyRebased.project!.entryText?.plainText,
        'Locally edited description',
      );
      expect(fullyRebased.project!.entryText?.markdown, '**Synced body**');
      expect(
        fullyRebased.project!.entryText?.quill,
        '[{"insert":"Synced body"}]',
      );
      expect(
        fullyRebased.project!.entryText?.geolocation,
        syncedGeolocation,
      );

      await notifier.saveChanges();
      expect(persisted!.entryText?.plainText, 'Locally edited description');
      expect(persisted!.entryText?.markdown, '**Synced body**');
      expect(persisted!.entryText?.quill, '[{"insert":"Synced body"}]');
      expect(persisted!.entryText?.geolocation, syncedGeolocation);
    });

    test('clears pending edits when a synced deletion is observed', () async {
      final container = await createLoadedContainer();
      final notifier = container.read(
        projectDetailControllerProvider(projectId).notifier,
      )..updateTitle('Unsaved title');
      when(
        () => mockRepo.getProjectById(projectId),
      ).thenAnswer((_) async => null);
      final deletionObserved = Completer<void>();
      final subscription = container.listen(
        projectDetailControllerProvider(projectId),
        (_, next) {
          if (next.project == null && !deletionObserved.isCompleted) {
            deletionObserved.complete();
          }
        },
      );

      updateStreamController.add({projectId});
      await deletionObserved.future;
      subscription.close();

      final deleted = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(deleted.project, isNull);
      expect(deleted.hasChanges, isFalse);

      await notifier.saveChanges();
      verifyNever(() => mockRepo.updateProject(any()));
    });

    test('applies a synced deletion even when task loading fails', () async {
      final container = await createLoadedContainer();
      final subscription = container.listen(
        projectDetailControllerProvider(projectId),
        (_, _) {},
      );
      final notifier = container.read(
        projectDetailControllerProvider(projectId).notifier,
      )..updateTitle('Unsaved title');
      clearInteractions(mockRepo);
      when(
        () => mockRepo.getProjectById(projectId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => throw StateError('task rollup failed'));

      updateStreamController.add({projectId});
      await pumpEventQueue();
      await pumpEventQueue();

      final deleted = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(deleted.project, isNull);
      expect(deleted.hasChanges, isFalse);

      await notifier.saveChanges();
      verifyNever(() => mockRepo.updateProject(any()));
      subscription.close();
    });

    test('ignores an older reload that completes after a deletion', () async {
      final container = await createLoadedContainer();
      final staleTasks = Completer<List<Task>>();
      final firstReloadStarted = Completer<void>();
      var projectReloadCount = 0;
      var taskReloadCount = 0;
      final staleProject = makeTestProject(
        id: projectId,
        title: 'Stale project',
      );
      final staleTask = makeTestTask(id: 'stale-task');
      when(
        () => mockRepo.getProjectById(projectId),
      ).thenAnswer((_) async {
        projectReloadCount++;
        return projectReloadCount == 1 ? staleProject : null;
      });
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) {
        taskReloadCount++;
        if (taskReloadCount == 1) {
          firstReloadStarted.complete();
          return staleTasks.future;
        }
        return Future.value([]);
      });

      updateStreamController.add({projectId});
      await firstReloadStarted.future;

      final deletionObserved = Completer<void>();
      final subscription = container.listen(
        projectDetailControllerProvider(projectId),
        (_, next) {
          if (next.project == null && !deletionObserved.isCompleted) {
            deletionObserved.complete();
          }
        },
      );
      updateStreamController.add({projectId});
      await deletionObserved.future;

      staleTasks.complete([staleTask]);
      await pumpEventQueue();
      await pumpEventQueue();
      subscription.close();

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.project, isNull);
      expect(state.linkedTasks, isEmpty);
      expect(state.hasChanges, isFalse);
    });

    test('saveChanges sets updateFailed on exception', () async {
      when(
        () => mockRepo.updateProject(any()),
      ).thenThrow(Exception('db error'));

      final container = await createLoadedContainer();
      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateTitle('Changed');
      await container
          .read(projectDetailControllerProvider(projectId).notifier)
          .saveChanges();

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.error, ProjectDetailError.updateFailed);
      expect(state.isSaving, isFalse);
    });

    test('reload failure sets loadFailed error', () async {
      final container = await createLoadedContainer();

      when(
        () => mockRepo.getProjectById(projectId),
      ).thenThrow(Exception('network error'));
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenThrow(Exception('network error'));

      // Trigger reload via stream and wait for it to process.
      final errorCompleter = Completer<void>();
      final sub = container.listen(
        projectDetailControllerProvider(projectId),
        (_, next) {
          if (next.error != null && !errorCompleter.isCompleted) {
            errorCompleter.complete();
          }
        },
      );

      updateStreamController.add({projectId});
      await errorCompleter.future.timeout(const Duration(milliseconds: 200));
      sub.close();

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.error, ProjectDetailError.loadFailed);
    });

    test('stream notification triggers reload', () async {
      final container = await createLoadedContainer();

      // Update mock to return a project with different title
      final updatedProject = makeTestProject(
        id: projectId,
        title: 'Updated via stream',
      );
      when(
        () => mockRepo.getProjectById(projectId),
      ).thenAnswer((_) async => updatedProject);

      // Emit update notification and wait for it to process.
      final reloadCompleter = Completer<void>();
      final sub = container.listen(
        projectDetailControllerProvider(projectId),
        (_, next) {
          if (next.project?.data.title == 'Updated via stream' &&
              !reloadCompleter.isCompleted) {
            reloadCompleter.complete();
          }
        },
      );

      updateStreamController.add({projectId});
      await reloadCompleter.future.timeout(const Duration(milliseconds: 200));
      sub.close();

      final state = container.read(
        projectDetailControllerProvider(projectId),
      );
      expect(state.project!.data.title, 'Updated via stream');
    });

    test('updateCategoryId marks hasChanges true', () async {
      final container = await createLoadedContainer();
      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateCategoryId('new-category-id');
      final state = container.read(projectDetailControllerProvider(projectId));
      expect(state.hasChanges, isTrue);
      expect(state.project!.meta.categoryId, 'new-category-id');
    });

    test('no changes when setting same categoryId', () async {
      // The default test project has null categoryId
      final container = await createLoadedContainer();
      container
          .read(projectDetailControllerProvider(projectId).notifier)
          .updateCategoryId(null);
      final state = container.read(projectDetailControllerProvider(projectId));
      expect(state.hasChanges, isFalse);
    });

    test(
      'updateCategoryId and updateStatus are no-ops before a project loads',
      () async {
        // Project lookup returns null → the controller never has a pending
        // project, so both mutators must early-return without state changes.
        when(
          () => mockRepo.getProjectById(projectId),
        ).thenAnswer((_) async => null);
        final container = ProviderContainer(
          overrides: [projectRepositoryProvider.overrideWithValue(mockRepo)],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          projectDetailControllerProvider(projectId),
          (_, _) {},
        );
        addTearDown(sub.close);
        await pumpEventQueue();

        final notifier =
            container.read(
                projectDetailControllerProvider(projectId).notifier,
              )
              ..updateCategoryId('new-category-id')
              ..updateStatus(
                ProjectStatus.active(
                  id: 'status-new',
                  createdAt: DateTime(2026, 3, 15),
                  utcOffset: 0,
                ),
              );

        final state = container.read(
          projectDetailControllerProvider(projectId),
        );
        expect(state.project, isNull);
        expect(state.hasChanges, isFalse);
        expect(notifier, isNotNull);
      },
    );
  });
}
