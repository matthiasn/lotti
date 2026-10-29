"""Scores on-device embedding models on Lotti's multilingual retrieval task.

The corpus is the penguin demo world in every language the demo seed speaks
(`export_corpus_test.dart` writes it). Each checklist item and linked note is
a query whose right answer is the task it belongs to, among all the world's
tasks — the semantic step task search needs: a note phrased unlike its task
should still find it. A BM25 run over the same corpus, through SQLite FTS5
with the tokenizer the app's index uses, is the keyword baseline.

Usage (ONNX Runtime pinned to the oldest version the app ships — 1.24.2,
iOS; Linux and Android ship 1.27.0 — so a variant that needs a newer operator
fails here rather than on a phone):

    python tool/embedding_eval/evaluate.py --models-dir DIR [--corpus PATH]

DIR holds the Hugging Face snapshots named in MODELS. Writes a Markdown
report and a JSON summary next to the corpus.
"""
from __future__ import annotations

import argparse
import json
import os
import resource
import sqlite3
import statistics
import time
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import onnxruntime as ort
from tokenizers import Tokenizer


@dataclass(frozen=True)
class ModelSpec:
    name: str
    folder: str
    file: str
    query_prefix: str
    document_prefix: str
    pooling: str  # 'sentence' (the export pools) or 'mean'
    dims: tuple[int, ...] = (0,)  # 0 is the model's full width
    max_tokens: int = 512


GEMMA_QUERY = 'task: search result | query: '
GEMMA_DOCUMENT = 'title: none | text: '

MODELS = [
    ModelSpec('EmbeddingGemma-300m q4', 'embeddinggemma-300m-ONNX',
              'onnx/model_q4.onnx', GEMMA_QUERY, GEMMA_DOCUMENT, 'sentence',
              dims=(0, 256)),
    ModelSpec('EmbeddingGemma-300m q4 (no gather)', 'embeddinggemma-300m-ONNX',
              'onnx/model_no_gather_q4.onnx', GEMMA_QUERY, GEMMA_DOCUMENT,
              'sentence'),
    ModelSpec('EmbeddingGemma-300m int8', 'embeddinggemma-300m-ONNX',
              'onnx/model_quantized.onnx', GEMMA_QUERY, GEMMA_DOCUMENT,
              'sentence', dims=(0, 256)),
    ModelSpec('EmbeddingGemma-300m fp32', 'embeddinggemma-300m-ONNX',
              'onnx/model.onnx', GEMMA_QUERY, GEMMA_DOCUMENT, 'sentence'),
    ModelSpec('multilingual-e5-small int8', 'multilingual-e5-small',
              'onnx/model_int8.onnx', 'query: ', 'passage: ', 'mean'),
    ModelSpec('multilingual-e5-small fp32', 'multilingual-e5-small',
              'onnx/model.onnx', 'query: ', 'passage: ', 'mean'),
]


@dataclass
class Embedder:
    spec: ModelSpec
    session: ort.InferenceSession
    tokenizer: Tokenizer
    inputs: set[str] = field(default_factory=set)

    @classmethod
    def load(cls, models_dir: Path, spec: ModelSpec, threads: int) -> Embedder:
        root = models_dir / spec.folder
        options = ort.SessionOptions()
        options.intra_op_num_threads = threads
        options.inter_op_num_threads = 1
        session = ort.InferenceSession(
            str(root / spec.file), options, providers=['CPUExecutionProvider'],
        )
        tokenizer = Tokenizer.from_file(str(root / 'tokenizer.json'))
        tokenizer.no_padding()
        tokenizer.enable_truncation(spec.max_tokens)
        return cls(spec, session, tokenizer,
                   {i.name for i in session.get_inputs()})

    def embed(self, text: str, *, query: bool) -> np.ndarray:
        prefix = self.spec.query_prefix if query else self.spec.document_prefix
        encoding = self.tokenizer.encode(prefix + text)
        ids = np.array([encoding.ids], dtype=np.int64)
        mask = np.ones_like(ids)
        feeds = {'input_ids': ids, 'attention_mask': mask}
        if 'token_type_ids' in self.inputs:
            feeds['token_type_ids'] = np.zeros_like(ids)
        names = [o.name for o in self.session.get_outputs()]
        outputs = dict(zip(names, self.session.run(None, feeds)))
        if self.spec.pooling == 'sentence' and 'sentence_embedding' in outputs:
            vector = outputs['sentence_embedding'][0]
        else:
            hidden = outputs.get('last_hidden_state', next(iter(outputs.values())))[0]
            vector = hidden.mean(0)
        return vector.astype(np.float32)


