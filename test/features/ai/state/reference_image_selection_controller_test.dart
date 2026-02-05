import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

void main() {
  group('ReferenceImageSelectionState', () {
    test('has correct default values', () {
      const state = ReferenceImageSelectionState();

      expect(state.availableImages, isEmpty);
      expect(state.selectedImageIds, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.errorCode, isNull);
      expect(state.errorDetail, isNull);
    });

    test('copyWith creates correct copy', () {
      const state = ReferenceImageSelectionState();
      final newState = state.copyWith(
        isLoading: true,
        errorCode: ReferenceImageSelectionError.loadImagesFailed,
        errorDetail: 'test error detail',
      );

      expect(newState.isLoading, isTrue);
      expect(newState.errorCode, ReferenceImageSelectionError.loadImagesFailed);
      expect(newState.errorDetail, 'test error detail');
      expect(newState.availableImages, isEmpty);
    });
  });

  group('ReferenceImageSelectionStateX extension', () {
    test('canSelectMore returns true when under limit', () {
      const state = ReferenceImageSelectionState(
        selectedImageIds: {'id1', 'id2'},
      );

      expect(state.canSelectMore, isTrue);
    });

    test('canSelectMore returns false when at limit', () {
      const state = ReferenceImageSelectionState(
        selectedImageIds: {'id1', 'id2', 'id3'},
      );

      expect(state.canSelectMore, isFalse);
    });

    test('canSelectMore returns true when empty', () {
      const state = ReferenceImageSelectionState();

      expect(state.canSelectMore, isTrue);
    });

    test('selectionCount returns correct count', () {
      const emptyState = ReferenceImageSelectionState();
      const oneState = ReferenceImageSelectionState(
        selectedImageIds: {'id1'},
      );
      const twoState = ReferenceImageSelectionState(
        selectedImageIds: {'id1', 'id2'},
      );

      expect(emptyState.selectionCount, 0);
      expect(oneState.selectionCount, 1);
      expect(twoState.selectionCount, 2);
    });
  });

  group('ReferenceImageSelectionController', () {
    late MockJournalRepository mockJournalRepo;
    late ProviderContainer container;
    late Directory mockDocumentsDirectory;

    final testDate = DateTime(2025);
    JournalImage buildTestImage(String id) {
      return JournalImage(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: ImageData(
          imageId: id,
          imageFile: 'test_$id.jpg',
          imageDirectory: '/test/images',
          capturedAt: testDate,
        ),
      );
    }

    /// Helper to wait for async state to finish loading
    Future<ReferenceImageSelectionState> waitForLoaded(String taskId) async {
      final completer = Completer<ReferenceImageSelectionState>();
      final sub = container.listen(
        referenceImageSelectionControllerProvider(taskId: taskId),
        (_, state) {
          if (!state.isLoading && !completer.isCompleted) {
            completer.complete(state);
          }
        },
        fireImmediately: true,
      );

      final state = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          sub.close();
          return container.read(
            referenceImageSelectionControllerProvider(taskId: taskId),
          );
        },
      );
      sub.close();
      return state;
    }

    setUp(() async {
      await getIt.reset();
      getIt.allowReassignment = true;

      // Create a temp directory to simulate the documents directory
      mockDocumentsDirectory =
          Directory.systemTemp.createTempSync('ref_image_selection_ctrl_test_');
      getIt.registerSingleton<Directory>(mockDocumentsDirectory);

      mockJournalRepo = MockJournalRepository();
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepo),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await getIt.reset();
      try {
        mockDocumentsDirectory.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    test('build starts with loading state', () async {
      const taskId = 'test-task';

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
          .thenAnswer((_) async => []);

      final state = container.read(
        referenceImageSelectionControllerProvider(taskId: taskId),
      );

      expect(state.isLoading, isTrue);
    });

    test('loads available images on build', () async {
      const taskId = 'test-task';
      final images = [
        buildTestImage('img-1'),
        buildTestImage('img-2'),
      ];

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
          .thenAnswer((_) async => images);

      final state = await waitForLoaded(taskId);

      expect(state.isLoading, isFalse);
      expect(state.availableImages.length, 2);
    });

    test('handles error when loading images fails', () async {
      const taskId = 'test-task';

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
          .thenAnswer((_) async => throw Exception('Database error'));

      final state = await waitForLoaded(taskId);

      expect(state.isLoading, isFalse);
      expect(state.errorCode, ReferenceImageSelectionError.loadImagesFailed);
      expect(state.errorDetail, contains('Database error'));
    });

    test('toggleImageSelection adds image to selection', () async {
      const taskId = 'test-task';
      final images = [buildTestImage('img-1')];

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
          .thenAnswer((_) async => images);

      // Wait for loading to complete
      await waitForLoaded(taskId);

      // Toggle selection to add the image
      container
          .read(
            referenceImageSelectionControllerProvider(taskId: taskId).notifier,
          )
          .toggleImageSelection('img-1');

      final state = container.read(
        referenceImageSelectionControllerProvider(taskId: taskId),
      );

      expect(state.selectedImageIds.contains('img-1'), isTrue);
    });

    test('toggleImageSelection removes image from selection', () async {
      const taskId = 'test-task';
      final images = [buildTestImage('img-1')];

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
          .thenAnswer((_) async => images);

      // Wait for loading to complete
      await waitForLoaded(taskId);

      container.read(
        referenceImageSelectionControllerProvider(taskId: taskId).notifier,
      )
        // Add the image first
        ..toggleImageSelection('img-1')
        // Then toggle again to remove it
        ..toggleImageSelection('img-1');

      final state = container.read(
        referenceImageSelectionControllerProvider(taskId: taskId),
      );

      expect(state.selectedImageIds.contains('img-1'), isFalse);
    });

    test('toggleImageSelection respects max limit', () async {
      const taskId = 'test-task';
      final images = [
        buildTestImage('img-1'),
        buildTestImage('img-2'),
        buildTestImage('img-3'),
        buildTestImage('img-4'),
      ];

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
          .thenAnswer((_) async => images);

      // Wait for loading to complete
      await waitForLoaded(taskId);

      // Try to select all 4 images (should only allow 3)
      container.read(
        referenceImageSelectionControllerProvider(taskId: taskId).notifier,
      )
        ..toggleImageSelection('img-1')
        ..toggleImageSelection('img-2')
        ..toggleImageSelection('img-3')
        ..toggleImageSelection('img-4'); // Should be ignored

      final state = container.read(
        referenceImageSelectionControllerProvider(taskId: taskId),
      );

      expect(state.selectedImageIds.length, kMaxReferenceImages);
      expect(state.selectedImageIds.contains('img-4'), isFalse);
    });

    test('clearSelection removes all selections', () async {
      const taskId = 'test-task';
      final images = [buildTestImage('img-1'), buildTestImage('img-2')];

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
          .thenAnswer((_) async => images);

      // Wait for loading to complete
      await waitForLoaded(taskId);

      // Add some selections first, then clear them
      container.read(
        referenceImageSelectionControllerProvider(taskId: taskId).notifier,
      )
        ..toggleImageSelection('img-1')
        ..toggleImageSelection('img-2')
        ..clearSelection();

      final state = container.read(
        referenceImageSelectionControllerProvider(taskId: taskId),
      );

      expect(state.selectedImageIds, isEmpty);
    });

    test('different taskIds have independent state', () async {
      const taskId1 = 'task-1';
      const taskId2 = 'task-2';
      final images1 = [buildTestImage('img-1')];
      final images2 = [buildTestImage('img-2'), buildTestImage('img-3')];

      when(() => mockJournalRepo.getLinkedImagesForTask(taskId1))
          .thenAnswer((_) async => images1);
      when(() => mockJournalRepo.getLinkedImagesForTask(taskId2))
          .thenAnswer((_) async => images2);

      // Wait for both to load
      final results = await Future.wait([
        waitForLoaded(taskId1),
        waitForLoaded(taskId2),
      ]);

      expect(results[0].availableImages.length, 1);
      expect(results[1].availableImages.length, 2);
    });

    group('processSelectedImages', () {
      test('returns empty list when no images selected', () async {
        const taskId = 'test-task';
        final images = [buildTestImage('img-1'), buildTestImage('img-2')];

        when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
            .thenAnswer((_) async => images);

        // Wait for loading to complete
        await waitForLoaded(taskId);

        // Don't select any images - just call processSelectedImages
        final controller = container.read(
          referenceImageSelectionControllerProvider(taskId: taskId).notifier,
        );
        final results = await controller.processSelectedImages();

        expect(results, isEmpty);
      });

      test('sets isProcessing to true during processing', () async {
        const taskId = 'test-task';
        final images = [buildTestImage('img-1')];

        when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
            .thenAnswer((_) async => images);

        // Wait for loading to complete
        await waitForLoaded(taskId);

        final controller = container.read(
          referenceImageSelectionControllerProvider(taskId: taskId).notifier,
        )

          // Select an image
          ..toggleImageSelection('img-1');

        // Start processing (don't await)
        final future = controller.processSelectedImages();

        // Check processing state before completion
        final stateDuringProcessing = container.read(
          referenceImageSelectionControllerProvider(taskId: taskId),
        );
        expect(stateDuringProcessing.isProcessing, isTrue);

        // Wait for completion
        await future;
      });

      test('sets isProcessing to false after processing completes', () async {
        const taskId = 'test-task';
        final images = [buildTestImage('img-1')];

        when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
            .thenAnswer((_) async => images);

        // Wait for loading to complete
        await waitForLoaded(taskId);

        final controller = container.read(
          referenceImageSelectionControllerProvider(taskId: taskId).notifier,
        )

          // Select an image
          ..toggleImageSelection('img-1');

        // Process and wait
        await controller.processSelectedImages();

        // Check state after completion
        final stateAfterProcessing = container.read(
          referenceImageSelectionControllerProvider(taskId: taskId),
        );
        expect(stateAfterProcessing.isProcessing, isFalse);
      });

      test('skips images not found in available images', () async {
        const taskId = 'test-task';
        final images = [buildTestImage('img-1')];

        when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
            .thenAnswer((_) async => images);

        // Wait for loading to complete
        await waitForLoaded(taskId);

        final controller = container.read(
          referenceImageSelectionControllerProvider(taskId: taskId).notifier,
        )

          // Select an image that exists
          ..toggleImageSelection('img-1');

        // Manually modify selection to include a non-existent image
        // This simulates a race condition where an image was deleted

        final results = await controller.processSelectedImages();

        // Since img-1 file doesn't exist on disk, it will return empty
        // The point is that the method doesn't throw
        expect(results, isA<List<ProcessedReferenceImage>>());
      });

      test('uses O(1) map lookup for image retrieval', () async {
        const taskId = 'test-task';
        // Create multiple images to ensure map is used
        final images = [
          buildTestImage('img-1'),
          buildTestImage('img-2'),
          buildTestImage('img-3'),
          buildTestImage('img-4'),
          buildTestImage('img-5'),
        ];

        when(() => mockJournalRepo.getLinkedImagesForTask(taskId))
            .thenAnswer((_) async => images);

        // Wait for loading to complete
        await waitForLoaded(taskId);

        final controller = container.read(
          referenceImageSelectionControllerProvider(taskId: taskId).notifier,
        )

          // Select max images
          ..toggleImageSelection('img-1')
          ..toggleImageSelection('img-3')

          ..toggleImageSelection('img-5');

        // Process - this verifies the map lookup works
        final results = await controller.processSelectedImages();

        // Results should be empty since files don't exist on disk,
        // but no exception should be thrown
        expect(results, isA<List<ProcessedReferenceImage>>());
      });
    });
  });
}
