import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_settings_state.freezed.dart';

Set<String> availableModels = {
  'tiny',
  'tiny.en',
  'base',
  'base.en',
  'small',
  'small.en',
  'large-v2',
  'large-v3',
};

@freezed
class SpeechSettingsState with _$SpeechSettingsState {
  factory SpeechSettingsState({
    required Set<String> availableModels,
    String? selectedModel,
  }) = _SpeechSettingsState;
}
