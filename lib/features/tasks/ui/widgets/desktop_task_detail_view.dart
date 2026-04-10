import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/task_detail_record_provider.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

/// Desktop entry detail view that renders the Figma-designed task detail
/// layout using real data from providers.
///
/// Bridges the showcase detail pane with live task data
/// via the task detail record provider, enabling the new desktop design while
/// keeping the legacy detail page for mobile.
class DesktopTaskDetailView extends ConsumerWidget {
  const DesktopTaskDetailView({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(taskDetailRecordProvider(taskId));

    return recordAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: TaskShowcasePalette.accent(context),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (record) {
        if (record == null) {
          return const SizedBox.shrink();
        }
        return TaskDetailPane(
          key: ValueKey(taskId),
          record: record,
        );
      },
    );
  }
}
