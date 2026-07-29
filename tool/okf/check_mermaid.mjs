// Parses every ```mermaid block in the knowledge bundle with Mermaid itself.
//
// The Dart validator cannot do this: Mermaid has no Dart parser, so a diagram
// that never renders is invisible to `make okf_check`. Three broken diagrams
// shipped that way before this existed. One trap caused all three: **`;`
// terminates a statement**, so a semicolon in a label ends it there and the
// remainder is reparsed. (`:=` was once blamed for this and is innocent —
// `A --> B: id := joinId` parses fine against the pinned mermaid.)
//
// Parsing alone is not enough for that trap, which is why this script also
// inspects the built diagram: in a state diagram the split usually *succeeds*,
// silently rendering the remainder as extra state nodes. One real label —
// `dedupe payload by contentDigest; append messagePayload link; retract
// vanished sources` — parsed clean and produced six nodes instead of one.
//
// Usage: node tool/okf/check_mermaid.mjs [path...]
// Defaults to `knowledge`. Each path is a directory to scan or a single `.md`
// file to check; anything else is rejected rather than silently scanning
// nothing. Several roots can be given, because the same trap is invisible in
// any markdown the build does not parse: two broken ADR diagrams shipped while
// this gate watched only the knowledge bundle, and twelve more sat under
// `docs/`.
// Exits 0 when every block parses and renders the nodes it declares, 1 otherwise.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { JSDOM } from 'jsdom';

// Mermaid needs a DOM even to parse. jsdom is enough — no browser, no headless
// Chromium, so this stays runnable in CI without a 150 MB download.
const dom = new JSDOM('<!doctype html><html><body></body></html>', {
  pretendToBeVisual: true,
});
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.SVGElement = dom.window.SVGElement;
globalThis.Element = dom.window.Element;
// Node 25 exposes `navigator` as a getter-only global, so assignment throws.
Object.defineProperty(globalThis, 'navigator', {
  value: dom.window.navigator,
  configurable: true,
});

const { default: mermaid } = await import('mermaid');
mermaid.initialize({ startOnLoad: false, securityLevel: 'loose' });

const roots = process.argv.slice(2);
if (roots.length === 0) roots.push('knowledge');

/// Every markdown file under `target`, which may be a directory or a single
/// file. The file form is not a convenience: handing this a path used to throw
/// a raw ENOTDIR stack trace, and checking one document at a time is exactly
/// what you want while fixing the diagrams it reports.
function markdownFiles(target) {
  if (!statSync(target).isDirectory()) {
    // Returning [] here would let `check_mermaid.mjs README.txt` report
    // "0 blocks, 0 failed" and exit 0 — a false green in the one tool that
    // exists to prevent them.
    if (!target.endsWith('.md')) {
      throw new Error(
        `not a directory or a markdown file: ${target}\n` +
          'Pass a directory to scan, or a .md file to check on its own.',
      );
    }
    return [target];
  }
  return readdirSync(target).flatMap((entry) => {
    const path = join(target, entry);
    return statSync(path).isDirectory()
      ? markdownFiles(path)
      : path.endsWith('.md')
        ? [path]
        : [];
  });
}

// CommonMark fence forms, not just the canonical one. Matching `'```mermaid'`
// exactly meant a `~~~mermaid` or ````` ````mermaid ````` block was skipped in
// silence while the CI step claimed to have parsed every diagram — a false green
// in the one check that exists to prevent false greens.
// The leading-indent group is load-bearing: CommonMark allows a fence to be
// indented by at most **three** spaces. At four it is an indented code block — a
// literal example of a fence, not a fence — so trimming the indent away made a
// documented mermaid snippet indistinguishable from a real diagram.
const FENCE = /^( {0,3})(`{3,}|~{3,})\s*(\S*)/;

/// Whether `line` closes a block opened by `opener`: indented at most three
/// spaces, a **uniform** run of the opener's delimiter, at least as long, and
/// nothing else on the line.
///
/// The run must be uniform, not merely start with the right character: a mixed
/// `` `~~ `` after a ``` opener satisfied "first character matches, length is
/// enough" and closed the block, so the rest of the concept still rendered as
/// code while the checker reported success.
function closesFence(line, opener) {
  const match = /^ {0,3}(`+|~+)\s*$/.exec(line);
  if (match === null) return false;
  const run = match[1];
  return run[0] === opener[0] && run.length >= opener.length;
}

// One blockquote marker: up to three spaces of indent, `>`, and an *optional*
// single space or tab. The trailing space is optional in CommonMark, which is why
// the container is tracked as a **depth** rather than as literal prefix text — a
// body line may write `>flowchart TD` under an opener that wrote `> `.
const MARKER = /^ {0,3}>(?: |\t)?/;

/// How many blockquote markers `line` opens with.
function containerDepth(line) {
  let rest = line;
  let depth = 0;
  for (;;) {
    const match = MARKER.exec(rest);
    if (match === null) return depth;
    rest = rest.slice(match[0].length);
    depth += 1;
  }
}

