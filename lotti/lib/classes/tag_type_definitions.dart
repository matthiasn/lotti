import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/sync/vector_clock.dart';

part 'tag_type_definitions.freezed.dart';
part 'tag_type_definitions.g.dart';

@freezed
class TagTypeDefinition with _$TagTypeDefinition {
  factory TagTypeDefinition.tagDefinition({
    required String id,
    required String tag,
    required bool private,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    DateTime? deletedAt,
    bool? inactive,
  }) = TagDefinition;

  factory TagTypeDefinition.personTagDefinition({
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
  }) = PersonTagDefinition;

  factory TagTypeDefinition.storyTagDefinition({
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
  }) = StoryTagDefinition;

  factory TagTypeDefinition.fromJson(Map<String, dynamic> json) =>
      _$TagTypeDefinitionFromJson(json);
}
