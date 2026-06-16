import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_range.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// The pinned readout that sits in the glass sticky bar above Save, so the
/// duration (the design's primary clarity device) is always visible — even in
/// the taller different-dates layout.
///
/// Renders one of three states from [range]:
/// - invalid (composed end before start, only reachable in different-dates
///   mode): a warning row;
/// - valid: a "Duration" row with the formatted value, plus a teal "+1 day"
///   chip when the end was auto-rolled to the next day
///   ([EntryDateTimeRange.overnightAuto]).
class EntryDateTimeStatusBar extends StatelessWidget {
  const EntryDateTimeStatusBar({required this.range, super.key});

  final EntryDateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    if (!range.valid) {
      return Row(
        children: [
          Icon(
            Icons.warning_rounded,
            size: 20,
            color: context.colorScheme.error,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              context.messages.journalDateInvalid,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              MdiIcons.clockTimeFourOutline,
              size: 20,
              color: context.colorScheme.primary,
            ),
            SizedBox(width: tokens.spacing.step3),
            Text(
              context.messages.journalDurationLabel,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              formatRangeDuration(range.duration),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (range.overnightAuto) ...[
          SizedBox(height: tokens.spacing.step3),
          Align(
            alignment: Alignment.centerLeft,
            child: DsPill(
              variant: DsPillVariant.tinted,
              // Teal (not the brand-purple Duration accent) so it reads as a
              // distinct "heads up" state badge rather than echoing the value.
              color: tokens.colors.interactive.enabled,
              label: context.messages.journalOvernightNextDay(
                DateFormat('EEE d MMM').format(range.dateTo),
              ),
              leading: Icon(
                MdiIcons.weatherNight,
                size: 14,
                color: tokens.colors.interactive.enabled,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
