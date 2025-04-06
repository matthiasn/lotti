import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_list_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';

class ToggleStarredListTile extends ConsumerWidget {
  const ToggleStarredListTile({
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
    final starred = entry?.meta.starred ?? false;

    return MenuSwitchListTile(
      title: context.messages.journalToggleStarredTitle,
      onChanged: notifier.setStarred,
      value: starred,
      icon: Icons.star_outline_rounded,
      activeIcon: Icons.star_rounded,
      activeColor: starredGold,
    );
  }
}
