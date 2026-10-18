import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Where the companion stands on the task summary card, by the width the
/// card body has.
enum CompanionPlacement {
  /// Head to toe at the card's leading side, [ControlSizes.companionCard]
  /// high, in place of the badge and heading the header, summary and
  /// freshness row ([CompanionBesideReport]); her head is level with the
  /// title.
  beside(CompanionFraming.full),

  /// Her bust inside the header's badge tile, grown to [ControlSizes.avatar]
  /// like the Day header's bust, beside the agent name she answers to; the
  /// summary keeps the full width. Beside the prose on a
  /// phone she would cost it a third of its measure and stand by a column
  /// far taller than she is.
  header(CompanionFraming.bust);

  const CompanionPlacement(this.framing);

  /// The framing she is drawn in for this placement.
  final CompanionFraming framing;

  /// The narrowest card body, at the default text scale, that keeps her
  /// beside the prose: her slot and its gap still leave the summary about
  /// 55 characters a line.
  static const double besideMinWidth = 480;

  /// Beside the prose when the body keeps that measure at the reader's
  /// [textScaler]: larger type needs a wider body for the same characters a
  /// line, so on a mid-width card large text moves her into the header
  /// rather than starving the summary.
  static CompanionPlacement forBodyWidth(
    double width, {
    TextScaler textScaler = TextScaler.noScaling,
  }) => width >= textScaler.scale(besideMinWidth) ? beside : header;
}

/// [companion] standing at the leading side of the card, heading the
/// [header], [body] and [footer] beside her — in place of the header's
/// badge, so the title, the agent name, the summary, its links and the
/// freshness row share one edge.
///
/// Her slot sits on the card padding and is only as wide as the reach she
/// uses at rest and in most gestures (the bust window); the rest of her
/// head-to-toe frame hangs into the card gutter on her leading side and into
/// the header's and body's own leading inset on her trailing side. Both
/// overhangs are smaller than the gutter they hang into, so a hand at full
/// reach is never clipped by the card nor drawn over the prose.
///
/// Her head starts where the header's content does, and the slot keeps a
/// step4 floor under her shoes, the freshness row's own bottom inset, so
/// under a short summary her feet and the status band end on one line.
class CompanionBesideReport extends StatelessWidget {
  const CompanionBesideReport({
    required this.companion,
    required this.header,
    required this.body,
    required this.footer,
    super.key,
  });

  /// The figure, expanding to the box it is given in the full framing.
  final Widget companion;

  /// The card header, without its badge, carrying its own insets.
  final Widget header;

  /// The report body, carrying its own horizontal insets.
  final Widget body;

  /// The freshness row, carrying its own insets: in the column, so "Out of
  /// date" starts on the summary's edge, and at the column's foot, so it
  /// closes the card level with her feet however short the summary.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: spacing.cardPadding,
            top: spacing.step4,
            bottom: spacing.step4,
          ),
          child: CompanionSlot(
            height: ControlSizes.companionCard,
            child: companion,
          ),
        ),
        Expanded(
          // At least her rail's height, with the freshness row at its foot:
          // under a one-line summary the status band still closes the card
          // instead of floating beside her shins. Taller prose needs no
          // spare room, and the column is just its content.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  spacing.step4 + ControlSizes.companionCard + spacing.step4,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, body],
                ),
                footer,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A slot [height] high and as wide as the bust window, holding [child] in
/// its full head-to-toe frame, centred and overhanging both sides by the
/// difference.
class CompanionSlot extends StatelessWidget {
  const CompanionSlot({required this.height, required this.child, super.key});

  final double height;
  final Widget child;

  /// How far her full frame overhangs each side of a slot [height] high.
  static double overhang(double height) {
    final full = CompanionFraming.full.window;
    final slot = CompanionFraming.bust.window;
    return (full.width - slot.width) / 2 * height / full.height;
  }

  @override
  Widget build(BuildContext context) {
    final frameWidth = height * CompanionFraming.full.aspectRatio;
    return SizedBox(
      width: frameWidth - 2 * overhang(height),
      height: height,
      child: OverflowBox(
        minWidth: frameWidth,
        maxWidth: frameWidth,
        child: child,
      ),
    );
  }
}
