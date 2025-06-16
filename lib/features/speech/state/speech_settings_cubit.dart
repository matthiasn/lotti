import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/speech_settings_state.dart';
import 'package:lotti/get_it.dart';

class SpeechSettingsCubit extends Cubit<SpeechSettingsState> {
  SpeechSettingsCubit()
      : super(
          SpeechSettingsState(
            availableModels: availableModels,
          ),
        ) {
    loadSelectedModel();
  }

  String _selectedModel = 'small';

  Future<void> loadSelectedModel() async {
    final selectedModel = await getIt<SettingsDb>().itemByKey(whisperModelKey);

    if (selectedModel != null) {
      _selectedModel = selectedModel;
      emitState();
    }
  }

  Future<void> selectModel(String selectedModel) async {
    _selectedModel = selectedModel;

    await getIt<SettingsDb>().saveSettingsItem(
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

  @override
  Future<void> close() async {
    await super.close();
  }
}
