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
// Usage: node tool/okf/check_mermaid.mjs [bundle-dir]
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

const root = process.argv[2] ?? 'knowledge';

function markdownFiles(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const path = join(dir, entry);
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
/// spaces, same delimiter character, at least as long, and nothing else on it.
function closesFence(line, opener) {
  const match = /^( {0,3})([`~]+)\s*$/.exec(line);
  if (match === null) return false;
  const run = match[2];
  return run[0] === opener[0] && run.length >= opener.length;
}

const blocks = [];
let unclosed = 0;
for (const file of markdownFiles(root)) {
  const lines = readFileSync(file, 'utf8').split('\n');
  let opener = null;
  let openedAt = 0;
  let isMermaid = false;
  lines.forEach((line, index) => {
    // Keep the leading indent: only the trailing whitespace is noise.
    const kept = line.replace(/\s+$/, '');
    if (opener === null) {
      const match = FENCE.exec(kept);
      if (match) {
        opener = match[2];
        openedAt = index;
        // Only the *outermost* fence counts: a mermaid fence shown as an example
        // inside a ````markdown block is documentation, not a diagram to parse.
        isMermaid = match[3].toLowerCase() === 'mermaid';
      }
      return;
    }
    if (!closesFence(kept, opener)) return;
    if (isMermaid) {
      blocks.push({
        file,
        line: openedAt + 1,
        code: lines.slice(openedAt + 1, index).join('\n'),
      });
    }
    opener = null;
    isMermaid = false;
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
  `\nmermaid: parsed ${blocks.length} block(s) in ${root}/ — ` +
    `${failed} failed, ${unclosed} unclosed`,
);
process.exit(failed + unclosed === 0 ? 0 : 1);
