import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_download_manager/flutter_download_manager.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/asr_service.dart';

const downloadPath =
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

class SpeechSettingsCubit extends Cubit<SpeechSettingsState> {
  SpeechSettingsCubit()
      : super(
          SpeechSettingsState(
            availableModels: availableModels,
            downloadedModels: <String>{},
            downloadProgress: <String, double>{},
          ),
        ) {
    for (final model in availableModels) {
      _downloadProgress[model] = 0;
    }
  }

  final AsrService _asrService = getIt<AsrService>();
  Set<String> _downloadedModels = <String>{};
  Map<String, double> _downloadProgress = <String, double>{};
  String _selectedModel = '';
  final downloadManager = DownloadManager();

  void getDownloadedModels() {
    _downloadedModels = <String>{};
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
    final filePath = './Documents/whisper/$fileName';
    await downloadManager.addDownload(url, filePath);
    final task = downloadManager.getDownload(url);

    if (task == null) {
      return;
    }

    task.progress.addListener(() {
      _downloadProgress[model] = task.progress.value;
      _downloadProgress = {..._downloadProgress};
      emitState();
    });

    await task.whenDownloadComplete();

    _downloadedModels = <String>{
      ..._downloadedModels,
      model,
    };
    emitState();
  }

  void emitState() {
    emit(
      state.copyWith(
        downloadedModels: _downloadedModels,
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
