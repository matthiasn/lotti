import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/utils/image_utils.dart';

import 'entity_factories.dart';
import 'manual_screenshot_locale.dart';

String _t(String en, String de) => manualScreenshotText(en: en, de: de);

/// Fixed clock shared by the manual screenshot fixtures.
final manualDemoNow = DateTime(2026, 7, 17, 10, 30);

const manualDemoCategoryId = 'manual-penguin-ops';
const manualDemoProjectLabelId = 'manual-project-waddle';
const manualDemoCriticalLabelId = 'manual-habitat-critical';

const manualMissionControlProviderId = 'provider-mission-control-router';
const manualHabitatLabProviderId = 'provider-habitat-local-lab';
const manualOrbitalVisionProviderId = 'provider-orbital-vision';
const manualAudioBayProviderId = 'provider-penguin-audio-bay';

const manualWaddleCommandModelId = 'model-waddle-command-70b';
const manualEmperorReasoningModelId = 'model-emperor-reasoning-xl';
const manualSardineLogisticsModelId = 'model-sardine-logistics-14b';
const manualHabitatVisionModelId = 'model-habitat-vision-pro';
const manualPenguinBriefingsModelId = 'model-penguin-briefings';
const manualCoverArtistModelId = 'model-project-waddle-cover-artist';

const manualProjectWaddleProfileId = 'profile-project-waddle-command';
const manualHabitatLocalProfileId = 'profile-habitat-local-first';
const manualFishDiplomacyProfileId = 'profile-fish-diplomacy';

const manualOrbitalHabitatTaskId = 'task-orbital-habitat';
const manualRollCallTaskId = 'task-emperor-penguin-roll-call';
const manualLaunchReviewTaskId = 'task-project-waddle-launch-review';
const manualLunchTaskId = 'task-coffee-is-not-a-vegetable';
const manualSardineFuturesTaskId = 'task-negotiate-sardine-futures';
const manualFishFeederTaskId = 'task-zero-gravity-feeder';
const manualSardineCargoTaskId = 'task-sardine-cargo';
const manualPenguinPassengerTaskId = 'task-penguin-passenger';
const manualHeadsetWalkTaskId = 'task-walk-without-headset';
const manualHabitatCoverImageId = 'manual-penguin-habitat-cover';
const manualRollCallCoverImageId = 'manual-penguin-roll-call-cover';
const manualLaunchReviewCoverImageId = 'manual-penguin-launch-review-cover';
const manualLunchCoverImageId = 'manual-penguin-lunch-cover';
const manualSardineFuturesCoverImageId = 'manual-penguin-sardine-futures-cover';
const manualFishFeederCoverImageId = 'manual-penguin-feeder-cover';
const manualSardineCargoCoverImageId = 'manual-penguin-cargo-cover';
const manualPenguinPassengerCoverImageId = 'manual-penguin-legal-cover';
const manualHeadsetWalkCoverImageId = 'manual-penguin-headset-walk-cover';

