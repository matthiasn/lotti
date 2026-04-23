import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/tasks/services/checklist_markdown_exporter.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card.dart';
import 'package:lotti/features/tasks/ui/checklists/correction_undo_snackbar.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_section_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/share_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// Wires a checklist entity to its [ChecklistCard] and handles all
/// side-effects: provider subscriptions, export/share, correction capture
/// snackbars, and drop-zone for cross-checklist item moves.
///
/// Replaces the old `ChecklistWrapper`.
class ChecklistCardWrapper extends ConsumerWidget {
  const ChecklistCardWrapper({
    required this.entryId,
    required this.taskId,
    this.categoryId,
    this.isSortingMode = false,
    this.onExpansionChanged,
    this.initiallyExpanded,
    this.reorderIndex,
    super.key,
  });

  final String entryId;
  final String taskId;
  final String? categoryId;

  final bool isSortingMode;

  // ignore: avoid_positional_boolean_parameters
  final void Function(String checklistId, bool isExpanded)? onExpansionChanged;
  final bool? initiallyExpanded;
  final int? reorderIndex;

  static const _shareHintSeenKey = 'seen_checklist_share_hint';

  Future<List<ChecklistItem?>> _resolveItems(
    WidgetRef ref,
    Checklist checklist,
  ) {
    return Future.wait(
      checklist.data.linkedChecklistItems.map<Future<ChecklistItem?>>(
        (id) => ref
            .read(
              checklistItemControllerProvider((id: id, taskId: taskId)).future,
            )
            .catchError((Object error, StackTrace stackTrace) {
              if (getIt.isRegistered<LoggingService>()) {
                getIt<LoggingService>().captureException(
                  'Failed to resolve checklist item $id: $error',
                  domain: 'ChecklistCardWrapper',
                  subDomain: '_resolveItems',
                  stackTrace: stackTrace,
                );
              }
              return null;
            }),
      ),
    );
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

    // Show correction-capture snackbar.
    ref.listen<PendingCorrection?>(
      correctionCaptureProvider,
      (previous, next) {
        if (next != null && previous != next) {
          final captureNotifier = ref.read(correctionCaptureProvider.notifier);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: CorrectionUndoSnackbarContent(
                  pending: next,
                  onUndo: () {
                    captureNotifier.cancel();
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
      onDropOver: (_) => DropOperation.move,
      onPerformDrop: (event) async {
        if (event.session.items.isEmpty) return;
        final localData = event.session.items.first.localData;
        if (localData != null) {
          await notifier.dropChecklistItem(localData, categoryId: categoryId);
        }
      },
      child: TaskDetailSectionCard(
        margin: const EdgeInsets.only(bottom: AppTheme.cardSpacing),
        padding: EdgeInsets.zero,
        child: ChecklistCard(
          id: checklist.id,
          taskId: taskId,
          title: checklist.data.title,
          itemIds: checklist.data.linkedChecklistItems,
          completionRate: completionRate,
          completedCount: completionCounts?.completedCount,
          totalCount: completionCounts?.totalCount,
          isSortingMode: isSortingMode,
          initiallyExpanded: initiallyExpanded,
          reorderIndex: reorderIndex,
          onExpansionChanged: onExpansionChanged != null
              ? (isExpanded) => onExpansionChanged!(entryId, isExpanded)
              : null,
          onTitleSave: notifier.updateTitle,
          onCreateItem: (title) => notifier.createChecklistItem(
            title,
            isChecked: false,
            categoryId: checklist.meta.categoryId,
          ),
          onReorder: notifier.updateItemOrder,
          onDelete: notifier.delete,
          onExportMarkdown: () async {
            final nothingMsg = context.messages.checklistNothingToExport;
            final copiedMsg = context.messages.checklistMarkdownCopied;
            final shareHintMsg = context.messages.checklistShareHint;
            final failedMsg = context.messages.checklistExportFailed;

            try {
              final resolved = await _resolveItems(ref, checklist);
              final markdown = checklistItemsToMarkdown(resolved);

              if (markdown.isEmpty) {
                if (!context.mounted) return;
                context.showToast(
                  tone: DesignSystemToastTone.warning,
                  title: nothingMsg,
                );
                return;
              }

              await ref.read(appClipboardProvider).writePlainText(markdown);

              // Clipboard write succeeded — from here on, any failure in
              // best-effort share-hint bookkeeping must NOT flip the
              // success toast into an error toast.
              final prefs = makeSharedPrefsService();
              final seen =
                  await prefs.getBool(_shareHintSeenKey).catchError((_) {
                    return false;
                  }) ??
                  false;
              final shouldShowShareHint = !isTestEnv && !seen;

              if (!context.mounted) return;
              final msg = shouldShowShareHint
                  ? '$copiedMsg — $shareHintMsg'
                  : copiedMsg;
              context.showToast(
                tone: DesignSystemToastTone.success,
                title: msg,
              );

              if (shouldShowShareHint) {
                // Fire-and-forget: never let a prefs failure surface as an
                // export error after the clipboard already succeeded.
                unawaited(
                  prefs
                      .setBool(key: _shareHintSeenKey, value: true)
                      .catchError((_) => false),
                );
              }
            } catch (_) {
              if (!context.mounted) return;
              context.showToast(
                tone: DesignSystemToastTone.error,
                title: failedMsg,
              );
            }
          },
          onShareMarkdown: () async {
            try {
              final resolved = await _resolveItems(ref, checklist);
              final shareText = checklistItemsToEmojiList(resolved);
              if (shareText.isEmpty) return;
              await ShareService.instance.shareText(
                text: shareText,
                subject: checklist.data.title,
              );
            } catch (error, stackTrace) {
              if (getIt.isRegistered<LoggingService>()) {
                getIt<LoggingService>().captureException(
                  'Failed to share checklist: $error',
                  domain: 'ChecklistCardWrapper',
                  subDomain: 'onShareMarkdown',
                  stackTrace: stackTrace,
                );
              }
            }
          },
        ),
      ),
    );
  }
}
