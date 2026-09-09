import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/logic/image_import.dart';

/// What one of the avatar sheet's actions came to.
enum PersonPhotoOutcome {
  /// The person was written.
  changed,

  /// The user backed out somewhere along the way; nothing was written.
  cancelled,

  /// The write was refused.
  failed,
}

/// Everything a surface can do to a person's two images — choose, re-crop
/// or remove the avatar; choose, reposition or remove the banner — as one
/// object whose only dependencies are the two repositories and the two
/// surfaces it opens, both handed in as functions.
///
/// The surfaces are functions rather than widgets so the whole flow — pick,
/// then crop, then write, or back out at either step — can be exercised in a
/// plain test with fakes, without a picker or a sheet on screen. The avatar
/// sheet and the form's Photo card are then only controls that call these,
/// and they cannot disagree about what a write contains.
class PersonPhotoActions {
  const PersonPhotoActions({
    required this.relationships,
    required this.journal,
    required this.pickImage,
    required this.chooseCrop,
  });

  final RelationshipRepository relationships;
  final JournalRepository journal;

  /// Opens the picker and imports the choice as a `JournalImage` linked to
  /// the person — its id, and whether the import *created* that entry — or
  /// null when the user backed out.
  final Future<ImportedImage?> Function() pickImage;

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
  /// writes nothing"), so an entry the import *created* is deleted again — it
  /// exists only to be this person's photo, and nobody has seen it anywhere
  /// else. A photo imported before resolves to its existing entry instead
  /// (`ImportedImage.created` false); that one is already the journal's and
  /// stays. The same discard follows a write that is refused or throws.
  Future<PersonPhotoOutcome> chooseAvatar(RelationshipEntry person) async {
    final picked = await pickImage();
    if (picked == null) return PersonPhotoOutcome.cancelled;
    final crop = await chooseCrop(picked.id, null);
    if (crop == null) {
      await _discard(picked);
      return PersonPhotoOutcome.cancelled;
    }
    return _writeOrDiscard(
      person,
      person.data.copyWith(avatarImageId: picked.id, avatarCrop: crop),
      picked,
    );
  }

  /// Re-frame the photograph the person already has. The crop is a transform
  /// over the original, so only the three numbers change.
  Future<PersonPhotoOutcome> adjustAvatar(RelationshipEntry person) async {
    final imageId = person.data.avatarImageId;
    if (imageId == null) return PersonPhotoOutcome.cancelled;
    final crop = await chooseCrop(imageId, person.data.avatarCrop);
    if (crop == null) return PersonPhotoOutcome.cancelled;
    return _write(person, person.data.copyWith(avatarCrop: crop));
  }

  /// Take the photograph off the person.
  ///
  /// Clears the reference and its framing and leaves the image entry where
  /// it is — the task cover-art precedent (`setCoverArt(null)`): removing a
  /// picture from one place is not deleting it from the journal.
  Future<PersonPhotoOutcome> removeAvatar(RelationshipEntry person) => _write(
    person,
    person.data.copyWith(avatarImageId: null, avatarCrop: null),
  );

  /// Choose a wide picture for the person's page. It starts centred; the
  /// form's Photo card lets the user drag it into place afterwards.
  Future<PersonPhotoOutcome> chooseBanner(RelationshipEntry person) async {
    final picked = await pickImage();
    if (picked == null) return PersonPhotoOutcome.cancelled;
    return _writeOrDiscard(
      person,
      person.data.copyWith(bannerImageId: picked.id, bannerCropX: 0.5),
      picked,
    );
  }

  /// Slide the banner left or right: [cropX] is the `BoxFit.cover`
  /// alignment, `0` hugging the left edge and `1` the right. The repository
  /// clamps it, so a gesture's rounding cannot store an edge the hero would
  /// have to guess at.
  Future<PersonPhotoOutcome> repositionBanner(
    RelationshipEntry person,
    double cropX,
  ) => _write(person, person.data.copyWith(bannerCropX: cropX));

  /// Take the banner off the person's page. Like [removeAvatar], the entry
  /// stays in the journal; only the reference and its framing go.
  Future<PersonPhotoOutcome> removeBanner(RelationshipEntry person) => _write(
    person,
    person.data.copyWith(bannerImageId: null, bannerCropX: 0.5),
  );

  Future<PersonPhotoOutcome> _write(
    RelationshipEntry person,
    RelationshipData data,
  ) async {
    final ok = await relationships.updateRelationship(
      person.copyWith(data: data),
    );
    return ok ? PersonPhotoOutcome.changed : PersonPhotoOutcome.failed;
  }

  /// [_write], taking the picture the flow just imported back out of the
  /// journal when the write is refused or throws: it was imported only to be
  /// this person's, and after a refused write nothing references it.
  Future<PersonPhotoOutcome> _writeOrDiscard(
    RelationshipEntry person,
    RelationshipData data,
    ImportedImage picked,
  ) async {
    final PersonPhotoOutcome outcome;
    try {
      outcome = await _write(person, data);
    } catch (_) {
      await _discard(picked);
      rethrow;
    }
    if (outcome == PersonPhotoOutcome.failed) await _discard(picked);
    return outcome;
  }

  /// Deletes [picked] again — only if this flow's import created it. An
  /// entry the import merely found is the journal's already, whoever else
  /// references it, and is not this flow's to remove.
  Future<void> _discard(ImportedImage picked) async {
    if (picked.created) await journal.deleteJournalEntity(picked.id);
  }
}