/// Provider rows shared by AI settings, profile pickers, and skill flows.
///
/// Names describe the role each endpoint plays in Project Waddle rather than
/// pretending the manual is connected to a real account. API keys are inert
/// demo strings and only ever render through the production masking widget.
final List<AiConfigInferenceProvider>
manualDemoAiProviders = List<AiConfigInferenceProvider>.unmodifiable([
  AiConfigInferenceProvider(
    id: manualMissionControlProviderId,
    baseUrl: 'https://openrouter.ai/api/v1',
    apiKey: 'sk-demo-project-waddle-7f3a',
    name: _t('Mission Control Router', 'Missionskontroll-Router'),
    description: _t(
      'Cloud routing for launch planning and high-stakes reasoning.',
      'Cloud-Routing für Startplanung und besonders wichtige Entscheidungen.',
    ),
    createdAt: manualDemoNow.subtract(const Duration(days: 90)),
    inferenceProviderType: InferenceProviderType.openRouter,
  ),
  AiConfigInferenceProvider(
    id: manualHabitatLabProviderId,
    baseUrl: 'http://habitat-ai.local:11434',
    apiKey: '',
    name: _t('Habitat Local Lab', 'Lokales Habitat-Labor'),
    description: _t(
      'Local models for private colony notes and sardine logistics.',
      'Lokale Modelle für private Kolonienotizen und Sardinenlogistik.',
    ),
    createdAt: manualDemoNow.subtract(const Duration(days: 72)),
    inferenceProviderType: InferenceProviderType.ollama,
  ),
  AiConfigInferenceProvider(
    id: manualOrbitalVisionProviderId,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    apiKey: 'demo-orbital-vision-91c2',
    name: _t('Orbital Vision', 'Orbitaler Blick'),
    description: _t(
      'Multimodal inspection for habitat imagery and cover art.',
      'Multimodale Prüfung von Habitatbildern und Titelgrafiken.',
    ),
    createdAt: manualDemoNow.subtract(const Duration(days: 61)),
    inferenceProviderType: InferenceProviderType.gemini,
  ),
  AiConfigInferenceProvider(
    id: manualAudioBayProviderId,
    baseUrl: 'http://audio-bay.local:11344',
    apiKey: '',
    name: _t('Penguin Audio Bay', 'Pinguin-Audiobucht'),
    description: _t(
      'Local transcription for mission briefings.',
      'Lokale Transkription für Missionsbriefings.',
    ),
    createdAt: manualDemoNow.subtract(const Duration(days: 45)),
    inferenceProviderType: InferenceProviderType.voxtral,
  ),
]);

