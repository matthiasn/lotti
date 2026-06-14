import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Compact period navigator for the Time Analysis dashboard:
/// `[ ‹ │ Week ▾ │ Jun 1 – 7 📅 │ › ]  MTD YTD  ⇄ Compare`.
///
/// The chevrons, granularity dropdown, and clickable period label live in one
/// bordered segmented cluster so the whole stepper reads as interactive at
/// rest (not as bare text). The granularity dropdown re-derives the period;
/// the chevrons step one whole period; stepping past today is disabled. The
/// outlined MTD/YTD pills jump to the current month/year-to-date; Compare
/// toggles the previous-period overlay.
class InsightsPeriodStepper extends StatelessWidget {
  const InsightsPeriodStepper({
    required this.selection,
    required this.onSelectUnit,
    required this.onStep,
    this.onOpenCalendar,
    this.onToggleCompare,
    this.onSelectToDate,
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

  /// Jumps to the to-date portion of the current month/year (the MTD/YTD
  /// shortcut pills). Null hides the pills.
  final ValueChanged<InsightsPeriodUnit>? onSelectToDate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final now = clock.now();
    // Forward is disabled once the period already reaches today: the future
    // holds no tracked time.
    final canStepForward = selection.range.endDayExclusive <= epochDay(now);

    bool toDateActive(InsightsPeriodUnit unit) =>
        selection.unit == unit && selection.range == periodToDate(unit, now);

    // IntrinsicHeight so the group divider before Compare can size to the
    // control row's height.
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavCluster(
            unit: selection.unit,
            label: _periodLabel(context, selection),
            onSelectUnit: onSelectUnit,
            onStepBack: () => onStep(-1),
            onStepForward: canStepForward ? () => onStep(1) : null,
            onOpenCalendar: onOpenCalendar,
          ),
          if (onSelectToDate != null) ...[
            SizedBox(width: tokens.spacing.step3),
            InsightsPillButton(
              label: messages.insightsRangeMtd,
              outlined: true,
              active: toDateActive(InsightsPeriodUnit.month),
              onTap: () => onSelectToDate!(InsightsPeriodUnit.month),
              semanticsLabel: messages.insightsRangeMonthToDate,
              tooltip: messages.insightsRangeMonthToDate,
            ),
            SizedBox(width: tokens.spacing.step2),
            InsightsPillButton(
              label: messages.insightsRangeYtd,
              outlined: true,
              active: toDateActive(InsightsPeriodUnit.year),
              onTap: () => onSelectToDate!(InsightsPeriodUnit.year),
              semanticsLabel: messages.insightsRangeYearToDate,
              tooltip: messages.insightsRangeYearToDate,
            ),
          ],
          if (onToggleCompare != null) ...[
            // A divider (not just a gap) groups the period controls — stepper
            // plus the to-date shortcuts — apart from Compare, which is an
            // independent mode toggle rather than a navigation control.
            SizedBox(width: tokens.spacing.step4),
            VerticalDivider(
              width: 1,
              thickness: 1,
              indent: tokens.spacing.step2,
              endIndent: tokens.spacing.step2,
              color: tokens.colors.decorative.level02,
            ),
            SizedBox(width: tokens.spacing.step4),
            InsightsPillButton(
              label: messages.insightsCompare,
              icon: Icons.compare_arrows_rounded,
              outlined: true,
              active: selection.compareEnabled,
              onTap: onToggleCompare!,
              tooltip: messages.insightsCompareTooltip,
            ),
          ],
        ],
      ),
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
///
/// Any period whose range still reaches today — the current week/month/year,
/// or an MTD/YTD to-date range — gets a "(so far)" qualifier so the headline
/// never overstates a still-partial period. The rule is one predicate (the
/// range extends to or past today), applied to every granularity, so the same
/// incomplete June reads identically whether viewed as Month or month-to-date.
String _periodLabel(BuildContext context, InsightsPeriodSelection selection) {
  final locale = Localizations.localeOf(context).toString();
  final start = dayStart(selection.range.startDay);
  final lastDay = dayStart(selection.range.endDayExclusive - 1);
  final soFar = isInProgress(selection.range, clock.now());

  String label(String base) =>
      soFar ? '$base (${context.messages.insightsPeriodToDateSuffix})' : base;

  switch (selection.unit) {
    case InsightsPeriodUnit.day:
      return label(DateFormat.yMMMMd(locale).format(start));
    case InsightsPeriodUnit.week:
      return label(_spanLabel(locale, start, lastDay));
    case InsightsPeriodUnit.month:
      return label(DateFormat.yMMMM(locale).format(start));
    case InsightsPeriodUnit.quarter:
      // yQQQ localizes both the quarter marker and the quarter/year order.
      return label(DateFormat.yQQQ(locale).format(start));
    case InsightsPeriodUnit.year:
      return label('${start.year}');
  }
}

/// `Jun 1 – 7` within a month, `Jan 1 – Jun 10` across months, `Jun 1` for
/// a single day (MTD/YTD on the period's first day).
String _spanLabel(String locale, DateTime start, DateTime lastDay) {
  final from = DateFormat.MMMd(locale).format(start);
  if (start == lastDay) return from;
  final to = start.month == lastDay.month
      ? DateFormat.d(locale).format(lastDay)
      : DateFormat.MMMd(locale).format(lastDay);
  return '$from – $to';
}

/// The bordered segmented cluster: prev chevron, granularity dropdown,
/// clickable period label, next chevron — separated by hairline dividers, the
/// whole group framed so it reads as one interactive control at rest.
class _NavCluster extends StatelessWidget {
  const _NavCluster({
    required this.unit,
    required this.label,
    required this.onSelectUnit,
    required this.onStepBack,
    required this.onStepForward,
    required this.onOpenCalendar,
  });

