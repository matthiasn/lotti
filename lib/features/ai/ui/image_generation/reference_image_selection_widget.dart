import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

/// Widget for selecting reference images to guide cover art generation.
///
/// Displays a grid of images linked to a task and allows the user to
/// select up to [kMaxReferenceImages] images as visual references.
class ReferenceImageSelectionWidget extends ConsumerStatefulWidget {
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
  ConsumerState<ReferenceImageSelectionWidget> createState() =>
      _ReferenceImageSelectionWidgetState();
}

class _ReferenceImageSelectionWidgetState
    extends ConsumerState<ReferenceImageSelectionWidget> {
  bool _hasAutoSkipped = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      referenceImageSelectionControllerProvider(taskId: widget.taskId),
    );
    final controller = ref.read(
      referenceImageSelectionControllerProvider(taskId: widget.taskId).notifier,
    );

    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle error state
    if (state.errorCode != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: context.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _getLocalizedError(context, state.errorCode!),
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              LottiPrimaryButton(
                label: context.messages.referenceImageSkip,
                onPressed: widget.onSkip,
              ),
            ],
          ),
        ),
      );
    }

    if (state.availableImages.isEmpty) {
      // No images available, skip this step automatically (only once)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAutoSkipped) {
          _hasAutoSkipped = true;
          widget.onSkip();
        }
      });
      return const SizedBox.shrink();
    }

    final colorScheme = context.colorScheme;

    return SingleChildScrollView(
      child: Column(
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.selectionCount}/$kMaxReferenceImages',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Image grid — shrinkWrap so it works in unbounded height contexts
          // (e.g., inside modal sheets with scrollable content)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: state.availableImages.length,
              itemBuilder: (context, index) {
                final image = state.availableImages[index];
                final isSelected =
                    state.selectedImageIds.contains(image.meta.id);
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
          const SizedBox(height: 24),

          // Action button — always pinned at the bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: LottiPrimaryButton(
              label: state.selectionCount > 0
                  ? context.messages
                      .referenceImageContinueWithCount(state.selectionCount)
                  : context.messages.referenceImageContinue,
              icon: Icons.arrow_forward_rounded,
              onPressed: state.isProcessing
                  ? null
                  : () async {
                      final images = await controller.processSelectedImages();
                      widget.onContinue(images);
                    },
            ),
          ),
        ],
      ),
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
    final file = File(getFullImagePath(image));

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
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
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

/// Maps error codes to localized strings.
String _getLocalizedError(
  BuildContext context,
  ReferenceImageSelectionError errorCode,
) {
  return switch (errorCode) {
    ReferenceImageSelectionError.loadImagesFailed =>
      context.messages.referenceImageLoadError,
  };
}
