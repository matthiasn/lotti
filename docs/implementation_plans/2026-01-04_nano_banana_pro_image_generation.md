# One-Shot Image Generation with Nano Banana Pro

**Date:** 2026-01-04
**Status:** Planned

## Overview

Enable direct image generation within the app using Gemini 3 Pro Image Preview (internally called "Nano Banana Pro"), allowing users to generate cover art images from voice note transcriptions without leaving the application.

## Background

### Current State
- Users can generate text prompts for images via the `imagePromptGeneration` response type
- The system currently uses a Gemini client infrastructure that handles text generation
- Users must copy generated prompts to external tools and paste resulting images back
- Cover art can be assigned to tasks via the existing visual mnemonics system

### Goal
Reduce friction by enabling one-shot image generation directly from voice note transcriptions.

### Nano Banana Pro (Gemini 3 Pro Image Preview)
- **Model ID**: `gemini-3-pro-image-preview`
- **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent`
- **Capabilities**: Text + Image input, Text + Image output
- **Response**: Base64-encoded image data in `inline_data.data` field

### Architecture Decision
- **Direct generation**: Send task context + audio transcript directly to Nano Banana Pro
- **No intermediate step**: Unlike `imagePromptGeneration` which creates a text prompt for external tools, this generates the image directly
- **Preconfigured prompt**: Follows existing patterns with a new entry in `preconfigured_prompts.dart`
- **Known model**: `gemini-3-pro-image-preview` added to known models with image output modality

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

### 1.2 Add New AI Response Type
**File:** `lib/features/ai/state/consts.dart`

```dart
const imageGenerationConst = 'ImageGeneration';

enum AiResponseType {
  // ... existing types ...
  @JsonValue(imageGenerationConst)
  imageGeneration,
}
```

Update the extension methods:
```dart
extension AiResponseTypeDisplay on AiResponseType {
  String localizedName(BuildContext context) {
    // ... existing cases ...
    case AiResponseType.imageGeneration:
      return l10n.aiResponseTypeImageGeneration;
  }

  IconData get icon {
    // ... existing cases ...
    case AiResponseType.imageGeneration:
      return Icons.auto_awesome;  // Or Icons.brush
  }
}
```

### 1.3 Add Localization Strings
**File:** `lib/l10n/app_en.arb`

```json
"aiResponseTypeImageGeneration": "Generated Image",
"imageGenerationModalTitle": "Generated Image",
"imageGenerationAcceptButton": "Accept as Cover Art",
"imageGenerationRejectButton": "Try Again",
"imageGenerationEditPromptButton": "Edit Prompt",
"imageGenerationGenerating": "Generating image...",
"imageGenerationError": "Failed to generate image",
"imageGenerationRetry": "Retry"
```

### 1.4 Add Preconfigured Prompt
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
  // Uses task input for context, transcript comes via placeholder
  requiredInputData: [InputDataType.task],
  aiResponseType: AiResponseType.imageGeneration,
  useReasoning: false,  // Image generation doesn't need reasoning
  description:
      'Generate cover art image directly from task context and voice description',
);
```

---

## Phase 2: Gemini Client Extension

### 2.1 Create Image Generation Repository
**File:** `lib/features/ai/repository/gemini_image_generation_repository.dart` (NEW)

```dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Repository for Gemini image generation operations
class GeminiImageGenerationRepository {
  GeminiImageGenerationRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _defaultTimeout = Duration(seconds: 120);
  static const _modelId = 'gemini-3-pro-image-preview';

  /// Generates an image from a text prompt using Nano Banana Pro
  ///
  /// Returns the generated image as base64-encoded data along with
  /// any accompanying text description.
  Future<ImageGenerationResult> generateImage({
    required String prompt,
    required String apiKey,
    String? baseUrl,
    String aspectRatio = '1:1',  // Default square for cover art
    String imageSize = '2K',
    Duration? timeout,
  }) async {
    final requestTimeout = timeout ?? _defaultTimeout;

    // Use Gemini API base URL
    final url = baseUrl ?? 'https://generativelanguage.googleapis.com/v1beta';
    final endpoint = Uri.parse('$url/models/$_modelId:generateContent');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
        'imageConfig': {
          'aspectRatio': aspectRatio,
          'imageSize': imageSize,
        }
      }
    };

    developer.log(
      'Sending image generation request - promptLength: ${prompt.length}, '
      'aspectRatio: $aspectRatio, imageSize: $imageSize',
      name: 'GeminiImageGenerationRepository',
    );

    try {
      final response = await _httpClient
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        throw ImageGenerationException(
          'Failed to generate image (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseResponse(result);
    } catch (e) {
      if (e is ImageGenerationException) rethrow;
      throw ImageGenerationException(
        'Failed to generate image: $e',
        originalError: e,
      );
    }
  }

  ImageGenerationResult _parseResponse(Map<String, dynamic> json) {
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

      // Check for text part
      if (partMap.containsKey('text')) {
        textDescription = partMap['text'] as String;
      }

      // Check for image part
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
}

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
  ImageGenerationException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'ImageGenerationException: $message';
}
```

