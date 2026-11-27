# ADR 0167: Task Documents Are Journal Entries the Agent Writes Directly, With Version History

- Status: Proposed
- Date: 2026-11-22, revised 2026-11-27 before it was accepted
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
- **Refining is a loop.** A document is reached in several turns: ask, read,
  ask again. Whatever stands between a request and its result is paid on
  every turn.

The closest existing shapes are the soul document (`soulDocument`,
`soulDocumentVersion`, `soulDocumentHead`: immutable versions plus a head
pointer) and the pull request entry (a journal variant linked to its task,
shown as a task section, merged across devices without a user-facing
conflict).

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

Two ways for the agent's text to reach a document were weighed, and the
first was built before the second was chosen:

- **Through a proposal.** `PRODUCT.md` makes an agent-initiated change a
  proposal with confirm and dismiss, and the first build did the same for
  documents: each version waited as a change item, was read in a sheet or a
  side-by-side review, and became the document on Confirm. It kept the rule
  whole, and it made every turn of the loop two steps. The apps people
  already draft documents in do not work that way: the model writes, and
  the earlier text is one step back in a version list.
- **Directly, with history as the way back.** The agent writes the version;
  the document shows it at once; every earlier version stays, and going back
  is one action. Nothing is lost by an unwanted version, because versions
  are append-only and a restore writes a new one. What a confirmation
  guarded — that an unasked-for or careless rewrite never replaces the
  user's text unseen — has to be guarded another way (decisions 3, 4 and 6).

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

3. **The agent writes a version directly; no confirmation stands in
   between.** `write_document_version(documentId | newTitle, markdown,
   changeSummary)` makes the text the document's current version as soon as
   it is called, recorded as the agent's. This adds a path to the class of
   pre-approved agent changes ([ADR 0102](0102-pre-approved-agent-changes.md)):
   the consent is the request the user made — the voice note, note or chat
   message that asked for the document — and, as for the task agent's
   other pre-approved writes, assigning the agent to the task. What makes it
   acceptable where a status change is not: the write destroys nothing
   (decision 2), and undoing it is one action on the document
   (decision 10).

4. **An agent version never replaces text the agent has not read.** A
   version is written over the version the agent read, and only while the
   document still shows that one — the compare-and-set a hand edit uses. In
   a wake, a document that has text must be read with `read_document` in
   that wake before a version of it is accepted, and the version is written
   over what that read returned, never over an id the model names. In chat,
   a document may be revised only when its text was supplied to the model,
   and the version is written over the version supplied. A version drafted
   against text that moved on meanwhile — the user edited by hand — is
   refused, with nothing written, and the agent is told to read again.

5. **A hand edit by the user writes a version directly.** It records the
   user as its author. Restoring an old version writes a new version with
   the old text.

6. **The agent drafts only when asked.** A version is written when a voice
   note, text entry or chat message asks for a document or names one. New
   material on the task (a transcript landing, a checklist change) does not
   revise documents on its own. Only the prompt and the tool description
   carry this rule — nothing in code can tell a request from other text —
   so a wake can misjudge it, and then an unasked-for version is the
   document's text until the user goes back. That is the cost of decision
   3, bounded by three things: one version per document in a wake; the
   version says it is the agent's wherever the document is listed or shown;
   and the version before it is one action away.

7. **Document text reaches the agent on request, which is a deliberate
   exception.** Every task agent wake gets a short directory of the task's
   documents (id, title, current version, one line). The full text of one
   comes only through a local read tool, `read_document(id)`. The task
   agent otherwise omits its prior report's prose so stale conclusions
   cannot feed back as evidence
   ([Task agents](../../knowledge/features/agents/task-agents.md)). A
   document is different: its current version is the user's work product,
   and revising it requires reading it.

8. **Two ways in, one write.** A task agent wake (a voice note or
   transcript on the task) and the task's query chat (a change request
   planned by `QueryTaskActionPlanner`) both write through the same tool,
   handler and port. A wake calls it as it runs. Chat records the version
   as an item of the answer's change set, as it records every change it
   plans, and applies that item as soon as the answer is saved, without
   asking; the rest of the set still waits for the user. One that could not
   be written stays pending on its row in the chat.

9. **A `documents` feature between `agents` and `tasks`.** It owns the
   section, the document page and the review mode. `agents` never imports
   it: it defines an interface for reading documents and writing a version,
   which `documents` implements and `appFeatureWiringOverrides()` binds, as
   `PullRequestLinkSource` does for pull requests. Entity classes live in
   `lib/classes`.

10. **The review shows what a version changed, and goes back.** A version
    written over another can be laid beside it, block by block, from the
    document page — which says so while the version on show is the agent's —
    and from the history. It decides nothing: it offers the version before
    it, restored as a new version, and the task's chat. Side by side needs
    about 900px of document width, more than the detail pane has at a 1440
    window with the task list showing. While the review is open, the task
    list and day column step aside, the same way they do for task chat
    today: their visibility is derived in `tasks_root_page.dart` and
    `beamer_app_layout_part.dart`, and the user's stored pane settings are
    never written. Opening chat from the review drops it to one column.

## Consequences

- Asking for a document, or for a change to one, is one step. The result is
  on the task when the wake or the chat answer finishes.
- `PRODUCT.md`'s rule that an agent proposes and the user decides has one
  more named exception. The record stays honest about it: a version says
  whether the agent or the user wrote it, and an agent version is never
  recorded as confirmed.
- A wrong or unasked-for version is live until the user notices. A user who
  copies a document out without reading it copies the agent's text. The
  agent's authorship on the task's document row and on the document page is
  what stands against that; whether it is enough should be watched once
  people use it, and a notification is the next thing to add if it is not.
- A version the chat writes is applied through the change set machinery, so
  its decision is stored as a confirmation with the user's message as its
  origin. That is the user's request, not a review of the text, and the
  version row itself carries no claim of confirmation.
- Documents outlive their agent. Retiring or replacing a task's agent leaves
  the documents and their history in place.
- A whole document travels in the prompt when read, and in the tool call
  when written. That is probably fine for a one-pager, but the token cost
  should be measured with a long document before shipping.
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