def normalise(matrix: np.ndarray, dims: int) -> np.ndarray:
    cut = matrix if dims == 0 else matrix[:, :dims]
    return cut / np.linalg.norm(cut, axis=1, keepdims=True)


def rank_metrics(ranks: list[int | None]) -> dict[str, float]:
    """Recall and mean reciprocal rank; a rank of None is an answer the
    ranking never retrieved, which earns nothing."""
    return {
        'recall@1': sum(r == 1 for r in ranks) / len(ranks),
        'recall@5': sum(r is not None and r <= 5 for r in ranks) / len(ranks),
        'mrr': sum(1 / r for r in ranks if r is not None) / len(ranks),
    }


def words(text: str) -> set[str]:
    """Lower-cased words of three letters or more, accents folded."""
    import unicodedata
    folded = ''.join(c for c in unicodedata.normalize('NFKD', text.lower())
                     if not unicodedata.combining(c))
    return {w for w in ''.join(c if c.isalnum() else ' ' for c in folded).split()
            if len(w) >= 3}


def common_words(language: dict) -> set[str]:
    """Words in a quarter or more of [language]'s tasks — articles,
    prepositions, the colony's own name — which carry no weight in BM25 and
    say nothing about which task a query means."""
    counts: dict[str, int] = {}
    for task in language['tasks']:
        for word in words(task['text']):
            counts[word] = counts.get(word, 0) + 1
    return {w for w, n in counts.items() if n >= len(language['tasks']) / 4}


def disjoint(language: dict, query: dict) -> bool:
    """Whether [query] shares no distinctive word with the task it belongs
    to: the cases keyword search cannot find and embeddings exist for."""
    task = next(t for t in language['tasks'] if t['id'] == query['task'])
    shared = words(query['text']) & words(task['text'])
    return not (shared - common_words(language))


def bm25_orders(language: dict) -> list[list[str]]:
    """Each query's matching tasks in BM25 order — only those: a task the
    keywords do not match has no keyword rank, so fusing earns it nothing."""
    db = sqlite3.connect(':memory:')
    db.execute("CREATE VIRTUAL TABLE t USING fts5(id UNINDEXED, text, "
               "tokenize = 'unicode61 remove_diacritics 2')")
    db.executemany('INSERT INTO t VALUES (?, ?)',
                   [(task['id'], task['text']) for task in language['tasks']])
    orders = []
    for query in language['queries']:
        terms = [w for w in ''.join(
            c if c.isalnum() else ' ' for c in query['text']).split() if len(w) > 1]
        expression = ' OR '.join(f'"{w}"' for w in terms) or '""'
        found = [row[0] for row in db.execute(
            'SELECT id FROM t WHERE t MATCH ? ORDER BY rank', (expression,))]
        orders.append(found)
    return orders


def rrf(*orders: list[str], k: int = 60) -> list[str]:
    """Reciprocal rank fusion of several rankings of the same ids."""
    scores: dict[str, float] = {}
    for order in orders:
        for index, item in enumerate(order):
            scores[item] = scores.get(item, 0.0) + 1 / (k + index + 1)
    return sorted(scores, key=lambda item: -scores[item])


def bm25_ranks(language: dict) -> list[int | None]:
    """Each query's answer's BM25 rank, or None when BM25 does not match it."""
    return [order.index(query['task']) + 1 if query['task'] in order else None
            for order, query in zip(bm25_orders(language), language['queries'])]


def score(embedder: Embedder, corpus: dict) -> dict:
    embedded = {}
    for code, language in corpus.items():
        embedded[code] = (
            np.stack([embedder.embed(t['text'], query=False)
                      for t in language['tasks']]),
            np.stack([embedder.embed(q['text'], query=True)
                      for q in language['queries']]),
        )
    results: dict = {}
    for dims in embedder.spec.dims:
        per_language = {}
        per_type: dict[str, list[int]] = {}
        all_ranks: list[int] = []
        disjoint_ranks: list[int] = []
        hybrid_ranks: list[int] = []
        hybrid_disjoint: list[int] = []
        for code, language in corpus.items():
            task_ids = [task['id'] for task in language['tasks']]
            documents = normalise(embedded[code][0], dims)
            queries = normalise(embedded[code][1], dims)
            similarity = queries @ documents.T
            keyword_orders = bm25_orders(language)
            ranks = []
            for row, query, keyword in zip(
                    similarity, language['queries'], keyword_orders):
                order = [task_ids[i] for i in np.argsort(-row)]
                rank = order.index(query['task']) + 1
                ranks.append(rank)
                per_type.setdefault(query['type'], []).append(rank)
                hybrid = rrf(order, keyword).index(query['task']) + 1
                hybrid_ranks.append(hybrid)
                if disjoint(language, query):
                    disjoint_ranks.append(rank)
                    hybrid_disjoint.append(hybrid)
            per_language[code] = rank_metrics(ranks)
            all_ranks += ranks
        label = 'full' if dims == 0 else f'{dims}d'
        results[label] = {
            'overall': rank_metrics(all_ranks),
            'no_shared_words': rank_metrics(disjoint_ranks)
            | {'n': len(disjoint_ranks)},
            'hybrid': rank_metrics(hybrid_ranks),
            'hybrid_no_shared_words': rank_metrics(hybrid_disjoint),
            'languages': per_language,
            'types': {k: rank_metrics(v) for k, v in per_type.items()},
        }
    return results


