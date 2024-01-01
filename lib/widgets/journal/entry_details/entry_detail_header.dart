import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:lotti/widgets/journal/entry_details/save_button.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:lotti/widgets/journal/tags/tag_add.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class EntryDetailHeader extends StatefulWidget {
  const EntryDetailHeader({
    this.inLinkedEntries = false,
    super.key,
    this.unlinkFn,
  });

  final bool inLinkedEntries;
  final Future<void> Function()? unlinkFn;

  @override
  State<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends State<EntryDetailHeader> {
  bool showAllIcons = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final linkService = getIt<LinkService>();

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, EntryState state) {
        final cubit = context.read<EntryCubit>();
        final item = state.entry;

        if (item == null) {
          return const SizedBox.shrink();
        }

        final id = item.meta.id;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SwitchIconWidget(
                      tooltip: localizations.journalFavoriteTooltip,
                      onPressed: cubit.toggleStarred,
                      value: item.meta.starred ?? false,
                      icon: Icons.star_outline_rounded,
                      activeIcon: Icons.star_rounded,
                      activeColor: starredGold,
                    ),
                    SwitchIconWidget(
                      tooltip: localizations.journalFlaggedTooltip,
                      onPressed: cubit.toggleFlagged,
                      value: item.meta.flag == EntryFlag.import,
                      icon: Icons.flag_outlined,
                      activeIcon: Icons.flag,
                      activeColor: Theme.of(context).colorScheme.error,
                    ),
                    if (!showAllIcons)
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(Icons.more_horiz),
                          tooltip: localizations.journalLinkFromHint,
                          onPressed: () => setState(() => showAllIcons = true),
                        ),
                      )
                    else ...[
                      SwitchIconWidget(
                        tooltip: localizations.journalPrivateTooltip,
                        onPressed: cubit.togglePrivate,
                        value: item.meta.private ?? false,
                        icon: Icons.shield_outlined,
                        activeIcon: Icons.shield,
                        activeColor: Theme.of(context).colorScheme.error,
                      ),
                      if (state.entry?.geolocation != null)
                        SwitchIconWidget(
                          tooltip: state.showMap
                              ? localizations.journalHideMapHint
                              : localizations.journalShowMapHint,
                          onPressed: cubit.toggleMapVisible,
                          value: cubit.showMap,
                          icon: Icons.map_outlined,
                          activeIcon: Icons.map,
                          activeColor: Theme.of(context).primaryColor,
                        ),
                      DeleteIconWidget(beamBack: !widget.inLinkedEntries),
                      const ShareButtonWidget(),
                      TagAddIconWidget(),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(Icons.add_link),
                          tooltip: localizations.journalLinkFromHint,
                          onPressed: () => linkService.linkFrom(id),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: Icon(MdiIcons.target),
                          tooltip: localizations.journalLinkToHint,
                          onPressed: () => linkService.linkTo(id),
                        ),
                      ),
                      if (widget.unlinkFn != null)
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: Icon(MdiIcons.linkOff),
                            tooltip: localizations.journalUnlinkHint,
                            onPressed: widget.unlinkFn,
                          ),
                        ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Icon(Icons.more_outlined),
                          tooltip: localizations.journalLinkFromHint,
                          onPressed: () => setState(() => showAllIcons = false),
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
      },
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
