import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/tasks/services/checklist_markdown_exporter.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/correction_undo_snackbar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/services/share_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// A convenience wrapper that wires a checklist instance to its state and
/// provides export/share actions.
///
/// Responsibilities
/// - Reads checklist/item state and passes it to [ChecklistWidget].
/// - Implements export (copy Markdown) and share (emoji list) callbacks.
/// - Shows a one‑time mobile hint after the first successful copy: "Long press
///   to share".
class ChecklistWrapper extends ConsumerWidget {
  const ChecklistWrapper({
    required this.entryId,
    required this.taskId,
    this.categoryId,
    this.isSortingMode = false,
    this.onExpansionChanged,
    this.initiallyExpanded,
    super.key,
  });

  final String entryId;
  final String taskId;
  final String? categoryId;

  /// Whether global sorting mode is active.
  final bool isSortingMode;

  /// Called when the checklist's expansion state changes.
  // ignore: avoid_positional_boolean_parameters
  final void Function(String checklistId, bool isExpanded)? onExpansionChanged;

  /// Override initial expansion state (used to restore after sorting).
  final bool? initiallyExpanded;

  /// Preferences key for the one‑time mobile “Long press to share” hint.
  static const _shareHintSeenKey = 'seen_checklist_share_hint';

  Future<List<ChecklistItem?>> _resolveChecklistItems(
    WidgetRef ref,
    Checklist checklist,
  ) {
    final futures =
        checklist.data.linkedChecklistItems.map<Future<ChecklistItem?>>(
      (id) => ref
          .read(
            checklistItemControllerProvider((id: id, taskId: taskId)).future,
          )
          .catchError((Object _, StackTrace __) => null),
    );
    return Future.wait<ChecklistItem?>(futures);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = checklistControllerProvider((id: entryId, taskId: taskId));
    final notifier = ref.read(provider.notifier);
    final checklist = ref.watch(provider).value;

    final completionRate = ref
        .watch(
          checklistCompletionRateControllerProvider((
            id: entryId,
            taskId: taskId,
          )),
        )
        .value;

    final completionCounts = ref
        .watch(
          checklistCompletionControllerProvider((
            id: entryId,
            taskId: taskId,
          )),
        )
        .value;

    // Listen for pending correction events and show countdown snackbar
    ref.listen<PendingCorrection?>(
      correctionCaptureProvider,
      (previous, next) {
        if (next != null && previous != next) {
          final notifier = ref.read(correctionCaptureProvider.notifier);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: CorrectionUndoSnackbarContent(
                  pending: next,
                  onUndo: () {
                    notifier.cancel();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
                backgroundColor: context.colorScheme.primaryContainer,
                behavior: SnackBarBehavior.floating,
                duration: kCorrectionSaveDelay + const Duration(seconds: 1),
                padding: EdgeInsets.zero,
              ),
            );
        }
      },
    );

    if (checklist == null || completionRate == null) {
      return const SizedBox.shrink();
    }

    return DropRegion(
      formats: Formats.standardFormats,
      onDropOver: (event) {
        return DropOperation.move;
      },
      onPerformDrop: (event) async {
        final item = event.session.items.first;
        final localData = item.localData;
        if (localData != null) {
          await notifier.dropChecklistItem(
            localData,
            categoryId: categoryId,
          );
        }
      },
      child: ChecklistWidget(
        id: checklist.id,
        taskId: taskId,
        title: checklist.data.title,
        itemIds: checklist.data.linkedChecklistItems,
        onTitleSave: notifier.updateTitle,
        onCreateChecklistItem: (title) => notifier.createChecklistItem(
          title,
          isChecked: false,
          categoryId: checklist.meta.categoryId,
        ),
        updateItemOrder: notifier.updateItemOrder,
        completionRate: completionRate,
        completedCount: completionCounts?.completedCount,
        totalCount: completionCounts?.totalCount,
        onDelete: ref.read(provider.notifier).delete,
        isSortingMode: isSortingMode,
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged != null
            ? (isExpanded) => onExpansionChanged!(entryId, isExpanded)
            : null,
        onExportMarkdown: () async {
          final messenger = ScaffoldMessenger.of(context);
          final nothingToExportMsg = context.messages.checklistNothingToExport;
          final copiedMsg = context.messages.checklistMarkdownCopied;
          final shareHintMsg = context.messages.checklistShareHint;
          final exportFailedMsg = context.messages.checklistExportFailed;

          try {
            final resolved = await _resolveChecklistItems(ref, checklist);
            final markdown = checklistItemsToMarkdown(resolved);

            if (markdown.isEmpty) {
              messenger.showSnackBar(
                SnackBar(content: Text(nothingToExportMsg)),
              );
              return;
            }

            await ref.read(appClipboardProvider).writePlainText(markdown);

            final prefs = makeSharedPrefsService();
            final seen = await prefs.getBool(_shareHintSeenKey) ?? false;
            final effectiveMsg = (!isTestEnv && !seen)
                ? '$copiedMsg — $shareHintMsg'
                : copiedMsg;
            messenger.showSnackBar(
              SnackBar(content: Text(effectiveMsg)),
            );
            if (!isTestEnv && !seen) {
              await prefs.setBool(key: _shareHintSeenKey, value: true);
            }
          } catch (_) {
            messenger.showSnackBar(SnackBar(
              content: Text(exportFailedMsg),
            ));
          }
        },
        onShareMarkdown: () async {
          // Build the same markdown and trigger the platform share sheet.
          try {
            final resolved = await _resolveChecklistItems(ref, checklist);
            final shareText = checklistItemsToEmojiList(resolved);
            if (shareText.isEmpty) {
              return; // nothing to share
            }
            await ShareService.instance
                .shareText(text: shareText, subject: checklist.data.title);
          } catch (_) {
            // Silently ignore share errors to avoid disrupting UX.
          }
        },
      ),
    );
  }
}
