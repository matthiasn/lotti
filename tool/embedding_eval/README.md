# Embedding model evaluation

Scores on-device text-embedding models on Lotti's own retrieval task, so the
model the app embeds with is chosen on evidence ([ADR 0144](../../docs/adr/0144-on-device-embeddings-use-embeddinggemma.md)).

Two query sets, both over the penguin demo world's tasks:

- **Paraphrase queries** (`paraphrases.json`): two searches per task in
  English, German, French and Czech, written to describe the task without its
  own wording — the case semantic search exists for.
- **Membership queries**: every checklist item and linked note in all eleven
  demo languages, whose answer is the task it belongs to.

Each model is scored alone, beside BM25 (SQLite FTS5 with the app index's
tokenizer) and fused with it (reciprocal rank fusion), with a split for the
queries that share no distinctive word with their task. Cost is file size,
load time and per-text latency at one and four threads. ONNX Runtime is
pinned to 1.22, the oldest the app ships, so a variant needing a newer
operator fails here rather than on a phone.

## Running it

```sh
# 1. The corpus, from the demo world (writes build/embedding_eval/corpus.json)
fvm flutter test tool/embedding_eval/export_corpus_test.dart

# 2. An environment and the models (about 2 GB)
uv venv /tmp/embed-venv && VIRTUAL_ENV=/tmp/embed-venv uv pip install -r tool/embedding_eval/requirements.txt
/tmp/embed-venv/bin/python -c "from huggingface_hub import snapshot_download as d
d('onnx-community/embeddinggemma-300m-ONNX', local_dir='/tmp/models/embeddinggemma-300m-ONNX',
  allow_patterns=['onnx/model*.onnx*', '*.json', '*.model'])
d('Xenova/multilingual-e5-small', local_dir='/tmp/models/multilingual-e5-small',
  allow_patterns=['onnx/model.onnx', 'onnx/model_int8.onnx', '*.json', '*.model'])"

# 3. Score, then render the tables (build/embedding_eval/report.md)
/tmp/embed-venv/bin/python tool/embedding_eval/evaluate.py --models-dir /tmp/models
/tmp/embed-venv/bin/python tool/embedding_eval/report.py
```

`--only NAME` scores the models whose name contains `NAME`.
