import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_range.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// The duration and endpoint readout shown after the time controls.
///
/// Renders one of three states from [range]:
/// - invalid (composed end before start, only reachable in different-dates
///   mode): a warning row;
/// - valid: a "Duration" row with the formatted value, plus a teal "+1 day"
///   chip when the end was auto-rolled to the next day
///   ([EntryDateTimeRange.overnightAuto]). The chip row always reserves its
///   layout height so crossing midnight never makes the sheet jump.
class EntryDateTimeStatusBar extends StatelessWidget {
  const EntryDateTimeStatusBar({required this.range, super.key});

  final EntryDateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (!range.valid) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.spacing.step12),
        child: Semantics(
          liveRegion: true,
          label: context.messages.journalDateInvalid,
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_rounded,
                  size: tokens.spacing.step6,
                  color: context.colorScheme.error,
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Text(
                    context.messages.journalDateInvalid,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: context.colorScheme.error,
                      fontWeight: tokens.typography.weight.semiBold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final duration = formatRangeDuration(range.duration);
    final rangeLabel = _formatRangeLabel(context, range);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.spacing.step12),
      child: Semantics(
        liveRegion: true,
        label:
            '${context.messages.journalDurationLabel}: $duration. $rangeLabel',
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < tokens.spacing.step13 * 4;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        MdiIcons.clockTimeFourOutline,
                        size: tokens.spacing.step6,
                        color: tokens.colors.interactive.enabled,
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Text(
                        context.messages.journalDurationLabel,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.mediumEmphasis,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        duration,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              fontWeight: tokens.typography.weight.semiBold,
                              color: tokens.colors.interactive.enabled,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  Text(
                    _formatRangeLabel(context, range, compact: compact),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  Visibility(
                    visible: range.overnightAuto,
                    maintainAnimation: true,
                    maintainSize: true,
                    maintainState: true,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DsPill(
                        variant: DsPillVariant.tinted,
                        color: tokens.colors.interactive.enabled,
                        label: context.messages.journalOvernightNextDay(
                          DateFormat('EEE d MMM', locale).format(range.dateTo),
                        ),
                        leading: Icon(
                          MdiIcons.weatherNight,
                          size: tokens.spacing.step5,
                          color: tokens.colors.interactive.enabled,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _formatRangeLabel(
  BuildContext context,
  EntryDateTimeRange range, {
  bool compact = false,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final dateFormat = compact
      ? DateFormat.MMMEd(locale)
      : DateFormat.yMMMEd(locale);
  String formatTime(DateTime date) => TimeOfDay.fromDateTime(date).format(
    context,
  );
  final start =
      '${dateFormat.format(range.dateFrom)} · '
      '${formatTime(range.dateFrom)}';
  final end = range.startDate.isSameCalendarDay(range.dateTo)
      ? formatTime(range.dateTo)
      : '${dateFormat.format(range.dateTo)} · '
            '${formatTime(range.dateTo)}';
  return '$start → $end';
}
