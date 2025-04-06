import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_list_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class ToggleFlaggedListTile extends ConsumerWidget {
  const ToggleFlaggedListTile({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);

    final entryState = ref.watch(provider).value;
    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;

    return MenuSwitchListTile(
      title: context.messages.journalToggleFlaggedTitle,
      onChanged: notifier.setFlagged,
      value: entry?.meta.flag == EntryFlag.import,
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag,
      activeColor: context.colorScheme.error,
    );
  }
}
