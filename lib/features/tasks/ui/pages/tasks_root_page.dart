import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/utils/consts.dart';

class TasksRootPage extends ConsumerWidget {
  const TasksRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(configFlagProvider(enableTasksRedesignFlag)).value ?? false;

    return enabled
        ? const TasksTabPage()
        : const InfiniteJournalPage(showTasks: true);
  }
}
