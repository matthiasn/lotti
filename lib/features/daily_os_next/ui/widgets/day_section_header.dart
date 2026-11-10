import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The label over a group of rows on the day page — "Needs you", "Today so
/// far", "Handled" — as one subtitle1 on the page's rail: the tier between the
/// page's title and its rows, a step above the rows' own semibold names, with
/// an optional
/// [summary] right-aligned in caption figures ("4h 35m · 3 done"). Every
/// group on the page is named the same way, a `step2` above its card and
/// inset as its rows are; the summary ends where the rows' figures do, short
/// of the chevron slot they keep.
class DaySectionHeader extends StatelessWidget {
  const DaySectionHeader({required this.label, this.summary, super.key});

  final String label;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final summary = this.summary;
    // Inset like the rows under it, so the label starts over their times
    // and the summary, short of the chevron slot every row keeps, ends on
    // the same right edge as their figures.
    final inset = DayRowScaffold.inset(context);
    return Padding(
      padding: EdgeInsets.only(
        left: inset,
        right: inset + DayRowTrailing.slotWidth(tokens),
        bottom: tokens.spacing.step2,
      ),
      child: Row(
        // The label and its summary share a baseline, whatever their sizes.
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          if (summary != null)
            Text(
              summary,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
                fontFeatures: dayFigures,
              ),
            ),
        ],
      ),
    );
  }
}
