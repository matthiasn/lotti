import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';

/// A fire-themed streak indicator badge.
///
/// Shows current streak count with fire emoji and animated effects.
/// Perfect for habit streaks, daily goals, etc.
class GameyStreakBadge extends StatefulWidget {
  const GameyStreakBadge({
    required this.streakCount,
    this.label,
    this.gradient,
    this.showFireEmoji = true,
    this.size = GameyStreakBadgeSize.medium,
    this.isPulsing = false,
    this.onTap,
    super.key,
  });

  /// Current streak count
  final int streakCount;

  /// Optional label (e.g., "days", "weeks")
  final String? label;

  /// Custom gradient (defaults to streak gradient)
  final Gradient? gradient;

  /// Whether to show fire emoji
  final bool showFireEmoji;

  /// Badge size
  final GameyStreakBadgeSize size;

  /// Whether to pulse when active
  final bool isPulsing;

  /// Tap callback
  final VoidCallback? onTap;

  @override
  State<GameyStreakBadge> createState() => _GameyStreakBadgeState();
}

enum GameyStreakBadgeSize {
  small(height: 28, fontSize: 12, emojiSize: 14, padding: 8),
  medium(height: 36, fontSize: 16, emojiSize: 18, padding: 12),
  large(height: 48, fontSize: 20, emojiSize: 24, padding: 16);

  const GameyStreakBadgeSize({
    required this.height,
    required this.fontSize,
    required this.emojiSize,
    required this.padding,
  });

  final double height;
  final double fontSize;
  final double emojiSize;
  final double padding;
}

class _GameyStreakBadgeState extends State<GameyStreakBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: GameyAnimations.pulse,
    );

    _pulseAnimation = Tween<double>(
      begin: 1,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: GameyAnimations.symmetrical,
      ),
    );

    if (widget.isPulsing && widget.streakCount > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(GameyStreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing &&
        widget.streakCount > 0 &&
        !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if ((!widget.isPulsing || widget.streakCount == 0) &&
        _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? GameyGradients.streak;
    final isActive = widget.streakCount > 0;

    Widget badge = Container(
      height: widget.size.height,
      padding: EdgeInsets.symmetric(horizontal: widget.size.padding),
      decoration: BoxDecoration(
        gradient: isActive ? effectiveGradient : null,
        color: isActive ? null : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(widget.size.height / 2),
        boxShadow: isActive
            ? GameyGlows.streakGlow(highlighted: widget.isPulsing)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.showFireEmoji) ...[
            Text(
              isActive ? '🔥' : '💨',
              style: TextStyle(fontSize: widget.size.emojiSize),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '${widget.streakCount}',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.size.fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(width: 4),
            Text(
              widget.label!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: widget.size.fontSize * 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    // Wrap with tap handler
    if (widget.onTap != null) {
      badge = GestureDetector(
        onTap: widget.onTap,
        child: badge,
      );
    }

    // Wrap with pulse animation
    if (widget.isPulsing && isActive) {
      badge = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: badge,
      );
    }

    return badge;
  }
}

/// A level badge with purple-blue gradient.
///
/// Shows current level with visual prominence.
class GameyLevelBadge extends StatelessWidget {
  const GameyLevelBadge({
    required this.level,
    this.gradient,
    this.size = GameyLevelBadgeSize.medium,
    this.onTap,
    super.key,
  });

  final int level;
  final Gradient? gradient;
  final GameyLevelBadgeSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? GameyGradients.level;

    Widget badge = Container(
      width: size.size,
      height: size.size,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(size.size / 3.5),
        boxShadow: GameyGlows.levelGlow(),
      ),
      child: Center(
        child: Container(
          width: size.innerSize,
          height: size.innerSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size.innerSize / 2),
          ),
          child: Center(
            child: Text(
              '$level',
              style: TextStyle(
                color: effectiveGradient.colors.first,
                fontSize: size.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      badge = GestureDetector(
        onTap: onTap,
        child: badge,
      );
    }

    return badge;
  }
}

enum GameyLevelBadgeSize {
  small(size: 32, innerSize: 20, fontSize: 12),
  medium(size: 48, innerSize: 30, fontSize: 16),
  large(size: 64, innerSize: 40, fontSize: 22);

  const GameyLevelBadgeSize({
    required this.size,
    required this.innerSize,
    required this.fontSize,
  });

  final double size;
  final double innerSize;
  final double fontSize;
}

/// Combined streak and level display
class GameyStreakLevelRow extends StatelessWidget {
  const GameyStreakLevelRow({
    required this.streakCount,
    required this.level,
    this.streakLabel,
    this.spacing = 12,
    super.key,
  });

  final int streakCount;
  final int level;
  final String? streakLabel;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameyStreakBadge(
          streakCount: streakCount,
          label: streakLabel,
          isPulsing: streakCount > 0,
        ),
        SizedBox(width: spacing),
        GameyLevelBadge(level: level),
      ],
    );
  }
}
