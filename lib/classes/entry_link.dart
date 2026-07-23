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
    bool? collapsed,
    DateTime? deletedAt,
  }) = RatingLink;

  const factory EntryLink.project({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) = ProjectLink;

  /// `fromId` blocks `toId`; rendered as "is blocked by" from `toId`'s side.
  /// See ADR 0042 decision 1.
  const factory EntryLink.blocks({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) = BlocksLink;

  /// `fromId` follows up on `toId`; rendered as "has follow-up" from
  /// `toId`'s side. See ADR 0042 decision 1.
  const factory EntryLink.followsUp({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) = FollowsUpLink;

  /// `fromId` duplicates `toId` (`toId` is canonical); rendered as
  /// "is duplicated by" from `toId`'s side. See ADR 0042 decision 1.
  const factory EntryLink.duplicates({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) = DuplicatesLink;

  /// `fromId` fixes the defect tracked by `toId`; rendered as "is fixed by"
  /// from `toId`'s side. See ADR 0042 decision 1.
  const factory EntryLink.fixes({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) = FixesLink;

  /// `fromId` supersedes `toId` (`toId` is obsolete); rendered as
  /// "is superseded by" from `toId`'s side. See ADR 0042 decision 1.
  const factory EntryLink.supersedes({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) = SupersedesLink;

  factory EntryLink.fromJson(Map<String, dynamic> json) =>
      _$EntryLinkFromJson(json);
}

/// The closed vocabulary of task-relationship semantics an [EntryLink] can
/// carry, plus the pre-existing untyped variants. Growing this enum requires
/// an ADR 0042 amendment (see "the typed vocabulary is closed by design").
enum EntryLinkType {
  basic,
  rating,
  project,
  blocks,
  followsUp,
  duplicates,
  fixes,
  supersedes,
}

/// Builds the [EntryLink] union member matching this [EntryLinkType], so
/// creation call sites can select the relationship semantics through one
/// parameter instead of naming the factory constructor directly.
extension EntryLinkTypeFactory on EntryLinkType {
  EntryLink buildLink({
    required String id,
    required String fromId,
    required String toId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required VectorClock? vectorClock,
    bool? hidden,
    bool? collapsed,
    DateTime? deletedAt,
  }) {
    switch (this) {
      case EntryLinkType.basic:
        return EntryLink.basic(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
      case EntryLinkType.rating:
        return EntryLink.rating(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
      case EntryLinkType.project:
        return EntryLink.project(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
      case EntryLinkType.blocks:
        return EntryLink.blocks(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
      case EntryLinkType.followsUp:
        return EntryLink.followsUp(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
      case EntryLinkType.duplicates:
        return EntryLink.duplicates(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
      case EntryLinkType.fixes:
        return EntryLink.fixes(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
      case EntryLinkType.supersedes:
        return EntryLink.supersedes(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: vectorClock,
          hidden: hidden,
          collapsed: collapsed,
          deletedAt: deletedAt,
        );
    }
  }
}
