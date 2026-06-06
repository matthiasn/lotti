part of 'capture_page.dart';

/// Pure viewport-height → layout calculation for the capture page.
///
/// Public (but test-only outside this file) so the clamp/line-count
/// invariants can be unit- and property-tested without widget pumps.
@visibleForTesting
class CaptureLayoutMetrics {
  const CaptureLayoutMetrics({
    required this.stateSlotHeight,
    required this.liveTranscriptLineCount,
    required this.reviewTranscriptLineCount,
  });

  factory CaptureLayoutMetrics.resolve(
    DsTokens tokens, {
    required CapturePhase phase,
    required double viewportHeight,
  }) {
    final minimumReviewTranscriptLineCount =
        minimumReviewTranscriptLineCountFor(viewportHeight);
    final minimumSlotHeight = minimumSlotHeightFor(
      tokens,
      phase,
      minimumReviewTranscriptLineCount: minimumReviewTranscriptLineCount,
    );
    final maximumSlotHeight = maximumSlotHeightFor(tokens);
    final availableForState =
        viewportHeight - _fixedVerticalChrome(tokens, phase);
    // On extreme viewports/zoom levels the phase minimum can exceed the cap;
    // widen the upper bound so clamp() never throws — the minimum wins, as it
    // already does when the available space is smaller than the minimum.
    final stateSlotHeight = availableForState
        .clamp(
          minimumSlotHeight,
          math.max(minimumSlotHeight, maximumSlotHeight),
        )
        .toDouble();

    return CaptureLayoutMetrics(
      stateSlotHeight: stateSlotHeight,
      liveTranscriptLineCount: _liveTranscriptLineCount(
        tokens,
        stateSlotHeight,
      ),
      reviewTranscriptLineCount: _reviewTranscriptLineCount(
        tokens,
        stateSlotHeight,
        minimumLineCount: minimumReviewTranscriptLineCount,
      ),
    );
  }

  final double stateSlotHeight;
  final int liveTranscriptLineCount;
  final int reviewTranscriptLineCount;

  static double _fixedVerticalChrome(DsTokens tokens, CapturePhase phase) {
    final greetingHeight =
        _lineHeightOf(calmGreetingStyle(tokens)) +
        tokens.spacing.step2 +
        _lineHeightOf(calmPageTitleStyle(tokens));
    final headlineHeight = _lineHeightOf(calmHeroStyle(tokens)) * 2;
    final capturedActionsHeight = phase == CapturePhase.captured
        ? tokens.spacing.step6 + tokens.spacing.step9
        : 0;

    return tokens.spacing.step6 * 2 +
        greetingHeight +
        tokens.spacing.step6 +
        headlineHeight +
        tokens.spacing.step8 +
        VoiceButton.fieldSizeFor(132) +
        tokens.spacing.step5 +
        capturedActionsHeight;
  }

  /// Resolved line height of a concrete [TextStyle] in logical pixels.
  static double _lineHeightOf(TextStyle style) =>
      style.fontSize! * (style.height ?? 1.0);

  /// Upper clamp bound for the state slot.
  @visibleForTesting
  static double maximumSlotHeightFor(DsTokens tokens) =>
      tokens.spacing.step13 + tokens.spacing.step11;

  /// Lower clamp bound for the state slot in the given [phase].
  @visibleForTesting
  static double minimumSlotHeightFor(
    DsTokens tokens,
    CapturePhase phase, {
    required int minimumReviewTranscriptLineCount,
  }) {
    return switch (phase) {
      CapturePhase.listening => math.max(
        tokens.spacing.step13 + tokens.spacing.step4,
        _listeningChromeHeight(tokens) +
            tokens.typography.lineHeight.bodyMedium * 3,
      ),
      CapturePhase.captured =>
        _reviewTranscriptChromeHeight(tokens) +
            tokens.typography.lineHeight.bodySmall *
                minimumReviewTranscriptLineCount,
      CapturePhase.idle ||
      CapturePhase.transcribing ||
      CapturePhase.error => tokens.spacing.step13 + tokens.spacing.step4,
    };
  }

  static int _liveTranscriptLineCount(DsTokens tokens, double slotHeight) {
    final textHeight = slotHeight - _listeningChromeHeight(tokens);
    return math.max(
      3,
      math.min(7, textHeight ~/ tokens.typography.lineHeight.bodyMedium),
    );
  }

  static int _reviewTranscriptLineCount(
    DsTokens tokens,
    double slotHeight, {
    required int minimumLineCount,
  }) {
    final textHeight = slotHeight - _reviewTranscriptChromeHeight(tokens);
    return math.max(
      minimumLineCount,
      math.min(6, textHeight ~/ tokens.typography.lineHeight.bodySmall),
    );
  }

  /// Viewport-height band for the review transcript's minimum line count:
  /// `< 560 → 2`, `< 700 → 3`, otherwise `4`.
  @visibleForTesting
  static int minimumReviewTranscriptLineCountFor(double viewportHeight) {
    if (viewportHeight < 560) return 2;
    if (viewportHeight < 700) return 3;
    return 4;
  }

  static double _reviewTranscriptChromeHeight(DsTokens tokens) {
    return tokens.typography.lineHeight.subtitle2 +
        tokens.spacing.step5 +
        tokens.spacing.step4 * 2 +
        tokens.spacing.step3;
  }

  static double _listeningChromeHeight(DsTokens tokens) {
    return tokens.spacing.step3 +
        tokens.typography.lineHeight.overline +
        tokens.spacing.step4 +
        const LiveWaveform(amplitudes: <double>[]).height +
        tokens.spacing.step4;
  }
}
