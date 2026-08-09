import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_modal.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_widget.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import 'test_utils.dart';

class _PopCountingObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

void main() {
  const taskId = 'task-with-images';

  setUp(() async {
    await setUpTestGetIt();
    getIt.registerSingleton<Directory>(Directory.systemTemp);
  });
  tearDown(tearDownTestGetIt);

  testWidgets('returns selected images from the shared selector flow', (
    tester,
  ) async {
    const processedImages = [
      ProcessedReferenceImage(
        base64Data: 'selected-image',
        mimeType: 'image/jpeg',
      ),
    ];
    final state = ReferenceImageSelectionState(
      availableImages: [buildTestReferenceImage('image-1')],
      selectedImageIds: const {'image-1'},
    );
    List<ProcessedReferenceImage>? result;

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          referenceImageSelectionControllerProvider(taskId).overrideWith(
            () => FakeReferenceImageSelectionController(
              state,
              processedImages: processedImages,
            ),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ReferenceImageSelectionModal.show(
                context: context,
                taskId: taskId,
                maxImages: kMaxCodingPromptImages,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('0/$kMaxCodingPromptImages'), findsNothing);
    expect(find.text('1/$kMaxCodingPromptImages'), findsOneWidget);

    await tester.ensureVisible(find.text('Continue (1)'));
    await tester.pump();
    await tester.tap(find.text('Continue (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, processedImages);
  });

  testWidgets('returns an empty selection when the task has no images', (
    tester,
  ) async {
    List<ProcessedReferenceImage>? result;

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          referenceImageSelectionControllerProvider(taskId).overrideWith(
            () => FakeReferenceImageSelectionController(
              const ReferenceImageSelectionState(),
            ),
          ),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ReferenceImageSelectionModal.show(
                context: context,
                taskId: taskId,
                maxImages: kMaxCodingPromptImages,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isEmpty);
    expect(find.byType(ReferenceImageSelectionWidget), findsNothing);
  });

  testWidgets('ignores image processing that finishes after dismissal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final processing = Completer<List<ProcessedReferenceImage>>();
    final state = ReferenceImageSelectionState(
      availableImages: [buildTestReferenceImage('image-1')],
      selectedImageIds: const {'image-1'},
    );
    late FakeReferenceImageSelectionController controller;
    final observer = _PopCountingObserver();
    List<ProcessedReferenceImage>? result;

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () async {
                          result = await ReferenceImageSelectionModal.show(
                            context: context,
                            taskId: taskId,
                            maxImages: kMaxCodingPromptImages,
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Push host'),
            ),
          ),
        ),
        navigatorObservers: [observer],
        overrides: [
          referenceImageSelectionControllerProvider(taskId).overrideWith(
            () => controller = FakeReferenceImageSelectionController(
              state,
              processedImagesFuture: processing.future,
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Push host'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue (1)'));
    await tester.tap(find.text('Continue (1)'));
    await tester.pump();
    expect(controller.processSelectedImagesCallCount, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(observer.popCount, 1);

    processing.complete(const [
      ProcessedReferenceImage(
        base64Data: 'late-image',
        mimeType: 'image/jpeg',
      ),
    ]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(result, isNull);
    expect(observer.popCount, 1);
    expect(find.text('Open'), findsOneWidget);
  });
}
