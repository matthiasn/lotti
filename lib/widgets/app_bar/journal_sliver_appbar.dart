import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:lotti/widgets/search/search_widget.dart';
import 'package:lotti/widgets/search/task_status_filter.dart';

class JournalSliverAppBar extends StatelessWidget {
  const JournalSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        return SliverAppBar(
          expandedHeight: 200,
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: EdgeInsets.only(top: isIOS ? 30 : 0),
              child: Column(
                children: [
                  SearchWidget(
                    margin: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 40,
                    ),
                    text: snapshot.match,
                    onChanged: cubit.setSearchString,
                  ),
                  const JournalFilter(),
                  const SizedBox(height: 10),
                  if (!snapshot.showTasks) const EntryTypeFilter(),
                  if (snapshot.showTasks) const TaskStatusFilter(),
                ],
              ),
            ),
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
    final localizations = AppLocalizations.of(context)!;

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
                color: Theme.of(context).textTheme.titleLarge?.color ??
                    Colors.grey,
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
              semanticLabel: localizations.journalFavoriteTooltip,
            ),
            segment(
              filter: DisplayFilter.flaggedEntriesOnly,
              icon: Icons.flag_outlined,
              activeIcon: Icons.flag,
              semanticLabel: localizations.journalFlaggedTooltip,
            ),
            segment(
              filter: DisplayFilter.privateEntriesOnly,
              icon: Icons.shield_outlined,
              activeIcon: Icons.shield,
              semanticLabel: localizations.journalPrivateTooltip,
            ),
          ],
        );
      },
    );
  }
}
