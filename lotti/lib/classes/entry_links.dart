import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'entry_links.freezed.dart';
part 'entry_links.g.dart';

@freezed
class EntryLink with _$EntryLink {
  factory EntryLink.basic({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
  }) = BasicLink;

  factory EntryLink.fromJson(Map<String, dynamic> json) =>
      _$EntryLinkFromJson(json);
}
