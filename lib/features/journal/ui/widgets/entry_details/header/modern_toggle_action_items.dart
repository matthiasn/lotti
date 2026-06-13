import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/action_menu_list_item.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

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

    return ActionMenuListItem(
      icon: starred ? Icons.star_rounded : Icons.star_outline_rounded,
      title: context.messages.journalToggleStarredTitle,
      iconColor: starred ? starredGold : null,
      onTap: () {
        notifier.toggleStarred();
        Navigator.of(context).pop();
      },
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

    return ActionMenuListItem(
      icon: private ? Icons.lock_rounded : Icons.lock_open_rounded,
      title: context.messages.journalTogglePrivateTitle,
      iconColor: private ? const Color(0xFFE57373) : null,
      onTap: () {
        notifier.togglePrivate();
        Navigator.of(context).pop();
      },
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

    return ActionMenuListItem(
      icon: flagged ? Icons.flag_rounded : Icons.flag_outlined,
      title: context.messages.journalToggleFlaggedTitle,
      iconColor: flagged ? const Color(0xFFBA68C8) : null,
      onTap: () {
        notifier.toggleFlagged();
        Navigator.of(context).pop();
      },
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

    return ActionMenuListItem(
      icon: showMap ? Icons.map_rounded : Icons.map_outlined,
      title: showMap
          ? context.messages.journalHideMapHint
          : context.messages.journalShowMapHint,
      onTap: () {
        notifier.toggleMapVisible();
        Navigator.of(context).pop();
      },
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

    return ActionMenuListItem(
      icon: Icons.delete_outline_rounded,
      title: context.messages.journalDeleteHint,
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
