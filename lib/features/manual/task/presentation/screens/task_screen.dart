/* import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/manual/task/presentation/controllers/task_controller.dart';

class TaskManualScreen extends ConsumerWidget {
  const TaskManualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TaskManualController(ref);
    final manualContent = controller.getManualContent();
   // final headerNote = controller.finalNote;

    return Scaffold(
      
      body: Column(
        children: [
        
          const SizedBox(height: 16),
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: manualContent.length,
            itemBuilder: (context, index) {
              final section = manualContent[index];
              return Column(
                children: [
                  const SizedBox(height: 16),
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...section.steps.map((step) => Text(step)).toList(),
                          if (section.imagePath != null) ...[
                            const SizedBox(height: 16),
                            Image.asset(section.imagePath!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
 */
