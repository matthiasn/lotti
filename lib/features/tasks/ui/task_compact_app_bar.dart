import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

/// Scroll offset at which the compact app bar stops being transparent
/// enough to see the header title below it and starts showing its own
/// subtitle-sized title to keep context. Matches the threshold used by
/// the expandable variant's collapse.
const double _persistentTitleScrollThreshold = 48;

/// Compact app bar for tasks without cover art.
///
/// Displays a simple SliverAppBar with back button, AI menu, and ellipsis
/// action. Once the task header has scrolled out of view, the app bar also
/// surfaces the task title in `subtitle2` so it stays on screen — matching
/// the title typography used by the task list cards.
class TaskCompactAppBar extends ConsumerWidget {
  const TaskCompactAppBar({
    required this.task,
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset =
        ref.watch(taskAppBarControllerProvider(id: task.id)).value ?? 0;
    final showTitle = offset >= _persistentTitleScrollThreshold;
    return SliverAppBar(
      backgroundColor: context.designTokens.colors.background.level01,
      leadingWidth: 100,
      titleSpacing: 0,
      toolbarHeight: 45,
      scrolledUnderElevation: 0,
      elevation: 0,
      leading: const BackWidget(),
      centerTitle: true,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: showTitle
            ? _CompactTitle(
                key: const ValueKey('compact-title'),
                task: task,
              )
            : const SizedBox.shrink(key: ValueKey('no-title')),
      ),
      actions: _buildActions(context),
      pinned: true,
      automaticallyImplyLeading: false,
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      UnifiedAiPopUpMenu(journalEntity: task, linkedFromId: null),
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

class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      child: Text(
        task.data.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: TaskShowcasePalette.highText(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
