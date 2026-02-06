import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'entry_link.g.dart';
part 'entry_link.freezed.dart';

@Freezed(fallbackUnion: 'basic')
abstract class EntryLink with _$EntryLink {
  const factory EntryLink.basic({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) = BasicLink;

  const factory EntryLink.rating({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    DateTime? deletedAt,
  }) = RatingLink;

  factory EntryLink.fromJson(Map<String, dynamic> json) =>
      _$EntryLinkFromJson(json);
}
