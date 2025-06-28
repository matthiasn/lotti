import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_image_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_task_card.dart';

class CardWrapperWidget extends StatelessWidget {
  const CardWrapperWidget({
    required this.item,
    required this.taskAsListView,
    super.key,
  });

  final JournalEntity item;
  final bool taskAsListView;

  @override
  Widget build(BuildContext context) {
    return item.maybeMap(
      journalImage: (JournalImage image) => JournalImageCard(item: image),
      task: (Task task) {
        if (taskAsListView) {
          return ModernTaskCard(task: task);
        } else {
          return JournalCard(item: task);
        }
      },
      orElse: () => JournalCard(item: item),
    );
  }
}
