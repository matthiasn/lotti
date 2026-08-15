# Tasks

Tasks are where Lotti stops being a journal and becomes a place to get things
done. A task is still a journal entry underneath, but with everything a task
needs: a status, a priority, a due date, an estimate, checklists, labels, a
project, and relationships to other tasks.

## What it does for the user

- **Tracks a piece of work end to end.** Title, status, priority, due date and
  time estimate, with tracked time compared against the estimate as work happens.
- **Starts a new task with somewhere to go.** A task you have just created opens
  with the cursor in its title field, and offers the four things a task usually
  needs next — write a note, add a checklist, record a voice note, assign an
  agent — as worded rows rather than unlabelled glyphs. That block retires the
  moment the task has any content.
- **Breaks work into checklists.** Multiple checklists per task, with items that
  can be reordered, dragged between checklists, and checked off — with a small
  celebration when a list or a task is finished.
- **Relates tasks to each other.** Beyond "relates to", a task can block another,
  follow up on it, duplicate it, fix it, or supersede it — chosen as one plain
  sentence ("This task… Blocks") rather than a type plus a direction. The same
  relationships can be spoken to the task agent ("this task is blocked by X"),
  which proposes the link for confirmation.
- **Knows when work is blocked.** A task with an open blocker is shown as blocked,
  and closing the blocker releases it automatically — no unlock step, on any
  device.
- **Finds the right tasks fast.** Filter by status, priority, label, category or
  project; sort by due date, priority or creation; search by text or by meaning.
  In narrow panes — a phone, or a desktop split view's list pane — the
  search-and-filter header folds into a slim bar while scrolling down the list
  and returns on a deliberate scroll back up, so small screens show tasks
  rather than chrome.
- **Makes room to focus on one task.** On desktop, the task list can be hidden
  after a task is selected and restored without losing its filters, search or
  scroll position. Back remains reserved for returning from a linked task.
- **Saves the filters that matter.** Frequently used queries become named views
  with live counts, pinned in the desktop sidebar or reachable from the mobile
  rail's Views button.
- **Shows AI work in context.** The agent's summary, its proposed changes, and
  what the AI has cost for this task all live on the task itself.

## What it owns

The task detail surfaces and their header; checklist management; linked-task UI;
task progress calculation; task-specific filter widgets and saved filters; and
the detail controls for status, category, priority, project, due date, labels,
estimate and language.

It does **not** own raw task persistence — task entities live in the journal and
persistence layer, and many writes flow through shared controllers there. It also
does not own AI: reports, proposals and prompts come from
[agents](../agents/README.md) and [ai](../ai/README.md).

## Where the code lives

```text
lib/features/tasks/
├── model/ · repository/ · services/
├── state/saved_filters/
├── ui/{checklists,filtering,header,labels,linked_tasks,pages,saved_filters,widgets}
├── util/ · widgetbook/
```

## How it works

The runtime architecture — the shared query stack, the desktop detail stack, the
checklist subsystem and its motion contract, typed relationships and derived
blockedness, header composition and scroll stability, and the saved-filter model
— is documented in the knowledge bundle:

**→ [knowledge/features/tasks/](../../../knowledge/features/tasks/)**
