import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The task summary with the companion who reads it aloud, arranged by the
/// width the card body has.
///
/// - **Wide** (at least [besideMinWidth]): she stands beside the whole body
///   at [ControlSizes.companionCardWide], level with the summary's opening
///   line, and the prose takes the rest of the row.
/// - **Narrow**: beside the prose she would cost a phone a third of its
///   measure and stand by a column far taller than she is. The prose takes
///   the full width instead, and she stands under it at
///   [ControlSizes.companionCardCompact], beside the links that close the
///   body — [buildBody] receives her as its disclosure leading.
///
/// Either way her slot is only as wide as the reach she uses at rest and in
/// most gestures (the bust window); the rest of her head-to-toe frame hangs
/// into the card gutter on her leading side and into the gap on her trailing
/// side, so her silhouette — not her empty frame — lines up with the edge the
/// footer starts on. Both overhangs are smaller than the gutter they hang
/// into, so a hand at full reach is never clipped by the card nor drawn over
/// the prose.
class CompanionReportLayout extends StatelessWidget {
  const CompanionReportLayout({
    required this.companion,
    required this.buildBody,
    super.key,
  });

  /// The narrowest card body that keeps her beside the prose: a 168-high
  /// slot and its gap still leave the summary about 55 characters a line.
  static const double besideMinWidth = 480;

  /// The figure, expanding to the box it is given in the full framing.
  final Widget companion;

  /// The report body; on a narrow card it is handed her slot to stand at the
  /// start of its disclosure row, on a wide one null.
  final Widget Function(Widget? disclosureLeading) buildBody;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    final gap = spacing.step5;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= besideMinWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [
              CompanionSlot(
                height: ControlSizes.companionCardWide,
                child: companion,
              ),
              Expanded(child: buildBody(null)),
            ],
          );
        }
        return buildBody(
          Padding(
            // Her frame starts at the crown of her hair; without air above
            // it she would stand on the last line of the prose.
            padding: EdgeInsetsDirectional.only(top: spacing.step3, end: gap),
            child: CompanionSlot(
              height: ControlSizes.companionCardCompact,
              child: companion,
            ),
          ),
        );
      },
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
