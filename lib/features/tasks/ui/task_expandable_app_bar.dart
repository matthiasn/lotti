import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/ui/unified_ai_popup_menu.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_modal.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';
import 'package:lotti/features/tasks/ui/cover_art_background.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_back_leading.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';

/// Expandable app bar for tasks with cover art.
///
/// Displays a SliverAppBar with a 16:9 aspect ratio cover image,
/// glass-styled back button and action buttons. Once the cover has
/// scrolled past the pinned toolbar, the bar surfaces the task title in
/// `subtitle2` so it stays on screen — matching the title typography used
/// by the task list cards.
class TaskExpandableAppBar extends ConsumerWidget {
  const TaskExpandableAppBar({
    required this.task,
    required this.coverArtId,
    super.key,
  });

  final Task task;
  final String coverArtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset =
        ref.watch(taskAppBarControllerProvider(id: task.id)).value ?? 0;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // Use the actual available width (not MediaQuery) so that in
        // desktop split-pane mode the image stays at 16:9 relative to
        // the detail pane, not the full window.
        final availableWidth = constraints.crossAxisExtent > 0
            ? constraints.crossAxisExtent
            : MediaQuery.of(context).size.width;
        final expandedHeight = availableWidth * 9 / 16;
        // Show the title once the cover is mostly out of view — ~85% of
        // the expanded height — so it appears as the compact collapsed
        // toolbar takes over.
        final showTitle = offset >= expandedHeight * 0.85;

        return SliverAppBar(
          backgroundColor: context.designTokens.colors.background.level01,
          expandedHeight: expandedHeight,
          leadingWidth: 48,
          titleSpacing: 0,
          toolbarHeight: 40,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: _GlassTaskBackLeading(
            isDesktop: isDesktopLayout(context),
          ),
          centerTitle: true,
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: showTitle
                ? _ExpandableCompactTitle(
                    key: const ValueKey('expandable-title'),
                    task: task,
                  )
                : const SizedBox.shrink(key: ValueKey('no-title')),
          ),
          actions: _buildGlassActions(context),
          pinned: true,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: CoverArtBackground(imageId: coverArtId),
          ),
        );
      },
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

/// Glass-styled back button leading for the expandable task app bar.
///
/// Mobile: always renders [GlassBackButton] which pops the navigator.
/// Desktop: delegates to [TaskDetailDesktopBackLeading], shared with the
/// compact bar so the back affordance is visually identical whether the
/// task has cover art or not.
class _GlassTaskBackLeading extends StatelessWidget {
  const _GlassTaskBackLeading({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return const Padding(
        padding: EdgeInsets.only(left: 8),
        child: GlassBackButton(),
      );
    }
    return const TaskDetailDesktopBackLeading();
  }
}

class _ExpandableCompactTitle extends StatelessWidget {
  const _ExpandableCompactTitle({required this.task, super.key});

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
