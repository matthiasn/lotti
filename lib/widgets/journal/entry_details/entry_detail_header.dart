import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:lotti/widgets/journal/entry_details/save_button.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:lotti/widgets/journal/tags/tag_add.dart';

class EntryDetailHeader extends StatefulWidget {
  const EntryDetailHeader({
    super.key,
  });

  @override
  State<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends State<EntryDetailHeader> {
  @override
  void initState() {
    super.initState();
  }

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

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SwitchIconWidget(
                      tooltip: localizations.journalFavoriteTooltip,
                      onPressed: cubit.toggleStarred,
                      value: item.meta.starred ?? false,
                      icon: styleConfig().cardStarIcon,
                      activeIcon: styleConfig().cardStarIconActive,
                    ),
                    SwitchIconWidget(
                      tooltip: localizations.journalPrivateTooltip,
                      onPressed: cubit.togglePrivate,
                      value: item.meta.private ?? false,
                      icon: styleConfig().cardShieldIcon,
                      activeIcon: styleConfig().cardShieldIconActive,
                    ),
                    SwitchIconWidget(
                      tooltip: localizations.journalFlaggedTooltip,
                      onPressed: cubit.toggleFlagged,
                      value: item.meta.flag == EntryFlag.import,
                      icon: styleConfig().cardFlagIcon,
                      activeIcon: styleConfig().cardFlagIconActive,
                    ),
                    if (state.entry?.geolocation != null)
                      SwitchIconWidget(
                        tooltip: state.showMap
                            ? localizations.journalHideMapHint
                            : localizations.journalShowMapHint,
                        onPressed: cubit.toggleMapVisible,
                        value: cubit.showMap,
                        icon: styleConfig().cardMapIcon,
                        activeIcon: styleConfig().cardMapIconActive,
                      ),
                    const DeleteIconWidget(),
                    const ShareButtonWidget(),
                    TagAddIconWidget(),
                  ],
                ),
                const SaveButton(),
              ],
            ),
            Divider(
              height: 0.5,
              color: styleConfig().secondaryTextColor,
            )
          ],
        );
      },
    );
  }
}

class SwitchIconWidget extends StatelessWidget {
  const SwitchIconWidget({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.value,
    required this.icon,
    required this.activeIcon,
  });

  final String tooltip;
  final void Function() onPressed;
  final bool value;

  final String icon;
  final String activeIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: IconButton(
        key: Key(value ? activeIcon : icon),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: () {
          if (value) {
            HapticFeedback.lightImpact();
          } else {
            HapticFeedback.heavyImpact();
          }
          onPressed();
        },
        icon: value ? SvgPicture.asset(activeIcon) : SvgPicture.asset(icon),
      ),
    );
  }
}
