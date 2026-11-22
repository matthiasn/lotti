# ADR 0166: The Task Agent Writes Its Report as Sections

- Status: Accepted
- Date: 2026-11-22
- Concepts: [task agents](../../knowledge/features/agents/task-agents.md), [agent UI surfaces](../../knowledge/features/agents/ui-surfaces.md)

## Context

The task page's AI summary shows the agent's report behind *Read more*.
Until now the agent wrote the report body as one Markdown document, and the
card rendered it with `AgentMarkdownView`: headings, bullets and paragraphs in
the violet card, looking like a pasted document, not part of the app.

The owner's direction is that structured agent output becomes components, not
Markdown. Two ways were weighed:

- **The card parses the Markdown.** Nothing in the data changes, but headings
  are free text in the task's language and the stock directive makes them
  optional, so a parser can only guess from the shape and needs a Markdown
  fallback anyway.
- **The agent writes the structure.** The report tool takes sections, each a
  list of points, a checklist or a paragraph, with an optional title. The
  structure is then data the model chose, not something guessed afterwards.

The report body is read by much more than the card: the agent internals, the
embedding index, read-aloud, the companion's report tools, the report editor's
regression checks and the publication-noise filters all read `content` as
Markdown text.

## Decision

1. **`update_report` takes `sections` instead of `content`.** Each section has
   a `kind` (`points`, `checklist`, `text`), an optional `title`, and either
   `items` (`{text, done}`) or `text`. Item and paragraph text stays inline
   Markdown, so links and emphasis survive. The report editor's forced
   `update_report` takes the same shape.
2. **`content` remains, written by the app.** The stored `content` is the
   sections rendered as Markdown (`renderAgentReportSectionsMarkdown`), so
   every reader of the text, and every check on it, keeps working unchanged.
3. **The sections are stored on the report** (`AgentReportEntity.sections`)
   after the same cleanup the text gets: absent-metadata notes leave every
   row, and a section the Markdown rules would drop (empty, "none", a Links
   section without a link) goes whole. The stored text is rendered from the
   cleaned, sanitized sections, so the two cannot disagree.
4. **The task card draws the sections** (`AgentReportSectionsView`): a title
   over a bulleted list, a read-only checklist, or a paragraph. A report with
   no sections (written before this change, by another agent kind, or by a
   model that sent `content` anyway) still renders as Markdown.
5. **A plain `content` string is still accepted** from a model that ignores
   the schema, and becomes a Markdown report.

## Consequences

- A synced report carries a new `sections` field. An older client ignores it
  and shows `content`, which is unchanged in form.
- Only the task card draws sections. The relationship briefing and the event
  summary share the card body, but their agents still write Markdown.
- The sections are not A2UI. ADR 0163 covers surfaces the model composes in a
  chat turn; here the app renders stored data, so plain design-system widgets
  draw it without a surface message in between.
- Custom and evolved report directives that name Markdown headings still work:
  each heading becomes a section title.
