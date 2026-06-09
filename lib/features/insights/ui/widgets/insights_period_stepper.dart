import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Compact period navigator for the Time Analysis dashboard:
/// `‹  [ Week ▾ ]  Jun 1 – 7  ›`.
///
/// The granularity dropdown re-derives the period via the controller; the
/// chevrons step one whole period at a time. Stepping forward past the
/// current period is disabled — there is no data in the future.
class InsightsPeriodStepper extends StatelessWidget {
  const InsightsPeriodStepper({
    required this.selection,
    required this.onSelectUnit,
    required this.onStep,
    this.onOpenCalendar,
    this.onToggleCompare,
    super.key,
  });

  final InsightsPeriodSelection selection;
  final ValueChanged<InsightsPeriodUnit> onSelectUnit;

  /// Negative steps back, positive forward.
  final ValueChanged<int> onStep;

  /// Tapping the period label opens the calendar picker. Null leaves the
  /// label inert.
  final VoidCallback? onOpenCalendar;

  /// Toggles previous-period comparison. Null hides the compare control.
  final VoidCallback? onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Forward is disabled once the period already reaches today: the future
    // holds no tracked time.
    final canStepForward =
        selection.range.endDayExclusive <= epochDay(clock.now());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChevronButton(
          icon: Icons.chevron_left_rounded,
          tooltip: messages.insightsPeriodPrevious,
          onPressed: () => onStep(-1),
        ),
        SizedBox(width: tokens.spacing.step1),
        _UnitDropdown(
          unit: selection.unit,
          onSelectUnit: onSelectUnit,
        ),
        SizedBox(width: tokens.spacing.step2),
        _PeriodLabel(
          label: _periodLabel(context, selection),
          onTap: onOpenCalendar,
        ),
        SizedBox(width: tokens.spacing.step2),
        _ChevronButton(
          icon: Icons.chevron_right_rounded,
          tooltip: messages.insightsPeriodNext,
          onPressed: canStepForward ? () => onStep(1) : null,
        ),
        if (onToggleCompare != null) ...[
          SizedBox(width: tokens.spacing.step4),
          InsightsPillButton(
            label: messages.insightsCompare,
            icon: Icons.compare_arrows_rounded,
            active: selection.compareEnabled,
            onTap: onToggleCompare!,
          ),
        ],
      ],
    );
  }
}

String _unitLabel(BuildContext context, InsightsPeriodUnit unit) {
  final messages = context.messages;
  return switch (unit) {
    InsightsPeriodUnit.day => messages.insightsPeriodDay,
    InsightsPeriodUnit.week => messages.insightsPeriodWeek,
    InsightsPeriodUnit.month => messages.insightsPeriodMonth,
    InsightsPeriodUnit.quarter => messages.insightsPeriodQuarter,
    InsightsPeriodUnit.year => messages.insightsPeriodYear,
  };
}

/// Human label for the current period, formatted per granularity in the
/// active locale (e.g. `Jun 1 – 7`, `June 2026`, `Q2 2026`, `2026`).
String _periodLabel(BuildContext context, InsightsPeriodSelection selection) {
  final locale = Localizations.localeOf(context).toString();
  final start = dayStart(selection.range.startDay);
  final lastDay = dayStart(selection.range.endDayExclusive - 1);
  switch (selection.unit) {
    case InsightsPeriodUnit.day:
      return DateFormat.yMMMMd(locale).format(start);
    case InsightsPeriodUnit.week:
      final from = DateFormat.MMMd(locale).format(start);
      final to = start.month == lastDay.month
          ? DateFormat.d(locale).format(lastDay)
          : DateFormat.MMMd(locale).format(lastDay);
      return '$from – $to';
    case InsightsPeriodUnit.month:
      return DateFormat.yMMMM(locale).format(start);
    case InsightsPeriodUnit.quarter:
      // yQQQ localizes both the quarter marker and the quarter/year order.
      return DateFormat.yQQQ(locale).format(start);
    case InsightsPeriodUnit.year:
      return '${start.year}';
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({required this.unit, required this.onSelectUnit});

  final InsightsPeriodUnit unit;
  final ValueChanged<InsightsPeriodUnit> onSelectUnit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return PopupMenuButton<InsightsPeriodUnit>(
      initialValue: unit,
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: onSelectUnit,
      itemBuilder: (context) => [
        for (final value in InsightsPeriodUnit.values)
          PopupMenuItem<InsightsPeriodUnit>(
            value: value,
            child: Text(
              _unitLabel(context, value),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.s),
          border: Border.all(color: tokens.colors.decorative.level02),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _unitLabel(context, unit),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Icon(
                Icons.expand_more_rounded,
                size: tokens.spacing.step5,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final text = Text(
      label,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.highEmphasis,
        fontWeight: tokens.typography.weight.semiBold,
      ),
    );
    if (onTap == null) return text;
    return Tooltip(
      message: context.messages.insightsPeriodJump,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          hoverColor: tokens.colors.surface.hover,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step2,
              vertical: tokens.spacing.step1,
            ),
            child: text,
          ),
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          hoverColor: tokens.colors.surface.hover,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step1),
            child: Icon(
              icon,
              size: tokens.spacing.step6,
              color: enabled
                  ? tokens.colors.text.mediumEmphasis
                  : tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}
