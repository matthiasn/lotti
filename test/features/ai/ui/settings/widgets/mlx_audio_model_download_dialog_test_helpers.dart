import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/mlx_audio_model_download_dialog.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai/util/mlx_audio_model_progress_store.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

AiConfigModel hModel({
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

Future<void> hPumpChoiceLauncher(
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

Future<void> hOpenChoiceDialog(WidgetTester tester) async {
  await tester.tap(find.text('Open chooser'));
  await tester.pump();
  await tester.pump(kThemeAnimationDuration);
}

Future<void> hClosePushedRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(kThemeAnimationDuration);
}

class PendingStatusMlxAudioChannel extends MlxAudioChannel {
  PendingStatusMlxAudioChannel(this.modelId);

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

class DialogHost extends StatefulWidget {
  const DialogHost({
    required this.initialModels,
    required this.initialRecommendedId,
    super.key,
  });

  final List<AiConfigModel> initialModels;
  final String initialRecommendedId;

  @override
  State<DialogHost> createState() => DialogHostState();
}

class DialogHostState extends State<DialogHost> {
  late List<AiConfigModel> hModels = widget.initialModels;
  late String _recommendedId = widget.initialRecommendedId;

  void swapToVoxtralOnly() {
    setState(() {
      hModels = hModels
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
          models: hModels,
          recommendedModelId: _recommendedId,
        ),
      ),
    );
  }
}

class TerminalMlxAudioChannel extends MlxAudioChannel {
  TerminalMlxAudioChannel(
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
class ThrowingInstallStore extends MlxAudioModelProgressStore {
  ThrowingInstallStore(this.error);

  final Object error;

  @override
  Future<void> installModel(String modelId) async {
    // ignore: only_throw_errors
    throw error;
  }
}
