import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

/// Provider rows shared by AI settings, profile pickers, skill flows, and the
/// production demo seed.
///
/// Names describe the role each endpoint plays in Project Waddle rather than
/// pretending the world is connected to a real account. API keys are inert
/// demo strings and only ever render through the production masking widget.
List<AiConfigInferenceProvider> demoAiProviders(DemoSeedText t, DateTime now) {
  return List<AiConfigInferenceProvider>.unmodifiable([
    AiConfigInferenceProvider(
      id: manualMissionControlProviderId,
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKey: 'sk-demo-project-waddle-7f3a',
      name: t('Mission Control Router', 'Missionskontroll-Router'),
      description: t(
        'Cloud routing for launch planning and high-stakes reasoning.',
        'Cloud-Routing für Startplanung und besonders wichtige Entscheidungen.',
      ),
      createdAt: now.subtract(const Duration(days: 90)),
      inferenceProviderType: InferenceProviderType.openRouter,
    ),
    AiConfigInferenceProvider(
      id: manualHabitatLabProviderId,
      baseUrl: 'http://habitat-ai.local:11434',
      apiKey: '',
      name: t('Habitat Local Lab', 'Lokales Habitat-Labor'),
      description: t(
        'Local models for private colony notes and sardine logistics.',
        'Lokale Modelle für private Kolonienotizen und Sardinenlogistik.',
      ),
      createdAt: now.subtract(const Duration(days: 72)),
      inferenceProviderType: InferenceProviderType.ollama,
    ),
    AiConfigInferenceProvider(
      id: manualOrbitalVisionProviderId,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      apiKey: 'demo-orbital-vision-91c2',
      name: t('Orbital Vision', 'Orbitaler Blick'),
      description: t(
        'Multimodal inspection for habitat imagery and cover art.',
        'Multimodale Prüfung von Habitatbildern und Titelgrafiken.',
      ),
      createdAt: now.subtract(const Duration(days: 61)),
      inferenceProviderType: InferenceProviderType.gemini,
    ),
    AiConfigInferenceProvider(
      id: manualAudioBayProviderId,
      baseUrl: 'http://audio-bay.local:11344',
      apiKey: '',
      name: t('Penguin Audio Bay', 'Pinguin-Audiobucht'),
      description: t(
        'Local transcription for mission briefings.',
        'Lokale Transkription für Missionsbriefings.',
      ),
      createdAt: now.subtract(const Duration(days: 45)),
      inferenceProviderType: InferenceProviderType.voxtral,
    ),
  ]);
}

