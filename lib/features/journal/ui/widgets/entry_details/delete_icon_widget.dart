import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

class DeleteIconListTile extends ConsumerWidget {
  const DeleteIconListTile({
    required this.entryId,
    required this.beamBack,
    super.key,
  });

  final String entryId;
  final bool beamBack;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: entryId);

    Future<void> onPressed() async {
      const deleteKey = 'deleteKey';
      final result = await showModalActionSheet<String>(
        context: context,
        title: context.messages.journalDeleteQuestion,
        actions: [
          ModalSheetAction(
            icon: Icons.warning_rounded,
            label: context.messages.journalDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
            isDefaultAction: true,
          ),
        ],
      );

      if (result == deleteKey) {
        await ref.read(provider.notifier).delete(beamBack: beamBack);
      }
    }

    return ListTile(
      leading: const Icon(Icons.delete_outline_rounded),
      title: Text(context.messages.journalDeleteHint),
      onTap: () async {
        await onPressed();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
