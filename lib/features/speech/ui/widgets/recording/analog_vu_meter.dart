// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:lotti/features/speech/ui/widgets/recording/vu_meter_constants.dart';
import 'package:lotti/features/speech/ui/widgets/recording/vu_meter_painter.dart';

/// An analog VU (Volume Unit) meter widget that displays audio levels
/// with a traditional needle-based meter design.
class AnalogVuMeter extends StatefulWidget {
  const AnalogVuMeter({
    required this.decibels,
    required this.size,
    required this.colorScheme,
    super.key,
  });

  /// Current audio level in decibels (0-160 range)
  final double decibels;

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
    if (oldWidget.decibels != widget.decibels) {
      _updateNeedle(widget.decibels);
    }
  }

  void _updateNeedle(double decibels) {
    final normalizedValue = VuMeterUtils.normalizeDecibels(decibels);
    _animateNeedle(normalizedValue);
    _checkClipping(normalizedValue);
    _updatePeak(normalizedValue);
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

  void _checkClipping(double normalizedValue) {
    if (normalizedValue > VuMeterConstants.clipThreshold) {
      _clipController.forward(from: 0);
      Future.delayed(VuMeterConstants.clipHoldDuration, () {
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
    Future.delayed(VuMeterConstants.peakHoldDuration, () {
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
