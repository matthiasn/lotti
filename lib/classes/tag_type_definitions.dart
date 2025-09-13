import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'tag_type_definitions.freezed.dart';
part 'tag_type_definitions.g.dart';

@freezed
sealed class TagEntity with _$TagEntity {
  const factory TagEntity.genericTag({
    required String id,
    required String tag,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    bool? inactive,
  }) = GenericTag;

  const factory TagEntity.personTag({
    required String id,
    required String tag,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    String? firstName,
    String? lastName,
    DateTime? deletedAt,
    bool? inactive,
  }) = PersonTag;

  const factory TagEntity.storyTag({
    required String id,
    required String tag,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    String? description,
    String? longTitle,
    DateTime? deletedAt,
    bool? inactive,
  }) = StoryTag;

  factory TagEntity.fromJson(Map<String, dynamic> json) =>
      _$TagEntityFromJson(json);
}
