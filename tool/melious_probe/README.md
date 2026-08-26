# Melious provider probe

A pytest harness that asks one question: when `api.melious.ai` answers *"The
request was rejected as malformed"*, is our request actually malformed?

It sends the smallest body the OpenAI chat schema permits — `model` plus one
user message, nothing else — so a rejection cannot be blamed on an optional
parameter we chose to send.

## Running

The suite hits the live paid API, so it is opt-in:

```bash
cd tool/melious_probe
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

# credential: process env wins, else ../../.env, else ../../../lotti3/.env
.venv/bin/pytest --live                                   # whole catalog
.venv/bin/pytest --live --models qwen3.8-27b,qwen3.6-27b  # just these
.venv/bin/pytest --live --report report.json              # machine-readable
.venv/bin/pytest                                          # offline checks only
```

## What each file is for

| File | Purpose |
| --- | --- |
| `melious.py` | Thin API client. Adds nothing to the payload — anything clever here would undermine the diagnosis. |
| `test_chat_completions.py` | The control group, the decisive one-byte experiment, and a per-model sweep of the catalog. |
| `test_catalog.py` | Pins what the catalog claims, including that broken and working models are metadata-identical. |

## Reading the results

`Outcome` classifies each attempt:

- `ok` — the model answered.
- `malformed` — HTTP 400. **This is the defect.** The provider advertises the
  model, then rejects a two-field request and blames the caller.
- `upstream` — HTTP 5xx, retried twice, then reported as a skip. Capacity, not
  a contract breach.
- `not_found` — HTTP 404, the model is absent at the backend Melious routes to.

Retrying 5xx but never 4xx is deliberate: a server that returns 400 has made a
decision about the request, and repeating it only spends money.
