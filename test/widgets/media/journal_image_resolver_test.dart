import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/journal_image_resolver.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_entry_controller.dart';
import '../../helpers/journal_image_fixtures.dart';
import '../../helpers/thumb_hash_fixtures.dart';
import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  late Directory documents;

  setUp(() async {
    documents = Directory.systemTemp.createTempSync('journal_image_resolver_');
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

  /// Pumps a resolver for [imageId] and records every resolution the builder
  /// was handed, newest last.
  Future<List<ResolvedJournalImage?>> pumpResolver(
    WidgetTester tester, {
    required String imageId,
    required List<Override> overrides,
  }) async {
    final seen = <ResolvedJournalImage?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          builder: LegacyMaterialBridge.builder,
          home: Scaffold(
            body: JournalImageResolver(
              imageId: imageId,
              builder: (context, resolved) {
                seen.add(resolved);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return seen;
  }

  group('JournalImageResolver', () {
    testWidgets('hands the builder null for an entry that is not an image', (
      tester,
    ) async {
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

      final seen = await pumpResolver(
        tester,
        imageId: 'text-1',
        overrides: [createEntryControllerOverride(text)],
      );

      expect(seen.last, isNull);
    });

    testWidgets('resolves a file that is on disk, with no stand-in', (
      tester,
    ) async {
      final image = buildJournalImage();
      final path = createImageFile(image);

      final seen = await pumpResolver(
        tester,
        imageId: image.id,
        overrides: [createEntryControllerOverride(image)],
      );

      final resolved = seen.last!;
      expect(resolved.path, path);
      expect(resolved.fileExists, isTrue);
      expect(resolved.thumbHash, isNull);
      expect(resolved.hasNothingToShow, isFalse);
    });

    testWidgets('resolves a missing file to its stand-in while it is on the '
        'way', (tester) async {
      final image = buildJournalImage(
        imageFile: 'downloading.webp',
        thumbHash: sampleThumbHash,
      );

      final seen = await pumpResolver(
        tester,
        imageId: image.id,
        overrides: [createEntryControllerOverride(image)],
      );

      final resolved = seen.last!;
      expect(resolved.fileExists, isFalse);
      expect(resolved.thumbHash, ThumbHash.fromBase64(sampleThumbHash));
      expect(
        resolved.hasNothingToShow,
        isFalse,
        reason: 'a stand-in is something to show',
      );
    });

    testWidgets('a missing file with a hash that does not parse has nothing '
        'to show', (tester) async {
      final image = buildJournalImage(
        imageFile: 'downloading.webp',
        thumbHash: corruptThumbHash,
      );

      final seen = await pumpResolver(
        tester,
        imageId: image.id,
        overrides: [createEntryControllerOverride(image)],
      );

      final resolved = seen.last!;
      expect(resolved.fileExists, isFalse);
      expect(resolved.thumbHash, isNull);
      expect(resolved.hasNothingToShow, isTrue);
    });

    testWidgets('rebuilds with the file once it lands', (tester) async {
      final image = buildJournalImage(thumbHash: sampleThumbHash);

      final seen = await pumpResolver(
        tester,
        imageId: image.id,
        overrides: [createEntryControllerOverride(image)],
      );
      expect(seen.last!.fileExists, isFalse);

      createImageFile(image);
      // The test-environment poll looks every 100 ms.
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        seen.last!.fileExists,
        isTrue,
        reason:
            'the arrival is an event the host is rebuilt for, not '
            'something it has to ask about',
      );
      expect(seen.last!.path, getFullImagePath(image));
    });

    testWidgets('switching imageId resolves the new entry', (tester) async {
      final first = buildJournalImage(imageFile: 'a.jpg');
      final second = buildJournalImage(
        id: 'image-2',
        imageFile: 'b.jpg',
        thumbHash: sampleThumbHash,
      );
      createImageFile(first);
      final overrides = [
        createEntryControllerOverride(first),
        createEntryControllerOverride(second),
      ];

      final seen = await pumpResolver(
        tester,
        imageId: 'image-1',
        overrides: overrides,
      );
      expect(seen.last!.fileExists, isTrue);

      // Same ProviderScope, new imageId: pumpWidget diffs the element tree,
      // so this is the didUpdateWidget path, not a fresh mount.
      final after = await pumpResolver(
        tester,
        imageId: 'image-2',
        overrides: overrides,
      );

      expect(after.last!.path, getFullImagePath(second));
      expect(after.last!.fileExists, isFalse);
      expect(after.last!.thumbHash, isNotNull);
    });
  });

  group('JournalImageFileResolver', () {
    /// Pumps the file half alone — no `ProviderScope` at all, so a read of
    /// any provider would throw — and records every resolution the builder
    /// was handed, newest last.
    Future<List<ResolvedJournalImage>> pumpFileResolver(
      WidgetTester tester,
      JournalImage image,
    ) async {
      final seen = <ResolvedJournalImage>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          home: Scaffold(
            body: JournalImageFileResolver(
              image: image,
              builder: (context, resolved) {
                seen.add(resolved);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      return seen;
    }

    testWidgets('resolves the entry it is handed, touching no provider', (
      tester,
    ) async {
      final image = buildJournalImage(thumbHash: sampleThumbHash);

      final seen = await pumpFileResolver(tester, image);

      final resolved = seen.last;
      expect(resolved.image, image);
      expect(resolved.path, getFullImagePath(image));
      expect(resolved.fileExists, isFalse);
      expect(resolved.thumbHash, isNotNull);
    });

    testWidgets('a different entry is watched at its own path', (
      tester,
    ) async {
      final first = buildJournalImage();
      final second = buildJournalImage(id: 'image-2', imageFile: 'second.jpg');
      final path = createImageFile(second);

      await pumpFileResolver(tester, first);
      // Same widget type in the same slot, so this is the didUpdateWidget
      // path, not a fresh mount.
      final seen = await pumpFileResolver(tester, second);

      expect(seen.last.image, second);
      expect(seen.last.path, path);
      expect(
        seen.last.fileExists,
        isTrue,
        reason: 'the watch moved to the new file instead of reporting the old',
      );
    });
  });

  group('ResolvedJournalImage', () {
    test('is a value: same entry, same path, same state, same resolution', () {
      final hash = ThumbHash.fromBase64(sampleThumbHash);
      final image = buildJournalImage();
      ResolvedJournalImage resolution({
        JournalImage? image,
        String path = '/p',
        bool fileExists = false,
        ThumbHash? thumbHash,
      }) => ResolvedJournalImage(
        image: image ?? buildJournalImage(),
        path: path,
        fileExists: fileExists,
        thumbHash: thumbHash,
      );

      final a = resolution(image: image);
      expect(a, resolution(image: image));
      expect(a.hashCode, resolution(image: image).hashCode);
      expect(
        a,
        isNot(resolution(image: image, fileExists: true)),
        reason: 'the file landing is a change a host must see',
      );
      expect(a, isNot(resolution(image: image, thumbHash: hash)));
      expect(a, isNot(resolution(image: image, path: '/q')));
      expect(
        a,
        isNot(resolution(image: buildJournalImage(id: 'image-2'))),
        reason: 'a different entry at the same path is a different resolution',
      );
    });
  });

  group('boundedFileImage', () {
    test('caps each axis to its own bound at the pixel ratio, keeping the '
        'aspect ratio — a banner strip is wide, not square', () {
      final provider =
          boundedFileImage(
                '/p/a.jpg',
                bounds: const Size(402, 96),
                devicePixelRatio: 2,
              )
              as ResizeImage;
      expect(provider.width, 804);
      expect(provider.height, 192);
      expect(provider.policy, ResizeImagePolicy.fit);
    });

    test('a non-positive bound on either axis decodes at full size', () {
      expect(
        boundedFileImage(
          '/p/a.jpg',
          bounds: const Size(0, 96),
          devicePixelRatio: 2,
        ),
        isA<FileImage>(),
      );
      expect(
        boundedFileImage(
          '/p/a.jpg',
          bounds: const Size(402, -1),
          devicePixelRatio: 2,
        ),
        isA<FileImage>(),
      );
    });
  });

  group('cappedFileImage', () {
    test('caps both axes to the slot at the device pixel ratio, keeping the '
        'aspect ratio', () {
      final provider =
          cappedFileImage('/p/a.jpg', size: 40, devicePixelRatio: 3)
              as ResizeImage;
      expect(provider.width, 120);
      expect(provider.height, 120);
      expect(
        provider.policy,
        ResizeImagePolicy.fit,
        reason: 'a portrait photo must not be squashed into a square decode',
      );
    });

    test('rounds the cap and never lets it reach zero', () {
      final provider =
          cappedFileImage('/p/a.jpg', size: 0.2, devicePixelRatio: 1)
              as ResizeImage;
      expect(provider.width, 1);
    });

    test("clamps an absurd slot to the decoder's ceiling", () {
      final provider =
          cappedFileImage(
                '/p/a.jpg',
                size: 1000000000,
                devicePixelRatio: 4,
              )
              as ResizeImage;
      expect(provider.width, 10000);
    });

    test('a non-positive slot decodes at full size', () {
      expect(
        cappedFileImage('/p/a.jpg', size: 0, devicePixelRatio: 2),
        isA<FileImage>(),
      );
      expect(
        cappedFileImage('/p/a.jpg', size: -8, devicePixelRatio: 2),
        isA<FileImage>(),
      );
    });
  });
}
