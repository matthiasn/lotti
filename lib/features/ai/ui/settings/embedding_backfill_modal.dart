import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/embedding_backfill_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class EmbeddingBackfillModal {
  const EmbeddingBackfillModal._();

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final selectedCategoryNotifier = ValueNotifier<CategoryDefinition?>(null);

    try {
      await ConfirmationProgressModal.show(
        context: context,
        message: context.messages.maintenanceBackfillEmbeddingsMessage,
        confirmLabel: context.messages.maintenanceBackfillEmbeddingsConfirm,
        isDestructive: false,
        closeOnComplete: false,
        confirmEnabledListenable: selectedCategoryNotifier,
        isConfirmEnabled: () => selectedCategoryNotifier.value != null,
        confirmationContent: _CategoryPicker(
          selectedCategoryNotifier: selectedCategoryNotifier,
        ),
        operation: () {
          final categoryId = selectedCategoryNotifier.value?.id;
          if (categoryId == null) return Future<void>.value();
          return container
              .read(embeddingBackfillControllerProvider.notifier)
              .backfillCategory(categoryId);
        },
        progressBuilder: (context) => _BackfillProgress(
          selectedCategoryNotifier: selectedCategoryNotifier,
        ),
      );
    } finally {
      selectedCategoryNotifier.dispose();
    }
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selectedCategoryNotifier});

  final ValueNotifier<CategoryDefinition?> selectedCategoryNotifier;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: CategorySelectionModalContent(
        onCategorySelected: (category) {
          selectedCategoryNotifier.value = category;
        },
      ),
    );
  }
}

class _BackfillProgress extends ConsumerWidget {
  const _BackfillProgress({required this.selectedCategoryNotifier});

  final ValueNotifier<CategoryDefinition?> selectedCategoryNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backfillState = ref.watch(embeddingBackfillControllerProvider);
    final progress = backfillState.progress;
    final isRunning = backfillState.isRunning;
    final error = backfillState.error;
    final categoryName = selectedCategoryNotifier.value?.name ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        if (error != null)
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          )
        else if (progress >= 1.0 && !isRunning)
          Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '100%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 5,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        if (error != null)
          Text(
            error,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          )
        else ...[
          Text(
            categoryName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.messages.maintenanceBackfillEmbeddingsProgress(
              backfillState.processedCount,
              backfillState.totalCount,
              backfillState.embeddedCount,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
