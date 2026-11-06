import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Daily OS overlines, badges and eyebrows are written in sentence case and
/// shown as written: no style or widget upper-cases them on the way out, so
/// the catalog is the one place casing can go wrong. Twenty-four of them once
/// shipped in capitals ("FINAL STEP", "🎤 REFINEMENT"), so this reads every
/// catalog and fails on any `dailyOs*` value carrying a fully capitalised
/// word.
void main() {
  // Four or more capitals in a row, in any script: "HEARD", "ÉNERGIE". Short
  // acronyms (AI, OS, TTS) stay legal.
  final shoutedWord = RegExp(r'\p{Lu}{4,}', unicode: true);

  final catalogs = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.arb'))
      .toList();

  test('finds the catalogs', () {
    expect(catalogs.length, greaterThanOrEqualTo(11));
  });

  for (final catalog in catalogs) {
    test('${catalog.uri.pathSegments.last} writes Daily OS labels in '
        'sentence case', () {
      final entries = jsonDecode(catalog.readAsStringSync()) as Map;
      final shouted = <String, String>{
        for (final MapEntry(:key, :value) in entries.entries)
          if (key is String &&
              key.startsWith('dailyOs') &&
              value is String &&
              shoutedWord.hasMatch(value))
            key: value,
      };
      expect(shouted, isEmpty);
    });
  }
}
