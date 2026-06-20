import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Widget to display due date with color coding for overdue/today status.
/// Supports tapping to toggle between absolute (e.g., "Dec 24, 2025") and
/// relative (e.g., "Due in 5 days") date display.
class DueDateText extends StatefulWidget {
  const DueDateText({
    required this.dueDate,
    super.key,
  });

  final DateTime dueDate;

  @override
  State<DueDateText> createState() => _DueDateTextState();
}

class _DueDateTextState extends State<DueDateText> {
  bool _showRelative = false;

  Color _getColor(BuildContext context, DueDateStatus status) {
    return status.urgentColor ??
        context.colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
  }

  String _getAbsoluteText(BuildContext context, DueDateStatus status) {
    if (status.daysUntilDue == 0) {
      return context.messages.taskDueToday;
    }
    return context.messages.taskDueDateWithDate(
      DateFormat.yMMMd().format(widget.dueDate),
    );
  }

  String _getRelativeText(BuildContext context, DueDateStatus status) {
    final days = status.daysUntilDue ?? 0;

    if (days == 0) {
      return context.messages.taskDueToday;
    } else if (days == 1) {
      return context.messages.taskDueTomorrow;
    } else if (days == -1) {
      return context.messages.taskDueYesterday;
    } else if (days > 1) {
      return context.messages.taskDueInDays(days);
    } else {
      // Overdue by multiple days
      return context.messages.taskOverdueByDays(-days);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get reference time once for consistent calculations within this build
    final now = clock.now();
    final status = getDueDateStatus(
      dueDate: widget.dueDate,
      referenceDate: now,
    );

    final tokens = context.designTokens;
    final color = _getColor(context, status);
    final text = _showRelative
        ? _getRelativeText(context, status)
        : _getAbsoluteText(context, status);

    // Every due date is a calm surface chip matching the other metadata chips:
    // same height, neutral fill, hairline border. Urgency is signalled only by
    // the text/icon COLOUR (overdue red, due-today amber) and a slightly
    // heavier weight — so the deadline stays scannable without reading as an
    // "angry" filled red block, and a dated card is still spottable among
    // undated ones.
    final isUrgent = status.isUrgent;

    return GestureDetector(
      onTap: () => setState(() => _showRelative = !_showRelative),
      child: Container(
        height: 20,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step2,
          vertical: tokens.spacing.step1,
        ),
        decoration: BoxDecoration(
          color: TaskShowcasePalette.surface(context),
          borderRadius: BorderRadius.circular(tokens.radii.xs),
          border: Border.all(color: TaskShowcasePalette.border(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: tokens.typography.styles.others.caption.copyWith(
                color: color,
                fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
