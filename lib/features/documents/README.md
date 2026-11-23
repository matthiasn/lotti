# Documents

Lets a task hold markdown documents, such as a client one-pager, a meeting
summary or a follow-up email. The task's agent drafts and revises them from
what the task already holds, only when asked, and every agent version is a
proposal the user confirms or dismisses. The user can also edit by hand,
restore an older version, and copy the markdown out.

The feature is being built in steps (ADR 0166). Today a user can write a
document by hand, read it, edit it, look back through its versions, restore
one, delete it and copy it out, and the task's agent drafts and revises
documents when a voice note, a note or the task's chat asks it to. A
proposed version can be read before it is confirmed, and the document page
opens the task's chat beside the document.

## What it does

- **Shows a Documents section on the task** while the task holds a
  document: each one's title, version and age, with a Copy action that puts
  the current markdown on the clipboard. The Add sheet's "Write a document"
  row and the section's + open an editor for a new one; tapping a document
  opens its page.
- **Shows a document on its own page**: its text, where the version came
  from, Edit, Copy, its history of versions with Restore, and Delete.
- **Lays the agent's draft beside the current text**, block by block, so a
  new version is confirmed after seeing what it changes; a draft written
  over an older version cannot be confirmed and is sent back to the agent. On
  desktop the page opens over its task in the detail pane, which comes back
  as it was on close; on a phone it is pushed.
- **Keeps each document on its task.** A document is a `TaskDocumentEntry`
  linked from the task, in the task's category and with its private flag,
  so it syncs, filters and hides with the task.
- **Keeps every version.** The text lives in append-only
  `TaskDocumentVersionEntry` rows; the document only names the version it
  shows. A restore writes the old text as a new version instead of moving
  the document back.
- **Never overwrites a newer version.** A version is written over the
  version it was based on, and only while the document still shows that
  one. An edit or a confirmed proposal based on an older version comes back
  stale, with nothing changed.
- **Deletes a document with its versions**, so nothing is left that the app
  can no longer reach.

## What it owns, and what it delegates

It owns the document repository
(`repository/task_document_repository.dart`): creating, writing versions,
restoring, renaming and deleting. It owns the section
(`ui/task_documents_section.dart`), the editor (`ui/task_document_editor.dart`),
the Add sheet row (`ui/new_document_item.dart`), and the document page with
its history (`ui/task_document_page.dart`, `ui/task_document_history.dart`).
The tasks feature shows the page in its detail pane, and the app shell routes
`/tasks/:taskId/documents/:documentId` to it. The tasks feature places
the section in its page, and the app shell wires the row into the journal's
Add sheet through `JournalDetailSlots.taskCreateActions`.

It delegates storage and sync to the journal. The entities live in
`lib/classes/task_document_data.dart`, a document's versions are read by an
indexed query on `JournalDb`, and `updateJournalEntity` merges two
concurrent versions of a document with `mergeConcurrentTaskDocumentVersions`
instead of raising a conflict.

It implements the task agent's `TaskDocumentSource` port
(`service/task_document_agent_source.dart`), through which the agent lists
and reads a task's documents and a version the user confirmed is written;
the agent's tools and their rules live in the agents feature.

It owns the side-by-side review of the agent's draft of a new version
(`ui/widgets/document_review_view.dart`): the document page opens it from
its "Review changes" notice, with the versions side by side where the pane
is wide enough and stacked where it is not, and Confirm or Discard decided
through the agents feature's confirmation service. Its block alignment is
in `logic/markdown_block_diff.dart` and its state in
`state/document_review_providers.dart`, which also tells the task split
and the app shell when a review is on screen, so the task list and the day
column step aside for it. Still to come: a route into it.

## Where it sits

`documents` ranks directly below `tasks` in
`tool/architecture/layer_guard.dart`: tasks shows its section, and it will
implement the interface the agents feature defines for writing a
confirmed version.

See [Task documents](../../../knowledge/features/documents.md) for how it
works at runtime.
