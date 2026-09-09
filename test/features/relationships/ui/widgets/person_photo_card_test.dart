import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/relationships/ui/shared/cover_crop_geometry.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/person_photo_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/widgets/media/file_image_size.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/journal_image_fixtures.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final at = DateTime(2026, 8, 13, 14);
  late Directory documents;
  late MockRelationshipRepository relationships;
  late MockJournalRepository journal;
  late List<String> log;
  late PersonPhotoOutcome outcome;
  late int changes;

  RelationshipEntry person({
    String? avatarImageId,
    String? bannerImageId,
    double bannerCropX = 0.5,
  }) => RelationshipEntry(
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
      bannerImageId: bannerImageId,
      bannerCropX: bannerCropX,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: at,
        utcOffset: 0,
      ),
    ),
  );

  /// Real flows over scripted surfaces and a scripted write, so a tap runs
  /// end to end and the card's own behaviour — which flow, and what it does
  /// afterwards — is what gets asserted. [pickImage] replaces the picker
  /// that "returns" a fresh id, for the one test whose picker fails.
  PersonPhotoActions actions({Future<ImportedImage?> Function()? pickImage}) =>
      PersonPhotoActions(
        relationships: relationships,
        journal: journal,
        pickImage:
            pickImage ??
            () async {
              log.add('pick');
              return (id: 'image-new', created: true);
            },
        chooseCrop: (imageId, initial) async {
          log.add('crop $imageId');
          return const AvatarCrop(x: 0.2, y: 0.3, scale: 2);
        },
      );

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('person_photo_card_');
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(documents)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      },
    );
    relationships = MockRelationshipRepository();
    journal = MockJournalRepository();
    log = [];
    changes = 0;
    outcome = PersonPhotoOutcome.changed;
    when(
      () => relationships.updateRelationship(any()),
    ).thenAnswer((_) async => outcome != PersonPhotoOutcome.failed);
    // A refused write discards the picture the flow imported; without this
    // the refused-write tests would reach their toast through the exception
    // path instead, and prove nothing about the refusal.
    when(
      () => journal.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await tearDownTestGetIt();
    try {
      documents.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpCard(
    WidgetTester tester,
    RelationshipEntry entry, {
    List<Override> overrides = const [],
    double width = 400,
    Future<ImportedImage?> Function()? pickImage,
    ImageFileSizeReader readImageSize = readImageFileSize,
    Future<void> Function()? onChanged,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: SizedBox(
            width: width,
            child: PersonPhotoCard(
              person: entry,
              actions: actions(pickImage: pickImage),
              onChanged: onChanged ?? () async => changes++,
              readImageSize: readImageSize,
            ),
          ),
        ),
        overrides: overrides,
      ),
    );
    await tester.pump();
  }

  String buttonLabel(WidgetTester tester, String key) =>
      tester.widget<DesignSystemButton>(find.byKey(ValueKey(key))).label;

  testWidgets('a person with neither picture is offered the library for the '
      'face and an add for the banner, and nothing to crop or remove', (
    tester,
  ) async {
    await pumpCard(tester, person());

    expect(
      find.byKey(const ValueKey('person-form-photo-privacy')),
      findsOneWidget,
    );
    expect(
      buttonLabel(tester, 'person-form-face-change'),
      'Choose from library',
    );
    expect(find.byKey(const ValueKey('person-form-face-crop')), findsNothing);
    expect(find.byKey(const ValueKey('person-form-face-remove')), findsNothing);
    expect(buttonLabel(tester, 'person-form-banner-change'), 'Add banner');
    expect(find.byKey(const ValueKey('person-form-banner-hint')), findsNothing);
    expect(
      find.byKey(const ValueKey('person-form-banner-preview')),
      findsNothing,
    );
    final preview = tester.widget<PersonaAvatar>(
      find.byKey(const ValueKey('person-form-face-preview')),
    );
    expect(preview.imageId, isNull);
  });

  testWidgets('with both pictures every action is offered and the banner '
      'says how to frame it', (tester) async {
    await pumpCard(
      tester,
      person(avatarImageId: 'face-1', bannerImageId: 'banner-1'),
    );

    expect(buttonLabel(tester, 'person-form-face-change'), 'Change');
    expect(buttonLabel(tester, 'person-form-face-crop'), 'Adjust crop');
    expect(buttonLabel(tester, 'person-form-face-remove'), 'Remove');
    expect(buttonLabel(tester, 'person-form-banner-change'), 'Change');
    expect(buttonLabel(tester, 'person-form-banner-remove'), 'Remove');
    expect(find.text('Drag to reposition'), findsOneWidget);
  });

  testWidgets('choosing a face runs pick → crop → write and tells the host', (
    tester,
  ) async {
    await pumpCard(tester, person());

    await tester.tap(find.byKey(const ValueKey('person-form-face-change')));
    await tester.pumpAndSettle();

    expect(log, ['pick', 'crop image-new']);
    expect(changes, 1);
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.avatarImageId, 'image-new');
  });

  testWidgets('adjusting the face re-crops the photo it already has — no '
      'picker — and tells the host', (tester) async {
    await pumpCard(tester, person(avatarImageId: 'face-1'));

    await tester.tap(find.byKey(const ValueKey('person-form-face-crop')));
    await tester.pumpAndSettle();

    expect(log, ['crop face-1']);
    expect(changes, 1);
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.avatarImageId, 'face-1');
    expect(written.data.avatarCrop, const AvatarCrop(x: 0.2, y: 0.3, scale: 2));
  });

  testWidgets('removing the face clears the reference and its framing without '
      'opening anything, and tells the host', (tester) async {
    final framed = person(avatarImageId: 'face-1');
    await pumpCard(
      tester,
      framed.copyWith(
        data: framed.data.copyWith(
          avatarCrop: const AvatarCrop(y: 0.3, scale: 2),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('person-form-face-remove')));
    await tester.pumpAndSettle();

    expect(log, isEmpty, reason: 'removing opens neither picker nor crop');
    expect(changes, 1);
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.avatarImageId, isNull);
    expect(written.data.avatarCrop, isNull);
  });

  testWidgets('adding a banner runs the picker alone and writes it centred', (
    tester,
  ) async {
    await pumpCard(tester, person());

    await tester.tap(find.byKey(const ValueKey('person-form-banner-change')));
    await tester.pumpAndSettle();

    expect(log, ['pick']);
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.bannerImageId, 'image-new');
    expect(written.data.bannerCropX, 0.5);
    expect(changes, 1);
  });

  testWidgets('removing the banner writes and tells the host; a refused write '
      'tells the user instead', (tester) async {
    await pumpCard(tester, person(bannerImageId: 'banner-1'));
    await tester.tap(find.byKey(const ValueKey('person-form-banner-remove')));
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(find.text('Could not save the photo'), findsNothing);

    outcome = PersonPhotoOutcome.failed;
    await tester.tap(find.byKey(const ValueKey('person-form-face-change')));
    await tester.pumpAndSettle();
    expect(changes, 1, reason: 'a failed write is not a change');
    expect(find.text('Could not save the photo'), findsOneWidget);
    verify(
      () => journal.deleteJournalEntity('image-new'),
    ).called(1);
    expect(
      log,
      ['pick', 'crop image-new'],
      reason: 'the refused path ran the whole flow, not an exception',
    );
  });

  testWidgets('a flow that throws is reported like a refused write, and the '
      'card is handed back rather than left disabled behind it', (
    tester,
  ) async {
    await pumpCard(
      tester,
      person(),
      pickImage: () async => throw StateError('the picker fell over'),
    );

    await tester.tap(find.byKey(const ValueKey('person-form-face-change')));
    await tester.pumpAndSettle();

    expect(find.text('Could not save the photo'), findsOneWidget);
    expect(changes, 0);
    final change = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('person-form-face-change')),
    );
    expect(
      change.onPressed,
      isNotNull,
      reason: 'busy must be released however the flow ends',
    );
  });

  testWidgets("a re-read that throws after a successful write is the host's "
      "problem, not the user's: no error toast, and the card is handed back", (
    tester,
  ) async {
    await pumpCard(
      tester,
      person(bannerImageId: 'banner-1'),
      onChanged: () async => throw StateError('the re-read fell over'),
    );

    await tester.tap(find.byKey(const ValueKey('person-form-banner-remove')));
    await tester.pumpAndSettle();

    verify(() => relationships.updateRelationship(any())).called(1);
    expect(
      find.text('Could not save the photo'),
      findsNothing,
      reason: 'the write landed; a toast saying it did not would be untrue',
    );
    final change = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('person-form-banner-change')),
    );
    expect(change.onPressed, isNotNull, reason: 'busy is released regardless');
  });

  testWidgets("dragging the banner sideways moves it by the hero's own "
      'geometry and writes once, when the finger lifts', (tester) async {
    // A wide picture: a square one cover-fitted into a strip has no
    // horizontal room and cannot be repositioned at all.
    const imageSize = Size(800, 100);
    final image = buildJournalImage(imageFile: 'wide.png');
    createImageFile(image);

    await pumpCard(
      tester,
      person(bannerImageId: image.id),
      overrides: [createEntryControllerOverride(image)],
      readImageSize: (_) async => imageSize,
    );
    // One frame for the size the preview is told to arrive.
    await tester.pump();
    final preview = find.byKey(const ValueKey('person-form-banner-preview'));
    final viewport = tester.getSize(preview);

    await tester.drag(preview, const Offset(-30, 0));
    await tester.pumpAndSettle();

    // WidgetTester.drag spends kDragSlopDefault getting the recognizer to
    // accept before any movement is delivered as a delta; the card sees the
    // remainder, and that is what the geometry maps.
    const delivered = 30.0 - kDragSlopDefault;
    final expected = CoverCropGeometry(
      imageSize: imageSize,
      viewport: viewport,
    ).panBy(const AvatarCrop(), const Offset(-delivered, 0)).x;
    final written =
        verify(
              () => relationships.updateRelationship(captureAny()),
            ).captured.single
            as RelationshipEntry;
    expect(written.data.bannerCropX, closeTo(expected, 1e-6));
    expect(
      expected,
      greaterThan(0.5),
      reason: 'dragging left shows more of the right',
    );
    expect(changes, 1);
  });
}