### 2.2 Add Provider for Image Generation Repository
**File:** `lib/features/ai/providers/gemini_image_generation_provider.dart` (NEW)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/gemini_image_generation_repository.dart';
import 'package:lotti/get_it.dart';

final geminiImageGenerationRepositoryProvider =
    Provider<GeminiImageGenerationRepository>((ref) {
  return GeminiImageGenerationRepository(
    httpClient: getIt<http.Client>(),
  );
});
```

### 2.3 Integrate with CloudInferenceRepository
**File:** `lib/features/ai/repository/cloud_inference_repository.dart`

Add method for image generation:
```dart
/// Generates an image using Nano Banana Pro (Gemini 3 Pro Image)
///
/// Returns the generated image data and optional description
Future<ImageGenerationResult> generateImage({
  required String prompt,
  required String model,
  required String baseUrl,
  required String apiKey,
  String aspectRatio = '1:1',
  String imageSize = '2K',
  AiConfigInferenceProvider? provider,
}) async {
  // Verify it's a Gemini provider
  if (provider?.inferenceProviderType != InferenceProviderType.gemini) {
    throw ArgumentError('Image generation requires Gemini provider');
  }

  return _geminiImageGenerationRepository.generateImage(
    prompt: prompt,
    apiKey: apiKey,
    baseUrl: baseUrl,
    aspectRatio: aspectRatio,
    imageSize: imageSize,
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
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/image_generation_state.dart';

final imageGenerationControllerProvider = StateNotifierProvider.autoDispose
    .family<ImageGenerationController, ImageGenerationState, String>(
  (ref, taskId) => ImageGenerationController(ref, taskId),
);

class ImageGenerationController extends StateNotifier<ImageGenerationState> {
  ImageGenerationController(this._ref, this._taskId)
      : super(const ImageGenerationState.idle());

  final Ref _ref;
  final String _taskId;

  /// Generate an image from the given prompt
  Future<void> generateImage(String prompt) async {
    state = ImageGenerationState.generating(prompt: prompt);

    try {
      final cloudRepo = _ref.read(cloudInferenceRepositoryProvider);
      final configRepo = _ref.read(aiConfigRepositoryProvider);

      // Find a Gemini provider with image generation capability
      final providers = await configRepo.getConfigsByType(
        AiConfigType.inferenceProvider,
      );

      final geminiProvider = providers
          .whereType<AiConfigInferenceProvider>()
          .where((p) => p.inferenceProviderType == InferenceProviderType.gemini)
          .firstOrNull;

      if (geminiProvider == null) {
        throw Exception('No Gemini provider configured');
      }

      final result = await cloudRepo.generateImage(
        prompt: prompt,
        model: 'gemini-3-pro-image-preview',
        baseUrl: geminiProvider.baseUrl,
        apiKey: geminiProvider.apiKey,
        aspectRatio: '2:1',  // Cinematic ratio for cover art
        imageSize: '2K',
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

  /// Reset to idle state
  void reset() {
    state = const ImageGenerationState.idle();
  }

  /// Retry with the same prompt
  Future<void> retry() async {
    final currentState = state;
    if (currentState is ImageGenerationError) {
      await generateImage(currentState.prompt);
    } else if (currentState is ImageGenerationSuccess) {
      await generateImage(currentState.prompt);
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
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ImageGenerationReviewModal extends ConsumerStatefulWidget {
  const ImageGenerationReviewModal({
    required this.taskId,
    required this.initialPrompt,
    super.key,
  });

  final String taskId;
  final String initialPrompt;

  static Future<void> show({
    required BuildContext context,
    required String taskId,
    required String initialPrompt,
  }) async {
    return ModalUtils.showSinglePageModal(
      context: context,
      title: context.messages.imageGenerationModalTitle,
      builder: (context) => ImageGenerationReviewModal(
        taskId: taskId,
        initialPrompt: initialPrompt,
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

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.initialPrompt);

    // Start generating immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(imageGenerationControllerProvider(widget.taskId).notifier)
          .generateImage(widget.initialPrompt);
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationControllerProvider(widget.taskId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image display area
          _buildImageArea(state),
          const SizedBox(height: 16),

          // Prompt editing area (shown when editing)
          if (_isEditing) ...[
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Edit prompt',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Action buttons
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
              Text(
                message,
                style: context.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ImageGenerationState state) {
    return state.when(
      idle: () => const SizedBox.shrink(),
      generating: (_) => const SizedBox.shrink(),
      success: (imageData, mimeType, prompt, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reject / Edit button
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            label: Text(
              _isEditing
                  ? 'Cancel'
                  : context.messages.imageGenerationEditPromptButton,
            ),
          ),

          // Regenerate (when editing)
          if (_isEditing)
            FilledButton.icon(
              onPressed: () {
                setState(() => _isEditing = false);
                ref
                    .read(imageGenerationControllerProvider(widget.taskId).notifier)
                    .generateImage(_promptController.text);
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.messages.imageGenerationRetry),
            )
          else
            // Accept button
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
            onPressed: () {
              setState(() => _isEditing = true);
            },
            icon: const Icon(Icons.edit),
            label: Text(context.messages.imageGenerationEditPromptButton),
          ),
          FilledButton.icon(
            onPressed: () {
              ref
                  .read(imageGenerationControllerProvider(widget.taskId).notifier)
                  .retry();
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.messages.imageGenerationRetry),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptImage(Uint8List imageData, String mimeType) async {
    HapticFeedback.selectionClick();

    // Save image to storage and link to task
    final imagePasteController = ref.read(imagePasteControllerProvider.notifier);

    // Save the image bytes as a file and create a JournalImage entry
    final imageId = await imagePasteController.saveImageFromBytes(
      imageData,
      mimeType: mimeType,
      linkedFromId: widget.taskId,
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
  }
}
```

### 4.2 Add saveImageFromBytes to ImagePasteController
**File:** `lib/features/journal/state/image_paste_controller.dart`

Add method to save image from bytes (extend existing controller):
```dart
/// Saves image bytes to storage and creates a JournalImage entry
///
/// Returns the ID of the created JournalImage entry, or null on failure
Future<String?> saveImageFromBytes(
  Uint8List imageData, {
  required String mimeType,
  String? linkedFromId,
}) async {
  try {
    // Generate filename based on timestamp
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final extension = mimeType.split('/').last;
    final filename = 'generated_$timestamp.$extension';

    // Get the images directory
    final docDir = await getApplicationDocumentsDirectory();
    final dateDir = DateTime.now().toIso8601String().substring(0, 10);
    final imagesDir = Directory('${docDir.path}/images/$dateDir');
    await imagesDir.create(recursive: true);

    // Save the file
    final file = File('${imagesDir.path}/$filename');
    await file.writeAsBytes(imageData);

    // Create JournalImage entry
    final imageId = uuid.v1();
    final journalImage = JournalImage(
      meta: Metadata(
        id: imageId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
      data: ImageData(
        capturedAt: DateTime.now(),
        imageId: imageId,
        imageFile: filename,
        imageDirectory: 'images/$dateDir',
      ),
    );

    // Persist and link
    await _journalRepo.createJournalEntity(journalImage);

    if (linkedFromId != null) {
      await _journalRepo.linkEntries(
        fromId: linkedFromId,
        toId: imageId,
      );
    }

    return imageId;
  } catch (e) {
    developer.log(
      'Failed to save generated image: $e',
      name: 'ImagePasteController',
    );
    return null;
  }
}
```

---

## Phase 5: Integration Point - Trigger from Audio Entry

### 5.1 Add "Generate Cover Art" Action to Audio Entry Menu
**File:** `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart`

Add new action item:
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
    // Only show for audio entries linked to tasks
    final provider = entryControllerProvider(id: entryId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalAudio || linkedFromId == null) {
      return const SizedBox.shrink();
    }

    // Verify linkedFromId is a Task
    final parentProvider = entryControllerProvider(id: linkedFromId);
    final parentEntry = ref.watch(parentProvider).value?.entry;
    if (parentEntry is! Task) return const SizedBox.shrink();

    // Get the transcript
    final transcript = entry.data.transcripts.lastOrNull?.transcript;
    if (transcript == null || transcript.isEmpty) {
      return const SizedBox.shrink();
    }

    return ModernModalActionItem(
      icon: Icons.auto_awesome,
      title: context.messages.generateCoverArt,  // Add this localization
      subtitle: context.messages.generateCoverArtSubtitle,  // Add this
      onTap: () {
        Navigator.of(context).pop();
        ImageGenerationReviewModal.show(
          context: context,
          taskId: linkedFromId,
          initialPrompt: transcript,
        );
      },
    );
  }
}
```

### 5.2 Add to InitialModalPageContent
**File:** `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart`

Add after image prompt generation items:
```dart
ModernGenerateCoverArtItem(
  entryId: entryId,
  linkedFromId: linkedFromId,
),
```

---

## Phase 6: Future Scope (Multi-Turn Conversations)

This phase is **NOT part of the current MVP** but should be considered in the architecture:

### 6.1 Planned Multi-Turn Features
1. **Iterative Refinement**: "Make the wizard look at the camera"
2. **Voice Feedback Loop**: Record another voice note to refine the image
3. **Conversation History**: Track refinement history for each generation session

### 6.2 Architectural Considerations for Future
- The `ImageGenerationController` can be extended to maintain conversation history
- The modal can be extended to show refinement history
- Image input can be added to the generation request (edit existing images)

---

## Testing Plan

### Unit Tests
1. `GeminiImageGenerationRepository` - API parsing, error handling
2. `ImageGenerationController` - State transitions
3. `ImageGenerationState` - Freezed equality

### Widget Tests
1. `ImageGenerationReviewModal` - Loading, success, error states
2. Action button behavior (accept, reject, edit, retry)
3. Integration with task cover art assignment

### Integration Tests
1. End-to-end flow: Voice note → Transcript → Generate → Accept → Cover art set
2. Error recovery and retry flows

---

## Files Summary

### New Files
| File | Purpose |
|------|---------|
| `lib/features/ai/repository/gemini_image_generation_repository.dart` | Gemini image generation API client |
| `lib/features/ai/providers/gemini_image_generation_provider.dart` | Riverpod provider |
| `lib/features/ai/state/image_generation_state.dart` | Freezed state model |
| `lib/features/ai/state/image_generation_controller.dart` | State management |
| `lib/features/ai/ui/image_generation_review_modal.dart` | Review modal UI |

### Modified Files
| File | Changes |
|------|---------|
| `lib/features/ai/util/known_models.dart` | Add Nano Banana Pro model with image output modality |
| `lib/features/ai/util/preconfigured_prompts.dart` | Add `imageGenerationPrompt` |
| `lib/features/ai/state/consts.dart` | Add `imageGeneration` response type |
| `lib/features/ai/repository/cloud_inference_repository.dart` | Add `generateImage` method |
| `lib/features/journal/state/image_paste_controller.dart` | Add `saveImageFromBytes` method |
| `lib/features/journal/ui/widgets/entry_details/header/modern_action_items.dart` | Add generate cover art item |
| `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart` | Add menu item |
| `lib/l10n/app_en.arb` | Add localization strings |
| `lib/l10n/app_de.arb` | Add German translations |

---

## Implementation Order

1. **Phase 1.1**: Add Nano Banana Pro to known models (`known_models.dart`)
2. **Phase 1.2**: Add `imageGeneration` response type (`consts.dart`)
3. **Phase 1.3**: Add localization strings (`app_en.arb`)
4. **Phase 1.4**: Add preconfigured prompt (`preconfigured_prompts.dart`)
5. Run `fvm dart run build_runner build`
6. **Phase 2**: Create image generation repository
7. **Phase 3**: Create controller and state
8. **Phase 4**: Create review modal
9. **Phase 5**: Integration with audio entry menu
10. Run analyzer, format, and tests
11. Manual testing of end-to-end flow

---

## Sources
- [Gemini Image Generation Guide](https://ai.google.dev/gemini-api/docs/image-generation)
- [Gemini 3 Developer Guide](https://ai.google.dev/gemini-api/docs/gemini-3)
