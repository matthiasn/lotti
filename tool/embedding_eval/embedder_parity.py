"""Writes the vectors ONNX Runtime and `tokenizers` give EmbeddingGemma for a
sample of the corpus, embedded as `evaluate.py` embeds them, for
`embedder_parity_test.dart` to compare the app's embedder against.

    python tool/embedding_eval/embedder_parity.py --models-dir DIR

Writes `build/embedding_eval/vectors.json` (or `--out`).
"""

import argparse
import json
from pathlib import Path

import numpy as np

from evaluate import MODELS, Embedder

SAMPLE_PER_LANGUAGE = 4
LONG_TEXT = 'The colony counts its penguins before every launch. ' * 120


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--models-dir', type=Path, required=True)
    parser.add_argument('--corpus', type=Path,
                        default=Path('build/embedding_eval/corpus.json'))
    parser.add_argument('--out', type=Path,
                        default=Path('build/embedding_eval/vectors.json'))
    args = parser.parse_args()

    spec = next(m for m in MODELS if m.name == 'EmbeddingGemma-300m q4')
    embedder = Embedder.load(args.models_dir, spec, threads=4)
    corpus = json.loads(args.corpus.read_text())

    samples = [('document', LONG_TEXT), ('query', '')]
    for language in corpus.values():
        samples += [('document', task['text'])
                    for task in language['tasks'][:SAMPLE_PER_LANGUAGE]]
        samples += [('query', query['text'])
                    for query in language['queries'][:SAMPLE_PER_LANGUAGE]]

    cases = []
    for kind, text in samples:
        vector = embedder.embed(text, query=kind == 'query')
        vector = vector / np.linalg.norm(vector)
        cases.append({'kind': kind, 'text': text,
                      'vector': [float(v) for v in vector]})
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(cases, ensure_ascii=False))
    print(f'{len(cases)} vectors -> {args.out}')


if __name__ == '__main__':
    main()
