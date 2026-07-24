import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';

import '../../../../test_helper.dart';

void main() {
  ProviderContainer makeContainer({List<Override> overrides = const []}) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  Widget buildSubject(
    ProviderContainer container,
    Widget child,
  ) {
    return UncontrolledProviderScope(
      container: container,
      child: WidgetTestBench(child: child),
    );
  }

  void setInferenceStatus({
    required ProviderContainer container,
    required String entryId,
    required AiResponseType responseType,
    required InferenceStatus status,
  }) {
    container
        .read(
          inferenceStatusControllerProvider((
            id: entryId,
            aiResponseType: responseType,
          )).notifier,
        )
        .setStatus(status);
  }

  group('AiRunningDecoderBars', () {
    const testId = 'test-id';
    const testPromptId = 'test-prompt-id';
    const testType = AiResponseType.promptGeneration;
    const testSet = {testType};

    testWidgets('renders nothing when no matching inference is running', (
      tester,
    ) async {
      final container = makeContainer();

      await tester.pumpWidget(
        buildSubject(
          container,
          const AiRunningDecoderBars(
            entryId: testId,
            responseTypes: testSet,
          ),
        ),
      );

      expect(find.byKey(AiRunningDecoderBars.indicatorKey), findsNothing);
      expect(find.byType(AiThinkingLineShader), findsNothing);
      container.dispose();
    });

    testWidgets('renders the decoder route with the configured height', (
      tester,
    ) async {
      final container = makeContainer();
      setInferenceStatus(
        container: container,
        entryId: testId,
        responseType: testType,
        status: InferenceStatus.running,
      );

      await tester.pumpWidget(
        buildSubject(
          container,
          const AiRunningDecoderBars(
            entryId: testId,
            responseTypes: testSet,
            height: 50,
          ),
        ),
      );
      await tester.pump(AiRunningDecoderBars.transitionDuration);

      expect(find.byKey(AiRunningDecoderBars.indicatorKey), findsOneWidget);
      final shader = tester.widget<AiThinkingLineShader>(
        find.byType(AiThinkingLineShader),
      );
      expect(shader.route, AiThinkingShaderRoute.decoderBars);
      expect(shader.speed, AiRunningDecoderBars.defaultSpeed);
      expect(shader.height, 50);
      expect(shader.amplitude, AiRunningDecoderBars.defaultAmplitude);
      expect(shader.randomness, AiRunningDecoderBars.defaultRandomness);
      expect(shader.pulse, AiRunningDecoderBars.defaultPulse);
      expect(shader.opacity, 1);
      container.dispose();
    });

    testWidgets('runs when any configured response type is active', (
      tester,
    ) async {
      const responseTypes = {
        AiResponseType.promptGeneration,
        AiResponseType.audioTranscription,
        AiResponseType.imageAnalysis,
      };
      final container = makeContainer();
      setInferenceStatus(
        container: container,
        entryId: testId,
        responseType: AiResponseType.audioTranscription,
        status: InferenceStatus.running,
      );

      await tester.pumpWidget(
        buildSubject(
          container,
          const AiRunningDecoderBars(
            entryId: testId,
            responseTypes: responseTypes,
          ),
        ),
      );
      await tester.pump(AiRunningDecoderBars.transitionDuration);

      expect(find.byType(AiThinkingLineShader), findsOneWidget);
      expect(
        tester
            .widget<AiThinkingLineShader>(find.byType(AiThinkingLineShader))
            .route,
        AiThinkingShaderRoute.decoderBars,
      );
      container.dispose();
    });

    testWidgets('surfaces and consumes detailed inference errors', (
      tester,
    ) async {
      final container = makeContainer();
      setInferenceStatus(
        container: container,
        entryId: testId,
        responseType: testType,
        status: InferenceStatus.running,
      );

      await tester.pumpWidget(
        buildSubject(
          container,
          const AiRunningDecoderBars(
            entryId: testId,
            responseTypes: testSet,
          ),
        ),
      );
      await tester.pump(AiRunningDecoderBars.transitionDuration);

      final errorProvider = inferenceErrorControllerProvider((
        id: testId,
        aiResponseType: testType,
      ));
      container
          .read(errorProvider.notifier)
          .setError(
            'HTTP 503 · Melious · request melious-audio-123 failed',
          );
      setInferenceStatus(
        container: container,
        entryId: testId,
        responseType: testType,
        status: InferenceStatus.error,
      );
      await tester.pump();

      expect(
        find.text('HTTP 503 · Melious · request melious-audio-123 failed'),
        findsOneWidget,
      );
      expect(container.read(errorProvider), isNull);
      container.dispose();
    });

    testWidgets('opens existing progress when interactive bars are tapped', (
      tester,
    ) async {
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
      container
          .read(
            activeInferenceControllerProvider((
              entityId: testId,
              aiResponseType: testType,
            )).notifier,
          )
          .startInference(promptId: testPromptId);
      setInferenceStatus(
        container: container,
        entryId: testId,
        responseType: testType,
        status: InferenceStatus.running,
      );

      await tester.pumpWidget(
        buildSubject(
          container,
          const AiRunningDecoderBars(
            entryId: testId,
            responseTypes: testSet,
            isInteractive: true,
          ),
        ),
      );
      await tester.pump(AiRunningDecoderBars.transitionDuration);

      final tapTarget = find.ancestor(
        of: find.byKey(AiRunningDecoderBars.indicatorKey),
        matching: find.byType(GestureDetector),
      );
      expect(tapTarget, findsOneWidget);

      await tester.tap(tapTarget);
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
      container.dispose();
    });

    testWidgets('does not add a tap target when bars are not interactive', (
      tester,
    ) async {
      final container = makeContainer();
      setInferenceStatus(
        container: container,
        entryId: testId,
        responseType: testType,
        status: InferenceStatus.running,
      );

      await tester.pumpWidget(
        buildSubject(
          container,
          const AiRunningDecoderBars(
            entryId: testId,
            responseTypes: testSet,
          ),
        ),
      );
      await tester.pump(AiRunningDecoderBars.transitionDuration);

      expect(find.byType(AiThinkingLineShader), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(AiRunningDecoderBars.indicatorKey),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      container.dispose();
    });

    testWidgets(
      'animates reserved height and shader amplitude before collapsing',
      (tester) async {
        final container = makeContainer();

        await tester.pumpWidget(
          buildSubject(
            container,
            const Align(
              alignment: Alignment.topCenter,
              child: AiRunningDecoderBars(
                entryId: testId,
                responseTypes: testSet,
              ),
            ),
          ),
        );

        expect(find.byKey(AiRunningDecoderBars.indicatorKey), findsNothing);

        setInferenceStatus(
          container: container,
          entryId: testId,
          responseType: testType,
          status: InferenceStatus.running,
        );
        await tester.pump();
        await tester.pump(AiRunningDecoderBars.transitionDuration ~/ 2);

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
        expect(visibleShader.amplitude, AiRunningDecoderBars.defaultAmplitude);
        expect(visibleShader.opacity, 1);

        setInferenceStatus(
          container: container,
          entryId: testId,
          responseType: testType,
          status: InferenceStatus.idle,
        );
        await tester.pump();
        await tester.pump(AiRunningDecoderBars.transitionDuration ~/ 2);

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
        container.dispose();
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
  });

  group('AiThinkingShaderPresence', () {
    const key = ValueKey('presence-box');

    testWidgets('uses local running state for entry and exit transitions', (
      tester,
    ) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: AiThinkingShaderPresence(
            isRunning: false,
            indicatorKey: key,
          ),
        ),
      );
      expect(find.byKey(key), findsNothing);

      await tester.pumpWidget(
        const WidgetTestBench(
          child: AiThinkingShaderPresence(
            isRunning: true,
            indicatorKey: key,
          ),
        ),
      );
      await tester.pump(AiRunningDecoderBars.transitionDuration);
      expect(find.byKey(key), findsOneWidget);
      expect(
        tester
            .widget<AiThinkingLineShader>(find.byType(AiThinkingLineShader))
            .route,
        AiThinkingShaderRoute.decoderBars,
      );

      await tester.pumpWidget(
        const WidgetTestBench(
          child: AiThinkingShaderPresence(
            isRunning: false,
            indicatorKey: key,
          ),
        ),
      );
      await tester.pump(AiRunningDecoderBars.transitionDuration);
      expect(find.byKey(key), findsNothing);
    });

    testWidgets('adopts a new transition duration on rebuild', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: AiThinkingShaderPresence(
            isRunning: true,
            transitionDuration: Duration(milliseconds: 100),
            indicatorKey: key,
          ),
        ),
      );
      expect(find.byKey(key), findsOneWidget);

      await tester.pumpWidget(
        const WidgetTestBench(
          child: AiThinkingShaderPresence(
            isRunning: false,
            transitionDuration: Duration(seconds: 1),
            indicatorKey: key,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(key), findsOneWidget);
      final shader = tester.widget<AiThinkingLineShader>(
        find.byType(AiThinkingLineShader),
      );
      expect(shader.opacity, greaterThan(0));
      expect(shader.opacity, lessThan(1));

      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(key), findsNothing);
      expect(find.byType(AiThinkingLineShader), findsNothing);
    });
  });
}
