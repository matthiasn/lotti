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
    this.vectorDistance,
    super.key,
  });

  final JournalEntity item;
  final bool showCreationDate;
  final bool showDueDate;
  final bool showCoverArt;

  /// Cosine distance from vector search, if applicable.
  final double? vectorDistance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if gamey theme is selected for current brightness
    final themingState = ref.watch(themingControllerProvider);
    final brightness = Theme.of(context).brightness;
    final useGamey = themingState.isGameyThemeForBrightness(brightness);

    // RepaintBoundary isolates repaints to individual cards,
    // preventing cascading rebuilds during scroll
    final card = item.maybeMap(
      journalImage: (JournalImage image) => ModernJournalImageCard(item: image),
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
    );

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: vectorDistance != null
            ? Stack(
                children: [
                  card,
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _DistanceBadge(distance: vectorDistance!),
                  ),
                ],
              )
            : card,
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distance});

  final double distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _colorForDistance(distance),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        distance.toStringAsFixed(2),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Color _colorForDistance(double d) {
    if (d < 0.3) return Colors.green;
    if (d < 0.6) return Colors.orange.shade700;
    if (d < 0.8) return Colors.deepOrange;
    return Colors.red;
  }
}
