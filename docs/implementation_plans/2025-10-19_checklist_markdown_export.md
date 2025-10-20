# Checklist Markdown Export — Implementation Plan

## Summary

- Add an “Export as Markdown” capability for an entire checklist.
- Output uses GitHub-flavored Markdown checklist syntax per item:
    - `- [ ]` for incomplete, `- [x]` for completed.
- Primary action: copy the generated Markdown to clipboard (cross‑platform).
- Optional secondary action (where available): share the Markdown via the system share sheet. This
  would be second task and not part of the first version. Unclear at this point if actually useful.

## Goals

- One-click export of a single checklist into valid Markdown with preserved item order.
- Make it easy to paste into Linear, GitHub, or any Markdown-capable tool.
- Keep UI minimal and discoverable in the existing checklist header.

## Non‑Goals

- Exporting multiple checklists at once.
- Exporting tasks or other entry types as Markdown.
- Persisting exports or creating files.

## UX and Interaction

- Placement: add a small export action in the Checklist header (next to the edit icon).
    - Icon: `MdiIcons.exportVariant` (or `Icons.ios_share` on iOS if preferred for platform
      consistency).
    - Tooltip/semantics: “Export checklist as Markdown”.
- Action behavior:
    - Default tap: copy Markdown to clipboard, show localized SnackBar confirmation.
    - Optional overflow menu (or long-press/context on desktop):
        - Copy as Markdown (default)
        - Share as Markdown (mobile-first; use `share_plus`)
- Disabled state: if any checklist items are still loading, gracefully generate with what’s already
  available; if nothing is available yet, hide the copy button altogether.

## Output Format

- One line per item in current order:
    - `- [ ] Item title` when unchecked
    - `- [x] Item title` when checked
- Title handling:
    - By default, do not prepend the checklist title to maximize portability into other tools (like
      Linear). Consider a follow-up option for including a heading later.
- Sanitization:
    - Trim leading/trailing spaces on item titles.
    - Replace embedded newlines/tabs with a single space.
    - Leave other characters untouched (Markdown generally tolerates brackets/hyphens).

### Example

```
- [ ] Draft user research questions
- [x] Align success metrics
- [ ] Prepare kickoff deck
```

## Architecture

1) Generator: add a pure function to build Markdown from a checklist model
    - New file: `lib/features/tasks/services/checklist_markdown_exporter.dart`
    - API (example):
        - `String checklistToMarkdown({required List<ChecklistItem> items})`
    - Responsibilities:
        - Preserve input order.
        - Skip deleted items.
        - Apply sanitization: trim each checklist text.

2) UI hook: wire an export action where the checklist is built
    - Prefer keeping `ChecklistWidget` presentation-only; pass a callback from the wrapper that
      knows how to gather items.
    - `ChecklistWidget` changes:
        - Add optional `Future<void> Function()? onExportMarkdown` prop.
        - Render an icon button in the header when provided.
    - `ChecklistWrapper` (ConsumerWidget):
        - Implement `onExportMarkdown` by reading the linked item providers and waiting for values
          via `ref.read(checklistItemControllerProvider(...).future)`.
        - Build the Markdown with the exporter, then:
            - Copy via `appClipboardProvider.writePlainText(markdown)`.
            - Show localized SnackBar confirmation.
        - Optionally offer “Share” via `share_plus` on mobile.

## Data Flow

- Source of truth for item order: `Checklist.data.linkedChecklistItems` (already passed to
  `ChecklistWidget`).
- Fetch items: Riverpod `checklistItemControllerProvider(id: ..., taskId: ...)` futures; ignore
  null/deleted.
- Compose markdown from `(title, isChecked)` in the exact linked order.

## i18n / Strings

- Add to ARB (`lib/l10n/*.arb`):
    - `checklistExportMarkdown`: “Export as Markdown”
    - `checklistCopyMarkdown`: “Copy Markdown”
    - `checklistShareMarkdown`: “Share Markdown”
    - `checklistMarkdownCopied`: “Checklist copied as Markdown”
- Run `make l10n` and update `missing_translations.txt` accordingly.

## Accessibility

- Provide `semanticsLabel` for the export icon: “Export checklist as Markdown”.
- Ensure the SnackBar messages are descriptive and localized.

## Testing Strategy

1) Unit tests for generator
    - File: `test/features/tasks/services/checklist_markdown_exporter_test.dart`
    - Cases:
        - Empty list → empty string.
        - Mixed checked/unchecked items.
        - Order preserved.
        - Titles with whitespace/newlines.
        - Items with special characters (brackets, hyphens) pass through unchanged.

