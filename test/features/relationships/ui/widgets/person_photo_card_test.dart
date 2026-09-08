import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/image_utils.dart';
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
  /// afterwards — is what gets asserted.
  PersonPhotoActions actions() => PersonPhotoActions(
    relationships: relationships,
    journal: journal,
    pickImage: () async {
      log.add('pick');
      return 'image-new';
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
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: SizedBox(
            width: width,
            child: PersonPhotoCard(
              person: entry,
              actions: actions(),
              onChanged: () async => changes++,
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
  });

  testWidgets("dragging the banner sideways moves it by the hero's own "
      'geometry and writes once, when the finger lifts', (tester) async {
    // A wide picture: a square one cover-fitted into a strip has no
    // horizontal room and cannot be repositioned at all.
    final image = buildJournalImage(imageFile: 'wide.png');
    late Uint8List png;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 800, 100),
        Paint()..color = const Color(0xFF3366AA),
      );
      final picture = await recorder.endRecording().toImage(800, 100);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      png = bytes!.buffer.asUint8List();
    });
    createImageFile(image, bytes: png);
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(key: ValueKey('warm'))),
    );
    await tester.runAsync(
      () => precacheImage(
        FileImage(File(getFullImagePath(image))),
        tester.element(find.byKey(const ValueKey('warm'))),
      ),
    );

    await pumpCard(
      tester,
      person(bannerImageId: image.id),
      overrides: [createEntryControllerOverride(image)],
    );
    // The size probe: one frame to start, one for its setState.
    await tester.pump();
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
      imageSize: const Size(800, 100),
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
