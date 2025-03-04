import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/manual/task/presentation/controllers/task_controller.dart';
import 'package:lotti/features/manual/task/presentation/widgets/manual_content_row.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TaskManualController(ref);
    final manualContent = controller.getManualContent();
    final taskHeader = controller.taskHeader;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              child: Text(
                taskHeader,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...manualContent
                      .map((content) => ManualContentRow(content: content)),
                  // Your remaining widgets...
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
