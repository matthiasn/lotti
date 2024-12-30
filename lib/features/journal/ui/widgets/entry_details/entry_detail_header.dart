import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_prompt_icon_widget.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/delete_icon_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/share_button_widget.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tag_add.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/speech_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class EntryDetailHeader extends ConsumerStatefulWidget {
  const EntryDetailHeader({
    required this.entryId,
    this.inLinkedEntries = false,
    super.key,
    this.linkedFromId,
  });

  final bool inLinkedEntries;
  final String entryId;
  final String? linkedFromId;

  @override
  ConsumerState<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends ConsumerState<EntryDetailHeader> {
  bool showAllIcons = false;

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;
    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final id = entryState.entryId;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (entry is! JournalEvent)
                  SwitchIconWidget(
                    tooltip: context.messages.journalFavoriteTooltip,
                    onPressed: notifier.toggleStarred,
                    value: entry?.meta.starred ?? false,
                    icon: Icons.star_outline_rounded,
                    activeIcon: Icons.star_rounded,
                    activeColor: starredGold,
                  ),
                SwitchIconWidget(
                  tooltip: context.messages.journalFlaggedTooltip,
                  onPressed: notifier.toggleFlagged,
                  value: entry?.meta.flag == EntryFlag.import,
                  icon: Icons.flag_outlined,
                  activeIcon: Icons.flag,
                  activeColor: context.colorScheme.error,
                ),
                if (isDesktop)
                  AiPopUpMenu(
                    journalEntity: entry,
                    linkedFromId: widget.linkedFromId,
                  ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => ExtendedHeaderActions.show(
                    context: context,
                    entryId: id,
                    inLinkedEntries: widget.inLinkedEntries,
                    linkedFromId: widget.linkedFromId,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.inLinkedEntries) SaveButton(entryId: widget.entryId),
      ],
    );
  }
}

class SwitchIconWidget extends StatelessWidget {
  const SwitchIconWidget({
    required this.tooltip,
    required this.onPressed,
    required this.value,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    super.key,
  });

  final String tooltip;
  final void Function() onPressed;
  final bool value;

  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: IconButton(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        padding: EdgeInsets.zero,
        splashRadius: 1,
        tooltip: tooltip,
        onPressed: () {
          if (value) {
            HapticFeedback.lightImpact();
          } else {
            HapticFeedback.heavyImpact();
          }
          onPressed();
        },
        icon: value
            ? Icon(
                activeIcon,
                color: activeColor,
              )
            : Icon(icon),
      ),
    );
  }
}

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

class ExtendedHeaderActions {
  static Future<void> show({
    required BuildContext context,
    required String entryId,
    required String? linkedFromId,
    required bool inLinkedEntries,
  }) async {
    final linkService = getIt<LinkService>();

    await ModalUtils.showSinglePageModal(
      context: context,
      title: context.messages.entryActions,
      builder: (context) => Column(
        children: [
          TogglePrivateListTile(entryId: entryId),
          ToggleMapListTile(entryId: entryId),
          DeleteIconListTile(
            entryId: entryId,
            beamBack: !inLinkedEntries,
          ),
          SpeechModalListTile(entryId: entryId),
          ShareButtonListTile(entryId: entryId),
          TagAddListTile(entryId: entryId),
          ListTile(
            leading: const Icon(Icons.add_link),
            title: Text(context.messages.journalLinkFromHint),
            onTap: () {
              linkService.linkFrom(entryId);
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: Icon(MdiIcons.target),
            title: Text(context.messages.journalLinkToHint),
            onTap: () {
              linkService.linkTo(entryId);
              Navigator.of(context).pop();
            },
          ),
          if (linkedFromId != null)
            UnlinkListTile(
              entryId: entryId,
              linkedFromId: linkedFromId,
            ),
        ],
      ),
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
