import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Big circular voice button that anchors the Capture screen.
///
/// Three visual states, driven by [CapturePhase]:
/// - **idle** — solid teal gradient circle + mic glyph.
/// - **listening** — same gradient wrapped by the dBFS-driven tension-loop
///   shader; glyph stays mic.
/// - **captured** — same gradient with a stop-square glyph and no
///   shader.
///
/// Pure presentation. The parent calls [onTap] which delegates to
/// `CaptureController.toggle()`.
class VoiceButton extends StatelessWidget {
  const VoiceButton({
    required this.phase,
    required this.onTap,
    required this.semanticLabel,
    this.size = 132,
    this.dbfs = CaptureState.defaultDbfs,
    this.dbfsFloor = CaptureState.defaultDbfs,
    super.key,
  });

  @visibleForTesting
  static const coreButtonKey = ValueKey<String>('daily-os-voice-button-core');

  @visibleForTesting
  static const fieldKey = ValueKey<String>('daily-os-voice-button-field');

  @visibleForTesting
  static const listeningFrameKey = ValueKey<String>(
    'daily-os-voice-button-listening-frame',
  );

  @visibleForTesting
  static const restingFrameKey = ValueKey<String>(
    'daily-os-voice-button-resting-frame',
  );

  @visibleForTesting
  static const fieldPadding = 128.0;

  @visibleForTesting
  static const shaderSizeScale = 2.50;

  @visibleForTesting
  static const listeningFrameSizeScale = 1.58;

  @visibleForTesting
  static const restingFrameSizeScale = 1.46;

  @visibleForTesting
  static const shaderHoleSizeScale = 1.32;

  static double fieldSizeFor(double buttonSize) => buttonSize + fieldPadding;

  @visibleForTesting
  static double shaderSizeFor(double buttonSize) =>
      buttonSize * shaderSizeScale;

  @visibleForTesting
  static double listeningFrameSizeFor(double buttonSize) =>
      buttonSize * listeningFrameSizeScale;

  @visibleForTesting
  static double restingFrameSizeFor(double buttonSize) =>
      buttonSize * restingFrameSizeScale;

  @visibleForTesting
  static double shaderHoleSizeFor(double buttonSize) =>
      buttonSize * shaderHoleSizeScale;

  /// The current Capture phase. Drives glyph + shader visibility.
  final CapturePhase phase;

  final VoidCallback onTap;

  /// Used by screen readers; the button has no visible label.
  final String semanticLabel;

  /// Diameter of the tappable record button in logical pixels.
  final double size;

  /// Latest recorder amplitude in dBFS. Used only while listening.
  final double dbfs;

  /// Floor used to normalize [dbfs] inside the shader.
  final double dbfsFloor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final tealDeep = tokens.colors.interactive.hover;
    final onTeal = tokens.colors.text.onInteractiveAlert;
    final fieldSize = fieldSizeFor(size);
    final shaderSize = shaderSizeFor(size);
    final listeningFrameSize = listeningFrameSizeFor(size);
    final restingFrameSize = restingFrameSizeFor(size);
    final shaderHoleSize = shaderHoleSizeFor(size);
    final showRestingFrame =
        phase == CapturePhase.idle || phase == CapturePhase.error;

    final glyph = phase == CapturePhase.captured
        ? Icons.stop_rounded
        : MdiIcons.microphone;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        key: fieldKey,
        width: fieldSize,
        height: fieldSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (phase == CapturePhase.listening)
              ExcludeSemantics(
                child: OverflowBox(
                  minWidth: shaderSize,
                  maxWidth: shaderSize,
                  minHeight: shaderSize,
                  maxHeight: shaderSize,
                  child: ClipPath(
                    clipper: _RingFieldClipper(holeDiameter: shaderHoleSize),
                    child: AiVoiceInputShader(
                      dbfs: dbfs,
                      dbfsFloor: dbfsFloor,
                      size: shaderSize,
                      intensity: 0.84,
                      lineDensity: 24,
                      orbitalMix: 0.60,
                      primaryColor: teal,
                      secondaryColor: tokens.colors.text.highEmphasis,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            if (phase == CapturePhase.listening)
              ExcludeSemantics(
                child: _ListeningFrame(
                  diameter: listeningFrameSize,
                  color: teal,
                ),
              ),
            if (showRestingFrame)
              ExcludeSemantics(
                child: _RestingFrame(
                  diameter: restingFrameSize,
                  color: teal,
                ),
              ),
            // Wrap in Material/InkWell instead of `GestureDetector` so
            // keyboard focus, semantics actions, and ripple feedback
            // come from the platform's button primitive.
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Container(
                  key: coreButtonKey,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [teal, tealDeep],
                      stops: const [0.2, 1.0],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(
                    glyph,
                    size: size * 0.38,
                    color: onTeal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningFrame extends StatelessWidget {
  const _ListeningFrame({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: VoiceButton.listeningFrameKey,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: color.a * 0.36),
          width: 1.5,
        ),
      ),
      child: SizedBox.square(dimension: diameter),
    );
  }
}

class _RestingFrame extends StatelessWidget {
  const _RestingFrame({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: VoiceButton.restingFrameKey,
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: color.a * 0.16),
              ),
            ),
            child: SizedBox.square(dimension: diameter),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: color.a * 0.08),
              ),
            ),
            child: SizedBox.square(dimension: diameter * 0.78),
          ),
        ],
      ),
    );
  }
}

class _RingFieldClipper extends CustomClipper<Path> {
  const _RingFieldClipper({required this.holeDiameter});

  final double holeDiameter;

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hole = Rect.fromCircle(center: center, radius: holeDiameter / 2);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(hole);
  }

  @override
  bool shouldReclip(covariant _RingFieldClipper oldClipper) {
    return oldClipper.holeDiameter != holeDiameter;
  }
}
