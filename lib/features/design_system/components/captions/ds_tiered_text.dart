import 'package:flutter/widgets.dart';

/// One line of text that shows the widest of its [tiers] that fits, so a
/// structured wording (`with Pip · last spoke Sat 1 Aug`, `model · via
/// provider`) sheds whole segments before it sheds letters. The last tier is
/// the honest end of the ladder: when even it does not fit on a line it may
/// take [maxLines] and then ellipsizes.
///
/// Assistive technology always hears [semanticsLabel] — the full first tier
/// unless told otherwise — so what the screen shortens the reader keeps.
///
/// A wording built as `state · detail` can wear two inks: with [tailStyle]
/// set, whatever follows the first [tailSeparator] takes that style, so a
/// status line keeps its alert colour on the state word and its detail in
/// the meta ink. The rendered widget is then a rich text, so a test reads
/// the wording through the span rather than `Text.data`.
class DsTieredText extends StatelessWidget {
  const DsTieredText({
    required this.tiers,
    required this.style,
    this.maxLines = 1,
    this.semanticsLabel,
    this.textKey,
    this.textAlign,
    this.tailStyle,
    this.tailSeparator = ' · ',
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

  /// The ink for everything after the first [tailSeparator]; null keeps the
  /// whole wording in [style].
  final TextStyle? tailStyle;

  /// Where [tailStyle] begins, the separator itself included.
  final String tailSeparator;

  TextSpan _span(String wording) {
    final tail = tailStyle;
    final cut = tail == null ? -1 : wording.indexOf(tailSeparator);
    if (tail == null || cut < 0) return TextSpan(text: wording, style: style);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: wording.substring(0, cut)),
        TextSpan(text: wording.substring(cut), style: tail),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var chosen = tiers.last;
        for (final tier in tiers) {
          final painter = TextPainter(
            text: _span(tier),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width <= constraints.maxWidth) {
            chosen = tier;
            break;
          }
        }
        final lines = chosen == tiers.last ? maxLines : 1;
        final label = semanticsLabel ?? tiers.first;
        if (tailStyle == null) {
          return Text(
            chosen,
            key: textKey,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            semanticsLabel: label,
            style: style,
          );
        }
        return Text.rich(
          _span(chosen),
          key: textKey,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          semanticsLabel: label,
          style: style,
        );
      },
    );
  }
}
