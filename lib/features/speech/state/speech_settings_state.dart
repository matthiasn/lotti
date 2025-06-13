import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_settings_state.freezed.dart';

const List<String> availableModels = [
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

@freezed
class SpeechSettingsState with _$SpeechSettingsState {
  factory SpeechSettingsState({
    required Set<String> availableModels,
    String? selectedModel,
  }) = _SpeechSettingsState;
}
