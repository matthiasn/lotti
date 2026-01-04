# One-Shot Image Generation with Nano Banana Pro

**Date:** 2026-01-04
**Status:** Planned (Revised)

## Overview

Enable direct image generation within the app using Gemini 3 Pro Image Preview (internally called "Nano Banana Pro"), allowing users to generate cover art images from voice note transcriptions without leaving the application.

## Background

### Current State
- Users can generate text prompts for images via the `imagePromptGeneration` response type
- Image analysis uses a preconfigured prompt without a specialized response type - it just adds text to the image entry
- Cover art can be assigned to tasks via the existing visual mnemonics system
- The `importPastedImages` pipeline handles image storage with EXIF, geolocation, and directory structure

### Goal
Reduce friction by enabling one-shot image generation directly from voice note transcriptions.

### Nano Banana Pro (Gemini 3 Pro Image Preview)
- **Model ID**: `gemini-3-pro-image-preview`
- **Capabilities**: Text + Image input, Text + Image output
- **Response**: Base64-encoded image data in `candidates[0].content.parts[].inline_data.data`
- **Response format**: Uses snake_case (`inline_data`, `mime_type`) per [Gemini API docs](https://ai.google.dev/gemini-api/docs/image-generation)

### Architecture Decisions
1. **No new response type**: Uses existing `imagePromptGeneration` (conceptually similar - generating visual content from task context)
2. **Model-based detection**: Image generation is detected via `outputModalities: [Modality.image]`
3. **Preconfigured prompt**: Task context + transcript sent directly to Nano Banana Pro using existing placeholder expansion (`{{task}}`, `{{linked_tasks}}`, `{{audioTranscript}}`)
4. **Existing pipelines**: Use new `importImageBytesWithId()` (adapts existing pattern), use existing `GeminiUtils.buildGenerateContentUri()` for API calls
5. **Result is JournalImage**: On accept, save as JournalImage linked to task, set as cover art

---

## Phase 1: Data Model Updates

### 1.1 Add Nano Banana Pro to Known Models
**File:** `lib/features/ai/util/known_models.dart`

Add Nano Banana Pro to the Gemini models list:
```dart
const List<KnownModel> geminiModels = [
  // ... existing models ...
  KnownModel(
    providerModelId: 'models/gemini-3-pro-image-preview',
    name: 'Gemini 3 Pro Image (Nano Banana Pro)',
    inputModalities: [Modality.text, Modality.image],
    outputModalities: [Modality.text, Modality.image],  // KEY: image output
    isReasoningModel: false,
    supportsFunctionCalling: false,
    description:
        'High-quality image generation model for cover art and visual mnemonics. '
        'Generates images directly from task context and voice descriptions.',
  ),
];
```

### 1.2 Add Localization Strings
**File:** `lib/l10n/app_en.arb`

```json
"imageGenerationModalTitle": "Generated Image",
"imageGenerationAcceptButton": "Accept as Cover Art",
"imageGenerationEditPromptButton": "Edit Prompt",
"imageGenerationEditPromptLabel": "Edit prompt",
"imageGenerationCancelEdit": "Cancel",
"imageGenerationGenerating": "Generating image...",
"imageGenerationError": "Failed to generate image",
"imageGenerationSaveError": "Failed to save image: {error}",
"@imageGenerationSaveError": {
  "placeholders": {
    "error": {"type": "String"}
  }
},
"imageGenerationRetry": "Retry",
"generateCoverArt": "Generate Cover Art",
"generateCoverArtSubtitle": "Create image from voice description"
```

**File:** `lib/l10n/app_de.arb`

```json
"imageGenerationModalTitle": "Generiertes Bild",
"imageGenerationAcceptButton": "Als Cover übernehmen",
"imageGenerationEditPromptButton": "Prompt bearbeiten",
"imageGenerationEditPromptLabel": "Prompt bearbeiten",
"imageGenerationCancelEdit": "Abbrechen",
"imageGenerationGenerating": "Bild wird generiert...",
"imageGenerationError": "Bildgenerierung fehlgeschlagen",
"imageGenerationSaveError": "Bild konnte nicht gespeichert werden: {error}",
"@imageGenerationSaveError": {
  "placeholders": {
    "error": {"type": "String"}
  }
},
"imageGenerationRetry": "Wiederholen",
"generateCoverArt": "Cover generieren",
"generateCoverArtSubtitle": "Bild aus Sprachbeschreibung erstellen"
```

### 1.3 Add Preconfigured Prompt
**File:** `lib/features/ai/util/preconfigured_prompts.dart`

Add to the lookup map:
```dart
const Map<String, PreconfiguredPrompt> preconfiguredPrompts = {
  // ... existing entries ...
  'image_generation': imageGenerationPrompt,
};
```

Add the prompt definition:
```dart
/// Image Generation prompt template - generates cover art directly from
/// task context and voice note descriptions using Nano Banana Pro
const imageGenerationPrompt = PreconfiguredPrompt(
  id: 'image_generation',
  name: 'Generate Cover Art Image',
  systemMessage: '''
You are an AI image generator creating cover art for task management.

TASK: Generate a visually striking image that serves as a memorable visual mnemonic for the task described below.

IMAGE REQUIREMENTS:
- Aspect ratio: 2:1 (wide cinematic format)
- Composition: Center the primary subject within the middle square region
- This ensures the key visual remains visible when cropped to a square thumbnail
- Use horizontal margins for atmospheric context and cinematic framing

STYLE GUIDANCE:
- Create distinctive, memorable imagery that captures the essence of the task
- Use visual metaphors that connect to the task's theme or goal
- Prefer clean, modern aesthetics with good contrast
- Avoid text, logos, or watermarks in the image

VISUAL METAPHOR IDEAS (adapt based on task type):
- Debugging/fixing: Detective with magnifying glass, puzzle pieces coming together
- Feature completion: Rocket launch, finish line, puzzle piece clicking into place
- Learning/research: Open book with glowing pages, explorer with map
- Communication: Speech bubbles, connected nodes, bridge building
- Organization: Neat shelves, filing system, garden being tended

Generate an image that would make someone immediately recognize and remember this task.
''',
  userMessage: '''
TASK CONTEXT:
{{task}}

RELATED TASKS:
{{linked_tasks}}

USER'S IMAGE DESCRIPTION:
{{audioTranscript}}

Generate a cover art image based on the above context and the user's description.
''',
  requiredInputData: [InputDataType.task],
  aiResponseType: AiResponseType.imagePromptGeneration,  // Reuses existing type - conceptually similar
  useReasoning: false,
  description:
      'Generate cover art image directly from task context and voice description',
);
```

---

## Phase 2: Gemini Image Generation Support

### 2.1 Extend GeminiInferenceRepository for Image Generation
**File:** `lib/features/ai/repository/gemini_inference_repository.dart`

Add image generation method using existing patterns (GeminiUtils for URL building):

```dart
import 'dart:typed_data';

/// Result of an image generation request
class ImageGenerationResult {
  const ImageGenerationResult({
    required this.imageData,
    required this.mimeType,
    this.textDescription,
  });

  final Uint8List imageData;
  final String mimeType;
  final String? textDescription;
}

/// Exception thrown when image generation fails
class ImageGenerationException implements Exception {
  ImageGenerationException(this.message, {this.statusCode, this.originalError});

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'ImageGenerationException: $message';
}

// Add to GeminiInferenceRepository class:

/// Generates an image using Gemini 3 Pro Image (Nano Banana Pro)
///
/// Uses the model's native image generation capabilities with 2:1 aspect ratio
/// optimized for cover art (center-weighted for square thumbnail cropping).
Future<ImageGenerationResult> generateImage({
  required String prompt,
  required String systemMessage,
  required String model,
  required String baseUrl,
  required String apiKey,
  String aspectRatio = '2:1',
  Duration? timeout,
}) async {
  final requestTimeout = timeout ?? const Duration(seconds: 120);

  // Build URI using existing pattern
  final uri = GeminiUtils.buildGenerateContentUri(
    baseUrl: baseUrl,
    model: model,
    apiKey: apiKey,
  );

  // Configure for 2:1 aspect ratio (cover art optimized for center-crop to square)
  // See: https://ai.google.dev/gemini-api/docs/image-generation
  final requestBody = {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': '$systemMessage\n\n$prompt'}
        ]
      }
    ],
    'generationConfig': {
      'responseModalities': ['TEXT', 'IMAGE'],
      'imageConfig': {
        'aspectRatio': aspectRatio,  // Default '2:1' for cover art
      },
    }
  };

  developer.log(
    'Sending image generation request - model: $model, promptLength: ${prompt.length}',
    name: 'GeminiInferenceRepository',
  );

  try {
    final response = await _httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw ImageGenerationException(
        'Failed to generate image (HTTP ${response.statusCode}): ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseImageResponse(result);
  } catch (e) {
    if (e is ImageGenerationException) rethrow;
    throw ImageGenerationException('Failed to generate image: $e', originalError: e);
  }
}

ImageGenerationResult _parseImageResponse(Map<String, dynamic> json) {
  String? textDescription;
  Uint8List? imageData;
  String? mimeType;

  final candidates = json['candidates'] as List<dynamic>?;
  if (candidates == null || candidates.isEmpty) {
    throw ImageGenerationException('No candidates in response');
  }

  final content = candidates[0]['content'] as Map<String, dynamic>?;
  final parts = content?['parts'] as List<dynamic>?;

  if (parts == null) {
    throw ImageGenerationException('No parts in response');
  }

  for (final part in parts) {
    final partMap = part as Map<String, dynamic>;

    if (partMap.containsKey('text')) {
      textDescription = partMap['text'] as String;
    }

    // Gemini API uses snake_case in JSON responses
    // See: https://ai.google.dev/gemini-api/docs/image-generation
    if (partMap.containsKey('inline_data')) {
      final inlineData = partMap['inline_data'] as Map<String, dynamic>;
      mimeType = inlineData['mime_type'] as String?;
      final base64Data = inlineData['data'] as String?;
      if (base64Data != null) {
        imageData = base64Decode(base64Data);
      }
    }
  }

  if (imageData == null) {
    throw ImageGenerationException('No image data in response');
  }

  return ImageGenerationResult(
    imageData: imageData,
    mimeType: mimeType ?? 'image/png',
    textDescription: textDescription,
  );
}
```

### 2.2 Add generateImage to CloudInferenceRepository
**Note:** `GeminiUtils.buildGenerateContentUri()` already exists - no need to add it.
**File:** `lib/features/ai/repository/cloud_inference_repository.dart`

```dart
/// Generates an image using a model with image output capability
///
/// Returns the generated image data. Only works with Gemini provider
/// and models that have Modality.image in outputModalities.
Future<ImageGenerationResult> generateImage({
  required String prompt,
  required String systemMessage,
  required String model,
  required String baseUrl,
  required String apiKey,
  required AiConfigInferenceProvider provider,
}) async {
  if (provider.inferenceProviderType != InferenceProviderType.gemini) {
    throw ArgumentError('Image generation currently only supports Gemini provider');
  }

  return _geminiRepository.generateImage(
    prompt: prompt,
    systemMessage: systemMessage,
    model: model,
    baseUrl: baseUrl,
    apiKey: apiKey,
  );
}
```

---

## Phase 3: Image Generation Controller

### 3.1 Create Image Generation State
**File:** `lib/features/ai/state/image_generation_state.dart` (NEW)

```dart
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_generation_state.freezed.dart';

@freezed
class ImageGenerationState with _$ImageGenerationState {
  const factory ImageGenerationState.idle() = ImageGenerationIdle;

  const factory ImageGenerationState.generating({
    required String prompt,
  }) = ImageGenerationInProgress;

  const factory ImageGenerationState.success({
    required Uint8List imageData,
    required String mimeType,
    required String prompt,
    String? textDescription,
  }) = ImageGenerationSuccess;

  const factory ImageGenerationState.error({
    required String message,
    required String prompt,
  }) = ImageGenerationError;
}
```

### 3.2 Create Image Generation Controller
**File:** `lib/features/ai/state/image_generation_controller.dart` (NEW)

```dart
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/image_generation_state.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';

/// Parameters for image generation
class ImageGenerationParams {
  const ImageGenerationParams({
    required this.taskId,
    required this.audioEntryId,
  });

  final String taskId;
  final String audioEntryId;
}

final imageGenerationControllerProvider = StateNotifierProvider.autoDispose
    .family<ImageGenerationController, ImageGenerationState, ImageGenerationParams>(
  (ref, params) => ImageGenerationController(ref, params),
);

class ImageGenerationController extends StateNotifier<ImageGenerationState> {
  ImageGenerationController(this._ref, this._params)
      : super(const ImageGenerationState.idle());

  final Ref _ref;
  final ImageGenerationParams _params;

  /// Generate an image using the preconfigured prompt with full task context
  Future<void> generateImage() async {
    // Get audio entry for context - PromptBuilderHelper will find linked task
    final audioEntry = _ref.read(entryControllerProvider(id: _params.audioEntryId)).value?.entry;

    if (audioEntry is! JournalAudio) {
      state = const ImageGenerationState.error(
        message: 'Audio entry not found',
        prompt: '',
      );
      return;
    }

    // Check for transcript
    final transcript = audioEntry.data.transcripts.lastOrNull?.transcript ?? '';
    if (transcript.isEmpty) {
      state = const ImageGenerationState.error(
        message: 'No transcript available',
        prompt: '',
      );
      return;
    }

    // Declare prompt before try block so it's accessible in catch
    var prompt = '';

    try {
      final cloudRepo = _ref.read(cloudInferenceRepositoryProvider);
      final configRepo = _ref.read(aiConfigRepositoryProvider);

      // Find Gemini provider and image-capable model FIRST (needed for prompt config)
      final providers = await configRepo.getConfigsByType(AiConfigType.inferenceProvider);
      final models = await configRepo.getConfigsByType(AiConfigType.model);

      final geminiProvider = providers
          .whereType<AiConfigInferenceProvider>()
          .where((p) => p.inferenceProviderType == InferenceProviderType.gemini)
          .firstOrNull;

      if (geminiProvider == null) {
        throw Exception('No Gemini provider configured');
      }

      // Find model with image output capability
      final imageModel = models
          .whereType<AiConfigModel>()
          .where((m) => m.inferenceProviderId == geminiProvider.id)
          .where((m) => m.outputModalities.contains(Modality.image))
          .firstOrNull;

      if (imageModel == null) {
        throw Exception('No image generation model configured. Add Gemini 3 Pro Image model.');
      }

      // Build the full prompt using existing PromptBuilderHelper
      // Pass model ID to make prompt config future-proof for validation
      prompt = await _buildPromptWithContext(audioEntry, imageModel.id);
      state = ImageGenerationState.generating(prompt: prompt);

      final result = await cloudRepo.generateImage(
        prompt: prompt,
        systemMessage: imageGenerationPrompt.systemMessage,
        model: imageModel.providerModelId,
        baseUrl: geminiProvider.baseUrl,
        apiKey: geminiProvider.apiKey,
        provider: geminiProvider,
      );

      state = ImageGenerationState.success(
        imageData: result.imageData,
        mimeType: result.mimeType,
        prompt: prompt,
        textDescription: result.textDescription,
      );
    } catch (e) {
      state = ImageGenerationState.error(
        message: e.toString(),
        prompt: prompt,
      );
    }
  }

  /// Generate with a custom/edited prompt (user override)
  Future<void> generateWithPrompt(String customPrompt) async {
    state = ImageGenerationState.generating(prompt: customPrompt);

    try {
      final cloudRepo = _ref.read(cloudInferenceRepositoryProvider);
      final configRepo = _ref.read(aiConfigRepositoryProvider);

      final providers = await configRepo.getConfigsByType(AiConfigType.inferenceProvider);
      final models = await configRepo.getConfigsByType(AiConfigType.model);

      final geminiProvider = providers
          .whereType<AiConfigInferenceProvider>()
          .where((p) => p.inferenceProviderType == InferenceProviderType.gemini)
          .firstOrNull;

      if (geminiProvider == null) {
        throw Exception('No Gemini provider configured');
      }

      final imageModel = models
          .whereType<AiConfigModel>()
          .where((m) => m.inferenceProviderId == geminiProvider.id)
          .where((m) => m.outputModalities.contains(Modality.image))
          .firstOrNull;

      if (imageModel == null) {
        throw Exception('No image generation model configured');
      }

      final result = await cloudRepo.generateImage(
        prompt: customPrompt,
        systemMessage: imageGenerationPrompt.systemMessage,
        model: imageModel.providerModelId,
        baseUrl: geminiProvider.baseUrl,
        apiKey: geminiProvider.apiKey,
        provider: geminiProvider,
      );

      state = ImageGenerationState.success(
        imageData: result.imageData,
        mimeType: result.mimeType,
        prompt: customPrompt,
        textDescription: result.textDescription,
      );
    } catch (e) {
      state = ImageGenerationState.error(
        message: e.toString(),
        prompt: customPrompt,
      );
    }
  }

  /// Build prompt using existing PromptBuilderHelper for placeholder expansion.
  /// The helper handles {{task}}, {{linked_tasks}}, {{audioTranscript}} placeholders.
  ///
  /// [modelId] is included to make the prompt config future-proof for validation
  /// via [isModelSuitableForPrompt] if this code path ever changes.
  Future<String> _buildPromptWithContext(JournalAudio audioEntry, String modelId) async {
    final promptBuilderHelper = PromptBuilderHelper(
      aiInputRepository: _ref.read(aiInputRepositoryProvider),
      checklistRepository: _ref.read(checklistRepositoryProvider),
      journalRepository: _ref.read(journalRepositoryProvider),
      labelsRepository: _ref.read(labelsRepositoryProvider),
    );

    // Create AiConfigPrompt for placeholder expansion
    // Model IDs included for future-proofing if validation is ever added
    final promptConfig = AiConfigPrompt(
      id: 'image_generation_temp',
      name: 'Image Generation',
      systemMessage: imageGenerationPrompt.systemMessage,
      userMessage: imageGenerationPrompt.userMessage,
      defaultModelId: modelId,
      modelIds: [modelId],
      createdAt: DateTime.now(),
      requiredInputData: imageGenerationPrompt.requiredInputData,
      aiResponseType: AiResponseType.imagePromptGeneration,
      useReasoning: false,
    );

    // The helper expands {{task}}, {{linked_tasks}}, {{audioTranscript}} placeholders
    final prompt = await promptBuilderHelper.buildPromptWithData(
      promptConfig: promptConfig,
      entity: audioEntry,  // Audio entry - helper will find linked task
    );

    return prompt ?? '';
  }

  void reset() {
    state = const ImageGenerationState.idle();
  }

  Future<void> retry() async {
    final currentState = state;
    if (currentState is ImageGenerationError) {
      await generateWithPrompt(currentState.prompt);
    } else if (currentState is ImageGenerationSuccess) {
      await generateWithPrompt(currentState.prompt);
    }
  }
}
```

---

## Phase 4: Image Review Modal

### 4.1 Create Image Review Modal Widget
**File:** `lib/features/ai/ui/image_generation_review_modal.dart` (NEW)

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/image_generation_controller.dart';
import 'package:lotti/features/ai/state/image_generation_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ImageGenerationReviewModal extends ConsumerStatefulWidget {
  const ImageGenerationReviewModal({
    required this.taskId,
    required this.audioEntryId,
    super.key,
  });

  final String taskId;
  final String audioEntryId;

  static Future<void> show({
    required BuildContext context,
    required String taskId,
    required String audioEntryId,
  }) async {
    return ModalUtils.showSinglePageModal(
      context: context,
      title: context.messages.imageGenerationModalTitle,
      builder: (context) => ImageGenerationReviewModal(
        taskId: taskId,
        audioEntryId: audioEntryId,
      ),
    );
  }

  @override
  ConsumerState<ImageGenerationReviewModal> createState() =>
      _ImageGenerationReviewModalState();
}