def keyword_scores(corpus: dict) -> dict:
    ranks = [r for lang in corpus.values() for r in bm25_ranks(lang)]
    hard = [r for lang in corpus.values()
            for r, q in zip(bm25_ranks(lang), lang['queries'])
            if disjoint(lang, q)]
    return {'overall': rank_metrics(ranks),
            'no_shared_words': rank_metrics(hard) | {'n': len(hard)},
            'languages': {c: rank_metrics(bm25_ranks(l))
                          for c, l in corpus.items()}}


def paraphrase_corpus(corpus: dict, path: Path) -> dict:
    """The tasks of each language the paraphrase set covers, queried by the
    paraphrases: searches written for a task without reusing its words."""
    paraphrases = json.loads(path.read_text())
    languages = {code for by_code in paraphrases.values() for code in by_code}
    return {
        code: {
            'tasks': corpus[code]['tasks'],
            'queries': [
                {'id': f'{task_id}:{code}:{i}', 'type': 'paraphrase',
                 'text': text, 'task': task_id}
                for task_id, by_code in paraphrases.items()
                for i, text in enumerate(by_code.get(code, []))
            ],
        }
        for code in sorted(languages)
    }


def speed(models_dir: Path, spec: ModelSpec, corpus: dict) -> dict:
    sample = [q['text'] for q in corpus['en']['queries'][:40]] + \
             [t['text'] for t in corpus['de']['tasks'][:10]]
    timings = {}
    for threads in (1, 4):
        started = time.perf_counter()
        embedder = Embedder.load(models_dir, spec, threads)
        load = time.perf_counter() - started
        embedder.embed('warm up', query=True)
        laps = []
        for text in sample:
            started = time.perf_counter()
            embedder.embed(text, query=False)
            laps.append((time.perf_counter() - started) * 1000)
        timings[f'{threads}t'] = {
            'load_s': round(load, 2),
            'median_ms': round(statistics.median(laps), 1),
            'p95_ms': round(sorted(laps)[int(len(laps) * 0.95) - 1], 1),
        }
    return timings


def model_bytes(models_dir: Path, spec: ModelSpec) -> int:
    base = models_dir / spec.folder / spec.file
    return sum(p.stat().st_size for p in base.parent.glob(base.name + '*'))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--models-dir', type=Path, required=True)
    parser.add_argument('--corpus', type=Path,
                        default=Path('build/embedding_eval/corpus.json'))
    parser.add_argument('--only', help='run the models whose name contains this')
    args = parser.parse_args()
    corpus = json.loads(args.corpus.read_text())

    paraphrases = paraphrase_corpus(
        corpus, Path(__file__).with_name('paraphrases.json'))
    summary = {'onnxruntime': ort.__version__,
               'membership': {'bm25': keyword_scores(corpus)},
               'paraphrase': {'bm25': keyword_scores(paraphrases)},
               'models': {}}
    for spec in MODELS:
        if args.only and args.only not in spec.name:
            continue
        print(f'== {spec.name}', flush=True)
        try:
            embedder = Embedder.load(args.models_dir, spec, os.cpu_count() or 4)
            entry = {'quality': score(embedder, corpus),
                     'paraphrase': score(embedder, paraphrases),
                     'speed': speed(args.models_dir, spec, corpus),
                     'mb': round(model_bytes(args.models_dir, spec) / 1e6, 1)}
        except Exception as error:  # noqa: BLE001 - recorded in the report
            entry = {'error': f'{type(error).__name__}: {error}'[:300]}
        entry['peak_rss_mb'] = round(
            resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1)
        summary['models'][spec.name] = entry
        print(json.dumps(entry.get('quality', entry), default=str)[:400], flush=True)

    out = args.corpus.with_name('summary.json')
    out.write_text(json.dumps(summary, indent=1))
    print('wrote', out)


if __name__ == '__main__':
    main()
