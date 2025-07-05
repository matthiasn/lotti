import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/modal/clean_filter_chip.dart';
import 'package:lotti/widgets/modal/clean_filter_section.dart';

class CleanJournalFilter extends StatelessWidget {
  const CleanJournalFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();

        return CleanFilterSection(
          title: 'Quick Filters',
          subtitle: 'Filter entries by special attributes',
          children: [
            CleanFilterChip(
              label: 'Starred',
              icon: Icons.star,
              isSelected: snapshot.filters.contains(DisplayFilter.starredEntriesOnly),
              onTap: () {
                final filters = Set<DisplayFilter>.from(snapshot.filters);
                if (filters.contains(DisplayFilter.starredEntriesOnly)) {
                  filters.remove(DisplayFilter.starredEntriesOnly);
                } else {
                  filters.add(DisplayFilter.starredEntriesOnly);
                }
                cubit.setFilters(filters);
              },
              selectedColor: starredGold,
            ),
            CleanFilterChip(
              label: 'Flagged',
              icon: Icons.flag,
              isSelected: snapshot.filters.contains(DisplayFilter.flaggedEntriesOnly),
              onTap: () {
                final filters = Set<DisplayFilter>.from(snapshot.filters);
                if (filters.contains(DisplayFilter.flaggedEntriesOnly)) {
                  filters.remove(DisplayFilter.flaggedEntriesOnly);
                } else {
                  filters.add(DisplayFilter.flaggedEntriesOnly);
                }
                cubit.setFilters(filters);
              },
              selectedColor: const Color(0xFFBA68C8),
            ),
            CleanFilterChip(
              label: 'Private',
              icon: Icons.lock,
              isSelected: snapshot.filters.contains(DisplayFilter.privateEntriesOnly),
              onTap: () {
                final filters = Set<DisplayFilter>.from(snapshot.filters);
                if (filters.contains(DisplayFilter.privateEntriesOnly)) {
                  filters.remove(DisplayFilter.privateEntriesOnly);
                } else {
                  filters.add(DisplayFilter.privateEntriesOnly);
                }
                cubit.setFilters(filters);
              },
              selectedColor: const Color(0xFFE57373),
            ),
          ],
        );
      },
    );
  }
}
