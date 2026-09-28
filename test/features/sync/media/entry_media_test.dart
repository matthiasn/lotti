import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/media/entry_media.dart';
import 'package:path/path.dart' as p;

void main() {
  final date = DateTime.utc(2024);
  final meta = Metadata(
    id: 'entry-1',
    createdAt: date,
    updatedAt: date,
    dateFrom: date,
    dateTo: date,
  );

  late Directory root;
  late Directory documents;

  setUp(() {
    root = Directory.systemTemp.createTempSync('entry_media_test');
    documents = Directory(p.join(root.path, 'Documents'))..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  JournalImage image() => JournalImage(
    meta: meta,
    data: ImageData(
      capturedAt: date,
      imageId: 'img-1',
      imageFile: 'photo.jpg',
      imageDirectory: '/images/2024-01-01/',
    ),
  );

  group('entryMedia', () {
    test('resolves an image to its canonical file and travel path', () {
      final media = entryMedia(image(), documentsDirectory: documents)!;

      expect(
        media.file.path,
        p.join(documents.path, 'images', '2024-01-01', 'photo.jpg'),
      );
      expect(media.relativePath, '/images/2024-01-01/photo.jpg');
    });

    test('finds an image where the legacy separator bug left it, as the '
        'payload sender does', () {
      // The bug appended `images/...` straight to the documents root.
      final legacy = File(
        p.join(root.path, 'Documentsimages', '2024-01-01', 'photo.jpg'),
      )..createSync(recursive: true);

      final media = entryMedia(image(), documentsDirectory: documents)!;

      expect(media.file.path, legacy.path);
      expect(media.relativePath, '/images/2024-01-01/photo.jpg');
    });

    test('resolves an audio entry under the documents directory', () {
      final audio = JournalAudio(
        meta: meta,
        data: AudioData(
          dateFrom: date,
          dateTo: date,
          audioFile: 'note.aac',
          audioDirectory: '/audio/2024-01-01/',
          duration: const Duration(seconds: 3),
        ),
      );

      final media = entryMedia(audio, documentsDirectory: documents)!;

      expect(media.file.path, '${documents.path}/audio/2024-01-01/note.aac');
      expect(media.relativePath, '/audio/2024-01-01/note.aac');
    });

    test('is null for an entry without media', () {
      final text = JournalEntry(
        meta: meta,
        entryText: const EntryText(plainText: 'no media'),
      );

      expect(entryMedia(text, documentsDirectory: documents), isNull);
    });
  });

  group('mediaFileLength', () {
    test('is the byte length of a file that exists', () async {
      final file = File(p.join(documents.path, 'blob'))
        ..writeAsBytesSync(List<int>.filled(42, 1));

      expect(await mediaFileLength(file), 42);
    });

    test('is 0 for a missing file', () async {
      expect(await mediaFileLength(File(p.join(documents.path, 'none'))), 0);
    });
  });
}
