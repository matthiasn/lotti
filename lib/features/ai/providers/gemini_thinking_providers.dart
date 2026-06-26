import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls whether Gemini reasoning/thinking content is surfaced inline.
///
/// UI can toggle this; CloudInferenceRepository reads it to override the
/// `includeThoughts` flag in the final thinking config.
final geminiIncludeThoughtsProvider =
    NotifierProvider<GeminiIncludeThoughts, bool>(
      GeminiIncludeThoughts.new,
      name: 'geminiIncludeThoughtsProvider',
    );

class GeminiIncludeThoughts extends Notifier<bool> {
  @override
  bool build() => false;

  bool get includeThoughts => state;
  set includeThoughts(bool value) => state = value;

  void toggle() => state = !state;
}
