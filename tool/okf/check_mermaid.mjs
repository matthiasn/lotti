// Parses every ```mermaid block in the knowledge bundle with Mermaid itself.
//
// The Dart validator cannot do this: Mermaid has no Dart parser, so a diagram
// that never renders is invisible to `make okf_check`. Three broken diagrams
// shipped that way before this existed. Two traps caused all three — `;` is a
// statement separator in every diagram type, and a second `:` ends a
// stateDiagram transition label — but the point of parsing for real is catching
// the ones nobody has hit yet.
//
// Usage: node tool/okf/check_mermaid.mjs [bundle-dir]
// Exits 0 when every block parses, 1 otherwise.
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

const blocks = [];
let unclosed = 0;
for (const file of markdownFiles(root)) {
  const lines = readFileSync(file, 'utf8').split('\n');
  let openedAt = null;
  lines.forEach((line, index) => {
    if (openedAt === null && line.trim() === '```mermaid') {
      openedAt = index;
    } else if (openedAt !== null && line.trim() === '```') {
      blocks.push({
        file,
        line: openedAt + 1,
        code: lines.slice(openedAt + 1, index).join('\n'),
      });
      openedAt = null;
    }
  });
  if (openedAt !== null) {
    // The Dart validator reports this too; repeated here so this script is
    // honest about a block it could not extract rather than skipping silently.
    console.error(`unclosed mermaid fence: ${file}:${openedAt + 1}`);
    unclosed++;
  }
}

let failed = 0;
for (const block of blocks) {
  try {
    await mermaid.parse(block.code);
  } catch (error) {
    failed++;
    const detail = String(error?.message ?? error)
      .split('\n')
      .slice(0, 6)
      .join('\n      ');
    console.error(`\nFAIL ${block.file}:${block.line}\n      ${detail}`);
  }
}

console.log(
  `\nmermaid: parsed ${blocks.length} block(s) in ${root}/ — ` +
    `${failed} failed, ${unclosed} unclosed`,
);
process.exit(failed + unclosed === 0 ? 0 : 1);
