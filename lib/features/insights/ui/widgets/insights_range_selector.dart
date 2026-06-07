import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Quick-access range presets plus a custom range picker, mirroring the
/// Cursor usage dashboard: `[May 30 – Jun 05 ▾] 1d 7d 30d MTD YTD Last
/// month`.
///
/// The leading button always shows the active range and opens a date-range
/// picker; preset pills re-resolve relative to "now".
class InsightsRangeSelector extends StatelessWidget {
  const InsightsRangeSelector({
    required this.range,
    required this.onPresetSelected,
    required this.onCustomRangeSelected,
    super.key,
  });

  final InsightsRange range;
  final ValueChanged<InsightsRangePreset> onPresetSelected;
  final void Function(DateTime start, DateTime end) onCustomRangeSelected;

  String _presetLabel(BuildContext context, InsightsRangePreset preset) {
    final messages = context.messages;
    return switch (preset) {
      InsightsRangePreset.d1 => messages.insightsRange1d,
      InsightsRangePreset.d7 => messages.insightsRange7d,
      InsightsRangePreset.d30 => messages.insightsRange30d,
      InsightsRangePreset.mtd => messages.insightsRangeMtd,
      InsightsRangePreset.ytd => messages.insightsRangeYtd,
      InsightsRangePreset.lastMonth => messages.insightsRangeLastMonth,
    };
  }

  String _rangeLabel(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final format = DateFormat.MMMd(locale);
    final start = dayStart(range.startDay);
    final lastDay = dayStart(range.endDayExclusive - 1);
    if (range.dayCount == 1) return format.format(start);
    return '${format.format(start)} – ${format.format(lastDay)}';
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = clock.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: dayStart(range.startDay),
        end: dayStart(range.endDayExclusive - 1),
      ),
    );
    if (picked != null) {
      onCustomRangeSelected(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InsightsPillButton(
          label: _rangeLabel(context),
          icon: Icons.calendar_month_outlined,
          // The persistent outline marks this as the custom-range control;
          // when a custom range is active it doubles as the "Custom"
          // selection indicator (no preset pill is lit).
          outlined: true,
          active: range.preset == null,
          onTap: () => _pickCustomRange(context),
          semanticsLabel: context.messages.insightsRangeCustom,
        ),
        SizedBox(width: tokens.spacing.step3),
        for (final preset in InsightsRangePreset.values)
          InsightsPillButton(
            label: _presetLabel(context, preset),
            active: range.preset == preset,
            onTap: () => onPresetSelected(preset),
          ),
      ],
    );
  }
}
