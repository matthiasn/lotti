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
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SwitchIconWidget(
                  tooltip: localizations.journalFavoriteTooltip,
                  activeColor: colorConfig().starredGold,
                  onPressed: cubit.toggleStarred,
                  value: item.meta.starred ?? false,
                  iconData: MdiIcons.star,
                ),
                SwitchIconWidget(
                  tooltip: localizations.journalPrivateTooltip,
                  activeColor: colorConfig().error,
                  onPressed: cubit.togglePrivate,
                  value: item.meta.private ?? false,
                  iconData: MdiIcons.security,
                ),
                SwitchIconWidget(
                  tooltip: localizations.journalFlaggedTooltip,
                  activeColor: colorConfig().error,
                  onPressed: cubit.toggleFlagged,
                  value: item.meta.flag == EntryFlag.import,
                  iconData: MdiIcons.flag,
                ),
                if (state.entry?.geolocation != null)
                  SwitchIconWidget(
                    tooltip: localizations.journalFlaggedTooltip,
                    activeColor: colorConfig().starredGold,
                    onPressed: cubit.toggleMapVisible,
                    value: cubit.showMap,
                    iconData: MdiIcons.mapOutline,
                  ),
                const DeleteIconWidget(),
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
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.value,
    required this.activeColor,
    required this.iconData,
  });

  final String tooltip;
  final void Function() onPressed;
  final bool value;
  final Color activeColor;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return IconButton(
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
      icon: Icon(
        iconData,
        size: 20,
        color: value ? activeColor : colorConfig().entryTextColor,
      ),
    );
  }
}
