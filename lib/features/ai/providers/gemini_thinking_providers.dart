import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gemini_thinking_providers.g.dart';

/// Controls whether Gemini reasoning/thinking content is surfaced inline.
///
/// UI can toggle this; CloudInferenceRepository reads it to override the
/// `includeThoughts` flag in the final thinking config.
@Riverpod(keepAlive: true)
class GeminiIncludeThoughts extends _$GeminiIncludeThoughts {
  @override
  bool build() => false;

  bool get includeThoughts => state;
  set includeThoughts(bool value) => state = value;

  void toggle() => state = !state;
}
