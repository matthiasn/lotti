import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';

/// Expandable app bar for tasks with cover art.
///
/// Displays a SliverAppBar with a 16:9 aspect ratio cover image,
/// glass-styled back button and action buttons.
class TaskExpandableAppBar extends StatelessWidget {
  const TaskExpandableAppBar({
    required this.task,
    required this.coverArtId,
    super.key,
  });

  final Task task;
  final String coverArtId;

  @override
  Widget build(BuildContext context) {
    // 16:9 aspect ratio to match generated cover art
    final expandedHeight = MediaQuery.of(context).size.width * 9 / 16;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      leadingWidth: 48,
      titleSpacing: 0,
      toolbarHeight: 40,
      scrolledUnderElevation: 0,
      elevation: 10,
      leading: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: GlassBackButton(),
      ),
      actions: _buildGlassActions(context),
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: CoverArtBackground(imageId: coverArtId),
      ),
    );
  }

  List<Widget> _buildGlassActions(BuildContext context) {
    return [
      UnifiedAiPopUpMenu(
        journalEntity: task,
        linkedFromId: null,
        iconColor: Colors.white,
      ),
      const SizedBox(width: 8),
      GlassActionButton(
        onTap: () => ExtendedHeaderModal.show(
          context: context,
          entryId: task.id,
          linkedFromId: null,
          link: null,
          inLinkedEntries: false,
        ),
        child: const Icon(
          Icons.more_horiz,
          size: 26,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 10),
    ];
  }
}
