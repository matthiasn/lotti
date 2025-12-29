import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/labels/label_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/search/index.dart';

/// Utility functions for opening the label selection modal.
///
/// Consolidates the modal opening logic used by both ModernLabelsItem
/// and EntryLabelsDisplay to avoid code duplication.
class LabelSelectionModalUtils {
  LabelSelectionModalUtils._();

  /// Opens the label selection modal for a journal entry.
  ///
  /// [context] - Build context for showing the modal
  /// [entryId] - The ID of the entry being labeled
  /// [initialLabelIds] - Currently assigned label IDs
  /// [categoryId] - Optional category ID for filtering labels
  static Future<void> openLabelSelector({
    required BuildContext context,
    required String entryId,
    required List<String> initialLabelIds,
    String? categoryId,
  }) async {
    final applyController = ValueNotifier<Future<bool> Function()?>(null);
    final searchNotifier = ValueNotifier<String>('');
    final searchController = TextEditingController();

    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        titleWidget: Padding(
          padding:
              const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 8),
          child: LottiSearchBar(
            hintText: context.messages.tasksLabelsSheetSearchHint,
            controller: searchController,
            useGradientInDark: false,
            onChanged: (value) => searchNotifier.value = value,
            onClear: () {
              searchNotifier.value = '';
              searchController.clear();
            },
            textCapitalization: TextCapitalization.words,
          ),
        ),
        navBarHeight: 80,
        stickyActionBar:
            LabelSelectionStickyActionBar(applyController: applyController),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        builder: (ctx) {
          final minHeight = MediaQuery.of(ctx).size.height * 0.5;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: LabelSelectionModalContent(
              entryId: entryId,
              initialLabelIds: initialLabelIds,
              categoryId: categoryId,
              applyController: applyController,
              searchQuery: searchNotifier,
            ),
          );
        },
      );
    } finally {
      applyController.dispose();
      searchNotifier.dispose();
      searchController.dispose();
    }
  }
}

/// Sticky action bar widget for the label selection modal.
///
/// Contains Cancel and Apply buttons with proper styling.
class LabelSelectionStickyActionBar extends StatelessWidget {
  const LabelSelectionStickyActionBar({
    required this.applyController,
    super.key,
  });

  final ValueNotifier<Future<bool> Function()?> applyController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.messages.cancelButton),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<Future<bool> Function()?>(
                valueListenable: applyController,
                builder: (context, applyFn, _) {
                  return FilledButton(
                    onPressed: applyFn == null
                        ? null
                        : () async {
                            final ok = await applyFn();
                            if (!context.mounted) return;
                            if (ok) {
                              Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.messages.tasksLabelsUpdateFailed,
                                  ),
                                ),
                              );
                            }
                          },
                    child: Text(context.messages.tasksLabelsSheetApply),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
