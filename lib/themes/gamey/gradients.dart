import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Feature-specific gradients for gamified visual design.
/// Each feature gets its own gradient identity for instant recognition.
class GameyGradients {
  GameyGradients._();

  // ============================================================================
  // UNIFIED GAMEY ACCENT GRADIENT
  // ============================================================================

  /// The unified gamey gradient used for all card icon badges throughout the app.
  /// Provides a consistent, bubbly look across tasks, journal, and settings.
  static const LinearGradient unified = LinearGradient(
    colors: [GameyColors.gameyAccent, GameyColors.gameyAccentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // FEATURE GRADIENTS
  // ============================================================================

  /// Journal entries - calming teal gradient
  static const LinearGradient journal = LinearGradient(
    colors: [GameyColors.journalTeal, GameyColors.journalTealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Habits - energetic pink gradient
  static const LinearGradient habit = LinearGradient(
    colors: [GameyColors.habitPink, GameyColors.habitPinkDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Tasks - productive yellow gradient
  static const LinearGradient task = LinearGradient(
    colors: [GameyColors.taskYellow, GameyColors.taskYellowDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Moods - introspective indigo gradient
  static const LinearGradient mood = LinearGradient(
    colors: [GameyColors.moodIndigo, GameyColors.moodIndigoDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Health/Measurements - vital green gradient
  static const LinearGradient health = LinearGradient(
    colors: [GameyColors.healthGreen, GameyColors.healthGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// AI/Speech - futuristic cyan gradient
  static const LinearGradient ai = LinearGradient(
    colors: [GameyColors.aiCyan, GameyColors.aiCyanDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Settings - sophisticated purple gradient
  static const LinearGradient settings = LinearGradient(
    colors: [GameyColors.primaryPurple, GameyColors.moodIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // ACTION GRADIENTS
  // ============================================================================

  /// Success/completion gradient
  static const LinearGradient success = LinearGradient(
    colors: [GameyColors.primaryGreen, GameyColors.primaryGreenLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// XP/Progress gradient (green to light green)
  static const LinearGradient xpProgress = LinearGradient(
    colors: [GameyColors.primaryGreen, Color(0xFF89E219)],
  );

  /// Level badge gradient (purple to blue)
  static const LinearGradient level = LinearGradient(
    colors: [GameyColors.primaryPurple, GameyColors.primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Streak badge gradient (orange to red - fire energy)
  static const LinearGradient streak = LinearGradient(
    colors: [GameyColors.primaryOrange, GameyColors.primaryRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warning/destructive gradient
  static const LinearGradient warning = LinearGradient(
    colors: [GameyColors.primaryRed, GameyColors.primaryRedLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // REWARD GRADIENTS
  // ============================================================================

  /// Gold reward gradient
  static const LinearGradient gold = LinearGradient(
    colors: [GameyColors.goldReward, GameyColors.goldRewardDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium gold gradient (more vibrant)
  static const LinearGradient goldPremium = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFDAA520)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Silver reward gradient
  static const LinearGradient silver = LinearGradient(
    colors: [GameyColors.silverRewardLight, GameyColors.silverReward],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Bronze reward gradient
  static const LinearGradient bronze = LinearGradient(
    colors: [GameyColors.bronzeRewardLight, GameyColors.bronzeReward],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // NEON GRADIENTS (for celebrations/special moments)
  // ============================================================================

  /// Neon celebration gradient
  static const LinearGradient neonCelebration = LinearGradient(
    colors: [
      GameyColors.neonCyan,
      GameyColors.neonPurple,
      GameyColors.neonPink,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Rainbow gradient for special achievements
  static const LinearGradient rainbow = LinearGradient(
    colors: [
      GameyColors.primaryRed,
      GameyColors.primaryOrange,
      GameyColors.taskYellow,
      GameyColors.primaryGreen,
      GameyColors.primaryBlue,
      GameyColors.primaryPurple,
    ],
  );

  // ============================================================================
  // BACKGROUND GRADIENTS
  // ============================================================================

  /// Light mode background gradient
  static const LinearGradient backgroundLight = LinearGradient(
    colors: [
      Colors.white,
      Color(0xFFFAFAFA), // Colors.grey.shade50 equivalent
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Dark mode background gradient (deep purple night)
  static const LinearGradient backgroundDark = LinearGradient(
    colors: [
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================================
  // CARD GRADIENTS
  // ============================================================================

  /// Vibrant card gradient for light mode
  /// Can accept an optional surface color, otherwise uses white
  static LinearGradient cardLight(Color accentColor, [Color? surfaceColor]) {
    final baseSurface = surfaceColor ?? Colors.white;
    return LinearGradient(
      colors: [
        Color.lerp(baseSurface, accentColor, 0.06) ?? baseSurface,
        Color.lerp(baseSurface, accentColor, 0.12) ?? baseSurface,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Subtle card gradient for dark mode
  /// Can accept an optional surface color, otherwise uses gamey dark surface
  static LinearGradient cardDark(Color accentColor, [Color? surfaceColor]) {
    final baseSurface = surfaceColor ?? GameyColors.surfaceDarkElevated;
    return LinearGradient(
      colors: [
        baseSurface,
        Color.lerp(baseSurface, accentColor, 0.08) ?? baseSurface,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Theme-aware card gradient that adapts to current theme
  static LinearGradient cardFromContext(
      BuildContext context, Color accentColor) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = colorScheme.surfaceContainer;
    return isDark
        ? cardDark(accentColor, surfaceColor)
        : cardLight(accentColor, surfaceColor);
  }

  // ============================================================================
  // SHIMMER GRADIENT (for loading/special effects)
  // ============================================================================

  /// Shimmer sweep gradient
  static const LinearGradient shimmer = LinearGradient(
    colors: [
      Colors.transparent,
      Color(0x33FFFFFF),
      Colors.transparent,
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.5, -0.5),
    end: Alignment(1.5, 0.5),
  );

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get gradient for a feature type
  static LinearGradient forFeature(String feature) {
    switch (feature.toLowerCase()) {
      case 'journal':
      case 'entry':
      case 'text':
        return journal;
      case 'habit':
      case 'habits':
        return habit;
      case 'task':
      case 'tasks':
        return task;
      case 'mood':
      case 'moods':
        return mood;
      case 'health':
      case 'measurement':
        return health;
      case 'ai':
      case 'speech':
      case 'transcription':
        return ai;
      case 'achievement':
      case 'reward':
        return gold;
      case 'streak':
        return streak;
      case 'level':
        return level;
      case 'settings':
      case 'config':
        return settings;
      default:
        return success;
    }
  }

  /// Create a custom gradient from two colors
  static LinearGradient custom(
    Color start,
    Color end, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry endAlign = Alignment.bottomRight,
  }) {
    return LinearGradient(
      colors: [start, end],
      begin: begin,
      end: endAlign,
    );
  }
}
