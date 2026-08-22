import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

/// Shows or hides the map on an entry that carries a geolocation.
///
/// Flips the entry's own map visibility and dismisses the sheet, so the change
/// is visible on the entry underneath. No trailing glyph: the tap does not
/// hand off to another surface, it acts on the entry you came from.
class ModernToggleMapItem extends ConsumerWidget {
  const ModernToggleMapItem({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final entry = entryState?.entry;
    final geolocation = entry?.geolocation;

    if (entryState == null || geolocation == null || entry is Task) {
      return const SizedBox.shrink();
    }

    final showMap = entryState.showMap;

    return DsActionRow(
      icon: LottiIcons.map,
      title: showMap
          ? context.messages.journalHideMapHint
          : context.messages.journalShowMapHint,
      onTap: () {
        notifier.toggleMapVisible();
        Navigator.of(context).pop();
      },
    );
  }
}

/// Deletes the entry, behind the shared confirmation sheet.
///
/// The sheet's only [DsActionRowTone.destructive] row, and the only one below
/// the list's divider. It carries no trailing glyph for the same reason the
/// copy rows do not: the confirmation is a question, not a destination.
class ModernDeleteItem extends ConsumerWidget {
  const ModernDeleteItem({
    required this.entryId,
    required this.beamBack,
    super.key,
  });

  final String entryId;
  final bool beamBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(entryId);

    Future<void> onPressed() async {
      const deleteKey = 'deleteKey';
      final result = await showModalActionSheet<String>(
        context: context,
        title: context.messages.journalDeleteQuestion,
        actions: [
          ModalSheetAction(
            icon: LottiIcons.warning,
            label: context.messages.journalDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
          ),
        ],
      );

      if (result == deleteKey) {
        await ref.read(provider.notifier).delete(beamBack: beamBack);
      }
    }

    return DsActionRow(
      icon: LottiIcons.delete,
      title: context.messages.journalDeleteHint,
      tone: DsActionRowTone.destructive,
      onTap: () async {
        await onPressed();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
