import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

/// Compact app bar for tasks without cover art.
///
/// Displays a simple SliverAppBar with back button and action buttons.
/// Used when the task has no cover art image.
class TaskCompactAppBar extends StatelessWidget {
  const TaskCompactAppBar({
    required this.task,
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      leadingWidth: 100,
      titleSpacing: 0,
      toolbarHeight: 45,
      scrolledUnderElevation: 0,
      elevation: 10,
      leading: const BackWidget(),
      actions: _buildActions(context),
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      GlassIconContainer(
        child: UnifiedAiPopUpMenu(journalEntity: task, linkedFromId: null),
      ),
      IconButton(
        icon: Icon(
          Icons.more_horiz,
          color: context.colorScheme.outline,
        ),
        onPressed: () => ExtendedHeaderModal.show(
          context: context,
          entryId: task.id,
          linkedFromId: null,
          link: null,
          inLinkedEntries: false,
        ),
      ),
      const SizedBox(width: 10),
    ];
  }
}
