import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Modern styled toggle starred action item
class ModernToggleStarredItem extends ConsumerWidget {
  const ModernToggleStarredItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final starred = entry?.meta.starred ?? false;

    return ModernModalActionItem(
      icon: starred ? Icons.star_rounded : Icons.star_outline_rounded,
      title: context.messages.journalToggleStarredTitle,
      iconColor: starred ? starredGold : null,
      onTap: notifier.toggleStarred,
    );
  }
}

/// Modern styled toggle private action item
class ModernTogglePrivateItem extends ConsumerWidget {
  const ModernTogglePrivateItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final private = entry?.meta.private ?? false;

    return ModernModalActionItem(
      icon: private ? Icons.lock_rounded : Icons.lock_open_rounded,
      title: context.messages.journalTogglePrivateTitle,
      iconColor: private ? const Color(0xFFE57373) : null,
      onTap: notifier.togglePrivate,
    );
  }
}

/// Modern styled toggle flagged action item
class ModernToggleFlaggedItem extends ConsumerWidget {
  const ModernToggleFlaggedItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final flagged = entry?.meta.flag != null;

    return ModernModalActionItem(
      icon: flagged ? Icons.flag_rounded : Icons.flag_outlined,
      title: context.messages.journalToggleFlaggedTitle,
      iconColor: flagged ? const Color(0xFFBA68C8) : null,
      onTap: notifier.toggleFlagged,
    );
  }
}

/// Modern styled toggle map action item
class ModernToggleMapItem extends ConsumerWidget {
  const ModernToggleMapItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final entry = entryState?.entry;
    final geolocation = entry?.geolocation;

    if (entryState == null || geolocation == null || entry is Task) {
      return const SizedBox.shrink();
    }

    final showMap = entryState.showMap;

    return ModernModalActionItem(
      icon: showMap ? Icons.map_rounded : Icons.map_outlined,
      title: showMap
          ? context.messages.journalHideMapHint
          : context.messages.journalShowMapHint,
      onTap: notifier.toggleMapVisible,
    );
  }
}

/// Modern styled delete action item
class ModernDeleteItem extends ConsumerWidget {
  const ModernDeleteItem({
    required this.entryId,
    required this.beamBack,
    super.key,
  });

  final String entryId;
  final bool beamBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);

    Future<void> onPressed() async {
      const deleteKey = 'deleteKey';
      final result = await showModalActionSheet<String>(
        context: context,
        title: context.messages.journalDeleteQuestion,
        actions: [
          ModalSheetAction(
            icon: Icons.warning_rounded,
            label: context.messages.journalDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
          ),
        ],
      );

      if (result == deleteKey) {
        await ref.read(provider.notifier).delete(beamBack: beamBack);
      }
    }

    return ModernModalActionItem(
      icon: Icons.delete_outline_rounded,
      title: 'Delete entry',
      isDestructive: true,
      onTap: () async {
        await onPressed();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Modern styled speech recognition action item
class ModernSpeechItem extends ConsumerWidget {
  const ModernSpeechItem({
    required this.entryId,
    required this.pageIndexNotifier,
    super.key,
  });

  final String entryId;
  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    final item = entryState?.entry;
    if (item == null || item is! JournalAudio) {
      return const SizedBox.shrink();
    }

    return ModernModalActionItem(
      icon: Icons.transcribe_rounded,
      title: context.messages.speechModalTitle,
      onTap: () => pageIndexNotifier.value = 2,
    );
  }
}

/// Modern styled share action item
class ModernShareItem extends ConsumerWidget {
  const ModernShareItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entryState == null ||
        entry is! JournalImage && entry is! JournalAudio) {
      return const SizedBox.shrink();
    }

    return ModernModalActionItem(
      icon: Icons.share_rounded,
      title: 'Share',
      onTap: () async {
        Navigator.of(context).pop();

        if (isLinux || isWindows) {
          return;
        }

        if (entry is JournalImage) {
          final filePath = getFullImagePath(entry);
          await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
        }
        if (entry is JournalAudio) {
          final filePath = await AudioUtils.getFullAudioPath(entry);
          await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
        }
      },
    );
  }
}

