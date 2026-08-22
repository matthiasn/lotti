import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_toggle_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The entry's three booleans — starred, private, flagged — as toggle chips
/// at the head of the `•••` menu.
///
/// They used to be the sheet's first three rows, which was wrong twice over.
/// A row promises an action and then a dismissal; these are states, and the
/// sheet closing after each one meant setting two of them cost two trips
/// through the menu. And their value lived only in an icon's fill, four
/// characters wide, at the far left of a full-width row.
///
/// As chips they toggle optimistically and in place: the entry controller
/// writes through, the provider pushes the new value back, and the sheet
/// stays open.
class EntryToggleChips extends ConsumerWidget {
  const EntryToggleChips({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(entryId);
    final entry = ref.watch(provider).value?.entry;

    if (entry == null) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(provider.notifier);
    final tokens = context.designTokens;
    final starred = entry.meta.starred ?? false;
    final private = entry.meta.private ?? false;
    final flagged = entry.meta.flag != null;

    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        DsActionToggleChip(
          label: context.messages.journalToggleStarredTitle,
          icon: starred ? LottiIconsFilled.star : LottiIcons.star,
          selected: starred,
          onToggle: notifier.toggleStarred,
        ),
        DsActionToggleChip(
          label: context.messages.journalTogglePrivateTitle,
          // The icon set has no filled padlock, and it needs none: a *closed*
          // padlock against an open one already says on versus off, which is
          // exactly what fill says on the star and the flag.
          icon: private ? LottiIcons.lock : LottiIcons.unlocked,
          selected: private,
          onToggle: notifier.togglePrivate,
        ),
        DsActionToggleChip(
          label: context.messages.journalToggleFlaggedTitle,
          icon: flagged ? LottiIconsFilled.flag : LottiIcons.flag,
          selected: flagged,
          onToggle: notifier.toggleFlagged,
        ),
      ],
    );
  }
}
