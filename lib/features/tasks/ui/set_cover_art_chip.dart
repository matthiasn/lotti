import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

/// Chip shown in image entry header when the image is linked from a task.
/// Allows setting/unsetting the image as the task's cover art.
class SetCoverArtChip extends ConsumerWidget {
  const SetCoverArtChip({
    required this.imageId,
    required this.linkedFromId,
    super.key,
  });

  final String imageId;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show when linked from something
    if (linkedFromId == null) return const SizedBox.shrink();

    // Check if the parent is a task
    final parentProvider = entryControllerProvider(id: linkedFromId!);
    final parentEntry = ref.watch(parentProvider).value?.entry;

    if (parentEntry is! Task) return const SizedBox.shrink();

    final isCurrentCover = parentEntry.data.coverArtId == imageId;

    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(parentProvider.notifier);
        await notifier.setCoverArt(isCurrentCover ? null : imageId);
      },
      child: SubtleActionChip(
        label: isCurrentCover
            ? context.messages.coverArtChipActive
            : context.messages.coverArtChipSet,
        icon: isCurrentCover ? Icons.image : Icons.image_outlined,
        isUrgent: isCurrentCover,
        urgentColor: starredGold,
      ),
    );
  }
}