/// Modern styled tag add action item
class ModernTagAddItem extends StatelessWidget {
  const ModernTagAddItem({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context) {
    return ModernModalActionItem(
      icon: Icons.label_outline_rounded,
      title: context.messages.journalTagPlusHint,
      onTap: () => pageIndexNotifier.value = 1,
    );
  }
}

/// Modern styled unlink action item
class ModernUnlinkItem extends ConsumerWidget {
  const ModernUnlinkItem({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ModernModalActionItem(
      icon: Icons.link_off_rounded,
      title: 'Unlink',
      onTap: () async {
        const unlinkKey = 'unlinkKey';
        final result = await showModalActionSheet<String>(
          context: context,
          title: context.messages.journalUnlinkQuestion,
          actions: [
            ModalSheetAction(
              icon: Icons.warning,
              label: context.messages.journalUnlinkConfirm,
              key: unlinkKey,
              isDestructiveAction: true,
            ),
          ],
        );

        if (result == unlinkKey) {
          final notifier = ref.read(
            linkedEntriesControllerProvider(id: linkedFromId).notifier,
          );
          await notifier.removeLink(toId: entryId);
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Modern styled toggle hidden action item
class ModernToggleHiddenItem extends ConsumerWidget {
  const ModernToggleHiddenItem({
    required this.link,
    super.key,
  });

  final EntryLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = link.hidden ?? false;
    final provider = linkedEntriesControllerProvider(id: link.fromId);
    final notifier = ref.read(provider.notifier);

    return ModernModalActionItem(
      icon: hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      title: hidden ? 'Show link' : 'Hide link',
      onTap: () {
        final updatedLink = link.copyWith(hidden: !hidden);
        notifier.updateLink(updatedLink);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Modern styled copy image action item
class ModernCopyImageItem extends ConsumerWidget {
  const ModernCopyImageItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final notifier = ref.read(provider.notifier);

    final item = entryState?.entry;
    if (item == null || item is! JournalImage) {
      return const SizedBox.shrink();
    }

    return ModernModalActionItem(
      icon: MdiIcons.contentCopy,
      title: 'Copy image',
      onTap: () async {
        await notifier.copyImage();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Reusable copy entry text action item (plain or markdown)
class ModernCopyEntryTextItem extends ConsumerWidget {
  const ModernCopyEntryTextItem({
    required this.entryId,
    required this.markdown,
    super.key,
  });

  final String entryId;
  final bool markdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final hasText =
        notifier.controller.document.toPlainText().trim().isNotEmpty;
    final entry = entryState?.entry;
    if (!hasText || entry == null) {
      return const SizedBox.shrink();
    }

    final title = markdown
        ? context.messages.copyAsMarkdown
        : context.messages.copyAsText;
    final icon = markdown ? Icons.code : MdiIcons.contentCopy;

    return ModernModalActionItem(
      icon: icon,
      title: title,
      onTap: () async {
        if (markdown) {
          await notifier.copyEntryTextMarkdown();
        } else {
          await notifier.copyEntryTextPlain();
        }
        if (context.mounted) {
          await Navigator.of(context).maybePop();
        }
      },
    );
  }
}

/// Modern styled labels action item for non-task entries.
/// Opens a dedicated single-page modal for label selection.
class ModernLabelsItem extends ConsumerWidget {
  const ModernLabelsItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    // Only show for non-task entries (tasks have their own labels UI)
    if (entry == null || entry is Task) {
      return const SizedBox.shrink();
    }

    return ModernModalActionItem(
      icon: MdiIcons.labelOutline,
      title: context.messages.entryLabelsActionTitle,
      subtitle: context.messages.entryLabelsActionSubtitle,
      onTap: () async {
        // Close the multi-page modal first
        Navigator.of(context).pop();
        if (!context.mounted) return;
        // Open dedicated labels modal
        await _openLabelsModal(context, entry);
      },
    );
  }

  Future<void> _openLabelsModal(
    BuildContext context,
    JournalEntity entry,
  ) async {
    await LabelSelectionModalUtils.openLabelSelector(
      context: context,
      entryId: entryId,
      initialLabelIds: entry.meta.labelIds ?? <String>[],
      categoryId: entry.meta.categoryId,
    );
  }
}
