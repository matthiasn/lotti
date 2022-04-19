import 'package:flutter/material.dart';
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
  final JournalEntity item;
  final Function saveFn;

  const EntryDetailHeader({
    Key? key,
    required this.item,
    required this.saveFn,
  }) : super(key: key);

  @override
  State<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends State<EntryDetailHeader> {
  final JournalDb db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  late final Stream<JournalEntity?> stream =
      db.watchEntityById(widget.item.meta.id);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return StreamBuilder<JournalEntity?>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<JournalEntity?> snapshot,
        ) {
          JournalEntity? liveEntity = snapshot.data;
          if (liveEntity == null) {
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
                        item: liveEntity,
                      );
                    },
                  );
                },
                child: Text(
                  df.format(liveEntity.meta.dateFrom),
                  style: textStyle,
                ),
              ),
              Row(
                children: [
                  SwitchIconWidget(
                    tooltip: localizations.journalFavoriteTooltip,
                    activeColor: AppColors.starredGold,
                    onPressed: () {
                      bool prev = liveEntity.meta.starred ?? false;
                      Metadata newMeta = liveEntity.meta.copyWith(
                        starred: !prev,
                      );
                      persistenceLogic.updateJournalEntity(liveEntity, newMeta);
                    },
                    value: liveEntity.meta.starred ?? false,
                    iconData: MdiIcons.star,
                  ),
                  SwitchIconWidget(
                    tooltip: localizations.journalPrivateTooltip,
                    activeColor: AppColors.error,
                    onPressed: () {
                      bool prev = liveEntity.meta.private ?? false;
                      Metadata newMeta = liveEntity.meta.copyWith(
                        private: !prev,
                      );
                      persistenceLogic.updateJournalEntity(liveEntity, newMeta);
                    },
                    value: liveEntity.meta.private ?? false,
                    iconData: MdiIcons.security,
                  ),
                  SwitchIconWidget(
                    tooltip: localizations.journalFlaggedTooltip,
                    activeColor: AppColors.error,
                    onPressed: () {
                      bool prev = liveEntity.meta.flag == EntryFlag.import;
                      Metadata newMeta = liveEntity.meta.copyWith(
                        flag: prev ? EntryFlag.none : EntryFlag.import,
                      );
                      persistenceLogic.updateJournalEntity(liveEntity, newMeta);
                    },
                    value: liveEntity.meta.flag == EntryFlag.import,
                    iconData: MdiIcons.flag,
                  ),
                  TagAddIconWidget(item: widget.item),
                ],
              ),
            ],
          );
        });
  }
}

class SwitchIconWidget extends StatelessWidget {
  const SwitchIconWidget({
    Key? key,
    required this.tooltip,
    required this.onPressed,
    required this.value,
    required this.activeColor,
    required this.iconData,
  }) : super(key: key);

  final String tooltip;
  final void Function() onPressed;
  final bool value;
  final Color activeColor;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        iconData,
        color: value ? activeColor : AppColors.entryTextColor,
      ),
    );
  }
}
