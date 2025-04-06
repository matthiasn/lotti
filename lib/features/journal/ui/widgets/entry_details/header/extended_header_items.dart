import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_list_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class UnlinkListTile extends ConsumerWidget {
  const UnlinkListTile({
    required this.entryId,
    required this.linkedFromId,
    super.key,
  });

  final String entryId;
  final String linkedFromId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> unlink() async {
      final notifier =
          ref.read(linkedEntriesControllerProvider(id: linkedFromId).notifier);

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
            isDefaultAction: true,
          ),
        ],
      );

      if (result == unlinkKey) {
        await notifier.removeLink(toId: entryId);
      }
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return ListTile(
      leading: const Icon(Icons.link_off_outlined),
      title: Text(context.messages.journalUnlinkHint),
      onTap: unlink,
    );
  }
}

class ToggleMapListTile extends ConsumerWidget {
  const ToggleMapListTile({
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

    if (entry?.geolocation == null) {
      return const SizedBox.shrink();
    }

    return MenuSwitchListTile(
      title: entryState.showMap
          ? context.messages.journalHideMapHint
          : context.messages.journalShowMapHint,
      onChanged: notifier.setMapVisible,
      value: entryState.showMap,
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      activeColor: Theme.of(context).primaryColor,
    );
  }
}

class ToggleHiddenListTile extends ConsumerWidget {
  const ToggleHiddenListTile({
    required this.entryId,
    required this.link,
    super.key,
  });

  final String entryId;
  final EntryLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = linkedEntriesControllerProvider(id: link.fromId);
    final notifier = ref.read(provider.notifier);
    final isHidden = link.hidden ?? false;

    // ignore: avoid_positional_boolean_parameters
    void updateLink(bool hidden) {
      final hidden = link.hidden ?? false;
      final updatedLink = link.copyWith(hidden: !hidden);
      notifier.updateLink(updatedLink);
      Navigator.of(context).pop();
    }

    return MenuSwitchListTile(
      // TODO: l10n
      title: 'Hidden',
      onChanged: updateLink,
      value: isHidden,
      icon: MdiIcons.archive,
      activeIcon: MdiIcons.archiveCancel,
      activeColor: Theme.of(context).primaryColor,
    );
  }
}

class CopyImageListTile extends ConsumerWidget {
  const CopyImageListTile({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null || entryState.entry is! JournalImage) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.copy),
      title: Text(context.messages.journalCopyImageLabel),
      onTap: () async {
        await notifier.copyImage();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
