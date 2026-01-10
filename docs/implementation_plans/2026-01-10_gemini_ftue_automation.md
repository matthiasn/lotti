# Gemini FTUE Automation - Implementation Plan

**Date:** 2026-01-10
**Status:** Implemented

## Overview

Automate the First Time User Experience (FTUE) for new users creating a Gemini provider. When a Gemini provider is created, the system will automatically generate specific models, prompt variants, and a configured test category with auto-selection logic.

---

## Current State Analysis

### Existing Infrastructure

| Component | File | Description |
|-----------|------|-------------|
| Provider Prompt Setup | `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart` | Existing service that offers prompt creation after provider setup |
| Preconfigured Prompts | `lib/features/ai/util/preconfigured_prompts.dart` | Template prompts for common AI tasks |
| Known Models | `lib/features/ai/util/known_models.dart` | Predefined model configurations per provider type |
| AI Config Repository | `lib/features/ai/repository/ai_config_repository.dart` | CRUD for providers, models, and prompts |
| Category Repository | `lib/features/categories/repository/categories_repository.dart` | CRUD for categories |
| Category Definition | `lib/classes/entity_definitions.dart` | Includes `allowedPromptIds` and `automaticPrompts` fields |

### Current Provider Prompt Setup Service

The existing `ProviderPromptSetupService`:
- Supports Gemini and Ollama providers
- Creates 4 prompts for Gemini (Audio Transcription, Image Analysis in Task Context, Checklist Updates, Task Summary)
- Names prompts as `"{PromptName} - {ModelName}"` (e.g., "Task Summary - Gemini 2.5 Pro")
- Shows a confirmation dialog before creation
- Does **NOT** create models (assumes they already exist)
- Does **NOT** create categories

### Key Models in Known Models

From `geminiModels` in `known_models.dart`:
```
models/gemini-3-pro-image-preview   -> "Gemini 3 Pro Image (Nano Banana Pro)"
models/gemini-3-pro-preview         -> "Gemini 3 Pro Preview"
models/gemini-3-flash-preview       -> "Gemini 3 Flash Preview"
models/gemini-2.5-pro               -> "Gemini 2.5 Pro"
models/gemini-2.5-flash             -> "Gemini 2.5 Flash"
```

---

## Requirements Summary

### 1. Model Creation
Create/verify three models for the Gemini provider:
- **Gemini 3 Flash Preview** → `models/gemini-3-flash-preview` (fast text/audio/image input)
- **Gemini 3 Pro Preview** → `models/gemini-3-pro-preview` (reasoning tasks)
- **Nano Banana Pro** → `models/gemini-3-pro-image-preview` (image generation output)

Verify existence by checking `providerModelId` matches before creating.

### 2. Prompt Variant Creation
Create both **Flash** and **Pro** variants for 9 prompt types:

| Preconfigured Prompt ID | Display Name | Flash Prompt Name | Pro Prompt Name |
|------------------------|--------------|-------------------|-----------------|
| `audio_transcription` | Audio Transcription | Audio Transcription Gemini Flash | Audio Transcription Gemini Pro |
| `audio_transcription_task_context` | Audio Transcription with Task Context | Audio Transcription (Task Context) Gemini Flash | Audio Transcription (Task Context) Gemini Pro |
| `task_summary` | Task Summary | Task Summary Gemini Flash | Task Summary Gemini Pro |
| `checklist_updates` | Checklist Updates | Checklist Gemini Flash | Checklist Gemini Pro |
| `image_analysis` | Image Analysis | Image Analysis Gemini Flash | Image Analysis Gemini Pro |
| `image_analysis_task_context` | Image Analysis in Task Context | Image Analysis (Task Context) Gemini Flash | Image Analysis (Task Context) Gemini Pro |
| `prompt_generation` | Generate Coding Prompt | Coding Prompt Gemini Flash | Coding Prompt Gemini Pro |
| `image_prompt_generation` | Generate Image Prompt | Image Prompt Gemini Flash | Image Prompt Gemini Pro |
| `cover_art_generation` | Generate Cover Art | Cover Art Gemini Flash | Cover Art Gemini Pro* |

**Total: 18 prompts** (9 Flash + 9 Pro)

*Note: Cover Art prompts use the **Nano Banana Pro** (image output) model, not the text Pro model.

### 3. Category Setup
- Create category named "Test Category Gemini Enabled"
- Enable all 18 prompts via `allowedPromptIds`
- Configure `automaticPrompts` for auto-run

### 4. Auto-Selection Logic
Configure `automaticPrompts` map on the category:

| AiResponseType | Selected Prompt Variant | Model Used | Reasoning Mode |
|----------------|------------------------|------------|----------------|
| `audioTranscription` | Flash | Gemini 3 Flash Preview | useReasoning=true (thinking) |
| `imageAnalysis` | Flash | Gemini 3 Flash Preview | useReasoning=true (thinking) |
| `taskSummary` | Flash | Gemini 3 Flash Preview | useReasoning=true (thinking) |
| `checklistUpdates` | **Pro** | Gemini 3 Pro Preview | useReasoning=true |
| `promptGeneration` | **Pro** | Gemini 3 Pro Preview | useReasoning=true |
| `imagePromptGeneration` | Flash | Gemini 3 Flash Preview | useReasoning=true (thinking) |
| `imageGeneration` | Pro* | **Nano Banana Pro** | useReasoning=false |

