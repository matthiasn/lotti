import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/image_generation_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// A modal widget for reviewing generated cover art images.
///
/// This modal displays the generated image and provides actions to:
/// - Accept the image as cover art for the task
/// - Edit the prompt and regenerate
/// - Cancel and close the modal
class ImageGenerationReviewModal extends ConsumerStatefulWidget {
  const ImageGenerationReviewModal({
    required this.entityId,
    required this.linkedTaskId,
    required this.categoryId,
    required this.initialPrompt,
    super.key,
  });

  /// The ID of the audio entry triggering image generation.
  final String entityId;

  /// The ID of the task to which the cover art will be assigned.
  final String linkedTaskId;

  /// Optional category ID for the generated image entry.
  final String? categoryId;

  /// The initial prompt for image generation.
  final String initialPrompt;

  /// Shows the image generation review modal.
  static Future<void> show({
    required BuildContext context,
    required String entityId,
    required String linkedTaskId,
    required String initialPrompt,
    String? categoryId,
  }) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.imageGenerationModalTitle,
      builder: (modalContext) => ImageGenerationReviewModal(
        entityId: entityId,
        linkedTaskId: linkedTaskId,
        categoryId: categoryId,
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
  bool _isEditingPrompt = false;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.initialPrompt);

    // Start generation on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGeneration();
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _startGeneration() {
    ref
        .read(
          imageGenerationControllerProvider(entityId: widget.entityId).notifier,
        )
        .generateImage(prompt: widget.initialPrompt);
  }

  Future<void> _handleAccept(Uint8List imageBytes, String mimeType) async {
    // Import the generated image as a journal entry linked to the task
    final extension = mimeType.split('/').lastOrNull ?? 'png';

    final imageId = await importGeneratedImageBytes(
      data: imageBytes,
      fileExtension: extension,
      linkedId: widget.linkedTaskId,
      categoryId: widget.categoryId,
    );

    // Set the image as cover art for the task
    if (imageId != null) {
      await _setCoverArtForTask(widget.linkedTaskId, imageId);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Sets the cover art for a task.
  Future<void> _setCoverArtForTask(String taskId, String imageId) async {
    final journalDb = getIt<JournalDb>();
    final persistenceLogic = getIt<PersistenceLogic>();

    final entity = await journalDb.journalEntityById(taskId);
    if (entity is! Task) return;

    final updatedData = entity.data.copyWith(coverArtId: imageId);
    await persistenceLogic.updateTask(
      journalEntityId: taskId,
      taskData: updatedData,
    );
  }

  void _handleEditPrompt() {
    setState(() {
      _isEditingPrompt = true;
    });
  }

  void _handleCancelEdit() {
    setState(() {
      _isEditingPrompt = false;
      _promptController.text = widget.initialPrompt;
    });
  }

  void _handleRegenerateWithNewPrompt() {
    final newPrompt = _promptController.text.trim();
    if (newPrompt.isNotEmpty) {
      setState(() {
        _isEditingPrompt = false;
      });
      ref
          .read(
            imageGenerationControllerProvider(entityId: widget.entityId)
                .notifier,
          )
          .generateImage(prompt: newPrompt);
    }
  }

  void _handleRetry() {
    ref
        .read(
          imageGenerationControllerProvider(entityId: widget.entityId).notifier,
        )
        .retryGeneration();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      imageGenerationControllerProvider(entityId: widget.entityId),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isEditingPrompt)
          _buildPromptEditor(context)
        else
          state.map(
            initial: (_) => _buildLoadingState(context),
            generating: (s) => _buildGeneratingState(context, s.prompt),
            success: (s) => _buildSuccessState(context, s),
            error: (s) => _buildErrorState(context, s),
          ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildGeneratingState(BuildContext context, String prompt) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          CircularProgressIndicator(
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            context.messages.imageGenerationGenerating,
            style: context.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, ImageGenerationSuccess s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image preview with 16:9 aspect ratio
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(
              s.imageBytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Action buttons
        Row(
          children: [
            LottiSecondaryButton(
              label: context.messages.imageGenerationEditPromptButton,
              icon: Icons.edit_outlined,
              onPressed: _handleEditPrompt,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LottiPrimaryButton(
                label: context.messages.imageGenerationAcceptButton,
                icon: Icons.check_rounded,
                onPressed: () => _handleAccept(s.imageBytes, s.mimeType),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, ImageGenerationError s) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.imageGenerationError,
            style: context.textTheme.titleMedium?.copyWith(
              color: colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.errorMessage,
            style: context.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              LottiSecondaryButton(
                label: context.messages.imageGenerationEditPromptButton,
                icon: Icons.edit_outlined,
                onPressed: _handleEditPrompt,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LottiPrimaryButton(
                  label: context.messages.imageGenerationRetry,
                  icon: Icons.refresh_rounded,
                  onPressed: _handleRetry,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromptEditor(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.messages.imageGenerationEditPromptLabel,
            style: context.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            maxLines: 5,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerLow,
            ),
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              LottiSecondaryButton(
                label: context.messages.imageGenerationCancelEdit,
                icon: Icons.close_rounded,
                onPressed: _handleCancelEdit,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LottiPrimaryButton(
                  label: context.messages.generateCoverArt,
                  icon: Icons.auto_awesome_outlined,
                  onPressed: _handleRegenerateWithNewPrompt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
