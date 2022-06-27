import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DeleteIconWidget extends StatelessWidget {
  DeleteIconWidget({
    super.key,
    required this.entityId,
    required this.popOnDelete,
  });

  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final String entityId;
  final bool popOnDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    Future<void> onPressed() async {
      const deleteKey = 'deleteKey';
      final result = await showModalActionSheet<String>(
        context: context,
        title: localizations.journalDeleteQuestion,
        actions: [
          SheetAction(
            icon: Icons.warning,
            label: localizations.journalDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
            isDefaultAction: true,
          ),
        ],
      );

      if (result == deleteKey) {
        await persistenceLogic.deleteJournalEntity(entityId);

        if (popOnDelete) {
          await getIt<AppRouter>().pop();
        }
      }
    }

    return IconButton(
      icon: const Icon(MdiIcons.trashCanOutline),
      iconSize: 24,
      tooltip: localizations.journalDeleteHint,
      padding: const EdgeInsets.only(
        left: 16,
        top: 8,
        bottom: 8,
      ),
      color: AppColors.entryTextColor,
      onPressed: onPressed,
    );
  }
}