*Cover art/image generation uses the Nano Banana Pro (image output) model.

### 5. User Feedback
Display summary of what was created:
- Number of models created/verified
- Number of prompts created
- Category created with configuration

### 6. Automatic Gemini Setup Prompt
Display a modal prompting users to set up Gemini when no Gemini provider/models exist:
- **Trigger:** App open when no Gemini models are defined
- **Persistence:** Track dismissal state to avoid repeated prompts
- **Behavior:**
  - First app open: Show modal asking "Would you like to set up Gemini?"
  - Subsequent opens: Show again unless explicitly dismissed or Gemini is set up
  - After dismissal: Don't show again (persisted preference)
- **Action:** Route to AI Settings > Providers with Gemini pre-selected

---

## Design Decisions

### Q1: Which models should be created for FTUE?
**Decision:** Create three models with standard naming (no "Nano Banana" for text models):
- **Gemini 3 Flash Preview** (`models/gemini-3-flash-preview`) - fast text/audio/image input
- **Gemini 3 Pro Preview** (`models/gemini-3-pro-preview`) - reasoning tasks
- **Nano Banana Pro** (`models/gemini-3-pro-image-preview`) - image generation output (only this one uses "Nano Banana")

**Rationale:** "Nano Banana" naming is reserved exclusively for the image generation model. Text models use standard Gemini naming to avoid confusion.

### Q2: Should we extend the existing service or create a new one?
**Decision:** Extend `ProviderPromptSetupService` with a new method for comprehensive FTUE setup.

**Rationale:** Keeps related functionality together, allows reuse of existing helper methods.

### Q3: How to handle existing prompts/models with same name?
**Decision:** Check by `providerModelId` for models and `preconfiguredPromptId + defaultModelId` for prompts. Skip if exists.

**Rationale:** Using stable identifiers (`preconfiguredPromptId` + `defaultModelId`) instead of name-based matching prevents duplicates reliably, even if users rename prompts. This approach is more robust than name suffix matching.

### Q4: Should the category creation be optional?
**Decision:** Always create the category as part of FTUE setup.

**Rationale:** Simpler flow - no checkbox needed. Category provides immediate value for testing.

### Q5: Where should the automatic Gemini setup prompt be triggered?
**Decision:** Trigger from a high-level app widget (e.g., `HomePage` or `AppShell`) after initial load, checking for Gemini provider existence.

**Rationale:** Ensures the prompt appears early in the user journey without blocking app startup.

### Q6: How should the dismissal state be persisted?
**Decision:** Use `SharedPreferences` with a key like `gemini_setup_prompt_dismissed`.

**Rationale:** Simple, reliable persistence that survives app restarts. No need for database storage since this is a one-time user preference.

### Q7: What happens if the user dismisses but later wants to set up Gemini?
**Decision:** Users can always manually navigate to Settings > AI > Providers to add Gemini. The automatic prompt is just a convenience for FTUE.

**Rationale:** The prompt is a helper, not a gatekeeper. Users retain full control.

### Q8: Auto-selection logic for prompts in the test category?
**Decision:**
- **Pro model:** Checklist Updates, Generate Coding Prompt (need stronger reasoning)
- **Flash model with thinking:** All other prompts (Audio, Image, Task Summary, etc.)

**Rationale:** Flash with `useReasoning=true` enables thinking mode in Gemini 3 Flash, providing good reasoning at faster speed. Pro reserved for function-calling (Checklist) and code generation tasks.

---

## Data Flow

### Flow 1: Automatic Gemini Setup Prompt (New Users)

```
                         App Opens
                             |
                             v
              Check: Any Gemini providers exist?
                             |
              +--------------+--------------+
              |                             |
              v                             v
         (Yes, exists)               (No, none exist)
              |                             |
              v                             v
        No action needed         Check: Was prompt dismissed?
                                            |
                              +-------------+-------------+
                              |                           |
                              v                           v
                     (Yes, dismissed)           (No, not dismissed)
                              |                           |
                              v                           v
                     No action needed        Show Gemini Setup Modal
                                                         |
                                          +--------------+--------------+
                                          |                             |
                                          v                             v
                                   User: "Set Up"              User: "Not Now"
                                          |                             |
                                          v                             v
                               Navigate to AI Settings      Persist dismissal
                               Providers (Gemini selected)  (SharedPreferences)
                                          |
                                          v
                               User creates Gemini provider
                                          |
                                          v
                               (Continue to Flow 2)
```

### Flow 2: Post-Provider Creation FTUE

