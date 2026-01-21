import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';

/// A full-screen celebration overlay with confetti and trophy animation.
///
/// Use for achievements, completions, milestones, etc.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.stars = 0,
    this.reward,
    this.onDismiss,
    this.autoDismissAfter = const Duration(seconds: 3),
    this.showConfetti = true,
    super.key,
  });

  /// Main celebration title
  final String? title;

  /// Secondary message
  final String? subtitle;

  /// Celebration icon (defaults to trophy)
  final IconData? icon;

  /// Icon background color
  final Color? iconColor;

  /// Number of stars to display (0-3)
  final int stars;

  /// Optional reward text
  final String? reward;

  /// Callback when dismissed
  final VoidCallback? onDismiss;

  /// Auto-dismiss duration (null to disable)
  final Duration? autoDismissAfter;

  /// Whether to show confetti
  final bool showConfetti;

  /// Show the celebration overlay
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    int stars = 0,
    String? reward,
    Duration? autoDismissAfter = const Duration(seconds: 3),
    bool showConfetti = true,
  }) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => CelebrationOverlay(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        stars: stars,
        reward: reward,
        autoDismissAfter: autoDismissAfter,
        showConfetti: showConfetti,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _contentController;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;

  final List<_ConfettiParticle> _confetti = [];
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();

    // Icon animation
    _iconController = AnimationController(
      vsync: this,
      duration: GameyAnimations.celebration,
    );
    _iconScaleAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: GameyAnimations.bounce,
      ),
    );

    // Content animation
    _contentController = AnimationController(
      vsync: this,
      duration: GameyAnimations.normal,
    );
    _contentFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: GameyAnimations.smooth,
      ),
    );
    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: GameyAnimations.smooth,
      ),
    );

    // Confetti animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.showConfetti) {
      _generateConfetti();
    }

    // Start animations
    _iconController.forward().then((_) {
      _contentController.forward();
    });

    if (widget.showConfetti) {
      _confettiController.forward();
    }

    // Auto-dismiss
    if (widget.autoDismissAfter != null) {
      Future.delayed(widget.autoDismissAfter!, () {
        if (mounted) {
          widget.onDismiss?.call();
        }
      });
    }
  }

  void _generateConfetti() {
    final random = math.Random();
    for (var i = 0; i < 50; i++) {
      _confetti.add(
        _ConfettiParticle(
          color: GameyColors
              .confettiColors[random.nextInt(GameyColors.confettiColors.length)],
          startX: random.nextDouble(),
          startY: -0.1 - random.nextDouble() * 0.3,
          endY: 1.2,
          size: 6 + random.nextDouble() * 6,
          rotation: random.nextDouble() * math.pi * 2,
          rotationSpeed: (random.nextDouble() - 0.5) * 4,
          horizontalDrift: (random.nextDouble() - 0.5) * 0.3,
          delay: random.nextDouble() * 0.3,
        ),
      );
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _contentController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = widget.iconColor ?? GameyColors.goldReward;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Confetti layer
            if (widget.showConfetti)
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(
                      confetti: _confetti,
                      progress: _confettiController.value,
                    ),
                  );
                },
              ),

            // Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with glow
                  AnimatedBuilder(
                    animation: _iconScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _iconScaleAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            effectiveIconColor,
                            effectiveIconColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: GameyGlows.neonGlow(effectiveIconColor),
                      ),
                      child: Icon(
                        widget.icon ?? Icons.emoji_events,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stars
                  if (widget.stars > 0)
                    SlideTransition(
                      position: _contentSlideAnimation,
                      child: FadeTransition(
                        opacity: _contentFadeAnimation,
                        child: _StarRating(stars: widget.stars),
                      ),
                    ),

                  if (widget.stars > 0) const SizedBox(height: 16),

                  // Title
                  if (widget.title != null)
                    SlideTransition(
                      position: _contentSlideAnimation,
                      child: FadeTransition(
                        opacity: _contentFadeAnimation,
                        child: Text(
                          widget.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 8),
                    SlideTransition(
                      position: _contentSlideAnimation,
                      child: FadeTransition(
                        opacity: _contentFadeAnimation,
                        child: Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],

                  // Reward
                  if (widget.reward != null) ...[
                    const SizedBox(height: 20),
                    SlideTransition(
                      position: _contentSlideAnimation,
                      child: FadeTransition(
                        opacity: _contentFadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: GameyGradients.gold,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow:
                                GameyGlows.achievementGlow(highlighted: true),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.diamond,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.reward!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Tap to dismiss hint
                  FadeTransition(
                    opacity: _contentFadeAnimation,
                    child: Text(
                      'Tap to continue',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isFilled = index < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            isFilled ? Icons.star : Icons.star_border,
            color: isFilled ? GameyColors.goldReward : Colors.white30,
            size: 32,
          ),
        );
      }),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.color,
    required this.startX,
    required this.startY,
    required this.endY,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.horizontalDrift,
    required this.delay,
  });

  final Color color;
  final double startX;
  final double startY;
  final double endY;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double horizontalDrift;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.confetti,
    required this.progress,
  });

  final List<_ConfettiParticle> confetti;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in confetti) {
      final adjustedProgress =
          ((progress - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final x = size.width *
          (particle.startX + particle.horizontalDrift * adjustedProgress);
      final y = size.height *
          (particle.startY +
              (particle.endY - particle.startY) * adjustedProgress);
      final rotation =
          particle.rotation + particle.rotationSpeed * adjustedProgress;
      final opacity = (1 - adjustedProgress * 0.5).clamp(0.0, 1.0);

      canvas..save()
      ..translate(x, y)
      ..rotate(rotation);

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas..drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      )

      ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// A simple confetti burst widget that can be added anywhere
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    this.particleCount = 30,
    this.duration = const Duration(milliseconds: 1500),
    this.colors,
    this.onComplete,
    super.key,
  });

  final int particleCount;
  final Duration duration;
  final List<Color>? colors;
  final VoidCallback? onComplete;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _confetti = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _generateConfetti();
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  void _generateConfetti() {
    final random = math.Random();
    final colors = widget.colors ?? GameyColors.confettiColors;

    for (var i = 0; i < widget.particleCount; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 0.2 + random.nextDouble() * 0.3;

      _confetti.add(
        _ConfettiParticle(
          color: colors[random.nextInt(colors.length)],
          startX: 0.5,
          startY: 0.5,
          endY: 0.5 + math.sin(angle) * speed,
          size: 4 + random.nextDouble() * 4,
          rotation: random.nextDouble() * math.pi * 2,
          rotationSpeed: (random.nextDouble() - 0.5) * 6,
          horizontalDrift: math.cos(angle) * speed,
          delay: 0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            confetti: _confetti,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.confetti,
    required this.progress,
  });

  final List<_ConfettiParticle> confetti;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in confetti) {
      final x = size.width *
          (particle.startX + particle.horizontalDrift * progress);
      final y = size.height *
          (particle.startY + (particle.endY - particle.startY) * progress);
      final rotation = particle.rotation + particle.rotationSpeed * progress;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      canvas..save()
      ..translate(x, y)
      ..rotate(rotation);

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas..drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: particle.size,
          height: particle.size * 0.6,
        ),
        paint,
      )

      ..restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
