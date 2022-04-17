import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:lotti/widgets/journal/entry_details/switch_row_widget.dart';

class EntryInfoRow extends StatelessWidget {
  final String entityId;
  final JournalDb db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(entityId);
  final bool popOnDelete;

  EntryInfoRow({
    Key? key,
    required this.entityId,
    required this.popOnDelete,
  }) : super(key: key);

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
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
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
                ],
              ),
              DeleteIconWidget(
                entityId: entityId,
                popOnDelete: popOnDelete,
              ),
            ],
          );
        });
  }
}
