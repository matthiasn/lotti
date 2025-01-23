import 'dart:async';

import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollama_task_summary.g.dart';

@riverpod
class AiTaskSummaryController extends _$AiTaskSummaryController {
  @override
  String build({required String id}) {
    summarizeEntry();
    return '';
  }

  Future<void> summarizeEntry() async {
    final markdown = await ref.read(
      taskMarkdownControllerProvider(id: id).future,
    );

    state = '';

    if (markdown == null) {
      return;
    }

    final llm = Ollama(
      defaultOptions: const OllamaOptions(
        model: 'llama3.2-vision:latest', // TODO: make configurable
        temperature: 3,
        system: 'The prompt is a markdown document describing a task, '
            'with logbook of the completion of the task. '
            'Summarize the task, the achieved results, and the remaining steps. '
            'Also give me summary of the learnings, if there are any, and '
            'anything else that might be relevant to the task. '
            'Keep it short and succinct. '
            'Be slightly motivational, but not overly so. The goal is to get me '
            'to finish the task.',
      ),
    );

    final prompt = PromptValue.string(markdown);

    final buffer = StringBuffer();
    await llm.stream(prompt).forEach((res) {
      buffer.write(res.outputAsString);
      state = buffer.toString();
    });

    //print(buffer);
  }
}

@riverpod
class TaskMarkdownController extends _$TaskMarkdownController {
  final JournalDb _db = getIt<JournalDb>();

  @override
  Future<String?> build({required String id}) async {
    final entry = await _db.journalEntityById(id);
    final buffer = StringBuffer();

    if (entry == null) {
      return null;
    }

    buffer.writeln(entry.getMarkdown());

    final linkedEntities = await _db.getLinkedEntities(id);

    for (final linked in linkedEntities) {
      buffer
        ..writeln('******')
        ..writeln(linked.getMarkdown(indentation: 1));
    }

    return buffer.toString();
  }
}

extension EntryExtension on JournalEntity {
  String getMarkdown({int indentation = 0}) {
    final headline = maybeMap(
      event: (event) => 'Event: ${event.data.title}',
      task: (task) => 'Task: ${task.data.title}',
      orElse: () => null,
    );

    final attachment = maybeMap(
      journalImage: (image) => image.data.imageFile,
      journalAudio: (audio) => audio.data.audioFile,
      orElse: () => null,
    );
    final attachmentType = maybeMap(
      journalImage: (image) => 'Image file:',
      journalAudio: (audio) => 'Audio file:',
      orElse: () => null,
    );

    final buffer = StringBuffer();

    if (headline != null) {
      buffer
        ..writeln(headline)
        ..writeln(indentation > 0 ? '-------' : '======')
        ..writeln();
    }

    // TODO: use Intl?
    final formattedDate =
        meta.dateFrom.toIso8601String().substring(0, 16).replaceAll('T', ' ');
    buffer
      ..writeln('Date: $formattedDate')
      ..writeln();

    if (categoryId != null) {
      final category =
          getIt<EntitiesCacheService>().getCategoryById(categoryId);
      buffer
        ..writeln('Category: ${category?.name}')
        ..writeln();
    }

    if (attachment != null) {
      buffer
        ..writeln('$attachmentType $attachment')
        ..writeln();
    }

    final markdown = entryText?.markdown;

    if (markdown != null) {
      buffer
        ..write(markdown)
        ..writeln();
    }

    return buffer.toString();
  }
}
