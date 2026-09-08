import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:lotti/widgets/media/thumb_hash_image.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/journal_image_fixtures.dart';
import '../../../../helpers/thumb_hash_fixtures.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  group('personaAccentForId', () {
    test('is stable for the same id across calls', () {
      final a = personaAccentForId('rel-1', Brightness.dark);
      final b = personaAccentForId('rel-1', Brightness.dark);
      expect(a, b);
    });

    test('is stable across brightness only when the palette agrees', () {
      // Different brightness can resolve to a different value; the contract
      // is stability *per brightness*, not across brightness.
      final dark = personaAccentForId('rel-1', Brightness.dark);
      final light = personaAccentForId('rel-1', Brightness.light);
      expect(dark, isA<Color>());
      expect(light, isA<Color>());
    });

    test('distributes across ids (not every id maps to the same accent)', () {
      final accents = {
        for (final id in ['rel-1', 'rel-2', 'rel-3', 'rel-4', 'rel-5', 'rel-6'])
          id: personaAccentForId(id, Brightness.dark),
      };
      expect(accents.values.toSet().length, greaterThan(1));
    });

    test('every accent comes from the exported token sets — no widget-local '
        'color literals', () {
      for (final brightness in Brightness.values) {
        final tokens = brightness == Brightness.dark
            ? dsTokensDark
            : dsTokensLight;
        final tokenAccents = {
          tokens.colors.interactive.enabled,
          GoalAccentHues.neon(brightness),
          GoalAccentHues.aurora(brightness),
          tokens.colors.alert.warning.ink,
          tokens.colors.alert.info.ink,
          tokens.colors.alert.success.ink,
        };
        for (var i = 0; i < 64; i++) {
          expect(
            tokenAccents,
            contains(personaAccentForId('rel-$i', brightness)),
            reason:
                'persona accents must resolve to design-system tokens so '
                'palette changes propagate from the token export',
          );
        }
      }
    });
  });

  group('personaInitial', () {
    test('returns the uppercased first letter of a name', () {
      expect(personaInitial('Anna'), 'A');
      expect(personaInitial('ben'), 'B');
      expect(personaInitial('  carla  '), 'C');
    });

    test('falls back to a middot for empty or null names', () {
      expect(personaInitial(''), '·');
      expect(personaInitial(null), '·');
      expect(personaInitial('   '), '·');
    });
  });

  group('PersonaAvatar', () {
    testWidgets('renders the initial and derives the accent from id', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: const PersonaAvatar(initial: 'A', id: 'rel-1'),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      // The avatar circle is a Container with a BoxShape.circle decoration.
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('honours an explicit accent over the id', (tester) async {
      const accent = Color(0xFF123456);
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: const PersonaAvatar(initial: 'A', id: 'rel-1', accent: accent),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, accent.withValues(alpha: 0.20));
    });

    testWidgets('asserts when neither id nor accent is given', (tester) async {
      // The constructor's `id != null || accent != null` assertion is a
      // hard failure, so constructing it directly is the cleanest proof.
      expect(
        () => PersonaAvatar(initial: 'A'),
        throwsA(isA<Object>()),
      );
    });

    testWidgets('uses the middot for an empty initial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          theme: resolveTestTheme(),
          home: const PersonaAvatar(initial: '', id: 'rel-1'),
        ),
      );
      expect(find.text('·'), findsOneWidget);
    });
  });

  group('PersonaAvatar with a photograph', () {
    late Directory documents;
    final theme = resolveTestTheme();
    const ring = ValueKey('persona-avatar-ring');

    setUp(() async {
      documents = Directory.systemTemp.createTempSync('persona_avatar_');
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<Directory>(documents)
            ..registerSingleton<EditorStateService>(MockEditorStateService())
            ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
        },
      );
    });

    tearDown(() async {
      await tearDownTestGetIt();
      try {
        documents.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<void> pumpAvatar(
      WidgetTester tester,
      PersonaAvatar avatar, {
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            builder: LegacyMaterialBridge.builder,
            theme: theme,
            home: Scaffold(body: Center(child: avatar)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    Border ringBorder(WidgetTester tester) {
      final container = tester.widget<Container>(find.byKey(ring));
      return (container.decoration! as BoxDecoration).border! as Border;
    }

    testWidgets('no photo: no ring, no resolver — the tree is what it was', (
      tester,
    ) async {
      await pumpAvatar(tester, const PersonaAvatar(initial: 'P', id: 'p'));

      expect(find.byKey(ring), findsNothing);
      expect(find.byType(JournalImageResolver), findsNothing);
      expect(find.byType(ClipOval), findsNothing);
      expect(find.text('P'), findsOneWidget);
      expect(tester.getSize(find.byType(PersonaAvatar)), const Size(40, 40));
    });

    testWidgets(
      'photo on disk: the picture inside an accent ring, no initial',
      (tester) async {
        final image = buildJournalImage();
        createImageFile(image);

        await pumpAvatar(
          tester,
          PersonaAvatar(initial: 'P', id: 'p', imageId: image.id),
          overrides: [createEntryControllerOverride(image)],
        );

        expect(find.byKey(ring), findsOneWidget);
        expect(find.byType(ClipOval), findsOneWidget);
        expect(find.text('P'), findsNothing);
        final picture = tester.widget<Image>(find.byType(Image));
        expect(picture.image, isA<ResizeImage>());
        expect(picture.fit, BoxFit.cover);
        expect(
          ringBorder(tester).top.color,
          personaAccentForId('p', theme.brightness),
          reason: 'the ring is the same accent the initial would have worn',
        );
      },
    );

    testWidgets('arriving: the stand-in fills the ring until the file lands', (
      tester,
    ) async {
      final image = buildJournalImage(
        imageFile: 'downloading.webp',
        thumbHash: sampleThumbHash,
      );

      await pumpAvatar(
        tester,
        PersonaAvatar(initial: 'P', id: 'p', imageId: image.id),
        overrides: [createEntryControllerOverride(image)],
      );

      expect(find.byKey(ring), findsOneWidget);
      expect(find.text('P'), findsNothing);
      final standIn = tester.widget<Image>(find.byType(Image));
      expect(
        standIn.image,
        ThumbHashImage(ThumbHash.fromBase64(sampleThumbHash)),
      );

      createImageFile(image);
      await tester.pump(const Duration(milliseconds: 150));

      final providers = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image);
      expect(providers.whereType<ResizeImage>(), hasLength(1));
    });

    testWidgets('id known, no stand-in: the ring says a photo exists and the '
        'initial keeps the circle full', (tester) async {
      final image = buildJournalImage(imageFile: 'downloading.webp');

      await pumpAvatar(
        tester,
        PersonaAvatar(initial: 'P', id: 'p', imageId: image.id),
        overrides: [createEntryControllerOverride(image)],
      );

      expect(find.byKey(ring), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('an id that does not resolve to an image is drawn like a '
        'missing stand-in — never an empty circle', (tester) async {
      final now = DateTime(2025, 12, 31, 12);
      final text = JournalEntry(
        meta: Metadata(
          id: 'text-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: 'not a picture'),
      );

      await pumpAvatar(
        tester,
        const PersonaAvatar(initial: 'P', id: 'p', imageId: 'text-1'),
        overrides: [createEntryControllerOverride(text)],
      );

      expect(find.byKey(ring), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('the ring is inside the size, so a photo never grows a row', (
      tester,
    ) async {
      final image = buildJournalImage();
      createImageFile(image);
      final tokens = theme.extension<DsTokens>()!;

      for (final size in [40.0, 48.0, 80.0]) {
        await pumpAvatar(
          tester,
          PersonaAvatar(initial: 'P', id: 'p', size: size, imageId: image.id),
          overrides: [createEntryControllerOverride(image)],
        );

        expect(
          tester.getSize(find.byType(PersonaAvatar)),
          Size(size, size),
          reason: 'at $size the ring must not add to the diameter',
        );
        expect(
          ringBorder(tester).top.width,
          tokens.spacing.step1,
          reason: 'one ring width at every size — no token was invented',
        );
      }
    });

    testWidgets("the initial inside the ring keeps the outer size's type "
        'scale', (tester) async {
      final image = buildJournalImage(imageFile: 'downloading.webp');

      await pumpAvatar(
        tester,
        PersonaAvatar(initial: 'P', id: 'p', size: 80, imageId: image.id),
        overrides: [createEntryControllerOverride(image)],
      );

      final text = tester.widget<Text>(find.text('P'));
      expect(
        text.style!.fontSize,
        80 * 0.42,
        reason: 'the initial must not shrink because a photo is on its way',
      );
    });

    testWidgets('the crop is applied as alignment plus a zoom about it', (
      tester,
    ) async {
      final image = buildJournalImage();
      createImageFile(image);

      await pumpAvatar(
        tester,
        PersonaAvatar(
          initial: 'P',
          id: 'p',
          imageId: image.id,
          crop: const AvatarCrop(x: 0.25, y: 1, scale: 2.5),
        ),
        overrides: [createEntryControllerOverride(image)],
      );

      // Scoped to the ring: the shell adds Transforms of its own.
      final zoom = tester.widget<Transform>(
        find.descendant(of: find.byKey(ring), matching: find.byType(Transform)),
      );
      expect(zoom.transform.getMaxScaleOnAxis(), 2.5);
      expect(zoom.alignment, const Alignment(-0.5, 1));
      final picture = tester.widget<Image>(find.byType(Image));
      expect(picture.alignment, const Alignment(-0.5, 1));
    });

    testWidgets('the decode is bounded to the slot at the widest zoom, so a '
        'zoomed face is drawn from pixels the source has', (tester) async {
      final image = buildJournalImage();
      createImageFile(image);
      final tokens = theme.extension<DsTokens>()!;

      await pumpAvatar(
        tester,
        PersonaAvatar(
          initial: 'P',
          id: 'p',
          size: 80,
          imageId: image.id,
          crop: const AvatarCrop(scale: maxAvatarCropScale),
        ),
        overrides: [createEntryControllerOverride(image)],
      );

      final decode =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      final inner = 80 - 2 * tokens.spacing.step1;
      final bound = (inner * maxAvatarCropScale * tester.view.devicePixelRatio)
          .round();
      expect(
        decode.width,
        bound,
        reason:
            'a decode capped to the circle itself would be magnified '
            '${maxAvatarCropScale.toInt()}× into a blur of its own pixels',
      );
      expect(decode.height, bound);
      expect(
        decode.policy,
        ResizeImagePolicy.fit,
        reason: 'a source smaller than the bound still decodes at its own size',
      );
    });

    testWidgets('no crop means centred at the widest zoom', (tester) async {
      final image = buildJournalImage();
      createImageFile(image);

      await pumpAvatar(
        tester,
        PersonaAvatar(initial: 'P', id: 'p', imageId: image.id),
        overrides: [createEntryControllerOverride(image)],
      );

      final zoom = tester.widget<Transform>(
        find.descendant(of: find.byKey(ring), matching: find.byType(Transform)),
      );
      expect(zoom.transform.getMaxScaleOnAxis(), 1);
      expect(zoom.alignment, Alignment.center);
    });

    testWidgets('an explicit accent colours the ring too', (tester) async {
      const accent = Color(0xFF123456);
      final image = buildJournalImage();
      createImageFile(image);

      await pumpAvatar(
        tester,
        PersonaAvatar(initial: 'P', accent: accent, imageId: image.id),
        overrides: [createEntryControllerOverride(image)],
      );

      expect(ringBorder(tester).top.color, accent);
    });
  });
}
