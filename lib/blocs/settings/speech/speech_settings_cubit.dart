import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:lotti/blocs/settings/speech/speech_settings_state.dart';

class SpeechSettingsCubit extends Cubit<SpeechSettingsState> {
  SpeechSettingsCubit()
      : super(
          SpeechSettingsState(
            availableModels: availableModels,
            downloadedModels: <String>{},
          ),
        );

  Set<String> _downloadedModels = <String>{};
  String _selectedModel = '';

  void getDownloadedModels() {
    _downloadedModels = <String>{};
    emitState();
  }

  void selectModel(String selectedModel) {
    debugPrint('selectModel $selectedModel');
    _selectedModel = selectedModel;
    emitState();
  }

  void downloadModel(String model) {
    debugPrint('downloadModel $model');
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
        selectedModel: _selectedModel,
      ),
    );
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
