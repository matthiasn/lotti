// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/speech/ui/widgets/recording/vu_meter_constants.dart';
import 'package:lotti/features/speech/ui/widgets/recording/vu_meter_painter.dart';

/// An analog VU (Volume Unit) meter widget that displays audio levels
/// with a traditional needle-based meter design.
class AnalogVuMeter extends StatefulWidget {
  const AnalogVuMeter({
    required this.vu,
    required this.dBFS,
    required this.size,
    required this.colorScheme,
    super.key,
  });

  /// Current VU level in dB (-20 to +3 range, where 0 VU = -18 dBFS RMS)
  final double vu;

  /// Current instantaneous dBFS level (used for clipping detection)
  final double dBFS;

  /// Width of the meter widget (height will be size * 0.5)
  final double size;

  /// Color scheme for theming the meter
  final ColorScheme colorScheme;

  @override
  State<AnalogVuMeter> createState() => _AnalogVuMeterState();
}

class _AnalogVuMeterState extends State<AnalogVuMeter>
    with TickerProviderStateMixin {
  late AnimationController _needleController;
  late AnimationController _peakController;
  late AnimationController _clipController;
  late Animation<double> _needleAnimation;
  late Animation<double> _peakAnimation;
  late Animation<double> _clipAnimation;

  double _currentValue = 0;
  double _peakValue = 0;
  Timer? _peakHoldTimer;
  Timer? _clipHoldTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Defer initial update to avoid starting timers during initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateMeter();
      }
    });
  }

  void _initializeAnimations() {
    _needleController = AnimationController(
      duration: VuMeterConstants.needleAnimationDuration,
      vsync: this,
    );
    _peakController = AnimationController(
      duration: VuMeterConstants.peakDecayDuration,
      vsync: this,
    );
    _clipController = AnimationController(
      duration: VuMeterConstants.clipAnimationDuration,
      vsync: this,
    );

    _needleAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _needleController,
      curve: Curves.easeOutCubic,
    ));

    _peakAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _peakController,
      curve: Curves.easeInOutCubic,
    ));

    _clipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _clipController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(AnalogVuMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vu != widget.vu || oldWidget.dBFS != widget.dBFS) {
      _updateMeter();
    }
  }

  void _updateMeter() {
    // Convert VU to normalized scale (0-1) for meter display
    final normalizedValue = _normalizeVu(widget.vu);
    _animateNeedle(normalizedValue);

    // Check clipping based on dBFS (clip when > -3 dBFS)
    _checkClipping(widget.dBFS);
    _updatePeak(normalizedValue);
  }

  /// Normalize VU values (-20 to +3) to 0-1 scale for meter display
  double _normalizeVu(double vu) {
    // Map VU dB to 0-1 scale position with traditional VU meter scaling
    if (vu <= -20) return 0;
    if (vu <= -10) return 0.15 * (vu + 20) / 10;
    if (vu <= -7) return 0.15 + 0.10 * (vu + 10) / 3;
    if (vu <= -5) return 0.25 + 0.10 * (vu + 7) / 2;
    if (vu <= -3) return 0.35 + 0.10 * (vu + 5) / 2;
    if (vu <= 0) return 0.45 + 0.15 * (vu + 3) / 3;
    if (vu <= 3) return 0.60 + 0.40 * vu / 3;
    return 1; // +3 dB and above
  }

  void _animateNeedle(double normalizedValue) {
    _needleAnimation = Tween<double>(
      begin: _currentValue,
      end: normalizedValue,
    ).animate(CurvedAnimation(
      parent: _needleController,
      curve: Curves.easeOutCubic,
    ));

    _needleController.forward(from: 0);
    _currentValue = normalizedValue;
  }

  void _checkClipping(double dBFS) {
    // Trigger clipping indicator when signal exceeds -3 dBFS
    if (dBFS > -3.0) {
      _clipController.forward(from: 0);
      _clipHoldTimer?.cancel();
      _clipHoldTimer = Timer(VuMeterConstants.clipHoldDuration, () {
        if (mounted) {
          _clipController.reverse();
        }
      });
    }
  }

  void _updatePeak(double normalizedValue) {
    if (normalizedValue > _peakValue) {
      _peakValue = normalizedValue;
      _holdPeak();
    }
  }

  void _holdPeak() {
    _peakAnimation = Tween<double>(
      begin: _peakValue,
      end: _peakValue,
    ).animate(_peakController);

    // Start decay after hold time
    _peakHoldTimer?.cancel();
    _peakHoldTimer = Timer(VuMeterConstants.peakHoldDuration, () {
      if (mounted) {
        _decayPeak();
      }
    });
  }

  void _decayPeak() {
    _peakAnimation = Tween<double>(
      begin: _peakValue,
      end: _currentValue, // Fall back to current level, not zero
    ).animate(CurvedAnimation(
      parent: _peakController,
      curve: Curves.easeInQuad,
    ));

    _peakController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _peakValue = _currentValue;
        });
      }
    });
  }

  @override
  void dispose() {
    _peakHoldTimer?.cancel();
    _clipHoldTimer?.cancel();
    _needleController.dispose();
    _peakController.dispose();
    _clipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 0.5,
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_needleAnimation, _peakAnimation, _clipAnimation]),
        builder: (context, child) {
          return CustomPaint(
            painter: VuMeterPainter(
              value: _needleAnimation.value,
              peakValue: _peakAnimation.value,
              clipValue: _clipAnimation.value,
              colorScheme: widget.colorScheme,
              isDarkMode: Theme.of(context).brightness == Brightness.dark,
            ),
          );
        },
      ),
    );
  }
}
