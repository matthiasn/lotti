import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/animated_modern_task_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_journal_image_card.dart';

class CardWrapperWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
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
        orElse: () => ModernJournalCard(item: item),
      ),
    );
  }
}
