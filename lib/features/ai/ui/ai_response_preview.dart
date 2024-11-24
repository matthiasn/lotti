import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/ollama_prompt.dart';
import 'package:lotti/features/ai/state/ollama_prompt_checklist.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/misc/buttons.dart';

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
  const AiChecklistResponsePreview({
    required this.linkedFromId,
    super.key,
  });

  final String? linkedFromId;

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
              const Text('Select the items that are relevant to you:'),
              for (final item in items)
                CheckboxItemWidget(
                  title: item.title,
                  isChecked: false,
                  onChanged: (checked) {},
                ),
              Button(
                'Create checklist',
                onPressed: () {
                  getIt<PersistenceLogic>().createChecklist(
                    taskId: linkedFromId,
                    items: items,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
