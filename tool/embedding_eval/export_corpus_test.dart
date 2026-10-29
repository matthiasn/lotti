// Exports the penguin demo world, in every language the demo seed speaks, as
// the retrieval corpus `tool/embedding_eval/evaluate.py` scores embedding
// models on. Not part of the test suite — run it on purpose:
//
//   fvm flutter test tool/embedding_eval/export_corpus_test.dart
//
// Writes `build/embedding_eval/corpus.json` (or `EMBEDDING_EVAL_CORPUS`).
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/search_document.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';

/// The text an entity is embedded as: its title, then its body.
String _text(JournalEntity entity) {
  final document = searchDocumentFor(entity, measurableDataType: (_) => null);
  return [
    document.title,
    document.body,
  ].where((part) => part.trim().isNotEmpty).join('\n').trim();
}

Map<String, Object> _language(String code) {
  final world = ManualDemoWorld.penguinLogistics(
    translate: demoSeedTextForLocale(Locale(code)),
    now: manualDemoNow,
  );
  final tasks = {for (final task in world.tasks) task.meta.id: task};
  final checklistTasks = {
    for (final checklist in world.checklists)
      checklist.meta.id: checklist.data.linkedTasks,
  };

  // Every child that belongs to exactly one task is a query whose answer is
  // that task: a checklist item through its checklist, a note or time record
  // through the link from its task.
  final queries = <Map<String, String>>[];
  void add(JournalEntity child, String type, Iterable<String> taskIds) {
    final owners = taskIds.where(tasks.containsKey).toSet();
    final text = _text(child);
    if (owners.length != 1 || text.isEmpty) return;
    queries.add({
      'id': child.meta.id,
      'type': type,
      'text': text,
      'task': owners.single,
    });
  }

  for (final item in world.checklistItems) {
    add(item, 'checklist_item', [
      for (final checklistId in item.data.linkedChecklists)
        ...?checklistTasks[checklistId],
    ]);
  }
  final linkedFrom = <String, Set<String>>{};
  for (final link in world.links) {
    (linkedFrom[link.toId] ??= {}).add(link.fromId);
  }
  // A time record without words is no query; `add` skips the empty ones.
  for (final entry in [...world.entries, ...world.timeRecords]) {
    add(entry, 'note', linkedFrom[entry.meta.id] ?? const {});
  }

  return {
    'tasks': [
      for (final task in tasks.values)
        {'id': task.meta.id, 'text': _text(task)},
    ],
    'queries': queries,
  };
}

void main() {
  test('export the multilingual demo corpus', () {
    final corpus = {
      for (final code in demoSeedLanguageCodes) code: _language(code),
    };
    final path =
        Platform.environment['EMBEDDING_EVAL_CORPUS'] ??
        'build/embedding_eval/corpus.json';
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(corpus));

    final english = corpus['en']!;
    expect(english['tasks'], hasLength(28));
    expect((english['queries']! as List).length, greaterThan(100));
  });
}
