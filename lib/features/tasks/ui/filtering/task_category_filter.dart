import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

class TaskCategoryFilter extends StatefulWidget {
  const TaskCategoryFilter({super.key});

  @override
  State<TaskCategoryFilter> createState() => _TaskCategoryFilterState();
}

class _TaskCategoryFilterState extends State<TaskCategoryFilter> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final categories = getIt<EntitiesCacheService>().sortedCategories;

    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, state) {
        final cubit = context.read<JournalPageCubit>();

        final filteredCategories = _showAll
            ? categories
            : categories.where((category) {
                final isSelected =
                    state.selectedCategoryIds.contains(category.id);
                return category.favorite ?? isSelected;
              }).toList();

        // Show at least the unassigned filter even when no categories exist
        // This improves onboarding experience

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              context.messages.taskCategoryLabel,
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...filteredCategories.map((category) {
                  final isSelected =
                      state.selectedCategoryIds.contains(category.id);
                  final color = colorFromCssHex(category.color);
                  return FilterChoiceChip(
                    isSelected: isSelected,
                    onTap: () => cubit.toggleSelectedCategoryIds(
                      category.id,
                    ),
                    label: category.name,
                    selectedColor: color,
                  );
                }),
                FilterChoiceChip(
                  onTap: () => cubit.toggleSelectedCategoryIds(''),
                  label: context.messages.taskCategoryUnassignedLabel,
                  selectedColor: Colors.grey,
                  isSelected: state.selectedCategoryIds.contains(''),
                ),
                FilterChoiceChip(
                  onTap: cubit.selectedAllCategories,
                  label: context.messages.taskCategoryAllLabel,
                  selectedColor: Colors.grey,
                  isSelected: state.selectedCategoryIds.isEmpty,
                ),
                if (!_showAll)
                  FilterChoiceChip(
                    onTap: () => setState(() {
                      _showAll = !_showAll;
                    }),
                    label: '...',
                    selectedColor: Colors.grey,
                    isSelected: _showAll,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
