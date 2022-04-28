import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'tag_type_definitions.freezed.dart';
part 'tag_type_definitions.g.dart';

@freezed
class TagEntity with _$TagEntity {
  factory TagEntity.genericTag({
    required String id,
    required String tag,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    bool? inactive,
  }) = GenericTag;

  factory TagEntity.personTag({
    required String id,
    required String tag,
    String? firstName,
    String? lastName,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    bool? inactive,
  }) = PersonTag;

  factory TagEntity.storyTag({
    required String id,
    required String tag,
    String? description,
    String? longTitle,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    bool? inactive,
  }) = StoryTag;

  factory TagEntity.fromJson(Map<String, dynamic> json) =>
      _$TagEntityFromJson(json);
}
