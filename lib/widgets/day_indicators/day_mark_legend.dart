import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

/// The key to the day squares: the same fills the cells draw, through the
/// same helpers, so the key cannot drift from the map it explains. Swatches
/// carry the cells' shape and non-color cues — the partial dot, the dashed
/// today ring — because a key to a mark that is not on the map is no key.
class DayMarkLegend extends StatelessWidget {
  const DayMarkLegend({
    this.showAgesOut = true,
    this.showOutcomes = false,
    this.showVerdicts = false,
    super.key,
  });

  /// Whether to key the quiet "ages out tonight" outline. Only surfaces
  /// whose cells can draw it — the goal detail's rolling windows — name it.
  final bool showAgesOut;

  /// Whether to key the recorded habit outcomes a cell can carry: the skip
  /// dash and the missed cross.
  final bool showOutcomes;

  /// Whether to key the four verdict hues and glyphs a judged day wears.
  final bool showVerdicts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    Widget item(
      Color color,
      String label, {
      bool outlined = false,
      bool dotted = false,
      bool dashed = false,
      IconData? glyph,
      Color? glyphInk,
    }) {
      Widget swatch = Container(
        width: IconSizes.xs,
        height: IconSizes.xs,
        decoration: BoxDecoration(
          color: outlined || dashed ? Colors.transparent : color,
          border: outlined
              ? Border.all(color: color, width: BorderWidths.emphasis)
              : null,
          borderRadius: BorderRadius.circular(dayCellRadius(tokens)),
        ),
        // The legend swatch carries the same shape and non-color cue as the
        // cells it keys — at `radii.xs` it was a different shape from both.
        child: dotted
            ? Center(child: partialDayDot(tokens, tokens.spacing.step1))
            : glyph != null
            ? Center(
                child: Icon(glyph, size: IconSizes.xs * 0.75, color: glyphInk),
              )
            : null,
      );
      if (dashed) {
        // Same stroke as the ring it keys — a hairline swatch beside a
        // two-pixel ring is a key to a mark that is not on the map.
        swatch = DsDashedBorder(
          color: color,
          strokeWidth: BorderWidths.emphasis,
          radius: dayCellRadius(tokens),
          child: swatch,
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          SizedBox(width: tokens.spacing.step2),
          // Flexible so the longer done/partial labels line-break on narrow
          // cards instead of overflowing the legend row.
          Flexible(
            child: Text(
              label,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
        ],
      );
    }

    // Centered, like every legend and summary line on these cards: the key
    // is card-level annotation, not a row in the leading-aligned data stack.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: tokens.spacing.step4,
        runSpacing: tokens.spacing.step2,
        children: [
          item(
            dayMarkStateFill(tokens, DayMarkState.full),
            dayMarkStateLabel(context, DayMarkState.full),
          ),
          item(
            dayMarkStateFill(tokens, DayMarkState.partial),
            dayMarkStateLabel(context, DayMarkState.partial),
            dotted: true,
          ),
          // The state most cells are actually IN. A key that explained the
          // two green ones and both edge cases while staying silent about
          // the majority fill left the one a reader most needs unnamed.
          item(
            dayMarkStateFill(tokens, DayMarkState.none),
            dayMarkStateLabel(context, DayMarkState.none),
          ),
          // Quiet outline, matching the ring the cells actually draw — an
          // on-track row must not wear the alarm hue in its key either.
          if (showAgesOut)
            item(
              tokens.colors.text.lowEmphasis,
              context.messages.goalProgressAgesOut,
              outlined: true,
            ),
          // Dashed, exactly like the today cell — the key must match the map.
          item(
            todayRingInk(tokens),
            context.messages.goalProgressToday,
            dashed: true,
          ),
          // The outcome glyphs, in the same ink the cells draw them.
          if (showOutcomes)
            for (final state in [DayMarkState.skipped, DayMarkState.missed])
              item(
                dayMarkStateFill(tokens, state),
                dayMarkStateLabel(context, state),
                glyph: dayMarkStateGlyph(state),
                glyphInk: dayMarkStateGlyphInk(tokens, state),
              ),
          // A judged day: its own hue and shape, through the same helpers
          // the cells use — four fills a reader must be able to tell apart.
          // "judged Missed" beside "Missed": a recorded outcome and a
          // verdict can share a name, and the key must not list one word
          // twice with two different swatches.
          if (showVerdicts)
            for (final verdict in DayVerdict.values)
              item(
                dayVerdictFill(tokens, verdict),
                context.messages.dayMarkLegendJudged(
                  dayVerdictLabel(context, verdict),
                ),
                glyph: dayVerdictGlyph(verdict),
                glyphInk: dayVerdictInk(tokens, verdict),
              ),
        ],
      ),
    );
  }
}
