import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_settings_state.freezed.dart';

Set<String> availableModels = {
  'tiny.en',
  'tiny',
  'base.en',
  'base',
  'small.en',
  'small',
  'medium.en',
  'medium',
  'large-v1',
  'large',
};

@freezed
class SpeechSettingsState with _$SpeechSettingsState {
  factory SpeechSettingsState({
    required Set<String> availableModels,
    required Map<String, double> downloadProgress,
    String? selectedModel,
  }) = _SpeechSettingsState;
}
