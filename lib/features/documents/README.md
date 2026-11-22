# Documents

Lets a task hold markdown documents, such as a client one-pager, a meeting
summary or a follow-up email. The task's agent drafts and revises them from
what the task already holds, only when asked, and every agent version is a
proposal the user confirms or dismisses. The user can also edit by hand,
restore an older version, and copy the markdown out.

The feature is being built in steps (ADR 0166). Today a user can write a
document by hand, edit it and copy it out; the agent does not draft yet.

## What it does

- **Shows a Documents section on the task** while the task holds a
  document: each one's title, version and age, with a Copy action that puts
  the current markdown on the clipboard. The Add sheet's "Write a document"
  row and the section's + open an editor for a new one; tapping a document
  opens it in the editor.
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
(`ui/task_documents_section.dart`), the editor (`ui/task_document_editor.dart`)
and the Add sheet row (`ui/new_document_item.dart`). The tasks feature places
the section in its page, and the app shell wires the row into the journal's
Add sheet through `JournalDetailSlots.taskCreateActions`.

It delegates storage and sync to the journal. The entities live in
`lib/classes/task_document_data.dart`, a document's versions are read by an
indexed query on `JournalDb`, and `updateJournalEntity` merges two
concurrent versions of a document with `mergeConcurrentTaskDocumentVersions`
instead of raising a conflict.

Still to come: the document page with its history, restore, delete and
side-by-side review, and the agent and chat paths that propose versions.

## Where it sits

`documents` ranks directly below `tasks` in
`tool/architecture/layer_guard.dart`: tasks shows its section, and it will
implement the interface the agents feature defines for writing a
confirmed version.

See [Task documents](../../../knowledge/features/documents.md) for how it
works at runtime.
