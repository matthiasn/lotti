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

test('a mixed closing run does not close the block', () => {
  // CommonMark requires the closing run to be uniform. `` `~~ `` after a ```
  // opener passed a "first character matches, long enough" test and closed the
  // block, so the rest of the file rendered as code while the check passed.
  const r = run('```mermaid\nflowchart TD\n  A --> B\n`~~\n\nprose\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /unclosed mermaid fence/);
});

test('a literal > inside a top-level fence does not close it', () => {
  const r = run('```mermaid\nflowchart TD\n> ```\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /unclosed mermaid fence/);
});

test('a blockquoted fence is a real diagram', () => {
  // CommonMark strips the container prefix before recognising the fence, so
  // `> ```mermaid` opens a block. Requiring column 0 skipped it in silence.
  const r = run('> ```mermaid\n> flowchart TD\n>   A -->\n> ```\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /FAIL/);
});

test('a quoted fence works when marker spacing varies', () => {
  // `>flowchart TD` under a `> ```mermaid` opener: the marker's trailing space is
  // optional, so matching exact prefix text stripped nothing and the block read
  // as unclosed.
  const r = run('> ```mermaid\n>flowchart TD\n>  A --> B\n>```\n');
  assert.ok(r.ok, r.output);
  assert.match(r.output, /parsed 1 block/);
});

test('a nested blockquote fence is still recognised', () => {
  const r = run('> > ```mermaid\n> > flowchart TD\n> >   A --> B\n> > ```\n');
  assert.ok(r.ok, r.output);
  assert.match(r.output, /parsed 1 block/);
});

test('an unclosed mermaid fence is reported', () => {
  const r = run('```mermaid\nflowchart TD\n  A --> B\n');
  assert.ok(!r.ok);
  assert.match(r.output, /unclosed mermaid fence/);
});

test('an unclosed ordinary fence is reported too', () => {
  // This used to be delegated to the Dart validator, which flags any unclosed
  // fence — but that validator only runs over knowledge/, so once docs/ was
  // gated here the delegation had no backstop.
  const r = run('```dart\nvar x = 1;\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /unclosed code fence/);
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

test('a root may be a single file', () => {
  // Passing a file used to throw a raw ENOTDIR stack trace. Asserting only
  // that a *broken* file fails would not distinguish the fix from that crash,
  // so this checks a valid file is read and counted, then that a broken one
  // fails for a mermaid reason.
  const dir = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  try {
    const valid = join(dir, 'one.md');
    writeFileSync(valid, good);
    const output = execFileSync('node', [script, valid], {
      encoding: 'utf8',
      stdio: 'pipe',
    });
    assert.match(output, /parsed 1 block\(s\)/);

    const broken = join(dir, 'two.md');
    writeFileSync(broken, '```mermaid\nflowchart TD\n  A -->\n```\n');
    try {
      execFileSync('node', [script, broken], {
        encoding: 'utf8',
        stdio: 'pipe',
      });
      assert.fail('a broken diagram in a file root must fail the run');
    } catch (error) {
      assert.match(`${error.stdout ?? ''}${error.stderr ?? ''}`, /FAIL/);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('an unclosed ordinary fence is reported, not silently swallowed', () => {
  // It hides every diagram below it: the extractor reads the rest of the file
  // as literal code. Reporting only unclosed *mermaid* openers meant a broken
  // diagram underneath one exited 0 — and outside knowledge/ nothing else
  // flags unclosed fences.
  const r = run('```dart\nvar x = 1;\n\n```mermaid\nflowchart TD\n  A --> B\n');
  assert.ok(!r.ok, r.output);
  assert.match(r.output, /unclosed code fence/);
  // The diagram below it was never extracted — that is the harm.
  assert.match(r.output, /parsed 0 block\(s\)/);
});

test('a root that is neither a directory nor markdown is rejected', () => {
  // Silently scanning nothing and exiting 0 is the failure mode this whole
  // tool exists to prevent.
  const dir = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  try {
    const notMarkdown = join(dir, 'README.txt');
    writeFileSync(notMarkdown, 'flowchart TD\n  A --> B\n');
    try {
      execFileSync('node', [script, notMarkdown], {
        encoding: 'utf8',
        stdio: 'pipe',
      });
      assert.fail('an unsupported root must not pass silently');
    } catch (error) {
      assert.match(
        `${error.stdout ?? ''}${error.stderr ?? ''}`,
        /not a directory or a markdown file/,
      );
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('every root given is scanned, not just the first', () => {
  // The gate watched only `knowledge/` while two ADR diagrams rendered as
  // error boxes. Taking several roots is what closes that gap, so a second
  // root being silently ignored would reopen it.
  const first = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  const second = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  try {
    writeFileSync(join(first, 'ok.md'), good);
    writeFileSync(
      join(second, 'broken.md'),
      '```mermaid\nflowchart TD\n  A -->\n```\n',
    );
    assert.throws(
      () =>
        execFileSync('node', [script, first, second], {
          encoding: 'utf8',
          stdio: 'pipe',
        }),
      'a broken diagram under the second root must fail the run',
    );
  } finally {
    rmSync(first, { recursive: true, force: true });
    rmSync(second, { recursive: true, force: true });
  }
});

test('the block count spans every root', () => {
  const first = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  const second = mkdtempSync(join(tmpdir(), 'mermaid-gate-'));
  try {
    writeFileSync(join(first, 'a.md'), good);
    writeFileSync(join(second, 'b.md'), good);
    const output = execFileSync('node', [script, first, second], {
      encoding: 'utf8',
      stdio: 'pipe',
    });
    assert.match(output, /parsed 2 block\(s\)/);
  } finally {
    rmSync(first, { recursive: true, force: true });
    rmSync(second, { recursive: true, force: true });
  }
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
