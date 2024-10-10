import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/ollama_prompt.dart';
import 'package:lotti/features/ai/state/ollama_prompt_checklist.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_widget.dart';

class AiResponsePreview extends ConsumerWidget {
  const AiResponsePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responseText = ref.watch(aiResponseProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 600),
          child: MarkdownBody(data: responseText),
        ),
      ),
    );
  }
}

class AiChecklistResponsePreview extends ConsumerWidget {
  const AiChecklistResponsePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(aiChecklistResponseProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 600),
          child: Column(
            children: [
              for (final item in items)
                CheckboxItemWidget(
                  title: item.title,
                  isChecked: false,
                  onChanged: (checked) {},
                ),
            ],
          ),
        ),
      ),
    );
  }
}