2) Widget tests for UI
    - File: `test/features/tasks/ui/checklists/checklist_export_button_test.dart`
    - Verify export icon renders when `onExportMarkdown` is provided.
    - Tapping export calls the callback once.
    - With a mocked `AppClipboard`, verify that copy is called with expected string.

3) Integration slice (optional)
    - A small test through `ChecklistWrapper` with a couple of mocked items to verify the composed
      output and SnackBar display.

## Performance

- Complexity is O(n) in item count. Uses `Future.wait` to fetch items concurrently. No persistent
  caching added.

## Edge Cases & Handling

- Items still loading: gather what’s available via futures; if none resolve, hide the export icon.
- Deleted items: filtered out.
- Very long lists: acceptable; copying to clipboard handles large strings. Consider truncation
  warning only if discovered as a real issue.

## Files to Modify / Add

- Add: `lib/features/tasks/services/checklist_markdown_exporter.dart`
- Update: `lib/features/tasks/ui/checklists/checklist_widget.dart` (accept and render export
  callback prop)
- Update: `lib/features/tasks/ui/checklists/checklist_wrapper.dart` (implement callback: collect
  items → generate → copy/share)
- Add tests:
    - `test/features/tasks/services/checklist_markdown_exporter_test.dart`
    - `test/features/tasks/ui/checklists/checklist_export_button_test.dart`
- i18n:
    - Update `lib/l10n/app_*.arb` with new keys; run `make l10n`.

## Rollout Plan

1) Implement generator and unit tests.
2) Add UI prop and wire the button; add widget tests.
3) Integrate copy/share using `appClipboardProvider` and `share_plus` where supported.
4) Update l10n ARB files and run `make l10n`.
5) Run `make analyze` and `make test`; ensure zero analyzer warnings.
6) Manual verification on desktop and mobile simulators/emulators.

## Open Questions

- Should we include the checklist title as a Markdown heading optionally? (Default proposed: no, to
  maximize frictionless pasting into Linear.) - No, don't add checklist title.
- Do we need a transient modal to pick “Copy vs Share”, or is a single-tap copy sufficient with a
  long-press/context alternative for Share? - No modal, long press for share seems like a good idea
  if we get to that.

## Implementation Checklist

- [x] Generator builds correct Markdown across edge cases
- [x] Export icon present and accessible in header
- [x] Copy action uses `AppClipboard` and shows localized SnackBar
- [x] Share action available on mobile via `share_plus`
- [x] i18n keys added and generated
- [x] Unit and widget tests added and passing
- [x] `make analyze` yields zero warnings

## Implementation Summary (as built)

- Generators
    - `checklistItemsToMarkdown` produces `- [ ]` / `- [x]` lines (preserves order, trims titles,
      skips deleted).
    - `checklistItemsToEmojiList` produces `⬜` / `✅` lines for messenger/email sharing.

- UI integration
    - `ChecklistWidget` header shows edit first, then export.
    - Export IconButton wrapped in a `GestureDetector` for:
        - Tap/click → copy Markdown
        - Long‑press (mobile) and secondary‑click (desktop) → share emoji list
    - Tooltip shown on desktop; suppressed on mobile so long‑press fires.

- Copy flow
    - Uses `appClipboardProvider` to copy; shows SnackBar.
    - One‑time mobile hint appended to the SnackBar: “Long press to share”.

- Share flow
    - Uses `SharePlus.instance.share(ShareParams(text: ..., subject: ...))`.
    - Subject is checklist title; text is emoji list for better chat/email readability.

- i18n
    - Added ARB keys for: export tooltip, copy success, share hint, empty list, and export failure.
    - All strings are referenced via generated getters (gen‑l10n).

- Files
    - Exporters: `lib/features/tasks/services/checklist_markdown_exporter.dart`
    - UI: `lib/features/tasks/ui/checklists/checklist_widget.dart`,
      `lib/features/tasks/ui/checklists/checklist_wrapper.dart`
    - Tests: `test/features/tasks/services/checklist_markdown_exporter_test.dart`,
      `test/features/tasks/services/checklist_emoji_exporter_test.dart`,
      `test/features/tasks/ui/checklists/checklist_export_button_test.dart`,
      `test/features/tasks/ui/checklists/checklist_wrapper_export_test.dart`

- Notes
    - macOS share sheet preview spacing is system‑controlled; no styling hook via `share_plus`.
    - Markdown copy intentionally excludes a heading for cleaner pasting into Linear/GitHub.

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS
  assertions such as finding a row or whatnot. Focus on useful information.
- Aim for full coverage of every code path.
