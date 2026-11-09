import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:meta/meta.dart';

/// An entity a reply of hers shows as a preview card: which it is, and the
/// title it had when the turn was walked — what the card says until the
/// live preview has loaded, and still says if the entity is gone.
///
/// The thread stores only this, never the preview itself: the card reads
/// the entity as it is now ([FrontEntityPreview]), so a status changed after
/// the turn is shown changed.
@immutable
class FrontEntityReference {
  const FrontEntityReference({
    required this.kind,
    required this.id,
    required this.title,
  });

  final FrontDestinationKind kind;
  final String id;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is FrontEntityReference &&
      other.kind == kind &&
      other.id == id &&
      other.title == title;

  @override
  int get hashCode => Object.hash(kind, id, title);

  @override
  String toString() => 'FrontEntityReference(${kind.wireName}, $id, $title)';
}

/// What a glance at an entity shows in her chat, before opening it: only the
/// fields its card draws, not the whole domain object.
@immutable
sealed class FrontEntityPreview {
  const FrontEntityPreview({required this.entityId, required this.entityKind});

  final String entityId;
  final FrontDestinationKind entityKind;
}

/// A task as its preview card shows it: its cover, title, its agent's
/// one-liner, status, category, when it is due and how long it is estimated
/// to take.
class FrontTaskPreview extends FrontEntityPreview {
  const FrontTaskPreview({
    required super.entityId,
    required this.title,
    required this.status,
    this.oneLiner,
    this.due,
    this.estimate,
    this.categoryId,
    this.coverArtId,
    this.coverArtCropX = 0.5,
  }) : super(entityKind: FrontDestinationKind.task);

  final String title;
  final TaskStatus status;

  /// The latest report's one-line subtitle; null when there is none.
  final String? oneLiner;
  final DateTime? due;
  final Duration? estimate;
  final String? categoryId;
  final String? coverArtId;

  /// Horizontal crop of the cover (0 left, 0.5 centre, 1 right).
  final double coverArtCropX;

  /// Done or rejected: nothing about it is still to do, so neither when it
  /// is due nor how long it should take is worth showing.
  bool get settled => status is TaskDone || status is TaskRejected;

  @override
  bool operator ==(Object other) =>
      other is FrontTaskPreview &&
      other.entityId == entityId &&
      other.title == title &&
      other.status == status &&
      other.oneLiner == oneLiner &&
      other.due == due &&
      other.estimate == estimate &&
      other.categoryId == categoryId &&
      other.coverArtId == coverArtId &&
      other.coverArtCropX == coverArtCropX;

  @override
  int get hashCode => Object.hash(
    entityId,
    title,
    status,
    oneLiner,
    due,
    estimate,
    categoryId,
    coverArtId,
    coverArtCropX,
  );

  @override
  String toString() => 'FrontTaskPreview($entityId, $title)';
}
