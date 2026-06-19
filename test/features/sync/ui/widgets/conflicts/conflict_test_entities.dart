import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Shared entity builders for the conflict-resolution unit tests (diff engine
/// and merge assembler). Deterministic dates; only the parts that vary between
/// tests are parameters.

Metadata metaOf({
  String id = 'e1',
  String? categoryId,
  bool? starred,
  bool? private,
  EntryFlag? flag,
  DateTime? deletedAt,
  DateTime? dateFrom,
  DateTime? dateTo,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) => Metadata(
  id: id,
  createdAt: DateTime(2024, 3, 15, 8),
  updatedAt: updatedAt ?? DateTime(2024, 3, 15, 10),
  dateFrom: dateFrom ?? DateTime(2024, 3, 15, 9),
  dateTo: dateTo ?? DateTime(2024, 3, 15, 11),
  categoryId: categoryId,
  starred: starred,
  private: private,
  flag: flag,
  deletedAt: deletedAt,
  vectorClock: vectorClock ?? const VectorClock({'a': 1}),
);

JournalEntity entryOf({
  String text = 'baseline note',
  String? categoryId,
  bool? starred,
  bool? private,
  EntryFlag? flag,
  DateTime? deletedAt,
  DateTime? dateFrom,
  DateTime? dateTo,
  DateTime? updatedAt,
  VectorClock? vectorClock,
}) => JournalEntry(
  meta: metaOf(
    categoryId: categoryId,
    starred: starred,
    private: private,
    flag: flag,
    deletedAt: deletedAt,
    dateFrom: dateFrom,
    dateTo: dateTo,
    updatedAt: updatedAt,
    vectorClock: vectorClock,
  ),
  entryText: text.isEmpty ? null : EntryText(plainText: text),
);

JournalEntity taskOf({
  String title = 'Baseline task',
  String text = 'task notes',
  Duration? estimate,
  VectorClock? vectorClock,
}) => Task(
  meta: metaOf(id: 'task-1', starred: true, vectorClock: vectorClock),
  data: TaskData(
    title: title,
    dateFrom: DateTime(2024, 3, 15, 9),
    dateTo: DateTime(2024, 3, 15, 11),
    statusHistory: const [],
    status: TaskStatus.open(
      id: 'st-1',
      createdAt: DateTime(2024, 3, 15, 9),
      utcOffset: 0,
    ),
    estimate: estimate,
  ),
  entryText: EntryText(plainText: text),
);

JournalEntity audioOf({required Duration duration}) => JournalAudio(
  meta: metaOf(id: 'audio-1'),
  data: AudioData(
    dateFrom: DateTime(2024, 3, 15, 9),
    dateTo: DateTime(2024, 3, 15, 11),
    audioFile: 'a.m4a',
    audioDirectory: '/audio',
    duration: duration,
  ),
);
