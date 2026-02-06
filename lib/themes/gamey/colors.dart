import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';

/// Vibrant, gamified color palette inspired by MalSehen's playful design.
/// These colors are designed to make the app feel fun, rewarding, and engaging.
class GameyColors {
  GameyColors._();

  // ============================================================================
  // UNIFIED GAMEY ACCENT
  // ============================================================================

  /// The unified accent color used for ALL gamey cards throughout the app.
  /// This provides a consistent, bubbly look across tasks, journal, and settings.
  static const Color gameyAccent = Color(0xFF1CB0F6);
  static const Color gameyAccentLight = Color(0xFF49C0F8);
  static const Color gameyAccentDark = Color(0xFF0A8FCC);

  // ============================================================================
  // PRIMARY ACTION COLORS
  // ============================================================================

  /// Success green - used for completions, achievements, positive actions
  static const Color primaryGreen = Color(0xFF58CC02);
  static const Color primaryGreenLight = Color(0xFF7ED321);

  /// Info blue - used for secondary actions, information, navigation
  static const Color primaryBlue = Color(0xFF1CB0F6);
  static const Color primaryBlueLight = Color(0xFF49C0F8);

  /// Level purple - used for levels, progression, premium features
  static const Color primaryPurple = Color(0xFF6B4CE5);
  static const Color primaryPurpleLight = Color(0xFF8B6EF0);

  /// Streak orange - used for streaks, motivation, fire energy
  static const Color primaryOrange = Color(0xFFFF9600);
  static const Color primaryOrangeLight = Color(0xFFFFAB33);

  /// Warning red - used for warnings, hearts/lives, destructive actions
  static const Color primaryRed = Color(0xFFFF4B4B);
  static const Color primaryRedLight = Color(0xFFFF6B6B);

  // ============================================================================
  // FEATURE-SPECIFIC COLORS
  // ============================================================================

  /// Journal entries - calming teal
  static const Color journalTeal = Color(0xFF00D9C0);
  static const Color journalTealLight = Color(0xFF33E3CE);
  static const Color journalTealDark = Color(0xFF00B4A0);

  /// Habits - energetic pink
  static const Color habitPink = Color(0xFFFF6B9D);
  static const Color habitPinkLight = Color(0xFFFF8FB5);
  static const Color habitPinkDark = Color(0xFFFF4777);

  /// Tasks - productive yellow
  static const Color taskYellow = Color(0xFFFFD93D);
  static const Color taskYellowLight = Color(0xFFFFE266);
  static const Color taskYellowDark = Color(0xFFFFBE0B);

  /// Moods - introspective indigo
  static const Color moodIndigo = Color(0xFF5C6BC0);
  static const Color moodIndigoLight = Color(0xFF7986CB);
  static const Color moodIndigoDark = Color(0xFF3F51B5);

  /// Health/Measurements - vital green
  static const Color healthGreen = Color(0xFF4CAF50);
  static const Color healthGreenLight = Color(0xFF66BB6A);
  static const Color healthGreenDark = Color(0xFF388E3C);

  /// AI/Speech - futuristic cyan
  static const Color aiCyan = Color(0xFF00BCD4);
  static const Color aiCyanLight = Color(0xFF26C6DA);
  static const Color aiCyanDark = Color(0xFF0097A7);

  // ============================================================================
  // REWARD & ACHIEVEMENT COLORS
  // ============================================================================

  /// Gold for rewards, achievements, premium
  static const Color goldReward = Color(0xFFD4AF37);
  static const Color goldRewardLight = Color(0xFFE6C65C);
  static const Color goldRewardDark = Color(0xFFB8860B);

  /// Silver for secondary achievements
  static const Color silverReward = Color(0xFFC0C0C0);
  static const Color silverRewardLight = Color(0xFFD3D3D3);

  /// Bronze for tertiary achievements
  static const Color bronzeReward = Color(0xFFCD7F32);
  static const Color bronzeRewardLight = Color(0xFFD4956A);

  // ============================================================================
  // NEON ACCENTS (for special moments/celebrations)
  // ============================================================================

  static const Color neonCyan = Color(0xFF00D9FF);
  static const Color neonGreen = Color(0xFF00FF94);
  static const Color neonPurple = Color(0xFFB24BF3);
  static const Color neonPink = Color(0xFFFF006E);
  static const Color neonYellow = Color(0xFFFFE500);

  // ============================================================================
  // SURFACE COLORS (for cards and backgrounds)
  // ============================================================================

  /// Light mode surfaces
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightElevated = Color(0xFFFAFAFA);

  /// Dark mode surfaces with depth
  static const Color surfaceDark = Color(0xFF1E1E2E);
  static const Color surfaceDarkElevated = Color(0xFF2A2A3C);
  static const Color surfaceDarkLow = Color(0xFF181825);

  // ============================================================================
  // CONFETTI COLORS
  // ============================================================================

  static const List<Color> confettiColors = [
    primaryGreen,
    primaryBlue,
    primaryPurple,
    primaryOrange,
    neonPink,
    neonCyan,
    goldReward,
    Color(0xFFFFFFFF),
  ];

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get feature color based on entry type or feature name
  static Color featureColor(String feature) {
    switch (feature.toLowerCase()) {
      case 'journal':
      case 'entry':
      case 'text':
        return journalTeal;
      case 'habit':
      case 'habits':
        return habitPink;
      case 'task':
      case 'tasks':
        return taskYellow;
      case 'mood':
      case 'moods':
        return moodIndigo;
      case 'health':
      case 'measurement':
        return healthGreen;
      case 'ai':
      case 'speech':
      case 'transcription':
        return aiCyan;
      case 'achievement':
      case 'reward':
        return goldReward;
      default:
        return primaryBlue;
    }
  }

  // ==========================================================================
  // GAMEY PRIORITY COLORS (purple/violet spectrum)
  // These are intentionally distinct from the shared priority constants in
  // colors.dart — the gamey theme uses more saturated, vibrant shades.
  // ==========================================================================

  static const Color priorityUrgent = Color(0xFFAB47BC); // vivid purple
  static const Color priorityHigh = Color(0xFF7E57C2); // deep purple
  static const Color priorityMedium = Color(0xFF7986CB); // indigo
  static const Color priorityLow = Color(0xFF90A4AE); // blue-grey

  /// Get priority color for tasks.
  /// Uses purple/violet spectrum to be visually distinct from status colors.
  static Color priorityColor(TaskPriority priority) => switch (priority) {
        TaskPriority.p0Urgent => priorityUrgent,
        TaskPriority.p1High => priorityHigh,
        TaskPriority.p2Medium => priorityMedium,
        TaskPriority.p3Low => priorityLow,
      };
}
