import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/gemini_stream_parser.dart';

void main() {
  group('GeminiStreamParser', () {
    test('parses simple NDJSON objects', () {
      final parser = GeminiStreamParser();
      final line1 = jsonEncode({'a': 1});
      final line2 = jsonEncode({'b': 2});
      final out = parser.addChunk('$line1\n$line2\n');
      expect(out.length, 2);
      expect(out[0]['a'], 1);
      expect(out[1]['b'], 2);
      expect(parser.remainder(), isEmpty);
    });

    test('parses SSE data: lines with inline JSON payloads', () {
      final parser = GeminiStreamParser();
      final a = jsonEncode({'x': 'y'});
      final b = jsonEncode({'ok': true});
      final mixed = 'data: $a\n' // inline payload
          'data: ignore-this\n' // non-JSON payload should be dropped
          'data:   $b\n';
      final out = parser.addChunk(mixed);
      expect(out.length, 2);
      expect(out[0]['x'], 'y');
      expect(out[1]['ok'], true);
    });

    test('parses JSON array framing with commas and brackets', () {
      final parser = GeminiStreamParser();
      final o1 = jsonEncode({'i': 1});
      final o2 = jsonEncode({'i': 2});
      final chunk = ' [ $o1 , $o2 ] '; // leading space/brackets/commas
      final out = parser.addChunk(chunk);
      expect(out.length, 2);
      expect(out[0]['i'], 1);
      expect(out[1]['i'], 2);
      expect(parser.remainder(), isEmpty);
    });

    test('handles objects spanning multiple chunks', () {
      final parser = GeminiStreamParser();
      const part1 = '{"foo": {"bar": 1';
      const part2 = '}, "baz": 2}';
      var out = parser.addChunk(part1);
      expect(out, isEmpty);
      expect(parser.remainder(), isNotEmpty);
      out = parser.addChunk(part2);
      expect(out.length, 1);
      final foo = out.first['foo'] as Map<String, dynamic>;
      expect(foo['bar'], 1);
      expect(out.first['baz'], 2);
      expect(parser.remainder(), isEmpty);
    });

    test('ignores braces inside string literals', () {
      final parser = GeminiStreamParser();
      const obj = r'{"t": "text with { braces } and \"escapes\""}';
      final out = parser.addChunk(obj);
      expect(out.length, 1);
      expect(out.first['t'], contains('{ braces }'));
    });

    test('mixed NDJSON + SSE + array framing', () {
      final parser = GeminiStreamParser();
      final a = jsonEncode({'a': 1});
      final b = jsonEncode({'b': 2});
      final c = jsonEncode({'c': 3});
      final mixed = 'data: $a\n[$b,\n$c]';
      final out = parser.addChunk(mixed);
      expect(out.map((e) => e.keys.first).toList(), ['a', 'b', 'c']);
    });

    test('malformed object is skipped and scanning continues', () {
      final parser = GeminiStreamParser();
      const bad = '{a:b}';
      final good = jsonEncode({'ok': true});
      final out = parser.addChunk('$bad$good');
      expect(out.length, 1);
      expect(out.first['ok'], true);
    });

    test('respects maxBufferSize and trims from the left', () {
      final small = GeminiStreamParser(maxBufferSize: 32);
      // Create a long prefix with junk, then a valid object
      final junk = 'x' * 100; // 100 characters
      final obj = jsonEncode({'z': 9});
      final out = small.addChunk('$junk$obj');
      // We still parse the object; buffer should not exceed cap
      expect(out.length, 1);
      expect(out.first['z'], 9);
      expect(small.remainder().length <= 32, isTrue);
    });
  });
}
