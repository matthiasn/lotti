import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';

/// What one of the avatar sheet's actions came to.
enum AvatarPhotoOutcome {
  /// The person was written.
  changed,

  /// The user backed out somewhere along the way; nothing was written.
  cancelled,

  /// The write was refused.
  failed,
}

/// The three things the avatar sheet can do to a person's photo — choose,
/// re-crop, remove — as one object whose only dependencies are the two
/// repositories and the two surfaces it opens, both handed in as functions.
///
/// The surfaces are functions rather than widgets so the whole flow — pick,
/// then crop, then write, or back out at either step — can be exercised in a
/// plain test with fakes, without a picker or a sheet on screen. The sheet
/// widget is then only rows that call these.
class AvatarPhotoActions {
  const AvatarPhotoActions({
    required this.relationships,
    required this.journal,
    required this.pickImage,
    required this.chooseCrop,
  });

  final RelationshipRepository relationships;
  final JournalRepository journal;

  /// Opens the picker and imports the choice as a `JournalImage` linked to
  /// the person, returning its id — or null when the user backed out.
  final Future<String?> Function() pickImage;

  /// Opens the crop surface over the image, starting from the given framing
  /// (null for the default), and returns the framing the user committed — or
  /// null when they cancelled.
  final Future<AvatarCrop?> Function(String imageId, AvatarCrop? initial)
  chooseCrop;

  /// Choose a photograph from the library, frame it, and make it the avatar.
  ///
  /// The picker has to import the picture before the crop surface can show
  /// it, so by the time the user sees *Use photo* an entry already exists.
  /// Cancelling there must still leave nothing behind (design: "cancelling
  /// writes nothing"), so the freshly imported entry is deleted again — it
  /// exists only to be this person's photo, and nobody has seen it anywhere
  /// else.
  Future<AvatarPhotoOutcome> choose(RelationshipEntry person) async {
    final imageId = await pickImage();
    if (imageId == null) return AvatarPhotoOutcome.cancelled;
    final crop = await chooseCrop(imageId, null);
    if (crop == null) {
      await journal.deleteJournalEntity(imageId);
      return AvatarPhotoOutcome.cancelled;
    }
    return _write(
      person,
      person.data.copyWith(avatarImageId: imageId, avatarCrop: crop),
    );
  }

  /// Re-frame the photograph the person already has. The crop is a transform
  /// over the original, so only the three numbers change.
  Future<AvatarPhotoOutcome> adjust(RelationshipEntry person) async {
    final imageId = person.data.avatarImageId;
    if (imageId == null) return AvatarPhotoOutcome.cancelled;
    final crop = await chooseCrop(imageId, person.data.avatarCrop);
    if (crop == null) return AvatarPhotoOutcome.cancelled;
    return _write(person, person.data.copyWith(avatarCrop: crop));
  }

  /// Take the photograph off the person.
  ///
  /// Clears the reference and its framing and leaves the image entry where
  /// it is — the task cover-art precedent (`setCoverArt(null)`): removing a
  /// picture from one place is not deleting it from the journal.
  Future<AvatarPhotoOutcome> remove(RelationshipEntry person) => _write(
    person,
    person.data.copyWith(avatarImageId: null, avatarCrop: null),
  );

  Future<AvatarPhotoOutcome> _write(
    RelationshipEntry person,
    RelationshipData data,
  ) async {
    final ok = await relationships.updateRelationship(
      person.copyWith(data: data),
    );
    return ok ? AvatarPhotoOutcome.changed : AvatarPhotoOutcome.failed;
  }
}
