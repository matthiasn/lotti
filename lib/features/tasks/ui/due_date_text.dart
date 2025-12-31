import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
  }

  String _getAbsoluteText(BuildContext context, DueDateStatus status) {
    if (status.daysUntilDue == 0) {
      return context.messages.taskDueToday;
    }
    return context.messages
        .taskDueDateWithDate(DateFormat.yMMMd().format(widget.dueDate));
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

    final color = _getColor(context, status);
    final text = _showRelative
        ? _getRelativeText(context, status)
        : _getAbsoluteText(context, status);

    return GestureDetector(
      onTap: () => setState(() => _showRelative = !_showRelative),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_rounded,
            size: AppTheme.statusIndicatorFontSize,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(
              fontSize: AppTheme.statusIndicatorFontSize,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
