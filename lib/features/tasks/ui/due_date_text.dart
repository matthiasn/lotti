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
  /// `null` follows the proximity default (relative phrasing for near dates,
  /// absolute date for far ones); tapping sets it to flip to the other form.
  bool? _showRelativeOverride;

  /// Within this window a relative phrasing ("Due Today", "Overdue by 3 days")
  /// triages faster than an absolute date; beyond it an exact date is more
  /// useful for planning, so the chip defaults to the absolute form.
  static const int _relativeWindowDays = 7;

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

    // Default representation: relative phrasing whenever it triages faster.
    // *Overdue* dates are ALWAYS relative ("Overdue by N days"), however long
    // ago — a bare absolute date disguises the most urgent item as a far-off
    // one and drops the redundant text cue colour-blind users rely on. Future
    // dates are relative within a week ("Due Today", "Due in 3 days") and
    // absolute beyond it, where an exact date aids planning. Since overdue days
    // are negative they always satisfy `days <= _relativeWindowDays`, so a
    // single threshold covers both. Tapping flips to the other representation.
    final days = status.daysUntilDue;
    final defaultRelative = days != null && days <= _relativeWindowDays;
    final showRelative = _showRelativeOverride ?? defaultRelative;
    final text = showRelative
        ? _getRelativeText(context, status)
        : _getAbsoluteText(context, status);

    // Every due date is a calm surface chip matching the other metadata chips:
    // same height, neutral fill, hairline border. Urgency is signalled only by
    // the text/icon COLOUR (overdue red, due-today amber, upcoming neutral) and
    // a weight LADDER — so the deadline stays scannable without reading as an
    // "angry" filled red block, and a dated card is still spottable among
    // undated ones.
    //
    // The ladder makes *overdue* the loudest state (heaviest weight), then
    // due-today, then a quiet upcoming date: triage needs "what's late?" to win
    // over "what's due today", and amber (today) is intrinsically brighter than
    // red (overdue), so overdue earns the extra weight to out-rank it.
    final weight = switch (status.urgency) {
      DueDateUrgency.overdue => FontWeight.w700,
      DueDateUrgency.dueToday => FontWeight.w600,
      DueDateUrgency.normal => FontWeight.w500,
    };

    return GestureDetector(
      onTap: () => setState(() => _showRelativeOverride = !showRelative),
      child: Container(
        height: 24,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step2,
          vertical: tokens.spacing.step1,
        ),
        decoration: BoxDecoration(
          color: TaskShowcasePalette.surface(context),
          borderRadius: BorderRadius.circular(tokens.radii.xs),
          // Stronger hairline (decorative.level02) so the chip boundary is
          // perceptible against the near-same-tone surface for low-vision users.
          border: Border.all(
            color: TaskShowcasePalette.containerBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: color,
                fontWeight: weight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
