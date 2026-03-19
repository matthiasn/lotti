import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockProjectRepository mockRepo;
  late StreamController<Set<String>> updateStreamController;

  final projectId = uuid.v1();

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockRepo = MockProjectRepository();
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
  });

  tearDown(() async {
    await updateStreamController.close();
  });

  /// Creates a container and waits for the controller to finish loading.
  Future<ProviderContainer> createLoadedContainer() async {
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
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
      expect(state.hasChanges, isTrue);
      expect(state.project!.data.title, 'New Title');
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
        when(() => mockRepo.updateProject(any())).thenAnswer((_) async => true);

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
  });
}
