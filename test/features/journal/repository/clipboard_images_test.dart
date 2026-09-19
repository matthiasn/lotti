import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/clipboard_images.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(Formats.png);
  });

  late MockSystemClipboard clipboard;
  late MockClipboardReader reader;

  /// An item offering exactly [formats]; any other format is refused.
  MockClipboardDataReader itemOffering(Set<DataFormat> formats) {
    final item = MockClipboardDataReader();
    when(() => item.canProvide(any())).thenAnswer(
      (invocation) => formats.contains(invocation.positionalArguments.first),
    );
    return item;
  }

  /// Makes [item] deliver [bytes] for [format] — synchronously, as the
  /// platform may, returning no progress.
  void deliver(
    MockClipboardDataReader item,
    FileFormat format,
    List<int> bytes,
  ) {
    final file = MockDataReaderFile();
    when(file.readAll).thenAnswer((_) async => Uint8List.fromList(bytes));
    when(
      () => item.getFile(format, any(), onError: any(named: 'onError')),
    ).thenAnswer((invocation) {
      final onFile =
          invocation.positionalArguments[1]
              as Future<void> Function(
                DataReaderFile,
              );
      onFile(file);
      return null;
    });
  }

  setUp(() {
    clipboard = MockSystemClipboard();
    reader = MockClipboardReader();
    when(clipboard.read).thenAnswer((_) async => reader);
  });

  group('clipboardImageFormatOf', () {
    test('prefers PNG over JPEG when an item offers both', () {
      final format = clipboardImageFormatOf(
        itemOffering({Formats.png, Formats.jpeg}),
      );
      expect(format?.format, Formats.png);
      expect(format?.extension, 'png');
    });

    test('reads a JPEG-only item as jpg', () {
      final format = clipboardImageFormatOf(itemOffering({Formats.jpeg}));
      expect(format?.format, Formats.jpeg);
      expect(format?.extension, 'jpg');
    });

    test('an item with no image format yields nothing', () {
      expect(clipboardImageFormatOf(itemOffering({Formats.plainText})), isNull);
    });
  });

  group('readClipboardImage', () {
    test(
      'returns the bytes of a file the platform delivers synchronously',
      () async {
        final item = itemOffering({Formats.png});
        deliver(item, Formats.png, [1, 2, 3]);

        expect(await readClipboardImage(item, Formats.png), [1, 2, 3]);
      },
    );

    test(
      'completes with null when the platform will deliver no file',
      () async {
        final item = itemOffering({Formats.png});
        when(
          () =>
              item.getFile(Formats.png, any(), onError: any(named: 'onError')),
        ).thenReturn(null);

        expect(await readClipboardImage(item, Formats.png), isNull);
      },
    );

    test('fails with the error the platform reports', () async {
      final item = itemOffering({Formats.png});
      final progress = MockReadProgress();
      when(
        () => item.getFile(Formats.png, any(), onError: any(named: 'onError')),
      ).thenAnswer((invocation) {
        final onError =
            invocation.namedArguments[#onError] as void Function(Object);
        onError(StateError('clipboard gone'));
        return progress;
      });

      await expectLater(
        readClipboardImage(item, Formats.png),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('clipboardHasImageProvider', () {
    Future<bool> read(SystemClipboard? systemClipboard) {
      final container = ProviderContainer(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(systemClipboard),
        ],
      );
      addTearDown(container.dispose);
      return container.read(clipboardHasImageProvider.future);
    }

    test('is false where the platform has no clipboard', () async {
      expect(await read(null), isFalse);
    });

    test('is false when no item carries an image', () async {
      final items = [
        itemOffering({Formats.plainText}),
      ];
      when(() => reader.items).thenReturn(items);
      expect(await read(clipboard), isFalse);
    });

    test('is true when any item carries an image', () async {
      final items = [
        itemOffering({Formats.plainText}),
        itemOffering({Formats.jpeg}),
      ];
      when(() => reader.items).thenReturn(items);
      expect(await read(clipboard), isTrue);
    });
  });

  group('importFirstClipboardImage', () {
    late Directory documents;
    late MockPersistenceLogic persistenceLogic;

    setUp(() async {
      documents = Directory.systemTemp.createTempSync('clipboard_images_');
      persistenceLogic = MockPersistenceLogic();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<Directory>(documents)
            ..registerSingleton<PersistenceLogic>(persistenceLogic);
        },
      );
      when(
        () => persistenceLogic.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          uuidV5Input: any(named: 'uuidV5Input'),
          flag: any(named: 'flag'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((invocation) async {
        final at = DateTime(2026, 9, 19, 10);
        return Metadata(
          id: 'pasted-image',
          createdAt: at,
          updatedAt: at,
          dateFrom: at,
          dateTo: at,
          categoryId: invocation.namedArguments[#categoryId] as String?,
        );
      });
      when(
        () => persistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          linkCollapsed: any(named: 'linkCollapsed'),
        ),
      ).thenAnswer((_) async => true);
    });

    tearDown(() async {
      await tearDownTestGetIt();
      documents.deleteSync(recursive: true);
    });

    test('imports the first image, linked collapsed in the given category, '
        'and returns the new entry', () async {
      final text = itemOffering({Formats.plainText});
      final first = itemOffering({Formats.png});
      final second = itemOffering({Formats.jpeg});
      deliver(first, Formats.png, [1, 2, 3]);
      deliver(second, Formats.jpeg, [4, 5, 6]);
      when(() => reader.items).thenReturn([text, first, second]);

      final imported = await importFirstClipboardImage(
        clipboard,
        linkedId: 'task-1',
        categoryId: 'cat-1',
        linkCollapsed: true,
      );

      expect(imported, (id: 'pasted-image', created: true));
      final written =
          verify(
                () => persistenceLogic.createDbEntity(
                  captureAny(),
                  linkedId: 'task-1',
                  shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
                  linkCollapsed: true,
                ),
              ).captured.single
              as JournalImage;
      expect(written.meta.categoryId, 'cat-1');
      expect(written.data.imageFile, endsWith('.png'));
      verifyNever(
        () => second.getFile(any(), any(), onError: any(named: 'onError')),
      );
    });

    test('returns null without importing when the clipboard holds no '
        'image', () async {
      final items = [
        itemOffering({Formats.plainText}),
      ];
      when(() => reader.items).thenReturn(items);

      expect(
        await importFirstClipboardImage(clipboard, linkedId: 'task-1'),
        isNull,
      );
      verifyNever(
        () => persistenceLogic.createDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
          linkCollapsed: any(named: 'linkCollapsed'),
        ),
      );
    });

    test('returns null where the platform has no clipboard', () async {
      expect(await importFirstClipboardImage(null, linkedId: 'task-1'), isNull);
    });
  });
}