```
                    User Creates Gemini Provider
                              |
                              v
                  ProviderPromptSetupService
                              |
           +------------------+------------------+
           |                                     |
           v                                     v
    Show Enhanced Dialog               (if user declines)
    - Preview models                   Return without setup
    - Preview prompts
    - Option to create category
           |
           v
    User Confirms "Set Up Everything"
           |
           v
    +------+------+
    |             |
    v             v
 Create/Verify  Create 18
 2 Models       Prompts
    |             |
    +------+------+
           |
           v
    Create Category
    - Set allowedPromptIds (all 18)
    - Set automaticPrompts (5 configs)
           |
           v
    Show Result Dialog
    - Models: 2 created/verified
    - Prompts: 18 created
    - Category: 1 created
```

---

## Implementation Plan

### Phase 1: Define Model Specifications

#### 1.1 Add FTUE Model Constants

**File:** `lib/features/ai/util/known_models.dart`

Add constants for the three models used in FTUE:

```dart
/// Models used for FTUE automation - Gemini 3 Preview series
/// Text models (Flash for speed, Pro for reasoning)
const ftueFlashModelId = 'models/gemini-3-flash-preview';
const ftueProModelId = 'models/gemini-3-pro-preview';

/// Image generation model (Nano Banana Pro)
const ftueImageModelId = 'models/gemini-3-pro-image-preview';

/// Display names match existing known_models entries
const ftueFlashDisplayName = 'Gemini 3 Flash Preview';
const ftueProDisplayName = 'Gemini 3 Pro Preview';
const ftueImageDisplayName = 'Gemini 3 Pro Image (Nano Banana Pro)';
```

**Rationale:** Uses existing model names from `geminiModels` list. Three models cover all use cases: Flash for speed, Pro for reasoning, Nano Banana Pro for image generation.

---

### Phase 2: Extend Provider Prompt Setup Service

#### 2.1 Create Result Data Classes

**File:** `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart`

Add new data classes for tracking setup results:

```dart
/// Result of the FTUE setup process
class FtueSetupResult {
  const FtueSetupResult({
    required this.modelsCreated,
    required this.modelsVerified,
    required this.promptsCreated,
    required this.categoryCreated,
    required this.categoryName,
    this.errors = const [],
  });

  final int modelsCreated;
  final int modelsVerified;
  final int promptsCreated;
  final bool categoryCreated;
  final String? categoryName;
  final List<String> errors;
}

/// Configuration for a model to create during FTUE
class ModelSetupConfig {
  const ModelSetupConfig({
    required this.providerModelId,
    required this.displayName,
    required this.knownModel,
  });

  final String providerModelId;
  final String displayName;
  final KnownModel knownModel;
}

/// Configuration for prompts to create during FTUE
class PromptSetupConfig {
  const PromptSetupConfig({
    required this.template,
    required this.modelVariant,
    required this.promptName,
  });

  final PreconfiguredPrompt template;
  final String modelVariant; // 'flash' or 'pro'
  final String promptName;
}
```

#### 2.2 Add FTUE Setup Method

**File:** `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart`

Add new method for comprehensive FTUE setup:

```dart
/// Performs comprehensive FTUE setup for Gemini providers.
///
/// This creates:
/// 1. Nano Banana and Nano Banana Pro models (if not exist)
/// 2. Flash and Pro variants for all 9 prompt types (18 prompts)
/// 3. A test category with all prompts enabled and auto-selection configured
///
/// Returns [FtueSetupResult] with details of what was created.
Future<FtueSetupResult?> performGeminiFtueSetup({
  required BuildContext context,
  required WidgetRef ref,
  required AiConfigInferenceProvider provider,
  required bool createCategory,
}) async {
  // Implementation in Phase 2.3-2.6
}
```

#### 2.3 Implement Model Creation/Verification

```dart
Future<({List<AiConfigModel> created, List<AiConfigModel> verified})>
    _ensureModelsExist({
  required AiConfigRepository repository,
  required String providerId,
  required List<ModelSetupConfig> modelConfigs,
}) async {
  final allModels = await repository.getConfigsByType(AiConfigType.model);
  final providerModels = allModels
      .whereType<AiConfigModel>()
      .where((m) => m.inferenceProviderId == providerId)
      .toList();

  final created = <AiConfigModel>[];
  final verified = <AiConfigModel>[];

  for (final config in modelConfigs) {
    // Check if model with same providerModelId already exists
    final existing = providerModels.firstWhereOrNull(
      (m) => m.providerModelId == config.providerModelId,
    );

    if (existing != null) {
      verified.add(existing);
    } else {
      // Create new model
      final newModel = config.knownModel.toAiConfigModel(
        id: const Uuid().v4(),
        inferenceProviderId: providerId,
      ).copyWith(name: config.displayName);

      await repository.saveConfig(newModel);
      created.add(newModel);
    }
  }

  return (created: created, verified: verified);
}
```

#### 2.4 Implement Prompt Creation

