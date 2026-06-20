import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_icon_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/switch_icon_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/image_utils.dart';

/// The header row above an entry's body in the detail view: category icon,
/// date/time editor, AI menu, and the overflow action menu (flag, star,
/// private, delete, etc.).
///
/// Renders one of two layouts. When the entry is collapsible (an image/audio/
/// text entry shown inside a parent's linked-entries list, `isCollapsible`),
/// the header gains a tap-to-toggle affordance wired to `onToggleCollapse`.
/// Otherwise it renders the standard full header.
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
    final tokens = context.designTokens;
    final showCategory =
        entry != null &&
        entry is! Task &&
        entry is! JournalEvent &&
        !widget.inLinkedEntries;
    return Row(
      children: [
        EntryDatetimeWidget(entryId: widget.entryId),
        if (showCategory) ...[
          SizedBox(width: tokens.spacing.step3),
          CategorySelectionIconButton(entry: entry),
        ],
        const Spacer(),
        ..._spacedTrailing(
          context,
          _trailingActions(context, entry, id, notifier, tokens),
        ),
      ],
    );
  }

  /// The trailing action controls shared by both header layouts, in one fixed
  /// order — favorite, flag, AI, overflow — with absent actions simply omitted
  /// so the cluster reads consistently across all entry types.
  List<Widget> _trailingActions(
    BuildContext context,
    JournalEntity? entry,
    String id,
    EntryController notifier,
    DsTokens tokens,
  ) {
    return <Widget>[
      // Favorite toggle is shown on every (non-event) entry, not only when
      // already starred, so the action set is consistent across card types —
      // the appearing/disappearing star was the most jarring header
      // inconsistency. Empty/outline when not starred, gold when starred.
      if (entry != null && entry is! JournalEvent)
        SwitchIconWidget(
          tooltip: context.messages.journalFavoriteTooltip,
          onPressed: notifier.toggleStarred,
          value: entry.meta.starred ?? false,
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
          (entry is Task ||
              entry is JournalImage ||
              entry is JournalAudio ||
              entry is JournalEntry))
        UnifiedAiPopUpMenu(
          journalEntity: entry,
          linkedFromId: widget.linkedFromId,
          // mediumEmphasis (~10:1) so the outlined assistant glyph reads as a
          // calm, co-equal header control rather than the heaviest element on
          // the card — still well clear of the non-text-contrast floor.
          iconColor: tokens.colors.text.mediumEmphasis,
        ),
      IconButton(
        icon: Icon(Icons.more_horiz, color: tokens.colors.text.mediumEmphasis),
        onPressed: () => ExtendedHeaderModal.show(
          context: context,
          entryId: id,
          inLinkedEntries: widget.inLinkedEntries,
          linkedFromId: widget.linkedFromId,
          link: widget.link,
        ),
      ),
    ];
  }

  /// Interleaves a consistent inter-control gap so adjacent header controls
  /// never sit flush — the crowded 4-control headers were a mis-tap hazard for
  /// motor-impaired users, so neighbouring tap zones get a clear visible gap.
  List<Widget> _spacedTrailing(BuildContext context, List<Widget> actions) {
    final gap = context.designTokens.spacing.step3;
    final out = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) out.add(SizedBox(width: gap));
      out.add(actions[i]);
    }
    return out;
  }

  Widget _buildCollapsibleHeader(
    BuildContext context,
    JournalEntity? entry,
    String id,
    EntryController notifier,
  ) {
    final tokens = context.designTokens;
    return Row(
      children: [
        if (widget.isCollapsed) ...[
          // Collapsed preview: thumbnail/icon + date + duration
          if (entry is JournalImage) _buildImageThumbnail(entry),
          if (entry is JournalAudio) _buildAudioIcon(context),
          if (entry is JournalEntry) _buildTextIcon(context),
          SizedBox(width: tokens.spacing.step3),
          EntryDatetimeWidget(entryId: widget.entryId),
          if (entry is JournalAudio) _buildDurationLabel(context, entry),
        ],
        if (!widget.isCollapsed)
          // Expanded: date on left, actions on right
          EntryDatetimeWidget(entryId: widget.entryId),
        const Spacer(),
        if (!widget.isCollapsed) ...[
          // Action icons only when expanded — same spaced cluster as the
          // default header so the family shares one action grammar.
          ..._spacedTrailing(
            context,
            _trailingActions(context, entry, id, notifier, tokens),
          ),
          SizedBox(width: tokens.spacing.step2),
        ],
        AnimatedRotation(
          turns: widget.isCollapsed ? -0.25 : 0.0,
          duration: AppTheme.chevronRotationDuration,
          child: IconButton(
            icon: Icon(
              Icons.expand_more,
              color: tokens.colors.text.mediumEmphasis,
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
          errorBuilder: (_, _, _) => const Icon(
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

  Widget _buildTextIcon(BuildContext context) {
    return Icon(
      Icons.description_outlined,
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

    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(left: tokens.spacing.step3),
      child: Text(
        label,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}