class _ImageGenerationReviewModalState
    extends ConsumerState<ImageGenerationReviewModal> {
  late TextEditingController _promptController;
  bool _isEditing = false;
  bool _isSaving = false;

  ImageGenerationParams get _params => ImageGenerationParams(
        taskId: widget.taskId,
        audioEntryId: widget.audioEntryId,
      );

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();

    // Start generating immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imageGenerationControllerProvider(_params).notifier).generateImage();
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationControllerProvider(_params));

    // Update prompt controller when state changes
    if (state is ImageGenerationSuccess && _promptController.text.isEmpty) {
      _promptController.text = state.prompt;
    } else if (state is ImageGenerationError && _promptController.text.isEmpty) {
      _promptController.text = state.prompt;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildImageArea(state),
          const SizedBox(height: 16),
          if (_isEditing) ...[
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.messages.imageGenerationEditPromptLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _buildActionButtons(state),
        ],
      ),
    );
  }

  Widget _buildImageArea(ImageGenerationState state) {
    return state.when(
      idle: () => const SizedBox(height: 200),
      generating: (prompt) => SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.messages.imageGenerationGenerating),
            ],
          ),
        ),
      ),
      success: (imageData, mimeType, prompt, description) => Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageData,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      error: (message, prompt) => SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colorScheme.error),
              const SizedBox(height: 8),
              Text(
                context.messages.imageGenerationError,
                style: TextStyle(color: context.colorScheme.error),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message,
                  style: context.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ImageGenerationState state) {
    if (_isSaving) {
      return const Center(child: CircularProgressIndicator());
    }

    return state.when(
      idle: () => const SizedBox.shrink(),
      generating: (_) => const SizedBox.shrink(),
      success: (imageData, mimeType, prompt, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            label: Text(
              _isEditing
                  ? context.messages.imageGenerationCancelEdit
                  : context.messages.imageGenerationEditPromptButton,
            ),
          ),
          if (_isEditing)
            FilledButton.icon(
              onPressed: () {
                setState(() => _isEditing = false);
                ref
                    .read(imageGenerationControllerProvider(_params).notifier)
                    .generateWithPrompt(_promptController.text);
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.messages.imageGenerationRetry),
            )
          else
            FilledButton.icon(
              onPressed: () => _acceptImage(imageData, mimeType),
              icon: const Icon(Icons.check),
              label: Text(context.messages.imageGenerationAcceptButton),
            ),
        ],
      ),
      error: (message, prompt) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          OutlinedButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit),
            label: Text(context.messages.imageGenerationEditPromptButton),
          ),
          FilledButton.icon(
            onPressed: () {
              ref.read(imageGenerationControllerProvider(_params).notifier).retry();
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.messages.imageGenerationRetry),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptImage(Uint8List imageData, String mimeType) async {
    setState(() => _isSaving = true);
    HapticFeedback.selectionClick();

    try {
      // Extract extension from mime type (e.g., 'image/png' -> 'png')
      final extension = mimeType.split('/').last;

      // Use new helper that returns the id
      final imageId = await importImageBytesWithId(
        data: imageData,
        fileExtension: extension,
        linkedId: widget.taskId,
      );

      if (imageId != null) {
        // Set as cover art for the task
        final taskController = ref.read(
          entryControllerProvider(id: widget.taskId).notifier,
        );
        await taskController.setCoverArt(imageId);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.messages.imageGenerationSaveError(e.toString())),
          ),
        );
      }
    }
  }
}
```

### 4.2 Add Image Import Helper Function
**File:** `lib/logic/image_import.dart`

Add a variant that returns the created image id for cover art linking:
```dart
/// Imports image bytes and creates a JournalImage entry, returning the id.
///
/// This is a variant of [importPastedImages] that returns the created entry's id
/// for use cases like setting cover art.
///
/// Note: Unlike [importPastedImages], this does NOT support [analysisTrigger]
/// because it's designed for AI-generated images where automatic analysis
/// would be redundant (we already know the image content from the generation
/// prompt). If analysis is needed in the future, add the parameter.
Future<String?> importImageBytesWithId({
  required Uint8List data,
  required String fileExtension,
  String? linkedId,
  String? categoryId,
}) async {
  // Validate file size
  if (data.length > MediaImportConstants.maxImageFileSizeBytes) {
    getIt<LoggingService>().captureException(
      'Image too large: ${data.length} bytes',
      domain: MediaImportConstants.loggingDomain,
      subDomain: 'importImageBytesWithId',
    );
    return null;
  }

  // Extract original timestamp from EXIF data, fallback to current time
  final capturedAt = await _extractImageTimestamp(data);
  final geolocation = await extractGpsCoordinates(data, capturedAt);
  final id = uuid.v1();

  final day =
      DateFormat(AudioRecorderConstants.directoryDateFormat).format(capturedAt);
  final relativePath = '${MediaImportConstants.imagesDirectoryPrefix}$day/';
  final directory = await createAssetDirectory(relativePath);
  final targetFileName = '$id.$fileExtension';
  final targetFilePath = '$directory$targetFileName';

  final file = await File(targetFilePath).create(recursive: true);
  await file.writeAsBytes(data);

  final imageData = ImageData(
    imageId: id,
    imageFile: targetFileName,
    imageDirectory: relativePath,
    capturedAt: capturedAt,
    geolocation: geolocation,
  );

  final journalImage = await JournalRepository.createImageEntry(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
  );

  return journalImage?.id;
}
```

---

## Phase 5: Integration Point - Trigger from Audio Entry

### 5.1 Add "Generate Cover Art" Action to Audio Entry Menu
**File:** `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart`

```dart
class ModernGenerateCoverArtItem extends ConsumerWidget {
  const ModernGenerateCoverArtItem({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show for audio entries linked to tasks with transcripts
    final provider = entryControllerProvider(id: entryId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalAudio || linkedFromId == null) {
      return const SizedBox.shrink();
    }

    // Verify linkedFromId is a Task
    final parentProvider = entryControllerProvider(id: linkedFromId);
    final parentEntry = ref.watch(parentProvider).value?.entry;
    if (parentEntry is! Task) return const SizedBox.shrink();

    // Check for transcript
    final hasTranscript = entry.data.transcripts.isNotEmpty &&
        (entry.data.transcripts.last.transcript?.isNotEmpty ?? false);
    if (!hasTranscript) return const SizedBox.shrink();

    // Check if Gemini provider with image model is configured
    // (Could add a provider check here for better UX)

    return ModernModalActionItem(
      icon: Icons.auto_awesome,
      title: context.messages.generateCoverArt,
      subtitle: context.messages.generateCoverArtSubtitle,
      onTap: () {
        Navigator.of(context).pop();
        ImageGenerationReviewModal.show(
          context: context,
          taskId: linkedFromId,
          audioEntryId: entryId,
        );
      },
    );
  }
}
```

### 5.2 Add to InitialModalPageContent
**File:** `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart`

Add after existing audio-related items:
```dart
ModernGenerateCoverArtItem(
  entryId: entryId,
  linkedFromId: linkedFromId,
),
```

---

## Phase 6: Future Scope

**NOT part of MVP** - architectural considerations only:

### 6.1 Model Thoughts Display (Follow-up Task)
The Gemini response may include text alongside the image (model's reasoning or description). The current implementation captures this in `textDescription` but only displays it briefly. A future enhancement could:
- Show expandable "Model Thoughts" section in review modal
- Persist thoughts alongside the generated image
- Use thoughts for refinement context in multi-turn conversations

### 6.2 Multi-Turn Conversations
1. **Iterative Refinement**: "Make the wizard look at the camera"
2. **Voice Feedback Loop**: Record another voice note to refine
3. **Conversation History**: Track refinement history per session
4. **Image Input**: Send previous image + refinement text for edits

The `ImageGenerationController` can be extended to maintain conversation history.

---

## Testing Plan

### Unit Tests
1. `GeminiInferenceRepository.generateImage()` - API response parsing
2. `ImageGenerationController` - State transitions, prompt building
3. `ImageGenerationState` - Freezed equality

### Widget Tests
1. `ImageGenerationReviewModal` - Loading, success, error states
2. Action button behavior (accept, edit, retry)
3. `ModernGenerateCoverArtItem` - Visibility conditions

### Integration Tests
1. End-to-end: Audio entry → Generate → Accept → Cover art set
2. Error recovery and retry flows

---

## Files Summary

### New Files
| File | Purpose |
|------|---------|
| `lib/features/ai/state/image_generation_state.dart` | Freezed state model |
| `lib/features/ai/state/image_generation_controller.dart` | Generation orchestration with context |
| `lib/features/ai/ui/image_generation_review_modal.dart` | Review modal UI |

### Modified Files
| File | Changes |
|------|---------|
| `lib/features/ai/util/known_models.dart` | Add Nano Banana Pro model |
| `lib/features/ai/util/preconfigured_prompts.dart` | Add `imageGenerationPrompt` |
| `lib/features/ai/repository/gemini_inference_repository.dart` | Add `generateImage()` method |
| `lib/features/ai/repository/cloud_inference_repository.dart` | Add `generateImage()` delegation |
| `lib/logic/image_import.dart` | Add `importImageBytesWithId()` helper |
| `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart` | Add menu item |
| `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart` | Wire up menu item |
| `lib/l10n/app_en.arb` | Add localization strings |
| `lib/l10n/app_de.arb` | Add German localization strings |

---

## Implementation Order

1. **Phase 1.1**: Add Nano Banana Pro to known models
2. **Phase 1.2**: Add localization strings
3. **Phase 1.3**: Add preconfigured prompt (with `imagePromptGeneration` response type)
4. **Phase 2**: Extend GeminiInferenceRepository with `generateImage()`
5. Run `fvm dart run build_runner build`
6. **Phase 3**: Create state and controller
7. **Phase 4**: Create review modal with existing import pipeline
8. **Phase 5**: Add menu item integration
9. Run analyzer, format, and tests
10. Manual testing of end-to-end flow

---

## Key Design Decisions

1. **No new AiResponseType** - Reuses existing `imagePromptGeneration`, detects image capability from model's `outputModalities`
2. **Existing import pipeline** - Uses new `importImageBytesWithId()` (adapts existing pattern, returns id for cover art)
3. **Existing URL patterns** - Uses `GeminiUtils` for API URL construction
4. **Model-based detection** - Finds model with `Modality.image` in `outputModalities`
5. **Full task context** - Builds prompt using preconfigured template with `{{task}}`, `{{linked_tasks}}`, `{{audioTranscript}}`

---

## Sources
- [Gemini Image Generation Guide](https://ai.google.dev/gemini-api/docs/image-generation)
- [Gemini 3 Developer Guide](https://ai.google.dev/gemini-api/docs/gemini-3)