```dart
Future<List<AiConfigPrompt>> _createPrompts({
  required AiConfigRepository repository,
  required AiConfigModel flashModel,
  required AiConfigModel proModel,
  required AiConfigModel imageModel,
}) async {
  final prompts = <AiConfigPrompt>[];
  const uuid = Uuid();

  // Get existing prompts to check for duplicates
  final existingPrompts = await repository.getConfigsByType(AiConfigType.prompt);
  final existingPromptSet = existingPrompts
      .whereType<AiConfigPrompt>()
      .map((p) => '${p.preconfiguredPromptId}_${p.defaultModelId}')
      .toSet();

  // Define all prompt configurations
  final promptConfigs = _getGeminiFtuePromptConfigs(
    flashModel: flashModel,
    proModel: proModel,
    imageModel: imageModel,
  );

  for (final config in promptConfigs) {
    final model = switch (config.modelVariant) {
      'flash' => flashModel,
      'pro' => proModel,
      'image' => imageModel,
      _ => flashModel,
    };

    // Check for existing prompt with same preconfiguredPromptId + modelId
    final key = '${config.template.id}_${model.id}';
    if (existingPromptSet.contains(key)) {
      // Skip - prompt already exists for this template + model combination
      continue;
    }

    final prompt = AiConfig.prompt(
      id: uuid.v4(),
      name: config.promptName,
      systemMessage: config.template.systemMessage,
      userMessage: config.template.userMessage,
      defaultModelId: model.id,
      modelIds: [model.id],
      createdAt: DateTime.now(),
      useReasoning: config.template.useReasoning,
      requiredInputData: config.template.requiredInputData,
      aiResponseType: config.template.aiResponseType,
      description: config.template.description,
      trackPreconfigured: true,
      preconfiguredPromptId: config.template.id,
      defaultVariables: config.template.defaultVariables,
    );

    await repository.saveConfig(prompt);
    prompts.add(prompt);
  }

  return prompts;
}

List<PromptSetupConfig> _getGeminiFtuePromptConfigs({
  required AiConfigModel flashModel,
  required AiConfigModel proModel,
  required AiConfigModel imageModel, // Nano Banana Pro for image generation
}) {
  return [
    // Audio Transcription variants
    PromptSetupConfig(
      template: audioTranscriptionPrompt,
      modelVariant: 'flash',
      promptName: 'Audio Transcription Gemini Flash',
    ),
    PromptSetupConfig(
      template: audioTranscriptionPrompt,
      modelVariant: 'pro',
      promptName: 'Audio Transcription Gemini Pro',
    ),

    // Audio Transcription with Task Context variants
    PromptSetupConfig(
      template: audioTranscriptionWithTaskContextPrompt,
      modelVariant: 'flash',
      promptName: 'Audio Transcription (Task Context) Gemini Flash',
    ),
    PromptSetupConfig(
      template: audioTranscriptionWithTaskContextPrompt,
      modelVariant: 'pro',
      promptName: 'Audio Transcription (Task Context) Gemini Pro',
    ),

    // Task Summary variants
    PromptSetupConfig(
      template: taskSummaryPrompt,
      modelVariant: 'flash',
      promptName: 'Task Summary Gemini Flash',
    ),
    PromptSetupConfig(
      template: taskSummaryPrompt,
      modelVariant: 'pro',
      promptName: 'Task Summary Gemini Pro',
    ),

    // Checklist variants
    PromptSetupConfig(
      template: checklistUpdatesPrompt,
      modelVariant: 'flash',
      promptName: 'Checklist Gemini Flash',
    ),
    PromptSetupConfig(
      template: checklistUpdatesPrompt,
      modelVariant: 'pro',
      promptName: 'Checklist Gemini Pro',
    ),

    // Image Analysis variants
    PromptSetupConfig(
      template: imageAnalysisPrompt,
      modelVariant: 'flash',
      promptName: 'Image Analysis Gemini Flash',
    ),
    PromptSetupConfig(
      template: imageAnalysisPrompt,
      modelVariant: 'pro',
      promptName: 'Image Analysis Gemini Pro',
    ),

    // Image Analysis in Task Context variants
    PromptSetupConfig(
      template: imageAnalysisInTaskContextPrompt,
      modelVariant: 'flash',
      promptName: 'Image Analysis (Task Context) Gemini Flash',
    ),
    PromptSetupConfig(
      template: imageAnalysisInTaskContextPrompt,
      modelVariant: 'pro',
      promptName: 'Image Analysis (Task Context) Gemini Pro',
    ),

    // Generate Coding Prompt variants
    PromptSetupConfig(
      template: promptGenerationPrompt,
      modelVariant: 'flash',
      promptName: 'Coding Prompt Gemini Flash',
    ),
    PromptSetupConfig(
      template: promptGenerationPrompt,
      modelVariant: 'pro',
      promptName: 'Coding Prompt Gemini Pro',
    ),

    // Generate Image Prompt variants
    PromptSetupConfig(
      template: imagePromptGenerationPrompt,
      modelVariant: 'flash',
      promptName: 'Image Prompt Gemini Flash',
    ),
    PromptSetupConfig(
      template: imagePromptGenerationPrompt,
      modelVariant: 'pro',
      promptName: 'Image Prompt Gemini Pro',
    ),

    // Cover Art Generation variants (uses Nano Banana Pro image model)
    PromptSetupConfig(
      template: coverArtGenerationPrompt,
      modelVariant: 'flash', // Actually uses Flash for the "Flash" variant
      promptName: 'Cover Art Gemini Flash',
    ),
    PromptSetupConfig(
      template: coverArtGenerationPrompt,
      modelVariant: 'image', // Uses Nano Banana Pro (image output model)
      promptName: 'Cover Art Gemini Pro',
    ),
  ];
}
```

