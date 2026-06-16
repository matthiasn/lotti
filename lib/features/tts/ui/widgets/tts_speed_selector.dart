import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/tts/model/tts_settings.dart';

/// Playback-speed control over [kTtsSpeedSequence] (0.5×–2×).
///
/// Rendered as a fill-width [DsSegmentedToggle] so all seven steps share one
/// pill and speak the same visual language as the voice gender toggle and the
/// rest of the app's segmented controls. Fill-width (`expand`) keeps every
/// step in a single row at any pane width instead of wrapping.
class TtsSpeedSelector extends StatelessWidget {
  const TtsSpeedSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Currently selected speed; must be one of [kTtsSpeedSequence].
  final double value;

  /// Called with the tapped speed step.
  final ValueChanged<double> onChanged;

  /// Renders a speed for the toggle: whole numbers drop the decimal
  /// (`1` not `1.0`), fractional steps keep it (`0.75`).
  static String formatSpeed(double speed) {
    return speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DsSegmentedToggle<double>(
      expand: true,
      selected: value,
      onChanged: onChanged,
      segments: [
        for (final speed in kTtsSpeedSequence)
          DsSegment(speed, formatSpeed(speed)),
      ],
    );
  }
}
