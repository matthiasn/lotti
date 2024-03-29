import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

class DeleteIconWidget extends StatelessWidget {
  const DeleteIconWidget({
    required this.beamBack,
    super.key,
  });

  final bool beamBack;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

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
              ModalSheetAction(
                icon: Icons.warning_rounded,
                label: localizations.journalDeleteConfirm,
                key: deleteKey,
                isDestructiveAction: true,
                isDefaultAction: true,
              ),
            ],
          );

          if (result == deleteKey) {
            await cubit.delete(beamBack: beamBack);
          }
        }

        return SizedBox(
          width: 40,
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            splashColor: Colors.transparent,
            tooltip: localizations.journalDeleteHint,
            padding: EdgeInsets.zero,
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}
