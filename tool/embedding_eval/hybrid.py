"""Scores how to combine keyword search and search by meaning, on the app's
own keyword path, so the hybrid ranking the app ships is chosen on evidence
(ADR 0144 asked for exactly this before any fusion ships).

The keyword side is what the app runs, not a stand-in:

- the same FTS5 table (`title`, `body`, `extra`; `unicode61 remove_diacritics
  2`, `prefix '2 3'`);
- the same match expression (`ftsMatchExpression`: every word required, the
  last one also as a prefix);
- the same ranking (`bm25` with the title worth 10, the body 1, `extra` 2).

The meaning side is the shipped model, EmbeddingGemma q4, with its query and
document prompts.

Three query sets per language:

- **paraphrase:** searches written for a task without its words
  (`paraphrases.json`). This is what meaning search exists for.
- **title words:** the two most distinctive words of a task's title, as a user
  types what they remember. This is where keywords are strongest.
- **title:** a task's whole title.

A fusion is good when it beats keyword search on paraphrases and loses nothing
against it on the other two.

    python tool/embedding_eval/hybrid.py --models-dir DIR

Writes `build/embedding_eval/hybrid.json` and `hybrid.md` next to the corpus.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import unicodedata
from pathlib import Path

import numpy as np

from evaluate import MODELS, Embedder, common_words, normalise, rank_metrics

SEGMENT = re.compile(r'"([^"]*)"?|[^\s"]+')
MIN_PREFIX_LENGTH = 2
MAX_PHRASES = 16


def tokens(text: str) -> list[str]:
    """What the `unicode61` tokenizer keeps: runs of letters (with their
    combining marks) and digits — `_token` in `lib/database/fts_query.dart`."""
    out, current = [], []
    for char in text:
        if unicodedata.category(char)[0] in 'LMN':
            current.append(char)
        elif current:
            out.append(''.join(current))
            current = []
    if current:
        out.append(''.join(current))
    return out


def fts_match_expression(text: str, *, any_term: bool = False,
                         prefix_last_word: bool = True) -> str | None:
    """A port of `ftsMatchExpression` (`lib/database/fts_query.dart`)."""
    phrases: list[str] = []
    prefix_last = False
    for segment in SEGMENT.finditer(text):
        if len(phrases) == MAX_PHRASES:
            break
        quoted = segment.group(1)
        found = tokens(quoted if quoted is not None else segment.group(0))
        if not found:
            continue
        phrases.append('"' + ' '.join(found) + '"')
        prefix_last = (prefix_last_word and quoted is None
                       and segment.end() == len(text)
                       and len(found[-1]) >= MIN_PREFIX_LENGTH)
    if not phrases:
        return None
    if prefix_last:
        phrases[-1] += '*'
    return (' OR ' if any_term else ' ').join(phrases)


def keyword_orders(tasks: list[dict], queries: list[dict]) -> list[list[str]]:
    """Each query's matching tasks in the app's order; only those."""
    db = sqlite3.connect(':memory:')
    db.execute("CREATE VIRTUAL TABLE t USING fts5(id UNINDEXED, title, body, "
               "extra, tokenize = 'unicode61 remove_diacritics 2', "
               "prefix = '2 3')")
    db.executemany('INSERT INTO t VALUES (?, ?, ?, ?)',
                   [(t['id'], t['title'], t['body'], t['extra']) for t in tasks])
    orders = []
    for query in queries:
        expression = fts_match_expression(query['text'])
        if expression is None:
            orders.append([])
            continue
        orders.append([row[0] for row in db.execute(
            'SELECT id FROM t WHERE t MATCH ? '
            'ORDER BY bm25(t, 0.0, 10.0, 1.0, 2.0)', (expression,))])
    return orders


def fold(text: str) -> str:
    return ''.join(c for c in unicodedata.normalize('NFKD', text.lower())
                   if not unicodedata.combining(c))


def title_word_queries(language: dict) -> list[dict]:
    """Per task, the two longest title words that are not common across the
    language's tasks — what a user remembers of a title."""
    common = common_words(language)
    queries = []
    for task in language['tasks']:
        candidates = [w for w in tokens(task['title'])
                      if len(w) >= 3 and fold(w) not in common]
        picked = sorted(dict.fromkeys(candidates), key=len, reverse=True)[:2]
        if len(picked) == 2:
            # In title order, the way it was read.
            picked.sort(key=lambda w: task['title'].index(w))
            queries.append({'text': ' '.join(picked), 'task': task['id']})
    return queries


def distinctive(language: dict, text: str) -> list[str]:
    """[text]'s words of three letters or more that are not common across
    the language's tasks, longest first, each once."""
    common = common_words(language)
    candidates = [w for w in tokens(text) if len(w) >= 3 and fold(w) not in common]
    return sorted(dict.fromkeys(candidates), key=len, reverse=True)


def one_word_queries(language: dict) -> list[dict]:
    """A task's most distinctive title word alone: keywords may match several
    tasks, and the order among them decides."""
    return [{'text': words[0], 'task': t['id']}
            for t in language['tasks']
            if (words := distinctive(language, t['title']))]


