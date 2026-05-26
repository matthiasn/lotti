import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Big circular voice button that anchors the Capture screen.
///
/// Three visual states, driven by [CapturePhase]:
/// - **idle** — solid teal gradient circle + mic glyph.
/// - **listening** — same gradient with two concentric outward-rippling
///   teal rings; glyph stays mic.
/// - **captured** — same gradient with a stop-square glyph and no
///   rings.
///
/// Pure presentation. The parent calls [onTap] which delegates to
/// `CaptureController.toggle()`.
class VoiceButton extends StatefulWidget {
  const VoiceButton({
    required this.phase,
    required this.onTap,
    required this.semanticLabel,
    this.size = 132,
    super.key,
  });

  /// The current Capture phase. Drives glyph + ripples.
  final CapturePhase phase;

  final VoidCallback onTap;

  /// Used by screen readers; the button has no visible label.
  final String semanticLabel;

  /// Outer diameter in logical pixels.
  final double size;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with TickerProviderStateMixin {
  late final AnimationController _rippleA;
  late final AnimationController _rippleB;
  Timer? _staggerTimer;

  @override
  void initState() {
    super.initState();
    _rippleA = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _rippleB = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncRippleAnimation();
  }

  @override
  void didUpdateWidget(covariant VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != oldWidget.phase) {
      _syncRippleAnimation();
    }
  }

  void _syncRippleAnimation() {
    _staggerTimer?.cancel();
    if (widget.phase == CapturePhase.listening) {
      _rippleA
        ..reset()
        ..repeat();
      // 0.6s stagger between the two rings. Held in a Timer so the
      // pending callback is cancellable when the widget disposes
      // mid-listening.
      _staggerTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (widget.phase == CapturePhase.listening) {
          _rippleB
            ..reset()
            ..repeat();
        }
      });
    } else {
      _rippleA.stop();
      _rippleB.stop();
    }
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _rippleA.dispose();
    _rippleB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final tealDeep = tokens.colors.interactive.hover;
    final onTeal = tokens.colors.text.onInteractiveAlert;

    final glyph = widget.phase == CapturePhase.captured
        ? Icons.stop_rounded
        : MdiIcons.microphone;

    final ringMax = widget.size + 96.0;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: SizedBox(
        width: ringMax,
        height: ringMax,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.phase == CapturePhase.listening) ...[
              _Ring(
                controller: _rippleA,
                startSize: widget.size,
                endSize: ringMax,
                color: teal,
              ),
              _Ring(
                controller: _rippleB,
                startSize: widget.size,
                endSize: ringMax,
                color: teal,
              ),
            ],
            GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: widget.size,
                height: widget.size,
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
                  size: widget.size * 0.38,
                  color: onTeal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.controller,
    required this.startSize,
    required this.endSize,
    required this.color,
  });

  final AnimationController controller;
  final double startSize;
  final double endSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // Eased expansion + fade. `Curves.easeOutCubic` flattens the
        // outward motion; opacity decays linearly to zero so the ring
        // visibly leaves the field of view.
        final size =
            startSize +
            (endSize - startSize) * Curves.easeOutCubic.transform(t);
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final strokeColor = color.withValues(alpha: opacity * 0.42);
        return ExcludeSemantics(
          child: CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              color: strokeColor,
              strokeWidth: 1.5 + (2.0 * (1.0 - t)),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      math.min(size.width, size.height) / 2 - strokeWidth / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.color != color || old.strokeWidth != strokeWidth;
  }
}
