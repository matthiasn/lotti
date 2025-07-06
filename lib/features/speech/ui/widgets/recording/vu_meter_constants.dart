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
}
