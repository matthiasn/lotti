import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/embedding_backfill_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/settings/ui/confirmation_progress_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';

/// Entry point for the "generate embeddings" maintenance flow.
///
/// Lets the user pick which categories to (re)embed, then runs the backfill
/// through `embeddingBackfillControllerProvider` while showing live progress.
class EmbeddingBackfillModal {
  const EmbeddingBackfillModal._();

  /// Opens the confirmation + progress modal. Confirm stays disabled until at
  /// least one category is selected; on confirm it backfills the selected
  /// categories and keeps the sheet open to show progress until completion.
  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    final selectedIdsNotifier = ValueNotifier<Set<String>>({});
    final allCategoryIds = getIt<EntitiesCacheService>().sortedCategories
        .map((c) => c.id)
        .toSet();

    try {
      await ConfirmationProgressModal.show(
        context: context,
        message: context.messages.maintenanceGenerateEmbeddingsMessage,
        confirmLabel: context.messages.maintenanceGenerateEmbeddingsConfirm,
        isDestructive: false,
        closeOnComplete: false,
        confirmEnabledListenable: selectedIdsNotifier,
        isConfirmEnabled: () => selectedIdsNotifier.value.isNotEmpty,
        confirmationContent: _MultiCategoryPicker(
          selectedIdsNotifier: selectedIdsNotifier,
          allCategoryIds: allCategoryIds,
        ),
        operation: () {
          final categoryIds = selectedIdsNotifier.value;
          if (categoryIds.isEmpty) return Future<void>.value();
          return container
              .read(embeddingBackfillControllerProvider.notifier)
              .backfillCategories(categoryIds);
        },
        progressBuilder: (context) => const _BackfillProgressContent(),
      );
    } finally {
      selectedIdsNotifier.dispose();
    }
  }
}

class _MultiCategoryPicker extends StatelessWidget {
  const _MultiCategoryPicker({
    required this.selectedIdsNotifier,
    required this.allCategoryIds,
  });

  final ValueNotifier<Set<String>> selectedIdsNotifier;
  final Set<String> allCategoryIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<Set<String>>(
          valueListenable: selectedIdsNotifier,
          builder: (context, selectedIds, _) {
            final allSelected =
                allCategoryIds.isNotEmpty &&
                allCategoryIds.every(selectedIds.contains);
            return Align(
              alignment: Alignment.centerRight,
              child: DesignSystemButton(
                variant: DesignSystemButtonVariant.tertiary,
                label: allSelected
                    ? context.messages.embeddingUnselectAll
                    : context.messages.embeddingSelectAll,
                onPressed: () {
                  selectedIdsNotifier.value = allSelected
                      ? {}
                      : Set.of(allCategoryIds);
                },
              ),
            );
          },
        ),
        SizedBox(
          height: 260,
          child: CategoryPickerSheet(
            mode: CategoryPickerMode.multi,
            options: getIt<EntitiesCacheService>().sortedCategories,
            stagedNotifier: selectedIdsNotifier,
            // The progress modal owns the confirm action — no Apply footer.
            reserveFooterInset: false,
          ),
        ),
      ],
    );
  }
}

/// Shared progress content for the generate embeddings modal.
///
/// Shows a progress bar while running, a checkmark on completion, and an
/// error icon with message on failure.
class _BackfillProgressContent extends ConsumerWidget {
  const _BackfillProgressContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backfillState = ref.watch(embeddingBackfillControllerProvider);
    final progress = backfillState.progress;
    final isRunning = backfillState.isRunning;
    final error = backfillState.error;

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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
        else
          Text(
            context.messages.maintenanceGenerateEmbeddingsProgress(
              backfillState.processedCount,
              backfillState.totalCount,
              backfillState.embeddedCount,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}