#### 2.5 Implement Category Creation

```dart
/// Creates or updates the FTUE test category with all prompts enabled and auto-selection.
///
/// If the category already exists, it will be updated with the new prompts.
/// Returns a tuple of (category, wasCreated) where wasCreated is true if
/// a new category was created, false if an existing one was updated.
Future<(CategoryDefinition?, bool)> _createOrUpdateFtueCategory({
  required CategoryRepository categoryRepository,
  required List<AiConfigPrompt> prompts,
  required String flashModelId,
  required String proModelId,
  required String imageModelId,
}) async {
  const categoryName = 'Test Category Gemini Enabled';

  // Build allowedPromptIds from all created prompts
  final allowedPromptIds = prompts.map((p) => p.id).toList();

  // Build automaticPrompts map with auto-selection logic using stable IDs
  final automaticPrompts = _buildAutomaticPromptsMap(
    prompts,
    flashModelId: flashModelId,
    proModelId: proModelId,
    imageModelId: imageModelId,
  );

  // Check if category already exists
  final allCategories = await categoryRepository.getAllCategories();
  final existingCategory = allCategories
      .where((c) => c.name == categoryName && c.deletedAt == null)
      .firstOrNull;

  if (existingCategory != null) {
    // Update existing category with new prompts
    final updatedCategory = existingCategory.copyWith(
      allowedPromptIds: allowedPromptIds,
      automaticPrompts: automaticPrompts,
    );

    await categoryRepository.updateCategory(updatedCategory);
    return (updatedCategory, false); // false = was updated, not created
  }

  // Create new category
  final category = await categoryRepository.createCategory(
    name: categoryName,
    color: '#4285F4', // Google Blue
  );

  // Update with prompts configuration
  final updatedCategory = category.copyWith(
    allowedPromptIds: allowedPromptIds,
    automaticPrompts: automaticPrompts,
  );

  await categoryRepository.updateCategory(updatedCategory);

  return (updatedCategory, true); // true = was created
}

/// Builds the automaticPrompts map with FTUE auto-selection logic.
///
/// Uses stable identifiers (preconfiguredPromptId + modelId) for matching
/// instead of fragile name-based matching.
///
/// Auto-selection rules:
/// - Checklist, Coding Prompt: Pro model
/// - Image Generation: Nano Banana Pro (image model)
/// - Everything else: Flash with thinking
Map<AiResponseType, List<String>> _buildAutomaticPromptsMap(
  List<AiConfigPrompt> prompts, {
  required String flashModelId,
  required String proModelId,
  required String imageModelId,
}) {
  final map = <AiResponseType, List<String>>{};

  // Helper to find prompt by preconfiguredPromptId + modelId
  // This is more stable than name-based matching
  String? findPromptId(String preconfiguredId, String modelId) {
    return prompts
        .firstWhereOrNull(
          (p) =>
              p.preconfiguredPromptId == preconfiguredId &&
              p.defaultModelId == modelId,
        )
        ?.id;
  }

  // Audio Transcription -> Flash
  final audioFlash = findPromptId('audio_transcription', flashModelId);
  if (audioFlash != null) {
    map[AiResponseType.audioTranscription] = [audioFlash];
  }

  // Image Analysis (task context) -> Flash
  final imageFlash = findPromptId('image_analysis_task_context', flashModelId);
  if (imageFlash != null) {
    map[AiResponseType.imageAnalysis] = [imageFlash];
  }

  // Task Summary -> Flash
  final summaryFlash = findPromptId('task_summary', flashModelId);
  if (summaryFlash != null) {
    map[AiResponseType.taskSummary] = [summaryFlash];
  }

  // Checklist Updates -> Pro (needs stronger reasoning)
  final checklistPro = findPromptId('checklist_updates', proModelId);
  if (checklistPro != null) {
    map[AiResponseType.checklistUpdates] = [checklistPro];
  }

  // Prompt Generation -> Pro (code prompts need stronger reasoning)
  final promptGenPro = findPromptId('prompt_generation', proModelId);
  if (promptGenPro != null) {
    map[AiResponseType.promptGeneration] = [promptGenPro];
  }

  // Image Prompt Generation -> Flash
  final imagePromptFlash = findPromptId('image_prompt_generation', flashModelId);
  if (imagePromptFlash != null) {
    map[AiResponseType.imagePromptGeneration] = [imagePromptFlash];
  }

  // Image Generation -> Image model (Nano Banana Pro)
  final imageGenImage = findPromptId('cover_art_generation', imageModelId);
  if (imageGenImage != null) {
    map[AiResponseType.imageGeneration] = [imageGenImage];
  }

  return map;
}
```

#### 2.6 Implement Enhanced Confirmation Dialog

**File:** `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart`

Add new dialog method for FTUE with category option:

