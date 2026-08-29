import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

/// The key to the day squares — only for what the squares actually show.
///
/// A key explains what a reader cannot get from the mark itself: the
/// colour-only states (done, done-but-target-still-building, no entry), the
/// two rings, and the verdict hues a judged day wears. It never lists the
/// outcome glyphs (the skip dash, the missed cross name themselves, and every
/// cell answers hover with its outcome), and it never lists a state that is
/// not on the strip it sits under: an eleven-entry wall under a row of seven
/// squares was more legend than data. The same fills the cells draw, through
/// the same helpers, so the key cannot drift from the map.
class DayMarkLegend extends StatelessWidget {
  const DayMarkLegend({
    required this.states,
    this.verdicts = const {},
    this.showAgesOut = false,
    this.showToday = false,
    super.key,
  });

  /// The measured states present on the keyed strip. Only the colour-only
  /// ones — [DayMarkState.full], [DayMarkState.partial], [DayMarkState.none]
  /// — get an entry; a skip or a miss carries its own glyph.
  final Set<DayMarkState> states;

  /// The verdicts present on the keyed strip; each gets its hue and glyph.
  final Set<DayVerdict> verdicts;

  /// Whether the strip draws the quiet "ages out tonight" outline.
  final bool showAgesOut;

  /// Whether the strip contains today, and therefore its dashed ring.
  final bool showToday;

  /// Whether there is anything to key at all.
  bool get isEmpty =>
      !states.contains(DayMarkState.full) &&
      !states.contains(DayMarkState.partial) &&
      !states.contains(DayMarkState.none) &&
      verdicts.isEmpty &&
      !showAgesOut &&
      !showToday;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    // One register for the row: the state labels double as tooltip and
    // semantics fragments and arrive in mid-sentence case, so the key
    // capitalises each entry itself rather than reading three conventions.
    String sentence(String label) =>
        label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
    Widget item(
      Color color,
      String label, {
      bool outlined = false,
      bool dotted = false,
      bool dashed = false,
      IconData? glyph,
      Color? glyphInk,
    }) {
      // One size up from the smallest icon: at IconSizes.xs the cell radius
      // rounded the swatch into a disc, and the verdict glyphs were mush.
      Widget swatch = Container(
        width: IconSizes.s,
        height: IconSizes.s,
        decoration: BoxDecoration(
          // A ring is a modifier on any square, so both ring swatches are
          // drawn over nothing: one rule for both, and no fill that the
          // aged-out or today cell might not actually wear.
          color: outlined || dashed ? Colors.transparent : color,
          border: outlined
              ? Border.all(color: color, width: BorderWidths.emphasis)
              : null,
          // Scaled to the swatch: the cell radius on a 16px square rounds
          // it into a disc, and the key must show the cells' shape.
          borderRadius: BorderRadius.circular(tokens.radii.xs),
        ),
        // The legend swatch carries the same shape and non-color cue as the
        // cells it keys — at `radii.xs` it was a different shape from both.
        child: dotted
            ? Center(child: partialDayDot(tokens, tokens.spacing.step2))
            : glyph != null
            ? Center(
                child: Icon(
                  glyph,
                  size: dayMarkGlyphSize(IconSizes.s),
                  color: glyphInk,
                ),
              )
            : null,
      );
      if (dashed) {
        // Same stroke as the ring it keys — a hairline swatch beside a
        // two-pixel ring is a key to a mark that is not on the map.
        swatch = DsDashedBorder(
          color: color,
          strokeWidth: BorderWidths.emphasis,
          radius: tokens.radii.xs,
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
              sentence(label),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
        ],
      );
    }

    // Under the squares, starting where they start: centred across a wide
    // card the key floated mid-card as a footer, tied to nothing.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: tokens.spacing.step4,
        runSpacing: tokens.spacing.step2,
        children: [
          if (states.contains(DayMarkState.full))
            item(
              dayMarkStateFill(tokens, DayMarkState.full),
              dayMarkStateLabel(context, DayMarkState.full),
            ),
          if (states.contains(DayMarkState.partial))
            item(
              dayMarkStateFill(tokens, DayMarkState.partial),
              dayMarkStateLabel(context, DayMarkState.partial),
              dotted: true,
            ),
          if (states.contains(DayMarkState.none))
            item(
              dayMarkStateFill(tokens, DayMarkState.none),
              dayMarkStateLabel(context, DayMarkState.none),
            ),
          // A judged day: its own hue and shape, through the same helpers
          // the cells use — the hues are the one thing a reader cannot
          // name from the square alone.
          for (final verdict in DayVerdict.values)
            if (verdicts.contains(verdict))
              item(
                dayVerdictFill(tokens, verdict),
                context.messages.dayMarkLegendJudged(
                  dayVerdictLabel(context, verdict),
                ),
                glyph: dayVerdictGlyph(verdict),
                glyphInk: dayVerdictInk(tokens, verdict),
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
          if (showToday)
            item(
              todayRingInk(tokens),
              context.messages.goalProgressToday,
              dashed: true,
            ),
        ],
      ),
    );
  }
}
