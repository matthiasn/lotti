import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/ollama_task_summary.dart';

class AiTaskSummaryView extends ConsumerWidget {
  const AiTaskSummaryView({
    required this.id,
    super.key,
  });

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markdown =
        ref.watch(taskMarkdownControllerProvider(id: id)).valueOrNull;
    final summary = ref.watch(aiTaskSummaryControllerProvider(id: id));

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 600),
          child: Column(
            children: [
              MarkdownBody(data: summary),
              const SizedBox(height: 200),
              if (markdown != null) MarkdownBody(data: markdown),
            ],
          ),
        ),
      ),
    );
  }
}