```dart
Future<({bool proceed, bool createCategory})?> _showFtueSetupDialog(
  BuildContext context, {
  required String providerName,
  required List<ModelSetupConfig> models,
  required List<PromptSetupConfig> prompts,
}) async {
  return showDialog<({bool proceed, bool createCategory})>(
    context: context,
    builder: (context) => _FtueSetupDialog(
      providerName: providerName,
      modelCount: models.length,
      promptCount: prompts.length,
    ),
  );
}
```

---

### Phase 3: Create FTUE Setup Dialog Widget

#### 3.1 Create Dialog Widget

**New file:** `lib/features/ai/ui/settings/widgets/ftue_setup_dialog.dart`

```dart
class FtueSetupDialog extends StatelessWidget {
  const FtueSetupDialog({
    required this.providerName,
    required this.modelCount,
    required this.promptCount,
    super.key,
  });

  final String providerName;
  final int modelCount;
  final int promptCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: _buildTitle(context),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(context),
            const SizedBox(height: 16),
            _buildPreviewSection(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No Thanks'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Set Up'),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What will be created:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Models section
          _buildPreviewItem(
            context,
            icon: Icons.memory,
            title: '$modelCount Models',
            subtitle: 'Flash, Pro, and Nano Banana Pro (image)',
          ),
          const SizedBox(height: 8),

          // Prompts section
          _buildPreviewItem(
            context,
            icon: Icons.chat_bubble_outline,
            title: '$promptCount Prompts',
            subtitle: 'Flash & Pro variants for 9 prompt types',
          ),
          const SizedBox(height: 8),

          // Category section (always created)
          _buildPreviewItem(
            context,
            icon: Icons.folder_outlined,
            title: '1 Category',
            subtitle: 'Test Category Gemini Enabled',
          ),
        ],
      ),
    );
  }

  // ... additional helper methods
}
```

---

### Phase 4: Create Result Display Dialog

#### 4.1 Create Result Dialog Widget

**New file:** `lib/features/ai/ui/settings/widgets/ftue_result_dialog.dart`

```dart
class FtueResultDialog extends StatelessWidget {
  const FtueResultDialog({
    required this.result,
    super.key,
  });

  final FtueSetupResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Setup Complete'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultItem(
            context,
            icon: Icons.memory,
            label: 'Models',
            value: '${result.modelsCreated} created, ${result.modelsVerified} verified',
          ),
          const SizedBox(height: 8),
          _buildResultItem(
            context,
            icon: Icons.chat_bubble_outline,
            label: 'Prompts',
            value: '${result.promptsCreated} created',
          ),
          if (result.categoryCreated) ...[
            const SizedBox(height: 8),
            _buildResultItem(
              context,
              icon: Icons.folder_outlined,
              label: 'Category',
              value: result.categoryName ?? 'Created',
            ),
          ],
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Warnings:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            ...result.errors.map((e) => Text(
              '- $e',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            )),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildResultItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
```

---

### Phase 5: Integration

#### 5.1 Update Inference Provider Edit Page

**File:** `lib/features/ai/ui/settings/inference_provider_edit_page.dart`

Update the post-save hook to use the new FTUE setup:

```dart
// After successful provider save
if (provider.inferenceProviderType == InferenceProviderType.gemini) {
  await ref.read(providerPromptSetupServiceProvider).performGeminiFtueSetup(
    context: context,
    ref: ref,
    provider: savedProvider,
    createCategory: true, // From dialog
  );
}
```

---

### Phase 6: Automatic Gemini Setup Prompt

#### 6.1 Create Gemini Setup Prompt Service

**New file:** `lib/features/ai/ui/settings/services/gemini_setup_prompt_service.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'gemini_setup_prompt_service.g.dart';

/// Key for storing whether the Gemini setup prompt was dismissed
const _dismissedKey = 'gemini_setup_prompt_dismissed';

/// Service that manages the automatic Gemini setup prompt for new users.
///
/// This service:
/// 1. Checks if any Gemini providers exist
/// 2. Tracks whether the user has dismissed the prompt
/// 3. Determines whether to show the setup prompt
@riverpod
class GeminiSetupPromptService extends _$GeminiSetupPromptService {
  @override
  Future<bool> build() async {
    return _shouldShowPrompt();
  }

  /// Checks whether the setup prompt should be shown.
  ///
  /// Returns true if:
  /// - No Gemini providers exist AND
  /// - The user hasn't dismissed the prompt
  Future<bool> _shouldShowPrompt() async {
    // Check if any Gemini providers exist
    final hasGeminiProvider = await _hasGeminiProvider();
    if (hasGeminiProvider) {
      return false;
    }

    // Check if prompt was dismissed
    final wasDismissed = await _wasPromptDismissed();
    return !wasDismissed;
  }

  /// Checks if any Gemini inference providers exist.
  Future<bool> _hasGeminiProvider() async {
    final repository = ref.read(aiConfigRepositoryProvider);
    final providers = await repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );

    return providers
        .whereType<AiConfigInferenceProvider>()
        .any((p) => p.inferenceProviderType == InferenceProviderType.gemini);
  }

  /// Checks if the prompt was previously dismissed.
  Future<bool> _wasPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  /// Marks the prompt as dismissed so it won't show again.
  Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    state = const AsyncValue.data(false);
  }

  /// Resets the dismissal state (useful for testing or user preference reset).
  Future<void> resetDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
    ref.invalidateSelf();
  }
}
```

