import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/provenance/crypto/canonical_json.dart';

/// A string from arbitrary Unicode scalar values (surrogate code points,
/// which are not scalar values, are mapped to 'A').
String _stringFrom(List<int> codePoints) => String.fromCharCodes(
  codePoints.map((cp) => cp >= 0xD800 && cp <= 0xDFFF ? 0x41 : cp),
);

void main() {
  group('canonicalJson', () {
    // RFC 8785 section 3.2.3: members sorted by UTF-16 code units, so the
    // emoji (surrogates D83D DE00) sorts before U+FB33.
    test('sorts members by UTF-16 code units, as RFC 8785 shows', () {
      final json = canonicalJson(<String, Object?>{
        '€': 'Euro Sign',
        '\r': 'Carriage Return',
        'דּ': 'Hebrew Letter Dalet With Dagesh',
        '1': 'One',
        '\u{1F600}': 'Emoji: Grinning Face',
        '\u0080': 'Control',
        'ö': 'Latin Small Letter O With Diaeresis',
      });

      final keys = (jsonDecode(json) as Map<String, Object?>).keys.toList();
      expect(keys, [
        '\r',
        '1',
        '\u0080',
        'ö',
        '€',
        '\u{1F600}',
        'דּ',
      ]);
      expect(json, startsWith(r'{"\r":"Carriage Return","1":"One",'));
    });

    test('escapes exactly what RFC 8785 escapes', () {
      expect(
        canonicalJson('"\\\b\t\n\f\r\u0001\u001f\u007f/é€'),
        r'"\"\\\b\t\n\f\r\u0001\u001f'
        '\u007f/é€"',
      );
    });

    test('writes literals, integers and nesting without whitespace', () {
      expect(
        canonicalJson(<String, Object?>{
          'b': [true, false, null, -3, 0],
          'a': <String, Object?>{},
          'c': <Object?>[],
        }),
        '{"a":{},"b":[true,false,null,-3,0],"c":[]}',
      );
    });

    test('accepts the full exact integer range and nothing beyond it', () {
      expect(canonicalJson(maxCanonicalInt), '9007199254740991');
      expect(canonicalJson(-maxCanonicalInt), '-9007199254740991');
      expect(
        () => canonicalJson(maxCanonicalInt + 1),
        throwsA(isA<CanonicalJsonException>()),
      );
    });

    for (final (label, value) in <(String, Object?)>[
      ('a double', 1.5),
      ('an integral double', 1.0),
      ('NaN', double.nan),
      ('a lone high surrogate', 'a\ud800'),
      ('a lone low surrogate', '\udc00b'),
      ('a non-string key', <Object?, Object?>{1: 'x'}),
      ('an unsupported type', DateTime(2026)),
    ]) {
      test('rejects $label', () {
        expect(
          () => canonicalJson(value),
          throwsA(isA<CanonicalJsonException>()),
        );
      });
    }
  });

  group('parseCanonicalJson', () {
    test('accepts canonical bytes', () {
      expect(parseCanonicalJson(utf8.encode('{"a":1,"b":[null]}')), {
        'a': 1,
        'b': [null],
      });
    });

    for (final (label, text) in <(String, String)>[
      ('unsorted members', '{"b":1,"a":2}'),
      ('whitespace', '{"a": 1}'),
      ('an unnecessary escape', r'"\u0041"'),
      ('an upper-case escape', r'"\u001F"'),
      ('a float', '1.0'),
      ('an exponent', '1e2'),
    ]) {
      test('rejects $label', () {
        expect(
          () => parseCanonicalJson(utf8.encode(text)),
          throwsA(isA<CanonicalJsonException>()),
        );
      });
    }

    test('an error names the problem', () {
      expect(
        const CanonicalJsonException('lone low surrogate').toString(),
        'CanonicalJsonException: lone low surrogate',
      );
    });

    test('rejects bytes that are not JSON', () {
      expect(
        () => parseCanonicalJson(utf8.encode('{"a":')),
        throwsA(isA<CanonicalJsonException>()),
      );
    });
  });

  glados.Glados<List<MapEntry<String, int>>>(
    glados.any.list(
      glados.any.mapEntry(glados.any.letterOrDigits, glados.any.int32),
    ),
    glados.ExploreConfig(numRuns: 200),
  ).test(
    'member order in the input never changes the bytes',
    (entries) {
      final forward = Map<String, int>.fromEntries(entries);
      final backward = Map<String, int>.fromEntries(
        forward.entries.toList().reversed,
      );
      expect(canonicalJsonBytes(backward), canonicalJsonBytes(forward));
    },
    tags: 'glados',
  );

  glados.Glados<List<int>>(
    glados.any.listWithLengthInRange(
      0,
      16,
      glados.any.intInRange(0, 0x110000),
    ),
    glados.ExploreConfig(numRuns: 300),
  ).test(
    'any Unicode string survives encode, decode and re-encode unchanged',
    (codePoints) {
      final value = <String, Object?>{
        _stringFrom(codePoints): _stringFrom(codePoints.reversed.toList()),
      };
      final bytes = canonicalJsonBytes(value);
      final decoded = parseCanonicalJson(bytes);
      expect(decoded, value);
      expect(canonicalJsonBytes(decoded), bytes);
    },
    tags: 'glados',
  );
}
