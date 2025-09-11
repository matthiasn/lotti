import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls whether Gemini reasoning/thinking content is surfaced inline.
///
/// UI can toggle this; CloudInferenceRepository reads it to override the
/// `includeThoughts` flag in the final thinking config.
final geminiIncludeThoughtsProvider = StateProvider<bool>((ref) => false);
