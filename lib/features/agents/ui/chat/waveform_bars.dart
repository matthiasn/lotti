import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The live recording waveform, drawn the way a phone's voice composer draws
/// one: a row of thin capsules in the composer's own row, newest on the
/// right, scrolling left as the recording goes on. Speech is a tall capsule,
/// quiet is a dot — so the row reads as "listening" even before a word.
///
/// No frame and no baseline: the waveform is content of the composer, not a
/// field inside it. One colour, the high-emphasis text token, in both
/// themes. Slots older than the recording are dots, so the row is always
/// full width rather than growing in from the right.
class WaveformBars extends StatelessWidget {
  const WaveformBars({
    required this.amplitudesNormalized,
    super.key,
  });

  /// Levels in `0..1`, oldest first — one bar each.
  final List<double> amplitudesNormalized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Bars are as wide as the gaps between them: the smallest spacing step.
    final bar = tokens.spacing.step1;
    return SizedBox(
      height: tokens.spacing.step7,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: Size(constraints.maxWidth, tokens.spacing.step7),
          painter: WaveformBarsPainter(
            amplitudes: amplitudesNormalized,
            barWidth: bar,
            barSpacing: bar,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}

/// Paints [WaveformBars]. Public so its geometry can be tested directly.
@visibleForTesting
class WaveformBarsPainter extends CustomPainter {
  WaveformBarsPainter({
    required this.amplitudes,
    required this.barWidth,
    required this.barSpacing,
    required this.color,
  });

  /// Levels in `0..1`, oldest first.
  final List<double> amplitudes;
  final double barWidth;
  final double barSpacing;
  final Color color;

  /// How many bars fit [width], newest at the right edge.
  int capacity(double width) =>
      ((width + barSpacing) / (barWidth + barSpacing)).floor();

  /// The height of a bar for [level]: a dot (as tall as it is wide) at the
  /// bottom of the range, the full [maxHeight] at the top. Eased in, so
  /// ordinary room noise stays close to a dot and speech stands up.
  double barHeight(double level, double maxHeight) {
    final eased = Curves.easeIn.transform(level.clamp(0.0, 1.0));
    return barWidth + eased * (maxHeight - barWidth);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final slots = capacity(size.width);
    if (slots <= 0) return;
    final paint = Paint()..color = color;
    final radius = Radius.circular(barWidth / 2);
    final centreY = size.height / 2;
    final step = barWidth + barSpacing;
    // Right-aligned: slot `slots - 1` is the newest sample.
    final offset = size.width - (slots * step - barSpacing);
    final firstSample = amplitudes.length - slots;
    for (var slot = 0; slot < slots; slot++) {
      final sample = firstSample + slot;
      final level = sample < 0 ? 0.0 : amplitudes[sample];
      final height = barHeight(level, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offset + slot * step,
            centreY - height / 2,
            barWidth,
            height,
          ),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformBarsPainter oldDelegate) =>
      oldDelegate.amplitudes != amplitudes ||
      oldDelegate.color != color ||
      oldDelegate.barWidth != barWidth ||
      oldDelegate.barSpacing != barSpacing;
}
