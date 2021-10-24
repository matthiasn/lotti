import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/task.dart';
import 'package:wisely/sync/vector_clock.dart';

import 'entry_text.dart';

part 'journal_entry.freezed.dart';
part 'journal_entry.g.dart';

@freezed
class CheckListItem with _$CheckListItem {
  factory CheckListItem({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    required String plainText,
    Geolocation? geolocation,
    DateTime? updatedAt,
  }) = _CheckListItem;

  factory CheckListItem.fromJson(Map<String, dynamic> json) =>
      _$CheckListItemFromJson(json);
}

@freezed
class JournalEntry with _$JournalEntry {
  factory JournalEntry({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    DateTime? updatedAt,
    Geolocation? geolocation,
    VectorClock? vectorClock,
    EntryText? entryText,
    List<String>? linkedImageIds,
    List<String>? linkedAudioNoteIds,
    Task? task,
  }) = _JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);
}
