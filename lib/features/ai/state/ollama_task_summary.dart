import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:ollama/ollama.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollama_task_summary.g.dart';

@riverpod
class AiTaskSummaryController extends _$AiTaskSummaryController {
  final JournalDb _db = getIt<JournalDb>();

  @override
  String build({
    required String id,
    required bool processImages,
  }) {
    summarizeEntry();
    return '';
  }

  Future<void> summarizeEntry() async {
    final start = DateTime.now();
    final entry = await _db.journalEntityById(id);

    final markdown = await ref.read(
      taskMarkdownControllerProvider(id: id).future,
    );

    state = '';

    if (markdown == null) {
      return;
    }

    const systemMessage =
        'The prompt is a markdown document describing a task, '
        'with logbook of the completion of the task. '
        'Also, there might be checklist items with a status of either '
        'COMPLETED or TO DO. '
        'Summarize the task, the achieved results, and the remaining steps '
        'that have not been completed yet. '
        'Note any learnings or insights that can be drawn from the task, if any. '
        'If there are images, include their content in the summary. '
        'Consider that the content of the images, likely screenshots, '
        'are related to the completion of the task. '
        'Note that the logbook is in reverse chronological order. '
        'Keep it short and succinct. '
        'Calculate total time spent on the task. ';

    final llm = Ollama();
    final buffer = StringBuffer();
    final images =
        processImages && entry is Task ? await getImages(entry) : null;

    const model = 'deepseek-r1:8b'; // TODO: make configurable
    const temperature = 0.6;

    final stream = llm.generate(
      markdown,
      model: model,
      system: systemMessage,
      options: ModelOptions(
        temperature: temperature,
      ),
      images: images,
    );

    await for (final chunk in stream) {
      buffer.write(chunk.text);
      state = buffer.toString();
    }

    final completeResponse = buffer.toString();
    final [thoughts, response] = completeResponse.split('</think>');

    final data = AiResponseData(
      model: model,
      temperature: temperature,
      systemMessage: systemMessage,
      prompt: markdown,
      thoughts: thoughts.replaceAll('<think>', ''),
      response: response,
    );

    await getIt<PersistenceLogic>().createAiResponseEntry(
      data: data,
      dateFrom: start,
      linkedId: id,
      categoryId: entry?.categoryId,
    );
  }

  Future<List<String>> getImages(Task task) async {
    final linkedEntities = await _db.getLinkedEntities(id);
    final imageEntries = linkedEntities.whereType<JournalImage>();
    final base64Images = <String>[];

    for (final imageEntry in imageEntries) {
      final fullPath = getFullImagePath(imageEntry);
      final bytes = await File(fullPath).readAsBytes();
      final base64String = base64Encode(bytes);
      base64Images.add(base64String);
    }

    return base64Images;
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

    if (entry is Task) {
      await addChecklistSection(
        entry,
        buffer: buffer,
      );
    }

    final linkedEntities = await _db.getLinkedEntities(id);

    for (final linked in linkedEntities) {
      buffer
        ..writeln('******')
        ..writeln('Linked:')
        ..writeln(linked.getMarkdown(indentation: 1));
    }

    return buffer.toString();
  }

  Future<void> addChecklistSection(
    Task task, {
    required StringBuffer buffer,
  }) async {
    final checklistIds = task.data.checklistIds ?? [];

    if (checklistIds.isEmpty) {
      return;
    }

    buffer
      ..writeln('******')
      ..writeln('Checklists:')
      ..writeln();

    for (final checklistId in checklistIds) {
      final checklist = await _db.journalEntityById(checklistId);
      if (checklist != null && checklist is Checklist) {
        buffer
          ..writeln(checklist.data.title)
          ..writeln();

        final checklistItemIds = checklist.data.linkedChecklistItems;
        for (final checklistItemId in checklistItemIds) {
          final checklistItem = await _db.journalEntityById(checklistItemId);
          if (checklistItem != null && checklistItem is ChecklistItem) {
            final data = checklistItem.data;
            buffer
              ..writeln(
                '${data.isChecked ? 'COMPLETED' : 'TO DO'}: ${data.title}',
              )
              ..writeln();
          }
        }
        buffer.writeln();
      }
    }

    buffer
      ..writeln('******')
      ..writeln()
      ..writeln();
  }
}

extension EntryExtension on JournalEntity {
  String getMarkdown({int indentation = 0}) {
    final headline = maybeMap(
      event: (event) => 'Event: ${event.data.title}',
      task: (task) {
        final status = task.data.status.map(
          open: (_) => 'OPEN',
          groomed: (_) => 'GROOMED',
          started: (_) => 'STARTED',
          inProgress: (_) => 'IN PROGRESS',
          blocked: (_) => 'BLOCKED',
          onHold: (_) => 'ON HOLD',
          done: (_) => 'DONE',
          rejected: (_) => 'REJECTED',
        );
        return 'Task: ${task.data.title} - Status: $status';
      },
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
        ..writeln('${indentation > 0 ? '#' : '##'} $headline')
        ..writeln();
    }

    // TODO: use Intl?
    final formattedDate =
        meta.dateFrom.toIso8601String().substring(0, 16).replaceAll('T', ' ');
    buffer
      ..writeln('Date: $formattedDate')
      ..writeln();

    final duration = entryDuration(this);

    if (duration.inSeconds > 10) {
      buffer
        ..writeln('Time spent: ${formatDuration(duration)}')
        ..writeln();
    }

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
