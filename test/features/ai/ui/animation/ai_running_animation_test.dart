import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:siri_wave/siri_wave.dart';

import '../../../../test_helper.dart';

void main() {
  group('AiRunningAnimation', () {
    testWidgets('should render SiriWaveform with correct height', (
      tester,
    ) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: AiRunningAnimation(height: 100),
        ),
      );

      // Verify the SiriWaveform widget is rendered
      expect(find.byType(SiriWaveform), findsOneWidget);

      // Verify it uses the correct controller type
      final waveformWidget = tester.widget<SiriWaveform>(
        find.byType(SiriWaveform),
      );
      expect(waveformWidget.controller, isA<IOS9SiriWaveformController>());

      // Verify the height is set correctly
      final options = waveformWidget.options as IOS9SiriWaveformOptions;
      expect(options.height, 100);
    });
  });

  group('AiRunningAnimationWrapper', () {
    const testId = 'test-id';
    // ignore: deprecated_member_use_from_same_package
    const testType = AiResponseType.taskSummary;
    final testSet = {testType};

    testWidgets('should render nothing when isRunning is false', (
      tester,
    ) async {
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

    testWidgets('should render animation when isRunning is true', (
      tester,
    ) async {
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

    testWidgets('should wrap with GestureDetector when isInteractive is true', (
      tester,
    ) async {
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
      },
    );

    testWidgets('should handle tap when interactive with active inference', (
      tester,
    ) async {
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
        // ignore: deprecated_member_use_from_same_package
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
    // ignore: deprecated_member_use_from_same_package
    const testType = AiResponseType.taskSummary;
    final testSet = {testType};

    testWidgets('should render nothing when isRunning is false', (
      tester,
    ) async {
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
      },
    );

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

    testWidgets('should handle multiple response types in card', (
      tester,
    ) async {
      // Test with multiple response types
      final multipleTypes = {
        // ignore: deprecated_member_use_from_same_package
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
              // ignore: deprecated_member_use_from_same_package
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

    testWidgets('should properly set height for glass container', (
      tester,
    ) async {
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

  group('AiRunningDecoderBars', () {
    const testId = 'test-id';
    const testPromptId = 'test-prompt-id';
    // ignore: deprecated_member_use_from_same_package
    const testType = AiResponseType.taskSummary;
    final testSet = {testType};

    void setInferenceStatus(
      ProviderContainer container,
      InferenceStatus status,
    ) {
      container
          .read(
            inferenceStatusControllerProvider(
              id: testId,
              aiResponseType: testType,
            ).notifier,
          )
          .setStatus(status);
    }

    testWidgets('renders nothing when no matching inference is running', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: AiRunningDecoderBars(
              entryId: testId,
              responseTypes: testSet,
            ),
          ),
        ),
      );

      expect(find.byKey(AiRunningDecoderBars.indicatorKey), findsNothing);
      expect(find.byType(AiThinkingLineShader), findsNothing);
    });

    testWidgets('renders decoder-bars shader when inference is running', (
      tester,
    ) async {
      final container = ProviderContainer();
      try {
        setInferenceStatus(container, InferenceStatus.running);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: WidgetTestBench(
              child: AiRunningDecoderBars(
                entryId: testId,
                responseTypes: testSet,
              ),
            ),
          ),
        );
        await tester.pump(AiRunningDecoderBars.transitionDuration);

        expect(find.byKey(AiRunningDecoderBars.indicatorKey), findsOneWidget);
        expect(find.byType(AiThinkingLineShader), findsOneWidget);
        final shader = tester.widget<AiThinkingLineShader>(
          find.byType(AiThinkingLineShader),
        );
        expect(shader.route, AiThinkingShaderRoute.decoderBars);
        expect(shader.speed, AiRunningDecoderBars.defaultSpeed);
        expect(shader.height, AiRunningDecoderBars.defaultHeight);
        expect(shader.amplitude, AiRunningDecoderBars.defaultAmplitude);
        expect(shader.randomness, AiRunningDecoderBars.defaultRandomness);
        expect(shader.pulse, AiRunningDecoderBars.defaultPulse);
        expect(shader.opacity, 1);
      } finally {
        container.dispose();
      }
    });

    testWidgets('wraps decoder bars in a tap target when interactive', (
      tester,
    ) async {
      final container = ProviderContainer();
      try {
        setInferenceStatus(container, InferenceStatus.running);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: WidgetTestBench(
              child: AiRunningDecoderBars(
                entryId: testId,
                responseTypes: testSet,
                isInteractive: true,
              ),
            ),
          ),
        );
        await tester.pump(AiRunningDecoderBars.transitionDuration);

        expect(find.byType(GestureDetector), findsOneWidget);
        expect(find.byType(AiThinkingLineShader), findsOneWidget);
      } finally {
        container.dispose();
      }
    });

    testWidgets(
      'animates reserved height and shader amplitude before removing shader',
      (tester) async {
        final container = ProviderContainer();
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: WidgetTestBench(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AiRunningDecoderBars(
                    entryId: testId,
                    responseTypes: testSet,
                  ),
                ),
              ),
            ),
          );

          expect(find.byKey(AiRunningDecoderBars.indicatorKey), findsNothing);
          expect(find.byType(AiThinkingLineShader), findsNothing);

          setInferenceStatus(container, InferenceStatus.running);
          await tester.pump();
          await tester.pump(
            Duration(
              milliseconds:
                  AiRunningDecoderBars.transitionDuration.inMilliseconds ~/ 2,
            ),
          );

          final enteringSize = tester.getSize(
            find.byKey(AiRunningDecoderBars.indicatorKey),
          );
          final enteringShader = tester.widget<AiThinkingLineShader>(
            find.byType(AiThinkingLineShader),
          );
          expect(enteringSize.height, greaterThan(0));
          expect(
            enteringShader.height,
            lessThan(AiRunningDecoderBars.defaultHeight),
          );
          expect(
            enteringShader.amplitude,
            lessThan(AiRunningDecoderBars.defaultAmplitude),
          );
          expect(enteringShader.opacity, lessThan(1));

          await tester.pump(AiRunningDecoderBars.transitionDuration);
          final visibleSize = tester.getSize(
            find.byKey(AiRunningDecoderBars.indicatorKey),
          );
          final visibleShader = tester.widget<AiThinkingLineShader>(
            find.byType(AiThinkingLineShader),
          );
          expect(visibleSize.height, greaterThan(enteringSize.height));
          expect(visibleShader.height, AiRunningDecoderBars.defaultHeight);
          expect(
            visibleShader.amplitude,
            AiRunningDecoderBars.defaultAmplitude,
          );
          expect(visibleShader.opacity, 1);

          setInferenceStatus(container, InferenceStatus.idle);
          await tester.pump();
          await tester.pump(
            Duration(
              milliseconds:
                  AiRunningDecoderBars.transitionDuration.inMilliseconds ~/ 2,
            ),
          );

          final exitingSize = tester.getSize(
            find.byKey(AiRunningDecoderBars.indicatorKey),
          );
          final exitingShader = tester.widget<AiThinkingLineShader>(
            find.byType(AiThinkingLineShader),
          );
          expect(exitingSize.height, lessThan(visibleSize.height));
          expect(
            exitingShader.amplitude,
            lessThan(AiRunningDecoderBars.defaultAmplitude),
          );
          expect(exitingShader.opacity, lessThan(1));

          await tester.pump(AiRunningDecoderBars.transitionDuration);

          expect(find.byKey(AiRunningDecoderBars.indicatorKey), findsNothing);
          expect(find.byType(AiThinkingLineShader), findsNothing);
        } finally {
          container.dispose();
        }
      },
    );

    test('resolves shader width from constraints before media size', () {
      expect(
        AiRunningDecoderBars.resolveShaderWidth(
          const BoxConstraints.tightFor(width: 320),
          const Size(800, 600),
        ),
        320,
      );
      expect(
        AiRunningDecoderBars.resolveShaderWidth(
          const BoxConstraints(),
          const Size(800, 600),
        ),
        800,
      );
    });

    testWidgets('opens existing progress modal when tapped', (tester) async {
      final prompt = AiConfigPrompt(
        id: testPromptId,
        name: 'Decoder prompt',
        systemMessage: 'Summarize the task.',
        userMessage: 'Use the active task.',
        defaultModelId: 'model-id',
        modelIds: const ['model-id'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: testType,
      );
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider(
            testPromptId,
          ).overrideWith((ref) async => prompt),
        ],
      );

      try {
        container
            .read(
              activeInferenceControllerProvider(
                entityId: testId,
                aiResponseType: testType,
              ).notifier,
            )
            .startInference(promptId: testPromptId);
        setInferenceStatus(container, InferenceStatus.running);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: WidgetTestBench(
              child: AiRunningDecoderBars(
                entryId: testId,
                responseTypes: testSet,
                isInteractive: true,
              ),
            ),
          ),
        );
        await tester.pump(AiRunningDecoderBars.transitionDuration);

        final decoderTapTarget = find.ancestor(
          of: find.byKey(AiRunningDecoderBars.indicatorKey),
          matching: find.byType(GestureDetector),
        );
        expect(decoderTapTarget, findsOneWidget);

        await tester.tap(decoderTapTarget);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Decoder prompt'), findsOneWidget);
        expect(find.byType(UnifiedAiProgressContent), findsOneWidget);

        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(UnifiedAiProgressContent), findsNothing);
      } finally {
        container.dispose();
      }
    });
  });
}
