import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:material_ui/material_ui.dart';

/// Figures for clock times and durations on the day page: tabular, so a
/// column of times lines up, without the slashed zero of the numeric-badge
/// set, so they read as the same digits as the prose around them.
const List<FontFeature> dayFigures = [FontFeature.tabularFigures()];

/// The one row grid every list on the day page uses — the agenda, its folded
/// run of finished items, "Today so far" and the activity entries — so their
/// times, marks and words start on the same vertical lines on every tab.
///
/// Left to right: a `step10` time column (scaled with the text size,
/// right-aligned against a `step2` gutter, low-emphasis caption with
/// [dayFigures]); a [leading] slot one caption glyph wide for the row's mark
/// (a category dot or a small glyph, centred in it, so dots and glyphs share
/// one centre line); a `step3` gap; then
/// [child], the row's words; and an optional [trailing] at the end. Rows are
/// at least [TapTargets.minimum] tall, inset by `cardPadding` (`step4` on a
/// phone), and a
/// one-line row centres in that height. The time and the mark centre on
/// the first line of [child], whose line height is [firstLine] (bodySmall
/// unless given).
class DayRowScaffold extends StatelessWidget {
  const DayRowScaffold({
    required this.time,
    required this.leading,
    required this.child,
    this.trailing,
    this.firstLine,
    this.timeOverline,
    super.key,
  });

  /// A word above the time, in high-emphasis caption — "Now" on the row
  /// under way.
  final String? timeOverline;

  /// The row's time, already formatted ("9:00 AM", or a dash).
  final String time;

  /// The row's mark: a category dot, a check, a status glyph.
  final Widget leading;

  final Widget child;
  final Widget? trailing;

  /// Unscaled line height of [child]'s first line; bodySmall by default.
  final double? firstLine;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final scaler = MediaQuery.textScalerOf(context);
    final line = scaler.scale(
      firstLine ?? tokens.typography.lineHeight.bodySmall,
    );
    double centred(double height) =>
        ((line - height) / 2).clamp(0, double.infinity);
    final markSlot = tokens.typography.size.caption;
    final trailing = this.trailing;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TapTargets.minimum),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Padding(
          // A phone gives the words the room: a step4 inset, the card's
          // padding on a wide pane.
          padding: EdgeInsets.symmetric(
            horizontal: isDesktopLayout(context)
                ? tokens.spacing.cardPadding
                : tokens.spacing.step4,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const Key('day_row_time'),
                width: scaler.scale(tokens.spacing.step10),
                padding: EdgeInsets.only(
                  top: centred(
                    scaler.scale(tokens.typography.lineHeight.caption),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                        fontFeatures: dayFigures,
                      ),
                    ),
                    if (timeOverline case final overline?)
                      Text(
                        overline,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: captionLabelStyle(
                          tokens,
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Padding(
                padding: EdgeInsets.only(top: centred(markSlot)),
                child: SizedBox.square(
                  dimension: markSlot,
                  child: Center(child: leading),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(child: child),
              if (trailing != null) ...[
                SizedBox(width: tokens.spacing.step3),
                Padding(
                  padding: EdgeInsets.only(
                    top: centred(
                      scaler.scale(tokens.typography.lineHeight.caption),
                    ),
                  ),
                  child: trailing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
