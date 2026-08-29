import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/tooltips/ds_tooltip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_styles.dart';

/// The edge of every day square: the handover's 11px square at the nearest
/// icon size, one size everywhere it is drawn.
const double kDaySquareSize = IconSizes.xs;

/// A not-yet-resolved day slot — a loading window, or today while it is
/// still open: same footprint as a real square, dashed outline instead of a
/// fill, so the silhouette holds without borrowing the empty-day encoding.
class PlaceholderDayCell extends StatelessWidget {
  const PlaceholderDayCell({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DsDashedBorder(
      color: tokens.colors.text.lowEmphasis,
      radius: tokens.radii.xs,
      child: const SizedBox.square(dimension: kDaySquareSize),
    );
  }
}

/// One day square, as the habits handover draws it: a small rounded square
/// filled in the interactive hue when the day was kept and in the neutral
/// level-03 surface otherwise — a recorded verdict paints its own hue, and an
/// empty TODAY is the dashed unresolved outline, since the day is not over.
/// Nothing is drawn inside a square and nothing around it; which day it is,
/// what happened and what the user ruled are answered by the tooltip and the
/// semantics, not by glyphs, corner letters or rings on a 12px cell.
///
/// Read-only by default. With [onTap] the square keeps its size while the
/// hit slot around it clears the touch floor, the cell announces itself as a
/// button with [label], and a [caption] letter names the weekday above it.
class DayMarkCell extends StatelessWidget {
  const DayMarkCell({
    required this.mark,
    this.onTap,
    this.caption,
    this.label,
    this.tooltipDay,
    this.tooltipOutcome,
    super.key,
  });

  final DayMark mark;
  final VoidCallback? onTap;

  /// A one-letter weekday initial drawn above the square, inside the hit
  /// slot, on a tappable cell only: an action has to say which day it acts
  /// on before it is tapped. Ignored without [onTap] — a read-only strip is
  /// the handover's bare row of squares.
  final String? caption;

  /// Spoken name for a tappable cell. Null on a read-only strip, whose
  /// semantics are carried by the summary above it.
  final String? label;

  /// The hover tooltip: the day names the subject, the outcome describes it.
  /// A read-only cell still answers hover with them — the square cannot tell
  /// one Tuesday from the next, and the tooltip is where a dated cell reveals
  /// which day it stands for.
  final String? tooltipDay;
  final String? tooltipOutcome;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final verdict = mark.verdict;
    final Widget cell = mark.pending
        ? const PlaceholderDayCell()
        : Container(
            width: kDaySquareSize,
            height: kDaySquareSize,
            decoration: BoxDecoration(
              color: verdict == null
                  ? dayMarkStateFill(tokens, mark.state)
                  : dayVerdictFill(tokens, verdict),
              borderRadius: BorderRadius.circular(tokens.radii.xs),
            ),
          );
    final onTap = this.onTap;
    if (onTap == null) {
      final tooltipDay = this.tooltipDay;
      if (tooltipDay == null) return cell;
      return DsTooltip(
        title: tooltipDay,
        message: tooltipOutcome ?? '',
        preferBelow: false,
        child: cell,
      );
    }
    // The square keeps its size; the hit slot around it takes the full height
    // of the touch floor and whatever width the row can spare. No hover fill:
    // the slot is far larger than the square it serves, and Material's
    // overlay drew a phantom button bulging around the cell. Hover answers
    // with the tooltip instead. `excludeSemantics` drops the ink well's own
    // node, so the activation action is published here.
    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: DsTooltip(
        title: tooltipDay,
        message: tooltipOutcome ?? '',
        preferBelow: false,
        child: DsQuietInk(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          focusRing: true,
          builder: (context, highlighted) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TapTargets.minimum),
            child: Center(child: dayCellWithCaption(tokens, cell, caption)),
          ),
        ),
      ),
    );
  }
}

/// A day square with its weekday initial above it — the layout every
/// tappable day cell shares, whether it is a [DayMarkCell] or the goal
/// card's own outcome-menu cell. Just the square when [caption] is null.
Widget dayCellWithCaption(DsTokens tokens, Widget square, String? caption) {
  if (caption == null) return square;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        caption,
        maxLines: 1,
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
      SizedBox(height: tokens.spacing.step1),
      square,
    ],
  );
}
