import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/ui/widgets/avatar_photo_actions.dart';
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

  AvatarPhotoActions actions() => AvatarPhotoActions(
    relationships: relationships,
    journal: journal,
    pickImage: () async {
      log.add('pick');
      return pickResult;
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

        expect(await actions().choose(person()), AvatarPhotoOutcome.cancelled);

        expect(log, ['pick']);
        verifyNever(() => relationships.updateRelationship(any()));
        verifyNever(() => journal.deleteJournalEntity(any()));
      },
    );

    test('cancelling the crop deletes the entry the picker had already '
        'imported, so cancelling leaves nothing behind', () async {
      cropResult = null;

      expect(await actions().choose(person()), AvatarPhotoOutcome.cancelled);

      expect(log, ['pick', 'crop image-new from null']);
      verify(() => journal.deleteJournalEntity('image-new')).called(1);
      verifyNever(() => relationships.updateRelationship(any()));
    });

    test('committing writes the image and the framing together', () async {
      expect(await actions().choose(person()), AvatarPhotoOutcome.changed);

      final data = written()!;
      expect(data.avatarImageId, 'image-new');
      expect(data.avatarCrop, newCrop);
      verifyNever(() => journal.deleteJournalEntity(any()));
    });

    test('the crop surface starts from the default framing for a new photo, '
        'even when the person had one before', () async {
      await actions().choose(person(avatarImageId: 'old', avatarCrop: crop));

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

      expect(await actions().choose(person()), AvatarPhotoOutcome.failed);
    });
  });

  group('adjust', () {
    test(
      'a person with no photo has nothing to adjust: nothing opens',
      () async {
        expect(await actions().adjust(person()), AvatarPhotoOutcome.cancelled);
        expect(log, isEmpty);
      },
    );

    test('opens the crop surface over the current photo, starting from its '
        'current framing', () async {
      await actions().adjust(
        person(avatarImageId: 'image-1', avatarCrop: crop),
      );

      expect(log, ['crop image-1 from 0.3']);
    });

    test('cancelling writes nothing', () async {
      cropResult = null;

      expect(
        await actions().adjust(
          person(avatarImageId: 'image-1', avatarCrop: crop),
        ),
        AvatarPhotoOutcome.cancelled,
      );
      verifyNever(() => relationships.updateRelationship(any()));
    });

    test('committing writes only the framing and keeps the image', () async {
      expect(
        await actions().adjust(
          person(avatarImageId: 'image-1', avatarCrop: crop),
        ),
        AvatarPhotoOutcome.changed,
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
        await actions().remove(
          person(avatarImageId: 'image-1', avatarCrop: crop),
        ),
        AvatarPhotoOutcome.changed,
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
        await actions().remove(person(avatarImageId: 'image-1')),
        AvatarPhotoOutcome.failed,
      );
    });
  });
}
