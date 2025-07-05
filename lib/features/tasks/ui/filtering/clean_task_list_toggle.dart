import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/blocs/journal/journal_page_state.dart';
import 'package:lotti/themes/theme.dart';

class CleanTaskListToggle extends StatelessWidget {
  const CleanTaskListToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalPageCubit, JournalPageState>(
      builder: (context, snapshot) {
        final cubit = context.read<JournalPageCubit>();
        final showTaskList = snapshot.taskAsListView;

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                showTaskList ? Icons.view_list : Icons.view_agenda,
                size: 20,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task View',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      showTaskList ? 'Grouped by status' : 'List view',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
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
        );
      },
    );
  }
}
