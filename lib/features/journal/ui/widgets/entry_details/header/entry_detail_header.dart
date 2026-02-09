import 'dart:io';

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
import 'package:lotti/utils/image_utils.dart';

class EntryDetailHeader extends ConsumerStatefulWidget {
  const EntryDetailHeader({
    required this.entryId,
    this.inLinkedEntries = false,
    super.key,
    this.linkedFromId,
    this.link,
    this.isCollapsible = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final bool inLinkedEntries;
  final String entryId;
  final String? linkedFromId;
  final EntryLink? link;
  final bool isCollapsible;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  @override
  ConsumerState<EntryDetailHeader> createState() => _EntryDetailHeaderState();
}

class _EntryDetailHeaderState extends ConsumerState<EntryDetailHeader> {
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

    if (widget.isCollapsible) {
      return _buildCollapsibleHeader(context, entry, id, notifier);
    }

    return _buildDefaultHeader(context, entry, id, notifier);
  }

  Widget _buildDefaultHeader(
    BuildContext context,
    JournalEntity? entry,
    String id,
    EntryController notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        EntryDatetimeWidget(entryId: widget.entryId),
        const SizedBox.shrink(),
        if (entry != null &&
            entry is! Task &&
            entry is! JournalEvent &&
            !widget.inLinkedEntries)
          CategorySelectionIconButton(entry: entry),
        const SizedBox(width: 10),
        const Spacer(),
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
        if (entry != null &&
            (entry is Task || entry is JournalImage || entry is JournalAudio))
          UnifiedAiPopUpMenu(
            journalEntity: entry,
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
    );
  }

  Widget _buildCollapsibleHeader(
    BuildContext context,
    JournalEntity? entry,
    String id,
    EntryController notifier,
  ) {
    return Row(
      children: [
        // When collapsed, show preview so user can identify the entry
        if (widget.isCollapsed) ...[
          if (entry is JournalImage) _buildImageThumbnail(entry),
          if (entry is JournalAudio) _buildAudioIcon(context),
          const SizedBox(width: AppTheme.spacingSmall),
          EntryDatetimeWidget(entryId: widget.entryId),
          if (entry is JournalAudio) _buildDurationLabel(context, entry),
        ],
        // Hide action buttons when collapsed for a clean, minimal look
        if (!widget.isCollapsed) ...[
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
          if (entry != null &&
              (entry is Task || entry is JournalImage || entry is JournalAudio))
            UnifiedAiPopUpMenu(
              journalEntity: entry,
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
        const Spacer(),
        AnimatedRotation(
          turns: widget.isCollapsed ? -0.25 : 0.0,
          duration: AppTheme.chevronRotationDuration,
          child: IconButton(
            icon: Icon(
              Icons.expand_more,
              color: context.colorScheme.outline,
            ),
            onPressed: widget.onToggleCollapse,
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(JournalImage image) {
    final file = File(getFullImagePath(image));
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.thumbnailBorderRadius),
      child: SizedBox(
        width: AppTheme.thumbnailSize,
        height: AppTheme.thumbnailSize,
        child: Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth:
              (AppTheme.thumbnailSize * AppTheme.thumbnailCacheMultiplier)
                  .toInt(),
          errorBuilder: (_, __, ___) => const Icon(
            Icons.image_outlined,
            size: AppTheme.previewIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildAudioIcon(BuildContext context) {
    return Icon(
      Icons.mic_rounded,
      size: AppTheme.previewIconSize,
      color: context.colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildDurationLabel(BuildContext context, JournalAudio audio) {
    final duration = audio.data.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final label = minutes >= 60
        ? '${duration.inHours}:${minutes.remainder(60).toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacingSmall),
      child: Text(
        label,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.outline,
        ),
      ),
    );
  }
}
