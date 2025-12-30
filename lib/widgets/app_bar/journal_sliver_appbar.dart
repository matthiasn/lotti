import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/ui/widgets/ai_chat_icon.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:lotti/widgets/search/search_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class JournalSliverAppBar extends ConsumerWidget {
  const JournalSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    return SliverAppBar(
      pinned: true,
      toolbarHeight: 100,
      title: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: SearchWidget(
                  margin: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMedium,
                    horizontal: AppTheme.spacingSmall,
                  ),
                  onChanged: controller.setSearchString,
                ),
              ),
              if (state.showTasks) ...[
                const AiChatIcon(),
                const TaskFilterIcon(),
              ] else
                const JournalFilterIcon(),
            ],
          ),
          // Moved TaskLabelQuickFilter out of the AppBar into its own sliver
          // below the header to avoid clipping when chips wrap.
        ],
      ),
    );
  }
}

class JournalFilter extends ConsumerWidget {
  const JournalFilter({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller =
        ref.read(journalPageControllerProvider(showTasks).notifier);

    ButtonSegment<DisplayFilter> segment({
      required DisplayFilter filter,
      required IconData icon,
      required IconData activeIcon,
      required String semanticLabel,
    }) {
      final active = state.filters.contains(filter);
      return ButtonSegment<DisplayFilter>(
        value: filter,
        label: Tooltip(
          message: semanticLabel,
          child: Icon(
            active ? activeIcon : icon,
            semanticLabel: semanticLabel,
            color: context.textTheme.titleLarge?.color ?? Colors.grey,
          ),
        ),
      );
    }

    return SegmentedButton<DisplayFilter>(
      selected: state.filters,
      showSelectedIcon: false,
      multiSelectionEnabled: true,
      onSelectionChanged: controller.setFilters,
      emptySelectionAllowed: true,
      segments: [
        segment(
          filter: DisplayFilter.starredEntriesOnly,
          icon: Icons.star_outline,
          activeIcon: Icons.star,
          semanticLabel: context.messages.journalFavoriteTooltip,
        ),
        segment(
          filter: DisplayFilter.flaggedEntriesOnly,
          icon: Icons.flag_outlined,
          activeIcon: Icons.flag,
          semanticLabel: context.messages.journalFlaggedTooltip,
        ),
        segment(
          filter: DisplayFilter.privateEntriesOnly,
          icon: Icons.shield_outlined,
          activeIcon: Icons.shield,
          semanticLabel: context.messages.journalPrivateTooltip,
        ),
      ],
    );
  }
}

class JournalFilterIcon extends ConsumerWidget {
  const JournalFilterIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    // Get the parent container to share with the modal
    final container = ProviderScope.containerOf(context);

    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacingSmall),
      child: IconButton(
        onPressed: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            title: context.messages.journalSearchHint,
            modalDecorator: (child) {
              // Use UncontrolledProviderScope to share the parent container
              // with overrides for the modal-specific scope value
              return UncontrolledProviderScope(
                container: container,
                child: ProviderScope(
                  overrides: [
                    journalPageScopeProvider.overrideWithValue(showTasks),
                  ],
                  child: child,
                ),
              );
            },
            builder: (_) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JournalFilter(),
                SizedBox(height: 10),
                EntryTypeFilter(),
                SizedBox(height: 10),
                TaskCategoryFilter(),
              ],
            ),
          );
        },
        icon: Icon(MdiIcons.filterVariant),
      ),
    );
  }
}
