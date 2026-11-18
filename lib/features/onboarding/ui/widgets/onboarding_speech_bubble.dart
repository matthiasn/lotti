import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// What the companion says in onboarding, in a speech bubble under her whose
/// tail points up at her: a [title] in a heading, then [text] — either may be
/// left out, not both.
///
/// The bubble is the caption of her line: the same words she speaks where a
/// voice is on hand, and the only place they appear where none is.
///
/// It is outlined on the panel's own surface, so it reads as her speaking
/// and not as one more raised block like the tray under it.
///
/// With a [minHeight] the bubble takes the full width and at least that
/// height, its words starting at the top, so that it is one size from step
/// to step and the headline is at one height whatever follows it.
class OnboardingSpeechBubble extends StatelessWidget {
  const OnboardingSpeechBubble({
    this.text,
    this.title,
    this.minHeight,
    super.key,
  }) : assert(title != null || text != null, 'A bubble says something');

  final String? title;
  final String? text;

  /// The least the bubble's body takes; with it the body spans the width.
  final double? minHeight;

  /// The width of the outline around the body and up the tail.
  static const double outlineWidth = OnboardingBubbleTailPainter.overlap;

  /// What she says under the headline: one step below the headline's
  /// emphasis, so the narrator never outweighs the step's own content.
  static TextStyle bodyStyle(DsTokens tokens) => tokens
      .typography
      .styles
      .body
      .bodyMedium
      .copyWith(color: tokens.colors.text.mediumEmphasis);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fill = tokens.colors.background.level01;
    final outline = tokens.colors.decorative.level02;
    final tailSize = Size(tokens.spacing.step5, tokens.spacing.step3);
    final body = Container(
      width: minHeight == null ? null : double.infinity,
      // The words start at the top of whatever height it takes.
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: outline),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title case final title?)
              Text(
                title,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            if (title != null && text != null)
              SizedBox(height: tokens.spacing.step2),
            if (text case final text?)
              Text(
                text,
                textAlign: TextAlign.center,
                style: bodyStyle(tokens),
              ),
          ],
        ),
      ),
    );
    // The tail is painted over the body's top edge, covering the stretch of
    // outline under it, so the outline runs unbroken up one side of the tail
    // and down the other.
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: tailSize.height - OnboardingBubbleTailPainter.overlap,
          ),
          child: body,
        ),
        CustomPaint(
          size: tailSize,
          painter: OnboardingBubbleTailPainter(color: fill, outline: outline),
        ),
      ],
    );
  }
}

/// The bubble's tail: a triangle in the bubble's [color], its tip up toward
/// her, its two rising edges drawn in the bubble's [outline].
@visibleForTesting
class OnboardingBubbleTailPainter extends CustomPainter {
  const OnboardingBubbleTailPainter({
    required this.color,
    required this.outline,
  });

  final Color color;
  final Color outline;

  /// How far the tail reaches down over the body's top edge: the width of
  /// the outline it covers there.
  static const double overlap = 1;

  /// The triangle for a canvas of [size], tip first.
  static Path tailPath(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawPath(tailPath(size), Paint()..color = color)
      ..drawPath(
        Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height),
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = overlap,
      );
  }

  @override
  bool shouldRepaint(OnboardingBubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.outline != outline;
}
