import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/image_generation/reference_image_selection_widget.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// A modal for selecting reference images and triggering background cover art
/// generation via the skill system.
///
/// After the user selects reference images and taps "Continue", the modal
/// transitions to a progress view showing the Siri waveform animation.
/// The user can dismiss the modal at any time without stopping the background
/// generation, which continues via `SkillInferenceRunner.runImageGeneration`.
class CoverArtSkillModal extends ConsumerStatefulWidget {
  const CoverArtSkillModal({
    required this.entityId,
    required this.skillId,
    required this.linkedTaskId,
    required this.parentRef,
    this.categoryId,
    super.key,
  });

  /// The ID of the audio entry that provides the voice description.
  final String entityId;

  /// The ID of the image generation skill to invoke.
  final String skillId;

  /// The ID of the task to which the cover art will be assigned.
  final String linkedTaskId;

  /// Optional category ID for the generated image entry.
  final String? categoryId;

  /// A [WidgetRef] from the parent context, used to trigger the skill
  /// provider after the modal closes.
  final WidgetRef parentRef;

  /// Shows the cover art skill modal.
  static Future<void> show({
    required BuildContext context,
    required String entityId,
    required String skillId,
    required String linkedTaskId,
    required WidgetRef ref,
    String? categoryId,
  }) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.imageGenerationModalTitle,
      builder: (modalContext) => CoverArtSkillModal(
        entityId: entityId,
        skillId: skillId,
        linkedTaskId: linkedTaskId,
        categoryId: categoryId,
        parentRef: ref,
      ),
    );
  }

  @override
  ConsumerState<CoverArtSkillModal> createState() => _CoverArtSkillModalState();
}

class _CoverArtSkillModalState extends ConsumerState<CoverArtSkillModal> {
  bool _isGenerating = false;
  int _referenceImageCount = 0;

  void _handleImageSelectionContinue(List<ProcessedReferenceImage> images) {
    _triggerGeneration(images);
  }

  void _handleSkipImageSelection() {
    _triggerGeneration([]);
  }

  void _triggerGeneration(List<ProcessedReferenceImage> referenceImages) {
    developer.log(
      'CoverArtSkillModal: triggering generation for entity '
      '${widget.entityId} with ${referenceImages.length} reference images',
      name: 'CoverArtSkillModal',
    );

    setState(() {
      _isGenerating = true;
      _referenceImageCount = referenceImages.length;
    });

    // Fire-and-forget: trigger the skill via the parent ref so the provider
    // survives modal disposal.
    unawaited(
      widget.parentRef.read(
        triggerSkillProvider((
          entityId: widget.entityId,
          skillId: widget.skillId,
          linkedTaskId: widget.linkedTaskId,
          referenceImages: referenceImages.isNotEmpty ? referenceImages : null,
        )).future,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return _CoverArtProgressView(
        entityId: widget.entityId,
        linkedTaskId: widget.linkedTaskId,
        referenceImageCount: _referenceImageCount,
      );
    }

    return ReferenceImageSelectionWidget(
      taskId: widget.linkedTaskId,
      onContinue: _handleImageSelectionContinue,
      onSkip: _handleSkipImageSelection,
    );
  }
}

/// Progress view shown while cover art is being generated in the background.
///
/// Watches [InferenceStatusController] for the linked task to reflect
/// generation status. The user can dismiss the modal at any time — the
/// generation continues via `ref.keepAlive()` in `triggerSkillProvider`.
class _CoverArtProgressView extends ConsumerWidget {
  const _CoverArtProgressView({
    required this.entityId,
    required this.linkedTaskId,
    required this.referenceImageCount,
  });

  final String entityId;
  final String linkedTaskId;
  final int referenceImageCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      inferenceStatusControllerProvider(
        id: linkedTaskId,
        aiResponseType: AiResponseType.imageGeneration,
      ),
    );

    final colorScheme = context.colorScheme;
    final isComplete = status == InferenceStatus.idle;
    final isError = status == InferenceStatus.error;
    final isRunning = status == InferenceStatus.running;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          // Status icon or animation
          if (isRunning)
            const SizedBox(
              height: 60,
              child: AiRunningAnimation(height: 60),
            )
          else if (isError)
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error,
            )
          else if (isComplete)
            Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
          const SizedBox(height: 24),
          // Status text
          Text(
            _statusText(context, status),
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          // Subtitle with reference image count
          Text(
            _subtitleText(context, status),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _statusText(BuildContext context, InferenceStatus status) {
    return switch (status) {
      InferenceStatus.running => context.messages.imageGenerationGenerating,
      InferenceStatus.error => context.messages.imageGenerationError,
      InferenceStatus.idle => context.messages.coverArtGenerationComplete,
    };
  }

  String _subtitleText(BuildContext context, InferenceStatus status) {
    if (status == InferenceStatus.error) {
      return context.messages.coverArtGenerationDismissHint;
    }
    if (status == InferenceStatus.idle) {
      return context.messages.coverArtGenerationDismissHint;
    }
    // Running
    if (referenceImageCount > 0) {
      return context.messages.imageGenerationWithReferences(
        referenceImageCount,
      );
    }
    return context.messages.coverArtGenerationDismissHint;
  }
}
