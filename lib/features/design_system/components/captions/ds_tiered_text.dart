import 'package:flutter/widgets.dart';

/// One line of text that shows the widest of its [tiers] that fits, so a
/// structured wording (`with Pip · last spoke Sat 1 Aug`, `model · via
/// provider`) sheds whole segments before it sheds letters. The last tier is
/// the honest end of the ladder: when even it does not fit on a line it may
/// take [maxLines] and then ellipsizes.
///
/// Assistive technology always hears [semanticsLabel] — the full first tier
/// unless told otherwise — so what the screen shortens the reader keeps.
class DsTieredText extends StatelessWidget {
  const DsTieredText({
    required this.tiers,
    required this.style,
    this.maxLines = 1,
    this.semanticsLabel,
    this.textKey,
    this.textAlign,
    super.key,
  }) : assert(tiers.length > 0, 'a ladder needs at least one wording');

  /// Widest wording first.
  final List<String> tiers;
  final TextStyle style;

  /// Lines the narrowest tier may take when none fits on one.
  final int maxLines;

  /// What assistive technology reads; the first tier when null.
  final String? semanticsLabel;

  /// On the rendered [Text], so a test reads the wording that was chosen.
  final Key? textKey;

  /// Where the chosen wording sits in the width it was given.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var chosen = tiers.last;
        for (final tier in tiers) {
          final painter = TextPainter(
            text: TextSpan(text: tier, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width <= constraints.maxWidth) {
            chosen = tier;
            break;
          }
        }
        return Text(
          chosen,
          key: textKey,
          maxLines: chosen == tiers.last ? maxLines : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          semanticsLabel: semanticsLabel ?? tiers.first,
          style: style,
        );
      },
    );
  }
}
