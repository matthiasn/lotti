import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TaskSearchModeFilter extends ConsumerWidget {
  const TaskSearchModeFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    if (!state.enableVectorSearch) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.tasksSearchModeLabel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<SearchMode>(
          selected: {state.searchMode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            controller.setSearchMode(selection.first);
          },
          segments: [
            ButtonSegment<SearchMode>(
              value: SearchMode.fullText,
              label: Text(context.messages.searchModeFullText),
              icon: const Icon(Icons.text_fields, size: 18),
            ),
            ButtonSegment<SearchMode>(
              value: SearchMode.vector,
              label: Text(context.messages.searchModeVector),
              icon: const Icon(Icons.hub_outlined, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
