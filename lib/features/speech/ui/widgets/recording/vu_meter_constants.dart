/// Constants and utilities for the VU meter widget
class VuMeterConstants {
  VuMeterConstants._();

  /// Duration for needle animation (fast response)
  static const needleAnimationDuration = Duration(milliseconds: 100);

  /// Duration for peak hold decay animation
  static const peakDecayDuration = Duration(milliseconds: 1500);

  /// Duration before peak starts to decay
  static const peakHoldDuration = Duration(milliseconds: 800);

  /// Duration for clip indicator animation
  static const clipAnimationDuration = Duration(milliseconds: 150);

  /// Duration to hold the clip indicator lit
  static const clipHoldDuration = Duration(milliseconds: 150);

  /// Threshold for triggering clip indicator (90% of scale)
  static const clipThreshold = 0.9;

  /// Reference level for 0 VU in input decibels
  static const referenceLevel = 130.0;

  /// Scale factor for converting input decibels to VU dB
  static const decibelScaleFactor = 4.0;
}

/// Utilities for VU meter calculations
class VuMeterUtils {
  VuMeterUtils._();

  /// Normalizes input decibels (0-160) to VU meter scale position (0-1)
  ///
  /// VU meters typically show -20 to +3 dB range
  /// 0 dB on VU scale should be at ~60% position
  static double normalizeDecibels(double decibels) {
    // Convert to dB scale where 130 input = 0 VU
    final vuDb = (decibels - VuMeterConstants.referenceLevel) /
        VuMeterConstants.decibelScaleFactor;

    // Map VU dB to 0-1 scale position with non-linear scaling
    // matching traditional VU meter response
    if (vuDb <= -20) return 0;
    if (vuDb <= -10) return 0.15 * (vuDb + 20) / 10;
    if (vuDb <= -7) return 0.15 + 0.10 * (vuDb + 10) / 3;
    if (vuDb <= -5) return 0.25 + 0.10 * (vuDb + 7) / 2;
    if (vuDb <= -3) return 0.35 + 0.10 * (vuDb + 5) / 2;
    if (vuDb <= 0) return 0.45 + 0.15 * (vuDb + 3) / 3;
    if (vuDb <= 3) return 0.60 + 0.20 * vuDb / 3;
    return 1; // +3 dB and above
  }
}
