import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

    final color = _getColor(context, status);
    final text = _showRelative
        ? _getRelativeText(context, status)
        : _getAbsoluteText(context, status);

    final row = Row(
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
    );

    // Every due date is a chip so a dated card is spottable among undated
    // ones, with the fill escalating by urgency so the deadline is the per-card
    // alarm: overdue / due-today get a filled tinted pill (the loudest
    // metadata), upcoming dates a quiet neutral outline. The pill's FORM also
    // distinguishes the deadline from the priority header band when both are
    // red.
    final isUrgent = status.isUrgent;
    return GestureDetector(
      onTap: () => setState(() => _showRelative = !_showRelative),
      child: _DuePill(
        fill: isUrgent ? color.withValues(alpha: 0.16) : Colors.transparent,
        border: isUrgent
            ? color.withValues(alpha: 0.45)
            : context.designTokens.colors.decorative.level02,
        child: row,
      ),
    );
  }
}

/// A rounded due-date chip matching the other metadata chips' dimensions. The
/// urgent variants pass a tinted [fill] + matching [border] so the deadline
/// reads as the loudest metadata; upcoming dates pass a transparent fill with a
/// neutral hairline so they still have presence without shouting. The hairline
/// keeps the chip perceptible (WCAG 1.4.11) regardless of fill luminance.
class _DuePill extends StatelessWidget {
  const _DuePill({
    required this.fill,
    required this.border,
    required this.child,
  });

  final Color fill;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
