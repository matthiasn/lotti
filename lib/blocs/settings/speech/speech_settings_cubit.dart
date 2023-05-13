import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_download_manager/flutter_download_manager.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/asr_service.dart';
import 'package:lotti/utils/file_utils.dart';

const downloadPath =
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

class SpeechSettingsCubit extends Cubit<SpeechSettingsState> {
  SpeechSettingsCubit({DownloadManager? downloadManager})
      : super(
          SpeechSettingsState(
            availableModels: availableModels,
            downloadProgress: <String, double>{},
          ),
        ) {
    _downloadManager = downloadManager ?? DownloadManager();

    for (final model in availableModels) {
      _downloadProgress[model] = 0;
    }
    detectDownloadedModels();
  }

  final AsrService _asrService = getIt<AsrService>();
  Map<String, double> _downloadProgress = <String, double>{};
  String _selectedModel = '';
  late final DownloadManager _downloadManager;

  Future<void> detectDownloadedModels() async {
    final docDir = await findDocumentsDirectory();
    final modelsDir =
        await Directory('${docDir.path}/whisper/').create(recursive: true);
    final files = modelsDir.listSync(followLinks: false);

    for (final file in files) {
      final path = file.path;
      if (path.endsWith('.bin')) {
        final model =
            path.split('/').last.replaceAll('.bin', '').replaceAll('ggml-', '');
        _downloadProgress[model] = 1.0;
      }
    }

    emitState();
  }

  void selectModel(String selectedModel) {
    _selectedModel = selectedModel;
    _asrService.model = selectedModel;
    emitState();
  }

  Future<void> downloadModel(String model) async {
    final fileName = 'ggml-$model.bin';
    final url = '$downloadPath/$fileName';
    final docDir = await findDocumentsDirectory();
    final modelsDir =
        await Directory('${docDir.path}/whisper/').create(recursive: true);

    await _downloadManager.addDownload(url, modelsDir.path);
    final task = _downloadManager.getDownload(url);

    if (task == null) {
      return;
    }

    task.progress.addListener(() {
      _downloadProgress[model] = task.progress.value;
      emitState();
    });

    await task.whenDownloadComplete();
    emitState();
  }

  void emitState() {
    _downloadProgress = {..._downloadProgress};

    emit(
      state.copyWith(
        downloadProgress: _downloadProgress,
        selectedModel: _selectedModel,
      ),
    );
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