/// Removes `depth` blockquote markers from `line`, whatever their spacing.
///
/// Tied to the opener's depth on purpose. Stripping `>` unconditionally meant a
/// **top-level** fence whose body contained a literal `` > ``` `` had that marker
/// stripped and then read as the close — so an unclosed fence was reported as a
/// clean block. CommonMark treats content inside a fence as literal; only the
/// container the fence was opened *under* is removed from its body.
///
/// **List-item containers are not modelled**: a fence indented past three spaces
/// inside a list item reads as an indented code block, so keep diagrams at the
/// top level of a document.
function stripDepth(line, depth) {
  let rest = line;
  for (let i = 0; i < depth; i++) {
    const match = MARKER.exec(rest);
    if (match === null) return rest;
    rest = rest.slice(match[0].length);
  }
  return rest;
}

// A bad root is a usage error, not a crash: report it the way every other
// failure here is reported rather than as a raw Node stack trace.
let targets;
try {
  targets = roots.flatMap((dir) => markdownFiles(dir));
} catch (error) {
  console.error(`\nmermaid: ${error.message}`);
  process.exit(1);
}

const blocks = [];
let unclosed = 0;
for (const file of targets) {
  const lines = readFileSync(file, 'utf8').split('\n');
  let opener = null;
  let openedAt = 0;
  let isMermaid = false;
  let depth = 0;
  lines.forEach((line, index) => {
    const trimmedEnd = line.replace(/\s+$/, '');
    if (opener === null) {
      // Outside a fence, a blockquote marker is a container: strip it, and
      // remember it so the body and the close are read in the same context.
      const candidate = containerDepth(trimmedEnd);
      const match = FENCE.exec(stripDepth(trimmedEnd, candidate));
      if (match) {
        opener = match[2];
        depth = candidate;
        openedAt = index;
        // Only the *outermost* fence counts: a mermaid fence shown as an example
        // inside a ````markdown block is documentation, not a diagram to parse.
        isMermaid = match[3].toLowerCase() === 'mermaid';
      }
      return;
    }
    // Inside a fence, only the opener's own container is removed.
    if (!closesFence(stripDepth(trimmedEnd, depth), opener)) return;
    if (isMermaid) {
      blocks.push({
        file,
        line: openedAt + 1,
        // Unwrap the container on the body too, or mermaid is handed `> > A --> B`
        // and reports "no diagram type detected" for a diagram that renders fine.
        code: lines
          .slice(openedAt + 1, index)
          .map((l) => stripDepth(l, depth))
          .join('\n'),
      });
    }
    opener = null;
    isMermaid = false;
    depth = 0;
  });
  if (opener !== null && isMermaid) {
    // The Dart validator reports any unclosed fence; repeated here so this
    // script is honest about a block it could not extract rather than skipping.
    console.error(`unclosed mermaid fence: ${file}:${openedAt + 1}`);
    unclosed++;
  }
}

/// Node ids that only exist because a statement was split.
///
/// A `;` in an unquoted label ends the statement, and the remainder is reparsed —
/// in a state diagram it usually becomes extra *states*, so the block parses
/// clean and renders wrongly. Any id carrying a `;` is that split, and nothing
/// legitimate produces one: a real id cannot contain the separator, and a
/// semicolon inside a quoted label or a `note` body never reaches the node list.
export function phantomNodes(diagram) {
  let data;
  try {
    data = diagram.db?.getData?.();
  } catch {
    return []; // diagram types without a node view (sequence, etc.)
  }
  return (data?.nodes ?? [])
    .map((n) => String(n.id ?? n.label ?? ''))
    .filter((id) => id.includes(';'));
}

let failed = 0;
for (const block of blocks) {
  const where = `${block.file}:${block.line}`;
  try {
    await mermaid.parse(block.code);
  } catch (error) {
    failed++;
    const detail = String(error?.message ?? error)
      .split('\n')
      .slice(0, 6)
      .join('\n      ');
    console.error(`\nFAIL ${where}\n      ${detail}`);
    continue;
  }
  // Parsed — now check it renders what it declares.
  try {
    const diagram = await mermaid.mermaidAPI.getDiagramFromText(block.code);
    const phantoms = phantomNodes(diagram);
    if (phantoms.length > 0) {
      failed++;
      console.error(
        `\nFAIL ${where}\n      a \`;\` split a statement: this parses but ` +
          `renders phantom node(s) ${phantoms.map((p) => `\`${p}\``).join(', ')}` +
          `\n      Use a comma. A semicolon terminates the statement.`,
      );
    }
  } catch {
    // Building the diagram can fail for reasons parse tolerates; parse is the
    // contract this gate promises, so do not fail the run on it.
  }
}

console.log(
  `\nmermaid: parsed ${blocks.length} block(s) in ${roots.join(', ')} — ` +
    `${failed} failed, ${unclosed} unclosed`,
);
process.exit(failed + unclosed === 0 ? 0 : 1);