#### 6.2 Create Gemini Setup Prompt Modal

**New file:** `lib/features/ai/ui/settings/widgets/gemini_setup_prompt_modal.dart`

```dart
class GeminiSetupPromptModal extends StatelessWidget {
  const GeminiSetupPromptModal({
    required this.onSetUp,
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onSetUp;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Set Up AI Features?'),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Would you like to set up Gemini AI?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFeatureItem(
                  context,
                  icon: Icons.mic,
                  text: 'Audio transcription',
                ),
                const SizedBox(height: 8),
                _buildFeatureItem(
                  context,
                  icon: Icons.image,
                  text: 'Image analysis',
                ),
                const SizedBox(height: 8),
                _buildFeatureItem(
                  context,
                  icon: Icons.checklist,
                  text: 'Smart checklists',
                ),
                const SizedBox(height: 8),
                _buildFeatureItem(
                  context,
                  icon: Icons.summarize,
                  text: 'Task summaries',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You can always set this up later in Settings.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('Not Now'),
        ),
        FilledButton.icon(
          onPressed: onSetUp,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Set Up Gemini'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
```

#### 6.3 Create Trigger Widget

**New file:** `lib/features/ai/ui/settings/widgets/gemini_setup_prompt_trigger.dart`

```dart
/// A widget that automatically shows the Gemini setup prompt when appropriate.
///
/// Place this widget high in the widget tree (e.g., in HomePage or AppShell)
/// to trigger the prompt on app open.
class GeminiSetupPromptTrigger extends ConsumerStatefulWidget {
  const GeminiSetupPromptTrigger({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<GeminiSetupPromptTrigger> createState() =>
      _GeminiSetupPromptTriggerState();
}

class _GeminiSetupPromptTriggerState
    extends ConsumerState<GeminiSetupPromptTrigger> {
  bool _hasShownPrompt = false;

  @override
  Widget build(BuildContext context) {
    // Watch the service to know when to show the prompt
    final shouldShowAsync = ref.watch(geminiSetupPromptServiceProvider);

    // Show prompt once after first successful load
    shouldShowAsync.whenData((shouldShow) {
      if (shouldShow && !_hasShownPrompt) {
        _hasShownPrompt = true;
        // Use post-frame callback to avoid showing during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPromptModal();
        });
      }
    });

    return widget.child;
  }

  Future<void> _showPromptModal() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GeminiSetupPromptModal(
        onSetUp: () {
          Navigator.of(context).pop();
          _navigateToGeminiSetup();
        },
        onDismiss: () {
          Navigator.of(context).pop();
          ref.read(geminiSetupPromptServiceProvider.notifier).dismissPrompt();
        },
      ),
    );
  }

  void _navigateToGeminiSetup() {
    // Navigate to AI Settings > Providers with Gemini pre-selected
    // Uses AiSettingsNavigationService (Beamer-based navigation)
    AiSettingsNavigationService.navigateToCreateProvider(
      context,
      preselectedType: InferenceProviderType.gemini,
    );
  }
}
```

#### 6.4 Integrate Trigger into App

**File:** `lib/pages/home/home_page.dart` (or equivalent high-level widget)

Wrap the main content with the trigger:

```dart
@override
Widget build(BuildContext context) {
  return GeminiSetupPromptTrigger(
    child: Scaffold(
      // ... existing content
    ),
  );
}
```

---

### Phase 7: Testing

#### 7.1 Unit Tests for FTUE Setup

**New file:** `test/features/ai/ui/settings/services/provider_prompt_setup_service_ftue_test.dart`

Test cases:
- Model creation when models don't exist
- Model verification when models already exist
- Prompt creation with correct naming
- Category creation with correct `allowedPromptIds`
- Auto-selection logic correctness
- Error handling for partial failures

#### 7.2 Unit Tests for Gemini Setup Prompt

**New file:** `test/features/ai/ui/settings/services/gemini_setup_prompt_service_test.dart`

Test cases:
- Returns true when no Gemini provider exists and not dismissed
- Returns false when Gemini provider exists
- Returns false when prompt was dismissed
- `dismissPrompt()` persists dismissal and updates state
- `resetDismissal()` clears persisted state

#### 7.3 Widget Tests for FTUE Dialogs

**New file:** `test/features/ai/ui/settings/widgets/ftue_setup_dialog_test.dart`

Test cases:
- Dialog renders correctly
- Category checkbox toggles state
- Confirm returns correct result
- Cancel returns null

**New file:** `test/features/ai/ui/settings/widgets/ftue_result_dialog_test.dart`

Test cases:
- Result display shows correct counts
- Errors are displayed when present
- Done button closes dialog

#### 7.4 Widget Tests for Gemini Setup Prompt

**New file:** `test/features/ai/ui/settings/widgets/gemini_setup_prompt_modal_test.dart`

Test cases:
- Modal renders with correct content
- Feature list displays all items
- "Set Up Gemini" button calls onSetUp callback
- "Not Now" button calls onDismiss callback

