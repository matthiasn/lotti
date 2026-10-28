import 'package:lotti/classes/ai/ai_config.dart';

/// The sampling temperature for a request that may run with reasoning on.
///
/// OpenAI's reasoning models accept only 1.0 while they reason, so a
/// reasoning request gets 1.0 and anything else gets [fallback]. Mistral
/// recommends 0.0–0.7 for all of its models, reasoning ones included, so a
/// Mistral request keeps [fallback] either way.
double samplingTemperature({
  required InferenceProviderType? providerType,
  required bool reasoning,
  required double fallback,
}) =>
    reasoning && providerType != InferenceProviderType.mistral ? 1.0 : fallback;
