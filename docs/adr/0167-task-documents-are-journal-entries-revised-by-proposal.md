# ADR 0167: Task Documents Are Journal Entries, Revised by Proposal

- Status: Proposed
- Date: 2026-11-22
- Concepts: [Task documents](../../knowledge/features/documents.md), [Task agents](../../knowledge/features/agents/task-agents.md), [Query chat](../../knowledge/features/agents/query-chat.md), [GitHub pull requests](../../knowledge/features/github.md)

## Context

Users already write client one-pagers, meeting summaries and follow-up
emails by feeding material into a chat with a model and refining the result
over several turns. Most of that material is already in a Lotti task: the
instructions in its voice notes, a meeting transcript linked to it, its
checklists. What is missing is a place for the result.

The ask is a task that holds markdown documents its agent drafts and
revises. A voice note such as *"I want a one-pager with the follow-up for
the meeting where we present the next steps"* produces a first version. A
later note, or a chat message, asks for changes ("less salesy, take the
dates from the meeting") and produces the next version. The user copies the
markdown out and posts it elsewhere. A task may hold several documents.

Three properties shape the storage and the write path:

- **A document outlives the agent.** Agent reports are keyed by `agentId`
  (`AgentReportEntity`, `AgentReportHeadEntity` in
  `lib/classes/agents/agent_domain_entity.dart`), and a task's agent can be
  retired and replaced. A client document must not leave with it.
- **The user edits it too.** Small fixes by hand are expected, so the text
  is part of the user's record, not only agent output.
- **Agents propose, the user decides.** `PRODUCT.md` makes every
  agent-initiated change a proposal with confirm and dismiss. ADR 0102 lists
  the few pre-approved exceptions, and documents are not to become one.

The closest existing shapes are the soul document (`soulDocument`,
`soulDocumentVersion`, `soulDocumentHead`: immutable versions plus a head
pointer, revised through a proposal) and the pull request entry (a journal
variant linked to its task, shown as a task section, merged across devices
without a user-facing conflict).

Two placements were weighed:

- **Agent database**, next to reports and souls. Writes go through
  `AgentSyncService` and conflicts are last-writer-wins. But the agent
  database deliberately does not mirror journal state, documents would be
  owned by an agent rather than the task, and a hand edit by the user would
  be a user write stored as agent data.
- **Journal**, next to pull request entries. The document is part of the
  task's record, outlives any agent, and can be shown by the task page
  without the agent feature. New journal variants need no SQL migration
  (rows are serialized JSON with indexed type columns); an older build skips
  a variant it cannot decode.

## Decision

1. **A document belongs to exactly one task and lives in the journal.** Two
   new `JournalEntity` variants: `TaskDocument` (title, the id of its
   current version) linked to its task by an `EntryLink`, and
   `TaskDocumentVersion` (document id, version number, markdown, author,
   provenance). There is no document without a task. Documents and their
   versions are kept out of the task's history list, as pull request
   entries already are.

2. **Versions are append-only; "current" is a pointer.** A version is never
   edited after it is written, so two devices can never conflict over one.
   Only `TaskDocument` changes. Two concurrent versions of it merge in
   `database_entity_ops.dart` without a user-facing conflict, like a pull
   request pair: the pointer goes to the newer of the two versions, the
   title is last-writer-wins, and both versions stay in history.

3. **The agent writes only through a proposal.** A new deferred tool,
   `propose_document_version(documentId | newTitle, markdown, changeSummary,
   baseVersionId)`, becomes a `ChangeItem` the user confirms or dismisses.
   Confirming goes through `ChangeSetConfirmationService` and
   `TaskToolDispatcher`, which writes the version and moves the pointer in
   one transaction. A newer proposal for the same document retracts the
   older pending one.

4. **A stale proposal cannot be confirmed.** `baseVersionId` names the
   version the agent drafted against. If the current version has moved on,
   Confirm is not offered. The user can dismiss the proposal or ask the
   agent to redo it against the current version. Confirming it would make
   the agent's text current and silently drop the user's newer edits from
   it.

5. **A hand edit by the user writes a version directly.** It is the user's
   own write, so it needs no proposal. It records the user as its author.
   Restoring an old version writes a new version with the old text.

6. **The agent drafts only when asked.** A version is proposed when a voice
   note, text entry or chat message asks for a document or names one. New
   material on the task (a transcript landing, a checklist change) does not
   revise documents on its own. The task agent's prompt carries this rule,
   and the proposal step is the backstop: nothing reaches the document
   unconfirmed.

7. **Document text reaches the agent on request, which is a deliberate
   exception.** Every task agent wake gets a short directory of the task's
   documents (id, title, current version, one line). The full text of one
   comes only through a new local read tool, `read_document(id)`. The task
   agent otherwise omits its prior report's prose so stale conclusions
   cannot feed back as evidence
   ([Task agents](../../knowledge/features/agents/task-agents.md)). A
   document is different: its current version is text the user confirmed or
   wrote, and revising it requires reading it.

8. **Two ways in, one path.** A task agent wake (a voice note or transcript
   on the task) and the task's query chat (a change request planned by
   `QueryTaskActionPlanner`) both propose through the same tool and the same
   change set. Every place a proposal can be decided (the task section, the
   document page, its side-by-side review, the chat card) calls the same
   confirmation service.

9. **A `documents` feature between `agents` and `tasks`.** It owns the
   section, the document page and the review mode. `agents` never imports
   it: it defines an interface for writing a confirmed version, which
   `documents` implements and `appFeatureWiringOverrides()` binds, as
   `PullRequestLinkSource` does for pull requests. Entity classes live in
   `lib/classes`.

10. **Review takes its width without changing the user's layout.** Side by
    side needs about 900px of document width, more than the detail pane has
    at a 1440 window with the task list showing. While review is open, the
    task list and day column step aside, the same way they do for task chat
    today: their visibility is derived in `tasks_root_page.dart` and
    `beamer_app_layout_part.dart`, and the user's stored pane settings are
    never written. Opening chat from review drops it to one column.

## Consequences

- The record stays honest. Agent text enters a document only through a
  confirmed proposal, and each version records whether the agent or the
  user wrote it and what it was drafted from.
- Documents outlive their agent. Retiring or replacing a task's agent leaves
  the documents and their history in place.
- A whole document travels in a synced proposal, and in the prompt when
  read. That is probably fine for a one-pager, but the payload and token
  cost should be measured with a long document before shipping.
- The `documents` feature becomes a new rung in
  `tool/architecture/layer_guard.dart`, and `agents` grows one more
  interface implemented above it.
- A device on an older build skips both variants as undeserializable. It
  shows no documents and corrupts nothing.
- The chat way in depends on task chat, which is behind `enable_query_chat`
  (off by default). With the flag off, documents are steered by voice notes
  only, and "Ask for changes" is hidden.
- `DESIGN.md` says agent chat is a 400px overlay the page never reflows
  around, but `QueryCompanion` docks it as a column on wide windows. The
  side-by-side review relies on the docked behaviour, so `DESIGN.md` has to
  change to match the code before review ships.
- How a version is found from its document (an `EntryLink` or an indexed
  column in `lib/database/conversions.dart`), and whether deleting a
  document deletes its versions, are settled in the first implementation
  step and recorded in the concept.

## Related

- [ADR 0102: Pre-Approved Agent Changes](0102-pre-approved-agent-changes.md)
- [ADR 0165: Pull Requests Are Found by a Call of Their Own](0165-pull-requests-are-found-by-a-call-of-their-own.md)