**New file:** `test/features/ai/ui/settings/widgets/gemini_setup_prompt_trigger_test.dart`

Test cases:
- Shows modal when shouldShow is true
- Does not show modal when shouldShow is false
- Only shows modal once per session
- Navigates to correct route on setup
- Calls dismissPrompt on dismiss

---

## Implementation Order

| Step | Task | Files |
|------|------|-------|
| 1 | Add model constants to known_models.dart | `lib/features/ai/util/known_models.dart` |
| 2 | Add result data classes | `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart` |
| 3 | Implement model creation/verification | `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart` |
| 4 | Implement prompt creation | `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart` |
| 5 | Implement category creation | `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart` |
| 6 | Create FTUE setup dialog widget | `lib/features/ai/ui/settings/widgets/ftue_setup_dialog.dart` (new) |
| 7 | Create result dialog widget | `lib/features/ai/ui/settings/widgets/ftue_result_dialog.dart` (new) |
| 8 | Integrate into provider edit page | `lib/features/ai/ui/settings/inference_provider_edit_page.dart` |
| 9 | Create Gemini setup prompt service | `lib/features/ai/ui/settings/services/gemini_setup_prompt_service.dart` (new) |
| 10 | Create Gemini setup prompt modal | `lib/features/ai/ui/settings/widgets/gemini_setup_prompt_modal.dart` (new) |
| 11 | Create Gemini setup prompt trigger | `lib/features/ai/ui/settings/widgets/gemini_setup_prompt_trigger.dart` (new) |
| 12 | Integrate trigger into home page | `lib/pages/home/home_page.dart` |
| 13 | Write unit tests for FTUE | `test/features/ai/ui/settings/services/provider_prompt_setup_service_ftue_test.dart` (new) |
| 14 | Write unit tests for setup prompt | `test/features/ai/ui/settings/services/gemini_setup_prompt_service_test.dart` (new) |
| 15 | Write widget tests | `test/features/ai/ui/settings/widgets/*_test.dart` (new) |
| 16 | Run analyzer, formatter, full test suite | - |

---

## Files Summary

### New Files
- `lib/features/ai/ui/settings/services/gemini_setup_prompt_service.dart` - Automatic prompt service
- `lib/features/ai/ui/settings/widgets/ftue_setup_dialog.dart` - Post-provider FTUE dialog
- `lib/features/ai/ui/settings/widgets/ftue_result_dialog.dart` - Setup result display
- `lib/features/ai/ui/settings/widgets/gemini_setup_prompt_modal.dart` - Automatic setup prompt modal
- `lib/features/ai/ui/settings/widgets/gemini_setup_prompt_trigger.dart` - Widget to trigger prompt on app open
- `test/features/ai/ui/settings/services/provider_prompt_setup_service_ftue_test.dart`
- `test/features/ai/ui/settings/services/gemini_setup_prompt_service_test.dart`
- `test/features/ai/ui/settings/widgets/ftue_setup_dialog_test.dart`
- `test/features/ai/ui/settings/widgets/ftue_result_dialog_test.dart`
- `test/features/ai/ui/settings/widgets/gemini_setup_prompt_modal_test.dart`
- `test/features/ai/ui/settings/widgets/gemini_setup_prompt_trigger_test.dart`

### Modified Files
- `lib/features/ai/util/known_models.dart` - Add Nano Banana constants
- `lib/features/ai/ui/settings/services/provider_prompt_setup_service.dart` - Add FTUE logic
- `lib/features/ai/ui/settings/inference_provider_edit_page.dart` - Integration point
- `lib/pages/home/home_page.dart` - Add GeminiSetupPromptTrigger wrapper

---

## Appendix: Auto-Selection Rationale

| Response Type | Selected Variant | Model | useReasoning | Rationale |
|--------------|------------------|-------|--------------|-----------|
| Audio Transcription | Flash | Gemini 3 Flash | true | Flash with thinking mode provides fast, accurate transcription |
| Image Analysis | Flash | Gemini 3 Flash | true | Fast response with thinking for better context understanding |
| Task Summary | Flash | Gemini 3 Flash | true | Flash thinking balances speed and quality for frequent use |
| Checklist Updates | **Pro** | Gemini 3 Pro | true | Function calling requires stronger reasoning capabilities |
| Prompt Generation | **Pro** | Gemini 3 Pro | true | Code prompts benefit from Pro's deeper reasoning |
| Image Prompt Generation | Flash | Gemini 3 Flash | true | Fast generation with thinking for creative prompts |
| Image Generation | **Pro** | **Nano Banana Pro** | false | Image output requires dedicated image generation model |

### Note on Flash Thinking Mode
Gemini 3 Flash Preview supports thinking mode when `useReasoning=true` is set on prompts. This enables deeper reasoning at Flash's speed and cost, making it suitable for most tasks where Pro was previously required.

### Note on Image Generation
Cover art / image generation prompts require the **Nano Banana Pro** model (`gemini-3-pro-image-preview`) which has image OUTPUT capability. The regular Flash/Pro models only support image INPUT (analysis), not generation.
