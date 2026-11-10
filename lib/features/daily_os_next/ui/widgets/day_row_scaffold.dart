import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Figures for clock times and durations on the day page: tabular, so a
/// column of times lines up, without the slashed zero of the numeric-badge
/// set, so they read as the same digits as the prose around them.
const List<FontFeature> dayFigures = [FontFeature.tabularFigures()];

/// The one row grid every list on the day page uses — the agenda, its folded
/// run of finished items, "Today so far" and the activity entries — so their
/// times, marks and words start on the same vertical lines on every tab.
///
/// Left to right on the first line: the time column, right-aligned against a
/// `step2` gutter in low-emphasis caption [dayFigures]; a [leading] slot one
/// caption glyph wide for the row's mark (a category dot or a small glyph,
/// centred in it, so dots and glyphs share one centre line); a `step3` gap;
/// [child], the row's name; and an optional [trailing] — the row's figure
/// and chevron slot, a [DayRowTrailing]. The time column is as wide as the
/// widest time the device's clock writes ([timeColumnWidth]), so every row
/// on the page shares it and no width is spent on a fixed guess.
///
/// [below] — the row's meta, reason or actions — starts under [child] and
/// runs under [trailing] too: only the first line gives up width to the
/// figure.
///
/// Rows are at least [TapTargets.minimum] tall, inset by `cardPadding`
/// (`step4` on a phone), and a one-line row centres in that height. The time
/// and the mark centre on the first line of [child], whose line height is
/// [firstLine] (bodySmall unless given).
class DayRowScaffold extends StatelessWidget {
  const DayRowScaffold({
    required this.time,
    required this.leading,
    required this.child,
    this.trailing,
    this.below,
    this.firstLine,
    this.timeOverline,
    this.active = false,
    super.key,
  });

  /// Whether the row is the one under way: a `step1` teal edge down its
  /// start, with "Now" ([timeOverline]) under its time — the same mark on
  /// the agenda and in "Today so far", so what is running reads alike on
  /// every tab.
  final bool active;

  /// A word under the time, in high-emphasis caption — "Now" on the row
  /// under way — level with [below]'s first line rather than above it.
  final String? timeOverline;

  /// The row's time, already formatted ("9:00 AM", or empty).
  final String time;

  /// The row's mark: a category dot, a check, a status glyph.
  final Widget leading;

  /// The row's first line: its name.
  final Widget child;

  /// The row's figure and chevron slot, at the end of the first line.
  final Widget? trailing;

  /// What follows the name, full width under it and the trailing column.
  final Widget? below;

  /// Unscaled line height of [child]'s first line; bodySmall by default.
  final double? firstLine;

  /// The width of the page's time column: the widest of a late-evening time
  /// in the device's clock ("10:55 PM" or "22:55") and the "Now" that sits
  /// under a running row's time, at the user's text size.
  static double timeColumnWidth(BuildContext context) {
    final tokens = context.designTokens;
    final scaler = MediaQuery.textScalerOf(context);
    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return [
      widthOf(
        formatClock(context, DateTime(2000, 1, 1, 22, 55)),
        _timeStyle(tokens),
      ),
      widthOf(
        context.messages.dailyOsNextAgendaNow,
        captionLabelStyle(tokens, color: tokens.colors.text.highEmphasis),
      ),
    ].reduce((a, b) => a > b ? a : b).ceilToDouble();
  }

  /// Where a row's words start, from the row's inner edge: the time column,
  /// its gutter, the mark slot and the gap after it.
  static double wordsInset(BuildContext context) {
    final tokens = context.designTokens;
    return timeColumnWidth(context) +
        tokens.spacing.step2 +
        tokens.typography.size.caption +
        tokens.spacing.step3;
  }

  /// The horizontal inset of a row's content inside its card: `cardPadding`
  /// on a wide pane, `step4` on a phone.
  static double inset(BuildContext context) {
    final tokens = context.designTokens;
    return isDesktopLayout(context)
        ? tokens.spacing.cardPadding
        : tokens.spacing.step4;
  }

  static TextStyle _timeStyle(DsTokens tokens) =>
      tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.lowEmphasis,
        fontFeatures: dayFigures,
      );

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
    final captionLine = scaler.scale(tokens.typography.lineHeight.caption);
    final trailing = this.trailing;
    final below = this.below;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TapTargets.minimum),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset(context),
            vertical: tokens.spacing.step3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: const Key('day_row_time'),
                    width: timeColumnWidth(context),
                    alignment: AlignmentDirectional.topEnd,
                    padding: EdgeInsets.only(top: centred(captionLine)),
                    child: Text(
                      time,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _timeStyle(tokens),
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
                      padding: EdgeInsets.only(top: centred(captionLine)),
                      child: trailing,
                    ),
                  ],
                ],
              ),
              // The second line onwards: the overline beside what follows
              // the name, so "Now" never pushes the row's meta down.
              if (below != null || timeOverline != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: timeColumnWidth(context),
                      child: switch (timeOverline) {
                        final overline? => Padding(
                          // Level with the first line beneath the name.
                          padding: EdgeInsets.only(
                            top: below == null ? 0 : tokens.spacing.step1,
                          ),
                          child: Text(
                            overline,
                            key: const Key('day_row_overline'),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: captionLabelStyle(
                              tokens,
                              color: tokens.colors.text.highEmphasis,
                            ),
                          ),
                        ),
                        null => null,
                      },
                    ),
                    SizedBox(
                      width: wordsInset(context) - timeColumnWidth(context),
                    ),
                    Expanded(child: below ?? const SizedBox.shrink()),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    if (!active) return row;
    return Stack(
      children: [
        row,
        Positioned(
          key: const Key('day_row_active_edge'),
          left: 0,
          top: 0,
          bottom: 0,
          width: tokens.spacing.step1,
          child: ColoredBox(color: tokens.colors.interactive.enabled),
        ),
      ],
    );
  }
}

/// The end of a row's first line: its figure (a duration, in caption
/// [dayFigures]) and the chevron slot every row keeps, filled when the row
/// opens something. Every row on the page ends this way, so every figure —
/// and every section header's summary, inset by [slotWidth] — ends on one
/// right edge.
class DayRowTrailing extends StatelessWidget {
  const DayRowTrailing({this.figure, this.icon, super.key});

  /// The row's time, already formatted ("1h 30m"), or null for none.
  final String? figure;

  /// The chevron (or fold arrow) in the slot, or null to keep it empty.
  final IconData? icon;

  /// The width the chevron slot and its gap take after a figure.
  static double slotWidth(DsTokens tokens) =>
      tokens.spacing.step2 + tokens.typography.size.subtitle2;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final figure = this.figure;
    final icon = this.icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (figure != null)
          Text(
            figure,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontFeatures: dayFigures,
            ),
          ),
        SizedBox(width: tokens.spacing.step2),
        SizedBox(
          width: tokens.typography.size.subtitle2,
          child: icon == null
              ? null
              : Icon(
                  icon,
                  size: tokens.typography.size.subtitle2,
                  color: tokens.colors.text.lowEmphasis,
                ),
        ),
      ],
    );
  }
}
