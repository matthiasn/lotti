import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The label over a group of rows on the day page — "Needs you", "Today so
/// far", "Handled" — as one subtitle on the page's rail — the tier between the page's title
/// and its rows, with an optional
/// [summary] right-aligned in caption figures ("4h 35m · 3 done"). Every
/// group on the page is named the same way, a `step2` above its card.
class DaySectionHeader extends StatelessWidget {
  const DaySectionHeader({required this.label, this.summary, super.key});

  final String label;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final summary = this.summary;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              label,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
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
