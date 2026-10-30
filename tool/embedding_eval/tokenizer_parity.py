"""Writes the token ids Hugging Face `tokenizers` gives EmbeddingGemma's input,
for `tokenizer_parity_test.dart` to compare the app's Dart port against.

The texts are what the app will feed the model: every corpus text with the
document prompt, every query and paraphrase with the query prompt, and edge
cases the corpus does not reach (added tokens inside text, newline runs,
characters outside the vocabulary, long input). Each text is also encoded
truncated: at the 512 tokens the app allows, and at 16 and 2.

    python tool/embedding_eval/tokenizer_parity.py --models-dir DIR

Writes `build/embedding_eval/token_ids.json` (or `--out`).
"""

import argparse
import json
from pathlib import Path

from tokenizers import Tokenizer

MODEL = 'embeddinggemma-300m-ONNX'
QUERY = 'task: search result | query: '
DOCUMENT = 'title: none | text: '

EDGE_CASES = [
    '',
    ' ',
    '   leading and trailing   ',
    'a',
    'double  space',
    'tabs\tand\t\ttabs',
    'one\ntwo\n\nthree\n\n\n\nfour',
    '\n\n\n',
    'line\r\nbreak',
    '<start_of_turn>user\nhello<end_of_turn>',
    'a literal <bos> and <eos> and <pad> inside text',
    '<unknown_tag> [not a token]',
    '▁ the space mark itself ▁▁',
    'Grüße aus Zürich — naïve café, señor',
    'é combining acute, café',
    'Čeština: příliš žluťoučký kůň',
    '日本語のテキストと中文文本',
    '한국어 텍스트',
    'العربية نص',
    'emoji 🐧🐧 and 👩‍💻 and 🇩🇪',
    'math ∑∫√ and symbols ©®™',
    '\u200b zero width \ufeff bom',
    '\U0001d11e musical symbol, \U00010348 gothic',
    'https://github.com/matthiasn/lotti/pull/4879#issuecomment-1',
    'snake_case_identifier and camelCaseIdentifier',
    '1234567890 3.14159 1e-9 0x1F',
    '!!!???...,,,;;;',
    'penguin ' * 400,
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--models-dir', type=Path, required=True)
    parser.add_argument('--corpus', type=Path,
                        default=Path('build/embedding_eval/corpus.json'))
    parser.add_argument('--out', type=Path,
                        default=Path('build/embedding_eval/token_ids.json'))
    args = parser.parse_args()

    tokenizer = Tokenizer.from_file(
        str(args.models_dir / MODEL / 'tokenizer.json'))
    corpus = json.loads(args.corpus.read_text())
    paraphrases = json.loads(
        Path(__file__).with_name('paraphrases.json').read_text())

    texts = list(EDGE_CASES)
    for language in corpus.values():
        texts += [DOCUMENT + task['text'] for task in language['tasks']]
        texts += [QUERY + query['text'] for query in language['queries']]
    texts += [QUERY + query
              for by_language in paraphrases.values()
              for queries in by_language.values()
              for query in queries]

    texts = list(dict.fromkeys(texts))
    cases = [{'text': text, 'ids': tokenizer.encode(text).ids}
             for text in texts]
    # Truncated as the app truncates its input: at the model's limit, and
    # short enough that every text is cut.
    for max_length, sample in ((512, texts), (16, texts), (2, EDGE_CASES)):
        tokenizer.enable_truncation(max_length)
        cases += [{'text': text, 'max_length': max_length,
                   'ids': tokenizer.encode(text).ids} for text in sample]
    tokenizer.no_truncation()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(cases, ensure_ascii=False))
    print(f'{len(cases)} encodings, '
          f'{sum(len(c["ids"]) for c in cases)} tokens -> {args.out}')


if __name__ == '__main__':
    main()
