import 'dart:async';

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
        await _openChoiceDialog(tester);
        await tester.tap(find.text('Install model'));
        await _closePushedRoute(tester);

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
        final hostKey = GlobalKey<_DialogHostState>();
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _DialogHost(
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
        final hostKey = GlobalKey<_DialogHostState>();
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            _DialogHost(
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

      await _openChoiceDialog(tester);
      await tester.tap(find.text('Install model'));
      await _closePushedRoute(tester);

      expect(selectedModel?.providerModelId, recommendedModel.providerModelId);
    });
  });

  group('MlxAudioModelDownloadDialog', () {
    testWidgets('shows an indeterminate checking state while install starts', (
      tester,
    ) async {
      final model = _model(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );
      final channel = _PendingStatusMlxAudioChannel(model.providerModelId);
      addTearDown(channel.close);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MlxAudioModelDownloadDialog(model: model),
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
      expect(find.text('Checking model status'), findsOneWidget);
      expect(channel.installCalls, 1);
    });

    testWidgets(
      'reports a Flutter error when starting the install throws',
      (tester) async {
        final model = _model(
          id: 'qwen-17b-8bit',
          name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
          providerModelId: mlxAudioQwenAsr17B8BitModelId,
        );
        // The store status path still needs a working channel; only the
        // install call is forced to throw via the overridden store notifier.
        final channel = _TerminalMlxAudioChannel(
          model.providerModelId,
          MlxAudioModelStatus.notInstalled,
        );
        addTearDown(channel.close);

        final installError = StateError('install boom');

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MlxAudioModelDownloadDialog(model: model),
            overrides: [
              mlxAudioChannelProvider.overrideWithValue(channel),
              mlxAudioModelProgressStoreProvider.overrideWith(
                () => _ThrowingInstallStore(installError),
              ),
            ],
          ),
        );
        // Let the post-frame callback run so _startDownload executes and the
        // overridden installModel throws into the dialog's catch block.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // The dialog funnels the failure through FlutterError.reportError; the
        // test binding captures it so we can assert on the reported exception.
        final reported = tester.takeException();
        expect(reported, same(installError));

        // The dialog itself does not crash and keeps rendering its UI.
        expect(find.byType(MlxAudioModelDownloadDialog), findsOneWidget);
      },
    );

    testWidgets('renders measured downloading progress as percent', (
      tester,
    ) async {
      final model = _model(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );
      final channel = _TerminalMlxAudioChannel(
        model.providerModelId,
        MlxAudioModelStatus.downloading,
        completedUnitCount: 42,
        totalUnitCount: 100,
      );
      addTearDown(channel.close);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MlxAudioModelDownloadDialog(model: model),
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.42);
      expect(find.text('Downloading 42%'), findsOneWidget);
    });

    testWidgets(
      'renders indeterminate downloading progress without a percent',
      (
        tester,
      ) async {
        final model = _model(
          id: 'qwen-17b-8bit',
          name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
          providerModelId: mlxAudioQwenAsr17B8BitModelId,
        );
        final channel = _TerminalMlxAudioChannel(
          model.providerModelId,
          MlxAudioModelStatus.downloading,
        );
        addTearDown(channel.close);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MlxAudioModelDownloadDialog(model: model),
            overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, isNull);
        expect(find.text('Downloading'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);
      },
    );

    testWidgets('renders installed and not-installed terminal states', (
      tester,
    ) async {
      final model = _model(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );

      for (final statusCase in const [
        (MlxAudioModelStatus.installed, 1.0, 'Installed'),
        (MlxAudioModelStatus.notInstalled, 0.0, 'Not installed'),
      ]) {
        final channel = _TerminalMlxAudioChannel(
          model.providerModelId,
          statusCase.$1,
        );
        addTearDown(channel.close);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MlxAudioModelDownloadDialog(model: model),
            overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, statusCase.$2);
        expect(find.text(statusCase.$3), findsOneWidget);
      }
    });

    testWidgets('close button pops the dialog', (tester) async {
      final model = _model(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );
      final channel = _TerminalMlxAudioChannel(
        model.providerModelId,
        MlxAudioModelStatus.installed,
      );
      addTearDown(channel.close);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => MlxAudioModelDownloadDialog.show(
                context: context,
                model: model,
              ),
              child: const Text('Open download'),
            ),
          ),
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        ),
      );
      await tester.tap(find.text('Open download'));
      await tester.pump();
      await tester.pump(kThemeAnimationDuration);
      await tester.pump();
      await tester.pump();

      expect(find.byType(MlxAudioModelDownloadDialog), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(kThemeAnimationDuration);

      expect(find.byType(MlxAudioModelDownloadDialog), findsNothing);
    });

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
          await tester.pump();
          await tester.pump();
          await tester.pump();
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

class _PendingStatusMlxAudioChannel extends MlxAudioChannel {
  _PendingStatusMlxAudioChannel(this.modelId);

  final String modelId;
  final _statusCompleter = Completer<MlxAudioModelDownloadProgress>();
  int installCalls = 0;

  @override
  Stream<MlxAudioModelDownloadProgress> get downloadProgressStream =>
      const Stream.empty();

  @override
  Future<MlxAudioModelDownloadProgress> getModelStatus(String modelId) {
    return _statusCompleter.future;
  }

  @override
  Future<void> installModel(String modelId) async {
    installCalls++;
  }

  Future<void> close() async {
    if (!_statusCompleter.isCompleted) {
      _statusCompleter.complete(
        MlxAudioModelDownloadProgress(
          modelId: modelId,
          status: MlxAudioModelStatus.notInstalled,
        ),
      );
    }
  }
}

class _DialogHost extends StatefulWidget {
  const _DialogHost({
    required this.initialModels,
    required this.initialRecommendedId,
    super.key,
  });

  final List<AiConfigModel> initialModels;
  final String initialRecommendedId;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  late List<AiConfigModel> _models = widget.initialModels;
  late String _recommendedId = widget.initialRecommendedId;

  void swapToVoxtralOnly() {
    setState(() {
      _models = _models
          .where(
            (m) => m.providerModelId == mlxAudioVoxtralRealtime4BitModelId,
          )
          .toList();
      _recommendedId = 'no-match';
    });
  }

  /// Changes only the recommended id while keeping the *same* models list
  /// instance, so `didUpdateWidget` short-circuits the `identical(models)`
  /// check and evaluates the `recommendedModelId` comparison branch.
  void changeRecommendedIdOnly(String recommendedId) {
    setState(() {
      _recommendedId = recommendedId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: MlxAudioModelInstallChoiceDialog(
          models: _models,
          recommendedModelId: _recommendedId,
        ),
      ),
    );
  }
}

class _TerminalMlxAudioChannel extends MlxAudioChannel {
  _TerminalMlxAudioChannel(
    this.modelId,
    this.status, {
    this.completedUnitCount,
    this.totalUnitCount,
  });

  final String modelId;
  final MlxAudioModelStatus status;
  final int? completedUnitCount;
  final int? totalUnitCount;

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
      completedUnitCount: completedUnitCount,
      totalUnitCount: totalUnitCount,
    );
  }

  @override
  Future<void> installModel(String modelId) async {}

  Future<void> close() async {}
}

/// Store override whose [installModel] always throws, exercising the download
/// dialog's `_startDownload` catch branch that funnels into
/// [FlutterError.reportError].
class _ThrowingInstallStore extends MlxAudioModelProgressStore {
  _ThrowingInstallStore(this.error);

  final Object error;

  @override
  Future<void> installModel(String modelId) async {
    // ignore: only_throw_errors
    throw error;
  }
}
