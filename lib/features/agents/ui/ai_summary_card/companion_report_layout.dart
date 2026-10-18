import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Where the companion stands on an agent report card — the task summary,
/// the goal agent's read — by the width the card body has.
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

/// What a report card's header is handed for the companion: her bust as the
/// badge's `figure` on a narrow card, no `badge` at all beside a wide one
/// (she stands in its place), and `onFigureTap` only where her bust is
/// what the header shows.
typedef CompanionHeaderSlot = ({
  Widget? figure,
  bool badge,
  VoidCallback? onFigureTap,
});

/// The top block of an agent report card — header, body and footer — with
/// the companion placed by the width the card gives it
/// ([CompanionPlacement]): standing beside all three on a wide card
/// ([CompanionBesideReport]), her bust in the header's badge tile on a
/// narrow one, and absent, the classic badge in its place, while [companion]
/// is null.
///
/// Every report card that wears her shares this, so the placement rule, the
/// breakpoint and the bust's tap mean the same on the task summary and the
/// goal agent's read. The host keeps whatever it shows below the block
/// (proposals, history).
class CompanionReportScaffold extends StatelessWidget {
  const CompanionReportScaffold({
    required this.header,
    required this.footer,
    this.body,
    this.companion,
    this.onFigureTap,
    super.key,
  });

  /// The card header for [CompanionHeaderSlot] — a `TldrHeader` passing the
  /// slot's figure, badge and tap on.
  final Widget Function(CompanionHeaderSlot slot) header;

  /// The report body, carrying its own horizontal insets; null shows none.
  final Widget? body;

  /// The freshness row, carrying its own insets.
  final Widget footer;

  /// Her figure in the framing asked for, filling the box it is given; null
  /// while she is not shown (her flag is off).
  final Widget Function(CompanionFraming framing)? companion;

  /// What tapping her bust does on a narrow card — open her full-screen
  /// stage. A wide card already shows her in full, and offers no tap.
  final VoidCallback? onFigureTap;

  @override
  Widget build(BuildContext context) {
    final cardPadding = context.designTokens.spacing.cardPadding;
    return LayoutBuilder(
      builder: (context, constraints) {
        final companion = this.companion;
        // Where she stands follows the room the card body has, not the
        // window: a desktop pane can still give the card a phone's width.
        final placement = companion == null
            ? null
            : CompanionPlacement.forBodyWidth(
                constraints.maxWidth - 2 * cardPadding,
                textScaler: MediaQuery.textScalerOf(context),
              );
        final inHeader = placement == CompanionPlacement.header;
        final headerWidget = header((
          figure: inHeader ? companion!(CompanionFraming.bust) : null,
          badge: placement != CompanionPlacement.beside,
          onFigureTap: inHeader ? onFigureTap : null,
        ));
        if (placement == CompanionPlacement.beside) {
          return CompanionBesideReport(
            companion: companion!(CompanionFraming.full),
            header: headerWidget,
            body: body ?? const SizedBox.shrink(),
            footer: footer,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [headerWidget, ?body, footer],
        );
      },
    );
  }
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
