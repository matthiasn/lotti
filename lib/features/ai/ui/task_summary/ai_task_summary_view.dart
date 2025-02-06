import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai/state/ollama_task_checklist_summary.dart';

class AiTaskSummaryView extends ConsumerWidget {
  const AiTaskSummaryView({
    required this.id,
    super.key,
  });

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      aiTaskChecklistSummaryControllerProvider(
        id: id,
      ),
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 600),
          child: Column(
            children: [
              SelectionArea(
                child: GptMarkdown(state.summary ?? ''),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
