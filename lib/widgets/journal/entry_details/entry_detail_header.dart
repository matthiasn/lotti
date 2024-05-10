import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/ai_prompt_icon_widget.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:lotti/widgets/journal/entry_details/save_button.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:lotti/widgets/journal/tags/tag_add.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class EntryDetailHeader extends ConsumerStatefulWidget {
  const EntryDetailHeader({
    required this.entryId,
    this.inLinkedEntries = false,
    super.key,
    this.unlinkFn,
    this.linkedFromId,
  });

  final bool inLinkedEntries;
  final Future<void> Function()? unlinkFn;
  final String entryId;
  final String? linkedFromId;

  @override
  ConsumerState<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends ConsumerState<EntryDetailHeader> {
  bool showAllIcons = false;

  @override
  Widget build(BuildContext context) {
    final linkService = getIt<LinkService>();
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
                  activeColor: Theme.of(context).colorScheme.error,
                ),
                if (!showAllIcons)
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: context.messages.journalHeaderExpand,
                      onPressed: () => setState(() => showAllIcons = true),
                    ),
                  )
                else ...[
                  SwitchIconWidget(
                    tooltip: context.messages.journalPrivateTooltip,
                    onPressed: notifier.togglePrivate,
                    value: entry?.meta.private ?? false,
                    icon: Icons.shield_outlined,
                    activeIcon: Icons.shield,
                    activeColor: Theme.of(context).colorScheme.error,
                  ),
                  if (entry?.geolocation != null)
                    SwitchIconWidget(
                      tooltip: entryState.showMap
                          ? context.messages.journalHideMapHint
                          : context.messages.journalShowMapHint,
                      onPressed: notifier.toggleMapVisible,
                      value: entryState.showMap,
                      icon: Icons.map_outlined,
                      activeIcon: Icons.map,
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  DeleteIconWidget(
                    entryId: id,
                    beamBack: !widget.inLinkedEntries,
                  ),
                  const ShareButtonWidget(),
                  TagAddIconWidget(),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(Icons.add_link),
                      tooltip: context.messages.journalLinkFromHint,
                      onPressed: () => linkService.linkFrom(id),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: Icon(MdiIcons.target),
                      tooltip: context.messages.journalLinkToHint,
                      onPressed: () => linkService.linkTo(id),
                    ),
                  ),
                  if (widget.unlinkFn != null)
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(MdiIcons.linkOff),
                        tooltip: context.messages.journalUnlinkHint,
                        onPressed: widget.unlinkFn,
                      ),
                    ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(Icons.more_outlined),
                      tooltip: context.messages.journalHeaderContract,
                      onPressed: () => setState(() => showAllIcons = false),
                    ),
                  ),
                  if (isDesktop)
                    SizedBox(
                      width: 40,
                      child: AiPromptIconWidget(
                        journalEntity: entry,
                        linkedFromId: widget.linkedFromId,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SaveButton(),
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
