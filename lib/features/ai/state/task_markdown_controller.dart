import 'dart:async';

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_markdown_controller.g.dart';

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
      if (linked is JournalEntry ||
          linked is JournalImage ||
          linked is JournalAudio) {
        buffer
          ..writeln('******')
          ..writeln('Linked:')
          ..writeln(linked.getMarkdown(indentation: 1));
      }
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
      ..writeln('Checklist:')
      ..writeln('```json')
      ..writeln('[');

    final checklistItems = <ChecklistItemData>[];

    for (final checklistId in checklistIds) {
      final checklist = await _db.journalEntityById(checklistId);
      if (checklist != null && checklist is Checklist) {
        final checklistItemIds = checklist.data.linkedChecklistItems;
        for (final checklistItemId in checklistItemIds) {
          final checklistItem = await _db.journalEntityById(checklistItemId);
          if (checklistItem != null && checklistItem is ChecklistItem) {
            final data = checklistItem.data.copyWith(id: checklistItemId);
            checklistItems.add(data);
            buffer.writeln('\n${data.toJson()},\n');
          }
        }
      }
    }

    buffer
      ..writeln(']')
      ..writeln('```')
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
