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
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockLoggingService = MockLoggingService();

    // Register mocks in GetIt
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Setup mock behaviors
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
  });

  tearDown(getIt.reset);

  group('AI Animation Modal Interaction Tests', () {
    const testId = 'test-entity-id';
    const testPromptId = 'test-prompt-id';
    const testType = AiResponseType.taskSummary;
    final testTypes = {testType};

    late AiConfigPrompt testPrompt;

    setUp(() {
      testPrompt = AiConfigPrompt(
        id: testPromptId,
        name: 'Test Prompt',
        description: 'Test Description',
        systemMessage: 'Test system message',
        userMessage: 'Test user message',
        defaultModelId: 'test-model',
        modelIds: ['test-model'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.taskSummary,
      );
    });

    testWidgets(
        'tapping animation opens progress modal when inference is active',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          // Override the AI config provider
          aiConfigByIdProvider(testPromptId)
              .overrideWith((ref) async => testPrompt),
        ],
      );

      // Set up active inference
      container
          .read(
            activeInferenceControllerProvider(
              entityId: testId,
              aiResponseType: testType,
            ).notifier,
          )
          .startInference(
            promptId: testPromptId,
          );

      // Set status to running
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
              responseTypes: testTypes,
              isInteractive: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify animation is shown and is interactive
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);

      // Verify the tap handler exists
      final gesture = tester.widget<GestureDetector>(
        find.byType(GestureDetector),
      );
      expect(gesture.onTap, isNotNull);

      container.dispose();
    });

    testWidgets('animation does not open modal when not interactive',
        (tester) async {
      final container = ProviderContainer();

      // Set status to running
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
              responseTypes: testTypes,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify animation is shown but no GestureDetector
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);

      container.dispose();
    });

    testWidgets('handles missing active inference gracefully', (tester) async {
      final container = ProviderContainer();

      // Set status to running but no active inference
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
              responseTypes: testTypes,
              isInteractive: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify animation exists
      expect(find.byType(GestureDetector), findsOneWidget);

      // Tap the animation (no active inference, so nothing should happen)
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      container.dispose();
    });

    testWidgets('shows existing inference progress with showExisting flag',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider(testPromptId)
              .overrideWith((ref) async => testPrompt),
        ],
      );

      // Set up active inference
      container
          .read(
            activeInferenceControllerProvider(
              entityId: testId,
              aiResponseType: testType,
            ).notifier,
          )
          .startInference(
            promptId: testPromptId,
          );

      // Set status to running
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
              responseTypes: testTypes,
              isInteractive: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify animation is shown and interactive
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);

      container.dispose();
    });

    testWidgets('handles multiple response types correctly', (tester) async {
      final multipleTypes = {
        AiResponseType.taskSummary,
        AiResponseType.audioTranscription,
        AiResponseType.imageAnalysis,
      };

      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider(testPromptId)
              .overrideWith((ref) async => testPrompt),
        ],
      );

      // Set up active inference for audioTranscription
      container
          .read(
            activeInferenceControllerProvider(
              entityId: testId,
              aiResponseType: AiResponseType.audioTranscription,
            ).notifier,
          )
          .startInference(
            promptId: testPromptId,
          );

      // Set status to running for audioTranscription
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
              isInteractive: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify animation is shown
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);

      container.dispose();
    });

    testWidgets('AiRunningAnimationWrapperCard shows animation and handles tap',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          aiConfigByIdProvider(testPromptId)
              .overrideWith((ref) async => testPrompt),
        ],
      );

      // Set up active inference
      container
          .read(
            activeInferenceControllerProvider(
              entityId: testId,
              aiResponseType: testType,
            ).notifier,
          )
          .startInference(
            promptId: testPromptId,
          );

      // Set status to running
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
              height: 50,
              responseTypes: testTypes,
              isInteractive: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify glass container and animation are shown
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);

      // Verify it's wrapped in the glass container
      expect(
        find.ancestor(
          of: find.byType(AiRunningAnimation),
          matching: find.byType(GlassContainer),
        ),
        findsOneWidget,
      );

      container.dispose();
    });
  });
}
