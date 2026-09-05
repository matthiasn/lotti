import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:material_ui/material_ui.dart';

/// The six characters both devices derive independently, plus the line that
/// tells the reader what to do with them.
///
/// Shared rather than duplicated: the two sides are asked to look identical,
/// and when the inviting device rendered a rank smaller than the joining one,
/// the same string looked like two different values. The code itself is the
/// loudest thing in its block — mono at heading rank with opened tracking —
/// because it is the one value a human is asked to compare across a desk.
class PairingCheckCodeView extends StatelessWidget {
  const PairingCheckCodeView({
    required this.code,
    required this.caption,
    super.key,
    this.label,
    this.codeKey,
    this.centered = true,
  });

  final String code;

  /// Overline naming the value. Without it, six characters sitting between a
  /// QR and "paste this code there instead" read as the thing to paste.
  final String? label;

  /// What the reader should do — the comparison question on one side, the
  /// compare-before-connecting instruction on the other.
  final String caption;

  /// Key applied to the code [Text], for tests that read the rendered value.
  final Key? codeKey;

  /// Centred in a hero well; start-aligned beside the QR on a wide card.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = this.label;
    final align = centered ? TextAlign.center : TextAlign.start;
    // Mono, at a rank far above prose, with the tracking opened so the
    // characters can be checked one by one across two screens.
    final codeStyle =
        monoMetaStyle(
          tokens,
          tokens.colors,
          base: tokens.typography.styles.heading.heading1,
          color: tokens.colors.text.highEmphasis,
        ).copyWith(
          fontWeight: tokens.typography.weight.regular,
          letterSpacing: tokens.spacing.step1 * 2,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label.toUpperCase(),
            textAlign: align,
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
        ],
        Text(code, key: codeKey, textAlign: align, style: codeStyle),
        SizedBox(height: tokens.spacing.step2),
        Text(
          caption,
          textAlign: align,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}
