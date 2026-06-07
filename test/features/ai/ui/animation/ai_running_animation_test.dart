import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show AiConfigRepository;
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:siri_wave/siri_wave.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

void main() {
  /// Creates a [ProviderContainer] with a teardown safety net: when an
  /// assertion throws before the in-body `container.dispose()` runs, the
  /// teardown still disposes the container so it never leaks into the next
  /// test. The in-body dispose calls stay because they run *before* the
  /// binding's pending-timer check and cancel cacheFor keep-alive timers
  /// (addTearDown runs after that check, so it cannot replace them).
  /// Riverpod's dispose() is a no-op on an already-disposed container.
  ProviderContainer makeContainer({List<Override> overrides = const []}) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

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
      final container = makeContainer();

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
      final container = makeContainer();

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
        final container = makeContainer();

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
      final container = makeContainer();

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

      // No active inference is registered (only the status is running), so
      // the tap must be a no-op: no progress modal opens and nothing throws.
      // The modal-opening path is covered in the 'modal interaction' group.
      await tester.tap(gesture);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(UnifiedAiProgressContent), findsNothing);
      expect(find.byType(AiRunningAnimation), findsOneWidget);
      expect(tester.takeException(), isNull);

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
      final container = makeContainer();

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
        final container = makeContainer();

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
      final container = makeContainer();

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

    testWidgets(
      'should not be interactive by default (no GestureDetector)',
      (tester) async {
        final container = makeContainer();

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

        // The inner wrapper must not be interactive and no tap target exists.
        final wrapper = tester.widget<AiRunningAnimationWrapper>(
          find.byType(AiRunningAnimationWrapper),
        );
        expect(wrapper.isInteractive, isFalse);
        expect(find.byType(GestureDetector), findsNothing);

        container.dispose();
      },
    );

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
      final container = makeContainer();

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
      final container = makeContainer();
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
      final container = makeContainer();
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
      final container = makeContainer();
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
        final container = makeContainer();
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
      final container = makeContainer(
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

  // ── Transplanted from ai_animation_modal_interaction_test.dart so this
  // file remains the single mirror of ai_running_animation.dart (one test
  // file per source rule). The GetIt/mock harness is scoped to this group.
  group('modal interaction', () {
    late MockDomainLogger mockLoggingService;
    late MockAiConfigRepository mockAiConfigRepository;
    late MockAiConfigDb mockAiConfigDb;

    setUpAll(() {
      registerFallbackValue(StackTrace.current);
      registerFallbackValue(AiConfigType.prompt);
    });

    setUp(() async {
      mockLoggingService = MockDomainLogger();
      mockAiConfigRepository = MockAiConfigRepository();
      mockAiConfigDb = MockAiConfigDb();

      // setUpTestGetIt registers a real DomainLogger; swap in the mock so the
      // log stubs below are hit, and add the AI config services on top.
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<DomainLogger>()
            ..registerSingleton<DomainLogger>(mockLoggingService)
            ..registerSingleton<AiConfigRepository>(mockAiConfigRepository)
            ..registerSingleton<AiConfigDb>(mockAiConfigDb);
        },
      );

      // Setup mock behaviors
      when(
        () => mockLoggingService.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      // Setup AI config repository mock behavior
      when(
        () => mockAiConfigRepository.getConfigById(any<String>()),
      ).thenAnswer((_) async => null);

      when(
        () => mockAiConfigRepository.watchConfigsByType(any<AiConfigType>()),
      ).thenAnswer((_) => const Stream.empty());
    });

    tearDown(tearDownTestGetIt);

    group('AI Animation Modal Interaction Tests', () {
      const testId = 'test-entity-id';
      const testPromptId = 'test-prompt-id';
      // ignore: deprecated_member_use_from_same_package
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
          createdAt: DateTime(2024, 3, 15, 10, 30),
          useReasoning: false,
          requiredInputData: const [],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );
      });

      testWidgets(
        'tapping animation opens progress modal when inference is active',
        (tester) async {
          final container = makeContainer(
            overrides: [
              // Override the AI config provider
              aiConfigByIdProvider(
                testPromptId,
              ).overrideWith((ref) async => testPrompt),
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

          // Tapping must actually open the progress modal: the Wolt sheet
          // page is titled with the prompt name. The sheet hosts the looping
          // running animation, so settle would never finish — bounded pumps.
          await tester.tap(find.byType(GestureDetector));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          expect(find.text(testPrompt.name), findsOneWidget);

          container.dispose();
        },
      );

      testWidgets('animation does not open modal when not interactive', (
        tester,
      ) async {
        final container = makeContainer();

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

      testWidgets('handles missing active inference gracefully', (
        tester,
      ) async {
        final container = makeContainer();

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

      testWidgets('shows existing inference progress with showExisting flag', (
        tester,
      ) async {
        final container = makeContainer(
          overrides: [
            aiConfigByIdProvider(
              testPromptId,
            ).overrideWith((ref) async => testPrompt),
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
          // ignore: deprecated_member_use_from_same_package
          AiResponseType.taskSummary,
          AiResponseType.audioTranscription,
          AiResponseType.imageAnalysis,
        };

        final container = makeContainer(
          overrides: [
            aiConfigByIdProvider(
              testPromptId,
            ).overrideWith((ref) async => testPrompt),
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

      testWidgets(
        'AiRunningAnimationWrapperCard shows animation and handles tap',
        (tester) async {
          final container = makeContainer(
            overrides: [
              aiConfigByIdProvider(
                testPromptId,
              ).overrideWith((ref) async => testPrompt),
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
        },
      );
    });
  });
}
