import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/habit_signal_status_controller.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_presentation.dart';
import 'package:lotti/features/habits/ui/widgets/measurable_quick_record_chips.dart';
import 'package:lotti/features/habits/ui/widgets/signal_sparkline.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// One associated signal in the completion sheet: what it is, whether its
/// rule is met today, quick-record chips for a measurable, and the two-week
/// sparkline behind it.
class HabitSignalRow extends StatelessWidget {
  const HabitSignalRow({
    required this.leaf,
    required this.status,
    required this.onRecordMeasurable,
    required this.onMoreMeasurable,
    this.recordedValue,
    super.key,
  });

  final HabitLeafVerdict leaf;
  final HabitSignalStatus status;
  final void Function(MeasurableDataType dataType, num value)
  onRecordMeasurable;
  final ValueChanged<MeasurableDataType> onMoreMeasurable;
  final num? recordedValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cache = getIt<EntitiesCacheService>();
    final rule = leaf.rule;
    final measurable = rule is AutoCompleteRuleMeasurable
        ? cache.getDataTypeById(rule.dataTypeId)
        : null;

    final name = switch (rule) {
      AutoCompleteRuleMeasurable(:final dataTypeId, :final title) =>
        title ?? measurable?.displayName ?? dataTypeId,
      AutoCompleteRuleHealth(:final dataType, :final title) =>
        title ?? habitHealthTypeName(messages, dataType),
      AutoCompleteRuleWorkout(:final dataType, :final title) =>
        title ?? dataType,
      AutoCompleteRuleHabit(:final habitId, :final title) =>
        title ?? cache.getHabitById(habitId)?.name ?? habitId,
      _ => '',
    };
    final unit = switch (rule) {
      AutoCompleteRuleMeasurable() => measurable?.unitName ?? '',
      AutoCompleteRuleWorkout(:final valueType?) => habitWorkoutUnit(
        messages,
        valueType,
      ),
      _ => '',
    };

    final pillColor = leaf.satisfied
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    final captionStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final todayValue = leaf.value;
    final todayText = todayValue == null
        ? messages.habitSignalTodayNone
        : messages.habitSignalToday(
            '${_format(todayValue, locale)} $unit'.trim(),
          );

    return Container(
      key: ValueKey('habit-signal-row-${_leafKey(rule)}'),
      decoration: BoxDecoration(
        color: dsCardSurface(context),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: name,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                    children: [
                      if (unit.isNotEmpty)
                        TextSpan(text: '  $unit', style: captionStyle),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              DsPill(
                key: ValueKey('habit-signal-pill-${_leafKey(rule)}'),
                variant: DsPillVariant.tinted,
                shape: DsPillShape.tag,
                color: pillColor,
                leading: leaf.satisfied
                    ? Icon(
                        LottiIcons.confirm,
                        size: IconSizes.xs,
                        color: pillColor,
                      )
                    : null,
                label: _ruleStatus(messages, leaf, unit, locale),
              ),
            ],
          ),
          if (measurable != null) ...[
            SizedBox(height: tokens.spacing.step3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MeasurableQuickRecordChips(
                    dataType: measurable,
                    recordedValue: recordedValue,
                    onRecord: (value) => onRecordMeasurable(measurable, value),
                    onMore: () => onMoreMeasurable(measurable),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Text(todayText, style: captionStyle),
              ],
            ),
          ] else ...[
            SizedBox(height: tokens.spacing.step2),
            Text(todayText, style: captionStyle),
          ],
          SizedBox(height: tokens.spacing.step3),
          SignalSparkline(values: _series()),
        ],
      ),
    );
  }

  /// One value per window day for this leaf's series, oldest first.
  List<num?> _series() {
    final window = status.window;
    final rule = leaf.rule;
    num? forDay(DateTime day) => switch (rule) {
      AutoCompleteRuleMeasurable(:final dataTypeId) =>
        window.measurableTotalsByDay[dataTypeId]?[day],
      AutoCompleteRuleHealth(:final dataType) =>
        window.quantitativeByDay[dataType]?[day],
      AutoCompleteRuleWorkout(:final dataType, :final valueType) =>
        switch (window.workoutsByDay[dataType]?[day]) {
          null => null,
          final workouts =>
            valueType == null
                ? workouts.length
                : workouts.fold<num>(
                    0,
                    (sum, w) => sum + _workoutValue(w, valueType),
                  ),
        },
      AutoCompleteRuleHabit(:final habitId) =>
        (window.habitSuccessDays[habitId]?.contains(day) ?? false) ? 1 : null,
      _ => null,
    };
    return [for (final day in status.days) forDay(day)];
  }

  static num _workoutValue(WorkoutData w, WorkoutValueType type) =>
      switch (type) {
        WorkoutValueType.duration =>
          w.dateTo.difference(w.dateFrom).inSeconds / 60,
        WorkoutValueType.distance => (w.distance ?? 0) / 1000,
        WorkoutValueType.energy => w.energy ?? 0,
      };

  /// "any entry · done", "6,000 steps · 4,120 so far", "any workout · not yet".
  String _ruleStatus(
    AppLocalizations messages,
    HabitLeafVerdict leaf,
    String unit,
    String locale,
  ) {
    final rule = leaf.rule;
    final (num? minimum, num? maximum) = switch (rule) {
      AutoCompleteRuleMeasurable(:final minimum, :final maximum) ||
      AutoCompleteRuleHealth(:final minimum, :final maximum) ||
      AutoCompleteRuleWorkout(:final minimum, :final maximum) => (
        minimum,
        maximum,
      ),
      _ => (null, null),
    };
    final anyLabel = switch (rule) {
      AutoCompleteRuleHealth() => messages.habitSignalAnyReading,
      AutoCompleteRuleWorkout() => messages.habitSignalAnyWorkout,
      AutoCompleteRuleHabit() => messages.habitSignalHabitDone,
      _ => messages.habitSignalAnyEntry,
    };
    final target = minimum != null
        ? '≥ ${_format(minimum, locale)} $unit'.trim()
        : maximum != null
        ? '≤ ${_format(maximum, locale)} $unit'.trim()
        : anyLabel;
    if (leaf.satisfied) return messages.habitSignalStatusDone(target);
    if (leaf.value != null && (minimum != null || maximum != null)) {
      return messages.habitSignalStatusSoFar(
        target,
        _format(leaf.value!, locale),
      );
    }
    return messages.habitSignalStatusNotYet(target);
  }

  /// Formats in the app's locale — the one the surrounding copy is in —
  /// rather than the process locale, so German text never reads `6,000`.
  static String _format(num value, String locale) =>
      NumberFormat.decimalPattern(locale).format(
        value == value.roundToDouble() ? value.round() : value,
      );

  static String _leafKey(AutoCompleteRule rule) => switch (rule) {
    AutoCompleteRuleMeasurable(:final dataTypeId) => dataTypeId,
    AutoCompleteRuleHealth(:final dataType) => dataType,
    AutoCompleteRuleWorkout(:final dataType) => dataType,
    AutoCompleteRuleHabit(:final habitId) => habitId,
    _ => 'composite',
  };
}
