"""Renders `summary.json` from `evaluate.py` as Markdown tables.

    python tool/embedding_eval/report.py [build/embedding_eval/summary.json]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def pct(value: float) -> str:
    return f'{value * 100:.0f}%'


def quality_table(summary: dict, suite: str, key: str) -> list[str]:
    bm25 = summary[suite]['bm25']
    hard_n = bm25['no_shared_words']['n']
    lines = [
        (f'| Model | R@1 | R@5 | MRR | No shared words (n={hard_n}): R@1 | '
        'No shared words: MRR | Hybrid RRF: MRR |'),
        '|---|---|---|---|---|---|---|',
        (f"| BM25 (FTS5) | {pct(bm25['overall']['recall@1'])} | "
        f"{pct(bm25['overall']['recall@5'])} | {bm25['overall']['mrr']:.2f} | "
        f"{pct(bm25['no_shared_words']['recall@1'])} | "
        f"{bm25['no_shared_words']['mrr']:.2f} | — |"),
    ]
    for name, entry in summary['models'].items():
        if 'error' in entry:
            continue
        for label, quality in entry[key].items():
            overall = quality['overall']
            hard = quality['no_shared_words']
            title = name if label == 'full' else f'{name} @ {label}'
            lines.append(
                f"| {title} | {pct(overall['recall@1'])} | "
                f"{pct(overall['recall@5'])} | {overall['mrr']:.2f} | "
                f"{pct(hard['recall@1'])} | {hard['mrr']:.2f} | "
                f"{quality['hybrid']['mrr']:.2f} |")
    return lines


def language_table(summary: dict, suite: str, key: str) -> list[str]:
    codes = list(summary[suite]['bm25']['languages'])
    lines = ['| Model (MRR) | ' + ' | '.join(codes) + ' |',
             '|---|' + '---|' * len(codes),
             '| BM25 (FTS5) | ' + ' | '.join(
                 f"{summary[suite]['bm25']['languages'][c]['mrr']:.2f}"
                 for c in codes) + ' |']
    for name, entry in summary['models'].items():
        if 'error' in entry:
            continue
        languages = entry[key]['full']['languages']
        lines.append(f'| {name} | ' + ' | '.join(
            f"{languages[c]['mrr']:.2f}" for c in codes) + ' |')
    return lines


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1
                else 'build/embedding_eval/summary.json')
    summary = json.loads(path.read_text())
    lines = [f"ONNX Runtime {summary['onnxruntime']}, CPU.", '',
             '## Cost', '',
             ('| Model | File | Load (4 threads) | ms/text, 1 thread | '
             'ms/text, 4 threads | p95, 1 thread |'),
             '|---|---|---|---|---|---|']
    for name, entry in summary['models'].items():
        if 'error' in entry:
            lines.append(f"| {name} | does not load: {entry['error'][:90]} "
                         '| | | | |')
            continue
        speed = entry['speed']
        lines.append(
            f"| {name} | {entry['mb']:.0f} MB | {speed['4t']['load_s']} s | "
            f"{speed['1t']['median_ms']} | {speed['4t']['median_ms']} | "
            f"{speed['1t']['p95_ms']} |")
    lines += ['', '## Paraphrase queries (en, de, fr, cs)', '',
              *quality_table(summary, 'paraphrase', 'paraphrase'), '',
              *language_table(summary, 'paraphrase', 'paraphrase'), '',
              ('## Membership queries: a checklist item or note finds its task '
              '(11 languages)'), '',
              *quality_table(summary, 'membership', 'quality'), '',
              *language_table(summary, 'membership', 'quality')]
    out = path.with_name('report.md')
    out.write_text('\n'.join(lines) + '\n')
    print(out.read_text())


if __name__ == '__main__':
    main()
