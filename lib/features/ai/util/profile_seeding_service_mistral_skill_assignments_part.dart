part of 'profile_seeding_service.dart';

/// Well-known IDs for default inference profiles (idempotent seeding).
const profileGeminiFlashId = 'profile-gemini-flash-001';
const profileGeminiProId = 'profile-gemini-pro-001';
const profileOpenAiId = 'profile-openai-001';
const profileMistralEuId = 'profile-mistral-eu-001';
const profileMeliousId = 'profile-melious-001';
const profileMeliousFlashId = 'profile-melious-flash-001';
const profileAlibabaId = 'profile-alibaba-001';
const profileAnthropicId = 'profile-anthropic-001';
const profileLocalId = 'profile-local-001';
const profileLocalPowerId = 'profile-local-power-001';
const profileLocalGemmaOmlxId = 'profile-local-gemma-omlx-001';
const profileLocalGemmaId = 'profile-local-gemma-001';
const profileLocalGemmaPowerId = 'profile-local-gemma-power-001';

/// Current bundled-default generation for the Melious inference profile.
///
/// Each generation has a *frozen* constant below and its own one-shot
/// migration, so a profile stranded at generation 0 chains forward through
/// every generation in a single [ProfileSeedingService.upgradeExisting] pass.
/// Bumping this alone would retarget the older migrations' guards and stamps
/// along with it, which is exactly how a one-shot migration stops being one.
const int meliousProfileSeedGeneration = meliousProfileSeedGeneration2;

/// Generation 1: Qwen thinking, GLM 5.2 high-end, Mistral vision, Voxtral
/// transcription, Flux 2 Klein 9B image generation.
const meliousProfileSeedGeneration1 = 1;

/// Generation 2: GLM 5.2 thinking, Kimi K3 high-end *and* vision, Whisper
/// Large v3 transcription, Flux 2 Klein 9B image generation.
const meliousProfileSeedGeneration2 = 2;
const _logTag = 'ProfileSeedingService';
const _localPowerName = 'Local Power (oMLX)';
const _legacyLocalPowerName = 'Local Power (Ollama)';
const _legacyLocalPowerThinkingModelId = 'qwen3.6:35b-a3b-coding-nvfp4';
const _legacyLocalPowerImageModelId = 'qwen3.5:27b';
const _legacyMeliousFlux2DevModelId = 'black-forest-labs/flux-2-dev';

/// Default skill assignments for profiles with transcription + image
/// recognition model slots. Uses `skillTranscribeContextId` which has
/// `contextPolicy: fullTask` for richer context-aware transcription.
const _defaultSkillAssignments = [
  SkillAssignment(skillId: skillTranscribeContextId, automate: true),
  SkillAssignment(skillId: skillImageAnalysisContextId, automate: true),
  SkillAssignment(skillId: skillAudioSummaryId, automate: true),
];

/// Skill assignments for Mistral (EU) — uses the basic transcription skill
/// which has `contextPolicy: dictionaryOnly`, suitable for Voxtral's
/// more limited context window.
const _mistralSkillAssignments = [
  SkillAssignment(skillId: skillTranscribeId, automate: true),
  SkillAssignment(skillId: skillImageAnalysisContextId, automate: true),
  SkillAssignment(skillId: skillAudioSummaryId, automate: true),
];
