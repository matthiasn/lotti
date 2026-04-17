// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/attachment_enumerator.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';

void main() {
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('enumerator_test');
  });

  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Metadata meta({String id = 'e1'}) {
    final ts = DateTime(2026, 4, 17, 12);
    return Metadata(
      id: id,
      createdAt: ts,
      updatedAt: ts,
      dateFrom: ts,
      dateTo: ts,
    );
  }

  File writeFile(String relativePath, List<int> bytes) {
    final file = File('${docs.path}$relativePath')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return file;
  }

  group('SyncJournalEntity', () {
    test('text entry returns only the jsonPath file', () async {
      final entity = JournalEntity.journalEntry(
        meta: meta(),
        entryText: const EntryText(plainText: 'hello'),
      );
      const jsonPath = '/text_entries/e1.json';
      writeFile(jsonPath, utf8.encode(jsonEncode(entity)));

      final result = await enumerateAttachments(
        message: SyncMessage.journalEntity(
          id: 'e1',
          jsonPath: jsonPath,
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );

      expect(result, hasLength(1));
      expect(result.single.relativePath, jsonPath);
      expect(result.single.size, greaterThan(0));
    });

    test('journalImage returns jsonPath plus the image file', () async {
      final imageData = ImageData(
        capturedAt: DateTime(2026, 4, 17, 12),
        imageId: 'img-1',
        imageFile: 'photo.jpg',
        imageDirectory: '/images/',
      );
      final entity = JournalEntity.journalImage(
        meta: meta(),
        data: imageData,
        entryText: const EntryText(plainText: 'caption'),
      );
      const jsonPath = '/text_entries/img-1.json';
      writeFile(jsonPath, utf8.encode(jsonEncode(entity)));
      final imageRelative = getRelativeImagePath(entity as JournalImage);
      writeFile(imageRelative, List<int>.filled(64, 0xA));

      final result = await enumerateAttachments(
        message: SyncMessage.journalEntity(
          id: 'img-1',
          jsonPath: jsonPath,
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );

      expect(
        result.map((a) => a.relativePath).toSet(),
        equals({jsonPath, imageRelative}),
      );
      final imageDesc = result.firstWhere(
        (a) => a.relativePath == imageRelative,
      );
      expect(imageDesc.size, 64);
    });

    test('journalAudio returns jsonPath plus the audio file', () async {
      final audioData = AudioData(
        dateFrom: DateTime(2026, 4, 17, 12),
        dateTo: DateTime(2026, 4, 17, 12),
        audioFile: 'voice.aac',
        audioDirectory: '/audio/',
        duration: const Duration(seconds: 30),
      );
      final entity = JournalEntity.journalAudio(
        meta: meta(),
        data: audioData,
        entryText: const EntryText(plainText: 'transcript'),
      );
      const jsonPath = '/text_entries/audio-1.json';
      writeFile(jsonPath, utf8.encode(jsonEncode(entity)));
      final audioRelative = AudioUtils.getRelativeAudioPath(
        entity as JournalAudio,
      );
      writeFile(audioRelative, List<int>.filled(128, 0xC));

      final result = await enumerateAttachments(
        message: SyncMessage.journalEntity(
          id: 'audio-1',
          jsonPath: jsonPath,
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );

      expect(
        result.map((a) => a.relativePath).toSet(),
        equals({jsonPath, audioRelative}),
      );
      final audioDesc = result.firstWhere(
        (a) => a.relativePath == audioRelative,
      );
      expect(audioDesc.size, 128);
    });

    test('missing media file does not block the json entry', () async {
      final imageData = ImageData(
        capturedAt: DateTime(2026, 4, 17, 12),
        imageId: 'img-miss',
        imageFile: 'photo.jpg',
        imageDirectory: '/images/',
      );
      final entity = JournalEntity.journalImage(
        meta: meta(),
        data: imageData,
        entryText: const EntryText(plainText: 'caption'),
      );
      const jsonPath = '/text_entries/img-miss.json';
      writeFile(jsonPath, utf8.encode(jsonEncode(entity)));
      // NOTE: media file is NOT written to disk

      final result = await enumerateAttachments(
        message: SyncMessage.journalEntity(
          id: 'img-miss',
          jsonPath: jsonPath,
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );

      expect(
        result.map((a) => a.relativePath).toSet(),
        equals({jsonPath}),
      );
    });

    test('missing json file returns empty', () async {
      final result = await enumerateAttachments(
        message: SyncMessage.journalEntity(
          id: 'nope',
          jsonPath: '/does/not/exist.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );
      expect(result, isEmpty);
    });
  });

  group('other SyncMessage variants', () {
    test('SyncAgentEntity without jsonPath returns empty', () async {
      final result = await enumerateAttachments(
        message: SyncMessage.agentEntity(
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );
      expect(result, isEmpty);
    });

    test('SyncAgentLink without jsonPath returns empty', () async {
      final result = await enumerateAttachments(
        message: SyncMessage.agentLink(
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );
      expect(result, isEmpty);
    });

    test('SyncEntryLink returns empty (no attachments)', () async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'from',
        toId: 'to',
        createdAt: DateTime(2026, 4, 17),
        updatedAt: DateTime(2026, 4, 17),
        vectorClock: const VectorClock({'host': 1}),
      );
      final result = await enumerateAttachments(
        message: SyncMessage.entryLink(
          entryLink: link,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );
      expect(result, isEmpty);
    });

    test('SyncAiConfigDelete returns empty', () async {
      final result = await enumerateAttachments(
        message: const SyncMessage.aiConfigDelete(id: 'x'),
        documentsDirectory: docs,
      );
      expect(result, isEmpty);
    });
  });

  group('path hardening', () {
    test('rejects a jsonPath that escapes the documents directory', () async {
      // A sibling file that exists outside docs — the traversal target.
      final escapeTarget = File('${docs.path}/../escape.json')
        ..writeAsStringSync('{"secret":true}');
      addTearDown(() {
        if (escapeTarget.existsSync()) escapeTarget.deleteSync();
      });

      final result = await enumerateAttachments(
        message: SyncMessage.journalEntity(
          id: 'trav',
          jsonPath: '../escape.json',
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );

      expect(result, isEmpty);
    });

    test('rejects an absolute jsonPath pointing outside docs', () async {
      // Write a target outside docs; an absolute jsonPath would resolve to
      // it if the helper didn't strip the root prefix and re-anchor under
      // documentsDirectory.
      final outside = File('${docs.path}/../absolute.json')
        ..writeAsStringSync('{}');
      addTearDown(() {
        if (outside.existsSync()) outside.deleteSync();
      });

      final result = await enumerateAttachments(
        message: SyncMessage.journalEntity(
          id: 'abs',
          jsonPath: outside.absolute.path,
          vectorClock: null,
          status: SyncEntryStatus.initial,
        ),
        documentsDirectory: docs,
      );

      expect(result, isEmpty);
    });
  });
}
