import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_ui/material_ui.dart';

class TaskCounts extends StatelessWidget {
  const TaskCounts({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        children: [
          Text(
            'Tasks:',
            style: searchLabelStyle(),
          ),
          TasksCountWidget(
            status: 'OPEN',
            label: context.messages.taskStatusOpen,
          ),
          TasksCountWidget(
            status: 'IN PROGRESS',
            label: context.messages.taskStatusInProgress,
          ),
          TasksCountWidget(
            status: 'ON HOLD',
            label: context.messages.taskStatusOnHold,
          ),
          TasksCountWidget(
            status: 'BLOCKED',
            label: context.messages.taskStatusBlocked,
          ),
          TasksCountWidget(
            status: 'DONE',
            label: context.messages.taskStatusDone,
          ),
        ],
      ),
    );
  }
}

class TasksCountWidget extends ConsumerWidget {
  const TasksCountWidget({
    required this.status,
    required this.label,
    super.key,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: ref.watch(journalDbProvider).getTasksCount(statuses: [status]),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<int> snapshot,
          ) {
            if (snapshot.data == null) {
              return const SizedBox.shrink();
            } else {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${snapshot.data} $label',
                  style: searchLabelStyle(),
                ),
              );
            }
          },
    );
  }
}

class FlaggedCount extends ConsumerWidget {
  const FlaggedCount({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: ref.watch(journalDbProvider).getCountImportFlagEntries(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<int> snapshot,
          ) {
            final count = snapshot.data;
            return Text(
              'Flagged: $count',
              style: searchLabelStyle(),
            );
          },
    );
  }
}
