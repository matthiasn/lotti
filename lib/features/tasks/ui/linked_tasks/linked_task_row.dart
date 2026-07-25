import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

/// Row width from which a status label can share the title's line without
/// crowding it. Deliberately well below the detail reading measure the card is
/// capped at on wide windows: a window-level desktop check would read true
/// while the row it describes is narrower than the value it was compared
/// against, so this is measured against the row's own constraints instead.
const double _trailingStatusMinRowWidth = 520;

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
    this.onOpen,
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

  /// Overrides what tapping the row does. Null keeps the default — open the
  /// linked task's detail view. Supplied by surfaces that must dismiss
  /// themselves first: navigating from inside a modal otherwise lands behind
  /// the barrier, and the tap reads as doing nothing at all.
  final VoidCallback? onOpen;

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

    // Measured against the row's own constraints, not the window: the card is
    // capped at the detail reading measure on wide windows, and it can also
    // sit in a narrow column, so the window width says nothing about how much
    // room this row actually has.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideEnoughForTrailingStatus =
            constraints.maxWidth >= _trailingStatusMinRowWidth;
        return DesignSystemListItem(
          // Navigable in manage mode too: the edit/unlink buttons are additive,
          // so nulling this only produced a row that looked tappable and wasn't.
          onTap:
              onOpen ??
              () => openLinkedTaskDetail(context: context, taskId: task.id),
          title: task.data.title,
          titleMaxLines: 2,
          size: DesignSystemListItemSize.small,
          semanticsLabel: '${task.data.title}, $statusLabel',
          leading: StatusGlyph(status: task.data.status),
          // Status as a trailing anchor rather than a second line: it keeps the
          // row one line tall, and on a wide detail pane it stops the trailing
          // affordance floating alone at the far edge of an otherwise empty row.
          // Kept in manage mode too: curating links is exactly when knowing a
          // blocker is already Done matters most, and dropping it there cost
          // the row its second type level during the one task it serves.
          //
          // Spans rather than a plain subtitle purely to override the ink: the
          // list item's subtitle is medium emphasis, which on the narrow layout
          // tied the status with the section eyebrow that groups it and flattened
          // the same three roles the wide layout ranks.
          subtitleSpans: wideEnoughForTrailingStatus
              ? null
              : [
                  TextSpan(
                    text: statusLabel,
                    style: TextStyle(color: tokens.colors.text.lowEmphasis),
                  ),
                ],
          trailing: !wideEnoughForTrailingStatus
              ? null
              : Text(
                  statusLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
          trailingExtra: showActions
              ? SizedBox(
                  // Pinned to the same width the browse chevron reserves, so a
                  // row that offers only one action still leaves the title the
                  // same space as one that offers two.
                  width: tokens.spacing.step8 * 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
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
                          // The mode exists to retype relationships, so its
                          // verb outranks its escape hatch.
                          emphasis: tokens.colors.text.mediumEmphasis,
                        ),
                      if (onUnlink != null)
                        _RowAction(
                          tooltip: context.messages.unlinkButton,
                          onPressed: () => _confirmUnlink(context),
                          icon: Icons.close_rounded,
                          // Quieter than its neighbour, not louder: the
                          // confirmation modal is what makes unlinking safe,
                          // and painting the destructive action as the
                          // brightest mark on the row only draws the eye to it.
                        ),
                    ],
                  ),
                )
              : SizedBox(
                  // Both axes of the action pair, not just the width: manage
                  // mode occupies two step8-wide boxes each step9 tall, so
                  // reserving only the width still let the row grow taller on
                  // toggle and the card jump with it.
                  width: tokens.spacing.step8 * 2,
                  height: tokens.spacing.step8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Boxed like an action rather than pinned to the edge, so
                      // the chevron lands on the same vertical line the unlink
                      // button occupies instead of sitting further out.
                      SizedBox(
                        width: tokens.spacing.step8,
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward_ios,
                            size: tokens.spacing.step4,
                            color: tokens.colors.text.lowEmphasis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    // The shared confirmation modal, not a raw AlertDialog: this was the last
    // place in the feature that dropped out of the design system and rendered
    // Material defaults inside an otherwise tokenised surface.
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.unlinkTaskTitle,
      message: context.messages.unlinkTaskConfirm,
      confirmLabel: context.messages.unlinkButton,
      cancelLabel: context.messages.cancelButton,
    );
    if (!confirmed) return;

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

/// One manage-mode action on a [LinkedTaskRow]. A fixed `step8` box so the
/// trailing rail keeps one width whether the row shows actions or a chevron,
/// with the design system's minimum interactive target as its hit area.
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      // Compact density trims Material's padded 48pt tap target to the step8
      // box this rail reserves; without it two actions overflow the rail.
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      // Tight, not minimums: two of these have to fit the exact rail the
      // browse chevron reserves, and their height has to match it, or toggling
      // the mode resizes every row on the card.
      constraints: BoxConstraints.tightFor(
        width: tokens.spacing.step8,
        height: tokens.spacing.step8,
      ),
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
    final tokens = context.designTokens;
    return Icon(
      taskIconFromStatusString(status.toDbString),
      size: tokens.spacing.step5,
      color: taskColorFromStatusString(
        status.toDbString,
        brightness: brightness,
      ),
    );
  }
}
