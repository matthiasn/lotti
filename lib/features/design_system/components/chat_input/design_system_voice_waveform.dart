import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The live voice of a take, as a row of thin bars that spans all the width
/// it is given — on a phone and on the widest desktop row alike.
///
/// The row shows the last [window] of the take, however wide it is: the bar
/// count follows the width (one bar and one gap per slot), and each bar is
/// its slice of the window, read between the samples around it. So the row
/// is full a few seconds into a take and stays full, rather than filling at
/// one bar per sample and leaving most of a wide row for time before the
/// take. Nothing is drawn for that time: a take grows in from the right.
///
/// Bars are centred and grow both ways; loudness is eased in, so room noise
/// stays near a dot and speech uses most of the height. One quiet ink: the
/// voice is content of the composer, never its action.
class DesignSystemVoiceWaveform extends StatelessWidget {
  const DesignSystemVoiceWaveform({
    required this.levels,
    this.sampleInterval = defaultSampleInterval,
    this.window = defaultWindow,
    this.color,
    super.key,
  });

  /// How far back the row reaches.
  static const Duration defaultWindow = Duration(seconds: 4);

  /// How often a level is taken: the recorder's amplitude interval.
  static const Duration defaultSampleInterval = Duration(milliseconds: 100);

  /// Loudness in `0..1`, oldest first, one per [sampleInterval].
  final List<double> levels;
  final Duration sampleInterval;
  final Duration window;

  /// The bars' ink; medium emphasis when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final height = tokens.spacing.step7;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: DesignSystemVoiceWaveformPainter(
              levels: levels,
              samplesPerWindow:
                  window.inMicroseconds / sampleInterval.inMicroseconds,
              barWidth: tokens.spacing.step1,
              barSpacing: tokens.spacing.step1,
              color: color ?? tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [DesignSystemVoiceWaveform]. Public so its geometry can be tested.
@visibleForTesting
class DesignSystemVoiceWaveformPainter extends CustomPainter {
  DesignSystemVoiceWaveformPainter({
    required this.levels,
    required this.samplesPerWindow,
    required this.barWidth,
    required this.barSpacing,
    required this.color,
  });

  final List<double> levels;

  /// How many samples the row spans, end to end.
  final double samplesPerWindow;
  final double barWidth;
  final double barSpacing;
  final Color color;

  /// How many bars fit [width].
  int capacity(double width) =>
      ((width + barSpacing) / (barWidth + barSpacing)).floor();

  /// The level at fractional sample [at], read between its two neighbours;
  /// null before the take.
  double? levelAt(double at) {
    if (levels.isEmpty || at < 0) return null;
    final last = levels.length - 1;
    if (at >= last) return levels[last];
    final low = at.floor();
    final t = at - low;
    return levels[low] * (1 - t) + levels[low + 1] * t;
  }

  /// The height of a bar for [level]: a dot (as tall as it is wide) at the
  /// bottom of the range, all of [maxHeight] at the top.
  double barHeight(double level, double maxHeight) {
    final eased = Curves.easeOut.transform(level.clamp(0.0, 1.0));
    return barWidth + eased * (maxHeight - barWidth);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final slots = capacity(size.width);
    if (slots <= 0 || levels.isEmpty) return;
    final paint = Paint()..color = color;
    final radius = Radius.circular(barWidth / 2);
    final centreY = size.height / 2;
    final step = barWidth + barSpacing;
    // Right-aligned: the last slot is the newest sample.
    final offset = size.width - (slots * step - barSpacing);
    final newest = (levels.length - 1).toDouble();
    final perSlot = slots > 1 ? samplesPerWindow / (slots - 1) : 0.0;
    for (var slot = 0; slot < slots; slot++) {
      final level = levelAt(newest - (slots - 1 - slot) * perSlot);
      if (level == null) continue;
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
  bool shouldRepaint(covariant DesignSystemVoiceWaveformPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.samplesPerWindow != samplesPerWindow ||
      oldDelegate.color != color ||
      oldDelegate.barWidth != barWidth ||
      oldDelegate.barSpacing != barSpacing;
}
