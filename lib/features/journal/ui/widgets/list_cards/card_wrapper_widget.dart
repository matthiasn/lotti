import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/animated_task_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/widgets/gamey/gamey_journal_card.dart';

class CardWrapperWidget extends ConsumerWidget {
  const CardWrapperWidget({
    required this.item,
    this.showCreationDate = false,
    this.showDueDate = true,
    this.showCoverArt = true,
    super.key,
  });

  final JournalEntity item;
  final bool showCreationDate;
  final bool showDueDate;
  final bool showCoverArt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if gamey theme is selected for current brightness
    final themingState = ref.watch(themingControllerProvider);
    final brightness = Theme.of(context).brightness;
    final useGamey = themingState.isGameyThemeForBrightness(brightness);

    // RepaintBoundary isolates repaints to individual cards,
    // preventing cascading rebuilds during scroll
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: item.maybeMap(
          journalImage: (JournalImage image) =>
              ModernJournalImageCard(item: image),
          task: (Task task) {
            return AnimatedModernTaskCard(
              task: task,
              showCreationDate: showCreationDate,
              showDueDate: showDueDate,
              showCoverArt: showCoverArt,
            );
          },
          orElse: () => useGamey
              ? GameyJournalCard(item: item)
              : ModernJournalCard(item: item),
        ),
      ),
    );
  }
}
