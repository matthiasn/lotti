/// Gamey Widgets Library
///
/// A collection of vibrant, gamified widgets for Lotti.
///
/// Usage:
/// ```dart
/// import 'package:lotti/widgets/gamey/gamey_widgets.dart';
///
/// // Cards
/// GameyCard(child: ...)
/// GameyFeatureCard(feature: 'journal', child: ...)
/// GameyJournalCard(item: journalEntity)
/// GameySettingsCard(title: 'Settings', icon: Icons.settings)
///
/// // Icons
/// GameyIconBadge(icon: Icons.book)
/// GameyFeatureIconBadge(feature: 'habit', icon: Icons.check)
///
/// // Progress
/// GameyProgressBar(progress: 0.75)
/// GameyCircularProgress(progress: 0.5)
///
/// // Badges
/// GameyStreakBadge(streakCount: 7)
/// GameyLevelBadge(level: 5)
///
/// // Effects
/// ShimmerEffect(child: ...)
/// PulseEffect(child: ...)
/// CelebrationOverlay.show(context, title: 'Achievement!')
/// ```
library;

export 'celebration_overlay.dart';
export 'gamey_card.dart';
export 'gamey_fab.dart';
export 'gamey_icon_badge.dart';
export 'gamey_journal_card.dart';
export 'gamey_progress_bar.dart';
export 'gamey_settings_card.dart';
export 'gamey_streak_badge.dart';
export 'gamey_task_card.dart';
export 'shimmer_effect.dart';
