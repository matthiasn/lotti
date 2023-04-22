import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:lotti/widgets/journal/entry_details/save_button.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:lotti/widgets/journal/tags/tag_add.dart';

class EntryDetailHeader extends StatelessWidget {
  const EntryDetailHeader({
    this.inLinkedEntries = false,
    super.key,
  });

  final bool inLinkedEntries;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, EntryState state) {
        final cubit = context.read<EntryCubit>();
        final item = state.entry;

        if (item == null) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SwitchIconWidget(
                  tooltip: localizations.journalFavoriteTooltip,
                  onPressed: cubit.toggleStarred,
                  value: item.meta.starred ?? false,
                  icon: Icons.star_outline,
                  activeIcon: Icons.star,
                  activeColor: styleConfig().starredGold,
                ),
                SwitchIconWidget(
                  tooltip: localizations.journalPrivateTooltip,
                  onPressed: cubit.togglePrivate,
                  value: item.meta.private ?? false,
                  icon: Icons.shield_outlined,
                  activeIcon: Icons.shield,
                  activeColor: styleConfig().alarm,
                ),
                SwitchIconWidget(
                  tooltip: localizations.journalFlaggedTooltip,
                  onPressed: cubit.toggleFlagged,
                  value: item.meta.flag == EntryFlag.import,
                  icon: Icons.flag_outlined,
                  activeIcon: Icons.flag,
                  activeColor: styleConfig().primaryColor,
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
                    activeColor: styleConfig().primaryColor,
                  ),
                DeleteIconWidget(beamBack: !inLinkedEntries),
                const ShareButtonWidget(),
                TagAddIconWidget(),
              ],
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
