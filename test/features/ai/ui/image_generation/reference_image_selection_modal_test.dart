import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_modal.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/get_it.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import 'test_utils.dart';

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
}
