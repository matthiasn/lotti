import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

class SwitchListTile extends StatelessWidget {
  const SwitchListTile({
    required this.title,
    required this.onPressed,
    required this.value,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    super.key,
  });

  final String title;
  final void Function() onPressed;
  final bool value;

  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: value
          ? Icon(
              activeIcon,
              color: activeColor,
            )
          : Icon(icon),
      title: Text(title),
      onTap: onPressed,
    );
  }
}

class TogglePrivateListTile extends ConsumerWidget {
  const TogglePrivateListTile({
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

    return SwitchListTile(
      title: context.messages.journalPrivateTitle,
      onPressed: notifier.togglePrivate,
      value: entry?.meta.private ?? false,
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield,
      activeColor: context.colorScheme.error,
    );
  }
}

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

    return SwitchListTile(
      title: entryState.showMap
          ? context.messages.journalHideMapHint
          : context.messages.journalShowMapHint,
      onPressed: notifier.toggleMapVisible,
      value: entryState.showMap,
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      activeColor: Theme.of(context).primaryColor,
    );
  }
}
