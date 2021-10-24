import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'journal_entry.freezed.dart';
part 'journal_entry.g.dart';

@freezed
class JournalEntry with _$JournalEntry {
  factory JournalEntry({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    required int utcOffset,
    required String timezone,
    DateTime? updatedAt,
    String? transcript,
    double? latitude,
    double? longitude,
    VectorClock? vectorClock,
    String? imageFile,
    String? imageDirectory,
    String? plainText,
    String? markdown,
    String? quill,
  }) = _JournalEntry;

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);
}
