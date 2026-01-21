import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Glow and shadow effects for gamified visual design.
/// Glows add depth, highlight interactive elements, and create visual excitement.
class GameyGlows {
  GameyGlows._();

  // ============================================================================
  // GLOW INTENSITY LEVELS
  // ============================================================================

  static const double glowBlurSubtle = 8;
  static const double glowBlurMedium = 16;
  static const double glowBlurStrong = 24;
  static const double glowBlurIntense = 32;

  static const double glowOpacitySubtle = 0.15;
  static const double glowOpacityMedium = 0.25;
  static const double glowOpacityStrong = 0.35;
  static const double glowOpacityIntense = 0.45;

  // ============================================================================
  // SINGLE GLOW SHADOW
  // ============================================================================

  /// Creates a single color-matched glow shadow
  static BoxShadow colorGlow(
    Color color, {
    double blur = glowBlurMedium,
    double spread = 0,
    double opacity = glowOpacityMedium,
    Offset offset = Offset.zero,
  }) {
    return BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: spread,
      offset: offset,
    );
  }

  /// Creates a subtle glow for default state
  static BoxShadow subtleGlow(Color color) {
    return colorGlow(
      color,
      blur: glowBlurSubtle,
      opacity: glowOpacitySubtle,
    );
  }

  /// Creates a strong glow for highlighted/active state
  static BoxShadow strongGlow(Color color) {
    return colorGlow(
      color,
      blur: glowBlurStrong,
      opacity: glowOpacityStrong,
    );
  }

  /// Creates an intense glow for celebrations/special moments
  static BoxShadow intenseGlow(Color color) {
    return colorGlow(
      color,
      blur: glowBlurIntense,
      opacity: glowOpacityIntense,
    );
  }

  // ============================================================================
  // CARD GLOW SHADOWS (multiple layers for depth)
  // ============================================================================

  /// Creates a subtle glow effect for cards
  static List<BoxShadow> cardGlow(
    Color primaryColor, {
    bool isDark = false,
  }) {
    return [
      // Subtle outer glow only
      BoxShadow(
        color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.06),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Creates a slightly enhanced glow for highlighted cards
  static List<BoxShadow> cardGlowHighlighted(
    Color primaryColor, {
    bool isDark = false,
  }) {
    return [
      // Subtle highlighted outer glow
      BoxShadow(
        color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  // ============================================================================
  // ICON GLOW SHADOWS
  // ============================================================================

  /// Creates a subtle glow effect for icon badges
  static List<BoxShadow> iconGlow(Color color, {bool isActive = false}) {
    final opacity = isActive ? 0.15 : 0.08;
    final blur = isActive ? 8.0 : 6.0;

    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // ============================================================================
  // FEATURE-SPECIFIC GLOWS
  // ============================================================================

  /// Journal feature glow
  static List<BoxShadow> journalGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.journalTeal)
        : cardGlow(GameyColors.journalTeal);
  }

  /// Habit feature glow
  static List<BoxShadow> habitGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.habitPink)
        : cardGlow(GameyColors.habitPink);
  }

  /// Task feature glow
  static List<BoxShadow> taskGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.taskYellow)
        : cardGlow(GameyColors.taskYellow);
  }

  /// Mood feature glow
  static List<BoxShadow> moodGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.moodIndigo)
        : cardGlow(GameyColors.moodIndigo);
  }

  /// Achievement/reward glow
  static List<BoxShadow> achievementGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.goldReward)
        : cardGlow(GameyColors.goldReward);
  }

  /// Streak glow (fiery orange)
  static List<BoxShadow> streakGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.primaryOrange)
        : cardGlow(GameyColors.primaryOrange);
  }

  /// Level glow (purple)
  static List<BoxShadow> levelGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.primaryPurple)
        : cardGlow(GameyColors.primaryPurple);
  }

  /// Success glow (green)
  static List<BoxShadow> successGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.primaryGreen)
        : cardGlow(GameyColors.primaryGreen);
  }

  /// Warning/error glow (red)
  static List<BoxShadow> warningGlow({bool highlighted = false}) {
    return highlighted
        ? cardGlowHighlighted(GameyColors.primaryRed)
        : cardGlow(GameyColors.primaryRed);
  }

  // ============================================================================
  // NEON GLOWS (for celebrations)
  // ============================================================================

  /// Creates a neon glow effect (for special moments)
  static List<BoxShadow> neonGlow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.2),
        blurRadius: 12,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // ============================================================================
  // PULSE GLOW (for animations)
  // ============================================================================

  /// Creates glow parameters for pulse animation
  /// Use with AnimatedContainer or TweenAnimationBuilder
  static List<BoxShadow> pulseGlow(
    Color color, {
    required double pulseValue, // 0.0 to 1.0
  }) {
    final opacity = 0.06 + (pulseValue * 0.08);
    final blur = 6 + (pulseValue * 4);

    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        offset: const Offset(0, 2),
      ),
    ];
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get glow for a feature type
  static List<BoxShadow> forFeature(String feature, {bool highlighted = false}) {
    switch (feature.toLowerCase()) {
      case 'journal':
      case 'entry':
      case 'text':
        return journalGlow(highlighted: highlighted);
      case 'habit':
      case 'habits':
        return habitGlow(highlighted: highlighted);
      case 'task':
      case 'tasks':
        return taskGlow(highlighted: highlighted);
      case 'mood':
      case 'moods':
        return moodGlow(highlighted: highlighted);
      case 'achievement':
      case 'reward':
        return achievementGlow(highlighted: highlighted);
      case 'streak':
        return streakGlow(highlighted: highlighted);
      case 'level':
        return levelGlow(highlighted: highlighted);
      default:
        return successGlow(highlighted: highlighted);
    }
  }

  /// No shadow (for disabled/inactive states)
  static const List<BoxShadow> none = [];
}
