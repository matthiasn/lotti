import 'package:lotti/features/ai/model/ai_config.dart';

/// Normalizes a stored provider type string to a valid
/// [InferenceProviderType] name.
///
/// Rules:
/// - If the value equals `unknown`, default to `genericOpenAi`.
/// - If the value matches any known enum name, keep as-is.
/// - Otherwise, default to `genericOpenAi`.
String normalizeProviderType(String value) {
  final valid = InferenceProviderType.values.map((e) => e.name).toSet();
  if (value == 'unknown') {
    return InferenceProviderType.genericOpenAi.name;
  }
  if (valid.contains(value)) return value;
  return InferenceProviderType.genericOpenAi.name;
}
