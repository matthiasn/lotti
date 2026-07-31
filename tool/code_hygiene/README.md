# Code hygiene history

This tool charts whether Lotti's production and test code periodically shrinks,
instead of only growing. It selects one commit for each calendar day on the
first-parent history of a ref: the latest merge commit on that day when one
exists, otherwise the latest commit.

For every selected commit it streams `lib/` and `test/` from `git archive` into
a temporary directory and runs CLOC once with per-file JSON output. It never
checks out a commit or changes the working tree.

## Prerequisites

- Python 3.10 or newer
- Git
- [CLOC](https://github.com/AlDanial/cloc)

On macOS, CLOC is available with `brew install cloc`. Debian and Ubuntu package
it as `sudo apt install cloc`.

## Run it

From a local Lotti clone whose `HEAD` is the mainline you want to inspect:

```sh
python3 tool/code_hygiene/analyze.py .
```

The default window is 730 inclusive calendar days ending on the commit date at
`HEAD`. You can point at another local ref without switching branches:

```sh
python3 tool/code_hygiene/analyze.py . --ref origin/main --days 730
```

Results go to `build/code_hygiene/`:

- `code_hygiene.html` is a standalone interactive chart with no network-loaded
  dependencies.
- `code_hygiene.csv` contains commit metadata, code/comment/blank/file counts for
  each directory, combined code lines, and day-to-day deltas.
- `cache.json` stores CLOC results by full commit hash.

When that local cache is missing, the tool first restores the latest published
cache from R2, then falls back to the bundled compressed bootstrap cache if R2
is unavailable. Only commits absent from the restored cache are passed to CLOC.
Pass `--cache-url ''` to disable the network restore.

Open `code_hygiene.html` in a browser. The two upper lines show `lib` and `test`
code lines. Red-ringed points are directory-level shrinkage events; red bars in
the lower chart are days when their combined code count fell. Hover anywhere in
the plot to see the representative commit and exact deltas. A sustained upward
trend can be healthy feature growth; long periods with no downward events are
the hygiene warning this view is designed to expose.

The cache is written atomically after every completed commit. If the run is
interrupted, run the same command again and it resumes from the remaining
commits. `--refresh` forces selected commits to be counted again. A different
`--days` or `--ref` reuses any overlapping commit hashes already in the cache.

Missing historical `lib/` or `test/` directories are recorded as zero. Days
without commits have no point, and days without a merge use their final regular
commit.

Useful options:

```text
--output-dir PATH   output directory (relative paths resolve from the repo)
--cache PATH        use a cache outside the output directory
--cache-url URL     restore a missing cache from another URL
--seed-cache PATH   alternate compressed bootstrap cache
--git PATH          alternate Git executable
--cloc PATH         alternate CLOC executable
--refresh           recount selected commits
```

Run the focused unit tests with:

```sh
python3 -m unittest tool.code_hygiene.analyze_test
```

## Published artifacts

The scheduled [code-hygiene workflow](../../.github/workflows/code-hygiene.yml)
refreshes the analysis and publishes the standalone report, PNG capture, CSV,
and cache to Cloudflare R2 under `code-hygiene/latest/`. Every publishing run
also writes an immutable copy under `code-hygiene/commits/<commit-sha>/` for PR
review and historical reference.

- [Latest interactive chart](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/code-hygiene/latest/code_hygiene.html)
- [Latest PNG capture](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/code-hygiene/latest/render.png)
- [Latest CSV](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/code-hygiene/latest/code_hygiene.csv)
- [Latest cache](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/code-hygiene/latest/cache.json)
