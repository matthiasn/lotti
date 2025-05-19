import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:siri_wave/siri_wave.dart';

import '../../../../test_helper.dart';

// Create a simple provider we can use to override the real provider
final testBoolProvider =
    Provider.family<bool, ({String id, Set<String> responseTypes})>(
  (_, __) => false,
);

void main() {
  group('AiRunningAnimation', () {
    testWidgets('should render SiriWaveform with correct height',
        (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: AiRunningAnimation(height: 100),
        ),
      );

      // Verify the SiriWaveform widget is rendered
      expect(find.byType(SiriWaveform), findsOneWidget);

      // Verify it uses the correct controller type
      final waveformWidget =
          tester.widget<SiriWaveform>(find.byType(SiriWaveform));
      expect(waveformWidget.controller, isA<IOS9SiriWaveformController>());

      // Verify the height is set correctly
      final options = waveformWidget.options as IOS9SiriWaveformOptions;
      expect(options.height, 100);
    });
  });

  group('AiRunningAnimationWrapper', () {
    const testId = 'test-id';
    const testType = AiResponseType.taskSummary;
    final testSet = {testType};

    testWidgets('should render nothing when isRunning is false',
        (tester) async {
      // The default state for inference is idle, so we don't need any overrides
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: AiRunningAnimationWrapper(
              entryId: testId,
              height: 100,
              responseTypes: testSet,
            ),
          ),
        ),
      );

      // Should render nothing (SizedBox.shrink)
      expect(find.byType(AiRunningAnimation), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('should render animation when isRunning is true',
        (tester) async {
      // Create a provider container to manage state
      final container = ProviderContainer();

      // Set the inference status to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WidgetTestBench(
            child: AiRunningAnimationWrapper(
              entryId: testId,
              height: 100,
              responseTypes: testSet,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Should render the animation
      expect(find.byType(AiRunningAnimation), findsOneWidget);

      container.dispose();
    });
  });

  group('AiRunningAnimationWrapperCard', () {
    const testId = 'test-id';
    const testType = AiResponseType.taskSummary;
    final testSet = {testType};

    testWidgets('should render nothing when isRunning is false',
        (tester) async {
      // The default state for inference is idle, so we don't need any overrides
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: AiRunningAnimationWrapperCard(
              entryId: testId,
              height: 100,
              responseTypes: testSet,
            ),
          ),
        ),
      );

      // Should render nothing
      expect(find.byType(AiRunningAnimation), findsNothing);
      expect(find.byType(GlassContainer), findsNothing);
    });

    testWidgets(
        'should render glass container with animation when isRunning is true',
        (tester) async {
      // Create a provider container to manage state
      final container = ProviderContainer();

      // Set the inference status to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testType,
            ).notifier,
          )
          .setStatus(InferenceStatus.running);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: WidgetTestBench(
            child: AiRunningAnimationWrapperCard(
              entryId: testId,
              height: 100,
              responseTypes: testSet,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Should render the glass container with animation
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);

      container.dispose();
    });
  });
}
