import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_download_manager/flutter_download_manager.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

const downloadPath =
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

class SpeechSettingsCubit extends Cubit<SpeechSettingsState> {
  SpeechSettingsCubit({DownloadManager? downloadManager})
      : super(
          SpeechSettingsState(
            availableModels: availableModels,
            downloadProgress: <String, double>{},
            downloadedModelSizes: <String, double>{},
          ),
        ) {
    _downloadManager = downloadManager ?? DownloadManager();

    for (final model in availableModels) {
      _downloadProgress[model] = 0;
    }
    detectDownloadedModels();
    loadSelectedModel();
  }

  final AsrService _asrService = getIt<AsrService>();
  Map<String, double> _downloadProgress = <String, double>{};
  Map<String, double> _downloadedModelSizes = <String, double>{};
  String _selectedModel = '';
  late final DownloadManager _downloadManager;

  Future<void> loadSelectedModel() async {
    final selectedModel = await getIt<SettingsDb>().itemByKey(whisperModelKey);

    if (selectedModel != null) {
      _selectedModel = selectedModel;
      emitState();
    }
  }

  Future<void> detectDownloadedModels() async {
    _downloadedModelSizes = <String, double>{};
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
        _downloadedModelSizes[model] = file.statSync().size / 1024 / 1024;
      }
    }

    emitState();
  }

  Future<void> selectModel(String selectedModel) async {
    _selectedModel = selectedModel;
    _asrService.model = selectedModel;

    await getIt<SettingsDb>().saveSettingsItem(
      whisperModelKey,
      selectedModel,
    );

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
      final value = task.progress.value;
      _downloadProgress[model] = value;

      if (value == 1.0) {
        detectDownloadedModels();

        if (_selectedModel.isEmpty) {
          _selectedModel = model;
        }
      }
      emitState();
    });

    await task.whenDownloadComplete();
    emitState();
  }

  Future<void> deleteModel(String model) async {
    _downloadProgress = {..._downloadProgress};
    _downloadProgress[model] = 0;
    if (_selectedModel == model) {
      _selectedModel = '';
    }

    emitState();
    final fileName = 'ggml-$model.bin';
    final docDir = await findDocumentsDirectory();
    final modelsDir = Directory(p.join(docDir.path, 'whisper'));
    final file = File(p.join(modelsDir.path, fileName));
    await file.delete();
  }

  void emitState() {
    _downloadProgress = {..._downloadProgress};

    emit(
      state.copyWith(
        downloadProgress: _downloadProgress,
        selectedModel: _selectedModel,
        downloadedModelSizes: _downloadedModelSizes,
      ),
    );
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
