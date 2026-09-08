import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_actions.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final at = DateTime(2026, 8, 13, 14);
  const crop = AvatarCrop(x: 0.3, y: 0.4, scale: 2);
  const newCrop = AvatarCrop(x: 0.6, y: 0.1, scale: 1.5);

  late MockRelationshipRepository relationships;
  late MockJournalRepository journal;

  /// What the fakes were asked, so a test can say the surfaces opened in the
  /// right order with the right arguments — or did not open at all.
  late List<String> log;
  late String? pickResult;
  var pickCreated = true;
  late AvatarCrop? cropResult;

  RelationshipEntry person({String? avatarImageId, AvatarCrop? avatarCrop}) =>
      RelationshipEntry(
        meta: Metadata(
          id: 'rel-1',
          createdAt: at,
          updatedAt: at,
          dateFrom: at,
          dateTo: at,
        ),
        data: RelationshipData(
          title: 'Pip',
          avatarImageId: avatarImageId,
          avatarCrop: avatarCrop,
          status: RelationshipStatus.active(
            id: 'status-1',
            createdAt: at,
            utcOffset: 0,
          ),
        ),
      );

  PersonPhotoActions actions() => PersonPhotoActions(
    relationships: relationships,
    journal: journal,
    pickImage: () async {
      log.add('pick');
      final id = pickResult;
      return id == null ? null : (id: id, created: pickCreated);
    },
    chooseCrop: (imageId, initial) async {
      log.add('crop $imageId from ${initial?.x}');
      return cropResult;
    },
  );

  /// The person as it was written, or null when nothing was.
  RelationshipData? written() {
    final calls = verify(
      () => relationships.updateRelationship(captureAny()),
    ).captured;
    return calls.isEmpty ? null : (calls.single as RelationshipEntry).data;
  }

  setUp(() {
    relationships = MockRelationshipRepository();
    journal = MockJournalRepository();
    log = [];
    pickResult = 'image-new';
    pickCreated = true;
    cropResult = newCrop;
    when(
      () => relationships.updateRelationship(any()),
    ).thenAnswer((_) async => true);
    when(
      () => journal.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
  });

  group('choose', () {
    test(
      'backing out of the picker writes nothing and opens nothing else',
      () async {
        pickResult = null;

        expect(
          await actions().chooseAvatar(person()),
          PersonPhotoOutcome.cancelled,
        );

        expect(log, ['pick']);
        verifyNever(() => relationships.updateRelationship(any()));
        verifyNever(() => journal.deleteJournalEntity(any()));
      },
    );

    test('cancelling the crop deletes the entry the picker had already '
        'imported, so cancelling leaves nothing behind', () async {
      cropResult = null;

      expect(
        await actions().chooseAvatar(person()),
        PersonPhotoOutcome.cancelled,
      );

      expect(log, ['pick', 'crop image-new from null']);
      verify(() => journal.deleteJournalEntity('image-new')).called(1);
      verifyNever(() => relationships.updateRelationship(any()));
    });

    test('committing writes the image and the framing together', () async {
      expect(
        await actions().chooseAvatar(person()),
        PersonPhotoOutcome.changed,
      );

      final data = written()!;
      expect(data.avatarImageId, 'image-new');
      expect(data.avatarCrop, newCrop);
      verifyNever(() => journal.deleteJournalEntity(any()));
    });

    test('the crop surface starts from the default framing for a new photo, '
        'even when the person had one before', () async {
      await actions().chooseAvatar(
        person(avatarImageId: 'old', avatarCrop: crop),
      );

      expect(
        log.last,
        'crop image-new from null',
        reason: 'a framing chosen for a different picture must not carry over',
      );
    });

    test('a refused write is reported as failed', () async {
      when(
        () => relationships.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      expect(await actions().chooseAvatar(person()), PersonPhotoOutcome.failed);
    });
    test(
      'cancelling the crop leaves an entry the import merely found alone — a '
      "gallery photo imported before is the journal's, not this flow's",
      () async {
        pickCreated = false;
        cropResult = null;

        expect(
          await actions().chooseAvatar(person()),
          PersonPhotoOutcome.cancelled,
        );

        verifyNever(() => journal.deleteJournalEntity(any()));
      },
    );

    test(
      'a refused write takes the entry the import created back out, so a '
      'photo nobody references does not linger',
      () async {
        when(
          () => relationships.updateRelationship(any()),
        ).thenAnswer((_) async => false);

        expect(
          await actions().chooseAvatar(person()),
          PersonPhotoOutcome.failed,
        );

        verify(() => journal.deleteJournalEntity('image-new')).called(1);
      },
    );

    test('a refused write leaves an entry the import found alone', () async {
      pickCreated = false;
      when(
        () => relationships.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      expect(await actions().chooseAvatar(person()), PersonPhotoOutcome.failed);

      verifyNever(() => journal.deleteJournalEntity(any()));
    });

    test(
      'a write that throws discards the created entry and still throws',
      () async {
        when(
          () => relationships.updateRelationship(any()),
        ).thenThrow(StateError('db locked'));

        await expectLater(actions().chooseAvatar(person()), throwsStateError);

        verify(() => journal.deleteJournalEntity('image-new')).called(1);
      },
    );
  });

  group('adjust', () {
    test(
      'a person with no photo has nothing to adjust: nothing opens',
      () async {
        expect(
          await actions().adjustAvatar(person()),
          PersonPhotoOutcome.cancelled,
        );
        expect(log, isEmpty);
      },
    );

    test('opens the crop surface over the current photo, starting from its '
        'current framing', () async {
      await actions().adjustAvatar(
        person(avatarImageId: 'image-1', avatarCrop: crop),
      );

      expect(log, ['crop image-1 from 0.3']);
    });

    test('cancelling writes nothing', () async {
      cropResult = null;

      expect(
        await actions().adjustAvatar(
          person(avatarImageId: 'image-1', avatarCrop: crop),
        ),
        PersonPhotoOutcome.cancelled,
      );
      verifyNever(() => relationships.updateRelationship(any()));
    });

    test('committing writes only the framing and keeps the image', () async {
      expect(
        await actions().adjustAvatar(
          person(avatarImageId: 'image-1', avatarCrop: crop),
        ),
        PersonPhotoOutcome.changed,
      );

      final data = written()!;
      expect(data.avatarImageId, 'image-1');
      expect(data.avatarCrop, newCrop);
    });
  });

  group('remove', () {
    test('clears the image and its framing, and leaves the entry alone — '
        'the cover-art precedent', () async {
      expect(
        await actions().removeAvatar(
          person(avatarImageId: 'image-1', avatarCrop: crop),
        ),
        PersonPhotoOutcome.changed,
      );

      final data = written()!;
      expect(data.avatarImageId, isNull);
      expect(data.avatarCrop, isNull);
      verifyNever(() => journal.deleteJournalEntity(any()));
      expect(log, isEmpty, reason: 'removing opens no surface');
    });

    test('a refused write is reported as failed', () async {
      when(
        () => relationships.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      expect(
        await actions().removeAvatar(person(avatarImageId: 'image-1')),
        PersonPhotoOutcome.failed,
      );
    });
  });

  group('banner', () {
    test(
      'choosing writes the picture centred, and opens no crop surface',
      () async {
        expect(
          await actions().chooseBanner(person()),
          PersonPhotoOutcome.changed,
        );

        expect(log, [
          'pick',
        ], reason: 'a banner is framed by dragging, not cropped');
        final data = written()!;
        expect(data.bannerImageId, 'image-new');
        expect(data.bannerCropX, 0.5);
      },
    );

    test('backing out of the picker writes nothing', () async {
      pickResult = null;
      expect(
        await actions().chooseBanner(person()),
        PersonPhotoOutcome.cancelled,
      );
      verifyNever(() => relationships.updateRelationship(any()));
    });

    test('repositioning writes only the alignment', () async {
      final withBanner = person().copyWith(
        data: person().data.copyWith(
          bannerImageId: 'image-1',
          bannerCropX: 0.5,
        ),
      );

      expect(
        await actions().repositionBanner(withBanner, 0.2),
        PersonPhotoOutcome.changed,
      );

      final data = written()!;
      expect(data.bannerImageId, 'image-1');
      expect(data.bannerCropX, 0.2);
      expect(log, isEmpty);
    });

    test('removing clears the picture and resets the alignment, and leaves '
        'the entry alone', () async {
      final withBanner = person().copyWith(
        data: person().data.copyWith(
          bannerImageId: 'image-1',
          bannerCropX: 0.1,
        ),
      );

      expect(
        await actions().removeBanner(withBanner),
        PersonPhotoOutcome.changed,
      );

      final data = written()!;
      expect(data.bannerImageId, isNull);
      expect(data.bannerCropX, 0.5);
      verifyNever(() => journal.deleteJournalEntity(any()));
    });

    test('a refused write is reported as failed', () async {
      when(
        () => relationships.updateRelationship(any()),
      ).thenAnswer((_) async => false);
      expect(
        await actions().chooseBanner(person()),
        PersonPhotoOutcome.failed,
      );
    });

    test('a refused write takes the created picture back out', () async {
      when(
        () => relationships.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      expect(await actions().chooseBanner(person()), PersonPhotoOutcome.failed);

      verify(() => journal.deleteJournalEntity('image-new')).called(1);
    });

    test('a refused write leaves a picture the import found alone', () async {
      pickCreated = false;
      when(
        () => relationships.updateRelationship(any()),
      ).thenAnswer((_) async => false);

      expect(await actions().chooseBanner(person()), PersonPhotoOutcome.failed);

      verifyNever(() => journal.deleteJournalEntity(any()));
    });
  });
}
