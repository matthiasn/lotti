import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

class TaskSliverAppBar extends ConsumerWidget {
  const TaskSliverAppBar({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final item = ref.watch(provider).value?.entry;

    if (item == null || item is! Task) {
      return JournalSliverAppBar(entryId: taskId);
    }

    final coverArtId = item.data.coverArtId;

    // If no cover art, use compact app bar
    if (coverArtId == null) {
      return _buildCompactAppBar(context, item);
    }

    // Expandable app bar with cover art (2:1 aspect ratio)
    return _buildExpandableAppBar(context, item, coverArtId);
  }

  Widget _buildCompactAppBar(BuildContext context, Task task) {
    return SliverAppBar(
      leadingWidth: 100,
      titleSpacing: 0,
      toolbarHeight: 45,
      scrolledUnderElevation: 0,
      elevation: 10,
      leading: const BackWidget(),
      actions: _buildActions(context, task),
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }

  Widget _buildExpandableAppBar(
    BuildContext context,
    Task task,
    String coverArtId,
  ) {
    // 2:1 cinematic aspect ratio: height = width / 2
    final expandedHeight = MediaQuery.of(context).size.width / 2;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      leadingWidth: 52,
      titleSpacing: 0,
      toolbarHeight: 45,
      scrolledUnderElevation: 0,
      elevation: 10,
      leading: _buildGlassBackButton(context),
      actions: _buildGlassActions(context, task),
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: CoverArtBackground(imageId: coverArtId),
      ),
    );
  }

  Widget _buildGlassBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const GlassIconContainer(
          child: Icon(
            Icons.chevron_left,
            size: 26,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGlassActions(BuildContext context, Task task) {
    return [
      GlassIconContainer(
        child: UnifiedAiPopUpMenu(
          journalEntity: task,
          linkedFromId: null,
          iconColor: Colors.white,
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
        onPressed: () => ExtendedHeaderModal.show(
          context: context,
          entryId: taskId,
          linkedFromId: null,
          link: null,
          inLinkedEntries: false,
        ),
        icon: const GlassIconContainer(
          child: Icon(
            Icons.more_horiz,
            size: 26,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(width: 10),
    ];
  }

  List<Widget> _buildActions(BuildContext context, Task task) {
    return [
      UnifiedAiPopUpMenu(journalEntity: task, linkedFromId: null),
      IconButton(
        icon: Icon(
          Icons.more_horiz,
          color: context.colorScheme.outline,
        ),
        onPressed: () => ExtendedHeaderModal.show(
          context: context,
          entryId: taskId,
          linkedFromId: null,
          link: null,
          inLinkedEntries: false,
        ),
      ),
      const SizedBox(width: 10),
    ];
  }
}
