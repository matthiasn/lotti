import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Which side of a link the row's anchor task is on. `outgoing` means the
/// anchor task is the link's `fromId`.
enum LinkDirection { outgoing, incoming }

/// One row's content: the other task in the link, its direction relative to
/// the anchor task, and an optional direction caption.
class LinkedTaskRowData {
  const LinkedTaskRowData({
    required this.task,
    required this.direction,
    this.caption,
  });

  final Task task;
  final LinkDirection direction;

  /// Direction caption shown next to the direction glyph (e.g. "to"/"from"
  /// for the flat plain-link list, or a relationship phrase like "Follows up
  /// on" for a merged bidirectional section). Null omits the glyph+caption
  /// unit entirely — used when a section header already disambiguates
  /// direction (the split "Blocks"/"Blocked by" sections).
  final String? caption;
}

/// A single row in the linked-tasks card: direction glyph + caption (if any),
/// status glyph, title, and either a chevron (browse mode) or an unlink
/// button (manage mode, only when [onUnlink] is supplied). Shared by the flat
/// plain-link list and the typed relationship sections.
class LinkedTaskRow extends StatelessWidget {
  const LinkedTaskRow({
    required this.taskId,
    required this.data,
    required this.manageMode,
    this.onUnlink,
    super.key,
  });

  final String taskId;
  final LinkedTaskRowData data;
  final bool manageMode;

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
    final isOutgoing = data.direction == LinkDirection.outgoing;
    final directionColor = isOutgoing
        ? tokens.colors.alert.info.defaultColor
        : tokens.colors.alert.success.defaultColor;
    final glyph = isOutgoing
        ? 'assets/icons/subdirectory_arrow_right.svg'
        : 'assets/icons/subdirectory_arrow_left.svg';
    final caption = data.caption;

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
            if (caption != null) ...[
              SvgPicture.asset(
                glyph,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(directionColor, BlendMode.srcIn),
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                caption,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: directionColor,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
            ],
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
            if (manageMode && onUnlink != null)
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
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
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
