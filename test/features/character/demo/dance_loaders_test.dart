import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_loaders.dart';
import 'package:path/path.dart' as p;

void main() {
  group('parseDanceWords', () {
    test('maps entries and defaults voice to lead, section to empty', () {
      final words = parseDanceWords({
        'words': [
          {
            'start_sec': 1.0,
            'end_sec': 1.5,
            'word': 'hey',
            'voice': 'background',
            'section': 'chorus',
          },
          {'start_sec': 2.0, 'end_sec': 2.4, 'word': 'yo'},
        ],
      });
      expect(words, hasLength(2));
      expect(words[0], (
        start: 1.0,
        end: 1.5,
        word: 'hey',
        voice: 'background',
        section: 'chorus',
      ));
      expect(words[1].voice, 'lead', reason: 'default voice');
      expect(words[1].section, '', reason: 'default section');
    });

    test('skips entries missing either timestamp', () {
      final words = parseDanceWords({
        'words': [
          {'start_sec': 1.0, 'word': 'no-end'},
          {'end_sec': 2.0, 'word': 'no-start'},
          {'start_sec': 3.0, 'end_sec': 3.5, 'word': 'ok'},
        ],
      });
      expect(words.map((w) => w.word), ['ok']);
    });

    test('absent words key → empty list', () {
      expect(parseDanceWords(const {}), isEmpty);
    });
  });

  group('parseDanceCues', () {
    test('maps cues and defaults a missing shape to X (rest)', () {
      final cues = parseDanceCues({
        'cues': [
          {'start_sec': 0.0, 'end_sec': 0.2, 'shape': 'D'},
          {'start_sec': 0.2, 'end_sec': 0.4},
        ],
      });
      expect(cues[0].shape, 'D');
      expect(cues[1].shape, 'X', reason: 'default rest shape');
    });

    test('absent cues key → empty list', () {
      expect(parseDanceCues(const {}), isEmpty);
    });
  });

  group('load* file IO', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('dance_loaders'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a missing file degrades gracefully to an empty list', () async {
      final missing = p.join(dir.path, 'nope.json');
      expect(await loadDanceWords(missing), isEmpty);
      expect(await loadDanceCues(missing), isEmpty);
    });

    test('malformed JSON degrades gracefully to an empty list', () async {
      final bad = File(p.join(dir.path, 'bad.json'))
        ..writeAsStringSync('{ not json');
      expect(await loadDanceWords(bad.path), isEmpty);
      expect(await loadDanceCues(bad.path), isEmpty);
    });

    test('a valid file round-trips through the parser', () async {
      final file = File(p.join(dir.path, 'words.json'))
        ..writeAsStringSync(
          jsonEncode({
            'words': [
              {
                'start_sec': 1.0,
                'end_sec': 1.5,
                'word': 'hi',
                'voice': 'lead',
                'section': 'verse',
              },
            ],
          }),
        );
      final words = await loadDanceWords(file.path);
      expect(words, hasLength(1));
      expect(words.single.word, 'hi');
    });
  });
}