def body_word_queries(language: dict) -> list[dict]:
    """Two distinctive words of a task's body that its title lacks: they match
    the body column, which other tasks' titles outrank."""
    queries = []
    for task in language['tasks']:
        title = {fold(w) for w in tokens(task['title'])}
        words = [w for w in distinctive(language, task['body'])
                 if fold(w) not in title][:2]
        if len(words) == 2:
            queries.append({'text': ' '.join(words), 'task': task['id']})
    return queries


def typing_queries(language: dict) -> list[dict]:
    """The title words query mid-keystroke: its last word cut to three
    letters, matched as a prefix."""
    queries = []
    for query in title_word_queries(language):
        first, last = query['text'].rsplit(' ', 1)
        queries.append({'text': f'{first} {last[:3]}', 'task': query['task']})
    return queries


def title_queries(language: dict) -> list[dict]:
    return [{'text': t['title'], 'task': t['id']}
            for t in language['tasks'] if t['title'].strip()]


def paraphrase_queries(code: str, paraphrases: dict) -> list[dict]:
    return [{'text': text, 'task': task_id}
            for task_id, by_code in paraphrases.items()
            for text in by_code.get(code, [])]


def weighted_rrf(vector: list[str], keyword: list[str], *, k: int,
                 keyword_weight: float) -> list[str]:
    scores: dict[str, float] = {}
    for index, item in enumerate(vector):
        scores[item] = scores.get(item, 0.0) + 1 / (k + index + 1)
    for index, item in enumerate(keyword):
        scores[item] = (scores.get(item, 0.0)
                        + keyword_weight / (k + index + 1))
    # Stable: equal scores keep the order meaning search gave them.
    position = {item: i for i, item in enumerate(vector)}
    return sorted(scores, key=lambda item: (-scores[item],
                                            position.get(item, len(vector))))


def keyword_first(vector: list[str], keyword: list[str]) -> list[str]:
    return keyword + [item for item in vector if item not in set(keyword)]


METHODS = {
    'meaning': lambda v, kw: v,
    'keyword': lambda v, kw: kw,
    'keyword first': keyword_first,
    **{f'rrf k={k} w={w}': (lambda v, kw, k=k, w=w:
                             weighted_rrf(v, kw, k=k, keyword_weight=w))
       for k in (10, 30, 60) for w in (0.25, 0.5, 1.0, 2.0)},
}


def rank(order: list[str], answer: str) -> int | None:
    return order.index(answer) + 1 if answer in order else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--models-dir', type=Path, required=True)
    parser.add_argument('--corpus', type=Path,
                        default=Path('build/embedding_eval/corpus.json'))
    args = parser.parse_args()
    corpus = json.loads(args.corpus.read_text())
    paraphrases = json.loads(
        Path(__file__).with_name('paraphrases.json').read_text())

    spec = next(m for m in MODELS if m.name == 'EmbeddingGemma-300m q4')
    embedder = Embedder.load(args.models_dir, spec, os.cpu_count() or 4)

    ranks: dict[str, dict[str, list[int | None]]] = {}
    sizes: dict[str, int] = {}
    for code, language in corpus.items():
        tasks = language['tasks']
        task_ids = [t['id'] for t in tasks]
        documents = normalise(np.stack(
            [embedder.embed(t['text'], query=False) for t in tasks]), 0)
        sets = {
            'paraphrase': paraphrase_queries(code, paraphrases),
            'title words': title_word_queries(language),
            'one word': one_word_queries(language),
            'body words': body_word_queries(language),
            'typing': typing_queries(language),
            'title': title_queries(language),
        }
        for name, queries in sets.items():
            if not queries:
                continue
            sizes[name] = sizes.get(name, 0) + len(queries)
            embedded = normalise(np.stack(
                [embedder.embed(q['text'], query=True) for q in queries]), 0)
            similarity = embedded @ documents.T
            keyword = keyword_orders(tasks, queries)
            for row, query, kw in zip(similarity, queries, keyword):
                vector = [task_ids[i] for i in np.argsort(-row)]
                for method, fuse in METHODS.items():
                    (ranks.setdefault(method, {}).setdefault(name, [])
                     .append(rank(fuse(vector, kw), query['task'])))
        print(f'{code}: done', flush=True)

    summary = {
        'sizes': sizes,
        'methods': {m: {s: rank_metrics(r) for s, r in by_set.items()}
                    for m, by_set in ranks.items()},
    }
    out = args.corpus.with_name('hybrid.json')
    out.write_text(json.dumps(summary, indent=1))

    set_names = list(sizes)
    lines = ['| Method | ' + ' | '.join(f'{s} MRR (n={sizes[s]})'
                                         for s in set_names) + ' |',
             '|---|' + '---|' * len(set_names)]
    for method, by_set in summary['methods'].items():
        lines.append(f'| {method} | ' + ' | '.join(
            f"{by_set[s]['mrr']:.3f}" for s in set_names) + ' |')
    report = args.corpus.with_name('hybrid.md')
    report.write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines))
    print('wrote', out, 'and', report)


if __name__ == '__main__':
    main()
