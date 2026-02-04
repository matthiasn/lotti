# Reference Images for Cover Art Generation

**Date:** 2026-02-04
**Status:** Planning
**Branch:** `feat/reference-images-cover-art`

## Overview

Enhance task cover art generation by allowing users to select up to three reference images from the task to provide visual context to the AI model. This ensures generated cover art better matches specific activities like woodworking, gardening, or other visual contexts captured in task photos.

## Background

### Current State
- Cover art generation is fully implemented via "Nano Banana Pro" (Gemini 3 Pro Image)
- Users record audio describing desired cover art
- AI generates images based on:
  - Audio transcript (user's vision)
  - Task context (title, checklists, labels)
  - AI-generated task summary
- No visual reference is currently sent to the model

### Problem
The AI generates cover art based purely on text descriptions. When a user has photos of their actual woodworking project, garden, or specific activity, the generated cover art may not visually match the real-world context they're working with.

### Solution
Add an intermediate step after audio recording where users can optionally select 1-3 reference images from the task's linked images. These images are sent to Gemini alongside the text prompt, providing visual context for more accurate and contextually relevant cover art generation.

---

## User Flow

### Current Flow
```
Audio Entry Detail → "Generate Cover Art" → ImageGenerationReviewModal → Accept/Edit
```

### New Flow
```
Audio Entry Detail → "Generate Cover Art" → ReferenceImageSelectionStep → ImageGenerationReviewModal → Accept/Edit
```

### Detailed Steps
1. User taps "Generate Cover Art" from audio entry actions
2. **NEW**: Modal shows 3×3 grid of task's linked images
3. **NEW**: User selects 0-3 images (optional - can skip)
4. **NEW**: "Continue" button proceeds to generation
5. Modal shows generating state with selected reference images sent to API
6. User reviews generated image, can accept or edit prompt

---

## Technical Design

### Phase 1: Data Model & Repository

#### 1.1 Query Task's Linked Images
**File:** `lib/features/journal/repository/journal_repository.dart`

Add method to get JournalImage entries linked to a task:
```dart
/// Returns all JournalImage entries linked to the given task.
Future<List<JournalImage>> getLinkedImagesForTask(String taskId) async {
  final linkedEntities = await _journalDb.linkedJournalEntities(taskId).get();
  return linkedEntities
      .map(fromDbEntity)
      .whereType<JournalImage>()
      .toList();
}
```

#### 1.2 Image Processing Utilities
**File:** `lib/features/ai/util/image_processing_utils.dart` (NEW)

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Maximum dimension for reference images sent to Gemini.
/// Images larger than this are resized to fit within this boundary.
const int kMaxReferenceDimension = 2000;

/// Maximum number of reference images allowed.
const int kMaxReferenceImages = 3;

/// Represents a processed reference image ready for API submission.
class ProcessedReferenceImage {
  const ProcessedReferenceImage({
    required this.base64Data,
    required this.mimeType,
    required this.originalId,
  });

  final String base64Data;
  final String mimeType;
  final String originalId;
}

/// Processes an image file for use as a reference image.
///
/// - Reads the file from disk
/// - Resizes if any dimension exceeds [kMaxReferenceDimension]
/// - Converts to Base64
/// - Returns the processed image with metadata
Future<ProcessedReferenceImage?> processReferenceImage({
  required String filePath,
  required String imageId,
}) async {
  final file = File(filePath);
  if (!await file.exists()) return null;

  var bytes = await file.readAsBytes();
  final mimeType = _detectMimeType(filePath);

  // Decode to check dimensions
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // Resize if needed
  if (decoded.width > kMaxReferenceDimension ||
      decoded.height > kMaxReferenceDimension) {
    final resized = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? kMaxReferenceDimension : null,
      height: decoded.height >= decoded.width ? kMaxReferenceDimension : null,
    );
    bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  return ProcessedReferenceImage(
    base64Data: base64Encode(bytes),
    mimeType: mimeType,
    originalId: imageId,
  );
}

String _detectMimeType(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}
```

---

### Phase 2: Gemini API Integration

#### 2.1 Extend GeminiUtils for Reference Images
**File:** `lib/features/ai/repository/gemini_utils.dart`

Add parameter for reference images in image generation request:

```dart
/// Builds a Gemini request body for image generation with optional reference images.
///
/// Reference images provide visual context to guide the generated output.
/// Each image is included as an inline_data part before the text prompt.
static Map<String, dynamic> buildImageGenerationRequestBody({
  required String prompt,
  String? systemMessage,
  List<ProcessedReferenceImage>? referenceImages,
}) {
  final parts = <Map<String, dynamic>>[];

  // Add reference images first (visual context)
  if (referenceImages != null) {
    for (final refImage in referenceImages) {
      parts.add({
        'inline_data': {
          'mime_type': refImage.mimeType,
          'data': refImage.base64Data,
        },
      });
    }
  }

  // Add text prompt after images
  parts.add({'text': prompt});

  final contents = <Map<String, dynamic>>[
    {
      'role': 'user',
      'parts': parts,
    },
  ];

  final generationConfig = <String, dynamic>{
    'responseModalities': ['IMAGE', 'TEXT'],
    'imageConfig': {
      'aspectRatio': '16:9',
      'imageSize': '2K',
    },
  };

  final request = <String, dynamic>{
    'contents': contents,
    'generationConfig': generationConfig,
  };

  if (systemMessage != null && systemMessage.trim().isNotEmpty) {
    request['systemInstruction'] = {
      'role': 'system',
      'parts': [
        {'text': systemMessage},
      ],
    };
  }

  return request;
}
```

#### 2.2 Update GeminiInferenceRepository
**File:** `lib/features/ai/repository/gemini_inference_repository.dart`

Add `referenceImages` parameter to `generateImage()`:

```dart
Future<GeneratedImage> generateImage({
  required String prompt,
  required String model,
  required AiConfigInferenceProvider provider,
  String? systemMessage,
  List<ProcessedReferenceImage>? referenceImages,  // NEW
}) async {
  // ... existing implementation ...

  final body = GeminiUtils.buildImageGenerationRequestBody(
    prompt: prompt,
    systemMessage: systemMessage,
    referenceImages: referenceImages,  // NEW
  );

  // ... rest unchanged ...
}
```

#### 2.3 Update CloudInferenceRepository
**File:** `lib/features/ai/repository/cloud_inference_repository.dart`

Pass through the `referenceImages` parameter:

```dart
Future<GeneratedImage> generateImage({
  required String prompt,
  required String model,
  required AiConfigInferenceProvider provider,
  String? systemMessage,
  List<ProcessedReferenceImage>? referenceImages,  // NEW
}) async {
  // ... validation ...

  return _geminiRepository.generateImage(
    prompt: prompt,
    model: model,
    provider: provider,
    systemMessage: systemMessage,
    referenceImages: referenceImages,  // NEW
  );
}
```

---

### Phase 3: State Management

#### 3.1 Reference Image Selection State
**File:** `lib/features/ai/state/reference_image_selection_controller.dart` (NEW)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reference_image_selection_controller.freezed.dart';
part 'reference_image_selection_controller.g.dart';

@freezed
class ReferenceImageSelectionState with _$ReferenceImageSelectionState {
  const factory ReferenceImageSelectionState({
    @Default([]) List<JournalImage> availableImages,
    @Default({}) Set<String> selectedImageIds,
    @Default(false) bool isLoading,
    @Default(false) bool isProcessing,
    String? errorMessage,
  }) = _ReferenceImageSelectionState;

  const ReferenceImageSelectionState._();

  bool get canSelectMore => selectedImageIds.length < kMaxReferenceImages;
  int get selectionCount => selectedImageIds.length;
}

@riverpod
class ReferenceImageSelectionController
    extends _$ReferenceImageSelectionController {
  @override
  ReferenceImageSelectionState build({required String taskId}) {
    _loadAvailableImages();
    return const ReferenceImageSelectionState(isLoading: true);
  }

  Future<void> _loadAvailableImages() async {
    try {
      final journalRepository = ref.read(journalRepositoryProvider);
      final images = await journalRepository.getLinkedImagesForTask(taskId);

      state = state.copyWith(
        availableImages: images,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load images: $e',
      );
    }
  }

  void toggleImageSelection(String imageId) {
    final current = Set<String>.from(state.selectedImageIds);

    if (current.contains(imageId)) {
      current.remove(imageId);
    } else if (current.length < kMaxReferenceImages) {
      current.add(imageId);
    }

    state = state.copyWith(selectedImageIds: current);
  }

  void clearSelection() {
    state = state.copyWith(selectedImageIds: {});
  }

  /// Processes selected images and returns them ready for API submission.
  Future<List<ProcessedReferenceImage>> processSelectedImages() async {
    state = state.copyWith(isProcessing: true);

    try {
      final results = <ProcessedReferenceImage>[];

      for (final imageId in state.selectedImageIds) {
        final image = state.availableImages.firstWhere(
          (img) => img.meta.id == imageId,
          orElse: () => throw Exception('Image not found: $imageId'),
        );

        final filePath = getFullImagePath(image);
        final processed = await processReferenceImage(
          filePath: filePath,
          imageId: imageId,
        );

        if (processed != null) {
          results.add(processed);
        }
      }

      state = state.copyWith(isProcessing: false);
      return results;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to process images: $e',
      );
      return [];
    }
  }
}
```

#### 3.2 Update ImageGenerationController
**File:** `lib/features/ai/state/image_generation_controller.dart`

Add support for reference images:

```dart
/// Generates a cover art image with optional reference images.
Future<void> generateImage({
  required String prompt,
  String? systemMessage,
  List<ProcessedReferenceImage>? referenceImages,  // NEW
}) async {
  // ... existing try/catch structure ...

  final generatedImage = await cloudRepo.generateImage(
    prompt: prompt,
    model: model.providerModelId,
    provider: provider,
    systemMessage: effectiveSystemMessage,
    referenceImages: referenceImages,  // NEW
  );

  // ... rest unchanged ...
}

/// Generates from entity with optional reference images.
Future<void> generateImageFromEntity({
  required String audioEntityId,
  List<ProcessedReferenceImage>? referenceImages,  // NEW
}) async {
  // ... existing prompt building ...

  await generateImage(
    prompt: prompt,
    referenceImages: referenceImages,  // NEW
  );
}
```

---

### Phase 4: UI Components

#### 4.1 Reference Image Selection Widget
**File:** `lib/features/ai/ui/image_generation/reference_image_selection_widget.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class ReferenceImageSelectionWidget extends ConsumerWidget {
  const ReferenceImageSelectionWidget({
    required this.taskId,
    required this.onContinue,
    required this.onSkip,
    super.key,
  });

  final String taskId;
  final void Function(List<ProcessedReferenceImage> images) onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      referenceImageSelectionControllerProvider(taskId: taskId),
    );
    final controller = ref.read(
      referenceImageSelectionControllerProvider(taskId: taskId).notifier,
    );

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.availableImages.isEmpty) {
      // No images available, skip this step
      WidgetsBinding.instance.addPostFrameCallback((_) => onSkip());
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with count
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.messages.referenceImageSelectionTitle,
                  style: context.textTheme.titleMedium,
                ),
              ),
              Text(
                '${state.selectionCount}/$kMaxReferenceImages',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.messages.referenceImageSelectionSubtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Image grid (3x3 max visible, scrollable)
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: state.availableImages.length,
              itemBuilder: (context, index) {
                final image = state.availableImages[index];
                final isSelected = state.selectedImageIds.contains(image.meta.id);
                final canSelect = state.canSelectMore || isSelected;

                return _ImageGridTile(
                  image: image,
                  isSelected: isSelected,
                  canSelect: canSelect,
                  onTap: () => controller.toggleImageSelection(image.meta.id),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Skip button
              TextButton(
                onPressed: state.isProcessing ? null : onSkip,
                child: Text(context.messages.referenceImageSkip),
              ),
              const Spacer(),
              // Continue button
              FilledButton(
                onPressed: state.isProcessing
                    ? null
                    : () async {
                        final images = await controller.processSelectedImages();
                        onContinue(images);
                      },
                child: state.isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        state.selectionCount > 0
                            ? context.messages.referenceImageContinueWithCount(
                                state.selectionCount,
                              )
                            : context.messages.referenceImageContinue,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageGridTile extends StatelessWidget {
  const _ImageGridTile({
    required this.image,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
  });

  final JournalImage image;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return GestureDetector(
      onTap: canSelect ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image thumbnail
              EntryImageWidget(
                journalImage: image,
                fit: BoxFit.cover,
              ),
              // Dimming overlay for non-selectable
              if (!canSelect)
                Container(
                  color: Colors.black54,
                ),
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### 4.2 Update ImageGenerationReviewModal
**File:** `lib/features/ai/ui/image_generation/image_generation_review_modal.dart`

Add multi-step flow with reference image selection:

```dart
enum _ModalStep { selectImages, generating, review }

class _ImageGenerationReviewModalState
    extends ConsumerState<ImageGenerationReviewModal> {
  _ModalStep _currentStep = _ModalStep.selectImages;
  List<ProcessedReferenceImage> _selectedReferenceImages = [];

  // ... existing code ...

  void _handleImageSelectionContinue(List<ProcessedReferenceImage> images) {
    setState(() {
      _selectedReferenceImages = images;
      _currentStep = _ModalStep.generating;
    });
    _startGenerationWithReferences();
  }

  void _handleSkipImageSelection() {
    setState(() {
      _selectedReferenceImages = [];
      _currentStep = _ModalStep.generating;
    });
    _startGenerationWithReferences();
  }

  void _startGenerationWithReferences() {
    ref
        .read(imageGenerationControllerProvider(entityId: widget.entityId).notifier)
        .generateImageFromEntity(
          audioEntityId: widget.entityId,
          referenceImages: _selectedReferenceImages.isNotEmpty
              ? _selectedReferenceImages
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Route to appropriate step
    switch (_currentStep) {
      case _ModalStep.selectImages:
        return ReferenceImageSelectionWidget(
          taskId: widget.linkedTaskId,
          onContinue: _handleImageSelectionContinue,
          onSkip: _handleSkipImageSelection,
        );
      case _ModalStep.generating:
      case _ModalStep.review:
        // Existing generation/review UI
        return _buildGenerationUI();
    }
  }

  // ... rest of existing implementation ...
}
```

---

### Phase 5: Localization

#### 5.1 English Strings
**File:** `lib/l10n/app_en.arb`

```json
"referenceImageSelectionTitle": "Select Reference Images",
"referenceImageSelectionSubtitle": "Choose up to 3 images to guide the AI's visual style",
"referenceImageSkip": "Skip",
"referenceImageContinue": "Continue",
"referenceImageContinueWithCount": "Continue ({count})",
"@referenceImageContinueWithCount": {
  "placeholders": {
    "count": {"type": "int"}
  }
}
```

#### 5.2 German Strings
**File:** `lib/l10n/app_de.arb`

```json
"referenceImageSelectionTitle": "Referenzbilder auswählen",
"referenceImageSelectionSubtitle": "Wähle bis zu 3 Bilder, um den visuellen Stil der KI zu leiten",
"referenceImageSkip": "Überspringen",
"referenceImageContinue": "Weiter",
"referenceImageContinueWithCount": "Weiter ({count})"
```

---

### Phase 6: Update Preconfigured Prompt

#### 6.1 Enhance System Message
**File:** `lib/features/ai/util/preconfigured_prompts.dart`

Update the cover art generation prompt to mention reference images:

```dart
const coverArtGenerationPrompt = PreconfiguredPrompt(
  id: 'cover_art_generation',
  name: 'Generate Cover Art Image',
  systemMessage: '''
You are an expert visual artist creating cover art for task management.

TASK: Generate a visually striking image that serves as a memorable visual mnemonic for the task described below.

REFERENCE IMAGES (if provided):
- Use the visual style, color palette, and subject matter from reference images as inspiration
- The generated image should feel cohesive with the reference images
- Incorporate recognizable elements from the references where appropriate
- Match the lighting mood and overall aesthetic

IMAGE REQUIREMENTS:
- Aspect ratio: 16:9 (wide cinematic format)
- Composition: Center the primary subject within the middle square region
- This ensures the key visual remains visible when cropped to a square thumbnail
- IMPORTANT: Avoid placing key elements in the top 20% center area (device notch safe zone)
- Use horizontal margins for atmospheric context and cinematic framing

STYLE GUIDANCE:
- Create distinctive, memorable imagery that captures the essence of the task
- Use visual metaphors that connect to the task's theme or goal
- Prefer clean, modern aesthetics with good contrast
- Avoid text, logos, or watermarks in the image
- If reference images show real activities (woodworking, gardening, etc.), incorporate those materials and tools

VISUAL METAPHOR IDEAS (adapt based on task type):
- Building/crafting: Tools in action, materials being shaped, workshop atmosphere
- Nature/gardening: Plants, growth, natural light, earthy textures
- Learning/research: Open book with glowing pages, explorer with map
- Communication: Connected nodes, bridge building
- Organization: Neat arrangement, satisfying order

Generate an image that would make someone immediately recognize and remember this task.
''',
  // ... rest unchanged ...
);
```

---

## Testing Plan

### Unit Tests

1. **Image Processing Utils**
   - `processReferenceImage()` - resize logic, base64 encoding
   - `_detectMimeType()` - correct MIME type detection
   - Edge cases: missing file, corrupt image, already small image

2. **ReferenceImageSelectionController**
   - Initial state and loading
   - Toggle selection (add/remove)
   - Max selection limit enforcement
   - Process selected images

3. **GeminiUtils.buildImageGenerationRequestBody**
   - Without reference images (existing behavior)
   - With 1, 2, 3 reference images
   - Correct structure of inline_data parts

### Widget Tests

1. **ReferenceImageSelectionWidget**
   - Grid renders available images
   - Selection toggle visual feedback
   - Max selection disabled state
   - Skip button functionality
   - Continue button with count

2. **ImageGenerationReviewModal**
   - Step navigation flow
   - Reference images passed to generation
   - Skip bypasses selection step

### Integration Tests

1. End-to-end: Select images → Generate → Verify API payload includes images
2. Empty images list → Auto-skip to generation
3. Retry generation preserves reference images

---

## Files Summary

### New Files
| File | Purpose |
|------|---------|
| `lib/features/ai/util/image_processing_utils.dart` | Image resize & Base64 conversion |
| `lib/features/ai/state/reference_image_selection_controller.dart` | Selection state management |
| `lib/features/ai/ui/image_generation/reference_image_selection_widget.dart` | Image selection grid UI |

### Modified Files
| File | Changes |
|------|---------|
| `lib/features/journal/repository/journal_repository.dart` | Add `getLinkedImagesForTask()` |
| `lib/features/ai/repository/gemini_utils.dart` | Add reference images to request body |
| `lib/features/ai/repository/gemini_inference_repository.dart` | Pass reference images parameter |
| `lib/features/ai/repository/cloud_inference_repository.dart` | Pass reference images parameter |
| `lib/features/ai/state/image_generation_controller.dart` | Accept reference images |
| `lib/features/ai/ui/image_generation/image_generation_review_modal.dart` | Add selection step |
| `lib/features/ai/util/preconfigured_prompts.dart` | Update prompt for reference context |
| `lib/l10n/app_en.arb` | Add localization strings |
| `lib/l10n/app_de.arb` | Add German localization strings |

---

## Implementation Order

1. **Phase 1.2**: Create `image_processing_utils.dart` with resize/Base64 logic
2. **Phase 1.1**: Add `getLinkedImagesForTask()` to JournalRepository
3. **Phase 2**: Update Gemini utils and repositories for reference images
4. **Phase 3.1**: Create `ReferenceImageSelectionController`
5. **Phase 3.2**: Update `ImageGenerationController` to accept reference images
6. Run `fvm dart run build_runner build`
7. **Phase 4.1**: Create `ReferenceImageSelectionWidget`
8. **Phase 4.2**: Update `ImageGenerationReviewModal` with step flow
9. **Phase 5**: Add localization strings
10. **Phase 6**: Update preconfigured prompt
11. Run analyzer, format, and tests

---

## Dependencies

### Existing
- `flutter_image_compress` - Already in project for image compression
- `image` package - May need to add for dimension checking/resize

### Potentially New
- `image: ^4.x` - For decoding images to check dimensions before resize

Check `pubspec.yaml` for existing image handling packages before adding new ones.

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Large images slow down generation | Aggressive resize to 2000px max |
| Base64 encoding increases payload size | Limit to 3 images, resize before encoding |
| User confusion with step flow | Clear skip option, auto-skip if no images |
| Gemini API rejects multi-modal input | Test with Gemini 3 Pro Image Preview first |

---

## Future Enhancements

1. **Smart image suggestions** - Automatically suggest most relevant images based on recency or AI analysis
2. **Image cropping** - Let users crop to specific region before sending
3. **Reference from other tasks** - Allow selecting images from related/parent tasks
4. **Visual similarity** - Group similar images to avoid redundant selections

---

## Sources
- [Gemini Image Generation Guide](https://ai.google.dev/gemini-api/docs/image-generation)
- [Gemini Vision/Multimodal](https://ai.google.dev/gemini-api/docs/vision)
- Existing implementation: `2026-01-04_nano_banana_pro_image_generation.md`
