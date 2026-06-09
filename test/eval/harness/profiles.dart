// Canonical model profiles for Level 2 evaluation (ADR 0026).
//
// `modelId` is an `AiConfigModel` id resolved at run time via
// `resolveInferenceProvider` (ADR 0008); the placeholders below are wired to
// real config ids by the live runner in Phase 2. The point of the two profiles
// is to grade the SAME scenario under two optimisation targets:
//   - local:    constrained context + tight token budget, no thinking slot
//   - frontier: maximum capability, but token burn still matters

import 'eval_models.dart';

/// Local Ollama profile — optimise strictly for what the local model can do.
const kLocalOllamaProfile = EvalProfile(
  name: 'local-ollama',
  isLocal: true,
  modelId: 'ollama-thinking',
  temperature: 0.6,
  maxCompletionTokens: 2048,
  // A correct result that needs far more than this is a poor local fit.
  tokenBudget: 12000,
);

/// Frontier profile — optimise for quality, watch token burn.
const kFrontierProfile = EvalProfile(
  name: 'frontier-gemini',
  isLocal: false,
  modelId: 'gemini-thinking',
  maxCompletionTokens: 8192,
  tokenBudget: 200000,
);

/// The default set of profiles a Level 2 run grades every scenario against.
const kDefaultProfiles = <EvalProfile>[
  kLocalOllamaProfile,
  kFrontierProfile,
];
