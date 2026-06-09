// Canonical model profiles for Level 2 evaluation (ADR 0029).
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
  modelClass: EvalModelClass.localReasoning,
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
  modelClass: EvalModelClass.frontierReasoning,
  modelId: 'gemini-thinking',
  maxCompletionTokens: 8192,
  tokenBudget: 200000,
);

/// Fast local profile — useful for deciding which use cases are realistic on
/// small/offline models.
const kLocalSmallProfile = EvalProfile(
  name: 'local-small',
  isLocal: true,
  modelClass: EvalModelClass.localSmall,
  modelId: 'ollama-small',
  temperature: 0.4,
  maxCompletionTokens: 1024,
  tokenBudget: 6000,
);

/// Fast frontier profile — useful when latency/cost matters more than maximum
/// reasoning depth.
const kFrontierFastProfile = EvalProfile(
  name: 'frontier-fast',
  isLocal: false,
  modelClass: EvalModelClass.frontierFast,
  modelId: 'frontier-fast',
  temperature: 0.5,
  maxCompletionTokens: 4096,
  tokenBudget: 60000,
);

/// The default set of profiles a Level 2 run grades every scenario against.
const kDefaultProfiles = <EvalProfile>[
  kLocalSmallProfile,
  kLocalOllamaProfile,
  kFrontierFastProfile,
  kFrontierProfile,
];
