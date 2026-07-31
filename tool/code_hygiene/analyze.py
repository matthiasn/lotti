#!/usr/bin/env python3
"""Measure lib/ and test/ lines of code across a Git branch's daily history."""

from __future__ import annotations

import argparse
import csv
import gzip
import html
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from datetime import date, timedelta
from pathlib import Path, PurePosixPath
from typing import Iterable, Sequence


CACHE_SCHEMA_VERSION = 1
DEFAULT_DAYS = 730
DEFAULT_CACHE_URL = (
    "https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/"
    "code-hygiene/latest/cache.json"
)
DEFAULT_SEED_CACHE = Path(__file__).with_name("seed_cache.json.gz")
MAX_REMOTE_CACHE_BYTES = 10 * 1024 * 1024
TRACKED_ROOTS = ("lib", "test")


class HygieneError(RuntimeError):
    """An expected error that should be presented without a traceback."""


@dataclass(frozen=True)
class Commit:
    """The Git metadata needed to choose and label a daily snapshot."""

    hash: str
    parents: tuple[str, ...]
    date: date
    subject: str

    @property
    def is_merge(self) -> bool:
        """Return whether the commit has more than one parent."""
        return len(self.parents) > 1


@dataclass(frozen=True)
class LineCounts:
    """CLOC totals for one tracked directory."""

    files: int = 0
    blank: int = 0
    comment: int = 0
    code: int = 0


