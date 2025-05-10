import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/features/journal/riverpod/journal_providers.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:lotti/widgets/search/riverpod_entry_type_filter.dart';
import 'package:lotti/widgets/search/riverpod_search_widget.dart';
import 'package:lotti/widgets/search/search_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Original Bloc-based JournalSliverAppBar
class JournalSliverAppBar extends StatelessWidget {
  const JournalSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final showTasks = snapshot.showTasks;

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
                        vertical: 20,
                        horizontal: 40,
                      ),
                      text: snapshot.match,
                      onChanged: cubit.setSearchString,
                    ),
                  ),
                  if (showTasks)
                    const TaskFilterIcon()
                  else
                    const JournalFilterIcon(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Riverpod version of the JournalSliverAppBar
class RiverpodJournalSliverAppBar extends ConsumerWidget {
  const RiverpodJournalSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final showTasks = filters.showTasks;

    return SliverAppBar(
      pinned: true,
      toolbarHeight: 100,
      title: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: RiverpodSearchWidget(
                  margin: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 40,
                  ),
                ),
              ),
              if (showTasks)
                const TaskFilterIcon()
              else
                const RiverpodJournalFilterIcon(),
            ],
          ),
        ],
      ),
    );
  }
}

class JournalFilter extends StatelessWidget {
  const JournalFilter({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        ButtonSegment<DisplayFilter> segment({
          required DisplayFilter filter,
          required IconData icon,
          required IconData activeIcon,
          required String semanticLabel,
        }) {
          final active = snapshot.filters.contains(filter);
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
          selected: snapshot.filters,
          showSelectedIcon: false,
          multiSelectionEnabled: true,
          onSelectionChanged: cubit.setFilters,
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
      },
    );
  }
}

/// Riverpod version of JournalFilter
class RiverpodJournalFilter extends ConsumerWidget {
  const RiverpodJournalFilter({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(journalFiltersProvider);
    final filtersNotifier = ref.read(journalFiltersProvider.notifier);

    ButtonSegment<DisplayFilter> segment({
      required DisplayFilter filter,
      required IconData icon,
      required IconData activeIcon,
      required String semanticLabel,
    }) {
      final active = filters.filters.contains(filter);
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
      selected: filters.filters,
      showSelectedIcon: false,
      multiSelectionEnabled: true,
      onSelectionChanged: (value) {
        filtersNotifier.update((state) => state.copyWith(filters: value));
      },
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

class JournalFilterIcon extends StatelessWidget {
  const JournalFilterIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 30),
      child: IconButton(
        onPressed: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            title: context.messages.journalSearchHint,
            modalDecorator: (child) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<JournalPageCubit>()),
                ],
                child: child,
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

/// Riverpod version of JournalFilterIcon
class RiverpodJournalFilterIcon extends StatelessWidget {
  const RiverpodJournalFilterIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 30),
      child: IconButton(
        onPressed: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            title: context.messages.journalSearchHint,
            builder: (_) => const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiverpodJournalFilter(),
                SizedBox(height: 10),
                RiverpodEntryTypeFilter(),
                SizedBox(height: 10),
                // TaskCategoryFilter needs to be converted to Riverpod
                // TaskCategoryFilter(),
              ],
            ),
          );
        },
        icon: Icon(MdiIcons.filterVariant),
      ),
    );
  }
}