/// Saved model rows used throughout the manual's AI examples and the demo
/// seed.
List<AiConfigModel> demoAiModels(DemoSeedText t, DateTime now) {
  return List<AiConfigModel>.unmodifiable([
    AiConfigModel(
      id: manualWaddleCommandModelId,
      name: t('Waddle Command 70B', 'Watschelkommando 70B'),
      description: t(
        'Fast tool-calling model for routine Project Waddle operations.',
        'Schnelles Tool-Modell für den Routinebetrieb von Project Waddle.',
      ),
      providerModelId: 'meta-llama/llama-3.3-70b-instruct',
      inferenceProviderId: manualMissionControlProviderId,
      createdAt: now.subtract(const Duration(days: 80)),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      supportsFunctionCalling: true,
      maxCompletionTokens: 8192,
    ),
    AiConfigModel(
      id: manualEmperorReasoningModelId,
      name: t('Emperor Reasoning XL', 'Kaiserpinguin-Denken XL'),
      description: t(
        'Deliberate model for launch reviews and unusually formal penguins.',
        'Gründliches Modell für Startprüfungen und auffallend förmliche Pinguine.',
      ),
      providerModelId: 'anthropic/claude-sonnet-4.5',
      inferenceProviderId: manualMissionControlProviderId,
      createdAt: now.subtract(const Duration(days: 76)),
      inputModalities: const [Modality.text, Modality.image],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      supportsFunctionCalling: true,
      maxCompletionTokens: 16384,
    ),
    AiConfigModel(
      id: manualSardineLogisticsModelId,
      name: t('Sardine Logistics 14B', 'Sardinenlogistik 14B'),
      description: t(
        'Local planning model for cargo manifests and feeder calibration.',
        'Lokales Planungsmodell für Frachtlisten und Futterautomat-Kalibrierung.',
      ),
      providerModelId: 'qwen3:14b',
      inferenceProviderId: manualHabitatLabProviderId,
      createdAt: now.subtract(const Duration(days: 69)),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      supportsFunctionCalling: true,
      maxCompletionTokens: 4096,
    ),
    AiConfigModel(
      id: manualHabitatVisionModelId,
      name: t('Habitat Vision Pro', 'Habitat-Sicht Pro'),
      description: t(
        'Checks pressure gauges, ice seals, and suspicious fish-shaped alerts.',
        'Prüft Druckanzeigen, Eisdichtungen und verdächtig fischförmige Alarme.',
      ),
      providerModelId: 'gemini-2.5-flash',
      inferenceProviderId: manualOrbitalVisionProviderId,
      createdAt: now.subtract(const Duration(days: 58)),
      inputModalities: const [Modality.text, Modality.image],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: true,
      maxCompletionTokens: 8192,
    ),
    AiConfigModel(
      id: manualPenguinBriefingsModelId,
      name: t('Voxtral Penguin Briefings', 'Voxtral-Pinguinbriefings'),
      description: t(
        'Transcribes habitat voice memos with Project Waddle vocabulary.',
        'Transkribiert Habitat-Sprachnotizen mit dem Wortschatz von Project Waddle.',
      ),
      providerModelId: 'voxtral-mini-latest',
      inferenceProviderId: manualAudioBayProviderId,
      createdAt: now.subtract(const Duration(days: 42)),
      inputModalities: const [Modality.audio],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      maxCompletionTokens: 4096,
    ),
    AiConfigModel(
      id: manualCoverArtistModelId,
      name: t('Project Waddle Cover Artist', 'Project-Waddle-Titelkünstler'),
      description: t(
        'Creates centered 16:9 mission art that survives square thumbnail crops.',
        'Erstellt zentrierte 16:9-Missionsgrafiken für quadratische Vorschaubilder.',
      ),
      providerModelId: 'gemini-2.5-flash-image',
      inferenceProviderId: manualOrbitalVisionProviderId,
      createdAt: now.subtract(const Duration(days: 35)),
      inputModalities: const [Modality.text, Modality.image],
      outputModalities: const [Modality.image],
      isReasoningModel: false,
      maxCompletionTokens: 4096,
    ),
  ]);
}

/// Inference profiles demonstrate cloud, local-first, and specialist routing.
List<AiConfigInferenceProfile> demoAiProfiles(DemoSeedText t, DateTime now) {
  return List<AiConfigInferenceProfile>.unmodifiable([
    AiConfigInferenceProfile(
      id: manualProjectWaddleProfileId,
      name: t('Project Waddle Command', 'Project-Waddle-Kommando'),
      description: t(
        'Launch-critical planning, habitat vision, briefings, and cover art.',
        'Startkritische Planung, Habitat-Sicht, Briefings und Titelgrafiken.',
      ),
      createdAt: now.subtract(const Duration(days: 33)),
      thinkingModelId: manualWaddleCommandModelId,
      thinkingHighEndModelId: manualEmperorReasoningModelId,
      imageRecognitionModelId: manualHabitatVisionModelId,
      transcriptionModelId: manualPenguinBriefingsModelId,
      imageGenerationModelId: manualCoverArtistModelId,
      isDefault: true,
      skillAssignments: const [
        SkillAssignment(skillId: skillTranscribeContextId, automate: true),
        SkillAssignment(
          skillId: skillImageAnalysisContextId,
          automate: true,
        ),
      ],
    ),
    AiConfigInferenceProfile(
      id: manualHabitatLocalProfileId,
      name: t('Habitat Local-First', 'Habitat zuerst lokal'),
      description: t(
        'Keeps private colony notes and routine sardine logistics local.',
        'Hält private Kolonienotizen und alltägliche Sardinenlogistik lokal.',
      ),
      createdAt: now.subtract(const Duration(days: 27)),
      thinkingModelId: manualSardineLogisticsModelId,
      transcriptionModelId: manualPenguinBriefingsModelId,
      desktopOnly: true,
      skillAssignments: const [
        SkillAssignment(skillId: skillTranscribeId, automate: true),
      ],
    ),
    AiConfigInferenceProfile(
      id: manualFishDiplomacyProfileId,
      name: t('Fish Diplomacy', 'Fischdiplomatie'),
      description: t(
        'Extra deliberation for Europa sardine markets and passenger law.',
        'Besonders gründlich für Europas Sardinenmärkte und Passagierrecht.',
      ),
      createdAt: now.subtract(const Duration(days: 19)),
      thinkingModelId: manualEmperorReasoningModelId,
      imageRecognitionModelId: manualHabitatVisionModelId,
    ),
  ]);
}

