import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Size of the "this navigates somewhere" chevron, shared by [LinkedTaskRow]
/// and the header's blocked-by chip so the same affordance is the same glyph
/// at the same size everywhere it appears in this feature.
const double linkedRowChevronSize = 14;

/// One row's content: the other task in the link.
///
/// Deliberately just the task — direction and relationship kind are stated by
/// the section header the row sits under, never repeated per row.
class LinkedTaskRowData {
  const LinkedTaskRowData({required this.task});

  final Task task;
}

/// A single row in the linked-tasks card: status glyph, title, and either a
/// chevron (browse mode) or edit/unlink buttons (manage mode, only for
/// whichever of [onEdit]/[onUnlink] is supplied). Shared by the flat
/// plain-link list and the typed relationship sections — one template for
/// every row on the card.
class LinkedTaskRow extends StatelessWidget {
  const LinkedTaskRow({
    required this.taskId,
    required this.data,
    required this.manageMode,
    this.onEdit,
    this.onUnlink,
    super.key,
  });

  final String taskId;
  final LinkedTaskRowData data;
  final bool manageMode;

  /// Opens the edit-relationship modal for this row's link. Null hides the
  /// edit affordance even in manage mode (used for rows with no relationship
  /// to retype, e.g. none today, but kept optional for forward compat).
  final Future<void> Function()? onEdit;

  /// Invoked after the user confirms the unlink dialog; awaited so a failure
  /// can be surfaced via a SnackBar instead of silently leaving the row
  /// displayed with no feedback. Null hides the unlink affordance even in
  /// manage mode (falls back to the plain chevron) rather than showing a
  /// control that does nothing.
  final Future<void> Function()? onUnlink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final task = data.task;

    return InkWell(
      onTap: manageMode
          ? null
          : () => openLinkedTaskDetail(context: context, taskId: task.id),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          children: [
            StatusGlyph(status: task.data.status),
            SizedBox(width: tokens.spacing.step2),
            Expanded(
              child: Text(
                task.data.title,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            if (manageMode && (onEdit != null || onUnlink != null)) ...[
              if (onEdit != null)
                IconButton(
                  tooltip: context.messages.editLinkTypeTooltip,
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  // Not Icons.edit_outlined — that glyph is StatusGlyph's own
                  // icon for TaskStatus.groomed, so a Groomed row in manage
                  // mode would show the same pencil twice with two different
                  // meanings right next to each other.
                  icon: Icon(
                    Icons.swap_horiz_rounded,
                    size: 16,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              if (onUnlink != null)
                IconButton(
                  tooltip: context.messages.unlinkButton,
                  onPressed: () => _confirmUnlink(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
            ] else
              Icon(
                Icons.arrow_forward_ios,
                size: linkedRowChevronSize,
                color: tokens.colors.text.lowEmphasis,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.messages.unlinkTaskTitle),
        content: Text(ctx.messages.unlinkTaskConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.messages.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.messages.unlinkButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await onUnlink?.call();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.messages.unlinkTaskFailedMessage)),
        );
      }
    }
  }
}

/// Task-status icon + color glyph, shared by every linked-task row and the
/// task search picker.
class StatusGlyph extends StatelessWidget {
  const StatusGlyph({required this.status, super.key});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Icon(
      taskIconFromStatusString(status.toDbString),
      size: 16,
      color: taskColorFromStatusString(
        status.toDbString,
        brightness: brightness,
      ),
    );
  }
}
