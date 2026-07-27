import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The six characters both devices derive independently, plus the line that
/// tells the reader what to do with them.
///
/// Shared rather than duplicated: the two sides are asked to look identical,
/// and when the inviting device rendered a rank smaller than the joining one,
/// the same string looked like two different values.
class PairingCheckCodeView extends StatelessWidget {
  const PairingCheckCodeView({
    required this.code,
    required this.caption,
    super.key,
    this.label,
    this.codeKey,
  });

  final String code;

  /// Names the value. Without it, six characters sitting between a QR and
  /// "paste this code there instead" read as the thing to paste.
  final String? label;

  /// What the reader should do — the imperative on one side, the mismatch
  /// consequence on the other.
  final String caption;

  /// Key applied to the code [Text], for tests that read the rendered value.
  final Key? codeKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final label = this.label;

    return Column(
      children: [
        if (label != null) ...[
          Text(
            label,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
        ],
        Text(
          code,
          key: codeKey,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.heading.heading2.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}