/// Available actions shown over the orbital-habitat task in the AI menu.
List<AiConfigSkill> demoAiSkills(DemoSeedText t, DateTime now) {
  return List<AiConfigSkill>.unmodifiable([
    AiConfigSkill(
      id: manualHabitatBriefingSkillId,
      name: t(
        'Transcribe habitat briefing',
        'Habitat-Briefing transkribieren',
      ),
      description: t(
        'Turn a Project Waddle voice memo into punctuated mission notes.',
        'Verwandle eine Project-Waddle-Sprachnotiz in gegliederte Missionsnotizen.',
      ),
      createdAt: now,
      skillType: SkillType.transcription,
      requiredInputModalities: const [Modality.audio],
      systemInstructions: t(
        'Transcribe the mission briefing accurately.',
        'Transkribiere das Missionsbriefing genau.',
      ),
      userInstructions: t(
        'Preserve Project Waddle names and terminology.',
        'Behalte Namen und Begriffe von Project Waddle bei.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
    ),
    AiConfigSkill(
      id: manualHabitatPhotoSkillId,
      name: t('Inspect habitat photo', 'Habitatfoto prüfen'),
      description: t(
        'Find pressure-gauge anomalies and task-relevant seal damage.',
        'Finde auffällige Druckanzeigen und relevante Schäden an Dichtungen.',
      ),
      createdAt: now,
      skillType: SkillType.imageAnalysis,
      requiredInputModalities: const [Modality.image],
      systemInstructions: t(
        'Inspect the habitat image for operational risks.',
        'Prüfe das Habitatbild auf Betriebsrisiken.',
      ),
      userInstructions: t(
        'Report only visible and actionable findings.',
        'Melde nur sichtbare und praktisch relevante Befunde.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
    ),
    AiConfigSkill(
      id: manualWaddleCoverArtSkillId,
      name: t(
        'Generate Project Waddle cover art',
        'Project-Waddle-Titelgrafik erzeugen',
      ),
      description: t(
        'Create centered 16:9 art for the task and its square thumbnail.',
        'Erstelle eine zentrierte 16:9-Grafik samt quadratischem Vorschaubild.',
      ),
      createdAt: now,
      skillType: SkillType.imageGeneration,
      requiredInputModalities: const [Modality.text],
      systemInstructions: t(
        'Create memorable mission cover art.',
        'Erstelle eine einprägsame Titelgrafik für die Mission.',
      ),
      userInstructions: t(
        'Keep the penguin subject inside the square-safe area.',
        'Halte den Pinguin im sicheren Bereich für den quadratischen Zuschnitt.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
    ),
    AiConfigSkill(
      id: manualLaunchPromptSkillId,
      name: t(
        'Draft launch-review prompt',
        'Prompt für Startprüfung entwerfen',
      ),
      description: t(
        'Prepare a complete AI prompt for the next Mission Control review.',
        'Bereite einen vollständigen KI-Prompt für die nächste Startprüfung vor.',
      ),
      createdAt: now,
      skillType: SkillType.promptGeneration,
      requiredInputModalities: const [Modality.text],
      systemInstructions: t(
        'Write a precise operational prompt.',
        'Schreibe einen präzisen operativen Prompt.',
      ),
      userInstructions: t(
        'Include the task context and outstanding risks.',
        'Beziehe den Aufgabenkontext und offene Risiken ein.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
    ),
  ]);
}
