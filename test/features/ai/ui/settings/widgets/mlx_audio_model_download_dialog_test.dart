import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/mlx_audio_model_download_dialog.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

AiConfigModel _model({
  required String id,
  required String name,
  required String providerModelId,
  String description = 'Local speech model',
}) {
  return AiTestDataFactory.createTestModel(
    id: id,
    name: name,
    description: description,
    providerModelId: providerModelId,
    inputModalities: const [Modality.audio, Modality.text],
  );
}

Future<void> _pumpChoiceLauncher(
  WidgetTester tester, {
  required List<AiConfigModel> models,
  required ValueChanged<AiConfigModel?> onResult,
}) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Builder(
        builder: (context) {
          return TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<AiConfigModel>(
                MaterialPageRoute<AiConfigModel>(
                  builder: (_) => Scaffold(
                    body: SingleChildScrollView(
                      child: MlxAudioModelInstallChoiceDialog(
                        models: models,
                        recommendedModelId: mlxAudioRecommendedSttModelId,
                      ),
                    ),
                  ),
                ),
              );
              onResult(result);
            },
            child: const Text('Open chooser'),
          );
        },
      ),
    ),
  );
}

Future<void> _openChoiceDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open chooser'));
  await tester.pump();
  await tester.pump(kThemeAnimationDuration);
}

Future<void> _closePushedRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(kThemeAnimationDuration);
}

void main() {
  group('MlxAudioModelInstallChoiceDialog', () {
    final recommendedModel = _model(
      id: 'qwen-17b-8bit',
      name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
      providerModelId: mlxAudioQwenAsr17B8BitModelId,
      description: 'Recommended local STT model',
    );
    final voxtralModel = _model(
      id: 'voxtral-4bit',
      name: 'Voxtral Mini Realtime 4B (MLX 4-bit)',
      providerModelId: mlxAudioVoxtralRealtime4BitModelId,
      description: 'Explicit comparison model',
    );

    testWidgets('preselects the recommended model and labels it', (
      tester,
    ) async {
      AiConfigModel? selectedModel;

      await _pumpChoiceLauncher(
        tester,
        models: [voxtralModel, recommendedModel],
        onResult: (model) => selectedModel = model,
      );
      await _openChoiceDialog(tester);

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
      await _closePushedRoute(tester);

      expect(selectedModel?.providerModelId, mlxAudioQwenAsr17B8BitModelId);
    });

    testWidgets('returns the model the user selects', (tester) async {
      AiConfigModel? selectedModel;

      await _pumpChoiceLauncher(
        tester,
        models: [recommendedModel, voxtralModel],
        onResult: (model) => selectedModel = model,
      );
      await _openChoiceDialog(tester);

      await tester.tap(find.text(voxtralModel.name));
      await tester.pump();
      await tester.tap(find.text('Install model'));
      await _closePushedRoute(tester);

      expect(
        selectedModel?.providerModelId,
        mlxAudioVoxtralRealtime4BitModelId,
      );
    });

    testWidgets('cancel returns no model', (tester) async {
      AiConfigModel? selectedModel = recommendedModel;

      await _pumpChoiceLauncher(
        tester,
        models: [recommendedModel, voxtralModel],
        onResult: (model) => selectedModel = model,
      );
      await _openChoiceDialog(tester);

      await tester.tap(find.text('Cancel'));
      await _closePushedRoute(tester);

      expect(selectedModel, isNull);
    });
  });

  group('MlxAudioModelDownloadDialog', () {
    testWidgets(
      'renders terminal failed and unsupported states with determinate progress',
      (tester) async {
        final model = _model(
          id: 'qwen-17b-8bit',
          name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
          providerModelId: mlxAudioQwenAsr17B8BitModelId,
        );

        for (final status in [
          MlxAudioModelStatus.failed,
          MlxAudioModelStatus.unsupported,
        ]) {
          final channel = _TerminalMlxAudioChannel(
            model.providerModelId,
            status,
          );
          addTearDown(channel.close);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              MlxAudioModelDownloadDialog(model: model),
              overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
            ),
          );
          await tester.pump();
          await Future<void>.value();
          await tester.pump();
          await Future<void>.value();
          await tester.pump();

          final indicator = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(indicator.value, 0);

          if (status == MlxAudioModelStatus.failed) {
            expect(find.text('Download failed'), findsOneWidget);
          } else {
            expect(find.text('Apple Silicon required'), findsOneWidget);
          }
        }
      },
    );
  });
}

class _TerminalMlxAudioChannel extends MlxAudioChannel {
  _TerminalMlxAudioChannel(this.modelId, this.status);

  final String modelId;
  final MlxAudioModelStatus status;

  @override
  Stream<MlxAudioModelDownloadProgress> get downloadProgressStream =>
      Stream.value(_progress);

  @override
  Future<MlxAudioModelDownloadProgress> getModelStatus(String modelId) async {
    return _progress;
  }

  MlxAudioModelDownloadProgress get _progress {
    return MlxAudioModelDownloadProgress(
      modelId: modelId,
      status: status,
    );
  }

  @override
  Future<void> installModel(String modelId) async {}

  Future<void> close() async {}
}