  final InsightsPeriodUnit unit;
  final String label;
  final ValueChanged<InsightsPeriodUnit> onSelectUnit;
  final VoidCallback onStepBack;
  final VoidCallback? onStepForward;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.s),
        border: Border.all(color: tokens.colors.decorative.level02),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ClusterButton(
              icon: Icons.chevron_left_rounded,
              tooltip: messages.insightsPeriodPrevious,
              onPressed: onStepBack,
            ),
            _ClusterDivider(tokens: tokens),
            _UnitDropdown(unit: unit, onSelectUnit: onSelectUnit),
            _ClusterDivider(tokens: tokens),
            _PeriodLabel(label: label, onTap: onOpenCalendar),
            _ClusterDivider(tokens: tokens),
            _ClusterButton(
              icon: Icons.chevron_right_rounded,
              tooltip: messages.insightsPeriodNext,
              onPressed: onStepForward,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterDivider extends StatelessWidget {
  const _ClusterDivider({required this.tokens});

  final DsTokens tokens;

  @override
  Widget build(BuildContext context) => VerticalDivider(
    width: 1,
    thickness: 1,
    indent: tokens.spacing.step2,
    endIndent: tokens.spacing.step2,
    color: tokens.colors.decorative.level02,
  );
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
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        if (onTap != null) ...[
          SizedBox(width: tokens.spacing.step2),
          // A calendar glyph marks the label as the jump-to-date affordance;
          // without it the most powerful navigation reads as static text.
          Icon(
            Icons.calendar_today_rounded,
            size: tokens.spacing.step4,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ],
      ],
    );
    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      child: content,
    );
    if (onTap == null) return padded;
    return Tooltip(
      message: context.messages.insightsPeriodJump,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: tokens.colors.surface.hover,
          child: padded,
        ),
      ),
    );
  }
}

class _ClusterButton extends StatelessWidget {
  const _ClusterButton({
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
        child: InkWell(
          onTap: onPressed,
          hoverColor: tokens.colors.surface.hover,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step2,
              vertical: tokens.spacing.step2,
            ),
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
