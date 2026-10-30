import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_tokenizer.dart';

import 'tokenizer_json.dart';

void main() {
  /// Encodes [text] and spells the ids back as their tokens, `<bos>` and
  /// `<eos>` left out, so expectations read as text.
  List<String> tokensOf(Map<String, dynamic> json, String text) {
    final tokenizer = GemmaTokenizer.fromTokenizerJson(json);
    final vocab =
        (json['model'] as Map<String, dynamic>)['vocab'] as Map<String, int>;
    final byId = {for (final e in vocab.entries) e.value: e.key};
    final ids = tokenizer.encode(text);
    expect(ids.first, tokenizer.bosId);
    expect(ids.last, tokenizer.eosId);
    return [for (final id in ids.sublist(1, ids.length - 1)) byId[id]!];
  }

  test('wraps every encoding in <bos> and <eos>, the empty text too', () {
    final tokenizer = GemmaTokenizer.fromTokenizerJson(tokenizerJson());

    expect(tokenizer.bosId, 2);
    expect(tokenizer.eosId, 1);
    expect(tokenizer.encode(''), [2, 1]);
  });

  group('maxLength', () {
    final json = tokenizerJson(tokens: ['a', 'b', 'c']);
    final tokenizer = GemmaTokenizer.fromTokenizerJson(json);
    final a = tokenizer.encode('a')[1];
    final b = tokenizer.encode('b')[1];
    final c = tokenizer.encode('c')[1];

    test('cuts the text from the end, keeping <bos> and <eos>', () {
      expect(tokenizer.encode('abc', maxLength: 4), [2, a, b, 1]);
      expect(tokenizer.encode('abc', maxLength: 2), [2, 1]);
    });

    test('leaves an encoding that fits alone', () {
      expect(tokenizer.encode('abc', maxLength: 5), [2, a, b, c, 1]);
      expect(tokenizer.encode('abc', maxLength: 6), [2, a, b, c, 1]);
    });

    test('needs room for <bos> and <eos>', () {
      expect(
        () => tokenizer.encode('abc', maxLength: 1),
        throwsArgumentError,
      );
    });
  });

  test("takes <bos> and <eos> from the post-processor's own table", () {
    final tokenizer = GemmaTokenizer.fromTokenizerJson(
      tokenizerJson(
        postProcessor: {
          ...bosEosTemplate,
          'special_tokens': {
            '<bos>': {
              'ids': [7],
            },
            '<eos>': {
              'ids': [8],
            },
          },
        },
      ),
    );

    expect(tokenizer.encode(''), [7, 8]);
  });

  test('marks spaces with ▁ and merges across them into one word', () {
    final json = tokenizerJson(
      tokens: ['a', 'b', '▁', '▁b', 'a▁b'],
      merges: [
        ['▁', 'b'],
        ['a', '▁b'],
      ],
    );

    expect(tokensOf(json, 'a b'), ['a▁b']);
    expect(tokensOf(json, 'b  b'), ['b', '▁', '▁b']);
  });

  test('merges the lowest rank first, wherever it sits', () {
    final json = tokenizerJson(
      tokens: ['a', 'b', 'c', 'ab', 'bc'],
      merges: [
        ['b', 'c'],
        ['a', 'b'],
      ],
    );

    expect(tokensOf(json, 'abc'), ['a', 'bc']);
  });

  test('merges the leftmost of equally ranked pairs first', () {
    final json = tokenizerJson(
      tokens: ['a', 'aa'],
      merges: [
        ['a', 'a'],
      ],
    );

    expect(tokensOf(json, 'aaa'), ['aa', 'a']);
  });

  test('keeps merging the pairs earlier merges create', () {
    final json = tokenizerJson(
      tokens: ['a', 'b', 'aa', 'aaaa', 'aab'],
      merges: [
        ['a', 'a'],
        ['aa', 'aa'],
        ['aa', 'b'],
      ],
    );

    expect(tokensOf(json, 'aaaa'), ['aaaa']);
    expect(tokensOf(json, 'aaaaaab'), ['aaaa', 'aab']);
  });

  test('accepts merges written as "left right" strings', () {
    final json = tokenizerJson(tokens: ['a', 'b', 'ab'], merges: ['a b']);

    expect(tokensOf(json, 'ab'), ['ab']);
  });

  test(
    'falls back to UTF-8 byte tokens for characters not in the vocabulary',
    () {
      final json = tokenizerJson(tokens: ['a']);

      expect(tokensOf(json, 'aé🐧'), [
        'a',
        '<0xC3>',
        '<0xA9>',
        '<0xF0>',
        '<0x9F>',
        '<0x90>',
        '<0xA7>',
      ]);
    },
  );

  test('cuts added tokens out of the raw text, the longest at each place', () {
    final json = tokenizerJson(
      tokens: ['a', 'b', 'ab'],
      merges: [
        ['a', 'b'],
      ],
      addedTokens: ['\n', '\n\n', '<turn>'],
    );

    expect(tokensOf(json, 'a\n\n\nb'), ['a', '\n\n', '\n', 'b']);
    // No merge reaches across an added token.
    expect(tokensOf(json, 'a<turn>b'), ['a', '<turn>', 'b']);
    expect(tokensOf(json, '<bos>ab<tur'), [
      '<bos>',
      'ab',
      '<0x3C>',
      '<0x74>',
      '<0x75>',
      '<0x72>',
    ]);
  });

  group('rejects a tokenizer.json it does not implement', () {
    void expectRejected(Map<String, dynamic> json) => expect(
      () => GemmaTokenizer.fromTokenizerJson(json),
      throwsFormatException,
    );

    test('another model type or flag', () {
      expectRejected(tokenizerJson(modelOverrides: {'type': 'WordPiece'}));
      expectRejected(tokenizerJson(modelOverrides: {'byte_fallback': false}));
      expectRejected(tokenizerJson(modelOverrides: {'dropout': 0.1}));
      expectRejected(
        tokenizerJson(modelOverrides: {'continuing_subword_prefix': '##'}),
      );
      expectRejected(
        tokenizerJson(modelOverrides: {'end_of_word_suffix': '</w>'}),
      );
      expectRejected(tokenizerJson(modelOverrides: {'ignore_merges': true}));
    });

    test('another normalizer or pre-tokenizer', () {
      expectRejected(tokenizerJson(normalizer: null));
      expectRejected(tokenizerJson(normalizer: {'type': 'NFKC'}));
      expectRejected(
        tokenizerJson(preTokenizer: {'type': 'Whitespace'}),
      );
      expectRejected(
        tokenizerJson(
          preTokenizer: {
            'type': 'Split',
            'pattern': {'String': '-'},
          },
        ),
      );
    });

    test('a post-processor other than <bos> … <eos>', () {
      final single = bosEosTemplate['single']! as List<Object>;
      for (final processor in <Object?>[
        null,
        {'type': 'ByteLevel'},
        {'type': 'TemplateProcessing', 'single': single.sublist(1)},
        {'type': 'TemplateProcessing', 'single': 'not a list'},
        {
          'type': 'TemplateProcessing',
          'single': [single[0], single[1], single[0]],
        },
        {
          'type': 'TemplateProcessing',
          'single': [single[1], single[0], single[2]],
        },
        {
          'type': 'TemplateProcessing',
          'single': [
            single[0],
            {
              'Sequence': {'id': 'A', 'type_id': 1},
            },
            single[2],
          ],
        },
        {
          'type': 'TemplateProcessing',
          'single': [single[0], 'A', single[2]],
        },
      ]) {
        expectRejected(tokenizerJson(postProcessor: processor));
      }
    });

    test('added tokens matched after normalization or with stripping', () {
      expectRejected(
        tokenizerJson(addedTokenOverrides: {'normalized': true}),
      );
      expectRejected(tokenizerJson(addedTokenOverrides: {'lstrip': true}));
      expectRejected(tokenizerJson(addedTokenOverrides: {'rstrip': true}));
      expectRejected(
        tokenizerJson(addedTokenOverrides: {'single_word': true}),
      );
    });

    test('ids too large to pack', () {
      final json = tokenizerJson();
      ((json['model'] as Map<String, dynamic>)['vocab']
              as Map<String, int>)['huge'] =
          1 << 18;
      expectRejected(json);
    });

    test('a vocabulary missing byte tokens, or a merge outside it', () {
      expectRejected(tokenizerJson(withBytes: false));
      expectRejected(
        tokenizerJson(
          tokens: ['a', 'b'],
          merges: [
            ['a', 'b'],
          ],
        ),
      );
      expectRejected(tokenizerJson(tokens: ['a', 'b', 'ab'], merges: ['ab']));
    });

    test('a post-processor without one id for <bos> and for <eos>', () {
      for (final specialTokens in <Object?>[
        null,
        'not a map',
        <String, Object>{},
        {
          '<bos>': {'ids': 2},
          '<eos>': {
            'ids': [1],
          },
        },
        {
          '<bos>': {
            'ids': [2, 3],
          },
          '<eos>': {
            'ids': [1],
          },
        },
        {
          '<bos>': {
            'ids': [2],
          },
          '<eos>': {
            'ids': ['1'],
          },
        },
      ]) {
        expectRejected(
          tokenizerJson(
            postProcessor: {
              ...bosEosTemplate,
              'special_tokens': specialTokens,
            },
          ),
        );
      }
    });

    test('an inverted split', () {
      expectRejected(
        tokenizerJson(
          preTokenizer: {
            'type': 'Split',
            'pattern': {'String': ' '},
            'behavior': 'Removed',
            'invert': true,
          },
        ),
      );
    });
  });

  test('a pre-tokenizer may be absent', () {
    final json = tokenizerJson(preTokenizer: null, tokens: ['a']);

    expect(tokensOf(json, 'a a'), ['a', '<0xE2>', '<0x96>', '<0x81>', 'a']);
  });
}
