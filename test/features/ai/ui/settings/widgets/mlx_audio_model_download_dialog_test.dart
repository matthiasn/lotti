import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/mlx_audio_model_download_dialog.dart';
import 'package:lotti/features/ai/util/known_models.dart';

import '../../../../../widget_test_utils.dart';
import 'mlx_audio_model_download_dialog_test_helpers.dart';

void main() {
  group('MlxAudioModelInstallChoiceDialog', () {
    final recommendedModel = hModel(
      id: 'qwen-17b-8bit',
      name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
      providerModelId: mlxAudioQwenAsr17B8BitModelId,
      description: 'Recommended local STT model',
    );
    final voxtralModel = hModel(
      id: 'voxtral-4bit',
      name: 'Voxtral Mini Realtime 4B (MLX 4-bit)',
      providerModelId: mlxAudioVoxtralRealtime4BitModelId,
      description: 'Explicit comparison model',
    );

    testWidgets('preselects the recommended model and labels it', (
      tester,
    ) async {
      AiConfigModel? selectedModel;

      await hPumpChoiceLauncher(
        tester,
        models: [voxtralModel, recommendedModel],
        onResult: (model) => selectedModel = model,
      );
      await hOpenChoiceDialog(tester);

      expect(
        find.text(
          'Pick the local speech-to-text model to download first. You can '
          'install the others later from the model list.',
        ),
        findsOneWidget,
      );
      expect(find.text(recommendedModel.name), findsOneWidget);
      expect(find.text(voxtralModel.name), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);

      await tester.tap(find.text('Install model'));
      await hClosePushedRoute(tester);

      expect(selectedModel?.providerModelId, mlxAudioQwenAsr17B8BitModelId);
    });

    testWidgets('returns the model the user selects', (tester) async {
      AiConfigModel? selectedModel;

      await hPumpChoiceLauncher(
        tester,
        models: [recommendedModel, voxtralModel],
        onResult: (model) => selectedModel = model,
      );
      await hOpenChoiceDialog(tester);

      await tester.tap(find.text(voxtralModel.name));
      await tester.pump();
      await tester.tap(find.text('Install model'));
      await hClosePushedRoute(tester);

      expect(
        selectedModel?.providerModelId,
        mlxAudioVoxtralRealtime4BitModelId,
      );
    });

    testWidgets('cancel returns no model', (tester) async {
      AiConfigModel? selectedModel = recommendedModel;

      await hPumpChoiceLauncher(
        tester,
        models: [recommendedModel, voxtralModel],
        onResult: (model) => selectedModel = model,
      );
      await hOpenChoiceDialog(tester);

      await tester.tap(find.text('Cancel'));
      await hClosePushedRoute(tester);

      expect(selectedModel, isNull);
    });

    testWidgets(
      'falls back to the first model when no recommended id matches',
      (tester) async {
        AiConfigModel? selectedModel;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    final result = await Navigator.of(context)
                        .push<AiConfigModel>(
                          MaterialPageRoute<AiConfigModel>(
                            builder: (_) => Scaffold(
                              body: SingleChildScrollView(
                                child: MlxAudioModelInstallChoiceDialog(
                                  models: [voxtralModel],
                                  recommendedModelId: 'does-not-match-anything',
                                ),
                              ),
                            ),
                          ),
                        );
                    selectedModel = result;
                  },
                  child: const Text('Open chooser'),
                );
              },
            ),
          ),
        );
        await hOpenChoiceDialog(tester);
        await tester.tap(find.text('Install model'));
        await hClosePushedRoute(tester);

        expect(
          selectedModel?.providerModelId,
          mlxAudioVoxtralRealtime4BitModelId,
        );
      },
    );

    testWidgets(
      'didUpdateWidget rebuilds the model index when models or '
      'recommendedModelId change',
      (tester) async {
        final hostKey = GlobalKey<DialogHostState>();
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DialogHost(
              key: hostKey,
              initialModels: [recommendedModel, voxtralModel],
              initialRecommendedId: recommendedModel.providerModelId,
            ),
          ),
        );

        expect(find.text(recommendedModel.name), findsOneWidget);
        expect(find.text(voxtralModel.name), findsOneWidget);

        hostKey.currentState!.swapToVoxtralOnly();
        await tester.pump();

        expect(find.text(recommendedModel.name), findsNothing);
        expect(find.text(voxtralModel.name), findsOneWidget);
      },
    );

    testWidgets(
      'didUpdateWidget re-evaluates selection when only recommendedModelId '
      'changes',
      (tester) async {
        final hostKey = GlobalKey<DialogHostState>();
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DialogHost(
              key: hostKey,
              initialModels: [recommendedModel, voxtralModel],
              initialRecommendedId: recommendedModel.providerModelId,
            ),
          ),
        );

        // Initially the recommended badge sits on the recommended model row.
        final recommendedRadio = tester.widget<RadioListTile<String>>(
          find.ancestor(
            of: find.text(recommendedModel.name),
            matching: find.byType(RadioListTile<String>),
          ),
        );
        expect(recommendedRadio.value, recommendedModel.providerModelId);
        expect(find.text('Recommended'), findsOneWidget);

        // Change ONLY the recommended id (same models list instance), which
        // forces didUpdateWidget to evaluate the recommendedModelId branch and
        // rebuild the ordering so Voxtral becomes the recommended row.
        hostKey.currentState!.changeRecommendedIdOnly(
          voxtralModel.providerModelId,
        );
        await tester.pump();

        // The recommended badge now labels the Voxtral row, proving the index
        // was rebuilt off the new recommendedModelId.
        expect(find.text('Recommended'), findsOneWidget);
        final badgeRow = tester.widget<RadioListTile<String>>(
          find.ancestor(
            of: find.text('Recommended'),
            matching: find.byType(RadioListTile<String>),
          ),
        );
        expect(badgeRow.value, voxtralModel.providerModelId);
      },
    );

    testWidgets('show static helper resolves with the selected model', (
      tester,
    ) async {
      AiConfigModel? selectedModel;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selectedModel = await MlxAudioModelInstallChoiceDialog.show(
                  context: context,
                  models: [recommendedModel, voxtralModel],
                  recommendedModelId: recommendedModel.providerModelId,
                );
              },
              child: const Text('Open chooser'),
            ),
          ),
        ),
      );

      await hOpenChoiceDialog(tester);
      await tester.tap(find.text('Install model'));
      await hClosePushedRoute(tester);

      expect(selectedModel?.providerModelId, recommendedModel.providerModelId);
    });
  });
}
