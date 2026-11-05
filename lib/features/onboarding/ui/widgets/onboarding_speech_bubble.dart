import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Where the companion stands relative to her bubble: the tail points at her.
enum OnboardingBubbleTail {
  /// She stands above the bubble.
  up,

  /// She stands to the bubble's left.
  left,
}

/// What the companion says in onboarding, in a speech bubble whose tail points
/// at her: a [title] in a heading, then [text] — either may be left out, not
/// both.
///
/// The bubble is the caption of her line: the same words she speaks where a
/// voice is on hand, and the only place they appear where none is.
class OnboardingSpeechBubble extends StatelessWidget {
  const OnboardingSpeechBubble({
    this.text,
    this.title,
    this.tail = OnboardingBubbleTail.up,
    super.key,
  }) : assert(title != null || text != null, 'A bubble says something');

  final String? title;
  final String? text;
  final OnboardingBubbleTail tail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fill = tokens.colors.background.level02;
    final centred = tail == OnboardingBubbleTail.up;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centred
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (title case final title?)
              Text(
                title,
                textAlign: centred ? TextAlign.center : TextAlign.start,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            if (title != null && text != null)
              SizedBox(height: tokens.spacing.step2),
            if (text case final text?)
              Text(
                text,
                textAlign: centred ? TextAlign.center : TextAlign.start,
                style:
                    (centred
                            ? tokens.typography.styles.body.bodyLarge
                            : tokens.typography.styles.body.bodyMedium)
                        .copyWith(color: tokens.colors.text.mediumEmphasis),
              ),
          ],
        ),
      ),
    );
    final pointer = CustomPaint(
      size: switch (tail) {
        OnboardingBubbleTail.up => Size(
          tokens.spacing.step5,
          tokens.spacing.step3,
        ),
        OnboardingBubbleTail.left => Size(
          tokens.spacing.step3,
          tokens.spacing.step5,
        ),
      },
      painter: OnboardingBubbleTailPainter(color: fill, tail: tail),
    );
    return switch (tail) {
      OnboardingBubbleTail.up => Column(
        mainAxisSize: MainAxisSize.min,
        children: [pointer, body],
      ),
      OnboardingBubbleTail.left => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pointer,
          Flexible(child: body),
        ],
      ),
    };
  }
}

/// The bubble's tail: a triangle in the bubble's [color], its tip toward her.
@visibleForTesting
class OnboardingBubbleTailPainter extends CustomPainter {
  const OnboardingBubbleTailPainter({required this.color, required this.tail});

  final Color color;
  final OnboardingBubbleTail tail;

  /// The triangle for a canvas of [size], tip first.
  static Path tailPath(Size size, OnboardingBubbleTail tail) => switch (tail) {
    OnboardingBubbleTail.up =>
      Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
    OnboardingBubbleTail.left =>
      Path()
        ..moveTo(0, size.height / 2)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..close(),
  };

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(tailPath(size, tail), Paint()..color = color);

  @override
  bool shouldRepaint(OnboardingBubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tail != tail;
}
