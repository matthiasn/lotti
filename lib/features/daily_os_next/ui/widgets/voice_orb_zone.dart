import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Fixed-height block hosting the waveform slot, the voice orb, and a
/// one-line status caption — the shared bottom anatomy of the Capture and
/// Refine surfaces.
///
/// Stability contract: the reserved space never changes with phase — the
/// waveform slot is always present (content only while listening /
/// transcribing), and the caption is a single forced-strut line whose style
/// is identical across phases (only the color changes). That is what keeps
/// the orb stationary under the user's finger.
class VoiceOrbZone extends StatelessWidget {
  const VoiceOrbZone({
    required this.phase,
    required this.caption,
    required this.captionColor,
    required this.semanticLabel,
    required this.onTap,
    this.amplitudes = const [],
    this.dbfs = CaptureState.defaultDbfs,
    super.key,
  });

  /// Height reserved for the waveform strip whether or not it is shown.
  @visibleForTesting
  static const double waveformSlotHeight = 24;

  /// Capture phase driving the orb visuals and the waveform slot.
  final CapturePhase phase;

  /// One-line status caption under the orb. Status only — actions live on
  /// the orb itself and on the host's action bar.
  final String caption;

  final Color captionColor;

  final String semanticLabel;

  final VoidCallback onTap;

  /// Rolling normalized amplitude window for the waveform strip.
  final List<double> amplitudes;

  /// Latest recorder amplitude in dBFS, passed through to the orb shader.
  final double dbfs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final showWaveform =
        phase == CapturePhase.listening || phase == CapturePhase.transcribing;

    final captionStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: captionColor,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: waveformSlotHeight,
          child: showWaveform
              ? AnimatedOpacity(
                  opacity: phase == CapturePhase.listening ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: LiveWaveform(
                    amplitudes: amplitudes,
                    width: 220,
                    height: waveformSlotHeight,
                  ),
                )
              : null,
        ),
        // step5 air on both sides of the orb: the listening shader spills
        // past the button field, so the neighbours need clearance for it
        // to breathe.
        SizedBox(height: tokens.spacing.step5),
        VoiceButton(
          phase: phase,
          dbfs: dbfs,
          semanticLabel: semanticLabel,
          onTap: onTap,
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          strutStyle: StrutStyle.fromTextStyle(
            captionStyle,
            forceStrutHeight: true,
          ),
          style: captionStyle,
        ),
      ],
    );
  }
}

/// Live transcript pinned above the orb: bottom-aligned, auto-following
/// the newest words, fading out toward the top edge of its zone.
class LiveTranscriptView extends StatelessWidget {
  const LiveTranscriptView({
    required this.text,
    required this.color,
    super.key,
  });

  /// Stable key on the scrolling viewport, for layout asserts.
  @visibleForTesting
  static const Key viewportKey = Key(
    'daily_os_capture_live_transcript_viewport',
  );

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (text.isEmpty) return const SizedBox.expand();
    final style = tokens.typography.styles.body.bodyMedium.copyWith(
      color: color,
    );

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0, 0.22],
      ).createShader(bounds),
      child: SizedBox.expand(
        key: viewportKey,
        child: SingleChildScrollView(
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ),
    );
  }
}
