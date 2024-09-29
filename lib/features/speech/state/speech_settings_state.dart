import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_settings_state.freezed.dart';

Set<String> availableModels = {
  'large-v3',
  'large-v2_949MB',
  'distil-large-v3_594MB',
  'distil-large-v3_turbo_600MB',
  'small',
};

@freezed
class SpeechSettingsState with _$SpeechSettingsState {
  factory SpeechSettingsState({
    required Set<String> availableModels,
    required Map<String, double> downloadProgress,
    required Map<String, double> downloadedModelSizes,
    String? selectedModel,
  }) = _SpeechSettingsState;
}
