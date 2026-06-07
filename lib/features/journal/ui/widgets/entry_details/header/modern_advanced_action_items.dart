part of 'modern_action_items.dart';

/// Modern styled generate cover art action item.
/// Shows only for audio entries that are linked to a task.
class ModernGenerateCoverArtItem extends ConsumerWidget {
  const ModernGenerateCoverArtItem({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String? linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    // Only show for audio entries
    if (entry == null || entry is! JournalAudio) {
      return const SizedBox.shrink();
    }

    // Only show when linked to a task
    final linkedTaskId = linkedFromId;
    if (linkedTaskId == null) {
      return const SizedBox.shrink();
    }

    // Check if the linked entity is actually a task
    final linkedProvider = entryControllerProvider(id: linkedTaskId);
    final linkedState = ref.watch(linkedProvider).value;
    final linkedEntry = linkedState?.entry;

    if (linkedEntry == null || linkedEntry is! Task) {
      return const SizedBox.shrink();
    }

    return ActionMenuListItem(
      icon: Icons.auto_awesome_outlined,
      title: context.messages.generateCoverArt,
      subtitle: context.messages.generateCoverArtSubtitle,
      onTap: () async {
        Navigator.of(context).pop();
        if (!context.mounted) return;

        await _openImageGenerationModal(
          context: context,
          linkedTaskId: linkedTaskId,
          linkedTask: linkedEntry,
          ref: ref,
        );
      },
    );
  }

  Future<void> _openImageGenerationModal({
    required BuildContext context,
    required String linkedTaskId,
    required Task linkedTask,
    required WidgetRef ref,
  }) async {
    await CoverArtSkillModal.show(
      context: context,
      entityId: entryId,
      skillId: skillImageGenId,
      linkedTaskId: linkedTaskId,
      ref: ref,
    );
  }
}

/// Modern styled set cover art action item.
/// Shows only for image entries that are linked to a task.
class ModernSetCoverArtItem extends ConsumerWidget {
  const ModernSetCoverArtItem({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentProvider = entryControllerProvider(id: linkedFromId);
    final parentEntry = ref.watch(parentProvider).value?.entry;

    if (parentEntry is! Task) return const SizedBox.shrink();

    final isCurrentCover = parentEntry.data.coverArtId == entryId;

    return ActionMenuListItem(
      icon: isCurrentCover ? Icons.image : Icons.image_outlined,
      title: isCurrentCover
          ? context.messages.coverArtChipActive
          : context.messages.coverArtChipSet,
      iconColor: isCurrentCover ? starredGold : null,
      onTap: () async {
        final notifier = ref.read(parentProvider.notifier);
        await notifier.setCoverArt(isCurrentCover ? null : entryId);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Modern styled link from action item
class ModernLinkFromItem extends StatelessWidget {
  const ModernLinkFromItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context) {
    return ActionMenuListItem(
      icon: Icons.add_link,
      title: context.messages.journalLinkFromHint,
      onTap: () {
        getIt<LinkService>().linkFrom(entryId);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern styled link to action item
class ModernLinkToItem extends StatelessWidget {
  const ModernLinkToItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context) {
    return ActionMenuListItem(
      icon: MdiIcons.target,
      title: context.messages.journalLinkToHint,
      onTap: () {
        getIt<LinkService>().linkTo(entryId);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern styled rate session action item.
/// Shows "Rate Session" or "View Rating" depending on whether
/// a rating already exists for this time entry.
class ModernRateSessionItem extends ConsumerWidget {
  const ModernRateSessionItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableRatingsAsync = ref.watch(
      configFlagProvider(enableSessionRatingsFlag),
    );
    final enableRatings =
        enableRatingsAsync.unwrapPrevious().whenData((value) => value).value ??
        false;

    if (!enableRatings) {
      return const SizedBox.shrink();
    }

    final rating = ref.watch(ratingControllerProvider(targetId: entryId)).value;
    final hasRating = rating != null;

    return ActionMenuListItem(
      icon: hasRating ? Icons.star_rate_rounded : Icons.star_rate_outlined,
      title: hasRating
          ? context.messages.sessionRatingViewAction
          : context.messages.sessionRatingRateAction,
      iconColor: hasRating ? starredGold : null,
      onTap: () {
        Navigator.of(context).pop();
        RatingModal.show(context, entryId);
      },
    );
  }
}