def _run(
    command: Sequence[str],
    *,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as error:
        raise HygieneError(f"Required command was not found: {command[0]}") from error
    except OSError as error:
        raise HygieneError(f"Could not run required command {command[0]}: {error}") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip() or "no diagnostic output"
        rendered = " ".join(command)
        raise HygieneError(f"Command failed ({rendered}): {detail}") from error


def _repository_root(repository: Path, git: str) -> Path:
    result = _run([git, "-C", str(repository), "rev-parse", "--show-toplevel"])
    return Path(result.stdout.strip()).resolve()


def _commits_on_first_parent(repo: Path, ref: str, git: str) -> list[Commit]:
    result = _run(
        [
            git,
            "-C",
            str(repo),
            "log",
            "--first-parent",
            "--date=short",
            "--format=%H%x09%P%x09%cs%x09%s",
            ref,
        ]
    )
    commits = []
    for line in result.stdout.splitlines():
        commit_hash, parents, committed_on, subject = line.split("\t", 3)
        commits.append(
            Commit(
                hash=commit_hash,
                parents=tuple(parents.split()),
                date=date.fromisoformat(committed_on),
                subject=subject,
            )
        )
    if not commits:
        raise HygieneError(f"No commits were found at ref {ref!r}")
    return commits


def select_daily_commits(
    commits: Iterable[Commit],
    *,
    start: date,
    end: date,
) -> list[Commit]:
    """Choose the newest merge per day, or the newest commit when none merged."""
    newest_by_day: dict[date, Commit] = {}
    newest_merge_by_day: dict[date, Commit] = {}
    for commit in commits:
        if not start <= commit.date <= end:
            continue
        newest_by_day.setdefault(commit.date, commit)
        if commit.is_merge:
            newest_merge_by_day.setdefault(commit.date, commit)

    return [
        newest_merge_by_day.get(day, newest_by_day[day])
        for day in sorted(newest_by_day)
    ]


def _existing_roots(repo: Path, commit_hash: str, git: str) -> tuple[str, ...]:
    result = _run(
        [
            git,
            "-C",
            str(repo),
            "ls-tree",
            "-d",
            "--name-only",
            commit_hash,
            "--",
            *TRACKED_ROOTS,
        ]
    )
    existing = frozenset(result.stdout.splitlines())
    return tuple(root for root in TRACKED_ROOTS if root in existing)


def _safe_member_path(member_name: str, roots: Sequence[str]) -> PurePosixPath | None:
    path = PurePosixPath(member_name)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        return None
    if path.parts[0] not in roots:
        return None
    return path


def _extract_archive(
    repo: Path,
    commit_hash: str,
    roots: Sequence[str],
    destination: Path,
    git: str,
) -> None:
    command = [
        git,
        "-C",
        str(repo),
        "archive",
        "--format=tar",
        commit_hash,
        "--",
        *roots,
    ]
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as error:
        raise HygieneError(f"Required command was not found: {git}") from error
    except OSError as error:
        raise HygieneError(f"Could not run required command {git}: {error}") from error

    assert process.stdout is not None
    assert process.stderr is not None
    stderr_chunks: list[bytes] = []

    def drain_stderr() -> None:
        for chunk in iter(lambda: process.stderr.read(65536), b""):
            stderr_chunks.append(chunk)

    stderr_thread = threading.Thread(target=drain_stderr, daemon=True)
    stderr_thread.start()

    def terminate_and_reap() -> None:
        if process.poll() is None:
            process.kill()
        process.wait()
        stderr_thread.join()

    def stderr_text() -> str:
        return b"".join(stderr_chunks).decode(errors="replace").strip()

    try:
        with tarfile.open(fileobj=process.stdout, mode="r|*") as archive:
            for member in archive:
                relative_path = _safe_member_path(member.name, roots)
                if relative_path is None:
                    raise HygieneError(
                        f"Unsafe path in Git archive for {commit_hash}: {member.name}"
                    )
                target = destination.joinpath(*relative_path.parts)
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                if not member.isfile():
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                source = archive.extractfile(member)
                if source is None:
                    raise HygieneError(
                        f"Could not read {member.name} from Git archive {commit_hash}"
                    )
                with source, target.open("wb") as output:
                    shutil.copyfileobj(source, output)
        process.stdout.close()
        return_code = process.wait()
        stderr_thread.join()
    except tarfile.TarError as error:
        terminate_and_reap()
        detail = stderr_text()
        raise HygieneError(
            f"Could not read Git archive for {commit_hash}: "
            f"{detail or str(error)}"
        ) from error
    except BaseException:
        terminate_and_reap()
        raise
    finally:
        process.stdout.close()
        process.stderr.close()
    stderr = stderr_text()
    if return_code != 0:
        raise HygieneError(
            f"git archive failed for {commit_hash}: {stderr or 'no diagnostic output'}"
        )


def aggregate_cloc_report(report: dict) -> dict[str, LineCounts]:
    """Aggregate a CLOC --by-file JSON object into lib and test totals."""
    totals = {root: LineCounts() for root in TRACKED_ROOTS}
    mutable = {
        root: {"files": 0, "blank": 0, "comment": 0, "code": 0}
        for root in TRACKED_ROOTS
    }
    for raw_path, values in report.items():
        if raw_path in {"header", "SUM"} or not isinstance(values, dict):
            continue
        normalized = raw_path.replace("\\", "/").lstrip("./")
        root = normalized.partition("/")[0]
        if root not in mutable:
            continue
        mutable[root]["files"] += 1
        for field in ("blank", "comment", "code"):
            mutable[root][field] += int(values.get(field, 0))
    for root in TRACKED_ROOTS:
        totals[root] = LineCounts(**mutable[root])
    return totals


def _count_commit(
    repo: Path,
    commit: Commit,
    *,
    git: str,
    cloc: str,
    cloc_version: str,
) -> dict:
    roots = _existing_roots(repo, commit.hash, git)
    totals = {root: LineCounts() for root in TRACKED_ROOTS}
    if roots:
        with tempfile.TemporaryDirectory(prefix="lotti-code-hygiene-") as temp:
            snapshot = Path(temp)
            _extract_archive(repo, commit.hash, roots, snapshot, git)
            result = _run(
                [cloc, "--json", "--by-file", "--quiet", *roots],
                cwd=snapshot,
            )
            try:
                totals = aggregate_cloc_report(json.loads(result.stdout))
            except (json.JSONDecodeError, TypeError, ValueError) as error:
                raise HygieneError(
                    f"CLOC returned invalid JSON for commit {commit.hash}"
                ) from error

    return {
        "commit": commit.hash,
        "date": commit.date.isoformat(),
        "is_merge": commit.is_merge,
        "subject": commit.subject,
        "cloc_version": cloc_version,
        "lib": asdict(totals["lib"]),
        "test": asdict(totals["test"]),
    }


def _empty_cache() -> dict:
    return {"schema_version": CACHE_SCHEMA_VERSION, "commits": {}}


def _load_cache(path: Path) -> dict:
    if not path.exists():
        return _empty_cache()
    try:
        cache = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise HygieneError(f"Could not read cache {path}: {error}") from error
    if (
        not isinstance(cache, dict)
        or cache.get("schema_version") != CACHE_SCHEMA_VERSION
        or not isinstance(cache.get("commits"), dict)
    ):
        raise HygieneError(
            f"Cache {path} has an unsupported format; move it aside and rerun"
        )
    return cache


def _validated_cache_text(content: str, source: str) -> dict:
    try:
        cache = json.loads(content)
    except json.JSONDecodeError as error:
        raise HygieneError(f"Could not parse cache from {source}: {error}") from error
    if (
        not isinstance(cache, dict)
        or cache.get("schema_version") != CACHE_SCHEMA_VERSION
        or not isinstance(cache.get("commits"), dict)
    ):
        raise HygieneError(f"Cache from {source} has an unsupported format")
    return cache


def _restore_cache(
    path: Path,
    *,
    cache_url: str | None,
    seed_cache: Path | None,
) -> str | None:
    """Restore a missing cache from R2, then from the bundled bootstrap cache."""
    if path.exists():
        return None

    if cache_url:
        try:
            with urllib.request.urlopen(cache_url, timeout=30) as response:
                payload = response.read(MAX_REMOTE_CACHE_BYTES + 1)
            if len(payload) > MAX_REMOTE_CACHE_BYTES:
                raise HygieneError(
                    f"Remote cache exceeds {MAX_REMOTE_CACHE_BYTES} bytes"
                )
            content = payload.decode("utf-8")
            _validated_cache_text(content, cache_url)
            _atomic_write(path, content if content.endswith("\n") else content + "\n")
            return f"remote cache {cache_url}"
        except (OSError, UnicodeDecodeError, urllib.error.URLError, HygieneError) as error:
            print(f"warning: could not restore remote cache: {error}", file=sys.stderr)

    if seed_cache and seed_cache.is_file():
        try:
            with gzip.open(seed_cache, "rt", encoding="utf-8") as source:
                content = source.read()
            _validated_cache_text(content, str(seed_cache))
            _atomic_write(path, content if content.endswith("\n") else content + "\n")
            return f"seed cache {seed_cache}"
        except (OSError, UnicodeDecodeError, HygieneError) as error:
            raise HygieneError(f"Could not restore seed cache {seed_cache}: {error}") from error
    return None


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("w", encoding="utf-8", newline="") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _write_cache(path: Path, cache: dict) -> None:
    _atomic_write(path, json.dumps(cache, indent=2, sort_keys=True) + "\n")


def _cache_record_uses_cloc(record: object, cloc_version: str) -> bool:
    return isinstance(record, dict) and record.get("cloc_version") == cloc_version


def _rows(records: Sequence[dict]) -> list[dict]:
    rows = []
    previous = None
    for record in records:
        row = {
            "date": record["date"],
            "commit": record["commit"],
            "is_merge": record["is_merge"],
            "subject": record["subject"],
        }
        for root in TRACKED_ROOTS:
            for field in ("files", "blank", "comment", "code"):
                row[f"{root}_{field}"] = record[root][field]
        row["total_code"] = row["lib_code"] + row["test_code"]
        for series in ("lib", "test", "total"):
            key = f"{series}_code" if series != "total" else "total_code"
            row[f"{series}_delta"] = 0 if previous is None else row[key] - previous[key]
        rows.append(row)
        previous = row
    return rows


CSV_FIELDS = (
    "date",
    "commit",
    "is_merge",
    "subject",
    "lib_files",
    "lib_blank",
    "lib_comment",
    "lib_code",
    "test_files",
    "test_blank",
    "test_comment",
    "test_code",
    "total_code",
    "lib_delta",
    "test_delta",
    "total_delta",
)


def _write_csv(path: Path, rows: Sequence[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("w", encoding="utf-8", newline="") as output:
            writer = csv.DictWriter(output, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(
                {
                    **row,
                    "subject": (
                        f"'{row['subject']}"
                        if row["subject"].startswith(("=", "+", "-", "@"))
                        else row["subject"]
                    ),
                }
                for row in rows
            )
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


CHART_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__TITLE__</title>
  <style>
    :root { color-scheme: light dark; font-family: Inter, system-ui, sans-serif; }
    body { margin: 0; background: #111827; color: #e5e7eb; }
    main { max-width: 1320px; margin: auto; padding: 16px 20px 18px; }
    .heading { display: flex; align-items: baseline; justify-content: space-between; gap: 24px; margin: 0 2px 10px; }
    h1 { margin: 0; font-size: clamp(1.5rem, 3vw, 2rem); white-space: nowrap; }
    .lede { color: #9ca3af; margin: 0; text-align: right; font-size: .9rem; }
    .cards { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 10px; margin-bottom: 10px; }
    .card { background: #1f2937; border: 1px solid #374151; border-radius: 10px; padding: 8px 12px; min-height: 48px; }
    .card span { color: #9ca3af; display: block; font-size: .68rem; text-transform: uppercase; letter-spacing: .06em; }
    .card strong { display: block; font-size: 1.1rem; margin-top: 3px; }
    .chart-shell { position: relative; background: #1f2937; border: 1px solid #374151; border-radius: 12px; padding: 8px 10px 6px; overflow: hidden; }
    svg { display: block; width: 100%; height: auto; }
    .grid { stroke: #374151; stroke-width: 1; }
    .axis-label { fill: #9ca3af; font-size: 13px; }
    .series { fill: none; stroke-width: 3; stroke-linejoin: round; stroke-linecap: round; }
    .area { opacity: .08; }
    .gc { fill: #111827; stroke: #f87171; stroke-width: 2.5; }
    .cursor { stroke: #d1d5db; stroke-width: 1; stroke-dasharray: 4 4; pointer-events: none; }
    .tooltip { position: absolute; display: none; pointer-events: none; min-width: 245px; max-width: 360px; padding: 12px; border-radius: 9px; background: rgba(3, 7, 18, .96); border: 1px solid #4b5563; box-shadow: 0 12px 30px #0008; font-size: .85rem; line-height: 1.45; }
    .tooltip b { color: white; }
    .delta-band { fill: #261c22; stroke: #4b2d36; stroke-width: 1; }
    .legend { display: flex; flex-wrap: wrap; gap: 18px; margin: 7px 4px 1px; color: #d1d5db; font-size: .8rem; }
    .swatch { width: 18px; height: 3px; display: inline-block; margin-right: 7px; vertical-align: middle; }
    .note { color: #9ca3af; font-size: .8rem; margin: 7px 4px 0; }
    @media (max-width: 760px) {
      .heading { display: block; }
      .lede { margin-top: 4px; text-align: left; }
      .cards { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .card:last-child { grid-column: span 2; }
    }
    code { color: #f3f4f6; }
  </style>
</head>
<body>
<main>
  <header class="heading">
    <h1>__TITLE__</h1>
    <p class="lede">Daily mainline snapshots · red marks code “garbage collection” events</p>
  </header>
  <section class="cards" id="cards"></section>
  <section class="chart-shell">
    <svg id="chart" viewBox="0 0 1200 600" role="img" aria-label="Code lines and daily shrinkage over time for lib and test"></svg>
    <div class="tooltip" id="tooltip"></div>
    <div class="legend">
      <span><i class="swatch" style="background:#60a5fa"></i>lib code</span>
      <span><i class="swatch" style="background:#fbbf24"></i>test code</span>
      <span><i class="swatch" style="background:#f87171"></i>combined LOC removed that day</span>
    </div>
  </section>
  <p class="note">The lower chart is scaled only to negative deltas so cleanup events stay visible. Hover for commit details; missing calendar days are not interpolated.</p>
</main>
<script>
const rows = __DATA__;
const svg = document.getElementById('chart');
const tooltip = document.getElementById('tooltip');
const NS = 'http://www.w3.org/2000/svg';
const W = 1200, left = 82, right = 28, plotTop = 24, plotBottom = 365, deltaTop = 423, deltaBottom = 570;
const width = W - left - right;
const fmt = new Intl.NumberFormat();
const values = rows.flatMap(d => [d.lib_code, d.test_code]);
const yMax = Math.max(1, ...values) * 1.06;
const x = i => left + (rows.length === 1 ? width / 2 : i * width / (rows.length - 1));
const y = value => plotBottom - value / yMax * (plotBottom - plotTop);
const largestShrink = Math.max(1, ...rows.map(d => Math.max(0, -d.total_delta)));
const deltaBaseline = deltaTop + 22;
const deltaY = value => deltaBaseline + Math.max(0, -value) / largestShrink * (deltaBottom - deltaBaseline);
function node(name, attrs = {}, text = '') {
  const el = document.createElementNS(NS, name);
  for (const [key, value] of Object.entries(attrs)) el.setAttribute(key, value);
  if (text) el.textContent = text;
  return el;
}
for (let i = 0; i <= 5; i++) {
  const value = yMax * i / 5;
  const py = y(value);
  svg.append(node('line', {x1:left, x2:W-right, y1:py, y2:py, class:'grid'}));
  svg.append(node('text', {x:left-12, y:py+4, 'text-anchor':'end', class:'axis-label'}, fmt.format(Math.round(value))));
}
const tickCount = Math.min(7, rows.length);
for (let i = 0; i < tickCount; i++) {
  const index = tickCount === 1 ? 0 : Math.round(i * (rows.length - 1) / (tickCount - 1));
  const anchor = i === 0 ? 'start' : i === tickCount - 1 ? 'end' : 'middle';
  svg.append(node('text', {x:x(index), y:plotBottom+30, 'text-anchor':anchor, class:'axis-label'}, rows[index].date));
}
svg.append(node('rect', {x:left, y:deltaTop, width, height:deltaBottom-deltaTop, rx:6, class:'delta-band'}));
svg.append(node('text', {x:left+10, y:deltaTop+15, class:'axis-label'}, 'Daily shrinkage · combined LOC removed'));
svg.append(node('text', {x:left-12, y:deltaBaseline+4, 'text-anchor':'end', class:'axis-label'}, '0'));
svg.append(node('text', {x:left-12, y:deltaBottom, 'text-anchor':'end', class:'axis-label'}, `−${fmt.format(largestShrink)}`));
svg.append(node('line', {x1:left, x2:W-right, y1:deltaBaseline, y2:deltaBaseline, class:'grid'}));
const barWidth = Math.max(2.2, Math.min(10, width / Math.max(rows.length, 1) * .9));
rows.forEach((d, i) => {
  if (d.total_delta >= 0) return;
  const py = deltaY(d.total_delta);
  svg.append(node('rect', {
    x:x(i)-barWidth/2, y:deltaBaseline, width:barWidth,
    height:Math.max(2, py-deltaBaseline), fill:'#f87171', opacity:.95
  }));
});
function pathFor(key) {
  return rows.map((d, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(d[key]).toFixed(1)}`).join(' ');
}
function drawSeries(key, color) {
  const line = pathFor(key);
  const area = `${line} L${x(rows.length-1)},${plotBottom} L${x(0)},${plotBottom} Z`;
  svg.append(node('path', {d:area, fill:color, class:'area'}));
  svg.append(node('path', {d:line, stroke:color, class:'series'}));
  rows.forEach((d, i) => {
    if (i && d[`${key.replace('_code','')}_delta`] < 0) {
      svg.append(node('circle', {cx:x(i), cy:y(d[key]), r:5, class:'gc'}));
    }
  });
}
drawSeries('lib_code', '#60a5fa');
drawSeries('test_code', '#fbbf24');
const cursor = node('line', {y1:plotTop, y2:deltaBottom, class:'cursor', visibility:'hidden'});
svg.append(cursor);
const overlay = node('rect', {x:left, y:plotTop, width, height:deltaBottom-plotTop, fill:'transparent'});
svg.append(overlay);
overlay.addEventListener('mousemove', event => {
  const rect = svg.getBoundingClientRect();
  const mouseX = (event.clientX - rect.left) * W / rect.width;
  const index = rows.length === 1 ? 0 : Math.max(0, Math.min(rows.length-1, Math.round((mouseX-left)/width*(rows.length-1))));
  const d = rows[index];
  cursor.setAttribute('x1', x(index)); cursor.setAttribute('x2', x(index)); cursor.setAttribute('visibility', 'visible');
  tooltip.style.display = 'block';
  tooltip.innerHTML = `<b>${d.date}</b> · <code>${d.commit.slice(0,10)}</code>${d.is_merge ? ' · merge' : ''}<br>${escapeHtml(d.subject)}<br><br><span style="color:#60a5fa">lib ${fmt.format(d.lib_code)}</span> (${signed(d.lib_delta)})<br><span style="color:#fbbf24">test ${fmt.format(d.test_code)}</span> (${signed(d.test_delta)})<br>total ${fmt.format(d.total_code)} (${signed(d.total_delta)})`;
  const shell = svg.parentElement.getBoundingClientRect();
  tooltip.style.left = `${Math.min(event.clientX-shell.left+14, shell.width-tooltip.offsetWidth-12)}px`;
  tooltip.style.top = `${Math.max(8, event.clientY-shell.top-tooltip.offsetHeight-12)}px`;
});
overlay.addEventListener('mouseleave', () => { tooltip.style.display='none'; cursor.setAttribute('visibility','hidden'); });
function signed(value) { return `${value > 0 ? '+' : ''}${fmt.format(value)}`; }
function escapeHtml(value) { const div=document.createElement('div'); div.textContent=value; return div.innerHTML; }
const latest = rows[rows.length-1];
const gcRows = rows.filter(d => d.total_delta < 0);
const biggest = gcRows.reduce((best, d) => !best || d.total_delta < best.total_delta ? d : best, null);
const cards = [
  ['Range', `${rows[0].date} → ${latest.date}`],
  ['Snapshots', fmt.format(rows.length)],
  ['Latest total', fmt.format(latest.total_code)],
  ['Shrink days', fmt.format(gcRows.length)],
  ['Largest shrink', biggest ? `${fmt.format(biggest.total_delta)} · ${biggest.date}` : 'none']
];
document.getElementById('cards').innerHTML = cards.map(([label,value]) => `<div class="card"><span>${label}</span><strong>${value}</strong></div>`).join('');
</script>
</body>
</html>
"""


def _write_chart(path: Path, rows: Sequence[dict], title: str) -> None:
    if not rows:
        raise HygieneError("Cannot render a chart without any selected commits")
    serialized = json.dumps(rows).replace("<", "\\u003c")
    content = CHART_TEMPLATE.replace("__TITLE__", html.escape(title)).replace(
        "__DATA__", serialized
    )
    _atomic_write(path, content)


def analyze(
    repository: Path,
    *,
    ref: str,
    days: int,
    output_dir: Path,
    cache_path: Path,
    git: str,
    cloc: str,
    refresh: bool,
    cache_url: str | None = DEFAULT_CACHE_URL,
    seed_cache: Path | None = DEFAULT_SEED_CACHE,
) -> tuple[Path, Path, Path, int, int]:
    """Run the analysis and return output paths plus measured/cached counts."""
    if days < 1:
        raise HygieneError("--days must be at least 1")
    repo = _repository_root(repository, git)
    commits = _commits_on_first_parent(repo, ref, git)
    end = commits[0].date
    start = end - timedelta(days=days - 1)
    selected = select_daily_commits(commits, start=start, end=end)
    if not selected:
        raise HygieneError(f"No commits were selected between {start} and {end}")

    restored_from = _restore_cache(
        cache_path,
        cache_url=cache_url,
        seed_cache=seed_cache,
    )
    if restored_from:
        print(f"Restored {restored_from}")
    cache = _load_cache(cache_path)
    cloc_version = _run([cloc, "--version"]).stdout.strip()
    missing = [
        commit
        for commit in selected
        if refresh
        or commit.hash not in cache["commits"]
        or not _cache_record_uses_cloc(
            cache["commits"][commit.hash],
            cloc_version,
        )
    ]

    measured = 0
    for index, commit in enumerate(missing, start=1):
        print(
            f"[{index}/{len(missing)}] {commit.date} {commit.hash[:10]} "
            f"{'merge' if commit.is_merge else 'commit'}",
            flush=True,
        )
        cache["commits"][commit.hash] = _count_commit(
            repo,
            commit,
            git=git,
            cloc=cloc,
            cloc_version=cloc_version,
        )
        _write_cache(cache_path, cache)
        measured += 1

    records = [cache["commits"][commit.hash] for commit in selected]
    rows = _rows(records)
    csv_path = output_dir / "code_hygiene.csv"
    chart_path = output_dir / "code_hygiene.html"
    _write_csv(csv_path, rows)
    _write_chart(chart_path, rows, f"Lotti code hygiene · {ref}")
    return csv_path, chart_path, cache_path, measured, len(selected) - measured


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Count lib/ and test/ code lines at one representative mainline "
            "commit per day and render a standalone history chart."
        )
    )
    parser.add_argument(
        "repository",
        nargs="?",
        default=".",
        type=Path,
        help="Git repository to analyze (default: current directory)",
    )
    parser.add_argument("--ref", default="HEAD", help="Mainline ref (default: HEAD)")
    parser.add_argument(
        "--days",
        default=DEFAULT_DAYS,
        type=int,
        help=f"Inclusive history window ending at the ref date (default: {DEFAULT_DAYS})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("build/code_hygiene"),
        help="Output directory, relative to the repository by default",
    )
    parser.add_argument(
        "--cache",
        type=Path,
        help="Cache file (default: <output-dir>/cache.json)",
    )
    parser.add_argument(
        "--cache-url",
        default=DEFAULT_CACHE_URL,
        help=(
            "Remote cache used when the local cache is missing; pass an empty "
            "string to disable"
        ),
    )
    parser.add_argument(
        "--seed-cache",
        type=Path,
        default=DEFAULT_SEED_CACHE,
        help="Compressed bootstrap cache used when the remote cache is unavailable",
    )
    parser.add_argument("--git", default="git", help="Git executable")
    parser.add_argument("--cloc", default="cloc", help="CLOC executable")
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Recount selected commits even when cached",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        repository = args.repository.resolve()
        repo = _repository_root(repository, args.git)
        output_dir = args.output_dir
        if not output_dir.is_absolute():
            output_dir = repo / output_dir
        cache_path = args.cache or output_dir / "cache.json"
        if not cache_path.is_absolute():
            cache_path = repo / cache_path
        csv_path, chart_path, cache_path, measured, reused = analyze(
            repo,
            ref=args.ref,
            days=args.days,
            output_dir=output_dir,
            cache_path=cache_path,
            git=args.git,
            cloc=args.cloc,
            refresh=args.refresh,
            cache_url=args.cache_url or None,
            seed_cache=args.seed_cache,
        )
    except HygieneError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("\nInterrupted. Completed commits remain in the cache.", file=sys.stderr)
        return 130

    print(f"Wrote {csv_path}")
    print(f"Wrote {chart_path}")
    print(f"Cache {cache_path} ({measured} measured, {reused} reused)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
