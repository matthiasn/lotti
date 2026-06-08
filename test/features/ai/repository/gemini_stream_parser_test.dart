import 'dart:convert';

import 'package:glados/glados.dart';
import 'package:lotti/features/ai/repository/gemini_stream_parser.dart';

class _GeminiPayload {
  const _GeminiPayload({
    required this.text,
    required this.number,
    required this.flag,
  });

  final String text;
  final int number;
  final bool flag;

  Map<String, dynamic> toJson() => {
    'text': text,
    'number': number,
    'flag': flag,
    'nested': {'braced': '{$text}'},
  };
}

extension _AnyGeminiPayload on Any {
  Generator<_GeminiPayload> get geminiPayload => combine3(
    nonEmptyLetterOrDigits,
    intInRange(-100, 100),
    any.bool,
    (String text, int number, bool flag) => _GeminiPayload(
      text: text,
      number: number,
      flag: flag,
    ),
  );

  Generator<List<_GeminiPayload>> get geminiPayloads =>
      listWithLengthInRange(0, 8, geminiPayload);
}

List<String> _splitRandomly(String text, Random random) {
  if (text.isEmpty) return [''];

  final chunks = <String>[];
  var index = 0;
  while (index < text.length) {
    final remaining = text.length - index;
    final width = 1 + random.nextInt(remaining);
    chunks.add(text.substring(index, index + width));
    index += width;
  }
  return chunks;
}

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
      final mixed =
          'data: $a\n' // inline payload
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

    Glados(any.geminiPayloads).testWithRandom(
      'parses the same objects regardless of stream chunk boundaries',
      (payloads, random) {
        final payload = payloads.map((p) => jsonEncode(p.toJson())).join('\n');

        final wholeParser = GeminiStreamParser();
        final whole = wholeParser.addChunk(payload);

        final chunkedParser = GeminiStreamParser();
        final chunked = <Map<String, dynamic>>[];
        for (final chunk in _splitRandomly(payload, random)) {
          chunked.addAll(chunkedParser.addChunk(chunk));
        }

        expect(chunked, whole);
        expect(chunkedParser.remainder(), wholeParser.remainder());
      },
      tags: 'glados',
    );

    // Property for the maxBufferSize trim+align invariant: even when a junk
    // prefix that on its own exceeds the cap arrives before a valid object,
    // the object is still recovered once it completes. The junk is generated
    // without any '{' so the left-trim's "align to next '{'" step cannot chop
    // into the object that follows. The junk is fed first so that, when the
    // object arrives in the next chunk, the trim path runs against an already
    // over-cap buffer (the worst case for the trim+align logic). Note: the cap
    // bounds growth across calls, not a single oversized chunk, so we assert on
    // object recovery rather than on a hard buffer-length bound after the junk.
    Glados3(
      any.intInRange(1, 64), // cap
      any.intInRange(0, 200), // extra junk beyond the cap
      any.nonEmptyLetterOrDigits, // brace-free value placed in the object
      // Cheaper than the default; pure in-memory string scanning.
      ExploreConfig(numRuns: 120),
    ).test(
      'recovers a valid object after an oversized junk prefix',
      (cap, extraJunk, value) {
        final parser = GeminiStreamParser(maxBufferSize: cap);
        final junk = 'x' * (cap + extraJunk);
        // First chunk: pure junk, no braces. Nothing completes yet.
        final firstOut = parser.addChunk(junk);
        expect(firstOut, isEmpty);
        // The all-'x' junk leaves no '{' to trim/align against, so it stays
        // buffered verbatim; it must not have produced any objects.
        expect(parser.remainder(), junk);

        // Second chunk: a complete, valid JSON object. This is where the
        // trim+align path runs against an over-cap buffer.
        final obj = jsonEncode({'v': value});
        final out = parser.addChunk(obj);

        expect(out.length, 1);
        expect(out.first['v'], value);
        // After parsing the only object, no remainder lingers.
        expect(parser.remainder(), isEmpty);
      },
      tags: 'glados',
    );
  });
}
