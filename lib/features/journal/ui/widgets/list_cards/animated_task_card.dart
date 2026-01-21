import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/task_card.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/gamey/gamey_task_card.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';

/// An animated version of ModernTaskCard that adds hover and tap animations
///
/// This wrapper applies AnimatedModalItem animations to ModernTaskCard.
/// Since ModernTaskCard has its own margins, this widget sets the margin on
/// AnimatedModalItem to `EdgeInsets.zero` to avoid duplicated spacing.
///
/// When gamey theme is selected, uses GameyTaskCard instead which has
/// its own built-in animations.
class AnimatedModernTaskCard extends ConsumerWidget {
  const AnimatedModernTaskCard({
    required this.task,
    this.showCreationDate = false,
    this.showDueDate = true,
    this.showCoverArt = true,
    super.key,
  });

  final Task task;
  final bool showCreationDate;
  final bool showDueDate;
  final bool showCoverArt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if gamey theme is selected (for either light or dark)
    final themingState = ref.watch(themingControllerProvider);
    final useGamey = themingState.isUsingGameyTheme;

    // Gamey cards have built-in animations, no need for wrapper
    if (useGamey) {
      return GameyTaskCard(
        task: task,
        showCreationDate: showCreationDate,
        showDueDate: showDueDate,
        showCoverArt: showCoverArt,
      );
    }

    // Since ModernTaskCard includes its own margins, set AnimatedModalItem's
    // margin to zero to avoid double spacing
    return AnimatedModalItem(
      onTap: () => beamToNamed('/tasks/${task.meta.id}'),
      hoverScale: 0.995, // Slightly less scale for list items
      tapScale: 0.985, // Subtle tap effect
      hoverElevation: 2, // Less elevation for list items
      margin: EdgeInsets.zero, // ModernTaskCard already has its own margins
      disableShadow: true, // ModernTaskCard already has its own shadow
      child: ModernTaskCard(
        task: task,
        showCreationDate: showCreationDate,
        showDueDate: showDueDate,
        showCoverArt: showCoverArt,
      ),
    );
  }
}
