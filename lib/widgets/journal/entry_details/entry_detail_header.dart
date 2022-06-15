import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_datetime_modal.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class EntryDetailHeader extends StatefulWidget {
  const EntryDetailHeader({
    super.key,
    required this.itemId,
    required this.saveFn,
  });

  final String itemId;
  final Function saveFn;

  @override
  State<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends State<EntryDetailHeader> {
  final JournalDb db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  late final Stream<JournalEntity?> stream = db.watchEntityById(widget.itemId);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<JournalEntity?>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<JournalEntity?> snapshot,
      ) {
        final item = snapshot.data;
        if (item == null) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  builder: (BuildContext context) {
                    return EntryDateTimeModal(
                      item: item,
                    );
                  },
                );
              },
              child: Text(
                df.format(item.meta.dateFrom),
                style: textStyle,
              ),
            ),
            Row(
              children: [
                SwitchIconWidget(
                  tooltip: localizations.journalFavoriteTooltip,
                  activeColor: AppColors.starredGold,
                  onPressed: () {
                    final prev = item.meta.starred ?? false;
                    final newMeta = item.meta.copyWith(
                      starred: !prev,
                    );
                    persistenceLogic.updateJournalEntity(item, newMeta);
                  },
                  value: item.meta.starred ?? false,
                  iconData: MdiIcons.star,
                ),
                SwitchIconWidget(
                  tooltip: localizations.journalPrivateTooltip,
                  activeColor: AppColors.error,
                  onPressed: () {
                    final prev = item.meta.private ?? false;
                    final newMeta = item.meta.copyWith(
                      private: !prev,
                    );
                    persistenceLogic.updateJournalEntity(item, newMeta);
                  },
                  value: item.meta.private ?? false,
                  iconData: MdiIcons.security,
                ),
                SwitchIconWidget(
                  tooltip: localizations.journalFlaggedTooltip,
                  activeColor: AppColors.error,
                  onPressed: () {
                    final prev = item.meta.flag == EntryFlag.import;
                    final newMeta = item.meta.copyWith(
                      flag: prev ? EntryFlag.none : EntryFlag.import,
                    );
                    persistenceLogic.updateJournalEntity(item, newMeta);
                  },
                  value: item.meta.flag == EntryFlag.import,
                  iconData: MdiIcons.flag,
                ),
                TagAddIconWidget(itemId: widget.itemId),
              ],
            ),
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
        color: value ? activeColor : AppColors.entryTextColor,
      ),
    );
  }
}
