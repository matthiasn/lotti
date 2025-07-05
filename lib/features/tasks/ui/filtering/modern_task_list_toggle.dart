import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

class ModernTaskListToggle extends StatelessWidget {
  const ModernTaskListToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final showTaskList = snapshot.taskAsListView;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPadding,
            vertical: AppTheme.spacingSmall,
          ),
          child: ModernBaseCard(
            onTap: cubit.toggleTaskAsListView,
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            child: Row(
              children: [
                ModernIconContainer(
                  icon: showTaskList
                      ? Icons.view_list_rounded
                      : Icons.view_agenda_rounded,
                  iconColor: context.colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.spacingLarge),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task View',
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.titleFontSize,
                        ),
                      ),
                      const SizedBox(
                          height: AppTheme.spacingBetweenTitleAndSubtitle),
                      Text(
                        showTaskList ? 'Grouped by status' : 'List view',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontSize: AppTheme.subtitleFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: showTaskList,
                  onChanged: (_) => cubit.toggleTaskAsListView(),
                  activeColor: context.colorScheme.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
