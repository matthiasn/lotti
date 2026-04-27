import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_back_leading.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

/// Scroll offset at which the compact app bar surfaces the task title in
/// its own toolbar so context stays on screen once the inline header
/// scrolls out of the pinned app bar's footprint.
///
/// The expandable variant can derive this threshold from its own cover
/// image height (`expandedHeight * 0.85`), but the compact variant has
/// no cover image and no direct access to the `DesktopTaskHeader`'s
/// intrinsic height — so it uses a small fixed offset just past the
/// pinned toolbar. The inline header's title stays visible below the
/// toolbar until scrolling catches up, so brief overlap at the
/// transition is acceptable.
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
    final isDesktop = isDesktopLayout(context);
    // On desktop the back arrow is only rendered while a linked task
    // sits on top of the detail stack — at that point we use the same
    // glass-styled button (and matching 48px leading width) as the
    // expandable bar so the affordance stays visually identical
    // whether the task has cover art or not.
    return SliverAppBar(
      backgroundColor: context.designTokens.colors.background.level01,
      leadingWidth: isDesktop ? 48 : 100,
      titleSpacing: 0,
      toolbarHeight: 45,
      scrolledUnderElevation: 0,
      elevation: 0,
      leading: _TaskBackLeading(isDesktop: isDesktop),
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

/// Leading widget for the compact task app bar.
///
/// Mobile: always renders [BackWidget] which beams back to the task list.
/// Desktop: delegates to [TaskDetailDesktopBackLeading], shared with the
/// expandable bar so the back affordance is visually identical whether
/// the task has cover art or not.
class _TaskBackLeading extends StatelessWidget {
  const _TaskBackLeading({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return const BackWidget();
    }
    return const TaskDetailDesktopBackLeading();
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
