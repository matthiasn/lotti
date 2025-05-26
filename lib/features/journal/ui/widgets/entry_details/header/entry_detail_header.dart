import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_icon_button.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_icon_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

class EntryDetailHeader extends ConsumerStatefulWidget {
  const EntryDetailHeader({
    required this.entryId,
    this.inLinkedEntries = false,
    super.key,
    this.linkedFromId,
    this.link,
  });

  final bool inLinkedEntries;
  final String entryId;
  final String? linkedFromId;
  final EntryLink? link;

  @override
  ConsumerState<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends ConsumerState<EntryDetailHeader> {
  bool showAllIcons = false;

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;
    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final entry = entryState.entry;
    final id = entryState.entryId;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: 5,
          ),
          child: EntryDatetimeWidget(entryId: widget.entryId),
        ),
        const SizedBox.shrink(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (entry != null &&
                  entry is! Task &&
                  entry is! JournalEvent &&
                  !widget.inLinkedEntries)
                CategorySelectionIconButton(entry: entry),
              const SizedBox(width: 10),
              if (entry is! JournalEvent && (entry?.meta.starred ?? false))
                SwitchIconWidget(
                  tooltip: context.messages.journalFavoriteTooltip,
                  onPressed: notifier.toggleStarred,
                  value: entry?.meta.starred ?? false,
                  icon: Icons.star_outline_rounded,
                  activeIcon: Icons.star_rounded,
                  activeColor: starredGold,
                ),
              if (entry?.meta.flag == EntryFlag.import)
                SwitchIconWidget(
                  tooltip: context.messages.journalFlaggedTooltip,
                  onPressed: notifier.toggleFlagged,
                  value: entry?.meta.flag == EntryFlag.import,
                  icon: Icons.flag_outlined,
                  activeIcon: Icons.flag,
                  activeColor: context.colorScheme.error,
                ),
              if (entry != null && entry is Task ||
                  entry is JournalImage ||
                  entry is JournalAudio)
                UnifiedAiPopUpMenu(
                  journalEntity: entry!,
                  linkedFromId: widget.linkedFromId,
                ),
              IconButton(
                icon: Icon(
                  Icons.more_horiz,
                  color: context.colorScheme.outline,
                ),
                onPressed: () => ExtendedHeaderModal.show(
                  context: context,
                  entryId: id,
                  inLinkedEntries: widget.inLinkedEntries,
                  linkedFromId: widget.linkedFromId,
                  link: widget.link,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
