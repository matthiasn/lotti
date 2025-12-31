import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

/// Chip shown in task header meta card when cover art is set.
/// Tapping removes the cover art from the task.
class RemoveCoverArtChip extends ConsumerWidget {
  const RemoveCoverArtChip({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final entry = ref.watch(provider).value?.entry;

    // Only show when task has cover art set
    if (entry is! Task || entry.data.coverArtId == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(provider.notifier);
        await notifier.setCoverArt(null);
      },
      child: SubtleActionChip(
        label: context.messages.coverArtChipActive,
        icon: Icons.image,
        isUrgent: true,
        urgentColor: starredGold,
      ),
    );
  }
}
