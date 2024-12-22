import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:lotti/widgets/search/search_widget.dart';
import 'package:lotti/widgets/search/task_filter_icon.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
                  if (showTasks) const TaskFilterIcon(),
                  if (!showTasks) const JournalFilterIcon(),
                ],
              ),
            ],
          ),
        );
      },
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

class JournalFilterIcon extends StatelessWidget {
  const JournalFilterIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 30),
      child: IconButton(
        onPressed: () {
          ModalUtils.showSinglePageModal(
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
              children: [
                JournalFilter(),
                SizedBox(height: 10),
                EntryTypeFilter(),
              ],
            ),
          );
        },
        icon: Icon(MdiIcons.filterVariant),
      ),
    );
  }
}
