// Tests for the mermaid gate. Run with `node --test tool/okf/`.
//
// These exist because the gate was shipped claiming "verified against fixtures"
// with no fixtures committed — an unverifiable check is exactly what this tool is
// supposed to prevent elsewhere.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = join(dirname(fileURLToPath(import.meta.url)), 'check_mermaid.mjs');

/// Runs the checker over a throwaway directory containing [content].
///
/// `stdio: 'pipe'` matters for more than tidiness: most cases here expect the
/// checker to *fail*, and inheriting its stderr printed those expected `FAIL`
/// banners into a passing `make knowledge_check`, which read as a broken build.
/// The directory is removed in `finally` — without it each run left a
/// `/tmp/mermaid-gate-*` behind, and they accumulated in the hundreds.
function run(content, { name = 'concept.md' } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  try {
    writeFileSync(join(dir, name), content);
    try {
      const stdout = execFileSync('node', [script, dir], {
        encoding: 'utf8',
        stdio: 'pipe',
      });
      return { ok: true, output: stdout };
    } catch (error) {
      return {
        ok: false,
        output: `${error.stdout ?? ''}${error.stderr ?? ''}`,
      };
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const good = '```mermaid\nflowchart TD\n  A --> B\n```\n';

test('a valid diagram passes', () => {
  const r = run(good);
  assert.ok(r.ok, r.output);
  assert.match(r.output, /parsed 1 block\(s\)/);
});

test('a syntactically broken diagram fails', () => {
  const r = run('```mermaid\nflowchart TD\n  A -->\n```\n');
  assert.ok(!r.ok);
  assert.match(r.output, /FAIL/);
});

test('a tilde fence is not skipped', () => {
  // Matching only the canonical fence made these pass in silence.
  const r = run('~~~mermaid\nflowchart TD\n  A -->\n~~~\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /FAIL/);
});

test('a four-backtick fence is not skipped', () => {
  const r = run('````mermaid\nflowchart TD\n  A -->\n````\n');
  assert.ok(!r.ok, r.output);
});

test('a longer closing fence closes a shorter opener', () => {
  const r = run('```mermaid\nflowchart TD\n  A --> B\n`````\n');
  assert.ok(r.ok, r.output);
  assert.match(r.output, /parsed 1 block/);
});

test('a mermaid example nested in a markdown block is documentation', () => {
  // Only the outermost fence counts, or every doc that *shows* mermaid syntax
  // would be parsed as a diagram.
  const r = run('````markdown\n```mermaid\nnot real mermaid {{{\n```\n````\n');
  assert.ok(r.ok, r.output);
  assert.match(r.output, /parsed 0 block/);
});

test('a four-space-indented fence is a literal, not a diagram', () => {
  // CommonMark: four spaces makes it an indented code block, so this is a doc
  // *showing* mermaid syntax. Parsing it would reject valid documentation.
  const r = run('How to write one:\n\n    ```mermaid\n    not real {{{\n    ```\n');
  assert.ok(r.ok, r.output);
  assert.match(r.output, /parsed 0 block/);
});

test('a three-space-indented fence is still a diagram', () => {
  const r = run('   ```mermaid\n   flowchart TD\n     A -->\n   ```\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /FAIL/);
});

test('an unclosed mermaid fence is reported', () => {
  const r = run('```mermaid\nflowchart TD\n  A --> B\n');
  assert.ok(!r.ok);
  assert.match(r.output, /unclosed mermaid fence/);
});

test('an unclosed non-mermaid fence is left to the Dart validator', () => {
  const r = run('```dart\nvar x = 1;\n');
  assert.ok(r.ok, r.output);
});

test('a semicolon that splits a statement fails even though it parses', () => {
  // The quiet failure: mermaid accepts this and renders the remainder as extra
  // state nodes. Two shipped in the bundle before the gate learned to see it.
  const r = run('```mermaid\nstateDiagram-v2\n  A --> A: dedupe; append link; retract\n```\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /renders phantom node/);
});

test('the same label with commas passes', () => {
  const r = run('```mermaid\nstateDiagram-v2\n  A --> A: dedupe, append link, retract\n```\n');
  assert.ok(r.ok, r.output);
});

test('a semicolon inside a quoted node label is safe', () => {
  const r = run('```mermaid\nflowchart TD\n  A["compacted; the spliced section"] --> B\n```\n');
  assert.ok(r.ok, r.output);
});

test('a semicolon inside a note body is safe', () => {
  const r = run(
    '```mermaid\nstateDiagram-v2\n  A --> B\n  note right of A\n    wins; otherwise newest\n  end note\n```\n',
  );
  assert.ok(r.ok, r.output);
});

test('markdown files in subdirectories are scanned', () => {
  const dir = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  try {
    mkdirSync(join(dir, 'features', 'deep'), { recursive: true });
    writeFileSync(
      join(dir, 'features', 'deep', 'c.md'),
      '```mermaid\nflowchart TD\n  A -->\n```\n',
    );
    assert.throws(() =>
      execFileSync('node', [script, dir], { encoding: 'utf8', stdio: 'pipe' }),
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
