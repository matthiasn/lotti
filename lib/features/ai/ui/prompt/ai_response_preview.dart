import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/ollama_prompt.dart';

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
