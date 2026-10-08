import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One "next time" fact: its caption (`Pay attention to`, `Better to
/// avoid`), the words themselves, and the key a test finds the words by.
typedef NextTimeFact = ({String caption, String text, Key? key});

/// The notes to keep in mind next time, as the person page and the check-in
/// page both draw them: a low-emphasis caption over the body line, `step1`
/// between the two, `step3` between facts — flat on the card, no tile of
/// their own. The person page used to frame each fact in a bordered box
/// while the check-in page set the same facts flat, so the one piece of
/// content the two pages share looked like two components.
class NextTimeFacts extends StatelessWidget {
  const NextTimeFacts({required this.facts, super.key});

  final List<NextTimeFact> facts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, fact) in facts.indexed) ...[
          if (index > 0) SizedBox(height: tokens.spacing.step3),
          Text(
            fact.caption,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          Text(
            fact.text,
            key: fact.key,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ],
    );
  }
}
