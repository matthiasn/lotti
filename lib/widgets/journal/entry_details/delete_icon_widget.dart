import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DeleteIconWidget extends StatelessWidget {
  const DeleteIconWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void maybePop() => Navigator.of(context).maybePop();

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState state,
      ) {
        final cubit = context.read<EntryCubit>();

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
            await cubit.delete();
            maybePop();
          }
        }

        return SizedBox(
          width: 40,
          child: IconButton(
            icon: const Icon(MdiIcons.trashCanOutline),
            iconSize: 24,
            tooltip: localizations.journalDeleteHint,
            padding: EdgeInsets.zero,
            color: colorConfig().entryTextColor,
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}