/// Saved model rows used throughout the manual's AI examples.
final List<AiConfigModel>
manualDemoAiModels = List<AiConfigModel>.unmodifiable([
  AiConfigModel(
    id: manualWaddleCommandModelId,
    name: _t('Waddle Command 70B', 'Watschelkommando 70B'),
    description: _t(
      'Fast tool-calling model for routine Project Waddle operations.',
      'Schnelles Tool-Modell für den Routinebetrieb von Project Waddle.',
    ),
    providerModelId: 'meta-llama/llama-3.3-70b-instruct',
    inferenceProviderId: manualMissionControlProviderId,
    createdAt: manualDemoNow.subtract(const Duration(days: 80)),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    maxCompletionTokens: 8192,
  ),
  AiConfigModel(
    id: manualEmperorReasoningModelId,
    name: _t('Emperor Reasoning XL', 'Kaiserpinguin-Denken XL'),
    description: _t(
      'Deliberate model for launch reviews and unusually formal penguins.',
      'Gründliches Modell für Startprüfungen und auffallend förmliche Pinguine.',
    ),
    providerModelId: 'anthropic/claude-sonnet-4.5',
    inferenceProviderId: manualMissionControlProviderId,
    createdAt: manualDemoNow.subtract(const Duration(days: 76)),
    inputModalities: const [Modality.text, Modality.image],
    outputModalities: const [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    maxCompletionTokens: 16384,
  ),
  AiConfigModel(
    id: manualSardineLogisticsModelId,
    name: _t('Sardine Logistics 14B', 'Sardinenlogistik 14B'),
    description: _t(
      'Local planning model for cargo manifests and feeder calibration.',
      'Lokales Planungsmodell für Frachtlisten und Futterautomat-Kalibrierung.',
    ),
    providerModelId: 'qwen3:14b',
    inferenceProviderId: manualHabitatLabProviderId,
    createdAt: manualDemoNow.subtract(const Duration(days: 69)),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    maxCompletionTokens: 4096,
  ),
  AiConfigModel(
    id: manualHabitatVisionModelId,
    name: _t('Habitat Vision Pro', 'Habitat-Sicht Pro'),
    description: _t(
      'Checks pressure gauges, ice seals, and suspicious fish-shaped alerts.',
      'Prüft Druckanzeigen, Eisdichtungen und verdächtig fischförmige Alarme.',
    ),
    providerModelId: 'gemini-2.5-flash',
    inferenceProviderId: manualOrbitalVisionProviderId,
    createdAt: manualDemoNow.subtract(const Duration(days: 58)),
    inputModalities: const [Modality.text, Modality.image],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
    supportsFunctionCalling: true,
    maxCompletionTokens: 8192,
  ),
  AiConfigModel(
    id: manualPenguinBriefingsModelId,
    name: _t('Voxtral Penguin Briefings', 'Voxtral-Pinguinbriefings'),
    description: _t(
      'Transcribes habitat voice memos with Project Waddle vocabulary.',
      'Transkribiert Habitat-Sprachnotizen mit dem Wortschatz von Project Waddle.',
    ),
    providerModelId: 'voxtral-mini-latest',
    inferenceProviderId: manualAudioBayProviderId,
    createdAt: manualDemoNow.subtract(const Duration(days: 42)),
    inputModalities: const [Modality.audio],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
    maxCompletionTokens: 4096,
  ),
  AiConfigModel(
    id: manualCoverArtistModelId,
    name: _t('Project Waddle Cover Artist', 'Project-Waddle-Titelkünstler'),
    description: _t(
      'Creates centered 16:9 mission art that survives square thumbnail crops.',
      'Erstellt zentrierte 16:9-Missionsgrafiken für quadratische Vorschaubilder.',
    ),
    providerModelId: 'gemini-2.5-flash-image',
    inferenceProviderId: manualOrbitalVisionProviderId,
    createdAt: manualDemoNow.subtract(const Duration(days: 35)),
    inputModalities: const [Modality.text, Modality.image],
    outputModalities: const [Modality.image],
    isReasoningModel: false,
    maxCompletionTokens: 4096,
  ),
]);

/// Inference profiles demonstrate cloud, local-first, and specialist routing.
final List<AiConfigInferenceProfile> manualDemoAiProfiles =
    List<AiConfigInferenceProfile>.unmodifiable([
      AiConfigInferenceProfile(
        id: manualProjectWaddleProfileId,
        name: _t('Project Waddle Command', 'Project-Waddle-Kommando'),
        description: _t(
          'Launch-critical planning, habitat vision, briefings, and cover art.',
          'Startkritische Planung, Habitat-Sicht, Briefings und Titelgrafiken.',
        ),
        createdAt: manualDemoNow.subtract(const Duration(days: 33)),
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
        name: _t('Habitat Local-First', 'Habitat zuerst lokal'),
        description: _t(
          'Keeps private colony notes and routine sardine logistics local.',
          'Hält private Kolonienotizen und alltägliche Sardinenlogistik lokal.',
        ),
        createdAt: manualDemoNow.subtract(const Duration(days: 27)),
        thinkingModelId: manualSardineLogisticsModelId,
        transcriptionModelId: manualPenguinBriefingsModelId,
        desktopOnly: true,
        skillAssignments: const [
          SkillAssignment(skillId: skillTranscribeId, automate: true),
        ],
      ),
      AiConfigInferenceProfile(
        id: manualFishDiplomacyProfileId,
        name: _t('Fish Diplomacy', 'Fischdiplomatie'),
        description: _t(
          'Extra deliberation for Europa sardine markets and passenger law.',
          'Besonders gründlich für Europas Sardinenmärkte und Passagierrecht.',
        ),
        createdAt: manualDemoNow.subtract(const Duration(days: 19)),
        thinkingModelId: manualEmperorReasoningModelId,
        imageRecognitionModelId: manualHabitatVisionModelId,
      ),
    ]);

/// Available actions shown over the orbital-habitat task in the AI menu.
final List<AiConfigSkill> manualDemoAiSkills = List<AiConfigSkill>.unmodifiable(
  [
    AiConfigSkill(
      id: 'skill-habitat-briefing',
      name: _t(
        'Transcribe habitat briefing',
        'Habitat-Briefing transkribieren',
      ),
      description: _t(
        'Turn a Project Waddle voice memo into punctuated mission notes.',
        'Verwandle eine Project-Waddle-Sprachnotiz in gegliederte Missionsnotizen.',
      ),
      createdAt: manualDemoNow,
      skillType: SkillType.transcription,
      requiredInputModalities: const [Modality.audio],
      systemInstructions: _t(
        'Transcribe the mission briefing accurately.',
        'Transkribiere das Missionsbriefing genau.',
      ),
      userInstructions: _t(
        'Preserve Project Waddle names and terminology.',
        'Behalte Namen und Begriffe von Project Waddle bei.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
    ),
    AiConfigSkill(
      id: 'skill-habitat-photo',
      name: _t('Inspect habitat photo', 'Habitatfoto prüfen'),
      description: _t(
        'Find pressure-gauge anomalies and task-relevant seal damage.',
        'Finde auffällige Druckanzeigen und relevante Schäden an Dichtungen.',
      ),
      createdAt: manualDemoNow,
      skillType: SkillType.imageAnalysis,
      requiredInputModalities: const [Modality.image],
      systemInstructions: _t(
        'Inspect the habitat image for operational risks.',
        'Prüfe das Habitatbild auf Betriebsrisiken.',
      ),
      userInstructions: _t(
        'Report only visible and actionable findings.',
        'Melde nur sichtbare und praktisch relevante Befunde.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
    ),
    AiConfigSkill(
      id: 'skill-waddle-cover-art',
      name: _t(
        'Generate Project Waddle cover art',
        'Project-Waddle-Titelgrafik erzeugen',
      ),
      description: _t(
        'Create centered 16:9 art for the task and its square thumbnail.',
        'Erstelle eine zentrierte 16:9-Grafik samt quadratischem Vorschaubild.',
      ),
      createdAt: manualDemoNow,
      skillType: SkillType.imageGeneration,
      requiredInputModalities: const [Modality.text],
      systemInstructions: _t(
        'Create memorable mission cover art.',
        'Erstelle eine einprägsame Titelgrafik für die Mission.',
      ),
      userInstructions: _t(
        'Keep the penguin subject inside the square-safe area.',
        'Halte den Pinguin im sicheren Bereich für den quadratischen Zuschnitt.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
    ),
    AiConfigSkill(
      id: 'skill-launch-prompt',
      name: _t(
        'Draft launch-review prompt',
        'Prompt für Startprüfung entwerfen',
      ),
      description: _t(
        'Prepare a complete AI prompt for the next Mission Control review.',
        'Bereite einen vollständigen KI-Prompt für die nächste Startprüfung vor.',
      ),
      createdAt: manualDemoNow,
      skillType: SkillType.promptGeneration,
      requiredInputModalities: const [Modality.text],
      systemInstructions: _t(
        'Write a precise operational prompt.',
        'Schreibe einen präzisen operativen Prompt.',
      ),
      userInstructions: _t(
        'Include the task context and outstanding risks.',
        'Beziehe den Aufgabenkontext und offene Risiken ein.',
      ),
      contextPolicy: ContextPolicy.fullTask,
      isPreconfigured: true,
      useReasoning: true,
    ),
  ],
);

const manualDemoCoverAssets = <String, String>{
  manualHabitatCoverImageId:
      'assets/design_system/manual_task_cover_habitat.webp',
  manualRollCallCoverImageId:
      'assets/design_system/manual_task_cover_roll_call.webp',
  manualLaunchReviewCoverImageId:
      'assets/design_system/manual_task_cover_launch_review.webp',
  manualLunchCoverImageId: 'assets/design_system/manual_task_cover_lunch.webp',
  manualSardineFuturesCoverImageId:
      'assets/design_system/manual_task_cover_sardine_futures.webp',
  manualFishFeederCoverImageId:
      'assets/design_system/manual_task_cover_feeder.webp',
  manualSardineCargoCoverImageId:
      'assets/design_system/manual_task_cover_cargo.webp',
  manualPenguinPassengerCoverImageId:
      'assets/design_system/manual_task_cover_legal.webp',
  manualHeadsetWalkCoverImageId:
      'assets/design_system/manual_task_cover_headset_walk.webp',
};

/// Re-encodes installed manual artwork as PNG bytes in place.
///
/// The headless Flutter test engine can leave resized WebP decoding pending,
/// while production widgets correctly resolve the same files on devices. PNG
/// bytes keep screenshot captures deterministic; image codecs detect the bytes
/// rather than relying on the retained `.webp` filenames.
Future<void> transcodeManualDemoMediaToPng(List<File> files) async {
  for (final file in files) {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    frame.image.dispose();
    codec.dispose();
  }
}

/// One deterministic, production-shaped data set reused across manual pages.
///
/// Keeping tasks, categories, labels, and cover images here prevents the task
/// list, task detail, and Daily OS agenda screenshots from drifting into
/// unrelated demo universes.
class ManualDemoWorld {
  ManualDemoWorld._({
    required this.category,
    required this.labels,
    required this.coverImages,
    required this.tasks,
  });

  factory ManualDemoWorld.penguinLogistics() {
    final category = CategoryDefinition(
      id: manualDemoCategoryId,
      createdAt: manualDemoNow,
      updatedAt: manualDemoNow,
      name: _t('Penguin Operations', 'Pinguinbetrieb'),
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
      color: '#4AB6E8',
    );
    final labels = <LabelDefinition>[
      LabelDefinition(
        id: manualDemoProjectLabelId,
        name: 'Project Waddle',
        color: '#1F9CF5',
        createdAt: manualDemoNow,
        updatedAt: manualDemoNow,
        vectorClock: null,
        private: false,
      ),
      LabelDefinition(
        id: manualDemoCriticalLabelId,
        name: _t('Habitat critical', 'Habitat kritisch'),
        color: '#FBA337',
        createdAt: manualDemoNow,
        updatedAt: manualDemoNow,
        vectorClock: null,
        private: false,
      ),
    ];
    final coverImages = manualDemoCoverAssets.entries.map((entry) {
      return JournalImage(
        meta: Metadata(
          id: entry.key,
          createdAt: manualDemoNow,
          updatedAt: manualDemoNow,
          dateFrom: manualDemoNow,
          dateTo: manualDemoNow,
          categoryId: manualDemoCategoryId,
        ),
        data: ImageData(
          capturedAt: manualDemoNow,
          imageId: '${entry.key}-file',
          imageFile: entry.value.split('/').last,
          imageDirectory: '/manual_demo/',
        ),
      );
    }).toList();

    Task task({
      required String id,
      required String title,
      required String description,
      required TaskStatus status,
      required TaskPriority priority,
      required DateTime due,
      required String coverArtId,
      required List<String> labelIds,
      required Duration estimate,
    }) {
      final base = TestTaskFactory.create(
        id: id,
        title: title,
        plainText: description,
        createdAt: manualDemoNow.subtract(const Duration(days: 2)),
        dateFrom: manualDemoNow,
        dateTo: manualDemoNow.add(estimate),
        status: status,
        statusHistory: [status],
        categoryId: manualDemoCategoryId,
        estimate: estimate,
      );
      return base.copyWith(
        meta: base.meta.copyWith(labelIds: labelIds),
        data: base.data.copyWith(
          due: due,
          priority: priority,
          coverArtId: coverArtId,
          coverArtCropX: 0.5,
        ),
      );
    }

    final orbitalStatus = TaskStatus.inProgress(
      id: 'status-orbital-in-progress',
      createdAt: manualDemoNow.subtract(const Duration(hours: 2)),
      utcOffset: 120,
    );
    final feederStatus = TaskStatus.open(
      id: 'status-feeder-open',
      createdAt: manualDemoNow.subtract(const Duration(days: 1)),
      utcOffset: 120,
    );
    final cargoStatus = TaskStatus.groomed(
      id: 'status-cargo-groomed',
      createdAt: manualDemoNow.subtract(const Duration(hours: 20)),
      utcOffset: 120,
    );
    final passengerStatus = TaskStatus.open(
      id: 'status-passenger-open',
      createdAt: manualDemoNow.subtract(const Duration(hours: 10)),
      utcOffset: 120,
    );
    final agendaStatus = TaskStatus.open(
      id: 'status-agenda-open',
      createdAt: manualDemoNow.subtract(const Duration(days: 1)),
      utcOffset: 120,
    );

    return ManualDemoWorld._(
      category: category,
      labels: labels,
      coverImages: coverImages,
      tasks: [
        task(
          id: manualRollCallTaskId,
          title: _t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
          description: _t(
            'Count every expedition penguin, check the tiny oxygen packs, '
                'and record any suspiciously formal salutes.',
            'Zähle alle Expeditionspinguine, prüfe die winzigen Sauerstoffpacks '
                'und notiere verdächtig förmliche Grüße.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p2Medium,
          due: DateTime(2026, 7, 17, 9),
          coverArtId: manualRollCallCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 30),
        ),
        task(
          id: manualOrbitalHabitatTaskId,
          title: _t(
            'Inspect orbital penguin habitat',
            'Pinguin-Habitat im Orbit inspizieren',
          ),
          description: _t(
            'Inspect pressure seals, confirm all 37 emperor penguins are '
                'present, and route the sardine cargo pods before the live '
                'Project Waddle demonstration.',
            'Prüfe die Druckdichtungen, bestätige alle 37 Kaiserpinguine und '
                'route die Sardinen-Frachtkapseln vor der Live-Demo von '
                'Project Waddle.',
          ),
          status: orbitalStatus,
          priority: TaskPriority.p1High,
          due: DateTime(2026, 7, 17, 12),
          coverArtId: manualHabitatCoverImageId,
          labelIds: const [
            manualDemoProjectLabelId,
            manualDemoCriticalLabelId,
          ],
          estimate: const Duration(hours: 2),
        ),
        task(
          id: manualLaunchReviewTaskId,
          title: _t(
            'Project Waddle launch review',
            'Startprüfung für Project Waddle',
          ),
          description: _t(
            'Review the ice-pad trajectory, confirm the snack manifest, '
                'and make sure Mission Control has removed the fish-shaped '
                'cursor from the launch display.',
            'Prüfe die Flugbahn vom Eisstartplatz, bestätige die Snackliste '
                'und stelle sicher, dass die Missionskontrolle den '
                'fischförmigen Mauszeiger entfernt hat.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p1High,
          due: DateTime(2026, 7, 17, 12),
          coverArtId: manualLaunchReviewCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 45),
        ),
        task(
          id: manualLunchTaskId,
          title: _t(
            'Lunch (coffee is not a vegetable)',
            'Mittagessen (Kaffee ist kein Gemüse)',
          ),
          description: _t(
            'Eat something recognizable as food before the robot '
                'nutritionist files another orbital wellness incident.',
            'Iss etwas, das als Essen erkennbar ist, bevor der '
                'Roboter-Ernährungsberater den nächsten orbitalen '
                'Gesundheitsvorfall meldet.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p3Low,
          due: DateTime(2026, 7, 17, 13),
          coverArtId: manualLunchCoverImageId,
          labelIds: const [],
          estimate: const Duration(hours: 1),
        ),
        task(
          id: manualSardineFuturesTaskId,
          title: _t('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
          description: _t(
            "Lock the colony's Q3 sardine price before the Europa exchange "
                'discovers why the emergency fish ceiling is shaped like a '
                'penguin.',
            'Sichere den Sardinenpreis der Kolonie für Q3, bevor die Europa-Börse '
                'entdeckt, warum der Notfall-Fischdeckel wie ein Pinguin aussieht.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p1High,
          due: DateTime(2026, 7, 17, 14, 30),
          coverArtId: manualSardineFuturesCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(hours: 1, minutes: 30),
        ),
        task(
          id: manualFishFeederTaskId,
          title: _t(
            'Recalibrate the zero-gravity fish feeder',
            'Schwerelosen Fischfütterer neu kalibrieren',
          ),
          description: _t(
            'Run the low-orbit sardine test and stop the feeder from '
                'launching lunch toward Mission Control.',
            'Führe den Sardinentest im niedrigen Orbit aus und hindere den '
                'Fütterer daran, das Mittagessen zur Missionskontrolle zu schießen.',
          ),
          status: feederStatus,
          priority: TaskPriority.p0Urgent,
          due: DateTime(2026, 7, 17, 15),
          coverArtId: manualFishFeederCoverImageId,
          labelIds: const [manualDemoCriticalLabelId],
          estimate: const Duration(hours: 1, minutes: 30),
        ),
        task(
          id: manualSardineCargoTaskId,
          title: _t(
            'Confirm the interplanetary sardine cargo pods',
            'Interplanetare Sardinen-Frachtkapseln bestätigen',
          ),
          description: _t(
            'Reconcile the cold-chain manifest with the colony dashboard '
                'before the next supply shuttle leaves Europa.',
            'Gleiche die Kühlketten-Frachtliste mit dem Kolonie-Dashboard ab, '
                'bevor das nächste Versorgungsshuttle Europa verlässt.',
          ),
          status: cargoStatus,
          priority: TaskPriority.p2Medium,
          due: DateTime(2026, 7, 18, 9),
          coverArtId: manualSardineCargoCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 45),
        ),
        task(
          id: manualPenguinPassengerTaskId,
          title: _t(
            'Ask Legal whether a penguin is a passenger',
            'Rechtsabteilung fragen, ob ein Pinguin Passagier ist',
          ),
          description: _t(
            'Resolve whether Sir Flaps-a-Lot needs a boarding pass or a '
                'cargo declaration before launch.',
            'Kläre, ob Sir Flatterviel vor dem Start eine Bordkarte oder eine '
                'Frachtdeklaration braucht.',
          ),
          status: passengerStatus,
          priority: TaskPriority.p3Low,
          due: DateTime(2026, 7, 20, 16),
          coverArtId: manualPenguinPassengerCoverImageId,
          labelIds: const [manualDemoProjectLabelId],
          estimate: const Duration(minutes: 30),
        ),
        task(
          id: manualHeadsetWalkTaskId,
          title: _t('Walk without a headset', 'Spaziergang ohne Headset'),
          description: _t(
            'Take one quiet lap around the orbital ice garden without '
                'turning it into a briefing, podcast, or emergency call.',
            'Dreh eine ruhige Runde durch den orbitalen Eisgarten, ohne daraus '
                'ein Briefing, einen Podcast oder einen Notruf zu machen.',
          ),
          status: agendaStatus,
          priority: TaskPriority.p3Low,
          due: DateTime(2026, 7, 17, 18),
          coverArtId: manualHeadsetWalkCoverImageId,
          labelIds: const [],
          estimate: const Duration(minutes: 30),
        ),
      ],
    );
  }

  final CategoryDefinition category;
  final List<LabelDefinition> labels;
  final List<JournalImage> coverImages;
  final List<Task> tasks;

  Task get orbitalHabitatTask => taskById(manualOrbitalHabitatTaskId);
  Task get fishFeederTask => taskById(manualFishFeederTaskId);
  Task get sardineCargoTask => taskById(manualSardineCargoTaskId);
  Task get penguinPassengerTask => taskById(manualPenguinPassengerTaskId);

  /// Curated first page used by the Tasks manual screenshots.
  ///
  /// The Daily OS fixture resolves the remaining task entities through
  /// [entityById] without crowding this browse-page composition.
  List<Task> get taskBrowseTasks => [
    orbitalHabitatTask,
    fishFeederTask,
    sardineCargoTask,
    penguinPassengerTask,
  ];

  Task taskById(String id) => tasks.singleWhere((task) => task.meta.id == id);

  JournalImage coverImageById(String id) =>
      coverImages.singleWhere((image) => image.meta.id == id);

  JournalEntity? entityById(String id) {
    for (final coverImage in coverImages) {
      if (id == coverImage.meta.id) return coverImage;
    }
    for (final task in tasks) {
      if (task.meta.id == id) return task;
    }
    return null;
  }

  /// Copies the bundled artwork into the same document-relative path used by
  /// production cover-art widgets.
  Future<List<File>> installMedia(Directory documentsDirectory) async {
    final installedFiles = <File>[];
    for (final coverImage in coverImages) {
      final target = File(
        getFullImagePath(
          coverImage,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      await target.parent.create(recursive: true);
      installedFiles.add(
        await File(
          manualDemoCoverAssets[coverImage.meta.id]!,
        ).copy(target.path),
      );
    }
    return installedFiles;
  }
}

/// Primes the production image-provider keys with decoded cover art.
///
/// The headless Flutter test engine can leave resized WebP decoding pending
/// indefinitely even though the raw file decodes successfully. Production
/// widgets still construct and resolve their normal providers; this helper
/// only seeds the test image cache before the first frame so screenshots paint
/// the same bitmap deterministically. Raw [FileImage] keys can also be primed
/// for production surfaces that render unresized reference images.
Future<void> primeManualDemoCoverArt(
  WidgetTester tester, {
  required Directory documentsDirectory,
  required ManualDemoWorld world,
  List<int> extents = const [48, 96, 144, 216, 1280, 2048, 3072],
  Set<String>? imageIds,
  bool includeRawFileImage = false,
}) async {
  await tester.runAsync(() async {
    final coverImages = imageIds == null
        ? world.coverImages
        : world.coverImages.where(
            (coverImage) => imageIds.contains(coverImage.meta.id),
          );
    for (final coverImage in coverImages) {
      final file = File(
        getFullImagePath(
          coverImage,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      final fileImage = FileImage(file);
      final bytes = await file.readAsBytes();
      final cache = PaintingBinding.instance.imageCache;
      if (includeRawFileImage) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final key = await fileImage.obtainKey(ImageConfiguration.empty);
        cache
          ..evict(key)
          ..putIfAbsent(
            key,
            () => OneFrameImageStreamCompleter(
              SynchronousFuture(
                ImageInfo(image: frame.image.clone()),
              ),
            ),
          );
        frame.image.dispose();
        codec.dispose();
      }
      for (final extent in extents) {
        final providers = [
          ResizeImage(
            fileImage,
            width: extent,
            height: extent,
            policy: ResizeImagePolicy.fit,
          ),
          ResizeImage(
            fileImage,
            width: extent,
            policy: ResizeImagePolicy.fit,
          ),
        ];
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: extent,
          allowUpscaling: false,
        );
        final frame = await codec.getNextFrame();
        for (final provider in providers) {
          final key = await provider.obtainKey(ImageConfiguration.empty);
          cache
            ..evict(key)
            ..putIfAbsent(
              key,
              () => OneFrameImageStreamCompleter(
                SynchronousFuture(
                  ImageInfo(image: frame.image.clone()),
                ),
              ),
            );
        }
        frame.image.dispose();
        codec.dispose();
      }
    }
  });
}
