import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_label.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_helper.dart';

const _entryId = 'entry-1';
const _promptId = 'prompt-1';

void main() {
  late ProviderContainer container;

  /// Released at the end of each test body, not in a tear-down: the status
  /// providers keep themselves alive on a cache timer, which the binding
  /// would find still pending.
  ProviderContainer makeContainer({List<Override> overrides = const []}) =>
      container = ProviderContainer(overrides: overrides);

  void run(ProviderContainer container, AiResponseType type) => container
      .read(
        inferenceStatusControllerProvider((
          id: _entryId,
          aiResponseType: type,
        )).notifier,
      )
      .setStatus(InferenceStatus.running);

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer container, {
    Set<AiResponseType> types = const {
      AiResponseType.imageAnalysis,
      AiResponseType.audioTranscription,
      AiResponseType.audioSummary,
      AiResponseType.promptGeneration,
      AiResponseType.imagePromptGeneration,
      AiResponseType.imageGeneration,
      AiResponseType.pullRequestSummary,
    },
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: WidgetTestBench(
          // Loose constraints, as under an action bar's controls.
          child: Align(
            alignment: Alignment.topCenter,
            child: AiRunningLabel(entryId: _entryId, responseTypes: types),
          ),
        ),
      ),
    );
    await tester.pump(AiRunningDecoderBars.transitionDuration);
  }

  for (final (type, words) in [
    (AiResponseType.imageAnalysis, 'Analyzing image'),
    (AiResponseType.audioTranscription, 'Transcribing audio'),
    (AiResponseType.audioSummary, 'Summarizing recording'),
    (AiResponseType.promptGeneration, 'Writing a prompt'),
    (AiResponseType.imagePromptGeneration, 'Writing a prompt'),
    (AiResponseType.imageGeneration, 'Generating image'),
    (AiResponseType.pullRequestSummary, 'AI is working'),
  ]) {
    testWidgets('a running $type reads "$words" behind its own glyph', (
      tester,
    ) async {
      makeContainer();
      run(container, type);
      await pump(tester, container);

      expect(find.text(words), findsOneWidget);
      expect(find.byIcon(type.icon), findsOneWidget);
      // The chevron says the line opens the progress view.
      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
      container.dispose();
    });
  }

  testWidgets('nothing running: no words, no glyph, and no height taken '
      "under the host's controls", (tester) async {
    await pump(tester, makeContainer());

    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(tester.getSize(find.byType(AiRunningLabel)).height, 0);
    container.dispose();
  });

  testWidgets('a run of a kind this host does not show is not named', (
    tester,
  ) async {
    makeContainer();
    run(container, AiResponseType.imageGeneration);
    await pump(tester, container, types: {AiResponseType.audioTranscription});

    expect(find.byType(Text), findsNothing);
    container.dispose();
  });

  testWidgets('the glyph wears agent violet and the words the quiet ink: '
      'a caption under the controls, not a capsule', (tester) async {
    makeContainer();
    run(container, AiResponseType.audioTranscription);
    await pump(tester, container);

    final tokens = tester.element(find.byType(AiRunningLabel)).designTokens;
    expect(
      tester
          .widget<Icon>(find.byIcon(AiResponseType.audioTranscription.icon))
          .color,
      tokens.colors.aiCard.accent,
    );
    expect(
      tester.widget<Text>(find.text('Transcribing audio')).style?.color,
      tokens.colors.text.mediumEmphasis,
    );
    expect(
      find.descendant(
        of: find.byType(AiRunningLabel),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    container.dispose();
  });

  testWidgets('a tap opens the progress of the run in flight', (tester) async {
    const type = AiResponseType.audioTranscription;
    final prompt = AiConfigPrompt(
      id: _promptId,
      name: 'Transcription prompt',
      systemMessage: 'Transcribe.',
      userMessage: 'The recording.',
      defaultModelId: 'model-id',
      modelIds: const ['model-id'],
      createdAt: DateTime(2024, 3, 15, 10, 30),
      useReasoning: false,
      requiredInputData: const [],
      aiResponseType: type,
    );
    makeContainer(
      overrides: [
        aiConfigByIdProvider(_promptId).overrideWith((ref) async => prompt),
      ],
    );
    container
        .read(
          activeInferenceControllerProvider((
            entityId: _entryId,
            aiResponseType: type,
          )).notifier,
        )
        .startInference(promptId: _promptId);
    run(container, type);
    await pump(tester, container);

    await tester.tap(find.text('Transcribing audio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Transcription prompt'), findsOneWidget);
    expect(find.byType(UnifiedAiProgressContent), findsOneWidget);
    container.dispose();
  });
}
