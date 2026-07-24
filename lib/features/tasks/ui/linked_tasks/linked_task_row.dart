import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
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

    final showActions = manageMode && (onEdit != null || onUnlink != null);
    final statusLabel = taskLabelFromStatusString(
      task.data.status.toDbString,
      context,
    );

    return DesignSystemListItem(
      // Navigable in manage mode too: the edit/unlink buttons are additive,
      // so nulling this only produced a row that looked tappable and wasn't.
      onTap: () => openLinkedTaskDetail(context: context, taskId: task.id),
      title: task.data.title,
      titleMaxLines: 2,
      size: DesignSystemListItemSize.small,
      semanticsLabel: '${task.data.title}, $statusLabel',
      leading: StatusGlyph(status: task.data.status),
      // Status as a trailing anchor rather than a second line: it keeps the
      // row one line tall, and on a wide detail pane it stops the trailing
      // affordance floating alone at the far edge of an otherwise empty row.
      trailing: showActions
          ? null
          : Text(
              statusLabel,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
      trailingExtra: showActions
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  _RowAction(
                    tooltip: context.messages.editLinkTypeTooltip,
                    onPressed: () => onEdit?.call(),
                    // Not Icons.edit_outlined — that glyph is StatusGlyph's
                    // own icon for TaskStatus.groomed, so a Groomed row in
                    // manage mode would show the same pencil twice with two
                    // different meanings right next to each other.
                    icon: Icons.swap_horiz_rounded,
                  ),
                if (onEdit != null && onUnlink != null)
                  SizedBox(width: tokens.spacing.step2),
                if (onUnlink != null)
                  _RowAction(
                    tooltip: context.messages.unlinkButton,
                    onPressed: () => _confirmUnlink(context),
                    icon: Icons.close_rounded,
                    // The destructive one carries more weight than its
                    // neighbour so the two aren't interchangeable smudges.
                    emphasis: tokens.colors.text.mediumEmphasis,
                  ),
              ],
            )
          : Icon(
              Icons.arrow_forward_ios,
              size: linkedRowChevronSize,
              color: tokens.colors.text.lowEmphasis,
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

/// One manage-mode action on a [LinkedTaskRow]. Sized from the design
/// system's own minimum interactive target rather than a 32px literal, so the
/// edit and unlink glyphs are comfortably hittable.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.emphasis,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final target = tokens.spacing.step9;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: target, minHeight: target),
      icon: Icon(
        icon,
        size: tokens.spacing.step5,
        color: emphasis ?? tokens.colors.text.lowEmphasis,
      ),
    );
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
