import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/utils/entry_utils.dart';

void main() {
  group('Entry utils', () {
    test('entryTextFromPlain returns null when provided a null value', () {
      expect(entryTextFromPlain(null), null);
    });

    test('entryTextFromPlain returns expected EntryText', () {
      expect(
        entryTextFromPlain('some entry text'),
        const EntryText(
          plainText: 'some entry text\n',
          quill: r'[{"insert":"some entry text\n"}]',
          markdown: 'some entry text\n',
        ),
      );
    });

    glados.Glados(
      glados.any.generatedPlainEntryText,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'entryTextFromPlain preserves generated text and emits valid Quill JSON',
      (scenario) {
        final result = entryTextFromPlain(scenario.plain);

        expect(result, isNotNull, reason: '$scenario');
        expect(result!.plainText, '${scenario.plain}\n', reason: '$scenario');
        expect(result.markdown, '${scenario.plain}\n', reason: '$scenario');
        expect(result.quill, isNotNull, reason: '$scenario');
        expect(
          jsonDecode(result.quill!),
          [
            {'insert': '${scenario.plain}\n'},
          ],
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });
}

enum _GeneratedPlainTextChunk {
  word,
  space,
  quote,
  backslash,
  newline,
  carriageReturn,
  tab,
  markdownLink,
  jsonPunctuation,
}

class _GeneratedPlainEntryText {
  const _GeneratedPlainEntryText(this.chunks);

  final List<_GeneratedPlainTextChunk> chunks;

  String get plain => chunks.map((chunk) => chunk.text).join();

  @override
  String toString() => '_GeneratedPlainEntryText(plain: ${jsonEncode(plain)})';
}

extension on _GeneratedPlainTextChunk {
  String get text => switch (this) {
    _GeneratedPlainTextChunk.word => 'text',
    _GeneratedPlainTextChunk.space => ' ',
    _GeneratedPlainTextChunk.quote => '"quoted"',
    _GeneratedPlainTextChunk.backslash => r'\path\file',
    _GeneratedPlainTextChunk.newline => '\n',
    _GeneratedPlainTextChunk.carriageReturn => '\r',
    _GeneratedPlainTextChunk.tab => '\t',
    _GeneratedPlainTextChunk.markdownLink => '[label](https://example.com)',
    _GeneratedPlainTextChunk.jsonPunctuation => '{}[],:',
  };
}

extension _AnyEntryUtils on glados.Any {
  glados.Generator<_GeneratedPlainTextChunk> get _plainTextChunk =>
      glados.AnyUtils(this).choose(_GeneratedPlainTextChunk.values);

  glados.Generator<_GeneratedPlainEntryText> get generatedPlainEntryText =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 20, _plainTextChunk)
          .map(_GeneratedPlainEntryText.new);
}
