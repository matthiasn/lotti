import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/cover_crop_geometry.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/avatar_crop_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/journal_image_fixtures.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late Directory documents;
  late JournalImage image;
  late ValueNotifier<AvatarCrop> handle;
  final at = DateTime(2026, 8, 13, 14);

  /// The size the surface is told its picture has — what a drag moves
  /// against — in place of reading a file's header.
  const imageSize = Size(160, 160);
  Future<Size> readImageSize(String _) async => imageSize;

  final person = RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: RelationshipData(
      title: 'Pip',
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: at,
        utcOffset: 0,
      ),
    ),
  );

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('avatar_crop_sheet_');
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Directory>(documents)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      },
    );
    image = buildJournalImage(imageFile: 'pip.png');
    createImageFile(image);
    handle = ValueNotifier(const AvatarCrop());
  });

  tearDown(() async {
    handle.dispose();
    await tearDownTestGetIt();
    try {
      documents.deleteSync(recursive: true);
    } catch (_) {}
  });

  AvatarCropForm form() => AvatarCropForm(
    relationship: person,
    imageId: image.id,
    handle: handle,
    readImageSize: readImageSize,
  );

  /// Pumps the form at a known width, then one frame for the size the
  /// surface is told to arrive.
  Future<void> pumpForm(WidgetTester tester, {double width = 300}) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: SizedBox(width: width, child: form()),
          ),
        ),
        overrides: [createEntryControllerOverride(image)],
      ),
    );
    await tester.pump();
  }

  final viewport = find.byKey(const ValueKey('avatar-crop-viewport'));

  group('AvatarCropForm', () {
    testWidgets('shows the hint, a square viewport, and a live preview that '
        'is the list avatar itself', (tester) async {
      await pumpForm(tester);

      expect(find.byKey(const ValueKey('avatar-crop-hint')), findsOneWidget);
      expect(find.text('Drag to move · pinch to zoom'), findsOneWidget);
      expect(tester.getSize(viewport), const Size(300, 300));
      final preview = tester.widget<PersonaAvatar>(
        find.byKey(const ValueKey('avatar-crop-preview')),
      );
      expect(preview.imageId, image.id);
      expect(preview.size, 40, reason: 'the preview is the list size');
      expect(preview.crop, const AvatarCrop());
    });

    testWidgets('the wheel zooms, and the preview follows the handle', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(viewport),
          scrollDelta: const Offset(0, -300),
        ),
      );
      await tester.pump();

      expect(handle.value.scale, closeTo(math.e, 1e-9));
      final preview = tester.widget<PersonaAvatar>(
        find.byKey(const ValueKey('avatar-crop-preview')),
      );
      expect(preview.crop!.scale, closeTo(math.e, 1e-9));
    });

    testWidgets('the picture is decoded at the deepest zoom from the start, '
        'so a zoom never re-keys the decode — and the preview is bounded the '
        'same way', (tester) async {
      await pumpForm(tester);
      // The widget decodes for the MediaQuery's ratio, which the harness
      // sets independently of the test view's.
      final dpr = MediaQuery.devicePixelRatioOf(tester.element(viewport));
      final bound = ((300 * maxAvatarCropScale).ceil() * dpr).round();
      ResizeImage viewportDecode() =>
          tester
                  .widget<Image>(
                    find.descendant(
                      of: viewport,
                      matching: find.byType(Image),
                    ),
                  )
                  .image
              as ResizeImage;

      expect(viewportDecode().width, bound);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(viewport),
          scrollDelta: const Offset(0, -300),
        ),
      );
      await tester.pump();

      expect(handle.value.scale, closeTo(math.e, 1e-9));
      expect(
        viewportDecode().width,
        bound,
        reason: 'zooming must not mint a new image-cache key',
      );
      final preview = tester.widget<PersonaAvatar>(
        find.byKey(const ValueKey('avatar-crop-preview')),
      );
      expect(preview.decodeZoom, maxAvatarCropScale);
    });

    testWidgets('the wheel over the picture zooms it and leaves the sheet '
        'where it was — the signal is claimed, not shared with the scroll '
        'view around the form', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  SizedBox(width: 300, child: form()),
                  // Somewhere for the scroll view to go, so a notch that
                  // reached it would visibly move it.
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
          overrides: [createEntryControllerOverride(image)],
        ),
      );
      await tester.pump();
      controller.jumpTo(100);
      await tester.pump();

      // Up, which scrolls the view back towards the top and zooms in.
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(viewport),
          scrollDelta: const Offset(0, -300),
        ),
      );
      await tester.pump();

      expect(handle.value.scale, closeTo(math.e, 1e-9));
      expect(
        controller.offset,
        100,
        reason: 'a notch over the picture must zoom it, not scroll the sheet',
      );
    });

    testWidgets('a pinch zooms by the ratio of spans, and a second movement '
        'of the same fingers applies only the change since the last one — '
        'not the whole gesture again', (tester) async {
      await pumpForm(tester);
      final center = tester.getCenter(viewport);

      final left = await tester.startGesture(center - const Offset(20, 0));
      final right = await tester.startGesture(center + const Offset(20, 0));
      // Span 40 → 80: twice as far apart.
      await left.moveBy(const Offset(-20, 0));
      await right.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(handle.value.scale, closeTo(2, 1e-6));

      // Span 80 → 120: three times the start, so ×1.5 on top — not ×3.
      await left.moveBy(const Offset(-20, 0));
      await right.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(handle.value.scale, closeTo(3, 1e-6));

      await left.up();
      await right.up();
      await tester.pump();
      expect(handle.value.x, 0.5, reason: 'a symmetric pinch does not pan');
    });

    testWidgets('zoom is clamped to the range the model allows', (
      tester,
    ) async {
      await pumpForm(tester);

      for (var i = 0; i < 5; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(viewport),
            scrollDelta: const Offset(0, -900),
          ),
        );
      }
      await tester.pump();
      expect(handle.value.scale, maxAvatarCropScale);

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(viewport),
          scrollDelta: const Offset(0, 9000),
        ),
      );
      await tester.pump();
      expect(handle.value.scale, minAvatarCropScale);
    });

    testWidgets('a drag moves the picture under the finger by exactly the '
        "geometry, once it knows the picture's size", (tester) async {
      await pumpForm(tester);
      // A square picture at the widest zoom has no room to move; zoom in
      // first so the drag has somewhere to go.
      handle.value = const AvatarCrop(scale: 2);
      await tester.pump();

      await tester.drag(viewport, const Offset(-30, 12));
      await tester.pump();

      final geometry = CoverCropGeometry.circle(
        imageSize: imageSize,
        diameter: 300,
      );
      final expected = geometry.panBy(
        const AvatarCrop(scale: 2),
        const Offset(-30, 12),
      );
      expect(handle.value.x, closeTo(expected.x, 1e-6));
      expect(handle.value.y, closeTo(expected.y, 1e-6));
      expect(
        handle.value.x,
        greaterThan(0.5),
        reason: 'dragging left shows more of the right',
      );
    });
  });

  group('showAvatarCropSheet', () {
    Future<Future<AvatarCrop?>> openSheet(WidgetTester tester) async {
      late Future<AvatarCrop?> result;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  result = showAvatarCropSheet(
                    context: context,
                    relationship: person,
                    imageId: image.id,
                    initial: const AvatarCrop(x: 0.1, y: 0.9, scale: 3),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          overrides: [createEntryControllerOverride(image)],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a picture with nothing to show yet — no file, no stand-in — '
        'leaves a plain square where the viewport would be, and the preview '
        'keeps the initial', (tester) async {
      final pending = buildJournalImage(
        id: 'image-pending',
        imageFile: 'pending.png',
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: AvatarCropForm(
                  relationship: person,
                  imageId: pending.id,
                  handle: handle,
                  readImageSize: readImageSize,
                ),
              ),
            ),
          ),
          overrides: [createEntryControllerOverride(pending)],
        ),
      );
      await tester.pump();

      expect(
        viewport,
        findsNothing,
        reason: 'nothing to drag until a picture or its stand-in exists',
      );
      final square = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(AvatarCropForm),
          matching: find.byType(ColoredBox),
        ),
      );
      final tokens = tester.element(find.byType(AvatarCropForm)).designTokens;
      expect(square.color, tokens.colors.background.level02);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('avatar-crop-preview')),
          matching: find.text('P'),
        ),
        findsOneWidget,
        reason: 'the preview is a PersonaAvatar, so it shows the initial',
      );
    });

    testWidgets('Use photo resolves to the framing being edited', (
      tester,
    ) async {
      final result = await openSheet(tester);
      expect(find.text('Choose the face'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('avatar-crop-use')));
      await tester.pumpAndSettle();

      expect(await result, const AvatarCrop(x: 0.1, y: 0.9, scale: 3));
    });

    testWidgets('Cancel resolves to nothing', (tester) async {
      final result = await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('avatar-crop-cancel')));
      await tester.pumpAndSettle();

      expect(await result, isNull);
    });
  });
}
