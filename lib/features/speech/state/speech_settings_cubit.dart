import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/asr_service.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';
import 'package:lotti/get_it.dart';

class SpeechSettingsCubit extends Cubit<SpeechSettingsState> {
  SpeechSettingsCubit()
      : super(
          SpeechSettingsState(
            availableModels: availableModels.toSet(),
          ),
        ) {
    loadSelectedModel();
  }

  final AsrService _asrService = getIt<AsrService>();
  final SettingsDb _settingsDb = getIt<SettingsDb>();

  String _selectedModel = 'small';

  Future<void> loadSelectedModel() async {
    final selectedModel = await _settingsDb.itemByKey(whisperModelKey);

    if (selectedModel != null) {
      _selectedModel = selectedModel;
      emitState();
    }
  }

  Future<void> selectModel(String selectedModel) async {
    _selectedModel = selectedModel;
    _asrService.model = selectedModel;

    await _settingsDb.saveSettingsItem(
      whisperModelKey,
      selectedModel,
    );

    emitState();
  }

  void emitState() {
    emit(
      state.copyWith(
        selectedModel: _selectedModel,
      ),
    );
  }

  /// Ensures the current model setting is valid
  void ensureValidModel() {
    // List of valid FastWhisper model names
    const validModels = [
      'tiny.en',
      'tiny',
      'base.en',
      'base',
      'small.en',
      'small',
      'medium.en',
      'medium',
      'large-v1',
      'large-v2',
      'large',
      'fastWhisper',
    ];

    // If current model is not in the valid list, set to 'small'
    if (!validModels.contains(_selectedModel)) {
      _selectedModel = 'small';
      _asrService.model = _selectedModel;
      _settingsDb.saveSettingsItem(whisperModelKey, _selectedModel);
      emitState();
    }
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
