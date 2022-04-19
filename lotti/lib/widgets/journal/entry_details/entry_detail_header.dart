import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_datetime_modal.dart';
import 'package:lotti/widgets/journal/entry_details/switch_row_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/journal/tags_widget.dart';

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
              SwitchRowWidget(
                label: localizations.journalFavoriteLabel,
                activeColor: AppColors.starredGold,
                onChanged: (bool value) {
                  Metadata newMeta = liveEntity.meta.copyWith(
                    starred: value,
                  );
                  persistenceLogic.updateJournalEntity(liveEntity, newMeta);
                },
                value: liveEntity.meta.starred ?? false,
              ),
              SwitchRowWidget(
                label: localizations.journalPrivateLabel,
                activeColor: AppColors.error,
                onChanged: (bool value) {
                  Metadata newMeta = liveEntity.meta.copyWith(
                    private: value,
                  );
                  persistenceLogic.updateJournalEntity(liveEntity, newMeta);
                },
                value: liveEntity.meta.private ?? false,
              ),
              SwitchRowWidget(
                label: localizations.journalFlaggedLabel,
                activeColor: AppColors.error,
                onChanged: (bool value) {
                  Metadata newMeta = liveEntity.meta.copyWith(
                    flag: value ? EntryFlag.import : EntryFlag.none,
                  );
                  persistenceLogic.updateJournalEntity(liveEntity, newMeta);
                },
                value: liveEntity.meta.flag == EntryFlag.import,
              ),
              TagAddIconWidget(item: widget.item),
            ],
          );
        });
  }
}
