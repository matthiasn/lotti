import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:siri_wave/siri_wave.dart';

import '../../../../test_helper.dart';

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

    testWidgets('should wrap with GestureDetector when isInteractive is true',
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
              isInteractive: true,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Should render the animation wrapped in GestureDetector
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);

      container.dispose();
    });

    testWidgets(
        'should not wrap with GestureDetector when isInteractive is false',
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

      // Should render the animation without GestureDetector
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);

      container.dispose();
    });

    testWidgets('should handle tap when interactive with active inference',
        (tester) async {
      // This test verifies the _handleTap method executes without error
      // Full modal display testing would require more complex setup

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
              isInteractive: true,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Find and tap the GestureDetector
      final gesture = find.byType(GestureDetector);
      expect(gesture, findsOneWidget);

      // Tapping should trigger _handleTap method
      // The method will look for active inference and potentially show modal
      await tester.tap(gesture);
      await tester.pump();

      // Verify the tap was handled without errors
      expect(find.byType(AiRunningAnimation), findsOneWidget);

      container.dispose();
    });

    testWidgets('should handle multiple response types', (tester) async {
      // Test with multiple response types in the set
      final multipleTypes = {
        AiResponseType.taskSummary,
        AiResponseType.audioTranscription,
        AiResponseType.imageAnalysis,
      };

      // Create a provider container to manage state
      final container = ProviderContainer();

      // Set one of the inference statuses to running
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: AiResponseType.audioTranscription,
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
              responseTypes: multipleTypes,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Should render the animation when any type is running
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

    testWidgets('should render with isInteractive parameter', (tester) async {
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
              isInteractive: true,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Should render the glass container with animation
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);

      // The AiRunningAnimationWrapper inside should be interactive
      final wrapper = tester.widget<AiRunningAnimationWrapper>(
        find.byType(AiRunningAnimationWrapper),
      );
      expect(wrapper.isInteractive, isTrue);

      container.dispose();
    });

    testWidgets('should handle multiple response types in card',
        (tester) async {
      // Test with multiple response types
      final multipleTypes = {
        AiResponseType.taskSummary,
        AiResponseType.audioTranscription,
      };

      // Create a provider container to manage state
      final container = ProviderContainer();

      // Set the inference status to running for one type
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: AiResponseType.taskSummary,
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
              responseTypes: multipleTypes,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Should render when any type is running
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GlassContainer), findsOneWidget);

      container.dispose();
    });

    testWidgets('should properly set height for glass container',
        (tester) async {
      // Create a provider container to manage state
      final container = ProviderContainer();
      const testHeight = 150.0;

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
              height: testHeight,
              responseTypes: testSet,
            ),
          ),
        ),
      );

      // Allow widget to build
      await tester.pump();

      // Verify the height is passed correctly
      final glassContainer = tester.widget<GlassContainer>(
        find.byType(GlassContainer),
      );
      expect(glassContainer.height, testHeight);

      container.dispose();
    });
  });
}
