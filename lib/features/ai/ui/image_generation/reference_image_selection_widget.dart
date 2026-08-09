import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/reference_image_selection_controller.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/image_utils.dart';

/// Widget for selecting task images as AI reference inputs.
///
/// Displays a grid of images linked to a task and allows the user to
/// select up to [maxImages] images as visual references.
class ReferenceImageSelectionWidget extends ConsumerStatefulWidget {
  const ReferenceImageSelectionWidget({
    required this.taskId,
    required this.onContinue,
    required this.onSkip,
    this.maxImages = kMaxReferenceImages,
    super.key,
  });

  final String taskId;
  final void Function(List<ProcessedReferenceImage> images) onContinue;
  final VoidCallback onSkip;
  final int maxImages;

  @override
  ConsumerState<ReferenceImageSelectionWidget> createState() =>
      _ReferenceImageSelectionWidgetState();
}

class _ReferenceImageSelectionWidgetState
    extends ConsumerState<ReferenceImageSelectionWidget> {
  bool _hasAutoSkipped = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final state = ref.watch(
      referenceImageSelectionControllerProvider(widget.taskId),
    );
    final controller = ref.read(
      referenceImageSelectionControllerProvider(widget.taskId).notifier,
    );

    if (state.isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.step8),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    // Handle error state
    if (state.errorCode != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.step8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: IconSizes.xxxl,
                color: context.colorScheme.error,
              ),
              SizedBox(height: spacing.step5),
              Text(
                _getLocalizedError(context, state.errorCode!),
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: spacing.step5),
              DesignSystemButton(
                label: context.messages.referenceImageSkip,
                onPressed: widget.onSkip,
                size: DesignSystemButtonSize.large,
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
            padding: EdgeInsets.all(spacing.step5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.messages.referenceImageSelectionTitle,
                    style: tokens.typography.styles.subtitle.subtitle2,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.step3,
                    vertical: spacing.step1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      tokens.radii.badgesPills,
                    ),
                  ),
                  child: Text(
                    '${state.selectionCount}/${widget.maxImages}',
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subtitle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.step5),
            child: Text(
              context.messages.referenceImageSelectionSubtitle(
                widget.maxImages,
              ),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
          SizedBox(height: spacing.step5),

          // Image grid — shrinkWrap so it works in unbounded height contexts
          // (e.g., inside modal sheets with scrollable content)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.step5),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: spacing.step3,
                mainAxisSpacing: spacing.step3,
              ),
              itemCount: state.availableImages.length,
              itemBuilder: (context, index) {
                final image = state.availableImages[index];
                final isSelected = state.selectedImageIds.contains(
                  image.meta.id,
                );
                final canSelect =
                    state.selectionCount < widget.maxImages || isSelected;
                final isFromLinkedTask = state.linkedTaskImageIds.contains(
                  image.meta.id,
                );

                return _ImageGridTile(
                  image: image,
                  isSelected: isSelected,
                  canSelect: canSelect,
                  isFromLinkedTask: isFromLinkedTask,
                  onTap: () => controller.toggleImageSelection(
                    image.meta.id,
                    maxImages: widget.maxImages,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: spacing.step6),

          // Action button — always pinned at the bottom
          Padding(
            padding: EdgeInsets.all(spacing.step5),
            child: DesignSystemButton(
              label: state.selectionCount > 0
                  ? context.messages.referenceImageContinueWithCount(
                      state.selectionCount,
                    )
                  : context.messages.referenceImageContinue,
              leadingIcon: Icons.arrow_forward_rounded,
              size: DesignSystemButtonSize.large,
              onPressed: state.isProcessing
                  ? null
                  : () async {
                      final images = await controller.processSelectedImages();
                      if (!mounted) return;
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
    required this.isFromLinkedTask,
    required this.onTap,
  });

  final JournalImage image;
  final bool isSelected;
  final bool canSelect;
  final bool isFromLinkedTask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final file = File(getFullImagePath(image));

    return GestureDetector(
      onTap: canSelect ? onTap : null,
      child: AnimatedContainer(
        duration: MotionDurations.short4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: BorderWidths.emphasis,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.s),
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
                ColoredBox(
                  color: colorScheme.scrim.withValues(alpha: 0.54),
                ),
              // Selection indicator
              if (isSelected)
                Positioned(
                  top: spacing.step1,
                  right: spacing.step1,
                  child: Container(
                    padding: EdgeInsets.all(spacing.step1),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: IconSizes.s,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              // Linked-task indicator
              if (isFromLinkedTask)
                Positioned(
                  bottom: spacing.step1,
                  left: spacing.step1,
                  child: Tooltip(
                    message: context.messages.linkedTaskImageBadge,
                    child: Container(
                      padding: EdgeInsets.all(spacing.step1),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(
                          alpha: 0.85,
                        ),
                        borderRadius: BorderRadius.circular(tokens.radii.xs),
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        size: IconSizes.xs,
                        color: colorScheme.onSecondaryContainer,
                      ),
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
